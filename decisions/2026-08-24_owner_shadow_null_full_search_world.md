# OWNER decision — evaluate the strongest strategy against a full null search world

Date: 2026-08-24

Authority: OWNER chat instruction to replace an isolated single-strategy
p-value with a deterministic shadow comparison against the complete Factory
search world.

## Decision

Extend the existing Shadow Null Factory without changing any gate. Before the
new evaluation, freeze every distinct `(EA, symbol)` identity in the canonical
linear-frontier census and bind the sorted list with SHA-256. Use that pair
count as a conservative *lower bound* on multiplicity: phase verdicts, reruns
and parameter trials may enlarge the true search world but may never reduce it
below one trial per observed pair.

The strongest strategy remains selected mechanically from the supplied bound
return panel. The report must preserve its marginal p-value and observed-panel
maxT result, then add:

- IID full-world and repeated-template sensitivity FWER values;
- the Bonferroni threshold for the frozen pair count;
- Monte Carlo resolution sufficiency and the minimum replication count;
- exact return-panel coverage of the frozen identities;
- a fail-closed full-world decision when loser returns or resolution are
  incomplete.

## Boundary

This is post-hoc, shadow-only research. It does not change Q08, any threshold,
verdict, queue row, candidate state, book, deployment, terminal, T_Live or
AutoTrading. A statistical sensitivity pass would still not grant gate or book
authority.

## Canonical surfaces

- `tools/strategy_farm/shadow_search_world_census.py`
- `tools/strategy_farm/shadow_null_factory.py`
- `tools/strategy_farm/config/shadow_null_search_world_census.v1.schema.json`
- `docs/ops/evidence/2026-08-24_shadow_null_full_search_world.md`
