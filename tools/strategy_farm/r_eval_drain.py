"""R-eval drain lane (Claude, 2026-06-10, OWNER-approved acceleration).

Root cause: the pump queues auto-r-eval-*.md task files into codex_inbox,
but the goal-bridge consumer died 2026-05-17 — 1,323 files unconsumed,
leaving 1,212 approved cards stuck at r_gate_not_pass and therefore never
built. This runner drains the backlog directly: per run it picks a batch of
cards with UNKNOWN R-fields and spawns ONE headless Claude (Sonnet, per
farmctl._claude_env) that evaluates each card against
processes/qb_reputable_source_criteria.md and updates the frontmatter
in place (PASS/FAIL + reasoning). Completed cards' inbox files are archived.

Guards: quota (pauses when Claude weekly or Sonnet weekly > 85%), lock file,
20-min spawn timeout. Scheduled task: QM_StrategyFarm_REvalDrain_20min.
Self-terminating: no-ops when no UNKNOWN cards remain.
"""
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, r"C:\QM\repo\tools\strategy_farm")
import farmctl  # noqa: E402

ROOT = Path(r"D:\QM\strategy_farm")
CARDS = ROOT / "artifacts" / "cards_approved"
INBOX = ROOT / "codex_inbox"
ARCHIVE = INBOX / ".archive" / "r_eval_done"
LOCK = ROOT / "state" / "locks" / "r_eval_drain.lock"
LOG = Path(r"D:\QM\reports\state\r_eval_drain.jsonl")
QUOTA = ROOT / "state" / "quota_snapshot.json"
CRITERIA = Path(r"C:\QM\repo\processes\qb_reputable_source_criteria.md")
BATCH = 12
TIMEOUT_S = 20 * 60
QUOTA_CEILING = 85.0
R_KEYS = ("r1_track_record", "r2_mechanical", "r3_data_available", "r4_ml_forbidden")


def log(event: dict) -> None:
    event["ts"] = datetime.now(timezone.utc).isoformat()
    with LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event) + "\n")


def card_unknown(card_path: Path) -> bool:
    try:
        fm = farmctl.parse_card_frontmatter(card_path)
    except Exception:
        return False
    if not farmctl._card_r1_build_ready(fm):
        return True
    return any(
        str(fm.get(key) or "UNKNOWN").strip().upper() not in ("PASS", "FAIL")
        for key in farmctl.R_STRICT_PASS_FIELDS
    )


def quota_ok() -> tuple[bool, str]:
    try:
        s = json.loads(QUOTA.read_text(encoding="utf-8"))
        d = s["claude"]["data"]
        week = float(d.get("structured", {}).get("week_pct") or d.get("matches", {}).get("week_pct") or 0)
        sonnet = float(d.get("sonnet_pct") or 0)
    except Exception as e:
        return True, f"quota_unreadable({e})"  # fail-open: drain is low volume
    if week > QUOTA_CEILING or sonnet > QUOTA_CEILING:
        return False, f"week={week} sonnet={sonnet} > {QUOTA_CEILING}"
    return True, f"week={week} sonnet={sonnet}"


def main() -> int:
    # lock (stale after 45 min)
    if LOCK.exists() and time.time() - LOCK.stat().st_mtime < 45 * 60:
        return 0
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    LOCK.write_text(str(os.getpid()), encoding="utf-8")
    try:
        ok, detail = quota_ok()
        if not ok:
            log({"event": "paused_quota", "detail": detail})
            return 0

        batch = []
        for card in sorted(CARDS.glob("QM5_*.md")):
            if card_unknown(card):
                batch.append(card)
                if len(batch) >= BATCH:
                    break
        if not batch:
            log({"event": "drained_nothing_left"})
            return 0

        card_list = "\n".join(f"- {c}" for c in batch)
        prompt = f"""You are the QM R-gate evaluator (mechanical checklist task).

Read the criteria file: {CRITERIA}

Then, for EACH card file below, one at a time:
1. Read the card (YAML frontmatter + body).
2. Evaluate only R-fields that do not already carry a final value:
   - r1_track_record  (source-quality tier; final values are PASS, TIER_A,
     TIER_B, TIER_C, or FAIL)
   - r2_mechanical    (rules fully mechanical, no discretion, no ML)
   - r3_data_available (symbols/timeframe testable on our DWX MT5 data)
   - r4_ml_forbidden  (no machine-learning components)
3. Preserve every already-final value exactly, especially an existing R1 tier.
   For unresolved fields, edit the card file IN PLACE: set R1 to TIER_A,
   TIER_B, or TIER_C when source_id exists (unknown author reputation is valid);
   when source_id is absent, set it to
   {farmctl.OWNER_SOURCE_RECOVERY_ID} and record Fabian Grabner (OWNER) as the
   canonical source instead of rejecting R1. Set R2-R4 to PASS or FAIL; and
   add/update matching reasoning keys
   (r1_reasoning, r2_reasoning, r3_reasoning, r4_reasoning - one concise
   sentence each). Do not touch any other frontmatter key. Do not modify
   the card body. Preserve YAML validity.
Be strict on R2-R4 mechanics/data/ML. Never fail a card solely because its
author, reputation, or original citation is unknown; apply the OWNER source
fallback above.
No commit, no push, no other files. When all cards are done, exit.

Cards:
{card_list}
"""
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        prompt_file = ROOT / "logs" / f"r_eval_drain_{ts}.prompt.txt"
        live_log = ROOT / "logs" / f"r_eval_drain_{ts}.live.log"
        prompt_file.write_text(prompt, encoding="utf-8", newline="\n")

        claude_path = farmctl._resolve_claude()
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        with open(prompt_file, "rb") as stdin_f, open(live_log, "wb") as stdout_f:
            proc = subprocess.Popen(
                [claude_path, "-p",
                 "--permission-mode", "bypassPermissions",
                 "--add-dir", "C:\\QM\\repo",
                 "--add-dir", "D:\\QM\\strategy_farm"],
                cwd=r"C:\QM\repo",
                env=farmctl._claude_env(),
                stdin=stdin_f, stdout=stdout_f, stderr=subprocess.STDOUT,
                shell=True, creationflags=creationflags, close_fds=True,
            )
            try:
                rc = proc.wait(timeout=TIMEOUT_S)
            except subprocess.TimeoutExpired:
                proc.kill()
                rc = -9

        done, still_unknown = [], []
        ARCHIVE.mkdir(parents=True, exist_ok=True)
        for card in batch:
            if card_unknown(card):
                still_unknown.append(card.name)
                continue
            done.append(card.name)
            ea_id = "_".join(card.stem.split("_")[:2])
            for f in INBOX.glob(f"auto-r-eval-{ea_id}-*.md"):
                try:
                    f.rename(ARCHIVE / f.name)
                except OSError:
                    pass
        log({"event": "batch_done", "rc": rc, "batch": len(batch),
             "evaluated": done, "still_unknown": still_unknown,
             "live_log": str(live_log)})
        return 0
    finally:
        LOCK.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
