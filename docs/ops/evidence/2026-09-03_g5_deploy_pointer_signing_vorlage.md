# G5 — Deploy-pointer signing Vorlage (2026-09-03)

**Gap:** `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md:347-350` (G5). `live_deployment_pointer.json`
is unsigned; `morning_brief.py` reads its Deploy lamp **GELB (AMBER)** and
`verify_live_deployment_contract.py` reads identity **UNKNOWN** for server/epoch/binary.
This document prepares the OWNER signing step so it is a 2-minute review, not deliberation.
Signing is **OWNER/ROT only** — no AI seat mints a signed live binding
(`generate_live_deployment_pointer.py:19-27`; CLAUDE.md T_Live Hard Rule).

**Merge SHAs (this worktree):** `git merge --ff-only agents/board-advisor`:
`a92cda60fe → f5bd0a08ff` (fast-forward, HEAD now `f5bd0a08ff3bbda5c159ede09f1ca552b694b289`).

**Hard-limit compliance:** read-only throughout. No write under `D:/QM`, `C:/QM/mt5`, or
`decisions/`. The generator was run **once, unsigned, `--dry-run`** (writes nothing —
`generate_live_deployment_pointer.py:222-224`); the live pointer's SHA is byte-unchanged
(`f5f23f3c…` before and after the run). No enqueue/hold/release/supersede/restart, no
commit/push. Farm DB was not written.

---

## 0 · TL;DR for OWNER

The unsigned pointer already contains the **correct, byte-identical** composition that is
live today (all three fingerprints reproduce exactly from disk — §2). Signing is a
review-and-approve act, not a rebuild. Before signing, settle **two** things:

1. **Which `deployment_epoch_utc`** — `2026-07-24T06:42:00Z` (manifest-finalized, current
   value) vs `2026-07-19T13:50:00Z` (actual go-live). §6 Risk-1.
2. **Ordering** — a *signed write* is itself freeze-gated and will be **refused while the
   freeze is ACTIVE** (`generate_live_deployment_pointer.py:215-218` → `risk_freeze.py:446,463-464`).
   The freeze must be in its LIFTED state before the signed mint runs. §6 Risk-2.

Also note (§5): signing flips **morning_brief.py** GELB→GRÜN on its own, but it does **not**
by itself clear the UNKNOWNs in **verify_live_deployment_contract.py** — that consumer does
not read the pointer yet and needs the small code rollout G5 also names.

---

## 1 · What the unsigned pointer contains today

**File:** `D:\QM\reports\state\live_deployment_pointer.json` (read-only; not modified).
- `sha256(file)` = `f5f23f3c597f07217ef4406a34f929a2cb50e580986007eefe758d4e27b1704a`
- `schema_version` = `qm.live_deployment_pointer.v1`
- `written_at_utc` = `2026-08-22T10:06:38Z` · `generator.task_id` = `SP-A1`
- **`signed` = `false` · `approved_by` = `null` · `approval_evidence` = `null`** ← the three
  fields OWNER signing sets.

**Manifest it binds (the deployed book):**
- `manifest_path` = `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json`
- `manifest_sha256` = `8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`
  — **verified: equals the actual file's SHA-256 today** (recomputed from disk). Consumers
  recompute-and-compare; a mismatch is ROT (`morning_brief.py:736-738`).
- `manifest_declared_status` = `LIVE`
- `manifest_declared_approved_by` = OWNER (Fabian) 2026-07-24 chat countersign + vault
  NEEDS_FABIAN checkbox; content-sha `a766b5ba…`; record
  `decisions/2026-07-24_owner_approvals_audit_package.md`.

**Identity fields the signed pointer authenticates:**
- `expected_account` = `4000090541` (matches manifest `book = DXZ_4000090541`)
- `expected_server` = `Darwinex-Live`
- `expected_phase` = `DXZ_LIVE`
- `deployment_epoch_utc` = `2026-07-24T06:42:00+00:00` (see §6 Risk-1 — contested)

