r"""Daily mailbox source-intake — read info@ forwards, analyze the sources, feed the factory.

OWNER forwards research links (reddit / YouTube / GitHub / articles / MQL5) to
info@quantmechanica.com. `sourcing_intake_sweep.py` already extracts those links read-only into
`D:\QM\reports\sourcing_intake\leads.csv` (status NEW). This wrapper adds the missing second half
the OWNER asked for (2026-07-22): a DAILY (06:07) run that

  1. runs the extraction sweep (reuses sourcing_intake_sweep.py unchanged), then
  2. for any NEW leads, dispatches ONE headless AI analyst (Codex) with a
     doctrine-bound, injection-safe prompt to: deep-read each source, judge it against R1-R4 + the
     FX-edge / structural-edge doctrine + the reputable-source criteria, and for QUALIFYING sources
     feed the factory via `farmctl add-source` (the canonical G0 intake) + a draft strategy card,
     marking each lead's status (QUALIFIED / REJECTED / DEFERRED) in leads.csv.

SAFETY MODEL (important)
  - The sweep already restricts to SELF-SENT mail (OWNER's own forwards), so senders are trusted.
    The LINKED CONTENT (web pages, reddit, repos) is still untrusted external data — the analyst
    prompt treats it as DATA, never as instructions, and never follows anything embedded in a page.
  - "Implement" = feed the normal pipeline (add-source → G0 review → Research → card → approve → build).
    The analyst may reserve exactly one EA ID per qualifying source through the canonical allocator,
    but NEVER approves cards, builds EAs, edits registries directly, touches T_Live, or crosses any
    money/live gate. Those stay OWNER + Claude + the deterministic pipeline.
  - Extraction never depends on the AI: if the analyst dispatch fails or Codex is unavailable, the new
    leads are still captured (status NEW) for the next run / manual triage. NEW in leads.csv is
    authoritative and is never suppressed by the legacy analyst-triage audit file.
  - Completion is evidence-based: every handed-off URL must have a verified terminal
    QUALIFIED / REJECTED / DEFERRED status; QUALIFIED additionally requires a matching factory source
    and a source-linked G0 card.
    The Codex return code remains diagnostic evidence, but verified postconditions are authoritative.

Run manually:  python tools/strategy_farm/mailbox_source_intake.py [--dry-run] [--no-dispatch]
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

try:
    from managed_codex import (
        count_live_managed_codex_processes as active_managed_codex_count,
        release_managed_codex_process,
        spawn_managed_codex,
        terminate_managed_codex_pid,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.managed_codex import (
        count_live_managed_codex_processes as active_managed_codex_count,
        release_managed_codex_process,
        spawn_managed_codex,
        terminate_managed_codex_pid,
    )

REPO_ROOT = Path(r"C:\QM\repo")
FARM_ROOT = Path(r"D:\QM\strategy_farm")
FARM_DB = FARM_ROOT / "state" / "farm_state.sqlite"
SWEEP = REPO_ROOT / "tools" / "strategy_farm" / "sourcing_intake_sweep.py"
PROMPT_TEMPLATE = REPO_ROOT / "tools" / "strategy_farm" / "prompts" / "mailbox_source_intake_prompt.md"
INTAKE_DIR = Path(r"D:\QM\reports\sourcing_intake")
LEADS_CSV = INTAKE_DIR / "leads.csv"
TRIAGE_STATE = INTAKE_DIR / "analyst_triage_state.json"   # terminal-status audit; never a NEW-lead gate
RUN_LOG = INTAKE_DIR / "mailbox_source_intake_run_log.jsonl"
PROMPT_OUT_DIR = INTAKE_DIR / "analyst_prompts"

PYTHONW = r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe"
PYTHON = r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
CODEX_CMD = r"C:\Users\Administrator\AppData\Roaming\npm\codex.cmd"
CODEX_HOME = r"C:\Users\Administrator\.codex"

CREATE_NO_WINDOW = 0x08000000
TERMINAL_STATUSES = {"QUALIFIED", "REJECTED", "DEFERRED"}
RETRYABLE_STATUS_PREFIXES = (
    "DEFERRED:HANDOFF_FAILED",
    "DEFERRED:TECHNICAL_RETRY",
    "DEFERRED:FETCH_ERROR",
    "DEFERRED:ACCESS_BLOCKED",
)
MAX_MANAGED_CODEX = 3


class LeadStateError(RuntimeError):
    """Canonical leads.csv could not be read safely."""


def _managed_codex_limit() -> int:
    """Mirror the pump's current disk-backed Codex capacity conservatively."""
    if (FARM_ROOT / "CODEX_LOW_TOKENS.flag").exists():
        return 1
    capacity_file = FARM_ROOT / "state" / "codex_parallel.txt"
    try:
        raw = capacity_file.read_text(encoding="utf-8").strip() if capacity_file.exists() else "3"
        return max(1, min(16, int(raw)))
    except (OSError, TypeError, ValueError):
        return MAX_MANAGED_CODEX


