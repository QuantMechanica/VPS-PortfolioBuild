# QM5_11660_pp-wedge — Strategy Spec

**EA ID:** QM5_11660
**Slug:** `pp-wedge`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Author of this spec:** Codex
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

On each completed H4 bar, calculate the highest high and lowest low over the
last `strategy_window` bars. The high trend is the sign of the newest high
minus the oldest high in that window; the low trend is calculated the same
way. A PatternPy `Wedge Up` label occurs when the rolling high is at least the
prior bar's high, the rolling low is at most the prior bar's low, and both
trends are positive. A `Wedge Down` label uses the inverse envelope comparisons
and requires both trends to be negative.

Enter long at the next bar open after `Wedge Up`; enter short after `Wedge
Down`. Exit a long on `Wedge Down`, when the completed close is below the prior
bar's low, or after the configured H4 bar limit. Exit a short on `Wedge Up`,
when the completed close is above the prior bar's high, or at the same time
limit. Every position also carries a fixed multiple of ATR(14) as an emergency
stop. There is no take-profit, trailing stop, grid, martingale, or ML logic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_window` | 3 | 3–8 | Rolling OHLC window used by the source detector. |
| `strategy_atr_period` | 14 | 14–30 | ATR period for the emergency stop. |
| `strategy_sl_atr_mult` | 2.0 | 1.0–3.0 | Emergency stop distance in ATR units. |
| `strategy_max_hold_bars` | 12 | 6–30 | Maximum number of H4 bars held. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major-FX diversity sleeve.
- `GBPUSD.DWX` — liquid major-FX diversity sleeve.
- `XAUUSD.DWX` — liquid metal cross-check for pattern portability.
- `GDAXI.DWX` — DWX registry mapping for the card's GER40 target.
- `NDX.DWX` — liquid US technology-index cross-check.

**Explicitly NOT for:**

- Any symbol without one of QM5_11660's five registry slots — the EA rejects
  unregistered hosts during configuration validation.
- Timeframes below H4 — the approved baseline is structural and low-frequency.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 32 |
| Typical hold time | one to twelve H4 bars |
| Expected drawdown profile | clustered losses when short rolling trends alternate direction |
| Regime preference | directional structural trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** public open-source code
**Pointer:** `https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py`, function `detect_wedge`
**R1–R4 verdict (Q00):** all PASS; see `docs/strategy_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3%–0.5% |

Environment-to-mode validation is enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Q01 source-exact rebuild from approved card | Replaced orphan pivot/breakout implementation. |
