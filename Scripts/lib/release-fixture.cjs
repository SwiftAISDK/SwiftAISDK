// Synthetic release history for disposable test/rehearsal snapshots only.
const fs = require("node:fs");
const path = require("node:path");
const { rootDefault, readCatalog, json, ensure } = require("./catalog.cjs");
function seedPilot(snapshot) {
  ensure(fs.realpathSync(snapshot) !== fs.realpathSync(rootDefault),
    "Cannot seed release fixtures in the canonical checkout");
  const pilot = ["swift-ai-core", "swift-ai-anthropic", "swift-ai-openai-compatible", "swift-ai-openai"];
  const data = readCatalog(snapshot);
  ensure(pilot.every((id) => data.catalog.packages.some((p) => p.id === id && p.state === "extracted")),
    "Pilot fixture packages must be extracted");
  for (const sub of ["changes", "sets"]) {
    const directory = path.join(snapshot, "Releases", sub);
    fs.mkdirSync(directory, { recursive: true });
    for (const name of fs.readdirSync(directory).filter((f) => f.endsWith(".json")))
      fs.unlinkSync(path.join(directory, name));
  }
  fs.writeFileSync(path.join(snapshot, "Releases/changes/modular-pilot.json"), json({
    schemaVersion: 1, id: "modular-pilot", status: "reviewed", summary: "Disposable initial pilot fixture",
    packages: pilot.map((id) => ({ package: id, bump: "initial", notes: "Fixture initial release.",
      compatibility: "Synthetic version history; not a public release." })),
  }));
}
module.exports = { seedPilot };