**Sleeve identity / binary evidence:**
- `expected_sleeves.count` = **24** · `expected_sleeves.identity_sha256` =
  `9aa10411d99adf81861503a0023832874873de39eeaacfa880bfc4368fcf84d0` (sorted `(ea_id, symbol,
  magic)` roster fingerprint — order-independent).
- `binary_setfile_fingerprint.fingerprint_sha256` =
  `8e476e5b807450cbaea92f12b92fcaa285e372a47533b5071996d114a3116035` ·
  `n_sleeves` = 24 · **`n_binary_missing` = 0** (every deployed `.ex5` hashed OK on disk).
- 24 sleeves span 21 distinct binaries (some EAs run two symbols) — consistent with the
  freeze baseline `binary_count: 21` (`D:/QM/reports/state/live_risk_freeze.json`).

**Roster (24 sleeves; ex5_status + set-file RISK_PERCENT, all ENV=live / RISK_FIXED=0):**

| ea_id | symbol | magic | ex5 | RISK_% |
|---|---|---|---|---|
| 1556 | XAUUSD.DWX | 15560004 | OK | 0.6017 |
| 1567 | EURUSD.DWX | 15670007 | OK | 0.1791 |
| 10403 | XAUUSD.DWX | 104030002 | OK | 0.2204 |
| 10440 | NDX.DWX | 104400003 | OK | 0.0577 |
| 10513 | XAUUSD.DWX | 105130003 | OK | 0.305 |
| 10706 | GBPUSD.DWX | 107060001 | OK | 0.053 |
| 10911 | GDAXI.DWX | 109110003 | OK | 0.1276 |
| 10919 | XTIUSD.DWX | 109190001 | OK | 0.9181 |
| 10939 | GBPUSD.DWX | 109390001 | OK | 0.1887 |
| 11132 | SP500.DWX | 111320000 | OK | 0.4562 |
| 11165 | EURUSD.DWX | 111650000 | OK | 0.4127 |
| 11165 | AUDCAD.DWX | 111650002 | OK | 0.523 |
| 11421 | EURUSD.DWX | 114210000 | OK | 0.3364 |
| 11421 | AUDUSD.DWX | 114210003 | OK | 0.3614 |
| 11708 | EURUSD.DWX | 117080000 | OK | 0.508 |
| 12567 | XNGUSD.DWX | 125670002 | OK | 0.9797 |
| 12567 | XAUUSD.DWX | 125670003 | OK | 0.7465 |
| 12778 | AUDUSD.DWX | 127780000 | OK | 0.4905 |
| 12969 | USDJPY.DWX | 129690000 | OK | 0.51 |
| 12989 | XAUUSD.DWX | 129890003 | OK | 0.242 |
| 13117 | EURGBP.DWX | 131170000 | OK | 0.4199 |
| 13128 | NDX.DWX | 131280000 | OK | 1.0 |
| 13213 | USDJPY.DWX | 132130000 | OK | 0.0431 |
| 13301 | GDAXI.DWX | 133010010 | OK | 0.0692 |

Total book risk ≈ **9.75%** (freeze baseline `total_risk_percent: 9.7499`).

---

## 2 · Exact unsigned dry-run command (RUN — writes nothing)

Run from the repo root (`C:/QM/repo`). `--dry-run` prints the computed pointer and writes
nothing regardless of `--out` (`generate_live_deployment_pointer.py:222-224`). This is the
**GELB / AI-allowed** mode (docstring `:19-27`).

```bash
NOW=$(python -c "import datetime;print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
python tools/strategy_farm/generate_live_deployment_pointer.py \
  --manifest "D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json" \
  --environment "T_Live/DXZ" \
  --expected-account 4000090541 \
  --expected-server "Darwinex-Live" \
  --expected-phase "DXZ_LIVE" \
  --deployment-epoch-utc "2026-07-24T06:42:00+00:00" \
  --written-at-utc "$NOW" \
  --dry-run --out "<scratch>/live_deployment_pointer_DRYRUN.json"
```

