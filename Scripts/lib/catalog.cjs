// Catalog readers shared by the old CLIs, the SDK command, and docs generation.
const fs = require("node:fs");
const path = require("node:path");
const rootDefault = path.resolve(__dirname, "../..");
const json = (value) => JSON.stringify(value, null, 2) + "\n";
const readJSON = (root, file) =>
  JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
function ensure(ok, message) {
  if (!ok) throw new Error(message);
}
function validateSchema(value, schema, definitions, where) {
  const supported = new Set([
    "$ref",
    "type",
    "enum",
    "pattern",
    "properties",
    "required",
    "additionalProperties",
    "items",
  ]);
  for (const keyword of Object.keys(schema))
    ensure(supported.has(keyword), `Unsupported schema keyword: ${keyword}`);
  if (schema.$ref)
    ensure(
      Object.keys(schema).length === 1,
      "Schema reference siblings are not supported",
    );
  if (schema.$ref)
    return validateSchema(
      value,
      definitions[schema.$ref.split("/").pop()],
      definitions,
      where,
    );
  if (schema.enum)
    ensure(schema.enum.includes(value), `${where}: unexpected value ${value}`);
  const type =
    value === null
      ? "null"
      : Array.isArray(value)
        ? "array"
        : Number.isInteger(value)
          ? "integer"
          : typeof value;
  if (schema.type)
    ensure(
      [schema.type].flat().includes(type),
      `${where}: expected ${schema.type}, got ${type}`,
    );
  if (schema.pattern)
    ensure(new RegExp(schema.pattern).test(value), `${where}: invalid format`);
  if (schema.type === "object") {
    for (const key of schema.required)
      ensure(Object.hasOwn(value, key), `${where}: missing ${key}`);
    for (const key of Object.keys(value)) {
      ensure(
        Object.hasOwn(schema.properties, key),
        `${where}: unknown field ${key}`,
      );
      validateSchema(
        value[key],
        schema.properties[key],
        definitions,
        `${where}.${key}`,
      );
    }
  }
  if (schema.type === "array")
    value.forEach((item, i) =>
      validateSchema(item, schema.items, definitions, `${where}[${i}]`),
    );
}
function localPath(root, relative, mustExist = false) {
  ensure(
    typeof relative === "string" &&
      relative.length > 0 &&
      !path.isAbsolute(relative) &&
      !relative.split("/").includes("..") &&
      !relative.includes("\\") &&
      !relative.includes("\0"),
    `Unsafe catalog path: ${relative}`,
  );
  const full = path.join(root, relative);
  if (mustExist)
    ensure(fs.existsSync(full), `Missing mapped path: ${relative}`);
  let existing = full;
  while (!fs.existsSync(existing)) existing = path.dirname(existing);
  const actual = fs.realpathSync(existing),
    base = fs.realpathSync(root);
  ensure(
    actual === base || actual.startsWith(base + path.sep),
    `Path escapes checkout: ${relative}`,
  );
  return full;
}
function unique(values, label) {
  ensure(new Set(values).size === values.length, `Duplicate ${label}`);
}
function topological(nodes, dependencies) {
  const active = new Set(),
    done = new Set(),
    result = [];
  function visit(node) {
    ensure(!active.has(node), `Dependency cycle at ${node}`);
    if (done.has(node)) return;
    active.add(node);
    for (const dependency of dependencies(node)) {
      ensure(nodes.includes(dependency), `Unknown dependency ${dependency}`);
      visit(dependency);
    }
    active.delete(node);
    done.add(node);
    result.push(node);
  }
  [...nodes].sort().forEach(visit);
  return result;
}
function readCatalog(root = rootDefault) {
  const catalog = readJSON(root, "Porting/packages.json");
  const lock = readJSON(root, "Porting/upstream-lock.json");
  const workspace = readJSON(root, "Porting/workspace-map.json");
  const definitions = readJSON(
    root,
    "Porting/schemas/catalog.schema.json",
  ).$defs;
  for (const [name, value] of [
    ["packages", catalog],
    ["lock", lock],
    ["workspace", workspace],
  ])
    validateSchema(value, definitions[name], definitions, name);
  const packages = catalog.packages,
    ids = packages.map((p) => p.id),
    upstream = lock.packages.map((p) => p.name);
  unique(ids, "package ID");
  unique(upstream, "upstream package");
  unique(
    catalog.capabilities.map((c) => c.name),
    "capability",
  );
  unique(
    packages.flatMap((p) => p.modules.map((m) => m.name)),
    "module name",
  );
  ensure(packages.length > 0, "Empty package catalog");
  const maps = new Map(),
    rows = packages
      .flatMap((p) => p.capabilityRows)
      .sort((a, b) => a.order - b.order);
  unique(
    rows.map((r) => r.providerID),
    "provider ID",
  );
  unique(
    rows.map((r) => r.order),
    "capability row order",
  );
  unique(
    rows.flatMap((r) => r.factoryNames),
    "factory",
  );
  for (const entry of lock.packages) {
    ensure(
      /^(ai|@ai-sdk\/[a-z0-9]+(?:-[a-z0-9]+)*)$/.test(entry.name),
      `Invalid npm name ${entry.name}`,
    );
    ensure(
      packages.some((p) => p.upstream.includes(entry.name)),
      `Unowned upstream package ${entry.name}`,
    );
    if (entry.reviewedVersion !== null)
      ensure(
        /^\d+\.\d+\.\d+(?:-[\w.-]+)?$/.test(entry.reviewedVersion),
        `Invalid reviewed version ${entry.name}`,
      );
    else
      ensure(
        entry.reviewStatus === "unreviewed",
        `Missing reviewed version ${entry.name}`,
      );
    if (entry.reviewStatus === "unreviewed")
      ensure(
        entry.reviewedVersion === null,
        `Unreviewed package has a reviewed version: ${entry.name}`,
      );
    if (entry.reviewedVersion !== null)
      ensure(
        entry.sourceRef === `npm:${entry.name}@${entry.reviewedVersion}`,
        `Source/version mismatch: ${entry.name}`,
      );
    if (entry.reviewStatus === "reviewed")
      ensure(
        entry.archiveIntegrity &&
          entry.testRef &&
          entry.testRefRelationship === "matching-release" &&
          entry.contractFamilies.length > 0,
        `Incomplete reviewed provenance: ${entry.name}`,
      );
    if (entry.archiveIntegrity !== null)
      ensure(
        /^sha(256|384|512)-[A-Za-z0-9+/]+=*$/.test(entry.archiveIntegrity),
        `Invalid integrity ${entry.name}`,
      );
    if (entry.testRef !== null)
      ensure(
        /^[a-f0-9]{40}$/.test(entry.testRef),
        `Invalid test ref ${entry.name}`,
      );
  }
  for (const p of packages) {
    ensure(
      p.directory === `Packages/${p.id}`,
      `Directory/identity mismatch: ${p.id}`,
    );
    ensure(
      p.repository === `https://github.com/${catalog.organization}/${p.id}.git`,
      `Repository/identity mismatch: ${p.id}`,
    );
    ensure(
      p.modules.length > 0 && p.upstream.length > 0,
      `Empty module/upstream ownership: ${p.id}`,
    );
    unique(p.upstream, `upstream ownership ${p.id}`);
    unique(
      p.dependencies.map((d) => d.package),
      `dependency ${p.id}`,
    );
    for (const u of p.upstream)
      ensure(upstream.includes(u), `Missing upstream lock ${u}`);
    for (const r of p.capabilityRows) {
      ensure(
        p.state !== "scaffold",
        `Unimplemented scaffold advertises capabilities: ${p.id}`,
      );
      ensure(
        p.upstream.includes(r.upstreamPackage),
        `Wrong capability owner ${r.providerID}`,
      );
      ensure(
        lock.packages.find((u) => u.name === r.upstreamPackage).reviewStatus !==
          "unreviewed",
        `Unreviewed provider advertises capabilities: ${r.providerID}`,
      );
      ensure(
        r.factoryNames.length > 0 && r.capabilities.length > 0,
        `Empty capability ${r.providerID}`,
      );
      unique(r.capabilities, `capability ${r.providerID}`);
      for (const c of r.capabilities)
        ensure(
          catalog.capabilities.some((x) => x.name === c),
          `Unknown capability ${c}`,
        );
    }
    for (const m of p.modules) {
      for (const resource of m.testResources || [])
        localPath(root, `${p.directory}/Tests/${m.name}Tests/${resource}`, true);
      for (const d of [...m.dependencies, ...(m.testDependencies || [])]) {
        const [packageID, module] = d.includes("/") ? d.split("/") : [p.id, d];
        ensure(
          packages.some(
            (q) =>
              q.id === packageID && q.modules.some((t) => t.name === module),
          ),
          `Unknown module dependency ${d}`,
        );
        if (packageID !== p.id)
          ensure(
            p.dependencies.some((x) => x.package === packageID),
            `Undeclared package dependency ${d}`,
          );
      }
    }
    const map = readJSON(root, `${p.directory}/Porting/map.json`);
    validateSchema(map, definitions.map, definitions, `map ${p.id}`);
    ensure(map.package === p.id, `Wrong map owner ${p.id}`);
    ensure(
      JSON.stringify([...map.upstream.map((u) => u.name)].sort()) ===
        JSON.stringify([...p.upstream].sort()),
      `Upstream mapping mismatch ${p.id}`,
    );
    for (const u of map.upstream)
      for (const f of [...u.implementation, ...u.tests]) {
        localPath(root, f);
        ensure(
          f.startsWith("packages/" + u.name.replace("@ai-sdk/", "") + "/"),
          `Wrong upstream path ${f}`,
        );
      }
    for (const f of [...p.guides, ...Object.values(map.swift).flat()])
      localPath(root, f, true);
    maps.set(p.id, map);
    if (p.state === "extracted")
      for (const m of p.modules) {
        for (const dir of [
          `${p.directory}/Sources/${m.name}`,
          `${p.directory}/Tests/${m.name}Tests`,
        ]) {
          const full = localPath(root, dir, true);
          ensure(
            fs.statSync(full).isDirectory() && fs.readdirSync(full).length > 0,
            `Empty extracted module directory: ${dir}`,
          );
        }
      }
  }
  workspace.files.forEach((f) => localPath(root, f, true));
  const order = topological(ids, (id) =>
    packages.find((p) => p.id === id).dependencies.map((d) => d.package),
  );
  const modules = packages.flatMap((p) =>
    p.modules.map((m) => `${p.id}/${m.name}`),
  );
  topological(modules, (id) => {
    const [p, m] = id.split("/");
    return packages
      .find((q) => q.id === p)
      .modules.find((t) => t.name === m)
      .dependencies.map((d) => (d.includes("/") ? d : `${p}/${d}`));
  });
  // Legacy files must remain explicitly owned; new module trees are owned by their package map.
  const owned = [
    ...workspace.files,
    ...[...maps.values()].flatMap((m) => Object.values(m.swift).flat()),
  ];
  const sourceGroups = [
    "Sources",
    "Tests",
    "Examples",
    ...packages
      .flatMap((p) =>
        ["Sources", "Tests"].map((group) => `${p.directory}/${group}`),
      )
      .filter((group) => fs.existsSync(path.join(root, group))),
  ];
  for (const group of sourceGroups) {
    function walk(dir) {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if ([".build", ".swiftpm", ".DS_Store"].includes(entry.name)) continue;
        const full = path.join(dir, entry.name),
          rel = path.relative(root, full).split(path.sep).join("/");
        if (entry.isDirectory()) walk(full);
        else
          ensure(
            owned.some((f) => rel === f || rel.startsWith(f + "/")),
            `Unowned workspace input ${rel}`,
          );
      }
    }
    walk(path.join(root, group));
  }
  return { root, catalog, lock, workspace, maps, rows, order };
}
function upstreamEntries(root = rootDefault) {
  return readCatalog(root)
    .lock.packages.filter((p) => p.reviewedVersion !== null)
    .map((p) => ({
      kind: p.ledgerKind,
      name: p.name,
      current: p.reviewedVersion,
      version: p.reviewedVersion,
      evidence: p.evidence.replaceAll("`", ""),
    }));
}
function docsRows(root = rootDefault) {
  const data = readCatalog(root);
  return data.rows.map((r) => ({
    providerID: r.providerID,
    upstreamPackage: r.upstreamPackage,
    factories: r.factoryNames.map((f) => "`" + f + "`").join(", "),
    ...Object.fromEntries(
      data.catalog.capabilities.map((c) => [
        c.name,
        r.capabilities.includes(c.name) ? "✅" : "",
      ]),
    ),
    files: r.files ? "✅" : "",
    skills: r.skills ? "✅" : "",
    notes: r.notes,
  }));
}
module.exports = {
  rootDefault,
  json,
  readJSON,
  ensure,
  localPath,
  readCatalog,
  upstreamEntries,
  docsRows,
  topological,
  validateSchema,
};
