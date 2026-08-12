# QM5_20186 XAU/XAG same-calendar rank — build and Q02 enqueue

Date: 2026-07-31 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20186_xauxag-samecal`

Strategy ID: `KELOHARJU-FMR-XAUXAG-SAMECAL-2026_S01`

## Outcome

One new low-frequency precious-metals basket was carded, registered, built,
strictly compiled, and handed to the paced Q02 fleet. On the first tradable
XAU D1 bar of each broker month, it compares XAU and XAG average returns for
that same calendar month over the prior ten years, buys the higher-ranked
metal, and shorts the lower-ranked metal.

This is a market-neutral construction intent, not proof of neutrality,
decorrelation, profitability, certification, or portfolio admission. Q02 and
the unchanged downstream gates remain authoritative.

## Source and source-policy boundary

The governed composite packet is
`strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md`:

- Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
  *The Journal of Finance* 71(4), 1557-1590, supply the same-calendar
  commodity ranking construction and five-observation minimum.
- Fuertes, Miffre, and Rallis (2010), "Tactical Allocation in Commodity
  Futures Markets: Combining Momentum and Term Structure Signals,"
  *Journal of Banking & Finance* 34(10), 2530-2548, supply the governed
  XAU/XAG cross-sectional carrier and one-month holding translation.

Both parent packets were already completely reviewed and durably approved.
Fresh routing of the institutional PDF URLs returned
`PERMISSION_REQUIRED` / `DEFERRED:SOURCE_POLICY`; the routing record is
`retrieval_route_20260731.json`. No blocked page content or retrieval bypass
was used. Neither paper tests this exact two-CFD basket, so the conjunction is
declared as a QM falsification hypothesis rather than an inherited result.

## Non-duplicate boundary

The deterministic pre-allocation scan covered 4,243 EA-registry rows and 377
cards and returned `CLEAN`: no exact or fuzzy strategy/mechanic match. Manual
semantic resolution separated the candidate from the existing XAU/XAG
families:

- ratio z-score, OLS-residual, C-MTAR, conditional-quantile, breakout, and
  ten-D1 return-spread EAs estimate different state variables;
- weekend and Monday-difference EAs use session calendars rather than prior
  years' same-month returns;
- `QM5_20057`, `QM5_20184`, and `QM5_20050` rank contiguous one-, three-,
  and twelve-month returns; and
- `QM5_13115_energy-samecal` applies the same source information family to
  the economically different XTI/XNG pair and cannot trade either metal.

The locked ten-prior-year same-calendar estimator on XAU/XAG is therefore a
new carrier, not a post-result parameter variation.

## Frozen baseline

- Logical basket: `QM5_20186_XAU_XAG_SAMECAL_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, magic `201860000`.
- Companion/slot 1: `XAGUSD.DWX`, D1, magic `201860001`.
- Decision: first tradable XAU D1 bar of each broker month.
- History: exactly ten prior occurrences of the decision calendar month,
  retaining synchronized XAU/XAG current and prior month-end timestamps and
  requiring at least five paired samples.
- Signal: mean XAU log return minus mean XAG log return; positive is long XAU
  and short XAG, negative reverses the legs, and exact zero stays flat.
- Attempt ledger: persist the month before history, signal, news, quote,
  spread, sizing, stop, or order gates; no same-month retry.
- Risk: one `RISK_FIXED=1000` package split equally after independent
  `3.5 * ATR(20,D1)` stop normalization; `RISK_PERCENT=0`.
- Lifecycle: next-month close, 40-calendar-day stale close, frozen per-leg
  stops, and immediate orphan, duplicate, direction, or missing-stop repair.
- News axes: OFF. Friday close: disabled.
- No live setfile, parameter sweep, external runtime feed, banned/ML
  indicator, grid, martingale, scale-in, or pyramiding.

## Q01 evidence

