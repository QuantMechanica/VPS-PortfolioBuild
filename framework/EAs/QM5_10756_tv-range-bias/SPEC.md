# QM5_10756_tv-range-bias - Strategy Spec

**EA ID:** QM5_10756
**Slug:** `tv-range-bias`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA builds Asia, London, and New York opening ranges from M15 bars. It sets a bullish bias when the London close is above the Asia high with sufficient London candle body strength, and a bearish bias when the London close is below the Asia low with the same strength rule. After the New York opening range is complete, a long entry waits for a break above the range high, a pullback toward that high, and a reclaim above it; short entries mirror the rule below the range low. Stop loss is the opposite side of the New York range, take profit is 2R, and any remaining position is forced flat at the configured session close hour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_asia_start_hour` | 0 | 0-23 | Broker-time hour where the Asia range begins. |
| `strategy_asia_end_hour` | 7 | 1-24 | Broker-time hour where the Asia range ends. |
| `strategy_london_start_hour` | 7 | 0-23 | Broker-time hour where the London bias window begins. |
| `strategy_london_end_hour` | 12 | 1-24 | Broker-time hour where the London bias window ends. |
| `strategy_ny_range_start_hour` | 13 | 0-23 | Broker-time hour where the New York opening range begins. |
| `strategy_ny_range_end_hour` | 14 | 1-24 | Broker-time hour where the New York opening range ends and entries may begin. |
| `strategy_force_flat_hour` | 21 | 0-23 | Broker-time hour for strategy forced-flat exit. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback used by the range-size filter. |
| `strategy_min_range_atr_mult` | 0.25 | 0.0-10.0 | Blocks New York ranges smaller than this ATR multiple. |
| `strategy_max_range_atr_mult` | 3.00 | 0.0-10.0 | Blocks New York ranges larger than this ATR multiple. |
| `strategy_london_body_min_ratio` | 0.55 | 0.0-1.0 | Minimum London body divided by London high-low range for directional strength. |
| `strategy_retest_tolerance_points` | 10 | 0-1000 | Price tolerance around the New York range edge for the retest. |
| `strategy_rr_target` | 2.00 | 0.1-10.0 | Full-position take-profit multiple of initial risk. |
| `strategy_one_trade_per_day` | true | true/false | Enforces the card's one-trade-per-day option for P2 baseline. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major from the approved R3 portable basket.
- `GBPUSD.DWX` - FX major from the approved R3 portable basket.
- `USDJPY.DWX` - FX major from the approved R3 portable basket.
- `XAUUSD.DWX` - DWX matrix metal equivalent for the card's bare `XAUUSD` R3 token.
- `GDAXI.DWX` - DWX matrix DAX equivalent for the card's `GER40.DWX` intent.
- `NDX.DWX` - Liquid US index CFD from the approved R3 portable basket.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - build-time registration is forbidden for non-matrix symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday, from New York breakout/retest until 2R, SL, or 21:00 broker forced-flat. |
| Expected drawdown profile | False-breakout drawdowns clustered during neutral or choppy session-overlap days. |
| Regime preference | Breakout and volatility expansion after aligned session bias. |
| Win rate target (qualitative) | Medium, with 2R winners offsetting failed retests. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView public script
**Pointer:** `https://www.tradingview.com/script/7ffHpmz6-Range-Break-v1-Session-Bias-Scale-Outs/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10756_tv-range-bias.md`

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
| v1 | 2026-06-14 | Initial build from card | c48d93f2-a5f8-4b0b-9fb5-fbb32401def8 |
