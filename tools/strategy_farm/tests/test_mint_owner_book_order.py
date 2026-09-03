"""Tests for tools/strategy_farm/mint_owner_book_order.py (runbook gap G1).

Covers:
* a minted file parses as VALID through the guard's own parser, for every venue;
* a corrupted OWNER-ORDER line is reported INVALID;
* the default refuses to write into a decisions/ directory (fail-closed).
"""
from __future__ import annotations

import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import mint_owner_book_order as mint  # noqa: E402
from tools.strategy_farm import book_build_guard  # noqa: E402


TODAY = dt.date.today().isoformat()
VENUES = ("dxz", "ftmo", "both")


def _mint(order_dir: Path, venue: str, date_str: str = TODAY, extra=None) -> int:
    argv = [
        "--venue",
        venue,
        "--date",
        date_str,
        "--order-dir",
        str(order_dir),
        "--author",
        "OWNER",
        "--session",
        "sess-test",
    ]
    if extra:
        argv.extend(extra)
    return mint.main(argv)


# ---------------------------------------------------------------------------
# 1. A minted file parses as valid through the guard parser, for each venue.
# ---------------------------------------------------------------------------
def test_minted_file_valid_for_each_venue(tmp_path):
    for venue in VENUES:
        out = tmp_path / f"scratch_{venue}"
        rc = _mint(out, venue)
        assert rc == 0, f"mint returned {rc} for venue={venue}"

        target = out / mint.order_filename(venue, TODAY)
        assert target.is_file(), f"expected minted file {target}"

        # Guard-parser round-trip via the tool's helper.
        is_valid, parsed_venue, reasons = mint.validate_order_file(target)
        assert is_valid, f"venue={venue} reasons={reasons}"
        assert parsed_venue == venue

        # Direct round-trip through the guard's own private parser, in isolation.
        artifact, guard_reasons = book_build_guard._find_owner_order(
            venue, target.parent, today=dt.date.today()
        )
        assert artifact is not None, f"guard refused venue={venue}: {guard_reasons}"
        assert Path(artifact).name == target.name

        # The exact mandated line is present verbatim.
        text = target.read_text(encoding="utf-8")
        assert f"OWNER-ORDER: BOOK_BUILD {venue} {TODAY}" in text.splitlines()


def test_dxz_order_satisfies_a_both_request_but_not_vice_versa(tmp_path):
    # Mirrors _compatible_order_venues (book_build_guard.py:112-115): a `both`
    # order also satisfies a dxz/ftmo request; a dxz order does NOT satisfy a
    # `both` request.
    both_dir = tmp_path / "both"
    assert _mint(both_dir, "both") == 0
    both_file = both_dir / mint.order_filename("both", TODAY)
    artifact, _ = book_build_guard._find_owner_order(
        "dxz", both_file.parent, today=dt.date.today()
    )
    assert artifact is not None  # both-order satisfies a dxz request

    dxz_dir = tmp_path / "dxz"
    assert _mint(dxz_dir, "dxz") == 0
    dxz_file = dxz_dir / mint.order_filename("dxz", TODAY)
    artifact_both, reasons = book_build_guard._find_owner_order(
        "both", dxz_file.parent, today=dt.date.today()
    )
    assert artifact_both is None  # dxz-order does NOT satisfy a both request
    assert any("wrong_venue" in r for r in reasons)


# ---------------------------------------------------------------------------
# 2. A corrupted OWNER-ORDER line is reported invalid.
# ---------------------------------------------------------------------------
def test_corrupted_line_reported_invalid(tmp_path):
    out = tmp_path / "scratch"
    assert _mint(out, "dxz") == 0
    target = out / mint.order_filename("dxz", TODAY)

    good = target.read_text(encoding="utf-8")
    corrupted = good.replace("BOOK_BUILD", "BOOK_BUILT")  # keep filename valid
    assert corrupted != good
    target.write_text(corrupted, encoding="utf-8")

    is_valid, venue, reasons = mint.validate_order_file(target)
    assert not is_valid
    assert venue == "dxz"
    assert any("owner_order_invalid" in r for r in reasons), reasons


