const fs = require("node:fs");
const path = require("node:path");
const { ensure } = require("./catalog.cjs");
const { hash, git } = require("./release.cjs");
const required = ["catalog", "tooling", "all-source-tests", "distributions", "maintenance",
  "ios", "examples", "oauth", "docs-install", "docs-check", "docs-build"];
function verify(root, file, commit) {
  const receipt = JSON.parse(fs.readFileSync(file, "utf8"));
  ensure(receipt.kind === "local-migration-verification" && receipt.status === "passed" &&
    receipt.sourceCommit === commit && receipt.sourceTree === git(["rev-parse", `${commit}^{tree}`], root),
    "Local verification does not match this exact canonical source");
  ensure(receipt.policy === "Docs/Migration/M6/ci-budget-policy.json" &&
    fs.existsSync(path.join(root, receipt.policy)), "Missing user-directed migration CI policy");
  ensure(required.every(name => receipt.checks.some(c => c.name === name && c.exitCode === 0)), "Incomplete local verification");
  for (const check of receipt.checks) {
    ensure(check.exitCode === 0 && path.isAbsolute(check.log) &&
      fs.existsSync(check.log) && hash(fs.readFileSync(check.log)) === check.logSHA256,
      "Local verification log missing or changed: " + check.name);
  }
  return { kind: receipt.kind, sourceCommit: commit, receiptSHA256: hash(fs.readFileSync(file)),
    policy: receipt.policy, hostedVerification: "Deferred until the final migration handoff by user instruction" };
}
module.exports = { verify, required };
