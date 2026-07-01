# QM5_9401_demark-tdprl-fade-h4 - Strategy Spec

**EA ID:** QM5_9401
**Slug:** `demark-tdprl-fade-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

This EA mechanises the DeMark TD Predicted Range fade from the approved card. On H4 closed bars it computes the next bar's predicted range from the previous closed H4 bar:

- If prior close > prior open: `X = (2*H + L + C) / 4`
- If prior close < prior open: `X = (H + 2*L + C) / 4`
- If prior close = prior open: `X = (H + L + 2*C) / 4`
- `TDPRH = 2*X - L`
- `TDPRL = 2*X - H`

A long entry is opened on the next H4 bar when the just-closed bar penetrated `TDPRL`, closed back above `TDPRL`, closed green, and printed an upward tail at least `0.5*ATR(14)`. A short entry is opened on the mirror condition at `TDPRH`: penetration above `TDPRH`, close back below `TDPRH`, red close, and upper tail at least `0.5*ATR(14)`.

Stops are fixed from the trigger bar extreme: long stop at trigger low minus `0.3*ATR(14)`, short stop at trigger high plus `0.3*ATR(14)`. Profit target is the trigger bar `X` value. If neither SL nor TP is hit, the EA exits after 12 completed H4 bars plus the next bar open window.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_H4` | H4 only for this card | Base timeframe for TDPR trigger evaluation |
| `strategy_atr_period` | `14` | `1` to `100` | ATR lookback used for tail, spread, and stop offsets |
| `strategy_tail_atr_mult` | `0.50` | `> 0` | Minimum reversal tail size as a fraction of ATR |
| `strategy_stop_atr_mult` | `0.30` | `> 0` | Stop offset beyond trigger low or high |
| `strategy_spread_atr_mult` | `0.20` | `> 0` | Maximum positive spread as a fraction of ATR |
| `strategy_time_stop_bars` | `12` | `1` to `100` | Number of closed H4 bars to hold before time-stop exit |
| `strategy_sunday_open_hour_broker` | `22` | `0` to `23` | Sunday broker hour before which new entries are suppressed |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` - card-listed liquid FX major
- `GBPUSD.DWX` - card-listed liquid FX major
- `USDJPY.DWX` - card-listed liquid FX major
- `AUDUSD.DWX` - card-listed liquid FX major
- `USDCAD.DWX` - card-listed liquid FX major
- `USDCHF.DWX` - card-listed liquid FX major
- `NZDUSD.DWX` - card-listed liquid FX major
- `XAUUSD.DWX` - card-listed metal CFD
- `XTIUSD.DWX` - card-listed energy CFD
- `GDAXI.DWX` - card-listed index CFD present in the DWX matrix
- `NDX.DWX` - card-listed index CFD present in the DWX matrix
- `WS30.DWX` - card-listed index CFD present in the DWX matrix
- `UK100.DWX` - card-listed index CFD present in the DWX matrix

**Explicitly NOT for:**

- `FRA40.DWX` - card-listed but absent from `framework/registry/dwx_symbol_matrix.csv` on 2026-07-01
- `JP225.DWX` - card-listed but absent from `framework/registry/dwx_symbol_matrix.csv` on 2026-07-01
- Any non-`.DWX` symbol - outside V5 backtest symbol discipline

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 framework |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 60 from the approved card |
| Typical hold time | hours to a few H4 bars; hard time stop after 12 H4 bars plus the next bar open window |
| Expected drawdown profile | mean-reversion drawdown during persistent range expansions |
| Regime preference | predicted-range mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum thread with book lineage
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_9401_demark-tdprl-fade-h4.md`
**R1-R4 verdict (Q00):** all PASS in the approved card

Primary lineage cited by the approved card: Tom DeMark TD Predicted Range / TD Range Projection, Jason Perl, `DeMark Indicators`, Bloomberg Press 2008, chapter 13, and Tom DeMark, `The New Science of Technical Analysis`, Wiley 1994.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`). The generated Q02 setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from approved card | Build task `bd078fb1-d4ba-4894-ba48-08177f183132` |
