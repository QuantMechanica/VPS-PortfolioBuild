# QM5_9508_carver-carrybook - Strategy Spec

**EA ID:** QM5_9508
**Slug:** carver-carrybook
**Source:** 1a059d6d-84fa-5d0c-94c5-86dd0481637c (see `sources/carver-leveraged-trading`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the daily direction implied by broker swap metadata. On each D1 bar it computes `CarryScore = SwapLong - SwapShort`, smooths it with a 20-period EMA, and enters long after three consecutive smoothed readings above a deadband or short after three consecutive smoothed readings below the negative deadband. It exits a long after two consecutive non-positive smoothed carry readings, exits a short after two consecutive non-negative readings, or closes either side after 180 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_carry_ema_period` | 20 | `>=1` | EMA period used to smooth the swap carry score. |
| `strategy_confirm_bars` | 3 | `>=1` | Consecutive D1 bars required before entry. |
| `strategy_exit_confirm_bars` | 2 | `>=1` | Consecutive D1 bars required before signal-reversal exit. |
| `strategy_deadband_mult` | 0.10 | `>=0` | Deadband multiplier applied to the absolute carry proxy. |
| `strategy_deadband_proxy_days` | 252 | `>=1` | Card horizon for median absolute carry; current swap metadata is used as the deterministic available proxy. |
| `strategy_atr_period` | 25 | `>=1` | ATR period for the hard initial stop. |
| `strategy_atr_stop_mult` | 3.0 | `>0` | ATR multiple for the hard initial stop. |
| `strategy_max_hold_bars` | 180 | `>=1` | Maximum D1 bars before forced refresh exit. |
| `strategy_spread_median_days` | 60 | `>=1` | D1 spread sample length for the entry spread filter. |
| `strategy_spread_mult` | 2.0 | `>0` | Maximum current spread as a multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDJPY.DWX` - FX pair from the card target universe with DWX swap metadata.
- `AUDUSD.DWX` - FX pair from the card target universe with DWX swap metadata.
- `NZDJPY.DWX` - FX pair from the card target universe with DWX swap metadata.
- `NZDUSD.DWX` - FX pair from the card target universe with DWX swap metadata.
- `USDJPY.DWX` - FX pair from the card target universe with DWX swap metadata.
- `EURUSD.DWX` - FX pair from the card target universe with DWX swap metadata.
- `GBPJPY.DWX` - FX pair from the card target universe with DWX swap metadata.
- `XAUUSD.DWX` - Card-listed non-FX symbol; entry is skipped if swap fields are both zero.

**Explicitly NOT for:**
- Non-card symbols - not part of the approved target universe for this build.
- Symbols outside `dwx_symbol_matrix.csv` - no verified DWX data path.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Days to months, capped at 180 D1 bars |
| Expected drawdown profile | ATR-stop bounded carry exposure; losses cluster when carry direction reverses late. |
| Regime preference | carry-direction |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1a059d6d-84fa-5d0c-94c5-86dd0481637c
**Source type:** book
**Pointer:** Robert Carver, "Leveraged Trading", Harriman House, 2019, chapter 8; companion carry spreadsheet at `https://www.systematicmoney.org/leveraged-trading-resources`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9508_carver-carrybook.md`

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
| v1 | 2026-06-20 | Initial build from card | 47c4b1a9-172d-4024-ac21-d732018ad21b |
