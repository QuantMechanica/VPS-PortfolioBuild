"""Drift guard + determinism tests for the Symbol List vault-page generator.

The vault page '06 Infrastructure/Symbol List' is generated from
framework/registry/dwx_symbol_matrix.csv by tools/vault/gen_symbol_list_page.py.
These tests enforce the two contract properties:

1. Determinism: identical CSV bytes -> byte-identical page, no wall-clock content.
2. Drift guard: the committed vault page must equal the page generated from the
   committed matrix CSV. A matrix change therefore fails this test until someone
   reruns `python tools/vault/gen_symbol_list_page.py --write`.

The drift-guard test skips gracefully if the vault page is not mounted (e.g. a
CI box without the G: drive); on the VPS it runs for real.
"""

import hashlib
import re
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_symbol_list_page as gen  # noqa: E402


REPO_MATRIX = gen.MATRIX_CSV
HEARTBEAT = gen.REPO_ROOT / "tools" / "strategy_farm" / "heartbeat_snapshot.py"


def _matrix_bytes() -> bytes:
    return REPO_MATRIX.read_bytes()


def test_matrix_csv_present():
    assert REPO_MATRIX.exists(), f"matrix CSV missing: {REPO_MATRIX}"


def test_render_is_deterministic():
    data = _matrix_bytes()
    a = gen.render_page(data)
    b = gen.render_page(data)
    assert a == b
    # A trailing whitespace/CRLF slip would break byte-identity downstream.
    assert "\r" not in a
    assert a.endswith("\n")


def test_no_wallclock_timestamp_in_output():
    page = gen.render_page(_matrix_bytes())
    # Historical/provenance dates that are pinned in code (DL-059 rename,
    # SP500 routing evidence ref) are allowed; a *fresh* generation date is not.
    # Assert the removed hand-maintained "Stand:" date line is gone.
    assert "**Stand:**" not in page
    # And no ISO datetime with a time-of-day component (wall clock) leaked in.
    assert not re.search(r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}", page)


def test_source_hash_matches_csv_bytes():
    data = _matrix_bytes()
    page = gen.render_page(data)
    digest = hashlib.sha256(data).hexdigest()
    assert f"sha256: {digest}" in page


def test_generated_marker_present():
    page = gen.render_page(_matrix_bytes())
    assert "GENERATED" in page
    assert gen.SCRIPT_REL in page


def test_qm_admin_heartbeat_refreshes_vault_page():
    source = HEARTBEAT.read_text(encoding="utf-8")
    assert "sync_symbol_list_page(out)" in source
    assert '"tools" / "vault" / "gen_symbol_list_page.py"' in source


def test_all_matrix_symbols_appear():
    data = _matrix_bytes()
    page = gen.render_page(data)
    rows = gen.parse_rows(data)
    assert rows, "matrix CSV parsed to zero rows"
    for row in rows:
        sym = row["symbol"].strip()
        assert sym in page, f"symbol missing from generated page: {sym}"
    # Count line must equal the number of matrix rows.
    assert f"## Aktive Symbole ({len(rows)})" in page


def test_sp500_present_when_in_matrix():
    # Regression: the hand-maintained page dropped SP500 for 3.5 months.
    data = _matrix_bytes()
    rows = gen.parse_rows(data)
    if any(r["symbol"].strip() == "SP500.DWX" for r in rows):
        assert "SP500.DWX" in gen.render_page(data)


def test_vault_page_matches_matrix():
    """Drift guard: committed vault page == page generated from committed CSV."""
    page_path = gen.VAULT_PAGE
    try:
        page_available = page_path.exists()
    except OSError as exc:
        pytest.skip(f"vault page unavailable: {page_path}: {exc}")
    if not page_available:
        pytest.skip(f"vault page not mounted: {page_path}")
    expected = gen.render_page(_matrix_bytes()).encode("utf-8")
    actual = page_path.read_bytes()
    assert actual == expected, (
        "Symbol List vault page is out of sync with the matrix CSV. "
        "Run: python tools/vault/gen_symbol_list_page.py --write"
    )
