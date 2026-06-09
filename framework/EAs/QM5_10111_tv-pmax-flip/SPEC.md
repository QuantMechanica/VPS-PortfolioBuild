# QM5_10111_tv-pmax-flip - Strategy Spec

**EA ID:** QM5_10111
**Slug:** `tv-pmax-flip`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades the PMax flip rule from the approved card on closed H1 bars. It computes an EMA(10) and a PMax line built from EMA plus ATR(10) bands at a 3.0 multiplier; the PMax line trails on the active side and flips direction when the EMA crosses the opposite stop. A long entry fires when the EMA crosses above PMax, and a short entry fires when the EMA crosses below PMax. On an opposite signal, the EA closes the current position and opens the opposite side, with the initial stop and trailing stop anchored to the active PMax line.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 10 | 2-100 | ATR period used to build the PMax line. |
| `strategy_atr_mult` | 3.0 | 0.1-10.0 | ATR multiplier applied to the EMA stop bands. |
| `strategy_ma_period` | 10 | 2-200 | EMA period used as the moving average side of the cross. |
| `strategy_filter_atr_period` | 14 | 2-100 | ATR period used for stop-distance validation and optional TP. |
| `strategy_min_stop_atr` | 0.5 | 0.0-10.0 | Minimum initial PMax stop distance as a multiple of ATR(14). |
| `strategy_max_stop_atr` | 4.0 | 0.1-20.0 | Maximum initial PMax stop distance as a multiple of ATR(14). |
| `strategy_max_spread_frac` | 0.10 | 0.0-1.0 | Maximum allowed spread as a fraction of PMax stop distance. |
| `strategy_use_protective_tp` | true | true/false | Enables the P2 protective take-profit from the card. |
| `strategy_tp_atr_mult` | 4.0 | 0.0-20.0 | Protective take-profit distance as a multiple of ATR(14). |
| `strategy_pmax_warmup_bars` | 150 | 20-500 | Number of closed bars used to reconstruct the trailing PMax state. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major from the card's P2 basket; liquid H1 trend-following test market.
- `GBPUSD.DWX` - FX major from the card's P2 basket; liquid H1 trend-following test market.
- `XAUUSD.DWX` - Gold CFD from the card's P2 basket; volatile trend-following market.
- `GDAXI.DWX` - Canonical DWX DAX symbol used in place of card-stated `GER40.DWX`, which is not present in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any unregistered symbol - the framework magic resolver only permits active registry rows for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Hours to a few days, until the next PMax flip or protective TP/SL. |
| Expected drawdown profile | Trend-following whipsaws in sideways regimes; risk bounded by framework sizing and PMax stop distance. |
| Regime preference | Trend-following / trailing-stop reversal. |
| Win rate target (qualitative) | Medium. |

Card cadence note: H1 trailing-stop reversal signals are expected to produce roughly 25-55 trades per year per symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/nHGK4Qtp/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10111_tv-pmax-flip.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | 7b0fbb9d-5575-4193-bc7b-8df553edf3a1 |
