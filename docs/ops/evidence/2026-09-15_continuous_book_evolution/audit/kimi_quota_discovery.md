# Kimi Quota Discovery — read-only audit (directive §30–§33)

**Date:** 2026-09-15 · **Scope:** read-only, no secrets printed · **Auditor task:** `kimi_quota_discovery`
**Report:** `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/kimi_quota_discovery.md`

## Headline

1. **A real, authoritative usage endpoint EXISTS and is the exact call the official CLI's usage panel makes: `GET https://api.kimi.com/coding/v1/usages`** with `Authorization: Bearer <oauth access_token>` + `Accept: application/json`. Its JSON returns `usages.{limit_5h, limit_7d, limit_month_total, limit_month_code}`, each `{used_ratio, reset_time}`, plus a `boosterWallet` (the "additional quota" the OWNER saw as not-activated) — a 1:1 match to the OWNER's 2026-09-15 UI snapshot (§31).
2. This **refutes** the prior conclusion baked into `KIMI_INTEGRATION_ARCHITECTURE.md`, `audit/kimi_cli.md §6`, and `config/kimi_adapter.v1.json:88` ("no programmatic Kimi usage endpoint exists / spend is NOT CLI-queryable"). The governor is therefore still running `usage_source: "local_ledger_only"` on artificial 40/day–200/week caps — a drift the directive §31/§33 explicitly wants closed.
3. Recommended first call is that single read-only GET; the plan name ("Allegro") is not in `/usages` but is retrievable from a second official-client call, `GET .../coding/v1/me` (`user_level_name`), which also returns PII and must be field-filtered.

## Findings

### F1 — The usage endpoint, verbatim from the installed client
`kimi.exe` bundles the JS that builds and calls the usage URL. Extracted by byte-offset from `C:/Users/Administrator/.kimi-code/bin/kimi.exe` (151 MB, v0.43.1):

```js
function kimiCodeBaseUrl() {
  return (process.env["KIMI_CODE_BASE_URL"] ?? "https://api.kimi.com/coding/v1").replace(/\/+$/, "");
}
function kimiCodeUsageUrl() { return `${kimiCodeBaseUrl()}/usages`; }
function managedUsageUrl(baseUrl) {
  if (baseUrl === void 0) return kimiCodeUsageUrl();
  return `${baseUrl.replace(/\/+$/, "")}/usages`;
}
// DEFAULT_KIMI_CODE_BASE_URL = "https://api.kimi.com/coding/v1";
// GLOBAL_KIMI_CODE_BASE_URL  = "https://api.kimi.ai/coding/v1";
```
- Evidence: `kimi.exe` strings, functions `kimiCodeBaseUrl`, `kimiCodeUsageUrl`, `managedUsageUrl`.
- This VPS is region `mainland-cn` (`C:/Users/Administrator/.kimi-code/region`) and `config.toml base_url = https://api.kimi.com/coding/v1`, so the effective URL is **`https://api.kimi.com/coding/v1/usages`**. (Global accounts would be `api.kimi.ai`; overridable via env `KIMI_CODE_BASE_URL`.)

