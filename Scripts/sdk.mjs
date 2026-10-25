#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import catalogTools from "./lib/catalog.cjs";
import generator from "./lib/generate.cjs";
import releases from "./lib/release.cjs";
import publication from "./lib/publish.cjs";
const { rootDefault, json, readCatalog, ensure, localPath } = catalogTools;
const args = process.argv.slice(2);
let root = rootDefault;
const rootIndex = args.indexOf("--root");
if (rootIndex >= 0) {
  ensure(args[rootIndex + 1], "--root requires a path");
  root = path.resolve(args[rootIndex + 1]);
  args.splice(rootIndex, 2);
}
function value(flag) {
  const i = args.indexOf(flag);
  ensure(
    i >= 0 && args[i + 1] && !args[i + 1].startsWith("--"),
    `${flag} requires a value`,
  );
  return args[i + 1];
}
function options(start, allowed) {
  for (let i = start; i < args.length; i++) {
    ensure(Object.hasOwn(allowed, args[i]), `Unknown option: ${args[i]}`);
    if (allowed[args[i]]) {
      value(args[i]);
      i++;
    }
  }
}
function addPackage() {
  const data = readCatalog(root),
    upstream = value("--upstream");
  ensure(
    /^@ai-sdk\/[a-z0-9]+(?:-[a-z0-9]+)*$/.test(upstream),
    "Expected an @ai-sdk/<slug> name",
  );
  ensure(
    !data.lock.packages.some((p) => p.name === upstream),
    `Already registered: ${upstream}`,
  );
  const slug = upstream.slice("@ai-sdk/".length),
    id = `swift-ai-${slug}`,
    directory = `Packages/${id}`;
  const module = args.includes("--module")
    ? value("--module")
    : "SwiftAI" +
      slug
        .split("-")
        .map((s) => s[0].toUpperCase() + s.slice(1))
        .join("");
  ensure(/^[A-Z][A-Za-z0-9]*$/.test(module), "Invalid Swift module name");
  ensure(
    !data.catalog.packages.some(
      (p) => p.id === id || p.modules.some((m) => m.name === module),
    ),
    "Duplicate package/module",
  );
  const dir = localPath(root, directory);
  ensure(!fs.existsSync(dir), "Scaffold destination already exists");
  const originalCatalog = fs.readFileSync(
    path.join(root, "Porting/packages.json"),
  );
  const originalLock = fs.readFileSync(
    path.join(root, "Porting/upstream-lock.json"),
  );
  const p = {
    id,
    kind: "provider",
    directory,
    repository: `https://github.com/${data.catalog.organization}/${id}.git`,
    state: "scaffold",
    modules: [
      {
        name: module,
        dependencies: [
          "swift-ai-core/SwiftAIProvider",
          "swift-ai-core/SwiftAITransport",
          "swift-ai-core/SwiftAIProviderUtilities",
        ],
      },
    ],
    upstream: [upstream],
    dependencies: [{ package: "swift-ai-core", from: "1.0.0" }],
    capabilityRows: [],
    guides: [`${directory}/README.md`],
  };
  const lock = {
    name: upstream,
    reviewedVersion: null,
    ledgerKind: "provider",
    evidence: `${directory}/Porting/map.json`,
    reviewStatus: "unreviewed",
    archiveIntegrity: null,
    sourceRef: null,
    testRef: null,
    testRefRelationship: "unavailable",
    contractFamilies: [],
    contractReview:
      "Unreviewed scaffold; inspect published source and tests before implementing.",
  };
  const map = {
    schemaVersion: 1,
    package: id,
    status: "unreviewed",
    upstream: [
      { name: upstream, implementation: [`packages/${slug}/src`], tests: [] },
    ],
    swift: {
      sources: [`${directory}/Sources/${module}`],
      tests: [`${directory}/Tests/${module}Tests`],
      resources: [],
    },
    differences: [],
    reviewNote:
      "No behavior is ported. Record source/test provenance, translated assertions and deliberate differences before changing status.",
  };
  const write = (file, body) => {
    const full = localPath(root, file);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, body);
  };
  try {
    write(`${directory}/Porting/map.json`, json(map));
    write(
      `${directory}/Sources/${module}/Pending.swift`,
      "// NOT IMPLEMENTED. Add the reviewed provider surface here. No supported API yet.\n",
    );
    write(
      `${directory}/Tests/${module}Tests/Pending.swift`,
      "// No assertions yet. Translate upstream behavior tests before marking this package implemented.\n",
    );
    write(
      `${directory}/README.md`,
      `# ${module}\n\nNOT IMPLEMENTED. This scaffold is not an installable provider release.\n\nIndependent Swift port of Vercel AI SDK ${upstream}.\n\nBefore release, document setup, authentication, a working usage example, supported capabilities, and known differences. Register reviewed archive/test provenance and translate upstream assertions.\n`,
    );
    data.catalog.packages.push(p);
    data.catalog.packages.sort((a, b) => a.id.localeCompare(b.id));
    data.lock.packages.push(lock);
    write("Porting/packages.json", json(data.catalog));
    write("Porting/upstream-lock.json", json(data.lock));
    generator.generate(root);
  } catch (error) {
    fs.writeFileSync(path.join(root, "Porting/packages.json"), originalCatalog);
    fs.writeFileSync(
      path.join(root, "Porting/upstream-lock.json"),
      originalLock,
    );
    fs.rmSync(dir, { recursive: true, force: true });
    throw error;
  }
  console.log(
    json({
      package: id,
      state: "scaffold",
      capabilities: [],
      reviewedVersion: null,
    }),
  );
}
try {
  if (!args.length || args.includes("--help"))
    console.log(
      `SwiftAISDK package and release tooling\n\n  generate [--check]                     Validate and generate metadata/manifests\n  catalog validate                       Check schema, paths, ownership and dependency cycles\n  package add --upstream @ai-sdk/name [--module SwiftAIName]\n  upstream check [legacy version-check options]\n  upstream prepare [legacy diff options]\n  verify --affected --files path1,path2   Select checks; does not execute Swift tests\n\n--root <checkout> selects an isolated checkout for tooling rehearsals.\nRelease rehearsal commands (local only):\n  release plan [--id release-id] [--output plan.json]\n  release export --dry-run --plan plan.json --output new-directory\n  release rehearse --export export-directory --staging new-or-resumed-directory\n    [--baseline prior-staging] [--stop-after N] [--interrupt-after-push N]\nProduction publication:\n  release export --publication --plan plan.json --output new-directory\n  release publish --export export-directory --staging attempt-directory --ci-run completed-run-id`,
    );
  else if (args[0] === "generate") {
    options(1, { "--check": false });
    console.log(json(generator.generate(root, args.includes("--check"))));
  } else if (args[0] === "catalog" && args[1] === "validate") {
    options(2, {});
    const data = readCatalog(root);
    console.log(
      `CATALOG VALID: ${data.catalog.packages.length} packages, ${data.lock.packages.length} upstream entries, ${data.rows.length} capability rows`,
    );
  } else if (args[0] === "package" && args[1] === "add") {
    options(2, { "--upstream": true, "--module": true });
    addPackage();
  } else if (args[0] === "verify" && args.includes("--affected")) {
    options(1, { "--affected": false, "--files": true });
    console.log(
      json(
        generator.affected(
          readCatalog(root),
          value("--files").split(",").filter(Boolean),
        ),
      ),
    );
  } else if (args[0] === "release" && args[1] === "plan") {
    options(2, { "--id": true, "--output": true });
    const result = releases.plan(
      root,
      args.includes("--id") ? value("--id") : "modular-pilot",
    );
    if (args.includes("--output")) {
      const output = path.resolve(value("--output"));
      ensure(!fs.existsSync(output), "Plan output already exists");
      fs.mkdirSync(path.dirname(output), { recursive: true });
      fs.writeFileSync(output, json(result), { flag: "wx" });
    }
    console.log(json(result));
  } else if (args[0] === "release" && args[1] === "export") {
    options(2, { "--dry-run": false, "--publication": false, "--plan": true, "--output": true });
    ensure(
      args.includes("--dry-run") !== args.includes("--publication"),
      "Select exactly one of --dry-run or --publication",
    );
    const result = releases.exportRelease(
      root,
      JSON.parse(fs.readFileSync(value("--plan"), "utf8")),
      path.resolve(value("--output")),
      { publication: args.includes("--publication") },
    );
    console.log(
      json({
        kind: result.kind,
        source: result.plan.source.inputsSHA256,
        exports: result.exports.map(({ package: id, version, sha256 }) => ({
          package: id,
          version,
          sha256,
        })),
      }),
    );
  } else if (args[0] === "release" && args[1] === "publish") {
    options(2, { "--export": true, "--staging": true, "--ci-run": true });
    console.log(json(publication.publish(root, path.resolve(value("--export")),
      path.resolve(value("--staging")), { ciRun: value("--ci-run") })));
  } else if (args[0] === "release" && args[1] === "rehearse") {
    options(2, {
      "--export": true,
      "--staging": true,
      "--baseline": true,
      "--stop-after": true,
      "--interrupt-after-push": true,
    });
    const count = (flag) => {
      if (!args.includes(flag)) return 0;
      const n = Number(value(flag));
      ensure(
        Number.isSafeInteger(n) && n > 0,
        `${flag} requires a positive integer`,
      );
      return n;
    };
    console.log(
      json(
        releases.rehearse(
          path.resolve(value("--export")),
          path.resolve(value("--staging")),
          {
            stopAfter: count("--stop-after"),
            crashAfterPush: count("--interrupt-after-push"),
            baseline: args.includes("--baseline")
              ? path.resolve(value("--baseline"))
              : null,
          },
        ),
      ),
    );
  } else if (args[0] === "upstream" && ["check", "prepare"].includes(args[1])) {
    const forwarded = args.slice(2);
    if (args[1] === "prepare" && !forwarded.includes("--prepare-diffs"))
      forwarded.push("--prepare-diffs");
    const result = spawnSync(
      process.execPath,
      [path.join(root, "Scripts/check-upstream-versions.js"), ...forwarded],
      { cwd: root, stdio: "inherit" },
    );
    if (result.error) throw result.error;
    process.exitCode = result.status ?? 1;
  } else throw new Error("Unknown command; run node Scripts/sdk.mjs --help");
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
