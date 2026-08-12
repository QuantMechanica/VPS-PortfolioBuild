# T_Live decision record — KS vintage recompile deploy (8 files / 10 identities)

- Date: 2026-08-02
- Scope: file-side EX5 replacement on `C:\QM\mt5\T_Live\MT5_Base` for EAs
  10911, 10919, 10939, 11132, 11421, 12567, 12989 (base packet, 9 identities)
  plus 10513 (addendum, tenth identity) and its two terminal-local baseline
  aliases. No AutoTrading change. Re-init performed by OWNER.

## Authority chain

1. Base packet OWNER signature: „passt alles, Sonntagsfenster bestätigt!"
   (2026-07-31, `docs/ops/evidence/2026-07-31_ks_recompile_signature_packet.md`,
   bound manifest `ee12f509…`, source pin 386151841, compiler 5.0.0.6061).
2. Addendum OWNER signature: „klar akzeptier ich das, somit freigegeben"
   (2026-08-01, `docs/ops/evidence/2026-07-31_10513_addendum_manifest.md`,
   canonical EX5 `04b62af2…` = exact Q10-PASS binary).
3. Claude reviewer approvals recorded in both documents (builder ≠ approver
   preserved: Codex built, Claude reviewed, OWNER signed).
4. Sunday market-closed window confirmed by OWNER in writing; OWNER present
   in-session during execution and performed the controlled re-init.

## Verification evidence

Full execution record with timeline, registry-drift fresh review, position
preflight, §2 gate table (10/10 PASS incl. payload-hash==baseline-hash per
identity) and post-deploy pulse (23/24 loaded, 0 dormant):
`docs/ops/evidence/2026-08-02_ks_deploy_execution.md`.

Deployment epoch: 2026-08-02T08:23:01Z. OWNER re-init: 08:24:21Z. Gate PASS:
~08:31Z. Rollback preimages verified at
`C:\QM\deploy\KSRecompile_20260802_386151841\preimages*` (7 + 1 files);
rollback execution would require the separate written OWNER authority per the
signed packet.

## Behavioral riders accepted with the deploy (recorded, not compile noise)

10911 1.0 % per-trade risk cap (`qm_risk_cap_pct`); execution-contract bar
cadences (H1/H4/D1 fail-at-init); native news entry gating (stale limit 336 h,
fail-closed); hardened sizing/order path; KS sandbox-relative baseline path +
book-scoped halt channel. 10513 additionally carries the full June-28→July-13
framework delta and has no EXECUTION_CONTRACT event at this pin (EX5-only
provenance caveat accepted in the signed addendum).

## Consequence

Kill-switch baseline coverage of the live DXZ book: 13/24 → **23/24 armed,
0 dormant**. Remaining uncovered: 10440 (no Q10 PASS exists — honest gap).
MNT-043 vintage bill application (evidence overlay + Q06/Q07 rerun enqueues)
follows as a separate reviewed step.
