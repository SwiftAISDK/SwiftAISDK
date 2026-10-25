#!/usr/bin/env node
// Catalog-wide distribution verification. Only disposable local repositories are
// written; existing public tags are fetched read-only to test real lower bounds.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import catalog from './lib/catalog.cjs';
import release from './lib/release.cjs';

const {ensure, json, rootDefault: root} = catalog;
const args = process.argv.slice(2);
ensure(args.length === 2 && args[0] === '--report', 'Usage: verify-package-distributions.mjs --report output.json');
const output = path.resolve(args[1]);
ensure(!fs.existsSync(output), 'Report already exists');
const logDirectory = output.replace(/\.json$/, '') + '.logs';
ensure(!fs.existsSync(logDirectory), 'Log directory already exists');
fs.mkdirSync(logDirectory, {recursive: true});
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'swift-ai-all-distributions-'));
const snapshot = path.join(temp, 'canonical');
const checks = [], consumers = [];
function command(cmd, argv, cwd, label, expectedFailure = false) {
  const result = spawnSync(cmd, argv, {cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024});
  if (result.error) throw result.error;
  const log = (result.stdout || '') + (result.stderr || '');
  const logFile = path.join(logDirectory, `${String(checks.length + 1).padStart(3, '0')}-${label.replace(/[^\w-]/g, '-')}.log`);
  fs.writeFileSync(logFile, log);
  checks.push({label, command: [cmd, ...argv], exitCode: result.status, log: logFile,
    logSHA256: release.hash(log), summaries: log.split('\n').filter(l => /Test run with|Build complete|IMPORTS_OK/.test(l))});
  ensure(expectedFailure ? result.status !== 0 : result.status === 0, `${label} failed; see ${logFile}`);
  return result.stdout;
}
function copySnapshot() {
  fs.mkdirSync(snapshot);
  const names = release.git(['ls-files', '--cached', '--others', '--exclude-standard', '-z'], root).split('\0').filter(Boolean);
  for (const name of new Set(names)) {
    if (name.split('/').some(p => ['.build', '.swiftpm', 'node_modules', 'dist', '.DS_Store', '__pycache__'].includes(p) || p.startsWith('._'))) continue;
    const from = path.join(root, name);
    if (!fs.existsSync(from)) continue;
    ensure(fs.lstatSync(from).isFile(), 'Non-file snapshot input: ' + name);
    const to = path.join(snapshot, name); fs.mkdirSync(path.dirname(to), {recursive: true}); fs.copyFileSync(from, to);
  }
}
let report;
try {
  copySnapshot();
  const data = catalog.readCatalog(snapshot);
  const units = data.order.map(id => data.catalog.packages.find(p => p.id === id)).filter(p => p.state === 'extracted');
  const unitByID = new Map(units.map(p => [p.id, p]));
  const sets = fs.readdirSync(path.join(snapshot, 'Releases/sets')).filter(f => f.endsWith('.json'))
    .flatMap(f => JSON.parse(fs.readFileSync(path.join(snapshot, 'Releases/sets', f))).packages);
  const published = new Map();
  for (const item of sets) {
    if (!published.has(item.package)) published.set(item.package, []);
    published.get(item.package).push(item);
  }
  // Existing reviewed changes supply real semantic bumps. Add synthetic patches
  // for otherwise unchanged units so every current distribution tree is checked.
  fs.writeFileSync(path.join(snapshot, 'Releases/changes/all-package-verification.json'), json({
    schemaVersion: 1, id: 'all-package-verification', status: 'reviewed',
    summary: 'Disposable verification exports for every extracted catalog package; not a publication plan.',
    packages: units.map(p => {
      const prior = published.get(p.id)?.slice().sort((a,b) => release.compare(a.version,b.version)).at(-1)?.version;
      const requirements = units.flatMap(q => q.dependencies.filter(d => d.package === p.id).map(d => d.from));
      const bump = prior ? ['patch', 'minor', 'major'].find(b => requirements.every(v => release.compare(release.versionAfter(prior, b), v) >= 0)) : 'initial';
      ensure(bump, 'Cannot construct compatible synthetic version for ' + p.id);
      return {package: p.id, bump, notes: 'Exercise current standalone sources, tests and resources.', compatibility: 'Synthetic local Git tags only.'};
    })
  }));
  release.git(['init', '-q', '--initial-branch=main'], snapshot);
  release.git(['add', '.'], snapshot);
  release.git(['commit', '-q', '-m', 'Disposable catalog-wide distribution verification'], snapshot);
  const candidate = release.plan(snapshot, 'all-package-verification');
  ensure(candidate.packages.length === units.length, 'Not every extracted package was selected');
  const first = path.join(temp, 'export-a'), second = path.join(temp, 'export-b');
  const a = release.exportRelease(snapshot, candidate, first), b = release.exportRelease(snapshot, candidate, second);
  ensure(json(a) === json(b), 'Exports differ from identical snapshot');
  console.log(`DETERMINISTIC EXPORTS: ${units.length} packages`);
  const stage = path.join(temp, 'publication');
  const journal = release.rehearse(first, stage);
  const versions = new Map(journal.packages.map(p => [p.package, [{...p,
    dependencies: candidate.packages.find(q => q.package === p.package).dependencies}]]));
  for (const [id, entries] of published) {
    if (!unitByID.has(id)) continue;
    const remote = path.join(stage, 'remotes', id + '.git');
    for (const entry of entries) {
      command('git', ['fetch', '--no-tags', unitByID.get(id).repository,
        `refs/tags/${entry.version}:refs/tags/${entry.version}`], remote, `fetch published ${id} ${entry.version}`);
      ensure(release.git(['rev-parse', `refs/tags/${entry.version}^{}`], remote) === entry.exportCommit, 'Published peeled tag changed: ' + id);
      ensure(release.git(['rev-parse', `refs/tags/${entry.version}`], remote) === entry.tagObject, 'Published annotated tag changed: ' + id);
      versions.get(id).push(entry);
    }
  }
  for (const list of versions.values()) list.sort((a, b) => release.compare(a.version, b.version));
  // Ask SwiftPM to write its own mirror configuration, then reuse its bytes.
  for (const p of units) command('swift', ['package', 'config', 'set-mirror', '--original', p.repository,
    '--mirror', pathToFileURL(path.join(stage, 'remotes', p.id + '.git')).href], snapshot, 'mirror ' + p.id);
  const mirror = fs.readFileSync(path.join(snapshot, '.swiftpm/configuration/mirrors.json'));
  function installMirrors(cwd) {
    const dir = path.join(cwd, '.swiftpm/configuration'); fs.mkdirSync(dir, {recursive: true}); fs.writeFileSync(path.join(dir, 'mirrors.json'), mirror);
  }
  function closure(id, found = new Set()) {
    if (found.has(id)) return found; found.add(id);
    for (const d of unitByID.get(id).dependencies) closure(d.package, found);
    return found;
  }
  function minimumVersions(id) {
    const ids = closure(id), required = new Map();
    required.set(id, journal.packages.find(p => p.package === id).version);
    for (const key of ids) for (const dep of unitByID.get(key).dependencies) {
      if (!required.has(dep.package) || release.compare(dep.from, required.get(dep.package)) > 0) required.set(dep.package, dep.from);
    }
    return new Map([...required].map(([key, lower]) => {
      const match = versions.get(key).find(v => release.accepts(lower, v.version));
      ensure(match, `No real minimum candidate for ${key} from ${lower}`); return [key, match.version];
    }));
  }
  function publicClient(label, roots, pins, exactAll = true) {
    const cwd = path.join(temp, 'consumers', label), source = path.join(cwd, 'Sources/Consumer');
    fs.mkdirSync(source, {recursive: true});
    const ids = new Set(roots.flatMap(id => [...closure(id)]));
    // Latest clients constrain roots only. Adding a newer transitive major here
    // would incorrectly force it on a provider whose range still permits 1.x.
    const dependencies = [...(exactAll ? ids : new Set(roots))].map(id => {
      const v = pins.get(id) ?? journal.packages.find(p => p.package === id).version;
      return `.package(url: "${unitByID.get(id).repository}", ${exactAll ? 'exact' : 'from'}: "${v}")`;
    });
    const modules = roots.flatMap(id => unitByID.get(id).modules.map(m => ({id, name: m.name})));
    fs.writeFileSync(path.join(cwd, 'Package.swift'), `// swift-tools-version: 6.3\nimport PackageDescription\nlet package = Package(name: "Consumer", platforms: [.macOS("12.0"), .iOS("15.0")], dependencies: [${dependencies.join(',')}], targets: [.executableTarget(name: "Consumer", dependencies: [${modules.map(m => `.product(name: "${m.name}", package: "${m.id}")`).join(',')}])], swiftLanguageModes: [.v6])\n`);
    let code = modules.map(m => 'import ' + m.name).join('\n') + '\n';
    for (const {id, name} of modules) {
      const directory = path.join(snapshot, unitByID.get(id).directory, 'Sources', name);
      // Refer to public concrete provider types without relying on @testable or
      // inventing network credentials. Behavioral execution is in exported tests.
      for (const file of fs.readdirSync(directory).filter(f => f.endsWith('.swift'))) {
        const text = fs.readFileSync(path.join(directory, file), 'utf8');
        for (const match of text.matchAll(/public\s+(?:final\s+)?(?:class|struct)\s+(\w+)\s*:\s*AIProvider\b/g)) code += `let _: ${name}.${match[1]}.Type = ${name}.${match[1]}.self\n`;
      }
    }
    fs.writeFileSync(path.join(source, 'main.swift'), code + 'print("IMPORTS_OK")\n'); installMirrors(cwd);
    // Share only the disposable compiler scratch area. Each client still starts
    // without a lockfile and its resolved versions/revisions are checked below.
    const scratch = path.join(temp, exactAll ? 'minimum-client-build' : 'latest-client-build');
    command('swift', ['run', '--scratch-path', scratch, '-c', 'release', 'Consumer'], cwd, label);
    const lock = JSON.parse(fs.readFileSync(path.join(cwd, 'Package.resolved')));
    const resolved = new Map();
    for (const pin of lock.pins) {
      const version = versions.get(pin.identity)?.find(v => v.version === pin.state.version);
      ensure(version && pin.state.revision === version.exportCommit, 'Unknown resolved candidate: ' + label + ' / ' + pin.identity);
      if (exactAll || roots.includes(pin.identity)) ensure(pin.state.version === pins.get(pin.identity), 'Wrong requested version: ' + label + ' / ' + pin.identity);
      resolved.set(pin.identity, version);
    }
    const reachable = new Set();
    function visit(id) {
      if (reachable.has(id)) return; reachable.add(id);
      const version = resolved.get(id); ensure(version, 'Missing resolved package: ' + id);
      for (const dependency of version.dependencies) {
        ensure(resolved.has(dependency.package) && release.accepts(dependency.from, resolved.get(dependency.package).version), 'Unsatisfied recorded dependency: ' + id);
        visit(dependency.package);
      }
    }
    roots.forEach(visit);
    ensure(json([...resolved.keys()].sort()) === json([...reachable].sort()), 'Unexpected resolved closure: ' + label);
    consumers.push({label, roots, lockfile: lock, publicTypesOnly: true});
  }
  for (const entry of a.exports) {
    const cwd = path.join(temp, 'packages', entry.package);
    fs.mkdirSync(path.dirname(cwd), {recursive: true});
    release.git(['clone', '-q', '--branch', entry.version, path.join(stage, 'remotes', entry.package + '.git'), cwd], temp);
    const manifest = fs.readFileSync(path.join(cwd, 'Package.swift')); installMirrors(cwd);
    command('swift', ['test', '--scratch-path', path.join(temp, 'standalone-test-build'), '--no-parallel'], cwd, 'exported tests ' + entry.package);
    ensure(manifest.equals(fs.readFileSync(path.join(cwd, 'Package.swift'))), 'Export manifest changed');
    publicClient(entry.package + '-minimum', [entry.package], minimumVersions(entry.package));
    publicClient(entry.package + '-latest', [entry.package], new Map(journal.packages.map(p => [p.package, p.version])), false);
    console.log('DISTRIBUTION VERIFIED: ' + entry.package);
  }
  const independent = units.filter(p => p.kind === 'provider' && published.has(p.id));
  const older = independent.find(a => independent.some(b => a.id !== b.id && !closure(a.id).has(b.id) && !closure(b.id).has(a.id)));
  const newer = independent.find(b => older && b.id !== older.id && !closure(older.id).has(b.id) && !closure(b.id).has(older.id));
  ensure(older && newer, 'Need two independently released providers for mixed-version check');
  const mixedPins = new Map(journal.packages.map(p => [p.package, p.version]));
  mixedPins.set(older.id, published.get(older.id).sort((a,b) => release.compare(a.version,b.version)).at(-1).version);
  publicClient('mixed-published-and-candidate', [older.id, newer.id], mixedPins);
  // Exercise the actual remote-only umbrella manifest through an annotated Git
  // tag, with the same exported dependencies as ordinary consumers would get.
  const umbrella = path.join(temp, 'SwiftAISDK'); fs.mkdirSync(umbrella);
  for (const name of ['Package.swift', 'Sources', 'LICENSE'])
    fs.cpSync(path.join(snapshot, name), path.join(umbrella, name), {recursive: true});
  ensure(!fs.readFileSync(path.join(umbrella, 'Package.swift'), 'utf8').includes('.package(path:'), 'Local path in public umbrella');
  release.git(['init', '-q', '--initial-branch=main'], umbrella);
  release.git(['add', '.'], umbrella); release.git(['commit', '-q', '-m', 'Disposable 3.0 umbrella'], umbrella);
  release.git(['tag', '-a', '3.0.0', '-m', 'Local verification fixture only'], umbrella);
  const complete = path.join(temp, 'complete-consumer');
  fs.cpSync(path.join(snapshot, 'Examples/Complete'), complete, {recursive: true});
  installMirrors(complete);
  command('swift', ['package', 'config', 'set-mirror', '--original', 'https://github.com/SwiftAISDK/SwiftAISDK.git',
    '--mirror', pathToFileURL(umbrella).href], complete, 'mirror compatibility umbrella');
  const completed = command('swift', ['run', '--scratch-path', path.join(temp, 'latest-client-build'), '-c', 'release', 'CompleteConsumer'], complete, 'complete compatibility client');
  ensure(completed.includes('COMPLETE_CONSUMER_OK'), 'Missing compatibility runtime checks');
  const completeLock = JSON.parse(fs.readFileSync(path.join(complete, 'Package.resolved')));
  ensure(completeLock.pins.length === units.length + 1, 'Incomplete umbrella dependency graph');
  for (const pin of completeLock.pins) {
    if (pin.identity === 'swiftaisdk') {
      ensure(pin.state.version === '3.0.0' && pin.state.revision === release.git(['rev-parse', 'HEAD'], umbrella), 'Wrong umbrella tag');
    } else ensure(versions.get(pin.identity)?.some(v => v.version === pin.state.version && v.exportCommit === pin.state.revision), 'Unverified umbrella dependency');
  }
  consumers.push({label: 'complete-compatibility', lockfile: completeLock, ordinaryImports: true, offlineRuntimeAssertions: true});
  report = {schemaVersion: 1, status: 'passed', evidenceKind: 'local synthetic exports with real published lower bounds',
    sourceSnapshot: candidate.source, packageCount: units.length, deterministicExports: a.exports,
    checks, consumers, temporaryDirectory: temp};
  fs.mkdirSync(path.dirname(output), {recursive: true}); fs.writeFileSync(output, json(report));
  console.log('ALL DISTRIBUTIONS VERIFIED: ' + units.length);
  fs.rmSync(temp, {recursive: true, force: true});
} catch (error) {
  fs.writeFileSync(output + '.failure.json', json({status: 'failed', message: error.message, checks, consumers, temporaryDirectory: temp}));
  throw error;
}
