#!/usr/bin/env python3
"""Generate/check the frozen M0 ownership audit, not the future release catalog.

First run `swift package dump-symbol-graph --minimum-access-level internal`.
Then run this script with --write; --check verifies current inputs and outputs.
Only standard-library Python is required. No networking or Swift source edits.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Docs/Migration/M0"
CONTRACTS = "swift-ai-core/SwiftAIProvider"
FACADE = "swift-ai-core/SwiftAI"
UI = "swift-ai-ui/SwiftAIUI"
INTEGRATION = "workspace/IntegrationTests"
TEST_SUPPORT = "workspace/TestSupport"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encode(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def table(document, first_header):
    lines = document.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith(first_header))
    result = []
    for line in lines[start + 2:]:
        if not line.startswith("|"):
            break
        result.append([cell.strip().replace("`", "") for cell in
                       re.split(r"(?<!\\)\|", line)[1:-1]])
    return result


def inventory(graph_dir):
    ownership = json.loads((OUT / "ownership.json").read_text())
    rules = ownership["files"]
    modules = set(ownership["modules"])
    sources = {str(p.relative_to(ROOT)) for p in
               (ROOT / "Sources").rglob("*.swift")}
    if sources != set(rules):
        raise ValueError(f"Source ownership mismatch: unowned={sorted(sources-set(rules))}; "
                         f"missing={sorted(set(rules)-sources)}")
    for path, rule in rules.items():
        if rule["default"] not in modules:
            raise ValueError(f"Unknown module in {path}")
        previous_end = 0
        for span in sorted(rule["ranges"], key=lambda r: r["start"]):
            if not (previous_end < span["start"] <= span["end"]):
                raise ValueError(f"Overlapping/invalid split in {path}: {span}")
            if span["owner"] not in modules:
                raise ValueError(f"Unknown split module in {path}: {span}")
            previous_end = span["end"]

    def owner_at(path, line):
        rule = rules[path]
        for span in rule["ranges"]:
            if span["start"] <= line <= span["end"]:
                return span["owner"]
        return rule["default"]

    graphs = sorted(graph_dir.glob("SwiftAISDK*.symbols.json"))
    if not graphs:
        raise ValueError(f"No compiler symbol graphs in {graph_dir}")
    symbols, relationships, graph_hashes = {}, [], {}
    for path in graphs:
        graph = json.loads(path.read_bytes())
        # Swift emits arrays in unspecified order and absolute source URLs.
        # Freeze semantic content so the same toolchain can verify another checkout.
        normalized = json.loads(json.dumps(graph))
        for symbol in normalized["symbols"]:
            if "location" in symbol:
                source = Path(unquote(urlparse(symbol["location"]["uri"]).path))
                symbol["location"]["uri"] = str(source.relative_to(ROOT))
        normalized["symbols"].sort(key=lambda s: s["identifier"]["precise"])
        normalized["relationships"].sort(key=lambda r: json.dumps(r, sort_keys=True))
        graph_hashes[path.name] = digest(encode(normalized).encode())
        for symbol in graph["symbols"]:
            symbols[symbol["identifier"]["precise"]] = symbol
        relationships.extend(graph["relationships"])
    if not any(s["accessLevel"] == "internal" for s in symbols.values()):
        raise ValueError("Internal symbol graph required for signature boundary analysis")
    parents = {r["source"]: r["target"] for r in relationships
               if r["kind"] == "memberOf"}

    def location(usr, seen=None):
        seen = set() if seen is None else seen
        if usr in seen or usr not in symbols:
            raise ValueError(f"Cannot resolve source location for {usr}")
        seen.add(usr)
        s = symbols[usr]
        if "location" in s:
            path = Path(unquote(urlparse(s["location"]["uri"]).path))
            return str(path.relative_to(ROOT)), s["location"]["position"]["line"] + 1, False
        parent = parents.get(usr)
        if parent is None and "::SYNTHESIZED::" in usr:
            parent = usr.split("::SYNTHESIZED::", 1)[1]
        if not parent:
            raise ValueError(f"Unlocated symbol lacks owning nominal: {usr}")
        path, line, _ = location(parent, seen)
        return path, line, True

    resolved = {}
    for usr, s in symbols.items():
        path, line, inherited_location = location(usr)
        if path not in rules:
            raise ValueError(f"Unowned compiler symbol at {path}:{line}")
        resolved[usr] = {
            "usr": usr,
            "name": ".".join(s["pathComponents"]),
            "kind": s["kind"]["identifier"],
            "source": path,
            "line": line,
            "owner": owner_at(path, line),
            "locationFromParent": inherited_location,
            "access": s["accessLevel"],
            "declaration": "".join(f["spelling"] for f in s.get("declarationFragments", [])),
        }
    public = sorted((s for s in resolved.values() if s["access"] in ("public", "open")),
                    key=lambda s: (s["source"], s["line"], s["usr"]))
    type_owners = defaultdict(set)
    for usr, s in symbols.items():
        if len(s["pathComponents"]) == 1 and s["kind"]["identifier"] in (
                "swift.struct", "swift.class", "swift.enum", "swift.protocol", "swift.typealias"):
            type_owners[s["pathComponents"][0]].add(resolved[usr]["owner"])

    # Compiler-resolved signature dependencies, never claimed to cover function bodies.
    edges = defaultdict(list)
    type_relationships = defaultdict(set)
    for relationship in relationships:
        if relationship["kind"] in ("conformsTo", "inheritsFrom"):
            type_relationships[relationship["source"]].add(relationship["target"])
    for usr, s in symbols.items():
        origin = resolved[usr]
        refs = {fragment.get("preciseIdentifier") for fragment in s.get("declarationFragments", [])}
        refs.update(type_relationships[usr])
        for ref in refs:
            if ref not in resolved or ref == usr:
                continue
            target = resolved[ref]
            if origin["owner"] != target["owner"]:
                edges[(origin["owner"], target["owner"])].append({
                    "symbol": origin["name"], "source": origin["source"],
                    "line": origin["line"], "references": target["name"],
                })
    edge_rows = [{"from": a, "to": b, "references": sorted(v, key=lambda r:
                  (r["source"], r["line"], r["symbol"], r["references"]))}
                 for (a, b), v in sorted(edges.items())]
    adjacency = defaultdict(set)
    for a, b in edges:
        adjacency[a].add(b)
    # Tarjan strongly connected components of proposed ownership, not current Swift modules.
    index, stack, active, indices, lows, cycles = 0, [], set(), {}, {}, []

    def visit(v):
        nonlocal index
        indices[v] = lows[v] = index
        index += 1
        stack.append(v)
        active.add(v)
        for w in sorted(adjacency[v]):
            if w not in indices:
                visit(w)
                lows[v] = min(lows[v], lows[w])
            elif w in active:
                lows[v] = min(lows[v], indices[w])
        if lows[v] == indices[v]:
            component = []
            while True:
                w = stack.pop()
                active.remove(w)
                component.append(w)
                if w == v:
                    break
            if len(component) > 1:
                cycles.append(sorted(component))
    for v in sorted(modules):
        if v not in indices:
            visit(v)

    ledger_text = (ROOT / "Docs/ProviderVersionLedger.md").read_text()
    upstream = []
    for line in ledger_text.splitlines():
        m = re.match(r"\| `(@ai-sdk/[^`]+)` \| `([^`]+)` \| (.+) \|$", line)
        if m:
            slug = m[1].removeprefix("@ai-sdk/")
            upstream.append({"npm": m[1], "baseline": m[2],
                             "destinations": [ownership["providerModules"][slug]],
                             "disposition": "preserve-reviewed-provider-surface-and-known-gaps",
                             "existingEvidence": m[3]})
    core = (ROOT / "Docs/CoreV6Parity.md").read_text().split("snapshots, currently ", 1)[1].split("References:", 1)[0]
    for spec in re.findall(r"`([^`]+)`", core):
        name, version = spec.rsplit("@", 1)
        destinations = {
            "ai": [FACADE, UI], "@ai-sdk/provider": [CONTRACTS],
            "@ai-sdk/provider-utils": ["swift-ai-core/SwiftAIProviderUtilities", "swift-ai-core/SwiftAITransport"],
            "@ai-sdk/react": [UI],
        }[name]
        upstream.append({"npm": name, "baseline": version, "destinations": destinations,
                         "disposition": "React runtime remains out of scope; preserve native UI mapping" if name == "@ai-sdk/react" else "preserve-reviewed-core-surface-and-known-gaps",
                         "existingEvidence": "Docs/CoreV6Parity.md"})
    if len({p["npm"] for p in upstream}) != len(upstream):
        raise ValueError("Duplicate upstream package ownership")
    if len(upstream) != 54:
        raise ValueError("M0 must account for the 54 frozen upstream entries")
    matrix_text = (ROOT / "Docs/ProviderCapabilityMatrix.md").read_text()
    matrix_rows = table(matrix_text, "| Upstream package | Provider ID |")
    notes = dict(table(matrix_text, "| Provider ID | Note |"))
    header = next(l for l in matrix_text.splitlines() if l.startswith("| Upstream package | Provider ID |"))
    headers = [s.strip() for s in header.split("|")[1:-1]]
    capabilities = []
    factory_owners = {}
    for values in matrix_rows:
        row = dict(zip(headers, values))
        slug = row["Upstream package"].removeprefix("@ai-sdk/")
        owner = ownership["providerModules"][slug]
        for factory in re.findall(r"AIProviders\.(\w+)", values[2]):
            factory_owners[factory] = owner
        capabilities.append({"owner": owner, "current": row,
                             "existingBehaviorAndGaps": notes.get(row["Provider ID"], "")})
    if len(capabilities) != 54 or any(not c["existingBehaviorAndGaps"] for c in capabilities):
        raise ValueError("M0 must retain all 54 capability rows and their notes")

    file_symbols = defaultdict(list)
    for symbol in public:
        file_symbols[symbol["source"]].append(symbol)
    files = []
    baseline_paths = sorted(p for group in ("Sources", "Tests", "Examples")
                            for p in (ROOT / group).rglob("*") if p.is_file()
                            and ".build" not in p.parts and ".swiftpm" not in p.parts
                            and p.name != ".DS_Store")
    for path in baseline_paths:
        relative = str(path.relative_to(ROOT))
        data = path.read_bytes()
        record = {"path": relative, "sha256": digest(data), "bytes": len(data)}
        if relative in rules:
            rule = rules[relative]
            destinations = {rule["default"]} | {r["owner"] for r in rule["ranges"]}
            record.update(kind="source", destinations=sorted(destinations),
                          action="split" if rule["ranges"] else "move",
                          publicSymbols=len(file_symbols[relative]), reason=rule["reason"])
        elif relative.startswith("Tests/") and path.suffix != ".swift":
            if not relative.startswith("Tests/SwiftAISDKTests/Fixtures/OpenAIResponses/"):
                raise ValueError(f"Unclassified resource {relative}")
            record.update(kind="resource", destinations=[ownership["providerModules"]["openai"]],
                          action="move-with-tests", reason="OpenAI Responses fixture")
        elif relative.startswith("Tests/") or relative.startswith("Examples/"):
            content = data.decode()
            subjects = set()
            for token in set(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", content)):
                subjects.update(type_owners.get(token, ()))
            for factory in re.findall(r"AIProviders\.(\w+)", content):
                if factory in factory_owners:
                    subjects.add(factory_owners[factory])
            concrete = {s for s in subjects if not s.startswith("swift-ai-core/") and s != "SwiftAISDK/SwiftAISDK"}
            if relative.startswith("Examples/"):
                record.update(kind="example", destinations=["workspace/Examples"],
                              action="retain-consumer-example", reason="Public-import consumer coverage")
            elif "TestSupport" in path.stem or path.stem == "TestSupport":
                record.update(kind="test-support", destinations=[TEST_SUPPORT],
                              action="share-test-only", reason="Test support excluded from production products")
            else:
                # Mixed/core/compatibility tests intentionally remain integration tests in M0.
                owner = next(iter(concrete)) if len(concrete) == 1 else INTEGRATION
                record.update(kind="test", destinations=[owner], action="move-test" if owner != INTEGRATION else "retain-integration",
                              reason="One concrete package subject" if owner != INTEGRATION else "Cross-package, core, or compatibility assertions")
            record["subjectCandidates"] = sorted(subjects)
        else:
            raise ValueError(f"Unclassified file {relative}")
        files.append(record)
    preservation_docs = ["Docs/PortingStatus.md", "Docs/CoreV6Parity.md", "Docs/ProviderVersionLedger.md",
                         "Docs/ProviderCapabilityMatrix.md", "Docs/UpstreamTestInventory.md"]
    # Status gains the M0 progress section; freeze behavioral content only.
    behavior_status = (ROOT / preservation_docs[0]).read_text().split("## Weekly upstream parity", 1)[1]
    preservation = {p: digest((ROOT / p).read_bytes()) for p in preservation_docs[1:]}
    preservation[preservation_docs[0] + "#behavior-after-planning-section"] = digest(behavior_status.encode())
    counts = Counter(f["kind"] for f in files)
    snapshot = {
        "schema": 1, "baselineCommit": git("rev-parse", "HEAD"),
        "scope": "M0 ownership plan; destinations are not implemented modules",
        "compiler": subprocess.check_output(["swift", "--version"], text=True, stderr=subprocess.STDOUT).strip(),
        "ownershipSHA256": digest((OUT / "ownership.json").read_bytes()),
        "packageManifestSHA256": digest((ROOT / "Package.swift").read_bytes()),
        "symbolGraphSemanticHashes": graph_hashes,
        "counts": {**dict(counts), "publicSymbols": len(public), "publicSymbolsUsingParentLocation": sum(s["locationFromParent"] for s in public),
                   "upstreamPackages": len(upstream), "capabilityRows": len(capabilities)},
        "preservedBehaviorDocuments": preservation,
        "files": files, "upstreamPackages": sorted(upstream, key=lambda p:p["npm"]),
        "capabilities": capabilities,
        "analysisLimits": ["Signature edges use compiler-resolved types and conformances, not a complete call graph.",
                           "Test subjectCandidates are lexical hints; destinations retain mixed cases in integration.",
                           "All destination ranges are frozen against source hashes, not a reusable release catalog."],
    }
    report = {"scope": "Compiler signature edges under proposed ownership; cycles are extraction work",
              "stronglyConnectedComponents": sorted(cycles), "edges": edge_rows}
    symbols_jsonl = "".join(json.dumps(s, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n" for s in public)
    package_map = [
        "# M0 upstream package destinations", "",
        "Generated by `Scripts/audit-migration-m0.py`; frozen planning destinations, not released packages.", "",
        "All entries preserve the reviewed behavior and existing gaps recorded in `inventory.json`.",
        "The React entry preserves the native UI mapping; the React runtime remains out of scope.",
        "Open Responses currently shares implementation with OpenAI; see the boundary register in [README.md](README.md).", "",
        "| Upstream package | Reviewed baseline | Planned package/module |",
        "| --- | --- | --- |",
    ]
    for entry in sorted(upstream, key=lambda p: p["npm"]):
        destinations = ", ".join("`" + d + "`" for d in entry["destinations"])
        package_map.append(f"| `{entry['npm']}` | `{entry['baseline']}` | {destinations} |")
    return {"inventory.json": encode(snapshot), "public-symbols.jsonl": symbols_jsonl,
            "signature-dependencies.json": encode(report), "package-map.md": "\n".join(package_map) + "\n"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--symbol-graphs", type=Path, default=ROOT / ".build/out/symbolgraph")
    args = parser.parse_args()
    outputs = inventory(args.symbol_graphs)
    failures = []
    for name, content in outputs.items():
        path = OUT / name
        if args.write:
            path.write_text(content)
        elif not path.exists() or path.read_text() != content:
            failures.append(name)
    if failures:
        raise SystemExit("M0 INVENTORY MISMATCH: " + ", ".join(failures))
    summary = json.loads(outputs["inventory.json"])["counts"]
    print("M0 INVENTORY " + ("WRITTEN" if args.write else "VERIFIED") + ": " + json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
