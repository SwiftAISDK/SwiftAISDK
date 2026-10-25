const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const {
  rootDefault: root,
  json,
  readCatalog,
  upstreamEntries,
  topological,
} = require("../lib/catalog.cjs");
const { generate, affected } = require("../lib/generate.cjs");
const read = (r, p) => JSON.parse(fs.readFileSync(path.join(r, p), "utf8"));
function fixture(t) {
  const dir = fs.mkdtempSync(
    path.join(os.tmpdir(), "swiftaisdk-catalog-test-"),
  );
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
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
  ]) {
    fs.cpSync(path.join(root, name), path.join(dir, name), {
      recursive: true,
      filter: (p) =>
        !p
          .split(path.sep)
          .some((x) =>
            [".build", ".swiftpm", "node_modules", "__pycache__"].includes(x),
          ) && !p.includes("/Docs/Migration/M0/"),
    });
  }
  return dir;
}
function edit(r, p, fn) {
  const value = read(r, p);
  fn(value);
  fs.writeFileSync(path.join(r, p), json(value));
}
function run(r, args, options = {}) {
  const result = spawnSync(
    process.execPath,
    [path.join(r, "Scripts/sdk.mjs"), ...args],
    { cwd: r, encoding: "utf8", ...options },
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout;
}

test("all generated outputs match and a repeat generation changes no bytes", () => {
  const result = generate(root, true);
  assert.deepEqual(result.changed, []);
  const again = generate(root, false);
  assert.deepEqual(again.changed, []);
});
test(
  "M1 import preserves reviewed versions, capability rows and notes",
  { skip: process.env.M1_VERIFY_IMPORT !== "1" },
  () => {
    const baseline = read(root, "Docs/Migration/M1/import-baseline.json"),
      data = readCatalog(root);
    assert.deepEqual(data.rows, baseline.capabilities);
    assert.deepEqual(
      data.lock.packages.map((p) => ({
        name: p.name,
        version: p.reviewedVersion,
        kind: p.ledgerKind,
        evidence: p.evidence,
      })),
      baseline.upstream,
    );
  },
);
test("invalid schema fields, duplicate identity, cycles and unsafe paths fail closed", (t) => {
  const r = fixture(t),
    file = "Porting/packages.json",
    original = fs.readFileSync(path.join(r, file));
  const reject = (fn, pattern) => {
    edit(r, file, fn);
    assert.throws(() => readCatalog(r), pattern);
    fs.writeFileSync(path.join(r, file), original);
  };
  reject((c) => {
    c.packages[0].unknownFlag = true;
  }, /unknown field/);
  reject((c) => {
    c.packages.push(c.packages[0]);
  }, /Duplicate package ID/);
  reject((c) => {
    c.packages[0].directory = "../escape";
  }, /Directory\/identity/);
  reject((c) => {
    const p = c.packages[0];
    p.dependencies.push({ package: p.id, from: "1.0.0" });
  }, /Dependency cycle/);
  reject((c) => {
    c.packages[0].modules[0].dependencies.push("swift-ai-core/DoesNotExist");
  }, /Unknown module/);
  reject((c) => {
    c.packages[0].modules[0].testDependencies = ["swift-ai-core/DoesNotExist"];
  }, /Unknown module/);
  reject((c) => {
    c.packages[0].modules[0].testResources = ["../escape"];
  }, /Unsafe catalog path/);
  reject((c) => {
    c.packages.find(p => p.id === "swift-ai-openai").modules[0].testResources = ["MissingFixtures"];
  }, /Missing mapped path/);
});
test("stale output, unmapped input and deleted mappings are detected", (t) => {
  const r = fixture(t);
  fs.appendFileSync(
    path.join(r, "Packages/swift-ai-core/Package.swift"),
    "// drift\n",
  );
  assert.throws(() => generate(r, true), /Generated files differ/);
  generate(r);
  const unknown = path.join(r, "Sources/SwiftAISDK/UnownedM1.swift");
  fs.writeFileSync(unknown, "// new input\n");
  assert.throws(() => readCatalog(r), /Unowned workspace input/);
  fs.unlinkSync(unknown);
  const source = path.join(r, "Packages/swift-ai-core/Sources/SwiftAI/AI.swift");
  fs.renameSync(source, source + ".removed");
  assert.throws(() => readCatalog(r), /Missing mapped path/);
});
test("one registration scaffolds every derived surface without claiming support", (t) => {
  const r = fixture(t),
    before = readCatalog(r),
    name = "@ai-sdk/migration-fixture",
    id = "swift-ai-migration-fixture";
  const output = JSON.parse(
    run(r, [
      "package",
      "add",
      "--upstream",
      name,
      "--module",
      "SwiftAIMigrationFixture",
    ]),
  );
  assert.equal(output.state, "scaffold");
  const data = readCatalog(r);
  assert.equal(
    data.catalog.packages.length,
    before.catalog.packages.length + 1,
  );
  assert.equal(data.lock.packages.length, before.lock.packages.length + 1);
  assert.deepEqual(data.rows, before.rows);
  const entry = data.lock.packages.find((p) => p.name === name);
  assert.equal(entry.reviewedVersion, null);
  assert.equal(entry.reviewStatus, "unreviewed");
  assert(!upstreamEntries(r).some((p) => p.name === name));
  assert(
    fs
      .readFileSync(path.join(r, `Packages/${id}/README.md`), "utf8")
      .includes("NOT IMPLEMENTED"),
  );
  const manifest = fs.readFileSync(
    path.join(r, `Packages/${id}/Package.swift`),
    "utf8",
  );
  assert(manifest.includes("SwiftAIMigrationFixture"));
  assert(manifest.includes("https://github.com/SwiftAISDK/swift-ai-core.git"));
  assert(!manifest.includes(".package(path:"));
  assert(
    read(r, "Porting/Generated/ci-matrix.json").include.some(
      (p) => p.package === id && !p.independentBuildReady,
    ),
  );
  assert(
    read(r, "Porting/Generated/exports.json").packages.some(
      (p) => p.package === id && !p.releaseReady,
    ),
  );
  assert(
    read(r, "Porting/Generated/development-workspace.json").dependencies.some(
      (p) => p.identity === id && p.path === `Packages/${id}`,
    ),
  );
  assert(
    fs
      .readFileSync(path.join(r, "Docs/PackageCatalog.md"), "utf8")
      .includes(id),
  );
  assert.deepEqual(JSON.parse(run(r, ["generate", "--check"])).changed, []);
  assert(!fs.readFileSync(path.join(r, "Package.swift"), "utf8").includes(id));
  assert(!fs.readFileSync(path.join(r, "Sources/SwiftAISDK/ProviderExports.swift"), "utf8").includes("SwiftAIMigrationFixture"));
  edit(r, "Porting/packages.json", (c) => {
    const p = c.packages.find((p) => p.id === id);
    p.capabilityRows = [
      {
        ...data.rows[0],
        order: 999,
        providerID: "migration-fixture",
        upstreamPackage: name,
        factoryNames: ["AIProviders.migrationFixture"],
      },
    ];
  });
  assert.throws(() => readCatalog(r), /advertises capabilities/);
  // Exercise only the workspace-registration transition in this disposable
  // fixture. It remains unreviewed and advertises no upstream implementation.
  edit(r, "Porting/packages.json", c => {
    const p = c.packages.find(p => p.id === id);
    p.capabilityRows = [];
    p.state = "extracted";
  });
  run(r, ["generate"]);
  assert(fs.readFileSync(path.join(r, "Package.swift"), "utf8").includes(`.package(path: "Packages/${id}")`));
  assert(fs.readFileSync(path.join(r, "Sources/SwiftAISDK/ProviderExports.swift"), "utf8").includes("@_exported import SwiftAIMigrationFixture"));
  assert.deepEqual(JSON.parse(run(r, ["generate", "--check"])).changed, []);
});
test("legacy version CLI consumes catalog and preserves output contract without network", (t) => {
  const r = fixture(t),
    bin = path.join(r, "fake-bin");
  fs.mkdirSync(bin);
  fs.writeFileSync(
    path.join(bin, "npm"),
    '#!/usr/bin/env node\nconsole.log("0.0.0");\n',
    { mode: 0o755 },
  );
  const result = spawnSync(
    process.execPath,
    [path.join(r, "Scripts/check-upstream-versions.js"), "--all", "--json"],
    {
      cwd: r,
      encoding: "utf8",
      env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH },
    },
  );
  assert.equal(result.status, 0, result.stderr);
  const rows = JSON.parse(result.stdout),
    expected = upstreamEntries(r);
  assert.equal(rows.length, expected.length);
  for (const p of expected) {
    const row = rows.find((x) => x.name === p.name);
    assert.equal(row.current, p.current);
    assert.equal(row.kind, p.kind);
    assert.equal(row.latest, "0.0.0");
    assert.equal(row.error, null);
    assert(!Object.hasOwn(row, "version"));
  }
  const failed = spawnSync(
    process.execPath,
    [
      path.join(r, "Scripts/check-upstream-versions.js"),
      "--package",
      "ai",
      "--fail-on-outdated",
    ],
    {
      cwd: r,
      encoding: "utf8",
      env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH },
    },
  );
  assert.equal(failed.status, 2);
  fs.writeFileSync(
    path.join(bin, "npm"),
    "#!/usr/bin/env node\nprocess.exit(1);\n",
  );
  const unavailable = spawnSync(
    process.execPath,
    [
      path.join(r, "Scripts/check-upstream-versions.js"),
      "--package",
      "ai",
      "--json",
      "--fail-on-outdated",
    ],
    {
      cwd: r,
      encoding: "utf8",
      env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH },
    },
  );
  assert.equal(unavailable.status, 2);
  assert.equal(JSON.parse(unavailable.stdout)[0].latest, null);
  assert.equal(JSON.parse(unavailable.stdout)[0].error, "npm view failed");
});
test("legacy test-inventory wrapper reads catalog registrations", (t) => {
  const r = fixture(t),
    up = path.join(r, "upstream");
  fs.mkdirSync(path.join(up, "packages/openai/src"), { recursive: true });
  fs.writeFileSync(
    path.join(up, "packages/openai/src/probe.test.ts"),
    "// fixture\n",
  );
  for (const args of [
    ["init", "--quiet"],
    ["add", "."],
    [
      "-c",
      "user.name=Fixture",
      "-c",
      "user.email=fixture@example.invalid",
      "commit",
      "--quiet",
      "-m",
      "fixture",
    ],
  ]) {
    const result = spawnSync("git", args, { cwd: up, encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
  }
  const out = path.join(r, "inventory.md"),
    result = spawnSync(
      process.execPath,
      [
        path.join(r, "Scripts/update-upstream-test-inventory.js"),
        "--no-refresh",
        "--upstream-dir",
        up,
        "--out",
        out,
      ],
      { cwd: r, encoding: "utf8" },
    );
  assert.equal(result.status, 0, result.stderr);
  const text = fs.readFileSync(out, "utf8");
  assert(text.includes("packages/openai/src/probe.test.ts"));
  assert(
    text.includes(
      upstreamEntries(r).find((p) => p.name === "@ai-sdk/openai").version,
    ),
  );
});
test("dependency selection widens uncertain mappings and includes downstream users", () => {
  const data = readCatalog(root),
    selection = affected(data, [
      "Sources/SwiftAISDK/Models/OpenAIResponsesModel.swift",
    ]);
  assert.equal(selection.packages.length, data.catalog.packages.length);
  assert(selection.reason[0].includes("coarse"));
  assert.equal(selection.execution, "selection-only");
  const order = topological(
    ["consumer", "core", "provider"],
    (id) => ({ consumer: ["provider"], provider: ["core"], core: [] })[id],
  );
  assert(order.indexOf("core") < order.indexOf("provider"));
  assert(order.indexOf("provider") < order.indexOf("consumer"));
});

test("compatibility facade follows new core signatures and rejects unsupported public surface", (t) => {
  const r = fixture(t);
  const file = path.join(r, "Packages/swift-ai-core/Sources/SwiftAI/AI.swift");
  fs.appendFileSync(file, "\nextension AI { public static func migrationSentinel(value: Int = 7) async throws -> Int { value } }\n");
  generate(r);
  const compatibility = fs.readFileSync(path.join(r, "Sources/SwiftAISDK/Compatibility.swift"), "utf8");
  assert.match(compatibility, /migrationSentinel\(value: Int = 7\) async throws -> Int/);
  assert.match(compatibility, /try await SwiftAI\.AI\.migrationSentinel\(value: value\)/);
  fs.appendFileSync(file, "\nextension AI { public static var unsupportedMigrationProperty: Int { 1 } }\n");
  assert.throws(() => generate(r), /Unsupported public compatibility declaration|Command failed/);
});
