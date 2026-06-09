# QM5_10074_gh-santi-adxma - Strategy Spec

**EA ID:** QM5_10074
**Slug:** gh-santi-adxma
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades the H1 Santiago ADX EMA trend filter from the approved card. On each newly opened H1 bar it checks the last closed EMA(8) sequence, requires the previous closed bar to be above or below that EMA, and requires ADX(8) to be greater than 22 with DI aligned in the trade direction. It opens a market buy for rising EMA, price above EMA, ADX strength, and +DI above -DI; it opens a market sell for the inverse. There is no strategy close signal after entry; exits are the attached fixed stop loss and take profit plus framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 8 | > 0 | EMA period used for trend slope and price relation. |
| strategy_adx_period | 8 | > 0 | ADX period used for trend strength and DI direction. |
| strategy_adx_min | 22.0 | > 0 | Minimum ADX value required before entry. |
| strategy_stop_loss_pips | 30 | > 0 | Fixed stop-loss distance from entry. |
| strategy_take_profit_pips | 100 | > 0 | Fixed take-profit distance from entry. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid forex target with EMA and ADX data available in the DWX matrix.
- GBPUSD.DWX - card-listed liquid forex target with EMA and ADX data available in the DWX matrix.
- XAUUSD.DWX - card-listed metals target with EMA and ADX data available in the DWX matrix.
- GDAXI.DWX - canonical DWX DAX symbol used for the card's GER40.DWX target, because GER40.DWX is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- GER40.DWX - card-stated name is not in `dwx_symbol_matrix.csv`; use GDAXI.DWX for DAX exposure.
- Any symbol without an active `magic_numbers.csv` row for QM5_10074.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Expected trade frequency | not specified in card frontmatter |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | bounded by fixed SL and V5 risk framework |
| Regime preference | trend-following / trend-strength |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub source code
**Pointer:** `santiago-cruzlopez/MQL5`, `1_Expert_Advisors_EA/019_ADX_EA.mq5`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10074_gh-santi-adxma.md`

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
| v1 | 2026-06-09 | Initial build from card | 4b3dc30a-0c83-4826-ad1f-0fa1f470dbed |
