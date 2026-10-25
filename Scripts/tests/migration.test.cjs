const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const catalog = require('../lib/catalog.cjs');
const upstream = require('../lib/upstream.cjs');
const release = require('../lib/release.cjs');
const local = require('../lib/local-verification.cjs');
const development = require('../lib/development.cjs');
const { umbrellaManifest } = require('../lib/generate.cjs');
test('published archive integrity rejects missing, corrupt and altered input', () => {
  const bytes = Buffer.from('published archive');
  const integrity = 'sha512-' + crypto.createHash('sha512').update(bytes).digest('base64');
  assert.doesNotThrow(() => upstream.verifyIntegrity(bytes, integrity));
  assert.throws(() => upstream.verifyIntegrity(Buffer.from('changed archive'), integrity), /mismatch/);
  assert.throws(() => upstream.verifyIntegrity(bytes, null), /integrity/);
  assert.deepEqual(upstream.changedFiles([{path:'same',sha256:'a'},{path:'deleted',sha256:'b'}], [{path:'same',sha256:'c'},{path:'new',sha256:'d'}]), [
    {path:'deleted',change:'deleted'}, {path:'new',change:'added'}, {path:'same',change:'modified'},
  ]);
});
test('upstream preparation identifies Swift ownership and conservatively widens shared helpers', () => {
  const data = catalog.readCatalog();
  const provider = upstream.selectOwners(data, ['@ai-sdk/openai']);
  assert.deepEqual(provider.owners.map(p => p.package), ['swift-ai-openai']);
  assert(provider.owners[0].swift.sources.some(f => f.endsWith('OpenAIResponsesModel.swift')));
  const shared = upstream.selectOwners(data, ['@ai-sdk/provider-utils']);
  assert.deepEqual(shared.owners.map(p => p.package), ['swift-ai-core']);
  assert.equal(shared.verification.packages.length, data.catalog.packages.length);
});
test('published root uses ranges while development links the identical source bytes', () => {
  const data = catalog.readCatalog(), manifest = umbrellaManifest(data);
  assert(!manifest.includes('.package(path:'));
  assert.equal((manifest.match(/\.package\(url:/g) || []).length, data.catalog.packages.filter(p => p.state === 'extracted').length);
  assert(manifest.includes('swift-ai-core.git", from: "1.1.0"'));
  const workspace = development.prepare();
  for (const name of ['Sources', 'Tests', 'Docs', 'Porting'])
    assert.equal(fs.realpathSync(path.join(workspace, name)), fs.realpathSync(path.join(data.root, name)));
  assert(fs.readFileSync(path.join(workspace, 'Package.swift'), 'utf8').includes('.package(path: "../../../Packages/'));
  assert.deepEqual(fs.readFileSync(path.join(workspace, 'Examples/Package.swift')), fs.readFileSync(path.join(data.root, 'Examples/Package.swift')));
});
test('local migration publication evidence rejects another source, missing checks and tampered logs', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'swift-ai-local-evidence-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const commit = release.git(['rev-parse','HEAD'], catalog.rootDefault);
  const log = path.join(dir, 'check.log'); fs.writeFileSync(log, 'passed');
  const record = { kind: 'local-migration-verification', status: 'passed', sourceCommit: commit,
    sourceTree: release.git(['rev-parse', 'HEAD^{tree}'], catalog.rootDefault), policy: 'Docs/Migration/M6/ci-budget-policy.json',
    checks: local.required.map(name => ({name,exitCode:0,log,logSHA256:release.hash('passed')})) };
  const file = path.join(dir, 'receipt.json'); const write = v => fs.writeFileSync(file, JSON.stringify(v));
  write(record); assert.equal(local.verify(catalog.rootDefault,file,commit).sourceCommit,commit);
  assert.throws(() => local.verify(catalog.rootDefault,file,'a'.repeat(40)), /exact canonical/);
  write({...record,checks:record.checks.slice(1)}); assert.throws(() => local.verify(catalog.rootDefault,file,commit), /Incomplete/);
  write(record); fs.writeFileSync(log, 'tampered'); assert.throws(() => local.verify(catalog.rootDefault,file,commit), /log missing or changed/);
});
