from pathlib import Path


ROOT = Path("C:/QM/repo")
RESOLVER = ROOT / "framework/include/QM/QM_MagicResolver.mqh"
GENERATOR = ROOT / "framework/scripts/update_magic_resolver.py"


def canonical(symbol: str) -> str:
    base = symbol.split(".", 1)[0]
    return "XTIUSD" if base == "USOIL" else base


def test_required_ftmo_and_dxz_alias_pairs() -> None:
    assert canonical("EURUSD.DWX") == canonical("EURUSD")
    assert canonical("XAGUSD.DWX") == canonical("XAGUSD")
    assert canonical("XAUUSD.DWX") == canonical("XAUUSD.cash")
    assert canonical("XTIUSD.DWX") == canonical("USOIL.cash")
    assert canonical("GBPUSD.DWX") != canonical("EURUSD")


def test_generated_resolver_and_generator_share_canonical_contract() -> None:
    resolver = RESOLVER.read_text(encoding="utf-8-sig")
    generator = GENERATOR.read_text(encoding="utf-8-sig")
    for source in (resolver, generator):
        assert "QM_MagicSymbolCanonical" in source
        assert 'base == "USOIL"' in source
        assert 'return "XTIUSD"' in source
        assert "QM_MagicSymbolCanonical(position_symbol)" in source
        assert "QM_MagicSymbolCanonical(registered_symbol)" in source
