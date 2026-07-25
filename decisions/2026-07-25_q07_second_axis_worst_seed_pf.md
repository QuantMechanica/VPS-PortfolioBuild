# Decision: Q07 multiseed second axis — bounded variance tolerated on a strong worst seed

- Date: 2026-07-25
- Status: accepted (OWNER ratified in chat: "Bin für die ratifizierte Zweitachse!")
- Affected: `framework/scripts/q07_multiseed.py` (`evaluate_seeds`)
- Relation: Track-C criteria change per the gate-repair programme; the numeric anchors follow
  DL-082 §4 and `decisions/2026-07-25_q02_pf_floor_120_to_110.md`.

## The problem, measured

The 2026-07-25 Q07 rerun of the sealed cohort (12 book sleeves, fixed seed injector, fresh
evidence) produced four FAILs — **every one of them profitable on every seed**:

| sleeve | risk@12 | variance % | per-seed PF | worst seed |
|---|---:|---:|---|---:|
| 10919/XTIUSD | 1.00 | 28.89 | 3.02 · 3.97 · 3.18 · 3.12 · 3.15 | 3.02 |
| 12567/XAUUSD | 0.98 | 32.35 | 1.82 · 1.61 · 1.69 · 1.80 · 2.20 | 1.61 |
| 1556/XAUUSD | 0.79 | 21.20 | ~1.99–2.19 | 1.99 |
| 11421/AUDUSD | 0.47 | 20.29 | 1.16–1.36 | 1.16 |

The variance metric is **relative** (`(max−min)/mean`), so it is scale-dependent: a PF-2 sleeve
whose seeds span 1.6–2.2 breaches 20 % while a PF-1.05 sleeve with seeds 1.00–1.10 passes at
~10 %. The single-threshold gate systematically fails the strongest sleeves and passes the
marginal ones — the opposite of its intent.

## The rule (as implemented)

```
PASS  iff  every seed PF >= 1.0                       (unchanged — a losing seed always fails)
      AND  ( variance < 20%                            (primary axis, unchanged)
             OR ( min_pf >= 1.10 AND variance < 40% ) (second axis, this decision) )
```

Anchors, chosen by Claude and flagged for OWNER objection:

- **`min_pf >= 1.10`** — the ratified cost-noise hard bottom: DL-082 §4 set it, today's Q02
  decision aligned the standalone constant to it. A sleeve whose *worst* seed clears the floor
  that Q02 demands of a *median* result is robust in the sense the gate exists to certify:
  the edge survives every fill sequence; only its magnitude varies.
- **`variance < 40%`** — a dispersion guard at 2× the primary threshold. Extreme dispersion
  (a seed at 1.1 next to a seed at 8) signals fit-to-fill-sequence that no worst-seed floor
  excuses. All four observed boundary cases (20.29–32.35) sit under it with margin.

The reason string names the axis (`second_axis:...`) so evidence consumers can always
distinguish a second-axis pass from a primary one.

## Effect on the sealed cohort

All four FAILs above regrade to **PASS (second axis)**. Regrade records are written alongside
the original aggregates (the FAIL evidence is preserved, not overwritten). Unaffected: the five
primary PASSes, the INVALID cold-cache retries, and the 1567 zero-variance anomaly (its issue is
authentication, not variance).

## Guard rails

- This tolerates *bounded magnitude dispersion on a profitable base*; it does not touch the
  losing-seed rule, the trade floor, or any other gate.
- Codex review of the implementation is pending per bilateral review separation; the rule itself
  is OWNER-ratified and not subject to that review.
