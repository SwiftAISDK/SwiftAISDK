#!/usr/bin/env python3
"""Compare M0 symbol identities after intentional module moves (not ABI validation).

First dump graphs with `swift package dump-symbol-graph --minimum-access-level
internal` in the root and every extracted package. This is an opt-in migration
check, not a replacement for normal-import consumer and behavior tests.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, help='Save JSON report; baseline is never modified')
args = parser.parse_args()
baseline = [json.loads(line) for line in (ROOT / 'Docs/Migration/M0/public-symbols.jsonl').read_text().splitlines()]
catalog = json.loads((ROOT / 'Porting/packages.json').read_text())
packages = [(ROOT, ['SwiftAISDK'])] + [
    (ROOT / p['directory'], [m['name'] for m in p['modules']])
    for p in catalog['packages'] if p['state'] == 'extracted'
]
modules = {m for _, names in packages for m in names}
current = {}
all_current = {}
for package, names in packages:
    # SwiftPM Xcode and native build systems use different build directories.
    paths = [p for p in (package / '.build').glob('**/symbolgraph/*.symbols.json')
             if not any(part.startswith('migration-') for part in p.relative_to(package).parts)]
    found = set()
    for path in paths:
        graph = json.loads(path.read_text())
        module = graph['module']['name']
        if module not in names:
            continue
        found.add(module)
        for symbol in graph['symbols']:
            all_current[symbol['identifier']['precise']] = symbol
            if symbol.get('accessLevel') == 'public':
                current[symbol['identifier']['precise']] = symbol
    if found != set(names):
        parser.error(f'Missing runtime graphs in {package}: {set(names) - found}')

# Mangling substitutions change when a referenced type moves to another module.
# Demangle each side of synthesized IDs before normalizing module qualifiers.
identifiers = [row['usr'] for row in baseline] + list(all_current)
parts = sorted({p for u in identifiers for p in u.split('::') if p != 'SYNTHESIZED'})
mangled = [('$s' + p[2:]) if p.startswith('s:') else p for p in parts]
lines = subprocess.check_output(['xcrun', 'swift-demangle', '--compact'],
    input='\n'.join(mangled) + '\n', text=True).splitlines()
if len(lines) != len(parts):
    parser.error('Unexpected demangler output')
module_pattern = '|'.join(re.escape(m) for m in sorted(modules, key=len, reverse=True))
def normalize(text):
    text = re.sub(r'\(extension in (' + module_pattern + r')\):', '', text)
    return re.sub(r'\b(?:' + module_pattern + r')\.', '', text)
lookup = dict(zip(parts, map(normalize, lines)))
def key(identifier):
    return '::'.join(lookup.get(p, p) for p in identifier.split('::'))
current_keys = {key(u) for u in current}
baseline_keys = {key(row['usr']) for row in baseline}
current_declarations = {key(u): symbol for u, symbol in all_current.items()}
unmatched = [dict(row, normalized=key(row['usr'])) for row in baseline if key(row['usr']) not in current_keys]
missing, nonpublic_synthesized = [], []
for row in unmatched:
    # With minimum-access=internal, Swift also labels protocol convenience
    # members synthesized on an internal conformer as public. Such a conformer
    # was never a public nominal declaration in M0. Keep the discrepancy visible
    # without promoting an implementation detail merely to reproduce that graph.
    parent = row['usr'].split('::SYNTHESIZED::', 1)
    declaration = current_declarations.get(key(parent[1])) if len(parent) == 2 else None
    if (declaration and key(parent[1]) not in baseline_keys
            and declaration.get('accessLevel') in ('internal', 'fileprivate', 'private')):
        nonpublic_synthesized.append(dict(row, currentParentAccess=declaration['accessLevel'],
            reason='Synthesized convenience on a non-public nominal type; parent absent from M0 public declarations and still non-public.'))
    else:
        missing.append(row)
report = {
    'baselinePublicSymbols': len(baseline),
    'currentPublicSymbols': len(current),
    'matchedBaselineSymbols': len(baseline) - len(unmatched),
    'nonPublicSynthesizedMembers': nonpublic_synthesized,
    'unmatchedBaselineSymbols': missing,
    'comparison': 'Compiler public symbols with runtime module qualifiers normalized. Unmatched convenience members on non-public conformers are recorded separately, never silently discarded. Not an ABI guarantee.',
}
if args.output:
    args.output.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k not in ['unmatchedBaselineSymbols', 'nonPublicSynthesizedMembers', 'comparison']}
    | {'unmatchedBaselineSymbols': len(missing), 'nonPublicSynthesizedMembers': len(nonpublic_synthesized)}, indent=2))
raise SystemExit(1 if missing else 0)
