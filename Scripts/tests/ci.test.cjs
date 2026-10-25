const test = require('node:test');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const {readCatalog} = require('../lib/catalog.cjs');
const {plan} = require('../ci-plan.cjs');
const data = readCatalog();

test('prose and site changes never run Swift tests', () => {
  for (const file of ['README.md', 'Docs/PortingStatus.md', 'Docs/Migration.md', 'docs-site/src/content/docs/index.mdx'])
    assert.equal(plan([file], data).swift, false);
  assert.equal(plan(['docs-site/src/content/docs/index.mdx'], data).docs, true);
  assert.equal(plan(['Docs/PortingStatus.md'], data).docs, false);
});
test('provider changes select dependents and the facade, not unrelated providers', () => {
  const result = plan(['Packages/swift-ai-openai/Sources/SwiftAIOpenAI/OpenAIResponsesModel.swift'], data);
  assert.equal(result.swift, true);
  assert(result.packages.split(',').includes('swift-ai-openai'));
  assert(result.packages.split(',').includes('swift-ai-azure'));
  assert(!result.packages.split(',').includes('swift-ai-anthropic'));
  const commands = JSON.parse(execFileSync(process.execPath, ['Scripts/test-packages.mjs', '--packages', result.packages, '--list'], {encoding:'utf8'}));
  assert.deepEqual(commands.map(c => c.package), [...result.packages.split(','), 'SwiftAISDK']);
});
test('core contracts select all packages; facade tests select only the facade', () => {
  assert.equal(plan(['Packages/swift-ai-core/Sources/SwiftAI/AI.swift'], data).packages.split(',').length, 52);
  const result = plan(['Tests/SwiftAISDKTests/Integration.swift'], data);
  assert.equal(result.swift, true);
  assert.equal(result.packages, '');
});
test('workflow changes and explicit docs runs do not trigger SDK tests', () => {
  assert.deepEqual(plan(['.github/workflows/docs.yml'], data), {swift:false, docs:true, tools:true, packages:''});
  assert.deepEqual(plan([], data, 'docs'), {swift:false, docs:true, tools:false, packages:''});
  assert.equal(plan([], data, 'all').packages.split(',').length, 52);
});
test('publication rejects a green docs-only run and accepts actual exact-source tests', () => {
  const {verifyHostedCI} = require('../lib/publish.cjs');
  const run = {head_sha:'a', conclusion:'success', status:'completed', path:'.github/workflows/docs.yml', event:'push'};
  const passed = [{name:'test', status:'completed', conclusion:'success'}];
  assert.throws(() => verifyHostedCI(run, [{name:'test',status:'completed',conclusion:'skipped'}], 'a'));
  assert.throws(() => verifyHostedCI(run, passed, 'b'));
  assert.throws(() => verifyHostedCI({...run,conclusion:'cancelled'}, passed, 'a'));
  assert.equal(verifyHostedCI(run, passed, 'a').sourceCommit, 'a');
  assert.equal(verifyHostedCI({...run,event:'workflow_dispatch'}, passed, 'a').sourceCommit, 'a');
});
