# QM5_11297_cs-sma9-cross — Strategy Spec

**EA ID:** QM5_11297
**Slug:** `cs-sma9-cross`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades the close/SMA(9) reverse-cross on H1 bars. On each completed bar it
reads the last closed bar (shift 1) and the prior bar (shift 2). It goes long when
the close crosses above the 9-period SMA (close was at/below SMA on the prior bar
and above it on the last bar) and short when the close crosses below the 9-period
SMA. The SMA cross is the single trigger event; there is no additional state filter.

It holds one position per magic. The position is closed on the opposite reverse-cross
(a long closes when the close crosses back below SMA(9); a short closes when the
close crosses back above SMA(9)). The source is alert-only with no native stop, so
V5 adds a catastrophic stop at 2.0 × ATR(14) from entry. There is no take-profit;
exits are signal-driven plus the catastrophic stop. A reverse position can only open
on a later completed bar after the prior one is flat.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 9 | 5-50 | SMA period for the close cross (CryptoSignal 9-period example) |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the catastrophic stop |
| `strategy_sl_atr_mult` | 2.0 | 1.0-4.0 | Catastrophic stop distance = mult × ATR |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-50.0 | Skip entry if spread exceeds this % of stop distance (fail-open on .DWX zero spread) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; card initial basket; H1 SMA(9) cadence applies.
- `GBPUSD.DWX` — liquid FX major; card initial basket.
- `USDJPY.DWX` — liquid FX major; card initial basket.
- `XAUUSD.DWX` — gold; trends well, card initial basket; H1 close-cross applicable.
- `GDAXI.DWX` — DAX 40, ported from the card's `GER40` (GER40 is not in `dwx_symbol_matrix.csv`; GDAXI.DWX is the canonical DAX symbol).

**Explicitly NOT for:**
- `GER40.DWX` — not a canonical DWX symbol; the broker provides no tick data for it. Ported to `GDAXI.DWX`.

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
| Trades / year / symbol | `~90` |
| Typical hold time | `hours (a few H1 bars between reverse-crosses)` |
| Expected drawdown profile | `whipsaw losses in ranging regimes; trend-following payoff in directional moves` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low` (trend-following: many small losses, fewer large wins) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `forum` (GitHub repository / open-source project)
**Pointer:** `https://github.com/CryptoSignal/Crypto-Signal/blob/master/docs/config.md` (SMA informant + crossover analyzer)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11297_cs-sma9-cross.md`

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
| v1 | 2026-06-18 | Initial build from card | (uncommitted) |
