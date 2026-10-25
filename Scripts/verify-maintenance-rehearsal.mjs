#!/usr/bin/env node
// Replay a real, already-ported upstream update in disposable repositories.
// Nothing here updates production npm baselines or publishes remote tags.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
import catalog from './lib/catalog.cjs';
import generate from './lib/generate.cjs';
import release from './lib/release.cjs';
import fixtures from './lib/release-fixture.cjs';
import upstream from './lib/upstream.cjs';
const { rootDefault: root, ensure, json } = catalog;
const args = process.argv.slice(2);
ensure(args.length === 2 && args[0] === '--report', 'Usage: verify-maintenance-rehearsal.mjs --report new-report.json');
const output = path.resolve(args[1]), logs = output.replace(/\.json$/, '') + '.logs';
ensure(!fs.existsSync(output) && !fs.existsSync(logs), 'Report/logs already exist');
fs.mkdirSync(logs, { recursive: true });
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'swift-ai-maintenance-'));
const snapshot = path.join(temp, 'canonical'), checks = [];
function command(cmd, argv, cwd, name, failure = false) {
  const r = spawnSync(cmd, argv, { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const log = (r.stdout || '') + (r.stderr || '');
  const logFile = path.join(logs, name + '.log'); fs.writeFileSync(logFile, log);
  checks.push({ name, command: [cmd, ...argv], exitCode: r.status, log: logFile, logSHA256: release.hash(log),
    summaries: log.split('\n').filter(l => /Test run with|recorded an issue|failed|passed|_OK/.test(l)).slice(-25) });
  ensure(!r.error && (failure ? r.status !== 0 : r.status === 0), `${name}: unexpected result; see ${logFile}`);
  return log;
}
function write(file, value) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, typeof value === 'string' ? value : json(value)); }
function recordSet(id, candidate, journal) {
  write(path.join(snapshot, 'Releases/sets', id + '.json'), {
    schemaVersion: 1, id, status: 'published', sourceCommit: candidate.source.commit,
    changeIDs: candidate.changeIDs, consumerVerificationSHA256: release.hash('Disposable local rehearsal only'),
    packages: journal.packages.map(p => ({ package: p.package, version: p.version,
      sourceCommit: candidate.source.commit, exportCommit: p.exportCommit, exportSHA256: p.exportSHA256,
      tagObject: p.tagObject, dependencies: candidate.packages.find(q => q.package === p.package).dependencies })),
  });
}
try {
  // Both versions are historical, explicit fixtures. A fresh network lookup does
  // not select a new production baseline or a new provider.
  const prepared = upstream.prepare(root, { name: '@ai-sdk/openai', from: '4.0.101', to: '4.0.102',
    directory: path.join(root, '.build/upstream-rehearsal/openai-4.0.101--4.0.102') });
  ensure(prepared.testComparison === 'release-matched' && prepared.changedTests.some(f => f.path.endsWith('openai-responses-language-model.test.ts')),
    'The upstream fixture must include a verified changed behavior test');
  fs.mkdirSync(snapshot);
  for (const name of new Set(release.git(['ls-files', '--cached', '--others', '--exclude-standard', '-z'], root).split('\0').filter(Boolean))) {
    const from = path.join(root, name); if (!fs.existsSync(from)) continue;
    ensure(fs.lstatSync(from).isFile(), 'Unexpected snapshot input');
    const to = path.join(snapshot, name); fs.mkdirSync(path.dirname(to), { recursive: true }); fs.copyFileSync(from, to);
  }
  const providerFile = 'Packages/swift-ai-openai/Sources/SwiftAIOpenAI/OpenAIResponsesModel.swift';
  const helperFile = 'Packages/swift-ai-core/Sources/SwiftAI/AIFacadeGenerateObjectTelemetry.swift';
  const provider = fs.readFileSync(path.join(snapshot, providerFile), 'utf8');
  const helper = fs.readFileSync(path.join(snapshot, helperFile), 'utf8');
  ensure(provider.includes('structuredOutputText: structuredOutputText,') && helper.includes('generatedResult.structuredOutputText ?? generatedResult.text'), 'Replay anchors changed; review the fixture');
  // Controlled pre-fix behavior, not a claim to reproduce all bytes of 4.0.101.
  write(path.join(snapshot, providerFile), provider.replace('structuredOutputText: structuredOutputText,', 'structuredOutputText: nil,'));
  write(path.join(snapshot, helperFile), helper.replace('generatedResult.structuredOutputText ?? generatedResult.text', 'generatedResult.text'));
  fixtures.seedPilot(snapshot);
  release.git(['init', '-q', '--initial-branch=main'], snapshot);
  release.git(['add', '.'], snapshot); release.git(['commit', '-q', '-m', 'Disposable pre-fix maintenance baseline'], snapshot);
  const initial = release.plan(snapshot, 'maintenance-baseline');
  const initialExport = path.join(temp, 'initial-export'), initialStage = path.join(temp, 'initial-stage');
  release.exportRelease(snapshot, initial, initialExport);
  const baseline = release.rehearse(initialExport, initialStage);
  recordSet('maintenance-baseline', initial, baseline);
  const testFile = 'Packages/swift-ai-openai/Tests/SwiftAIOpenAITests/MigrationRehearsalTests.swift';
  write(path.join(snapshot, testFile), `import Foundation
import Testing
import SwiftAI
import SwiftAIOpenAI
// Translated from the release-matched OpenAI 4.0.102 Responses tests.
// The commentary and final answer must both remain visible as generated text.
private struct RehearsalObject: Codable, Sendable { let items: [String] }
private func rehearsalModel() throws -> any LanguageModel {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"r","status":"completed","output":[{"type":"message","id":"draft","role":"assistant","status":"completed","phase":"commentary","content":[{"type":"output_text","text":"{\\"items\\":[]}","annotations":[]}]},{"type":"message","id":"final","role":"assistant","status":"completed","phase":"final_answer","content":[{"type":"output_text","text":"{\\"items\\":[\\"result\\"]}","annotations":[]}]}]}"#))
    return try AIProviders.openAI(configuration: .init(apiKey: "offline-fixture", transport: transport)).responses("gpt-5.3-codex")
}
@Test func migrationReplayProviderPreservesTextAndSelectsFinalJSON() async throws {
    let result = try await rehearsalModel().generate(.init(messages: [.user("json")], responseFormat: .json()))
    #expect(result.text == #"{"items":[]}{"items":["result"]}"#)
    #expect(result.structuredOutputText == #"{"items":["result"]}"#)
}
@Test func migrationReplaySharedObjectParserUsesSelectedJSON() async throws {
    let result = try await AI.generateObject(model: rehearsalModel(), request: .init(messages: [.user("json")]), as: RehearsalObject.self)
    #expect(result.object.items == ["result"])
    #expect(result.textResult.text == #"{"items":[]}{"items":["result"]}"#)
}
`);
  const mappingFile = path.join(snapshot, 'Packages/swift-ai-openai/Porting/map.json');
  const mapping = JSON.parse(fs.readFileSync(mappingFile)); mapping.swift.tests.push(testFile);
  mapping.reviewNote += ' Disposable M7 replay maps Responses structured-output selection and translated test to the release-matched 4.0.102 change.';
  write(mappingFile, mapping);
  const swift = ['test', '--package-path', 'Packages/swift-ai-openai', '--scratch-path', path.join(temp, 'build'), '--no-parallel', '--filter', 'migrationReplay'];
  const red = command('swift', swift, snapshot, 'both-regressions', true);
  ensure(red.includes('recorded an issue') && red.includes('migrationReplayProvider') && red.includes('migrationReplayShared'), 'Failure was not the expected behavior regression');
  write(path.join(snapshot, providerFile), provider);
  const partial = command('swift', swift, snapshot, 'provider-fixed-helper-still-broken', true);
  ensure(partial.includes('migrationReplayProviderPreservesTextAndSelectsFinalJSON() passed') && partial.includes('migrationReplaySharedObjectParserUsesSelectedJSON() recorded an issue'), 'Shared helper regression not isolated');
  write(path.join(snapshot, helperFile), helper);
  command('swift', swift, snapshot, 'provider-and-helper-fixed');
  const lockFile = path.join(snapshot, 'Porting/upstream-lock.json'), lock = JSON.parse(fs.readFileSync(lockFile));
  const entry = lock.packages.find(p => p.name === prepared.request.name);
  Object.assign(entry, { reviewedVersion: prepared.new.version, sourceRef: `npm:${entry.name}@${prepared.new.version}`,
    archiveIntegrity: prepared.new.integrity, testRef: prepared.new.tests.ref, testRefRelationship: 'matching-release',
    reviewStatus: 'reviewed', contractReview: 'Disposable replay of already-ported final-answer selection; existing contract families retained. No production provenance changed.' });
  write(lockFile, lock);
  const data = catalog.readCatalog(snapshot), affected = generate.affected(data, [providerFile, helperFile, testFile]);
  ensure(affected.packages.length === data.catalog.packages.length, 'Shared core change omitted downstream checks');
  write(path.join(snapshot, 'Releases/changes/maintenance-update.json'), { schemaVersion: 1, id: 'maintenance-update', status: 'reviewed', summary: 'Disposable replay of Responses structured-output update',
    packages: ['swift-ai-core', 'swift-ai-openai'].map(packageID => ({ package: packageID, bump: 'patch', notes: 'Replay selected final-answer parsing.', compatibility: 'No public signature or dependency-range changes in this synthetic replay.' })) });
  generate.generate(snapshot);
  release.git(['add', '.'], snapshot); release.git(['commit', '-q', '-m', 'Replay provider, translated tests, shared parser and reviewed provenance'], snapshot);
  const candidate = release.plan(snapshot, 'maintenance-update');
  ensure(json(candidate.packages.map(p => p.package)) === json(['swift-ai-core', 'swift-ai-openai']), 'Unchanged units selected for release');
  const exported = path.join(temp, 'updated-export'), stage = path.join(temp, 'updated-stage');
  release.exportRelease(snapshot, candidate, exported);
  const journal = release.rehearse(exported, stage, { baseline: initialStage });
  const unchanged = baseline.packages.filter(p => !journal.packages.some(q => q.package === p.package));
  for (const p of unchanged) ensure(release.git(['rev-parse', 'refs/heads/main'], path.join(stage, 'remotes', p.package + '.git')) === p.exportCommit, 'Unchanged distribution advanced');
  recordSet('maintenance-update', candidate, journal);
  const id = 'swift-ai-maintenance-fixture';
  command(process.execPath, ['Scripts/sdk.mjs', 'package', 'add', '--upstream', '@ai-sdk/maintenance-fixture', '--module', 'SwiftAIMaintenanceFixture'], snapshot, 'add-provider');
  for (const file of ['Docs/PackageCatalog.md', 'Porting/Generated/ci-matrix.json', 'Porting/Generated/exports.json', 'Porting/Generated/development-workspace.json'])
    ensure(fs.readFileSync(path.join(snapshot, file), 'utf8').includes(id), 'Scaffold missing generated registration: ' + file);
  ensure(!fs.readFileSync(path.join(snapshot, 'Package.swift'), 'utf8').includes(id), 'Unimplemented provider entered umbrella');
  write(path.join(snapshot, 'Releases/changes/unfinished.json'), { schemaVersion: 1, id: 'unfinished', status: 'reviewed', summary: 'Must not be released', packages: [{ package: id, bump: 'initial', notes: 'Fixture', compatibility: 'Unimplemented' }] });
  let refused = false;
  try { release.plan(snapshot, 'unfinished'); } catch (e) { refused = /unextracted/.test(e.message); }
  ensure(refused, 'Scaffold was releaseable');
  const catalogFile = path.join(snapshot, 'Porting/packages.json'), registered = JSON.parse(fs.readFileSync(catalogFile));
  registered.packages.find(p => p.id === id).state = 'extracted'; write(catalogFile, registered); generate.generate(snapshot);
  refused = false;
  try { release.plan(snapshot, 'unfinished'); } catch (e) { refused = /unreviewed/.test(e.message); }
  ensure(refused, 'Changing implementation state bypassed provenance gate');
  const report = { schemaVersion: 1, status: 'passed', kind: 'disposable real-upstream maintenance replay',
    productionBaselineChanged: false, remoteWrites: false, upstream: prepared, checks,
    verificationSelection: affected, releasedPackages: journal.packages, unchangedPackages: unchanged,
    scaffold: { package: id, commandRegistrations: 1, additionalHardcodedLists: 0, unimplementedReleaseRejected: true,
      extractedButUnreviewedReleaseRejected: true, generatedSurfaces: ['manifest', 'mapping', 'CI selection', 'export', 'documentation index', 'workspace'] },
    temporaryDirectory: temp };
  fs.writeFileSync(output, json(report));
  fs.rmSync(temp, { recursive: true, force: true });
  console.log('MAINTENANCE_REHEARSAL_OK');
} catch (error) {
  fs.writeFileSync(output + '.failure.json', json({ status: 'failed', error: error.message, checks, temporaryDirectory: temp }));
  throw error;
}
