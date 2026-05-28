# QM5_10367_et-gbs-breakout - Strategy Spec

**EA ID:** QM5_10367
**Slug:** `et-gbs-breakout`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates D1 bars for a breakout from a multi-week congestion range. A long entry is allowed when the last closed bar closes at least 0.5 ATR above the prior 20-bar range high, the prior range width is no more than 1.5 ATR, and closed-bar tick volume is at least 150% of the prior 50-bar average. A short entry mirrors the rule below the range low and requires 200% of average volume. Exits are the protective stop, target, or a 20-D1-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_congestion_bars` | 20 | 20-30 | Number of prior D1 bars used to define congestion. |
| `strategy_atr_period` | 20 | 10-50 | ATR period used for congestion width, breakout threshold, and ATR exits. |
| `strategy_congestion_atr_mult` | 1.5 | 1.0-2.0 | Maximum congestion range width as ATR multiple. |
| `strategy_breakout_atr_mult` | 0.5 | 0.25-0.75 | Minimum close beyond support/resistance as ATR multiple. |
| `strategy_use_volume_filter` | true | true/false | Enables source volume confirmation using closed-bar tick volume. |
| `strategy_volume_sma_bars` | 50 | 20-100 | Lookback for average tick volume. |
| `strategy_long_volume_mult` | 1.5 | 1.0-2.5 | Long breakout volume threshold. |
| `strategy_short_volume_mult` | 2.0 | 1.0-3.0 | Short breakout volume threshold. |
| `strategy_use_atr_exits` | true | true/false | Uses ATR target/stop when true, source percentage target/stop when false. |
| `strategy_target_atr_mult` | 2.0 | 1.0-4.0 | ATR profit target multiple. |
| `strategy_stop_atr_mult` | 2.5 | 1.0-4.0 | ATR stop multiple. |
| `strategy_target_pct` | 5.0 | 1.0-10.0 | Source percentage profit target when ATR exits are off. |
| `strategy_stop_pct` | 6.0 | 1.0-12.0 | Source percentage stop when ATR exits are off. |
| `strategy_max_breakout_pct` | 6.0 | 1.0-10.0 | Skips breakouts too far beyond prior resistance/support. |
| `strategy_max_hold_bars` | 20 | 5-30 | Time stop measured in D1 bars. |
| `strategy_spread_lookback_bars` | 20 | 5-60 | Closed-bar spread sample used for median spread filter. |
| `strategy_spread_median_mult` | 2.5 | 1.0-5.0 | Maximum current spread as a multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index custom symbol explicitly approved for backtest use.
- `NDX.DWX` - Nasdaq 100 index exposure in the card's US index basket.
- `WS30.DWX` - Dow 30 index exposure in the card's US index basket.
- `GDAXI.DWX` - Verified DWX DAX symbol used for the card's GER40/DAX exposure.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; mapped to verified `GDAXI.DWX`.
- `SPX500.DWX` - Not the canonical available S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | 3-12 days, capped at 20 D1 bars |
| Expected drawdown profile | Low-frequency breakout system with gap and false-breakout risk. |
| Regime preference | breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/gbs-trading-system.141815/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10367_et-gbs-breakout.md`

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
| v1 | 2026-05-25 | Initial build from card | 1580c496-b946-4a7c-a3ca-89b13da400df |
