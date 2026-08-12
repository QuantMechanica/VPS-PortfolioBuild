# QM5_9578_bandy-percentb-bb-mr-index — Strategy Spec

**EA ID:** QM5_9578
**Slug:** bandy-percentb-bb-mr-index
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On each completed D1 bar, the EA calculates 20-day Bollinger `%B` from closing prices. It opens one long position at the next D1 session open when `%B` is strictly below the configured entry threshold (0.0 by default) and the same close is above its 200-day simple moving average. The position carries a catastrophic stop 2.5 times ATR(14) below entry and closes when closed-bar `%B` is at least 0.5 or after seven completed D1 trading periods, whichever occurs first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | `>= 2`; P3 candidates 15/20/25 | Closing-price Bollinger lookback. |
| `strategy_bb_deviation` | 2.0 | `> 0`; P3 candidates 1.8/2.0/2.2 | Standard-deviation multiplier for the Bollinger envelope. |
| `strategy_entry_pctb` | 0.0 | `< strategy_exit_pctb`; P3 candidates -0.05/0.00/0.05 | Long entry requires closed-bar `%B` to be strictly below this value. |
| `strategy_exit_pctb` | 0.5 | `> strategy_entry_pctb`; P3 candidates 0.40/0.50/0.60 | Long exit requires closed-bar `%B` to be at least this value. |
| `strategy_regime_sma_period` | 200 | `>= 2` | Positive-regime SMA lookback; entry close must be strictly above it. |
| `strategy_atr_period` | 14 | `>= 1` | ATR lookback used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | `> 0` | Initial stop distance in ATR multiples. |
| `strategy_max_hold_days` | 7 | `>= 1` | Maximum completed D1 trading periods held before exit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — canonical S&P 500 custom-symbol alias for the source strategy's US large-cap index exposure.
- `NDX.DWX` — liquid Nasdaq 100 index proxy suitable for the same daily index mean-reversion rule.
- `WS30.DWX` — liquid Dow 30 index proxy that completes the card's portable US-index basket.

**Explicitly NOT for:**

- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` — these aliases are absent from `dwx_symbol_matrix.csv`; `SP500.DWX` is the sole canonical S&P 500 backtest symbol.
- Non-index `.DWX` symbols — the approved card is specifically an equity-index mean-reversion strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | Framework `QM_IsNewBar()` on a D1 chart; every strategy price/indicator read uses closed-bar shift 1. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Expected trade frequency | Not separately specified in card frontmatter; the stated expectation is 8 trades/year/symbol. |
| Typical hold time | Not specified in card frontmatter; hard time stop after 7 D1 trading periods. |
| Expected drawdown profile | Approximately 16% expected drawdown per card frontmatter. |
| Regime preference | Long-only index mean reversion while price remains above SMA(200). |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016  
**Source type:** book  
**Pointer:** `[[sources/bandy-quantitative-technical-analysis]]`; Howard Bandy, *Quantitative Technical Analysis* (Blue Owl Press, 2015)  
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_9578_bandy-percentb-bb-mr-index.md`.

---

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
| v1 | 2026-08-02 | Initial build from card | 0d8d21da-1f3a-4ab3-b177-d29f60d758f2 |
