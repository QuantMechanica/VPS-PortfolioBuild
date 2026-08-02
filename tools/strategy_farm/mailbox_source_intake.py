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
import time
import traceback
from pathlib import Path


def _pythonw_excepthook(exc_type: type[BaseException], exc: BaseException, tb) -> None:
    """Persist otherwise invisible top-level pythonw failures."""
    try:
        crash_log = globals().get(
            "PYTHONW_CRASH_LOG",
            Path(r"D:\QM\reports\sourcing_intake")
            / "mailbox_source_intake_pythonw_crash.log",
        )
        crash_log.parent.mkdir(parents=True, exist_ok=True)
        stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with crash_log.open("a", encoding="utf-8") as handle:
            handle.write(f"\n[{stamp}] uncaught top-level exception\n")
            traceback.print_exception(exc_type, exc, tb, file=handle)
    except Exception:
        # An exception hook must never mask the original failure.
        pass


if __name__ == "__main__":
    # Install before project-local imports so pythonw import/startup failures are
    # durable even when the normal intake run log has not been created.
    sys.excepthook = _pythonw_excepthook


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
PYTHONW_CRASH_LOG = INTAKE_DIR / "mailbox_source_intake_pythonw_crash.log"
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
ANALYST_CHUNK_SIZE = int(os.environ.get("ANALYST_CHUNK_SIZE", "5"))
ANALYST_CHUNK_TIMEOUT_SECONDS = int(
    os.environ.get("ANALYST_CHUNK_TIMEOUT_SECONDS", "600")
)
# Task Scheduler kills the outer task at 45 minutes and the console-session
# bridge waits 44 minutes. Stop launching work at 40 minutes and retain a
# reconciliation/cleanup margin rather than letting the scheduler kill a child.
RUN_BUDGET_SECONDS = 40 * 60
SHUTDOWN_GRACE_SECONDS = 2 * 60


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


def _chunk_leads(
    leads: list[dict], chunk_size: int | None = None
) -> list[list[dict]]:
    """Return stable, bounded analyst batches without dropping or duplicating rows."""
    if chunk_size is None:
        chunk_size = ANALYST_CHUNK_SIZE
    if chunk_size <= 0:
        raise ValueError("chunk_size must be positive")
    return [leads[start : start + chunk_size] for start in range(0, len(leads), chunk_size)]


def dispatch_analyst(
    prompt: str,
    timeout_seconds: int | None = None,
) -> dict:
    """Run one ownership-tracked Codex analyst synchronously.

    Each invocation owns one bounded lead chunk. Runs blocking so the scheduled
    task's lifetime covers the analysis; the caller enforces the outer run budget.
    Managed-process registration makes the normal farm capacity checks see this
    analyst; when disk-backed capacity is full, Task Scheduler retries later.
    """
    if timeout_seconds is None:
        timeout_seconds = ANALYST_CHUNK_TIMEOUT_SECONDS
    if timeout_seconds <= 0:
        raise ValueError("timeout_seconds must be positive")
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
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
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
                max_age_minutes=max(10, (timeout_seconds + 119) // 60),
                dedupe_key="mailbox_source_intake",
                metadata={
                    "prompt": str(prompt_path),
                    "live_log": str(log_path),
                    "timeout_seconds": timeout_seconds,
                },
                stdin=stdin_f,
                stdout=stdout_f,
                stderr=subprocess.STDOUT,
                env=env,
                shell=True,
                creationflags=CREATE_NO_WINDOW,
                close_fds=True,
            )
        returncode = proc.wait(timeout=timeout_seconds)
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
            "timeout_seconds": timeout_seconds,
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
            "reason": (
                f"codex chunk timed out at {timeout_seconds}s; "
                "unfinished leads remain retryable"
            ),
            "prompt": str(prompt_path),
            "log": str(log_path),
            "timeout_seconds": timeout_seconds,
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


def _reconcile_leads(
    leads: list[dict],
) -> tuple[set[str], dict[str, str], set[str], list[str], dict[str, str]]:
    """Resolve current canonical handoff state for exactly these lead rows."""
    lead_urls = {
        str(row.get("url") or "").strip()
        for row in leads
        if str(row.get("url") or "").strip()
    }
    statuses = load_lead_statuses(lead_urls)
    handoff_checks = {
        url: _terminal_handoff_ok(url, statuses.get(url)) for url in lead_urls
    }
    completed = {url for url, (ok, _reason) in handoff_checks.items() if ok}
    remaining = sorted(lead_urls - completed)
    errors = {
        url: reason
        for url, (ok, reason) in sorted(handoff_checks.items())
        if not ok and reason
    }
    return lead_urls, statuses, completed, remaining, errors


def _refresh_triage_audit() -> int:
    """Checkpoint terminal CSV state after a chunk; leads.csv remains canonical."""
    all_statuses = load_lead_statuses()
    terminal_urls = {
        url for url, status in all_statuses.items() if _is_terminal_status(status)
    }
    _save_triaged(terminal_urls)
    return len(terminal_urls)


