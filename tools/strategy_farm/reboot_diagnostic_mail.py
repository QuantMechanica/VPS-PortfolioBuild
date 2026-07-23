"""Send one evidence-based mail after a Windows reboot.

The factory watchdog writes ``reboot_diagnostic_pending.json`` before it invokes
``shutdown.exe``.  A delayed AtStartup task runs this module after Windows is
back, verifies the matching User32/1074 event, correlates watchdog and resource
history, records the recovery state, and sends one German explanation mail. If
there is no valid watchdog marker, the task still classifies the new boot from
Windows events (planned 1074, BugCheck, Kernel-Power/6008, or unknown).

Each delivery cycle is claimed exclusively on disk before SMTP. Within a cycle,
transient SMTP failures receive two bounded retries; a failed cycle lets Task
Scheduler start up to six later cycles. All cycles use the same deterministic
Message-ID, and a successful cycle permanently closes the boot. This minimizes
both lost mail and duplicate delivery; SMTP itself cannot provide a strict
exactly-once guarantee.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(r"C:\QM\repo")
TOOLS_DIR = REPO_ROOT / "tools" / "strategy_farm"
REPORTS_STATE = Path(r"D:\QM\reports\state")
PENDING_FILE = REPORTS_STATE / "reboot_diagnostic_pending.json"
STATE_FILE = REPORTS_STATE / "reboot_diagnostic_mail_state.json"
WATCHDOG_LOG = REPORTS_STATE / "factory_watchdog.jsonl"
LIVE_WATCHDOG_LOG = REPORTS_STATE / "live_uptime_watchdog.jsonl"
RUN_LOG = REPORTS_STATE / "reboot_diagnostic_mail.jsonl"
REPORT_DIR = Path(r"D:\QM\reports\reboot_diagnostics")
MULTISYMBOL_REGISTRY = Path(r"D:\QM\strategy_farm\state\multisymbol_eas.txt")

EXPECTED_SOURCE = "QM_StrategyFarm_FactoryWatchdog_15min"
EXPECTED_KIND = "session_loss_heal"
MAX_MARKER_AGE_HOURS = 24
MAX_BOOT_REPORT_AGE_HOURS = 24
CLAIM_STALE_SECONDS = 4 * 60
PROVIDER_USER32 = "user32"
PROVIDER_KERNEL_POWER = "microsoft-windows-kernel-power"
PROVIDER_EVENTLOG = "eventlog"
PROVIDER_BUGCHECK = frozenset(
    {
        "bugcheck",
        "microsoft-windows-wer-systemerrorreporting",
    }
)


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(value: dt.datetime | None = None) -> str:
    return (value or _utc_now()).astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse_ts(value: Any) -> dt.datetime | None:
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc)
    except (TypeError, ValueError):
        return None


def _local_text(value: dt.datetime | None) -> str:
    if value is None:
        return "unbekannt"
    return value.astimezone().strftime("%d.%m.%Y %H:%M:%S")


def _read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _read_state(path: Path) -> tuple[dict[str, Any], str]:
    """Read primary state, falling back to the last atomically saved copy."""

    def read_candidate(candidate: Path) -> dict[str, Any] | None:
        try:
            data = json.loads(candidate.read_text(encoding="utf-8-sig"))
            if (
                not isinstance(data, dict)
                or int(data.get("schema") or 0) != 1
                or not isinstance(data.get("events"), dict)
                or _parse_ts(data.get("last_observed_boot_utc")) is None
            ):
                return None
            return data
        except (OSError, TypeError, ValueError):
            return None

    primary_exists = path.exists()
    if primary_exists:
        primary = read_candidate(path)
        if primary is not None:
            return primary, "primary"
    backup = path.with_name(f"{path.name}.bak")
    backup_exists = backup.exists()
    if backup_exists:
        recovered = read_candidate(backup)
        if recovered is not None:
            return recovered, "backup"
    return {}, "corrupt" if primary_exists or backup_exists else "missing"


def _atomic_write_json(
    path: Path,
    data: dict[str, Any],
    *,
    keep_backup: bool = False,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    serialized = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    tmp.write_text(serialized, encoding="utf-8")
    os.replace(tmp, path)
    if keep_backup:
        backup = path.with_name(f"{path.name}.bak")
        backup_tmp = backup.with_name(f"{backup.name}.{os.getpid()}.tmp")
        backup_tmp.write_text(serialized, encoding="utf-8")
        os.replace(backup_tmp, backup)


def _pid_alive(pid: Any) -> bool:
    try:
        process_id = int(pid)
    except (TypeError, ValueError):
        return False
    if process_id <= 0:
        return False
    if sys.platform == "win32":
        try:
            import ctypes

            process_query_limited_information = 0x1000
            still_active = 259
            handle = ctypes.windll.kernel32.OpenProcess(
                process_query_limited_information,
                False,
                process_id,
            )
            if not handle:
                return False
            try:
                exit_code = ctypes.c_ulong(0)
                return bool(
                    ctypes.windll.kernel32.GetExitCodeProcess(
                        handle,
                        ctypes.byref(exit_code),
                    )
                ) and exit_code.value == still_active
            finally:
                ctypes.windll.kernel32.CloseHandle(handle)
        except Exception:
            return False
    try:
        os.kill(process_id, 0)
        return True
    except OSError:
        return False


def _process_started_utc(pid: Any) -> dt.datetime | None:
    """Return a Windows process creation timestamp to defeat PID reuse."""

    if sys.platform != "win32":
        return None
    try:
        import ctypes

        process_id = int(pid)

        class FILETIME(ctypes.Structure):
            _fields_ = [
                ("low", ctypes.c_ulong),
                ("high", ctypes.c_ulong),
            ]

        handle = ctypes.windll.kernel32.OpenProcess(0x1000, False, process_id)
        if not handle:
            return None
        try:
            created = FILETIME()
            exited = FILETIME()
            kernel = FILETIME()
            user = FILETIME()
            if not ctypes.windll.kernel32.GetProcessTimes(
                handle,
                ctypes.byref(created),
                ctypes.byref(exited),
                ctypes.byref(kernel),
                ctypes.byref(user),
            ):
                return None
            ticks = (int(created.high) << 32) | int(created.low)
            unix_seconds = (ticks - 116444736000000000) / 10_000_000
            return dt.datetime.fromtimestamp(unix_seconds, tz=dt.timezone.utc)
        finally:
            ctypes.windll.kernel32.CloseHandle(handle)
    except (OSError, TypeError, ValueError):
        return None


def _claim_owner_alive(
    claim: dict[str, Any],
    current: dt.datetime | None = None,
) -> bool:
    owner_pid = claim.get("claim_owner_pid")
    if owner_pid and _pid_alive(owner_pid):
        expected_started = _parse_ts(claim.get("claim_owner_started_utc"))
        if expected_started is not None:
            actual_started = _process_started_utc(owner_pid)
            if actual_started is not None:
                return abs((actual_started - expected_started).total_seconds()) < 1
            # If Windows temporarily refuses GetProcessTimes, prefer duplicate
            # suppression while the exact PID is still alive.
            return True
        claimed_at = _parse_ts(claim.get("claimed_at_utc"))
        if claimed_at is None:
            return True
        return ((current or _utc_now()) - claimed_at).total_seconds() < CLAIM_STALE_SECONDS
    if owner_pid:
        return False
    claimed_at = _parse_ts(claim.get("claimed_at_utc"))
    if claimed_at is None:
        return True
    return ((current or _utc_now()) - claimed_at).total_seconds() < CLAIM_STALE_SECONDS


def _claimed_delivery_abandoned(
    event: dict[str, Any],
    current: dt.datetime | None = None,
) -> bool:
    if str(event.get("status") or "") != "claimed":
        return False
    return not _claim_owner_alive(event, current)


def _claim_file_abandoned(
    claim_path: Path,
    current: dt.datetime | None = None,
) -> bool:
    claim = _read_json(claim_path)
    if claim:
        return not _claim_owner_alive(claim, current)
    try:
        claimed_at = dt.datetime.fromtimestamp(
            claim_path.stat().st_mtime,
            tz=dt.timezone.utc,
        )
    except OSError:
        return False
    return ((current or _utc_now()) - claimed_at).total_seconds() >= CLAIM_STALE_SECONDS


def _append_log(record: dict[str, Any], path: Path = RUN_LOG) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
    except OSError:
        pass


def _read_jsonl(path: Path, limit: int = 500) -> list[dict[str, Any]]:
    try:
        lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines()[-limit:]
    except OSError:
        return []
    records: list[dict[str, Any]] = []
    for line in lines:
        try:
            item = json.loads(line)
        except ValueError:
            continue
        if isinstance(item, dict):
            records.append(item)
    return records


def _powershell_json(script: str, timeout: int = 45) -> dict[str, Any]:
    completed = subprocess.run(
        (
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            script,
        ),
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    if completed.returncode != 0:
        raise RuntimeError((completed.stderr or completed.stdout or "PowerShell failed").strip())
    raw = completed.stdout.strip()
    if not raw:
        raise RuntimeError("PowerShell returned no diagnostic JSON")
    try:
        data = json.loads(raw)
    except ValueError as exc:
        raise RuntimeError(f"PowerShell returned invalid JSON: {raw[-500:]}") from exc
    if not isinstance(data, dict):
        raise RuntimeError("PowerShell diagnostic root is not an object")
    return data


def collect_windows_context() -> dict[str, Any]:
    """Collect persistent reboot events plus the post-boot recovery state."""

    script = r"""
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$os = Get-CimInstance Win32_OperatingSystem
$bootLocal = $os.LastBootUpTime
$boot = $bootLocal.ToUniversalTime()
# Get-WinEvent interprets FilterHashtable StartTime/EndTime in local time on
# Windows PowerShell 5.1, even when passed a DateTime whose Kind is UTC.
$windowStart = $bootLocal.AddHours(-2)
$windowEnd = $bootLocal.AddMinutes(15)

