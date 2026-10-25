// Offline release planning/export and local-only publication rehearsal.
// No function in this module accepts a network publication destination.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const os = require("node:os");
const { spawnSync } = require("node:child_process");
const {
  json,
  ensure,
  localPath,
  readCatalog,
  validateSchema,
} = require("./catalog.cjs");
const { manifest, exportInputRoots } = require("./generate.cjs");
const hash = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");
const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const rank = { initial: 0, patch: 1, minor: 2, major: 3 };
function run(command, args, cwd, options = {}) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });
  if (result.error) throw result.error;
  ensure(
    result.status === 0,
    `${command} ${args.join(" ")} failed (${result.status})\n${result.stdout || ""}${result.stderr || ""}`,
  );
  return result.stdout.trim();
}
function git(args, cwd) {
  return run(
    "git",
    [
      "-c",
      "core.hooksPath=/dev/null",
      "-c",
      "commit.gpgSign=false",
      "-c",
      "tag.gpgSign=false",
      "-c",
      "user.name=SwiftAISDK Release Rehearsal",
      "-c",
      "user.email=rehearsal@example.invalid",
      ...args,
    ],
    cwd,
    {
      env: {
        ...process.env,
        GIT_AUTHOR_DATE: "2000-01-01T00:00:00Z",
        GIT_COMMITTER_DATE: "2000-01-01T00:00:00Z",
      },
    },
  );
}
function compare(a, b) {
  const aa = a.split(".").map(Number),
    bb = b.split(".").map(Number);
  for (let i = 0; i < 3; i++) if (aa[i] !== bb[i]) return aa[i] - bb[i];
  return 0;
}
const accepts = (from, version) =>
  compare(version, from) >= 0 && version.split(".")[0] === from.split(".")[0];
