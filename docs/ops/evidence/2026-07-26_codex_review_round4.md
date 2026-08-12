# Codex micro-closure review round 4 — WSE23, WSF3, WSB2 artifact

- Date: 2026-07-26
- Branch reviewed: `agents/board-advisor`
- Final review pin: `d93e4057c32af80978ddaca1b92ebb27715b1a75`
  (`build: pump auto-commit 5 factory artifact path(s)`)
- Initial pin: `91752a516812ad3c8b7d5ea31132faee6c0d12d0`; the intervening factory
  commit touched only nine EA set files and no reviewed path. Apply checks and focused
  suites were repeated at the final pin.
- Final-pin throwaway integration worktree:
  `C:\QM\scratch\codex_round4_integration_d93e4057`
- Review posture: read-only except for this review record. No canonical patch
  application, commit, install, T_Live access, live-DB access/write, terminal action,
  compile, or scheduled-task/process action was performed. Tests used injected files and
  temporary databases; the WSF detector probe printed SQLite `query_only=1`.

Patch/artifact identities:

| Item | SHA-256 |
|---|---|
| `wse23/wse23.patch` | `167b085e4931024247c35e5136b6e6da8039beddb69be4bc3aa968e4d0e27ceb` |
| `wsf3/wsf3.patch` | `d751905d52899f76a3c61042dd5906aaadcfcbc1212412b9136be3f302a4e30b` |
| `wsb2/b3_check.txt` | `f9ab2b1db0d745cc032e125bffee4b18c6c274d9173c6fd51a384a53bc15b421` |

## Verdicts

| Item | Verdict | Decisive finding |
|---|---|---|
| `wse23` | **CHANGES-REQUIRED (packaging only)** | The semantic repair passes all 64 supplied tests and every requested hostile/valid probe. However, the supplied patch does not pass the round-3 default gate `git apply --check --verbose` at the tested HEAD: a `morning_brief.py` hunk still expects the old `{EMERALD}` header context while HEAD has `{ACCENT}`. `git apply --3way` applies without conflicts and was sufficient for functional testing, but it does not substantiate the claimed default clean apply. Regenerate/rebase the patch against current HEAD; no semantic redesign is indicated. |
| `wsf3` | **APPROVE** | Default apply succeeds at current HEAD (only the expected `health.py` offsets 96/97); 33 tests pass. Both hostile inputs return CANDIDATE with the required reasons, and a realistic shared-identity/distinct-report pair reaches AUTHENTICATED directly and through the production detector. |
| `wsb2/b3_check.txt` | **APPROVE** | The calculation labels are removed and replaced by the ratified expectation/planning-minimum framing plus an explicit UNPROVEN statement. Bundle-wide searches find no active unsupported mapping; residual old strings occur only in explicit historical/disavowal text. |

## WSE23 — semantic closure passes, default apply does not

Source inspection confirms that `_e1_schema_ok` and `_e3_schema_ok` run before any
producer status is trusted. A present but schema-invalid E1 primary returns UNKNOWN and
does not fall through to the legacy fallback. `_authenticate_deploy` derives a manifest
account only from a `\d{6,}` match and makes an unbindable book UNKNOWN.

The four WSE1 producer fixtures were independently SHA-compared with
`wse1/samples/`: **4/4 byte-identical**. The parameterized suite contains 11 E1 and 10
E3 required-field negative cases.

Current-pin test rerun:

```text
................................................................         [100%]
64 passed in 1.52s
```

Independent requested probes:

```text
HOSTILE_E1 level=UNBEKANNT value=SCHEMA? age_sec=None overall=ROT
HOSTILE_E3 level=UNBEKANNT value=SCHEMA? age_sec=None overall=ROT
HOSTILE_UNBINDABLE_DIRECT
('UNBEKANNT', ["Manifest-Buch 'DXZ' ohne bindbaren Account — expected_account nicht verifizierbar"])
HOSTILE_UNBINDABLE_INTEGRATED level=UNBEKANNT authenticated=False account=None overall=ROT

VALID_PRODUCER wse1_alarm_all_ok.json level=GRÜN value=DXZ ✓ · FTMO ✓ age_sec=45.0
VALID_PRODUCER wse1_alarm_tlive_missing.json level=ROT value=DXZ missing · FTMO ✓ age_sec=45.0
VALID_PRODUCER wse3_deployment_contract_green.json level=GRÜN value=24/24 age_sec=45.0
VALID_PRODUCER wse3_deployment_contract_red.json level=ROT value=23/24 age_sec=45.0
```

