# QM5_10914_grimes-vol-comp - Strategy Spec

**EA ID:** QM5_10914
**Slug:** grimes-vol-comp
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA waits for volatility compression on H1: ATR(5) divided by ATR(60) must be below 0.75 for at least 3 of the prior 5 closed bars, and the prior 20-bar high-low range must be no wider than 1.25 times ATR(60). It enters long on the next bar when the last closed bar closes above the prior 20-bar high by at least 0.1 times ATR(14), and enters short when the last closed bar closes below the prior 20-bar low by the same ATR buffer. The initial stop is the closer of the opposite range side and 1.2 times ATR(14), with a minimum distance of 0.8 times ATR(14). At +1.5R it partially closes and then trails the remainder with a 2.0 times ATR(14) Chandelier-style stop from the best closed-bar close since entry; any position still open after 20 H1 bars is closed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_atr_period | 5 | >= 2 | Fast ATR period used in the compression ratio. |
| strategy_slow_atr_period | 60 | > fast ATR period | Slow ATR period used in compression and range-width checks. |
| strategy_entry_atr_period | 14 | >= 2 | ATR period used for breakout buffer, stop sizing, and trailing. |
| strategy_compression_lookback | 5 | >= 1 | Number of prior closed bars checked for ATR compression. |
| strategy_compression_min_bars | 3 | 1 to compression lookback | Minimum compressed bars required inside the lookback. |
| strategy_compression_ratio | 0.75 | > 0 | ATR(5) / ATR(60) threshold for compression. |
| strategy_range_lookback_bars | 20 | >= 2 | Prior closed bars defining the compression range. |
| strategy_range_atr_mult | 1.25 | > 0 | Maximum prior range width as a multiple of ATR(60). |
| strategy_breakout_atr_mult | 0.10 | >= 0 | Required close beyond the range as a multiple of ATR(14). |
| strategy_stop_atr_mult | 1.20 | > 0 | ATR stop candidate when it is closer than the opposite range side. |
| strategy_min_stop_atr_mult | 0.80 | > 0 | Minimum stop distance as a multiple of ATR(14). |
| strategy_target_r_mult | 1.50 | > 0 | R multiple for the first target partial close. |
| strategy_trail_atr_mult | 2.00 | > 0 | ATR multiple for Chandelier-style trailing after target one. |
| strategy_spread_stop_frac | 0.10 | >= 0 | Maximum spread as a fraction of stop distance. |
| strategy_time_exit_bars | 20 | > 0 | Maximum holding time in base-timeframe bars. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - Card-listed S&P 500 index exposure; valid backtest-only custom symbol.
- NDX.DWX - Card-listed Nasdaq index exposure with DWX availability.
- GDAXI.DWX - Matrix-valid DAX equivalent for the card's GER40.DWX target.
- XAUUSD.DWX - Card-listed gold exposure with DWX availability.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is registered as GDAXI.DWX.
- SPX500.DWX - Not the canonical S&P 500 custom symbol; SP500.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Intraday to 20 H1 bars |
| Expected drawdown profile | ATR-bounded breakout losses during failed volatility expansions. |
| Regime preference | volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "Volatility Compression", 2011-10-12, and "Trading Volatility Compression", 2014-05-19
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10914_grimes-vol-comp.md`

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
| v1 | 2026-06-06 | Initial build from card | 48485318-e4d2-4dcf-abf5-768a30ee59f3 |
