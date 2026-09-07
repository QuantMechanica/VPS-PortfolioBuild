# Website design system v1.0 — implementation evidence

- Task: `06109144-e44e-4859-b908-35a5f233199c`
- Scope: local work copy only; **no deploy**
- Site worktree: `C:/QM/deploy/qm-ops-refresh`
- Site branch: `agents/codex-website-design-system-v1`
- Site commit: `abb22f9ed64e6ef44a46ee557498b5748c650476`
- Binding package intake: `9bd0bea521`
- Verification time: `2026-09-07T14:29:18Z`

## Result

The homepage, archive list, 3,339 generated archive detail pages, blog, and secondary pages now share the package design system. The package token and component CSS files are copied byte-for-byte into the site (SHA-256 `5d9298d20043799aaeef3a9b00a4b2472b7c28ae06b1e332c484993d7fd3e480` and `0ba24ebeeba9573370e6b1010bf97169e8cc422e6faa989f24c866454d38114f`). Every page loads tokens first, components second, and page composition CSS last.

The retained homepage elements are restyled in the package grammar: `The Quantitative Edge.`, the real records block, the left-to-right evidence funnel, vertical mechanics, and the animated candle header. The hero has six navigation items, one green primary action, and one secondary text link. The site uses Inter with the required Segoe UI / Helvetica Neue / Arial fallbacks, a 1,240 px content maximum, 16 px cards, 8 px controls, and 44 px minimum interactive targets.

## Compatibility-token mapping

| Previous site alias family | Package token | Value / purpose |
|---|---|---|
| `--ink`, `--c-text`, `--qm-text` | `--qm-carbon` | `#171A21`, primary text |
| `--ink-2`, `--c-text-2`, `--qm-text-muted` | `--qm-slate` | `#677185`, secondary text |
| `--paper`, `--c-bg`, `--qm-bg` | `--qm-surface` | `#FFFFFF`, page surface |
| `--paper-alt`, `--c-bg-alt`, `--qm-surface-2` | `--qm-cloud` | `#F5F7F9`, alternate surface |
| `--accent`, `--c-accent`, `--qm-em` | `--qm-green` | `#0A8A5B`, brand accent |
| `--accent-strong`, `--c-accent-hover`, `--em-d` | `--qm-green-dark` | `#087247`, accessible CTA/text green |
| `--steel`, `--steel-strong` | `--qm-info` | `#3B6CF6`, informational signal |
| `--pass`, `--c-pass`, `--qm-pass` | `--qm-positive` | `#0B7A53` |
| `--fail`, `--c-fail`, `--qm-fail` | `--qm-negative` | `#B8454D` |
| `--warn`, `--c-warn`, `--qm-promising` | `--qm-warning` | `#996515` |
| `--line`, `--c-line`, `--border` | `--qm-border` | `#DCE2E8` |
| `--line-2`, `--c-line-2`, `--border-h` | `--qm-border-strong` | `#C8D0DA` |
| display/body/mono font aliases | `--qm-font-sans` | Inter, Segoe UI, Helvetica Neue, Arial |
| legacy spacing aliases | `--qm-space-*` | package 4/8/12/16/24/32/48/64/96/128 rhythm |
| legacy radius aliases | `--qm-radius-control`, `--qm-radius-card` | 8 px / 16 px |

There is no independent legacy palette: the compatibility layer resolves legacy names onto package tokens. Static audit found zero shipped CSS files containing the retired `#2954d4`, Fraunces, or IBM Plex families, and zero unexplained shell hex colors.

## Design reconciliations

