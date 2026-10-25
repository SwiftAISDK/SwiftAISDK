// Select CI work from changed paths; package dependencies come from the catalog.
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const {readCatalog} = require('./lib/catalog.cjs');

function plan(files, data, scope = '') {
  const selected = new Set();
  let swift = scope === 'all', docs = Boolean(scope), tools = scope === 'all';
  const all = () => data.catalog.packages.filter(p => p.state === 'extracted').forEach(p => selected.add(p.id));
  if (swift) all();
  for (const file of files) {
    const packageCode = /^Packages\/([^/]+)\/(Sources\/|Tests\/|Package\.swift$)/.exec(file);
    const common = /^(Package\.swift|Porting\/packages\.json|Scripts\/lib\/(development|generate)\.cjs)$/.test(file);
    if (packageCode) {
      swift = true;
      if (data.catalog.packages.some(p => p.id === packageCode[1] && p.state === 'extracted')) selected.add(packageCode[1]);
      else all();
    }
    if (/^(Sources|Tests|Examples)\//.test(file)) swift = true;
    if (common) { swift = true; all(); }
    if (/^(Scripts|Porting|Releases)\//.test(file) || file.startsWith('.github/')) tools = true;
    if (/^(docs-site\/|Docs\/Migration\.md$|Porting\/(packages|upstream-lock)\.json$|Sources\/|Packages\/[^/]+\/Sources\/)/.test(file) || file === '.github/workflows/docs.yml' || common) docs = true;
  }
  for (const id of data.order) {
    const p = data.catalog.packages.find(p => p.id === id);
    if (p.state === 'extracted' && p.dependencies.some(d => selected.has(d.package))) selected.add(id);
  }
  return {swift, docs, tools, packages: data.order.filter(id => selected.has(id)).join(',')};
}

if (require.main === module) {
  const event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const git = args => execFileSync('git', args, {encoding: 'utf8'}).trim();
  let files = [], scope = '';
  if (process.env.GITHUB_EVENT_NAME === 'workflow_dispatch') scope = event.inputs?.scope || 'all';
  else {
    const base = event.pull_request?.base.sha || event.before;
    if (!base || /^0+$/.test(base)) scope = 'all';
    else files = git(['diff', '--name-only', '--no-renames', base, 'HEAD']).split('\n').filter(Boolean);
  }
  const result = plan(files, readCatalog(), scope);
  fs.appendFileSync(process.env.GITHUB_OUTPUT, Object.entries(result).map(([k,v]) => `${k}=${v}\n`).join(''));
  console.log(JSON.stringify(result, null, 2));
}
module.exports = {plan};
