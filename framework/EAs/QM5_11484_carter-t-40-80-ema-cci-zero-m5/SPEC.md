# QM5_11484_carter-t-40-80-ema-cci-zero-m5 - Strategy Spec

**EA ID:** QM5_11484
**Slug:** carter-t-40-80-ema-cci-zero-m5
**Source:** b3b11449-1e72-5140-917b-c35b6253f1e7 (see `sources/carter-thomas-20-forex-m5`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades the M5 Carter System #10 rule. A long entry is allowed when EMA(40) is above EMA(80) on the closed M5 bar and CCI(21) crosses up through zero from the prior closed bar to the latest closed bar. A short entry is the mirror image: EMA(40) below EMA(80) and CCI(21) crossing down through zero. Exits are fixed 12-pip stop loss and fixed 12-pip take profit, with no discretionary strategy close beyond framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 40 | 1+ | Fast EMA period for trend state |
| strategy_ema_slow_period | 80 | 1+ | Slow EMA period for trend state |
| strategy_cci_period | 21 | 1+ | CCI period for zero-cross trigger |
| strategy_sl_pips | 12 | 1-15 for P2/P3 | Fixed stop-loss distance in pips |
| strategy_tp_pips | 12 | 1+ | Fixed take-profit distance in pips |
| strategy_no_friday_entry | true | true/false | Blocks new entries on broker Friday |
| strategy_spread_cap_pips | 15.0 | 0+ | Maximum allowed spread in pips; zero modeled spread is allowed |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Carter M5 FX rule directly targets liquid major FX pairs.
- GBPUSD.DWX - Major FX pair with M5 DWX data and the same EMA/CCI mechanics.
- USDJPY.DWX - Major FX pair with M5 DWX data and pip-scaled fixed exits.
- AUDUSD.DWX - Major FX pair with M5 DWX data and portable momentum behavior.
- USDCAD.DWX - Major FX pair with M5 DWX data and portable momentum behavior.

**Explicitly NOT for:**
- SP500.DWX - The card is FX-specific, not an index CFD strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | intraday, minutes to hours |
| Expected drawdown profile | Fixed 12-pip stop should create frequent small losses in trendless M5 conditions |
| Regime preference | trend and momentum-confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b3b11449-1e72-5140-917b-c35b6253f1e7
**Source type:** self-published strategy collection
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), System #10; all R1-R4 PASS per `artifacts/cards_approved/QM5_11484_carter-t-40-80-ema-cci-zero-m5.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11484_carter-t-40-80-ema-cci-zero-m5.md`

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
| v1 | 2026-06-23 | Initial build from card | f5a016e7-0574-4697-87a2-38f5774ea061 |
