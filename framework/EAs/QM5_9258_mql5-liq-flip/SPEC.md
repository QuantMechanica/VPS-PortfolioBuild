# QM5_9258_mql5-liq-flip - Strategy Spec

**EA ID:** QM5_9258
**Slug:** `mql5-liq-flip`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA scans a higher timeframe for supply and demand zones created by impulse candles. A short-side supply zone becomes a long demand zone when a later strong bullish candle closes above it; a long-side demand zone becomes a short supply zone when a later strong bearish candle closes below it. The EA enters on the next M15 bar after price retests the flipped zone and the closed confirmation bar shows bullish or bearish engulfing, pin-bar, or inside-break reversal behavior. The stop sits beyond the far edge of the traded zone plus 0.5 ATR(14), the target is the nearest opposing active zone when it is within 3R, otherwise 2R, and the EA exits early on a close beyond the traded zone or after 64 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_zone_timeframe` | `PERIOD_H1` | M15-D1 practical | Higher timeframe used to derive supply/demand zones. |
| `strategy_zone_scan_bars` | `160` | 40-500 | Maximum closed higher-timeframe bars scanned for zones and flips. |
| `strategy_zone_expiry_bars` | `96` | 1-300 | Maximum higher-timeframe bars allowed between flip and retest. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for impulse normalization and stop buffers. |
| `strategy_impulse_atr_mult` | `1.5` | 0.5-5.0 | Minimum candle range, in ATR units, for an impulse break. |
| `strategy_body_atr_mult` | `0.7` | 0.1-3.0 | Minimum candle body, in ATR units, for an impulse break. |
| `strategy_zone_pad_atr_mult` | `0.10` | 0.0-1.0 | ATR padding added around the base zone. |
| `strategy_retest_pad_atr_mult` | `0.25` | 0.0-2.0 | ATR tolerance for retesting a flipped zone. |
| `strategy_stop_atr_buffer` | `0.50` | 0.1-3.0 | ATR buffer beyond the far edge of the traded zone for SL. |
| `strategy_fallback_rr` | `2.0` | 0.5-10.0 | Fixed fallback target when no opposing zone qualifies. |
| `strategy_opposing_zone_max_rr` | `3.0` | 1.0-10.0 | Maximum RR distance for using an opposing zone target. |
| `strategy_max_hold_bars` | `64` | 1-500 | Time stop measured in current-chart bars. |
| `strategy_max_spread_pips` | `30` | 0-200 | Optional wide-spread guard; zero disables the guard. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair explicitly listed in the approved card.
- `GBPUSD.DWX` - liquid major FX pair explicitly listed in the approved card.
- `XAUUSD.DWX` - liquid gold instrument explicitly listed in the approved card.

**Explicitly NOT for:**
- Equity-index-only baskets - the approved card targets FX and gold only.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not eligible for DWX backtests.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_H1` supply/demand zone scan by default |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Up to 64 M15 bars, roughly 16 hours before time stop |
| Expected drawdown profile | ATR-buffered zone stops; one position per magic number |
| Regime preference | Reversal after liquidity-zone role flip and retest |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/21677`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9258_mql5-liq-flip.md`

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
| v1 | 2026-06-26 | Initial build from card | 15184014-2c54-48cc-aec9-c36fdb60e8b0 |
