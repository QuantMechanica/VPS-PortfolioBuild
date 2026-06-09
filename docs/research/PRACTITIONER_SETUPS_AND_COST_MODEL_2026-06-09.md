# Practitioner Setups (ORB/ICT/Turnaround) + the real DXZ cost model

**Author:** Claude · **Date:** 2026-06-09 · **Status:** research brief (Edge-Quality Initiative, part 3)
**Runs:** deep-research `wakdgb7gi` (ORB/expectancy, academic-skeptic) + `wg6ga9qp9` (practitioner-tuned specs + cost), 200+ agents, adversarially verified.

## TL;DR

1. **ORB is the one academically-credible day-trading edge** (Zarattini-Aziz: ~17% win + 10R + 1% sizing = net-positive *by asymmetry*) — but headline returns are gross of spread/slippage on US stocks; transfer to our CFD universe is an assumption.
2. **ICT (Silver Bullet / Judas / Unicorn) are practitioner-grade but fully MECHANIZABLE** into testable specs (multiply-corroborated, no verified track records → model the FILTERS, treat win-rate claims as qualitative).
3. **Turnaround Tuesday is conditional, not blanket** — long-only 1-day mean-reversion gated by negative HTF trend + oversold, on equity indices.
4. **★ Cost model: Q08 is already correct; Q04 is wrong.** The real DXZ commission is **%-of-notional (~0.005% round-trip)**, not a flat $7/lot — too harsh for FX, too lenient for high-notional index/gold.
5. **Unifying money-management principle:** asymmetric R:R (≥1.5–2:1) + fixed-fractional risk makes a sub-50%/50-60%-win edge net-positive and prop-challenge-passing.

## Mechanizable specs (testable — for refining our existing ORB/ICT/sweep cards)

Common tuned pattern (the FILTERS that separate working from naive):
**HTF directional-bias gate (D1/4H PD-array) → fixed kill-zone time window → liquidity sweep → displacement → FVG/breaker entry on retest → liquidity-to-liquidity target.** Counter-bias / out-of-window setups are explicit failure modes.

- **Silver Bullet:** 3 ET kill-zones (03–04 London, **10–11 NY AM = highest prob**, 14–15 NY PM); HTF-bias gate; sweep→displacement→3-candle FVG (1–5m) entry at FVG edge or 50% CE; stop beyond FVG; target 2:1–4:1 liquidity-to-liquidity. ~7–8 params.
- **Judas Swing:** 00:00–05:00 NY (London-killzone sub-window); HARD daily bias; LTF Market-Structure-Shift; entry on PD-array retest; target prior-day high/low. Stop placement underspecified → **tune it**. ~5–6 params.
- **Unicorn:** swing-break + Breaker Block + overlapping FVG (3 simultaneous), HTF-gated; entry on breaker+FVG retest.
- **Turnaround Tuesday (conditional):** long-only, buy early-week weakness, gated by **negative HTF (quarterly) trend + oversold RSI**, 1-day hold, equity indices. (Instrument-specificity to specific indices was *refuted* — treat as "equity indices broadly", test per-symbol.)

> **DST caveat (critical for EAs):** kill-zones are fixed in **Eastern Time** → they shift ±1h in broker time (GMT+2/+3) at each US DST transition. Code as DST-aware broker-time offsets, not fixed UTC hours. (Ties to our broker-time convention.)

> **Evidence honesty:** ICT/Turnaround are blog/tutorial-grade, no verified track records — extract + test the *rules*, do not trust claimed expectancy. Let our (recalibrated, DL-071) pipeline be the judge.

## ★ The cost-model correction (highest-value, OWNER-flagged)

| | model | per-instrument truth |
|---|---|---|
| **Q08** (`live_commission.json` + CommissionModel) | ✅ `max(0.005%×notional, flat_floor)` — forex flat €5, index €5.5 | correct, research-validated (~0.005% = primary broker docs), authority OWNER 2026-06-01 worst-case{DXZ,FTMO} |
| **Q04** (`q04_walkforward.py`) | ❌ flat **$7/lot** injected EA-side | wrong in BOTH directions: too harsh for FX majors (~$5 real), **materially too lenient** for high-notional index CFDs + XAUUSD (%-of-notional ≫ $7) |

**Plus:** the MT5 tester itself applies **$0** commission to `.DWX` custom symbols (groups file keyed to broker paths the custom symbols don't match) — so the EA-side injection is the *only* cost modeled, and Q04's is the crude flat $7.

**Swaps:** asymmetric long/short, vary daily, settle 17:00 NY, **3× on Wednesday** — currently unmodeled anywhere (=$0). Material for multi-day-hold edges (ORB is intraday → swap ~irrelevant; Turnaround Tuesday / structural holds → matters).

## Recommended fix (OWNER decision — touches the hard-bounded cost model + re-runs Q04)

**Unify Q04's commission to Q08's `CommissionModel`** (the real %-of-notional `max(pct×notional, flat)`), replacing the flat $7/lot. Scope/caveats:
1. Q04 applies commission **EA-side** (injects a per-lot value into the setfile; the EA computes pf_net). So the fix is a **framework change** — the EA commission logic must become **notional-based** (per-trade `0.005%×notional`, with the flat floor), not flat-per-lot. Touches `QM_Common.mqh` / the commission-injection path.
2. It requires a **Q04 re-run** (not a free re-grade) — the per-fold pf_net changes.
3. It **shifts Q04 verdicts**, incl. the DL-071 re-grades: index/gold edges get *harsher* (correctly), FX edges *gentler*. Net effect per EA depends on its instrument + notional.
4. Values are NOT invented — they exist in `live_commission.json` (OWNER 2026-06-01 authority); no Hard-Rule violation.
5. Optional same change: add the asymmetric daily **swap** to the model for multi-day-hold edges (or explicitly waive for intraday).

This is the single most impactful cost-integrity fix: every index/gold EA's Q04 cost is currently understated. Recommend ratifying as a DL + implementing the EA-side notional commission, then re-running Q04 for the affected cohort.
