# QM5_20303 WTI smooth-volatility-beta build review

Date: 2026-08-13  
Router task: `0f9884af-dfa7-4921-aec3-f1cac4df76df`  
Source build task: `ab9ebab8-c37c-4e38-b935-835ee1b1de32`  
Branch: `agents/board-advisor`  
Disposition: `REVIEW`

## Outcome

The build-only review passes. `QM5_20303_wti-volbeta-reg` is registry-clean, card-bound, strict-compile clean, and backed by independent formula checks. It remains a non-live build artifact. No Q02 backtest was started or enqueued in this cycle because the required `qm-build-ea-from-card` workflow is build-only and the routed constraints prohibit a manual backtest.

An intermediate commit, `2ca1168d3`, had staged the prior QM5_20302 ALIQ implementation under the QM5_20303 label. The corrected source was present in the shared working tree, reviewed against the approved card, compiled, and committed as `fd89295ca` (`fix(build): bind QM5_20303 smooth-vol beta source`). The post-set validation refreshed the setfile header hash; that bounded delta and this evidence document are committed separately with explicit pathspecs.

## Governed preflight

- Approved card: `C:/QM/repo/strategy-seeds/cards/approved/QM5_20303_wti-volbeta-reg_card.md`
- `g0_status`: `APPROVED`
- Execution contract: `DRAFT`; build and non-live verification only
- EA registry: `20303,wti-volbeta-reg,...,active`
- Magic registry: slot 0, `XTIUSD.DWX`, magic `203030000`, active
- EA/card/registry slug: `wti-volbeta-reg`
- Traded host: `XTIUSD.DWX`, D1; `XNGUSD.DWX` is read-only and has no order slot
- EA-local `docs/strategy_card.md` SHA-256 exactly matches the canonical approved card

## Card-to-framework alignment

- No-trade: exact host/timeframe/EA/slot, locked risk/news/Friday/strategy parameters, and fixed-risk contract are checked in `Strategy_NoTradeFilter`.
- Entry: the month attempt is persisted before history and entry-only gates; exactly 545 synchronized completed XTI/XNG D1 closes produce two disjoint 272-return blocks; each block uses local inverse-volatility weights, a 20-return sample-volatility change, fixed two-sigma jump zeroing, and a 252-row three-column OLS. High recent smooth beta is long; low recent smooth beta is short.
- Management: malformed owned exposure is closed, prior-month exposure is closed before replacement logic, and the forty-calendar-day stale guard remains active.
- Close: the frozen `3.5 * ATR(20,D1)` broker stop, framework kill switch, monthly replacement, and stale guard are the only authorized exits. No TP, trail, partial, scale-in, grid, martingale, or pyramid exists.
- Risk and setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`; `qm_news_stale_max_hours=336`; Friday close and both news axes are locked off exactly as the approved Q02 card specifies.

## Focused verification

1. PASS — independent Python reference suite: 6/6 tests. Coverage includes block-local weights, exact OLS row counts, disjoint return support, common-scale invariance, retained jump rows with zeroed smooth factor, direction/tolerance, exact close count, synchronization, chronology, and freshness.
2. PASS — `validate_build_guardrails.py` on the MQ5 and backtest setfile; no findings and maximum allowed news staleness 336 hours.
3. PASS — strict MetaEditor compile from `compile_one.ps1`: 0 errors, 0 warnings. Evidence: `D:/QM/reports/compile/20260813_095442/summary.csv` and `C:/QM/repo/framework/build/compile/20260813_095442/QM5_20303_wti-volbeta-reg.compile.log`.
4. PASS — target post-set `build_check.ps1 -Strict -SkipCompile`: 0 failures, 0 warnings. Evidence: `D:/QM/reports/framework/21/build_check_20260813_095552.json`.
5. PASS — static scope review found the sole order path is the host `QM_TM_OpenPosition`; `XNGUSD.DWX` appears only as a read-only synchronized `CopyRates` input.
6. PASS — `git diff --check` on the EA path and evidence path.
7. No new pipeline verdict was created. Existing Q01 evidence remains `D:/QM/reports/pipeline/QM5_20303/P1/P1_QM5_20303_result.json`; Q02 remains not enqueued by this build-only review.

## SHA-256 bindings

- MQ5: `dce1a65098e5e6a81eb3c9568c42a07c5f31a9284747419bcca2ba053f3a4145`
- EX5: `ea2ec9a3bc16e363f2a610db0d679941331884ff44d5c62ad611bae47c50c83d`
- SPEC: `0453259e201d5cc4b55946d3b4c32ce4a2aa7e0da78d7732d67bffca35d53783`
- Backtest setfile: `42a5ffb5807149da590963f80b22679b47fdd187c244a9fe18d20c09c1d0a2bc`
- Approved card and EA-local card copy: `b2f8ff8b0a34b38aa1e99402a9f1b604ffd7f32f8e56bbe663272e21aa2f9481`
- Reference test: `67c9bbf32dd18fe09ea40086d3e937219ff4990f4a0cd5c0e07982d2e5989a7f`

## Safety boundary

No terminal was launched, no active backtest was interrupted, and no Q02 work item was created. T_Live, AutoTrading, live/deploy manifests, execution-contract status, portfolio gates, and main were untouched. Build PASS is not a profitability or pipeline verdict.
