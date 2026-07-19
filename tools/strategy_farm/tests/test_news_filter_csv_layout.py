from __future__ import annotations

from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
NEWS_FILTER = REPO / "framework" / "include" / "QM" / "QM_NewsFilter.mqh"


def test_news_csv_loader_maps_production_headers_instead_of_fixed_columns() -> None:
    source = NEWS_FILTER.read_text(encoding="utf-8")

    for header in ("DATETIME_UTC", "DATETIME", "CURRENCY", "IMPACT"):
        assert f'header == "{header}"' in source

    assert "fields[datetime_index]" in source
    assert "fields[currency_index]" in source
    assert "fields[impact_index]" in source
    assert "currency = fields[2]" not in source
    assert "impact = fields[3]" not in source


def test_secondary_layout_explicitly_prefers_utc_over_eet() -> None:
    source = NEWS_FILTER.read_text(encoding="utf-8")
    utc_branch = source.index('header == "DATETIME_UTC"')
    generic_branch = source.index('header == "DATETIME"')

    assert utc_branch < generic_branch
    assert "Always prefer UTC over local/EET" in source


def test_live_content_coverage_gap_is_warn_only() -> None:
    source = NEWS_FILTER.read_text(encoding="utf-8")

    warning = 'QM_LogEvent(QM_WARN, "NEWS_CALENDAR_COVERAGE_GAP"'
    assert warning in source
    assert 'QM_NewsLogSetupMissing("calendar_content_coverage_gap")' not in source
    assert source.index(warning) < source.index("g_qm_news_available = true;")
