# QM5_11355_robo-psar-cci - Strategy Spec

**EA ID:** QM5_11355
**Slug:** robo-psar-cci
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades M5 forex momentum in the direction confirmed by Parabolic SAR, EMA21, EMA50, and CCI(45). A long entry is allowed on a newly closed M5 bar when PSAR is below the closed-bar close, price is above both EMA21 and EMA50, and CCI(45) is above 100. A short entry is the mirror: PSAR above the close, price below both EMAs, and CCI(45) below -100. The initial stop is the EMA21 level capped at 15 pips from entry, with a fixed 10-pip take-profit for P2.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 21 | 1+ | EMA used for dynamic stop and trend confirmation. |
| `strategy_ema_slow_period` | 50 | 1+ | Slower EMA trend confirmation. |
| `strategy_cci_period` | 45 | 2+ | CCI momentum filter period from the card. |
| `strategy_cci_threshold` | 100.0 | >0 | Absolute CCI impulse threshold for long and short entries. |
| `strategy_psar_step` | 0.02 | >0 | Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | 0.20 | >0 | Parabolic SAR maximum acceleration. |
| `strategy_psar_warmup_bars` | 120 | 20+ | Closed M5 bars used to reconstruct PSAR state once per entry bar. |
| `strategy_tp_pips` | 10.0 | >0 | Fixed P2 take-profit in pips. |
| `strategy_max_stop_pips` | 15.0 | >0 | Maximum EMA21 stop distance in pips. |
| `strategy_spread_cap_pips` | 3.0 | >0 | Maximum allowed spread in pips. |
| `strategy_session_start_gmt` | 13 | 0-23 | London plus New York session start hour in GMT. |
| `strategy_session_end_gmt` | 22 | 0-23 | London plus New York session end hour in GMT. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card names EURUSD and gives the 10-pip P2 take-profit baseline.
- `AUDUSD.DWX` - Card names AUDUSD as a liquid DWX forex pair for the same M5 scalp.
- `GBPUSD.DWX` - Card names GBPUSD as a liquid DWX forex pair for the same M5 scalp.

**Explicitly NOT for:**
- `SP500.DWX` - This card is a forex scalp, not an equity index strategy.
- `XAUUSD.DWX` - This card does not specify metal spread or stop behaviour.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none in P2 implementation; the card adapts the source M1/M5 idea to M5 for DWX data availability |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 600 |
| Typical hold time | Minutes to under one session, governed by 10-pip TP or EMA21 stop |
| Expected drawdown profile | Frequent small losses during choppy M5 sessions, capped by 15-pip maximum stop |
| Regime preference | Trend-following impulse scalp |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** local PDF
**Pointer:** RoboForex, "Strategy Scalping with use of Parabolic SAR + CCI", local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11355_robo-psar-cci.md`

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
| v1 | 2026-06-08 | Initial build from card | c4aff33d-2014-46b6-a35a-9b80d22ac3d6 |
