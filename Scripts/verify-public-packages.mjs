#!/usr/bin/env node
// Clean consumers using actual public Git tags, without mirrors or local paths.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import catalog from "./lib/catalog.cjs";
import release from "./lib/release.cjs";
const { rootDefault: root, ensure, json } = catalog;
const [attempt, output] = process.argv.slice(2);
ensure(attempt && output && !fs.existsSync(output), "Usage: verify-public-packages.mjs attempt.json new-report.json");
const journal = JSON.parse(fs.readFileSync(attempt, "utf8"));
ensure(journal.kind === "github-publication" && journal.status === "tags-and-releases-ready", "Public refs must be ready");
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "swift-ai-public-consumers-"));
const logDirectory = path.resolve(output).replace(/\.json$/, "") + ".logs";
ensure(!fs.existsSync(logDirectory), "Report logs already exist");
fs.mkdirSync(logDirectory, { recursive: true });
const checks = [], consumers = [];
function command(cmd, argv, cwd, name) {
  const result = spawnSync(cmd, argv, { cwd, encoding: "utf8", maxBuffer: 64 * 1024 * 1024,
    env: { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1", GIT_TERMINAL_PROMPT: "0" } });
  const log = (result.stdout || "") + (result.stderr || "");
  fs.writeFileSync(path.join(logDirectory, name + ".log"), log);
  ensure(!result.error && result.status === 0, `${name} failed: ${log.slice(-8000)}`);
  checks.push({ name, command: [cmd, ...argv], exitCode: result.status, logSHA256: release.hash(log),
    summaries: log.split("\n").filter((s) => /_OK|CONSUMER VERIFIED|Build complete/.test(s)) });
  return result.stdout;
}
try {
  const swiftVersion = command("swift", ["--version"], temp, "swift-version").trim();
  const expected = {
    CoreOnly: ["swift-ai-core"],
    AnthropicOnly: ["swift-ai-core", "swift-ai-anthropic"],
    OpenAICompatibleOnly: ["swift-ai-core", "swift-ai-openai-compatible"],
    OpenAIOnly: ["swift-ai-core", "swift-ai-openai-compatible", "swift-ai-openai"],
    MixedProviders: ["swift-ai-core", "swift-ai-anthropic", "swift-ai-openai-compatible", "swift-ai-openai"],
  };
  for (const [name, closure] of Object.entries(expected)) {
    const cwd = path.join(temp, name);
    fs.mkdirSync(cwd);
    fs.cpSync(path.join(root, "Examples", name, "Sources"), path.join(cwd, "Sources"), { recursive: true });
    let manifest = fs.readFileSync(path.join(root, "Examples", name, "Package.swift"), "utf8");
    for (const p of journal.packages) {
      ensure(p.repository.name === "SwiftAISDK/" + p.package, "Unexpected public repository");
      manifest = manifest.replaceAll(`.package(path: "../../Packages/${p.package}")`,
        `.package(url: "https://github.com/${p.repository.name}.git", exact: "${p.version}")`);
    }
    ensure(!manifest.includes(".package(path:"), "Local dependency in consumer");
    fs.writeFileSync(path.join(cwd, "Package.swift"), manifest);
    const result = command("swift", ["run", "--disable-dependency-cache", "--config-path", path.join(cwd, "config"),
      "--cache-path", path.join(cwd, "cache"), "--security-path", path.join(cwd, "security"),
      name === "CoreOnly" ? "CoreConsumer" : "ProviderConsumer"], cwd, name);
    ensure(result.includes(name === "CoreOnly" ? "CORE CONSUMER VERIFIED" : name.toUpperCase() + "_OK"), "Missing consumer runtime assertion");
    const lockfile = JSON.parse(fs.readFileSync(path.join(cwd, "Package.resolved"), "utf8"));
    ensure(json(lockfile.pins.map((p) => p.identity).sort()) === json(closure.sort()), "Unexpected dependency closure");
    for (const pin of lockfile.pins) {
      const receipt = journal.packages.find((p) => p.package === pin.identity);
      ensure(pin.location === `https://github.com/${receipt.repository.name}.git` &&
        pin.state.version === receipt.version && pin.state.revision === receipt.exportCommit, "Wrong public resolved version/commit");
    }
    consumers.push({ name, manifest, lockfile });
    console.log("PUBLIC CONSUMER VERIFIED: " + name);
  }
  fs.writeFileSync(output, json({ schemaVersion: 1, status: "passed", sourceCommit: journal.sourceCommit,
    swiftVersion, mirrors: false, localDependencies: false, credentialsRequired: false,
    providerCalls: "offline injected transports", checks, consumers }));
} finally { fs.rmSync(temp, { recursive: true, force: true }); }
