# QM5_41222 USDJPY REQUAL-8 build, compile, and review handoff

- Recorded: `2026-09-02T13:23Z`
- Branch: `agents/board-advisor`
- Build commit: `cf18ae5a88bf0c98534d41bf3dcd22f5f24f828d`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256:
  `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Build task: `c2ef7f4a-5b2a-472b-a8bf-6cc4c64acb8b`
- Checkpoint: `PAIR8_BUILD_RECORDED_INDEPENDENT_REVIEW_PENDING`

## Outcome

The final REQUAL-8 identity now has a mechanically faithful USDJPY H1 source
port, complete SPEC, one generated fixed-risk setfile, and a governed EX5. The
resident `COMPILE_EA` worker compiled on T4 and returned `COMPILE_OK`; the
compiler reported zero errors and zero warnings and strict `build_check`
passed.

The generation-0 build is recorded `done`. A scoped Codex mechanical review is
also recorded `PASS`, and the required independent review is pending. Exactly
one hash-pinned governed smoke attempt used `-Terminal any`; the resolver
returned `status=no_capacity` before selecting or launching a terminal. The
build therefore records the sanctioned `deferred_p2_smoke` outcome. No Q02 row
was created and the manifest hold was not released.

## Identity and mechanics

- Parent: `QM5_11476_lien-k-double-bb-trend-h1`
- Successor: `QM5_41222_lien-k-double-bb-trend-h1-requal8`
- Target: `USDJPY.DWX / H1`
- Magic: slot `0`, `412220000`
- Source lineage: Kathy Lien, *Battle Tested Forex Trading Strategies*, Double
  Bollinger Bands; approved parent source ID
  `d0ac3635-33fb-5c22-916b-4b3c77f51bb9`

The port preserves the parent transition into the 1SD-to-2SD trend zone,
middle-band slope filter, opposite-inner-band structural stop with 60-pip cap
and 40-pip fallback, neutral-channel exit, and no-Friday-entry rule. Current
framework conformance adds bounded `QM_ReadBar` reads, the Q08 MAE-first hook,
entry-only news gating below management and exits, explicit H1 execution
contract, and zero-initialized trade requests. No strategy mechanics, ML,
grid, martingale, or adaptive parameter logic was introduced.

## Sealed artifacts

| Artifact | SHA-256 |
|---|---|
| MQ5 | `6befddb17c01ffd70fd91994d90286d8c19cdaf0683433769a3e62f0179d3545` |
| EX5 | `c79da53b30c53ae2b23e13d3009e57395b0be3f5d075037b79c59518c8abae0d` |
| SPEC | `950a6018b639c1eede0bfb796763b86e1553fe166e3adf08fefce5c979c397e6` |
| USDJPY H1 backtest set | `325dfb83f3755d4c184ac45772e1e2065fc909a8251eed484602e0441f6daf47` |
| Compile evidence | `033218e027aa8caad5457ff8bdd129d36482a221d4c163b4cba75bb8c5678759` |
| Build result | `7d69595d6da56ae094d44f2c4779a3052c53764721b111aa16c51ab4facc1f09` |

The setfile is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`qm_magic_slot_offset=0`, and `USDJPY.DWX / H1` provenance.

## Governed compile

- Work item: `57868897-b86a-4d46-9af0-7f7aefe81561`
- State/verdict: `done / COMPILE_OK`
- Worker: `T4`
- Evidence:
  `D:/QM/reports/work_items/57868897-b86a-4d46-9af0-7f7aefe81561/QM5_41222/COMPILE_EA/compile_evidence.json`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260902_131126.json`

The exact compile activation hold was released with the bounded one-row
ceremony only after its dry run matched the queued and current MQ5 hashes. The
pre-release backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260902T130926Z_1a90aac5.sqlite`
with SHA-256
`5b3969fc704964b9c6dc840b75f1382028a84e3d0ee2d50c4255cc9033555a19`.
No compiler or terminal was started manually.

## Verification and capacity boundary

- `skill_build_ea_guard.py`: identity, registry, magic, and EA directory PASS.
- `validate_spec_doc.py`: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: MQ5 and setfile PASS, zero findings, maximum
  news staleness `336` hours.
- `build_gate_hardening.py`: zero failures; its three warnings are the expected
  undecidable-card warnings for a manifest-authorized runtime recovery card.
- Exact magic collision check: one active row, no collision; exact symbol
  matrix match: PASS.
- Pre-compile CPU sample: average `76.901277%`, maximum `80.474397%`.
- Pre-smoke CPU sample: average `87.874054%`, maximum `96.388925%`.

Neither five-sample check reached the `97%` stop ceiling. The subsequent exact
smoke attempt still failed closed with `status=no_capacity`, so it launched no
tester and was not retried.

## Review and serial state

- Codex review: `34f35c03-67e6-4e24-b9ae-e090d24ac3df`, `done/PASS`, zero
  findings. Smoke sanity is honestly `UNKNOWN` because no smoke report exists.
- Independent review: `df4a5b66-a554-4cdf-b159-10f3fb6cea6b`, `pending`.
- Pair-8 Q02 rows: zero.
- Pair-8 manifest hold: `08fe4173-07d9-47e1-97e9-a76b1159ad94`, still active
  as `Q09_AWAITING_SEALED_PLAN`, unreleased.

The canonical continuation is: complete the independent review, enqueue one
worker-bound Q01 smoke under the sealed generation-0 hashes, authenticate a
genuine PASS, append the smoke-successor generation, complete generation-
matched reviews, enqueue the manifest's single Q02 row, and only then release
the exact pair-8 hold. A no-capacity result is never relabelled as PASS.

No `T_Live`, AutoTrading, live manifest, portfolio gate, protected
`QM5_41162` work item, historical pipeline row, active tester, or main branch
was changed. No pipeline verdict is asserted.
