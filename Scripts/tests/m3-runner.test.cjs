const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {selectRunner, prepareToolchain, createGitHubAPI, watchQueuedJob, main, DEFAULT_MACOS_SDKROOT} = require('../m3-runner.cjs');

const SHA = 'a'.repeat(40);
const M3 = ['self-hosted', 'macOS', 'ARM64', 'swift-ai-m3'];
const trusted = {eventName: 'push', ref: 'refs/heads/main'};
function temporary(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'swiftai-runner-'));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  return directory;
}
function toolchainFixture(t, names = ['swift-6.3.3-RELEASE.xctoolchain']) {
  const home = temporary(t), calls = [];
  fs.mkdirSync(path.join(home, 'Library/Developer/Toolchains'), {recursive: true});
  for (const name of names) fs.mkdirSync(path.join(home, 'Library/Developer/Toolchains', name), {recursive: true});
  const environment = {RUNNER_ENVIRONMENT: 'self-hosted', GITHUB_PATH: path.join(home, 'path'), GITHUB_ENV: path.join(home, 'env')};
  const defaultSDKRoot = path.join(home, 'SDKs/MacOSX26.5.sdk');
  fs.mkdirSync(defaultSDKRoot, {recursive: true});
  fs.writeFileSync(path.join(defaultSDKRoot, 'SDKSettings.json'), JSON.stringify({CanonicalName: 'macosx26.5', Version: '26.5'}));
  const run = (command, args, options) => {
    calls.push({command, args, options});
    return command.endsWith('/swift') ? 'Apple Swift version 6.3.3 (swiftlang-6.3.3.1)\nTarget: arm64-apple-macosx' : 'org.swift.633.release\n';
  };
  return {home, environment, run, calls, defaultSDKRoot};
}
function watchdog(overrides = {}) {
  let time = 0, jobReads = 0;
  const requests = [], sleeps = [];
  const options = {repository: 'SwiftAISDK/SwiftAISDK', runID: '1234', sha: SHA, ...trusted,
    now: () => time, sleep: async milliseconds => { sleeps.push(milliseconds); time += milliseconds; },
    api: async (method, resource, body) => {
      requests.push({method, resource, body, time});
      if (resource.includes('/jobs?')) {
        jobReads++;
        return {total_count: 1, jobs: [{name: 'test', status: 'queued'}]};
      }
      if (resource.endsWith('/git/ref/heads/main')) return {object: {sha: SHA}};
      assert.equal(method, 'POST');
      return null;
    }, ...overrides};
  return {options, requests, sleeps, now: () => time, advance: milliseconds => { time += milliseconds; }, jobReads: () => jobReads};
}

