#!/usr/bin/env node
// Fresh consumers of actual public Git refs: no local overrides, mirrors or credentials.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import catalog from './lib/catalog.cjs';
import release from './lib/release.cjs';
const { rootDefault: root, ensure, json } = catalog;
const [attempt, outputArg, ...extra] = process.argv.slice(2);
ensure(attempt && outputArg && (extra.length === 0 || (extra.length === 2 && extra[0] === '--umbrella')), 'Usage: verify-public-packages.mjs attempt.json new-report.json [--umbrella version]');
const output = path.resolve(outputArg), umbrellaVersion = extra[1];
ensure(!fs.existsSync(output), 'Report already exists');
const journal = JSON.parse(fs.readFileSync(attempt, 'utf8'));
ensure(journal.kind === 'github-publication' && journal.status === 'tags-and-releases-ready', 'Public refs must be ready');
const data = catalog.readCatalog(root);
const historical = fs.readdirSync(path.join(root, 'Releases/sets')).filter(f => f.endsWith('.json'))
  .flatMap(f => JSON.parse(fs.readFileSync(path.join(root, 'Releases/sets', f))).packages);
const versions = new Map();
for (const p of [...historical, ...journal.packages]) {
  if (!versions.has(p.package)) versions.set(p.package, []);
  const list = versions.get(p.package), prior = list.find(q => q.version === p.version);
  ensure(!prior || (prior.exportCommit === p.exportCommit && prior.tagObject === p.tagObject), 'Conflicting published receipt');
  if (!prior) list.push(p);
}
for (const list of versions.values()) list.sort((a, b) => release.compare(a.version, b.version));
const latest = new Map([...versions].map(([id, entries]) => [id, entries.at(-1)]));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'swift-ai-public-consumers-'));
const logDirectory = output.replace(/\.json$/, '') + '.logs';
ensure(!fs.existsSync(logDirectory), 'Report logs already exist'); fs.mkdirSync(logDirectory, { recursive: true });
const checks = [], consumers = [];
const environment = { ...process.env, GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_NOSYSTEM: '1', GIT_TERMINAL_PROMPT: '0' };
function command(cmd, argv, cwd, name) {
  const result = spawnSync(cmd, argv, { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, env: environment });
  const log = (result.stdout || '') + (result.stderr || '');
  const logFile = path.join(logDirectory, name + '.log'); fs.writeFileSync(logFile, log);
  checks.push({ name, command: [cmd, ...argv], exitCode: result.status, log: logFile, logSHA256: release.hash(log),
    summaries: log.split('\n').filter(s => /_OK|CONSUMER VERIFIED|Build complete/.test(s)) });
  ensure(!result.error && result.status === 0, `${name} failed; see ${logFile}`);
  return result.stdout;
}
function closure(roots, selected) {
  const found = new Set();
  function visit(id) {
    if (found.has(id)) return; found.add(id);
    const p = selected.get(id); ensure(p, 'Missing selected receipt: ' + id);
    for (const d of p.dependencies) {
      ensure(release.accepts(d.from, selected.get(d.package)?.version || '0.0.0'), 'Incompatible selected dependency: ' + id);
      visit(d.package);
    }
  }
  roots.forEach(visit); return [...found].sort();
}
function runClient(name, manifest, sources, roots, selected, executable, marker, rootReceipt = null) {
  // SwiftPM derives the root identity from the folder too. A client named after
  // its dependency would resolve its own product instead of the remote package.
  const cwd = path.join(temp, 'consumer-' + name); fs.mkdirSync(cwd);
  if (typeof sources === 'string') {
    const directory = path.join(cwd, 'Sources', executable); fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(path.join(directory, 'main.swift'), sources);
  } else fs.cpSync(sources.path, path.join(cwd, 'Sources'), { recursive: true });
  ensure(!manifest.includes('.package(path:'), 'Local dependency in consumer');
  fs.writeFileSync(path.join(cwd, 'Package.swift'), manifest);
  const result = command('swift', ['run', '--disable-dependency-cache', '--config-path', path.join(cwd, 'config'),
    '--cache-path', path.join(cwd, 'cache'), '--security-path', path.join(cwd, 'security'),
    '--scratch-path', path.join(temp, rootReceipt ? 'umbrella-build' : 'modular-build'), '-c', 'release', executable], cwd, name);
  ensure(result.includes(marker), 'Missing consumer runtime assertion');
  const lockfile = JSON.parse(fs.readFileSync(path.join(cwd, 'Package.resolved'), 'utf8'));
  const expected = rootReceipt ? ['swiftaisdk', ...roots] : closure(roots, selected);
  ensure(json(lockfile.pins.map(p => p.identity).sort()) === json(expected.sort()), 'Unexpected dependency closure: ' + name);
  for (const pin of lockfile.pins) {
    const receipt = pin.identity === 'swiftaisdk' ? rootReceipt : selected.get(pin.identity);
    const repository = pin.identity === 'swiftaisdk' ? 'SwiftAISDK' : receipt.package;
    ensure(pin.location === `https://github.com/SwiftAISDK/${repository}.git` && pin.state.version === receipt.version &&
      pin.state.revision === receipt.exportCommit, 'Wrong public resolved version/commit: ' + name + '/' + pin.identity);
  }
  ensure(!fs.existsSync(path.join(cwd, '.swiftpm/configuration/mirrors.json')), 'Unexpected local mirror');
  const record = { name, manifest, lockfile, marker }; consumers.push(record);
  console.log('PUBLIC CONSUMER VERIFIED: ' + name); return record;
}
try {
  const swiftVersion = command('swift', ['--version'], temp, 'swift-version').trim();
  // Canonical examples use local identities; substitute only dependency locations.
  const examples = ['CoreOnly', 'AnthropicOnly', 'OpenAICompatibleOnly', 'OpenAIOnly', 'MixedProviders'];
  for (const name of examples) {
    let manifest = fs.readFileSync(path.join(root, 'Examples', name, 'Package.swift'), 'utf8');
    const roots = [];
    for (const [id, p] of latest) {
      if (manifest.includes(`.package(path: "../../Packages/${id}")`)) roots.push(id);
      manifest = manifest.replaceAll(`.package(path: "../../Packages/${id}")`, `.package(url: "https://github.com/SwiftAISDK/${id}.git", exact: "${p.version}")`);
    }
    runClient(name, manifest, { path: path.join(root, 'Examples', name, 'Sources') }, roots, latest,
      name === 'CoreOnly' ? 'CoreConsumer' : 'ProviderConsumer', name === 'CoreOnly' ? 'CORE CONSUMER VERIFIED' : name.toUpperCase() + '_OK');
  }
  for (const p of data.catalog.packages.filter(p => latest.has(p.id))) {
    const v = latest.get(p.id).version;
    const manifest = `// swift-tools-version: 6.3\nimport PackageDescription\nlet package = Package(name: "Consumer", platforms: [.macOS("12.0"), .iOS("15.0")], dependencies: [.package(url: "${p.repository}", exact: "${v}")], targets: [.executableTarget(name: "Consumer", dependencies: [${p.modules.map(m => `.product(name: "${m.name}", package: "${p.id}")`).join(',')}])], swiftLanguageModes: [.v6])\n`;
    let code = p.modules.map(m => 'import ' + m.name).join('\n') + '\n';
    for (const m of p.modules) for (const name of fs.readdirSync(path.join(root, p.directory, 'Sources', m.name)).filter(f => f.endsWith('.swift'))) {
      const content = fs.readFileSync(path.join(root, p.directory, 'Sources', m.name, name), 'utf8');
      for (const match of content.matchAll(/public\s+(?:final\s+)?(?:class|struct)\s+(\w+)\s*:\s*AIProvider\b/g)) code += `let _: ${m.name}.${match[1]}.Type = ${m.name}.${match[1]}.self\n`;
    }
    runClient(p.id, manifest, code + 'print("PUBLIC_IMPORTS_OK")\n', [p.id], latest, 'Consumer', 'PUBLIC_IMPORTS_OK');
  }
  // Real independently pinned versions. Keep core and OpenAI fixed while only
  // Anthropic changes from its first release to the newest published version.
  const independent = 'swift-ai-anthropic';
  if ((versions.get(independent)?.length || 0) > 1) {
    const pins = new Map(latest), beforeVersion = versions.get(independent)[0];
    pins.set(independent, beforeVersion);
    let sourceManifest = fs.readFileSync(path.join(root, 'Examples/MixedProviders/Package.swift'), 'utf8');
    const records = [];
    for (const state of ['before', 'after']) {
      if (state === 'after') pins.set(independent, latest.get(independent));
      let manifest = sourceManifest;
      for (const [id, p] of pins) manifest = manifest.replaceAll(`.package(path: "../../Packages/${id}")`, `.package(url: "https://github.com/SwiftAISDK/${id}.git", exact: "${p.version}")`);
      records.push(runClient('independent-upgrade-' + state, manifest, { path: path.join(root, 'Examples/MixedProviders/Sources') },
        ['swift-ai-core', 'swift-ai-openai', independent], pins, 'ProviderConsumer', 'MIXEDPROVIDERS_OK'));
    }
    const before = new Map(records[0].lockfile.pins.map(p => [p.identity, p.state]));
    for (const pin of records[1].lockfile.pins) if (pin.identity !== independent)
      ensure(json(pin.state) === json(before.get(pin.identity)), 'Updating one provider changed another pin');
  }
  if (umbrellaVersion) for (const version of [umbrellaVersion, '2.8.1']) {
    const refs = command('git', ['ls-remote', 'https://github.com/SwiftAISDK/SwiftAISDK.git', `refs/tags/${version}`, `refs/tags/${version}^{}`], temp, 'umbrella-refs-' + version)
      .trim().split('\n').map(s => s.split(/\s+/));
    const commit = refs.find(r => r[1].endsWith('^{}'))?.[0]; ensure(commit, 'Umbrella release must have an annotated tag');
    const manifest = fs.readFileSync(path.join(root, 'Examples/Complete/Package.swift'), 'utf8').replace('from: "3.0.0"', `exact: "${version}"`);
    runClient('complete-' + version, manifest, { path: path.join(root, 'Examples/Complete/Sources') },
      version === '2.8.1' ? [] : [...latest.keys()], latest, 'CompleteConsumer', 'COMPLETE_CONSUMER_OK', { version, exportCommit: commit });
  }
  fs.writeFileSync(output, json({ schemaVersion: 1, status: 'passed', sourceCommit: journal.sourceCommit, swiftVersion,
    mirrors: false, localDependencies: false, credentialsRequired: false, packageCount: latest.size,
    providerCalls: 'offline injected transports', checks, consumers }));
  fs.rmSync(temp, { recursive: true, force: true });
} catch (error) {
  fs.writeFileSync(output + '.failure.json', json({ status: 'failed', error: error.message, checks, consumers, temporaryDirectory: temp }));
  throw error;
}
