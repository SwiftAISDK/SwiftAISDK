// Immutable published archive preparation and conservative Swift owner selection.
// Preparation never edits reviewed baselines or claims that a test was ported.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { spawnSync } = require("node:child_process");
const { readCatalog, json, ensure } = require("./catalog.cjs");
const { affected } = require("./generate.cjs");
const { hash, run } = require("./release.cjs");

function verifyIntegrity(bytes, integrity) {
  const entries = String(integrity).split(/\s+/).filter(Boolean);
  ensure(entries.length && entries.every(s => /^sha(256|384|512)-[A-Za-z0-9+/]+=*$/.test(s)),
    "Missing or unsupported published archive integrity");
  ensure(entries.some(s => {
    const dash = s.indexOf("-");
    return crypto.createHash(s.slice(0, dash)).update(bytes).digest("base64") === s.slice(dash + 1);
  }), "Published archive integrity mismatch");
}
function fileHashes(directory) {
  const files = [];
  function walk(relative) {
    for (const e of fs.readdirSync(path.join(directory, relative), { withFileTypes: true })) {
      const file = path.posix.join(relative, e.name);
      ensure(!e.isSymbolicLink(), "Unexpected archive symlink: " + file);
      if (e.isDirectory()) walk(file);
      else { ensure(e.isFile(), "Unexpected archive input: " + file); files.push({ path: file, sha256: hash(fs.readFileSync(path.join(directory, file))) }); }
    }
  }
  walk("");
  return files.sort((a, b) => a.path.localeCompare(b.path));
}
function changedFiles(before, after) {
  const a = new Map(before.map(f => [f.path, f.sha256])), b = new Map(after.map(f => [f.path, f.sha256]));
  return [...new Set([...a.keys(), ...b.keys()])].sort().filter(f => a.get(f) !== b.get(f))
    .map(file => ({ path: file, change: !a.has(file) ? "added" : !b.has(file) ? "deleted" : "modified" }));
}
function selectOwners(data, upstreamNames) {
  const owners = data.catalog.packages.filter(p => p.upstream.some(n => upstreamNames.includes(n)));
  ensure(owners.length, "No registered Swift owner for requested upstream package");
  const swiftPaths = owners.flatMap(p => Object.values(data.maps.get(p.id).swift).flat());
  return {
    owners: owners.map(p => ({ package: p.id, mappingStatus: data.maps.get(p.id).status,
      swift: data.maps.get(p.id).swift, dependencies: p.dependencies, upstream: data.maps.get(p.id).upstream })),
    verification: affected(data, swiftPaths),
    releaseSelection: "No releases selected by discovery; review changed Swift units separately.",
  };
}
function productionBackend(root) {
  return {
    archive(name, version, directory) {
      const metadata = JSON.parse(run("npm", ["view", `${name}@${version}`, "--json"], root));
      ensure(metadata.name === name && metadata.version === version, "Registry package/version mismatch");
      const result = JSON.parse(run("npm", ["pack", `${name}@${version}`, "--ignore-scripts", "--pack-destination", directory, "--json"], root))[0];
      ensure(result && path.basename(result.filename) === result.filename, "Unexpected npm archive filename");
      const file = path.join(directory, result.filename), bytes = fs.readFileSync(file);
      verifyIntegrity(bytes, metadata.dist?.integrity);
      return { metadata, file, bytes };
    },
    tests(name, version, metadata, fallback, destination) {
      const slug = name.replace("@ai-sdk/", ""), prefix = `packages/${slug}/`;
      const repository = typeof metadata.repository === "string" ? metadata.repository : metadata.repository?.url;
      ensure(repository && /github\.com[/:]vercel\/ai(?:\.git)?$/.test(repository), "Unexpected upstream repository");
      let ref = /^[a-f0-9]{40}$/.test(metadata.gitHead || "") ? metadata.gitHead : null;
      if (!ref) {
        const tag = `${name}@${version}`;
        const refs = run("git", ["ls-remote", "https://github.com/vercel/ai.git", `refs/tags/${tag}`, `refs/tags/${tag}^{}`], root)
          .split("\n").filter(Boolean).map(s => s.split(/\s+/));
        ref = refs.find(r => r[1].endsWith("^{}"))?.[0] || refs[0]?.[0] || null;
      }
      let relationship = ref ? "matching-release" : "unavailable";
      if (!ref && fallback?.testRef) {
        ref = fallback.testRef;
        relationship = "inventory-snapshot-not-release-verified";
      }
      if (!ref) return { ref: null, relationship, files: [], note: "No release ref or recorded fallback exists." };
      ensure(/^[a-f0-9]{40}$/.test(ref), "Invalid upstream test revision");
      const api = endpoint => JSON.parse(run("gh", ["api", endpoint], root));
      if (relationship === "matching-release") {
        const entry = api(`repos/vercel/ai/contents/${prefix}package.json?ref=${ref}`);
        const pkg = JSON.parse(Buffer.from(entry.content, "base64").toString("utf8"));
        ensure(pkg.name === name && pkg.version === version, "Release test ref package/version mismatch");
      }
      const tree = api(`repos/vercel/ai/git/trees/${ref}?recursive=1`);
      ensure(!tree.truncated, "Upstream tree listing is truncated");
      const paths = tree.tree.filter(e => e.type === "blob" && e.path.startsWith(prefix) && /\.(test|test-d|spec)\.tsx?$/.test(e.path));
      for (const entry of paths) {
        ensure(!entry.path.split("/").includes(".."), "Unsafe upstream test path");
        const file = path.join(destination, entry.path); fs.mkdirSync(path.dirname(file), { recursive: true });
        run("curl", ["--fail", "--silent", "--show-error", "--location", `https://raw.githubusercontent.com/vercel/ai/${ref}/${entry.path}`, "--output", file], root);
        const bytes = fs.readFileSync(file);
        const blob = crypto.createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
        ensure(blob === entry.sha, "Upstream test blob mismatch");
      }
      return { ref, relationship, files: fileHashes(destination),
        note: relationship === "matching-release" ? "Package version checked at immutable ref; review tests before advancing provenance." : "Explicit recorded fallback; these tests do not prove release-matched parity." };
    },
  };
}
function prepare(root, { name, from, to, directory }, backend = productionBackend(root)) {
  ensure(/^(ai|@ai-sdk\/[a-z0-9-]+)$/.test(name) && [from, to].every(v => /^\d+\.\d+\.\d+(?:-[\w.-]+)?$/.test(v)), "Invalid upstream package/version");
  const data = readCatalog(root), selection = selectOwners(data, [name]);
  const lock = data.lock.packages.find(p => p.name === name);
  const request = { name, from, to };
  if (fs.existsSync(directory)) {
    const file = path.join(directory, "work-item.json");
    ensure(fs.existsSync(file), "Incomplete preparation exists; choose a new --work-dir for a retry");
    const existing = JSON.parse(fs.readFileSync(file, "utf8"));
    ensure(json(existing.request) === json(request), "Preparation directory belongs to a different request");
    ensure(json(existing.owners) === json(selection.owners) &&
      json(existing.verification) === json(selection.verification),
      "Swift ownership changed since preparation; choose a new --work-dir");
    for (const side of ["old", "new"]) {
      const e = existing[side];
      verifyIntegrity(fs.readFileSync(path.join(directory, e.archive)), e.integrity);
      ensure(json(fileHashes(path.join(directory, side))) === json(e.files), "Prepared source bytes changed");
      ensure(json(fileHashes(path.join(directory, `${side}-tests`))) === json(e.tests.files), "Prepared test bytes changed");
    }
    return existing;
  }
  fs.mkdirSync(directory, { recursive: true });
  const result = { schemaVersion: 1, status: "prepared-not-reviewed", request, ...selection };
  for (const [side, version] of [["old", from], ["new", to]]) {
    const packs = path.join(directory, "packs", side); fs.mkdirSync(packs, { recursive: true });
    const archive = backend.archive(name, version, packs);
    verifyIntegrity(archive.bytes, archive.metadata.dist?.integrity);
    const listing = run("tar", ["-tzf", archive.file], root).split("\n").filter(Boolean);
    ensure(listing.every(p => p.startsWith("package/") && !p.split("/").includes("..")), "Unsafe archive member");
    const types = run("tar", ["-tvzf", archive.file], root).split("\n").filter(Boolean);
    ensure(types.every(p => p[0] === "-" || p[0] === "d"), "Archive contains links or special files");
    const extracted = path.join(directory, side); fs.mkdirSync(extracted);
    run("tar", ["-xzf", archive.file, "-C", extracted, "--strip-components=1"], root);
    const testsPath = path.join(directory, side + "-tests"); fs.mkdirSync(testsPath);
    result[side] = { version, archive: path.relative(directory, archive.file),
      integrity: archive.metadata.dist.integrity, archiveSHA256: hash(archive.bytes),
      files: fileHashes(extracted), tests: backend.tests(name, version, archive.metadata, lock, testsPath) };
  }
  result.changedFiles = changedFiles(result.old.files, result.new.files);
  result.changedTests = changedFiles(result.old.tests.files, result.new.tests.files);
  result.declarationChanges = result.changedFiles.filter(f => /\.d\.[cm]?ts$/.test(f.path));
  result.testComparison = result.old.tests.relationship === "matching-release" && result.new.tests.relationship === "matching-release"
    ? "release-matched" : "incomplete: missing release-matched test evidence; unchanged fallback tests are not proof of no test changes";
  const diff = spawnSync("diff", ["-ruN", "--exclude=*.map", path.join(directory, "old"), path.join(directory, "new")], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  ensure(!diff.error && [0, 1].includes(diff.status), "Upstream diff failed");
  fs.writeFileSync(path.join(directory, "upstream.diff"), diff.stdout);
  fs.writeFileSync(path.join(directory, "summary.md"), `# ${name} ${from} → ${to}\n\nPrepared, not reviewed. Production baselines were not changed.\n\nSwift owners: ${result.owners.map(p => p.package).join(", ")}\n\n${result.testComparison}\n\nSee work-item.json for immutable archives, test revisions, changed declarations, source/test owners and downstream checks. Read the tests before porting implementation. Record each delta's disposition, Swift changes, translated tests and documentation before advancing the reviewed baseline.\n`);
  fs.writeFileSync(path.join(directory, "work-item.json"), json(result));
  return result;
}
module.exports = { prepare, selectOwners, verifyIntegrity, changedFiles, fileHashes };
