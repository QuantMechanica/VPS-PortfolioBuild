# B-prime release wave 2 — governed execution record

- Router task: `253814f1-f01a-4ea5-899f-b4ea3fc2dbcb`
- OWNER authority: `e1259d10-5bf7-48d4-8059-594159e98445` and `617abd80-f0d9-49b4-b817-e82abf0ad381`
- Exact scope: the ten work-item IDs in the dry-run/apply receipts
- Outcome: **9 released, 1 correctly deferred**

## Outcome

The eight review-only scoped-window successors now have immutable contract-v3
news plans (8 cells each), current setfile/MQ5/EX5 identities, and explicit
self-hashed `qm.scoped-q10-q09-pass-execution-anchor/v1` documents. The anchors
authenticate each exact Q09 PASS aggregate plus its terminal run summary. They
use the plan format's historical Q08-evidence slot without inventing a Q07 or
Q08 verdict. The original review-only window seal is retained byte-for-byte in
`scoped_q10_window_seal_review_origin`; the conversion marker binds it to the
new plan and both OWNER decisions.

For every one of those eight rows, the apply transaction changed the active
`Q09_AWAITING_SEALED_PLAN` hold into a physical `NEWS_CALENDAR_TAINTED` hold,
then called `news_calendar_taint.release_scoped_item()`. Each row consequently
has the standard B-prime marker and footnote `Kalender scope-begrenzt`, no
active policy hold, `terminal_claimable=true`, and no status/verdict/evidence
mutation.

`ee4ff9b4` (QM5_10771/XAUUSD H1) retained an authenticated 8-cell plan and its
bound Q07 evidence. Its runner/worker process had exited before durable
completion; the creation-key/PID-reuse recovery class is fixed by `d6b58fb21`.
The same physical-taint-hold then `release_scoped_item()` sequence released it.

`745671a4` (QM5_11129/SP500 D1) remains pending and unclaimed under
`NEWS_RUNNER_SPAWN_SILENT_ABORT`. Its previous forensic root cause is still
present: the hash-bound Q07 evidence file
`D:\QM\reports\work_items\e3187d46-42c3-4dc7-beac-25cc8a0d947b\QM5_11129\Q07\SP500_DWX\aggregate.json`
does not exist. A new terminal claim would fail in `assert_factory_capacity`.
No hold or marker was changed for this row; it needs a separately routed,
append-only lineage regeneration rather than a bypass.

No wave-1 row was in the tool allowlist. No calendar was repinned or published,
no gate threshold or pipeline verdict was changed, and no terminal, backtest,
T_Live, or AutoTrading process/state was touched.

## Artifacts

- Dry run: `docs/ops/evidence/2026-09-07_scoped_b_release_bprime_wave2_dry_run.json`
- Apply receipt: `docs/ops/evidence/2026-09-07_scoped_b_release_bprime_wave2_apply.json`
- Post-apply verification: `docs/ops/evidence/2026-09-07_scoped_b_release_bprime_wave2_verification.json`
- State backup: `D:\QM\strategy_farm\state\backups\farm_state_before_scoped_b_wave2_20260907T075616Z_31a3f09b.sqlite`
- State-backup SHA-256: `dfe9e3452ecc96ad49812d75add273e62304b48dad3b60fe1ca66bcb2fa91e63`

## Verification

```text
python tools/strategy_farm/scoped_q10_wave2.py --verify --receipt docs/ops/evidence/2026-09-07_scoped_b_release_bprime_wave2_verification.json
PASS: 10/10 state dispositions match their fail-closed expectations

python -m pytest -q tools/strategy_farm/tests/test_scoped_q10_wave2.py tools/strategy_farm/tests/test_news_calendar_scoped_activation.py tools/strategy_farm/tests/test_news_calendar_taint.py tools/strategy_farm/tests/test_q09_news_runner_v2.py tools/strategy_farm/tests/test_news_gate_service.py
93 passed

python -m py_compile tools/strategy_farm/scoped_q10_wave2.py tools/strategy_farm/q09_news_runner.py tools/strategy_farm/news_calendar_scoped_activation.py
PASS

git diff --check -- <explicit wave-2 paths>
PASS
```

This is an operations/release artifact, not pipeline evidence and not a Q-phase
verdict. The nine released rows remain subject to ordinary worker capacity and
ordinary Q10_NEWS adjudication. CEO/Claude verifies the claims and first
terminal verdicts; this task remains in REVIEW.
