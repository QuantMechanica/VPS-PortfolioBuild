# QM5_9574_demark-td-anti-diff-3bar-h4 - Strategy Spec

**EA ID:** QM5_9574
**Slug:** `demark-td-anti-diff-3bar-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9574_demark-td-anti-diff-3bar-h4.md`)
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

The EA trades a closed-bar H4 DeMark TD Anti-Differential reversal pattern. A long signal requires three declining closes, then a bullish reversal close whose size is at least 60% of the prior down leg, with the prior bar making a lower low and a range of at least 0.7 ATR(14). A short signal mirrors the same rules after three rising closes. The stop is placed beyond the four-bar setup with a 0.3 ATR buffer, the target is 1.8R, and positions are closed after 12 H4 bars or on an opposite pattern.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period used for exhaustion, stop buffer, and spread scaling. |
| `strategy_asymmetry_mult` | 0.60 | 0.10-2.00 | Minimum reversal close size relative to the prior setup leg. |
| `strategy_exhaustion_range_atr` | 0.70 | 0.10-5.00 | Minimum setup-bar range as a multiple of ATR. |
| `strategy_stop_buffer_atr` | 0.30 | 0.00-3.00 | ATR buffer added beyond the four-bar setup high/low for SL. |
| `strategy_rr_target` | 1.80 | 0.50-10.00 | Reward-to-risk multiple for TP. |
| `strategy_max_hold_bars` | 12 | 1-100 | H4 bars to hold before time-stop exit. |
| `strategy_max_setup_range_atr` | 4.00 | 0.50-20.00 | Rejects extreme four-bar ranges above this ATR multiple. |
| `strategy_spread_atr_fraction` | 0.20 | 0.00-2.00 | Blocks entries when modeled spread exceeds this ATR fraction. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major in the card basket.
- `GBPUSD.DWX` - FX major in the card basket.
- `USDJPY.DWX` - FX major in the card basket.
- `AUDUSD.DWX` - FX major in the card basket.
- `USDCAD.DWX` - FX major in the card basket.
- `USDCHF.DWX` - FX major in the card basket.
- `NZDUSD.DWX` - FX major in the card basket.
- `XAUUSD.DWX` - metal CFD in the card basket.
- `XTIUSD.DWX` - non-XNG energy CFD in the card basket.
- `GDAXI.DWX` - index CFD in the card basket.
- `NDX.DWX` - index CFD in the card basket.
- `WS30.DWX` - index CFD in the card basket.
- `UK100.DWX` - index CFD in the card basket.

**Explicitly NOT for:**
- `FRA40.DWX` - listed in the card but absent from `framework/registry/dwx_symbol_matrix.csv`.
- `JP225.DWX` - listed in the card but absent from `framework/registry/dwx_symbol_matrix.csv`.

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
| Trades / year / symbol | `26` |
| Typical hold time | Up to 12 H4 bars, about 2 trading days. |
| Expected drawdown profile | Reversal pattern with fixed 1R stop and 1.8R target; sensitive to strongly trending regimes. |
| Regime preference | Reversal / exhaustion after short directional runs. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `web_forum` plus DeMark/Perl book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9574_demark-td-anti-diff-3bar-h4.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9574_demark-td-anti-diff-3bar-h4.md`

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
| v1 | 2026-07-01 | Initial build from card | 54d9b053-29b5-40cb-ba0c-e4af108f6307 |
