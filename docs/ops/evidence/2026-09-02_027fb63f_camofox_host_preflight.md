# camofox-browser evaluation — host pre-flight (Phase 1 blocked)

- Router task: `027fb63f-07a8-4799-a3e3-5c6fd3558d4b` (claude, `ops_issue`, priority 55)
- OWNER authorization: 2026-09-01 — camofox-browser as scraping backend for research lanes
- Upstream: `https://github.com/jo-inc/camofox-browser` (MIT), localhost REST API port 9377
- Cycle: claude orchestration, 2026-09-02 ~10:50Z
- Mode: **read-only pre-flight.** Nothing installed, enabled, configured, or started.

## Verdict — Phase 1 cannot start without an OWNER-window reboot

Camofox on Windows runs **via Docker or WSL2 only**. Neither is present on this
host, and **neither can be enabled without a reboot** of a factory-critical
machine running T1–T10 plus T_Live.

Measured on the host:

| capability | state | evidence |
|---|---|---|
| `Microsoft-Windows-Subsystem-Linux` | **Disabled** | `Get-WindowsOptionalFeature -Online` |
| `VirtualMachinePlatform` | **Disabled** | `Get-WindowsOptionalFeature -Online` |
| WSL distros installed | **none** | `wsl.exe -l -v` returns usage text, no distro list |
| Docker | **not installed** | `Get-Command docker` → not found |

Enabling `Microsoft-Windows-Subsystem-Linux` + `VirtualMachinePlatform` is a
Windows optional-feature change that **requires a restart**. Docker Desktop
additionally depends on the same virtualization stack.

**This is an OWNER-window action, not an agent action.** It is outside this
task's own guardrails, which state "NO factory config changes, NO scheduled
tasks, NO touching T_Live or worker paths" — a host reboot is a larger
intervention than any of those.

Task status left `IN_PROGRESS` → surfaced to REVIEW as **BLOCKED on
precondition**, so the next cycle does not rediscover the same wall.

## Host resource baseline (for the eventual footprint budget)

Captured 2026-09-02 ~10:52Z while the factory was running:

| metric | value |
|---|---|
| RAM total | 63.1 GB |
| RAM free | 27.2 GB |
| Logical CPUs | 16 (1 socket, 8 physical cores, SMT on) |
| CPU utilisation | 61.6% |
| Commit used / limit | 44.5 GB / 122.6 GB (78.1 GB raw headroom) |

**Caveat on the headroom figure — do not read 78.1 GB as spare capacity.** The
terminal workers do not claim against raw commit headroom; they claim against
*effective* headroom after subtracting per-item reservations. Measured the same
morning, that effective figure went **negative** (−2.2 GB) and blocked claims
across T1/T5 with `commit_headroom_low`, against a `threshold_gb` of 24.0
(see `2026-09-02_claude_orchestration_cycle_health_wedge.md` §5).

So the host is **already claim-constrained under its own governor** even while
raw commit looks comfortable. A WSL2 VM or Docker Desktop would add a permanent
resident allocation on top of that. Camofox's advertised ~40 MB idle is
irrelevant here — the cost that matters is the **WSL2/Docker VM baseline**, not
the app, and WSL2's `vmmem` will reserve well beyond 40 MB.

Acceptance criterion (a) — "lightest viable runtime with measured RAM/CPU
footprint idle+active" — therefore has a real answer pending: measure the
**VM baseline**, not the camofox process.

## Acceptance criteria — none met yet

| # | criterion | status |
|---|---|---|
| a | Runtime option chosen with measured RAM/CPU footprint idle+active | **BLOCKED** — no runtime installable without reboot |
| b | Zero factory interference demonstrated | **NOT STARTED** — needs a running instance |
| c | Telemetry off, API-key + localhost binding verified | **NOT STARTED** |
| d | Babypips + YouTube-transcript demo fetch evidence | **NOT STARTED** |
| e | Go/no-go + integration sketch | **NOT REACHED** — see recommendation below |

No go/no-go is claimed. The only thing established is the precondition.

## Recommendation to OWNER

1. **Do not enable WSL2/Docker on this host while it is the factory host.** It is
   already claim-constrained under its own commit governor; adding a resident VM
   competes with backtests for exactly the resource that is currently the
   bottleneck. This is the same constraint the ticket flags ("factory-critical").
2. **Preferred: evaluate camofox off-host.** The REST API binds localhost by
   design, but the research lanes do not need it co-located with the factory.
   A small separate box, or a scheduled window on this host *after* the queue
   drains, both avoid contending with T1–T10.
3. **If on-host is required**, the feature-enable + reboot must be an OWNER
   window with the factory brought down cleanly first — not an inline agent step.
4. Hardening requirements from the ticket remain non-negotiable whenever it does
   run: `CAMOFOX_API_KEY` set, **localhost binding only**,
   `CAMOFOX_CRASH_REPORT_ENABLED=false` (no VPS detail exposure — Hard Rule),
   cookie import disabled.

## Next step

OWNER decision on runtime location (off-host vs on-host reboot window). No agent
work can advance criteria (a)–(d) until that is settled.

## Scope discipline

Read-only inspection only: `Get-WindowsOptionalFeature`, `wsl.exe --status`,
`Get-Command docker`, `Get-CimInstance Win32_OperatingSystem/Win32_ComputerSystem`,
performance counters. **Nothing installed, enabled, downloaded, configured, or
started.** No Windows feature changed, no reboot, no scheduled task, no factory
config change, no T_Live or worker-path touch.

## Evidence sources

- `Get-WindowsOptionalFeature -Online` (WSL / VirtualMachinePlatform state)
- `wsl.exe -l -v`, `wsl.exe --status`, `Get-Command docker`
- `Win32_OperatingSystem`, `Win32_ComputerSystem`,
  `\Memory\Commit Limit`, `\Memory\Committed Bytes`, `\Processor(_Total)\% Processor Time`
- `C:/QM/repo/docs/ops/evidence/2026-09-02_claude_orchestration_cycle_health_wedge.md` (§5, commit-governor behaviour)
- agent_task `027fb63f-07a8-4799-a3e3-5c6fd3558d4b`
