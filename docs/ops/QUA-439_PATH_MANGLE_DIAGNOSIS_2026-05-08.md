# QUA-439 Adapter Path-Mangle Diagnosis (2026-05-08)

## Symptom

Some agent configs showed Windows cwd paths mangled from `C:\QM\repo` to `C:\QMepo`.

## Root Cause

The breakage is consistent with an unescaped backslash sequence in string serialization: `\r` in `C:\QM\repo` is interpreted as carriage return, collapsing the visible `r` and yielding `C:\QM<CR>epo` (rendered as `C:\QMepo` in UI/JSON views).

## Evidence

- Existing org record already captured the exact artifact: `C:\QM<CR>epo` in wave-plan documentation.
- Decision-log entry documents recurrence risk from table-cell copy paths containing bare backslashes and explicitly names the `\r` artifact.
- Current issue title itself preserves the same observed mutation: `C:\QM\repo -> C:\QMepo`.

## Engineering Controls

1. Treat all Windows paths in JSON/prompt payload templates as either:
   - doubled backslashes (`C:\\QM\\repo`) or
   - forward slashes (`C:/QM/repo`) when accepted.
2. Avoid plain markdown table-cell path literals as adapter-config copy sources; use fenced code tokens for path fields.
3. Add preflight validation in hire/config scripts:
   - reject cwd strings containing control chars (`\r`, `\n`, `\t`) after decode.
   - reject regex `^([A-Za-z]:\\[^\r\n\t]*)$` failure for Windows cwd when backslash form is used.
4. Normalize outbound comment payload paths to forward slashes (already implemented in `paperclip/tools/ops/lib/paperclip_api.py`).

## Scope Decision

No framework/EA logic impact. This is an adapter-config serialization hygiene defect.