test('only main push and manual dispatch prefer the dedicated M3 labels', () => {
  for (const eventName of ['push', 'workflow_dispatch'])
    assert.deepEqual(selectRunner({...trusted, eventName}), {labels: M3, kind: 'm3'});
  for (const eventName of ['pull_request', 'pull_request_target', 'schedule', 'repository_dispatch', undefined])
    assert.deepEqual(selectRunner({...trusted, eventName}), {labels: ['macos-26'], kind: 'github'});
  for (const ref of ['refs/heads/feature', 'refs/tags/1.0.0', 'refs/pull/42/merge', '', undefined])
    assert.deepEqual(selectRunner({...trusted, ref}), {labels: ['macos-26'], kind: 'github'});
});
test('explicit github preference wins and callers cannot mutate shared labels', () => {
  assert.deepEqual(selectRunner({...trusted, preference: 'github'}), {labels: ['macos-26'], kind: 'github'});
  selectRunner(trusted).labels.push('unrelated-runner');
  assert.deepEqual(selectRunner(trusted).labels, M3);
});
test('select CLI writes exact labels and kind to the Actions output file', t => {
  const output = path.join(temporary(t), 'output');
  const result = execFileSync(process.execPath, [path.join(__dirname, '../m3-runner.cjs'), 'select'], {
    env: {...process.env, GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_REF: 'refs/heads/main', RUNNER_PREFERENCE: 'auto', GITHUB_OUTPUT: output}, encoding: 'utf8',
  });
  assert.deepEqual(JSON.parse(result), {labels: M3, kind: 'm3'});
  assert.equal(fs.readFileSync(output, 'utf8'), `labels=${JSON.stringify(M3)}\nkind=m3\n`);
});
test('hosted preparation does no filesystem or process work', () => {
  assert.deepEqual(prepareToolchain({environment: {RUNNER_ENVIRONMENT: 'github-hosted'}, home: '/does-not-exist',
    run: () => assert.fail('Hosted preparation must not spawn processes')}), {kind: 'github', prepared: false});
});
test('prepare selects exact side-by-side Swift and appends only job environment files', t => {
  const fixture = toolchainFixture(t);
  fs.writeFileSync(fixture.environment.GITHUB_ENV, 'KEEP=value\n');
  const original = {...fixture.environment};
  const result = prepareToolchain(fixture);
  assert.equal(result.prepared, true);
  assert.equal(result.bundleID, 'org.swift.633.release');
  assert.equal(DEFAULT_MACOS_SDKROOT, '/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk');
  assert.equal(result.sdkRoot, fixture.defaultSDKRoot);
  assert.equal(fs.readFileSync(fixture.environment.GITHUB_PATH, 'utf8'), `${path.join(result.toolchain, 'usr/bin')}\n`);
  assert.equal(fs.readFileSync(fixture.environment.GITHUB_ENV, 'utf8'), `KEEP=value\nTOOLCHAINS=org.swift.633.release\nSDKROOT=${fixture.defaultSDKRoot}\n`);
  assert.deepEqual(fixture.environment, original);
  assert.deepEqual(fixture.calls.map(c => c.command), [path.join(result.toolchain, 'usr/bin/swift'), '/usr/bin/plutil', path.join(result.toolchain, 'usr/bin/swiftc')]);
  assert.deepEqual(fixture.calls[0].args, ['--version']);
  assert.deepEqual(fixture.calls[2].args, ['-sdk', fixture.defaultSDKRoot, '-typecheck', '-']);
  assert.equal(fixture.calls[2].options.input, 'import Foundation\nimport CryptoKit\n');
  assert.equal(fixture.calls[2].options.env.SDKROOT, fixture.defaultSDKRoot);
  assert.equal(fixture.calls[2].options.env.TOOLCHAINS, result.bundleID);
});
test('preparation rejects missing or ambiguous matching toolchains without exports', t => {
  for (const names of [[], ['one-6.3.3.xctoolchain', 'two-6.3.3.xctoolchain']]) {
    const fixture = toolchainFixture(t, names);
    assert.throws(() => prepareToolchain(fixture), /Expected one Swift 6\.3\.3/);
    assert(!fs.existsSync(fixture.environment.GITHUB_ENV));
  }
});
test('preparation rejects other patch versions and development compilers', t => {
  for (const version of ['6.4.0', '6.3.30', '6.3.3-dev']) {
    const fixture = toolchainFixture(t);
    fixture.run = () => `Swift version ${version} (test)`;
    assert.throws(() => prepareToolchain(fixture), /Expected one Swift 6\.3\.3/);
    assert(!fs.existsSync(fixture.environment.GITHUB_PATH));
  }
});
test('invalid bundle IDs cannot inject job environment lines', t => {
  const fixture = toolchainFixture(t), run = fixture.run;
  fixture.run = (command, args) => command.endsWith('/swift') ? run(command, args) : 'org.swift.633\nINJECT=value';
  assert.throws(() => prepareToolchain(fixture), /Invalid toolchain/);
  assert(!fs.existsSync(fixture.environment.GITHUB_ENV));
});
test('an explicit compatible SDK override is validated with the pinned compiler', t => {
  const fixture = toolchainFixture(t);
  const sdkRoot = path.join(fixture.home, 'alternate/MacOSX26.4.sdk');
  fs.mkdirSync(sdkRoot, {recursive: true});
  fs.writeFileSync(path.join(sdkRoot, 'SDKSettings.json'), JSON.stringify({CanonicalName: 'macosx26.4', Version: '26.4'}));
  fixture.environment.SWIFT_M3_MACOS_SDKROOT = sdkRoot;
  fixture.environment.SDKROOT = '/unrelated/system/MacOSX27.sdk';
  const original = {...fixture.environment};
  const result = prepareToolchain(fixture);
  assert.equal(result.sdkRoot, sdkRoot);
  assert.equal(fixture.calls.at(-1).options.env.SDKROOT, sdkRoot);
  assert.deepEqual(fixture.calls.at(-1).args, ['-sdk', sdkRoot, '-typecheck', '-']);
  assert(fs.readFileSync(fixture.environment.GITHUB_ENV, 'utf8').endsWith(`SDKROOT=${sdkRoot}\n`));
  assert.deepEqual(fixture.environment, original);
});
test('missing, non-directory and unsafe SDK paths export no partial environment', t => {
  for (const shape of ['missing', 'file', 'relative', 'newline']) {
    const fixture = toolchainFixture(t);
    const sdkPath = path.join(fixture.home, 'bad.sdk');
    if (shape === 'file') fs.writeFileSync(sdkPath, 'not an SDK directory');
    fixture.environment.SWIFT_M3_MACOS_SDKROOT = shape === 'relative' ? 'relative.sdk' : shape === 'newline' ? `${sdkPath}\nINJECT=value` : sdkPath;
    assert.throws(() => prepareToolchain(fixture));
    assert(!fixture.calls.some(c => c.args.includes('-typecheck')));
    assert(!fs.existsSync(fixture.environment.GITHUB_PATH));
    assert(!fs.existsSync(fixture.environment.GITHUB_ENV));
  }
});
test('non-macOS or malformed SDK manifests are rejected before the compiler probe', t => {
  for (const manifest of ['{"CanonicalName":"iphonesimulator26.5"}', '{invalid']) {
    const fixture = toolchainFixture(t);
    fs.writeFileSync(path.join(fixture.defaultSDKRoot, 'SDKSettings.json'), manifest);
    assert.throws(() => prepareToolchain(fixture));
    assert(!fixture.calls.some(c => c.args.includes('-typecheck')));
    assert(!fs.existsSync(fixture.environment.GITHUB_ENV));
  }
});
test('Foundation or CryptoKit incompatibility fails preparation without exports', t => {
  for (const message of ['unknown option -target-arch-variant', 'no such module CryptoKit']) {
    const fixture = toolchainFixture(t), run = fixture.run;
    fixture.run = (command, args, options) => {
      if (args.includes('-typecheck')) {
        assert.equal(options.env.SDKROOT, fixture.defaultSDKRoot);
        assert.equal(options.input, 'import Foundation\nimport CryptoKit\n');
        throw new Error(message);
      }
      return run(command, args, options);
    };
    assert.throws(() => prepareToolchain(fixture), error => error.message === message);
    assert(!fs.existsSync(fixture.environment.GITHUB_PATH));
    assert(!fs.existsSync(fixture.environment.GITHUB_ENV));
  }
});

