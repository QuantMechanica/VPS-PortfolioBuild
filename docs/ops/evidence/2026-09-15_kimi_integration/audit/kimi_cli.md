## Kimi CLI Installation Audit — QuantMechanica VPS (read-only)

**Date:** 2026-09-15 · **Auditor scope:** read-only · **Live LLM calls used:** 1 of max 1

### 1. Identity, version, location

| Fact | Value | Evidence |
|---|---|---|
| Product | Kimi Code (CLI) | `kimi --help` banner: "The Starting Point for Next-Gen Agents"; Documentation: https://moonshotai.github.io/kimi-code/ |
| Version | **0.43.1** | `kimi.exe --version` → `0.43.1`; `updates/latest.json` `latest:"0.43.1"` |
| Executable | `C:\Users\Administrator\.kimi-code\bin\kimi.exe` (151,553,536 bytes, mtime 2026-09-15 08:53:24) | `Get-ChildItem -Recurse -Filter kimi*` |
| Helper binary | `C:\Users\Administrator\.kimi-code\bin\fd.exe` (file-search helper) | same listing |
| Native runtime | `%LOCALAPPDATA%\kimi-code\native\0.43.1\win32-x64\<hash>\` (node_modules: `@moonshot-ai/pi-tui`, `@mariozechner/clipboard`; runtime: `kap-server`, `minidb`) | `Get-ChildItem C:\Users\Administrator\AppData\Local\kimi-code -Recurse` |
| On PATH? | **No** | `where.exe kimi/kimi.cmd/kimi.exe` → not found; `Get-Command kimi` → not recognized |
| npm/pip/pipx/Scoop? | **No** (self-contained per-user install) | `npm ls -g` (no kimi); `pip show kimi-cli` → not found; `pipx` → not recognized |

### 2. Authentication method and state

| Fact | Value | Evidence |
|---|---|---|
| Method | **Device-code OAuth (Bearer)** — not an API key | `kimi provider list` → `managed:kimi-code type=kimi models=4 source=oauth`; `config.toml` `api_key=""` + `[.oauth] storage="file" key="oauth/kimi-code"`; `kimi login` = "Authenticate ... via the device-code flow" |
| Credential file | `C:\Users\Administrator\.kimi-code\credentials\kimi-code.json` — **EXISTS**, 1556 bytes, mtime **2026-09-15 11:25:36** | `Get-ChildItem`; `ConvertFrom-Json` |
| Fields (values NOT printed) | access_token, refresh_token, expires_at, scope, token_type, expires_in | `.PSObject.Properties.Name` |
| Token type / scope | `Bearer` / `kimi-code` | field read (non-secret) |
| Access-token lifetime | `expires_in=900` (15 min); auto-refreshed via refresh_token | field read |
| Valid at audit? | **Yes** — expires_at=1789466268 = 2026-09-15T09:57:48Z > now 09:43:45Z; refresh_token present | epoch→UTC parse, `valid_now=True` |
| Endpoint / plan | `https://api.kimi.com/coding/v1` — **Kimi Code coding-subscription** endpoint | `config.toml` base_url |
| Region | `mainland-cn` (kimi.com; vs `global`=kimi.ai) | `region` file; `acp --help` |
| device_id | present | `Test-Path .kimi-code\device_id` = True |

**Interpretation:** This is consistent with the OWNER's statement — a Kimi Code **subscription** (source=oauth, coding endpoint), NOT a platform pay-as-you-go API key/balance. The "USD 50 API balance" assumption does not apply here; there is no api_key configured.

### 3. Models available

| Alias | display_name | max_context_size | efforts (default) | Evidence |
|---|---|---|---|---|
| `kimi-code/kimi-for-coding` (**default**) | K2.8 Preview | 1,048,576 | low/high/max (max) | `config.toml [models.*]`; `provider list` "Default model: kimi-code/kimi-for-coding" |
| `kimi-code/kimi-for-coding-highspeed` | K2.7 Code Highspeed | 262,144 | — | config.toml |
| `kimi-code/k3` | K3 | 1,048,576 | low/high/max (high) | config.toml |
| `kimi-code/k3-256k` | K3-256k | 262,144 | low/high/max (high) | config.toml |

