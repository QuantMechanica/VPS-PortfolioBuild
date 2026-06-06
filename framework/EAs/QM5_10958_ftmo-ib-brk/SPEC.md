# QM5_10958_ftmo-ib-brk - Strategy Spec

**EA ID:** QM5_10958
**Slug:** ftmo-ib-brk
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades the first valid M15 close outside the Initial Balance range. EURUSD.DWX and GBPUSD.DWX use a 09:00-10:00 CET range; NDX.DWX and WS30.DWX use a 15:30-16:30 CET range. A long entry requires the closed M15 candle to cross above the IB high, while a short entry requires a cross below the IB low. The IB width must be between 0.6 and 1.4 times H1 ATR(14); the stop is placed 0.1 IB widths beyond the opposite side of the range, final TP is 1.5 IB widths, and SL moves to breakeven after price touches 1.0 IB width in favor.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | H1 ATR period for the IB-width filter. |
| `strategy_ib_width_min_atr` | 0.6 | 0.1-5.0 | Minimum IB width as a multiple of H1 ATR. |
| `strategy_ib_width_max_atr` | 1.4 | 0.1-5.0 | Maximum IB width as a multiple of H1 ATR. |
| `strategy_sl_buffer_ib_mult` | 0.1 | 0.0-2.0 | Stop buffer beyond the opposite IB boundary. |
| `strategy_tp1_be_ib_mult` | 1.0 | 0.1-5.0 | Favorable move in IB widths before SL moves to breakeven. |
| `strategy_final_tp_ib_mult` | 1.5 | 0.1-5.0 | Final take-profit distance in IB widths. |
| `strategy_spread_stop_max_fraction` | 0.08 | 0.0-0.5 | Maximum spread as a fraction of planned stop distance. |
| `strategy_fx_ib_start_hhmm` | 900 | 0-2359 | London IB start for EURUSD.DWX and GBPUSD.DWX. |
| `strategy_fx_ib_end_hhmm` | 1000 | 0-2359 | London IB end for EURUSD.DWX and GBPUSD.DWX. |
| `strategy_fx_session_close_hhmm` | 1700 | 0-2359 | London session close used for time exit. |
| `strategy_index_ib_start_hhmm` | 1530 | 0-2359 | US IB start for NDX.DWX and WS30.DWX. |
| `strategy_index_ib_end_hhmm` | 1630 | 0-2359 | US IB end for NDX.DWX and WS30.DWX. |
| `strategy_index_session_close_hhmm` | 2200 | 0-2359 | US session close used for time exit. |
| `strategy_lookback_bars` | 96 | 16-200 | Bounded M15 scan window for finding the current day's IB bars. |
| `strategy_news_post_breakout_minutes` | 30 | 0-240 | Documents the card's post-breakout news window; central V5 high-impact news pause enforces the active block. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX symbol for the London Initial Balance.
- `GBPUSD.DWX` - card-listed FX symbol for the London Initial Balance.
- `NDX.DWX` - card-listed US index symbol for the US Initial Balance.
- `WS30.DWX` - card-listed US index symbol for the US Initial Balance.

**Explicitly NOT for:**
- `SP500.DWX` - not listed in the card's R3 P2 basket.
- `XAUUSD.DWX` - not an FX/index Initial Balance target in this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1 ATR(14)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Intraday, from breakout to session close or SL/TP. |
| Expected drawdown profile | Fixed-risk breakout losses clustered during false-breakout regimes. |
| Regime preference | Breakout / volatility expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO blog article
**Pointer:** https://ftmo.com/en/use-the-initial-balance-to-your-advantage/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10958_ftmo-ib-brk.md`

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
| v1 | 2026-06-06 | Initial build from card | 6332aeb3-95a8-4b9a-899e-d430c4e598e7 |
