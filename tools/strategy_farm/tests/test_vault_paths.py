from __future__ import annotations

from pathlib import Path

from tools.strategy_farm import vault_paths


def test_default_vault_root_has_company_reference_segment():
    root = vault_paths.vault_root()
    assert "QuantMechanica - Company Reference" in str(root)
    assert vault_paths.strategy_wiki_root().name == "09 Strategy Wiki"


def test_env_override(monkeypatch, tmp_path):
    monkeypatch.setenv(vault_paths.ENV_VAULT_ROOT, str(tmp_path))
    assert vault_paths.vault_root() == tmp_path
    assert vault_paths.strategy_wiki_strategies_dir() == tmp_path / "09 Strategy Wiki" / "strategies"
    assert vault_paths.strategy_wiki_generated_dir() == tmp_path / "09 Strategy Wiki" / "generated"


def test_explicit_override_wins_over_env(monkeypatch, tmp_path):
    monkeypatch.setenv(vault_paths.ENV_VAULT_ROOT, str(tmp_path / "env"))
    explicit = tmp_path / "explicit"
    assert vault_paths.vault_root(explicit) == explicit


def test_card_content_hash_is_line_ending_and_self_hash_stable():
    body = "---\nea_id: QM5_1\nslug: foo\n---\n\n# Foo\ntext\n"
    crlf = body.replace("\n", "\r\n")
    assert vault_paths.card_content_sha256(body) == vault_paths.card_content_sha256(crlf)

    # Persisting a card_sha256/card_hash line must not change the hash.
    with_hash = body.replace(
        "slug: foo\n", "slug: foo\ncard_sha256: deadbeef\n"
    )
    assert vault_paths.card_content_sha256(with_hash) == vault_paths.card_content_sha256(body)


def test_card_file_hash_roundtrip(tmp_path):
    p = tmp_path / "c.md"
    p.write_text("---\nea_id: QM5_9\n---\n# X\n", encoding="utf-8")
    assert vault_paths.card_file_content_sha256(p) == vault_paths.card_content_sha256(
        p.read_text(encoding="utf-8")
    )
