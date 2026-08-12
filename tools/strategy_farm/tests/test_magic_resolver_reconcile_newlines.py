from __future__ import annotations

import hashlib
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import farmctl  # noqa: E402


def test_reconcile_does_not_regenerate_for_crlf_only_drift(
    tmp_path: Path, monkeypatch
) -> None:
    lf = b"ea_id,symbol_slot\n13301,0\n"
    expected = hashlib.sha256(lf).hexdigest().upper()
    registry = tmp_path / "magic_numbers.csv"
    registry.write_bytes(lf.replace(b"\n", b"\r\n"))
    resolver = tmp_path / "QM_MagicResolver.mqh"
    resolver.write_text(
        f'#define QM_MAGIC_REGISTRY_SHA256 "{expected}"\n', encoding="utf-8"
    )
    regen = tmp_path / "update_magic_resolver.py"
    regen.write_text("raise SystemExit(99)\n", encoding="utf-8")
    monkeypatch.setattr(farmctl, "MAGIC_CSV_PATH", registry)
    monkeypatch.setattr(farmctl, "MAGIC_RESOLVER_PATH", resolver)
    monkeypatch.setattr(farmctl, "MAGIC_REGEN_SCRIPT", regen)

    result = farmctl._reconcile_magic_resolver(tmp_path)

    assert result["regenerated"] is False
    assert result["reason"] == "in_sync"
