#!/usr/bin/env node
// Copies only the independently consumable core and its client outside this repo.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root = fileURLToPath(new URL('..', import.meta.url));
const destination = fs.mkdtempSync(path.join(os.tmpdir(), 'swift-ai-core-isolation-'));
function run(args, cwd) {
  const result = spawnSync('swift', args, {cwd, encoding:'utf8', maxBuffer:32*1024*1024});
  if (result.status !== 0) throw new Error((result.stdout ?? '') + (result.stderr ?? ''));
  return result.stdout;
}
try {
  fs.cpSync(path.join(root,'Packages/swift-ai-core'),path.join(destination,'swift-ai-core'), {
    recursive:true, filter: p => !p.split(path.sep).some(s => ['.build','.swiftpm'].includes(s))
  });
  const client=path.join(destination,'CoreConsumer');
  fs.cpSync(path.join(root,'Examples/CoreOnly'),client, {recursive:true,filter:p=>!p.split(path.sep).some(s=>['.build','.swiftpm'].includes(s))});
  const manifest=path.join(client,'Package.swift');
  fs.writeFileSync(manifest, fs.readFileSync(manifest,'utf8').replace('../../Packages/swift-ai-core','../swift-ai-core'));
  const graph=JSON.parse(run(['package','show-dependencies','--format','json'],client));
  if(graph.dependencies.length !== 1 || graph.dependencies[0].identity !== 'swift-ai-core' || graph.dependencies[0].dependencies.length !== 0) throw new Error('Unexpected dependency graph: '+JSON.stringify(graph));
  process.stdout.write(run(['run','CoreConsumer'],client));
  console.log('ISOLATION VERIFIED: a standalone copy, no aggregate sources, one dependency, zero external core dependencies');
} finally {
  fs.rmSync(destination,{recursive:true,force:true});
}