Capabilities across models: thinking, always_thinking, image_in, video_in (except k3-256k), tool_use, dynamically_loaded_tools. Thinking is **on by default** (`[thinking] enabled=true`). Select via `-m/--model`.

### 4. Headless invocation syntax (from `kimi --help`)

| Concern | Flag / behavior | Evidence |
|---|---|---|
| One-shot prompt | `-p, --prompt <prompt>` "Run one prompt non-interactively and print the response" | `kimi --help` |
| Output format | `--output-format {text,stream-json}` (default text) | `kimi --help` |
| Model | `-m, --model <model>` | `kimi --help` |
| Never-ask automation | `--auto` (everything runs, no interruption) | `kimi --help` |
| Ask-when-needed | `-y, --yolo` (risky actions still ask) | `kimi --help` |
| Plan mode | `--plan` | `kimi --help` |
| Extra workspace dir | `--add-dir <dir>` (repeatable) | `kimi --help` |
| Skills / agent | `--skills-dir <dir>`, `--agent <name>`, `--agent-file <path>` | `kimi --help` |
| Resume | `-S/--session [id]`, `-c/--continue`, `kimi -r <sessionId>` | `kimi --help`; live-call trailer |
| Working dir | uses process cwd (session bound to it via `workspaces.json`) | `workspaces.json` shows `wd_repo_*` keyed by root `C:\QM\repo` |
| System prompt | via `--agent-file` (Markdown agent definition) — no dedicated `--system` flag | `kimi --help` |
| stdin prompt | **UNKNOWN** (only `-p <arg>` documented/tested) | — |
| Timeout flag | **none** — bound externally | `kimi --help` (absent) |

**Top-level commands:** export, fork, provider, session, acp, web, server (deprecated), rc/remote, login, doctor, vis, migrate, upgrade/update.

### 5. Live verification (the ONE call)

```
CMD:     kimi -p "Reply with exactly the word OK." --output-format text
EXIT:    0
LATENCY: 6.2 s
STDOUT (first 600 chars):
  kimi version 0.43.1
  • The user wants me to reply with exactly the word "OK". ... (thinking)
  • OK
  To resume this session: kimi -r session_26f56c6d-0d53-4523-be22-6929471f288f
```
Auth works end-to-end. **No usage/quota indicator was printed.** Note the text-mode output wraps the answer in a version banner + thinking bullets + a resume trailer.

### 6. Usage / quota / concurrency / errors

- **No `usage`/`quota`/`account`/`limits`/`status` subcommand** — spend is **not** CLI-queryable. Evidence: `kimi --help` command list.
- Usage is exposed only to a custom **status_line command** (receives JSON `{model,cwd,git,usage,mode}` on stdin). Evidence: `tui.toml [status_line]` comment.
- **Exit codes:** only `0` (success) observed; non-zero taxonomy **UNDOCUMENTED locally / UNKNOWN**.
- **Concurrency / rate limits:** **UNKNOWN** (not documented locally, not tested).
- **Context limits:** stated locally per model — up to 1,048,576 tokens (K2.8/K3). Evidence: `config.toml max_context_size`.

### 7. Logs / transcripts / state