**Result of the run (2026-09-03, `written_at_utc=2026-09-03T16:03:30Z`):** exit 0, nothing
written to the live path (SHA unchanged `f5f23f3c…`). The dry-run output is **byte-identical
to the live pointer except `written_at_utc`** — i.e. the deployed composition has **not
drifted** since the pointer was last written:

| Field | live pointer | dry-run | equal? |
|---|---|---|---|
| `manifest_sha256` | `8c719b08…eab6` | `8c719b08…eab6` | ✅ |
| `expected_sleeves.identity_sha256` | `9aa10411…f84d0` | `9aa10411…f84d0` | ✅ |
| `binary_setfile_fingerprint.fingerprint_sha256` | `8e476e5b…6035` | `8e476e5b…6035` | ✅ |
| `n_binary_missing` | 0 | 0 | ✅ |
| `written_at_utc` | `2026-08-22T10:06:38Z` | `2026-09-03T16:03:30Z` | (clock only) |

This equality is the core evidence for OWNER: **the pointer OWNER would sign describes the
exact book that is live on disk right now.**

---

## 3 · 2-minute OWNER review checklist

Compare the dry-run output (or the live unsigned pointer) against these expected values.
Everything below already checks out today (§2); the review is a confirmation, not a hunt.

| # | Check | Where | Expected | Why it matters |
|---|---|---|---|---|
| 1 | Right manifest | `manifest_path` | `…portfolio_manifest_live_24sleeve_20260724.json` | Signing the wrong manifest authenticates the wrong book (§6 Risk-3). |
| 2 | Manifest SHA matches file | `manifest_sha256` vs `sha256sum` of the manifest | both `8c719b08…eab6` | Guards against tamper / a re-materialized file (`morning_brief.py:736-738` = ROT on mismatch). |
| 3 | Sleeve count | `expected_sleeves.count` | `24` | Roster completeness; matches freeze baseline. |
| 4 | Roster fingerprint | `expected_sleeves.identity_sha256` | `9aa10411…f84d0` | Any add/remove/re-magic changes this hash. |
| 5 | **No missing binaries** | `binary_setfile_fingerprint.n_binary_missing` | **`0`** | A nonzero count means a sleeve's `.ex5` is not on disk — signing would authenticate a book that cannot run (SP-A1 schema §4). |
| 6 | Account bindable + matches | `expected_account` vs manifest `book` digits | both `4000090541` | Unbindable/mismatched account is the guard that stops a false GRÜN (`morning_brief.py:752-765`). |
| 7 | Server / phase present | `expected_server` / `expected_phase` | `Darwinex-Live` / `DXZ_LIVE` | Absent → GELB (never GRÜN). |
| 8 | Epoch semantics | `deployment_epoch_utc` | **decide: `2026-07-24T06:42Z` vs `2026-07-19T13:50Z`** | Downstream "days-live" math off by 5 days if wrong (§6 Risk-1). |
| 9 | Approval record exists | the `--approval-evidence` path | a dated OWNER record on disk | Generator refuses `--signed` if the path is absent (`:158-162`). |

---

## 4 · Exact OWNER commands to sign / commit (ROT — OWNER only)

> **AI restriction:** an AI seat runs this tool **only unsigned**. The commands below are
> for OWNER (or Claude acting on a dated written OWNER approval, never by default).

**Pre-req A — settle the epoch (§6 Risk-1).** Keep `2026-07-24T06:42:00+00:00`, *or* switch
to the go-live epoch `2026-07-19T13:50:00Z` (cite `decisions/2026-07-19_t_live_dxz_sunday_final_book.md`).
Use the chosen value verbatim in `--deployment-epoch-utc` below.

