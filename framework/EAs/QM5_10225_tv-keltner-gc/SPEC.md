# QM5_10225_tv-keltner-gc - Strategy Spec

**EA ID:** QM5_10225
**Slug:** `tv-keltner-gc`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

Long when the fast EMA is above the slow EMA and the confirmed bar close crosses above the EMA-based Keltner upper breakout band. Short when the fast EMA is below the slow EMA and the confirmed bar close crosses below the Keltner lower breakout band. The stop is placed 1.5 ATR from entry by default and the take-profit is placed 3.0 ATR from entry by default. No discretionary exit is added beyond the bracket SL/TP and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ma_period` | 50 | 1-500 | Fast EMA used for golden-cross trend alignment. |
| `strategy_slow_ma_period` | 200 | 1-1000 | Slow EMA used for trend alignment. |
| `strategy_keltner_ema_period` | 20 | 1-500 | EMA basis period for the Keltner channel. |
| `strategy_atr_period` | 14 | 1-500 | ATR period for the Keltner bands and bracket distances. |
| `strategy_breakout_atr_mult` | 1.0 | 0.1-10.0 | ATR multiplier for the breakout channel. |
| `strategy_sl_atr_mult` | 1.5 | 0.1-20.0 | ATR distance for the stop-loss from entry. |
| `strategy_tp_atr_mult` | 3.0 | 0.1-50.0 | ATR distance for the take-profit from entry. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card-listed liquid gold CFD with stable ATR/Keltner bands.
- `GDAXI.DWX` - DWX matrix equivalent for the card's `GER40.DWX` index target.
- `NDX.DWX` - card-listed liquid US index CFD.
- `EURUSD.DWX` - card-listed liquid FX pair.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Non-DWX symbols - research and backtest artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

The card recommends M15, H1, and H4 testing. H1 is used as the primary build/smoke timeframe, with M15 and H4 setfiles generated for downstream coverage.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | hours to a few days; not specified in card frontmatter |
| Expected drawdown profile | ATR-bracketed breakout drawdowns with whipsaw risk in range-bound markets |
| Regime preference | trend-following / Keltner breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script page
**Pointer:** `https://www.tradingview.com/script/9N0JyfyH-Keltner-Channel-Strategy-with-Golden-Cross/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10225_tv-keltner-gc.md`

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
| v1 | 2026-06-09 | Initial build from card | a39ea283-838e-4acf-81d4-515f721d36b1 |
