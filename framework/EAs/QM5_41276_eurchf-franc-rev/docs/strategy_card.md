---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-EURCHF-FRANC-REVERSAL-20260901_S01
variant_id: AI-CODEX-EURCHF-FRANC-REVERSAL-20260901_S01
source_id: AI-CODEX-EURCHF-FRANC-REVERSAL-20260901
ea_id: QM5_41276
slug: eurchf-franc-rev
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41276_eurchf-franc-rev_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41276_eurchf_franc_strength_reversal_g0.md
source_approval: decisions/2026-09-01_eurchf_franc_strength_reversal_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; QuantMechanica OWNER orthogonal-return program; Swiss National Bank source lineage"
source_citation: "OpenAI Codex (2026), EURCHF extreme franc-strength closed-bar reversal; bounded lineage in the OWNER Orthogonal Return Sources Program (2026-08-13) and local SNB-linked source packets."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). EURCHF extreme franc-strength closed-bar reversal."
    location: "strategy-seeds/sources/AI-CODEX-EURCHF-FRANC-REVERSAL-20260901/source.md"
    quality_tier: governed_source
    role: exact_formula_activity_boundary_risk_and_lifecycle
  - type: owner_research_program
    citation: "QuantMechanica OWNER (2026). Orthogonal Return Sources Program, candidate 7."
    location: "docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md"
    quality_tier: internal_governed_research
    role: original_eurchf_h4_research_ticket_and_gap_regime_warnings
  - type: official_source_packet
    citation: "Grisse and Nitschka (2013), On financial risk and the safe haven characteristics of Swiss franc exchange rates, Swiss National Bank Working Paper 2013-04."
    location: "strategy-seeds/sources/EIA-SNB-XTI-USDCHF-RSPREAD-2026/source.md"
    quality_tier: official_central_bank_lineage
    role: chf_safe_haven_carrier_only
strategy_mechanic: eurchf-h4-long-only-extreme-franc-strength-excurrent-forty-close-zscore-lower-prior-250-close-decile-bullish-closed-bar-reversal
sources:
  - "[[sources/AI-CODEX-EURCHF-FRANC-REVERSAL-20260901]]"
concepts:
  - "[[concepts/safe-haven-currency]]"
  - "[[concepts/one-sided-mean-reversion]]"
  - "[[concepts/closed-bar-reversal]]"
indicators:
  - "[[indicators/excurrent-close-zscore]]"
  - "[[indicators/trailing-close-range-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [forex, swiss-franc, mean-reversion, long-only, h4, structural, low-frequency, atr-hard-stop, fixed-target, time-stop, single-symbol]
markets: [forex]
timeframes: [H4]
target_symbols: [EURCHF.DWX]
primary_target_symbols: [EURCHF.DWX]
single_symbol_only: true
logical_symbol: EURCHF.DWX
symbol: EURCHF.DWX
host_symbol: EURCHF.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412760000
period: H4
timeframe: H4
execution_timeframe: H4
signal_timeframe: H4
direction: long_only
intraday: true
closed_bar_cache_required: true
smoke_year: 2022
expected_trade_frequency: "Approximately 12-25 completed positions per full post-warm-up year as an ordering prior only; Q02 must establish at least ten distinct entry days in every full year or retire."
expected_trades_per_year_per_symbol: 18
expected_hold_time: "one H4 bar to three elapsed days; hard maximum eighteen H4 periods"
expected_regime: "episodic reversal after extreme franc strength; vulnerable to persistent repricing and discontinuous CHF gaps"
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_UNTESTED_MECHANIZATION_AND_POST_FLOOR_REGIME_RISK
r1_reasoning: "Complete durable OWNER research and local official-source packets support the CHF stress carrier and exact research ticket; the trading rule and post-2015 profitability remain untested synthesis."
r2_mechanical: PASS
r2_reasoning: "Closed-bar sample membership, population deviation, strict thresholds, range location, reversal, side, ATR stop/target, fixed risk, and exits are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Canonical EURCHF.DWX supplies native H4 research data; the symbol matrix does not yet record a confirmed live-order alias, and this card authorizes no live action."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed OHLC, fixed-window arithmetic, ATR, quotes, positions, time, and V5 framework state; no trained output, adaptive parameter, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: prior-forty-close population z score excluding the signal bar; strict z<-2.0; signal close in lower 10% of prior-250-close range; bullish close above open and prior close; ATR(14,H4); signal-low minus 0.25 ATR structural stop, minimum 1.25 ATR distance, reject above 2.50 ATR; 1.50 ATR target; z>-0.50 closed-bar exit; eighteen-H4-period time stop; 50-point positive-spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: true
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify an unused EURCHF H4 one-sided extreme-franc-strength reversal. Verify ex-current reference windows, population standard deviation, strict thresholds, lower-decile close range, reversal orientation, long-only side, frozen ATR risk, time/Friday exits, and gap-tail honesty. Q09 alone may establish realized overlap."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_eurchf_carrier, closed_h4_bar_only, ex_current_reference_windows, population_standard_deviation, strict_z_thresholds, lower_decile_close_range, bullish_reversal_orientation, long_only, no_averaging, hard_stop_present, gap_slippage_not_capped, risk_mode_dual, friday_close_enabled, time_stop, q02_activity_floor, live_symbol_routing_unresolved, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 plus durable source approval: higher-priority diverse build and infrastructure recovery paths were exhausted; R1 preserves untested/post-floor risks, R2 locks all mechanics, R3 uses canonical EURCHF.DWX research data while live routing remains unresolved, and R4 is fixed deterministic arithmetic. Canonical dedup is CLEAN and manual review separates all EURCHF-capable neighbors."
---