**Pre-req B — the signed write is freeze-gated (§6 Risk-2).** A `--signed` write (non-dry-run)
calls `risk_freeze.assert_live_book_mutation_allowed(...)` and is **refused while the freeze
is ACTIVE** (`generate_live_deployment_pointer.py:215-218`; `risk_freeze.py:446,463-464`).
The freeze state must first record an OWNER lift (`status` ∈ {LIFTED, INACTIVE} **with**
`lift_authority` **and** `lifted_at_utc` — `risk_freeze.py:447`). There is no `lift`
subcommand; the LIFTED state is an OWNER/ROT act on
`D:/QM/reports/state/live_risk_freeze.json`, authored as part of the lift decision. Sequence:
OWNER lift-decision + LIFTED state → **then** the signed mint below.

**Step 1 — mint the signed pointer** (OWNER, from `C:/QM/repo`):

```bash
python tools/strategy_farm/generate_live_deployment_pointer.py \
  --manifest "D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json" \
  --environment "T_Live/DXZ" \
  --expected-account 4000090541 \
  --expected-server "Darwinex-Live" \
  --expected-phase "DXZ_LIVE" \
  --deployment-epoch-utc "<CHOSEN EPOCH from Pre-req A>" \
  --written-at-utc "<ISO-8601 UTC now>" \
  --signed \
  --approved-by "OWNER (Fabian) 2026-09-03 <channel/method>" \
  --approval-evidence "decisions/2026-07-24_owner_approvals_audit_package.md" \
  --out "D:\QM\reports\state\live_deployment_pointer.json"
```

(Optional dry-signed preview first: add `--dry-run` to the same command to print the exact
`signed:true` shape without writing and without the freeze block — `:215` skips the assert on
dry-run. Still an OWNER-only action.)

**Step 2 — confirm the lamp went GRÜN:**

```bash
python tools/strategy_farm/morning_brief.py   # Deploy lamp: "signiert & authentifiziert"
```

**Step 3 — record the decision** under `decisions/YYYY-MM-DD_t_live_pointer_sign_dxz.md`
citing the pointer's `manifest_sha256` and `written_at_utc` (per SP-A1 schema §4 step 5 /
CLAUDE.md T_Live workflow). This is the deploy-pointer half of the freeze-lift SP-A1/A2.

---

## 5 · What changes in the consumers after signing (file:line)

### Consumer 1 — `morning_brief.py` (Deploy lamp) — flips on the signature alone

Reads the runtime pointer via `_resolve_deploy_stamp` (`morning_brief.py:673-690`) and
authenticates it in `_authenticate_deploy` (`:693-774`). With the current unsigned pointer,
`src="runtime_stamp"` starts the lamp at GRÜN (`:715`) but two checks downgrade it:

- `:719` `if stamp.get("signed") is not True:` → note `signed≠true`, level → **GELB** (`:721`).
- `:723-725` `approved_by` empty → note `approved_by fehlt`, level → **GELB**.

Every other check already passes (SHA match `:727-738`; epoch parses `:740`; account bindable
and equal `:752-765`; phase present `:767`; manifest `LIVE` `:771`). **After signing**
(`signed:true` + non-empty `approved_by`), `:719` and `:723` stop firing → `_authenticate_deploy`
returns `L_GREEN` → `authed=True` (`:805`) → the Deploy lamp is **GRÜN** (`:810`). No code
change needed — the signature is sufficient here.

### Consumer 2 — `verify_live_deployment_contract.py` — signature alone is NOT sufficient

This tool authenticates a `--manifest` (`:1326`) and **does not read the runtime pointer at
all** (no `live_deployment_pointer` code path; the only mentions `:1191-1194` are prose in the
rendered contract). Its identity binding (`:874-906`) therefore reads, for the deployed
manifest, which carries no server/epoch and pins 0/24 binary hashes:

- `server_known = False` → **`SERVER_EXPECTATION_UNKNOWN`** (`:917-921`).
- `epoch_known = False` → **`DEPLOYMENT_EPOCH_UNKNOWN`** (`:923-926`).
- `binary_known = False` (0/24 `ex5_sha256`) → **`BINARY_IDENTITY_UNKNOWN`** (`:927-930`).
- `account` KNOWN (`book=DXZ_4000090541`); `manifest_signed` KNOWN=True (status `LIVE` +
  approver → `:386-387`). These WARN findings roll up to **AMBER** (`:944-951`).

