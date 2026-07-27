# Codex independent recommendation — FTMO next step

Date: 2026-07-27  
Router task: `d8e9a355-c79c-450d-95c0-a812f2089321`

## Decision

**Stop the current FTMO campaign.** The single next action is an OWNER close
decision that releases its reserved factory capacity back to the ordinary
sleeve-supply / DarwinexZero track. This is a campaign close, not a claim that a
future, independently gate-admitted FTMO book can never be proposed.

## 1. Do we have a defensible FTMO book today?

**No.** The decisive reason is that the configuration the framework can actually
run is nowhere near the required success probability: a fresh read-only execution
of `python tools/strategy_farm/portfolio/challenge_as_deployed.py` on 2026-07-27
reported **4.7% OOS** for its best five-sleeve combination at the only permitted
leverage, while the script fixes `LEVERAGES = (1.0,)`
(`tools/strategy_farm/portfolio/challenge_as_deployed.py:43`). The earlier 79.5%
number is already below the 80% target and assumes a different sizing regime
(`docs/ops/evidence/2026-07-27_ftmo_campaign_state_after_remediation.md:105-113`).

Admission evidence independently rejects the claimed book. The four manifest legs
are each recorded as `FAIL_PORTFOLIO`
(`docs/ops/evidence/2026-07-27_ftmo_campaign_state_after_remediation.md:90-93`),
and the wider qualifying-set audit says all six campaign sleeves have the same
Q09 verdict (`docs/ops/evidence/2026-07-27_sleeve_funnel_authoritative.md:159-162`).
This is not merely an uncertainty around an otherwise deployable 80% book; it is
an inadmissible book whose executable sizing produces about one pass in twenty.

## 2. What is the single next step?

**Record an OWNER decision closing this FTMO campaign and release its reserved
factory capacity to the existing sleeve-supply / DXZ queue.** Do not create a new
FTMO measurement or remediation programme as part of that close.

The release is the economically relevant action: the current supply audit has only
9 qualifying sleeves out of 189 Q08 trade streams
(`docs/ops/evidence/2026-07-27_sleeve_funnel_authoritative.md:25-34`), so scarce
tester and engineering capacity has a direct alternative use in improving the
underlying sleeve inventory. This recommendation does not invent new queue work;
it redirects capacity only through the already-governed router.

## 3. Expected payoff, and when it would be wasted

The payoff is avoided opportunity cost. Closing now avoids spending engineering
time on a common-framework sampler, recompiling four EAs, and consuming four
full-history Q08 tester runs—the minimum proposed evidence-repair programme
(`docs/ops/evidence/a5768d03_equity_export_gap_2026-07-27.md:37-42`). That work
would improve measurement but would not cure the four legs' Q09 rejection or the
1x deployed result. The released capacity instead serves the supply bottleneck
documented above.

Closing would be the wrong economic choice only if there were already a
framework-executable, independently held-out, gate-admitted configuration near
the 80% threshold whose final cheap verification was being abandoned. The current
evidence establishes the opposite: no deployable measured configuration reaches
80% (`docs/ops/evidence/2026-07-27_ftmo_campaign_state_after_remediation.md:128-132`).
A future proposal should therefore compete for capacity as a new opportunity on
fresh evidence, rather than inheriting this campaign's sunk-cost priority.

## 4. What should explicitly not be done next?

Do **not** build the equity sampler or launch the four full-history reruns next.
The current durable evidence cannot reconstruct intratrade equity
(`docs/ops/evidence/a5768d03_equity_export_gap_2026-07-27.md:6-21`), but repairing
that observation gap answers “how accurately does this rejected book fail?” before
it answers “is there an admissible book worth measuring?” That sequence has
negative expected value at a 4.7% executable baseline.

Do **not** raise risk caps, wire the fictional 4x/8x manifest sizing, or weaken any
framework guardrail to recover the historical headline. The framework's live
equity percentage cap is implemented in
`framework/include/QM/QM_RiskSizer.mqh:84-115`, and the campaign audit records the
resulting 1x constraint (`docs/ops/evidence/2026-07-27_ftmo_campaign_state_after_remediation.md:17-25`).
Changing risk governance to make an optimizer's selected book executable changes
the product and its loss distribution; it is not validation.

Do **not** buy or start another FTMO trial, repeatedly rerun deterministic
`INFRA_FAIL` rows, or prioritize fresh Q09 runs merely to rescue the campaign.
Only 2/158 valid-setfile Q08 infrastructure failures are directly transient and
at least 129/158 are deterministic without upstream changes
(`docs/ops/evidence/2026-07-27_q08_valid_setfile_infra_fail_distribution.md:24-27`).
Fresh Q09 evidence may still be appropriate in the ordinary pipeline, but it
should not retain FTMO-specific priority after campaign close.

## 5. Is the campaign worth continuing?

**No, not as a funded campaign. Stop and redirect capacity.** The expected benefit
of continued campaign-specific work is bounded by an executable estimate of 4.7%,
while the target is 80%; the next proposed measurement step has real framework,
compile, and tester cost but no mechanism for repairing admission or return speed.
The alternative use—building and qualifying sleeve supply—addresses a measured
scarcity of only 9 qualifying streams from 189 and also benefits the DXZ business
(`docs/ops/evidence/2026-07-27_sleeve_funnel_authoritative.md:25-34`).

This conclusion is based on prospective economics, not sunk cost: stop paying for
FTMO-specific information until the normal pipeline independently produces a
gate-admitted, framework-executable candidate that can plausibly clear the target.
At that point a new campaign can be evaluated on preregistered, timezone-correct,
closed-position and multi-day-aware evidence; the present campaign should not
reserve capacity while waiting for that possibility.

## Focused verification

- Read-only reproduction command:
  `python tools/strategy_farm/portfolio/challenge_as_deployed.py`
- Observed terminal summary on 2026-07-27:
  `N=5`, `IS=10.0%`, `OOS=4.7%`, `95% CI=0%..12%`, all legs `1.0x`.
- No tester, terminal, queue, set-file, EA, framework, T_Live, or AutoTrading
  state was changed while preparing this recommendation.
