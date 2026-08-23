# Codex review — QM5_411xx indicator-buffer repair

- Router task: `50467e7e-3148-4792-9223-083bd8ee2516`
- Authority: `router_ops_issue:50467e7e`
- Reviewed at: `2026-08-23T19:04:06Z`
- Implementation branch: `rb-411xx-build-gate`
- Implementation commits: `565e5110f4c9ebf1e34667a2639fded408f0d489`
  (original 20-EA wave) and `c29853f95bc0bf554ac75122b62570407c4d466a`
  (post-merge QM5_41133 repair)
- Review verdict: `STATIC_REMEDIATION_PASS_COMPILE_PENDING`

## Outcome

The systematic `EA_INDICATOR_BUFFER_UNBOUNDED` defect is mechanically repaired
on the isolated implementation branch. The D10 rule itself was not weakened.
The original 20 source-repair `COMPILE_EA` rows exist append-only and are bound
to the repaired source hashes. They have not yet produced governed
`COMPILE_OK` evidence, so this review does not claim a compile or pipeline PASS.

No merge, cherry-pick, or main/`cto_main` mutation was performed in this Codex
cycle. The implementation remains on `rb-411xx-build-gate` for the
Claude+OWNER close-out path.

## Root cause and prevention

`framework/scripts/build_check.ps1` invokes D10 in
`tools/strategy_farm/build_gate_hardening.py`. The generated commodity/XAU-XAG
sources resized numeric arrays dynamically but proved indices only against
configured counters such as `strategy_max_month_sessions`, not against the
actual runtime destination size. The shared Codex generation contract did not
state that distinction.

Commit `565e5110f` adds local fail-closed `ArraySize(...)` proofs to the affected
sources and hardens the shared builder prompt at
`tools/strategy_farm/prompts/codex_build_ea.md:256-264`: every dynamic numeric
buffer access must be tied to `ArraySize`, and any legacy `CopyBuffer` use must
prove the returned copy count. A diff audit found zero changed input, threshold,
limit, period, multiplier, risk, or news lines in the EA patches.

## Focused verification

Executed against clean branch head `c29853f95`:

- `python -m pytest -q tools/strategy_farm/tests/test_build_gate_hardening.py::test_qm5_411xx_sources_have_no_unbounded_numeric_buffers`
  — `1 passed in 0.92s`; the test scans every `QM5_411*/*.mq5` source and applies
  `check_indicator_buffer_bounds`.
- `python -m pytest -q tools/strategy_farm/tests/test_compile_work_items.py`
  — `16 passed in 7.25s`.
- `python -m py_compile tools/strategy_farm/compile_work_items.py tools/strategy_farm/farmctl.py tools/strategy_farm/build_gate_hardening.py`
  — exit `0`.
- `git diff-tree --check 565e5110f^ 565e5110f` — exit `0`.
- All 20 original repaired source hashes in the canonical dirty working tree are
  byte-identical to branch head and to the `mq5_sha256` values on their queued
  source-repair rows.

The implementation evidence records a scoped
`build_check.ps1 -EALabel <label> -Strict -SkipCompile` attempt for every
original row. Each was refused before the static scan by the live-factory
interlock (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). No terminal was stopped and
no guard was bypassed. The Python D10 gate is green, but the governed compile
lane must supply the final build evidence.

## Per-EA repair and queue result

