from __future__ import annotations

from pathlib import Path

from validate_symbol_scope import audit_ea, find_violations


def _write_ea(tmp_path: Path, label: str, source: str) -> Path:
    ea_dir = tmp_path / label
    ea_dir.mkdir()
    (ea_dir / f"{label}.mq5").write_text(source, encoding="utf-8")
    return ea_dir


def test_dynamic_symbol_array_is_resolved_and_rejected_without_manifest(
    tmp_path: Path,
) -> None:
    label = "QM5_99991_dynamic-basket"
    ea_dir = _write_ea(
        tmp_path,
        label,
        '''
string g_pairs[3] = {"EURUSD.DWX", "GBPJPY.DWX", "XAUUSD.DWX"};
void ReadBasket()
  {
   double closes[];
   for(int i = 0; i < 3; ++i)
      CopyClose(g_pairs[i], PERIOD_M15, 1, 97, closes);
  }
''',
    )

    result = audit_ea(label, ea_dir)

    assert result.verdict == "MULTI_SYMBOL_LEAK_NOT_DECLARED"
    assert result.n_violations == 3
    assert result.referenced_foreign_symbols == [
        "EURUSD.DWX",
        "GBPJPY.DWX",
        "XAUUSD.DWX",
    ]
    assert {item.resolved_symbol for item in result.violations} == set(
        result.referenced_foreign_symbols
    )


def test_dynamic_symbol_array_is_checked_against_manifest(tmp_path: Path) -> None:
    label = "QM5_99992_manifest-gap"
    ea_dir = _write_ea(
        tmp_path,
        label,
        '''
const string pairs[] = {"EURUSD.DWX", "USDJPY.DWX"};
void ReadBasket()
  {
   MqlRates rates[];
   CopyRates(pairs[0], PERIOD_H1, 0, 2, rates);
  }
''',
    )
    (ea_dir / "basket_manifest.json").write_text(
        '{"basket_symbols": ["EURUSD.DWX"]}', encoding="utf-8"
    )

    result = audit_ea(label, ea_dir)

    assert result.verdict == "MULTI_SYMBOL_LEAK_NOT_IN_MANIFEST"
    assert result.referenced_foreign_symbols == ["EURUSD.DWX", "USDJPY.DWX"]
    assert [item.resolved_symbol for item in result.violations] == ["USDJPY.DWX"]


def test_unresolved_computed_symbol_remains_visible_without_false_rejection(
    tmp_path: Path,
) -> None:
    label = "QM5_99993_computed-symbol"
    ea_dir = _write_ea(
        tmp_path,
        label,
        '''
void ReadOne(string prefix)
  {
   double closes[];
   CopyClose(prefix + ".DWX", PERIOD_M15, 1, 2, closes);
  }
''',
    )

    violations, symbols, unresolved = find_violations(
        label, ea_dir / f"{label}.mq5"
    )

    assert violations == []
    assert symbols == set()
    assert unresolved == {'prefix + ".DWX"'}