test('watch waits a full 90 seconds then checks main and fresh queue before one hosted dispatch', async () => {
  const fixture = watchdog();
  const result = await watchQueuedJob(fixture.options);
  assert.equal(result.action, 'fallback-dispatched');
  assert.equal(fixture.now(), 90_000);
  assert.deepEqual(fixture.requests.slice(-3).map(r => [r.method, r.resource]), [
    ['GET', '/repos/SwiftAISDK/SwiftAISDK/git/ref/heads/main'],
    ['GET', '/repos/SwiftAISDK/SwiftAISDK/actions/runs/1234/jobs?filter=latest&per_page=100&page=1'],
    ['POST', '/repos/SwiftAISDK/SwiftAISDK/actions/workflows/docs.yml/dispatches'],
  ]);
  assert.deepEqual(fixture.requests.at(-1).body, {ref: 'main', inputs: {scope: 'all', runner: 'github', fallback_from: '1234'}});
  assert.equal(fixture.requests.filter(r => r.method === 'POST').length, 1);
});
test('runner probes fall back to a runner smoke run, not release test evidence', async () => {
  const fixture = watchdog({jobName: 'runner_probe'}), api = fixture.options.api;
  fixture.options.api = async (...args) => {
    const result = await api(...args);
    if (args[1].includes('/jobs?')) result.jobs[0].name = 'runner_probe';
    return result;
  };
  await watchQueuedJob(fixture.options);
  assert.equal(fixture.requests.at(-1).body.inputs.scope, 'runner');
});
test('running, completed, failed and approval-waiting jobs never dispatch fallback', async () => {
  for (const job of [{status: 'in_progress'}, {status: 'completed', conclusion: 'success'},
    {status: 'completed', conclusion: 'failure'}, {status: 'waiting'}]) {
    const fixture = watchdog({api: async () => ({total_count: 1, jobs: [{name: 'test', ...job}]})});
    assert.deepEqual(await watchQueuedJob(fixture.options), {action: 'job-active', status: job.status});
    assert.equal(fixture.sleeps.length, 0);
  }
});
test('a newly started job wins the last-moment queue recheck', async () => {
  const fixture = watchdog(), api = fixture.options.api;
  fixture.options.api = async (...args) => {
    const result = await api(...args);
    if (args[1].includes('/jobs?') && fixture.jobReads() === 11) result.jobs[0].status = 'in_progress';
    return result;
  };
  assert.deepEqual(await watchQueuedJob(fixture.options), {action: 'job-active', status: 'in_progress'});
  assert(!fixture.requests.some(r => r.method === 'POST'));
});
test('superseded main commits never dispatch or cancel newer work', async () => {
  const fixture = watchdog(), api = fixture.options.api;
  fixture.options.api = async (...args) => args[1].endsWith('/git/ref/heads/main') ? {object: {sha: 'b'.repeat(40)}} : api(...args);
  assert.deepEqual(await watchQueuedJob(fixture.options), {action: 'superseded', sha: 'b'.repeat(40)});
  assert(!fixture.requests.some(r => r.method === 'POST'));
});
test('the 90-second grace begins when the target appears, not before it is created', async () => {
  const fixture = watchdog(), api = fixture.options.api;
  fixture.options.api = async (...args) => {
    const result = await api(...args);
    return args[1].includes('/jobs?') && fixture.now() < 20_000 ? {total_count: 0, jobs: []} : result;
  };
  await watchQueuedJob(fixture.options);
  assert.equal(fixture.requests.at(-1).time, 110_000);
});
test('missing targets terminate after bounded polling without fallback', async () => {
  const fixture = watchdog({api: async () => ({total_count: 0, jobs: []})});
  assert.equal((await watchQueuedJob(fixture.options)).action, 'timed-out');
  assert.equal(fixture.now(), 300_000);
  assert.equal(fixture.sleeps.length, 30);
});
test('slow API reads cannot dispatch after the polling deadline', async () => {
  const fixture = watchdog(), api = fixture.options.api;
  fixture.options.api = async (...args) => { fixture.advance(300_000); return api(...args); };
  assert.equal((await watchQueuedJob(fixture.options)).action, 'timed-out');
  assert.equal(fixture.requests.length, 1);
});
test('hosted routes and untrusted events require no API requests or token', async () => {
  const api = async () => assert.fail('Hosted or untrusted watchdog must not make API requests');
  for (const override of [{preference: 'github'}, {eventName: 'pull_request'}, {ref: 'refs/heads/topic'}])
    assert.equal((await watchQueuedJob({...watchdog().options, ...override, api})).action, 'skipped');
  assert.equal((await main('watch', {environment: {GITHUB_EVENT_NAME: 'pull_request', GITHUB_REF: 'refs/pull/1/merge'}, output: () => {}})).action, 'skipped');
});
test('invalid job names and source identities fail before API requests', async () => {
  for (const override of [{jobName: 'deploy'}, {sha: 'main'}, {runID: ''}, {repository: '../repo'}])
    await assert.rejects(watchQueuedJob({...watchdog().options, ...override}), /WATCH_JOB_NAME|Valid repository/);
});
test('watch rejects non-finite timing bounds and a disappearing target never dispatches', async () => {
  for (const override of [{queueMilliseconds: Infinity}, {pollMilliseconds: 0}, {maxMilliseconds: NaN}])
    await assert.rejects(watchQueuedJob({...watchdog().options, ...override}), /timing bounds/);
  const fixture = watchdog(), api = fixture.options.api;
  fixture.options.api = async (...args) => {
    const result = await api(...args);
    return args[1].includes('/jobs?') && fixture.jobReads() === 11 ? {total_count: 0, jobs: []} : result;
  };
  assert.deepEqual(await watchQueuedJob(fixture.options), {action: 'job-active', status: 'missing'});
  assert(!fixture.requests.some(r => r.method === 'POST'));
});
test('job listing follows pagination and refuses ambiguous targets', async () => {
  const fixture = watchdog({api: async (_, resource) => ({total_count: 101,
    jobs: resource.endsWith('page=1') ? Array.from({length: 100}, (_, i) => ({name: `other${i}`, status: 'completed'}))
      : [{name: 'test', status: 'in_progress'}]})});
  assert.equal((await watchQueuedJob(fixture.options)).action, 'job-active');
  await assert.rejects(watchQueuedJob({...fixture.options, api: async () => ({total_count: 2,
    jobs: [{name: 'test', status: 'queued'}, {name: 'test', status: 'queued'}]})}), /Ambiguous/);
});
test('API failures and malformed jobs responses fail closed', async () => {
  await assert.rejects(watchQueuedJob({...watchdog().options, api: async () => { throw new Error('read failed'); }}), /read failed/);
  await assert.rejects(watchQueuedJob({...watchdog().options, api: async () => ({jobs: []})}), /invalid jobs/);
});

