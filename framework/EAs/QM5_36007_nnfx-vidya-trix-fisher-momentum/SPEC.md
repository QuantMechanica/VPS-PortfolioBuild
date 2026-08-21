# QM5_36007_nnfx-vidya-trix-fisher-momentum — Strategy Spec

**EA ID:** QM5_36007
**Slug:** `nnfx-vidya-trix-fisher-momentum`
**Source:** `nnfx-vidya-trix-fisher-momentum-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

On each completed D1 bar, the EA buys when the close is above VIDYA(9, CMO 12), TRIX(14) is above its signal line, Fisher is positive, and MFI(14) is at least 50; it sells on the exact inverse conditions. Each entry receives a server-side stop one ATR(14) from the market price. At a one-ATR gain, the EA closes 50% and moves the remaining stop to entry plus or minus one pip; the runner closes when TRIX crosses back through its signal line. Entry is suppressed during the card's GMT rollover window, on a genuinely wide spread, after the card's loss limits, or while this EA already has a position.

The approved card does not state the TRIX signal smoothing period or Fisher lookback, so this build fixes them at conventional EMA(9) and 10-bar defaults and reports that interpretation for review.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_vidya_period` | 9 | 5–15 | VIDYA base smoothing period. |
| `strategy_cmo_period` | 12 | 8–20 | CMO lookback controlling VIDYA's adaptive alpha. |
| `strategy_trix_period` | 14 | 9–21 | Period of each of the three TRIX EMA stages. |
| `strategy_trix_signal_period` | 9 | fixed pending review | EMA period for the card's otherwise unspecified TRIX signal line. |
| `strategy_fisher_period` | 10 | fixed pending review | Lookback for the card's otherwise unspecified Fisher transform. |
| `strategy_mfi_period` | 14 | fixed | Tick-volume MFI lookback stated by the card. |
| `strategy_atr_period` | 14 | fixed | ATR lookback used by stops, TP1, and spread admission. |
| `strategy_mfi_midline` | 50.0 | fixed | Long/short MFI dividing level. |
| `strategy_sl_atr_mult` | 1.0 | fixed | Initial stop distance in ATR units. |
| `strategy_tp1_atr_mult` | 1.0 | fixed | Distance at which 50% is closed. |
| `strategy_spread_atr_mult` | 1.8 | fixed | Blocks entry only when positive spread exceeds this ATR multiple. |
| `strategy_daily_loss_limit_pct` | 2.0 | fixed | Daily realized-loss entry halt. |
| `strategy_daily_drawdown_hard_stop_pct` | 2.5 | fixed | Daily equity hard-stop measured from starting balance. |
| `strategy_total_drawdown_stop_pct` | 5.0 | fixed | Total equity hard-stop measured from initial equity. |
| `strategy_max_slippage_ticks` | 3.0 | fixed | Maximum entry deviation converted from trade ticks to MT5 points. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — the card's primary liquid FX trend instrument and smoke target.
- `GBPJPY.DWX` — the card's higher-volatility portable FX cross for D1 momentum.
- `NZDCAD.DWX` — the card's lower-correlation portable FX cross for D1 momentum.

All three symbols are present in `framework/registry/dwx_symbol_matrix.csv` and have active, distinct slots in `magic_numbers.csv`.

**Explicitly NOT for:**

- Any symbol outside those three rows — the approved card names a finite FX basket and does not authorize expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry; `QM_CalendarPeriodKey(PERIOD_D1)` advances the closed-bar cache without consuming the entry gate. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Expected trade frequency | 80–160 high-conviction trades per year across the basket, as stated in frontmatter |
| Typical hold time | Not specified in card; a D1 trade remains open until SL, TP1 protection plus TRIX recross, or framework Friday close |
| Expected drawdown profile | 18% expected drawdown in card frontmatter, with 2.0% daily realized, 2.5% daily equity, and 5.0% total hard limits |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | not governed; source performance claims were explicitly ignored by G0 approval reasoning |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-vidya-trix-fisher-momentum-official-source`
**Source type:** verified quantitative model
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_36007_nnfx-vidya-trix-fisher-momentum.md` and local build copy `docs/strategy_card.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_36007_nnfx-vidya-trix-fisher-momentum.md`.

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
| v1 | 2026-08-21 | Initial build from card | de0f1ea4-6465-4ba0-836d-483d4fd8dbeb |