- Global log: `C:\Users\Administrator\.kimi-code\logs\kimi-code.log` (minidb/session-index lines).
- User history: `C:\Users\Administrator\.kimi-code\user-history\*.jsonl`.
- Session store: `C:\Users\Administrator\.kimi-code\cache\query-store\` (16 shards, minidb).
- Update state: `updates\latest.json`, `updates\rollout.log`; **auto_install=true** (self-updating).
- Session enumeration/export: `kimi session list --json [--all --limit N --cwd <path>]`; `kimi export -o <zip> [sessionId]`.
- `kimi doctor` → validates config.toml & tui.toml (both OK).

### 8. Existing QuantMechanica integration

- **No wrapper in repo.** `Grep kimi` over `C:/QM/repo` (*.py,*.md,*.json,*.ps1) → No files found; broad bash grep only matched a `.png` (binary false positive).
- **No KIMI_ flags/files** under `D:\QM\strategy_farm`, `D:\QM\strategy_farm\state`, or `D:\QM\reports\state`; no `KIMI*` env vars. This is a greenfield integration.

### 9. Recommended adapter contract

**Primary argv (one-shot headless):**
```
C:\Users\Administrator\.kimi-code\bin\kimi.exe -p "<PROMPT>" --output-format stream-json -m kimi-code/kimi-for-coding --auto
```
(run with cwd = target dir, or `--add-dir <dir>`; full path required — not on PATH.)

- **Prompt delivery:** `-p <arg>` (stdin support UNKNOWN; argv risks ~32KB Windows cmdline cap for large prompts → for large/multi-turn use `kimi acp` stdio server).
- **Output parsing:** prefer **stream-json** (confirm event schema with one probe — untested here). If using **text**, strip: leading `^kimi version `, lines starting with the thinking bullet `• `, and the trailing `To resume this session: kimi -r …` line; residual = answer.
- **Automation:** `--auto` to guarantee no interactive prompt hangs a headless run. Malformed argv drops into the TUI (observed) → always validate args and run under a watchdog.
- **Timeouts:** external watchdog only (no CLI flag); 120–300s recommended (trivial call = 6.2s).
- **Error classes:** exit 0 = ok; non-zero/empty → classify auth-expired (needs `kimi login`/`kimi acp --login` device-code, not silently automatable) vs transient network/region (retry+backoff) vs other. Cheap health checks: `kimi provider list` (source=oauth) and `kimi doctor` before batches.
- **Multi-turn / tools:** drive `kimi acp` (Agent Client Protocol over stdio); manage sessions with `kimi session list --json` and archive with `kimi export`.
- **Governance:** track spend in an external ledger (quota_governor pattern) — the subscription allowance is NOT CLI-observable. Record CLI version per run (auto-update is on).

---

## CORRECTION ANNEX — 2026-09-15 (OWNER-DEC-CBE-20260915, slice c2_kimi_quota_fetcher)

**Supersedes §6's claim that "spend is not CLI-queryable / the subscription allowance is NOT CLI-observable."** That was true only for a CLI *subcommand* (there is none). It was **wrong** about the underlying capability: the installed client's usage panel calls a real, first-party, read-only endpoint, and this VPS can call the same one.

- **Endpoint (authoritative):** `GET https://api.kimi.com/coding/v1/usages` with `Authorization: Bearer <oauth access_token>` (the token already in `credentials/kimi-code.json`) and `Accept: application/json`. Region `mainland-cn` → `api.kimi.com`; global accounts use `api.kimi.ai`; override via env `KIMI_CODE_BASE_URL`. Plan label comes from `GET .../me` (`user_level_name`; PII-bearing — field-filter to `user_level_name`/`status`/`region`).
- **Live-verified 2026-09-15** from the worktree (one refresh + read): HTTP 200, plan `Allegro`, `usages.limit_5h`/`limit_7d` each `{used_ratio, reset_time}` (both 0.0 on a near-idle account), no `limit_month_*` and no `boosterWallet` returned for this account (the binary defines them; they appear only when populated). The stale-token case returns HTTP 401 `invalid_authentication_error`.
- **Token refresh:** the 15-min OAuth token is refreshed by the CLI **only on a real authenticated model call** (a `-p` prompt); neither `kimi provider list` nor `kimi doctor` refreshes it (both verified 2026-09-15). Re-implementing the OAuth grant is a documented non-goal.
- **Implementation:** `tools/strategy_farm/kimi_quota_fetcher.py` (+ `config/kimi_quota_fetcher.v1.json`) performs the single read-only GET, normalizes to `D:/QM/reports/state/kimi_quota_state.json`, and never logs/persists the token. `kimi_governor.evaluate()` calls it in-process (guarded, 15 s) and prefers the real ratios; the local 40/200 call caps became `runaway_guard` (120/600) anomaly protection only. Full evidence: `docs/ops/evidence/2026-09-15_continuous_book_evolution/design/c2_kimi_quota_fetcher_report.md` and `audit/kimi_quota_discovery.md`.