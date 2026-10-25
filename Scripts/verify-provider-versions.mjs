#!/usr/bin/env node
// Synthetic local Git tags verify SwiftPM constraints, not published releases.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import catalogTools from './lib/catalog.cjs';
import generator from './lib/generate.cjs';
const data = catalogTools.readCatalog();
const destination = fs.mkdtempSync(path.join(os.tmpdir(), 'swift-ai-version-fixtures-'));
const ids = ['swift-ai-core','swift-ai-anthropic','swift-ai-openai-compatible','swift-ai-openai'];
const urls = Object.fromEntries(ids.map(id => [id, pathToFileURL(path.join(destination,id)).href]));
const copy = (from,to) => fs.cpSync(from,to,{recursive:true,filter:p=>!p.split(path.sep).some(s=>['.build','.swiftpm'].includes(s))});
function run(command,args,cwd,expectFailure=false) {
  const result=spawnSync(command,args,{cwd,encoding:'utf8',maxBuffer:64*1024*1024});
  const output=(result.stdout||'')+(result.stderr||'');
  if(result.error) throw result.error;
  if(expectFailure ? result.status===0 : result.status!==0) throw new Error(`${command} ${args.join(' ')} exited ${result.status}\n${output}`);
  return output;
}
function commit(cwd,message) {run('git',['add','.'],cwd);run('git',['-c','user.name=Migration Fixture','-c','user.email=fixture@example.invalid','commit','-m',message],cwd);}
function tag(cwd,version) {run('git',['-c','user.name=Migration Fixture','-c','user.email=fixture@example.invalid','tag','-a',version,'-m','Synthetic resolver fixture '+version],cwd);}
function pins(client) {
  const value=JSON.parse(fs.readFileSync(path.join(client,'Package.resolved'),'utf8'));
  return Object.fromEntries(value.pins.map(pin=>[pin.identity,pin.state.version]));
}
function client(name,anthropicVersion,openAIVersion,coreVersion) {
  const cwd=path.join(destination,name);
  copy(path.join(data.root,'Examples/MixedProviders'),cwd);
  let manifest=fs.readFileSync(path.join(cwd,'Package.swift'),'utf8');
  for(const id of ['swift-ai-core','swift-ai-anthropic','swift-ai-openai']) {
    const requirement=id==='swift-ai-core' ? (coreVersion ? `exact: "${coreVersion}"` : 'from: "1.0.0"')
      : `exact: "${id==='swift-ai-anthropic' ? anthropicVersion : openAIVersion}"`;
    manifest=manifest.replace(`.package(path: "../../Packages/${id}")`,`.package(url: ${JSON.stringify(urls[id])}, ${requirement})`);
  }
  fs.writeFileSync(path.join(cwd,'Package.swift'),manifest);
  return cwd;
}
try {
  for(const id of ids) {
    const p=data.catalog.packages.find(p=>p.id===id),cwd=path.join(destination,id);
    copy(path.join(data.root,p.directory),cwd);
    let manifest=generator.manifest(data,p,{distribution:true});
    for(const dep of ids) manifest=manifest.replaceAll(data.catalog.packages.find(p=>p.id===dep).repository,urls[dep]);
    fs.writeFileSync(path.join(cwd,'Package.swift'),manifest);
    run('git',['init','-q'],cwd);commit(cwd,'Synthetic source snapshot for provider resolution');
    const versions=id==='swift-ai-core' ? ['1.0.0','1.1.0','2.0.0'] : id==='swift-ai-anthropic' ? ['1.1.0'] : id==='swift-ai-openai' ? ['1.3.0','1.4.0'] : ['1.0.0'];
    versions.forEach(v=>tag(cwd,v));
  }
  const mixed=client('MixedCompatible','1.1.0','1.3.0');
  run('swift',['package','resolve'],mixed);
  const first=pins(mixed);
  const expected={'swift-ai-core':'1.1.0','swift-ai-anthropic':'1.1.0','swift-ai-openai':'1.3.0','swift-ai-openai-compatible':'1.0.0'};
  for(const [id,version] of Object.entries(expected)) if(first[id]!==version) throw new Error('Unexpected pin '+id+': '+first[id]);
  const output=run('swift',['run','ProviderConsumer'],mixed);
  if(!output.includes('MIXEDPROVIDERS_OK')) throw new Error('Mixed consumer did not complete');
  console.log('MIXED COMPATIBLE',JSON.stringify(first));
  const manifest=path.join(mixed,'Package.swift');
  fs.writeFileSync(manifest,fs.readFileSync(manifest,'utf8').replace('exact: "1.3.0"','exact: "1.4.0"'));
  run('swift',['package','resolve'],mixed);
  const upgraded=pins(mixed);
  if(upgraded['swift-ai-anthropic']!=='1.1.0'||upgraded['swift-ai-openai']!=='1.4.0') throw new Error('Provider pin was not preserved');
  if(!run('swift',['run','ProviderConsumer'],mixed).includes('MIXEDPROVIDERS_OK')) throw new Error('Upgraded consumer did not complete');
  console.log('INDEPENDENT UPGRADE',JSON.stringify(upgraded));
  const lower=client('MinimumCore','1.1.0','1.3.0','1.0.0');
  run('swift',['package','resolve'],lower);
  if(pins(lower)['swift-ai-core']!=='1.0.0') throw new Error('Minimum core did not resolve');
  if(!run('swift',['run','ProviderConsumer'],lower).includes('MIXEDPROVIDERS_OK')) throw new Error('Minimum-core consumer did not complete');
  console.log('MINIMUM CORE',JSON.stringify(pins(lower)));
  const anthropic=path.join(destination,'swift-ai-anthropic');
  const anthManifest=path.join(anthropic,'Package.swift');
  fs.writeFileSync(anthManifest,fs.readFileSync(anthManifest,'utf8').replace('from: "1.0.0"','from: "2.0.0"'));
  commit(anthropic,'Synthetic incompatible core requirement');tag(anthropic,'2.0.0');
  const incompatible=client('IncompatibleCore','2.0.0','1.3.0');
  // Let the client accept either core major, so the conflict must arise between
  // provider requirements, rather than from the client's own constraint.
  const incompatibleManifest=path.join(incompatible,'Package.swift');
  fs.writeFileSync(incompatibleManifest,fs.readFileSync(incompatibleManifest,'utf8').replace(
    `.package(url: ${JSON.stringify(urls['swift-ai-core'])}, from: "1.0.0")`,
    `.package(url: ${JSON.stringify(urls['swift-ai-core'])}, "1.0.0"..<"3.0.0")`));
  const failure=run('swift',['package','resolve'],incompatible,true);
  if(!['swift-ai-core','swift-ai-anthropic','swift-ai-openai'].every(id=>failure.includes(id)) || !/dependenc|version|resolve/i.test(failure)) throw new Error('Resolution failed for an unrelated reason: '+failure);
  console.log('INCOMPATIBLE CORE REJECTED\n'+failure.trim());
  console.log('VERSION RESOLUTION VERIFIED: local synthetic tags; no published versions or release compatibility claimed');
} finally { fs.rmSync(destination,{recursive:true,force:true}); }
