# QM5_10097_mql5-swing-ext - Strategy Spec

**EA ID:** QM5_10097
**Slug:** mql5-swing-ext
**Source:** a120af9a-fb72-526c-bb80-d1d098a617b5
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades swing-extreme pullbacks on M5 with an H1 structure bias. On each new M5 bar it finds recent H1 and M5 swing highs and lows using three bars on both sides of the swing point. It buys when H1 structure is making higher highs and higher lows and current ask has extended below the latest M5 swing low by at least ATR(14) x 1.0; it sells when H1 structure is making lower highs and lower lows and current bid has extended above the latest M5 swing high by the same ATR amount. Stops are placed beyond the triggering M5 swing by the ATR buffer, and targets use the midpoint of the active M5 swing range as the deterministic interpretation of the card's "last high/low or midpoint" target wording.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_htf | PERIOD_H1 | valid MT5 timeframe | Higher timeframe used to determine swing-structure bias. |
| strategy_ltf | PERIOD_M5 | valid MT5 timeframe | Lower timeframe used for swing trigger points and ATR. |
| strategy_swing_bars | 3 | >= 1 | Bars on both sides required to confirm a swing high or swing low. |
| strategy_atr_period | 14 | >= 1 | ATR period used for extension threshold and stop buffer. |
| strategy_atr_multiplier | 1.0 | > 0 | ATR multiple required beyond the swing extreme and applied to the stop buffer. |
| strategy_swing_scan_bars | 180 | >= strategy_swing_bars x 2 + 10 | Number of closed bars scanned for recent swing points. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-targeted forex pair with DWX custom data available.
- XAUUSD.DWX - card-targeted gold CFD with DWX custom data available.
- GDAXI.DWX - card-targeted DAX CFD with DWX custom data available.

**Explicitly NOT for:**
- SPX500.DWX, SPY.DWX, ES.DWX - not card targets and not the canonical available S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 swing structure bias and M5 swing trigger/ATR |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday to multi-session until midpoint target, ATR-buffered stop, or Friday close. |
| Expected drawdown profile | Fixed-risk mean-reversion pullback exposure; drawdown expected during persistent directional extensions through swing extremes. |
| Regime preference | Mean-reversion pullback inside a higher-timeframe swing trend. |
| Win rate target (qualitative) | Medium to high implied by midpoint pullback target and ATR-buffered stop. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** a120af9a-fb72-526c-bb80-d1d098a617b5
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/21135
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10097_mql5-swing-ext.md`

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
| v1 | 2026-06-12 | Initial build from card | 061ff1af-1569-4786-b3c6-efbecd7dd7a6 |
