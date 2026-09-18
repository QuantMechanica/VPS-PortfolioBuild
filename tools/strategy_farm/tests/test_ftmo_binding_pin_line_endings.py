"""The M13 demo binding's sha256 pins must identify content, not a checkout.

Router ticket a5cf99d0 (2026-09-18): load_binding() refused in every checkout at
once because the pins were raw-byte digests of files whose line endings flip with
core.autocrlf. The terms evidence was pinned over LF and smudged to CRLF in every
worktree (account_terms_evidence_hash_drift); the Standard rulepack was pinned
over LF and is CRLF in checkouts predating its `text eol=lf` attribute
(rulepack_file_hash_drift); the two QM5_13206 governor presets were pinned over
the CRLF smudge and could therefore never verify on an LF checkout.

The pins are now computed over LF-normalized bytes, so the digest is a property
of the rule content. These tests hold that line: same content in either EOL
convention -> same pin, and any byte of rule content -> different pin.
"""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

import pytest

from tools.strategy_farm.ftmo import binding_hash, trial_setpath as s


def _crlf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")


# --- the hasher itself -----------------------------------------------------

def test_crlf_lf_and_cr_variants_of_one_content_share_a_pin():
    lf = b"rule_id=ftmo_2s_max_daily_loss\npercent=5\n"
    crlf = _crlf(lf)
    cr = lf.replace(b"\n", b"\r")
    assert hashlib.sha256(lf).hexdigest() != hashlib.sha256(crlf).hexdigest()
    pins = {binding_hash.content_sha256(v) for v in (lf, crlf, cr)}
    assert len(pins) == 1


def test_a_changed_byte_of_rule_content_still_changes_the_pin():
    base = b"rule_id=ftmo_2s_max_daily_loss\npercent=5\n"
    for mutated in (
        base.replace(b"percent=5", b"percent=6"),          # a threshold digit
        base.replace(b"max_daily_loss", b"max_dayly_loss"),  # a rule id
        base + b"percent_extra=1\n",                       # an inserted line
        base.replace(b"percent=5\n", b""),                 # a removed line
        base.replace(b"percent=5", b"percent=5 "),         # trailing whitespace
    ):
        assert binding_hash.content_sha256(mutated) != binding_hash.content_sha256(base)


def test_utf16_set_bytes_are_hashed_verbatim():
    """CR NUL LF NUL must not be byte-rewritten; MT5 writes UTF-16 set files."""
    utf16 = "RISK_FIXED=1000\r\n".encode("utf-16")
    assert binding_hash.normalize_line_endings(utf16) == utf16
    assert binding_hash.content_sha256(utf16) == hashlib.sha256(utf16).hexdigest()


def test_trial_setpath_and_the_evaluator_agree_on_the_hasher():
    from tools.strategy_farm.portfolio import ftmo_book3_standalone_evaluator as ev
    from tools.strategy_farm.ftmo import governor_rebind

    payload = b"a\r\nb\r\n"
    digest = binding_hash.content_sha256(payload)
    assert s.pin(payload) == digest
    assert governor_rebind.pin(payload) == digest
    assert ev._binding_pin(payload) == digest


# --- the committed binding -------------------------------------------------

PINNED = (
    ("account", "terms_evidence_path", "terms_evidence_sha256"),
    ("rulepack", "path", "file_sha256"),
    ("evaluator", "rulepack_path", "rulepack_file_sha256"),
    ("governor", "bootstrap_preset_path", "bootstrap_preset_sha256"),
    ("governor", "active_preset_path", "active_preset_sha256"),
)


def _binding() -> dict:
    return json.loads(s.BINDING.read_text(encoding="utf-8"))


def test_every_pinned_file_verifies_in_this_checkout():
    binding = _binding()
    for section, path_key, sha_key in PINNED:
        block = binding[section]
        raw = (s.REPO_ROOT / block[path_key]).read_bytes()
        assert s.pin(raw) == block[sha_key], f"{section}.{sha_key} drifted"


