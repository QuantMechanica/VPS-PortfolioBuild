# QM5_11353_rbt-cci14-zone-cross-h1 — Strategy Spec

**EA ID:** QM5_11353
**Slug:** `rbt-cci14-zone-cross-h1`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (RoboForex Strategy Collection, "CCI strategy")
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

CCI(14) on PRICE_TYPICAL is used as a momentum-phase detector. The single trigger
EVENT is CCI crossing from one extreme into the opposite zone. LONG: CCI must have
been deeply oversold (≤ -150) on at least one of the bars preceding the trigger
(a STATE observed in a 5-bar lookback), and CCI then crosses up through +100
(`CCI[2] ≤ +100 AND CCI[1] > +100`) — that cross is the entry event. SHORT mirrors:
prior CCI ≥ +150 within lookback, then a fresh cross down through -100. The
prior-extreme reading is a STATE and the zone cross is the EVENT, so they never need
to coincide on a single bar (avoids the two-cross-same-bar zero-trade trap). Stop is
a fixed 20 pips, take-profit a fixed 40 pips. A momentum-fade exit closes a long if
CCI falls back below +100 (short: rises back above -100).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 14 | 7-28 | CCI period (PRICE_TYPICAL) |
| `strategy_cci_oversold` | -150 | -200..-100 | Prior-extreme STATE threshold for a long setup |
| `strategy_cci_overbought` | 150 | 100..200 | Prior-extreme STATE threshold for a short setup |
| `strategy_cci_long_zone` | 100 | 80..150 | Cross-up level that triggers a LONG entry |
| `strategy_cci_short_zone` | -100 | -150..-80 | Cross-down level that triggers a SHORT entry |
| `strategy_prior_lookback` | 5 | 3-8 | Bars before the trigger to find the prior extreme |
| `strategy_sl_pips` | 20 | 10-60 | Fixed stop distance in pips |
| `strategy_tp_pips` | 40 | 20-120 | Fixed take-profit distance in pips |
| `strategy_use_fade_exit` | true | true/false | Exit when CCI returns past the trigger zone |
| `strategy_spread_cap_pips` | 20 | 5-50 | Block only a genuinely wide spread (fail-open on 0) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; CCI extreme-zone reversals are well behaved on H1.
- `GBPUSD.DWX` — high intraday range gives the oscillator room to reach ±150 extremes.
- `USDJPY.DWX` — major with distinct momentum bursts; pip-scaling handled via pip_factor.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500.DWX) — the card scopes this to FX majors on H1; fixed-pip
  stops are FX-calibrated and would be mis-scaled on index point structures.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~80` |
| Typical hold time | `hours (intraday H1, fixed 20/40 pip exits or fade)` |
| Expected drawdown profile | `moderate; selective extreme-to-extreme reversals` |
| Regime preference | `momentum-burst / reversal after exhaustion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** `book` (institutional strategy PDF)
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\362359657-Robo-forex-strategy.pdf` (RoboForex Strategy Collection, "CCI strategy")
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11353_rbt-cci14-zone-cross-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
