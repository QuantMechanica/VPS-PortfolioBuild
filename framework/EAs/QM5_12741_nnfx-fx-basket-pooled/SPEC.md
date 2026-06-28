# QM5_12741_nnfx-fx-basket-pooled - Strategy Spec

**EA ID:** QM5_12741
**Slug:** `nnfx-fx-basket-pooled`
**Source:** `nnfx-vp-canonical-2026-06-12` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-28

---

## 1. Strategy Logic

The EA runs on `AUDUSD.DWX` D1 and evaluates four FX majors once per completed D1 bar. For each member, it opens long when price has crossed above Kijun(26) within the entry window and SSL(10), Aroon(25), and Waddah-Attar-style MACD/Bollinger expansion all agree upward; it opens short on the symmetric downward alignment. Initial stop is 1.5 x ATR(14), half the position is closed at 1.0 x ATR in profit, and the runner stop is moved to breakeven. A leg exits when price recrosses Kijun against the position or SSL flips against it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_kijun_period` | 26 | 10-40 | Kijun baseline period. |
| `strategy_ssl_period` | 10 | 5-20 | SSL high/low moving-average period. |
| `strategy_aroon_period` | 25 | 14-40 | Aroon confirmation lookback. |
| `strategy_entry_window_bars` | 3 | 1-7 | Bars after a Kijun cross where the stack may align. |
| `strategy_atr_period` | 14 | 10-30 | ATR period for proximity, stop, and half-profit trigger. |
| `strategy_atr_proximity_mult` | 1.0 | 0.5-2.0 | Maximum distance from Kijun at entry in ATR units. |
| `strategy_sl_atr_mult` | 1.5 | 1.0-3.0 | Initial stop distance in ATR units. |
| `strategy_tp_half_atr_mult` | 1.0 | 0.5-2.0 | Profit trigger for half close and breakeven runner. |
| `strategy_wae_fast` | 20 | 12-30 | Fast MACD period for the WAE-style momentum gate. |
| `strategy_wae_slow` | 40 | 26-60 | Slow MACD period for the WAE-style momentum gate. |
| `strategy_wae_signal` | 9 | 5-15 | MACD signal period for the WAE-style momentum gate. |
| `strategy_wae_sensitivity` | 150.0 | 50-250 | Momentum scaling for the WAE-style gate. |
| `strategy_wae_bb_period` | 20 | 10-40 | Bollinger period for the expansion threshold. |
| `strategy_wae_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger deviation for the expansion threshold. |
| `strategy_wae_deadzone_pts` | 150 | 50-300 | Minimum point threshold for the WAE-style gate. |
| `strategy_max_family_positions` | 4 | 1-4 | Maximum simultaneous open basket legs. |
| `strategy_leg_risk_fraction` | 0.25 | 0.10-0.50 | Fraction of framework risk budget used per leg. |
| `strategy_max_spread_points` | 0 | 0-100 | Optional spread cap; 0 disables the cap. |
| `strategy_deviation_points` | 20 | 5-50 | Order deviation for basket leg sends. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - gross-positive member named by the approved card and host chart.
- `EURUSD.DWX` - gross-positive member named by the approved card.
- `GBPUSD.DWX` - gross-positive member named by the approved card.
- `USDCHF.DWX` - gross-positive member named by the approved card.

**Explicitly NOT for:**
- Other FX majors - excluded by the card because prior NNFX gross evidence was weaker.
- Metals, indices, and energy CFDs - excluded because this card is specifically the pooled FX trend sleeve.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `3` |
| Typical hold time | days to several weeks |
| Expected drawdown profile | Low-frequency trend sleeve with ATR-bounded per-leg risk. |
| Regime preference | FX trend persistence after multi-filter confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-vp-canonical-2026-06-12`
**Source type:** `published trading method / OWNER audit refinement`
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12741_nnfx-fx-basket-pooled.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12741_nnfx-fx-basket-pooled.md`

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
| v1 | 2026-06-28 | Initial build from card | e553d527 |
