const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { rootDefault: root, json } = require("../lib/catalog.cjs");
const release = require("../lib/release.cjs");
const { seedPilot } = require("../lib/release-fixture.cjs");
function fixture(t) {
  const parent = fs.mkdtempSync(
    path.join(os.tmpdir(), "swift-ai-release-test-"),
  );
  const dir = path.join(parent, "canonical");
  fs.mkdirSync(dir);
  t.after(() => fs.rmSync(parent, { recursive: true, force: true }));
  for (const name of [
    "Scripts",
    "Porting",
    "Packages",
    "Sources",
    "Tests",
    "Examples",
    "Docs",
    "docs-site/scripts",
    "Package.swift",
    "LICENSE",
    "Releases",
    ".github",
    ".gitignore",
  ])
    fs.cpSync(path.join(root, name), path.join(dir, name), {
      recursive: true,
      filter: (p) =>
        !p
          .split(path.sep)
          .some((x) =>
            [
              ".build",
              ".swiftpm",
              "node_modules",
              "__pycache__",
              "M0",
            ].includes(x),
          ),
    });
  seedPilot(dir);
  release.git(["init", "-q", "--initial-branch=main"], dir);
  release.git(["add", "."], dir);
  release.git(["commit", "-q", "-m", "Disposable canonical snapshot"], dir);
  return { dir, parent };
}
const read = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
function write(root, p, v) {
  fs.writeFileSync(path.join(root, p), json(v));
}
function publishedSnapshot(dir, candidate) {
  write(dir, "Releases/sets/first.json", {
    schemaVersion: 1,
    id: "first",
    status: "published",
    sourceCommit: "a".repeat(40),
    changeIDs: candidate.changeIDs,
    packages: candidate.packages.map((p) => ({
      package: p.package,
      version: p.version,
      dependencies: p.dependencies,
      sourceCommit: "a".repeat(40),
      exportSHA256: "b".repeat(64),
      exportCommit: "c".repeat(40),
      tagObject: "d".repeat(40),
    })),
    consumerVerificationSHA256: "e".repeat(64),
  });
}
test("release plan separates initial Swift versions, provenance and dependent verification", (t) => {
  const { dir } = fixture(t),
    p = release.plan(dir);
  assert.equal(p.source.workingTree, false);
  assert.match(p.source.commit, /^[a-f0-9]{40}$/);
  assert.deepEqual(
    p.packages.map((p) => p.package),
    [
      "swift-ai-core",
      "swift-ai-anthropic",
      "swift-ai-openai-compatible",
      "swift-ai-openai",
    ],
  );
  assert(p.packages.every((p) => p.version === "1.0.0"));
  assert.equal(p.publicationReady, false);
  publishedSnapshot(dir, p);
  write(dir, "Releases/changes/core-patch.json", {
    schemaVersion: 1,
    id: "core-patch",
    status: "reviewed",
    summary: "Fixture core fix",
    packages: [
      {
        package: "swift-ai-core",
        bump: "patch",
        notes: "Fixture correction",
        compatibility: "No API or minimum requirement change",
      },
    ],
  });
  const next = release.plan(dir, "core-patch");
  assert.deepEqual(
    next.packages.map((p) => [p.package, p.version]),
    [["swift-ai-core", "1.0.1"]],
  );
  assert.equal(next.verificationPackages.length, 4);
  const catalog = read(path.join(dir, "Porting/packages.json"));
  catalog.packages.find(
    (p) => p.id === "swift-ai-openai",
  ).dependencies[0].from = "1.0.1";
  write(dir, "Porting/packages.json", catalog);
  assert.throws(
    () => release.plan(dir),
    /dependency requirements need a release entry/,
  );
});
test("drafts do not release; invalid changes and unavailable dependencies fail", (t) => {
  const { dir } = fixture(t),
    file = "Releases/changes/modular-pilot.json",
    original = read(path.join(dir, file));
  write(dir, file, { ...original, status: "draft" });
  assert.equal(release.plan(dir).packages.length, 0);
  write(dir, file, {
    ...original,
    packages: [{ ...original.packages[0], package: "swift-ai-google" }],
  });
  assert.throws(() => release.plan(dir), /unextracted/);
  write(dir, file, { ...original, packages: [original.packages[1]] });
  assert.throws(() => release.plan(dir), /Unavailable compatible dependency/);
  write(dir, file, {
    ...original,
    packages: [original.packages[0], original.packages[0]],
  });
  assert.throws(() => release.plan(dir), /Duplicate change package/);
  write(dir, file, { ...original, unexpected: true });
  assert.throws(() => release.plan(dir), /unknown field/);
  assert.equal(release.versionAfter("1.3.5", "minor"), "1.4.0");
  assert.equal(release.versionAfter("1.3.5", "major"), "2.0.0");
});
test("allowlisted exports are deterministic, portable and retain source/test/provenance bytes", (t) => {
  const { dir, parent } = fixture(t);
  fs.writeFileSync(path.join(dir, "unrelated-private.txt"), "never export");
  const candidate = release.plan(dir),
    a = path.join(parent, "export-a"),
    b = path.join(parent, "export-b");
  const aa = release.exportRelease(dir, candidate, a),
    bb = release.exportRelease(dir, candidate, b);
  assert.deepEqual(aa, bb);
  for (const p of aa.exports) {
    assert(
      !p.files.some(
        (f) =>
          f.path.includes("unrelated-private") ||
          f.path.startsWith(".swiftpm/"),
      ),
    );
    const manifest = fs.readFileSync(
      path.join(a, p.package, "Package.swift"),
      "utf8",
    );
    assert(!manifest.includes(".package(path:"));
    for (const f of p.files.filter((f) => /^(Sources|Tests)\//.test(f.path)))
      assert.deepEqual(
        fs.readFileSync(path.join(a, p.package, f.path)),
        fs.readFileSync(path.join(dir, "Packages", p.package, f.path)),
      );
    assert.deepEqual(
      fs.readFileSync(
        path.join(a, p.package, ".github/workflows/package-check.yml"),
      ),
      fs.readFileSync(path.join(dir, ".github/workflows/package-check.yml")),
    );
    const provenance = read(path.join(a, p.package, "PROVENANCE.json"));
    assert.equal(provenance.source.commit, null);
    assert.equal(provenance.source.workingTree, true);
    assert(
      provenance.upstream.every(
        (u) =>
          u.testRefRelationship === "inventory-snapshot-not-release-verified",
      ),
    );
  }
  assert(
    aa.exports
      .find((p) => p.package === "swift-ai-openai")
      .files.some((f) => f.path.includes("Fixtures/OpenAIResponses/")),
  );
  release.validateExport(a);
  fs.appendFileSync(
    path.join(a, "swift-ai-core", "Package.swift"),
    "// tamper\n",
  );
  assert.throws(() => release.validateExport(a), /Export bytes changed/);
  fs.appendFileSync(
    path.join(dir, "Packages/swift-ai-core/Sources/SwiftAI/AI.swift"),
    "\n// changed input\n",
  );
  assert.throws(
    () => release.exportRelease(dir, candidate, path.join(parent, "stale")),
    /plan is stale/,
  );
});
test("interrupted local publication resumes from verified annotated refs without replacing them", (t) => {
  const { dir, parent } = fixture(t),
    candidate = release.plan(dir),
    exported = path.join(parent, "exports"),
    stage = path.join(parent, "attempt");
  release.exportRelease(dir, candidate, exported);
  assert.throws(
    () => release.rehearse(exported, stage, { crashAfterPush: 1 }),
    /before journal/,
  );
  assert.equal(read(path.join(stage, "attempt.json")).packages.length, 0);
  assert(!fs.existsSync(path.join(stage, "remotes/swift-ai-anthropic.git")));
  const remote = path.join(stage, "remotes/swift-ai-core.git");
  const tag = release.git(["rev-parse", "refs/tags/1.0.0"], remote);
  const result = release.rehearse(exported, stage);
  assert.equal(result.packages.length, 4);
  assert.equal(release.git(["rev-parse", "refs/tags/1.0.0"], remote), tag);
  assert.deepEqual(release.rehearse(exported, stage), result);
  assert.equal(release.git(["cat-file", "-t", tag], remote), "tag");
});
test("a conflicting published tag stops dependents and is never moved by a retry", (t) => {
  const { dir, parent } = fixture(t),
    candidate = release.plan(dir),
    exported = path.join(parent, "exports"),
    stage = path.join(parent, "attempt");
  release.exportRelease(dir, candidate, exported);
  assert.throws(
    () => release.rehearse(exported, stage, { stopAfter: 1 }),
    /verified package/,
  );
  const remote = path.join(stage, "remotes/swift-ai-core.git"),
    commit = release.git(["rev-parse", "refs/heads/main"], remote);
  release.git(["update-ref", "refs/tags/1.0.0", commit], remote);
  assert.throws(() => release.rehearse(exported, stage), /refusing to replace/);
  assert.equal(release.git(["rev-parse", "refs/tags/1.0.0"], remote), commit);
  assert(!fs.existsSync(path.join(stage, "remotes/swift-ai-anthropic.git")));
});
test("a provider-only patch reuses verified dependency tags and preserves old published tags", (t) => {
  const { dir, parent } = fixture(t),
    first = release.plan(dir),
    a = path.join(parent, "first-export"),
    stage = path.join(parent, "first-attempt");
  release.exportRelease(dir, first, a);
  const firstRefs = release.rehearse(a, stage);
  publishedSnapshot(dir, first);
  write(dir, "Releases/changes/openai-patch.json", {
    schemaVersion: 1,
    id: "openai-patch",
    status: "reviewed",
    summary: "Fixture provider-only patch",
    packages: [
      {
        package: "swift-ai-openai",
        bump: "patch",
        notes: "Fixture metadata change",
        compatibility: "No core or compatible API changes",
      },
    ],
  });
  const next = release.plan(dir, "openai-patch"),
    b = path.join(parent, "second-export"),
    nextStage = path.join(parent, "second-attempt");
  assert.deepEqual(
    next.packages.map((p) => p.package),
    ["swift-ai-openai"],
  );
  release.exportRelease(dir, next, b);
  const second = release.rehearse(b, nextStage, { baseline: stage });
  assert.equal(second.packages.length, 1);
  assert.equal(second.packages[0].version, "1.0.1");
  for (const p of firstRefs.packages) {
    const remote = path.join(nextStage, "remotes", p.package + ".git");
    assert.equal(
      release.git(["rev-parse", "refs/tags/1.0.0"], remote),
      p.tagObject,
    );
    if (p.package !== "swift-ai-openai")
      assert.equal(
        release.git(["rev-parse", "refs/heads/main"], remote),
        p.exportCommit,
      );
  }
  assert.deepEqual(release.rehearse(b, nextStage), second);
});
test("SIGKILL after push leaves a recoverable journal gap and stale process lock", (t) => {
  const { spawnSync } = require("node:child_process");
  const { dir, parent } = fixture(t),
    candidate = release.plan(dir),
    exported = path.join(parent, "exports"),
    stage = path.join(parent, "attempt");
  release.exportRelease(dir, candidate, exported);
  const child = spawnSync(
    process.execPath,
    [
      "-e",
      'require(process.argv[1]).rehearse(process.argv[2],process.argv[3],{onVerifiedPush:()=>process.kill(process.pid,"SIGKILL")})',
      require.resolve("../lib/release.cjs"),
      exported,
      stage,
    ],
    { encoding: "utf8" },
  );
  assert.equal(child.signal, "SIGKILL");
  assert(fs.existsSync(path.join(stage, "attempt.lock")));
  const remote = path.join(stage, "remotes/swift-ai-core.git"),
    before = release.git(["rev-parse", "refs/tags/1.0.0"], remote);
  assert.equal(read(path.join(stage, "attempt.json")).packages.length, 0);
  assert.equal(release.rehearse(exported, stage).packages.length, 4);
  assert.equal(release.git(["rev-parse", "refs/tags/1.0.0"], remote), before);
  assert(!fs.existsSync(path.join(stage, "attempt.lock")));
});
test("committed release-set records are append-only and cannot be reused as a candidate id", (t) => {
  const { dir } = fixture(t),
    candidate = release.plan(dir);
  publishedSnapshot(dir, candidate);
  release.git(["add", "Releases/sets/first.json"], dir);
  release.git(
    ["commit", "-q", "-m", "Disposable completed release record"],
    dir,
  );
  assert.throws(() => release.plan(dir, "first"), /already belongs/);
  const file = path.join(dir, "Releases/sets/first.json"),
    record = read(file);
  record.consumerVerificationSHA256 = "f".repeat(64);
  fs.writeFileSync(file, json(record));
  assert.throws(() => release.plan(dir, "second"), /modified or deleted/);
  fs.unlinkSync(file);
  assert.throws(() => release.plan(dir, "second"), /modified or deleted/);
});


test("production publication requires exact CI and resumes after a pushed tag without replacing refs", (t) => {
  const { publish } = require("../lib/publish.cjs");
  const { dir, parent } = fixture(t);
  const candidate = release.plan(dir);
  const output = path.join(parent, "production-export");
  const bundle = release.exportRelease(dir, candidate, output, { publication: true });
  assert.equal(bundle.publication, true);
  assert(!fs.readFileSync(path.join(output, "swift-ai-core", "README.md"), "utf8").includes("This is a candidate export"));
  const remotes = new Map();
  for (const p of candidate.packages) {
    const remote = path.join(parent, p.package + ".git");
    release.git(["init", "--bare", "-q", "--initial-branch=main", remote], dir);
    remotes.set(p.package, remote);
  }
  const published = new Map();
  let ciPass = false;
  const backend = {
    verifyCI(commit) { assert(ciPass, "exact CI required"); return { sourceCommit: commit, id: 1 }; },
    remote(p) { return { url: remotes.get(p.package), name: p.package, id: p.package }; },
    release(destination, receipt, notes) {
      const prior = published.get(destination.name);
      if (prior) assert.equal(prior.notes, notes);
      published.set(destination.name, { receipt, notes });
      return { id: destination.id, target: receipt.exportCommit };
    },
  };
  const staging = path.join(parent, "production-attempt");
  assert.throws(() => publish(dir, output, staging, { backend }), /exact CI required/);
  assert.equal(release.git(["tag", "--list"], remotes.get("swift-ai-core")), "");
  ciPass = true;
  assert.throws(() => publish(dir, output, staging, { backend, afterPush: () => { throw Error("crash gap"); } }), /crash gap/);
  const firstTag = release.git(["rev-parse", "1.0.0"], remotes.get("swift-ai-core"));
  assert.equal(published.size, 0);
  const result = publish(dir, output, staging, { backend });
  assert.equal(result.status, "tags-and-releases-ready");
  assert.equal(result.packages.length, 4);
  assert.equal(release.git(["rev-parse", "1.0.0"], remotes.get("swift-ai-core")), firstTag);
  assert.deepEqual(publish(dir, output, staging, { backend }), result);
  const source = path.join(output, "swift-ai-core", "README.md");
  fs.appendFileSync(source, "tamper");
  assert.throws(() => publish(dir, output, staging, { backend }), /Export bytes changed/);
});

test("production rejects dirty source and conflicting public tags before dependents", (t) => {
  const { publish } = require("../lib/publish.cjs");
  const { dir, parent } = fixture(t);
  fs.appendFileSync(path.join(dir, "LICENSE"), "\n");
  assert.throws(() => release.exportRelease(dir, release.plan(dir), path.join(parent, "dirty"), { publication: true }), /committed clean source/);
  release.git(["checkout", "--", "LICENSE"], dir);
  const output = path.join(parent, "export");
  release.exportRelease(dir, release.plan(dir), output, { publication: true });
  const remote = path.join(parent, "conflict.git");
  release.git(["clone", "--bare", "-q", dir, remote], parent);
  release.git(["tag", "-a", "1.0.0", "-m", "conflicting tag"], remote);
  const tag = release.git(["rev-parse", "1.0.0"], remote);
  let writes = 0;
  assert.throws(() => publish(dir, output, path.join(parent, "attempt"), { backend: {
    verifyCI: () => ({ id: 1 }), remote: (p) => ({ name: p.package, url: remote }),
    release: () => { writes++; },
  } }), /Unrecorded existing destination refs/);
  assert.equal(writes, 0);
  assert.equal(release.git(["rev-parse", "1.0.0"], remote), tag);
});


test("rehearsal fixtures remain usable after production changes are consumed", (t) => {
  assert.throws(() => seedPilot(root), /canonical checkout/);
  const { dir } = fixture(t), candidate = release.plan(dir);
  publishedSnapshot(dir, candidate);
  assert.equal(release.plan(dir, "after-publication").packages.length, 0);
  seedPilot(dir);
  assert.equal(release.plan(dir, "isolated-rehearsal").packages.length, 4);
});
