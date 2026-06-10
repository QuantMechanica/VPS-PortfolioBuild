# QM5_10134_bb-double — Strategy Spec

**EA ID:** QM5_10134
**Slug:** `bb-double`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Double Bollinger Band Breakout evaluated once per completed D1 bar. Two sets of Bollinger Bands are computed on PRICE_TYPICAL ((high + low + close) / 3) with period 20: an inner band at 1 standard deviation and an outer band at 2 standard deviations.

Enter long when the prior closed bar's close is above the inner upper band. Enter short when the prior closed bar's close is below the inner lower band. Only one position at a time.

Exit long when the prior closed bar's close falls back to or below the inner upper band (mean reversion) OR when close exceeds the outer upper band (overshoot/trend-exhaustion exit). Exit short when the prior closed bar's close rises back to or above the inner lower band OR when close drops below the outer lower band.

No explicit stop loss from the source. An emergency ATR-based stop is applied at entry (ATR period 20, multiplier 1.5) to cap catastrophic loss while keeping the band-based exits as the primary exit mechanism.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10–30 | Lookback period for both Bollinger Band sets |
| `strategy_inner_sigma` | 1.0 | 0.75–1.25 | Standard deviation multiplier for inner bands |
| `strategy_outer_sigma` | 2.0 | 1.75–2.5 | Standard deviation multiplier for outer bands |
| `strategy_allow_shorts` | true | true/false | Enable short entries (false = long-only mode for indices) |
| `strategy_emergency_atr_period` | 20 | 10–30 | ATR period for the emergency stop calculation |
| `strategy_emergency_atr_mult` | 1.5 | 1.0–3.0 | ATR multiplier for emergency stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — equity index CFD; band breakout captures trending regime; long-only variant available
- `WS30.DWX` — equity index CFD; same rationale as NDX
- `SP500.DWX` — backtest-only S&P analog; live promotion requires NDX or WS30 parallel validation
- `GDAXI.DWX` — European index; OHLC-based bands portable to DWX
- `UK100.DWX` — European index; OHLC-based bands portable to DWX
- `XAUUSD.DWX` — gold; trending volatility expansions match breakout mechanic
- `EURUSD.DWX` — major FX pair; sufficient bar history and volatility
- All other DWX FX pairs and metals in magic_numbers.csv — OHLC Bollinger rules fully portable

**Explicitly NOT for:**
- `XNGUSD.DWX` — natural gas; extreme volatility spikes may cause runaway emergency stops
- Any symbol without at least 20 D1 bars of history

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~18` |
| Typical hold time | `2–10 days` |
| Expected drawdown profile | `Moderate; whipsaw risk during choppy band-crossing periods` |
| Regime preference | `trend / volatility-breakout` |
| Win rate target (qualitative) | `low-medium (trend-following profile; large winners offset frequent small losses)` |

---

## 6. Source Citation

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Source type:** `forum`
**Pointer:** `https://raposa.trade/blog/4-simple-strategies-to-trade-bollinger-bands/` (section "Double Bollinger Band Breakout", 2021-07-21)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10134_bb-double.md`

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
| v1 | 2026-06-10 | Initial build from card | task 4bf9e63f |