def test_validate_reports_reason_for_wrong_filename(tmp_path):
    bogus = tmp_path / "not_an_order.md"
    bogus.write_text("OWNER-ORDER: BOOK_BUILD dxz " + TODAY + "\n", encoding="utf-8")
    is_valid, venue, reasons = mint.validate_order_file(bogus)
    assert not is_valid
    assert venue is None
    assert any("filename_does_not_match_order_grammar" in r for r in reasons), reasons


def test_validate_missing_file(tmp_path):
    is_valid, venue, reasons = mint.validate_order_file(tmp_path / "nope.md")
    assert not is_valid
    assert any("not_a_file" in r for r in reasons)


# ---------------------------------------------------------------------------
# 3. Default refuses to write into a decisions/ directory.
# ---------------------------------------------------------------------------
def test_default_refuses_decisions_dir(tmp_path):
    decisions = tmp_path / "decisions"
    rc = _mint(decisions, "dxz")  # no --i-am-owner
    assert rc == 2
    target = decisions / mint.order_filename("dxz", TODAY)
    assert not target.exists()
    # The directory itself must not have been created behind the refusal.
    assert not decisions.exists()


def test_nested_decisions_dir_also_refused(tmp_path):
    nested = tmp_path / "decisions" / "sub"
    rc = _mint(nested, "dxz")
    assert rc == 2
    assert not (nested / mint.order_filename("dxz", TODAY)).exists()


def test_i_am_owner_allows_decisions_dir(tmp_path):
    decisions = tmp_path / "decisions"
    rc = _mint(decisions, "dxz", extra=["--i-am-owner"])
    assert rc == 0
    target = decisions / mint.order_filename("dxz", TODAY)
    assert target.is_file()
    is_valid, _venue, reasons = mint.validate_order_file(target)
    assert is_valid, reasons


# ---------------------------------------------------------------------------
# Extra guardrails.
# ---------------------------------------------------------------------------
def test_order_dir_required_for_write(tmp_path, capsys):
    rc = mint.main(["--venue", "dxz", "--date", TODAY])
    assert rc == 2
    payload = json.loads(capsys.readouterr().out)
    assert payload["written"] is False
    assert "order_dir_required" in payload["error"]


def test_dry_run_prints_content_and_writes_nothing(tmp_path, capsys):
    rc = mint.main(["--venue", "ftmo", "--date", TODAY, "--dry-run"])
    assert rc == 0
    out = capsys.readouterr().out
    assert f"OWNER-ORDER: BOOK_BUILD ftmo {TODAY}" in out.splitlines()
    # nothing written anywhere under tmp_path
    assert not list(tmp_path.rglob("*_owner_book_order_*.md"))


def test_future_date_refused(tmp_path, capsys):
    future = (dt.date.today() + dt.timedelta(days=5)).isoformat()
    rc = _mint(tmp_path / "scratch", "dxz", date_str=future)
    assert rc == 2
    payload = json.loads(capsys.readouterr().out)
    assert "future" in payload["error"].lower()
    assert not (tmp_path / "scratch").exists()


def test_refuses_to_overwrite_without_force(tmp_path):
    out = tmp_path / "scratch"
    assert _mint(out, "dxz") == 0
    rc = _mint(out, "dxz")  # second mint, same target
    assert rc == 2
    assert _mint(out, "dxz", extra=["--force"]) == 0


def test_cli_subprocess_dry_run(tmp_path):
    # Confirm the module runs as a script (self sys.path insert in __main__).
    script = REPO / "tools" / "strategy_farm" / "mint_owner_book_order.py"
    proc = subprocess.run(
        [sys.executable, str(script), "--venue", "both", "--date", TODAY, "--dry-run"],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr
    assert f"OWNER-ORDER: BOOK_BUILD both {TODAY}" in proc.stdout.splitlines()
