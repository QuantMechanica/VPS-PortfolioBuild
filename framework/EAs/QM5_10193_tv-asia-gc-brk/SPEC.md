# QM5_10193_tv-asia-gc-brk - Strategy Spec

**EA ID:** QM5_10193
**Slug:** `tv-asia-gc-brk`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA records the high and low of the configured New York Asia session on each closed M5 or M15 bar. After that session ends, it trades only during the configured post-Asia window: a long can open when the last closed bar breaks above the Asia high plus the buffer and closes above EMA(200), and a short can open when the last closed bar breaks below the Asia low minus the buffer and closes below EMA(200). The Asia range must be between 0.5 and 3.0 times ATR(14), spread must be no more than 15% of the ATR stop distance, and the EA allows only one long and one short per trade day. Stops are 1.0 x ATR(14), take profit is 2.0 x ATR(14), optional ATR trailing is available for later P3 sweeps, and any open position is closed after the post-Asia window ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_broker_to_ny_offset_hours` | 7 | -12-14 | Broker time minus New York time, used for session conversion. |
| `strategy_asia_start_hour_ny` | 20 | 0-23 | New York hour where the Asia range starts. |
| `strategy_asia_end_hour_ny` | 3 | 0-23 | New York hour where the Asia range stops updating. |
| `strategy_trade_start_hour_ny` | 3 | 0-23 | New York hour where post-Asia breakout entries begin. |
| `strategy_trade_end_hour_ny` | 8 | 0-23 | New York hour where entries stop and open trades are closed. |
| `strategy_ema_period` | 200 | 1-500 | EMA period for the frozen-on trend filter. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for stops, targets, spread ratio, and range-height filter. |
| `strategy_sl_atr_mult` | 1.0 | 0.1-10.0 | Stop-loss distance in ATR multiples. |
| `strategy_tp_atr_mult` | 2.0 | 0.1-20.0 | Take-profit distance in ATR multiples. |
| `strategy_breakout_buffer_points` | 20 | 0-1000 | Points added beyond the Asia high/low before a breakout is valid. |
| `strategy_max_spread_atr_ratio` | 0.15 | 0.0-1.0 | Maximum spread as a fraction of ATR stop distance. |
| `strategy_min_range_atr_mult` | 0.5 | 0.0-10.0 | Minimum Asia range height in ATR multiples. |
| `strategy_max_range_atr_mult` | 3.0 | 0.0-20.0 | Maximum Asia range height in ATR multiples. |
| `strategy_enable_trailing` | false | true/false | Enables optional ATR trailing for P3 sweeps. |
| `strategy_trail_atr_mult` | 1.0 | 0.1-10.0 | ATR multiple used when trailing is enabled. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - primary gold market named by the card.
- `XAGUSD.DWX` - approved metals cross-check listed in card frontmatter.
- `GDAXI.DWX` - matrix-valid DAX custom symbol used for the card's `GER40.DWX` target.
- `NDX.DWX` - approved liquid index cross-check listed in card frontmatter.

**Explicitly NOT for:**
- Any symbol absent from `framework/registry/magic_numbers.csv` for `QM5_10193` - the framework magic resolver will reject it.

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
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, bounded by the post-Asia trading window |
| Expected drawdown profile | Bounded fixed-risk breakout drawdown, no grid or martingale |
| Regime preference | Volatility-expansion breakout after Asia range compression |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView Pine script`
**Pointer:** `https://www.tradingview.com/script/igbGCjKb-Asia-Range-Breakout-Scalper-GC-Gold-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10193_tv-asia-gc-brk.md`

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
| v1 | 2026-06-09 | Initial build from card | 2f656bf3-bc4a-4244-99c9-04492c83d247 |
