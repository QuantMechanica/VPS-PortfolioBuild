# DL-089 three-sibling compile continuation — 2026-08-29

- Router task: `4ea27950-fab1-49ee-a183-bf78967e8447`
- Lane: Codex / `agents/board-advisor`
- Disposition: **PARTIAL PASS — QM5_41194 COMPILE_OK; QM5_41195/41196 DESIGN GAP**
- Scope: framework repair, append-only governed compile enrollment/release, and
  the three named DL-089 Q12 declarations. No Q-phase, pipeline, economic,
  portfolio, or live verdict is asserted.

## Outcome

`QM5_41194_brent-tom-mom-opt` now has a source-hash-matched `COMPILE_OK`
successor with zero compiler errors, zero compiler warnings, and a passing
build check. The governed DL-089 service created its exact pending Q02
prerequisite for `QM5_13054 / XTIUSD.DWX`; the Q12 declaration remains pending
with zero matrix cells until that Q02 row produces a verdict.

`QM5_41195_aa-vol-sma10-opt` and `QM5_41196_qs-kama-trend-xau-opt` remain
unenrolled. Their files already use sibling-specific filenames, but the files
were created with copied, cryptographically bound parent-era setfile content.
The ordinary classifier correctly refuses both with only
`BOUND_SETFILE_HASH_EXISTS`. Adding another setfile name would not solve the
condition because the guard scans every `sets/*.set` under the sibling EA.
There is no task/label-bound rebuild or rebind authority for either identity,
so no binding was removed, overwritten, moved, or bypassed.

## QM5_41194 framework repair and governed compile

The source repair replaced the raw `iTime` call with a cached reference time
populated through `QM_ReadBar`, and added the explicit
`QM_FrameworkTrackOpenPositionMae()` call at the start of `OnTick`.

The canonical compile classifier was extended with one exact authority only:

`router_ops_issue:4ea27950-fab1-49ee-a183-bf78967e8447` →
`QM5_41194_brent-tom-mom-opt`.

The focused authority test proves the task ID cannot authorize `QM5_41195` or
an arbitrary label. It grants no Q-phase, setfile-unbinding, or live authority.

