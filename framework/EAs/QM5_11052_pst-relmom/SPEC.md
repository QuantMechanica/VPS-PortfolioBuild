# QM5_11052_pst-relmom — Strategy Spec

**EA ID:** QM5_11052
**Slug:** `pst-relmom`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (pysystemtrade rel_mom rule)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Cross-sectional (relative) momentum from Rob Carver's pysystemtrade `rel_mom`
rule. On each completed D1 bar the EA builds a volatility-normalised cumulative
log-return path for the host symbol and for every peer in the host's asset class
(FX majors, equity indices, or commodities). The asset-class benchmark is the
equal-weight mean of the peers' paths. The host's outperformance path is
`host_path − class_path`. For each horizon H in {10,20,40,80} it computes the
per-bar average outperformance over H bars, smooths it with an EMA of span
`max(H/4, 2)`, scales by the source forecast scalars (61.2403 / 86.5075 /
117.7794 / 159.8780), and clamps each component to [−20, +20]. The combined
forecast is the equal-weight mean of the four components. Enter long when the
combined forecast ≥ +5, short when ≤ −5. Close a long when the forecast decays
to ≤ +1 and a short when it rises to ≥ −1 (signal-reversal exit). An emergency
`3 × ATR(D1, 20)` stop bounds worst-case risk; the primary exit is the signal
reversal. One position per magic per host symbol.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_threshold` | 5.0 | 3-8 | Combined-forecast magnitude to ENTER long/short |
| `strategy_exit_buffer` | 1.0 | 0-2 | Combined-forecast magnitude to EXIT (signal reversal) |
| `strategy_vol_lookback` | 25 | 10-60 | D1 bars for return stdev (volatility normalisation) |
| `strategy_atr_period` | 20 | 10-30 | ATR(D1) period for the emergency stop |
| `strategy_stop_atr_mult` | 3.0 | 2.5-3.5 | Emergency stop distance = mult × ATR(D1) |
| `strategy_min_class_members` | 3 | 3-5 | Min peers with data to compute a class benchmark |
| `strategy_min_d1_bars` | 120 | 100-200 | Warmup: longest horizon + smoothing before trading |

---

## 3. Symbol Universe

**Designed for** (one EA instance per host symbol; the host is benchmarked
against its own asset class):

- `EURUSD.DWX` — FX major; benchmarked vs the FX-majors class.
- `GBPUSD.DWX` — FX major; FX-majors class.
- `USDJPY.DWX` — FX major; FX-majors class.
- `AUDUSD.DWX` — FX major; FX-majors class.
- `NDX.DWX` — Nasdaq 100 index; equity-indices class (live-tradable).
- `WS30.DWX` — Dow 30 index; equity-indices class (live-tradable).
- `XAUUSD.DWX` — Gold; commodities class.

**Foreign-symbol benchmark peers** (read-only on D1, never traded by another
class's instance): FX class adds NZDUSD/USDCHF/USDCAD; INDEX class adds
SP500/GDAXI/UK100; COMMODITY class adds XAGUSD/XTIUSD/XNGUSD — all present in
`framework/registry/dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Any symbol whose asset class has fewer than `strategy_min_class_members`
  peers carrying data — the cross-sectional benchmark would be meaningless and
  the EA produces no signal.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Foreign-symbol D1 reads of asset-class peers (basket benchmark) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | days to weeks (signal-reversal exit) |
| Expected drawdown profile | ~18% (crowds into recent leaders; can reverse at regime turns) |
| Regime preference | trend / cross-sectional persistence within an asset class |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** code (open-source library)
**Pointer:** https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rules/rel_mom.py (+ `rob_system/config.yaml`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11052_pst-relmom.md`

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
| v1 | 2026-06-17 | Initial build from card | basket EA, one position per magic |
