# FTMO M13 binding — line-ending-invariant pins + one-time re-pin

Ticket a5cf99d0 · baseline commit `e1d42acafb63` · generated 2026-09-18T02:00:24Z

## Verdict

**No content drift.** For every file pinned by `trial_setpath.load_binding()`, the
line-ending-normalized content is byte-identical both to the content the previous pin
described and to the committed git blob. Two pin *values* changed; zero rule bytes did.

## What was wrong

The pins were raw-byte sha256 of files whose line endings flip per working tree under
`core.autocrlf`. They were not even internally consistent about which byte stream they
described, so the binding refused everywhere at once:

| pinned file | old pin was computed over | symptom |
|---|---|---|
| `…2026-09-06_ftmo_demo_account_terms.md` | LF (git blob) | `account_terms_evidence_hash_drift` in every autocrlf working tree |
| `…/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json` | LF (git blob) | `rulepack_file_hash_drift` in `C:/QM/repo`, which predates the file's `text eol=lf` attribute |
| `…_M13_demo_bootstrap.set` | the CRLF smudge | verified only under autocrlf; could never verify on an LF clone or in CI |
| `…_M13_demo_active.set` | the CRLF smudge | same |

## Per-file drift and re-pin

| pin | old pin basis | worktree raw sha256 | git blob raw sha256 | normalized sha256 (new pin) | value changed | normalized content == previously pinned |
|---|---|---|---|---|---|---|
| `account_terms_evidence` | git_blob_bytes | `3b1d605ab0a4` | `6d6c7bdd43b6` | `6d6c7bdd43b6` | no | YES |
| `rulepack_file` | worktree_raw_bytes | `9db8fda733f5` | `9db8fda733f5` | `9db8fda733f5` | no | YES |
| `evaluator_rulepack_file` | worktree_raw_bytes | `9db8fda733f5` | `9db8fda733f5` | `9db8fda733f5` | no | YES |
| `governor_bootstrap_preset` | worktree_raw_bytes | `c189004f19e8` | `15c18dc43967` | `15c18dc43967` | yes | YES |
| `governor_active_preset` | worktree_raw_bytes | `853730943614` | `f73453412b51` | `f73453412b51` | yes | YES |

Full digests, byte lengths and CRLF line counts: `repin_proof.json`.

Only the two governor-preset pins changed value:

- `governor_bootstrap_preset`: `c189004f19e89fd83dd563cfd9334bc5b60c67cb9302b65217ad3ebbb7fb40f2` → `15c18dc439679b3482b321ac11a3711686fa73e78f50ba1379ad26a6ad7b8eeb`
- `governor_active_preset`: `8537309436144497e42ccdee94426eeb5d7bad95f3568f92ba01bf532dedb061` → `f73453412b51c25f4e6a84600f46f6602dc827aff9709b10ea7aca634cbe1361`

Both old values are the sha256 of the *same file's* CRLF bytes; normalizing exactly those
bytes yields the new value, which is also the sha256 of the committed LF blob. That is the
proof the change is line endings only.

## Fix

1. `tools/strategy_farm/ftmo/binding_hash.py` — one definition of the pin basis:
   sha256 over LF-normalized bytes (UTF-16 payloads are hashed verbatim, since CR NUL LF NUL
   must not be byte-rewritten). Used by `trial_setpath`, `governor_rebind` and
   `ftmo_book3_standalone_evaluator`, which previously each hashed raw bytes on their own.
2. `.gitattributes` — the three files that lacked an entry are now `-text`, so their
   working-tree bytes stay equal to the LF blob. The rulepack and the binding itself were
   already `text eol=lf`.

The two defenses are independent on purpose: a clone that ignores `.gitattributes` still
verifies, and a tool that forgets to normalize still sees stable bytes.

Sensitivity is unchanged. Any byte of rule content — a threshold digit, a rule id, an
inserted or removed line, trailing whitespace — still moves the digest; only the CR/LF
spelling of a line break is neutralized. `test_ftmo_binding_pin_line_endings.py` holds that line.

## Also fixed here (not a line-ending issue)

- **evaluator_block_annotation** — was `trial_setpath.load_binding -> Refusal('evaluator_binding_mismatch')`. Commit 6794e1b8fb added a prose key 'rulepack_file_sha256_note' inside binding.evaluator, which load_binding compares by exact 5-key dict equality, so the binding refused unconditionally. The prose was moved verbatim to a top-level 'notes' list; no pin, path, criterion or rule value changed.

## STILL BLOCKED — needs a decision, deliberately not fixed here

**as_of_label_conflict** → `trial_setpath.load_binding -> Refusal('wrong_rulepack')`

Commit 992c59d1af bumped FTMO_2S_100K_STANDARD_V2.json's own as_of to 2026-09-15 and the follow-up re-pin commits (aabacec330, 769cf3f0e5, 6794e1b8fb) updated file_sha256 and canonical_sha256 to that file but left binding.rulepack.as_of at 2026-09-04. load_binding requires binding.as_of == rulepack.as_of (2026-09-15), while ftmo_book3_standalone_evaluator.py:840 hard-codes contract.as_of == '2026-09-04'. The two modules are currently unsatisfiable together.

*Why not fixed here:* Choosing the binding rule-snapshot date touches gate/contract criteria (ROT under the Stehende Vollmacht) and is not a line-ending repair. The hash pins already identify the 2026-09-15 rulepack unambiguously, so the likely intent is 2026-09-15 on both sides, but that is an OWNER/ticket call.

Still red because of it:
- `tools/strategy_farm/tests/test_ftmo_trial_setpath.py::test_m13_binding_is_standard_hash_bound_and_governor_coherent`
- `tools/strategy_farm/tests/test_ftmo_trial_setpath.py::test_generated_manifest_names_standard_profile_and_internal_overlay`

So `load_binding()` now clears every hash gate in any working tree and stops one gate later,
at `wrong_rulepack`. Trial preset derivation and the demo installer stay blocked until the
`as_of` date is decided.

## Existing working trees

git checkout HEAD -- <the three newly -text files> once this lands, so their working-tree bytes match the LF blob.

Unrelated pre-existing dirt in `C:/QM/repo`: the working-tree copy of the Standard rulepack
carries an uncommitted `rebound_at_utc` bump to `2026-09-18T00:04:45Z` (written by
`rules_snapshot.py` in text mode, hence also the CRLF). That is a real content change and was
excluded from this re-pin — the pins here describe the committed content.