test('GitHub adapter sends ephemeral auth and accepts a successful dispatch once', async () => {
  const calls = [];
  const api = createGitHubAPI({token: 'synthetic-secret', fetch: async (url, options) => {
    calls.push({url, options}); return {ok: true, status: 204};
  }});
  assert.equal(await api('POST', '/dispatch', {ref: 'main'}), null);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].options.headers.authorization, 'Bearer synthetic-secret');
  assert.equal(calls[0].options.body, '{"ref":"main"}');
  assert(calls[0].options.signal instanceof AbortSignal);
});
test('ambiguous writes and error response bodies are never retried or logged', async () => {
  let calls = 0;
  const api = createGitHubAPI({token: 'synthetic-secret', fetch: async () => { calls++; throw new Error('synthetic-secret'); }});
  await assert.rejects(api('POST', '/dispatch', {}), error => /not retried/.test(error.message) && !error.message.includes('synthetic-secret'));
  assert.equal(calls, 1);
  const denied = createGitHubAPI({token: 'synthetic-secret', fetch: async () => ({ok: false, status: 403,
    json: () => assert.fail('Untrusted error bodies must not be printed')})});
  await assert.rejects(denied('GET', '/jobs'), /HTTP 403/);
});
test('GitHub GET decodes valid JSON and sanitizes malformed response diagnostics', async () => {
  const valid = createGitHubAPI({token: 'synthetic-secret', fetch: async () => ({ok: true, status: 200,
    json: async () => ({total_count: 0, jobs: []})})});
  assert.deepEqual(await valid('GET', '/jobs'), {total_count: 0, jobs: []});
  const malformed = createGitHubAPI({token: 'synthetic-secret', fetch: async () => ({ok: true, status: 200,
    json: async () => { throw new Error('bad body containing synthetic-secret'); }})});
  await assert.rejects(malformed('GET', '/jobs'), error => /invalid JSON/.test(error.message) && !error.message.includes('synthetic-secret'));
});
