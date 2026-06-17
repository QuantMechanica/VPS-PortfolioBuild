# QM5_11058_pst-skewfactor — Strategy Spec

**EA ID:** QM5_11058
**Slug:** `pst-skewfactor`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (see `strategy-seeds/sources/352af9de-f372-5cf2-9a86-681a26224597/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Cross-sectional negative-skew factor on D1, ported from Rob Carver's pysystemtrade
`rob_system` skew rules. Once per closed D1 bar the EA computes, for each of the 7
basket assets, the sample skew of its own last-L daily percentage returns and negates
it (`neg_skew = -rolling_skew`) for two lookbacks, L=365 and L=180. It then builds four
forecast components for the host symbol: `skewabs365`/`skewabs180` demean the host's
neg_skew against the cross-sectional (all-asset) mean and normalise by the
cross-sectional robust volatility (stdev of neg_skew across assets); `skewrv365`/
`skewrv180` demean against the host's asset-class mean instead. Each component is
EWMA-smoothed (span 90 for the 365D pair, span 45 for the 180D pair), multiplied by its
pysystemtrade forecast scalar, and capped to [-20,+20]. The combined forecast is the
equal-weight average of the available components. Enter long when combined ≥ +5, short
when combined ≤ −5. Close a long when the forecast decays to ≤ +1, a short when it
recovers to ≥ −1 (signal-reversal exit). One position per magic, so a flip only fires
after the position is flat and a later D1 close re-crosses the opposite entry threshold.
An emergency 3.0×ATR(20,D1) stop bounds worst-case risk; there is no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_skew_long_lookback` | 365 | 180-500 | D1 bars for the 365D skew components |
| `strategy_skew_short_lookback` | 180 | 90-365 | D1 bars for the 180D skew components |
| `strategy_ewma_span_long` | 90 | 30-180 | EWMA span for the 365D components |
| `strategy_ewma_span_short` | 45 | 15-90 | EWMA span for the 180D components |
| `strategy_scalar_abs365` | 2.351484 | fixed | pysystemtrade forecast scalar (skewabs365) |
| `strategy_scalar_abs180` | 4.590247 | fixed | pysystemtrade forecast scalar (skewabs180) |
| `strategy_scalar_rv365` | 3.002222 | fixed | pysystemtrade forecast scalar (skewrv365) |
| `strategy_scalar_rv180` | 5.244753 | fixed | pysystemtrade forecast scalar (skewrv180) |
| `strategy_forecast_cap` | 20.0 | 10-40 | Per-component clamp to [-cap,+cap] |
| `strategy_entry_threshold` | 5.0 | 3-8 | \|combined\| ≥ this to enter (P3 sweep {3,5,8}) |
| `strategy_exit_buffer` | 1.0 | 0-2 | Close when forecast decays inside this band (P3 {0,1,2}) |
| `strategy_atr_period` | 20 | 10-30 | ATR period for the emergency stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-3.5 | Stop distance = mult × ATR(D1) (P3 sweep {2.5,3.0,3.5}) |
| `strategy_min_d1_bars` | 420 | 250-600 | Warmup: 365D skew + smoothing before any asset is ready |
| `strategy_min_class_assets` | 3 | 2-7 | Min active assets in host class to enable the rv components |
| `strategy_spread_atr_cap_pct` | 200.0 | 50-400 | Skip entry if spread > this % of ATR(D1) (proxy for 2×median) |

---

## 3. Symbol Universe

This is a BASKET / cross-sectional FACTOR EA: every instance reads the full 7-asset
basket on D1 to build the cross-sectional skew factor, and trades only the host symbol.

**Designed for (registered hosts = the card's target basket):**
- `EURUSD.DWX` — FX major; deep D1 return history for stable skew.
- `GBPUSD.DWX` — FX major; FX-class relative skew leg.
- `USDJPY.DWX` — FX major; FX-class relative skew leg.
- `AUDUSD.DWX` — FX major (risk proxy); FX-class relative skew leg.
- `NDX.DWX` — Nasdaq 100; equity-index class, live-tradable.
- `WS30.DWX` — Dow 30; equity-index class, live-tradable.
- `XAUUSD.DWX` — Gold; commodity class, broadens the cross-section.

**Explicitly NOT for:**
- Symbols outside the registered basket — the cross-sectional demean and the host's
  asset-class mean are only defined for the 7 modelled assets; an unregistered host
  decodes to `g_host_idx = -1` and never trades (inert by design).

> Note: the commodity class holds a single asset (XAUUSD), so on XAUUSD the two `rv`
> (asset-class) components are suppressed (`min_class_assets=3` not met) and the
> forecast is built from the two `abs` (all-asset) components only — a deliberate,
> deterministic degradation, not a defect.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `D1 close reads across the full 7-asset basket (skew + cross-section)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default; D1) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~12` |
| Typical hold time | `weeks (slow factor; signal-reversal exit)` |
| Expected drawdown profile | `medium; slow factor, can be structurally biased by asset class` |
| Regime preference | `cross-sectional factor (negative-skew premium harvest)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** `repo` (open-source trading system — pysystemtrade)
**Pointer:** `https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rules/factors.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11058_pst-skewfactor.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
