# P1 — The MaxDD scale contradiction resolved: the bases differ by exposure, and Sharpe is scale-invariant

## The two bases, named

Both layers use the *same* weighting method (`inverse_vol_weights`) and the *same* capital.
What differs is the **total exposure the weight vector represents**.

| | Q09 admission | DXZ book builder |
|---|---|---|
| weighting | `inverse_vol_weights` | `CAPPED_INVERSE_VOL_DAILY_PNL` |
| weight normalisation | **weights sum to 1.0** (`portfolio_kpi.py:194`) | scaled to `total_risk_pct = 9.75`, `sleeve_cap_pct = 1.0` |
| capital | `DEFAULT_STARTING_CAPITAL` (canonical) | `starting_capital = 100000.0` |
| book MaxDD observed | ~0.30 % | **2.238 %** |

So the scaled quantity is **not** the capital — it is the exposure. Admission evaluates a
*unit-exposure* book: weights summing to 1 mean the book's daily PnL is a weighted **average**
of sleeve PnLs, each from a `RISK_FIXED=1000` backtest. The builder evaluates the **deployed**
book, whose weights are scaled so total risk is 9.75 %.

## Is the sub-1 % drawdown an artefact of the unscaled basis? Yes

MaxDD scales with exposure, essentially linearly. Verified directly — scaling every daily value
by 9.75× on a fixed series:

```
weight scale  1.00x  ->  sharpe 7.013240   maxdd 0.0180%
weight scale  9.75x  ->  sharpe 7.013240   maxdd 0.1749%     (9.72x the drawdown)
```

Observed ratio between the layers: `2.2384 / 0.2982 = 7.51×` — the same regime. (Not exactly
9.75× because the two figures come from different sleeve sets: the admission number is one
candidate's `maxdd_without`, not the whole live book. The point is the order of magnitude, and
it is the exposure scaling.)

**So yes: the sub-1 % figure is the unit-exposure book, and the deployed drawdown is ~7.5×
larger.** My earlier statement that "book MaxDD is sub-1 %" was true of the number I was
holding and false as a statement about the deployed book. That is now stated correctly.

## Does DL-079's noise argument survive the rescaling? Yes — but not for the reason I gave

The argument as I restated it was "book DD is sub-1 %, therefore 0.02 pp deltas are noise".
That form does **not** survive: at deployed exposure the deltas scale up with the drawdown, so
a 0.02 pp admission delta is ~0.15 pp deployed. The absolute magnitudes were the wrong thing to
lean on.

What survives is DL-079's own **revisit condition**, which is stated relative to the constraint,
not to zero: *"If DD ever approaches the cap, revisit to allow a DD-for-Sharpe trade in that
DD-constrained regime."*

At deployed exposure the book's MaxDD is **2.24 %** against the DZ mandate's **5 % daily /
20 % total**. Roughly nine-fold headroom on the total cap. **The revisit condition is not met**,
so the rule stands — and it stands on the comparison it was actually written against rather than
on an absolute-magnitude claim that rescaling breaks.

## The finding that makes the objective choice principled

**Sharpe is exactly scale-invariant. MaxDD is not.**

In the test above, scaling every weight by 9.75× left Sharpe unchanged to six decimal places
(7.013240 → 7.013240) while MaxDD moved 9.72×. That is not a numerical accident: scaling
multiplies mean and standard deviation by the same constant, so their ratio is fixed, whereas a
drawdown percentage on a fixed capital base does not normalise away.

The consequence is stronger than "DD deltas are noisy":

> **A drawdown-based objective is basis-dependent, so it means different things at the admission
> layer and the book layer. A Sharpe-based objective means the same thing at both.**

So "does Sharpe contribution survive on the builder's scale?" — yes, necessarily and exactly.
That is now the reason to prefer it, and it is a structural reason rather than an empirical one.
P6 can fix `does not degrade book Sharpe` as the falsification criterion without waiting for
further scale work.

## What remains genuinely in tension, stated precisely

The two gates are still not the same kind of rule, and the scale analysis sharpens rather than
dissolves it:

- **Admission (DL-079)** is a *trade-off* rule: improve Sharpe, or improve MaxDD without costing
  Sharpe. It weighs one against the other.
- **The book gate (DL-084)** is a *ratchet*: `maxDD <= incumbent` **and** `return/maxDD >=
  incumbent` **and** `worst-day >= incumbent`, all three. Nothing may get worse on any leg.

A ratchet on a scale-dependent quantity is strict by construction: the DXZ proposal improves
Sharpe (2.536 → 2.568) **and** annual return (10.13 → 10.22) and is refused for a 0.032 pp
MaxDD worsening and a 0.026 worsening in return/maxDD. Under a trade-off rule it would pass;
under a ratchet it cannot.

That is a policy question for OWNER — *should the book gate be a ratchet or a trade-off?* — and
it is now separable from the scale question, which is answered. I am not changing either rule.

## Correction to my own P5 write-up

P5 framed this as "the funnel admits sleeves Sharpe-first and assembles books DD-first, so a
candidate can clear the gate that lets it in and block the gate that would deploy it", and asked
which layer owns the risk preference. That framing was too loose in one respect: the layers do
not hold *opposing preferences* — they apply a trade-off rule and a ratchet respectively, at two
exposures, and only the DD leg is basis-sensitive. The open decision is the rule *form*
(ratchet vs trade-off), not a conflict of preference.

## Evidence

- `portfolio_kpi.py:194` — inverse-vol weights normalised to sum 1.0
- `portfolio_kpi.py:126-140` — `max_drawdown_pct` on a fixed capital base
- `portfolio_manifest.py:75` — `DEFAULT_STARTING_CAPITAL`
- DXZ dry-run manifest: `weighting.total_risk_pct 9.75`, `sleeve_cap_pct 1.0`,
  `comparison.starting_capital 100000.0`, `incumbent.max_drawdown_pct 2.238353`
- scale-invariance check: Sharpe identical at 1× and 9.75×; MaxDD 9.72×
- related: `2026-08-17_P1_book_test_recompute_and_my_reversal.md`,
  `2026-08-17_P5_book_builders_executed.md`
