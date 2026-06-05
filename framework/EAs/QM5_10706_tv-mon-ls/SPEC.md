# QM5_10706_tv-mon-ls — Strategy Spec

**EA ID:** QM5_10706
**Slug:** `tv-mon-ls`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView "Monday Liquidity Sweep - WolfWeb", andrei_keenvent)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA fades failed breaks of the prior Monday's range. During the logical
Monday session (day boundary shifted by `MondayBoxShiftHours`, source default
7h) it tracks the Monday high and Monday low to form a "Monday box". After
Monday, on each closed H1 bar it inspects the previous bar (the sweep bar): if
that bar wicked above the Monday high by at least `LiqPct` but no more than
`MaxWickPct` of price, and the just-closed bar closed back inside the Monday
range, it enters a market SHORT. A symmetric sweep below the Monday low with a
close back inside the range enters a market LONG. Stop loss sits just beyond the
sweep wick extreme (`SlPct` padding). Take profit is the larger of an R:R target
(`RrTarget`) and a Monday-range-percentage target (`MondayRangeTpPct` of the box
height). The stop is moved to a locked breakeven (entry ± `BeLockFrac` of risk)
once the trade reaches `BeTriggerR` of profit or has been open `BeBars` bars.
At most one trade per week. Open trades are force-closed on Friday by the
framework Friday-close guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `MondayBoxShiftHours` | 7 | 0-12 | Logical day-boundary shift for the Monday box. |
| `LiqPct` | 0.0002 | 0.0001-0.0004 | Min penetration beyond the Monday level for a valid sweep. |
| `MaxWickPct` | 0.0025 | 0.0015-0.0040 | Max penetration; deeper = real breakout, skipped. |
| `SlPct` | 0.0002 | 0.0001-0.0004 | Stop padding beyond the sweep wick extreme. |
| `RrTarget` | 3.5 | 2.0-3.5 | R:R take-profit multiple. |
| `MondayRangeTpPct` | 1.30 | 1.00-1.60 | Monday-range take-profit multiple. |
| `BeTriggerR` | 1.5 | 1.5-3.0 | R multiple that arms the breakeven lock. |
| `BeBars` | 24 | 1-200 | Bars-open that also arms the breakeven lock. |
| `BeLockFrac` | 0.1 | 0.0-1.0 | Fraction of initial risk locked at breakeven. |
| `OneTradePerWeek` | true | bool | P2 baseline: at most one trade per week. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquidity FX major; clean weekly-range structure.
- `GBPUSD.DWX` — liquid FX major with frequent Monday-range sweeps.
- `USDJPY.DWX` — liquid FX major; complements EUR/GBP correlation-wise.
- `XAUUSD.DWX` — gold; strong weekly-range behaviour and liquidity sweeps.
- `GDAXI.DWX` — DAX 40 index CFD (card said GER40; ported to the matrix name GDAXI).
- `NDX.DWX` — Nasdaq 100 index CFD; live-tradable US large-cap exposure.

**Explicitly NOT for:**
- `SP500.DWX` — not in the card basket and backtest-only (not broker-routable).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~42` |
| Typical hold time | `hours to ~3 days (intra-week)` |
| Expected drawdown profile | `low cadence; clustered losses on strong weekly continuation` |
| Regime preference | `mean-revert / failed-breakout reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView open-source script)
**Pointer:** `https://www.tradingview.com/script/FyQv2kdT-Monday-Liquidity-Sweep-WolfWeb/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10706_tv-mon-ls.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | 30769d9e-5847-43e6-a589-53e64bc08206 |
