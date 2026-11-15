# Release Set History

Narrative summaries of published release sets, moved from `Releases/README.md` on
2026-11-15. The machine-readable records remain in `Releases/sets/` and
`Releases/umbrella/`. See [Archive policy](README.md).

The 2026-11-01 release set is in `sets/weekly-upstream-20261101.json`: 48 changed
units, retaining the four unchanged distributions. `umbrella/3.1.0.json` records
the separate compatibility selection. npm package baselines remain independent.

The 2026-11-08 set is in `sets/weekly-upstream-20261108.json`: 48 changed
units (21 minor, 27 patch). ByteDance, Hugging Face, LMNT and Vercel retain
their distributions. `umbrella/3.2.0.json` records the separate compatibility
selection after its dependency tags passed public consumers and hosted CI.

The 2026-11-14 set is in `sets/weekly-upstream-20261114.json`: 48 changed
units (11 minor, 37 patch), with four unchanged distributions retained. All
48 standalone CI runs and 59 clean public consumers passed. Version-specific
lower bounds are additionally verified. `umbrella/3.3.0.json` records the separate
52-version compatibility selection after exact-source Swift 6.3.3 CI, annotated
tag/GitHub Release readback and actual 3.3.0/preserved 2.8.1 consumers passed. The
59 modular consumer report remains immutable; the two umbrella consumers have a
separate report in `Docs/Archive/UmbrellaConsumerVerification20261114.json`. The unchanged
MCP fixture needed one bounded same-SHA CI rerun; the initial failure and its
50 ms timing margin remain recorded test-stability debt.

The 2026-11-15 set is in `sets/weekly-upstream-20261115.json`: 36 changed
units (31 patch, two minor, three initial), retaining 19 unchanged units. All
36 standalone CIs and 62 clean actual-public-tag consumers passed. Eight
version-specific historical graphs and one exact least-version umbrella graph
supplement 112 generic local clients. `umbrella/3.4.0.json` records the separate compatibility selection after actual
3.4.0/preserved2.8.1 clients and tag/Release readback. Complete Swift6.3.3 M3
verification and the controlled hosted fallback also passed.