| EA | Repaired source line(s) | D10 result | Append-only `COMPILE_EA` result |
|---|---:|---|---|
| `QM5_41104_xauxag-mmedian-shift-rv` | `:728`, `:767` | PASS, 0 findings | `62ce0b4a-fc45-4b28-9381-4f58ed94827c`, pending/held |
| `QM5_41109_xauxag-mmean-median-rv` | `:724` | PASS, 0 findings | `cc09145c-a6d6-4cb0-88a4-e10ef58cc58d`, pending/released |
| `QM5_41110_xauxag-moutside-res-rv` | `:791` | PASS, 0 findings | `ec37ed6d-482e-4760-99df-ebf9cd3681fc`, pending/held |
| `QM5_41111_wti-mdaybreadth-mom` | `:552` | PASS, 0 findings | `cee2423d-d224-4581-a127-5fdfb548a5fa`, pending/held |
| `QM5_41112_xauxag-mdaybreadth-rv` | `:722`, `:788` | PASS, 0 findings | `b2cb3830-6542-4d61-ad87-ec63adb07cb2`, pending/held |
| `QM5_41113_xauxag-mhalfagree-rv` | `:723`, `:793` | PASS, 0 findings | `d62f097c-fedc-4643-a671-968a667a4f42`, pending/held |
| `QM5_41116_xauxag-mthirdvote-rv` | `:727`, `:799` | PASS, 0 findings | `65429bf8-28a5-46dd-a306-d7231ed7aa59`, pending/held |
| `QM5_41118_xauxag-mlatehalf-dom-rv` | `:729`, `:797` | PASS, 0 findings | `4c3f4186-8c20-40a3-a163-d53418aa2df7`, pending/held |
| `QM5_41119_xauxag-mclose-quartile-rv` | `:722`, `:757` | PASS, 0 findings | `2823303f-2984-49ff-a794-c34cd6a91527`, pending/held |
| `QM5_41120_xauxag-mopen-residence-rv` | `:736`, `:768` | PASS, 0 findings | `11348cba-e8bc-405b-acbb-a15cf45b1756`, pending/held |
| `QM5_41121_xauxag-mseqdom-rv` | `:731`, `:764` | PASS, 0 findings | `d3137a1c-2b0f-4120-8cc3-b3fd2840d0ca`, pending/held |
| `QM5_41123_xauxag-mpath-eff-rv` | `:732`, `:764` | PASS, 0 findings | `f1c50421-67c4-473f-b089-27e05acdd621`, pending/held |
| `QM5_41124_wti-mrms-coherence-mom` | `:477`, `:506` | PASS, 0 findings | `2de9682b-480f-42b5-a43c-bb3f387ab3c4`, pending/held |
| `QM5_41125_xauxag-mrms-coherence-rv` | `:735`, `:781`, `:797` | PASS, 0 findings | `9ea12411-fd99-4e38-9cac-a2aace69896b`, pending/held |
| `QM5_41126_wti-mpath-eff-mom` | `:477`, `:506` | PASS, 0 findings | `cc714ac2-ff1f-4604-ae08-7631ddf3b971`, pending/held |
| `QM5_41127_wti-mdaily-persist-mom` | `:501`, `:531`, `:541` | PASS, 0 findings | `76b9e5e3-d257-4957-88fa-a33d90a846c0`, pending/held |
| `QM5_41128_xauxag-mdaily-persist-rv` | `:749`, `:795`, `:807`, `:825` | PASS, 0 findings | `84fc53c7-e5a0-4fb0-9aa4-c2dbd15cfbb6`, pending/held |
| `QM5_41130_wti-mopen-residence-mom` | `:487`, `:523` | PASS, 0 findings | `0edf3c6a-c29d-4b90-9787-f099bb23d4e2`, pending/held |
| `QM5_41131_wti-mdaily-tailtrim-mom` | `:492`, `:523`, `:531`, `:581` | PASS, 0 findings | `34785097-be1a-448e-9a8e-28ee665e9ea6`, pending/held |
| `QM5_41132_wti-mweekday-med-mom` | `:497`, `:536` | PASS, 0 findings | `bdae4d54-e686-48e8-bde7-e3b5fdc95dd3`, pending/held |
| `QM5_41133_wti-mdaily-median-mom` | `:523`, `:557`, `:569` | PASS, 0 findings | Existing row `1fb58c79-e46f-4d72-9af1-26eb4656e0d5` is bound to the pre-repair hash; repaired-hash enqueue remains required after governed integration |

At `2026-08-23T19:04:06Z`, the exact source-repair authority query returned 20
rows, all `pending` without verdict, with 19 active holds. All were appended at
`2026-08-23T17:14:00Z`; no prior rows were deleted or overwritten.

## Review boundary

The static remediation is ready for OWNER/Claude integration review. It must
remain in `REVIEW` until the code branch is integrated through the authorized
close-out and the governed compile lane produces source-hash-matched
`COMPILE_OK` evidence. `QM5_41133` also needs a fresh append-only compile row for
its repaired hash after integration; its current pending row is intentionally
stale and must not be mutated.
