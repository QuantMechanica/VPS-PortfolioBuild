# Adversarial Verification — QM-TODO-20260820-003 (Website Strategy Archive Contract)

**Verdict: FAIL (security-first).** The generated public-staging file
`strategy_cards_public.json` leaks thousands of absolute local filesystem paths and
several email addresses. Acceptance rule "any single leak = FAIL" is breached at scale.

## Method
- Ran redaction tests: `python -m pytest tools/strategy_farm/tests/test_website_archive_contract.py -q` => **38 passed in 0.50s**.
- Structured leak-walk over every string value in all 5 preview JSON files
  (`D:\QM\exports\website_contract_preview\`), scratch script
  `scratchpad/leakscan.py` / `leak2.py`.
- Synthetic unknown-field-drop test + direct `scrub_text()` probes (in-process import).
- Chain addressability walk (IDs only) for 2 EAs.

## LEAK 1 — absolute local paths (CONFIRMED, severe)
`strategy_cards_public.json`, fields `excerpt_redacted` and `source_citation`:
**2334 distinct absolute-path substrings**. Examples (measured):
- `C:/Users/Administrator/Dropbox/Finanzen/Forex/###` — OWNER personal finance folder + admin username
- `C:/Users/Administrator/Downloads/Hyonix/Hyonix/RapidFireScalper.mq5`
- `D:/QM/strategy_farm/artifacts/research/...`, `D:/QM/mt5/T_Export/MQL5/Files`, `D:/QM/reports/work_items`
- `G:/My Drive/...` (Vault), `C:/QM/repo/framework/registry/dwx_symbol_matrix.csv`
- `l://OWNER-FTMO-SURVIVORS-20260711`

## LEAK 2 — email addresses (CONFIRMED)
`strategy_cards_public.json`: 5 distinct — `prbain@tradingsmart.com`, `sam86@live.com`,
`fxextract@yahoo.com` (source_citation / excerpt fields).

## Root cause
`_ABS_WIN_PATH = re.compile(r"[A-Za-z]:\\[^\s\"'<>|]*")` (line 68) matches **backslash**
paths only. Card markdown bodies use **forward slashes**, so `C:/`, `D:/`, `G:/` paths
pass `scrub_text()` untouched. There is **no email pattern** in `_FREE_TEXT_PATTERNS`.
Proof (in-process):
```
scrub C:/ path : 'see C:/Users/Administrator/Dropbox/x.md'   (UNREDACTED)
scrub D:/ path : 'see D:/QM/strategy_farm/artifacts/research/x' (UNREDACTED)
scrub email    : 'contact sam86@live.com now'                 (UNREDACTED)
scrub backslash: 'see [REDACTED]'                             (redacted — only this form covered)
```
The 38 passing tests use only backslash fixtures — the forward-slash + email classes are
**untested**, which is why the bypass shipped green.

## Checks that PASSED (report is fair)
- Unknown-field drop: `redact_record({...,'evil_secret_field','magic_number'}, allow)` drops both. VERIFIED.
- Chain addressable by IDs only: QM5_10000 & QM5_10001 walk EA->card->symbol/gate(Q02)->run_id->report_id->manifest. VERIFIED.
- Qxx-only naming in `gate_results.json`: `gate_id=Q02`, friendly `gate_name`; zero raw `P\d` tokens in any string field. VERIFIED.
- `.DWX` suffix (24k occurrences) is **not** a leak: contract line 52 declares `symbol_id` (`EURUSD.DWX`) "Public-safe; no account mapping."
- No magic numbers / account numbers / hostnames surfaced (forbidden-key guard + `symbol_id` opacity hold).
- IPv4 hits (`017.44.1.015`, `018.9.6.622`) are leading-zero DOI/version fragments, not real addresses — false positives.

## Scope discipline (PASS)
- Preview output is `D:\QM\exports\website_contract_preview\` — staging only; **nothing under `public-data/`**.
- `git status`: claimed 4 files present as untracked; no `.set`/`framework/EAs` churn attributable to this task; no live-exporter or guard files modified; no verdict logic touched. (Unrelated untracked `mission_control_v2_*` / `filesystem_inventory*` belong to sibling tasks, not TODO-003.)

## Required fix before this can go to PASS
1. Extend `_ABS_WIN_PATH` (or add a pattern) to cover forward-slash drive paths `([A-Za-z]:[\\/])`.
2. Add an email-address scrub pattern to `_FREE_TEXT_PATTERNS`.
3. Add forward-slash + email fixtures to the test suite and re-generate the preview; re-scan must return **0** path/email hits.

## Rollback
No rollback needed — verification is read-only; the only artifacts written are this
evidence doc and scratch scripts under the session scratchpad.
