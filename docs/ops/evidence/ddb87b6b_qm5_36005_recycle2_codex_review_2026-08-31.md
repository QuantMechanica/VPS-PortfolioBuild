# QM5_36005 recycle-2 Gemini remediation — mandatory Codex review

- Review task: `ddb87b6b-a6db-4f8d-be8f-337341238a8c`
- Gemini source task: `cf9b27fd-11f6-465b-9731-8e551bb9c671`
- Canonical build task: `85404c3e-51d0-4a7e-85f3-f4658bc1dea9`
- EA: `QM5_36005_nnfx-coral-trendlord-woodies-harvester`
- Reviewed at: `2026-08-31T09:56:52Z`
- Reviewed tree HEAD: `6bda905d5deb9e3582b2d1c45767c6c2b4e2fe1c`
- Disposition: **REMEDIATION_VERIFIED — remain in REVIEW for independent close-out**
- Pipeline verdict: **none** (this is code-review and build-provenance evidence)

The task requested the `code-review` and `gemini-output-review` skills. Neither
skill is installed in this Codex session, so the mandatory review was performed
directly against the prior close verdict, committed source and presets, governed
compiler receipt, current binary, approved-card mirror, and repository guards.

## Review scope and outcome

The prior independent close-out reduced recycle 2 to one concrete defect: the
presets and evidence declared source SHA-256 `f1869369...`, which did not bind
to the committed MQ5 blob (`d4111544...`). The source mechanics had otherwise
passed that close-out. The MQ5 has not changed since source-repair commit
`b4cd70953113c7b8eb850dbc81b55be64f4c9653`; this pass therefore reviews the
bounded hash/build remediation and rechecks the focused source guards.

That defect is repaired:

- The canonical SHA-256 of the committed MQ5 blob at `HEAD` is
  `d4111544f3b6184d89fbdc3303694e38d8dcaddad19c1032f6703119ac89fe8c`.
- All three committed backtest presets declare that exact canonical hash.
- The Windows working-copy SHA-256 is
  `12f7871acb352c23f79e6fe3a8268c816929898d340f56247031582279b911e9`;
  the difference is expected CRLF normalization and is reported explicitly by
  `canonical_hash.py` as working-copy drift, not durable provenance.
- Governed compile work item `59333bce-ff98-4059-9e34-56d306932f90` was
  released only after its expected and actual working-copy hashes both equaled
  `12f7871...`. Its receipt records compile PASS with zero compiler errors and
  zero compiler warnings, plus strict build-check PASS with zero failures.
- The receipt's EX5 SHA-256 and the current committed EX5 both equal
  `e11e8103deacb817642e1de7013b6c153569011d4751dba4c03c9e3d10dad258`.
  The binary was committed by deterministic artifact commit `7e661567bf3813447036db73b8db63915cd830a5`.

The strict build check emitted one non-blocking vocabulary warning for the
strategy event `STRATEGY_TOTAL_DD_HALT`; it reported no build failure and the
compiler itself reported no warning.

## Focused verification

| Check | Result |
|---|---|
| `canonical_hash.py ... --declared d4111544... --json` | **PASS** — declared hash equals canonical Git blob; transient CRLF drift is identified |
| `python -m pytest tools/strategy_farm/tests/test_qm5_36005_review_rework_static.py -q` | **PASS** — 8 passed |
| `validate_spec_doc.py` for the EA directory | **PASS** — 1/1 |
| `validate_build_guardrails.py` for the EA directory | **PASS** — four files, zero findings, maximum news staleness 336 hours |
| `validate_symbol_scope.py --fail-on-leak` | **PASS** — `SINGLE_SYMBOL_OK`, zero violations |
| `build_gate_hardening.py --ea-label QM5_36005_nnfx-coral-trendlord-woodies-harvester` | **PASS** — zero failures and zero warnings |
| `skill_build_ea_guard.py --ea-id 36005 ...` | **PASS** — EA registry, magic rows, and directory present |
| `farmctl.py work-items --ea QM5_36005` | Exactly one governed compile row; status done, verdict `COMPILE_OK` |
| Relevant `git diff --check` and scoped status | **PASS** — reviewed EA, presets, SPEC, and focused regression are clean |

The three presets retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, registered slots
0/1/2, and `qm_news_stale_max_hours` remains at the allowed maximum of 336 in
the EA. The approved-card mirror in `D:/QM/strategy_farm/artifacts/cards_approved/`
and the repository-approved card are byte-identical with SHA-256
`82135900487c2231096ff8fbc256da43a18a8a28033bd51971cf2e6610c348c4`.

## Boundary

This review resolves the recorded hash/build-provenance defect and accepts the
bounded remediation for independent close-review. It does not self-approve the
Gemini task, create a pipeline verdict, enqueue Q02, claim runtime behavior, or
alter source, presets, registry allocations, terminal processes, `T_Live`,
AutoTrading, or factory state. No manual compile or tester run was started.
