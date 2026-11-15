#!/usr/bin/env node
// Prefer the dedicated M3 for trusted main runs; a queued job can fall back once.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

const M3_LABELS = ['self-hosted', 'macOS', 'ARM64', 'swift-ai-m3'];
const HOSTED_LABELS = ['macos-26'];
const DEFAULT_MACOS_SDKROOT = '/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk';

function selectRunner({eventName, ref, preference = 'auto'} = {}) {
  const trusted = ['push', 'workflow_dispatch'].includes(eventName) && ref === 'refs/heads/main';
  return trusted && preference !== 'github'
    ? {labels: [...M3_LABELS], kind: 'm3'}
    : {labels: [...HOSTED_LABELS], kind: 'github'};
}

function prepareToolchain({environment = process.env, home = os.homedir(), run = execFileSync,
  defaultSDKRoot = DEFAULT_MACOS_SDKROOT} = {}) {
  if (environment.RUNNER_ENVIRONMENT !== 'self-hosted') return {kind: 'github', prepared: false};
  if (!environment.GITHUB_PATH || !environment.GITHUB_ENV) throw new Error('GITHUB_PATH and GITHUB_ENV are required.');
  const directory = path.join(home, 'Library/Developer/Toolchains');
  const candidates = fs.readdirSync(directory, {withFileTypes: true})
    .filter(entry => entry.isDirectory() && entry.name.includes('6.3.3') && entry.name.endsWith('.xctoolchain'))
    .map(entry => path.join(directory, entry.name)).sort();
  const verified = candidates.filter(toolchain => {
    const version = run(path.join(toolchain, 'usr/bin/swift'), ['--version'], {encoding: 'utf8'});
    return /\bSwift version 6\.3\.3(?=\s|$)/.test(version);
  });
  if (verified.length !== 1) throw new Error(`Expected one Swift 6.3.3 toolchain; found ${verified.length}.`);
  const toolchain = verified[0];
  const bundleID = run('/usr/bin/plutil', ['-extract', 'CFBundleIdentifier', 'raw', '-o', '-', path.join(toolchain, 'Info.plist')],
    {encoding: 'utf8'}).trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9.-]*$/.test(bundleID) || /[\r\n]/.test(toolchain)) throw new Error('Invalid toolchain path or bundle identifier.');
  const sdkRoot = environment.SWIFT_M3_MACOS_SDKROOT || defaultSDKRoot;
  if (!path.isAbsolute(sdkRoot) || /[\r\n]/.test(sdkRoot) || !fs.statSync(sdkRoot).isDirectory())
    throw new Error('SWIFT_M3_MACOS_SDKROOT must identify an existing absolute macOS SDK directory.');
  const sdk = JSON.parse(fs.readFileSync(path.join(sdkRoot, 'SDKSettings.json'), 'utf8'));
  if (typeof sdk.CanonicalName !== 'string' || !/^macosx\d/.test(sdk.CanonicalName)) throw new Error('Expected a macOS SDK manifest.');
  // The installed Xcode SDK can be newer than this pinned compiler. Verify the
  // actual compiler/SDK pair, including CryptoKit, before exporting either.
  run(path.join(toolchain, 'usr/bin/swiftc'), ['-sdk', sdkRoot, '-typecheck', '-'], {
    encoding: 'utf8', input: 'import Foundation\nimport CryptoKit\n',
    env: {...environment, TOOLCHAINS: bundleID, SDKROOT: sdkRoot},
  });
  fs.appendFileSync(environment.GITHUB_PATH, `${path.join(toolchain, 'usr/bin')}\n`);
  fs.appendFileSync(environment.GITHUB_ENV, `TOOLCHAINS=${bundleID}\nSDKROOT=${sdkRoot}\n`);
  return {kind: 'm3', prepared: true, toolchain, bundleID, sdkRoot};
}