def test_every_pinned_file_would_verify_under_the_opposite_eol_convention():
    """The decisive property: neither autocrlf nor an LF checkout can refuse."""
    binding = _binding()
    for section, path_key, sha_key in PINNED:
        block = binding[section]
        raw = (s.REPO_ROOT / block[path_key]).read_bytes()
        lf = raw.replace(b"\r\n", b"\n")
        assert s.pin(lf) == block[sha_key]
        assert s.pin(_crlf(lf)) == block[sha_key]


def _sync_as_of(binding: dict) -> dict:
    """Neutralize an unrelated pre-existing defect so these tests isolate EOL.

    Reported with ticket a5cf99d0 and deliberately NOT fixed in the committed
    binding: commit 992c59d1af bumped the rulepack's own ``as_of`` to 2026-09-15
    while the binding label still reads 2026-09-04, and
    ftmo_book3_standalone_evaluator hard-codes ``"2026-09-04"``. load_binding
    requires binding.as_of == rulepack.as_of, so the two modules are currently
    unsatisfiable together, and picking the winning date is a gate-criterion
    (ROT) call for the OWNER, not a line-ending repair. The label is therefore
    synced inside the fixture only.
    """
    rulepack = json.loads(
        (s.REPO_ROOT / binding["rulepack"]["path"]).read_text(encoding="utf-8")
    )
    binding["rulepack"]["as_of"] = rulepack["as_of"]
    return binding


def _mirror(root: Path, binding: dict, *, smudge) -> Path:
    """Copy every bound file into `root`, rewriting its line endings."""
    for section, path_key, _sha_key in PINNED:
        rel = binding[section][path_key]
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(smudge((s.REPO_ROOT / rel).read_bytes()))
    path = root / "binding.json"
    path.write_text(json.dumps(binding, indent=2), encoding="utf-8")
    return path


@pytest.mark.parametrize("smudge", [lambda d: d.replace(b"\r\n", b"\n"), _crlf],
                         ids=["lf_checkout", "autocrlf_checkout"])
def test_load_binding_succeeds_in_either_checkout(tmp_path, monkeypatch, smudge):
    binding = _sync_as_of(_binding())
    path = _mirror(tmp_path, binding, smudge=smudge)
    monkeypatch.setattr(s, "REPO_ROOT", tmp_path)
    loaded, rule, _rulepack_path, _raw = s.load_binding(path)
    assert loaded["binding_id"] == "FTMO_M13_STANDARD_DEMO_V1"
    assert rule["rulepack_id"] == "FTMO_2S_100K_STANDARD_V2"


@pytest.mark.parametrize(
    "section,path_key,mutate,refusal",
    [
        ("rulepack", "path",
         lambda d: d.replace(b'"percent_of_initial_simulated_capital": "5"',
                             b'"percent_of_initial_simulated_capital": "6"'),
         "rulepack_file_hash_drift"),
        ("account", "terms_evidence_path", lambda d: d + b"tampered\n",
         "account_terms_evidence_hash_drift"),
        ("governor", "bootstrap_preset_path",
         lambda d: d.replace(b"qm_news_temporal=3", b"qm_news_temporal=1"),
         "bootstrap_preset_hash_drift"),
    ],
)
def test_real_content_drift_is_still_refused(tmp_path, monkeypatch, section, path_key,
                                             mutate, refusal):
    binding = _sync_as_of(_binding())
    path = _mirror(tmp_path, binding, smudge=lambda d: d)

    target = tmp_path / binding[section][path_key]
    original = target.read_bytes()
    mutated = mutate(original)
    assert mutated != original, "fixture must actually change rule content"
    target.write_bytes(mutated)

    monkeypatch.setattr(s, "REPO_ROOT", tmp_path)
    with pytest.raises(s.Refusal, match=refusal):
        s.load_binding(path)
