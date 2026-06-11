# QM5_12372_tmom-sector-mom - Strategy Spec

**EA ID:** QM5_12372
**Slug:** tmom-sector-mom
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (ThewindMom/151-trading-strategies, src/strategies/etfs/sector_momentum.py)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA ranks a four-symbol index basket once per weekly D1 rotation. For each symbol it computes the cumulative return over the last `strategy_lookback_returns` closed D1 return observations as `close[1] / close[lookback + 1] - 1`, then ranks the basket descending. It opens or holds long positions only for symbols ranked inside `strategy_top_n`; an open long is closed at the next weekly rotation if the symbol falls outside that band. The baseline uses a hard stop at `strategy_atr_sl_mult * ATR(strategy_atr_period)` and no take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_returns` | 12 | 6-24 | Number of closed D1 return observations used for cumulative-return ranking. |
| `strategy_top_n` | 3 | 1-3 | Number of highest-ranked symbols eligible for long exposure. |
| `strategy_positive_momentum_gate` | false | true/false | Optional P3 gate requiring the current symbol's cumulative return to be positive. |
| `strategy_min_warmup_returns` | 17 | lookback+5 or higher | Minimum completed return observations required before ranking. |
| `strategy_atr_period` | 14 | 10-30 | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | ATR multiple used for the hard stop from entry. |
| `strategy_max_spread_points` | 0.0 | 0 disables, positive points cap | Optional current-spread cap for entries. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index proxy for liquid US large-cap growth exposure.
- `WS30.DWX` - Dow 30 index proxy for liquid US large-cap value/industrial exposure.
- `SP500.DWX` - S&P 500 custom symbol, valid for backtest-only US broad-market exposure.
- `GDAXI.DWX` - DAX custom symbol used as the available DWX port for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - named by the card but absent from `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable aliases; `SP500.DWX` is the canonical S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | D1 reads across `NDX.DWX`, `WS30.DWX`, `SP500.DWX`, and `GDAXI.DWX` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; basket ranking is limited to closed D1 rebalance bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Weekly basket rotation; positions can hold multiple weeks while still top-ranked. |
| Expected drawdown profile | Correlated index drawdowns controlled by ATR hard stops and rank exits. |
| Regime preference | Cross-sectional momentum / sector rotation. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** public GitHub repository
**Pointer:** ThewindMom/151-trading-strategies, `src/strategies/etfs/sector_momentum.py`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12372_tmom-sector-mom.md`

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
| v1 | 2026-06-11 | Initial build from card | ea6785c3-6497-4b7e-b4a9-141b990e5581 |
