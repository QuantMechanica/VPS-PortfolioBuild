# Build gate D11 — canonical DWX symbol existence

Date: 2026-08-22  
Router task: `29bba2f9-0fd4-4c98-9c52-996b2d118359`  
Disposition: `IMPLEMENTED_REVIEW_REQUIRED`

## Outcome

`tools/strategy_farm/build_gate_hardening.py` now performs a build-level D11
check. It loads the canonical symbol matrix and magic registry once, then
collects every `.DWX` symbol found in:

1. every setfile name beneath the selected EA directory;
2. every setfile's content, with source line provenance; and
3. every active/reserved `magic_numbers.csv` row for the exact EA id and slug.

Each observed symbol must exactly and case-sensitively match a `symbol` row in
`framework/registry/dwx_symbol_matrix.csv`. Missing or malformed registries,
unreadable setfiles, invalid EA labels, ambiguous matrix rows, and phantom
symbols are hard failures, never warnings. The JSON report includes registry
metadata plus symbol-by-symbol origins for review evidence.

The existing unconditional `Invoke-BuildGateHardeningCheck` call in
`framework/scripts/build_check.ps1` consumes all returned failures. A
PowerShell integration fixture proves D11 therefore changes canonical
`build_check.result` to `FAIL`; no separate or optional invocation was added.

The shared Codex/Gemini build template now contains the exact 37-row canonical
matrix snapshot and explicitly maps DAX to `GDAXI.DWX`, forbidding
`GER40.DWX`/`DE30.DWX`. The Codex review checklist independently requires the
same exact check across setfile names/content and current magic rows.

## Focused verification

- `python -m py_compile` on the checker and focused test module: PASS.
- D11 and PowerShell binding selection: `4 passed, 14 deselected`.
- All focused hardening tests except the unrelated fleet-wide D6 corpus audit:
  `17 passed, 1 deselected`.
- Prompt snapshot comparison: matrix `37`, listed `37`, missing `0`, extra `0`.
- `git diff --check` on the four implementation files: PASS.

Canonical-repository measurements after the change:

| EA | observed symbols | D11 result | evidence |
|---|---:|---|---|
| `QM5_12952_mql5-force-ema-card` | 3 | FAIL | `GER40.DWX` found in setfile name, setfile content line 7, and active magic slot 2; DAX hint is `GDAXI.DWX` |
| `QM5_12955_mql5-aroon-cross-card` | 3 | FAIL | `GER40.DWX` found in setfile name, setfile content line 7, and active magic slot 2; DAX hint is `GDAXI.DWX` |
| `QM5_12954_pring-coppock-h4-variant` | 13 | PASS | all 13 observed symbols are exact matrix members |

No EA, setfile, magic row, resolver, binary, terminal, backtest, deployment,
`T_Live`, or AutoTrading state was changed by this D11 task. The two detected
build defects remain visible for their governed repair/recycle work; this task
does not manufacture a pipeline verdict.

## Files in review

- `tools/strategy_farm/build_gate_hardening.py`
- `tools/strategy_farm/tests/test_build_gate_hardening.py`
- `tools/strategy_farm/prompts/codex_build_ea.md`
- `tools/strategy_farm/prompts/codex_review_ea.md`
- `docs/ops/evidence/2026-08-22_build_gate_d11_symbol_matrix.md`

## Verdict

`IMPLEMENTED_REVIEW_REQUIRED`: phantom-symbol fixtures fail closed, canonical
fixtures pass, and the shared build plus review instructions now expose the
canonical namespace. Leave in REVIEW; this is guardrail evidence, not a
pipeline or live-use approval.
