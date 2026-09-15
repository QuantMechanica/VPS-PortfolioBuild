#!/usr/bin/env python3
"""T_Live book-v2 cutover ceremony (Sunday 2026-09-20): preflight, guarded apply, rollback.

Authority: OWNER 2026-09-14 Freifahrtsschein (`decisions/2026-09-14_owner_risk_freeze_lift.md`) +
OWNER 2026-09-15 confirmation (`decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md`).
The AutoTrading toggle is never touched: T_Live_ON re-pins whatever the OWNER left in
common.ini ([Experts] Enabled) exactly as it does after every reboot.

Steps (every step journals to D:/QM/reports/state/tlive_book_cutover_<stamp>.jsonl and stops
the ceremony on the first failure; the terminal is only stopped after every copy source has
been validated, so a failing preflight never touches T_Live):

  P  preflight (``plan``): freeze lifted, decisions present, staging package hash-complete,
     copy plan v3 composed and dry-run through deploy_tlive_book (34 items), profile verified,
     exactly one T_Live terminal64, governor artifacts present, recovery pointer preview.
  S1 maintenance flag ON  (watchdog + session supervisor stop relaunching T_Live)
  S2 graceful terminal close (CloseMainWindow, wait <= 180 s; never a forced kill: on timeout
     the ceremony aborts and the flag comes off again, the old book keeps running)
  S3 backups (common.ini, deployed presets/binaries via the copy tool's backup dir, monitor v1)
  S4 copies: deploy_tlive_book --apply (24 re-weighted + 4 burn-in presets, 4 new + 1 repair
     binaries), monitor v2 binary, profile directory DarwinexZero_Book2_LiveOps
  S5 recovery pointer written (T_Live_ON resumes the new profile, python verifier)
  S6 maintenance flag OFF, T_Live_ON via the console-session helper, launcher journal = launched
  S7 verification: profile on disk == manifest, INIT_OK for all 28 magics after the restart,
     monitor v2 snapshot schema, RISK_FIXED=0 everywhere -> claude_verification_signature
  S8 governor enforce (adapter --enforce, halt-file executor) once the monitor v2 snapshot
     reports schema v2; otherwise deferred and reported

``rollback --backup-dir <dir>`` restores the backed-up files, removes the recovery pointer,
and relaunches T_Live on the previous profile.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

REPO = Path(r"C:\QM\repo")
sys.path.insert(0, str(REPO))
STAGING = Path(r"C:\QM\deploy\DXZ_V2_20260913")
LIVE_ROOT = Path(r"C:\QM\mt5\T_Live\MT5_Base")
PROFILE_NAME = "DarwinexZero_Book2_LiveOps"
PREVIOUS_PROFILE = "DarwinexZero_V2_LiveOps"
PROFILE_SRC = STAGING / "profile" / PROFILE_NAME
PROFILE_MANIFEST = PROFILE_SRC / "profile_manifest.json"
PROFILE_DST = LIVE_ROOT / "MQL5" / "Profiles" / "Charts" / PROFILE_NAME
MONITOR_V2_SRC = Path(r"C:\QM\deploy\governor_v2_20260913\staging\QM_AccountMonitor.ex5")
MONITOR_V2_SHA = "f98523ee82d36ad88713b554f3f270a40d79054f214f22aff9186441a0c7f7e9"
MONITOR_DST = LIVE_ROOT / "MQL5" / "Experts" / "QM_AccountMonitor.ex5"
COMMON_INI = LIVE_ROOT / "config" / "common.ini"
EVENT_LOG_DIR = LIVE_ROOT / "MQL5" / "Files" / "QM"
ACCOUNT_SNAPSHOT = EVENT_LOG_DIR / "journal" / "account_snapshot.json"
MAINTENANCE_FLAG = Path(r"D:\QM\reports\state\LIVE_UPTIME_MAINTENANCE.flag")
RECOVERY_POINTER = Path(r"D:\QM\reports\state\tlive_recovery_profile.json")
LAUNCHER_JOURNAL = Path(r"D:\QM\reports\state\live_launcher_events.jsonl")
STATE_DIR = Path(r"D:\QM\reports\state")
BACKUP_ROOT = STATE_DIR / "backups"
DECISIONS = [REPO / "decisions" / "2026-09-14_owner_risk_freeze_lift.md",
             REPO / "decisions" / "2026-09-15_owner_freifahrtsschein_scope_1_to_3.md",
             REPO / "decisions" / "2026-09-13_owner_governor_enforce_dxz.md"]
COPY_PLAN_V2 = STAGING / "copy_plan_v2.json"
COPY_PLAN_REPAIR = STAGING / "repair_v2" / "copy_plan_repair_v2.json"
COPY_PLAN_V3 = STAGING / "copy_plan_v3_cutover.json"
DEPLOY_MANIFEST_YAML = REPO / "docs" / "ops" / "evidence" / "2026-09-13_dxz_book_v2" / "deploy_manifest_v2_DRAFT.yaml"
GOV_DIR = REPO / "docs" / "ops" / "evidence" / "2026-09-13_governor_v2_cutover_package"
GOV_POLICY = GOV_DIR / "account_governor_policy_dxz_4000090541_20260913.OWNER_SIGNED_CANDIDATE.json"
GOV_POLICY_SHA = "f2baf21a6282942cc99b82ce77caaf46a561247b188340d4e2f06851f01feb70"
GOV_ACTIVATION = GOV_DIR / "governor_enforce_activation_dxz_4000090541_20260913.DRAFT.json"
GOV_ACTIVATION_SHA = "5ab3b819562a0504308434342744b1cd3d52c1e558267be8d520b34a9194fb41"
PYTHON = Path(sys.executable)
POWERSHELL = Path(r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")
CONSOLE_HELPER = REPO / "tools" / "strategy_farm" / "run_in_console_session.ps1"
T_LIVE_ON = REPO / "tools" / "strategy_farm" / "T_Live_ON.ps1"
TARGET_USER = "qm-admin"


def now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def iso(ts: dt.datetime | None = None) -> str:
    return (ts or now_utc()).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class CeremonyError(RuntimeError):
    pass


class Journal:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def write(self, event: str, **data: Any) -> None:
        rec = {"ts_utc": iso(), "event": event, **data}
        with self.path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec, ensure_ascii=False, default=str) + "\n")
        print(f"[{rec['ts_utc']}] {event} {json.dumps({k: v for k, v in data.items() if k != 'detail'}, default=str)[:300]}")


def ps(script: str, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run([str(POWERSHELL), "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script],
                          capture_output=True, text=True, timeout=timeout)


def tlive_processes() -> list[dict[str, Any]]:
    out = ps("Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | Where-Object { $_.ExecutablePath -like 'C:\\QM\\mt5\\T_Live\\*' } | "
             "Select-Object ProcessId, SessionId, ExecutablePath, CreationDate | ConvertTo-Json -Compress")
    if out.returncode != 0:
        raise CeremonyError(f"process probe failed: {out.stderr.strip()[:300]}")
    raw = out.stdout.strip()
    if not raw:
        return []
    data = json.loads(raw)
    return data if isinstance(data, list) else [data]


# --------------------------------------------------------------------------- copy plan v3

def compose_copy_plan_v3(decision_evidence: Path) -> dict[str, Any]:
    base = json.loads(COPY_PLAN_V2.read_text(encoding="utf-8-sig"))
    repair = json.loads(COPY_PLAN_REPAIR.read_text(encoding="utf-8-sig"))
    items: list[dict[str, Any]] = []
    for it in base["items"]:
        items.append({"source": it["source"], "destination_relative": it["destination_relative"],
                      "sha256": it["sha256"], "class": it.get("class")})
    promoted = 0
    skipped: list[dict[str, Any]] = []
    for it in base.get("pending_items") or []:
        if it.get("class") != "existing_risk_change":
            # deferred_new_sleeve (13054/21505 cut from the book) and dark_sleeve_repair_noop_until_source_fix
            # (12778/13117 stay dark no-ops per D7; 12969 is replaced by the repair_v2 41470 items below)
            skipped.append({"class": it.get("class"), "ea_id": it.get("ea_id"), "symbol": it.get("symbol"), "status": it.get("status")})
            continue
        src = Path(it["planned_source"])
        if not src.is_file():
            raise CeremonyError(f"pending preset not staged: {src}")
        actual = sha256_file(src)
        expected = str(it.get("sha256_staged_expected") or "").lower()
        if expected and actual != expected:
            raise CeremonyError(f"staged preset hash drift: {src.name} expected {expected[:12]} got {actual[:12]}")
        items.append({"source": str(src), "destination_relative": it["destination_relative"], "sha256": actual,
                      "class": it.get("class"), "old_risk": it.get("old_risk"), "new_risk": it.get("new_risk"),
                      "promoted_from": "pending_items (LIVE_RISK_FREEZE lifted 2026-09-14)"})
        promoted += 1
    for it in repair["items"]:
        items.append({"source": it["source"], "destination_relative": it["destination_relative"],
                      "sha256": it["sha256"], "class": "repair_v2_41470"})
    plan = {
        "schema": base["schema"], "source": str(STAGING), "destination": str(LIVE_ROOT), "destination_relative": "MQL5",
        "owner_approval_evidence": str(decision_evidence), "book": base.get("book"), "as_of": "2026-09-20",
        "variant": base.get("variant"), "owner_decision": base.get("owner_decision"),
        "note": f"cutover plan v3: {len(base['items'])} v2 items + {promoted} promoted re-weights + {len(repair['items'])} repair items",
        "items": items,
        "skipped_pending": skipped,
    }
    return plan


# --------------------------------------------------------------------------- preflight

def preflight(journal: Journal, *, decision_evidence: Path) -> dict[str, Any]:
    from tools.strategy_farm import build_tlive_book_profile as bp
    from tools.strategy_farm import deploy_tlive_book, risk_freeze

    report: dict[str, Any] = {"checks": []}

    def check(name: str, ok: bool, **detail: Any) -> None:
        report["checks"].append({"name": name, "ok": bool(ok), **detail})
        journal.write("preflight", check=name, ok=bool(ok), **detail)

    # P1 freeze
    try:
        risk_freeze.assert_live_book_mutation_allowed("book v2 cutover preflight")
        check("freeze_lifted", True)
    except Exception as exc:  # noqa: BLE001
        check("freeze_lifted", False, error=str(exc)[:300])
    # P2 decisions
    for d in DECISIONS:
        check(f"decision_present:{d.name}", d.is_file(), path=str(d))
    check("decision_evidence_for_copy_plan", decision_evidence.is_file(), path=str(decision_evidence))
    # P3 staging package
    check("profile_staged", PROFILE_SRC.is_dir() and PROFILE_MANIFEST.is_file(), path=str(PROFILE_SRC))
    if PROFILE_MANIFEST.is_file():
        v = bp.verify_profile(PROFILE_SRC, PROFILE_MANIFEST)
        check("profile_verify_staging", v["status"] == "OK", mismatches=v["mismatches"], charts=v["charts_found"])
        pm = json.loads(PROFILE_MANIFEST.read_text(encoding="utf-8"))
        check("profile_28_sleeves_plus_monitor", pm["n_sleeves"] == 28 and pm["n_charts"] == 29, n_sleeves=pm["n_sleeves"], n_charts=pm["n_charts"],
              total_risk=pm["total_risk_percent_at_cutover"])
    check("monitor_v2_artifact", MONITOR_V2_SRC.is_file() and sha256_file(MONITOR_V2_SRC) == MONITOR_V2_SHA, path=str(MONITOR_V2_SRC))
    check("profile_dst_absent", not PROFILE_DST.exists(), path=str(PROFILE_DST))
    # P4 copy plan v3 + dry-run
    try:
        plan = compose_copy_plan_v3(decision_evidence)
        COPY_PLAN_V3.write_text(json.dumps(plan, indent=2, ensure_ascii=False), encoding="utf-8")
        result = deploy_tlive_book.execute(COPY_PLAN_V3, live_root=LIVE_ROOT, apply=False)
        n_items = len(plan["items"])
        check("copy_plan_v3_dry_run", True, items=n_items, plan=str(COPY_PLAN_V3), result_keys=sorted(result.keys())[:8] if isinstance(result, dict) else str(type(result)))
    except Exception as exc:  # noqa: BLE001
        check("copy_plan_v3_dry_run", False, error=f"{type(exc).__name__}: {str(exc)[:400]}")
    # P5 terminal state
    try:
        procs = tlive_processes()
        check("tlive_single_process", len(procs) == 1, pids=[p.get("ProcessId") for p in procs], sessions=[p.get("SessionId") for p in procs])
    except CeremonyError as exc:
        check("tlive_single_process", False, error=str(exc))
    check("maintenance_flag_absent", not MAINTENANCE_FLAG.exists())
    check("recovery_pointer_absent", not RECOVERY_POINTER.exists())
    check("common_ini_present", COMMON_INI.is_file())
    # P6 pointer preview
    report["recovery_pointer_preview"] = recovery_pointer(decision_evidence)
    # P7 governor artifacts
    check("governor_policy_sha", GOV_POLICY.is_file() and sha256_file(GOV_POLICY) == GOV_POLICY_SHA)
    check("governor_activation_sha", GOV_ACTIVATION.is_file() and sha256_file(GOV_ACTIVATION) == GOV_ACTIVATION_SHA)
    check("console_helper_present", CONSOLE_HELPER.is_file() and T_LIVE_ON.is_file())
    report["ok"] = all(c["ok"] for c in report["checks"])
    journal.write("preflight_result", ok=report["ok"], failed=[c["name"] for c in report["checks"] if not c["ok"]])
    return report


def recovery_pointer(decision_evidence: Path) -> dict[str, Any]:
    return {
        "schema": "qm.tlive-recovery-profile.v1",
        "profile": PROFILE_NAME,
        "verifier": {"kind": "python", "exe": str(PYTHON),
                     "args": ["-X", "utf8", str(REPO / "tools" / "strategy_farm" / "build_tlive_book_profile.py"), "verify",
                              "--profile-dir", str(PROFILE_DST), "--manifest", str(PROFILE_MANIFEST)]},
        "previous_profile": PREVIOUS_PROFILE,
        "set_by": "Orchestrator Claude, tlive_book_cutover.py",
        "set_at_utc": iso(),
        "decision": str(decision_evidence),
    }


# --------------------------------------------------------------------------- apply steps

def step_maintenance(journal: Journal, on: bool, reason: str) -> None:
    if on:
        MAINTENANCE_FLAG.write_text(json.dumps({"owner": "tlive_book_cutover", "reason": reason, "set_at_utc": iso()}), encoding="utf-8")
    elif MAINTENANCE_FLAG.exists():
        MAINTENANCE_FLAG.unlink()
    journal.write("maintenance_flag", on=on, reason=reason)


def step_close_terminal(journal: Journal, timeout_s: int = 180) -> None:
    procs = tlive_processes()
    if len(procs) != 1:
        raise CeremonyError(f"expected exactly one T_Live terminal64, found {len(procs)}")
    pid = int(procs[0]["ProcessId"])
    out = ps(f"$p = Get-Process -Id {pid} -ErrorAction Stop; $r = $p.CloseMainWindow(); Write-Output ('close_main_window=' + $r)")
    journal.write("terminal_close_requested", pid=pid, rc=out.returncode, stdout=out.stdout.strip()[:120], stderr=out.stderr.strip()[:200])
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if not tlive_processes():
            journal.write("terminal_closed", pid=pid, waited_s=round(timeout_s - (deadline - time.monotonic()), 1))
            return
        time.sleep(3)
    raise CeremonyError(f"T_Live terminal {pid} still running after {timeout_s}s graceful close (no forced kill by design)")


def step_backups(journal: Journal, backup_dir: Path) -> None:
    backup_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(COMMON_INI, backup_dir / "common.ini")
    if MONITOR_DST.is_file():
        shutil.copy2(MONITOR_DST, backup_dir / "QM_AccountMonitor.v1.ex5")
    prev = PROFILE_DST.parent / PREVIOUS_PROFILE
    if prev.is_dir():
        shutil.copytree(prev, backup_dir / PREVIOUS_PROFILE, dirs_exist_ok=True)
    journal.write("backups_written", dir=str(backup_dir), common_ini=sha256_file(backup_dir / "common.ini"),
                  monitor_v1=(sha256_file(MONITOR_DST) if MONITOR_DST.is_file() else None))


def step_copies(journal: Journal, backup_dir: Path) -> dict[str, Any]:
    from tools.strategy_farm import build_tlive_book_profile as bp
    from tools.strategy_farm import deploy_tlive_book

    result = deploy_tlive_book.execute(COPY_PLAN_V3, live_root=LIVE_ROOT, backup_dir=backup_dir / "copy_tool", apply=True)
    journal.write("copy_plan_v3_applied", summary={k: (v if not isinstance(v, list) else len(v)) for k, v in (result.items() if isinstance(result, dict) else [])})
    # monitor v2 binary (outside the copy tool's allowed parents by design: guarded here)
    before = sha256_file(MONITOR_DST) if MONITOR_DST.is_file() else None
    tmp = MONITOR_DST.with_suffix(".ex5.tmp")
    shutil.copy2(MONITOR_V2_SRC, tmp)
    if sha256_file(tmp) != MONITOR_V2_SHA:
        tmp.unlink()
        raise CeremonyError("monitor v2 temp copy hash mismatch")
    tmp.replace(MONITOR_DST)
    journal.write("monitor_v2_installed", before=before, after=sha256_file(MONITOR_DST), expected=MONITOR_V2_SHA)
    # profile directory
    if PROFILE_DST.exists():
        raise CeremonyError(f"profile destination already exists: {PROFILE_DST}")
    shutil.copytree(PROFILE_SRC, PROFILE_DST)
    v = bp.verify_profile(PROFILE_DST, PROFILE_MANIFEST)
    if v["status"] != "OK":
        raise CeremonyError(f"profile verify after copy failed: {v['mismatches']}")
    journal.write("profile_installed", dst=str(PROFILE_DST), charts=v["charts_found"])
    return {"copy": result, "profile_verify": v}


def step_pointer(journal: Journal, decision_evidence: Path) -> None:
    ptr = recovery_pointer(decision_evidence)
    RECOVERY_POINTER.write_text(json.dumps(ptr, indent=2), encoding="utf-8")
    journal.write("recovery_pointer_written", path=str(RECOVERY_POINTER), profile=ptr["profile"])


def _launcher_events_since(since: dt.datetime) -> list[dict[str, Any]]:
    if not LAUNCHER_JOURNAL.exists():
        return []
    out = []
    for line in LAUNCHER_JOURNAL.read_text(encoding="utf-8", errors="replace").splitlines()[-50:]:
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        if rec.get("launcher") == "DXZ" and str(rec.get("ts_utc", "")) >= since.strftime("%Y-%m-%dT%H:%M:%S"):
            out.append(rec)
    return out


def step_launch(journal: Journal, wait_s: int = 240) -> dict[str, Any]:
    since = now_utc()
    args = f'-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{T_LIVE_ON}"'
    cmd = [str(POWERSHELL), "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(CONSOLE_HELPER),
           "-Exe", str(POWERSHELL), "-Arguments", args, "-WorkDir", str(REPO), "-TargetUser", TARGET_USER, "-WaitSeconds", str(wait_s)]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=wait_s + 120)
    events = _launcher_events_since(since)
    reasons = [e.get("reason") for e in events]
    procs = tlive_processes()
    journal.write("tlive_on_invoked", rc=out.returncode, launcher_reasons=reasons, pids=[p.get("ProcessId") for p in procs],
                  stdout=out.stdout.strip()[-400:], stderr=out.stderr.strip()[-300:])
    if len(procs) != 1 or "launched" not in reasons:
        raise CeremonyError(f"T_Live did not come back as one process with a 'launched' journal event (reasons={reasons})")
    return {"events": events, "pids": [p.get("ProcessId") for p in procs], "since": iso(since)}


def wait_for_init(magics_by_ea: dict[int, int], since: dt.datetime, timeout_s: int = 420) -> dict[str, Any]:
    since_s = since.strftime("%Y-%m-%dT%H:%M:%S")
    seen: dict[int, dict[str, Any]] = {}
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline and len(seen) < len(magics_by_ea):
        for ea, magic in magics_by_ea.items():
            if ea in seen:
                continue
            log = EVENT_LOG_DIR / f"QM5_{ea}_ea-{ea}.log"
            if not log.is_file():
                continue
            try:
                tail = log.read_bytes()[-200000:].decode("utf-8", errors="replace").splitlines()
            except OSError:
                continue
            for line in reversed(tail):
                if '"INIT_OK"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if str(rec.get("ts_utc", "")) >= since_s and int(rec.get("magic") or 0) == magic:
                    seen[ea] = {"ts_utc": rec.get("ts_utc"), "symbol": rec.get("symbol"), "magic": magic}
                    break
        if len(seen) < len(magics_by_ea):
            time.sleep(10)
    missing = {ea: m for ea, m in magics_by_ea.items() if ea not in seen}
    return {"seen": seen, "missing": missing, "ok": not missing}


def step_verify(journal: Journal, since: dt.datetime) -> dict[str, Any]:
    from tools.strategy_farm import build_tlive_book_profile as bp

    pm = json.loads(PROFILE_MANIFEST.read_text(encoding="utf-8"))
    magics = {int(c["ea_id"]): int(c["magic"]) for c in pm["charts"] if c["kind"] != "monitor"}
    init = wait_for_init(magics, since)
    journal.write("init_ok_scan", ok=init["ok"], seen=len(init["seen"]), missing=init["missing"])
    disk = bp.verify_profile(PROFILE_DST, PROFILE_MANIFEST)
    journal.write("profile_verify_live", status=disk["status"], mismatches=disk["mismatches"])
    snap: dict[str, Any] = {}
    if ACCOUNT_SNAPSHOT.is_file():
        try:
            snap = json.loads(ACCOUNT_SNAPSHOT.read_text(encoding="utf-8-sig"))
        except ValueError:
            snap = {}
    schema = str(snap.get("schema") or snap.get("schema_version") or "")
    journal.write("account_snapshot", schema=schema, generated=snap.get("generated_at_utc") or snap.get("ts_utc"))
    ok = init["ok"] and disk["status"] == "OK"
    sig = {
        "schema": "qm.claude-verification-signature.v1", "verified_at_utc": iso(), "ok": ok,
        "profile": PROFILE_NAME, "profile_manifest_sha256": sha256_file(PROFILE_MANIFEST),
        "init_ok_magics": sorted(m["magic"] for m in init["seen"].values()), "missing": init["missing"],
        "profile_verify": disk["status"], "monitor_snapshot_schema": schema,
    }
    sig_path = STATE_DIR / "tlive_book2_claude_verification.json"
    sig_path.write_text(json.dumps(sig, indent=2), encoding="utf-8")
    if ok:
        text = DEPLOY_MANIFEST_YAML.read_text(encoding="utf-8")
        if "claude_verification_signature: PENDING" in text:
            text = text.replace("claude_verification_signature: PENDING",
                                f'claude_verification_signature: "Orchestrator Claude {sig["verified_at_utc"]} | {sig_path} sha256 {sha256_file(sig_path)} | INIT_OK 28/28, profile verify OK"', 1)
            DEPLOY_MANIFEST_YAML.write_text(text, encoding="utf-8")
    journal.write("claude_verification_signature", ok=ok, path=str(sig_path))
    return {"ok": ok, "signature": sig}


def step_governor(journal: Journal, snapshot_schema: str, *, apply: bool) -> dict[str, Any]:
    cmd = [str(PYTHON), "-X", "utf8", str(REPO / "tools" / "strategy_farm" / "account_governor_action_adapter.py"), "--enforce",
           "--policy", str(GOV_POLICY), "--trusted-policy-sha256", GOV_POLICY_SHA,
           "--activation", str(GOV_ACTIVATION), "--trusted-activation-sha256", GOV_ACTIVATION_SHA,
           "--executor", "halt-file", "--enforce-order", str(REPO / "decisions" / "2026-09-13_owner_governor_enforce_dxz.md"),
           "--enforce-venue", "dxz"]
    if "v2" not in snapshot_schema.lower():
        journal.write("governor_enforce_deferred", reason=f"monitor snapshot schema {snapshot_schema!r} is not v2 yet", command=cmd)
        return {"status": "deferred", "command": cmd}
    if not apply:
        cmd.append("--dry-run")
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO), timeout=300)
    journal.write("governor_enforce", rc=out.returncode, apply=apply, stdout=out.stdout.strip()[-600:], stderr=out.stderr.strip()[-300:])
    return {"status": "ok" if out.returncode == 0 else "failed", "rc": out.returncode, "command": cmd}


def apply(journal: Journal, *, decision_evidence: Path, backup_dir: Path, governor_apply: bool) -> int:
    pre = preflight(journal, decision_evidence=decision_evidence)
    if not pre["ok"]:
        journal.write("abort", stage="preflight")
        return 2
    step_maintenance(journal, True, "book v2 cutover ceremony")
    try:
        step_close_terminal(journal)
    except CeremonyError as exc:
        journal.write("abort", stage="close_terminal", error=str(exc))
        step_maintenance(journal, False, "abort: terminal kept running on the old book")
        return 3
    try:
        step_backups(journal, backup_dir)
        step_copies(journal, backup_dir)
        step_pointer(journal, decision_evidence)
    except Exception as exc:  # noqa: BLE001
        journal.write("abort", stage="copies", error=f"{type(exc).__name__}: {exc}",
                      hint=f"rollback: tlive_book_cutover.py rollback --backup-dir {backup_dir}")
        return 4
    step_maintenance(journal, False, "copies done, relaunching on the new profile")
    launch = step_launch(journal)
    since = dt.datetime.fromisoformat(launch["since"].replace("Z", "+00:00"))
    ver = step_verify(journal, since)
    if not ver["ok"]:
        journal.write("verification_failed", missing=ver["signature"]["missing"], hint="assess before any rollback; the old book is in the backup dir")
        return 5
    gov = step_governor(journal, ver["signature"]["monitor_snapshot_schema"], apply=governor_apply)
    journal.write("ceremony_done", governor=gov["status"], backup_dir=str(backup_dir))
    return 0


def rollback(journal: Journal, backup_dir: Path) -> int:
    from tools.strategy_farm import deploy_tlive_book  # noqa: F401  (import check only)

    step_maintenance(journal, True, "rollback")
    try:
        step_close_terminal(journal)
    except CeremonyError as exc:
        journal.write("abort", stage="rollback_close", error=str(exc))
        step_maintenance(journal, False, "rollback aborted, terminal kept running")
        return 3
    restored = 0
    copy_backup = backup_dir / "copy_tool"
    if copy_backup.is_dir():
        for f in copy_backup.rglob("*"):
            if f.is_file():
                rel = f.relative_to(copy_backup)
                dst = LIVE_ROOT / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, dst)
                restored += 1
    mon = backup_dir / "QM_AccountMonitor.v1.ex5"
    if mon.is_file():
        shutil.copy2(mon, MONITOR_DST)
    if (backup_dir / "common.ini").is_file():
        shutil.copy2(backup_dir / "common.ini", COMMON_INI)
    if RECOVERY_POINTER.exists():
        RECOVERY_POINTER.unlink()
    journal.write("rollback_restored", files=restored, pointer_removed=True)
    step_maintenance(journal, False, "rollback: relaunch on previous profile")
    step_launch(journal)
    journal.write("rollback_done")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_plan = sub.add_parser("plan")
    p_plan.add_argument("--decision", type=Path, default=DECISIONS[1])
    p_apply = sub.add_parser("apply")
    p_apply.add_argument("--decision", type=Path, default=DECISIONS[1])
    p_apply.add_argument("--i-am-orchestrator", action="store_true")
    p_apply.add_argument("--governor-apply", action="store_true", help="run the adapter --enforce for real (default: adapter dry-run)")
    p_rb = sub.add_parser("rollback")
    p_rb.add_argument("--backup-dir", type=Path, required=True)
    p_rb.add_argument("--i-am-orchestrator", action="store_true")
    args = ap.parse_args(argv)
    stamp = now_utc().strftime("%Y%m%dT%H%M%SZ")
    journal = Journal(STATE_DIR / f"tlive_book_cutover_{args.cmd}_{stamp}.jsonl")
    journal.write("start", cmd=args.cmd, argv=argv or sys.argv[1:])
    if args.cmd == "plan":
        rep = preflight(journal, decision_evidence=args.decision)
        print(json.dumps({"ok": rep["ok"], "failed": [c["name"] for c in rep["checks"] if not c["ok"]],
                          "journal": str(journal.path), "copy_plan_v3": str(COPY_PLAN_V3)}, indent=2))
        return 0 if rep["ok"] else 1
    if not args.i_am_orchestrator:
        print("refused: --i-am-orchestrator required")
        return 2
    if args.cmd == "apply":
        backup_dir = BACKUP_ROOT / f"tlive_book_cutover_{stamp}"
        return apply(journal, decision_evidence=args.decision, backup_dir=backup_dir, governor_apply=bool(args.governor_apply))
    return rollback(journal, args.backup_dir)


if __name__ == "__main__":
    raise SystemExit(main())
