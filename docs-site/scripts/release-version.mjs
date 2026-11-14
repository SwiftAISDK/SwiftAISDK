import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const umbrellaRoot = fileURLToPath(new URL('../../Releases/umbrella/', import.meta.url));

function compareSemver(a, b) {
  const left = a.split('.').map(Number);
  const right = b.split('.').map(Number);
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index];
  }
  return 0;
}

/** Latest published umbrella release, read from `Releases/umbrella/<version>.json`. */
export function currentReleaseVersion() {
  const versions = readdirSync(umbrellaRoot)
    .map((name) => name.match(/^(\d+\.\d+\.\d+)\.json$/)?.[1])
    .filter(Boolean)
    .sort(compareSemver);
  if (versions.length === 0) throw new Error(`No umbrella releases in ${umbrellaRoot}`);
  return versions.at(-1);
}
