# QM5_10199_tv-vsa-absorb-fx - Strategy Spec

**EA ID:** QM5_10199
**Slug:** `tv-vsa-absorb-fx`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades closed M5 or M15 bars that show abnormal volume, abnormal range, and a direction flip in the card's OHLCV delta proxy. The proxy is `volume * (close - open) / max(high - low, tick_size)`, and a long requires the proxy to turn positive after a negative prior bar on a bullish candle; a short mirrors that rule. Entries are market orders with fixed SL/TP: stop is based on the signal bar low/high adjusted by 1%, capped at 3.0 * ATR(14), and target is 3.5R. The EA uses session filters, one open position per magic, and framework risk sizing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_volume_sma_period` | 20 | >= 1 | Lookback used for the prior-volume SMA. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for the range filter and stop cap. |
| `strategy_volume_multiplier` | 1.5 | > 0 | Signal bar volume must exceed prior SMA volume by this multiple. |
| `strategy_range_multiplier` | 1.0 | > 0 | Signal bar range must exceed ATR by this multiple. |
| `strategy_stop_percent` | 1.0 | > 0 | Percent adjustment beyond signal low/high for source stop. |
| `strategy_atr_stop_cap_mult` | 3.0 | > 0 | Maximum stop distance in ATR multiples. |
| `strategy_reward_r` | 3.5 | > 0 | Take-profit distance in R. |
| `strategy_max_spread_stop` | 0.15 | > 0 | Maximum spread as a fraction of stop distance. |
| `strategy_fx_session_start` | 13 | 0-23 | Broker-hour start for London/NY overlap FX entries. |
| `strategy_fx_session_end` | 17 | 0-23 | Broker-hour end for London/NY overlap FX entries. |
| `strategy_index_session_start` | 15 | 0-23 | Broker-hour start for index and gold entries. |
| `strategy_index_session_end` | 22 | 0-23 | Broker-hour end for index and gold entries. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX target for the OHLCV absorption proxy.
- `GBPUSD.DWX` - card-listed liquid FX target for the OHLCV absorption proxy.
- `XAUUSD.DWX` - card-listed gold target with tick-volume proxy support.
- `GDAXI.DWX` - registered DAX equivalent because card-listed `GER40.DWX` is not in the DWX matrix.
- `NDX.DWX` - card-listed index CFD target with tick-volume proxy support.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX`.
- Any unregistered symbol - magic resolution is defined only for the symbols above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` and `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Expected trade frequency | Frequent intraday signals on liquid sessions; card cites about 80 trades/year/symbol. |
| Typical hold time | Not specified in frontmatter; fixed SL/TP means intraday to multi-session until SL, TP, or Friday close. |
| Expected drawdown profile | Fixed $1,000 backtest risk per trade with 3.5R target and no martingale/grid. |
| Regime preference | Mean-reversion after volume-spike absorption/rejection bars. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/wPuAT5a1-VSA-with-Absorption-Proxy-for-Holmes-and-Bookmap-Style/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10199_tv-vsa-absorb-fx.md`

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
| v1 | 2026-06-09 | Initial build from card | 643cb3fa-0fb1-42c1-949a-365503e11730 |
