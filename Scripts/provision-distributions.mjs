#!/usr/bin/env node
// Create only the new repositories selected by a reviewed release plan.
// During M7, suspend Actions before the first push and retain restoration data.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import catalog from './lib/catalog.cjs';
import release from './lib/release.cjs';
const { rootDefault: root, ensure, json } = catalog;
const [planFile, receiptFile] = process.argv.slice(2);
ensure(planFile && receiptFile && process.argv.length === 4, 'Usage: provision-distributions.mjs plan.json receipt.json');
const candidate = JSON.parse(fs.readFileSync(planFile)); release.validatePlan(root, candidate);
ensure(candidate.source.commit && !candidate.source.workingTree, 'Provision from committed release scope');
const organization = catalog.readCatalog(root).catalog.organization;
function api(endpoint, method = 'GET', input) {
  const args = ['api', '--method', method, endpoint];
  if (input) args.push('--input', '-');
  const r = spawnSync('gh', args, { cwd: root, input: input ? json(input) : undefined, encoding: 'utf8' });
  ensure(!r.error && r.status === 0, `GitHub ${method} ${endpoint} failed: ${r.stderr}`);
  return r.stdout.trim() ? JSON.parse(r.stdout) : null;
}
const file = path.resolve(receiptFile); fs.mkdirSync(path.dirname(file), { recursive: true });
let receipt;
if (fs.existsSync(file)) {
  receipt = JSON.parse(fs.readFileSync(file));
  ensure(receipt.sourceCommit === candidate.source.commit && receipt.planSHA256 === release.hash(json(candidate)), 'Provisioning receipt belongs to another plan');
} else {
  const existing = JSON.parse(release.run('gh', ['api', '--paginate', '--slurp', `orgs/${organization}/repos?per_page=100`], root)).flat();
  receipt = { schemaVersion: 1, status: 'in-progress', sourceCommit: candidate.source.commit,
    planSHA256: release.hash(json(candidate)), startedAt: new Date().toISOString(),
    restoreCondition: 'End of the overall migration goal, after M7 main work and local verification',
    repositories: candidate.packages.map(p => ({ name: `${organization}/${p.package}`,
      existedBefore: existing.some(r => r.full_name === `${organization}/${p.package}`), status: 'pending' })) };
  release.atomicJSON(file, receipt);
}
for (const item of receipt.repositories) {
  if (!item.existedBefore && item.status === 'pending') {
    item.status = 'creating'; release.atomicJSON(file, receipt);
    api(`orgs/${organization}/repos`, 'POST', { name: item.name.split('/')[1], private: false, auto_init: false,
      has_issues: false, has_projects: false, has_wiki: false,
      description: 'Generated Swift package distribution. Source, issues and contributions: SwiftAISDK/SwiftAISDK.',
      homepage: 'https://swiftaisdk.github.io/SwiftAISDK/' });
  }
  const repo = api(`repos/${item.name}`);
  ensure(repo.full_name === item.name && !repo.private && !repo.archived && repo.permissions?.admin && repo.default_branch === 'main', 'Unexpected destination repository');
  if (item.id) ensure(item.id === repo.id, 'Repository identity changed');
  item.id = repo.id;
  if (!item.existedBefore) {
    ensure(repo.description === 'Generated Swift package distribution. Source, issues and contributions: SwiftAISDK/SwiftAISDK.' &&
      Date.parse(repo.created_at) >= Date.parse(receipt.startedAt) - 1000, 'Unrecorded existing repository; inspect before adopting');
    if (!item.originalActionsPermissions) {
      item.originalActionsPermissions = api(`repos/${item.name}/actions/permissions`);
      release.atomicJSON(file, receipt);
    }
    api(`repos/${item.name}/actions/permissions`, 'PUT', { enabled: false });
    const current = api(`repos/${item.name}/actions/permissions`);
    ensure(current.enabled === false, 'Actions suspension failed');
    item.suspendedActionsPermissions = current;
  } else {
    const workflows = api(`repos/${item.name}/actions/workflows`);
    ensure(workflows.workflows.some(w => w.path === '.github/workflows/ci.yml' && w.state === 'disabled_manually'), 'Existing distribution CI must remain suspended');
  }
  item.status = 'ready-with-ci-suspended'; release.atomicJSON(file, receipt);
  console.log('DESTINATION READY: ' + item.name);
}
receipt.status = 'ready'; release.atomicJSON(file, receipt);