The append-only successor is
`a7f59fd5-6bff-434a-bd95-1762c82ead9c`, superseding failed evidence row
`518916d5-ff50-4724-8583-6a21d7b9ebe2` without changing that historical row.
The exact-row release verified an identical queued/current MQ5 hash and made
the pre-mutation SQLite backup
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260829T210652Z_92cdc1f8.sqlite`
(SHA-256 `7c38d8ccb9379062cfb72edcbe527aa44540a33c7d148d46a7e38a7210cba689`).

| Artifact | SHA-256 / result |
|---|---|
| MQ5 expected and current | `4e49db2160aca15269279d38a8358d761669c783505a599d46b44206cb8c0b5e` / exact match |
| EX5 | `909e8b651d4b404821ef98364b2fe117201daa49912ebda386ea04bea122440a` |
| Setfile | `5baa5afd7cf35d4abf3005fc6f02d96309a57fec8ee7a96dbdc9af8fef673188` |
| Compile receipt | `be54bbe5af59a85c24d4ead28a0271c0798206357aca78f455600bd833ab7252` |
| Compiler | `PASS`, 0 errors, 0 warnings |
| Build check | `PASS`, no failure classes |
| Release dry run | `c480d498d44ff6e8cf5b1d35fc41c6d9aaf7f335ccc036268c05fdb147590331` |
| Release apply | `68fc1f235ad5e049135f6cef2bacda4bc2a2cf1148a8e2d5e1e3c3a631103cc1` |

The compile receipt is
`D:/QM/reports/work_items/a7f59fd5-6bff-434a-bd95-1762c82ead9c/QM5_41194/COMPILE_EA/compile_evidence.json`.
The governed release receipts are
`docs/ops/evidence/2026-08-29_4ea27950_QM5_41194_compile_release_dry_run.json`
and `docs/ops/evidence/2026-08-29_4ea27950_QM5_41194_compile_release.json`.

## QM5_41195 / QM5_41196 design gap

The canonical enrollment commands were repeated with each exact open build
task binding. Both bindings were authorized, and each enrollment was refused
solely by the existing bound setfile:

| EA | MQ5 SHA-256 | Setfile SHA-256 | Preserved embedded build hash | Result |
|---|---|---|---|---|
| `QM5_41195` | `713f6503a73b1c39a35c77b727ffd57999507fc50defb9da3de3c41f4146ecca` | `b7614116188c58acf23d7117faa5ea1382009cb69f1318c48b844722b3c1a421` | `55d38ba42b601f03aaec0451d6358b9c1c8b0ce86d7b692d2f9aee9db1476771` | `BOUND_SETFILE_HASH_EXISTS` |
| `QM5_41196` | `0128d2f16f3febd0bec549b8db0ea9fd030825dedfc06934d5aabc01781be665` | `3eb4146cd6de8592357189cd2134a3a0781fd727dcce92a92848e4f99b8f540b` | `ae7b2e5bdeb59c6ad95d5c856c77b2bbe23e20d3415a2498c525adf2c78b0660` | `BOUND_SETFILE_HASH_EXISTS` |

Commit `eae4326c1` proves both files were newly added under sibling-specific
paths while retaining parent slugs, parent set versions/dates, and already
bound build hashes. Thus the defect is in sibling construction semantics, not
the filename chosen at enrollment time.

`QM5_41195` also has a second exact prerequisite: its copied setfile uses
`qm_magic_slot_offset=1` so inherited basket index 1 selects XAGUSD, while its
active sibling registry row is slot 0 / XAGUSD and its source default is slot
0 (which selects XAUUSD in the inherited basket). A governed remediation must
align source host mapping, card/setfile parameters, and the active magic row;
compiling the current package would not provide an executable XAGUSD sibling.

The clean prerequisite is an OWNER/governance-approved sibling-first-compile
contract that either creates an unbound sibling setfile before the identity is
ever bound, or grants an exact task/label-bound append-only rebuild/rebind
ceremony that preserves the historical binding. The current task explicitly
forbids inventing that authority, so the default guard remains unchanged for
`QM5_41195` and `QM5_41196`.

## Q12 declaration state

After exact dry-run and apply service calls, canonical DB state is:

| Subject pair / declaration | Measurement EA | OPT_CENSUS cells | Exact prerequisite |
|---|---|---:|---|
| `QM5_13054 / XTIUSD.DWX` / `a5b90e08-cf49-51ac-be59-1d4926da2363` | `QM5_41194` | 0 | Q02 row `a9455a78-f667-5a9e-8a76-c97226182018` created and pending, no verdict. |
| `QM5_1537 / XAGUSD.DWX` / `c41e2606-3af1-5766-9bb7-18de8a763a18` | `QM5_41195` | 0 | Measurement sibling binary missing because compile enrollment is refused as above. |
| `QM5_21507 / XAUUSD.DWX` / `99e7e9db-d9a7-514c-b78d-c14e98ebec5d` | `QM5_41196` | 0 | Measurement sibling binary missing because compile enrollment is refused as above. |

All three Q12 declarations remain `pending` with no verdict. This is an exact
upstream-state report, not a pipeline verdict.

## Verification and guardrails

- `python -m pytest tools/strategy_farm/tests/test_compile_work_items.py -q`:
  `36 passed`.
- `python -m py_compile tools/strategy_farm/compile_work_items.py`: PASS.
- `validate_build_guardrails.py` on the repaired MQ5 and backtest setfile:
  PASS, zero findings, news-staleness ceiling 336 hours.
- Backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- No terminal was started manually, no active backtest was interrupted, no
  AutoTrading or T_Live state was changed, and no Q-phase/pipeline verdict was
  manufactured.
