# Deploy-pointer manifest reconciliation — and why the signature is HELD

Date: 2026-08-22
Author: Claude (Orchestrator), interactive slot
Trigger: OWNER approval `OWNER-ACT-SIGN-POINTER` ("OWNER: genehmigt",
Vault `12 ToDo/AI ToDos/OWNER.md`, 2026-08-22 20:52 local), recorded in
`decisions/2026-08-22_owner_decisions_evening_batch.md` §5.
Procedure: `docs/ops/evidence/2026-08-22_sp-a1_pointer_schema_and_signing.md` §4.

**Outcome: the prerequisite reconciliation is COMPLETE and unambiguous. The
signature itself is HELD, on a defect the reconciliation surfaced.**

Nothing on T_Live was touched. No AutoTrading state, no risk value, no set
file, no binary, no manifest was modified by this pass. It is read-only.

---

## 1. The prerequisite that had to be cleared

§4 of the signing procedure forbids signing a pointer whose `manifest_path`
targets a manifest other than the one T_Live actually runs, and names an
unresolved question: `farmctl health` (`ks_baseline_dormancy`) flags four
newer 2026-07-26 candidate manifests, all newer than the configured
2026-07-24 manifest. "Reconciling which manifest T_Live actually runs is a
prerequisite decision, not something this tool resolves."

That reconciliation is what §2 and §3 below do.

## 2. Roster reconciliation — deployed presets vs. every candidate manifest

Ground truth used: the 24 `.set` files actually present in
`C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets` (numbered `01_`…`24_`; the three
`_archiv*` subdirectories are excluded). Each filename encodes
`<slot>_<symbol>_<timeframe>_QM5_<ea_id>_<slug>.set`, giving a deployed
`(ea_id, symbol)` roster of 24 pairs.

| Manifest | sleeves | status | roster == deployed | extra | missing |
|---|---|---|---|---|---|
| `portfolio_manifest_live_24sleeve_20260724.json` | 24 | **LIVE** | **yes** | 0 | 0 |
| `portfolio_manifest_sunday_24sleeve_TOTALRISK12_20260726.json` | 24 | DRAFT | yes | 0 | 0 |
| `portfolio_manifest_sunday_FINAL22_TOTALRISK12_20260726.json` | 22 | DRAFT | no | 1 | 3 |
| `portfolio_manifest_sunday_FINAL23_TOTALRISK12_20260726.json` | 23 | DRAFT | no | 1 | 2 |
| `portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json` | 24 | DRAFT | no | 1 | 1 |

Three of the four 07-26 candidates are eliminated on roster alone. Two
manifests survive with an identical roster, so roster is not sufficient —
§3 decides between them.

## 3. Risk reconciliation — the decisive test

The two surviving manifests differ in what they claim each sleeve risks.
`RISK_PERCENT` was read from the 24 deployed `.set` files themselves and
compared sleeve-by-sleeve.

```
DEPLOYED total RISK_PERCENT = 9.7499  over 24 sleeves
RISK_FIXED = 0 on all 24 sleeves

portfolio_manifest_live_24sleeve_20260724.json
  manifest total = 9.7499   mismatches vs deployed =  0 / 24
portfolio_manifest_sunday_24sleeve_TOTALRISK12_20260726.json
  manifest total = 12.0000  mismatches vs deployed = 23 / 24
```

**Conclusion: `portfolio_manifest_live_24sleeve_20260724.json` is the
manifest T_Live actually runs — exact match on all 24 sleeves, to the fourth
decimal.** The pointer already targets exactly this file
(`manifest_sha256 8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`).

The 07-26 `TOTALRISK12` draft is the 9.75 % → 12 % scaling proposal. It was
never deployed, and OWNER parked exactly that scaling the same evening
(`OWNER-DEC-STAT-CONTRACT`: scaling 9.75 → 12+ stays parked until the drain
goal is reached). The four 07-26 files are drafts that were never adopted;
their presence is a housekeeping issue in `D:\QM\reports\portfolio`, not an
ambiguity about the live book.

**The `ks_baseline_dormancy` prerequisite is hereby resolved.**

## 4. Why the signature is held anyway — set-file provenance

