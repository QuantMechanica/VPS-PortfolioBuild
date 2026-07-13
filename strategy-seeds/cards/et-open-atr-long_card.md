---
strategy_id: CODEX-FTMO-ORB-LONG-2026-07-10_S01
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
ea_id: QM5_13127
slug: et-open-atr-long
status: REJECTED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
approved: 2026-07-10
approved_by: "OWNER-delegated CEO + Quality-Business + CTO decision to Codex"
ea_id_allocated_by: "OWNER-delegated CEO + CTO decision to Codex"
g0_approval_reasoning: "Source-faithful long-only repair of QM5_10375. The source pointer specifies a stop at session open plus 0.3 daily ATR; the existing symmetric short side was a V5 extension and produced only PF 1.035 before holdout versus PF 1.263 for longs. Fixed rules, no tuning, no ML or prohibited sizing."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
source_citations:
  - type: forum
    citation: "Elite Trader thread, Jock / TrueStory / risktaker, 2007-03-26; TradeStation code placing a stop at session open plus 0.3 daily ATR."
    location: "source pointer inherited from QM5_10375 SPEC"
    quality_tier: C
    role: primary
  - type: own_data_research
    citation: "Current-binary QM5_10375 NDX native MT5 report, 2020-2024; direction diagnostic restricted to 2020-2023 before holdout."
    location: "artifacts/ftmo_10375_orb_v2_holdout_screen_2026-07-10.json"
    quality_tier: B
    role: falsification
strategy_type_flags: [session-open-breakout, long-only, atr-hard-stop, intraday-flat]
target_symbols: [NDX.DWX]
primary_target_symbols: [NDX.DWX]
markets: [indices]
single_symbol_only: true
period: M5
timeframes: [M5, D1]
expected_trade_frequency: "Approximately 80-120 completed intraday trades/year."
expected_trades_per_year_per_symbol: 100
expected_pf: TBD
expected_dd_pct: TBD
risk_class: medium
ml_required: false
pipeline_phase: Q02_FAIL_PREHOLDOUT
research_verdict: RETIRED_2022_AND_POOLED_PF_FAIL
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [model4_every_real_tick, session_anchor, pending_expiry, risk_mode_dual, ftmo_news_profile, intraday_flat]
---

# NDX Session-Open ATR Breakout Long

## Hypothesis

The source rule places a buy stop at the primary-session open plus 0.30 of the
completed daily ATR. `QM5_10375` added a symmetric short bracket. On its fresh
2020-2024 native report, the pre-holdout 2020-2023 direction diagnostic was PF
1.263 for buys and PF 1.035 for sells. This card removes the unsupported short
extension without changing the source distance, risk geometry, target, spread
gate, session, or news timing.

The diagnostic is not an EA result because short-first days suppress possible
later long entries. Promotion therefore requires a fresh exact model-4 run of
this distinct binary, with 2024 and 2025 treated as holdout evidence.

## Rules

Trade one source-faithful NDX buy-stop breakout per broker date from the fixed
US cash-session anchor, with fixed ATR entry, stop, target, and time exit.

## 4. Entry Rules

- Evaluate `NDX.DWX` M5 only during the broker 16:30-22:30 order window.
- Read the actual 16:30 bar open and prior completed D1 ATR(20).
- Place one buy stop at open plus 0.30 ATR after all spread and news gates pass.

## 5. Exit Rules

- Broker stop is the session open minus 0.30 ATR.
- Broker target is entry plus 0.60 ATR.
- Close remaining exposure at session end; Friday close remains authoritative.

## 6. Filters (No-Trade Module)

- Exact symbol, timeframe, and magic slot are mandatory.
- Skip outside the order window, on invalid ATR/spread, or when the entry band
  is less than four spreads.
- Framework temporal news and FTMO compliance gates apply to new entries only.

## 7. Trade Management Rules

- Cancel an unfilled buy stop in the final 30 session minutes.
- Do not trail, break even, partially close, scale, reverse, or retry.

## Locked Rules

- Exact host is `NDX.DWX` on M5, slot 0.
- Broker session is 16:30 through 23:00.
- Anchor `session_open` to the actual 16:30 M5 bar even when news compliance
  delays the order decision.
- Once per broker date, place one BUY STOP at `session_open + 0.30 * D1 ATR(20)`.
- Protective stop is `session_open - 0.30 * D1 ATR(20)`.
- Take profit is `entry + 0.60 * D1 ATR(20)`.
- Use only the prior completed D1 ATR value.
- Skip when the entry band is less than four current spreads.
- Cancel the pending stop in the final 30 session minutes and close any open
  position at session end. Friday close remains authoritative.
- Use the framework 30-minute temporal news pause plus FTMO compliance overlay.
- One order attempt per broker date; no retry, short, reversal, scale-in,
  partial close, trail, break-even, grid, martingale, or ML.

## Locked Parameters

| parameter | value | authorized range |
|---|---:|---|
| D1 ATR period | 20 | [20] |
| entry ATR multiple | 0.30 | [0.30] |
| target ATR multiple | 0.60 | [0.60] |
| minimum band/spread | 4.0 | [4.0] |
| broker session | 16:30-23:00 | [16:30-23:00] |
| final order minutes | 30 | [30] |

No parameter sweep or rescue is authorized. A Q02 failure retires the card.

## Risk And Validation

- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Spread and both sides of the current index commission must be present in the
  native report. The strategy must remain flat before broker midnight, so no
  swap should accrue.
- DEV: 2020-2022; validation: 2023; locked holdouts: 2024 and 2025.
- Require pooled costed PF >= 1.20 and no negative validation/holdout year to
  advance beyond Q02.

## Pipeline Status

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `framework/build/compile/20260710_212857/QM5_13127_et-open-atr-long.compile.log` |
| Q02 Baseline Screening | 2026-07-10 | FAIL | `artifacts/ftmo_13127_q02_preholdout_2026-07-10.json` |
| Q04+ | 2026-07-10 | NOT RUN | Q02 hard stop |

## Retirement Decision

The exact long-only EA was deterministic, but 2022 returned 135 trades, PF
0.883 and USD -4,294.48. Pooled 2021-2023 PF was only 1.144, below the locked
1.20 gate. Seven trades also crossed broker midnight because no post-23:00 tick
was available; the custom symbol charged zero swap. The branch is retired
without running 2024/2025 holdouts or changing a parameter.