### F2 — How the client fetches it (headers, auth, timeout)
```js
async function fetchManagedUsage(url, accessToken, opts = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), opts.timeoutMs ?? 8e3); // 8 s
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}`, Accept: "application/json" },
    signal: controller.signal });
  if (!res.ok) { /* 401 -> "check your API key (try /login)"; 404 -> "Usage endpoint not available. Try Kimi For Coding." */ }
  return { kind: "ok", quota: parseManagedUsagePayload(await res.json()) };
}
```
The auth harness supplies the token via `ensureFresh` **before** the GET:
```js
const accessToken = await this.ensureFresh(name, { oauthRef: ... });
const result = await fetchManagedUsage(managedUsageUrl(options.baseUrl), accessToken);
```
- Evidence: `kimi.exe` functions `fetchManagedUsage`, the `getManagedUsage` method, `loadManagedUsageReport`.
- Auth shape is a **Bearer OAuth access token**, identical to the token already stored at `C:/Users/Administrator/.kimi-code/credentials/kimi-code.json` (field `access_token`; 15-min rolling, `expires_at` epoch). No API key. The same OAuth ref (`oauth/kimi-code`) authorizes `/usages`, `/me`, and the `search`/`fetch` services (`config.toml`).

### F3 — Response schema (maps 1:1 to the OWNER's UI snapshot)
```js
function parseQuotaUsages(raw) {
  return {
    limit5h:    parseQuotaEntry(raw["limit_5h"]),
    limit7d:    parseQuotaEntry(raw["limit_7d"]),
    monthTotal: parseQuotaEntry(raw["limit_month_total"]),
    monthCode:  parseQuotaEntry(raw["limit_month_code"]) };
}
function parseQuotaEntry(raw) {           // -> { usedRatio, resetAt }
  const usedRatio = ratioValue(raw["used_ratio"]);   // 0..1
  const resetAt = raw["reset_time"];                 // ISO-8601 string
}
// top level also: payload["boosterWallet"] -> { balance:{type:"BOOSTER",amount,...} }  (extra/add-on quota)
```
Display labels the CLI uses (`quotaUsageRows` / `monthlyBreakdown`):
| Payload field | CLI label | OWNER UI snapshot (2026-09-15) |
|---|---|---|
| `usages.limit_5h.used_ratio` / `.reset_time` | "5h limit" (+ reset hint) | rolling 5-hour Code ≈ 0.32 %, reset visible |
| `usages.limit_7d.used_ratio` / `.reset_time` | "Weekly limit" | rolling 7-day Code ≈ 0.06 %, reset visible |
| `usages.limit_month_total.used_ratio` / `.reset_time` | "Monthly limit" | total usage ≈ 0.01 %, monthly reset (renewal 2026-10-15) |
| `usages.limit_month_code` | monthly **Code** portion; `monthlyBreakdown` derives `kimiRatio = monthTotal − monthCode`, `codeRatio = monthCode` | the "Kimi vs Code" breakdown §32 asks for |
| `boosterWallet` (null/absent) | extra usage wallet | "additional quota currently NOT activated" |
- Evidence: `kimi.exe` functions `parseManagedUsagePayload`, `parseQuotaUsages`, `parseQuotaEntry`, `parseBoosterWallet`, `quotaUsageRows`, `monthlyBreakdown`, `usageRowResetHint`.

### F4 — Plan name ("Allegro") source: the `/me` endpoint, not `/usages`
The string "Allegro" does **not** appear anywhere in `kimi.exe`; `/usages` carries no plan label. The official client's user-info call carries the tier:
```js
function kimiCodeUserInfoUrl() { return `${kimiCodeBaseUrl()}/me`; }   // -> https://api.kimi.com/coding/v1/me
function parseManagedUserInfoPayload(payload) {
  return { userId, nickname, status, region,
           userLevel: intField(payload,"user_level") ?? 0,
           userLevelName: stringField(payload,"user_level_name") ?? "",  // <- plan/tier label, most likely "Allegro"
           domainName: stringField(payload,"domain_name") ?? "",
           email, phone, createdTime, lastLoginTime, ... }; }
