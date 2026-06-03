# QM5_10567_mql5-aroonhorn_v2_v2 ? Strategy Spec

**EA ID:** QM5_10567
**Slug:** `mql5-aroonhorn`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `artifacts/source_notes/b8b5125a-c67f-5bbc-baff-33456e08f5b2.md`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes a closed-bar Aroon oscillator from the most recent high and low locations over the configured lookback window. It opens long when the latest closed bar flips from non-bullish to a bullish AroonHornSign color point, and opens short when the latest closed bar flips from non-bearish to a bearish color point. Existing long positions close on a bearish point, and existing short positions close on a bullish point. Broker SL/TP use the card's P2 baseline: ATR(14) times 2.0 for the hard stop and a 1.5R take-profit target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for closed-bar AroonHornSign signal evaluation. |
| `strategy_aroon_period` | `25` | `2+` | Lookback window for locating the most recent high and low in the Aroon calculation. |
| `strategy_aroon_threshold` | `0.0` | `>= 0` | Minimum oscillator level for bullish and bearish color-point confirmation. |
| `strategy_atr_period` | `14` | `1+` | ATR lookback used for the hard stop distance. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | ATR multiple for the hard stop. |
| `strategy_target_r` | `1.5` | `> 0` | Reward-to-risk multiple for the take-profit target. |

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` ? source test family includes EURJPY H4, and the card lists it for DWX FX portability.
- `EURUSD.DWX` ? card-listed major FX target with dense DWX history.
- `GBPJPY.DWX` ? card-listed JPY cross for portable Aroon trend-signal testing.
- `XAUUSD.DWX` ? card-listed metals target for portable trend color-point testing.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` ? not valid for DWX P2 registration.
- Symbols not named in the card's primary P2 basket ? not part of this approved build scope.

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
| Trades / year / symbol | `35` |
| Typical hold time | hours to days on H4 color-point reversals |
| Expected drawdown profile | ATR-defined losses with 1.5R targets; moderate trade frequency. |
| Regime preference | trend / color-point reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/15336`
**R1?R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10567_mql5-aroonhorn_v2_v2.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 ? Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% ? 0.5%) |

ENV?mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-29 | Initial build from card | dc1ca836-9acb-4e4b-b56e-dcdb8e092140 |


