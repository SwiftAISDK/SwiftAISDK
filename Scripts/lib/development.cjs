// Local SwiftPM workspace. Public manifests always use real Git dependencies.
// Symlinks reference canonical sources; no source copies or editable checkouts.
const fs = require("node:fs");
const path = require("node:path");
const { readCatalog, ensure, rootDefault } = require("./catalog.cjs");
const { umbrellaManifest } = require("./generate.cjs");

function prepare(root = rootDefault) {
  const data = readCatalog(root);
  const workspace = path.join(root, ".build/development/SwiftAISDK");
  fs.mkdirSync(workspace, { recursive: true });
  function link(from, to) {
    const target = path.relative(path.dirname(to), from);
    if (fs.existsSync(to) || fs.lstatSync(to, { throwIfNoEntry: false })) {
      ensure(fs.lstatSync(to).isSymbolicLink() && fs.readlinkSync(to) === target,
        `Unexpected development workspace input: ${to}`);
    } else fs.symlinkSync(target, to);
  }
  for (const name of ["Sources", "Tests", "Docs", "Porting"])
    link(path.join(root, name), path.join(workspace, name));
  const manifest = umbrellaManifest(data, { localPrefix: "../../../" });
  const file = path.join(workspace, "Package.swift");
  if (!fs.existsSync(file) || fs.readFileSync(file, "utf8") !== manifest)
    fs.writeFileSync(file, manifest);
  // The complete examples' existing `..` dependency now selects this workspace.
  const examples = path.join(workspace, "Examples");
  fs.mkdirSync(examples, { recursive: true });
  for (const name of fs.readdirSync(path.join(root, "Examples"))) {
    if (name.startsWith(".") || name === "Package.resolved") continue;
    link(path.join(root, "Examples", name), path.join(examples, name));
  }
  return workspace;
}
module.exports = { prepare };