def main() -> int:
    run_started = time.monotonic()
    run_deadline = run_started + RUN_BUDGET_SECONDS
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

    chunks = _chunk_leads(leads)
    rec["dispatch_policy"] = {
        "chunk_size": ANALYST_CHUNK_SIZE,
        "chunk_timeout_seconds": ANALYST_CHUNK_TIMEOUT_SECONDS,
        "run_budget_seconds": RUN_BUDGET_SECONDS,
        "shutdown_grace_seconds": SHUTDOWN_GRACE_SECONDS,
        "chunks_total": len(chunks),
    }
    rec["chunks"] = []
    fatal_error: str | None = None

    for chunk_index, chunk in enumerate(chunks, 1):
        seconds_left = max(0.0, run_deadline - time.monotonic())
        required_seconds = ANALYST_CHUNK_TIMEOUT_SECONDS + SHUTDOWN_GRACE_SECONDS
        if seconds_left < required_seconds:
            rec["early_stop"] = {
                "reason": "insufficient budget for another full analyst chunk",
                "next_chunk": chunk_index,
                "chunks_remaining": len(chunks) - chunk_index + 1,
                "seconds_left": round(seconds_left, 3),
                "required_seconds": required_seconds,
            }
            _log_run(
                {
                    "ts": _now_iso(),
                    "event": "analyst_early_stop",
                    "run_ts": rec["ts"],
                    **rec["early_stop"],
                }
            )
            break

        prompt = build_prompt(chunk)
        if not prompt:
            fatal_error = "prompt template missing — unattempted leads left retryable"
            rec["early_stop"] = {
                "reason": fatal_error,
                "next_chunk": chunk_index,
                "chunks_remaining": len(chunks) - chunk_index + 1,
            }
            break

        disp = dispatch_analyst(prompt)
        try:
            chunk_urls, chunk_statuses, chunk_completed, chunk_remaining, chunk_errors = (
                _reconcile_leads(chunk)
            )
            terminal_audit_count = _refresh_triage_audit()
        except LeadStateError as exc:
            fatal_error = str(exc)
            rec["early_stop"] = {
                "reason": fatal_error,
                "next_chunk": chunk_index + 1,
                "chunks_remaining": len(chunks) - chunk_index,
            }
            break

        chunk_rec = {
            "chunk_index": chunk_index,
            "lead_count": len(chunk),
            "dispatch": disp,
            "lead_statuses": {
                url: chunk_statuses.get(url, "MISSING") for url in sorted(chunk_urls)
            },
            "handoff_errors": chunk_errors,
            "completed_leads": len(chunk_completed),
            "remaining_retryable_or_missing": len(chunk_remaining),
            "terminal_audit_count": terminal_audit_count,
        }
        rec["chunks"].append(chunk_rec)
        # A per-chunk durable checkpoint makes partial progress visible even if
        # a later chunk times out or the outer task exits early.
        _log_run(
            {
                "ts": _now_iso(),
                "event": "analyst_chunk_complete",
                "run_ts": rec["ts"],
                **chunk_rec,
            }
        )

        # Capacity/unexpected spawn failures are systemic for this run; walking
        # the remaining chunks would only repeat the same failure. A confirmed
        # per-chunk timeout is safe to continue after its exact child is gone.
        if not disp.get("dispatched"):
            rec["early_stop"] = {
                "reason": disp.get("reason", "analyst dispatch unavailable"),
                "next_chunk": chunk_index + 1,
                "chunks_remaining": len(chunks) - chunk_index,
            }
            break
        if disp.get("returncode") == 124 and not (
            disp.get("termination") or {}
        ).get("exit_confirmed"):
            rec["early_stop"] = {
                "reason": "timed-out analyst process exit was not confirmed",
                "next_chunk": chunk_index + 1,
                "chunks_remaining": len(chunks) - chunk_index,
            }
            break

    try:
        lead_urls, statuses, completed, remaining, handoff_errors = _reconcile_leads(leads)
        _refresh_triage_audit()
    except LeadStateError as exc:
        rec["action"] = str(exc)
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False))
        return 2

    rec["lead_statuses"] = {
        url: statuses.get(url, "MISSING") for url in sorted(lead_urls)
    }
    rec["handoff_errors"] = handoff_errors
    rec["completed_leads"] = len(completed)
    rec["remaining_new_leads"] = len(remaining)
    rec["dispatch"] = {
        "chunks_attempted": len(rec["chunks"]),
        "chunks_total": len(chunks),
        "process_warnings": [
            {
                "chunk_index": chunk["chunk_index"],
                "returncode": chunk["dispatch"].get("returncode"),
                "reason": chunk["dispatch"].get("reason"),
            }
            for chunk in rec["chunks"]
            if not chunk["dispatch"].get("ok")
        ],
    }

    # The canonical postcondition is stronger than the CLI return code: every URL
    # that was retryable at dispatch must now have a verified terminal handoff. Codex
    # may return 1 after a nonessential tool command times out even though its
    # final status edits completed; retain that rc as a warning, but do not turn
    # verified work red. Conversely, rc=0 with any NEW/missing URL is a failure.
    analysis_ok = not remaining and fatal_error is None
    run_ok = bool(sweep.get("ok")) and analysis_ok
    if run_ok:
        warning_count = len(rec["dispatch"]["process_warnings"])
        process_note = (
            "" if warning_count == 0 else f"; process warnings in {warning_count} chunk(s)"
        )
        rec["action"] = (
            f"analyst completed {len(completed)} lead(s) across "
            f"{len(rec['chunks'])} chunk(s); all terminal{process_note}"
        )
    else:
        reasons: list[str] = []
        if not sweep.get("ok"):
            reasons.append("sweep failed")
        if fatal_error:
            reasons.append(fatal_error)
        if rec.get("early_stop"):
            reasons.append(f"early stop: {rec['early_stop']['reason']}")
        if rec["dispatch"]["process_warnings"]:
            reasons.append(
                f"analyst process warning/failure in "
                f"{len(rec['dispatch']['process_warnings'])} chunk(s)"
            )
        if remaining:
            reasons.append(f"{len(remaining)} lead(s) remain retryable/missing")
        rec["action"] = "; ".join(reasons) or "intake incomplete"
    _log_run(rec)
    print(json.dumps(rec, ensure_ascii=False))
    if run_ok:
        return 0
    return 2 if fatal_error else 1


if __name__ == "__main__":
    sys.exit(main())
