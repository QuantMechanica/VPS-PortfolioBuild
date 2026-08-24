# Shadow Null Factory — full Factory search world — 2026-08-24

Status: canonical rollout and live shadow evaluation complete.

Authority: `decisions/2026-08-24_owner_shadow_null_full_search_world.md`

Mode: read-only census + shadow-only statistical sensitivity; never a gate,
candidate, book, deploy or live action.

## Why the 23-sleeve result was insufficient

The first Null Factory correctly compared the selected maximum with a joint
moving-block maxT null, but only inside 23 analyzed survivor sleeves. Its
winner, `QM5_10919_XTIUSD_109190001`, had annualized Sharpe `0.93740967`,
marginal empirical `p=0.0005` and 23-sleeve `maxT/FWER p=0.0275`. That answers
"best among this supplied survivor roster", not "best after the whole Factory
search".

## Full-world contract

`shadow_search_world_census.py` opens SQLite read-only, pins one explicit WAL
snapshot, reuses the canonical rebaseline frontier and freezes every sorted
`(ea_id, symbol)` identity. The list, not merely its count, is SHA-bound. The
pair universe is a conservative lower bound: internal phases, reruns and
parameter variants can only add multiplicity.

`shadow_null_factory.py --search-world-census ...` retains the observed joint
null and adds a post-hoc full-world sensitivity:

- marginal IID expansion: `1 - (1 - p_marginal)^N`;
- repeated 23-sleeve-template expansion across `ceil(N/23)` IID groups;
- Bonferroni threshold `alpha/N` and FWER bound from the empirical p estimate;
- explicit Monte Carlo resolution floor `1/(B+1)`;
- return-panel coverage and a fail-closed global decision.

IID is a sensitivity model, not a claim that Factory trials are independent.
The report also exposes the perfect-dependence template sensitivity. Missing
loser returns are never treated as zeros and never silently attested complete.

## Live preview before canonical integration

```text
frozen EA/symbol pairs: 14,639
pairs SHA-256: 6254ea5d16e33cc39283bb2ba89c437311f4631054b5e9419ebe90992af8451d
observed return panel: 23 / 14,639 = 0.157115%
selected: QM5_10919_XTIUSD_109190001
selected Sharpe: 0.93740967
marginal empirical p: 0.0005
23-sleeve maxT/FWER p: 0.0275
IID marginal full-world FWER p: 0.99933872
IID repeated-template full-world FWER p: 0.99999998
Bonferroni FWER bound from empirical p: 1.0
critical marginal p at alpha=0.05: 0.000003415534
Monte Carlo resolution floor (1,999 reps): 0.0005
minimum reps merely to resolve alpha/N: 292,779
additional reps needed: 290,780
full-world decision: SELECTION_NOT_PROVEN_ACROSS_DECLARED_SEARCH_WORLD
global null rejected: false
```

This does not say the selected sleeve has no edge. It says the current evidence
cannot distinguish its selection from luck across even the lower-bound Factory
search world. More permutations alone are insufficient for a final proof while
14,616 declared pair identities still lack a common, bound loser-inclusive
return panel.

## Verification

```text
related pytest: 41 passed
Python byte compilation: PASS
census JSON Schema parse: PASS
live preview: deterministic rerun produced the same pair count/hash and result
```

## Canonical rollout and runtime artifacts

```text
canonical commit: b3a6c1f5f (agents/board-advisor)
canonical related pytest: 41 passed
census generated_at: 2026-08-24T08:41:31.644730+00:00
census DB observation: 112,285 work items; 108,446 terminal verdicts
census artifact: D:\QM\strategy_farm\reports\shadow_research\2026-08-24_null_search_world_census.json
census bytes: 1,078,722
census SHA-256: 5c1a6774936e73d23e11fb7611a241d008abca33b2d92315bfbd833bffc7276d
report generated_at: 2026-08-24T08:41:40.481054+00:00
report artifact: D:\QM\strategy_farm\reports\shadow_research\2026-08-24_null_factory_full_search_world.json
report bytes: 14,151
report SHA-256: 219f212c31b3f2e0168768fc4f834005359fe4017d8dde2c004b2c5189751a78
```

The census artifact records the canonical code path
`C:\QM\repo\tools\strategy_farm\rebaseline_census.py`. Its identity count,
pair hash and statistical decision match the isolated deterministic preview.

No Factory process, work item, verdict, hold, queue priority, candidate, gate,
book or live surface was changed.