function createGitHubAPI({token, apiURL = 'https://api.github.com', fetch: fetchAPI = globalThis.fetch} = {}) {
  if (!token) throw new Error('GH_TOKEN is required for the queue watchdog.');
  return async function api(method, resource, body) {
    let response;
    try {
      response = await fetchAPI(`${apiURL.replace(/\/$/, '')}${resource}`, {
        method,
        headers: {accept: 'application/vnd.github+json', authorization: `Bearer ${token}`,
          'x-github-api-version': '2022-11-28', ...(body === undefined ? {} : {'content-type': 'application/json'})},
        ...(body === undefined ? {} : {body: JSON.stringify(body)}),
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      // A dispatch may have reached GitHub even when its response was lost.
      // Never retry writes, or include credentials/server diagnostics in logs.
      throw new Error(`GitHub ${method} ${resource} failed; request was not retried.`);
    }
    if (!response.ok) throw new Error(`GitHub ${method} ${resource} returned HTTP ${response.status}; request was not retried.`);
    try { return response.status === 204 ? null : await response.json(); }
    catch { throw new Error(`GitHub ${method} ${resource} returned invalid JSON; request was not retried.`); }
  };
}

async function listRunJobs(api, repository, runID) {
  const jobs = [];
  for (let page = 1; page <= 10; page++) {
    const result = await api('GET', `/repos/${repository}/actions/runs/${runID}/jobs?filter=latest&per_page=100&page=${page}`);
    if (!Array.isArray(result.jobs) || !Number.isSafeInteger(result.total_count) || result.total_count < 0)
      throw new Error('GitHub returned an invalid jobs response.');
    jobs.push(...result.jobs);
    if (jobs.length >= result.total_count || result.jobs.length === 0) return jobs;
  }
  throw new Error('Run jobs pagination exceeded the bounded limit.');
}

function targetJob(jobs, name) {
  const matching = jobs.filter(job => job.name === name);
  if (matching.length > 1) throw new Error(`Ambiguous watchdog target job: ${name}.`);
  return matching[0];
}

async function watchQueuedJob({api, repository, runID, sha, eventName, ref, preference = 'auto', jobName = 'test',
  now = () => performance.now(), sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds)),
  queueMilliseconds = 90_000, pollMilliseconds = 10_000, maxMilliseconds = 300_000} = {}) {
  if (selectRunner({eventName, ref, preference}).kind !== 'm3') return {action: 'skipped', reason: 'hosted-route'};
  if (!/^[A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9_.-]+$/.test(repository || '') ||
      ['.', '..'].includes(repository?.split('/')[1]) || !/^[1-9]\d*$/.test(String(runID || '')) ||
      !/^[a-f0-9]{40}$/i.test(sha || '')) throw new Error('Valid repository, run ID and source SHA are required.');
  if (!['test', 'runner_probe'].includes(jobName)) throw new Error('WATCH_JOB_NAME must be test or runner_probe.');
  if (![queueMilliseconds, pollMilliseconds, maxMilliseconds].every(Number.isFinite) ||
      !(queueMilliseconds >= 0 && pollMilliseconds > 0 && maxMilliseconds > queueMilliseconds)) throw new Error('Invalid watchdog timing bounds.');
  const deadline = now() + maxMilliseconds;
  class PollingTimeout extends Error {}
  const request = async (method, ...args) => {
    if (now() >= deadline) throw new PollingTimeout();
    const result = await api(method, ...args);
    if (method === 'GET' && now() >= deadline) throw new PollingTimeout();
    return result;
  };
  let queuedAt;
  const maxPolls = Math.ceil(maxMilliseconds / pollMilliseconds) + 1;
  try {
    for (let poll = 0; poll < maxPolls && now() < deadline; poll++) {
      const job = targetJob(await listRunJobs(request, repository, runID), jobName);
      if (job && job.status !== 'queued') return {action: 'job-active', status: job.status};
      if (!job) queuedAt = undefined;
      else if (queuedAt === undefined) queuedAt = now();
      if (job && now() - queuedAt >= queueMilliseconds) {
        const head = await request('GET', `/repos/${repository}/git/ref/heads/main`);
        if (head.object?.sha !== sha) return {action: 'superseded', sha: head.object?.sha};
        const fresh = targetJob(await listRunJobs(request, repository, runID), jobName);
        if (!fresh || fresh.status !== 'queued') return {action: 'job-active', status: fresh?.status || 'missing'};
        const inputs = {scope: jobName === 'runner_probe' ? 'runner' : 'all', runner: 'github', fallback_from: String(runID)};
        await request('POST', `/repos/${repository}/actions/workflows/docs.yml/dispatches`, {ref: 'main', inputs});
        return {action: 'fallback-dispatched', sourceRunID: String(runID), sha, jobName, inputs};
      }
      const remaining = deadline - now();
      if (remaining > 0) await sleep(Math.min(pollMilliseconds, remaining));
    }
  } catch (error) { if (!(error instanceof PollingTimeout)) throw error; }
  return {action: 'timed-out', reason: 'target-not-queued-long-enough'};
}

async function main(command, {environment = process.env, output = console.log, ...dependencies} = {}) {
  if (command === 'select') {
    const selection = selectRunner({eventName: environment.GITHUB_EVENT_NAME, ref: environment.GITHUB_REF,
      preference: environment.RUNNER_PREFERENCE || 'auto'});
    if (!environment.GITHUB_OUTPUT) throw new Error('GITHUB_OUTPUT is required.');
    fs.appendFileSync(environment.GITHUB_OUTPUT, `labels=${JSON.stringify(selection.labels)}\nkind=${selection.kind}\n`);
    output(JSON.stringify(selection));
    return selection;
  }
  if (command === 'prepare') {
    const prepared = prepareToolchain({environment, ...dependencies});
    output(JSON.stringify(prepared));
    return prepared;
  }
  if (command === 'watch') {
    const route = selectRunner({eventName: environment.GITHUB_EVENT_NAME, ref: environment.GITHUB_REF,
      preference: environment.RUNNER_PREFERENCE || 'auto'});
    const result = await watchQueuedJob({repository: environment.GITHUB_REPOSITORY, runID: environment.GITHUB_RUN_ID,
      sha: environment.GITHUB_SHA, eventName: environment.GITHUB_EVENT_NAME, ref: environment.GITHUB_REF,
      preference: environment.RUNNER_PREFERENCE || 'auto', jobName: environment.WATCH_JOB_NAME || 'test',
      api: dependencies.api || (route.kind === 'm3' ? createGitHubAPI({token: environment.GH_TOKEN, apiURL: environment.GITHUB_API_URL}) : undefined), ...dependencies});
    output(JSON.stringify(result));
    if (result.action === 'timed-out') throw new Error('Queue watchdog reached its polling bound without a safe fallback.');
    return result;
  }
  throw new Error('Usage: node Scripts/m3-runner.cjs select|prepare|watch');
}

if (require.main === module) main(process.argv[2]).catch(error => { console.error(error.message); process.exitCode = 1; });
module.exports = {selectRunner, prepareToolchain, createGitHubAPI, watchQueuedJob, main, DEFAULT_MACOS_SDKROOT};
