"""Summarize verdicts from verify_import_candidate output logs."""
from __future__ import annotations

import argparse
import re
from collections import Counter
from pathlib import Path

LINE_RE = re.compile(r"^\[(?P<verdict>[^\]]+)\]\s+(?P<symbol>[^:]+):")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("log_path")
    args = ap.parse_args()

    p = Path(args.log_path)
    text = p.read_text(encoding="utf-8")
    rows: list[tuple[str, str]] = []
    for line in text.splitlines():
        m = LINE_RE.match(line.strip())
        if not m:
            continue
        rows.append((m.group("symbol").strip(), m.group("verdict").strip()))

    latest: dict[str, str] = {}
    for sym, verdict in rows:
        latest[sym] = verdict

    print(f"log={p}")
    print(f"rows={len(rows)}")
    print(f"unique_symbols={len(latest)}")
    print("rows_verdict_counts")
    for verdict, count in Counter(v for _, v in rows).most_common():
        print(f"- {verdict}: {count}")
    print("latest_verdict_counts")
    for verdict, count in Counter(latest.values()).most_common():
        print(f"- {verdict}: {count}")
    ok_symbols = sorted([s for s, v in latest.items() if v == "OK"])
    print(f"latest_ok_symbols={ok_symbols}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

