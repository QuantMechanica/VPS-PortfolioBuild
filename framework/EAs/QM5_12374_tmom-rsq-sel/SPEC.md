# QM5_12374_tmom-rsq-sel - Strategy Spec

**EA ID:** QM5_12374
**Slug:** tmom-rsq-sel
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `strategy_farm/artifacts/cards_approved/QM5_12374_tmom-rsq-sel.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA runs a long-only D1 selectivity rotation across the approved DWX index basket. Every weekly rebalance, it computes each symbol's last 60 close-to-close D1 returns, regresses those returns against benchmark returns, and ranks symbols by selectivity, defined as `1 - R2`. The EA holds a long position only when the chart symbol is ranked in the top three; it exits when the symbol falls out of that top-ranked set. A hard stop is placed at 2.0 x ATR(14) below the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_returns` | 60 | 2+ | Number of completed D1 returns used in the OLS R-squared calculation. |
| `strategy_top_n` | 3 | 1-4 | Number of highest-selectivity symbols eligible to hold long positions. |
| `strategy_rebalance_interval_d1` | 5 | 1+ | D1 bars between rotation decisions; five bars is the weekly baseline. |
| `strategy_min_warmup_returns` | 80 | 60+ | Minimum completed D1 returns required before the strategy may trade. |
| `strategy_atr_period` | 14 | 1+ | ATR period for the hard protective stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1+ | ATR multiple used to place the hard stop. |
| `strategy_use_directional_overlay` | false | true / false | Optional P3 positive-return qualifier; disabled for the P2 baseline. |
| `strategy_directional_return_bars` | 20 | 1+ | Return lookback used only when the directional overlay is enabled. |
| `strategy_benchmark_symbol` | SP500.DWX | DWX basket symbol | Benchmark return series for the R-squared regression. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - canonical DWX DAX index symbol; used as the available port for card-stated `GER40.DWX`.
- `NDX.DWX` - Nasdaq 100 exposure from the approved R3 index basket.
- `WS30.DWX` - Dow 30 exposure from the approved R3 index basket.
- `SP500.DWX` - S&P 500 custom symbol; valid for backtest registration with the documented live-routing caveat.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated symbol is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered canonical substitute.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; `SP500.DWX` is the only accepted custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gating |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Weekly rotation holds, usually several days to multiple weeks |
| Expected drawdown profile | Moderate equity swings from index rotation plus ATR hard-stop exits |
| Regime preference | Selectivity rotation across liquid index CFDs |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub source file
**Pointer:** https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/etfs/r_squared.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12374_tmom-rsq-sel.md`

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
| v1 | 2026-06-18 | Initial build from card | d0aa75aa-1360-4ef7-a8f5-1544a63360bb |