The aggregate hostile-case `overall=ROT` is expected because all unrelated injected
sources were deliberately absent; the load-bearing lamp in each case is
`UNBEKANNT`, never green.

Apply verification at
`d93e4057c32af80978ddaca1b92ebb27715b1a75`:

```text
git apply --check --verbose wse23.patch
WSE23_STANDARD_APPLY_CHECK_EXIT=1

Hunks #1..#6 in morning_brief.py matched at offsets 2/3.
The insertion hunk at original morning_brief.py:584 failed because its context is:
  border-bottom:2px solid {EMERALD}
while current HEAD contains:
  border-bottom:2px solid {ACCENT}
```

The fallback test application was clean:

```text
git apply --3way --check --verbose wse23.patch
WSE23_THREEWAY_APPLY_CHECK_EXIT=0
```

Actual three-way application produced no unmerged index rows, preserved the current
`{ACCENT}` header, inserted `sec0`, and passed both staged/unstaged `git diff --check`.
This proves the functional result can merge three-way without a content conflict; it
does not cure the supplied patch's failed default apply gate.

## WSF3 — authenticated provenance boundary

The production boundary uses `^[0-9a-f]{64}$` for every EA, set, binary, and report
digest. For paired evidence it requires identical EA/set/binary hashes and unique report
hashes. Violations are stably de-duplicated into `malformed_hash`,
`identity_mismatch`, and `report_hash_not_distinct`.

Default apply verification at the final pin:

```text
git apply --check --verbose wsf3.patch
WSF3_STANDARD_APPLY_CHECK_EXIT=0
health.py hunk #3: offset 96
health.py hunk #4: offset 97
```

Current-pin test rerun:

```text
.................................                                        [100%]
33 passed in 1.20s
```

Independent hostile and positive probes:

```text
HOSTILE_MALFORMED ('CANDIDATE', ['malformed_hash'])
HOSTILE_IDENTITY_MISMATCH ('CANDIDATE', ['identity_mismatch'])
POSITIVE_PAIRED_TIER ('AUTHENTICATED', [])
POSITIVE_BINDING identity_shared=True report_distinct=True all_hashes_lower64=True
POSITIVE_DETECTOR_DB query_only=1
POSITIVE_DETECTOR status=WARN value=1
POSITIVE_DETECTOR_DETAIL ... stress_identity=1 candidates=0 authenticated=1
  unbound_provenance=[] ... harsh_reject_no_effect tier=AUTHENTICATED
```

The detector's `WARN` is the expected count-threshold verdict for one detected finding;
the provenance tier inside that result is genuinely `AUTHENTICATED`.

## WSB2 — repaired artifact and bundle claim search

The old artifact hash from round 3 was
`1caac057a9f0fb9055ba55aeb318e8078c891211bb7eb3ba8b973f50cc7a3864`;
the repaired file differs and now says:

```text
ceil(shortfall/ref) = 6
  -> SIX closes the target IN EXPECTATION under the optimistic mean-only assumption;
     NOT a pass probability.
ceil(pg/ref) = 7
  -> SEVEN is the probability-calibrated PLANNING MINIMUM.
P(pass Phase-1 in 30d)>0.5 remains UNPROVEN pending an admitted synchronized joint replay.
```

Bundle-wide search over all nine files in `wsb2\`:

| Search/classification | Result |
|---|---|
| Active calculation label `ceil(...)[O1~0.5/0.8]` | **0 hits** |
| Literal `[O1~0.5]` / `[O1~0.8]` tokens | one each, both on `b3_check.txt:11`, explicitly described as former, unsupported, and removed |
| Apparent six/seven probability-mapping phrases | only historical quotations or explicit negations in `MANIFEST.md` / `B3_RESIDUAL_DENSITY_GAP.md`; no active claim |
| `r=0.815` | 9 tokens, all in the search log or explicit “earlier/unbound/removed” dispositions; no active measured claim |
| Correct `UNPROVEN` framing | present in `b3_check.txt`, `B3_RESIDUAL_DENSITY_GAP.md`, and `MANIFEST.md` |

## Not verified

Not verified: canonical application/merge, post-merge or live runtime behavior, T_Live/terminal state, live databases, MQL compilation/execution, scheduled tasks, installs, or external signature authenticity.

PROGRAMME-COMPLETE(wsf3,wsb2) / REMAINING(wse23-current-HEAD-default-apply).
