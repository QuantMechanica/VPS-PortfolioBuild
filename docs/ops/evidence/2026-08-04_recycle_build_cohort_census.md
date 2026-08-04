# RECYCLE build cohort census — 2026-08-04

**Verdict:** mechanical census complete; no router state was changed by this census. The live snapshot contains **412 ticket rows** (411 unique EA identities), replacing the task payload's older approximate count. The result is decision support only: Claude/OWNER retains every close, retire, rebuild, or requeue decision.

## Snapshot and method

- Snapshot UTC: `2026-08-04T10:05:43Z`.
- Read-only SQLite source: `D:/QM/strategy_farm/state/farm_state.sqlite` (`mode=ro`).
- Registry: `C:/QM/repo/framework/registry/ea_id_registry.csv`; SHA-256 `603ced8509c7b0e9486b6216f6cf254478ba774ba8234a0b1270d8ed30ee55df`.
- Scope: every `RECYCLE` `build_ea` row plus the single `review_ea` whose ID starts `1099e860`, ordered by numeric priority then task ID.
- Evidence boundary: task payload, card path/frontmatter, current EA directory, EA-ID registry, and pipeline database only. No deep card re-review was performed.
- Historical pre-Q phase labels, where present in the database, are rendered only as their Q-equivalent.
- Classification precedence: current EA directory + registry row → `ALREADY_BUILT`; non-approved/unresolved card → `CARD_MISSING_OR_BLOCKED`; exact approved slug registered under another EA ID → `SUPERSEDED`; current frequency/closed-family doctrine → `DOCTRINE_DEAD`; only the remaining approved, represented-nowhere set → `REBUILD_CANDIDATE`.
- `ALREADY_BUILT` follows the task's requested mechanical definition (EA directory + registry row); it does not assert deployability, certification, or profitability.

## Summary

| Class | Ticket rows | Unique EA IDs | Mechanical reading (decision remains Claude/OWNER) |
|---|---:|---:|---|
| `ALREADY_BUILT` | 282 | 281 | Stale build/review ticket; inspect/close rather than duplicate the registered package. |
| `CARD_MISSING_OR_BLOCKED` | 4 | 4 | No build admission; keep stopped unless governance changes. |
| `DOCTRINE_DEAD` | 0 | 0 | Current doctrine rejects rebuilding this family. |
| `SUPERSEDED` | 126 | 126 | Old-ID ticket points to an exact strategy slug already shipped under another ID. |
| `REBUILD_CANDIDATE` | 0 | 0 | Only this class is eligible for an OWNER capacity decision. |
| **Total** | **412** | **411** | |

Additional mechanical checks:

- Priority distribution: p1=12, p12=2, p15=98, p50=298, p95=1, p96=1.
- Resolved card buckets: APPROVED=404, DRAFT=3, REJECTED=5.
- `ALREADY_BUILT` pipeline history: PASS history on 98 ticket rows; pipeline rows without PASS/retire on 16; no pipeline rows on 168; retirement-history rows are included explicitly in per-ticket reasons (none if absent).
- `SUPERSEDED` rows with an exact active registry alias: 126.

## Decision table