def _now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _log_run(rec: dict) -> None:
    try:
        INTAKE_DIR.mkdir(parents=True, exist_ok=True)
        with RUN_LOG.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception:
        pass


def _load_triaged() -> set[str]:
    try:
        return set(json.loads(TRIAGE_STATE.read_text(encoding="utf-8")).get("triaged_urls", []))
    except Exception:
        return set()


def _save_triaged(urls: set[str]) -> None:
    try:
        TRIAGE_STATE.write_text(
            json.dumps({"updated_at": _now_iso(), "triaged_urls": sorted(urls)}, ensure_ascii=False, indent=1),
            encoding="utf-8",
        )
    except Exception:
        pass


def run_sweep(dry_run: bool) -> dict:
    """Run the read-only extraction sweep. Never fatal to this wrapper."""
    if not SWEEP.exists():
        return {"ok": False, "reason": f"sweep missing: {SWEEP}"}
    cmd = [PYTHON, str(SWEEP)]
    if dry_run:
        cmd.append("--dry-run")
    try:
        p = subprocess.run(
            cmd, cwd=str(REPO_ROOT), capture_output=True, text=True, timeout=240,
            creationflags=CREATE_NO_WINDOW,
        )
        return {"ok": p.returncode == 0, "returncode": p.returncode, "tail": (p.stdout or "")[-400:]}
    except Exception as exc:
        return {"ok": False, "reason": f"sweep error: {exc!r}"}


def load_new_leads(already: set[str] | None = None) -> list[dict]:
    """Return every NEW or explicitly retryable lead.

    `already` remains in the signature for compatibility with older callers, but
    deliberately does not filter: leads.csv is the canonical state machine and a
    retryable row must remain eligible after a failed or partial analyst run.
    """
    del already
    if not LEADS_CSV.exists():
        return []
    out: list[dict] = []
    try:
        with LEADS_CSV.open("r", encoding="utf-8", newline="") as fh:
            for row in csv.DictReader(fh):
                if _is_retryable_status(row.get("status")):
                    out.append(row)
    except (OSError, UnicodeError, csv.Error) as exc:
        raise LeadStateError(f"could not read canonical leads CSV: {exc}") from exc
    return out


def _is_retryable_status(value: str | None) -> bool:
    text = (value or "").strip().upper()
    return text == "NEW" or text.startswith(RETRYABLE_STATUS_PREFIXES)


def _is_terminal_status(value: str | None) -> bool:
    text = (value or "").strip()
    if _is_retryable_status(text):
        return False
    if ":" not in text:
        return False
    kind, detail = text.split(":", 1)
    return kind.strip().upper() in TERMINAL_STATUSES and bool(detail.strip())


