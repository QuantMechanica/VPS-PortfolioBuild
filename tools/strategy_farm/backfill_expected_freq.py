"""Backfill expected trade frequency frontmatter on approved Strategy Cards.

The helper is intentionally heuristic and idempotent: it only inserts
expected_trades_per_year_per_symbol when the key is absent.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


DEFAULT_CARDS_DIR = Path(r"D:\QM\strategy_farm\artifacts\cards_approved")
FIELD = "expected_trades_per_year_per_symbol"


def classify_expected_trades(card_text: str) -> int:
    text = card_text.lower()
    if any(token in text for token in (
        "halloween", "sell in may", "sell-in-may", "last trading day of october",
        "last trading day of april", "january barometer", "turn of the year",
        "year-end", "end of year", "annual",
    )):
        return 2
    if any(token in text for token in (
        "semiannual", "semi-annual", "6m rotation", "six month", "6-month",
    )):
        return 2
    if any(token in text for token in (
        "weekly", "w1", "friday", "weekend", "week-end",
    )):
        return 50
    if any(token in text for token in (
        "monthly", "month-end", "month end", "monatsende", "monatlich",
        "12-month", "12m", "252", "d1 close at month",
    )):
        return 12
    if any(token in text for token in (
        "m1", "m5", "m15", "m30", "h1", "intraday", "session open",
        "session close", "opening range",
    )):
        return 500
    if any(token in text for token in (
        "d1", "daily", "next day", "overnight", "mean reversion",
    )):
        return 150
    return 50


def backfill_card(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"(?s)^(---\s*\n)(.*?)(\n---\s*\n?)(.*)$", text)
    if not m:
        return {"path": str(path), "updated": False, "reason": "no_frontmatter"}
    frontmatter = m.group(2)
    if re.search(rf"(?m)^{re.escape(FIELD)}\s*:", frontmatter):
        return {"path": str(path), "updated": False, "reason": "already_present"}
    value = classify_expected_trades(text)
    new_text = f"{m.group(1)}{frontmatter}\n{FIELD}: {value}{m.group(3)}{m.group(4)}"
    path.write_text(new_text, encoding="utf-8", newline="\n")
    return {"path": str(path), "updated": True, "value": value}


def backfill(cards_dir: Path = DEFAULT_CARDS_DIR) -> list[dict]:
    if not cards_dir.is_dir():
        return []
    return [backfill_card(path) for path in sorted(cards_dir.glob("QM5_*.md"))]


def main() -> int:
    parser = argparse.ArgumentParser(description="Backfill expected trade frequency on approved cards.")
    parser.add_argument("--cards-dir", type=Path, default=DEFAULT_CARDS_DIR)
    parser.add_argument("--summary-only", action="store_true")
    args = parser.parse_args()
    results = backfill(args.cards_dir)
    updated = [r for r in results if r.get("updated")]
    print(f"cards={len(results)} updated={len(updated)} skipped={len(results) - len(updated)}")
    if not args.summary_only:
        for r in updated:
            print(f"{r['value']}\t{r['path']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
