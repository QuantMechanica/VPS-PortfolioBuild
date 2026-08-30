# Bounded DL-089 sibling-setfile rebuild ceremony — 2026-08-30

- Router task: `da2c006e-e5ab-4f85-845f-2925f90dd68d`
- OWNER decision: `OWNER-DEC-SIBLING-REBIND-20260829`
- OWNER receipt: `717497ea-2790-4c6b-b768-e4e1d0b5cd19`
- Implementation commit: `1e4d1aefb`
- Disposition: **PARTIAL PASS — CEREMONY IMPLEMENTED AND EXACT ROWS RELEASED; COMPILE RECEIPTS PENDING**

This is build/operations evidence only. It is not a Q-phase, pipeline,
economic, portfolio, deployment, or live verdict.

## Outcome

The canonical compiler now has one append-only sibling-first-compile ceremony
bound to exactly this router task and exactly these labels:

- `QM5_41195_aa-vol-sma10-opt`
- `QM5_41196_qs-kama-trend-xau-opt`

No other task ID or EA label passes the authority test. Ordinary candidate
classification and ordinary recursive setfile validation remain unchanged.
The ceremony records the historical paths/hashes at enqueue, verifies a fresh
unbound task-specific setfile, binds only that fresh file, and rechecks the
historical hashes after the governed build.

`QM5_41195` is aligned to the authoritative `XAGUSD.DWX` slot 0 throughout:
the active magic registry row was already slot 0/XAGUSD, the approved card was
already XAGUSD, the new setfile resolves slot 0, and the source host basket now
maps slot 0 to XAGUSD. `QM5_41196` remains slot 0/XAUUSD consistently.

The sibling recipe is now explicit in
`docs/ops/DL089_PATTERN_SIBLING_BUILD_RECIPE.md`: new `_opt` siblings are
setfile-first and unbound; copying an already bound parent setfile is forbidden.

## Immutable historical and fresh setfile bindings

The two historical files remain in their original paths and retain the exact
pre-task SHA-256 values recorded by the sealed design-gap evidence. They were
not deleted, overwritten, renamed, moved, or rebound.

| EA | Historical bound setfile SHA-256 | Embedded historical build hash | Fresh unbound setfile SHA-256 | Fresh contract |
|---|---|---|---|---|
| `QM5_41195` | `b7614116188c58acf23d7117faa5ea1382009cb69f1318c48b844722b3c1a421` | `55d38ba42b601f03aaec0451d6358b9c1c8b0ce86d7b692d2f9aee9db1476771` | `a93826269aa4eeb6f1ad79dd1181cbc0c13a993c140af2d89a7dfb2252e68cc9` | `build_hash: pending`, slot 0, `RISK_FIXED=1000`, `RISK_PERCENT=0`, six `opt_pp_* = 0` |
| `QM5_41196` | `3eb4146cd6de8592357189cd2134a3a0781fd727dcce92a92848e4f99b8f540b` | `ae7b2e5bdeb59c6ad95d5c856c77b2bbe23e20d3415a2498c525adf2c78b0660` | `9eb094af4f8585bc24bf327f9bc250a22583428b2075e4633ad8a2dbc42ea190` | `build_hash: pending`, slot 0, `RISK_FIXED=1000`, `RISK_PERCENT=0`, six `opt_pp_* = 0` |

Fresh files are under each EA's
`sets/sibling_rebind_da2c006e/` directory. The default enrollment scanner
continues to see and refuse the historical top-level binding; only this exact
authority recognizes the nested unbound current file and waives that one
condition. The task-bound build-check path validates and binds only the nested
file.

## Governed enrollment and release

| EA | Current MQ5 SHA-256 | COMPILE_EA row | Release result |
|---|---|---|---|
| `QM5_41195` | `fcc3168694aba1e22f0a00a74f999e10f5875de4acb6a71c76286bbf72d31dec` | `a7b55e40-6fa0-4f75-a7d8-018e5731216b` | exact-row hold released; pending, unclaimed |
| `QM5_41196` | `0128d2f16f3febd0bec549b8db0ea9fd030825dedfc06934d5aabc01781be665` | `ca019c2d-ff8e-4384-a116-ccdb8348c9c2` | exact-row hold released; pending, unclaimed |

Release receipt hashes:

| Receipt | SHA-256 |
|---|---|
| `2026-08-30_da2c006e_QM5_41195_compile_release_dry_run.json` | `3e64e49ca573307cd5ec9cfa8787312c0df34a6e0efdcf9223067f4d24a53508` |
| `2026-08-30_da2c006e_QM5_41195_compile_release.json` | `d409f70bee5b172d1c257c86836ec4e27208c2551e950786fe091ff860d39be1` |
| `2026-08-30_da2c006e_QM5_41196_compile_release_dry_run.json` | `a42c1701dbfaeeb2a371904406d0c8349acf54f79c6c0449fab1f3e28ae97f21` |
| `2026-08-30_da2c006e_QM5_41196_compile_release.json` | `720185e0ed8c4597eb7ecf963324cc12c5abacb44c448533eb353fa94712f0bd` |

The initial and current health state reports the canonical
`repo_dirty_build_guard` blocked by unrelated working-copy changes. Both exact
rows therefore remain safely pending after hold release; no manual compiler,
terminal, worker, or guard bypass was used. The exact next prerequisite is a
clean canonical build guard followed by resident-worker processing of these
two already released rows. Only their source-hash-matched, zero-error,
zero-warning `COMPILE_OK` receipts can satisfy the remaining compile criterion.

## Q12 declaration state

A read-only `service-dl089-matrix` dry run made no mutation and returned the
exact current prerequisites:

| Subject / declaration | Current cells | Exact prerequisite |
|---|---:|---|
| `QM5_1537 / XAGUSD.DWX` / `c41e2606-3af1-5766-9bb7-18de8a763a18` | 0 | measurement binary `QM5_41195_aa-vol-sma10-opt.ex5` missing pending the COMPILE_EA receipt |
| `QM5_21507 / XAUUSD.DWX` / `99e7e9db-d9a7-514c-b78d-c14e98ebec5d` | 0 | measurement binary `QM5_41196_qs-kama-trend-xau-opt.ex5` missing pending the COMPILE_EA receipt |

No Q12 cells were invented. The governed service must be run again only after
both compile receipts exist; it may then create or report the next Q-only
prerequisite.

## Verification and guardrails

- `test_compile_work_items.py` plus `test_gen_setfile.py`: **40 passed**.
- Focused authority test proves the two-label set and rejects both the older
  duplicate task ID `28d59a8e...` and an arbitrary task ID.
- `validate_build_guardrails.py` on both MQ5 files and both fresh setfiles:
  **PASS**, zero findings, news-staleness ceiling 336 hours.
- Python compilation and PowerShell parser checks: **PASS**.
- Original historical hashes: byte-identical before/after implementation and
  enrollment/release.
- DL-089 selection rules, declared trial count, activity floor, and cell
  definitions were not edited.
- No terminal was started manually, no active T1-T10 run was interrupted, and
  no AutoTrading or T_Live state was touched.

Verdict: `PARTIAL_PASS_FOR_REVIEW_COMPILE_ROWS_RELEASED_PENDING_DIRTY_GUARD`.
