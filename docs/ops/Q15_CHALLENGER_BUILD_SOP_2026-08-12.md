# Q15 Challenger Build and Freeze SOP

Date: 2026-08-12  
Decision contract: DL-084  
Scope: Q14 `OPT_ELIGIBLE` opt-card to a new, frozen challenger identity and one standard Q02 seed

## Operating boundary

Q15 is a development and evidence gate. It does not run an optimization terminal,
does not skip or modify any standard gate, and does not produce a pipeline verdict.
The builder prepares a new EA, sealed DEV-only evidence, and a default-OFF smoke
proof. `framework/scripts/q15_freeze_check.py` validates and records the freeze.
On PASS it appends Q15 `CHALLENGER_SPAWNED` and one pending Q02 row; the challenger
then owns its own unchanged Q02→Q10 history.

Never start `terminal64.exe` manually. Use only an allocated, sanctioned smoke or
DEV-sweep lane. Do not start, stop, reserve, or reconfigure T1–T10 from this SOP.
Never touch T_Live, FTMO, AutoTrading, a deploy manifest, or a live setfile. The
builder is not the approver; the router artifact remains in REVIEW.

## Router `build_ea` payload contract

The Q15 coordinator creates one serial build ticket per opt-card. The payload must
contain this minimum contract before a builder starts:

```json
{
  "schema": "qm.q15-build-ticket/v1",
  "card_id": "OPT-13213-USDJPY-EXIT-SURGERY-1e2bb8e4c42f21f7",
  "opt_card": {
    "path": "D:/QM/reports/opt_track/<card_id>/opt_card.json",
    "sha256": "<64 lowercase hex>",
    "size_bytes": 2339
  },
  "q14_work_item_id": "<OPT_ELIGIBLE row id>",
  "challenger": {
    "ea_id": "QM5_<new id>",
    "slug": "<new lineage slug>",
    "directory": "C:/QM/repo/framework/EAs/QM5_<new id>_<slug>",
    "symbol": "USDJPY.DWX",
    "timeframe": "H1"
  },
  "lever": {
    "enable_input": "strategy_opt_enabled",
    "parameter": "<the one parameter_surface.parameters[0].name>",
    "default": "<card incumbent>",
    "candidate_values": ["<exact card surface>"]
  },
  "required_artifacts": {
    "dev_sweep": "D:/QM/reports/opt_track/<card_id>/dev_sweep.json",
    "default_off_equivalence": "D:/QM/reports/opt_track/<card_id>/default_off_equivalence.json",
    "freeze_addendum": "D:/QM/reports/opt_track/<card_id>/freeze_addendum.json"
  },
  "constraints": [
    "one EA build at a time",
    "DEV/IS selection only; every declared trial is run",
    "strategy_opt_enabled defaults false and is read",
    "the card lever input defaults to the incumbent and is read",
    "Q02 set uses RISK_FIXED=1000 and RISK_PERCENT=0",
    "no terminal or live-surface control"
  ]
}
```

The ticket must bind the current opt-card bytes. If its hash or Q14 identity no
longer matches, recycle the ticket; do not update the hash in place.

## Serial build procedure

1. Read the opt-card and its `trial_ledger.json` completely. Confirm one tunable
   parameter and record every `planned_trials` row before inspecting DEV outcomes.
2. Allocate a genuinely new EA ID and slug through the deterministic registries.
   Add the card symbol to `magic_numbers.csv`, regenerate
   `QM_MagicResolver.mqh`, and keep registry/compile work serial. The validator
   requires the resolver arrays, row count, and embedded LF-canonical registry hash
   to match the active magic rows exactly.
3. Build `QM5_<new id>_<slug>.mq5` and `.ex5`. The source must declare and read:

   ```mql5
   input bool strategy_opt_enabled = false;
   input <card type> <card parameter name> = <card incumbent>;
   ```

   `strategy_opt_enabled=false` must route to parent behavior. A declaration,
   comment, log line, or setfile row alone is not wiring; the source must read both
   inputs in executable code. This closes the QM5_1355 dead-input class.
4. Create two challenger sets under the new EA's `sets/` directory:

   - control-OFF smoke set: fixed risk, `strategy_opt_enabled=false`, card parameter
     at the incumbent;
   - Q02 backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
     `strategy_opt_enabled=true`, card parameter at the selected DEV value.

   The Q02 filename is
   `QM5_<id>_<slug>_<SYMBOL>_<TF>_backtest.set`. Do not create a live set.