**Signing the pointer changes none of this**, because verify never consults the pointer. The
G5 residual "roll the authenticated read into the consumers" is a **code change**: teach
`verify_live_deployment_contract.py` to resolve `expected_server` / `deployment_epoch` /
per-sleeve `ex5_sha256` from the signed runtime pointer (exactly what SP-A2 did for
`live_book_pulse.py`, `run_live_burnin.ps1`, `sunday_livevsbook_compare.ps1`,
`audit_live_book_inventory.py` — `docs/ops/evidence/2026-08-22_sp-a2_deploy_consumer_binding.md`).
Only after that rollout **and** signing do the three UNKNOWNs become KNOWN. **Do not treat the
GRÜN morning-brief lamp as G5 being closed** — verify remains AMBER until the code lands.

### Downstream (already pointer-bound by SP-A2 — informational)

`live_book_pulse.py` already resolves `book_manifest.source=runtime_pointer`,
`deploy_pointer_reconciliation.match=true` (current `live_book_pulse.json`). Signing does not
change its resolution; the pulse `verdict=WARN` is driven by unrelated items (KS coverage
23/24, missing `10440|NDX` kill-switch) per
`docs/ops/evidence/2026-09-02_ceo_wave1_dxz_live_book_governance.md`, not by the pointer
signature.

---

## 6 · Risks & rollback

**Risk-1 — epoch discrepancy (settle before signing).** The pointer's
`deployment_epoch_utc = 2026-07-24T06:42:00Z` is the manifest's `generated_at`
(file-provenance), but the book's actual go-live is `2026-07-19 ~15:50 CEST ≈ 13:50Z`
(`decisions/2026-07-19_t_live_dxz_sunday_final_book.md`), and
`scripts/sunday_livevsbook_compare.ps1` no longer hardcodes an epoch: since SP-A2 (header 2026-08-22) its `-DeploymentEpoch` defaults to `$null` and is read from the runtime deploy pointer (`scripts/sunday_livevsbook_compare.ps1:41`, `:60-72`), which today carries `2026-07-24T06:42:00+00:00`; the script header records abandoning the hardcoded `07-19` because it drifted from the deployed 24-sleeve manifest (`:24-27`). Adopting `07-19` therefore CHANGES the consumer's effective epoch rather than matching it (CEO correction 2026-09-03 16:35Z after the adversarial verifier refuted the original sentence). The morning-brief
lamp only checks the epoch *parses* (`morning_brief.py:740`), so the lamp is unaffected — but
burn-in / "days-live" math is **understated by 5 days** if 07-24 is signed in. Full analysis:
`docs/ops/evidence/2026-08-22_sp-a1_deployment_epoch_discrepancy_note.md`. **Decision needed:**
adopt `2026-07-19T13:50:00Z` (recommended — matches the field's "went-live" definition and the
existing consumer) or keep 07-24 and update the field's documented semantic.

**Risk-2 — freeze-gating / ordering (a real block, not a warning).** A `--signed` non-dry-run
mint is refused while the freeze is ACTIVE (`generate_live_deployment_pointer.py:215-218`;
freeze currently `ACTIVE`, armed `2026-08-31T05:12Z`, `OWNER-DEC-RISK-FREEZE`). Yet the signed
pointer is a **lift condition** for that same freeze (`risk_freeze.py:49-53`). Resolve by
ordering the lift ceremony: OWNER records the LIFTED freeze state (authority + timestamp)
**first**, then mints the signed pointer. The signed dry-run (`--signed --dry-run`) is the only
signed-shape output available while ACTIVE.

**Risk-3 — sign the right manifest.** `farmctl.py health` previously flagged newer,
unreconciled 2026-07-26 candidate manifests (`…FINAL22/23/24b…`, `…24sleeve_TOTALRISK12…`)
newer than the configured 07-24 file (SP-A1 schema §4;
`2026-08-22_sp-a2_deploy_consumer_binding.md` "Not done"). The 07-24 file is a
re-materialization of the same live composition (no 07-26 chart-side deploy record exists), and
its fingerprints match disk today (§2) — but OWNER must confirm 07-24 is the intended manifest
before signing, not silently inherit it.

