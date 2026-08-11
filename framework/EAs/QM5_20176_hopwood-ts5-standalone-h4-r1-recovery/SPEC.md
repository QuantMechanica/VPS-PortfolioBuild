# QM5_20176_hopwood-ts5-standalone-h4-r1-recovery — Strategy Spec

**EA ID:** QM5_20176
**Slug:** `hopwood-ts5-standalone-h4-r1-recovery`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Hopwood Trading System 5 (TS5) is the "fresh-cross-introduction" iteration of the
Hopwood TS-series trend stack, traded on the close of each H4 bar. It combines a
three-indicator directional consensus with a daily-timeframe regime filter and a
freshness gate that keeps the EA out of trends it already missed.

All checks read the last CLOSED H4 bar (shift = 1).

**Long entry** — all must hold on the closed bar:
1. DMI(14): +DI > -DI on the closed bar, AND the +DI/-DI up-cross occurred within
   the last `fresh_cross_window` (default 3) closed bars (TS5-distinguishing
   fresh-cross gate — an older cross is treated as a stale trend).
2. MACD(12,26,9) histogram (main - signal) > 0 on the closed bar.
3. Close of the closed bar > HHV(20) measured over the prior-bar window
   (Donchian-upper breach, shifts 2..21).
4. D1 regime: EMA(200,D1) rising — EMA(200,D1)[1] > EMA(200,D1)[1+5] — AND the last
   closed D1 close is above EMA(200,D1)[1].
5. No same-direction entry within the last `cooldown_bars` (default 4) H4 bars.

**Short entry** — the exact mirror (-DI > +DI with a fresh down-cross, MACD
histogram < 0, close < LLV(20) prior-bar window, EMA(200,D1) falling and D1 close
below EMA(200,D1)[1], cooldown satisfied).

**Entry order:** market buy at Ask / market sell at Bid. Initial stop =
`entry ± 2.5 × ATR(14)` via `QM_StopATR`. No fixed take-profit (`tp = 0`); the trade
is managed out by the trailing logic below.

**Spread filter:** skip the entry if `spread > 0.3 × ATR(14)`. A zero/undefined
spread never blocks (no fail-closed).

**Exit / management** (per tick while a position is open):
- **Opposite full-stack flip:** if the complete opposite stack fires (all four
  legs — DMI+fresh-cross, MACD sign, Donchian breach, D1 regime), close the
  position immediately at market. Partial flips do NOT close.
- **2-stage trailing stop:**
  - Stage 1 (profit < `1.5 × ATR(14)`): ATR trail at `2.5 × ATR(14)` via
    `QM_TM_TrailATR`.
  - Stage 2 (profit ≥ `1.5 × ATR(14)`): switch to a Parabolic SAR(0.02, 0.2) trail;
    move the stop to the closed-bar SAR level only when it improves (tightens) the
    current stop.
- The fresh-cross gate applies at entry only, never as a continuous exit
  (per Hopwood's TS5 rationale — freshness keeps us out of late entries, it does
  not chop us out of winners).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `dmi_period` | 14 | 10-20 | DMI/ADX period for the +DI/-DI cross |
| `fresh_cross_window` | 3 | 2-4 | Max age (closed bars) of the +DI/-DI cross for a fresh signal |
| `macd_fast` | 12 | 8-16 | MACD fast EMA period |
| `macd_slow` | 26 | 21-32 | MACD slow EMA period |
| `macd_signal` | 9 | 5-12 | MACD signal EMA period |
| `donchian_period` | 20 | 15-25 | Donchian HHV/LLV channel length |
| `d1_ema_period` | 200 | 100-250 | D1 regime EMA period |
| `d1_slope_lookback` | 5 | 3-8 | D1 bars back for the EMA-slope sign |
| `atr_period` | 14 | 10-20 | ATR period for the stop and trail |
| `sl_atr_mult` | 2.5 | 2.0-3.0 | Initial stop distance in ATR multiples |
| `trail_activate_atr_mult` | 1.5 | 1.0-2.5 | Profit (in ATR) to switch from ATR to PSAR trail |
| `psar_step` | 0.02 | 0.01-0.05 | Parabolic SAR acceleration step |
| `psar_max` | 0.2 | 0.1-0.4 | Parabolic SAR max acceleration |
| `spread_atr_mult_cap` | 0.3 | 0.1-0.6 | Skip entry when spread exceeds this × ATR |
| `cooldown_bars` | 4 | 0-10 | No same-direction re-entry within N H4 bars |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; original Hopwood habitat with clean H4 trends.
- `GBPUSD.DWX` — liquid FX major with pronounced trend legs suited to the stack.
- `USDJPY.DWX` — trending FX major; carry-driven directional persistence fits TS5.
- `XAUUSD.DWX` — strongly trending metal; the ATR/PSAR trail handles its wide ranges.
- `NDX.DWX` — index CFD with durable directional regimes; also the broker-routable
  parallel-validation proxy for SP500-family backtests.
- `WS30.DWX` — Dow index CFD; trending, and a second broker-routable index proxy.

**Explicitly NOT for:**
- Low-liquidity / wide-spread exotics — the `0.3 × ATR` spread cap starves entries
  and the fresh-cross gate is too selective to overcome persistent slippage.
- Sub-H4 intraday timeframes — the stack is calibrated for H4 swing cadence and
  would over-trade / whipsaw at M-series resolution.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` EMA(200) regime (slope + close) — read via `QM_EMA(..., PERIOD_D1, ...)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~4` |
| Typical hold time | `several days to a few weeks (H4 swing)` |
| Expected drawdown profile | `~20% peak-to-trough; concentrated losses during range/chop when the stack whipsaws` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low-to-medium (trend-following: many small stops, few large runners)` |

This is a deliberately **low-frequency confluence strategy**: entry requires four
independent trend legs plus a fresh DMI cross plus a D1 regime agreement to align
simultaneously, so signals are rare (~4 per year per symbol). Downstream gates
(Q02 rate-floor, Q04) should calibrate to this low cadence — a small absolute trade
count over a multi-year window is expected and by design, not a defect. Single-year
smoke tests may legitimately produce very few or zero trades.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` — Steve Hopwood, ForexFactory Trading-Systems archive, TS5-dedicated thread (the "Steve's Place" thread/254595 lineage; TS5 sits between TS4 and TS6).
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.md`

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
| v1 | 2026-08-11 | Initial build from card | R1-recovery build (recovered from QM5_1621); commit pending |
