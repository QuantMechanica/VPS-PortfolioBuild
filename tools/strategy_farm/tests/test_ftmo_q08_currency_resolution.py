from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
COMMON_INCLUDE = REPO_ROOT / "framework" / "include" / "QM" / "QM_Common.mqh"


def test_dwx_currency_conversion_prefers_custom_pairs() -> None:
    source = COMMON_INCLUDE.read_text(encoding="utf-8")

    assert 'const bool prefer_dwx = (StringFind(_Symbol, ".DWX") >= 0);' in source
    assert (
        'found = QM_FrameworkSymbolPrice(direct + ".DWX", px) '
        '|| QM_FrameworkSymbolPrice(direct, px);'
    ) in source
    assert (
        'found = QM_FrameworkSymbolPrice(inverse + ".DWX", px) '
        '|| QM_FrameworkSymbolPrice(inverse, px);'
    ) in source
