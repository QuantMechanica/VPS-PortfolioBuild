# QM5_11055_pst-assettrend — Strategy Spec

**EA ID:** QM5_11055
**Slug:** `pst-assettrend`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (Rob Carver / pysystemtrade rob_system asset-class trend)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

This is a basket EA. Instead of trending the traded symbol directly, it trends the
median volatility-normalised cumulative return series of the symbol's whole asset
class (forex, equity index, or metals/commodities). Once per completed D1 bar, for
each member of the host's asset class it computes the daily return divided by that
member's trailing robust daily volatility, then takes the cross-sectional median
across members and cumulates it into a synthetic "asset-class normalised price".
On that synthetic series it computes six EWMAC trend components for fast spans
{2,4,8,16,32,64} (slow span = 4× fast), each as
`(EMA(fast) − EMA(slow)) / robust_vol(diff(price),35)`, scaled by the source
forecast scalars `{10.846520, 7.572335, 5.190471, 3.549453, 2.344923, 1.546514}`
and capped to [−20,+20]. The combined forecast is the equal-weight mean of the six.
The host goes long when the combined forecast ≥ +5 and short when ≤ −5; it closes a
long when the forecast falls to ≤ +1 and a short when it rises to ≥ −1 (signal
reversal is the primary exit). An emergency stop of 3.0× ATR(20, D1) from entry
bounds worst-case MT5 risk; there is no take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_threshold` | 5.0 | 3.0-8.0 | Combined-forecast magnitude required to ENTER |
| `strategy_exit_buffer` | 1.0 | 0.0-2.0 | Combined-forecast magnitude at which an open trade EXITS |
| `strategy_min_class_members` | 3 | 3-5 | Minimum active asset-class members required for a valid forecast |
| `strategy_vol_lookback` | 35 | 20-60 | Robust-volatility lookback in D1 bars (normalisation + diff vol) |
| `strategy_atr_period` | 20 | 10-30 | ATR period for the emergency stop (D1) |
| `strategy_stop_atr_mult` | 3.0 | 2.5-3.5 | Emergency stop distance = mult × ATR(period, D1) |
| `strategy_min_d1_bars` | 320 | 200-400 | Minimum D1 warmup bars required per member |
| `strategy_series_window` | 400 | 200-650 | Synthetic-series reconstruction window in D1 bars |
| `strategy_spread_pct_of_stop` | 20.0 | 5.0-50.0 | Skip new entries if host spread exceeds this % of stop distance |

---

## 3. Symbol Universe

The EA runs per host symbol; the host's asset class supplies the basket the forecast
is built from. Registered hosts (card `target_symbols`):

**Designed for:**
- `EURUSD.DWX` — forex-class host; FX basket = the 28 DWX majors/minors.
- `GBPUSD.DWX` — forex-class host.
- `USDJPY.DWX` — forex-class host.
- `AUDUSD.DWX` — forex-class host.
- `NDX.DWX` — equity-index host; index basket = NDX/WS30/GDAXI/UK100/SP500.
- `WS30.DWX` — equity-index host.
- `XAUUSD.DWX` — metals/commodities host; class basket = XAUUSD/XAGUSD/XTIUSD/XNGUSD.

**Explicitly NOT for:**
- Any symbol whose asset class has fewer than `strategy_min_class_members` (3)
  testable DWX members — the forecast suppresses entries (XAU's class is padded
  with XAG/XTI/XNG to reach the minimum, per the card's ≥3-member rule).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | foreign-symbol D1 closes for every asset-class member (basket) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~35 (card claim; G0 reasoning flags this as inflated, ≥2/yr plausible) |
| Typical hold time | days to weeks (D1 trend) |
| Expected drawdown profile | medium-high; correlated trades across class members |
| Regime preference | trend-following |
| Win rate target (qualitative) | low-medium (trend-follower: few large winners) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** repo (open-source quant framework)
**Pointer:** https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rob_system/config.yaml (rules assettrend2..64; `systems/rawdata.py` normalised_price_for_asset_class)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11055_pst-assettrend.md`

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
