# QM5_11411_wilder-parabolic-sar-reversal-d1 — Strategy Spec

**EA ID:** QM5_11411
**Slug:** `wilder-parabolic-sar-reversal-d1`
**Source:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b` (see `strategy-seeds/sources/0ab0a479-4a09-5ecc-bb90-6a37148fa78b/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Wilder's Parabolic SAR stop-and-reverse system, always in the market on D1.
The Parabolic SAR (acceleration factor starting at 0.02, incrementing by 0.02
on each new extreme price, capped at 0.20) is the single signal. The SAR sits
below price during an up-leg and above price during a down-leg. When the SAR
crosses to the other side of price on the close of a daily bar, the trend has
flipped: the EA closes the current position and immediately reverses into the
opposite direction. A bullish flip is detected when the SAR was above the close
on the prior closed bar and is now below the close on the just-closed bar; a
bearish flip is the mirror. The initial stop on each new entry is the SAR price
itself (capped at 100 pips from entry), and the stop trails the SAR each closed
bar in the favourable direction only — there is no fixed profit target because
the opposite-direction reverse is the exit. An optional Wilder DI(14) filter can
restrict entries to flips that agree with the dominant directional index.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sar_step` | 0.02 | 0.01-0.03 | PSAR acceleration factor start/increment |
| `strategy_sar_max` | 0.20 | 0.15-0.25 | PSAR acceleration factor maximum |
| `strategy_use_di_filter` | false | true/false | Enable optional Wilder DI(14) direction filter |
| `strategy_di_period` | 14 | 7-28 | ADX/DI period for the optional filter |
| `strategy_max_sl_pips` | 100.0 | 50-200 | Initial-stop cap distance in pips (D1 P2 cap) |
| `strategy_bootstrap_inmarket` | true | true/false | Seed first position from current SAR side (always-in-market) |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip entry if spread exceeds this % of the stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean trend legs suit a stop-and-reverse system.
- `GBPUSD.DWX` — volatile major with sustained directional swings PSAR follows well.
- `USDJPY.DWX` — strong trending behaviour on D1; reverse-on-flip captures regime turns.
- `AUDUSD.DWX` — commodity major with persistent macro trends.
- `USDCAD.DWX` — oil-linked major; multi-week trends fit the accelerating SAR.

**Explicitly NOT for:**
- Index/CFD symbols (NDX.DWX, WS30.DWX, SP500.DWX) — the card scopes this build to the five FX majors only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~30` |
| Typical hold time | `days to weeks (one trend leg)` |
| Expected drawdown profile | `whipsaw losses in ranging regimes; recovers in trends` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low (trend-following: many small losses, few large wins)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b`
**Source type:** `book`
**Pointer:** `J. Welles Wilder Jr., "New Concepts in Technical Trading Systems" (Trend Research, 1978), Section II: Parabolic Time/Price System`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11411_wilder-parabolic-sar-reversal-d1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | uncommitted |