- **Contrast:** package green `#0A8A5B` is retained as the brand accent, but white text on that color measures below 4.5:1. Primary button backgrounds and small green text therefore use the package's own `--qm-green-dark` (`#087247`, 5.99:1). This is an accessibility use of a supplied token, not a new palette.
- **Reduced motion on the VPS:** with `prefers-reduced-motion`, the funnel starts at a static frame and the visible 44 px `Play funnel` control remains enabled. One click explicitly starts it; a second pauses it without resetting. The browser test observed time move from `0` to `0.6833`, then remain at `0.6833` while paused.
- **Evidence versus illustration:** records and funnel census values come from `public-data/funnel-stats.json`. Decorative chart/funnel marks carry `illustrative` labels; no fabricated dashboard or trading claim was introduced.
- **Archive:** `build_archive_v31.py` regenerates the shared shell and 3,339 detail pages. Its pseudo-symbol filter rejects exact `QM5`, `QM5_*`, `FX8*`, and `SLOT<digits>*` identities. One pre-existing narrow-range-open-break horizon inconsistency remains a source-data warning; no value was altered to hide it.

## Contrast measurements

Measured in headless Chrome from computed final colors:

| Foreground / background | Ratio |
|---|---:|
| Carbon / Surface | 17.41:1 |
| Slate / Surface | 4.91:1 |
| Slate / Cloud | 4.57:1 |
| Green Dark / Surface | 5.99:1 |
| Surface / Green Dark | 5.99:1 |
| Positive / Surface | 5.35:1 |
| Negative / Surface | 5.25:1 |
| Warning / Surface | 4.97:1 |

All tested body/status combinations meet WCAG AA normal-text contrast.

## Browser and static verification

Commands, from the site worktree:

```text
python -m py_compile tools/site-build/apply_design_system_v1.py tools/site-build/build_archive_v31.py
node --check tools/site-build/verify_design_system_v1.mjs
node tools/site-build/verify_design_system_v1.mjs --out C:/QM/worktrees/codex-orchestration-1/docs/ops/evidence/2026-09-07_website_design_system_v1/cdp_verification.json
git show --check abb22f9ed64e6ef44a46ee557498b5748c650476
```

Result: PASS. The dependency-free CDP audit is the available offline Lighthouse-style check. It reports:

- 3,369 HTML files checked; 3,339 archive detail pages present.
- Zero missing token links, wrong stylesheet orders, old font references, old-blue references, public exposure matches, stray shell palette values, or CRLF files.
- HTTP 200 for `/`, `/strategies/`, a generated detail page, and `/blog`.
- No browser runtime errors, desktop/mobile overflow, or undersized tested mobile controls.
- Exact hero copy/actions, six-item navigation, Inter computed font stack, real/illustrative labels, reduced-motion default and explicit override all passed.
- Archive row count is 3,339 and the sampled detail page retains visible navigation at scroll position zero.

Machine-readable evidence: [cdp_verification.json](cdp_verification.json).

## Screenshots

Before baseline:

- `screenshots/before/home_desktop.png` — 1,440 px
- `screenshots/before/home_mobile.png` — 375 px preserved baseline (closest available to the requested 390 px)
- `screenshots/before/archive_list.png` — 1,440 px
- `screenshots/before/archive_detail.png` — 1,440 px
- `screenshots/before/blog.png` — 1,440 px reconstructed comparator

The first four before images are byte-for-byte copies of the immediately preceding completed site-review evidence at commit `d50fa5933f26fa1a30f986943103897fb48238ca`; that state was the input baseline for this restyle. No new pre-change capture was possible after the working copy had been migrated. The blog comparator was reconstructed transparently by loading `/blog`, removing final stylesheets, and injecting the preserved pre-change `source_before/style.css`; it is a palette/typography comparator and is not claimed as a contemporaneous screenshot.

After implementation:

- `screenshots/after/home_desktop.png` — 1,440 px
- `screenshots/after/home_mobile.png` — 390 px
- `screenshots/after/archive_list.png` — 1,440 px
- `screenshots/after/archive_detail.png` — 1,440 px
- `screenshots/after/blog.png` — 1,440 px

## Scope and safety

- No production or preview deployment was performed. `OWNER-DEC-WEBSITE-DEPLOY-20260905` remains an OWNER decision.
- The unrelated pre-existing untracked `astra-rework/`, `assets/test.png`, and `*.bak_pre_astra` files were not staged.
- No terminal, worker, live-trading, registry, verdict, threshold, or strategy behavior was touched.
