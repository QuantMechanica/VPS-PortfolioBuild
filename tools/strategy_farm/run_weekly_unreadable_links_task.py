"""Windowless Scheduled-Task wrapper for the Friday unreadable-links mail."""

from __future__ import annotations

import contextlib
import runpy
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(r"C:\QM\repo")
LOG_PATH = Path(r"C:\Windows\Temp\weekly_unreadable_links_mail.log")
SCRIPT_PATH = (
    REPO_ROOT / "tools" / "strategy_farm" / "weekly_unreadable_links_mail.py"
)


def _ts() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def main() -> int:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8", newline="\n") as log:
        with contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
            print(f"[{_ts()}] weekly_unreadable_links_task start", flush=True)
            try:
                runpy.run_path(str(SCRIPT_PATH), run_name="__main__")
            except SystemExit as exc:
                code = int(exc.code or 0) if isinstance(exc.code, int) else 1
                print(
                    f"[{_ts()}] weekly_unreadable_links_task exit={code}",
                    flush=True,
                )
                return code
            except Exception:
                traceback.print_exc()
                print(
                    f"[{_ts()}] weekly_unreadable_links_task exit=1",
                    flush=True,
                )
                return 1
            print(f"[{_ts()}] weekly_unreadable_links_task exit=0", flush=True)
            return 0


if __name__ == "__main__":
    raise SystemExit(main())
