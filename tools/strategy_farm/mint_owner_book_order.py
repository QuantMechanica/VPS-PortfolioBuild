#!/usr/bin/env python3
"""Mint and validate OWNER book-build order files for ``book_build_guard``.

``book_build_guard._find_owner_order`` (book_build_guard.py:116) is the second
mandatory authority for book-build analysis entry. It hand-parses a decision file
named ``decisions/<YYYY-MM-DD>_owner_book_order_<venue>.md`` and requires the exact
line ``OWNER-ORDER: BOOK_BUILD <venue> <date>`` (book_build_guard.py:150), with venue
and date taken from the FILENAME. Nothing wrote or validated such a file before, so a
typo failed silently as ``owner_order_invalid`` (runbook gap G1,
docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md).

This tool closes that gap. It:

* emits the exact filename + the exact ``OWNER-ORDER:`` line into a caller-supplied
  ``--order-dir`` (there is no default: the flag is required for a real write);
* refuses to write into any ``decisions/`` directory unless the caller is the OWNER and
  passes ``--i-am-owner`` -- an AI seat mints into a scratch dir, and the OWNER signs by
  COMMITTING the file into ``decisions/``;
* ``--dry-run`` prints the exact content without writing;
* ``--validate <path>`` round-trips a file through ``book_build_guard._find_owner_order``
  (the same parser the guard uses) and reports valid/invalid with the reason.

This module NEVER touches the farm DB, queues, verdicts, factory state, deploy trees,
gate criteria, or AutoTrading. It only reads/writes plain decision-file text.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import sys
import tempfile
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import book_build_guard


SUPPORTED_VENUES = tuple(sorted(book_build_guard.SUPPORTED_VENUES))


def order_filename(venue: str, date_str: str) -> str:
    """The exact filename the guard regex accepts (book_build_guard.py:33-36)."""
    return f"{date_str}_owner_book_order_{venue}.md"


def owner_order_line(venue: str, date_str: str) -> str:
    """The exact machine-checked line (book_build_guard.py:150)."""
    return f"OWNER-ORDER: BOOK_BUILD {venue} {date_str}"


def _validate_date_token(date_str: str, *, today: dt.date) -> dt.date:
    """Parse an ISO date the way the guard does and refuse a future one.

    The guard rejects a future-dated order (``owner_order_future_dated``,
    book_build_guard.py:148), so minting one would produce a file that does not
    round-trip as valid today. Fail closed here instead.
    """
    try:
        parsed = dt.date.fromisoformat(date_str)
    except ValueError as exc:
        raise ValueError(
            f"--date must be an ISO calendar date (YYYY-MM-DD); got {date_str!r}: {exc}"
        ) from exc
    if parsed > today:
        raise ValueError(
            f"--date {date_str} is in the future (today={today.isoformat()}); the guard "
            f"would refuse it as owner_order_future_dated"
        )
    return parsed


def render_order_text(
    venue: str,
    date_str: str,
    *,
    author: str,
    session: str,
    generated_at: str,
) -> str:
    """Render the full order-file content, including the exact OWNER-ORDER line."""
    line = owner_order_line(venue, date_str)
    session_display = session if session else "unspecified"
    author_display = author if author else "OWNER"
    body = [
        f"# OWNER Book-Build Order -- {venue} -- {date_str}",
        "",
        f"- Venue: {venue}",
        f"- Effective date: {date_str}",
        f"- Author: {author_display}",
        f"- Generated (UTC): {generated_at}",
        f"- Session: {session_display}",
        "- Generator: tools/strategy_farm/mint_owner_book_order.py",
        "",
        "The line below is the machine-checked authorization token. book_build_guard",
        "(_find_owner_order, book_build_guard.py:116) requires it verbatim (stripped),",
        "with venue and date taken from THIS file's name. Do not edit it by hand.",
        "",
        line,
        "",
        "## What this authorizes",
        "",
        f"Entry into book-build ANALYSIS (dry-run/analytic) for the {venue} venue on the",
        "effective date, and nothing more. See docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md",
        "section 2 for the full ceremony step list.",
        "",
        "## What this does NOT authorize",
        "",
        "Live weights, T_Live writes, AutoTrading, or a risk-freeze lift. Each of those",
        "remains a separate OWNER act.",
        "",
        "## Signing",
        "",
        "This order is effective only when the OWNER COMMITS this file into decisions/",
        "with an explicit pathspec. Minting alone authorizes nothing.",
        "",
    ]
    return "\n".join(body)


def _path_is_decisions_dir(order_dir: Path) -> bool:
    """True if ``order_dir`` is (or is inside) a ``decisions`` directory.

    The guard's DEFAULT_ORDER_DIR is ``REPO_ROOT / 'decisions'`` and a real order file
    belongs only there. An AI seat must never write one; it mints into a scratch dir and
    the OWNER commits the file. Detect any ``decisions`` path component so a scratch dir
    literally named ``.../decisions`` is caught too.
    """
    resolved = Path(order_dir).resolve()
    return any(part.lower() == "decisions" for part in resolved.parts)


def validate_order_file(
    path: str | Path,
    *,
    today: dt.date | None = None,
) -> tuple[bool, str | None, list[str]]:
    """Round-trip ``path`` through the guard's own ``_find_owner_order`` parser.

    Returns ``(is_valid, venue_or_None, reasons)``. The file is copied into an isolated
    temporary directory so the guard parser considers ONLY this file (its glob would
    otherwise pick up every order file in the real directory).
    """
    today = today or dt.date.today()
    path = Path(path)
    if not path.is_file():
        return False, None, [f"not_a_file: {path}"]

    match = book_build_guard._ORDER_NAME.fullmatch(path.name)
    if match is None:
        return (
            False,
            None,
            [
                "filename_does_not_match_order_grammar: "
                f"{path.name!r} (expected "
                "<YYYY-MM-DD>_owner_book_order_<dxz|ftmo|both>.md)"
            ],
        )
    venue = match.group("venue")

    with tempfile.TemporaryDirectory(prefix="mint_owner_book_order_") as tmp:
        dest = Path(tmp) / path.name
        shutil.copyfile(path, dest)
        artifact, reasons = book_build_guard._find_owner_order(
            venue, Path(tmp), today=today
        )
    if artifact is not None:
        return True, venue, []
    return False, venue, reasons


def _do_validate(path: Path) -> int:
    is_valid, venue, reasons = validate_order_file(path)
    result = {
        "mode": "validate",
        "path": str(Path(path)),
        "venue": venue,
        "valid": is_valid,
        "reasons": reasons,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if is_valid else 2


def _do_mint(args: argparse.Namespace) -> int:
    today = dt.date.today()
    venue = book_build_guard._normalize_venue(args.venue)
    date_str = args.date or today.isoformat()
    _validate_date_token(date_str, today=today)

    generated_at = (
        dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    )
    content = render_order_text(
        venue,
        date_str,
        author=args.author,
        session=args.session,
        generated_at=generated_at,
    )
    filename = order_filename(venue, date_str)

    if args.dry_run:
        # Print the exact content only -- no write, no JSON wrapper -- so the OWNER
        # can eyeball or pipe it. --order-dir is not required for a dry run.
        sys.stdout.write(content)
        if not content.endswith("\n"):
            sys.stdout.write("\n")
        return 0

    if args.order_dir is None:
        print(
            json.dumps(
                {
                    "mode": "mint",
                    "written": False,
                    "error": "order_dir_required: pass --order-dir <dir> to write "
                    "(or --dry-run to preview). There is no default directory.",
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2

    order_dir = Path(args.order_dir)
    if _path_is_decisions_dir(order_dir) and not args.i_am_owner:
        print(
            json.dumps(
                {
                    "mode": "mint",
                    "written": False,
                    "order_dir": str(order_dir),
                    "error": "refusing_to_write_into_decisions: an AI seat never writes "
                    "an order file into a decisions/ directory. Mint into a scratch dir "
                    "and let the OWNER commit it. If you ARE the OWNER, re-run with "
                    "--i-am-owner.",
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2

    target = order_dir / filename
    if target.exists() and not args.force:
        print(
            json.dumps(
                {
                    "mode": "mint",
                    "written": False,
                    "path": str(target),
                    "error": "target_exists: refusing to overwrite. Pass --force to "
                    "replace it.",
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2

    order_dir.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")

    # Belt and suspenders: confirm the file we just wrote round-trips as valid.
    is_valid, _venue, reasons = validate_order_file(target)
    print(
        json.dumps(
            {
                "mode": "mint",
                "written": True,
                "path": str(target.resolve()),
                "venue": venue,
                "date": date_str,
                "owner_order_line": owner_order_line(venue, date_str),
                "round_trip_valid": is_valid,
                "reasons": reasons,
                "note": "Not authorized yet. The OWNER signs by committing this file "
                "into decisions/ with an explicit pathspec.",
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0 if is_valid else 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Mint or validate an OWNER book-build order file for "
        "book_build_guard."
    )
    parser.add_argument(
        "--validate",
        metavar="PATH",
        type=Path,
        default=None,
        help="Validate an existing order file by round-tripping it through "
        "book_build_guard._find_owner_order; print valid/invalid + reasons.",
    )
    parser.add_argument(
        "--venue",
        choices=SUPPORTED_VENUES,
        help="Venue token for the order (required when minting).",
    )
    parser.add_argument(
        "--date",
        default=None,
        help="Effective ISO date YYYY-MM-DD (default: today). A future date is refused.",
    )
    parser.add_argument(
        "--order-dir",
        type=Path,
        default=None,
        help="Directory to write the order file into (REQUIRED for a real write; there "
        "is no default). Refuses any decisions/ dir unless --i-am-owner is also given.",
    )
    parser.add_argument(
        "--author",
        default="OWNER",
        help="Provenance: who authored the order (default: OWNER).",
    )
    parser.add_argument(
        "--session",
        default="",
        help="Provenance: session id or url.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the exact order-file content and exit without writing.",
    )
    parser.add_argument(
        "--i-am-owner",
        action="store_true",
        help="Permit writing into a decisions/ directory. AI seats must NOT pass this; "
        "the OWNER signs by committing the file.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite an existing target file.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.validate is not None:
        return _do_validate(args.validate)

    if args.venue is None:
        parser.error("--venue is required when minting (or use --validate <path>)")

    try:
        return _do_mint(args)
    except ValueError as exc:
        print(
            json.dumps(
                {"mode": "mint", "written": False, "error": str(exc)},
                indent=2,
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
