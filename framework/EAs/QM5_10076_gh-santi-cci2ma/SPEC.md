# QM5_10076_gh-santi-cci2ma - Strategy Spec

**EA ID:** QM5_10076
**Slug:** `gh-santi-cci2ma`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `sources/github-mql5-stars-20`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA watches closed H1 bars for two independent signals: CCI(14, close) crossing the zero line and EMA(10, close) crossing EMA(60, close). It stores the latest direction from each signal until both states agree, then opens a market trade in that shared direction and clears both states. Long positions close when EMA(10) crosses below EMA(60); short positions close when EMA(10) crosses above EMA(60). A protective ATR stop is attached at entry because the source has no hard stop and the V5 card requires baseline safety.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_cci_period` | 14 | >= 1 | CCI lookback period applied to close price. |
| `strategy_fast_ema_period` | 10 | >= 1 and < slow EMA | Fast EMA period for entry state and exit crosses. |
| `strategy_slow_ema_period` | 60 | > fast EMA | Slow EMA period for entry state and exit crosses. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for the V5 protective stop. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiple used for the protective stop distance. |
| `strategy_max_spread_points` | 80 | 0 disables, otherwise > 0 | Blocks new trading when current spread exceeds this many points. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target forex major with OHLC-derived CCI and EMA data.
- `GBPUSD.DWX` - card target forex major with OHLC-derived CCI and EMA data.
- `XAUUSD.DWX` - card target metal CFD with OHLC-derived CCI and EMA data.
- `GDAXI.DWX` - available DWX DAX equivalent for the card's GER40 target.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated target is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Inferred: hours to days, until the opposite EMA(10/60) cross appears. |
| Expected drawdown profile | Inferred: trend-following whipsaw losses during sideways regimes, bounded by ATR protective stops. |
| Regime preference | Inferred from card concepts: trend-following with indicator confirmation. |
| Win rate target (qualitative) | Inferred: medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub source code
**Pointer:** `santiago-cruzlopez/MQL5`, `1_Expert_Advisors_EA/016_CCI_2MAVG_EA.mq5`, https://github.com/santiago-cruzlopez/MQL5/blob/master/1_Expert_Advisors_EA/016_CCI_2MAVG_EA.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10076_gh-santi-cci2ma.md`

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
| v1 | 2026-06-09 | Initial build from card | a0b49b08-f9c7-4cb0-a6bf-99103c02c105 |
