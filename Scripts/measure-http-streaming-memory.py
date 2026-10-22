#!/usr/bin/env python3
"""Measure an unread HTTP body on macOS, in isolated offline processes."""
import argparse
import json
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--runs", type=int, default=3)
    args = parser.parse_args()
    if platform.system() != "Darwin" or not 1 <= args.runs <= 10:
        parser.error("Requires macOS and --runs between 1 and 10")
    package = args.package.resolve()
    if not (package / "Package.swift").is_file():
        parser.error("--package must contain Package.swift")
    source = Path(__file__).with_name("HTTPStreamingMemoryProbe.swift").read_text()
    with tempfile.TemporaryDirectory(prefix="swiftaisdk-memory-") as folder:
        probe = Path(folder)
        (probe / "Sources" / "Probe").mkdir(parents=True)
        (probe / "Sources" / "Probe" / "main.swift").write_text(source)
        (probe / "Package.swift").write_text(
            '// swift-tools-version: 6.3\nimport PackageDescription\n'
            'let package = Package(name: "Probe", platforms: [.macOS(.v12)], '
            'dependencies: [.package(name: "SwiftAISDK", path: '
            + json.dumps(str(package), ensure_ascii=False)
            + ')], targets: [.executableTarget(name: "Probe", dependencies: '
            '[.product(name: "SwiftAISDK", package: "SwiftAISDK")])])\n'
        )
        build = ["swift", "build", "--package-path", str(probe), "--build-system", "native", "--jobs", "4"]
        result = subprocess.run(build, capture_output=True, text=True)
        if result.returncode:
            raise SystemExit(result.stdout[-4000:] + result.stderr[-4000:])
        bin_path = subprocess.check_output(build + ["--show-bin-path"], text=True).strip()
        samples = []
        for _ in range(args.runs):
            sample = json.loads(subprocess.check_output([str(Path(bin_path) / "Probe")], text=True))
            assert sample["payloadBytes"] == 1_048_576 and sample["consumedBytes"] == 128
            samples.append(sample)
        print(json.dumps({
            "scope": "URLSession byte-to-Data bridge; not a whole-facade memory bound",
            "mode": "offline URLProtocol; body left unread for two seconds",
            "samples": samples,
            "medianResidentGrowthUnread": statistics.median(s["residentGrowthUnread"] for s in samples),
        }, indent=2))


if __name__ == "__main__":
    main()
