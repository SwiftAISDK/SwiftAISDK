#!/usr/bin/env node
// Run every extracted test target, then the integration/compatibility aggregate.
import {spawnSync} from 'node:child_process';
import catalogTools from './lib/catalog.cjs';
const {readCatalog} = catalogTools;
const data = readCatalog();
const packages = data.order.map(id => data.catalog.packages.find(p => p.id === id)).filter(p => p.state === 'extracted');
const commands = packages.map(p => ({package: p.id, args: ['test', '--package-path', p.directory, '--no-parallel']}));
commands.push({package: 'SwiftAISDK', args: ['test', '--no-parallel']});
if (process.argv.includes('--list')) {
  process.stdout.write(JSON.stringify(commands, null, 2) + '\n');
} else {
  if (process.argv.length !== 2) throw new Error('Usage: node Scripts/test-packages.mjs [--list]');
  for (const command of commands) {
    process.stdout.write(`\nTesting ${command.package}\n`);
    const result = spawnSync('swift', command.args, {cwd: data.root, stdio: 'inherit'});
    if (result.error) throw result.error;
    if (result.status !== 0) process.exit(result.status ?? 1);
  }
}
