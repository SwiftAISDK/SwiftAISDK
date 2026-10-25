// Actual GitHub publication. The offline planner/exporter remains network-free.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { json, ensure } = require("./catalog.cjs");
const release = require("./release.cjs");
const { run, hash, atomicJSON, committedFiles, compare, accepts } = release;
const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
function git(args, cwd, identity) {
  return run("git", ["-c", "core.hooksPath=/dev/null", "-c", "commit.gpgSign=false",
    "-c", "tag.gpgSign=false", "-c", `user.name=${identity.name}`,
    "-c", `user.email=${identity.email}`, ...args], cwd, {
    env: { ...process.env, GIT_AUTHOR_DATE: identity.date, GIT_COMMITTER_DATE: identity.date },
  });
}
function refs(remote, version, cwd, identity) {
  return Object.fromEntries(git(["ls-remote", remote, "refs/heads/main",
    `refs/tags/${version}`, `refs/tags/${version}^{}`], cwd, identity)
    .split("\n").filter(Boolean).map((line) => line.split(/\s+/).reverse()));
}
function verifyRefs(actual, receipt, requireHead = false) {
  ensure(actual[`refs/tags/${receipt.version}`] === receipt.tagObject &&
    actual[`refs/tags/${receipt.version}^{}`] === receipt.exportCommit &&
    (!requireHead || actual["refs/heads/main"] === receipt.exportCommit),
  `Remote refs differ: ${receipt.package}@${receipt.version}; immutable tags will not be replaced`);
}
function verifyHostedCI(result, jobs, commit) {
  ensure(result.head_sha === commit && result.conclusion === "success" &&
    result.status === "completed" && result.path === ".github/workflows/docs.yml" &&
    ["push", "workflow_dispatch"].includes(result.event) &&
    jobs.some(j => j.name === "test" && j.status === "completed" && j.conclusion === "success"),
    "Canonical Swift tests have not passed for this exact source commit");
  return { id: result.id, url: result.html_url, sourceCommit: result.head_sha };
}
function github(root, canonical) {
  const api = (endpoint) => JSON.parse(run("gh", ["api", endpoint], root));
  return {
    verifyCI(commit, runID) {
      ensure(/^\d+$/.test(String(runID)), "A completed canonical CI run is required");
      const result = api(`repos/${canonical}/actions/runs/${runID}`);
      const jobs = api(`repos/${canonical}/actions/runs/${runID}/jobs`).jobs;
      return verifyHostedCI(result, jobs, commit);
    },
    remote(entry) {
      const match = /^https:\/\/github\.com\/([A-Za-z0-9-]+\/swift-ai-[a-z0-9-]+)\.git$/.exec(entry.repository);
      ensure(match && match[1].startsWith(canonical.split("/")[0] + "/"), "Unexpected publication destination");
      const repo = api(`repos/${match[1]}`);
      ensure(repo.full_name === match[1] && !repo.private && !repo.archived &&
        repo.permissions?.push && repo.default_branch === "main", "Destination is not a writable public distribution repository");
      return { url: `git@github.com:${match[1]}.git`, name: match[1], id: repo.id };
    },
    release(destination, receipt, notes, notesFile) {
      // Listing a repository is unambiguous: auth/server failures must not be
      // mistaken for a missing release and retried as a write.
      const entries = JSON.parse(run("gh", ["api", "--paginate", "--slurp",
        `repos/${destination.name}/releases?per_page=100`], root)).flat();
      let found = entries.find((r) => r.tag_name === receipt.version);
      if (!found) {
        fs.writeFileSync(notesFile, notes);
        run("gh", ["release", "create", receipt.version, "--repo", destination.name,
          "--verify-tag", "--target", receipt.exportCommit, "--title", `${receipt.package} ${receipt.version}`,
          "--notes-file", notesFile], root);
        found = api(`repos/${destination.name}/releases/tags/${receipt.version}`);
      }
      ensure(found.tag_name === receipt.version && found.target_commitish === receipt.exportCommit &&
        !found.draft && !found.prerelease && found.body.replace(/\r\n/g, "\n").trim() === notes.trim(),
      `Existing GitHub Release differs: ${receipt.package}; refusing to edit it`);
      return { id: found.id, url: found.html_url, target: found.target_commitish };
    },
  };
}
function publish(root, directory, staging, { ciRun, canonical = "SwiftAISDK/SwiftAISDK",
  // Internal transport seam for offline failure/recovery tests; not exposed by CLI.
  backend = null, afterPush = null } = {}) {
  root = path.resolve(root); directory = path.resolve(directory); staging = path.resolve(staging);
  const bundle = release.validateExport(directory), candidate = bundle.plan;
  ensure(bundle.publication === true && candidate.source.commit && !candidate.source.workingTree,
    "Publication needs a production export from committed clean source");
  release.validatePlan(root, candidate);
  const disjoint = (a, b) => a !== b && !a.startsWith(b + path.sep) && !b.startsWith(a + path.sep);
  ensure(disjoint(staging, directory) && !root.startsWith(staging + path.sep) && staging !== root,
    "Publication staging overlaps source or export");
  // Regenerate instead of trusting a self-consistent but edited bundle/hash list.
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "swift-ai-publish-validation-"));
  try {
    const fresh = release.exportRelease(root, candidate, path.join(scratch, "export"), { publication: true });
    ensure(json(fresh) === json(bundle), "Export does not match committed canonical source");
  } finally { fs.rmSync(scratch, { recursive: true, force: true }); }
  fs.mkdirSync(staging, { recursive: true });
  ensure(!fs.lstatSync(staging).isSymbolicLink() && disjoint(fs.realpathSync(staging), fs.realpathSync(directory)),
    "Publication staging overlaps through a symlink");
  const transport = backend || github(root, canonical);
  const ci = transport.verifyCI(candidate.source.commit, ciRun);
  const identity = {
    name: run("git", ["show", "-s", "--format=%an", candidate.source.commit], root),
    email: run("git", ["show", "-s", "--format=%ae", candidate.source.commit], root),
    date: run("git", ["show", "-s", "--format=%cI", candidate.source.commit], root),
  };
  const unlock = release.lock(staging), marker = path.join(staging, "attempt.json");
  try {
    const bundleSHA256 = hash(json(bundle));
    if (!fs.existsSync(marker)) {
      ensure(fs.readdirSync(staging).every((p) => p === "attempt.lock" || p === "attempt.json.tmp"),
        "Unknown publication staging contents");
      atomicJSON(marker, { schemaVersion: 1, kind: "github-publication", status: "in-progress",
        sourceCommit: candidate.source.commit, bundleSHA256, ci, packages: [] });
    }
    const journal = read(marker);
    ensure(journal.kind === "github-publication" && journal.bundleSHA256 === bundleSHA256,
      "Staging belongs to another publication");
    const history = fs.readdirSync(path.join(root, "Releases/sets")).filter((f) => f.endsWith(".json"))
      .flatMap((f) => read(path.join(root, "Releases/sets", f)).packages);
    const destinations = new Map(candidate.packages.map((p) => [p.package, transport.remote(p)]));
    for (const entry of bundle.exports) {
      const specification = candidate.packages.find((p) => p.package === entry.package);
      for (const dependency of entry.dependencies) {
        const verified = [...journal.packages, ...history].filter((p) =>
          p.package === dependency.package && accepts(dependency.from, p.version))
          .sort((a, b) => compare(b.version, a.version))[0];
        ensure(verified, `Unverified dependency: ${entry.package} -> ${dependency.package}`);
        const dest = destinations.get(dependency.package) || transport.remote({
          package: dependency.package, repository: `https://github.com/${canonical.split("/")[0]}/${dependency.package}.git` });
        verifyRefs(refs(dest.url, verified.version, staging, identity), verified);
      }
      const destination = destinations.get(entry.package);
      const previous = history.filter((p) => p.package === entry.package)
        .sort((a, b) => compare(b.version, a.version))[0];
      const repository = path.join(staging, "repositories", entry.package);
      const candidateFile = path.join(staging, `${entry.package}.json`);
      let remote = refs(destination.url, entry.version, staging, identity);
      if (!fs.existsSync(candidateFile)) {
        ensure(!remote[`refs/tags/${entry.version}`] &&
          (previous ? remote["refs/heads/main"] === previous.exportCommit : !remote["refs/heads/main"]),
          `Unrecorded existing destination refs: ${entry.package}; inspect instead of overwriting`);
        fs.rmSync(repository, { recursive: true, force: true });
        fs.mkdirSync(path.dirname(repository), { recursive: true });
        if (previous) {
          verifyRefs(refs(destination.url, previous.version, staging, identity), previous, true);
          git(["clone", "-q", destination.url, repository], staging, identity);
          git(["rm", "-r", "--ignore-unmatch", "."], repository, identity);
        }
        fs.cpSync(path.join(directory, entry.package), repository, { recursive: true });
        if (!previous) git(["init", "-q", "--initial-branch=main"], repository, identity);
        git(["add", "."], repository, identity);
        const message = `${entry.package} ${entry.version}\n\nCanonical-Commit: ${candidate.source.commit}\nExport-SHA256: ${entry.sha256}`;
        git(["commit", "-q", "-m", message], repository, identity);
        git(["tag", "-a", entry.version, "-m", message], repository, identity);
        atomicJSON(candidateFile, { package: entry.package, version: entry.version,
          sourceCommit: candidate.source.commit, exportSHA256: entry.sha256,
          exportCommit: git(["rev-parse", "HEAD"], repository, identity),
          tagObject: git(["rev-parse", `refs/tags/${entry.version}`], repository, identity),
          dependencies: entry.dependencies });
      }
      const receipt = read(candidateFile);
      ensure(receipt.package === entry.package && receipt.version === entry.version &&
        receipt.sourceCommit === candidate.source.commit && receipt.exportSHA256 === entry.sha256 &&
        json(receipt.dependencies) === json(entry.dependencies), "Candidate receipt changed");
      ensure(git(["cat-file", "-t", receipt.tagObject], repository, identity) === "tag" &&
        git(["rev-parse", `${entry.version}^{}`], repository, identity) === receipt.exportCommit &&
        git(["rev-parse", `refs/tags/${entry.version}`], repository, identity) === receipt.tagObject &&
        json(committedFiles(repository, receipt.exportCommit)) === json(entry.files), "Local candidate payload/tag changed");
      if (!remote[`refs/tags/${entry.version}`]) {
        ensure(previous ? remote["refs/heads/main"] === previous.exportCommit : !remote["refs/heads/main"],
          "Destination main changed before publication");
        git(["push", "--atomic", destination.url, `${receipt.exportCommit}:refs/heads/main`,
          `refs/tags/${entry.version}:refs/tags/${entry.version}`], repository, identity);
      }
      verifyRefs(refs(destination.url, entry.version, staging, identity), receipt, true);
      if (afterPush) afterPush(entry);
      const verification = path.join(staging, "readback", entry.package);
      fs.rmSync(verification, { recursive: true, force: true });
      fs.mkdirSync(path.dirname(verification), { recursive: true });
      git(["clone", "--bare", "-q", destination.url, verification], staging, identity);
      ensure(json(committedFiles(verification, receipt.exportCommit)) === json(entry.files), "Remote payload differs from export");
      const notes = `${entry.package} ${entry.version}\n\n${specification.changes.map((c) => `- ${c.notes}\n  Compatibility: ${c.compatibility}`).join("\n")}\n\nCanonical source: https://github.com/${canonical}/commit/${candidate.source.commit}\nExport SHA-256: ${entry.sha256}\n\nIndependent Swift-native port of Vercel AI SDK. npm baselines and retained source/test gaps are recorded in PROVENANCE.json and Porting/. Swift versions are independent of npm versions.\n`;
      const githubRelease = transport.release(destination, receipt, notes, path.join(staging, `${entry.package}-notes.md`));
      verifyRefs(refs(destination.url, entry.version, staging, identity), receipt, true);
      const verified = { ...receipt, githubRelease, repository: destination };
      const prior = journal.packages.find((p) => p.package === entry.package);
      ensure(!prior || json(prior) === json(verified), "Journal differs from verified publication");
      if (!prior) journal.packages.push(verified);
      atomicJSON(marker, journal);
    }
    journal.status = "tags-and-releases-ready";
    atomicJSON(marker, journal);
    return journal;
  } finally { unlock(); }
}
module.exports = { publish, verifyRefs, verifyHostedCI };