```
- Evidence: `kimi.exe` `kimiCodeUserInfoUrl`, `parseManagedUserInfoPayload`, `managedUserInfoUrl`.
- **Caveat:** `/me` returns PII (`email`, `phone`, `nickname`). A quota fetcher must extract **only** `user_level_name` / `status` / `region` and never persist the PII fields. Confidence that `user_level_name == "Allegro"` is **medium** (inferred; not string-confirmed in the binary — confirm with the one live probe).

### F5 — Token freshness / refresh (for when the stored token is expired)
The credential (`credentials/kimi-code.json`) holds `access_token, refresh_token, expires_at, expires_in(=900), scope(kimi-code), token_type(Bearer)` — **field names only; no values read/printed**. The client lazily refreshes on `ensureFresh` (no background loop) and writes the refreshed token back to the same file. Observed refresh grant in the binary:
```
GRANT_TYPE_REFRESH_TOKEN = "refresh_token";  TOKEN_ENDPOINT = "/v1/oauth/token";
OAUTH_API_BETA_HEADER = "oauth-2025-04-20";
DEFAULT_KIMI_CODE_OAUTH_HOST = "https://auth.kimi.com";  clientId = "17e5f671-d194-4dfb-9706-5516cb4…" (partial)
body = { grant_type:"refresh_token", refresh_token, client_id }
```
- Evidence: `kimi.exe` `ensureFresh` docblock, refresh-grant body, `TOKEN_ENDPOINT`, `auth.kimi.com`, `client_id`.
- **Practical consequence:** because `kimi_adapter.run_kimi` runs frequently and every Kimi CLI call auto-refreshes and rewrites the credential, the stored `access_token` is usually fresh. The fetcher should read `access_token` + `expires_at`; **if fresh** (with ~60 s skew) use it directly; **if stale** prefer to force a refresh by the CLI's own path rather than re-implementing the OAuth grant (see §Recommended actions / risk).

### F6 — Current runtime state (the drift to close)
- `D:/QM/reports/state/kimi_governor_state.json` → `"usage_source": "local_ledger_only"`, `state: NORMAL`, caps `40/day`, `200/week`, counts `2/2`. Derived purely from call counts (`kimi_governor.py:148 compute_state`, `:252`).
- `D:/QM/reports/state/kimi_usage_ledger.jsonl` → every row `"usage": null` (adapter never captured a snapshot). `kimi_adapter.py:402` comment: "never invented; null unless the CLI actually printed one".
- The governor already has the seam to prefer real data: `compute_state` sets `usage_source="usage_snapshot"` when any ledger row carries a non-empty `usage` (`:168-173,:252`). A fetcher that fills real ratios closes the loop with no schema change.

### F7 — Additional confirmations
- No `usage`/`quota` CLI subcommand exists (confirms `audit/kimi_cli.md §6` for the *CLI-surface* claim) — but the *endpoint* the CLI calls internally is real. The distinction matters: the prior audit tested only `kimi --help`, not the binary's network layer.
- `status_line` hook `usage` field is **per-session token accounting** streamed from assistant events (`usage = event.usage`, `mergeUsagePatch`), NOT subscription-remaining — a weak, non-authoritative source; do not rely on it for quota.
- Env override `KIMI_CODE_BASE_URL` redirects both `/usages` and `/me`; keep the fetcher's base configurable and default to `config.toml base_url`.

## Ranked candidate usage sources

| Rank | Source | Endpoint / auth | Fields | Stability / legitimacy | Verdict |
|---|---|---|---|---|---|
| **1** | **Managed usage** (what the CLI `/usage` panel calls) | `GET https://api.kimi.com/coding/v1/usages`; `Authorization: Bearer <access_token>`, `Accept: application/json`; 8 s timeout | `usages.limit_5h/limit_7d/limit_month_total/limit_month_code` → `used_ratio`+`reset_time`; `boosterWallet` | **Highest** — first-party, the official product's own read-only call; authoritative subscription state | **RECOMMENDED primary** |
| 2 | User/plan info | `GET https://api.kimi.com/coding/v1/me`; same Bearer auth | `user_level_name` (plan "Allegro"?), `status`, `region` (+PII to discard) | High legitimacy (first-party); PII-bearing → field-filter | Secondary, plan-name only |
| 3 | `status_line` hook `usage` | local stdin JSON to a hook cmd | per-session token usage patch | Fragile, per-session, not subscription-authoritative | Not for quota |
| 4 | Local call-count ledger (existing) | `kimi_usage_ledger.jsonl` + `kimi_governor.py` | call counts vs artificial 40/200 caps | Always available; artificial (directive §33 "fallback only") | **Fail-closed fallback** |

## Implementation sketch — `tools/strategy_farm/kimi_quota_fetcher.py`

Consistent with `kimi_adapter.py` / `kimi_governor.py` conventions (config-driven, no secret logging, fail-closed).

