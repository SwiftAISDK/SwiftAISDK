#!/usr/bin/env node
// The user-authorized temporary M7 publication gate. Output/logs stay outside Git.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import catalog from './lib/catalog.cjs';
import release from './lib/release.cjs';
import local from './lib/local-verification.cjs';
const { rootDefault: root, ensure, json } = catalog;
const [outputArg] = process.argv.slice(2);
ensure(outputArg && process.argv.length === 3, 'Usage: verify-local-migration.mjs new-report.json');
const output = path.resolve(outputArg), directory = output.replace(/\.json$/, '') + '.logs';
ensure(!fs.existsSync(output) && !fs.existsSync(directory), 'Verification output already exists');
ensure(release.git(['status', '--porcelain'], root) === '', 'Commit the verified source before the local publication gate');
const sourceCommit = release.git(['rev-parse', 'HEAD'], root);
const sdk = release.run('xcrun', ['--sdk', 'iphonesimulator', '--show-sdk-path'], root);
fs.mkdirSync(directory, { recursive: true });
const commands = [
  ['catalog', 'node', ['Scripts/sdk.mjs', 'generate', '--check']],
  ['tooling', 'node', ['--test', ...fs.readdirSync(path.join(root, 'Scripts/tests')).filter(f => f.endsWith('.test.cjs')).sort().map(f => 'Scripts/tests/' + f)]],
  ['all-source-tests', 'node', ['Scripts/test-packages.mjs']],
  ['distributions', 'node', ['Scripts/verify-package-distributions.mjs', '--report', path.join(directory, 'distributions.json')]],
  ['maintenance', 'node', ['Scripts/verify-maintenance-rehearsal.mjs', '--report', path.join(directory, 'maintenance.json')]],
  ['ios', 'node', ['Scripts/sdk.mjs', 'dev', 'build', '--triple', 'arm64-apple-ios15.0-simulator', '--sdk', sdk, '--scratch-path', path.join(root, '.build/ios-verification')]],
  ['examples', 'node', ['Scripts/sdk.mjs', 'dev', 'examples', 'build']],
  ['oauth', 'node', ['Scripts/sdk.mjs', 'dev', 'examples', 'run', 'MCPOAuthMigration']],
  ['docs-install', 'npm', ['ci', '--prefix', 'docs-site']],
  ['docs-check', 'npm', ['--prefix', 'docs-site', 'run', 'check']],
  ['docs-build', 'npm', ['--prefix', 'docs-site', 'run', 'build']],
];
ensure(json(commands.map(c => c[0])) === json(local.required), 'Local gate command list drifted');
const receipt = { schemaVersion: 1, kind: 'local-migration-verification', status: 'in-progress',
  sourceCommit, sourceTree: release.git(['rev-parse', 'HEAD^{tree}'], root),
  policy: 'Docs/Migration/M6/ci-budget-policy.json', swiftVersion: release.run('swift', ['--version'], root), checks: [] };
for (const [name, cmd, argv] of commands) {
  console.log('VERIFYING: ' + name);
  const logFile = path.join(directory, name + '.log'), fd = fs.openSync(logFile, 'w');
  const r = spawnSync(cmd, argv, { cwd: root, stdio: ['ignore', fd, fd],
    env: { ...process.env, DOCS_BASE: '/SwiftAISDK', DOCS_SITE: 'https://swiftaisdk.github.io' } });
  fs.closeSync(fd);
  const log = fs.readFileSync(logFile);
  receipt.checks.push({ name, command: [cmd, ...argv], exitCode: r.status, log: logFile, logSHA256: release.hash(log),
    summaries: log.toString().split('\n').filter(s => /Test run with|Build complete|ALL DISTRIBUTIONS|MAINTENANCE_REHEARSAL_OK|MCP_OAUTH|pages? built|errors?|warnings?/.test(s)).slice(-65) });
  fs.writeFileSync(output + '.pending.json', json(receipt));
  ensure(!r.error && r.status === 0, `${name} failed; inspect ${logFile}`);
  ensure(release.git(['rev-parse', 'HEAD'], root) === sourceCommit && release.git(['status', '--porcelain'], root) === '', 'Source changed during verification');
  console.log('PASSED: ' + name);
}
receipt.status = 'passed'; fs.writeFileSync(output, json(receipt));
local.verify(root, output, sourceCommit);
console.log('LOCAL_MIGRATION_VERIFIED: ' + sourceCommit);
