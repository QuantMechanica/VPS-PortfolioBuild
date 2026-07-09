# QM5_9451_demark-td-dwa-fade-h4 - Strategy Spec

**EA ID:** QM5_9451
**Slug:** `demark-td-dwa-fade-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9451_demark-td-dwa-fade-h4.md`
**Build task:** `e1c81f78-e019-400a-8c4e-9e9752df8f9d`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic
DeMark's Dynamic Weighted Average (TD-DWA) emphasizes closes from high-range bars. The EA computes a 13-bar range-weighted average on closed H4 bars:

`TD-DWA = sum(close[i] * (high[i] - low[i])) / sum(high[i] - low[i])`

Long entries require close[2] below TD-DWA[2] by at least 1.0 ATR, then close[1] closing up with a lower-tail rejection. Short entries are the mirror. A side-specific latch prevents repeated entries until price returns to the TD-DWA band. Exits occur on TD-DWA band touch or the 12-bar time stop; each entry also carries a hard ATR stop beyond the setup-bar extreme.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
| --- | ---: | --- | --- |
| `strategy_timeframe` | H4 | H4 fixed for build | Closed-bar signal timeframe |
| `strategy_dwa_period` | 13 | 8-21 | TD-DWA lookback |
| `strategy_atr_period` | 14 | 10-20 | ATR for deviation, stop and target band |
| `strategy_deviation_atr_mult` | 1.00 | 0.75-1.50 | Minimum prior-bar distance from TD-DWA |
| `strategy_reject_tail_min` | 0.30 | 0.20-0.50 | Minimum rejection tail share of setup-bar range |
| `strategy_target_band_atr` | 0.10 | 0.05-0.25 | Mean-band exit width around TD-DWA |
| `strategy_sl_atr_mult` | 0.80 | 0.50-1.20 | Hard SL beyond setup-bar extreme |
| `strategy_max_hold_bars` | 12 | 6-18 | Time stop in H4 bars |
| `strategy_spread_atr_mult` | 0.20 | 0.10-0.40 | Fail-open spread guard cap |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX` - major FX diversification
- `XAUUSD.DWX` - metal sleeve exposure with ATR-normalized mean-reversion mechanics
- `XTIUSD.DWX` - energy sleeve exposure beyond the forex basket
- `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX` - liquid index sleeves from the approved card

**Explicitly NOT for:**
- `FRA40.DWX` and `JP225.DWX` in this build - listed on the approved card but absent from `framework/registry/dwx_symbol_matrix.csv`
- Symbols outside the DWX matrix - no registered test data or magic allocation

---

## 4. Timeframe

| Aspect | Value |
| --- | --- |
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
| --- | --- |
| Trades / year / symbol | ~60 per approved card |
| Typical hold time | 1-12 H4 bars |
| Expected drawdown profile | Medium, stop distance adapts to setup ATR |
| Regime preference | Mean-reversion after H4 range-weighted deviations |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** DeMark / Perl technical analysis material as recorded on the approved card
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9451_demark-td-dwa-fade-h4.md`
**R1-R4 verdict (Q00):** all PASS on the approved card

Implementation uses structural OHLC/ATR mechanics only, with no ML, banned indicators, portfolio-gate changes, or live-trading changes.

---

## 7. Risk Model

| Phase | Risk mode | Value |
| --- | --- | --- |
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV-to-mode validation is enforced by `QM_FrameworkInit`; generated backtest setfiles use `RISK_PERCENT=0.0`, `RISK_FIXED=1000.0`, and `PORTFOLIO_WEIGHT=1.0`.

---

## Revision History
| Version | Date | Notes |
| --- | --- | --- |
| v1 | 2026-07-09 | Initial build from approved card for task e1c81f78-e019-400a-8c4e-9e9752df8f9d |