function versionAfter(old, bump) {
  if (!old) {
    ensure(bump === "initial", "First release must use an initial change");
    return "1.0.0";
  }
  ensure(
    bump !== "initial",
    "Initial change cannot follow a published release",
  );
  const v = old.split(".").map(Number),
    index = { major: 0, minor: 1, patch: 2 }[bump];
  v[index]++;
  for (let i = index + 1; i < 3; i++) v[i] = 0;
  return v.join(".");
}
function records(root, directory, definition, definitions) {
  const dir = localPath(root, directory, true);
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .map((file) => {
      const value = read(localPath(root, `${directory}/${file}`, true));
      validateSchema(
        value,
        definitions[definition],
        definitions,
        `${directory}/${file}`,
      );
      ensure(
        file === value.id + ".json",
        `Record filename must match id: ${file}`,
      );
      return value;
    });
}
function filesIn(root, relative) {
  const full = localPath(root, relative, true),
    stat = fs.lstatSync(full);
  ensure(
    !stat.isSymbolicLink(),
    `Export symlinks are not supported: ${relative}`,
  );
  if (stat.isFile()) return [relative];
  ensure(stat.isDirectory(), `Not a regular export input: ${relative}`);
  return fs
    .readdirSync(full)
    .sort()
    .flatMap((name) => {
      // OS/build metadata is never an export input. All actual sources/resources
      // are still checked against the catalog before this allowlist is expanded.
      if (
        name === ".DS_Store" ||
        name.startsWith("._") ||
        [".build", ".swiftpm", ".git", "node_modules"].includes(name)
      )
        return [];
      return filesIn(root, `${relative}/${name}`);
    });
}
function packageInputs(data, p) {
  const roots = exportInputRoots(p);
  ensure(
    fs.readFileSync(
      localPath(data.root, `${p.directory}/Package.swift`, true),
      "utf8",
    ) === manifest(data, p),
    `Stale canonical manifest: ${p.id}; run sdk.mjs generate`,
  );
  if (fs.existsSync(path.join(data.root, p.directory, "LICENSE")))
    roots.push(`${p.directory}/LICENSE`);
  for (const name of ["NOTICE", `${p.directory}/NOTICE`])
    if (fs.existsSync(path.join(data.root, name))) roots.push(name);
  return [...new Set(roots.flatMap((r) => filesIn(data.root, r)))].sort();
}
function plan(root, id = "modular-pilot") {
  ensure(/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(id), "Invalid release id");
  const data = readCatalog(root),
    defs = read(localPath(root, "Releases/schema.json", true)).$defs;
  const changes = records(root, "Releases/changes", "change", defs),
    sets = records(root, "Releases/sets", "releaseSet", defs);
  ensure(
    !sets.some((set) => set.id === id),
    "Release id already belongs to a published set",
  );
  // A previously committed release record is append-only. New records are
  // produced only after the real publication/consumer gate in M5.
  const committedRecords = git(
    ["ls-tree", "-r", "--name-only", "HEAD", "Releases/sets"],
    root,
  )
    .split("\n")
    .filter((file) => file.endsWith(".json"));
  for (const file of committedRecords) {
    const prior = spawnSync("git", ["show", `HEAD:${file}`], { cwd: root });
    ensure(
      prior.status === 0 &&
        fs.existsSync(path.join(root, file)) &&
        prior.stdout.equals(fs.readFileSync(path.join(root, file))),
      `Published release record was modified or deleted: ${file}`,
    );
  }
  const consumed = new Set(),
    latest = new Map(),
    known = new Set();
  for (const set of sets) {
    ensure(
      set.packages.length > 0 && set.changeIDs.length > 0,
      `Empty published set ${set.id}`,
    );
    ensure(
      new Set(set.packages.map((p) => p.package)).size === set.packages.length,
      `Duplicate package in set ${set.id}`,
    );
    for (const change of set.changeIDs) {
      ensure(!consumed.has(change), `Change consumed twice: ${change}`);
      consumed.add(change);
    }
    for (const p of set.packages) {
      ensure(
        p.sourceCommit === set.sourceCommit,
        `Mixed canonical commits in ${set.id}`,
      );
      ensure(
        !known.has(p.package + "@" + p.version),
        `Duplicate published version ${p.package}@${p.version}`,
      );
      known.add(p.package + "@" + p.version);
      ensure(
        data.catalog.packages.some((q) => q.id === p.package),
        `Unknown published package ${p.package}`,
      );
      if (
        !latest.has(p.package) ||
        compare(p.version, latest.get(p.package).version) > 0
      )
        latest.set(p.package, p);
    }
  }
  const pending = changes.filter(
      (c) => c.status === "reviewed" && !consumed.has(c.id),
    ),
    selected = new Map();
  for (const change of pending) {
    ensure(
      change.summary.trim() && change.packages.length,
      `Empty change ${change.id}`,
    );
    const seen = new Set();
    for (const entry of change.packages) {
      ensure(
        !seen.has(entry.package),
        `Duplicate change package ${entry.package}`,
      );
      seen.add(entry.package);
      ensure(
        entry.notes.trim() && entry.compatibility.trim(),
        `Missing change rationale ${entry.package}`,
      );
      const p = data.catalog.packages.find((p) => p.id === entry.package);
      ensure(
        p?.state === "extracted",
        `Cannot release unextracted package ${entry.package}`,
      );
      ensure(data.maps.get(p.id).status !== "unreviewed" &&
        p.upstream.every(name => data.lock.packages.find(u => u.name === name).reviewStatus !== "unreviewed"),
        `Cannot release unreviewed implementation ${p.id}`);
      const previous = selected.get(p.id);
      if (previous)
        ensure(
          (previous.bump === "initial") === (entry.bump === "initial"),
          `Conflicting initial/change bumps for ${p.id}`,
        );
      selected.set(p.id, {
        bump:
          previous && rank[previous.bump] > rank[entry.bump]
            ? previous.bump
            : entry.bump,
        changes: [
          ...(previous?.changes || []),
          {
            id: change.id,
            notes: entry.notes,
            compatibility: entry.compatibility,
          },
        ],
      });
    }
  }
  const packages = data.order
    .filter((id) => selected.has(id))
    .map((id) => {
      const p = data.catalog.packages.find((p) => p.id === id),
        change = selected.get(id);
      return {
        package: id,
        version: versionAfter(latest.get(id)?.version, change.bump),
        bump: change.bump,
        repository: p.repository,
        dependencies: p.dependencies,
        changes: change.changes,
        inputs: packageInputs(data, p),
      };
    });
  const versions = new Map([...latest].map(([id, p]) => [id, p.version]));
  packages.forEach((p) => versions.set(p.package, p.version));
  // A higher minimum must be released with the provider that needs it, not just
  // silently rewritten into its exported manifest without a SemVer change.
  for (const p of data.catalog.packages.filter(
    (p) => p.state === "extracted",
  )) {
    if (latest.has(p.id) && !selected.has(p.id))
      ensure(
        json(p.dependencies) === json(latest.get(p.id).dependencies),
        `Changed dependency requirements need a release entry: ${p.id}`,
      );
  }
  for (const p of packages)
    for (const d of p.dependencies) {
      const available = [
        versions.get(d.package),
        ...sets.flatMap((s) =>
          s.packages
            .filter((p) => p.package === d.package)
            .map((p) => p.version),
        ),
      ].filter(Boolean);
      ensure(
        available.some((v) => accepts(d.from, v)),
        `Unavailable compatible dependency ${p.package} -> ${d.package} from ${d.from}`,
      );
    }
  const affected = new Set(packages.map((p) => p.package));
  let changed = true;
  while (changed) {
    changed = false;
    for (const p of data.catalog.packages.filter(
      (p) => p.state === "extracted",
    ))
      if (
        !affected.has(p.id) &&
        p.dependencies.some((d) => affected.has(d.package))
      ) {
        affected.add(p.id);
        changed = true;
      }
  }
  const inputNames = [
    ...new Set([
      ...packages.flatMap((p) => p.inputs),
      "Porting/packages.json",
      "Porting/upstream-lock.json",
      "Porting/workspace-map.json",
      "Porting/schemas/catalog.schema.json",
      "Releases/schema.json",
      ...filesIn(root, "Releases/changes"),
      ...filesIn(root, "Releases/sets"),
      ...filesIn(root, "Scripts/lib"),
      "Scripts/sdk.mjs",
    ]),
  ].sort();
  const inputs = inputNames.map((file) => ({
    path: file,
    sha256: hash(fs.readFileSync(localPath(root, file, true))),
  }));
  const baseCommit = git(["rev-parse", "HEAD"], root),
    dirty =
      git(["status", "--porcelain", "--untracked-files=normal"], root) !== "";
  return {
    schemaVersion: 1,
    id,
    status: "candidate",
    publicationReady: false,
    source: {
      commit: dirty ? null : baseCommit,
      baseCommit,
      workingTree: dirty,
      inputsSHA256: hash(json(inputs)),
      inputs,
    },
    changeIDs: pending.map((c) => c.id),
    packages,
    verificationPackages: data.order.filter((id) => affected.has(id)),
    gate: "Export rehearsal only. Real publication requires a committed source, configured destinations, current verification and explicit release scope.",
  };
}
function treeFiles(root) {
  return filesIn(root, ".")
    .map((p) => p.replace(/^\.\//, ""))
    .sort()
    .map((p) => ({
      path: p,
      sha256: hash(fs.readFileSync(path.join(root, p))),
    }));
}
function writeFile(root, relative, content) {
  const file = localPath(root, relative);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}
function validatePlan(root, candidate) {
  ensure(
    candidate.status === "candidate" && candidate.schemaVersion === 1,
    "Not a release candidate plan",
  );
  const fresh = plan(root, candidate.id);
  ensure(
    json(fresh) === json(candidate),
    "Release plan is stale: source, changes, dependency graph or Git state changed",
  );
}
function exportRelease(root, candidate, destination, { publication = false } = {}) {
  if (publication) ensure(candidate.source.commit && !candidate.source.workingTree, "Publication requires committed clean source");
  validatePlan(root, candidate);
  ensure(candidate.packages.length > 0, "No reviewed pending release changes");
  ensure(
    !fs.existsSync(destination),
    "Export destination already exists; choose a new directory",
  );
  const data = readCatalog(root),
    exports = [];
  fs.mkdirSync(destination, { recursive: true });
  try {
    for (const entry of candidate.packages) {
      const p = data.catalog.packages.find((p) => p.id === entry.package),
        dir = path.join(destination, p.id);
      fs.mkdirSync(dir);
      const canonicalMap = read(
        path.join(root, p.directory, "Porting/map.json"),
      );
      const canonicalOnlyReferences = [];
      const swift = Object.fromEntries(
        Object.entries(canonicalMap.swift).map(([kind, paths]) => [
          kind,
          paths
            .filter((f) => {
              if (!f.startsWith(p.directory + "/")) {
                canonicalOnlyReferences.push({ kind, path: f });
                return false;
              }
              return true;
            })
            .map((f) => f.slice(p.directory.length + 1)),
        ]),
      );
      // Only explicit package source/test roots are copied. Metadata is rendered
      // below; original mappings are also retained verbatim for traceability.
      for (const input of entry.inputs)
        if (
          input.startsWith(p.directory + "/Sources/") ||
          input.startsWith(p.directory + "/Tests/")
        )
          writeFile(
            dir,
            input.slice(p.directory.length + 1),
            fs.readFileSync(path.join(root, input)),
          );
      writeFile(
        dir,
        "Package.swift",
        manifest(data, p, { distribution: true }),
      );
      writeFile(
        dir,
        "LICENSE",
        fs.readFileSync(
          path.join(
            root,
            fs.existsSync(path.join(root, p.directory, "LICENSE"))
              ? p.directory + "/LICENSE"
              : "LICENSE",
          ),
        ),
      );
      const notices = ["NOTICE", `${p.directory}/NOTICE`].filter((f) =>
        entry.inputs.includes(f),
      );
      if (notices.length)
        writeFile(
          dir,
          "NOTICE",
          notices
            .map((f) => fs.readFileSync(path.join(root, f), "utf8"))
            .join("\n"),
        );
      writeFile(
        dir,
        "Porting/canonical-map.json",
        fs.readFileSync(path.join(root, p.directory, "Porting/map.json")),
      );
      writeFile(
        dir,
        "Porting/map.json",
        json({
          ...canonicalMap,
          swift,
          canonicalOnlyReferences,
          canonicalDirectory: p.directory,
        }),
      );
      const upstream = data.lock.packages.filter((u) =>
        p.upstream.includes(u.name),
      );
      writeFile(
        dir,
        "Porting/upstream-lock.json",
        json({ schemaVersion: 1, packages: upstream }),
      );
      writeFile(dir, "Porting/capabilities.json", json(p.capabilityRows));
      const content = fs.readFileSync(
        path.join(root, p.directory, "README.md"),
        "utf8",
      );
      // Preserve authored prose; canonical-checkout relative links become links
      // to the canonical project. The export itself has no sibling file access.
      const guide = content.replace(
        /\]\((?![a-z]+:|#)([^)]+)\)/g,
        (all, target) => {
          const relative = path.posix.normalize(
            path.posix.join(p.directory, target),
          );
          return `](https://github.com/${data.catalog.organization}/SwiftAISDK/blob/main/${relative})`;
        },
      );
      writeFile(
        dir,
        "README.md",
        `<!-- Generated ${publication ? "distribution" : "release candidate"}; edit the canonical repository. -->\n# ${p.id} ${entry.version}\n\nIndependent Swift-native port of Vercel AI SDK. ${publication ? "Source and upstream dispositions are in PROVENANCE.json and Porting/." : "This is a candidate export; it is not evidence that a version is published. Source and upstream dispositions are in PROVENANCE.json and Porting/."}\n\n## Distribution manifest\n\n${publication ? "Add this package to your SwiftPM dependencies:" : "After this version is published:"}\n\n\`\`\`swift\n.package(url: "${p.repository}", from: "${entry.version}")\n\`\`\`\n\nProducts: ${p.modules.map((m) => "`" + m.name + "`").join(", ")}.\nContribute and report issues in the canonical SwiftAISDK repository.\n\n## Authored usage guide\n\n${guide}`,
      );
      writeFile(
        dir,
        "CHANGELOG.md",
        `# Changelog\n\n## ${entry.version}${publication ? "" : " (candidate)"}\n\n${entry.changes.map((c) => `- ${c.notes}\n  Compatibility: ${c.compatibility}`).join("\n")}\n`,
      );
      writeFile(
        dir,
        "PROVENANCE.json",
        json({
          schemaVersion: 1,
          package: p.id,
          version: entry.version,
          releaseID: candidate.id,
          source: { ...candidate.source, inputs: undefined },
          dependencies: p.dependencies,
          changes: entry.changes,
          canonicalDirectory: p.directory,
          upstream,
          note: "Independent port. Imported test refs and contract review gaps retain their original status; export is not new upstream parity proof.",
          canonicalInputs: entry.inputs.map((file) => ({
            canonicalPath: file,
            sha256: hash(fs.readFileSync(path.join(root, file))),
          })),
        }),
      );
      writeFile(
        dir,
        ".github/workflows/package-check.yml",
        fs.readFileSync(path.join(root, ".github/workflows/package-check.yml")),
      );
      writeFile(
        dir,
        ".github/workflows/ci.yml",
        "name: Package CI\non:\n  push:\n    branches: [main]\n  pull_request:\n  workflow_dispatch:\npermissions:\n  contents: read\njobs:\n  package:\n    uses: ./.github/workflows/package-check.yml\n",
      );
      const files = treeFiles(dir);
      exports.push({
        package: p.id,
        version: entry.version,
        dependencies: p.dependencies,
        sha256: hash(json(files)),
        files,
      });
    }
    const bundle = {
      schemaVersion: 1,
      kind: "release-export",
      ...(publication ? { publication: true } : {}),
      plan: candidate,
      exports,
    };
    writeFile(destination, "release-export.json", json(bundle));
    return bundle;
  } catch (error) {
    // Keep no apparently complete tree after a failed export. Destination was
    // exclusively created by this call and did not exist beforehand.
    fs.rmSync(destination, { recursive: true, force: true });
    throw error;
  }
}
function validateExport(directory) {
  const bundle = read(path.join(directory, "release-export.json"));
  ensure(
    bundle.kind === "release-export" && bundle.schemaVersion === 1,
    "Invalid export bundle",
  );
  ensure(
    bundle.exports.length === bundle.plan.packages.length,
    "Incomplete export bundle",
  );
  for (const entry of bundle.exports) {
    ensure(
      /^swift-ai-[a-z0-9-]+$/.test(entry.package),
      "Unsafe export identity",
    );
    ensure(
      bundle.plan.packages.some(
        (p) => p.package === entry.package && p.version === entry.version,
      ),
      "Export is not in plan",
    );
    const files = treeFiles(localPath(directory, entry.package, true));
    ensure(
      json(files) === json(entry.files) && hash(json(files)) === entry.sha256,
      `Export bytes changed: ${entry.package}`,
    );
  }
  return bundle;
}
function atomicJSON(file, value) {
  const temporary = file + ".tmp";
  fs.writeFileSync(temporary, json(value));
  fs.renameSync(temporary, file);
}
function lock(directory) {
  const file = path.join(directory, "attempt.lock");
  if (fs.existsSync(file)) {
    const owner = read(file);
    ensure(
      owner.host === os.hostname() &&
        Number.isInteger(owner.pid) &&
        owner.pid > 0,
      "Unknown attempt lock owner",
    );
    let alive = true;
    try {
      process.kill(owner.pid, 0);
    } catch (e) {
      if (e.code === "ESRCH") alive = false;
      else throw e;
    }
    ensure(!alive, "Publication rehearsal is already running");
    fs.unlinkSync(file);
  }
  const token = crypto.randomUUID();
  fs.writeFileSync(
    file,
    json({ pid: process.pid, host: os.hostname(), token }),
    { flag: "wx" },
  );
  return () => {
    if (fs.existsSync(file) && read(file).token === token) fs.unlinkSync(file);
  };
}
function remoteRefs(remote, cwd, version) {
  return Object.fromEntries(
    git(
      [
        "ls-remote",
        remote,
        "refs/heads/main",
        `refs/tags/${version}`,
        `refs/tags/${version}^{}`,
      ],
      cwd,
    )
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        const [sha, ref] = line.split(/\s+/);
        return [ref, sha];
      }),
  );
}
function committedFiles(repository, commit) {
  return git(["ls-tree", "-r", "--name-only", commit], repository)
    .split("\n")
    .sort()
    .map((file) => {
      const result = spawnSync("git", ["show", `${commit}:${file}`], {
        cwd: repository,
        maxBuffer: 64 * 1024 * 1024,
      });
      ensure(result.status === 0, `Cannot read committed file: ${file}`);
      return { path: file, sha256: hash(result.stdout) };
    });
}
function rehearse(
  directory,
  staging,
  {
    stopAfter = 0,
    crashAfterPush = 0,
    baseline = null,
    onVerifiedPush = null,
  } = {},
) {
  const bundle = validateExport(directory),
    bundleSHA256 = hash(json(bundle));
  const disjoint = (a, b) =>
    a !== b && !a.startsWith(b + path.sep) && !b.startsWith(a + path.sep);
  ensure(
    disjoint(path.resolve(staging), path.resolve(directory)),
    "Rehearsal staging and exports must not overlap",
  );
  if (!fs.existsSync(staging)) fs.mkdirSync(staging, { recursive: true });
  ensure(
    !fs.lstatSync(staging).isSymbolicLink(),
    "Staging cannot be a symlink",
  );
  ensure(
    disjoint(fs.realpathSync(staging), fs.realpathSync(directory)),
    "Rehearsal staging and exports must not overlap through symlinks",
  );
  const marker = path.join(staging, "attempt.json");
  const unlock = lock(staging);
  try {
    if (!fs.existsSync(marker) && fs.existsSync(marker + ".tmp")) {
      const pending = read(marker + ".tmp");
      ensure(
        pending.kind === "local-publication-rehearsal" &&
          pending.bundleSHA256 === bundleSHA256,
        "Unknown unfinished journal",
      );
      fs.renameSync(marker + ".tmp", marker);
    }
    if (!fs.existsSync(marker)) {
      ensure(
        fs.readdirSync(staging).every((f) => f === "attempt.lock"),
        "Staging is not an empty/new rehearsal directory",
      );
      let baselinePackages = [];
      if (baseline) {
        const previous = read(path.join(baseline, "attempt.json"));
        ensure(
          previous.kind === "local-publication-rehearsal" &&
            previous.status === "local-tags-ready",
          "Baseline tags are not ready",
        );
        const byID = new Map(
          [...(previous.baselinePackages || []), ...previous.packages].map(
            (p) => [p.package, p],
          ),
        );
        baselinePackages = [...byID.values()];
        for (const p of baselinePackages) {
          ensure(
            /^swift-ai-[a-z0-9-]+$/.test(p.package),
            "Unsafe baseline identity",
          );
          const remote = localPath(baseline, `remotes/${p.package}.git`, true),
            refs = remoteRefs(remote, baseline, p.version);
          ensure(
            refs[`refs/tags/${p.version}`] === p.tagObject &&
              refs[`refs/tags/${p.version}^{}`] === p.exportCommit &&
              refs["refs/heads/main"] === p.exportCommit,
            `Baseline refs changed: ${p.package}`,
          );
          ensure(
            hash(json(committedFiles(remote, p.exportCommit))) ===
              p.exportSHA256,
            `Baseline payload changed: ${p.package}`,
          );
        }
      }
      // The baseline is recorded before copying repositories, so a failed copy can
      // be retried against the same verified receipts.
      atomicJSON(marker, {
        schemaVersion: 1,
        kind: "local-publication-rehearsal",
        bundleSHA256,
        status: "in-progress",
        baseline: baseline ? path.resolve(baseline) : null,
        baselinePackages,
        packages: [],
      });
    }
    const journal = read(marker);
    ensure(
      journal.kind === "local-publication-rehearsal" &&
        journal.bundleSHA256 === bundleSHA256,
      "Staging belongs to a different export",
    );
    if (baseline)
      ensure(
        path.resolve(baseline) === journal.baseline,
        "Rehearsal baseline changed",
      );
    for (const p of journal.baselinePackages || []) {
      const remote = localPath(staging, `remotes/${p.package}.git`);
      if (!fs.existsSync(remote)) {
        const temporary = remote + ".copying";
        fs.rmSync(temporary, { recursive: true, force: true });
        fs.cpSync(
          localPath(journal.baseline, `remotes/${p.package}.git`, true),
          temporary,
          { recursive: true },
        );
        fs.renameSync(temporary, remote);
      }
      // Dependency tags must remain present even after a selected package adds a
      // newer tag. Branch heads are verified per selected package below.
      const refs = remoteRefs(remote, staging, p.version);
      ensure(
        refs[`refs/tags/${p.version}`] === p.tagObject &&
          refs[`refs/tags/${p.version}^{}`] === p.exportCommit,
        `Baseline tag changed: ${p.package}`,
      );
    }
    let count = 0;
    for (const entry of bundle.exports) {
      for (const dependency of entry.dependencies) {
        ensure(
          [...journal.packages, ...(journal.baselinePackages || [])].some(
            (p) => p.package === dependency.package,
          ),
          `Unverified dependency before ${entry.package}: ${dependency.package}`,
        );
        const remote = localPath(
          staging,
          `remotes/${dependency.package}.git`,
          true,
        );
        const tags = git(["tag", "--list"], remote).split("\n");
        ensure(
          tags.some(
            (v) =>
              /^[0-9]+\.[0-9]+\.[0-9]+$/.test(v) && accepts(dependency.from, v),
          ),
          `No compatible dependency tag for ${entry.package}: ${dependency.package}`,
        );
      }
      const repository = localPath(staging, `repositories/${entry.package}`),
        remote = localPath(staging, `remotes/${entry.package}.git`);
      const previous = (journal.baselinePackages || []).find(
        (p) => p.package === entry.package,
      );
      const candidateFile = localPath(
        staging,
        `candidates/${entry.package}.json`,
      );
      // A crash while constructing a local candidate has not published it yet.
      // Recreate only that owned scratch checkout; a completed candidate is
      // checked against its recorded immutable commit/tag instead.
      if (fs.existsSync(repository) && !fs.existsSync(candidateFile))
        fs.rmSync(repository, { recursive: true, force: true });
      if (!fs.existsSync(repository)) {
        fs.mkdirSync(path.dirname(repository), { recursive: true });
        if (previous) {
          git(["clone", "-q", remote, repository], staging);
          git(["rm", "-r", "--ignore-unmatch", "."], repository);
        }
        fs.cpSync(path.join(directory, entry.package), repository, {
          recursive: true,
        });
        if (!previous) git(["init", "-q", "--initial-branch=main"], repository);
        git(["add", "."], repository);
        git(
          [
            "commit",
            "-q",
            "-m",
            `${entry.package} ${entry.version}\n\nExport-SHA256: ${entry.sha256}`,
          ],
          repository,
        );
        git(
          [
            "tag",
            "-a",
            entry.version,
            "-m",
            `${entry.package} ${entry.version}\nExport-SHA256: ${entry.sha256}`,
          ],
          repository,
        );
        fs.mkdirSync(path.dirname(candidateFile), { recursive: true });
        atomicJSON(candidateFile, {
          exportSHA256: entry.sha256,
          commit: git(["rev-parse", "HEAD"], repository),
          tag: git(["rev-parse", `refs/tags/${entry.version}`], repository),
        });
      }
      ensure(
        !fs.lstatSync(repository).isSymbolicLink(),
        "Repository symlink not allowed",
      );
      const commit = git(["rev-parse", "HEAD"], repository),
        tag = git(["rev-parse", `refs/tags/${entry.version}`], repository);
      ensure(
        json(read(candidateFile)) ===
          json({ exportSHA256: entry.sha256, commit, tag }),
        "Local candidate identity changed",
      );
      ensure(
        git(["cat-file", "-t", tag], repository) === "tag",
        "Release tag must be annotated",
      );
      ensure(
        git(["rev-parse", `${entry.version}^{}`], repository) === commit,
        "Local tag does not target release commit",
      );
      // Verify local commit payload against the exported allowlist, even on a
      // retry. Neither a stale journal nor an existing tag establishes truth.
      ensure(
        json(committedFiles(repository, commit)) === json(entry.files),
        "Release commit bytes differ from export",
      );
      if (!fs.existsSync(remote)) {
        fs.mkdirSync(path.dirname(remote), { recursive: true });
        const temporary = remote + ".initializing";
        fs.rmSync(temporary, { recursive: true, force: true });
        git(
          ["init", "--bare", "-q", "--initial-branch=main", temporary],
          staging,
        );
        fs.renameSync(temporary, remote);
      }
      ensure(
        !fs.lstatSync(remote).isSymbolicLink(),
        "Remote symlink not allowed",
      );
      let refs = remoteRefs(remote, staging, entry.version);
      if (
        Object.keys(refs).length === 0 ||
        (previous &&
          refs["refs/heads/main"] === previous.exportCommit &&
          !refs[`refs/tags/${entry.version}`])
      ) {
        if (previous)
          git(
            ["merge-base", "--is-ancestor", previous.exportCommit, commit],
            repository,
          );
        git(
          [
            "push",
            "--atomic",
            remote,
            `${commit}:refs/heads/main`,
            `refs/tags/${entry.version}:refs/tags/${entry.version}`,
          ],
          repository,
        );
      } else
        ensure(
          refs["refs/heads/main"] === commit &&
            refs[`refs/tags/${entry.version}`] === tag &&
            refs[`refs/tags/${entry.version}^{}`] === commit,
          `Existing release refs differ; refusing to replace ${entry.package}@${entry.version}`,
        );
      refs = remoteRefs(remote, staging, entry.version);
      ensure(
        refs["refs/heads/main"] === commit &&
          refs[`refs/tags/${entry.version}`] === tag &&
          refs[`refs/tags/${entry.version}^{}`] === commit,
        `Publication readback failed: ${entry.package}`,
      );
      count++;
      if (onVerifiedPush) onVerifiedPush(count);
      if (crashAfterPush === count)
        throw new Error(
          `Injected interruption after atomic push, before journal: ${entry.package}`,
        );
      const receipt = {
        package: entry.package,
        version: entry.version,
        exportSHA256: entry.sha256,
        exportCommit: commit,
        tagObject: tag,
        tagCommit: commit,
      };
      const old = journal.packages.find((p) => p.package === entry.package);
      ensure(
        !old || json(old) === json(receipt),
        `Journal/ref mismatch: ${entry.package}`,
      );
      if (!old) journal.packages.push(receipt);
      atomicJSON(marker, journal);
      if (stopAfter === count)
        throw new Error(
          `Injected interruption after verified package: ${entry.package}`,
        );
    }
    journal.status = "local-tags-ready";
    atomicJSON(marker, journal);
    return journal;
  } finally {
    unlock();
  }
}
module.exports = {
  plan,
  exportRelease,
  validateExport,
  rehearse,
  hash,
  treeFiles,
  run,
  git,
  compare,
  accepts,
  versionAfter,
  validatePlan,
  committedFiles,
  atomicJSON,
  lock,
};
