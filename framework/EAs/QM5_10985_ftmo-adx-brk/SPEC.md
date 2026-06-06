# QM5_10985_ftmo-adx-brk - Strategy Spec

**EA ID:** QM5_10985
**Slug:** `ftmo-adx-brk`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H1 range breakouts after ADX compression. It requires ADX(14) to have stayed below 22 on at least 8 of the prior 12 closed H1 bars, the prior Donchian(20) range to be no wider than 2.2 * ATR(14), and the breakout candle range to be no wider than 2.5 * ATR(14). A long opens when the last closed H1 candle closes above the prior Donchian high, ADX crosses above 25 and rises, and +DI is above -DI; shorts mirror the rule below the prior Donchian low. The EA sets a 2.0R target, exits if ADX falls below 20, exits after 48 H1 bars, and trails after 1.5R by 2.0 * ATR(14) from the best closed-bar close since entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_adx_period` | 14 | >=1 | ADX and DI lookback period. |
| `strategy_atr_period` | 14 | >=1 | ATR lookback period for compression, stop, range filter, and trailing. |
| `strategy_donchian_lookback` | 20 | >=2 | Prior closed bars used for Donchian high and low. |
| `strategy_compression_window` | 12 | >=1 | Prior closed bars inspected for ADX compression. |
| `strategy_compression_min_bars` | 8 | 1-`strategy_compression_window` | Minimum bars with ADX below the compression threshold. |
| `strategy_compression_adx_max` | 22.0 | >0 | ADX value that qualifies as compression. |
| `strategy_compression_atr_mult` | 2.2 | >0 | Maximum Donchian height as a multiple of ATR. |
| `strategy_breakout_adx_level` | 25.0 | >0 | ADX level that must be crossed upward on breakout. |
| `strategy_exit_adx_level` | 20.0 | >0 | ADX level below which an open trade exits. |
| `strategy_breakout_range_atr_mult` | 2.5 | >0 | Maximum breakout candle range as a multiple of ATR. |
| `strategy_sl_atr_mult` | 1.2 | >0 | ATR stop candidate when the compression midpoint is farther away. |
| `strategy_tp_r_multiple` | 2.0 | >0 | Take-profit multiple of initial risk. |
| `strategy_trail_trigger_r` | 1.5 | >0 | Profit threshold before ATR trailing starts. |
| `strategy_trail_atr_mult` | 2.0 | >0 | ATR distance behind the best closed-bar close for trailing. |
| `strategy_max_hold_bars` | 48 | >=1 | Time exit in H1 bars. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread guard; 0 disables the extra spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with DWX data.
- `GBPUSD.DWX` - card-listed liquid FX major with DWX data.
- `XAUUSD.DWX` - card-listed metal with DWX data and volatility-expansion behavior.
- `GDAXI.DWX` - DAX custom symbol present in the DWX matrix; used as the available port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not part of the card basket and not valid substitutes for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Intraday to 48 H1 bars maximum |
| Expected drawdown profile | Breakout strategy with clustered losses during false volatility expansion |
| Regime preference | Volatility-expansion breakout after range compression |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** blog
**Pointer:** FTMO, "Top 11 Technical Indicators That Can Change Your Trading Forever", 2019, https://ftmo.com/en/blog/technical-indicators/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10985_ftmo-adx-brk.md`

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
| v1 | 2026-06-06 | Initial build from card | 05856dcc-edc8-41c2-b087-f42ea3be0968 |
