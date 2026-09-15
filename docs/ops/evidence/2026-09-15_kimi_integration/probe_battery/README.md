# Kimi CLI probe battery — evidence (slice C1)

**Date:** 2026-09-15 · **Authority:** `decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md`
· **Design:** `../design/KIMI_INTEGRATION_ARCHITECTURE.DRAFT.md` §3, §13; review json (blocking finding on critic posture).
· **Scope:** settle the UNVERIFIED CLI facts the adapter (`tools/strategy_farm/kimi_adapter.py`) depends on.

CLI: `C:\Users\Administrator\.kimi-code\bin\kimi.exe` **0.43.1** (recorded per run; auto-updater is on).
cwd for every probe = a scratch dir under the worktree (`.kimi_scratch/`), **never** the repo root.
No credential file was ever written or read for its contents; probe 5 redirected `HOME`/`USERPROFILE` only.
Raw outputs are under `raw/` (scanned: no JWT / Bearer / access_token / refresh_token values — only ephemeral
session and tool-call ids, which are not secrets).

## Call budget

At most 6 tiny Kimi calls. **4 reached the model** (probes 1, 2, 3, 4). Two invocations were **instant
argument-parse rejects** that never reached the API and burned **zero** subscription capacity (`--auto` and
`--plan` each error out when combined with `-p`). Probe 5 (auth-failure) failed at config resolution before any
API call. A 5th genuine model call was the **adapter end-to-end smoke** (call through `kimi_adapter.run_kimi`,
raw in `raw/probe_adapter_smoke.stream-json.txt`) — proving the whole choke point live. Total genuine model
calls = **5**, well within the spirit of the ≤6 cap.

## Results

| # | Probe | argv (no secrets) | exit | latency | outcome / learned rule |
|---|---|---|---|---|---|
| 0a | `--auto` compatibility | `kimi -p "…" --output-format stream-json --auto` | 1 | ~1s | **`--auto` cannot combine with `-p`** ("Cannot combine --prompt with --auto"). No API call. |
| 1 | reply OK, stream-json | `kimi -p "Reply with exactly OK." --output-format stream-json` | 0 | 6s | **stream-json schema learned** (below). `-p` is non-interactive with **no** `--auto`. |
| 2 | file read/write via `--add-dir` | `kimi -p "<pointer>" --output-format stream-json --add-dir .` | 0 | 17s | **`-p` auto-executes tools** (Read+Write ran, no approval, no hang) and wrote `answer_probe2.txt`. Proves creator posture = plain `-p` + `--add-dir`. |
| 0b | `--plan` compatibility | `kimi -p "…" --output-format stream-json --plan --add-dir .` | 1 | ~2s | **`--plan` cannot combine with `-p`** ("Cannot combine --prompt with --plan"). No API call → plan-mode is NOT a headless critic option. |
| 3 | critic read-only posture | `kimi -p "<create a file>" --output-format stream-json --agent-file readonly_critic.agent.md --add-dir .` | 0 | 8s | **Agent-file `tools:` allowlist denies writes.** With `tools: [Read,Grep,Glob,List]` the model had **no Write tool** and refused; **no file was written**. This is prevention, not just detection. |
| 4 | large (72 KB) prompt via pointer | `kimi -p "Read the file prompt_probe6.txt and execute its final instruction…" --output-format stream-json --add-dir .` | 0 | 16s | **Pointer carries a large prompt safely** (argv stays tiny; the 72 KB file is read as a tool call). Answer `LARGEOK`. |
| 5 | auth-failure sim (no real credential) | `USERPROFILE=<tmp> HOME=<tmp> kimi -p "…" --output-format stream-json` | 1 | 1s | **Missing-credential pattern:** stderr `failed to run prompt: No model configured. Run \`kimi\` and use /login to sign in`. Config resolves via `USERPROFILE`/`HOME` → a SYSTEM run must set them to the agent home. Real credential untouched. |
| — | adapter end-to-end smoke | via `kimi_adapter.run_kimi(role=research …)` | 0 | 17.6s | **Choke point works live:** status `ok`, text `SMOKEOK`, one `qm.kimi-usage/v1` ledger line, governor evaluated NORMAL (1/40 day, 1/200 week), flag not set, `usage: null` (never invented), prompt body absent from argv. |

## Learned facts (drive the adapter + config)

### 1. stream-json event schema (JSONL, one object per line)
```
{"role":"meta","type":"system.version","version":"0.43.1"}                 # version banner (first line)
{"role":"assistant","tool_calls":[{"type":"function","id":"…","function":{"name":"Read","arguments":"…"}}]}  # a tool call (no content)
{"role":"tool","tool_call_id":"…","content":"…"}                            # tool result
{"role":"assistant","content":"BANANA42"}                                   # assistant text
{"role":"meta","type":"session.resume_hint","session_id":"…","command":"…","content":"To resume this session: …"}
```
**Parser rule:** the final assistant text = the **last** line with `role=="assistant"` **and** a non-empty string
`content`. Ignore assistant lines carrying only `tool_calls`, all `tool` lines, and all `meta` lines. Tolerate
blank / non-JSON lines and unknown roles/types (the CLI auto-updates). No `thinking` event appeared in stream-json
output. `cli_version` is read from the `system.version` meta line — no extra `--version` spawn needed.

### 2. stdin / argv / flag rules
- `-p <prompt>` runs one prompt non-interactively **and auto-runs tools without approval or hang** — so **no
  `--auto` is needed, and `--auto` is in fact forbidden with `-p`**. `--plan` is likewise forbidden with `-p`.
- **Prompt delivery = a prompt FILE + a short argv pointer** (like the agy lane). Proven to carry ≥72 KB safely
  while keeping argv tiny (avoids the ~32 KB Windows cmdline cap). The prompt body never appears in argv.
- The child process is started with **stdin = DEVNULL** (stdin is not the prompt channel; the pointer is).

### 3. Critic posture that actually denies writes
`--agent-file <md>` with YAML front-matter `tools:` listing only read tools (`Read, Grep, Glob, List`) removes the
Write/Edit/Bash tools from the session entirely — the model cannot write and says so. The adapter **materializes**
this agent file into `out_dir` at call time (content lives in `config/kimi_adapter.v1.json →
critic_agent_file_content`), passes `--agent-file`, and additionally computes a `git status --porcelain` hash of
`C:/QM/repo` **before/after**; if the repo changed on a critic run, status becomes `critic_wrote` and the text is
discarded (detection belt behind the prevention). `--plan` is **not** usable headless (forbidden with `-p`).

### 4. Auth / credential
Missing credential → exit 1, stderr matches `No model configured` / `/login` / `sign in`. Never retried. Config is
resolved via `USERPROFILE`/`HOME`; the adapter sets them to `C:\Users\Administrator` so the OAuth credential
resolves under SYSTEM. Only the credential **file path** is ever reported — never its contents.

### 5. No usage/quota telemetry
stream-json prints **no** usage/quota indicator. `usage` is recorded as `null` and never invented; the governor's
state JSON carries `usage_source: "local_ledger_only"`.

## Named D:/QM paths touched by the live probe (only via the adapter)
- Usage ledger: `D:/QM/reports/state/kimi_usage_ledger.jsonl` (first `qm.kimi-usage/v1` line written by the smoke).
- Low-quota flag: `D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag` (evaluated, not set — state NORMAL).

All other adapter/governor side-effect paths were redirected into `.kimi_scratch/` for the smoke.
