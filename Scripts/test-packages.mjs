#!/usr/bin/env node
// Run every extracted test target, then the integration/compatibility aggregate.
import {spawnSync} from 'node:child_process';
import path from 'node:path';
import catalogTools from './lib/catalog.cjs';
import development from './lib/development.cjs';
const {readCatalog} = catalogTools;
const data = readCatalog();
const args = process.argv.slice(2), list = args.includes('--list');
if (list) args.splice(args.indexOf('--list'), 1);
if (args.length && (args.length !== 2 || args[0] !== '--packages'))
  throw new Error('Usage: node Scripts/test-packages.mjs [--packages id1,id2] [--list]');
const selected = args.length ? new Set(args[1].split(',').filter(Boolean)) : null;
if (selected) for (const id of selected)
  if (!data.catalog.packages.some(p => p.id === id && p.state === 'extracted')) throw new Error('Unknown extracted package: ' + id);
const packages = data.order.map(id => data.catalog.packages.find(p => p.id === id)).filter(p => p.state === 'extracted' && (!selected || selected.has(p.id)));
// Sequential roots share compiler outputs, but SwiftPM still plans each package
// and discovers only that root's test targets. Dependencies must not be tested
// merely by running the aggregate: SwiftPM does not do that automatically.
const scratch = path.join(data.root, '.build', 'package-test-workspace');
const commands = packages.map(p => ({package: p.id, args: ['test', '--package-path', p.directory, '--scratch-path', scratch, '--no-parallel']}));
commands.push({package: 'SwiftAISDK', args: ['test', '--package-path', development.prepare(data.root), '--scratch-path', scratch, '--no-parallel']});
if (list) {
  process.stdout.write(JSON.stringify(commands, null, 2) + '\n');
} else {
  for (const command of commands) {
    process.stdout.write(`\nTesting ${command.package}\n`);
    const result = spawnSync('swift', command.args, {cwd: data.root, stdio: 'inherit'});
    if (result.error) throw result.error;
    if (result.status !== 0) process.exit(result.status ?? 1);
  }
}
