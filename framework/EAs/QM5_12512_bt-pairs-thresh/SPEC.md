# QM5_12512_bt-pairs-thresh — Strategy Spec

**EA ID:** QM5_12512
**Slug:** `bt-pairs-thresh`
**Source:** `2d7aaa5f-321c-524b-99ce-bc921cddfc60`
**Author of this spec:** Codex
**Last revised:** 2026-07-24

## 1. Strategy Logic

On each completed H1 bar, the EA calculates `log(A) - log(B)` for one of three fixed FX pairs and standardizes it over 240 bars. It sells A and buys B at z-score +2, or buys A and sells B at z-score -2. Both legs close at absolute z-score 0.25, absolute z-score 3.5, after five H1 bars, or when either leg's ATR emergency stop or a framework exit fires.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `spread_lookback_bars` | 240 | 120–480 | H1 observations for spread mean and standard deviation |
| `fixed_beta` | 1.0 | fixed | Non-adaptive hedge ratio |
| `z_entry` | 2.0 | 1.5–2.5 | Absolute entry threshold |
| `z_exit` | 0.25 | 0.0–0.5 | Mean-reversion exit threshold |
| `z_pair_stop` | 3.5 | 3.0–4.0 | Pair-level emergency exit |
| `max_holding_bars` | 5 | 5–24 | Maximum H1 holding period |
| `atr_period` | 20 | fixed | Per-leg ATR lookback |
| `atr_stop_mult` | 2.0 | fixed | Per-leg emergency-stop distance |
| `median_spread_bars` | 1440 | fixed | 60 trading days of H1 spread samples |
| `median_spread_multiple` | 2.0 | fixed | Maximum current spread relative to median |

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` / `GBPUSD.DWX` — liquid European-major relative-value pair.
- `EURJPY.DWX` / `GBPJPY.DWX` — shared JPY quote isolates EUR/GBP relative movement.
- `AUDUSD.DWX` / `NZDUSD.DWX` — closely related Antipodean currencies.

**Explicitly NOT for:**
- Unregistered symbols or dynamically discovered pairs — the approved baseline is limited to the three named pairs.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the host H1 chart |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Typical hold time | no more than 5 H1 bars |
| Expected drawdown profile | bounded two-leg relative-value losses with ATR and z-score stops |
| Regime preference | mean-reverting relative FX prices |
| Win rate target (qualitative) | medium |

## 6. Source Citation

**Source ID:** `2d7aaa5f-321c-524b-99ce-bc921cddfc60`
**Source type:** GitHub repository
**Pointer:** `https://github.com/pmorissette/bt`, `examples/pairs_trading.py`, commit `2630651f212c025f0cec351d6319ad81d587ad6e`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_12512_bt-pairs-thresh.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 total pair risk, split 50/50 |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Requires a separately approved execution contract |

ENV-to-mode validation is enforced by `QM_FrameworkInit`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-24 | Initial build from card | d60f8790-0ae1-4a64-82ef-6ed810f4a92c |
