# QM5_12390_paired-switch - Strategy Spec

**EA ID:** QM5_12390
**Slug:** paired-switch
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates a long-only pair switch on the first tradable D1 bar of March, June, September, and December. It compares the prior 90 calendar-day D1 close return of the chart symbol's equity or index leg against `XAUUSD.DWX`; when the chart symbol is `XAUUSD.DWX`, it compares gold against the default equity leg `SP500.DWX`. The EA holds the chart symbol long only when that chart symbol is the winning leg, stays flat when the other leg wins, and closes any existing position at the next quarterly comparison if the chart leg no longer wins. Entries use a 3.0 * ATR(20, D1) emergency stop and no profit target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_defensive_symbol` | `XAUUSD.DWX` | Registered basket symbol | Defensive/risk-off leg used in each pair comparison. |
| `strategy_default_equity_symbol` | `SP500.DWX` | Registered equity/index symbol | Equity leg used when the EA is attached to `XAUUSD.DWX`. |
| `strategy_lookback_calendar_days` | `90` | `1`-`252` | Calendar-day return lookback for the quarterly comparison. |
| `strategy_min_warmup_d1_bars` | `100` | `100`+ | Minimum D1 bars required before a comparison is valid. |
| `strategy_atr_period` | `20` | `2`-`100` | D1 ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | `3.0` | `0.1`-`10.0` | ATR multiple for the initial emergency stop. |
| `strategy_quarterly_drawdown_stop` | `true` | `true` / `false` | Enables the optional pre-rebalance 4R stop. |
| `strategy_drawdown_stop_r` | `4.0` | `0.5`-`10.0` | R-multiple loss threshold for the optional quarterly drawdown stop. |
| `strategy_spread_lookback_d1_bars` | `60` | `1`-`252` | D1 lookback used to estimate median spread for the entry spread gate. |

Framework-level risk, news, RNG, stress, and Friday-close inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 risk-on leg named in the card's primary DWX port.
- `NDX.DWX` - Nasdaq 100 alternative risk-on leg named in the card.
- `GDAXI.DWX` - Verified DWX DAX symbol used as the available port for the card's `GER40.DWX` target.
- `XAUUSD.DWX` - Defensive/risk-off leg used as the bond-to-gold proxy in the card.

**Explicitly NOT for:**
- `GER40.DWX` - Card target is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX port.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Unavailable S&P variants; `SP500.DWX` is the only approved S&P 500 custom symbol.
- `WS30.DWX`, `UK100.DWX` - Available index symbols but not part of this card's pair list.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Cross-symbol D1 reads for the paired return comparison |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; quarterly state advances once per rebalance month |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `4` |
| Typical hold time | One quarter, until the next rebalance or emergency stop |
| Expected drawdown profile | Slow rotation profile with ATR emergency stops and possible defensive-leg holds |
| Regime preference | Relative-momentum, risk-on/risk-off asset switching |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public GitHub implementation / Quantpedia strategy reference
**Pointer:** https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/paired-switching.py
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12390_paired-switch.md`

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
| v1 | 2026-06-18 | Initial build from card | bdd76c85-af8e-4d5e-905f-d150f58dbcae |
