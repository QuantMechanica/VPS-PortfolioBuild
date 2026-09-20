# FABLE-DEC-VELOCITY-INTAKE-20260920 — governed force-rebuild wave for the Velocity intake

**Authority:** OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917 (Fable executes; OWNER 2026-09-20:
"solange Kapazitäten irgendwo vorhanden sind, kannst du die Priorität auch jetzt schon auf das
Velocity-Buch legen"). Scope: **COMPILE_EA force-rebuild only** for the intraday cards listed below —
no verdict, gate, live, deployment or portfolio authority. Every rebuilt `.ex5` is a NEW build
identity from Q02 (23.08. identity rule); old rows stay as append-only evidence.

**Why a rebuild is needed:** these EAs carry a COMPILE_OK receipt from 2026-08-26 but the binary the
receipt binds is no longer on disk — the worktree janitor restored the tracked pre-receipt `.ex5`
(class fixed in `cb53061862`) or the untracked binary was never committed (class fixed in
`65dbf8a704`). `intake-first-q02` therefore refuses with `compile_ex5_sha256_mismatch` /
`canonical_ex5_not_exactly_one`, and the ordinary compile guard refuses the rebuild with
`WORK_ITEMS_EXIST` / `EX5_ALREADY_PRESENT`. Fail-closed in the same shape as
OWNER-DEC-REQUEUE-LIFT-20260916-D4: the code list AND this document must both name an EA.

| EA | timeframe | stale COMPILE_OK | refusal at intake |
|---|---|---|---|
| QM5_11299 lwma144-smma5-fractal-m5-scalp | M5 | 42f036ac | compile_ex5_sha256_mismatch |
| QM5_11496 carter-t-ema100-psar-macd64128-m5 | M5 | 4fa03b66 | compile_ex5_sha256_mismatch |
| QM5_11516 carter-t-sma7-21-cci5-m15 | M15 | 20d69e5e | compile_ex5_sha256_mismatch |
| QM5_11518 carter-t-ema5-100-mtf-m15-h1 | M15 | c892c9dd | compile_ex5_sha256_mismatch |
| QM5_11291 tc20-ema18-28-wma5-12-rsi21-h1 | H1 | d0cb9e32 | canonical_ex5_not_exactly_one |
| QM5_11292 trix14-signal-cross | H1 | 74a0858e | canonical_ex5_not_exactly_one |

Procedure: `farmctl enqueue-compile <label>` → `release_compile_wave.py --apply` → COMPILE_OK →
binary committed under its receipt (janitor or manual, explicit pathspecs) → `intake-first-q02 --apply`
(RAM-ranked canary, never SP500). Revocation: remove the EA from this document.

## Wave 3 (2026-09-20 ~16:45Z) — card-amended intraday EAs, stale tracked `.ex5`

Cards received `target_symbols` from their active magic-registry rows (slot order) or the OWNER 2026-09-01
default universe (`wave3_card_amendment_plan.json`, `card_backups/`). The only remaining compile refusals
are waivable (`EX5_ALREADY_PRESENT` / `BOUND_SETFILE_HASH_EXISTS` / `WORK_ITEMS_EXIST`): the tracked
`.ex5` predates the governed compile lane and carries no COMPILE_OK receipt. Scope unchanged: COMPILE_EA only.

| EA | timeframe | refusals waived |
|---|---|---|
| QM5_10474_mql5-tdsglobal | {'candidates': ['H1'], 'source': 'mq5_period_literal', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_10475_mql5-puria | {'candidates': ['M30'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10475_mql5-puria.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M30'} | EX5_ALREADY_PRESENT |
| QM5_10479_mql5-lbs-atr | {'candidates': ['H1'], 'source': 'mq5_period_literal', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_10783_tv-bos-forex | {'candidates': ['M15'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10783_tv-bos-forex.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M15'} | EX5_ALREADY_PRESENT |
| QM5_10797_tv-rsi-ma | {'candidates': ['M30'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10797_tv-rsi-ma.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M30'} | EX5_ALREADY_PRESENT |
| QM5_10798_tv-ema9-full | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10798_tv-ema9-full.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_10812_tv-bb-atrtrail | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10812_tv-bb-atrtrail.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_10819_tv-dema-vwap | {'candidates': ['M15'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10819_tv-dema-vwap.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M15'} | EX5_ALREADY_PRESENT |
| QM5_10822_tv-vwap-brt | {'candidates': ['M15'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10822_tv-vwap-brt.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M15'} | EX5_ALREADY_PRESENT |
| QM5_10827_tv-vol-exp | {'candidates': ['M15'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10827_tv-vol-exp.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M15'} | EX5_ALREADY_PRESENT |
| QM5_10830_tv-ts461-sweep | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10830_tv-ts461-sweep.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_10831_tv-ref-st-tsl | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10831_tv-ref-st-tsl.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_10843_tv-fracture-th | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10843_tv-fracture-th.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_10861_tv-fli-stc | {'candidates': ['M30'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_10861_tv-fli-stc.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'M30'} | EX5_ALREADY_PRESENT |
| QM5_10862_tv-mtf-trend-bo | {'candidates': ['D1'], 'source': 'mq5_period_literal', 'timeframe': 'D1'} | EX5_ALREADY_PRESENT |
| QM5_11276_iaf-donchian | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11276_iaf-donchian.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11279_blade-macd-stoch-divergence | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11279_blade-macd-stoch-divergence.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11304_kathy-lien-double-bollinger-trend | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11304_kathy-lien-double-bollinger-trend.md', 'source': 'card_explicit_host_timeframe', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11305_alp-sma20-scalp | {'candidates': ['M1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11305_alp-sma20-scalp.md', 'source': 'card_frontmatter:period', 'timeframe': 'M1'} | EX5_ALREADY_PRESENT |
| QM5_11315_tc-m5-8-triple-bb50-rsi3-stoch | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11315_tc-m5-8-triple-bb50-rsi3-stoch.md', 'source': 'card_frontmatter:period', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_11330_tc-m5-16-wma5-sma11-psar-adx | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11330_tc-m5-16-wma5-sma11-psar-adx.md', 'source': 'card_frontmatter:period', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_11343_triad-session-breakout | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11343_triad-session-breakout.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11371_tom-demark-ema9-30-momentum-h1 | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11371_tom-demark-ema9-30-momentum-h1.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11394_paul-langer-m5-bb20-scalper | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11394_paul-langer-m5-bb20-scalper.md', 'source': 'card_frontmatter:period', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_11432_carter-multitf-candle-color-h1 | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11432_carter-multitf-candle-color-h1.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11437_carter-t-ema18-adx-pullback-h1 | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11437_carter-t-ema18-adx-pullback-h1.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11438_td-ema9ema30-momentum-h1 | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11438_td-ema9ema30-momentum-h1.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11442_burke-frd-fgd-daily-pump-m5 | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11442_burke-frd-fgd-daily-pump-m5.md', 'source': 'card_frontmatter:period', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_11443_burke-day3-breakout-trap-m5 | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11443_burke-day3-breakout-trap-m5.md', 'source': 'card_frontmatter:period', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_11454_davey-session-open-bracket-breakout | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11454_davey-session-open-bracket-breakout.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11459_blade-macd-stoch-divergence-h1 | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11459_blade-macd-stoch-divergence-h1.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11508_carter-t-ema50-100-macd-breakout | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11508_carter-t-ema50-100-macd-breakout.md', 'source': 'card_frontmatter:period', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_11537_carter-t-h1-ema5s5-ema75-bb-rsi | {'candidates': ['H1'], 'source': 'existing_setfiles', 'timeframe': 'H1'} | BOUND_SETFILE_HASH_EXISTS, EX5_ALREADY_PRESENT |
| QM5_11559_carter-t-m5-ema3-bb203-macd | {'candidates': ['M5'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11559_carter-t-m5-ema3-bb203-macd.md', 'source': 'card_frontmatter:period', 'timeframe': 'M5'} | EX5_ALREADY_PRESENT |
| QM5_11867_psar-adx50-di-h1 | {'candidates': ['H1'], 'card_path': 'D:\\QM\\strategy_farm\\artifacts\\cards_approved\\QM5_11867_psar-adx50-di-h1.md', 'source': 'card_frontmatter:timeframe', 'timeframe': 'H1'} | EX5_ALREADY_PRESENT |
| QM5_12351_alp-ema12-26 | {'candidates': ['M15'], 'source': 'existing_setfiles', 'timeframe': 'M15'} | EX5_ALREADY_PRESENT, WORK_ITEMS_EXIST |
| QM5_30005_bollinger-bands-grid-dark-venus | {'candidates': ['M15'], 'source': 'existing_setfiles', 'timeframe': 'M15'} | BOUND_SETFILE_HASH_EXISTS, EX5_ALREADY_PRESENT, WORK_ITEMS_EXIST |
| QM5_30006_adx-ma-trend-grid-dark-kronos | {'candidates': ['H1'], 'source': 'existing_setfiles', 'timeframe': 'H1'} | BOUND_SETFILE_HASH_EXISTS, EX5_ALREADY_PRESENT, WORK_ITEMS_EXIST |
| QM5_37001_ernest-chan-ornstein-uhlenbeck-statarb | {'candidates': ['H1'], 'source': 'existing_setfiles', 'timeframe': 'H1'} | BOUND_SETFILE_HASH_EXISTS, EX5_ALREADY_PRESENT |
| QM5_37005_chan-bollinger-adx-mean-reversion | {'candidates': ['H1'], 'source': 'existing_setfiles', 'timeframe': 'H1'} | BOUND_SETFILE_HASH_EXISTS, EX5_ALREADY_PRESENT |
| QM5_38004_codetrading-triple-ema-momentum-scalper | {'candidates': ['M5'], 'source': 'existing_setfiles', 'timeframe': 'M5'} | BOUND_SETFILE_HASH_EXISTS, EX5_ALREADY_PRESENT |
| QM5_39001_forexfactory-trading-made-simple-tms | {'candidates': ['H1'], 'source': 'existing_setfiles', 'timeframe': 'H1'} | BOUND_SETFILE_HASH_EXISTS, EX5_ALREADY_PRESENT, WORK_ITEMS_EXIST |
| QM5_40005_tradingview-multitimeframe-supertrend-atr | {'candidates': ['H1'], 'source': 'existing_setfiles', 'timeframe': 'H1'} | BOUND_SETFILE_HASH_EXISTS, EX5_ALREADY_PRESENT |
