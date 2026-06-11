# QM5_12358_tmom-fut-mom — Strategy Spec

**EA ID:** QM5_12358
**Slug:** `tmom-fut-mom`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed D1 bar, the EA computes the return of the instrument over three lookback windows (20, 60, and 120 bars) and converts each return to its sign (−1, 0, or +1). The momentum score is the arithmetic mean of the three signs. The EA enters long when the score exceeds zero and enters short when the score is below zero. An open position is closed when the score reverses: a long is closed when the score falls to zero or below, and a short is closed when the score rises to zero or above. A 2× ATR(14) hard stop protects each trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_short_lookback` | 20 | 5–50 | D1 bars for short-horizon return calculation |
| `strategy_medium_lookback` | 60 | 30–120 | D1 bars for medium-horizon return calculation |
| `strategy_long_lookback` | 120 | 60–252 | D1 bars for long-horizon return calculation |
| `strategy_atr_period` | 14 | 7–28 | ATR period used to set the hard stop distance |
| `strategy_atr_sl_mult` | 2.0 | 1.0–4.0 | Multiplier applied to ATR for stop-loss placement |
| `strategy_warmup_bars` | 150 | 130–200 | Minimum D1 bars required before the first entry |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; D1 trend persistence well-documented
- `GBPUSD.DWX` — liquid major FX pair; shows multi-horizon momentum behaviour
- `USDJPY.DWX` — liquid major FX pair with distinct carry/risk regimes
- `XAUUSD.DWX` — gold CFD; strong multi-month trend behaviour
- `GDAXI.DWX` — DAX 40 index CFD; ported from card GER40.DWX (same instrument, canonical DWX name)
- `NDX.DWX` — Nasdaq 100 index CFD; strong momentum characteristics
- `WS30.DWX` — Dow 30 index CFD; correlated US large-cap momentum basket

**Explicitly NOT for:**
- `SP500.DWX` — available backtest-only; excluded from initial basket (not broker-routable for live)
- `GER40.DWX` — not a valid DWX symbol; GDAXI.DWX is the canonical equivalent

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
| Trades / year / symbol | `12` |
| Typical hold time | `days to weeks` |
| Expected drawdown profile | `periodic trend-following drawdowns in ranging markets` |
| Regime preference | `trend-following` |
| Win rate target (qualitative) | `low (large winners offset frequent small losses)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `github`
**Pointer:** `https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/futures/trend_following.py` (Strategy 10.4: Trend Following)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12358_tmom-fut-mom.md`

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
| v1 | 2026-06-11 | Initial build from card | 821f5527-5a00-4315-bd52-cb41122ac62b |