function Convert-EventRow {
    param($Event)
    $message = ''
    try { $message = [string]$Event.Message } catch {}
    if ($message.Length -gt 1800) { $message = $message.Substring(0, 1800) }
    [pscustomobject]@{
        id = [int]$Event.Id
        record_id = [int64]$Event.RecordId
        provider = [string]$Event.ProviderName
        time_utc = $Event.TimeCreated.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        message = $message
    }
}

$systemEvents = @()
try {
    $systemEvents = @(Get-WinEvent -FilterHashtable @{
        LogName='System'; StartTime=$windowStart; EndTime=$windowEnd;
        Id=@(26,41,1074,109,6005,6006,6008,1001)
    } -MaxEvents 80 | ForEach-Object { Convert-EventRow $_ })
} catch {}

$applicationEvents = @()
try {
    $applicationEvents = @(Get-WinEvent -FilterHashtable @{
        LogName='Application'; StartTime=$windowStart; EndTime=$windowEnd; Id=26
    } -MaxEvents 20 | ForEach-Object { Convert-EventRow $_ })
} catch {}

$sessionEvents = @()
try {
    $sessionEvents = @(Get-WinEvent -FilterHashtable @{
        LogName='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational';
        StartTime=$windowStart; EndTime=$windowEnd; Id=@(23,24,40,41,45)
    } -MaxEvents 50 | ForEach-Object { Convert-EventRow $_ })
} catch {}

$taskEvents = @()
try {
    $taskEvents = @(Get-WinEvent -FilterHashtable @{
        LogName='Microsoft-Windows-TaskScheduler/Operational';
        StartTime=$bootLocal.AddMinutes(-45); EndTime=$bootLocal.AddMinutes(2); Id=201
    } -MaxEvents 1000 | ForEach-Object { Convert-EventRow $_ })
} catch {}

