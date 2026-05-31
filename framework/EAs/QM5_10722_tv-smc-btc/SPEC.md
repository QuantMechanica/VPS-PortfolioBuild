# QM5_10722_tv-smc-btc - Strategy Spec

**EA ID:** QM5_10722
**Slug:** `tv-smc-btc`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved TradingView mechanical strategy source)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the close of an H1 bar when both H4 and H1 have recently closed beyond a confirmed swing high or swing low, using `swing_length = 10`. A long also requires the latest H1 structure to contain a bearish order-block candle, a bullish fair-value gap overlapping that order block, a sweep below a prior swing low, and an entry price inside the H4 discount threshold. A short mirrors those rules with a bullish order-block candle, bearish fair-value gap, sweep above a prior swing high, and premium-zone location. Exits are fixed at a structure stop plus a two-times-risk take profit, with Friday close handled by the framework.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_swing_length` | 10 | 2-50 | Bars on each side used to confirm swing highs and lows. |
| `strategy_structure_memory` | 5 | 1-20 | Recent closed bars allowed to contain the BOS or CHoCH structure break. |
| `strategy_ob_lookback` | 15 | 3-50 | H1 bars searched for the last opposite candle order block. |
| `strategy_sweep_memory` | 20 | 3-80 | H1 bars searched for a liquidity sweep beyond a prior swing. |
| `strategy_pd_threshold` | 0.80 | 0.0-1.0 | Literal premium/discount threshold from the card's dealing range filter. |
| `strategy_sl_buffer_pct` | 0.003 | 0.0-0.02 | Stop buffer as a fraction of entry price. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the stop-distance validity filter. |
| `strategy_min_stop_atr` | 0.50 | 0.0-10.0 | Minimum stop distance in ATR multiples. |
| `strategy_max_stop_atr` | 5.00 | 0.1-20.0 | Maximum stop distance in ATR multiples. |
| `strategy_reward_risk` | 2.00 | 0.1-10.0 | Take-profit multiple of initial risk. |
| `strategy_h1_scan_bars` | 90 | 40-250 | H1 bars copied once per closed bar for SMC structure checks. |
| `strategy_h4_scan_bars` | 90 | 40-250 | H4 bars copied once per closed bar for direction and dealing range. |
| `strategy_trade_start_hour` | 0 | 0-23 | Optional broker-hour session start; 0 with end 24 means all day. |
| `strategy_trade_end_hour` | 24 | 0-24 | Optional broker-hour session end; 24 with start 0 means all day. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional spread cap in points; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - liquid index CFD port for the source's trend/imbalance mechanics.
- `GDAXI.DWX` - canonical available DAX symbol used in place of card-stated `GER40.DWX`.
- `XAUUSD.DWX` - liquid gold CFD with OHLC structure and ATR data available.
- `EURUSD.DWX` - liquid FX major with OHLC structure and ATR data available.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated alias is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX port.
- `BTCUSDT` - source default market, but it is outside the DWX matrix and is not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | H4 direction and H4 dealing range; H1 confirmation, OB, FVG, sweep, ATR |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | Not stated in frontmatter; expected hours to several days from H1 entry with 2R fixed target. |
| Expected drawdown profile | Confluence breakout/reversal model with clustered losses during noisy range regimes. |
| Regime preference | Volatility expansion after liquidity sweep and structure break. |
| Win rate target (qualitative) | Medium; 2R target allows profitability below 50 percent win rate. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `SMC Pro BTC - ICT Order Blocks & FVG [DOE]`, author handle `DOE_Trade`, approved card at `artifacts/cards_approved/QM5_10722_tv-smc-btc.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10722_tv-smc-btc.md`

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
| v1 | 2026-05-31 | Initial build from card | ea4e1cb7-d091-45cd-8d2f-fad19dc32aca |