```
Purpose: one read-only GET to the managed usage endpoint; normalize; write
         D:/QM/reports/state/kimi_quota_state.json; never print token values.

read_access_token(cred_path) ->
    d = json.load(cred_path)              # cred_path from config.credential_file
    tok = d["access_token"]; exp = int(d.get("expires_at", 0))
    fresh = exp - now_epoch() > skew_s (60)     # never log tok / refresh_token
    return tok, exp, fresh                        # values used, NEVER logged

fetch_usages(base_url, tok, timeout=8) ->
    GET f"{base_url.rstrip('/')}/usages"
        headers = {"Authorization": f"Bearer {tok}", "Accept": "application/json"}
    200 -> parse; 401 -> ("auth", ...); 404 -> ("endpoint_absent", ...); else ("http_%d")

fetch_me(base_url, tok)  ->  GET .../me ; keep ONLY user_level_name,status,region

normalize(payload_usages, payload_me) -> {
  "schema": "qm.kimi-quota/v1",
  "fetched_at": <utc iso>,
  "source": "managed_usage_endpoint",
  "source_url": ".../coding/v1/usages",           # no token
  "plan": <user_level_name or null>,
  "subscription_period": {"start": <cfg>, "end": <cfg or month reset>},
  "monthly": {"used_ratio": ..., "reset_at": ..., "kimi_ratio": total-code, "code_ratio": code},
  "rolling_5h": {"used_ratio": ..., "reset_at": ...},
  "rolling_7d": {"used_ratio": ..., "reset_at": ...},
  "extra_quota_active": bool(boosterWallet),
  "authoritative_source_ts": <server reset_time domain or fetched_at>,
  "fetch_status": "ok" | "auth_stale" | "endpoint_absent" | "http_error" | "cli_missing" | "timeout"
}

write_state(path) -> D:/QM/reports/state/kimi_quota_state.json   # ownership-tracked, atomic

main(): load config (reuse kimi_adapter.load_config / a kimi_quota_fetcher.v1.json);
        tok,exp,fresh = read_access_token(...)
        if not fresh: fetch_status="auth_stale" -> DO NOT reimplement OAuth grant;
             write state with last-known + fetch_status, and FALL BACK to the ledger governor.
        else: state = normalize(fetch_usages(...), fetch_me(...))
        write_state(); return 0/nonzero
```
Fail-closed contract (directive §33): on any non-`ok` `fetch_status`, `kimi_governor.compute_state` **keeps** running on the local call-count caps (its existing `usage_source="local_ledger_only"` path). When `fetch_status == ok`, the governor prefers the real `used_ratio` values (extend `compute_state` to read `kimi_quota_state.json`: CONSERVE at real ≥70 % of any window, EXHAUSTED at ≥100 % or booster-only-exhausted, and surface `usage_source="managed_usage_endpoint"`). Keep the 40/200 call caps only as runaway/anomaly guards, not as the primary ceiling (directive §33). Schedule via the existing `QM_StrategyFarm_KimiGovernor_15min` task (fetch then derive) rather than a new task.

## The ONE read-only HTTP call to try first

```
GET https://api.kimi.com/coding/v1/usages
Headers:
  Authorization: Bearer <access_token>      # read at runtime from
                                            # C:/Users/Administrator/.kimi-code/credentials/kimi-code.json
                                            # (field "access_token") — NEVER printed or logged
  Accept: application/json
Timeout: 8 s (matches the client)
```
Interpretation: `usages.limit_month_total.used_ratio` = monthly total; `limit_5h`/`limit_7d` = rolling Code windows; each `reset_time` is the authoritative reset timestamp; `boosterWallet` present ⇔ additional quota activated. A `401` means the stored token is stale (refresh needed); `404` means the account/region lacks the coding usage surface (fall back).

## Drift table

