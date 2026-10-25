#!/usr/bin/env node
// Real exported Git tags and clean clients; all remotes are disposable local bare
// repositories. SwiftPM mirrors preserve distribution manifests byte-for-byte.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";
import catalog from "./lib/catalog.cjs";
import release from "./lib/release.cjs";
const { rootDefault: root, json, ensure } = catalog;
const args = process.argv.slice(2);
ensure(
  args.length === 0 || (args.length === 2 && args[0] === "--report"),
  "Usage: verify-release-rehearsal.mjs [--report output.json]",
);
const output = args.length ? path.resolve(args[1]) : null;
if (output)
  ensure(
    !fs.existsSync(output),
    "Report already exists; choose a new report path",
  );
const logDirectory = output ? output.replace(/\.json$/, "") + ".logs" : null;
if (logDirectory) {
  ensure(
    !fs.existsSync(logDirectory),
    "Report logs already exist; choose a new report path",
  );
  fs.mkdirSync(logDirectory, { recursive: true });
}
const temp = fs.mkdtempSync(
  path.join(os.tmpdir(), "swift-ai-export-rehearsal-"),
);
const canonical = path.join(temp, "canonical");
const checks = [];
function command(cmd, argv, cwd, name) {
  const r = spawnSync(cmd, argv, {
    cwd,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (r.error) throw r.error;
  const log = (r.stdout || "") + (r.stderr || "");
  const logFile = logDirectory
    ? path.join(
        logDirectory,
        `${String(checks.length + 1).padStart(3, "0")}-${name.replace(/[^a-zA-Z0-9-]/g, "-")}.log`,
      )
    : null;
  if (logFile) fs.writeFileSync(logFile, log);
  ensure(
    r.status === 0,
    `${name}: ${cmd} ${argv.join(" ")} failed (${r.status})\n${log}`,
  );
  checks.push({
    name,
    command: [cmd, ...argv],
    exitCode: r.status,
    logSHA256: release.hash(log),
    log: logFile,
    summaries: log
      .split("\n")
      .filter((l) =>
        /Test run with|Build complete|_OK|CONSUMER VERIFIED/.test(l),
      ),
  });
  return r.stdout;
}
function mirror(cwd, stage, data) {
  for (const p of data.catalog.packages.filter((p) => p.state === "extracted"))
    command(
      "swift",
      [
        "package",
        "config",
        "set-mirror",
        "--original",
        p.repository,
        "--mirror",
        pathToFileURL(path.join(stage, "remotes", p.id + ".git")).href,
      ],
      cwd,
      "mirror " + p.id,
    );
}
function copyClient(name, to) {
  const from = path.join(canonical, "Examples", name);
  fs.mkdirSync(to, { recursive: true });
  fs.copyFileSync(
    path.join(from, "Package.swift"),
    path.join(to, "Package.swift"),
  );
  fs.cpSync(path.join(from, "Sources"), path.join(to, "Sources"), {
    recursive: true,
  });
}
function consumer(name, stage, data, receipts, label) {
  const cwd = path.join(temp, "consumers", label || name);
  copyClient(name, cwd);
  const file = path.join(cwd, "Package.swift");
  let manifest = fs.readFileSync(file, "utf8");
  for (const p of data.catalog.packages.filter(
    (p) => p.state === "extracted",
  )) {
    const r = receipts.find((r) => r.package === p.id);
    ensure(r, "Missing candidate receipt " + p.id);
    manifest = manifest.replaceAll(
      `.package(path: "../../Packages/${p.id}")`,
      `.package(url: "${p.repository}", exact: "${r.version}")`,
    );
  }
  ensure(
    !manifest.includes(".package(path:"),
    "Client has a local workspace dependency",
  );
  fs.writeFileSync(file, manifest);
  mirror(cwd, stage, data);
  const product = name === "CoreOnly" ? "CoreConsumer" : "ProviderConsumer";
  const result = command(
    "swift",
    ["run", product],
    cwd,
    "consumer " + (label || name),
  );
  ensure(
    result.includes(
      name === "CoreOnly"
        ? "CORE CONSUMER VERIFIED"
        : name.toUpperCase() + "_OK",
    ),
    "Consumer did not verify behavior",
  );
  const lock = JSON.parse(
    fs.readFileSync(path.join(cwd, "Package.resolved"), "utf8"),
  );
  const expected = {
    CoreOnly: ["swift-ai-core"],
    AnthropicOnly: ["swift-ai-core", "swift-ai-anthropic"],
    OpenAICompatibleOnly: ["swift-ai-core", "swift-ai-openai-compatible"],
    OpenAIOnly: [
      "swift-ai-core",
      "swift-ai-openai-compatible",
      "swift-ai-openai",
    ],
    MixedProviders: [
      "swift-ai-core",
      "swift-ai-anthropic",
      "swift-ai-openai-compatible",
      "swift-ai-openai",
    ],
  }[name];
  ensure(
    JSON.stringify(lock.pins.map((p) => p.identity).sort()) ===
      JSON.stringify(expected.sort()),
    "Wrong consumer package closure",
  );
  for (const pin of lock.pins) {
    const r = receipts.find((r) => r.package === pin.identity);
    ensure(
      pin.state.version === r.version && pin.state.revision === r.exportCommit,
      "Resolved a different version/commit: " + pin.identity,
    );
  }
  console.log("EXPORTED CONSUMER VERIFIED: " + (label || name));
  return { name: label || name, manifest, lockfile: lock };
}
function history(candidate, journal, id) {
  return {
    schemaVersion: 1,
    id,
    status: "published",
    sourceCommit: candidate.source.commit,
    changeIDs: candidate.changeIDs,
    packages: journal.packages.map((r) => ({
      package: r.package,
      version: r.version,
      sourceCommit: candidate.source.commit,
      exportSHA256: r.exportSHA256,
      exportCommit: r.exportCommit,
      tagObject: r.tagObject,
      dependencies: candidate.packages.find((p) => p.package === r.package)
        .dependencies,
    })),
    consumerVerificationSHA256: release.hash(json(checks)),
  };
}
try {
  fs.mkdirSync(canonical);
  const listed = spawnSync(
    "git",
    ["ls-files", "--cached", "--others", "--exclude-standard", "-z"],
    { cwd: root, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
  );
  ensure(listed.status === 0, "Cannot inventory canonical inputs");
  for (const relative of [
    ...new Set(listed.stdout.split("\0").filter(Boolean)),
  ]) {
    if (
      relative
        .split("/")
        .some(
          (s) =>
            [
              ".build",
              ".swiftpm",
              "node_modules",
              "dist",
              ".DS_Store",
            ].includes(s) || s.startsWith("._"),
        )
    )
      continue;
    const file = path.join(root, relative);
    if (!fs.existsSync(file)) continue;
    ensure(
      fs.lstatSync(file).isFile(),
      "Unexpected non-file in canonical snapshot: " + relative,
    );
    const to = path.join(canonical, relative);
    fs.mkdirSync(path.dirname(to), { recursive: true });
    fs.copyFileSync(file, to);
  }
  release.git(["init", "-q", "--initial-branch=main"], canonical);
  release.git(["add", "."], canonical);
  release.git(
    ["commit", "-q", "-m", "M4 disposable canonical working-tree snapshot"],
    canonical,
  );
  const data = catalog.readCatalog(canonical),
    candidate = release.plan(canonical, "m4-pilot-rehearsal");
  ensure(
    candidate.source.commit && !candidate.source.workingTree,
    "Snapshot must be committed",
  );
  const first = path.join(temp, "export-a"),
    second = path.join(temp, "export-b");
  const a = release.exportRelease(canonical, candidate, first),
    b = release.exportRelease(canonical, candidate, second);
  ensure(json(a) === json(b), "Repeated exports are not deterministic");
  console.log(
    "DETERMINISTIC EXPORT VERIFIED: " + a.exports.length + " packages",
  );
  const stage = path.join(temp, "initial-attempt");
  let interrupted = false;
  try {
    release.rehearse(first, stage, { crashAfterPush: 1 });
  } catch (e) {
    if (!e.message.includes("before journal")) throw e;
    interrupted = true;
  }
  ensure(interrupted, "Interruption was not exercised");
  const coreRemote = path.join(stage, "remotes/swift-ai-core.git");
  const coreTagBefore = release.git(
    ["rev-parse", "refs/tags/1.0.0"],
    coreRemote,
  );
  const initial = release.rehearse(first, stage);
  ensure(
    release.git(["rev-parse", "refs/tags/1.0.0"], coreRemote) === coreTagBefore,
    "Resume replaced the published tag",
  );
  ensure(
    json(release.rehearse(first, stage)) === json(initial),
    "Repeated completed attempt changed state",
  );
  console.log(
    "INTERRUPTION/RESUME VERIFIED: remote refs recovered before journal update",
  );
  for (const entry of a.exports) {
    const cwd = path.join(temp, "package-checks", entry.package);
    fs.mkdirSync(path.dirname(cwd), { recursive: true });
    release.git(
      [
        "clone",
        "-q",
        "--branch",
        entry.version,
        path.join(stage, "remotes", entry.package + ".git"),
        cwd,
      ],
      temp,
    );
    const before = release.hash(
      fs.readFileSync(path.join(cwd, "Package.swift")),
    );
    mirror(cwd, stage, data);
    command(
      "swift",
      ["test", "--no-parallel"],
      cwd,
      "exported tests " + entry.package,
    );
    ensure(
      before === release.hash(fs.readFileSync(path.join(cwd, "Package.swift"))),
      "A mirror altered the export manifest",
    );
    console.log("EXPORTED TESTS VERIFIED: " + entry.package);
  }
  const clients = [];
  for (const name of [
    "CoreOnly",
    "AnthropicOnly",
    "OpenAICompatibleOnly",
    "OpenAIOnly",
    "MixedProviders",
  ])
    clients.push(consumer(name, stage, data, initial.packages));
  const initialSet = history(candidate, initial, "m4-fixture-initial");
  fs.writeFileSync(
    path.join(canonical, "Releases/sets/m4-fixture-initial.json"),
    json(initialSet),
  );
  fs.writeFileSync(
    path.join(canonical, "Releases/changes/m4-fixture-openai-patch.json"),
    json({
      schemaVersion: 1,
      id: "m4-fixture-openai-patch",
      status: "reviewed",
      summary: "Disposable provider-only metadata patch",
      packages: [
        {
          package: "swift-ai-openai",
          bump: "patch",
          notes: "Fixture documentation change for independent release proof.",
          compatibility: "No runtime API or dependency requirement changes.",
        },
      ],
    }),
  );
  fs.appendFileSync(
    path.join(canonical, "Packages/swift-ai-openai/README.md"),
    "\nDisposable M4 patch fixture; no runtime behavior changed.\n",
  );
  release.git(["add", "."], canonical);
  release.git(
    ["commit", "-q", "-m", "M4 disposable provider-only patch"],
    canonical,
  );
  const patch = release.plan(canonical, "m4-provider-patch");
  ensure(
    patch.packages.length === 1 &&
      patch.packages[0].package === "swift-ai-openai" &&
      patch.packages[0].version === "1.0.1",
    "Unchanged providers were selected for release",
  );
  const patchDir = path.join(temp, "patch-export");
  const patchBundle = release.exportRelease(canonical, patch, patchDir);
  const nextStage = path.join(temp, "patch-attempt");
  const next = release.rehearse(patchDir, nextStage, { baseline: stage });
  const merged = [
    ...initial.packages.filter((p) => p.package !== "swift-ai-openai"),
    ...next.packages,
  ];
  for (const p of initial.packages) {
    const remote = path.join(nextStage, "remotes", p.package + ".git");
    ensure(
      release.git(["rev-parse", `refs/tags/${p.version}`], remote) ===
        p.tagObject,
      "Provider-only release replaced an old tag",
    );
    if (p.package !== "swift-ai-openai")
      ensure(
        release.git(["rev-parse", "refs/heads/main"], remote) ===
          p.exportCommit,
        "Unchanged dependency was republished",
      );
  }
  clients.push(
    consumer(
      "MixedProviders",
      nextStage,
      data,
      merged,
      "MixedProvidersOpenAIPatch",
    ),
  );
  release.rehearse(patchDir, nextStage);
  console.log(
    "PROVIDER-ONLY RELEASE VERIFIED: OpenAI 1.0.1; Anthropic/core/compatible remain 1.0.0",
  );
  const report = {
    schemaVersion: 1,
    kind: "release-rehearsal-verification",
    status: "complete",
    originalBaseCommit: release.git(["rev-parse", "HEAD"], root),
    canonicalSnapshotCommit: candidate.source.commit,
    canonicalInputsSHA256: candidate.source.inputsSHA256,
    initial: {
      candidateVersions: a.exports.map(
        ({ package: p, version, sha256, files }) => ({
          package: p,
          version,
          exportSHA256: sha256,
          fileCount: files.length,
        }),
      ),
      refs: initial.packages,
    },
    providerOnlyPatch: {
      versions: patchBundle.exports.map(({ package: p, version, sha256 }) => ({
        package: p,
        version,
        exportSHA256: sha256,
      })),
      refs: next.packages,
    },
    checks,
    clients,
    publication: {
      performed: false,
      scope:
        "Disposable local Git remotes only; canonical source remains unchanged. Snapshot commits are rehearsal evidence, not commits in the canonical repository.",
    },
  };
  if (output) {
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.writeFileSync(output, json(report));
  }
  console.log(
    "M4 RELEASE REHEARSAL VERIFIED: deterministic export, standalone tests/clients, immutable tags, resumable publication and independent patch",
  );
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