**Risk-4 — false sense of completion.** Signing satisfies the *morning-brief* half of G5 but
**not** the verify-consumer half (§5, Consumer 2). Reporting G5 closed on the GRÜN lamp alone
would be premature; the verify code rollout is still required.

**Risk-5 — necessary, not sufficient for the freeze lift.** SP-A1/A2 is one of **three** lift
conditions; NEWS-CONTRACT-V2 (task `84c988e6`) and GOVERNOR-HARDENING (SP-C1 v2 monitor) remain
`PARTIAL` (`risk_freeze.py:54-65`). Signing the pointer does not lift the freeze; the lift needs
all three met **and** an explicit written OWNER lift (`risk_freeze.py:223-225`).

**Rollback.** If a signed pointer is minted for a composition later rolled back: re-mint an
**unsigned** pointer for the restored composition — a signed pointer is OWNER/ROT to replace
(`BOOK_CEREMONY_RUNBOOK_2026-09.md:304`). The pointer never copies an EA or preset, so reverting
it has no T_Live effect on its own; the deployed presets/binaries roll back via
`deploy_tlive_book.py --backup-dir` (runbook §Rollback), independently of the pointer.

---

## 7 · Provenance (files read, read-only)

- Runbook G5 + step 4: `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md:118-119,153,304,347-350`.
- Generator + signing/freeze gates: `tools/strategy_farm/generate_live_deployment_pointer.py:19-27,142-190,204-208,215-224`.
- Freeze contract: `tools/strategy_farm/risk_freeze.py:47-66,430-464`; state
  `D:/QM/reports/state/live_risk_freeze.json` (status ACTIVE, baseline binary_count 21).
- Consumer 1: `tools/strategy_farm/morning_brief.py:121,673-690,693-774,777-812`.
- Consumer 2: `tools/strategy_farm/verify_live_deployment_contract.py:382-403,874-936,944-951,1326` (no pointer read path).
- Live pointer (never modified): `D:/QM/reports/state/live_deployment_pointer.json` (sha `f5f23f3c…`).
- Manifest: `D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json` (sha `8c719b08…`, book `DXZ_4000090541`, status LIVE, 0/24 ex5 pinned).
- Dry-run output (scratch, this worktree): `…/scratchpad/live_deployment_pointer_DRYRUN.json`.
- SP-A1/A2 background: `docs/ops/evidence/2026-08-22_sp-a1_pointer_schema_and_signing.md`,
  `2026-08-22_sp-a1_deployment_epoch_discrepancy_note.md`,
  `2026-08-22_sp-a2_deploy_consumer_binding.md`,
  `2026-09-02_ceo_wave1_dxz_live_book_governance.md` (§2, §"SP-A1/A2").
- Approval-evidence candidates on disk: `decisions/2026-07-24_owner_approvals_audit_package.md`,
  `decisions/2026-07-19_t_live_dxz_sunday_final_book.md`.

**Mutation statement:** this document created no live/T_Live state, no signed pointer, no
freeze change, no queue/DB write, no commit. The generator ran once, unsigned, `--dry-run`
(no bytes written). Every ROT action above remains a separate OWNER act.

## CEO verification notes (2026-09-03 16:35Z, workflow wf_b892e025-176)

Verifier re-derived ~17 claims (pointer sha, manifest sha equality, roster
identity, fingerprint, n_binary_missing=0, account/server/phase/epoch) and
confirmed the dry-run wrote nothing. One claim was refuted and is corrected
above (Risk-1: the Sunday compare script reads the epoch from the pointer;
it does not default to 07-19). The epoch decision itself (07-24 file
provenance vs 07-19 go-live) remains open for OWNER; both candidates are
documented with their consequences.
