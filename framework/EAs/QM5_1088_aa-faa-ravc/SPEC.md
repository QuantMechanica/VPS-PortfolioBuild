# QM5_1088_aa-faa-ravc — Strategy Spec

**EA ID:** QM5_1088
**Slug:** `aa-faa-ravc`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `sources/alpha-architect-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Once per calendar month the EA evaluates the full 7-symbol DWX proxy universe on D1 bars. For each symbol it computes: (a) 4-month relative momentum (close[1]/close[85]-1), (b) 4-month realized daily volatility (std dev of 84 D1 log-returns), and (c) average pairwise correlation with the remaining 6 universe members over the same 84-bar window. It then ranks each dimension — highest momentum best, lowest volatility best, lowest average correlation best — and combines them as composite = rank_momentum + 0.5*rank_vol + 0.5*rank_corr. The top 3 symbols by composite score that also clear the absolute-momentum gate (momentum > 0) are entered long at the first available D1 bar in the new month. Any holding that falls out of the top-3 or fails the absolute-momentum gate is closed at the next monthly rebalance tick.

---

## 2. Parameters

Table of strategy-specific inputs (framework inputs documented in `V5_FRAMEWORK_DESIGN.md`).

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_bars` | `84` | `21-252` | D1 bars for the 4-month ranking window (~4×21 trading days). |
| `strategy_top_n` | `3` | `1-7` | Max simultaneous universe holdings per month. |
| `strategy_atr_period` | `14` | `1-50` | ATR period (D1 bars) for the per-leg protective stop. |
| `strategy_atr_sl_mult` | `4.0` | `0.5-10.0` | ATR multiple applied to set the per-leg SL price. |
| `strategy_rebalance_day_max` | `7` | `1-15` | Latest calendar day in new month where an entry may fire. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 proxy; backtest-only per DWX matrix (no live routing).
- `NDX.DWX` — Nasdaq 100 proxy; live-tradable.
- `GDAXI.DWX` — DAX 40 proxy; live-tradable.
- `XAUUSD.DWX` — Gold proxy; provides diversification from equity trend.
- `XTIUSD.DWX` — WTI crude proxy; commodity diversifier.
- `EURUSD.DWX` — Euro-dollar FX; provides low-correlation leg.
- `USDJPY.DWX` — Dollar-yen FX; risk-off diversifier.

**Explicitly NOT for:**
- Unregistered symbols — ranking logic uses the fixed 7-symbol card universe and registered magic slots only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` (monthly rebalance cadence triggered by calendar-month change in TimeCurrent) |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` plus monthly-rebalance-key cache |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `4` (per-leg; ~3-5 round-trips/yr — a single instance only trades when its symbol is in the top-3 selection and holds across months) |
| Typical hold time | about one month, until next rebalance |
| Expected drawdown profile | moderate tactical-allocation drawdown; bounded by per-leg ATR SL and PORTFOLIO_WEIGHT=0.33 |
| Regime preference | relative momentum with risk-regime and correlation diversification |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog
**Pointer:** Wesley Gray PhD, "Flexible Asset Allocation: Dethroning Moving Average Rules?", Alpha Architect, 2014-09-18
**R1–R4 verdict (Q00):** R1, R2, R4 PASS; R3 UNKNOWN → mapped to approved DWX proxy basket per `artifacts/cards_approved/QM5_1088_aa-faa-ravc.md`

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
| v1 | 2026-06-09 | Initial build from card | 887fd34f-13d1-48a5-ac13-8e99c8d94adb |
| v2 | 2026-06-10 | Rebuild in place: changed from MN1 (untestable in MT5 tester on DWX symbols) to D1 with 84-bar lookback; ATR period 4→14 | 875609bc-1404-4f4e-a478-81b985dca842 |
