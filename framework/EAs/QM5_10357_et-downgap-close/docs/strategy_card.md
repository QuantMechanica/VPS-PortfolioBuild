---
ea_id: QM5_10357
slug: et-downgap-close
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "intradaybill / syswizard / Pro_Trader720, Easylanguage question, Elite Trader, 2008-03-06/2008-03-07, https://www.elitetrader.com/et/threads/easylanguage-question.120073/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/gap-reversion]]"
  - "[[concepts/close-exit]]"
  - "[[concepts/daily-pattern]]"
indicators: []
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX, EURUSD.DWX]
period: D1
expected_trade_frequency: "Two consecutive down gaps on daily bars are intermittent; conservative estimate 18 trades/year/symbol."
expected_trades_per_year_per_symbol: 18
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 linked Elite Trader source; R2 mechanical two-gap daily long entry and same-day close exit with ~18 trades/year/symbol; R3 testable on SP500.DWX and DWX indices/FX ports with T6 caveat; R4 fixed non-ML one-position logic."
---

# Elite Trader Two Down Gaps Close Exit

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/easylanguage-question.120073/
- Author / handle: `intradaybill`; implementation comments by `syswizard` and `Pro_Trader720`.
- Dates: 2008-03-06 and 2008-03-07.
- Location: posts #1, #4, and #5. The thread defines a daily EasyLanguage rule: buy after two consecutive down gaps at the next open and sell at the same day's close.

## Mechanik

### Entry
- Evaluate daily bars after session close.
- A down gap exists when `Low[n-1] > High[n]` in the source's EasyLanguage indexing.
- Baseline normalized rule: yesterday's high is below the prior day's low, and today's high is below yesterday's low.
- If flat and two consecutive down gaps are present, buy at next session open.
- Long-only source rule; optional short mirror can be evaluated separately only if G0 requests it.

### Exit
- Exit the long position at the close of the entry day.
- Protective stop: `1.0 * ATR(14,D1)` below entry for intraday crash protection.
- Friday close enforced by framework.

### Stop Loss
- Source only specifies close exit.
- V5 protective stop: `1.0 * ATR(14,D1)` below entry.
- Skip trade if the opening spread exceeds 2.5x rolling median spread.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Trade only symbols with reliable session opens; indices are primary.
- Optional FX port uses broker D1 open/close gaps; mark results separately because FX gaps differ from exchange-traded indices.
- Skip entries immediately after high-impact weekend gaps unless news filter allows.

## Concepts
- [[concepts/gap-reversion]] - buys after repeated bearish gaps expecting same-day reversion.
- [[concepts/close-exit]] - exits at the entry-day close.
- [[concepts/daily-pattern]] - signal is derived from daily OHLC relationships.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus visible handles. |
| R2 Mechanical | PASS | Two-gap condition, next-open entry, and same-day close exit are explicit. |
| R3 DWX-testbar | PASS | Daily OHLC gap pattern is testable on SP500.DWX, live index CFDs, and limited FX gap ports. |
| R4 No ML | PASS | Fixed daily rule; no ML, adaptive parameters, grid, martingale, or multiple positions. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`, `EURUSD.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source asks for code to buy after two consecutive down gaps and sell at the close of the same day.
- The source replies confirm the order timing can work on daily bars.

## Parameters To Test
- Gap definition: strict low/high gap, close-to-open gap, minimum gap 0.05 ATR, minimum gap 0.10 ATR.
- Protective stop: 0.75, 1.0, 1.5 ATR(14,D1).
- Entry timing: next open, first M15 close after open.
- Exit timing: same-day close, close minus 15 minutes, next open.

## Initial Risk Profile
Short-horizon mean-reversion pattern. Main risk is catching multi-day downside continuation after adverse news; V5 protective ATR stop and news filters reduce tail exposure.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
