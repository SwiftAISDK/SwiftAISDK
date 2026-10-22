#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// One short, no-retry request per available transport family. The normal Swift
// test suite never opts into paid requests; --run still requires LIVE_AI_TESTS=1.
const families = [
  ['OpenAI', 'OPENAI_API_KEY', 'liveProviderSmokeOpenAIStreamText', 24],
  ['Anthropic', 'ANTHROPIC_API_KEY', 'liveProviderSmokeAnthropicGenerateText', 24],
  ['Google', 'GEMINI_API_KEY', 'liveProviderSmokeGoogleStreamText', 64],
];
const args = process.argv.slice(2);
if (args.some(arg => !['--plan', '--run'].includes(arg)) || args.length > 1) {
  console.error('Usage: node Scripts/run-live-smoke.mjs [--plan|--run]');
  process.exit(2);
}
const selected = families.filter(([, key]) => process.env[key]?.trim());
const missing = families.filter(([, key]) => !process.env[key]?.trim());
const run = args[0] === '--run';
const enabled = process.env.LIVE_AI_TESTS === '1';
console.log(JSON.stringify({
  enabled,
  selected: selected.map(([provider, , test, maxOutputTokens]) => ({provider, test, maxOutputTokens})),
  missingCredentials: missing.map(([, key]) => key),
  willRun: run && enabled && selected.length > 0,
}, null, 2));
if (!run) process.exit(0);
if (!enabled || selected.length === 0) {
  console.error(!enabled
    ? 'No API calls made: set LIVE_AI_TESTS=1 explicitly before --run.'
    : 'No API calls made: none of the representative provider credentials is configured.');
  process.exit(2);
}
const result = spawnSync('swift', [
  'test', '--no-parallel', '--filter', selected.map(([, , test]) => test).join('|'),
], {cwd: fileURLToPath(new URL('..', import.meta.url)), stdio: 'inherit'});
if (result.error) console.error(`Unable to run Swift tests: ${result.error.message}`);
process.exit(result.status ?? 1);
