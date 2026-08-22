# MAE-hook emergency repair and governed rebuild handoff — 2026-08-22

Task: `8fe2a461-f70e-489f-ab54-a9ea7d15914c`

Verdict: **PARTIAL / SAFE HANDOFF**. The producer defect is closed, all six named
sources pass the current strict hardening contract, stale Q02 rows are held, and
six governed rebuild rows exist. The compile activation interlock remains in
force, so no new binary or fixed-binary Q02 verdict is claimed here.

## A. Producer prevention

- Commit `43fea65f3` makes the direct
  `QM_FrameworkTrackOpenPositionMae();` call the first `OnTick` statement in the
  Gemini build prompt and explicitly requires strict D3–D10 success.
- `agent_router._build_review_dispatch_gate` now reruns
  `build_gate_hardening.analyze_file` against the hash-bound canonical MQ5. A
  producer-claimed PASS cannot create a Codex REVIEW task when this canonical
  check fails.
- Focused verification:
  `test_gemini_build_review_creates_codex_review_task` and
  `test_gemini_claimed_pass_is_refused_when_canonical_hardening_fails`: **2 PASS**.

## B. Six-source repair

Commit `b88a3c075` adds the direct MAE hook to all six sources, adds explicit
array-bound proofs to QM5_12947, and completes the independently required
QM5_12952 `GER40` → `GDAXI.DWX` set/SPEC/magic/resolver correction.

| EA | MQ5 SHA-256 after repair | Strict hardening |
|---|---|---|
| QM5_12947 | `8f18ae119c7202ec410f82d249743f770f40278d48c4262be91ba3da3cbeedfc` | PASS, zero failures |
| QM5_12948 | `d315dbdbe375b2957960e378bcaca4b6d1c63114245e1465dcffa9f2bfda2f70` | PASS, zero failures |
| QM5_12949 | `09e4f5ec8ea23e8c028d3fda0210cf9c7e31d144fcc423da8c5ab58aa4a8684d` | PASS, zero failures |
| QM5_12950 | `d4c088ce21175157603e07133a279b6a2fad126aecce8d2912f7d61eb6b4ae8d` | PASS, zero failures |
| QM5_12951 | `b130b48a35f848ce6457e1fbd1d4787b031c9a41b9dd2246429a660e84a5b96a` | PASS, zero failures |
| QM5_12952 | `9134487ecbe7eb2635181e5c55776f8c046983be5ec966720ebf82f01fbc2bbd` | PASS, zero failures |

The verifier was run separately for every exact EA label with the canonical
repository and current registries. Risk/news thresholds were not changed.

## Governed rebuild and stale-Q02 containment

Commit `e8157aa70` adds a fail-closed rebuild authority scoped to the exact
OWNER-routed task id and EA ids 12947–12952. It only waives pre-existing build
artifacts/history; structural source, registry, symbol, timeframe, and magic
guards remain non-waivable. Its positive/negative authority test passes.

The following `COMPILE_EA` rows were then enqueued through `farmctl
enqueue-compile`; each is pending behind the standard
`COMPILE_EA_WORKER_ROLLOUT_PENDING` activation hold:

| EA | COMPILE_EA work item |
|---|---|
| QM5_12947 | `b599fe04-0d33-4bdd-8d1e-a7050b591e4e` |
| QM5_12948 | `d9641f79-f3c5-413f-bcfc-70a0fbb7b18d` |
| QM5_12949 | `cafb759d-7974-4189-beb6-d515d6ee84a6` |
| QM5_12950 | `ad6384cd-19c5-4d59-9658-fb3ede91c01b` |
| QM5_12951 | `1cab26d5-7a13-4cbd-8f5b-84ec57031d06` |
| QM5_12952 | `6c8a40b2-5518-477e-8264-303e8e2fc719` |

No activation hold was released and no ad-hoc compile was performed.

At handoff, two recurring Q02 rows still pointed at the old binary. They were
parked through `governed_work_item_hold.py` with non-restart hold
`MAE_HOOK_RECOMPILE_REQUIRED` and verified unclaimable:

- QM5_12947 `fc014472-3b6e-4b31-a232-7b462132f0dc`
- QM5_12948 `4f9fb7eb-21e6-4e84-9bb4-b3c2b39b7854`

Release is permitted only after the corresponding governed compile PASS and a
fresh binary-bound Q02 row exists. The required append-only/fixed-binary Q02
reruns therefore remain downstream work, not fabricated verdicts.

## C. Current-day strict-hardening sweep

The canonical Git history since `2026-08-22T00:00:00+02:00` identified 35 EA
labels. Current strict analysis yields 21 PASS and these 14 violators:

| EA | Failure count | Observed failure classes |
|---|---:|---|
| QM5_1188 | 1 | D11 unsupported `XBRUSD` |
| QM5_12955 | 2 | D7 MAE hook; D11 `GER40` |
| QM5_1345 | 1 | D7 MAE hook |
| QM5_1408 | 4 | D7, D9, 2×D10 |
| QM5_1409 | 8 | D7, D9, 6×D10 |
| QM5_1410 | 8 | strict-hardening failures |
| QM5_1416 | 4 | strict-hardening failures |
| QM5_1425 | 5 | strict-hardening failures |
| QM5_41104 | 2 | D10 |
| QM5_41109 | 1 | strict-hardening failure |
| QM5_41110 | 1 | strict-hardening failure |
| QM5_41111 | 1 | strict-hardening failure |
| QM5_41112 | 1 | strict-hardening failure |
| QM5_41113 | 1 | strict-hardening failure |

This sweep is an inventory, not blanket authorization to mutate unrelated
builds. Gemini review tasks already route to Codex and remain REVIEW/recycle
decisions; no Gemini output is self-approved or advanced to pipeline.