5. Compile serially, run target build checks, and retain the source/binary/setfile
   hashes. Do not weaken news staleness, risk, magic, or build guardrails.

## Default-OFF equivalence evidence

Run one meaningful smoke window through the sanctioned harness using the exact
parent binary and setfile bound in the opt-card, then the challenger binary with its
control-OFF set. The window must generate at least one normalized trade event.
Export each run as a `qm.trade-behavior/v1` JSON object whose `events` exclude
identity-only fields such as EA ID, magic, ticket, report path, and wall-clock run
metadata. The two normalized files must be byte-identical.

Write `default_off_equivalence.json` with schema
`qm.q15-default-off-equivalence/v1`. Bind the parent binary/set, challenger
binary/control-OFF set, and both normalized traces by path, SHA-256, and byte size.
The formal shape is in
`tools/strategy_farm/config/q15_default_off_equivalence.v1.schema.json`.
The validator independently opens every binding, rechecks the control-OFF set, and
compares the trace bytes; a claimed PASS field is neither required nor trusted.

## DEV-only sweep and plateau selection

Run exactly the ledger's declared candidates on a DEV/IS window ending before the
first opt-card comparison window. Do not read or summarize Q04 anchored OOS or the
post-DEV holdout during selection. Every trial gets a bound evidence file and the
opt-card's `success_metric.primary` scalar.

Write `dev_sweep.json` with schema `qm.opt-dev-sweep/v1`; its formal shape is in
`tools/strategy_farm/config/opt_dev_sweep.v1.schema.json`. Trial IDs and parameter
objects must match `planned_trials` exactly. `selection.chosen_trial_id` names one
observed trial.

The validator derives the plateau rather than trusting a declared flag:

- direction is `MAXIMIZE`;
- a value is on the plateau when its metric is within 5% of the best DEV metric;
- the chosen value and at least one numerically adjacent card candidate must both
  be on that plateau.

A knife-edge best with no adjacent plateau support fails Q15. Do not add candidates,
change tolerance, or replace a failed selection after seeing OOS.

## Freeze validation and apply

Run the read-only check first from the canonical checkout:

```powershell
cd C:/QM/repo
python framework/scripts/q15_freeze_check.py `
  --card-id <card_id> `
  --challenger-dir C:/QM/repo/framework/EAs/QM5_<new_id>_<slug>
```

The default paths are the card directory's `dev_sweep.json`,
`default_off_equivalence.json`, and `freeze_addendum.json`, plus the single matching
challenger `*_backtest.set`. Use the explicit path flags only to disambiguate; they
do not relax validation.

After independent review of the dry-run JSON, apply once:

```powershell
python framework/scripts/q15_freeze_check.py `
  --card-id <card_id> `
  --challenger-dir C:/QM/repo/framework/EAs/QM5_<new_id>_<slug> `
  --apply
```

`--apply` is canonical-checkout-only and fails while `FACTORY_OFF.flag` exists. It:

1. writes immutable `freeze_addendum.json` (`qm.opt-card-freeze/v1`), hash-binding
   the card, parent, challenger, registries, DEV evidence, equivalence evidence,
   chosen value, and fixed-risk Q02 set;
2. changes the card ledger from `OPENED` to schema-valid `CLOSED`, records all
   declared trial results, and appends the frozen addendum binding plus deterministic
   Q15/Q02 IDs;
3. appends done Q15 `CHALLENGER_SPAWNED` with a `Q14_ADMISSION` dependency on the
   exact `OPT_ELIGIBLE` row;
4. appends exactly one pending Q02 work item with source, binary, setfile, symbol,
   timeframe, and addendum hashes. It issues no dispatch tick.

Reapplying identical bytes is idempotent. Any changed hash, alternate Q15/Q02 row,
different closed ledger, stale resolver, unwired input, trace mismatch, incomplete
sweep, below-plateau choice, or wrong risk mode fails closed. There is no override in
this SOP; correct the build or produce a new governed ticket.

## Review handoff

The builder records the Q15 dry-run/apply JSON, compile and build-check receipts,
and commit IDs in `docs/ops/evidence/`. Move the router ticket only to REVIEW with
that evidence path. Review confirms hashes and tests; it does not infer Q02 or later
pipeline performance and does not promote the challenger to any downstream gate.
