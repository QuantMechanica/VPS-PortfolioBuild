from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "update_magic_resolver.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("update_magic_resolver_under_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_registry_identity_is_invariant_across_lf_and_crlf(tmp_path: Path) -> None:
    module = _load_module()
    registry = tmp_path / "magic_numbers.csv"
    lf = b"ea_id,symbol_slot\n13301,0\n"
    registry.write_bytes(lf)
    module.REGISTRY_CSV = registry
    expected = hashlib.sha256(lf).hexdigest().upper()

    assert module.csv_sha256_upper() == expected

    registry.write_bytes(lf.replace(b"\n", b"\r\n"))
    assert module.csv_sha256_upper() == expected