- Strategy-card schema lint: PASS; no missing sections and no ML hits.
- Exact G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build/registry/magic guard: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260731_132439/QM5_20186_xauxag-samecal.compile.log`.
- Strict V5 build check: PASS, zero failures and zero warnings.
- Final compile log:
  `C:/QM/repo/framework/build/compile/20260731_132521/QM5_20186_xauxag-samecal.compile.log`.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260731_132521.json`.

The global registry validator continues to report the repository's documented
legacy inventory; it found no QM5_20186-specific identity or collision
failure. Candidate-scoped checks and the strict build check passed. Resolver
generation used `--keep-obsolete` and reported 15,360 rows kept with none
dropped; both QM5_20186 slots resolve through the generated table.

Q01 artifacts span the deterministic pump commits and the scoped feature
commit:

- `b57ae991c8baf8ffff10d6508be233ec9a2fd27b` — EA-ID registry row (alongside
  an unrelated factory artifact committed by the pump).
- `82fc8dc5da8bcc86846268df04b374cf5d074abf` — two magic rows and generated
  resolver.
- `d3d5aa3a1` — source packet, approved card, basket code, EX5, manifest,
  SPEC, and RISK_FIXED setfile.

## Artifact hashes

- MQ5 SHA-256:
  `97462D9E43E0C7AEB16C03D323C97EFAD759C66AF0C234BC0BAAABEAC6066167`.
- EX5 SHA-256:
  `E03C3ED88BF365989951E533C457F1C704028268AD36DB7CF32B7F97487DB2CB`.
- Post-enqueue SPEC SHA-256:
  `52518E32D72969893D578579DFB2491377A1917494023E98BB3FF6C2B17D0F19`.
- Basket manifest SHA-256:
  `AAD645AD8EEAFCDABAA8FB0E4C8627F66817EBFD6E5A66BAC555D9F86865BFC1`.
- RISK_FIXED setfile SHA-256:
  `52C6672D1E1131CF493CD6D66A07B01482D983C38D297786A527F48C5DE0B041`.
- Setfile build hash:
  `3c296e7a37e2ee73a73e3db4f4ef5d4623025752ac9c619fa2faed7b45a646e8`.
- Post-enqueue repository card SHA-256:
  `25EEC45AAF606E9AAE75CE1C353417556CDF24506F867E6D872F39A26224D81E`.
- Source packet SHA-256:
  `9266E47C7F3235D900C9432FEAC33A417807AE1E2CC9685FF2FEADAB46DBF75E`.
- Farm build-bound card SHA-256:
  `0A055EA189DE2FDC44DCF1614D0FBD6D612400BCC353117180532AC8E92316D6`.
- Recorded farm build result SHA-256:
  `5509AAB63CF494133649D6B0AB55131FA51395034F943E6EE183BE36FAF65127`.

## Paced Q02 handoff

- Build task: `3a8b45d9-09a7-4d4a-8ae6-e6a257518805`, status `done`.
- Auto-enqueue: exactly one logical-basket item enqueued, zero skipped.
- Q02 work item: `d6305296-8823-42f6-8604-37725d037617`.
- Phase/kind: `Q02` / `backtest`.
- Logical symbol/timeframe: `QM5_20186_XAU_XAG_SAMECAL_D1` / D1.
- Created: `2026-07-31T13:27:25+00:00`.
- Handoff state at evidence close: `active`, attempt 0, claimed by paced
  terminal T4, with no verdict or evidence yet.

No manual smoke tester or backtest was launched. The immediate pre-enqueue
scan observed five active Q02 claims and only two factory tester processes
(T8 and T10), plus the separate pre-existing T_Live process. The
seven-terminal CPU ceiling was not hit, so canonical Q02 owns the first
CPU-bearing validation pass.

## Safety boundary

No portfolio gate, T_Live file, T_Live manifest, deploy manifest, or live
setfile was changed. AutoTrading was not toggled. The pre-existing T_Live
process was observed read-only only to exclude it from the factory capacity
count.
