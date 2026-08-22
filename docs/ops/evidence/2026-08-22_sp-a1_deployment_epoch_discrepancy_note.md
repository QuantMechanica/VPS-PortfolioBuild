# SP-A1 addendum — `deployment_epoch_utc` discrepancy to resolve before OWNER signing

Task: `agent_router` task `105cb532-20bc-49ca-b952-dc78633daf6b` (SP-A1). This is a
reviewer note on top of the already-committed
`docs/ops/evidence/2026-08-22_sp-a1_live_deployment_pointer_generator.md` and
`docs/ops/evidence/2026-08-22_sp-a1_pointer_schema_and_signing.md` — it does not change
the pointer already generated (which matches those docs: `written_at_utc:
2026-08-22T10:06:38Z`, `deployment_epoch_utc: 2026-07-24T06:42:00+00:00`,
`expected_phase: DXZ_LIVE`, `signed: false`).

## Finding

The generator run documented in `..._live_deployment_pointer_generator.md` used
`--deployment-epoch-utc "2026-07-24T06:42:00+00:00"`, justified there as "the live
manifest's own `generated_at` ... the only evidence-backed timestamp available for when
this book's manifest was finalized; no separate 'went live' timestamp exists in the
manifest or elsewhere."

That last clause is not quite right — a separate, more specific go-live timestamp does
exist:

- `decisions/2026-07-19_t_live_dxz_sunday_final_book.md`, section "SCHLUSSVERIFY — BUCH
  LIVE ALS SONNTAGS-FINAL-24 (2026-07-19 ~15:50)", records the actual chart-side
  go-live confirmation (24/24 charts verified, EA/magic/risk correct) at **2026-07-19
  ~15:50 local (W. Europe Standard Time, CEST = UTC+2 in July) ⇒ ~2026-07-19T13:50Z**.
- `scripts/sunday_livevsbook_compare.ps1` (pre-existing, unmodified by SP-A1) already
  pairs this exact manifest file with `$DeploymentEpoch = '2026-07-19'`
  (`$Manifest = 'D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json'`)
  — i.e. an existing consumer already treats 07-19 as the book's go-live epoch, not
  07-24.

The 2026-07-24 manifest file is a re-materialization of the *same* live composition
that went live 2026-07-19 (no new chart-side deploy happened on 07-24 — no decision
record for a 07-24 deploy exists). `generated_at` on that file reflects when the JSON
was last (re)written, which is a **provenance-of-the-file** timestamp, not a
**went-live** timestamp — and the pointer schema's own field definition (per
`state_contracts_v1.md` §3 and the SP-A1 schema doc) is "when the book went live."

## Why this matters before signing

`morning_brief.py`'s Deploy lamp only checks that `deployment_epoch_utc` *parses*
(`_authenticate_deploy` step (d)) — it does not itself compare epoch values, so this
discrepancy does **not** currently affect the GELB/GRÜN lamp outcome. But
`run_live_burnin.ps1` / burn-in day-counting (SP-A2, "Burn-in nutzt echten
deployment_epoch_utc mit >0 Beobachtungstagen") and any future dashboard/report that
computes "days live" from this field **will** be off by 5 days if it inherits
07-24 instead of 07-19 — and 07-24 is the wrong direction (understates uptime).

## Recommendation

Before OWNER/ROT signs this pointer, resolve which epoch is authoritative:
- If "went live" is the intended semantic (matches the field's own definition and the
  pre-existing `sunday_livevsbook_compare.ps1` default): re-run the generator with
  `--deployment-epoch-utc "2026-07-19T13:50:00Z"` before signing, citing
  `decisions/2026-07-19_t_live_dxz_sunday_final_book.md` as evidence.
- If "manifest finalized" is preferred instead (a defensible but different semantic):
  keep `2026-07-24T06:42:00+00:00`, but update the schema doc's field definition to say
  so explicitly, and update `scripts/sunday_livevsbook_compare.ps1`'s comment (it
  currently states 07-19 without qualification) so the two don't silently disagree.

Either is fine; leaving the pointer silently on 07-24 while a live consumer script's
existing default says 07-19 is the state to avoid. Not resolved by this note — flagged
for the next reviewer (OWNER or Claude close-out) ahead of the signing step in
`2026-08-22_sp-a1_pointer_schema_and_signing.md` §4.
