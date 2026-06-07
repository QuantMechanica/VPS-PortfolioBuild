# QM5_11113_tdseq-setup9 - Strategy Spec

**EA ID:** QM5_11113
**Slug:** `tdseq-setup9`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H4 bars for a TD Sequential setup-9 exhaustion pattern. A long signal appears when nine completed closes in a row are below the close four bars earlier and the first setup bar follows the buy price-flip condition; a short signal uses the mirrored greater-than rule and sell price flip. Long trades use the lower of the setup low and 2.0 x ATR(14) below entry as the stop, while short trades use the higher of the setup high and 2.0 x ATR(14) above entry. Open trades close on the reconstructed TDST level, an opposite setup-9 signal, or after 20 H4 bars.

---

## 2. Parameters

Table of every strategy-specific input parameter, its default, range, and meaning.

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_setup_bars` | 9 | 9 fixed | TD Sequential setup completion count from the card. |
| `strategy_compare_lag_bars` | 4 | 4 fixed | Close comparison lag for TD setup counting. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for the volatility stop branch. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple used to place the stop branch. |
| `strategy_max_hold_bars` | 20 | 1-200 | Maximum H4 bars to hold a trade before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid forex symbol with OHLC data suitable for TD counts.
- `GBPUSD.DWX` - Card-listed liquid forex symbol with OHLC data suitable for TD counts.
- `USDJPY.DWX` - Card-listed liquid forex symbol with OHLC data suitable for TD counts.
- `XAUUSD.DWX` - Card-listed liquid gold symbol with OHLC data suitable for TD counts.

**Explicitly NOT for:**
- `SP500.DWX` - Not in the card's R3 primary P2 basket.
- `NDX.DWX` - Not in the card's R3 primary P2 basket.
- `WS30.DWX` - Not in the card's R3 primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `32` |
| Typical hold time | Up to 20 H4 bars by card time exit. |
| Expected drawdown profile | Exhaustion-reversal trades with fixed stop risk and no pyramiding. |
| Regime preference | Exhaustion reversal after directional nine-bar close sequences. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** GitHub repository / MQL5 source
**Pointer:** `https://github.com/EarnForex/TDSequentialUltimate`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11113_tdseq-setup9.md`

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
| v1 | 2026-06-07 | Initial build from card | 335a1481-4dfe-457b-bc8c-a80b1080bc97 |
