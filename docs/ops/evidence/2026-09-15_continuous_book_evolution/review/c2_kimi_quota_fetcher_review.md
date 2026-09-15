# Adversarial review — slice `c2_kimi_quota_fetcher`

**Reviewer:** Claude (adversarial) · **Date:** 2026-09-15
**Directive:** OWNER-DEC-CBE-20260915 §30–§33, §70 (`Kimi real quota fetch failure falls back safely`, `no secret leakage`, `MT5 factory unaffected by Kimi failure`).
**Patch:** `scratchpad/patches_bc/c2_kimi_quota_fetcher.patch` (read in full, 1528 lines).
**Base:** `agents/board-advisor` @ `55fb2bf5fc` (canonical HEAD matches; worktree `wf_65943105-ce8-6` has it applied).

**Verdict: ACCEPT** (no blocking, no major; minor notes for follow-up).

---

## 1. RED boundaries — none crossed

- No gate threshold / criterion change. The only numeric change is renaming the local `40/day, 200/week` Kimi call caps to `runaway_guard` and raising to `120/600` — this is **explicitly mandated by §33** ("do not preserve an arbitrary low ceiling", "do not remove runaway protection") and is not a pipeline gate.
- No qualification weakening; runaway guard still trips EXHAUSTED (verified by test `test_runaway_guard_still_trips_with_normal_real_ratios`).
- No T_Live / AutoTrading / purchase / deployment touch. No farm DB (`farm_state.sqlite`) write. Only new runtime artifact is `D:/QM/reports/state/kimi_quota_state.json`.
- **No token/credential exposure.** Verified directly:
  - Credential field names read match the real file: keys `['access_token','expires_at','expires_in','refresh_token','scope','token_type']`; `expires_at` is epoch-seconds (1789478973). Fetcher reads only `access_token` + `expires_at` — correct.
  - `normalize()` never places the token in the state dict; `write_state` writes only the normalized dict. Tests assert the secret + `refresh-secret` absent from the on-disk state (`test_fetch_ok_writes_state_and_no_token_leak`), `/me` PII discarded (`test_me_pii_is_discarded`), and header redaction (`test_fetch_sends_bearer_header_but_never_persists_it`). `_print_redacted` has an `assert` defence-in-depth guard.
  - `error` fields carry only non-secret classifiers (`http_401`, `token_stale`, exception type names).

## 2. Directive fidelity — faithful

- §32 state fields all present: `plan`, `subscription_period.{start,end}`, `monthly`/`rolling_5h`/`rolling_7d` (each `used_ratio`+`reset_at`), `breakdown` (kimi-vs-code), `extra_quota_active` (booster), `source='api.kimi.com/coding/v1/usages'`, `source_timestamp`, `raw_schema_version`, `fetch_status ∈ {ok,auth_error,network_error,schema_error,disabled}`.
- Endpoint + auth exactly match the audit `kimi_quota_discovery.md` (RECOMMENDED primary: single read-only `GET /usages` Bearer OAuth, `/me` for plan label with PII field-filter, `KIMI_CODE_BASE_URL` override, 8 s timeout, 60 s skew). Cross-checked line-by-line against the discovery doc's F1/F3/F4/F5 and its pseudo-implementation — the fetcher implements the recommendation without deviation.
- Governor integration per §33: prefers real ratios only when `fetch_status==ok` AND fresh (`max_state_age_s=1800` = 2× the 15-min cadence); CONSERVE ≥0.80 window / ≥0.85 monthly, EXHAUSTED ≥0.98 — thresholds in `kimi_quota_fetcher.v1.json`, documented Fable-adjustable. On any failure/staleness falls back to ledger with `usage_source='local_ledger_fallback'` + failure class.
- **No new arbitrary permanent low cap invented**; runaway guard is documented as anomaly protection only, raised so it cannot bind before real telemetry. Runaway protection is **kept**, not removed.
- **No silent no-op warning.** The fallback path is real code that still evaluates ledger counts, error streaks, and the subscription-period rule; verified by `test_network_error_fallback_still_honours_ledger_exhaustion`.
- In-process wiring per §32: `evaluate` CLI subcommand fetches first (guarded try/except + 15 s thread-join timeout); no separate scheduled task added; `status`/`record()` consume the last written state without spending a fetch. Kill switch `QM_KIMI_QUOTA_FETCH=0` / `enabled:false` → `disabled` with zero network calls (tested).

