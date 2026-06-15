# Portfolio Buildability + FTMO Monte-Carlo — from existing backtests

**Author:** Claude (CEO analysis) · **Date:** 2026-06-15 · **Data:** Q08 full-history
trade streams (Common/Files/QM/q08_trades), Q07-depth survivors only.

## Portfolio (winning legs only — net>0, >=20 trades, FTMO-routable, no SP500)
| EA / symbol | trades | gross net | span |
|---|---|---|---|
| 10692 / NDX | 443 | +$44,424 | 2018-2025 |
| 10115 / GDAXI | 274 | +$17,110 | 2020-2024 |
| 10911 / GDAXI | 268 | +$13,226 | 2018-2025 |
| 11165 / AUDCAD | 173 | +$7,665 | 2017-2025 |
| 10815 / GDAXI | 66 | +$9,825 | 2018-2025 |
**5 legs · gross +$92,249 over 8.2 yrs (~$11.3k/yr) · maxDD -$20,686 (native RISK_FIXED sizing)**

EXCLUDED: gold legs (10038/XAU etc.) are NET-NEGATIVE full-history despite reaching Q07
(gates test specific windows; full-history re-run differs). 10440/10489/10513 NDX/XAU =
no stream emitted. So the "deep survivor nucleus" shrinks to 5 usable legs.

## FTMO Challenge Monte-Carlo (20k sims, 22-trading-day window, stationary bootstrap)
$100k acct, +10% target / -5% daily / -10% total. Sizing = native × multiplier (unknown true sizing).
| sizing | PASS | FAIL(blown) | timeout |
|---|---|---|---|
| 1.0x | 8.7% | 0.9% | 90.4% |
| 1.5x | 25.7% | 6.6% | 67.7% |
| 2.0x | 38.8% | 19.9% | 41.3% |
| 2.5x | 43.0% | 39.6% | 17.3% |
| 3.0x | 44.7% | 48.1% | 7.2% |

**Reframe:** modern FTMO has NO 30-day limit → "timeout" = keep trading, not a fail. Of
*resolved* challenges: at 1.5x sizing ~80% pass before blowing (25.7 vs 6.6); at 2.0x ~66%.

## BINDING CAVEATS (why this is NOT yet a live green light)
1. **GROSS of costs.** .DWX backtests apply $0 commission/$0 swap (verified). Real FTMO
   spread+commission on ~1,400 trades is UNMODELED and is the #1 uncertainty — could
   erode much of the $11k/yr edge. MUST be cost-stressed before any attempt.
2. **DAX-concentrated:** 3 of 5 legs on GDAXI = ~60% correlated exposure. Not the 4-5
   anticorrelated survivors the mission targets. A DAX regime shift hits most of the book.
3. **Thin + sizing-assumed:** only 5 legs; true position sizing (RISK_PERCENT live) must
   be calibrated, and the pass-rate is highly sizing-sensitive (the whole table above).

## Verdict
A marginal, gross-profitable portfolio CAN be assembled NOW (~25-40% FTMO pass, ~80% of
resolved challenges at conservative sizing). But it is cost-untested, DAX-concentrated,
and thin — "promising, not proven." Consistent with the 10692-alone dossier (PF 1.11,
PBO 51%). NOT a confident live deployment yet. Next: (1) inject realistic FTMO costs and
re-run; (2) add uncorrelated legs (NDX/FX/gold that survive full-history); (3) calibrate
live sizing to the DD box.

## Cost-stress addendum (2026-06-15, self-run, tools/strategy_farm/analyze_ftmo_costs.py)

Realistic FTMO costs injected as bps-of-notional round-turn (spread+commission+some swap).
Notional from the stream field where present; 10692/NDX reconstructed (median ~$10.8k —
likely UNDER-stated, so its cost is optimistic; it is the biggest +$44k leg). GDAXI legs
carry real notional ~$150-190k → costs hit them hardest.

| cost (round-turn) | gross/yr | maxDD | FTMO 2.0x PASS/FAIL (resolved%) |
|---|---|---|---|
| 0 bps (gross) | $11,254 | -$20,686 | 38.6 / 20.0 (~66% pass) |
| 2 bps | $7,997 | -$25,073 | 35.0 / 22.5 (~61%) |
| **4 bps (realistic central)** | **$4,739** | -$29,460 | **31.2 / 27.3 (~53%)** |
| 6 bps (conservative) | $1,482 | -$33,848 | 26.8 / 30.6 (~47%) |

Realistic FTMO all-in for our instruments ≈ 2-4 bps round-turn (indices: ~1.5pt spread,
$0 commission; FX AUDCAD: $6/lot + spread; swing-hold swap adds a little).

**Verdict (cost-aware):** costs are NOT a portfolio-killer here (unlike the cost-DEAD
cross-asset FX reversion study) — but at a realistic 4 bps they erode ~58% of the edge,
leaving a THIN $4.7k/yr (~4.7%/yr at this sizing) book that still passes ~53% of resolved
FTMO challenges at 2x sizing. The binding weaknesses remain DAX concentration (3/5 legs)
and thinness (5 legs), NOT costs. A live attempt is defensible-but-marginal; the real
upgrade is more uncorrelated legs, not cost reduction. Swap remains the least-modeled
component (no per-trade hold duration) — the 4-6 bps band is my allowance for it.
