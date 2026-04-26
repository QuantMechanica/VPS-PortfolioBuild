from __future__ import annotations

import hashlib
import os
import re
import sys
import time
import traceback
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

ROOT = Path(r"G:\Meine Ablage\QuantMechanica")
TODO_PATH = ROOT / "Company" / "TODO.md"
PROOF_PATH = ROOT / "Company" / "Results" / "CODEX_FEED_APPEND_FIX.md"
STATE_PATH = ROOT / "Company" / "Results" / "pipeline_feed_guard_state.json"
EA_STATE_FILE = Path(
    r"C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal"
    r"\6C3C6A11D1C3791DD4DBF45421BF8028\MQL5\Experts\EA_Testing\last_check_state.json"
)
ANCHOR_TOKEN = "APPEND-ANKER"
FEED_LINE_RE = re.compile(r"^\s*-\s*\[\s?.\]\s*(?:!EVENT!\s*)?\[\d{2}:\d{2}\]\s*disk=\d+GB\s*\|")
RECOVERY_THRESHOLD = 3  # consecutive cycles with advancing EA state mtime


@dataclass(frozen=True)
class NormalizeResult:
    changed: bool
    moved_lines: list[str]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")


def line_key(line: str) -> str:
    return hashlib.sha1(line.strip().encode("utf-8")).hexdigest()


def ensure_proof_header() -> None:
    if PROOF_PATH.exists():
        return
    write_text(
        PROOF_PATH,
        "\n".join(
            [
                "# CODEX_FEED_APPEND_FIX",
                "",
                "Status: IN PROGRESS",
                "",
                "Goal: prevent pipeline status-feed writes from staying orphaned at the end of `Company/TODO.md`.",
                "",
                "Proof Log:",
            ]
        ) + "\n",
    )


def append_proof(message: str) -> None:
    ensure_proof_header()
    with PROOF_PATH.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"- [{datetime.now().strftime('%Y-%m-%d %H:%M:%S CET')}] {message}\n")


def fd_diag(exc: BaseException) -> str:
    """Return a compact lock/fd diagnostic string for an OS-level exception."""
    parts = [f"{type(exc).__name__}: {exc}"]
    if hasattr(exc, "errno") and exc.errno is not None:
        parts.append(f"errno={exc.errno} ({os.strerror(exc.errno)})")
    if hasattr(exc, "winerror") and exc.winerror is not None:
        parts.append(f"winerror={exc.winerror}")
    if hasattr(exc, "filename") and exc.filename:
        parts.append(f"file={exc.filename!r}")
    return " | ".join(parts)


def trace(msg: str) -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def normalize_feed() -> NormalizeResult:
    lines = read_text(TODO_PATH).splitlines()
    anchor_idx = next(i for i, line in enumerate(lines) if ANCHOR_TOKEN in line)
    section_end = next((i for i in range(anchor_idx + 1, len(lines)) if lines[i].strip() == "---"), len(lines))

    feed_block = lines[anchor_idx + 1:section_end]
    kept_feed: list[str] = []
    existing_keys: set[str] = set()
    for line in feed_block:
        if FEED_LINE_RE.match(line):
            key = line_key(line)
            if key not in existing_keys:
                kept_feed.append(line)
                existing_keys.add(key)
        else:
            kept_feed.append(line)

    moved_lines: list[str] = []
    outside_lines: list[str] = []
    for idx, line in enumerate(lines):
        if anchor_idx < idx < section_end:
            continue
        if FEED_LINE_RE.match(line):
            key = line_key(line)
            if key not in existing_keys:
                moved_lines.append(line)
                existing_keys.add(key)
            continue
        outside_lines.append(line)

    if not moved_lines:
        return NormalizeResult(changed=False, moved_lines=[])

    rebuilt: list[str] = []
    inserted = False
    for line in outside_lines:
        rebuilt.append(line)
        if ANCHOR_TOKEN in line and not inserted:
            rebuilt.extend(kept_feed)
            rebuilt.extend(moved_lines)
            inserted = True

    write_text(TODO_PATH, "\n".join(rebuilt).rstrip() + "\n")
    return NormalizeResult(changed=True, moved_lines=moved_lines)


def json_escape(value: str) -> str:
    return value.replace('\\', '\\\\').replace('"', '\\"')


def write_state(last_message: str) -> None:
    payload = (
        "{\n"
        f'  "updated_at": "{datetime.now().strftime("%Y-%m-%dT%H:%M:%S")}",\n'
        f'  "last_message": "{json_escape(last_message)}"\n'
        "}\n"
    )
    write_text(STATE_PATH, payload)


def ea_state_mtime() -> float | None:
    """Return mtime of EA's last_check_state.json, or None if unreadable."""
    try:
        return EA_STATE_FILE.stat().st_mtime
    except OSError:
        return None


def main() -> None:
    append_proof("Feed guard started.")
    trace("Feed guard started.")
    cycle = 0
    prev_ea_mtime: float | None = None
    advance_streak = 0

    while True:
        cycle += 1
        trace(f"Cycle {cycle} start")

        try:
            result = normalize_feed()
            if result.changed:
                moved_times = ", ".join(
                    re.search(r"\[(\d{2}:\d{2})\]", line).group(1) for line in result.moved_lines
                )
                message = f"Moved {len(result.moved_lines)} orphan feed line(s) under APPEND-ANKER: {moved_times}."
                append_proof(message)
                write_state(message)
            else:
                write_state("No orphan feed lines detected.")

            # Recovery detection: require 3 consecutive cycles with advancing EA state mtime
            cur_mtime = ea_state_mtime()
            if cur_mtime is None:
                advance_streak = 0
                trace(f"Cycle {cycle} end | EA state file unreadable — streak reset to 0")
            elif prev_ea_mtime is None or cur_mtime > prev_ea_mtime:
                advance_streak += 1
                trace(
                    f"Cycle {cycle} end | changed={result.changed} | "
                    f"EA mtime advanced (streak={advance_streak}/{RECOVERY_THRESHOLD})"
                )
                if advance_streak >= RECOVERY_THRESHOLD:
                    recovery_msg = (
                        f"RECOVERY CONFIRMED: EA state mtime advanced for "
                        f"{advance_streak} consecutive cycles."
                    )
                    trace(recovery_msg)
                    append_proof(recovery_msg)
            else:
                advance_streak = 0
                trace(
                    f"Cycle {cycle} end | changed={result.changed} | "
                    f"EA mtime stale (mtime={cur_mtime}) — streak reset to 0"
                )
            prev_ea_mtime = cur_mtime

        except Exception:
            tb = traceback.format_exc()
            # Extract innermost OS error for lock/fd diagnostics
            cause: BaseException | None = sys.exc_info()[1]
            diag = ""
            while cause is not None:
                if isinstance(cause, OSError):
                    diag = f" | fd_diag: {fd_diag(cause)}"
                    break
                cause = cause.__cause__ or cause.__context__
            trace(f"Cycle {cycle} EXCEPTION{diag}")
            print(tb, flush=True)
            try:
                append_proof(f"Cycle {cycle} EXCEPTION{diag}:\n{tb.strip()}")
                write_state(f"ERROR cycle {cycle}: {sys.exc_info()[1]}")
            except Exception:
                pass  # write_state itself failed; can't recover here

        time.sleep(10)


if __name__ == "__main__":
    main()
