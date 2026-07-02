# Research Steering — Missing Sleeve Classes (2026-07-02)

**OWNER directive:** "Recherche auf fehlende Sleeves lenken! Du kannst auch recherchieren
oder Ideen entwickeln." — steer research toward the book's absent asset classes; Claude
may ideate directly.

## Why (evidence)

- Live 13-sleeve book concentration: QM5_12567 = **42.5% of weight** (XNG 23.5% + XAU 19.0%);
  XAUUSD as symbol ≈ 30%. Source: `D:\QM\reports\portfolio\manifest_d2c_13sleeve_2026-06-28.json`.
- **Absent classes:** crude/brent, silver, UK100/WS30 (as sleeves), JPY crosses beyond USDJPY,
  CHF pairs, cointegration style, calendar/seasonal style, all intraday (FTMO track).
- Q08 FAIL_SOFT admission pool is **exhausted** (19 ever → 13 deployed, rest adjudicated);
  growth must come from new orthogonal families (audit 2026-07-02).
- Commission by class (reference_commission_by_asset_class_2026-06-26): forex ~$45/rt HIGH,
  index ~$4.4, commodity ~$0.4–6.7 LOW → **index/commodity gross≈net**; FX ideas must be
  low-frequency to survive Q04.

## Lever 1 — queue steering (DONE 2026-07-02)

The pending Q02 queue already held material in every missing class, buried behind 2,041
FX-major items. **321 items boosted to the queue head** (crude 165, UK100 73, natgas 49,
silver 34), round-robin interleaved; downstream phases (Q03+), rescues, and priority_track
(T-WIN) still outrank them. Mechanism: `updated_at` epoch backdate (final claim tiebreaker
within phase rank) — NOT `priority_track`, which would have starved the rescue cascade.
⚠️ Queue mechanic discovered: `updated_at` is stored MIXED (epoch ints + ISO text) and
SQLite sorts INTEGER < TEXT → epoch rows always claim before text rows. Boost had to be
epoch-int based.

## Lever 2 — Claude idea slate (own development, mechanical + card-able)

Ranked by (portfolio fit × evidence strength × net-cost viability):

1. **XAGUSD D1 Donchian-55 trend** (silver solo — class fully absent). 55-day channel
   breakout, ADX(14)≥20 regime filter, ATR(20)×2.5 trail, ~15–30 tr/yr. Turtle family =
   maximally mechanical; silver trends violently when it goes; commodity commission ≈ free.
   Low corr expectation vs the book's MR-heavy commodity sleeves (trend vs reversion).
2. **UK100 turn-of-month** (calendar × index, both absent). Long entry close of T-2 before
   month-end, exit close of TD3 next month; UK pension-flow variant of the documented ToM
   effect. Complements (not duplicates) 12847 SP500 ToM: different index, different session,
   and 12847's PASS chain is being re-run after the Friday-close fix. MUST hold through
   weekend (card must state Friday-close=off explicitly, per the 12847 lesson).
3. **AUDJPY 10-day momentum, 5-day hold** (JPY cross, low-freq FX). Risk-on/off barometer
   momentum; ~40–60 tr/yr survives $45/rt only with multi-day holds — sized for that.
4. **XNGUSD seasonal shoulder-month MR** (natgas; needs source validation → Gemini R1).
5. **WS30/NDX 30-min opening-range breakout** (intraday index, FTMO track; blocked-soft on
   intraday MAE capture task 1d72d68a — research can precede data).
6. USDCHF weekly MR band — thin evidence, keep last.

Cards for #1–#3 to be authored via the normal card→R-gate flow (not force_build; organic
priority — the class boost gives their class the throughput anyway).

## Lever 3 — Gemini research tasks (enqueued 2026-07-02)

R1 natgas seasonality/EIA-cycle mechanics · R2 silver-specific mechanical edges (beyond
Donchian) · R3 UK100 calendar/session effects · R4 intraday index ORB parameterization for
the FTMO track. Each task demands: exact mechanical rules (no discretion), net-cost
viability per commission class, expected trade frequency, and an explicit low-correlation
argument vs the current book (momentum/MR/session mix), plus source citations.

## Interactions / guards

- Research throttle (reservoir <5) is an AUTO-creation rule; these are OWNER-directed
  manual enqueues. Build lane stays quota-governed — cards land in the reservoir and build
  when slots free; the class boost meanwhile works the ALREADY-BUILT backlog.
- Do not add more commodity-SPREAD ideas: a 15-EA XTI/XAG/XAU/XNG/WTI-BRENT spread wave is
  already queued (12825–12864) — intra-family correlated; the gap is SOLO silver/natgas/UK100
  and the style classes (calendar, intraday, low-freq JPY).