# QM5_41276 EURCHF Extreme Franc-Strength Reversal

## Hypothesis

After unusually strong CHF appreciation pushes EURCHF far below its recent H4
distribution and into the bottom of its longer closing-price range, the first
bullish closed-bar reversal may identify a bounded liquidity rebound. The
strategy buys only that rebound and never averages into continued franc
strength.

This is an untested post-floor EURCHF hypothesis. The source lineage supports
CHF as a stress-sensitive safe-haven carrier, not the trading rule, its sign,
its activity, its economics, or a permanent SNB backstop. Q02 owns activity
and economics, Q04 owns time stability, Q05-Q07 own the discontinuous gap tail,
and unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/AI-CODEX-EURCHF-FRANC-REVERSAL-20260901/source.md`,
authorized before extraction by
`decisions/2026-09-01_eurchf_franc_strength_reversal_source_approval.md`.

The complete local evidence comprises the OWNER orthogonal-return program and
two existing SNB-linked source packets. Public SNB page retrieval was deferred
by the governed source router; receipts are stored with the source. Therefore
no full-paper coefficient, intervention estimate, floor-era probability, or
performance result enters this card.

## Non-Duplicate Boundary

The canonical receipt
`artifacts/qm5_eurchf_franc_rev_preallocation_dedup_20260901.json`, SHA-256
`D78071AA44A69A45F5133709888CCD2B2E5684DF0539494B13B2CC95040FA80E`,
found no exact or fuzzy identity across 4,775 registry rows, 1,411 cards, and
45 Strategy Wiki nodes.

- `QM5_35008` is a symmetric M15 Bollinger/RSI evening fade across three FX
  symbols; this card is H4, EURCHF-only, long-only, and uses ex-current z and
  longer-range location without RSI or a session window.
- `QM5_1012` is a D1/H1 low-ADX prior-day false-break fade; this card has no
  ADX, prior-day range, or opposite-range pending trigger.
- `QM5_1011` follows inside-day breakouts. This card waits for a reversal and
  trades against the preceding extreme.
- EURCHF grid and stochastic-scalper blueprints use different mechanisms and
  risk architectures; no grid or scalping element is admitted here.

Verdict:
`DISTINCT_EURCHF_H4_LONG_ONLY_EXCURRENT_ZSCORE_LOWER_DECILE_BULLISH_REVERSAL`.

## Rules

### Market, Clock, And Data

- Host and trade exact `EURCHF.DWX`, H4, slot 0, magic `412760000`.
- Evaluate strategy state once per new H4 bar through the framework new-bar
  gate. Raw rates are copied once inside that closed-bar advance and cached;
  no history window is recomputed per tick.
- Let `C0` be the just-completed close. The signal bar is excluded from every
  reference sample.
- Require 251 completed H4 bars, positive finite OHLC, and positive finite ATR.

### Exact Signal

```text
R  = C1..C40
mu = sum(R) / 40
sd = sqrt(sum((x-mu)^2 for x in R) / 40)
z  = (C0-mu) / sd

lo = min(C1..C250)
hi = max(C1..C250)
lower_decile = lo + 0.10*(hi-lo)