| Doc / vault says | Runtime / binary says | Path |
|---|---|---|
| "Usage / quota subcommand: none — spend is NOT CLI-queryable"; "No programmatic usage endpoint exists" | The official client itself calls `GET /coding/v1/usages` (Bearer) and renders 5h/7d/monthly used-ratios + resets | `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md §1,§7`; `docs/ops/evidence/2026-09-15_kimi_integration/audit/kimi_cli.md §6` vs `kimi.exe` `fetchManagedUsage`/`kimiCodeUsageUrl` |
| `config._doc: "No programmatic Kimi usage endpoint exists ... state is derived from this local ledger only"` | Endpoint exists; ledger-only is a fallback, not the only option (directive §33) | `tools/strategy_farm/config/kimi_adapter.v1.json:88` vs `kimi.exe` |
| Governor `usage_source: "local_ledger_only"`, artificial caps 40/200 | Real subscription used-ratios are fetchable and near-zero (OWNER UI: ~0.01 %/0.32 %/0.06 %) | `D:/QM/reports/state/kimi_governor_state.json` vs directive §31 UI snapshot |
| Ledger rows `"usage": null` (never captured) | A `/usages` fetch would populate real usage; governor already flips `usage_source` on non-null usage | `D:/QM/reports/state/kimi_usage_ledger.jsonl` vs `kimi_governor.py:168-173,:252` |

## Open questions strictly requiring OWNER

None. The endpoint, auth shape, and response schema are established from the installed first-party client; implementation is a GREEN reversible tooling addition (read-only fetch + normalized state file) consistent with existing architecture. (No credential/token value was read, printed, or committed.)

## Recommended actions for implementing phases (Phase C — Kimi operationalization)

1. **Build `tools/strategy_farm/kimi_quota_fetcher.py`** per the sketch; config `tools/strategy_farm/config/kimi_quota_fetcher.v1.json` (or extend `kimi_adapter.v1.json`) with `base_url` (default from `config.toml`), `credential_file`, `endpoints:{usages:"/usages", me:"/me"}`, `timeout_s:8`, `skew_s:60`, `state_path:"D:/QM/reports/state/kimi_quota_state.json"`.
2. **First live probe (1 call):** issue the single `GET /usages` to confirm the JSON keys (`used_ratio`/`reset_time`), then one `GET /me` to confirm `user_level_name == "Allegro"`. Record raw shape (values redacted) under this evidence dir. Burns negligible quota.
3. **Extend `tools/strategy_farm/kimi_governor.py:compute_state`** to read `kimi_quota_state.json`: when `fetch_status=="ok"`, drive CONSERVE/EXHAUSTED from real `used_ratio` and set `usage_source="managed_usage_endpoint"`; keep the 40/200 call caps as runaway guards only (directive §33). Wire the fetch into `QM_StrategyFarm_KimiGovernor_15min`.
4. **Correct the stale claims:** `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md §1 (usage/quota row) & §7`, `config/kimi_adapter.v1.json:88 _doc`, and `docs/ops/evidence/2026-09-15_kimi_integration/audit/kimi_cli.md §6` — note the endpoint exists; ledger is now the fallback.
5. **Secret hygiene:** fetcher reads `access_token`/`refresh_token` at runtime only, logs field names + non-secret `expires_at` epoch, never values (mirror `kimi_adapter.py` docstring rule); discard `/me` PII fields (email/phone/nickname) — persist only `user_level_name`/`status`/`region`.
6. **Token-stale handling (risk-minimal):** do NOT re-implement the OAuth refresh grant in the fetcher (auth-surface risk, brittle client_id). If `access_token` is expired, mark `fetch_status="auth_stale"`, keep last-known state, and rely on the next `kimi_adapter` call to auto-refresh the credential; optionally trigger a no-op `kimi provider list` to force `ensureFresh`. Reserve the documented refresh grant (`auth.kimi.com`, `grant_type=refresh_token`) as a last resort only if the CLI cadence proves insufficient.
7. **Tests:** `tests/test_kimi_quota_fetcher.py` — parse a fixture `/usages` payload → normalized state; `401→auth_stale`, `404→endpoint_absent`, timeout→`timeout`; assert no token value ever reaches the state file or logs; governor prefers real ratios when `fetch_status==ok` and falls back to caps otherwise.
