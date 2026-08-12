# QM5_9576_bandy-zscore-mr-index — Strategy Spec

**EA ID:** QM5_9576
**Slug:** `bandy-zscore-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On each completed D1 bar, the EA calculates the close's 20-day z-score as `(close - SMA(close, 20)) / StdDev(close, 20)`. It enters long at the next D1 session open when the z-score is at or below -2.0, then exits when a completed bar reaches z-score 0.0 or after 10 completed trading days. Every entry carries a catastrophic stop three times ATR(14) below its market entry price; there is no short side, profit target, trailing stop, or scale-in.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_zscore_lookback` | 20 | 15–30 | D1 SMA and standard-deviation lookback used by the z-score. |
| `strategy_entry_z` | -2.0 | fixed baseline | Enter long when the completed-bar z-score is at or below this value. |
| `strategy_exit_z` | 0.0 | -0.5–0.5 | Exit when the completed-bar z-score is at or above this value. |
| `strategy_atr_period` | 14 | fixed baseline | D1 ATR period for the catastrophic stop. |
| `strategy_atr_stop_mult` | 3.0 | fixed baseline | ATR multiple placed below the next-session market entry. |
| `strategy_time_stop_bars` | 10 | 5–15 | Maximum completed D1 trading bars held without a mean-cross exit. |
| `strategy_regime_filter_enabled` | false | false/true | Enables the card-authorized optional P3 long-trend filter. |
| `strategy_regime_sma_period` | 200 | fixed baseline | Long-trend SMA period used only when the optional regime filter is enabled. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — canonical S&P 500 custom-symbol proxy for the card's US large-cap mean-reversion premise.
- `NDX.DWX` — liquid Nasdaq 100 index proxy in the card's R3 PASS basket.
- `WS30.DWX` — liquid Dow 30 index proxy that broadens the card-authorized US index basket.

**Explicitly NOT for:**
- Non-index symbols — the approved evidence and long-only short-horizon reversion thesis are specific to broad equity indices.
- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` — these are not canonical symbols in `dwx_symbol_matrix.csv`; `SP500.DWX` is the supported S&P 500 alias.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; framework D1 calendar cadence for exits |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 10 |
| Expected trade frequency | episodic, roughly monthly per symbol |
| Typical hold time | one to 10 completed trading days |
| Expected drawdown profile | approximately 15% card-level expectation, with clustered losses during persistent index selloffs |
| Regime preference | short-horizon mean reversion in broad equity indices |
| Win rate target (qualitative) | medium to high |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book
**Pointer:** Howard Bandy, *Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trading Management*, Blue Owl Press, 2015 (ISBN 978-0-9791037-7-1); approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9576_bandy-zscore-mr-index.md`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_9576_bandy-zscore-mr-index.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-02 | Initial build from card | c23858e0-8c31-45fb-8143-f7418f8f484f |