bullish_reversal = close0 > open0 and close0 > close1
BUY = z < -2.0 and close0 <= lower_decile and bullish_reversal
```

The deviation is population deviation with divisor forty. Both z boundaries
are strict. The long-only signal is flat on equality at `z=-2.0`. The
250-close range uses closes rather than candle highs/lows.

### Entry Rules

- Reject existing owned exposure, invalid/crossed quotes, nonpositive point,
  or a genuinely positive spread above 50 points. Zero modeled spread is
  valid for `.DWX`.
- Freeze `ATR(14,H4)` from the signal bar.
- Start the stop at `signal_low - 0.25*ATR`. The actual entry-stop distance is
  the larger of that structural distance and `1.25*ATR`. Reject the trade if
  it exceeds `2.50*ATR`.
- Attach a normalized broker hard stop and a normalized target at
  `entry + 1.50*ATR` before opening one market BUY.
- Size only through the V5 risk helper under `RISK_FIXED=1000`; no signal
  magnitude, retry, scale-in, averaging, pyramid, grid, or martingale.

### Exit And Management Rules

- On each new H4 bar, recompute the same ex-current z score. Close when
  `z > -0.50`.
- Close after eighteen H4 periods of elapsed time from broker position open.
- Framework Friday close remains enabled at broker hour 21.
- Broker hard stop, hard target, kill switch, and framework lifecycle remain
  active. There is no trail, break-even, partial close, opposite side, or
  same-bar re-entry.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| parameter | default | status |
|---|---:|---|
| `strategy_z_lookback` | 40 | locked |
| `strategy_z_entry` | -2.0 | locked |
| `strategy_z_exit` | -0.5 | locked |
| `strategy_range_lookback` | 250 | locked |
| `strategy_lower_decile` | 0.10 | locked |
| `strategy_atr_period` | 14 | locked |
| `strategy_swing_buffer_atr` | 0.25 | locked |
| `strategy_min_stop_atr` | 1.25 | locked |
| `strategy_max_stop_atr` | 2.50 | locked |
| `strategy_target_atr` | 1.50 | locked |
| `strategy_max_hold_bars` | 18 | locked |
| `strategy_max_spread_points` | 50 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing a window, threshold, range definition, reversal, side, stop, target,
hold, or carrier after Q02 is forbidden.

## Expected Behaviour And Frequency

Expect episodic entries clustered after risk-off CHF appreciation, roughly
12-25 positions per full post-warm-up year as an ordering prior. Typical holds
should range from one H4 bar to three elapsed days. Persistent repricing can
produce clustered stop losses; discontinuous CHF repricing can fill beyond the
requested hard stop.

Q02 must retire zero positions or fewer than ten distinct entry days in any
full post-warm-up calendar year.

## Reputable-Source Criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_UNTESTED_MECHANIZATION_AND_POST_FLOOR_REGIME_RISK | Complete durable OWNER research and official-source packets establish CHF safe-haven lineage and the exact research ticket; no trading result is imported. |
| R2 | PASS | Exact closed-bar samples, population deviation, strict thresholds, range, reversal, side, ATR risk, target, and exits. |
| R3 | PASS | Native registered EURCHF.DWX H4 research data; live alias remains unconfirmed and no live action is authorized. |
| R4 | PASS | Fixed native arithmetic and framework execution only; no trained/adaptive signal or external runtime feed. |

## Risk

Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and legacy news mode are OFF in the
locked baseline; Q09 owns news sensitivity. Friday close is ON.

The 2015 EURCHF gap proves that requested stop distance does not cap realized
gap loss. Retire on failed gap/regime stress, nonpositive economics, wrong
sample arithmetic, missing stop, repeat/short entry, wrong risk mode, missed
exit, or any downstream gate failure. No result-driven rescue is authorized.

EURCHF adds a currency carrier absent from the stated certified book, but that
is not a decorrelation result. The card authorizes no live routing, portfolio
admission, or correlation waiver.

## Framework Alignment

- `no_trade`: exact identity, period, parameter, risk/news/Friday, quote, and
  positive-spread contracts.
- `trade_entry`: cached H4 side and ATR state, one fixed-risk market BUY,
  broker hard stop, and fixed ATR target.
- `trade_management`: per-tick elapsed-time exit only; no indicator read or
  history scan.
- `trade_close`: cached closed-bar z exit plus framework stop, target, Friday,
  and kill-switch handling.

## Validation Plan

1. Card schema lint and forbidden-token scan.
2. Canonical dedup receipt and pure reference fixtures for sample exclusion,
   population z, strict boundaries, range location, reversal, and stop math.
3. V5 spec validation, scoped build check, and strict MQL5 compile.
4. One canonical `RISK_FIXED` EURCHF H4 backtest set.
5. One smoke only if whole-host CPU admission is below the ceiling; otherwise
   record the exact capacity deferral and stop.
6. One paced non-live Q02 enqueue; no manual backtest or terminal selection.

## Safety Boundary

Authorized: one registered V5 identity, one non-live source build, reference
tests, strict Q01, and at most one paced Q02 enqueue.

Forbidden: source-site scraping, manual backtest, optimization, live/demo/
shadow/stress presets, external runtime data, portfolio-gate edits, correlation
waivers, portfolio admission, deploy/live manifests, `T_Live`, AutoTrading,
or terminal control.

## Pipeline History

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 | 2026-09-01 | APPROVED; R1-R4 bounded PASS | source approval, policy receipts, dedup, card decision |
| Q01 | pending | pending | governed build task |
| Q02 | pending | not enqueued | paced worker owns dispatch after Q01 |

## Revision History

| version | date | reason | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | initial EURCHF extreme franc-strength reversal card | G0 | APPROVED |