| Priority | Ticket | Type | EA ID | Card path | Class | One-line reason |
|---:|---|---|---|---|---|---|
| 1 | 043c2a30 | build_ea | QM5_11896 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11896_morris-rsi10-divergence-candle-confirm.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 1 | 0daf10dc | build_ea | QM5_11901 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11901_london-asia-range-breakout-m15.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 1 | 1f400c88 | build_ea | QM5_11899 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11899_psar-ao-ac-confluence-h1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 1 | 2daf62c7 | build_ea | QM5_11900 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11900_kobasfx-4ema-macd-sentiment-h1.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 1 | 589b946f | build_ea | QM5_11912 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11912_cheng-triangle-2touch-second-break-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 1 | 5fad3240 | build_ea | QM5_11905 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11905_hui-chan-shiryaev-zhou-3day-d1.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 1 | 7a00522d | build_ea | QM5_11895 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11895_carter-ema-cross-rsi-candlestick-confirmation.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 1 | 7ddcaec6 | build_ea | QM5_11906 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11906_watthana-candlestick-rsi-stoch-ea-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 1 | aa39fa26 | build_ea | QM5_11915 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11915_fielder-deadtime-midpoint-reversion-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 1 | db2735b1 | build_ea | QM5_11902 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11902_bermuda-triangle-123-fib-extension-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 1 | ef231a79 | build_ea | QM5_11913 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11913_crue-ichimoku-5line-alignment-d1.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 1 | f1bdb9f3 | build_ea | QM5_11907 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_11907_davey-momentum-big-range-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 12 | 4f5ca647 | build_ea | QM5_2013 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2013_nnfx-v2-carry-momentum-filter.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 12 | 6bf69ce4 | build_ea | QM5_1084 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1084_chan-xle-basket-z2.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 00654c21 | build_ea | QM5_1634 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1634_mql5-consolid-break.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 015c2005 | build_ea | QM5_10150 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10150_sma50-200.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | 05203c02 | build_ea | QM5_12108 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1271_hopwood-cup-of-coffee-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 085278aa | build_ea | QM5_9121 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9121_aa-tma10-cross.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 0cc17076 | build_ea | QM5_10020 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10020_rw-spx-overnight.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 0f789eaa | build_ea | QM5_10711 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10711_tv-mktopen-imp.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 0ff5301f | build_ea | QM5_10692 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10692_tv-ls-ms.md | ALREADY_BUILT | EA dir + registry row (active); Q10 PASS history. |
| 15 | 152ee474 | build_ea | QM5_10374 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10374_et-ma-stack30.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 1b97c75f | build_ea | QM5_10561 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10561_mql5-delta-mfi.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 1bb278a3 | build_ea | QM5_1258 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1258_hopwood-bermaui-rsi-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 1e2d2400 | build_ea | QM5_10622 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10622_mql5-20200.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 2091a9fa | build_ea | QM5_10581 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10581_mql5-lr-slope.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 23f15867 | build_ea | QM5_10468 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10468_mql5-psar.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 2592752f | build_ea | QM5_12111 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1274_bressert-double-stochastic-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 26dd277d | build_ea | QM5_10713 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10713_tv-ultsmc-ema.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 29fe6323 | build_ea | QM5_10023 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10023_rw-eom-flow.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 2b84d6c6 | build_ea | QM5_10038 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10038_ff-4x25ema-mtf-h4.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | 2d83e1dc | build_ea | QM5_12112 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1275_channel-keltner-trend.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | 30752afb | build_ea | QM5_10126 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10126_carver-sma.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 36caa7af | build_ea | QM5_10439 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10439_mql5-asq-break.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 3b4f50f0 | build_ea | QM5_10712 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10712_tv-ict-retest.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 3e541bbb | build_ea | QM5_10772 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10772_tv-ny-vwap-ret.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 43fb67c0 | build_ea | QM5_10710 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10710_tv-asian-retbrk.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 4b38f7f1 | build_ea | QM5_10075 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10075_gh-santi-pa2.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 5216ca2f | build_ea | QM5_12109 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1272_camarilla-weekly-pivots-swing.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 57ceb773 | build_ea | QM5_10260 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10260_cieslak-fomc-cycle-idx.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | 58529de4 | build_ea | QM5_10562 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10562_mql5-donch-sys.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 5c0e69f3 | build_ea | QM5_10605 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10605_mql5-stepxccx.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 630cf64e | build_ea | QM5_10427 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10427_et-3bar-xma.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 63f76377 | build_ea | QM5_10163 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10163_tv-rsi-macd-long.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | 64a1bc8c | build_ea | QM5_10517 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10517_mql5-pct-chan.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 64d8e1e8 | build_ea | QM5_10478 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10478_mql5-bago.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 6535bc85 | build_ea | QM5_1099 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1099_dax-weekly-donchian50-breakout.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 659ff715 | build_ea | QM5_10566 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10566_mql5-ravi-hist.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | 669cff79 | build_ea | QM5_10381 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10381_et-macd-pos.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 676a3447 | build_ea | QM5_10717 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10717_edgelab-xsec-fx-momentum.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 68a9ba8c | build_ea | QM5_10760 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10760_tv-iu-orb.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 6940fd50 | build_ea | QM5_10603 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10603_mql5-mafn.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 6b6d0752 | build_ea | QM5_10027 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10027_rw-fx-carry.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 70a29f36 | build_ea | QM5_10759 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10759_tv-scp-score.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 75362314 | build_ea | QM5_10034 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10034_rw-pairs-z.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 7584a464 | build_ea | QM5_10542 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10542_mql5-bigdog.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 774e52ce | build_ea | QM5_10476 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10476_mql5-pamxa.md | ALREADY_BUILT | EA dir + registry row (active); Q09_PORTFOLIO PASS history. |
| 15 | 78460a75 | build_ea | QM5_10676 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10676_tv-pdh-vwap.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 78f7eaab | build_ea | QM5_10769 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10769_tv-axis-rev.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 7907b0ff | build_ea | QM5_10026 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10026_rw-fx-squeeze-mr.md | ALREADY_BUILT | EA dir + registry row (active); Q06 PASS history; deepest Q07. |
| 15 | 7c474fc4 | build_ea | QM5_12117 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1296_demark-td-sequential-h4.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 7db44e63 | build_ea | QM5_10488 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10488_mql5-ccirsi.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 7e2eafb9 | build_ea | QM5_10568 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10568_mql5-xdpo-hist.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 7f23e6cb | build_ea | QM5_10569 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10569_mql5-supertrend.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q09_PORTFOLIO. |
| 15 | 82ec4a7a | build_ea | QM5_10452 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10452_mql5-div3.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | 860402ff | build_ea | QM5_10693 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10693_tv-smp-gma-bos.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 8f43d17c | build_ea | QM5_10114 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10114_tv-golden-cross-50-200.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q09_PORTFOLIO. |
| 15 | 95edd8d3 | build_ea | QM5_10743 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10743_tv-nq-orb.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 96066d66 | build_ea | QM5_10024 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10024_rw-fx-comm-basket.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 9618f47c | build_ea | QM5_10076 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10076_gh-santi-cci2ma.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 98208be5 | build_ea | QM5_10705 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10705_tv-liq-trap.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | 9a02ee33 | build_ea | QM5_10042 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10042_ff-notable-numbers.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | 9a76907d | build_ea | QM5_10438 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10438_mql5-fvg-pull.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | 9bc1a94c | build_ea | QM5_12116 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1291_carter-ttm-squeeze-h1.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | 9e872ce2 | build_ea | TBD | C:/QM/repo/docs/research/CARD_DRAFT_TURN_OF_MONTH_INDEX_LONG_2026-07-16.md | CARD_MISSING_OR_BLOCKED | card bucket=DRAFT, frontmatter=APPROVED; not build-admissible. |
| 15 | 9f7ab554 | build_ea | QM5_10372 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10372_et-1005-bracket.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | a4003dc3 | build_ea | QM5_12113 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1288_bb-width-regime-breakout.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | a9c6dde6 | build_ea | QM5_10527 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10527_mql5-vortex-brk.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | affbb364 | build_ea | QM5_10069 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10069_mql5-hs-rev.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q09_PORTFOLIO. |
| 15 | b99b9910 | build_ea | QM5_10688 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10688_tv-ict-sess-v3.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | b9b00b59 | build_ea | QM5_10571 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10571_mql5-pchan-stop.md | ALREADY_BUILT | EA dir + registry row (active); Q06 PASS history; deepest Q07. |
| 15 | baf43eca | build_ea | QM5_10430 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10430_et-cum-rsi2.md | ALREADY_BUILT | EA dir + registry row (active); Q06 PASS history; deepest Q07. |
| 15 | bbb0cdb2 | build_ea | QM5_10762 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10762_tv-trend-brk.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | c20945d0 | build_ea | QM5_9132 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9132_aa-currency-econmom.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q03. |
| 15 | c3c8f065 | build_ea | QM5_10489 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10489_mql5-trendmgr.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | cb8c169e | build_ea | QM5_12115 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1290_classic-pivot-points-fade-break.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | cbc142d7 | build_ea | QM5_10589 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10589_mql5-leading.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | d2edaf18 | build_ea | QM5_10457 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10457_mql5-keltner.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | d36d5b71 | build_ea | QM5_10677 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10677_tv-session-sweep.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | d3f415e5 | build_ea | QM5_10727 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10727_tv-dy-vol-push.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | d51eb0c4 | build_ea | QM5_1056 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1056_moskowitz-tsmom-multiasset.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | d51f0c66 | build_ea | QM5_10570 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10570_mql5-stepma-nrtr.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | d87095b6 | build_ea | QM5_10770 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10770_tv-bigdaddy-orb.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | dba5fb5f | build_ea | QM5_10587 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10587_mql5-modopt.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | dc281e0e | build_ea | QM5_10690 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10690_tv-pdh-pdl-rev.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | dde5789f | build_ea | QM5_10771 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10771_tv-trail-hunter.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | de283d20 | build_ea | QM5_10134 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10134_bb-double.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 15 | de448769 | build_ea | QM5_10694 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10694_tv-ict-silver.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | df232a93 | build_ea | QM5_10429 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10429_et-rsi2-es.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | e0a64a75 | build_ea | QM5_10135 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10135_bbwidth-ema.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | e16fe7e8 | build_ea | QM5_10584 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10584_mql5-digvar.md | ALREADY_BUILT | EA dir + registry row (active); Q06 PASS history; deepest Q07. |
| 15 | e4585374 | build_ea | QM5_10019 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10019_rw-fx-nfp-drift.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 15 | e8f0ddba | build_ea | QM5_10513 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10513_mql5-ichimoku.md | ALREADY_BUILT | EA dir + registry row (active); Q10 PASS history. |
| 15 | ea1fd06d | build_ea | QM5_10440 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10440_mql5-ohlc-mtf.md | ALREADY_BUILT | EA dir + registry row (active); Q09_PORTFOLIO PASS history; deepest Q10. |
| 15 | f1e850c3 | build_ea | QM5_10454 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10454_mql5-supermac.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 15 | f229d72a | build_ea | QM5_10567 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10567_mql5-aroonhorn.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | f533c3ae | build_ea | QM5_10627 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10627_tq-spy-zscore.md | ALREADY_BUILT | EA dir + registry row (active); Q07 PASS history; deepest Q08. |
| 15 | f6ef0ef8 | build_ea | QM5_10141 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10141_rsi-meanrev.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | f6faae44 | build_ea | QM5_12110 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1273_mtf-stochastic-confirmation.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | fcf93b69 | build_ea | QM5_10022 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10022_rw-dual-mom.md | ALREADY_BUILT | EA dir + registry row (active); Q06 PASS history; deepest Q07. |
| 15 | fe0bd00e | build_ea | QM5_10709 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10709_tv-orb-multitp.md | ALREADY_BUILT | EA dir + registry row (active); Q03 PASS history; deepest Q04. |
| 15 | fe5d5eb9 | build_ea | QM5_10481 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_10481_mql5-exec-ao.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 50 | 00946895 | build_ea | QM5_1605 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1605_ehlers-spectral-dilation-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 01653662 | build_ea | QM5_1607 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1607_aa-mom-tol-band.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 01bd8a9d | build_ea | QM5_12944 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12944_sperandeo-trend-fault-line-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 02da6437 | build_ea | QM5_1624 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1624_ehlers-adaptive-cg-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12247 (active); no pipeline rows. |
| 50 | 0330fade | build_ea | QM5_9277 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9277_mql5-lw-obj-pull.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 037f7a25 | build_ea | QM5_9964 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9964_bandy-wide-range-bar-continuation-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 04125547 | build_ea | QM5_2022 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2022_ehlers-hilbert-phase-trend-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12284 (active); no pipeline rows. |
| 50 | 04f349cc | build_ea | QM5_9251 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9251_mql5-kagi-reversal.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 055d165f | build_ea | QM5_1537 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1537_aa-vol-sma10.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 0568432f | build_ea | QM5_9104 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9104_mql5-bb-sideways.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 05d72df0 | build_ea | QM5_1437 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1437_carter-ttm-squeeze-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12200 (active); no pipeline rows. |
| 50 | 084be1d0 | build_ea | QM5_9169 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9169_tv-mou-triple-lens-mtf.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 098a6f11 | build_ea | QM5_1578 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1578_hopwood-ts3-standalone-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12238 (active); no pipeline rows. |
| 50 | 0a7dec9e | build_ea | QM5_12937 | D:/QM/strategy_farm/artifacts/cards_rejected/QM5_12937_demark-td-termination-count-alt-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 0a9b9637 | build_ea | QM5_1526 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1526_demark-td-open-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12226 (active); no pipeline rows. |
| 50 | 0bf5bbf0 | build_ea | QM5_9304 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9304_mql5-nrtr-flip.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 0d36cc20 | build_ea | QM5_12942 | D:/QM/strategy_farm/artifacts/cards_draft/QM5_12942_ehlers-ebsw-cycle-composite-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 0d490609 | build_ea | QM5_1409 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1409_wyckoff-sign-of-strength-phase-d-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12179 (active); no pipeline rows. |
| 50 | 0f0a86ae | build_ea | QM5_1912 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1912_hopwood-asc-trend-channel-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12274 (active); no pipeline rows. |
| 50 | 1017e601 | build_ea | QM5_9273 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9273_mql5-rsi-hidden-div.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 10837ff7 | build_ea | QM5_1438 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1438_demark-td-demarker-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12201 (active); no pipeline rows. |
| 50 | 10f2e21f | build_ea | QM5_12926 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12926_renko-color-streak-h1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 11468a5a | build_ea | QM5_12922 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12922_ariel-first-half-month-idx.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 123a5ce6 | build_ea | QM5_1595 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1595_sperandeo-2b-pivot-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12244 (active); no pipeline rows. |
| 50 | 125751de | build_ea | QM5_1635 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1635_mql5-donchian-break.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 12829c50 | build_ea | QM5_1401 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1401_harmonic-shark-xabcd-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 13d9b822 | build_ea | QM5_2242 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2242_demark-td-magic-letters-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12303 (active); no pipeline rows. |
| 50 | 14432f77 | build_ea | QM5_1417 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1417_classical-pennant-continuation-h1.md | SUPERSEDED | exact approved slug is registered as QM5_12182 (active); no pipeline rows. |
| 50 | 1477e9b6 | build_ea | QM5_1594 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1594_hopwood-ts6-standalone-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12243 (active); no pipeline rows. |
| 50 | 14d9adac | build_ea | QM5_9147 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9147_aa-ew6-ma12.md | SUPERSEDED | exact approved slug is registered as QM5_12327 (active); no pipeline rows. |
| 50 | 14e4021c | build_ea | QM5_12954 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12954_pring-coppock-h4-variant.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 15d9681a | build_ea | QM5_2298 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2298_williams-smash-day-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12308 (active); no pipeline rows. |
| 50 | 181b8a00 | build_ea | QM5_9165 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9165_tv-joovier-london-session-breakout.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 18520109 | build_ea | QM5_12941 | D:/QM/strategy_farm/artifacts/cards_draft/QM5_12941_hopwood-bermaui-macd-h4-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 19c8295f | build_ea | QM5_12920 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12920_qp-pre-election-sp500.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 1b1dd349 | build_ea | QM5_9973 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9973_bandy-ibs-extreme-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); Q04 PASS history; deepest Q05. |
| 50 | 1b490cf7 | build_ea | QM5_9465 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9465_connors-rsi25-d1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 1c2c6857 | build_ea | QM5_1968 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1968_chande-aroon-oscillator-cross-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12280 (active); no pipeline rows. |
| 50 | 1f7c24c5 | build_ea | QM5_9232 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9232_mql5-bwmfi-ma.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 1fd88db4 | build_ea | QM5_2461 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2461_brooks-failed-wedge-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12321 (active); no pipeline rows. |
| 50 | 2189218c | build_ea | QM5_9216 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9216_mql5-bull-ema.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 2201ca64 | build_ea | QM5_2408 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2408_williams-mmm-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12318 (active); no pipeline rows. |
| 50 | 22b0307b | build_ea | QM5_1485 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1485_bw-awesome-oscillator-saucer-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 2321b9ed | build_ea | QM5_9965 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9965_bandy-index-gap-and-go-continuation.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 240c7757 | build_ea | QM5_1529 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1529_ehlers-reflex-indicator-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12228 (active); no pipeline rows. |
| 50 | 25102f3e | build_ea | QM5_9914 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9914_bandy-zlema-distance-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 27fb255a | build_ea | QM5_12612 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12612_tsmom-12m-vol-scaled-ndx.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 29c5ec88 | build_ea | QM5_9254 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9254_mql5-ga-break.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 2a3580e3 | build_ea | QM5_12939 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12939_carney-alternate-bat-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 2c0f932b | build_ea | QM5_1914 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1914_colby-mfi-divergence-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12276 (active); no pipeline rows. |
| 50 | 2c2ae3bf | build_ea | QM5_1650 | D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1650_hopwood-bermaui-macd-h4.md | CARD_MISSING_OR_BLOCKED | card bucket=REJECTED, frontmatter=REJECTED; not build-admissible. |
| 50 | 2cdbbe4e | build_ea | QM5_9010 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9010_mql5-envelope-bounce.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 2dc0025a | build_ea | QM5_9720 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9720_bandy-adx-regime-filter-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 2e1568bf | build_ea | QM5_1583 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1583_aa-sma10-tr4-risk.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 2f463fcc | build_ea | QM5_1859 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1859_carney-pesavento-ratio-symmetry-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12271 (active); no pipeline rows. |
| 50 | 30bbd5e2 | build_ea | QM5_2189 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2189_brooks-h1-l1-pullback-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12300 (active); no pipeline rows. |
| 50 | 3129e748 | build_ea | QM5_2241 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2241_ehlers-inverse-fisher-transform-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12302 (active); no pipeline rows. |
| 50 | 315fdaf0 | build_ea | QM5_1611 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1611_aa-dsp-hpes024.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 31cb89f3 | build_ea | QM5_9196 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9196_mql5-macd-obv-zero.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 32fe6e27 | build_ea | QM5_1538 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1538_aa-tsmom-1-3-12.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 335ec1bf | build_ea | QM5_1430 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1430_andrews-pitchfork-parallel-line-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12196 (active); no pipeline rows. |
| 50 | 3386130d | build_ea | QM5_9921 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9921_bandy-cmo-extreme-fade-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 34ffb386 | build_ea | QM5_9579 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9579_bandy-atr-channel-breakout-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 354268b6 | build_ea | QM5_12950 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12950_mql5-ad-price-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 35c9e6ad | build_ea | QM5_9183 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9183_jstm-parabolic-sar-flip.md | SUPERSEDED | exact approved slug is registered as QM5_12332 (active); no pipeline rows. |
| 50 | 36e5bbfa | build_ea | QM5_9934 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9934_bandy-ulcer-index-spike-rsi2-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 37bb113b | build_ea | QM5_1445 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1445_carney-three-drive-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12205 (active); no pipeline rows. |
| 50 | 37f0eab1 | build_ea | QM5_1524 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1524_williams-r-of-rsi-composite-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12224 (active); no pipeline rows. |
| 50 | 39477905 | build_ea | QM5_9922 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9922_bandy-vortex-crossover-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 3b5aa26f | build_ea | QM5_12928 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12928_renko-double-flip-confirm-h1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 3b5bc110 | build_ea | QM5_1562 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1562_demark-td-range-projection-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 3c27df92 | build_ea | QM5_2299 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2299_brooks-final-flag-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12309 (active); no pipeline rows. |
| 50 | 3cd229bb | build_ea | QM5_9182 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9182_jstm-heikin-ashi-trend-long.md | SUPERSEDED | exact approved slug is registered as QM5_12331 (active); no pipeline rows. |
| 50 | 3d286159 | build_ea | QM5_1533 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1533_williams-sentiment-index-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12232 (active); no pipeline rows. |
| 50 | 3df5d260 | build_ea | QM5_1636 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1636_sperandeo-3day-pivot-rule-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 3f4980fb | build_ea | QM5_9230 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9230_mql5-alligator-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 3fdd2c8d | build_ea | QM5_2409 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2409_demark-td-lines-active-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12319 (active); no pipeline rows. |
| 50 | 3ff472a0 | build_ea | QM5_9516 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9516_mql5-l1-ma.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 4063b233 | build_ea | QM5_9112 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9112_aa-des-trend0177.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 41a34361 | build_ea | QM5_1521 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1521_ehlers-predictive-moving-average-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12223 (active); no pipeline rows. |
| 50 | 4283ca39 | build_ea | QM5_1803 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1803_elder-triple-screen-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12267 (active); no pipeline rows. |
| 50 | 4382291e | build_ea | QM5_9103 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9103_mql5-ichi-ten-ki.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 44027948 | build_ea | QM5_1508 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1508_hopwood-triple-trend-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12220 (active); no pipeline rows. |
| 50 | 442039bc | build_ea | QM5_1648 | D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1648_demark-td-sequential-tdst-overlay-h4.md | CARD_MISSING_OR_BLOCKED | card bucket=REJECTED, frontmatter=APPROVED; not build-admissible. |
| 50 | 46327e2e | build_ea | QM5_1582 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1582_ehlers-super-smoother-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 47cbab28 | build_ea | QM5_1966 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1966_colby-demand-index-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12278 (active); no pipeline rows. |
| 50 | 499eaa2a | build_ea | QM5_9910 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9910_bandy-tema-adx-crossover-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 4a5c9ed6 | build_ea | QM5_1671 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1671_ehlers-ebsw-cycle-extract-composite-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 4b0bd563 | build_ea | QM5_9203 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9203_mql5-cci-zero.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 4b9809f2 | build_ea | QM5_9925 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9925_bandy-cci-momentum-breakout-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 4f5b3b2b | build_ea | QM5_12955 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12955_mql5-aroon-cross-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 4fc08ad9 | build_ea | QM5_1402 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1402_harmonic-cypher-xabcd-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 515d6668 | build_ea | QM5_1447 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1447_wilder-parabolic-sar-atr-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12207 (active); no pipeline rows. |
| 50 | 524cca67 | build_ea | QM5_9521 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9521_mql5-hidden-smash.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 528d9db8 | build_ea | QM5_9949 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9949_bandy-bbwidth-contraction-breakout-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 5297d50e | build_ea | QM5_2462 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2462_demark-td-channel-1-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12322 (active); no pipeline rows. |
| 50 | 52ee2c30 | build_ea | QM5_9215 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9215_mql5-bear-ema.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 52fc3ee3 | build_ea | QM5_9406 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9406_qs-daily-mac.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 531a62de | build_ea | QM5_1531 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1531_demark-td-open-bar-reversal-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12230 (active); no pipeline rows. |
| 50 | 5371ab7c | build_ea | QM5_9297 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9297_mql5-cmf-ma-cross.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 545ddaea | build_ea | QM5_1581 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1581_aa-rod-lh-mom.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 55c469d0 | build_ea | QM5_1618 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1618_mql5-ma-support.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 568405c9 | build_ea | QM5_9719 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9719_bandy-percentrank-channel-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 5766506d | build_ea | QM5_1619 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1619_ehlers-adaptive-cg-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 576c773a | build_ea | QM5_1539 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1539_aa-canary-13612w.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 5a6e93c2 | build_ea | QM5_1647 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1647_ehlers-ebsw-cycle-extraction-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12251 (active); no pipeline rows. |
| 50 | 5abe871c | build_ea | QM5_1604 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1604_sperandeo-123-reversal-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 5adea48e | build_ea | QM5_1967 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1967_pring-kst-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12279 (active); no pipeline rows. |
| 50 | 5ce8d642 | build_ea | QM5_1606 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1606_aa-gvmt-robust.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 5d74c748 | build_ea | QM5_1553 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1553_hopwood-bermaui-rsi-mtf-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 5de38382 | build_ea | QM5_9467 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9467_connors-crsi-pullback-d1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 5e7ee21a | build_ea | QM5_1651 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1651_ehlers-ebsw-cycle-extract-composite-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12259 (active); no pipeline rows. |
| 50 | 5fca8ef3 | build_ea | QM5_2355 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2355_demark-td-clopwin-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12315 (active); no pipeline rows. |
| 50 | 61ccc27f | build_ea | QM5_1426 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1426_classical-complex-head-shoulders-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12192 (active); no pipeline rows. |
| 50 | 62ac4ac4 | build_ea | QM5_1507 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1507_ehlers-mama-fama-cross-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12219 (active); no pipeline rows. |
| 50 | 63c1032c | build_ea | QM5_9583 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9583_ff-brv-sr-fade.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 63c95ae9 | build_ea | QM5_12921 | D:/QM/strategy_farm/artifacts/cards_rejected/QM5_12921_qp-january-barometer-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 6550a1f8 | build_ea | QM5_2297 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2297_sperandeo-channel-buster-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12307 (active); no pipeline rows. |
| 50 | 655d9d8a | build_ea | QM5_12924 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12924_hopwood-stochastic-cross-h1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 6738a92f | build_ea | QM5_1439 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1439_wyckoff-spring-test-phase-c-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12202 (active); no pipeline rows. |
| 50 | 67488097 | build_ea | QM5_9363 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9363_mql5-ichi-spanb-bounce.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 690cd9ab | build_ea | QM5_1612 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1612_aa-dsp-hplwma10.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 69ad8ea9 | build_ea | QM5_9912 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9912_bandy-zscore-returns-5d-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 69bced3f | build_ea | QM5_2190 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2190_chande-qstick-zero-cross-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12301 (active); no pipeline rows. |
| 50 | 6a0ae4d5 | build_ea | QM5_9284 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9284_brooks-tight-trading-range-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12345 (active); no pipeline rows. |
| 50 | 6a79738c | build_ea | QM5_9168 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9168_tv-elaris-confluence-scalping.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 6bfd24a6 | build_ea | QM5_9924 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9924_bandy-dema-crossover-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 6c3610cf | build_ea | QM5_1617 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1617_mql5-sar-sma-rapid.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 6c86e8b0 | build_ea | QM5_1488 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1488_as-ddm-pods.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 6cf3af36 | build_ea | QM5_1653 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1653_sperandeo-test-of-strength-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12261 (active); no pipeline rows. |
| 50 | 6e233c53 | build_ea | QM5_2352 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2352_williams-3day-failure-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12312 (active); no pipeline rows. |
| 50 | 70805206 | build_ea | QM5_2243 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2243_chande-aroon-divergence-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12304 (active); no pipeline rows. |
| 50 | 718716e3 | build_ea | QM5_12927 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12927_chande-vidya-trend-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 71af1255 | build_ea | QM5_9264 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9264_mql5-demarker-div.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 72766d7b | build_ea | QM5_9176 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9176_mql5-sar-rvi-reverse.md | SUPERSEDED | exact approved slug is registered as QM5_12328 (active); no pipeline rows. |
| 50 | 72e5f0a9 | build_ea | QM5_1585 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1585_demark-td-differential-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 749f4524 | build_ea | QM5_2020 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2020_chaikin-volatility-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12282 (active); no pipeline rows. |
| 50 | 77bb60df | build_ea | QM5_1425 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1425_classical-triple-bottom-reversal-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12191 (active); no pipeline rows. |
| 50 | 7830f003 | build_ea | QM5_1459 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1459_as-lumber-gold.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 7ac78155 | build_ea | QM5_1457 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1457_as-predict-bonds.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 7b3784ed | build_ea | QM5_9211 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9211_mql5-trendloom.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 7b431d7a | build_ea | QM5_12929 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12929_brooks-expanded-micro-channel-h1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 7b77b2b6 | build_ea | QM5_9224 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9224_mql5-vol-ma-cross.md | SUPERSEDED | exact approved slug is registered as QM5_12343 (active); no pipeline rows. |
| 50 | 7bc95960 | build_ea | QM5_9353 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9353_chande-stochrsi-base-cross-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 7c217c65 | build_ea | QM5_9223 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9223_mql5-demarker-div.md | SUPERSEDED | exact approved slug is registered as QM5_12342 (active); no pipeline rows. |
| 50 | 7c31ab3a | build_ea | QM5_1550 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1550_bressert-double-cycle-composite-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12235 (active); no pipeline rows. |
| 50 | 7dccf57e | build_ea | QM5_1408 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1408_classical-bull-flag-continuation-h1.md | SUPERSEDED | exact approved slug is registered as QM5_12178 (active); no pipeline rows. |
| 50 | 7f5be227 | build_ea | QM5_9947 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9947_bandy-double-bottom-formalised-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 810145d0 | build_ea | QM5_1629 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1629_ehlers-cybernetic-cycle-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12248 (active); no pipeline rows. |
| 50 | 8262515b | build_ea | QM5_2410 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2410_ehlers-universal-oscillator-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12320 (active); no pipeline rows. |
| 50 | 8393fe44 | build_ea | QM5_12938 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12938_hopwood-bermaui-dss-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 83f3bde2 | build_ea | QM5_12952 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12952_mql5-force-ema-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 8511bd8a | build_ea | QM5_2187 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2187_demark-td-trap-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12298 (active); no pipeline rows. |
| 50 | 86377647 | build_ea | QM5_9983 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9983_bandy-wide-range-bar-fade-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 897e7e91 | build_ea | QM5_1857 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1857_chande-forecast-oscillator-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12269 (active); no pipeline rows. |
| 50 | 8a0f2cf4 | build_ea | QM5_9410 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9410_mql5-boom-crash.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 8b3cc484 | build_ea | QM5_9963 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9963_bandy-lr-slope-sign-flip-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 8c3ddf84 | build_ea | QM5_9280 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9280_brooks-failed-triangle-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 8d108839 | build_ea | QM5_2407 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2407_demark-td-clop-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12317 (active); no pipeline rows. |
| 50 | 8d8774bf | build_ea | QM5_1623 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1623_hopwood-bermaui-dss-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12246 (active); no pipeline rows. |
| 50 | 8dcde79a | build_ea | QM5_1441 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1441_aroon-up-down-crossover-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12203 (active); no pipeline rows. |
| 50 | 8eaf03bd | build_ea | QM5_1969 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1969_chande-fo-histogram-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12281 (active); no pipeline rows. |
| 50 | 8f373d2d | build_ea | QM5_1622 | D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1622_demark-td-termination-count-alt-h4.md | CARD_MISSING_OR_BLOCKED | card bucket=REJECTED, frontmatter=APPROVED; not build-admissible. |
| 50 | 8ff4de4c | build_ea | QM5_9231 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9231_mql5-ad-price.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 90ae9c0d | build_ea | QM5_1431 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1431_williams-r-hidden-divergence-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12197 (active); no pipeline rows. |
| 50 | 912be76d | build_ea | QM5_9204 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9204_mql5-mfi-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 9285cf7d | build_ea | QM5_9252 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9252_mql5-ls-trendline.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 932dde11 | build_ea | QM5_1527 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1527_connors-crsi-composite-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12227 (active); no pipeline rows. |
| 50 | 970379cc | build_ea | QM5_9911 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9911_bandy-donchian-20-classic-breakout-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 973e3dce | build_ea | QM5_9225 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9225_mql5-rvi-ma.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 977c8c04 | build_ea | QM5_1673 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1673_sperandeo-tvii-trendline-failure-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 997906f8 | build_ea | QM5_2351 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2351_demark-td-diff-rsi-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12311 (active); no pipeline rows. |
| 50 | 99efdb31 | build_ea | QM5_2354 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2354_brooks-failed-final-flag-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12314 (active); no pipeline rows. |
| 50 | 9a44b91f | build_ea | QM5_1913 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1913_hutson-dpo-zero-cross-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12275 (active); no pipeline rows. |
| 50 | 9a7db6ac | build_ea | QM5_1649 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1649_carney-cypher-pattern-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12250 (active); no pipeline rows. |
| 50 | 9afcf2a0 | build_ea | QM5_9971 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9971_bandy-dpo-zero-cross-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 9c481197 | build_ea | QM5_9113 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9113_aa-ab-velocity.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 9ca8f81d | build_ea | QM5_9721 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9721_ff-dance-ema-touch-h1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 9e8fd51d | build_ea | QM5_9234 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9234_mql5-vol-ma-cross.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | 9fd339d0 | build_ea | QM5_9717 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9717_bandy-pir-position-in-range-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | a0768e09 | build_ea | QM5_9979 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9979_bandy-index-gap-fade-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | a2180685 | build_ea | QM5_13031 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_13031_wayward-bbrsi-stopmr.md | ALREADY_BUILT | EA dir + registry row (active); Q02 PASS history; deepest Q04. |
| 50 | a2c5e7eb | build_ea | QM5_1702 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1702_ehlers-ebsw-cycle-extraction-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12251 (active); no pipeline rows. |
| 50 | a2d787e7 | build_ea | QM5_1428 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1428_wyckoff-phase-e-mark-up-continuation-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12193 (active); no pipeline rows. |
| 50 | a7124029 | build_ea | QM5_9166 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9166_aa-vol-ma-timing.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | a8942b7a | build_ea | QM5_12925 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12925_hopwood-ma-rainbow-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | a944cf09 | build_ea | QM5_9909 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9909_bandy-lrchannel-breakout-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | aae32e9c | build_ea | QM5_12951 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12951_mql5-chaikin-zero-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | aaf5545d | build_ea | QM5_9461 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9461_gh-rsi-breakin.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | ab03acbe | build_ea | QM5_2135 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2135_chande-trendscore-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12296 (active); no pipeline rows. |
| 50 | ab171f6d | build_ea | QM5_12931 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12931_classical-triple-top-reversal-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | ab456e8d | build_ea | QM5_1557 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1557_aa-zak-psma10.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | ababc064 | build_ea | QM5_1404 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1404_as-raa-unemp-canary.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | aca126f7 | build_ea | QM5_9102 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9102_mql5-ichi-price-ki.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | ad115992 | build_ea | QM5_1593 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1593_carney-bat-pattern-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12242 (active); no pipeline rows. |
| 50 | ad4b4d2e | build_ea | QM5_1416 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1416_classical-bear-flag-continuation-h1.md | SUPERSEDED | exact approved slug is registered as QM5_12181 (active); no pipeline rows. |
| 50 | ad739240 | build_ea | QM5_1429 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1429_wyckoff-phase-e-mark-down-continuation-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12195 (active); no pipeline rows. |
| 50 | add54a46 | build_ea | QM5_9519 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9519_mql5-l1-ema.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | adec96fb | build_ea | QM5_12930 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12930_classical-ascending-triangle-breakout-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | ae818e35 | build_ea | QM5_2025 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2025_williams-accumulation-distribution-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12287 (active); no pipeline rows. |
| 50 | afe18aff | build_ea | QM5_2464 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2464_pring-special-k-histogram-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12324 (active); no pipeline rows. |
| 50 | afeb2af8 | build_ea | QM5_9205 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9205_mql5-stoch-side.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | afed7b7c | build_ea | QM5_9279 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9279_mql5-lw-3bull-fade.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | b15b055e | build_ea | QM5_1525 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1525_ehlers-empirical-mode-decomp-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12225 (active); no pipeline rows. |
| 50 | b1bcaee2 | build_ea | QM5_2188 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2188_chande-ravi-regime-cross-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12299 (active); no pipeline rows. |
| 50 | b3706cb0 | build_ea | QM5_9730 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9730_bandy-weekly-rsi-extreme-d1-trigger-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | b40150ec | build_ea | QM5_12949 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12949_mql5-rvi-ma-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | b436a5ae | build_ea | QM5_1449 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1449_wilder-adx-dmi-crossover-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12208 (active); no pipeline rows. |
| 50 | b454e005 | build_ea | QM5_9256 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9256_mql5-3swing-tl.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | b46d62d8 | build_ea | QM5_1911 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1911_elder-macd-histogram-hook-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12273 (active); no pipeline rows. |
| 50 | b58bf851 | build_ea | QM5_2353 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2353_ehlers-voss-predictor-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12313 (active); no pipeline rows. |
| 50 | b5905d19 | build_ea | QM5_2296 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2296_demark-td-diff-alt-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12306 (active); no pipeline rows. |
| 50 | b5f5f132 | build_ea | QM5_1436 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1436_williams-r-cross-zero-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12199 (active); no pipeline rows. |
| 50 | b770de57 | build_ea | QM5_9904 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9904_ff-sonicr-pvsra-h1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | b84df62f | build_ea | QM5_1592 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1592_ehlers-even-better-sinewave-mtf-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12241 (active); no pipeline rows. |
| 50 | b9563ce6 | build_ea | QM5_1546 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1546_connors-multi-day-high-low-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12233 (active); no pipeline rows. |
| 50 | b994c320 | build_ea | QM5_9275 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9275_mql5-lw-down-close.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | ba175427 | build_ea | QM5_2300 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2300_chande-vidya-slope-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12310 (active); no pipeline rows. |
| 50 | bb6235da | build_ea | QM5_9276 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9276_mql5-lw-3down.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | bd4171e3 | build_ea | QM5_1701 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1701_demark-td-sequential-tdst-overlay-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12253 (active); no pipeline rows. |
| 50 | bd923098 | build_ea | QM5_1405 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1405_as-rpv-bestvalue.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | bf75d014 | build_ea | QM5_9907 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9907_bandy-bbands-midband-reversion-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | bff7eda1 | build_ea | QM5_1802 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1802_elder-impulse-system-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12266 (active); no pipeline rows. |
| 50 | c060d896 | build_ea | QM5_1856 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1856_elder-force-index-spike-reversal-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12268 (active); no pipeline rows. |
| 50 | c0bb9235 | build_ea | QM5_9282 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9282_demark-td-stress-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | c10c1e2c | build_ea | QM5_9933 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9933_bandy-choppiness-index-sideways-rsi2-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | c15f2390 | build_ea | QM5_2186 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2186_ehlers-frama-cross-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12297 (active); no pipeline rows. |
| 50 | c1850502 | build_ea | QM5_1410 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1410_bressert-dual-cycle-oscillator-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12180 (active); no pipeline rows. |
| 50 | c214fe96 | build_ea | QM5_9111 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9111_aa-dlwma-trend10.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | c24879e3 | build_ea | QM5_1643 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1643_aa-overnight-mom.md | SUPERSEDED | exact approved slug is registered as QM5_12249 (retired); no pipeline rows. |
| 50 | c3f03e05 | build_ea | QM5_9580 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9580_bandy-regslope-pullback-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | c4f759a4 | build_ea | QM5_12936 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12936_demark-td-reverse-differential-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | c5306234 | build_ea | QM5_1563 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1563_ehlers-hilbert-transform-dft-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12236 (active); no pipeline rows. |
| 50 | c6387b4b | build_ea | QM5_1652 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1652_demark-td-sequential-tdst-overlay-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12253 (active); no pipeline rows. |
| 50 | c71f308a | build_ea | QM5_9932 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9932_bandy-roc-zscore-normalised-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | c7b9c56d | build_ea | QM5_1345 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1345_chan-cot-spec-momo.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | c81246b6 | build_ea | QM5_1591 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1591_demark-td-anti-differential-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12240 (active); no pipeline rows. |
| 50 | cab1d5d3 | build_ea | QM5_1432 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1432_demark-td-setup-trend-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12198 (active); no pipeline rows. |
| 50 | cadbb75f | build_ea | QM5_9718 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9718_bandy-cumulative-rsi2-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | cbdefd98 | build_ea | QM5_1503 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1503_ehlers-decycler-low-pass-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12215 (active); no pipeline rows. |
| 50 | cc4549cc | build_ea | QM5_9417 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9417_qs-sma10-30.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | cc5c1221 | build_ea | QM5_9222 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9222_mql5-bwmfi-ma.md | SUPERSEDED | exact approved slug is registered as QM5_12339 (active); no pipeline rows. |
| 50 | ce7ef250 | build_ea | QM5_9908 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9908_bandy-psar-flip-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | cf579137 | build_ea | QM5_9961 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9961_bandy-hma-supertrend-confluence-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | d00d7571 | build_ea | QM5_9241 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9241_mql5-engulf-retest.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | d09334f9 | build_ea | QM5_2021 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2021_chaikin-money-flow-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12283 (active); no pipeline rows. |
| 50 | d2b4cd24 | build_ea | QM5_9923 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9923_bandy-hma-crossover-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | d53ecca7 | build_ea | QM5_1504 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1504_raschke-three-little-indians-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12216 (active); no pipeline rows. |
| 50 | d573fb90 | build_ea | QM5_9716 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9716_bandy-trend-stretch-ratio-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | d68dcd1b | build_ea | QM5_1509 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1509_ehlers-even-better-sinewave-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12221 (active); no pipeline rows. |
| 50 | d76d758e | build_ea | QM5_2465 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2465_demark-td-channel-2-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12325 (active); no pipeline rows. |
| 50 | d7c64749 | build_ea | QM5_1965 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1965_elder-bull-bear-power-confirm-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12277 (active); no pipeline rows. |
| 50 | d820be5a | build_ea | QM5_9727 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9727_bandy-atr-ratio-compression-breakout-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | d82200c3 | build_ea | QM5_9303 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9303_mql5-ma-rsi-day.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | d90e7498 | build_ea | QM5_2023 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2023_demark-td-d-wave-wave5-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12285 (active); no pipeline rows. |
| 50 | d9a93eb1 | build_ea | QM5_12932 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12932_wyckoff-phase-e-markdown-continuation-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | dbee1531 | build_ea | QM5_1577 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1577_ehlers-super-smoother-2pole-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12237 (active); no pipeline rows. |
| 50 | de6c76f5 | build_ea | QM5_1613 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1613_aa-dsp-atsmom.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | de7917ef | build_ea | QM5_9913 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9913_bandy-rsi3-low-adx-mr-index.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | df4391d5 | build_ea | QM5_1532 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1532_ehlers-stochastic-rsi-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12231 (active); no pipeline rows. |
| 50 | e15e2aac | build_ea | QM5_1502 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1502_hopwood-reversal-indicator-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12214 (active); no pipeline rows. |
| 50 | e1abae8e | build_ea | QM5_1480 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1480_carter-ttm-trend-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12209 (active); no pipeline rows. |
| 50 | e22dac9b | build_ea | QM5_1157 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1157_plastun-crude-oil-autumn.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | e3a2083b | build_ea | QM5_12943 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12943_robopip-hlhb-trend-catcher-h1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | e3e1d19f | build_ea | QM5_12945 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12945_tv-kn-ema-cross-atr-tp.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | e4ad0c0c | build_ea | QM5_9181 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9181_jstm-dual-thrust-fx-intraday.md | SUPERSEDED | exact approved slug is registered as QM5_12330 (active); no pipeline rows. |
| 50 | e534be5a | build_ea | QM5_1487 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1487_raschke-3-10-oscillator-cross-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | e743e2c4 | build_ea | QM5_1572 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1572_aa-ls-mom-bear24.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | e7fdd25e | build_ea | QM5_9468 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9468_connors-rsi4-3day-d1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | e83eafb9 | build_ea | QM5_1547 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1547_demark-td-range-projection-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12234 (active); no pipeline rows. |
| 50 | ea5327f9 | build_ea | QM5_1407 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1407_classical-symmetric-triangle-breakout-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12177 (active); no pipeline rows. |
| 50 | eb06fcee | build_ea | QM5_9177 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9177_mql5-sar-rvi-zero.md | SUPERSEDED | exact approved slug is registered as QM5_12329 (active); no pipeline rows. |
| 50 | eb71678d | build_ea | QM5_1489 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1489_as-permanent-tactical.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | ef0f2333 | build_ea | QM5_2406 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2406_brooks-triangle-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12316 (active); no pipeline rows. |
| 50 | ef5aad39 | build_ea | QM5_9208 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9208_mql5-obv-price.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | effa9bc8 | build_ea | QM5_1858 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1858_elder-ray-bull-bear-power-zerocross-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12270 (active); no pipeline rows. |
| 50 | f08a89c4 | build_ea | QM5_9209 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9209_mql5-ac-ma-break.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | f0dd1187 | build_ea | QM5_9233 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9233_mql5-ad-div.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | f1d3f7a3 | build_ea | QM5_9167 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9167_tv-boswaves-supertrend-extensions.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | f24b54a3 | build_ea | QM5_9946 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9946_bandy-supertrend-flip-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | f2e0fa39 | build_ea | QM5_12940 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12940_bressert-cycle-trigger-line-h4-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | f3254781 | build_ea | QM5_12946 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12946_mql5-macd-obv-div-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | f3b6bf03 | build_ea | QM5_9972 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9972_bandy-heikin-ashi-color-flip-trend.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | f54bf4d4 | build_ea | QM5_1482 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1482_carney-three-drive-harmonic-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12211 (active); no pipeline rows. |
| 50 | f54dd835 | build_ea | QM5_1481 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1481_wilder-adx-dmi-crossover-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12208 (active); no pipeline rows. |
| 50 | f6029c79 | build_ea | QM5_1645 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1645_carney-cypher-pattern-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12250 (active); no pipeline rows. |
| 50 | f8763caf | build_ea | QM5_1751 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1751_ehlers-hilbert-fft-cleanup-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12264 (active); no pipeline rows. |
| 50 | f990754c | build_ea | QM5_1640 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1640_aa-indmom-12-0.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | f99873db | build_ea | QM5_9220 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9220_mql5-alligator-trend.md | SUPERSEDED | exact approved slug is registered as QM5_12334 (active); no pipeline rows. |
| 50 | f9e1abeb | build_ea | QM5_12923 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12923_hopwood-dmi-cross-h1-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | fb7ed34a | build_ea | QM5_12947 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12947_mql5-ha-ema-trend-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | fc522a96 | build_ea | QM5_12948 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_12948_mql5-mfi-trend-card.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | fcaeb2ee | build_ea | QM5_2463 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2463_sperandeo-spring-channel-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12323 (active); no pipeline rows. |
| 50 | fcd84ecd | build_ea | QM5_2244 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_2244_brooks-h2-l2-pullback-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12305 (active); no pipeline rows. |
| 50 | fcddd7f2 | build_ea | QM5_1444 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1444_vortex-indicator-cross-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12204 (active); no pipeline rows. |
| 50 | fddbb404 | build_ea | QM5_1511 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1511_connors-tps-time-price-score-h4.md | SUPERSEDED | exact approved slug is registered as QM5_12222 (active); no pipeline rows. |
| 50 | ffdb2772 | build_ea | QM5_9281 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9281_demark-td-demand-supply-line-h4.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 50 | ffdbf22e | build_ea | QM5_9466 | D:/QM/strategy_farm/artifacts/cards_approved/QM5_9466_connors-r2-d1.md | ALREADY_BUILT | EA dir + registry row (active); no pipeline rows. |
| 95 | 3dd18aa1 | build_ea | QM5_20160 | C:/QM/repo/strategy-seeds/cards/approved/QM5_20160_xng-fri-trend_card.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |
| 96 | 1099e860 | review_ea | QM5_20160 | C:/QM/repo/artifacts/cards_approved/QM5_20160_xng-fri-trend_card.md | ALREADY_BUILT | EA dir + registry row (active); evidence through Q02; no PASS/retire verdict. |

## Ranked REBUILD shortlist (maximum 15)

Scoring is deliberately bounded to the ratified plan: orthogonality alignment (0–4), expected density (0–3), and asset-survival alignment (0–3). The survival component uses the supplied cohort observations—FX 1.6% and metal 12.2%—without inventing a rate for other assets.

**None.** No ticket survives the mechanical gates as `REBUILD_CANDIDATE`: all approved not-already-built cards in this snapshot have an exact strategy slug registered under another EA ID. Creating a ranked list would duplicate shipped families.

## Verification and non-actions

- Coverage: 412/412 unique ticket IDs emitted; class counts sum to 412; one and only one `1099e860` review ticket included.
- Card resolution: 412/412 ticket rows have a durable card path (including the explicit blocked research draft).
- Shortlist bound: 0 ≤ 15, and every shortlisted row (if any) is classified `REBUILD_CANDIDATE`.
- The generator opened the farm database read-only and issued SELECT statements only.
- No EA build, queue insertion, requeue, card edit, registry edit, pipeline transition, terminal start, backtest interruption, T_Live change, or AutoTrading change was performed.
- Pipeline observations are historical evidence summaries only; this artifact does not create or upgrade a pipeline verdict.
