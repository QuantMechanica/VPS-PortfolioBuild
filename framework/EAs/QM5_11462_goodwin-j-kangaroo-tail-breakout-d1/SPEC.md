# QM5_11462_goodwin-j-kangaroo-tail-breakout-d1 — Strategy Spec

**EA ID:** QM5_11462
**Slug:** `goodwin-j-kangaroo-tail-breakout-d1`
**Source:** `038d2a5d-1c89-5745-afdb-2cd76b623b77` (see `sources/goodwin-j-beat-markets-guidebook`)
**Author of this spec:** Codex
**Last revised:** 2026-08-08

---

## 1. Strategy Logic

After each D1 close, the EA finds a bullish setup when the middle bar of the last three closed bars has the lowest low, or a bearish setup when it has the highest high. It arms a stop order one pip beyond the most recently closed bar, with the protective stop one pip beyond that bar's opposite extreme, unless the close moved more than 0.5% away from the middle-bar close or the latest range exceeds 80 pips. Unfilled orders expire at the configured same-session end, and filled positions close at 17:00 US Eastern time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_filter_pct` | 0.5 | 0, 0.3, 0.5, 1.0 | Maximum permitted continuation move from bar 2 to bar 3; zero disables the filter. |
| `strategy_offset_pips` | 1 | >0 | Pip offset beyond bar 3 for the stop-order entry and protective stop. |
| `strategy_range_cap_pips` | 80 | 60, 80, 120 | Maximum permitted high-low range of bar 3. |
| `strategy_spread_cap_pips` | 20 | >=0 | Blocks entry only when a positive modeled spread exceeds this cap; zero disables the cap. |
| `strategy_block_friday` | true | true/false | Prevents arming a pending order for the Friday broker session. |
| `strategy_eod_hour_et` | 17 | 0-23 | US-Eastern hour for pending-order expiry and same-session position exit. |
| `strategy_eod_minute_et` | 0 | 0-59 | US-Eastern minute for pending-order expiry and same-session position exit. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `USDJPY.DWX` — Goodwin's primary tested FX instrument and the first R3 symbol.
- `EURUSD.DWX` — card-listed portable liquid DWX major pair.
- `GBPUSD.DWX` — card-listed portable liquid DWX major pair.

**Explicitly NOT for:**

- Symbols outside the three-pair R3 basket — the approved card does not authorize a broader universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Expected trade frequency | Approximately 25 filled trades per year per symbol; no separate cadence is stated in the card. |
| Typical hold time | Intraday within one FX trading session, ending at 17:00 US Eastern time. |
| Expected drawdown profile | Not quantified by the card; every fill has a structural stop and setups above the 80-pip bar-range cap are skipped. |
| Regime preference | Breakout / volatility expansion after a confirmed three-bar pivot. |
| Win rate target (qualitative) | Not stated in the approved card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `038d2a5d-1c89-5745-afdb-2cd76b623b77`
**Source type:** book / guidebook
**Pointer:** Jarrod Goodwin, *Beat the Markets Strategy Guidebook*, local PDF `622374394-Beat-the-Markets-Strategy-Guidebook.pdf`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11462_goodwin-j-kangaroo-tail-breakout-d1.md`.

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
| v1 | 2026-08-08 | Initial build from card | 77b13611-feaf-4574-9f2d-c33e8921dc9c |