## 3. Correctness — sound

- Optional-param additions (`compute_state(..., quota_state=None)`, `evaluate(..., fetch=False, quota_state=None)`) are back-compatible. Grepped all callers: `kimi_adapter.py` (`record`→`evaluate`, no fetch), `agent_chain.py` (only `governor_config`/`allowed_capabilities`), and `kimi_governor.main`. None broken.
- Legacy `caps` key preserved as alias; existing `gov` fixture pins `caps:{10,40}` so `_guard_user_specified` is True and the fetcher default does not override it → 20 pre-existing governor tests keep their semantics.
- JSON configs valid; both new files parse. Windows paths use forward slashes / `pathlib` — fine. Atomic state write via `.tmp` + `replace`.
- Runs under SYSTEM scheduled task: `read_access_token` reads the credential file by absolute path with no env dependency (unlike the CLI, which needs `USERPROFILE`) — robust.
- **Independently ran the tests in the worktree: `45 passed in 1.20s`** (14 fetcher + 31 governor), matching the implementer's summary line.

## 4. Tests — §70 items present and meaningful

`Kimi real quota fetch failure falls back safely`: covered for every class (`auth_error`, `network_error`, `stale ok`, `disabled`, missing credential, timeout, 404, garbage JSON) at both fetcher and governor level. `no secret leakage`: covered (state file, `/me` PII, header redaction). `MT5 factory unaffected`: the fetch is guarded + bounded and `fetch()` never raises. Real ratios driving CONSERVE/EXHAUSTED and the runaway guard still tripping are both asserted. Summary line shows passing; re-verified above.

## 5. Docs — English, dated, non-destructive

- `KIMI_INTEGRATION_ARCHITECTURE.md` §1 usage row + §7/§7.2 corrected with dated `CORRECTION 2026-09-15 (OWNER-DEC-CBE-20260915)`; the old "no endpoint / local ledger only" text is retained as the historical/fallback design, not deleted.
- `kimi_cli.md` gets an append-only dated CORRECTION ANNEX; original §6 line retained.
- `config/kimi_adapter.v1.json:88` `_doc` corrected and marked SUPERSEDED. History preserved throughout.

---

## Minor notes (follow-up, non-blocking)

1. **Broken relative doc cross-reference.** The `kimi_cli.md` annex, `kimi_quota_fetcher.py` docstring, and `kimi_quota_fetcher.v1.json` cite `audit/kimi_quota_discovery.md`. The discovery doc actually lives at `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/kimi_quota_discovery.md`, but `kimi_cli.md` sits under `2026-09-15_kimi_integration/audit/`, so its relative `audit/kimi_quota_discovery.md` resolves to a non-existent sibling. Fix the pointer to the full path.
2. **404 collapsed into `network_error`.** The discovery doc (F1 line 40) notes 404 = "Usage endpoint not available" — a persistent, not transient, condition. The fetcher maps 404→`network_error`; still fails back safely to the ledger, but a distinct class (e.g. `endpoint_absent`) would avoid masking a genuine endpoint retirement as a transient blip. Optional.
3. **`refresh.via_cli` (OFF by default) would bypass the single-flight lock + usage ledger.** If ever enabled, `_refresh_via_cli` spawns `kimi.exe -p` directly, not through `kimi_adapter.run_kimi`, so that model call is uncounted in `kimi_usage_ledger.jsonl` and races the adapter's token-refresh write. It is off by default and documented as a lever; if turned on, route it through the adapter instead.
4. **Credential path + runaway guard duplicated across configs.** `credential_file`/`kimi_bin` are re-literal'd in `kimi_quota_fetcher.v1.json` rather than referencing `kimi_adapter.v1.json`; `runaway_guard` now lives in both configs (equal today). A future OWNER re-login or cap change must touch two files. Consider a single source of truth.
5. Directive text said "reuse kimi_adapter's loader" — there is no token loader in `kimi_adapter.py` (it only pre-flights that the credential file exists), so implementing a local `read_access_token` was the only option. Not a defect; noted for the record.

## Live-probe evidence
Not re-run (would require a fresh token and spend quota). The implementer pasted the redacted normalized output (plan `Allegro`, 5h/7d `used_ratio` 0.0, monthly/booster null) in the slice report, satisfying the directive's verify-once requirement; the schema divergence (monthly absent on the near-idle account) is honestly documented and handled as `null`.
