# Documentation dependencies

The documentation site has its own private npm package and lockfile. Its
`0.1.0` package version is independent of SwiftAISDK release tags.

## Verified baseline

The 2026-10-23 dependency repair uses these exact direct versions:

| Package | Version | Purpose |
| --- | --- | --- |
| `astro` | `7.4.2` | Static site build |
| `@astrojs/starlight` | `0.42.6` | Documentation theme and search |
| `@astrojs/markdown-remark` | `7.3.4` | Existing remark/rehype Markdown pipeline |
| `remark-gfm` | `4.0.1` | GitHub-flavored Markdown tables and other syntax |
| `sharp` | `0.35.5` | Image processing with patched native dependencies |
| `@astrojs/check` | `0.9.12` | Astro diagnostics |
| `typescript` | `6.0.3` | Latest TypeScript 6 patch supported by Astro check |

Use Node.js **22.23.4 or later** and npm **9.6.5 or later**, matching Astro's
published engine requirements. The documentation workflow uses Node.js 26.
`@astrojs/check` 0.9.12 supports TypeScript 5 and 6; TypeScript 7 is outside its
declared peer range. Direct dependencies remain pinned, and the committed
lockfile fixes the complete dependency graph without overrides.

## Astro 7 compatibility

Astro 7 defaults to a different Markdown processor. The site explicitly uses
`unified({ remarkPlugins: [remarkGfm] })` from `@astrojs/markdown-remark` so its
existing remark plugins continue to apply. `compressHTML: true` retains the
HTML-aware whitespace behavior used by Astro 6. See the
[Astro 7 migration guide](https://docs.astro.build/en/guides/upgrade-to/v7/).

Starlight 0.42 requires Astro 7.2.10 or newer and, when using the remark
processor, `@astrojs/markdown-remark` 7.3.0 or newer. Its browser support starts
at Chromium 116, Safari/iOS 17.0, and Firefox 125. It also changes mobile-menu
markup; the site's custom CSS does not target the removed selectors. See the
[Starlight 0.42 release notes](https://github.com/withastro/starlight/releases/tag/%40astrojs%2Fstarlight%400.42.0).

## Security verification

The full npm audit on 2026-10-23 reported **0 vulnerabilities** after a clean
install, down from 19 affected dependency entries: 1 critical, 16 high,
1 moderate, and 1 low. This includes development dependencies and the full
lockfile graph; it is a dated advisory check, not a guarantee against future
advisories.

An Astro 6 patch alone was insufficient. The
[AVIF advisory](https://github.com/advisories/GHSA-26w7-cxv4-gfx2) requires Astro
7.2.8 or later; the subsequent
[JSX/MDX escaping advisory](https://github.com/advisories/GHSA-98hj-9722-w3j8)
requires Astro 7.3.2 or later. Sharp 0.35.5 additionally fixes its
[librsvg advisory](https://github.com/advisories/GHSA-wq5f-xc86-pv6w).

For future dependency updates, inspect the advisory's affected range and the
packages' engine and peer requirements together. Recheck the complete resolved
graph after installation instead of treating npm's suggested version as proof
that every advisory is fixed.

Run from the repository root:

```sh
npm ci --prefix docs-site
npm audit --prefix docs-site
npm --prefix docs-site run check
DOCS_BASE=/SwiftAISDK DOCS_SITE=https://ozio.github.io npm --prefix docs-site run build
```

The check and build scripts regenerate public reference pages. Run them after
the corresponding Swift source and documentation changes have been integrated.