Signing the pointer marks the book *authenticated*. Before doing that on
OWNER's record, the deployed set files themselves were checked against the
set-file contract (`ENV=live`, `RISK_PERCENT` set, `RISK_FIXED=0`, plus the
generator's own provenance header). **10 of 24 deployed live presets fail
the provenance half of that check:**

| Preset | defect |
|---|---|
| `04_XTIUSD_H4_QM5_10919_grimes-overshoot.set` | header says `environment: backtest`, `risk_mode: FIXED` |
| `11_GBPUSD_H1_QM5_10706_tv-mon-ls.set` | `build_hash: pending` |
| `12_GBPUSD_H4_QM5_10939_grimes-context-pb.set` | `build_hash: pending` |
| `13_GDAXI_H1_QM5_10911_grimes-complex-pb.set` | `build_hash: pending` |
| `14_NDX_H1_QM5_13128_pre-fomc-drift-ndx.set` | `build_hash: pending` |
| `15_NDX_H1_QM5_10440_mql5-ohlc-mtf.set` | `build_hash: pending` |
| `16_SP500_D1_QM5_11132_tm-cum-rsi2.set` | `build_hash: pending` |
| `19_XAUUSD_D1_QM5_10513_mql5-ichimoku.set` | `build_hash: pending` |
| `23_XNGUSD_D1_QM5_12567_cum-rsi2-commodity.set` | `build_hash: pending` |
| `21_XAUUSD_H4_QM5_12989_grimes-nested-pb-v2.set` | `build_hash: pending` **and see below** |

Sleeve 21 is the one that stops the signature. Its first two lines, in the
file deployed on T_Live right now:

```
; DRAFT_ONLY: generated for D2-d s3-d2d-15-swap decision package, task 106ed489-5914-497b-9ca0-9986372ec8d0
; DO_NOT_COPY_TO_T_LIVE_WITHOUT_SIGNED_OWNER_MANIFEST
```

with `set_version: s20260703-d2d-s3-d2d-15-swap-DRAFT`,
`risk_mode: PERCENT_DRAFT_INVOL_SUMRISK_CAPPED_S3-D2D-15-SWAP`,
`build_hash: pending`, `author: Claude`, `date: 2026-07-03`. It was swept
into the 2026-07-24 deploy three weeks after being written as a draft, and
its own guard line was not honoured.

Neither sleeve has a `live` set file in the framework at all — for both
`QM5_12989` and `QM5_10919` the repo holds only `backtest`, `q05`, `q06_*`
and `q10_confirmation` variants. The T_Live presets are hand-produced
artifacts with no framework source of truth behind them.

### What this is, and what it is not

**It is not a trading defect, and no live misbehaviour is claimed.** The
functional keys are correct on all 24 sleeves: `RISK_FIXED=0`,
`RISK_PERCENT` set and positive, `PORTFOLIO_WEIGHT` present,
`qm_magic_slot_offset` consistent with the registry formula
(`ea_id*10000+slot`, spot-checked against the pointer roster). MT5 ignores
`;` comment lines, so the two odd headers change nothing about how those EAs
trade, and the deployed risk vector matches the LIVE manifest exactly
(§3, 0/24 mismatches). The book runs as the manifest says it runs.

**It is a provenance defect, and provenance is exactly what a signature
asserts.** Signing now would stamp "authenticated" onto a book in which 10 of
24 sleeves carry no build hash, one carries a backtest provenance header, and
one carries an explicit machine-readable marker saying it must not be on
T_Live without a signed OWNER manifest. A signature that launders that marker
away is worse than no signature: every downstream consumer
(Pulse, burn-in, Sunday-compare, inventory — all `RequireSigned`) would stop
reporting UNKNOWN and start reporting authenticated, on evidence that does
not support the word.

### Why this is not covered by OWNER's approval

OWNER approved signing a pointer that had been described to him as clean:
24 sleeves, real epoch 2026-07-24, `n_binary_missing: 0`, consumers bound
with `RequireSigned`. That description was accurate as far as it went — the
`.ex5` binaries all resolve and hash. The set-file provenance layer had never
been checked by anyone, so it was not part of what he approved. Reading a
general "genehmigt" as covering a defect nobody had measured yet would be
inferring the approval, which §4 explicitly forbids ("never inferred or
assumed").

Live book binding is ROT under the Stehende Vollmacht, so the Auffangregel
does not apply. This returns to OWNER as a decision.

## 5. Vorlage for OWNER

**Question:** sign the pointer now over the provenance gap, or repair the set
files first?

- **(a) Repair first, then sign — recommended.** Regenerate the 10 defective
  presets through `framework/scripts/gen_setfile.ps1` with `ENV=live` and a
  real `build_hash`, byte-verify that every functional key (`RISK_PERCENT`,
  `RISK_FIXED`, `PORTFOLIO_WEIGHT`, `qm_magic_slot_offset`) is **unchanged**,
  redeploy, then sign. Cost: one Codex task plus a verification pass. Risk:
  regenerating a deployed set file touches T_Live — it must be
  value-preserving and byte-diffed, and per the Hard Rules the AutoTrading
  toggle stays yours.
- **(b) Sign now, repair after.** The consumers go green immediately. Cost:
  the signature asserts provenance the files do not have, including over an
  explicit do-not-deploy marker. Not recommended.
- **(c) Sign a reduced book.** Not available — the pointer authenticates the
  book as a whole.

**Cost of waiting:** low and bounded. The consumers keep reading UNKNOWN,
which is their correct fail-closed state and what they have reported since
2026-07-24. Nothing degrades further by waiting; the sleeves keep trading
exactly as they do today either way.

**Recommendation: (a).** The reconciliation work that gated the signature is
done and will not need repeating — the manifest question is settled. What
remains is making the set files say truthfully what they already do.

## 6. Evidence

- Deployed presets: `C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\01_…24_*.set` (24 files)
- Pointer: `D:\QM\reports\state\live_deployment_pointer.json`,
  `signed:false`, `written_at_utc 2026-08-22T10:06:38Z`,
  `expected_sleeves.count 24`, `binary_setfile_fingerprint.n_binary_missing 0`
- Manifests compared: the five files listed in §2, all under `D:\QM\reports\portfolio`
- Procedure and schema: `docs/ops/evidence/2026-08-22_sp-a1_pointer_schema_and_signing.md`
- OWNER approval of record: `decisions/2026-08-22_owner_decisions_evening_batch.md` §5
- Original countersigned approval chain for the 07-24 manifest:
  `decisions/2026-07-24_owner_approvals_audit_package.md`
