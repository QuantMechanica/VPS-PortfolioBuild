# QM5_12373_tmom-alpha-rot — Strategy Spec

**EA ID:** QM5_12373
**Slug:** tmom-alpha-rot
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates the registered D1 index basket once per weekly rebalance bar. For each candidate symbol it computes close-to-close returns over the configured lookback and estimates Jensen alpha by ordinary least squares against the benchmark return series. It holds long exposure only when the chart symbol ranks in the top `strategy_top_n` alphas, and it closes the long when that rank is lost. A hard stop is placed at `strategy_atr_sl_mult * ATR(strategy_atr_period)` from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_lookback_returns | 60 | 5+ | Number of closed D1 returns used for OLS alpha. |
| strategy_top_n | 3 | 1-4 | Number of highest-alpha basket symbols eligible for long exposure. |
| strategy_risk_free_rate | 0.0 | 0.0 baseline | Per-bar risk-free return subtracted from symbol and benchmark returns. |
| strategy_benchmark_symbol | SP500.DWX | Registered basket symbol | Benchmark used for OLS beta and alpha. |
| strategy_alpha_positive_gate | false | true/false | Optional P3 filter requiring alpha above zero before entry. |
| strategy_atr_period | 14 | 1+ | ATR period used for the hard stop. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for the entry hard stop. |
| strategy_max_spread_points | 0.0 | >=0 | Optional live spread cap; zero disables the cap and zero DWX tester spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX — DAX 40 DWX equivalent for the card's GER40 target.
- NDX.DWX — Nasdaq 100 member of the approved index rotation basket.
- WS30.DWX — Dow 30 member of the approved index rotation basket.
- SP500.DWX — S&P 500 custom symbol and default benchmark; backtest-only for T6 routing.

**Explicitly NOT for:**
- GER40.DWX — card-stated name is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the available DAX symbol.
- Non-DWX symbols — framework backtests and registries require `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with weekly rebalance detection on D1 bar dates |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Weekly rotation holds; approximately days to weeks |
| Expected drawdown profile | Regression rotation can be unstable in short samples and is protected by a 2.0 ATR hard stop. |
| Regime preference | Relative momentum / alpha rotation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub strategy source
**Pointer:** ThewindMom/151-trading-strategies, `src/strategies/etfs/alpha_rotation.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12373_tmom-alpha-rot.md`

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
| v1 | 2026-06-18 | Initial build from card | 59c52452-44b3-417a-9ff1-f53685b31674 |
