# QM5_10661_tv-smc-btc-ob - Strategy Spec

**EA ID:** QM5_10661
**Slug:** tv-smc-btc-ob
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA waits for higher-timeframe structure and lower-timeframe confirmation before trading. A long requires H4 price to close above the most recent swing high, H1 price to close above the most recent H1 swing high, a recent sweep below prior H1 liquidity that closes back above it, and an H1 bullish fair-value gap overlapping the last bearish order-block candle before the move. Shorts mirror the same rules with closes below swing lows, a sweep above prior liquidity, and bearish FVG/order-block overlap. Entries are market orders on the next closed-bar evaluation; stop loss is beyond the order block plus 0.3%, and take profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_direction_tf | PERIOD_H4 | H1-D1 typical | Timeframe used for directional BOS/CHoCH bias. |
| strategy_confirmation_tf | PERIOD_H1 | M15-H4 typical | Timeframe used for confirmation, OB/FVG, and sweep checks. |
| strategy_structure_lookback | 48 | 12-200 bars | Closed bars scanned for swing structure. |
| strategy_swing_strength | 2 | 1-10 bars | Bars on each side used to mark a swing high or low. |
| strategy_ob_lookback | 24 | 3-100 bars | H1 bars scanned for the last opposing candle order block. |
| strategy_fvg_lookback | 24 | 3-100 bars | H1 bars scanned for FVG/order-block overlap. |
| strategy_sweep_memory_bars | 12 | 1-100 bars | Recent H1 bars allowed to contain the liquidity sweep. |
| strategy_sl_buffer_pct | 0.3 | 0.0-5.0 | Percent buffer beyond the order-block stop level. |
| strategy_rr | 2.0 | 0.5-10.0 | Take-profit multiple of stop distance. |
| strategy_selective_mode | false | true/false | Optional premium/discount filter; false is the aggressive baseline from the card. |
| strategy_max_spread_points | 0 | 0 or positive | Optional spread cap; 0 disables it for baseline portability. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - gold CFD from the card basket, suitable for OHLC order-block and liquidity-sweep mechanics.
- GDAXI.DWX - canonical DWX DAX symbol; used as the available matrix port for the card's GER40 exposure.
- NDX.DWX - Nasdaq index CFD from the card basket, suitable for index structure and imbalance rules.
- EURUSD.DWX - major FX pair from the card basket, suitable for OHLC-only SMC rules.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- BTCUSDT - source symbol only; crypto venue data is not required for this G0 port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H4 directional structure and H1 confirmation/entry structure |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` in framework OnTick before entry evaluation |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Not specified in frontmatter; expected to hold until 2R target, OB-buffer stop, or Friday close. |
| Expected drawdown profile | Not specified in frontmatter; fixed-risk one-position-per-magic baseline. |
| Regime preference | Structure-break and liquidity-sweep continuation after displacement. |
| Win rate target (qualitative) | Medium, with 2R target profile. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView script
**Pointer:** DOE_Trade, `SMC Pro BTC - ICT Order Blocks & FVG [DOE]`, TradingView, published 2026-02-19, https://www.tradingview.com/script/QMvHkvdQ-SMC-Pro-BTC-ICT-Order-Blocks-FVG-DOE/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10661_tv-smc-btc-ob.md`

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
| v1 | 2026-06-14 | Initial build from card | a40f68a0-c5ad-46bb-82cc-25732dd50e65 |
