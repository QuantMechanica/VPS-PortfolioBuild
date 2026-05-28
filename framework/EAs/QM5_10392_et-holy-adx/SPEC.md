# QM5_10392_et-holy-adx — Strategy Spec

**EA ID:** QM5_10392
**Slug:** `et-holy-adx`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades H1 pullbacks during strong ADX regimes. A long setup requires ADX(14) above 30, the completed bar close below EMA(20), and SMA(close, 5) rising versus the prior completed bar; it then places a buy stop at that setup bar high. A short setup mirrors this with the close above EMA(20), a falling SMA(close, 5), and a sell stop at the setup bar low. Broker SL/TP handle the 3-bar extreme stop and 10-bar extreme target, with a 20-bar time-stop failsafe if neither level closes the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 1+ | ADX lookback period. |
| `strategy_adx_cutoff` | 30.0 | 0+ | Minimum ADX value required for any setup. |
| `strategy_ema_period` | 20 | 1+ | EMA period for the pullback-side test. |
| `strategy_slope_period` | 5 | 1+ | SMA period used for the one-bar slope check. |
| `strategy_stop_lookback` | 3 | 1+ | Bars used for the source stop extreme. |
| `strategy_target_lookback` | 10 | 1+ | Bars used for the source target extreme. |
| `strategy_atr_period` | 14 | 1+ | ATR period for the maximum stop-distance filter. |
| `strategy_max_stop_atr` | 3.0 | 0+ | Skip entries whose stop distance exceeds this ATR multiple. |
| `strategy_min_spreads_stop` | 4 | 1+ | Minimum stop distance expressed in current spreads. |
| `strategy_max_hold_bars` | 20 | 1+ | Time-stop failsafe in bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair from the approved card basket.
- `GBPUSD.DWX` — liquid major FX pair from the approved card basket.
- `XAUUSD.DWX` — liquid metal CFD from the approved card basket.
- `GDAXI.DWX` — canonical DAX custom symbol available in the DWX matrix, used for the card's GER40 leg.
- `NDX.DWX` — liquid US index CFD from the approved card basket.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.

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
| Trades / year / symbol | `35` |
| Typical hold time | `hours to less than one trading day; failsafe exits after 20 H1 bars` |
| Expected drawdown profile | `Bounded stop trend-pullback drawdowns, with whipsaw risk in exhausted high-ADX regimes.` |
| Regime preference | `trend-pullback / strong ADX trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://elitetrader.com/et/threads/is-the-holy-grail-a-viable-method.12489/page-3#post-180289`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10392_et-holy-adx.md`

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
| v1 | 2026-05-25 | Initial build from card | a32acd3d-8cd7-4e87-b5df-7a95c08f093f |