def _parse_card_frontmatter(path: Path) -> dict[str, str]:
    """Parse the scalar fields needed for deterministic intake handoff checks."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return {}
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end < 0:
        return {}
    fields: dict[str, str] = {}
    for line in text[3:end].splitlines():
        match = re.match(r"^([A-Za-z0-9_-]+)\s*:\s*(.*?)\s*$", line)
        if not match:
            continue
        value = match.group(2).strip().strip("'\"")
        fields[match.group(1).lower()] = value
    return fields


def _find_source_card(source_id: str, url: str) -> Path | None:
    """Find a valid G0 card produced for this exact source and intake URL."""
    artifact_root = FARM_ROOT / "artifacts"
    for dirname in ("cards_draft", "cards_approved", "cards_rejected"):
        directory = artifact_root / dirname
        if not directory.is_dir():
            continue
        for path in directory.glob("QM5_*.md"):
            fields = _parse_card_frontmatter(path)
            ea_id = fields.get("ea_id", "")
            if fields.get("source_id") != source_id:
                continue
            if fields.get("source_uri") != url:
                continue
            if not re.fullmatch(r"QM5_\d+", ea_id) or not path.stem.startswith(f"{ea_id}_"):
                continue
            if fields.get("status", "").lower() != "draft":
                continue
            if fields.get("g0_status", "").upper() not in {"PENDING", "APPROVED", "REJECTED"}:
                continue
            return path
    return None


def _terminal_handoff_ok(url: str, value: str | None) -> tuple[bool, str | None]:
    """Verify terminal evidence; QUALIFIED needs both source row and G0 card."""
    if not _is_terminal_status(value):
        return False, "status is not terminal"
    kind, detail = (value or "").split(":", 1)
    if kind.strip().upper() != "QUALIFIED":
        return True, None
    source_id = detail.strip()
    if not FARM_DB.exists():
        return False, f"qualified source database missing: {FARM_DB}"
    try:
        with sqlite3.connect(f"file:{FARM_DB.as_posix()}?mode=ro", uri=True, timeout=5) as conn:
            row = conn.execute("SELECT uri FROM sources WHERE id = ?", (source_id,)).fetchone()
    except sqlite3.Error as exc:
        return False, f"qualified source lookup failed: {exc}"
    if row is None:
        return False, f"qualified source_id not found: {source_id}"
    if (row[0] or "").strip() != url:
        return False, f"qualified source URI mismatch for {source_id}"
    card_path = _find_source_card(source_id, url)
    if card_path is None:
        return False, f"qualified source has no valid source-linked G0 card: {source_id}"
    return True, None


def load_lead_statuses(urls: set[str] | None = None) -> dict[str, str]:
    """Read exact URL -> status cells from the canonical CSV."""
    wanted = set(urls or ())
    statuses: dict[str, str] = {}
    if not LEADS_CSV.exists():
        return statuses
    try:
        with LEADS_CSV.open("r", encoding="utf-8", newline="") as fh:
            for row in csv.DictReader(fh):
                url = (row.get("url") or "").strip()
                if url and (not wanted or url in wanted):
                    statuses[url] = (row.get("status") or "").strip()
    except (OSError, UnicodeError, csv.Error) as exc:
        raise LeadStateError(f"could not read canonical lead statuses: {exc}") from exc
    return statuses


def build_prompt(leads: list[dict]) -> str | None:
    if not PROMPT_TEMPLATE.exists():
        return None
    try:
        tmpl = PROMPT_TEMPLATE.read_text(encoding="utf-8")
    except Exception:
        return None
    lines = []
    for i, r in enumerate(leads, 1):
        lines.append(
            f"{i}. url={r.get('url','')}  | domain={r.get('domain_class','')} "
            f"| title={(r.get('resolved_title') or '').strip()[:160]}  | mail_uid={r.get('source_mail_uid','')}"
        )
    return tmpl.replace("{{DATE}}", _now_iso()).replace("{{LEAD_COUNT}}", str(len(leads))).replace(
        "{{LEADS}}", "\n".join(lines)
    )


def dispatch_analyst(prompt: str) -> dict:
    """Run one ownership-tracked Codex analyst synchronously.

    Runs blocking so the scheduled task's lifetime covers the analysis (task ExecutionTimeLimit=45min;
    Codex timeout below is 30min). Managed-process registration makes the normal farm capacity checks
    see this analyst; when the current disk-backed capacity is already full, Task Scheduler retries.
    """
    if not Path(CODEX_CMD).exists():
        return {"dispatched": False, "ok": False, "reason": "codex.cmd not found"}
    try:
        active = active_managed_codex_count(FARM_ROOT)
    except Exception as exc:
        return {
            "dispatched": False,
            "ok": False,
            "reason": f"could not verify managed Codex capacity: {exc!r}",
        }
    capacity = _managed_codex_limit()
    if active >= capacity:
        return {
            "dispatched": False,
            "ok": False,
            "reason": (
                f"managed Codex capacity full ({active}/{capacity}); "
                "leave lead retryable for Task Scheduler"
            ),
        }
    PROMPT_OUT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S")
    prompt_path = PROMPT_OUT_DIR / f"analyst_{stamp}.md"
    log_path = PROMPT_OUT_DIR / f"analyst_{stamp}.log"
    proc = None
    lease: dict | None = None
    try:
        prompt_path.write_text(prompt, encoding="utf-8")
        env = os.environ.copy()
        # Scheduled tasks may have SYSTEM/user-profile defaults. Codex auth and
        # configuration are deliberately anchored to the authenticated operator
        # profile used by every other managed Strategy Farm Codex spawn.
        env["CODEX_HOME"] = CODEX_HOME
        env["QM_AGENT_ID"] = "codex"
        command = [
            CODEX_CMD,
            "exec",
            "-s",
            "danger-full-access",
            "--cd",
            str(REPO_ROOT),
            "-m",
            "gpt-5.6-sol",
            "-c",
            "model_reasoning_effort=high",
        ]
        with prompt_path.open("rb") as stdin_f, log_path.open("wb") as stdout_f:
            proc, lease = spawn_managed_codex(
                FARM_ROOT,
                command,
                purpose="mailbox_source_intake",
                cwd=REPO_ROOT,
                max_age_minutes=35,
                dedupe_key="mailbox_source_intake",
                metadata={"prompt": str(prompt_path), "live_log": str(log_path)},
                stdin=stdin_f,
                stdout=stdout_f,
                stderr=subprocess.STDOUT,
                env=env,
                shell=True,
                creationflags=CREATE_NO_WINDOW,
                close_fds=True,
            )
        returncode = proc.wait(timeout=1800)
        release_managed_codex_process(FARM_ROOT, lease_id=str(lease["lease_id"]))
        has_log = log_path.exists() and log_path.stat().st_size > 0
        ok = returncode == 0 and has_log
        out = {
            "dispatched": True,
            "ok": ok,
            "returncode": returncode,
            "prompt": str(prompt_path),
            "log": str(log_path),
            "lease_id": lease["lease_id"],
        }
        if not ok:
            out["reason"] = (
                f"codex returned {returncode}" if returncode != 0 else "codex produced no output"
            )
        return out
    except subprocess.TimeoutExpired:
        stopped = _terminate_and_confirm(proc)
        return {
            "dispatched": True,
            "ok": False,
            "returncode": 124,
            "reason": "codex timed out at 1800s; any partial leads remain retryable",
            "prompt": str(prompt_path),
            "log": str(log_path),
            "termination": stopped,
        }
    except Exception as exc:
        cleanup = None
        if proc is not None and lease is not None:
            if proc.poll() is None:
                cleanup = _terminate_and_confirm(proc)
            else:
                cleanup = {
                    "released": bool(
                        release_managed_codex_process(
                            FARM_ROOT, lease_id=str(lease["lease_id"])
                        )
                    )
                }
        result = {
            "dispatched": False,
            "ok": False,
            "reason": f"dispatch error: {exc!r}",
            "log": str(log_path),
        }
        if cleanup is not None:
            result["cleanup"] = cleanup
        return result


def _terminate_and_confirm(proc: subprocess.Popen | None) -> dict | None:
    """Terminate the exact managed owner and confirm its retained handle exited."""
    if proc is None:
        return None
    result = terminate_managed_codex_pid(FARM_ROOT, proc.pid)
    exit_confirmed = proc.poll() is not None
    if result.get("stopped") and not exit_confirmed:
        try:
            proc.wait(timeout=15)
        except (subprocess.TimeoutExpired, OSError):
            pass
        exit_confirmed = proc.poll() is not None
    result = dict(result)
    result["exit_confirmed"] = exit_confirmed
    if not exit_confirmed:
        result["stopped"] = False
        result["reason"] = f"{result.get('reason', 'unknown')}; process exit unconfirmed"
    return result


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="sweep in dry-run; do not dispatch analyst")
    ap.add_argument("--no-dispatch", action="store_true", help="extract + report new leads but do not dispatch the analyst")
    args = ap.parse_args()

    rec: dict = {"ts": _now_iso(), "dry_run": args.dry_run}
    sweep = run_sweep(args.dry_run)
    rec["sweep"] = sweep

    try:
        leads = load_new_leads()
    except LeadStateError as exc:
        rec["action"] = str(exc)
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False))
        return 2
    rec["new_leads"] = len(leads)

    if args.dry_run:
        rec["action"] = "dry-run: no dispatch"
        print(json.dumps(rec, ensure_ascii=False, indent=1))
        _log_run(rec)
        return 0 if sweep.get("ok") else 1

    if not leads:
        rec["action"] = "no new leads — no-op"
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False))
        return 0 if sweep.get("ok") else 1

    if args.no_dispatch:
        rec["action"] = f"{len(leads)} new leads captured; dispatch suppressed (--no-dispatch)"
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False, indent=1))
        return 0 if sweep.get("ok") else 1

    prompt = build_prompt(leads)
    if not prompt:
        rec["action"] = "prompt template missing — leads left NEW for next run"
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False))
        return 2

    disp = dispatch_analyst(prompt)
    rec["dispatch"] = disp
    lead_urls = {r.get("url") for r in leads if r.get("url")}
    try:
        statuses = load_lead_statuses(lead_urls)
    except LeadStateError as exc:
        rec["action"] = str(exc)
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False))
        return 2
    handoff_checks = {url: _terminal_handoff_ok(url, statuses.get(url)) for url in lead_urls}
    completed = {url for url, (ok, _reason) in handoff_checks.items() if ok}
    remaining = sorted(lead_urls - completed)
    rec["lead_statuses"] = {url: statuses.get(url, "MISSING") for url in sorted(lead_urls)}
    rec["handoff_errors"] = {
        url: reason for url, (ok, reason) in sorted(handoff_checks.items()) if not ok and reason
    }
    rec["completed_leads"] = len(completed)
    rec["remaining_new_leads"] = len(remaining)

    # Keep the legacy file only as an audit of terminal CSV state. Rebuilding it
    # removes stale entries such as a URL that was once dispatched but stayed NEW.
    try:
        all_statuses = load_lead_statuses()
    except LeadStateError as exc:
        rec["action"] = str(exc)
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False))
        return 2
    _save_triaged({url for url, status in all_statuses.items() if _is_terminal_status(status)})

    # The canonical postcondition is stronger than the CLI return code: every URL
    # that was retryable at dispatch must now have a verified terminal handoff. Codex
    # may return 1 after a nonessential tool command times out even though its
    # final status edits completed; retain that rc as a warning, but do not turn
    # verified work red. Conversely, rc=0 with any NEW/missing URL is a failure.
    analysis_ok = not remaining
    run_ok = bool(sweep.get("ok")) and analysis_ok
    if run_ok:
        process_note = "" if disp.get("ok") else f"; analyst rc warning={disp.get('returncode', 'unknown')}"
        rec["action"] = f"analyst completed {len(completed)} lead(s); all terminal{process_note}"
    else:
        reasons: list[str] = []
        if not sweep.get("ok"):
            reasons.append("sweep failed")
        if not disp.get("ok"):
            reasons.append("analyst process failed")
        if remaining:
            reasons.append(f"{len(remaining)} lead(s) remain retryable/missing")
        rec["action"] = "; ".join(reasons) or "intake incomplete"
    _log_run(rec)
    print(json.dumps(rec, ensure_ascii=False))
    return 0 if run_ok else 1


if __name__ == "__main__":
    sys.exit(main())
