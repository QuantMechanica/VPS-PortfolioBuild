# QM5_9584_ff-brv-spikebase — Strategy Spec

**EA ID:** QM5_9584
**Slug:** `ff-brv-spikebase`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-07-25

## 1. Strategy Logic

On closed M15 bars, a spike is a bar whose range exceeds 2.5 ATR and whose
body occupies at least 60% of that range. The EA records a narrow zone beside
the spike open, waits for a first retest, a continuation away, and a second
retest that closes back in the spike direction. It exits at the nearer of
1.2R or 0.8 ATR, after six M15 bars, or when a bar closes through the zone.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| strategy_atr_period | 14 | 10–20 | ATR lookback |
| strategy_spike_atr_mult | 2.5 | 2.0–3.0 | Minimum spike range in ATR |
| strategy_min_body_ratio | 0.60 | 0.50–0.75 | Minimum body/range ratio |
| strategy_zone_atr_mult | 0.20 | 0.10–0.30 | Zone width and stop buffer in ATR |
| strategy_tp_atr_mult | 0.80 | 0.6–1.2 | ATR take-profit cap |
| strategy_reward_risk | 1.20 | 1.0–1.5 | Reward/risk take-profit cap |
| strategy_max_hold_bars | 6 | 4–10 | M15 time stop |

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX spike/retest carrier
- `EURJPY.DWX` — liquid JPY cross with episodic volatility
- `GBPUSD.DWX` — liquid major FX volatility carrier
- `XAUUSD.DWX` — liquid metal with pronounced spike/base structures

**Explicitly NOT for:**
- Thin or unavailable symbols — the card requires reliable M15 tick history.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M15)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | roughly 20–50; card midpoint 30 |
| Typical hold time | up to 90 minutes |
| Expected drawdown profile | clustered around volatile spike regimes |
| Regime preference | volatility-expansion / news-driven |
| Win rate target (qualitative) | medium |

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`  
**Source type:** forum  
**Pointer:** https://www.forexfactory.com/thread/post/3322403  
**R1–R4 verdict (Q00):** all PASS; see
`artifacts/cards_approved/QM5_9584_ff-brv-spikebase.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-25 | Initial build from card | 00ad4ef7-485c-4152-b6d0-21bc7474f9fe |
