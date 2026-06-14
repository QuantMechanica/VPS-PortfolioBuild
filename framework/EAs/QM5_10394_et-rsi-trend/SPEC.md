# QM5_10394_et-rsi-trend - Strategy Spec

**EA ID:** QM5_10394
**Slug:** `et-rsi-trend`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades the RSI regime rule from the Elite Trader source on the M15 chart. When flat, it buys on the next bar after RSI(close, 43) crosses above 50.5 and sells short on the next bar after RSI(close, 43) crosses below 49.5. Long trades exit when RSI has been above 52.5 and crosses back below 52.5; short trades exit when RSI has been below 47.0 and crosses back above 47.0. Each entry uses an initial stop at 2.0 x ATR(20) from the market entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_length` | `43` | `1-200` | RSI(close) period used for entry and exit threshold crosses. |
| `strategy_long_entry_rsi` | `50.5` | `0-100` | Long entry threshold crossed upward. |
| `strategy_short_entry_rsi` | `49.5` | `0-100` | Short entry threshold crossed downward. |
| `strategy_long_exit_rsi` | `52.5` | `0-100` | Long indicator trailing exit threshold crossed downward. |
| `strategy_short_exit_rsi` | `47.0` | `0-100` | Short indicator trailing exit threshold crossed upward. |
| `strategy_atr_period` | `20` | `1-200` | ATR period for the V5 baseline price stop. |
| `strategy_atr_sl_mult` | `2.0` | `0.1-10.0` | ATR multiplier for the initial stop. |
| `strategy_us_start_hour` | `15` | `0-23` | Broker-time regular-session start hour for SP500.DWX, NDX.DWX, and WS30.DWX. |
| `strategy_us_start_min` | `30` | `0-59` | Broker-time regular-session start minute for US index symbols. |
| `strategy_us_end_hour` | `22` | `0-23` | Broker-time regular-session end hour for US index symbols. |
| `strategy_us_end_min` | `0` | `0-59` | Broker-time regular-session end minute for US index symbols. |
| `strategy_eu_start_hour` | `9` | `0-23` | Broker-time regular-session start hour for GDAXI.DWX. |
| `strategy_eu_start_min` | `0` | `0-59` | Broker-time regular-session start minute for GDAXI.DWX. |
| `strategy_eu_end_hour` | `17` | `0-23` | Broker-time regular-session end hour for GDAXI.DWX. |
| `strategy_eu_end_min` | `30` | `0-59` | Broker-time regular-session end minute for GDAXI.DWX. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol matching the source ES/e-mini index intent; backtest-only per DWX discipline.
- `NDX.DWX` - Nasdaq 100 live-tradable US large-cap index analog.
- `WS30.DWX` - Dow 30 live-tradable US large-cap index analog.
- `GDAXI.DWX` - verified DWX DAX symbol used as the available port for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday, driven by RSI regime and indicator trailing exits. |
| Expected drawdown profile | Medium-frequency intraday trend following with whipsaw risk near RSI 50. |
| Regime preference | Trend |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/npp-builds-a-emini-system.82314/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10394_et-rsi-trend.md`

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
| v1 | 2026-06-14 | Initial build from card | 5bd95b0e-400f-407d-a5a2-582fd63b61b1 |
