"""Daily mailbox source-intake — read info@ forwards, analyze the sources, feed the factory.

OWNER forwards research links (reddit / YouTube / GitHub / articles / MQL5) to
info@quantmechanica.com. `sourcing_intake_sweep.py` already extracts those links read-only into
`D:\QM\reports\sourcing_intake\leads.csv` (status NEW). This wrapper adds the missing second half
the OWNER asked for (2026-07-22): a DAILY (06:00) run that

  1. runs the extraction sweep (reuses sourcing_intake_sweep.py unchanged), then
  2. for any NEW, not-yet-triaged leads, dispatches ONE headless AI analyst (Codex, detached) with a
     doctrine-bound, injection-safe prompt to: deep-read each source, judge it against R1-R4 + the
     FX-edge / structural-edge doctrine + the reputable-source criteria, and for QUALIFYING sources
     feed the factory via `farmctl add-source` (the canonical G0 intake) + a draft strategy card,
     marking each lead's status (QUALIFIED / REJECTED / DEFERRED) in leads.csv.

SAFETY MODEL (important)
  - The sweep already restricts to SELF-SENT mail (OWNER's own forwards), so senders are trusted.
    The LINKED CONTENT (web pages, reddit, repos) is still untrusted external data — the analyst
    prompt treats it as DATA, never as instructions, and never follows anything embedded in a page.
  - "Implement" = feed the normal pipeline (add-source → G0 review → Research → card → approve → build).
    The analyst NEVER approves cards, builds EAs, reserves ea_ids, touches T_Live, or any money/live
    gate. Those stay OWNER + Claude + the deterministic pipeline. This task fills the funnel; it does
    not bypass a single gate.
  - Extraction never depends on the AI: if the analyst dispatch fails or Codex is unavailable, the new
    leads are still captured (status NEW) for the next run / manual triage. The task exits 0 regardless
    (a scheduled task must not crash-loop).

Run manually:  python tools/strategy_farm/mailbox_source_intake.py [--dry-run] [--no-dispatch]
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(r"C:\QM\repo")
SWEEP = REPO_ROOT / "tools" / "strategy_farm" / "sourcing_intake_sweep.py"
PROMPT_TEMPLATE = REPO_ROOT / "tools" / "strategy_farm" / "prompts" / "mailbox_source_intake_prompt.md"
INTAKE_DIR = Path(r"D:\QM\reports\sourcing_intake")
LEADS_CSV = INTAKE_DIR / "leads.csv"
TRIAGE_STATE = INTAKE_DIR / "analyst_triage_state.json"   # UIDs already handed to an analyst
RUN_LOG = INTAKE_DIR / "mailbox_source_intake_run_log.jsonl"
PROMPT_OUT_DIR = INTAKE_DIR / "analyst_prompts"

PYTHONW = r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe"
PYTHON = r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
CODEX_CMD = r"C:\Users\Administrator\AppData\Roaming\npm\codex.cmd"
POWERSHELL = r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

CREATE_NO_WINDOW = 0x08000000
DETACHED_PROCESS = 0x00000008


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


def load_new_leads(already: set[str]) -> list[dict]:
    """NEW-status leads not yet handed to an analyst."""
    if not LEADS_CSV.exists():
        return []
    out: list[dict] = []
    try:
        with LEADS_CSV.open("r", encoding="utf-8", newline="") as fh:
            for row in csv.DictReader(fh):
                if (row.get("status") or "").strip().upper() == "NEW" and row.get("url") not in already:
                    out.append(row)
    except Exception:
        return []
    return out


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
    """Headless Codex analyst — pipes the prompt into `codex exec` (proven stdin pattern), SYNCHRONOUS.

    Runs blocking so the scheduled task's lifetime covers the analysis (task ExecutionTimeLimit=1h;
    codex timeout below is 50min). All codex output is redirected to the per-run log via `*>`.
    """
    if not Path(CODEX_CMD).exists():
        return {"dispatched": False, "reason": "codex.cmd not found"}
    PROMPT_OUT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S")
    prompt_path = PROMPT_OUT_DIR / f"analyst_{stamp}.md"
    log_path = PROMPT_OUT_DIR / f"analyst_{stamp}.log"
    try:
        prompt_path.write_text(prompt, encoding="utf-8")
        ps = (
            f"$ErrorActionPreference='Continue'; "
            f"Get-Content -Raw '{prompt_path}' | "
            f"& '{CODEX_CMD}' exec -s danger-full-access --cd '{REPO_ROOT}' "
            f"-m gpt-5.6-sol -c model_reasoning_effort=\"high\" *> '{log_path}'"
        )
        p = subprocess.run(
            [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps],
            cwd=str(REPO_ROOT), creationflags=CREATE_NO_WINDOW, timeout=3000,
        )
        ok = log_path.exists() and log_path.stat().st_size > 200
        out = {"dispatched": ok, "returncode": p.returncode, "prompt": str(prompt_path), "log": str(log_path)}
        if not ok:
            out["reason"] = "codex produced no/low output"
        return out
    except subprocess.TimeoutExpired:
        return {"dispatched": True, "note": "codex timed out at 3000s (analysis may be partial)",
                "prompt": str(prompt_path), "log": str(log_path)}
    except Exception as exc:
        return {"dispatched": False, "reason": f"dispatch error: {exc!r}", "log": str(log_path)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="sweep in dry-run; do not dispatch analyst")
    ap.add_argument("--no-dispatch", action="store_true", help="extract + report new leads but do not dispatch the analyst")
    args = ap.parse_args()

    rec: dict = {"ts": _now_iso(), "dry_run": args.dry_run}
    sweep = run_sweep(args.dry_run)
    rec["sweep"] = sweep

    already = _load_triaged()
    leads = load_new_leads(already)
    rec["new_leads"] = len(leads)

    if args.dry_run:
        rec["action"] = "dry-run: no dispatch"
        print(json.dumps(rec, ensure_ascii=False, indent=1))
        _log_run(rec)
        return 0

    if not leads:
        rec["action"] = "no new leads — no-op"
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False))
        return 0

    if args.no_dispatch:
        rec["action"] = f"{len(leads)} new leads captured; dispatch suppressed (--no-dispatch)"
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False, indent=1))
        return 0

    prompt = build_prompt(leads)
    if not prompt:
        rec["action"] = "prompt template missing — leads left NEW for next run"
        _log_run(rec)
        print(json.dumps(rec, ensure_ascii=False))
        return 0

    disp = dispatch_analyst(prompt)
    rec["dispatch"] = disp
    if disp.get("dispatched"):
        # Mark these URLs as handed to an analyst so we don't re-dispatch them tomorrow.
        _save_triaged(already | {r.get("url") for r in leads if r.get("url")})
        rec["action"] = f"dispatched analyst on {len(leads)} new lead(s)"
    else:
        rec["action"] = f"analyst dispatch failed; {len(leads)} leads left NEW for retry"
    _log_run(rec)
    print(json.dumps(rec, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
