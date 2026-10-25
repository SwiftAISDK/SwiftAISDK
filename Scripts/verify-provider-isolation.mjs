#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import catalogTools from './lib/catalog.cjs';
const data = catalogTools.readCatalog();
const destination = fs.mkdtempSync(path.join(os.tmpdir(), 'swift-ai-provider-isolation-'));
const variants = [
  ['AnthropicOnly', ['swift-ai-core', 'swift-ai-anthropic']],
  ['OpenAICompatibleOnly', ['swift-ai-core', 'swift-ai-openai-compatible']],
  ['OpenAIOnly', ['swift-ai-core', 'swift-ai-openai-compatible', 'swift-ai-openai']],
  ['MixedProviders', ['swift-ai-core', 'swift-ai-anthropic', 'swift-ai-openai-compatible', 'swift-ai-openai']],
];
const copy = (from, to) => fs.cpSync(from, to, {recursive: true, filter: p => !p.split(path.sep).some(s => ['.build','.swiftpm'].includes(s))});
function swift(args, cwd) {
  const result = spawnSync('swift', args, {cwd, encoding: 'utf8', maxBuffer: 64*1024*1024});
  if (result.status !== 0) throw new Error((result.stdout || '')+(result.stderr || ''));
  return result.stdout;
}
try {
  for (const [name, expected] of variants) {
    const workspace = path.join(destination, name);
    for (const id of expected) copy(path.join(data.root,'Packages',id), path.join(workspace,'Packages',id));
    const client = path.join(workspace,'Examples',name);
    copy(path.join(data.root,'Examples',name), client);
    const graph = JSON.parse(swift(['package','show-dependencies','--format','json'],client));
    const identities = new Set();
    function walk(node) { for (const dependency of node.dependencies) { identities.add(dependency.identity); walk(dependency); } }
    walk(graph);
    if (JSON.stringify([...identities].sort()) !== JSON.stringify([...expected].sort())) throw new Error('Unexpected dependency graph for '+name+': '+JSON.stringify([...identities]));
    const output = swift(['run','ProviderConsumer'],client);
    if (!output.includes(name.toUpperCase()+'_OK')) throw new Error('Missing consumer marker for '+name);
    process.stdout.write(output);
    console.log('ISOLATION VERIFIED: '+name+' -> '+[...identities].sort().join(', '));
  }
} finally { fs.rmSync(destination,{recursive:true,force:true}); }
