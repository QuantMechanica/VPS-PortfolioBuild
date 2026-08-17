# Forgotten-family Q02 dispatch readiness — 2026-08-17

Router task: `54cac972-aef1-47fd-ac71-12403178df91`

Repository snapshot: `cb26ef6e05ee8d39066b7a906ae827941fd6902a`

Verdict: `NO_DISPATCH_REGISTRY_AND_PACKAGE_GATES_FAILED`

## Outcome

The three named families contain 15 compiled EA directories, but none is
currently enqueue-ready. Cumulative result for this cohort is **0 dispatched / 0
actionable, 15 checked and 15 withheld**. No work item or farm task was created,
no EA was rebuilt, and no terminal was started.

The prior inventory correctly found zero work items for these packages, but
“built” does not imply runnable: all 15 are absent from both deterministic
registries, all 112 setfiles omit mandatory execution bindings, and none of the
sources assigns the request symbol slot. Enqueueing any of them would knowingly
create an init failure or an unauthenticated test.

## Cohort result

| EA | Approved-card location | Setfiles | High conformance findings | Missing magic symbols | Decision |
|---|---|---:|---:|---:|---|
| QM5_3001 alpha-rubber-band | approved root; not package-bound | 8 | 8 | 8/8 | withhold |
| QM5_3002 alpha-unger-method | approved root; not package-bound | 8 | 24 | 8/8 | withhold |
| QM5_3003 alpha-quants-hook | approved root; not package-bound | 8 | 8 | 8/8 | withhold |
| QM5_3004 alpha-morning-rush | approved root; not package-bound | 8 | 24 | 8/8 | withhold |
| QM5_3005 alpha-inst-pullback | no approved card; ID was retired for R1 failure | 8 | 8 | 8/8 | withhold |
| QM5_4001 elite-multi-factor-scoring | approved root; not package-bound | 10 | 10 | 10/10 | withhold |
| QM5_4002 elite-jpy-carry-fade | approved root; not package-bound | 2 | 2 | 2/2 | withhold |
| QM5_4003 elite-gamma-proxy-reversion | approved root; not package-bound | 10 | 10 | 10/10 | withhold |
| QM5_4004 elite-vsa-liquidity-sweep | approved root; not package-bound | 10 | 10 | 10/10 | withhold |
| QM5_4005 elite-gold-mid-week-fade | no card found in any card artifact root | 1 | 3 | 1/1 | withhold |
| QM5_5001 legend-unger-breakout | approved root; not package-bound | 7 | 21 | 7/7 | withhold |
| QM5_5002 legend-davey-trend | approved root; not package-bound | 7 | 7 | 7/7 | withhold |
| QM5_5003 legend-balke-session | approved root; not package-bound | 11 | 33 | 7/7 | withhold |
| QM5_5004 legend-simons-proxy | approved root; not package-bound | 7 | 7 | 7/7 | withhold |
| QM5_5005 legend-williams-expansion | approved root; not package-bound | 7 | 7 | 7/7 | withhold |

## Gate evidence

### Card linkage

Thirteen exact-name cards exist under
`D:/QM/strategy_farm/artifacts/cards_approved/`, but none of the 15 EA packages
contains `docs/strategy_card.md`. These are legacy cards: their frontmatter has
the R1-R4 fields and OWNER lineage but no explicit `g0_status`, target-symbol
list, or timeframe. They were located, but deliberately not copied into packages
that fail the more fundamental identity and setfile gates.

`QM5_3005` is not merely missing a copy. Router task
`31bc37a1-560f-419d-8b92-d86f08eac0a2` was closed after retiring its former
approved card for `R1_FAIL`; the rejected artifact is
`QM5_3005_alpha-inst-magnet.md`, which also does not match the present
`alpha-inst-pullback` package. `QM5_4005` has no matching card in approved,
review, rejected, or other strategy-farm card roots and no prior router task.

### Deterministic identity and magic

Read-only parsing of `ea_id_registry.csv`, `magic_numbers.csv`, and the generated
resolver found:

- zero EA-ID registry rows for all 15 IDs;
- zero non-retired magic rows for all 15 IDs;
- zero generated resolver rows for all 15 IDs;
- 108 unique `(EA, setfile symbol)` pairs, all 108 missing from both the magic
  registry and resolver.

This alone is a hard stop. The current framework fails closed when it cannot
resolve the registered magic.

### Host-slot binding

Every source declares `qm_magic_slot_offset` and passes it to framework init,
but no source assigns `req.symbol_slot = qm_magic_slot_offset`. Every one of the
112 setfiles also omits `qm_magic_slot_offset`, leaving the default slot zero for
all symbols. This fails the task's host-slot-conflation check and cannot be
papered over at enqueue time.

### Risk and strategy-input binding

All 112 setfiles contain `RISK_FIXED=100.0`, which is positive, but all 112 omit
the mandatory explicit `RISK_PERCENT=0`. They also omit every declared
`strategy_*` input and the governed setfile header. A scoped
`audit_strategy_conformance.py` run produced 294 findings:

- 182 high findings;
- 112 medium findings;
- 112 `MISSING_STRATEGY_PARAMS_IN_SETFILE` findings;
- 112 `SETFILE_HEADER_INCOMPLETE` findings;
- 35 `TIME_SENSITIVE_DEFAULTS_ONLY` findings; and
- 35 `SPEC_HAS_TIMES_BUT_SETFILE_HAS_NO_STRATEGY_PARAMS` findings.

Fourteen sources reference every declared strategy input. QM5_4005 additionally
declares `strategy_atr_period` and `strategy_atr_sl_mult` without reading either.

### Directory guardrails and basket scope

`validate_build_guardrails.py` returned PASS for all 15 directories, with the
336-hour news-staleness ceiling and no findings. That does not override the
explicit task checks above: the current validator does not flag an omitted
`RISK_PERCENT` key or missing strategy-input overrides. This is evidence of a
coverage gap, not permission to weaken the required contract.

No source names a foreign `.DWX` symbol, so `basket_manifest.json` is not required
for this cohort.

### History and mutation check

A read-only query of `D:/QM/strategy_farm/state/farm_state.sqlite` found zero
farm tasks and zero work items for all 15 IDs. The only EA-specific prior router
decision is the approved QM5_3005 card retirement described above; the other
router reference is the read-only stranded-inventory task itself. A second
read-only work-item query after the audit still returned zero rows.

## Safe next boundary

These are remediation candidates, not free dispatch candidates. Each EA needs a
separate deterministic route that establishes an OWNER-authorized card, reserves
its EA ID and per-symbol magic rows, binds the card, wires the request and setfile
slots, writes explicit fixed-risk and strategy inputs, regenerates the resolver,
and strictly rebuilds that one EA before any Q02 enqueue. This task made none of
those allocations or strategy decisions and did not create untracked work.