$processes = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe' OR Name='terminal64.exe'")
$workers = @($processes | Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
$factoryTerminals = @($processes | Where-Object {
    $_.Name -eq 'terminal64.exe' -and $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\'
}).Count
$liveTerminals = @($processes | Where-Object {
    $_.Name -eq 'terminal64.exe' -and ($_.CommandLine -match 'T_Live' -or $_.CommandLine -match 'FTMO')
}).Count

$targetUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon').DefaultUserName
if (-not $targetUser) { $targetUser = 'qm-admin' }
$sessionExists = $false
$sessionState = $null
foreach ($line in @(qwinsta 2>$null)) {
    if (($line -match "\b$([regex]::Escape($targetUser))\b") -and
        ($line -match "\s\d+\s+(Active|Disc|Conn)\b")) {
        $sessionExists = $true
        $sessionState = $matches[1]
    }
}

$factoryOnResult = $null
try {
    $factoryOnResult = (Get-ScheduledTaskInfo -TaskName 'QM_StrategyFarm_FactoryON_AtLogon').LastTaskResult
} catch {}

[pscustomobject]@{
    computer = [string]$env:COMPUTERNAME
    boot_utc = $boot.ToString('yyyy-MM-ddTHH:mm:ssZ')
    collected_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    system_events = $systemEvents
    application_events = $applicationEvents
    session_events = $sessionEvents
    task_events = $taskEvents
    recovery = [pscustomobject]@{
        target_user = $targetUser
        session_exists = $sessionExists
        session_state = $sessionState
        workers = $workers
        factory_terminals = $factoryTerminals
        live_terminals = $liveTerminals
        factory_on_last_result = $factoryOnResult
    }
} | ConvertTo-Json -Depth 7 -Compress
"""
    return _powershell_json(script)


def _events(context: dict[str, Any], key: str) -> list[dict[str, Any]]:
    value = context.get(key) or []
    if isinstance(value, dict):
        return [value]
    return [item for item in value if isinstance(item, dict)]


def _provider_is(event: dict[str, Any], *expected: str) -> bool:
    """Match Windows event provenance by normalized full provider name."""

    provider = str(event.get("provider") or "").strip().casefold()
    return provider in {name.casefold() for name in expected}


def validate_incident(
    incident: dict[str, Any],
    context: dict[str, Any],
    now: dt.datetime | None = None,
) -> tuple[bool, str, dict[str, Any] | None]:
    """Require a fresh known marker and its exact planned-shutdown event."""

    current = now or _utc_now()
    if incident.get("source") != EXPECTED_SOURCE or incident.get("kind") != EXPECTED_KIND:
        return False, "unknown_marker_contract", None
    event_id = str(incident.get("event_id") or "").strip()
    requested = _parse_ts(incident.get("requested_at_utc"))
    boot = _parse_ts(context.get("boot_utc"))
    if not event_id or requested is None or boot is None:
        return False, "marker_missing_id_or_time", None
    try:
        uuid.UUID(event_id)
    except ValueError:
        return False, "marker_invalid_event_id", None
    age_hours = (current - requested).total_seconds() / 3600
    if age_hours < 0 or age_hours > MAX_MARKER_AGE_HOURS:
        return False, "marker_stale", None
    if boot <= requested or (boot - requested).total_seconds() > 30 * 60:
        return False, "marker_does_not_precede_current_boot", None

    system_events = _events(context, "system_events")
    expected_comment = str(incident.get("shutdown_comment") or "").strip()
    if not expected_comment:
        return False, "marker_missing_shutdown_comment", None
    preboot_1074 = [
        event
        for event in system_events
        if (
            int(event.get("id") or 0) == 1074
            and _provider_is(event, PROVIDER_USER32)
            and (event_time := _parse_ts(event.get("time_utc"))) is not None
            and event_time < boot
        )
    ]
    latest_preboot_1074 = max(
        preboot_1074,
        key=lambda item: _parse_ts(item.get("time_utc")) or requested,
        default=None,
    )
    matching_1074: list[dict[str, Any]] = []
    for event in preboot_1074:
        message = str(event.get("message") or "")
        event_time = _parse_ts(event.get("time_utc"))
        if expected_comment not in message:
            continue
        if event_time is None or abs((event_time - requested).total_seconds()) > 10 * 60:
            continue
        matching_1074.append(event)
    if not matching_1074:
        return False, "matching_user32_1074_missing", None
    matching_event = max(
        matching_1074,
        key=lambda item: _parse_ts(item.get("time_utc")) or requested,
    )
    if latest_preboot_1074 is not matching_event:
        return False, "marker_shutdown_event_superseded", None
    event_time = _parse_ts(matching_event.get("time_utc"))
    assert event_time is not None
    if (boot - event_time).total_seconds() > 10 * 60:
        return False, "marker_shutdown_event_not_for_current_boot", None
    intervening_boot = any(
        int(other.get("id") or 0) == 6005
        and _provider_is(other, PROVIDER_EVENTLOG)
        and (other_time := _parse_ts(other.get("time_utc"))) is not None
        and event_time < other_time < boot
        for other in system_events
    )
    if intervening_boot:
        return False, "marker_precedes_another_boot", None
    return True, "verified", matching_event


def _generic_boot_incident(
    context: dict[str, Any],
    ignored_event: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Build a deterministic incident from persistent Windows boot events."""

    boot = _parse_ts(context.get("boot_utc"))
    if boot is None:
        raise ValueError("windows context has no valid boot_utc")
    all_events = [
        event
        for event in _events(context, "system_events")
        if event is not ignored_event
    ]

    def latest(
        ids: set[int],
        *,
        start: dt.datetime,
        end: dt.datetime,
        providers: tuple[str, ...] = (),
        providers_by_id: dict[int, tuple[str, ...]] | None = None,
    ) -> dict[str, Any] | None:
        matches = []
        for event in all_events:
            event_id = int(event.get("id") or 0)
            if event_id not in ids:
                continue
            event_time = _parse_ts(event.get("time_utc"))
            if event_time is None or not start <= event_time <= end:
                continue
            provider = str(event.get("provider") or "").strip().casefold()
            expected_providers = (
                (providers_by_id or {}).get(event_id, providers)
            )
            if expected_providers and provider not in expected_providers:
                continue
            matches.append(event)
        return max(matches, key=lambda item: _parse_ts(item.get("time_utc")) or start, default=None)

    planned = latest(
        {1074},
        start=boot - dt.timedelta(minutes=30),
        end=boot - dt.timedelta(microseconds=1),
        providers=(PROVIDER_USER32,),
    )
    bugcheck = latest(
        {1001},
        start=boot - dt.timedelta(minutes=2),
        end=boot + dt.timedelta(minutes=15),
        providers=tuple(PROVIDER_BUGCHECK),
    )
    unexpected = latest(
        {41, 6008},
        start=boot - dt.timedelta(minutes=2),
        end=boot + dt.timedelta(minutes=15),
        providers_by_id={
            41: (PROVIDER_KERNEL_POWER,),
            6008: (PROVIDER_EVENTLOG,),
        },
    )
    clean_kernel = latest(
        {109, 6006},
        start=boot - dt.timedelta(minutes=5),
        end=boot - dt.timedelta(microseconds=1),
        providers_by_id={
            109: (PROVIDER_KERNEL_POWER,),
            6006: (PROVIDER_EVENTLOG,),
        },
    )
    for candidate_name, candidate in (("planned", planned), ("clean_kernel", clean_kernel)):
        if candidate is None:
            continue
        candidate_time = _parse_ts(candidate.get("time_utc"))
        if candidate_time is None:
            continue
        superseded = any(
            int(event.get("id") or 0) == 6005
            and _provider_is(event, PROVIDER_EVENTLOG)
            and (event_time := _parse_ts(event.get("time_utc"))) is not None
            and candidate_time < event_time < boot
            for event in all_events
        )
        if superseded:
            if candidate_name == "planned":
                planned = None
            else:
                clean_kernel = None
    planned_message = str((planned or {}).get("message") or "")
    watchdog_planned = "qm factory_watchdog" in planned_message.lower()

    if bugcheck is not None:
        trigger_class = "bugcheck"
        trigger_title = "Windows-Systemabsturz (BugCheck)"
        trigger_summary = (
            "Windows protokollierte einen BugCheck. Das ist ein ungeplanter "
            "Systemabsturz; der Eventtext enthält den belastbarsten verfügbaren Hinweis."
        )
        confidence = "hoch"
        trigger_event = bugcheck
    elif unexpected is not None and planned is not None:
        trigger_class = "planned_unclean"
        trigger_title = (
            "Geplanter QM-Watchdog-Neustart mit unsauberem Abschluss"
            if watchdog_planned
            else "Geplanter Neustart mit unsauberem Abschluss"
        )
        trigger_summary = (
            "Event 1074 dokumentiert eine geplante Neustartabsicht; Kernel-Power "
            "oder Event 6008 zeigt zugleich, dass der vorherige Systemlauf nicht "
            "ordnungsgemäß abgeschlossen wurde."
        )
        confidence = "hoch"
        trigger_event = unexpected
    elif unexpected is not None:
        trigger_class = "unexpected"
        trigger_title = "Ungeplanter Neustart / unsauberes Herunterfahren"
        trigger_summary = (
            "Kernel-Power/EventLog meldet, dass Windows zuvor nicht sauber "
            "heruntergefahren wurde. Stromverlust, Reset oder Systemstillstand "
            "lassen sich daraus allein nicht eindeutig unterscheiden."
        )
        confidence = "mittel"
        trigger_event = unexpected
    elif planned is not None:
        trigger_class = "planned"
        trigger_title = (
            "Geplanter QM-Factory-Watchdog-Neustart"
            if watchdog_planned
            else "Geplanter Windows-Neustart"
        )
        trigger_summary = (
            "Windows Event 1074 nennt den Prozess, Benutzer und Grund, "
            "die den Neustart angefordert haben."
        )
        confidence = "hoch"
        trigger_event = planned
    elif clean_kernel is not None:
        trigger_class = "clean_shutdown"
        trigger_title = "Sauber eingeleiteter Windows-Neustart"
        trigger_summary = (
            "Kernel/EventLog zeigt eine reguläre Shutdown-Sequenz, aber keinen "
            "eindeutigen Initiator in Event 1074."
        )
        confidence = "mittel"
        trigger_event = clean_kernel
    else:
        trigger_class = "unknown"
        trigger_title = "Neustart ohne eindeutigen Windows-Auslöser"
        trigger_summary = (
            "Im verfügbaren Ereignisfenster fehlt ein eindeutiger geplanter, "
            "BugCheck- oder Kernel-Power-Auslöser."
        )
        confidence = "begrenzt"
        trigger_event = None

    event_time = _parse_ts((trigger_event or {}).get("time_utc"))
    requested = min(event_time, boot) if event_time is not None else boot
    event_id = str(
        uuid.uuid5(
            uuid.NAMESPACE_URL,
            "https://quantmechanica.local/windows-boot/"
            f"{context.get('computer') or 'unknown'}/{_iso(boot)}",
        )
    )
    return {
        "schema": 1,
        "event_id": event_id,
        "source": "WindowsEventLog",
        "kind": "windows_boot",
        "requested_at_utc": _iso(requested),
        "boot_utc": _iso(boot),
        "trigger_class": trigger_class,
        "trigger_title": trigger_title,
        "trigger_summary": trigger_summary,
        "trigger_confidence": confidence,
        "trigger_event": trigger_event,
        "evidence_events": [
            event
            for event in (bugcheck, unexpected, planned, clean_kernel)
            if event is not None
        ],
    }


def _window_records(
    records: list[dict[str, Any]],
    start: dt.datetime,
    end: dt.datetime,
) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    for record in records:
        stamp = _parse_ts(record.get("ts"))
        if stamp and start <= stamp <= end and record.get("action") != "heartbeat":
            selected.append(record)
    return selected


def _multisymbol_ids() -> set[str]:
    try:
        return {
            line.strip().split()[0]
            for line in MULTISYMBOL_REGISTRY.read_text(encoding="utf-8-sig").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
    except OSError:
        return set()


def _as_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def analyze_incident(
    incident: dict[str, Any],
    context: dict[str, Any],
    watchdog_records: list[dict[str, Any]],
    live_records: list[dict[str, Any]],
) -> dict[str, Any]:
    requested = _parse_ts(incident.get("requested_at_utc")) or _utc_now()
    pending_since = _parse_ts(incident.get("pending_since_utc"))
    boot = _parse_ts(context.get("boot_utc"))
    window_start = (pending_since or requested).replace() - dt.timedelta(minutes=20)
    preboot_end = (boot or requested) - dt.timedelta(microseconds=1)
    watchdog_window = _window_records(watchdog_records, window_start, preboot_end)
    live_window = _window_records(live_records, window_start, preboot_end)

    lost = [record for record in watchdog_window if record.get("session_lost")]
    healthy = [
        record
        for record in watchdog_window
        if not record.get("session_lost") and int(record.get("workers") or 0) > 0
    ]
    last_healthy = healthy[-1] if healthy else None
    first_lost = lost[0] if lost else None

    resource_candidates = [
        record.get("resource")
        for record in watchdog_window
        if isinstance(record.get("resource"), dict) and not record["resource"].get("error")
    ]
    if isinstance(incident.get("resource_snapshot"), dict):
        resource_candidates.append(incident["resource_snapshot"])
    pre_resource = (
        last_healthy.get("resource")
        if last_healthy and isinstance(last_healthy.get("resource"), dict)
        else (resource_candidates[-1] if resource_candidates else {})
    )
    pre_resource = pre_resource or {}

    commit_percent = _as_float(pre_resource.get("commit_percent"))
    commit_headroom = _as_float(pre_resource.get("commit_headroom_gb"))
    pagefile_percent = _as_float(pre_resource.get("pagefile_percent"))
    pages_per_sec = _as_float(pre_resource.get("pages_per_sec"))
    top_processes = pre_resource.get("top_processes") or []
    if isinstance(top_processes, dict):
        top_processes = [top_processes]
    top_processes = [item for item in top_processes if isinstance(item, dict)]
    largest = max(top_processes, key=lambda item: _as_float(item.get("private_gb")) or 0, default=None)
    largest_private = _as_float((largest or {}).get("private_gb"))

    pressure_signals: list[str] = []
    commit_critical = (
        (commit_percent is not None and commit_percent >= 90)
        or (commit_headroom is not None and commit_headroom <= 8)
    )
    pagefile_critical = pagefile_percent is not None and pagefile_percent >= 95
    paging_critical = pages_per_sec is not None and pages_per_sec >= 5000
    large_process = largest_private is not None and largest_private >= 12
    if commit_percent is not None and commit_percent >= 90:
        pressure_signals.append(f"Commit {commit_percent:.1f}%")
    if commit_headroom is not None and commit_headroom <= 8:
        pressure_signals.append(f"nur {commit_headroom:.1f} GB Commit-Reserve")
    if pagefile_percent is not None and pagefile_percent >= 95:
        pressure_signals.append(f"Pagefile {pagefile_percent:.1f}% belegt")
    elif pagefile_percent is not None and pagefile_percent >= 85:
        pressure_signals.append(f"Pagefile {pagefile_percent:.1f}% belegt")
    if pages_per_sec is not None and pages_per_sec >= 5000:
        pressure_signals.append(f"{pages_per_sec:,.0f} Pages/s".replace(",", "."))
    if largest and largest_private is not None and largest_private >= 12:
        pressure_signals.append(
            f"größter Prozess {largest.get('name', '?')} PID {largest.get('pid', '?')} "
            f"mit {largest_private:.1f} GB Private Bytes"
        )

    relevant_start = window_start
    relevant_end = preboot_end
    memory_events = _events(context, "application_events") + [
        event
        for event in _events(context, "system_events")
        if int(event.get("id") or 0) == 26
    ]
    relevant_application_events = [
        event
        for event in memory_events
        if (
            (event_time := _parse_ts(event.get("time_utc"))) is not None
            and relevant_start <= event_time <= relevant_end
        )
    ]
    memory_warning = any(
        "virtual memory" in str(event.get("message") or "").lower()
        or "virtueller speicher" in str(event.get("message") or "").lower()
        for event in relevant_application_events
    )
    if memory_warning:
        pressure_signals.append("Windows-Warnung zu niedrigem virtuellem Speicher")

    dll_init_failures = [
        event
        for event in _events(context, "task_events")
        if (
            (event_time := _parse_ts(event.get("time_utc"))) is not None
            and relevant_start <= event_time <= relevant_end
            and (
                "3221225794" in str(event.get("message") or "")
                or "0xc0000142" in str(event.get("message") or "").lower()
            )
        )
    ]
    if dll_init_failures:
        prefix = "mehrere Prozessstarts" if len(dll_init_failures) > 1 else "ein Prozessstart"
        pressure_signals.append(f"{prefix} scheiterten mit 0xC0000142 (DLL_INIT_FAILED)")

    # Pagefile occupancy alone is not a commit-exhaustion proof: Windows may
    # retain old pages while tens of GB of commit headroom remain.  "High"
    # therefore requires a critical commit signal plus independent support, or
    # an explicit low-virtual-memory warning plus two corroborating signals.
    strong_pressure = (
        commit_critical
        and (pagefile_critical or paging_critical or memory_warning or bool(dll_init_failures))
    ) or (
        memory_warning
        and sum((pagefile_critical, paging_critical, large_process, bool(dll_init_failures))) >= 2
    )
    acute_signal = commit_critical or paging_critical or memory_warning or bool(dll_init_failures)
    moderate_pressure = (
        acute_signal
        and sum(
            (
                commit_critical,
                pagefile_critical,
                paging_critical,
                large_process,
                memory_warning,
                bool(dll_init_failures),
            )
        )
        >= 2
    )

    unexpected_start = (boot or requested) - dt.timedelta(minutes=2)
    unexpected_end = (boot or requested) + dt.timedelta(minutes=15)
    unexpected = [
        event
        for event in _events(context, "system_events")
        if (
            (event_time := _parse_ts(event.get("time_utc"))) is not None
            and unexpected_start <= event_time <= unexpected_end
            and (
                (
                    int(event.get("id") or 0) == 41
                    and _provider_is(event, PROVIDER_KERNEL_POWER)
                )
                or (
                    int(event.get("id") or 0) == 6008
                    and _provider_is(event, PROVIDER_EVENTLOG)
                )
                or (
                    int(event.get("id") or 0) == 1001
                    and _provider_is(event, *PROVIDER_BUGCHECK)
                )
            )
        )
    ]
    lsm_terminate_hung = any(
        int(event.get("id") or 0) == 45
        and (event_time := _parse_ts(event.get("time_utc"))) is not None
        and relevant_start <= event_time <= relevant_end
        for event in _events(context, "session_events")
    )

    live_session_absent = [
        record
        for record in live_window
        if record.get("target_session_exists") is False
    ]
    live_both_down = [
        record
        for record in live_window
        if record.get("dxz_running") is False and record.get("ftmo_running") is False
    ]

    active_items = []
    if last_healthy:
        active_items = last_healthy.get("active_items") or []
    if not active_items:
        active_items = incident.get("active_items") or []
    if isinstance(active_items, dict):
        active_items = [active_items]
    active_items = [item for item in active_items if isinstance(item, dict)]
    multisymbol = _multisymbol_ids()
    for item in active_items:
        item["registry_multisymbol"] = str(item.get("ea_id") or "") in multisymbol

    if strong_pressure:
        root_cause = (
            "Mit hoher Wahrscheinlichkeit Ressourcenerschöpfung im interaktiven "
            "Windows-/MT5-Kontext, insbesondere Commit-/Pagefile-Druck."
        )
        confidence = "hoch"
    elif moderate_pressure:
        root_cause = (
            "Mit erhöhter Wahrscheinlichkeit Ressourcendruck im interaktiven "
            "Windows-/MT5-Kontext; die Signale sprechen für Commit-/Pagefile-Druck, "
            "beweisen aber nicht den einzelnen auslösenden Prozess."
        )
        confidence = "mittel-hoch"
    elif pressure_signals:
        root_cause = (
            "Ressourcendruck ist plausibel, aber die gespeicherten Signale reichen "
            "für eine eindeutige automatische Zuordnung nicht aus."
        )
        confidence = "mittel"
    else:
        root_cause = (
            "Die tiefere technische Ursache ist aus den automatisch gespeicherten "
            "Signalen nicht eindeutig beweisbar."
        )
        confidence = "begrenzt"

    return {
        "requested": requested,
        "pending_since": pending_since,
        "boot": boot,
        "first_lost": first_lost,
        "last_healthy": last_healthy,
        "watchdog_window": watchdog_window,
        "live_window": live_window,
        "live_session_absent": bool(live_session_absent),
        "live_both_down": bool(live_both_down),
        "lsm_terminate_hung": lsm_terminate_hung,
        "dll_init_failure_count": len(dll_init_failures),
        "unexpected_events": unexpected,
        "resource": pre_resource,
        "pressure_signals": pressure_signals,
        "root_cause": root_cause,
        "confidence": confidence,
        "active_items": active_items,
    }


def _fmt_num(value: Any, suffix: str = "") -> str:
    number = _as_float(value)
    return "n/a" if number is None else f"{number:.1f}{suffix}"


def build_mail(
    incident: dict[str, Any],
    context: dict[str, Any],
    analysis: dict[str, Any],
) -> tuple[str, str, str]:
    boot = analysis.get("boot")
    date_part = boot.astimezone().strftime("%d.%m.%Y %H:%M") if boot else "Zeit unbekannt"
    subject = f"[QM] Neustart erklärt — Factory-Watchdog · {date_part}"

    expected = int(incident.get("expected_workers") or 0)
    first_lost = analysis.get("first_lost") or {}
    last_healthy = analysis.get("last_healthy") or {}
    recovery = context.get("recovery") or {}
    if not isinstance(recovery, dict):
        recovery = {}
    resource = analysis.get("resource") or {}
    pressure = analysis.get("pressure_signals") or []
    unexpected = analysis.get("unexpected_events") or []
    evidence_signals = list(pressure)
    if analysis.get("live_session_absent"):
        evidence_signals.append("unabhängiger Live-Watchdog bestätigte: Zielsitzung nicht vorhanden")
    if analysis.get("live_both_down"):
        evidence_signals.append("DXZ- und FTMO-Terminal waren gleichzeitig nicht mehr vorhanden")
    if analysis.get("lsm_terminate_hung"):
        evidence_signals.append("Windows meldete eine verzögerte Sitzungsbeendigung (LSM Event 45)")
    if unexpected:
        unexpected_ids = sorted({int(event.get("id") or 0) for event in unexpected})
        evidence_signals.append(
            "Windows meldete zusätzlich einen unsauberen Abschluss "
            f"(Event {', '.join(str(event_id) for event_id in unexpected_ids)})"
        )

    shutdown_outcome = (
        "Windows protokollierte zugleich einen unsauberen Abschluss; geplant war "
        "die Neustartabsicht, nicht zwingend der tatsächliche Abschluss."
        if unexpected
        else ""
    )

    timeline = [
        (
            analysis.get("pending_since"),
            "Erste Bestätigung: interaktive Sitzung fehlt, Worker ausgefallen.",
        ),
        (
            analysis.get("requested"),
            "Zweite Bestätigung: Factory-Watchdog fordert kontrollierten Neustart an.",
        ),
        (analysis.get("boot"), "Windows startet neu."),
    ]

    active_lines = []
    for item in (analysis.get("active_items") or [])[:10]:
        flag = " · Multisymbol" if item.get("registry_multisymbol") else ""
        active_lines.append(
            f"{item.get('terminal') or '?'}: {item.get('ea_id') or '?'} "
            f"{item.get('phase') or ''}{flag}".strip()
        )

    exclusions = []
    if not unexpected:
        exclusions.append("kein Kernel-Power-41, kein Event 6008 und kein BugCheck")
    exclusions.append("Windows Update war nicht der Initiator; Event 1074 nennt den QM-Watchdog")

    text_lines = [
        "QM NEUSTARTDIAGNOSE",
        "",
        "Ergebnis",
        "Der Neustart war geplant und wurde vom QM-Factory-Watchdog ausgelöst,",
        "nachdem die interaktive qm-admin-Sitzung in zwei Prüfungen nicht mehr vorhanden war.",
        shutdown_outcome,
        "",
        "Wahrscheinlichste Ursache",
        f"{analysis['root_cause']} (Vertrauen: {analysis['confidence']})",
    ]
    if evidence_signals:
        text_lines.extend(["Signale: " + "; ".join(evidence_signals)])
    text_lines.extend(["", "Zeitlinie"])
    for stamp, label in timeline:
        text_lines.append(f"- {_local_text(stamp)} — {label}")
    if last_healthy:
        text_lines.append(
            f"- Letzter gesunder Watchdog-Snapshot: "
            f"{int(last_healthy.get('workers') or 0)}/{int(last_healthy.get('expect') or expected)} Worker."
        )
    if first_lost:
        text_lines.append(
            f"- Erster Verlust-Snapshot: {int(first_lost.get('workers') or 0)} Worker, "
            f"session_lost={bool(first_lost.get('session_lost'))}."
        )

    text_lines.extend(
        [
            "",
            "Ressourcen vor dem Ausfall",
            f"- Commit: {_fmt_num(resource.get('committed_gb'), ' GB')} / "
            f"{_fmt_num(resource.get('commit_limit_gb'), ' GB')} "
            f"({_fmt_num(resource.get('commit_percent'), '%')})",
            f"- Commit-Reserve: {_fmt_num(resource.get('commit_headroom_gb'), ' GB')}",
            f"- Pagefile: {_fmt_num(resource.get('pagefile_current_mb'), ' MB')} / "
            f"{_fmt_num(resource.get('pagefile_allocated_mb'), ' MB')} "
            f"({_fmt_num(resource.get('pagefile_percent'), '%')})",
            f"- Paging: {_fmt_num(resource.get('pages_per_sec'), ' Pages/s')}",
        ]
    )
    if active_lines:
        text_lines.extend(["", "Aktive Tests im letzten gesunden Snapshot"])
        text_lines.extend(f"- {line}" for line in active_lines)

    text_lines.extend(
        [
            "",
            "Ausgeschlossen",
            *(f"- {item}" for item in exclusions),
            "",
            "Wiederherstellung",
            f"- Sitzung {recovery.get('target_user') or 'qm-admin'}: "
            f"{'vorhanden' if recovery.get('session_exists') else 'nicht vorhanden'}"
            f" ({recovery.get('session_state') or 'n/a'})",
            f"- Factory-Worker: {int(recovery.get('workers') or 0)}/{expected or '?'}",
            f"- Factory-Terminals: {int(recovery.get('factory_terminals') or 0)}",
            f"- Live-Terminals: {int(recovery.get('live_terminals') or 0)}",
            "",
            f"Incident-ID: {incident.get('event_id')}",
            "Lokale Evidenz: D:\\QM\\reports\\reboot_diagnostics",
        ]
    )
    text_body = "\n".join(text_lines)

    color = "#b8720a" if analysis["confidence"] != "hoch" else "#d13438"
    timeline_html = "".join(
        f"<tr><td style='padding:5px 10px;color:#726b60;white-space:nowrap;'>"
        f"{html.escape(_local_text(stamp))}</td><td style='padding:5px 10px;'>"
        f"{html.escape(label)}</td></tr>"
        for stamp, label in timeline
    )
    signal_html = (
        "".join(f"<li>{html.escape(item)}</li>" for item in evidence_signals)
        or "<li>Keine belastbare Ressourcen-Zeitreihe verfügbar.</li>"
    )
    active_html = (
        "".join(f"<li>{html.escape(item)}</li>" for item in active_lines)
        or "<li>Keine strukturierten aktiven Items verfügbar.</li>"
    )
    exclusion_html = "".join(f"<li>{html.escape(item)}</li>" for item in exclusions)

    html_body = f"""<!doctype html>
<html><body style="margin:0;background:#f6f5f2;font-family:Segoe UI,Arial,sans-serif;color:#1c1a16;">
<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px 10px;">
<table width="680" cellpadding="0" cellspacing="0" style="max-width:680px;background:#fff;border:1px solid #e2ded4;">
<tr><td style="padding:24px 28px;border-bottom:1px solid #e2ded4;">
  <div style="font-size:11px;letter-spacing:2px;color:#2954d4;font-weight:700;">QUANTMECHANICA · OPS</div>
  <div style="font-size:25px;font-weight:650;margin-top:6px;">Neustart erklärt</div>
  <div style="color:#726b60;margin-top:5px;">{html.escape(date_part)} · Factory-Watchdog</div>
</td></tr>
<tr><td style="padding:22px 28px;">
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;">BESTÄTIGTER AUSLÖSER</div>
  <p style="line-height:1.55;">Der QM-Factory-Watchdog hat kontrolliert neu gestartet, nachdem
  die interaktive <code>qm-admin</code>-Sitzung zweimal als verloren bestätigt wurde.
  {html.escape(shutdown_outcome)}</p>
  <div style="border-left:4px solid {color};background:#f1efe8;padding:13px 15px;margin:18px 0;">
    <div style="font-weight:700;">Wahrscheinlichste Ursache · Vertrauen {html.escape(analysis['confidence'])}</div>
    <div style="margin-top:5px;line-height:1.5;">{html.escape(analysis['root_cause'])}</div>
  </div>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;">EVIDENZSIGNALE</div>
  <ul style="line-height:1.55;">{signal_html}</ul>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;margin-top:18px;">ZEITLINIE</div>
  <table cellpadding="0" cellspacing="0" style="font-size:13px;margin-top:5px;">{timeline_html}</table>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;margin-top:18px;">AKTIVE TESTS ZUVOR</div>
  <ul style="line-height:1.55;">{active_html}</ul>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;margin-top:18px;">AUSGESCHLOSSEN</div>
  <ul style="line-height:1.55;">{exclusion_html}</ul>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;margin-top:18px;">WIEDERHERSTELLUNG</div>
  <p style="line-height:1.55;">Sitzung:
  <strong>{'vorhanden' if recovery.get('session_exists') else 'nicht vorhanden'}</strong>
  ({html.escape(str(recovery.get('session_state') or 'n/a'))}) · Worker:
  <strong>{int(recovery.get('workers') or 0)}/{expected or '?'}</strong> ·
  Factory-Terminals: <strong>{int(recovery.get('factory_terminals') or 0)}</strong> ·
  Live-Terminals: <strong>{int(recovery.get('live_terminals') or 0)}</strong></p>
</td></tr>
<tr><td style="padding:15px 28px;background:#efece3;color:#726b60;font-size:11px;">
Incident {html.escape(str(incident.get('event_id') or '?'))} ·
D:\\QM\\reports\\reboot_diagnostics
</td></tr></table></td></tr></table></body></html>"""
    return subject, text_body, html_body


def build_generic_boot_mail(
    incident: dict[str, Any],
    context: dict[str, Any],
    analysis: dict[str, Any],
) -> tuple[str, str, str]:
    """Render a cause report for a boot without a verified watchdog marker."""

    boot = _parse_ts(context.get("boot_utc"))
    trigger_event = incident.get("trigger_event")
    if not isinstance(trigger_event, dict):
        trigger_event = {}
    trigger_time = _parse_ts(trigger_event.get("time_utc"))
    trigger_title = str(incident.get("trigger_title") or "Windows-Neustart")
    trigger_summary = str(incident.get("trigger_summary") or "")
    trigger_confidence = str(incident.get("trigger_confidence") or "begrenzt")
    date_part = (boot or _utc_now()).astimezone().strftime("%d.%m.%Y %H:%M")
    subject = f"[QM] Neustart erklärt — {trigger_title} · {date_part}"

    resource = analysis.get("resource") or {}
    recovery = context.get("recovery") or {}
    last_healthy = analysis.get("last_healthy") or {}
    expected = int(last_healthy.get("expect") or 0)
    active_lines = []
    for item in (analysis.get("active_items") or [])[:10]:
        flag = " · Multisymbol" if item.get("registry_multisymbol") else ""
        active_lines.append(
            f"{item.get('terminal') or '?'}: {item.get('ea_id') or '?'} "
            f"{item.get('phase') or ''}{flag}".strip()
        )

    evidence_lines = []
    evidence_events = incident.get("evidence_events") or []
    if isinstance(evidence_events, dict):
        evidence_events = [evidence_events]
    if not evidence_events and trigger_event:
        evidence_events = [trigger_event]
    seen_events: set[tuple[int, str]] = set()
    for event in evidence_events:
        if not isinstance(event, dict):
            continue
        event_id = int(event.get("id") or 0)
        event_stamp = str(event.get("time_utc") or "")
        event_key = (event_id, event_stamp)
        if event_key in seen_events:
            continue
        seen_events.add(event_key)
        event_time = _parse_ts(event.get("time_utc"))
        evidence_lines.append(
            f"Windows Event {event_id} "
            f"({event.get('provider') or 'unbekannt'}) um {_local_text(event_time)}"
        )
        event_message = " ".join(str(event.get("message") or "").split())
        if len(event_message) > 900:
            event_message = event_message[:897] + "..."
        if event_message:
            evidence_lines.append(event_message)
    pressure_signals = [str(item) for item in (analysis.get("pressure_signals") or [])]
    if pressure_signals:
        evidence_lines.append(
            "Ressourcensignale vor dem Neustart: " + "; ".join(pressure_signals)
        )
    if not evidence_lines:
        evidence_lines.append("Keine eindeutigen Windows-Ereignisse im verfügbaren Zeitfenster.")

    technical_context = str(analysis.get("root_cause") or "")
    technical_confidence = str(analysis.get("confidence") or "begrenzt")
    text_lines = [
        "QM NEUSTARTDIAGNOSE",
        "",
        "Ergebnis",
        f"{trigger_title} (Vertrauen: {trigger_confidence})",
        trigger_summary,
        "",
        "Windows-Evidenz",
        *(f"- {line}" for line in evidence_lines),
        "",
        "Zeitlinie",
        f"- {_local_text(trigger_time)} — relevantes Shutdown-/Fehlerereignis",
        f"- {_local_text(boot)} — Windows-Boot",
        "",
        "Technische Einordnung",
        f"{technical_context} (Vertrauen: {technical_confidence})",
        "Diese Ressourceneinordnung ist Kontext; bei einem geplanten Neustart ersetzt "
        "sie nicht den von Windows protokollierten Initiator.",
        "",
        "Ressourcen vor dem Neustart",
        f"- Commit: {_fmt_num(resource.get('committed_gb'), ' GB')} / "
        f"{_fmt_num(resource.get('commit_limit_gb'), ' GB')} "
        f"({_fmt_num(resource.get('commit_percent'), '%')})",
        f"- Commit-Reserve: {_fmt_num(resource.get('commit_headroom_gb'), ' GB')}",
        f"- Pagefile: {_fmt_num(resource.get('pagefile_current_mb'), ' MB')} / "
        f"{_fmt_num(resource.get('pagefile_allocated_mb'), ' MB')} "
        f"({_fmt_num(resource.get('pagefile_percent'), '%')})",
    ]
    if active_lines:
        text_lines.extend(
            ["", "Aktive Tests im letzten Snapshot", *(f"- {line}" for line in active_lines)]
        )
    text_lines.extend(
        [
            "",
            "Wiederherstellung",
            f"- Sitzung {recovery.get('target_user') or 'qm-admin'}: "
            f"{'vorhanden' if recovery.get('session_exists') else 'nicht vorhanden'} "
            f"({recovery.get('session_state') or 'n/a'})",
            f"- Factory-Worker: {int(recovery.get('workers') or 0)}/{expected or '?'}",
            f"- Factory-Terminals: {int(recovery.get('factory_terminals') or 0)}",
            f"- Live-Terminals: {int(recovery.get('live_terminals') or 0)}",
            "",
            f"Incident-ID: {incident.get('event_id')}",
            "Lokale Evidenz: D:\\QM\\reports\\reboot_diagnostics",
        ]
    )
    text_body = "\n".join(text_lines)

    color = {
        "planned": "#2954d4",
        "clean_shutdown": "#2954d4",
        "bugcheck": "#d13438",
        "unexpected": "#d13438",
    }.get(str(incident.get("trigger_class") or ""), "#b8720a")
    evidence_html = "".join(f"<li>{html.escape(line)}</li>" for line in evidence_lines)
    active_html = (
        "".join(f"<li>{html.escape(line)}</li>" for line in active_lines)
        or "<li>Keine strukturierten aktiven Items verfügbar.</li>"
    )
    html_body = f"""<!doctype html>
<html><body style="margin:0;background:#f6f5f2;font-family:Segoe UI,Arial,sans-serif;color:#1c1a16;">
<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px 10px;">
<table width="680" cellpadding="0" cellspacing="0" style="max-width:680px;background:#fff;border:1px solid #e2ded4;">
<tr><td style="padding:24px 28px;border-bottom:1px solid #e2ded4;">
  <div style="font-size:11px;letter-spacing:2px;color:#2954d4;font-weight:700;">QUANTMECHANICA · OPS</div>
  <div style="font-size:25px;font-weight:650;margin-top:6px;">Neustart erklärt</div>
  <div style="color:#726b60;margin-top:5px;">{html.escape(date_part)} · Windows</div>
</td></tr>
<tr><td style="padding:22px 28px;">
  <div style="border-left:4px solid {color};background:#f1efe8;padding:13px 15px;">
    <div style="font-weight:700;">{html.escape(trigger_title)} · Vertrauen {html.escape(trigger_confidence)}</div>
    <div style="margin-top:5px;line-height:1.5;">{html.escape(trigger_summary)}</div>
  </div>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;margin-top:18px;">WINDOWS-EVIDENZ</div>
  <ul style="line-height:1.55;">{evidence_html}</ul>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;margin-top:18px;">TECHNISCHE EINORDNUNG</div>
  <p style="line-height:1.55;">{html.escape(technical_context)}
  <strong>(Vertrauen {html.escape(technical_confidence)})</strong></p>
  <p style="line-height:1.45;color:#726b60;font-size:12px;">Ressourcensignale sind Kontext;
  bei geplanten Neustarts gilt der von Windows protokollierte Initiator.</p>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;margin-top:18px;">AKTIVE TESTS ZUVOR</div>
  <ul style="line-height:1.55;">{active_html}</ul>
  <div style="font-size:12px;color:#2954d4;font-weight:700;letter-spacing:1px;margin-top:18px;">WIEDERHERSTELLUNG</div>
  <p style="line-height:1.55;">Sitzung:
  <strong>{'vorhanden' if recovery.get('session_exists') else 'nicht vorhanden'}</strong>
  ({html.escape(str(recovery.get('session_state') or 'n/a'))}) · Worker:
  <strong>{int(recovery.get('workers') or 0)}/{expected or '?'}</strong> ·
  Factory-Terminals: <strong>{int(recovery.get('factory_terminals') or 0)}</strong> ·
  Live-Terminals: <strong>{int(recovery.get('live_terminals') or 0)}</strong></p>
</td></tr>
<tr><td style="padding:15px 28px;background:#efece3;color:#726b60;font-size:11px;">
Incident {html.escape(str(incident.get('event_id') or '?'))} ·
D:\\QM\\reports\\reboot_diagnostics
</td></tr></table></td></tr></table></body></html>"""
    return subject, text_body, html_body


def _record_observed_boot(state_path: Path, boot_utc: str) -> dict[str, Any]:
    state, state_source = _read_state(state_path)
    if state_source == "corrupt":
        raise OSError(f"reboot diagnostic state is corrupt: {state_path}")
    events = state.get("events")
    if not isinstance(events, dict):
        events = {}
    state.update(
        {
            "schema": 1,
            "updated_at_utc": _iso(),
            "last_observed_boot_utc": boot_utc,
            "events": events,
        }
    )
    _atomic_write_json(state_path, state, keep_backup=True)
    return state


def _claim_event(state_path: Path, incident: dict[str, Any], boot_utc: Any) -> tuple[bool, dict[str, Any]]:
    state, state_source = _read_state(state_path)
    if state_source == "corrupt":
        raise OSError(f"reboot diagnostic state is corrupt: {state_path}")
    events = state.get("events")
    if not isinstance(events, dict):
        events = {}
    event_id = str(incident["event_id"])
    normalized_boot = _iso(_parse_ts(boot_utc)) if _parse_ts(boot_utc) else str(boot_utc or "")
    same_boot_events = [
        event
        for event in events.values()
        if (
            isinstance(event, dict)
            and _parse_ts(event.get("boot_utc")) == _parse_ts(normalized_boot)
        )
    ]
    existing_event = events.get(event_id)
    if isinstance(existing_event, dict) and existing_event not in same_boot_events:
        same_boot_events.append(existing_event)
    current = _utc_now()
    for event in same_boot_events:
        status = str(event.get("status") or "")
        if status == "failed":
            continue
        if status == "claimed" and _claimed_delivery_abandoned(event, current):
            continue
        return False, state
    prior_delivery_cycles: list[int] = []
    for event in same_boot_events:
        status = str(event.get("status") or "")
        if status != "failed" and not (
            status == "claimed" and _claimed_delivery_abandoned(event, current)
        ):
            continue
        try:
            prior_delivery_cycles.append(max(1, int(event.get("delivery_cycle") or 1)))
        except (TypeError, ValueError):
            prior_delivery_cycles.append(1)
    delivery_cycle = (max(prior_delivery_cycles) if prior_delivery_cycles else 0) + 1
    # O_EXCL is the concurrency boundary.  Task Scheduler already uses
    # IgnoreNew, but this sentinel also protects manual/concurrent invocations.
    claim_dir = state_path.with_name(f"{state_path.stem}_claims")
    claim_dir.mkdir(parents=True, exist_ok=True)
    # The boot plus delivery cycle is the concurrency boundary. A failed SMTP
    # cycle can be retried by Task Scheduler, while marker/generic contenders
    # within the same cycle still cannot create two mails.
    descriptor: int | None = None
    claim_path: Path | None = None
    for _ in range(100):
        claim_key = f"boot:{normalized_boot or event_id}:delivery:{delivery_cycle}"
        claim_name = hashlib.sha256(claim_key.encode("utf-8")).hexdigest() + ".claim"
        claim_path = claim_dir / claim_name
        try:
            descriptor = os.open(claim_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            break
        except FileExistsError:
            if not _claim_file_abandoned(claim_path, current):
                return False, state
            delivery_cycle += 1
    if descriptor is None or claim_path is None:
        raise OSError("could not allocate a reboot diagnostic delivery cycle")
    owner_started = _process_started_utc(os.getpid())
    owner_started_utc = _iso(owner_started) if owner_started is not None else None
    claimed_at_utc = _iso(current)
    with os.fdopen(descriptor, "w", encoding="utf-8") as claim:
        claim.write(
            json.dumps(
                {
                    "event_id": event_id,
                    "claimed_at_utc": claimed_at_utc,
                    "boot_utc": normalized_boot,
                    "delivery_cycle": delivery_cycle,
                    "claim_owner_pid": os.getpid(),
                    "claim_owner_started_utc": owner_started_utc,
                },
                sort_keys=True,
            )
            + "\n"
        )
    events[event_id] = {
        "status": "claimed",
        "claimed_at_utc": claimed_at_utc,
        "requested_at_utc": incident.get("requested_at_utc"),
        "boot_utc": normalized_boot,
        "delivery_cycle": delivery_cycle,
        "claim_owner_pid": os.getpid(),
        "claim_owner_started_utc": owner_started_utc,
    }
    if len(events) > 50:
        events = dict(list(events.items())[-50:])
    state.update(
        {
            "schema": 1,
            "updated_at_utc": _iso(),
            "last_observed_boot_utc": normalized_boot,
            "events": events,
        }
    )
    try:
        _atomic_write_json(state_path, state, keep_backup=True)
    except OSError as exc:
        # The exclusive claim already guarantees at-most-once.  Keep sending
        # useful even if the secondary human-readable state file is unavailable.
        state["state_write_error"] = repr(exc)
    return True, state


def _finish_event(
    state_path: Path,
    event_id: str,
    status: str,
    result: dict[str, Any],
) -> None:
    state, state_source = _read_state(state_path)
    if state_source == "corrupt":
        raise OSError(f"reboot diagnostic state is corrupt: {state_path}")
    events = state.get("events")
    if not isinstance(events, dict):
        events = {}
    event = events.get(event_id)
    if not isinstance(event, dict):
        event = {}
    event.update(
        {
            "status": status,
            "finished_at_utc": _iso(),
            "mail_result": result,
        }
    )
    events[event_id] = event
    state.update({"schema": 1, "updated_at_utc": _iso(), "events": events})
    _atomic_write_json(state_path, state, keep_backup=True)


def _send_with_retries(
    sender: Callable[[str, str, str | None], dict[str, Any]],
    subject: str,
    text_body: str,
    html_body: str,
    *,
    attempts: int = 3,
    sleeper: Callable[[float], None] = time.sleep,
) -> dict[str, Any]:
    last: dict[str, Any] = {"sent": False, "reason": "not attempted"}
    delays = (0.0, 5.0, 20.0)
    for attempt in range(1, attempts + 1):
        if attempt > 1:
            sleeper(delays[min(attempt - 1, len(delays) - 1)])
        try:
            last = sender(subject, text_body, html_body)
        except Exception as exc:
            last = {"sent": False, "reason": f"sender raised: {exc!r}"}
        last = {**last, "attempt": attempt}
        if last.get("sent"):
            return last
        reason = str(last.get("reason") or "").lower()
        if any(token in reason for token in ("credentials missing", "reading creds", "authentication", " 535")):
            break
    return {**last, "sent": False, "attempts": last.get("attempt", attempts)}


def _write_report_bundle(
    incident: dict[str, Any],
    context: dict[str, Any],
    analysis: dict[str, Any],
    subject: str,
    text_body: str,
    html_body: str,
    report_dir: Path,
) -> dict[str, str]:
    report_dir.mkdir(parents=True, exist_ok=True)
    event_id = str(incident["event_id"])
    stem = f"{str(incident.get('requested_at_utc') or '')[:10]}_{event_id}"
    text_path = report_dir / f"{stem}.txt"
    html_path = report_dir / f"{stem}.html"
    json_path = report_dir / f"{stem}.json"
    text_path.write_text(text_body + "\n", encoding="utf-8")
    html_path.write_text(html_body, encoding="utf-8")
    serial_analysis = {
        key: (_iso(value) if isinstance(value, dt.datetime) else value)
        for key, value in analysis.items()
    }
    json_path.write_text(
        json.dumps(
            {
                "schema": 1,
                "subject": subject,
                "incident": incident,
                "windows_context": context,
                "analysis": serial_analysis,
            },
            ensure_ascii=False,
            indent=2,
            default=str,
        )
        + "\n",
        encoding="utf-8",
    )
    return {"text": str(text_path), "html": str(html_path), "json": str(json_path)}


def process_pending(
    *,
    pending_file: Path = PENDING_FILE,
    state_file: Path = STATE_FILE,
    watchdog_log: Path = WATCHDOG_LOG,
    live_watchdog_log: Path = LIVE_WATCHDOG_LOG,
    report_dir: Path = REPORT_DIR,
    run_log: Path = RUN_LOG,
    dry_run: bool = False,
    context_loader: Callable[[], dict[str, Any]] = collect_windows_context,
    sender: Callable[[str, str, str | None], dict[str, Any]] | None = None,
) -> dict[str, Any]:
    marker = _read_json(pending_file)
    try:
        context = context_loader()
    except Exception as exc:  # scheduled task must leave evidence, not a traceback-only failure
        result = {"ts": _iso(), "action": "context_failed", "error": repr(exc)}
        _append_log(result, run_log)
        return result

    boot = _parse_ts(context.get("boot_utc"))
    if boot is None:
        result = {
            "ts": _iso(),
            "action": "context_failed",
            "error": "windows context has no valid boot_utc",
        }
        _append_log(result, run_log)
        return result

    marker_valid = False
    marker_reason = "no_pending_incident"
    shutdown_event: dict[str, Any] | None = None
    if marker:
        marker_valid, marker_reason, shutdown_event = validate_incident(marker, context)

    state, state_source = _read_state(state_file)
    if state_source == "corrupt":
        result = {
            "ts": _iso(),
            "action": "state_failed",
            "error": f"reboot diagnostic state and backup are unreadable: {state_file}",
        }
        _append_log(result, run_log)
        return result
    observed_boot = _parse_ts(state.get("last_observed_boot_utc"))
    same_boot = observed_boot is not None and observed_boot == boot
    state_events = state.get("events") if isinstance(state.get("events"), dict) else {}
    marker_event_id = str(marker.get("event_id") or "") if marker else ""
    boot_event_records = [
        event
        for event in state_events.values()
        if (
            isinstance(event, dict)
            and _parse_ts(event.get("boot_utc")) == boot
        )
    ]
    retry_failed_delivery = bool(boot_event_records) and all(
        str(event.get("status") or "") == "failed"
        or _claimed_delivery_abandoned(event)
        for event in boot_event_records
    )
    ignored_shutdown_event: dict[str, Any] | None = None
    if marker_valid and not same_boot and marker_event_id in state_events:
        ignored_shutdown_event = shutdown_event
        marker_valid = False
        marker_reason = "marker_already_processed_for_previous_boot"
        shutdown_event = None
    if same_boot and not retry_failed_delivery:
        result = {
            "ts": _iso(),
            "action": (
                "noop_already_processed"
                if marker_event_id and marker_event_id in state_events
                else "noop_boot_already_observed"
            ),
            "event_id": marker_event_id or None,
            "boot_utc": _iso(boot),
        }
        _append_log(result, run_log)
        return result

    report_kind = "watchdog"
    if marker_valid:
        incident = marker
    elif observed_boot is None:
        if dry_run:
            result = {
                "ts": _iso(),
                "action": "dry_run_baseline_needed",
                "boot_utc": _iso(boot),
                "marker_ignored_reason": marker_reason if marker else None,
            }
            _append_log(result, run_log)
            return result
        try:
            _record_observed_boot(state_file, _iso(boot))
        except OSError as exc:
            result = {"ts": _iso(), "action": "claim_failed", "error": repr(exc)}
            _append_log(result, run_log)
            return result
        result = {
            "ts": _iso(),
            "action": "baseline_initialized",
            "boot_utc": _iso(boot),
            "marker_ignored_reason": marker_reason if marker else None,
        }
        _append_log(result, run_log)
        return result
    else:
        boot_age_hours = (_utc_now() - boot).total_seconds() / 3600
        if boot_age_hours < 0 or boot_age_hours > MAX_BOOT_REPORT_AGE_HOURS:
            if not dry_run:
                try:
                    _record_observed_boot(state_file, _iso(boot))
                except OSError:
                    pass
            result = {
                "ts": _iso(),
                "action": "noop_boot_outside_report_window",
                "boot_utc": _iso(boot),
                "boot_age_hours": round(boot_age_hours, 2),
            }
            _append_log(result, run_log)
            return result
        try:
            incident = _generic_boot_incident(context, ignored_event=ignored_shutdown_event)
        except ValueError as exc:
            result = {"ts": _iso(), "action": "context_failed", "error": str(exc)}
            _append_log(result, run_log)
            return result
        if marker:
            incident["marker_ignored_reason"] = marker_reason
            incident["ignored_marker_event_id"] = marker.get("event_id")
        shutdown_event = incident.get("trigger_event")
        report_kind = "windows"

    analysis = analyze_incident(
        incident,
        context,
        _read_jsonl(watchdog_log),
        _read_jsonl(live_watchdog_log),
    )
    analysis["verified_shutdown_event"] = shutdown_event
    if report_kind == "watchdog":
        subject, text_body, html_body = build_mail(incident, context, analysis)
    else:
        subject, text_body, html_body = build_generic_boot_mail(incident, context, analysis)
    paths = _write_report_bundle(
        incident,
        context,
        analysis,
        subject,
        text_body,
        html_body,
        report_dir,
    )

    if dry_run:
        result = {
            "ts": _iso(),
            "action": "dry_run_rendered",
            "event_id": incident.get("event_id"),
            "subject": subject,
            "reports": paths,
        }
        _append_log(result, run_log)
        return result

    try:
        claimed, _state = _claim_event(state_file, incident, context.get("boot_utc"))
    except OSError as exc:
        result = {
            "ts": _iso(),
            "action": "claim_failed",
            "event_id": incident.get("event_id"),
            "error": repr(exc),
        }
        _append_log(result, run_log)
        return result
    if not claimed:
        result = {
            "ts": _iso(),
            "action": "noop_already_processed",
            "event_id": incident.get("event_id"),
        }
        _append_log(result, run_log)
        return result

    if sender is None:
        sys.path.insert(0, str(TOOLS_DIR))
        from gmail_alarm import _send_mail

        message_id = f"<qm-reboot-{incident['event_id']}@quantmechanica.com>"
        sender = lambda mail_subject, mail_text, mail_html: _send_mail(
            mail_subject,
            mail_text,
            mail_html,
            message_id=message_id,
        )

    mail_result = _send_with_retries(sender, subject, text_body, html_body)
    status = "sent" if mail_result.get("sent") else "failed"
    state_write_error = None
    try:
        _finish_event(state_file, str(incident["event_id"]), status, mail_result)
    except OSError as exc:
        state_write_error = repr(exc)
    result = {
        "ts": _iso(),
        "action": f"mail_{status}",
        "event_id": incident.get("event_id"),
        "subject": subject,
        "reports": paths,
        "mail_result": mail_result,
    }
    if state_write_error:
        result["state_write_error"] = state_write_error
    _append_log(result, run_log)
    return result


def initialize_current_boot(
    *,
    state_file: Path = STATE_FILE,
    run_log: Path = RUN_LOG,
    context_loader: Callable[[], dict[str, Any]] = collect_windows_context,
) -> dict[str, Any]:
    """Record the installation boot as a no-mail baseline."""

    try:
        context = context_loader()
        boot = _parse_ts(context.get("boot_utc"))
        if boot is None:
            raise ValueError("windows context has no valid boot_utc")
        _record_observed_boot(state_file, _iso(boot))
    except Exception as exc:
        result = {"ts": _iso(), "action": "baseline_failed", "error": repr(exc)}
        _append_log(result, run_log)
        return result
    result = {
        "ts": _iso(),
        "action": "baseline_initialized",
        "boot_utc": _iso(boot),
        "reason": "installed_during_current_boot",
    }
    _append_log(result, run_log)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="QM post-reboot diagnostic mail")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="verify and render a pending incident, but do not claim or send it",
    )
    parser.add_argument(
        "--initialize-current-boot",
        action="store_true",
        help="record the current boot as a no-mail installation baseline",
    )
    args = parser.parse_args()
    result = (
        initialize_current_boot()
        if args.initialize_current_boot
        else process_pending(dry_run=args.dry_run)
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get("action") not in {
        "baseline_failed",
        "context_failed",
        "state_failed",
        "claim_failed",
        "mail_failed",
    } else 1


if __name__ == "__main__":
    raise SystemExit(main())
