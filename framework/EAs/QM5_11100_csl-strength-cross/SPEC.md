# QM5_11100_csl-strength-cross - Strategy Spec

**EA ID:** QM5_11100
**Slug:** csl-strength-cross
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA computes EarnForex Currency Strength Lines in the default ASI total mode for the base and quote currencies of the active FX pair. A long entry fires when the base-currency strength was below the quote-currency strength on the previous completed bar and crosses above it on the latest completed bar. A short entry fires on the inverse cross. Open trades close on the opposite strength cross, after 24 H1 bars, or through the ATR hard stop and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_calculation_mode` | `STRATEGY_CSL_ASI_TOT` | `STRATEGY_CSL_ASI_TOT`, `STRATEGY_CSL_ASI_TOT_MA` | Currency-strength calculation mode; default matches the card source default. |
| `strategy_rsi_period` | `14` | `2+` | RSI period used by the ASI strength calculation. |
| `strategy_smoothing_period` | `5` | `1+` | Averaging length used only when the MA variant is selected. |
| `strategy_opposite_zeros` | `false` | `true/false` | Optional P3 axis requiring the two currency lines to be on opposite sides of zero. |
| `strategy_atr_period` | `14` | `1+` | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | `2.5` | `>0` | ATR multiplier for the hard stop distance. |
| `strategy_max_hold_h1_bars` | `24` | `0+` | Maximum hold duration in H1 bars; zero disables the time exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair in the card's R3 basket and in the source's currency-strength universe.
- `GBPUSD.DWX` - major FX pair in the card's R3 basket and in the source's currency-strength universe.
- `USDJPY.DWX` - major FX pair in the card's R3 basket and in the source's currency-strength universe.
- `AUDUSD.DWX` - major FX pair in the card's R3 basket and in the source's currency-strength universe.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the source calculation depends on eight major currency strength lines.
- FX symbols outside the registered basket - Q02 should use the card's portable R3 basket only.

**Data-only dependencies (read, never traded):** the EA reads RSI on the full
28-pair major-currency universe (AUD/CAD/CHF/EUR/GBP/JPY/NZD/USD crosses) to
build each currency's strength line. These 28 pairs are registered via
`QM_SymbolGuardInit` and history-loaded via `QM_BasketWarmupHistory` in
`OnInit`; only the 4 symbols above carry magic-number registrations and take
positions.

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
| Trades / year / symbol | `45` |
| Typical hold time | `Up to 24 H1 bars` |
| Expected drawdown profile | `ATR-defined single-position FX momentum losses, bounded by 2.5 x ATR(14).` |
| Regime preference | `relative-momentum` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub source
**Pointer:** https://github.com/EarnForex/Currency-Strength-Lines
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11100_csl-strength-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | caaacf02-a1be-4ff4-bee3-63ccaf3debaa |
