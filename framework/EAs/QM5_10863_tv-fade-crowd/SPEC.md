# QM5_10863_tv-fade-crowd - Strategy Spec

**EA ID:** QM5_10863
**Slug:** tv-fade-crowd
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA fades a fully confirmed MACD/VWMA crowd signal on each closed bar. A bullish crowd setup is MACD crossing above its signal, positive MACD histogram, and the closed bar high at or above VWMA; the EA enters short against that setup. A bearish crowd setup is MACD crossing below its signal, negative histogram, and the closed bar low at or below VWMA; the EA enters long against that setup. Entries require ADX above the threshold, Choppiness below the threshold, spread below the stop-distance fraction, flat position state, and the cooldown to be clear. Exits are the fixed TP/SL bracket set at entry from trigger-bar ATR percent and the plug stop cap, plus framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 12 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | fast+1+ | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal period. |
| `strategy_vwma_period` | 20 | 2+ | VWMA lookback using DWX tick volume. |
| `strategy_adx_period` | 14 | 1+ | ADX lookback. |
| `strategy_adx_threshold` | 22.0 | 18.0-26.0 tested | Minimum ADX allowed. |
| `strategy_chop_period` | 14 | 2+ | Choppiness Index lookback. |
| `strategy_chop_threshold` | 50.0 | 45.0-55.0 tested | Maximum CHOP allowed. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for bracket sizing. |
| `strategy_atr_sl_mult` | 1.0 | 0.8-1.2 tested | ATR percent stop multiplier. |
| `strategy_atr_tp_mult` | 1.5 | 1.2-2.0 tested | ATR percent target multiplier. |
| `strategy_plug_stop_pct` | 2.5 | 1.5-3.5 tested | Maximum fixed plug stop percentage. |
| `strategy_cooldown_bars` | 5 | 3-8 tested | Bars to wait after a closed position before another entry. |
| `strategy_max_spread_stop_fraction` | 0.15 | 0.0-1.0 | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary forex basket member.
- `GBPUSD.DWX` - Card R3 primary forex basket member.
- `XAUUSD.DWX` - Card R3 primary metals basket member.
- `NDX.DWX` - Card R3 primary index basket member.
- `GDAXI.DWX` - Verified DWX DAX custom symbol used in place of card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; normalized to `GDAXI.DWX`.
- `SP500.DWX` - Mentioned only as a later possible test target, not part of this card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified in card; fixed TP/SL bracket should usually resolve within intraday to multi-day windows. |
| Expected drawdown profile | Medium cadence contrarian strategy; main risk is fading trend continuation. |
| Regime preference | Mean-reversion / contrarian in directional but non-choppy regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `Fade The Crowd Protocol >_`, author handle `BVLabs`, accessed 2026-05-22
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10863_tv-fade-crowd.md`

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
| v1 | 2026-06-06 | Initial build from card | aec6e7b6-7483-4a52-b306-1708fcef16db |
