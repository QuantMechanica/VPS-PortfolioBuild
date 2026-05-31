# QM5_10678_tv-tokyo-lsb - Strategy Spec

**EA ID:** QM5_10678
**Slug:** `tv-tokyo-lsb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades a Tokyo opening liquidity sweep breakout on M5 bars. Each Pakistan-time day it records the closed 05:55 PKT candle as the reference range, then checks only the closed checkpoint candles from 06:30 PKT through 08:30 PKT at 15-minute intervals. A long entry requires the checkpoint candle body and wick to be fully above the reference high; a short entry mirrors this below the reference low. The stop is placed on the opposite side of the reference range, the target is 1.5R, trades are skipped when stop distance exceeds 1.75 x ATR(14,M5), and any remaining position is closed at the configured same-day flat time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_magic_close_pkt_hhmm` | 555 | 0000-2359 | PKT close time of the M5 candle used as the magic reference range. |
| `strategy_first_checkpoint_pkt_hhmm` | 630 | 0000-2359 | First PKT checkpoint close tested for a clean breakout. |
| `strategy_final_checkpoint_pkt_hhmm` | 830 | 0000-2359 | Last PKT checkpoint close before the day becomes no-trade. |
| `strategy_checkpoint_interval_min` | 15 | 1-240 | Minutes between checkpoint tests. |
| `strategy_session_flat_pkt_hhmm` | 2355 | 0000-2359 | PKT time when an open trade is flattened if SL/TP did not hit. |
| `strategy_atr_period` | 14 | 1-200 | ATR lookback for the maximum stop-distance filter. |
| `strategy_max_stop_atr_mult` | 1.75 | 0.1-10.0 | Maximum allowed stop distance as a multiple of ATR(14,M5). |
| `strategy_rr` | 1.5 | 0.1-10.0 | Fixed reward-to-risk target. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - primary JPY market named by the card.
- `EURJPY.DWX` - JPY cross named in the R3 portable basket and present in the DWX matrix.
- `GBPJPY.DWX` - JPY cross named in the R3 portable basket and present in the DWX matrix.
- `EURUSD.DWX` - control symbol named in the R3 portable basket and present in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - the framework and registries require canonical `.DWX` backtest symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data is available for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `ATR(14,M5)` only |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Intraday; same-day flat if SL/TP does not hit. |
| Expected drawdown profile | Fixed-risk breakout losses bounded by one reference-range stop per traded day. |
| Regime preference | Tokyo session breakout / liquidity sweep. |
| Win rate target (qualitative) | Medium; payoff target is 1.5R. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/MN4tJCT5-Liquidity-Sweep-Breakout-LSB/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10678_tv-tokyo-lsb.md`

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
| v1 | 2026-05-31 | Initial build from card | f952daae-e9bc-48b4-825e-b6dea3163d39 |
