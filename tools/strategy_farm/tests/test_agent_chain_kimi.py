"""Kimi vendor in the Creator -> Critic -> Formatter chain (slice C3).

Covers: vendor normalization/aliases; the config invariants (kimi is never its own
creator's critic, never a formatter); vendor_gate('kimi') fail-closed behaviour
(EXHAUSTED flag, CONSERVE narrowed to a critic-for-non-kimi-creator, missing CLI,
missing credential); run_seat's kimi branch mapping kimi_adapter.run_kimi to the stage
contract; and the chain treating a kimi ``critic_wrote`` exactly like an unparsed critic
(fallback, then no formatter when nothing parses).

No live Kimi calls: the chain runs in fake mode (_fake_adapter) and the run_seat mapping
test monkeypatches ``kimi_adapter.run_kimi``.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import agent_chain as ac  # noqa: E402
import kimi_adapter as ka  # noqa: E402


@pytest.fixture()
def cfg(tmp_path: Path) -> dict:
    cfg = ac.load_config()
    cfg["paths"] = {
        "artifact_root": str(tmp_path / "art"),
        "receipt_root": str(tmp_path / "rcpt"),
        "lane_log_dir": str(tmp_path / "logs"),
        "farm_db": str(tmp_path / "farm.sqlite"),
    }
    # Kimi CLI + credential resolve to existing temp files by default; individual gate
    # tests override them to absent paths.
    kimi_bin = tmp_path / "kimi.exe"
    kimi_bin.write_text("stub", encoding="utf-8")
    kimi_cred = tmp_path / "kimi-code.json"
    kimi_cred.write_text("{}", encoding="utf-8")
    cfg["vendors"]["kimi"]["bin"] = str(kimi_bin)
    cfg["vendors"]["kimi"]["credential_file"] = str(kimi_cred)
    cfg["gates"] = {
        "codex_budget_line": False,
        "claude_disabled_flag": str(tmp_path / "CLAUDE_DISABLED.flag"),
        "codex_low_tokens_flag": str(tmp_path / "CODEX_LOW_TOKENS.flag"),
        "agy_low_quota_flag": str(tmp_path / "AGY_LOW_QUOTA.flag"),
        "kimi_low_quota_flag": str(tmp_path / "KIMI_LOW_QUOTA.flag"),
    }
    return cfg


@pytest.fixture()
def fake_env() -> dict[str, str]:
    return {"QM_AGENT_CHAIN_FAKE": "1", "QM_AGENT_CHAIN": "1"}


# --------------------------------------------------------------------------- normalization

def test_normalize_vendor_accepts_kimi_and_aliases() -> None:
    assert ac.normalize_vendor("kimi") == "kimi"
    assert ac.normalize_vendor("Kimi") == "kimi"
    assert ac.normalize_vendor("moonshot") == "kimi"
    assert ac.normalize_vendor("k2") == "kimi"
    assert ac.normalize_vendor("nope") == "unknown"
    assert ac.VENDOR_ALIASES["moonshot"] == "kimi"


# --------------------------------------------------------------------------- config invariants

def test_config_kimi_tables_are_cross_vendor_and_never_formatter() -> None:
    cfg = ac.load_config()
    table = cfg["roles"]["critic"]["by_creator_vendor"]
    assert "kimi" in table
    # by_creator_vendor.kimi lists ONLY non-kimi seats.
    assert all(ac.normalize_vendor(e["vendor"]) != "kimi" for e in table["kimi"])
    # kimi is inserted into the other creator tables so it can critique others.
    assert any(ac.normalize_vendor(e["vendor"]) == "kimi" for e in table["claude"])
    assert any(ac.normalize_vendor(e["vendor"]) == "kimi" for e in table["codex"])
    # formatter is never kimi.
    fmt = cfg["roles"]["formatter"]
    seats = [fmt.get("default") or {}, *(fmt.get("fallback") or [])]
    assert all(ac.normalize_vendor(s.get("vendor")) != "kimi" for s in seats)


# --------------------------------------------------------------------------- kimi as critic

def test_kimi_selected_as_critic_for_claude_creator_when_codex_gated(cfg: dict, fake_env: dict) -> None:
    Path(cfg["gates"]["codex_low_tokens_flag"]).write_text("x", encoding="utf-8")  # gate codex
    spec = {"kind": "run", "task": "t", "input_texts": {"a": "b"}}
    receipt = ac.run_chain(spec, apply=True, cfg=cfg, environ=fake_env)
    critic = receipt["stages"][1]
    assert critic["role"] == "critic"
    assert critic["seat"]["vendor"] == "kimi" and critic["cross_vendor"] is True
    assert receipt["status"] == "ok" and receipt["critic_verdict"] == "GAPS"
    # the critic trace carries a routing_reason explaining the pick and the codex skip.
    trace = receipt["seat_trace"]["critic"]
    assert any(t.get("skipped") == "codex_low_tokens_flag" and t.get("routing_reason") for t in trace)
    assert any(t.get("selected") and t["seat"].startswith("kimi") and t.get("routing_reason") for t in trace)


# --------------------------------------------------------------------------- kimi creator never gets a kimi critic

def test_kimi_creator_never_gets_kimi_critic_even_if_config_tampered(cfg: dict) -> None:
    # Tamper the table so the kimi creator's FIRST critic candidate is kimi itself.
    cfg["roles"]["critic"]["by_creator_vendor"]["kimi"] = [
        {"vendor": "kimi", "model": "k3"},
        {"vendor": "claude", "model": "sonnet"},
    ]
    open_seats, trace = ac.open_critic_seats("kimi", cfg, lambda v: None)
    assert open_seats and open_seats[0][0].vendor == "claude"  # kimi skipped, claude selected
    assert all(seat.vendor != "kimi" for seat, _ in open_seats)
    assert any(t.get("skipped") == "kimi_creator_never_kimi_critic"
               and t.get("routing_reason") == "kimi_creator_never_kimi_critic" for t in trace)
    # resolve_critic delegates to open_critic_seats and honours the invariant.
    seat, cross, _ = ac.resolve_critic("kimi", cfg, lambda v: None)
    assert seat.vendor == "claude" and cross is True


# --------------------------------------------------------------------------- kimi never a formatter

def test_kimi_never_formatter_even_if_config_tampered(cfg: dict) -> None:
    cfg["roles"]["formatter"] = {"default": {"vendor": "kimi", "model": "default"},
                                 "fallback": [{"vendor": "claude", "model": "haiku"}]}
    seat, trace = ac.resolve_formatter(cfg, lambda v: None)
    assert seat.vendor == "claude" and seat.model == "haiku"
    assert any(t.get("skipped") == "formatter_never_kimi" for t in trace)
    # a formatter table with ONLY kimi leaves no seat -> gated.
    cfg["roles"]["formatter"] = {"default": {"vendor": "kimi", "model": "default"}, "fallback": []}
    with pytest.raises(ac.ChainGated):
        ac.resolve_formatter(cfg, lambda v: None)


# --------------------------------------------------------------------------- vendor_gate('kimi')

def test_vendor_gate_kimi_exhausted_flag_gates(cfg: dict) -> None:
    flag = Path(cfg["gates"]["kimi_low_quota_flag"])
    flag.write_text(json.dumps({"state": "EXHAUSTED"}), encoding="utf-8")
    assert ac.vendor_gate("kimi", cfg, {"QM_AGENT_CHAIN": "1"}) == "kimi_low_quota_flag:EXHAUSTED"
    # the governor's MANAGED_BY-only body (no explicit state) is read as EXHAUSTED too.
    flag.write_text("MANAGED_BY=kimi_governor\nreason=daily cap hit (40/40)\n", encoding="utf-8")
    assert ac.vendor_gate("kimi", cfg, {"QM_AGENT_CHAIN": "1"},
                          role="critic", creator_vendor="claude") == "kimi_low_quota_flag:EXHAUSTED"


def test_vendor_gate_kimi_conserve_allows_critic_only(cfg: dict) -> None:
    Path(cfg["gates"]["kimi_low_quota_flag"]).write_text(json.dumps({"state": "CONSERVE"}), encoding="utf-8")
    env = {"QM_AGENT_CHAIN": "1"}
    # critic for a non-kimi creator survives CONSERVE...
    assert ac.vendor_gate("kimi", cfg, env, role="critic", creator_vendor="claude") is None
    # ...but creator/formatter roles do not.
    assert ac.vendor_gate("kimi", cfg, env, role="creator").startswith("kimi_conserve:")
    assert ac.vendor_gate("kimi", cfg, env, role="formatter").startswith("kimi_conserve:")
    # a kimi creator is never a kimi-critiqued deliverable, even in CONSERVE.
    assert ac.vendor_gate("kimi", cfg, env, role="critic", creator_vendor="kimi").startswith("kimi_conserve:")


def test_vendor_gate_kimi_cli_missing_gates(cfg: dict, tmp_path: Path) -> None:
    cfg["vendors"]["kimi"]["bin"] = str(tmp_path / "does_not_exist.exe")
    assert ac.vendor_gate("kimi", cfg, {"QM_AGENT_CHAIN": "1"}) == "kimi_cli_missing"


def test_vendor_gate_kimi_credential_missing_gates(cfg: dict, tmp_path: Path) -> None:
    cfg["vendors"]["kimi"]["credential_file"] = str(tmp_path / "gone.json")
    reason = ac.vendor_gate("kimi", cfg, {"QM_AGENT_CHAIN": "1"})
    assert reason == "kimi_credential_missing"
    # the reason is the class only - never the (missing) credential contents / path leakage of a token.
    assert "token" not in reason


def test_vendor_gate_kimi_kill_switch_first(cfg: dict) -> None:
    assert ac.vendor_gate("kimi", cfg, {"QM_AGENT_CHAIN": "0"}) == "kill_switch_QM_AGENT_CHAIN=0"


def test_vendor_gate_kimi_normal_open(cfg: dict) -> None:
    # no flag + CLI + credential present -> open.
    assert ac.vendor_gate("kimi", cfg, {"QM_AGENT_CHAIN": "1"}) is None


# --------------------------------------------------------------------------- run_seat kimi branch mapping

def _patch_run_kimi(monkeypatch, *, status: str, captured: dict) -> None:
    def fake_run_kimi(prompt, **kw):  # noqa: ANN001, ANN003
        captured.clear()
        captured.update(kw)
        captured["prompt"] = prompt
        return {
            "status": status, "text": ("answer" if status == "ok" else ""),
            "rc": 0 if status == "ok" else 1, "latency_s": 1.5, "cli_version": "0.43.1",
            "usage": {"output_tokens": 7}, "error": ("" if status == "ok" else f"forced:{status}"),
            "cmd": ["kimi", "-p", "POINTER"], "log_path": "LOG", "raw_path": "RAW",
        }
    monkeypatch.setattr(ka, "run_kimi", fake_run_kimi)


def test_run_seat_kimi_maps_adapter_result_and_passes_contract(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    captured: dict = {}
    _patch_run_kimi(monkeypatch, status="ok", captured=captured)
    out_dir = tmp_path / "chain"
    out_dir.mkdir()
    seat = ac.Seat(vendor="kimi", model="k3")
    result = ac.run_seat(seat, "critic", "PROMPT-BODY", cfg=cfg, out_dir=out_dir,
                         stage_name="stage2_critic", cwd=tmp_path, add_dirs=[], timeout=123,
                         environ={}, chain_id="CHAIN-1")
    # contract passed to the adapter:
    assert captured["capability"] == "research_critic"   # critic -> research_critic
    assert captured["task_id"] == "CHAIN-1"               # task_id = chain_id
    assert captured["model"] == "kimi-code/k3"            # from config vendors.kimi.models
    assert captured["timeout_s"] == 123
    assert ac.REPO_ROOT in captured["add_dirs"] and out_dir in captured["add_dirs"]
    assert captured["out_dir"] == out_dir
    # result mapping:
    assert result["status"] == "ok" and result["text"] == "answer"
    assert result["cost_usd"] is None                    # never invented
    assert result["usage"] == {"output_tokens": 7}       # passthrough
    assert result["cli_version"] == "0.43.1"             # into the stage record


def test_run_seat_kimi_capability_per_role(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    out_dir = tmp_path / "c"
    out_dir.mkdir()
    for role, want_cap in (("creator", "hypothesis_authoring"), ("formatter", "summary"),
                           ("critic", "research_critic")):
        captured: dict = {}
        _patch_run_kimi(monkeypatch, status="ok", captured=captured)
        ac.run_seat(ac.Seat(vendor="kimi", model="default"), role, "P", cfg=cfg, out_dir=out_dir,
                    stage_name=f"s_{role}", cwd=tmp_path, add_dirs=[], timeout=60, environ={},
                    chain_id="X")
        assert captured["capability"] == want_cap


@pytest.mark.parametrize("adapter_status,stage_status", [
    ("ok", "ok"),
    ("timeout", "timeout"),
    ("critic_wrote", "critic_wrote"),
    ("auth_expired", "error"),
    ("rate_limited", "error"),
    ("malformed_output", "error"),
    ("cli_missing", "error"),
])
def test_run_seat_kimi_status_mapping(cfg: dict, tmp_path: Path, monkeypatch,
                                      adapter_status: str, stage_status: str) -> None:
    captured: dict = {}
    _patch_run_kimi(monkeypatch, status=adapter_status, captured=captured)
    out_dir = tmp_path / "c"
    out_dir.mkdir()
    result = ac.run_seat(ac.Seat(vendor="kimi", model="k3"), "critic", "P", cfg=cfg, out_dir=out_dir,
                         stage_name="s2", cwd=tmp_path, add_dirs=[], timeout=60, environ={}, chain_id="X")
    assert result["status"] == stage_status
    assert result["cost_usd"] is None


# --------------------------------------------------------------------------- chain: kimi critic_wrote handled like unparsed

def test_kimi_critic_wrote_falls_back_to_next_seat(cfg: dict, fake_env: dict) -> None:
    # creator claude -> [codex, kimi, opus, agy]; codex (primary) returns critic_wrote, the one-shot
    # fallback kimi returns ok. critic_wrote is treated like an unparsed critic (superseded -> ok).
    env = {**fake_env, "QM_AGENT_CHAIN_FAKE_CRITIC_WROTE_VENDORS": "codex"}
    spec = {"kind": "critique", "task": "t",
            "existing_artifact": {"vendor": "claude", "model": "sonnet", "text": "delivered"}}
    receipt = ac.run_chain(spec, apply=True, cfg=cfg, environ=env)
    roles = [(s["role"], s["status"], (s.get("seat") or {}).get("vendor")) for s in receipt["stages"]]
    assert roles == [("creator", "reused", "claude"), ("critic", "critic_wrote", "codex"),
                     ("critic", "ok", "kimi"), ("formatter", "ok", "claude")]
    assert receipt["critic_fallback_used"] is True and receipt["status"] == "ok"


def test_kimi_critic_wrote_without_fallback_skips_formatter(cfg: dict, fake_env: dict) -> None:
    # creator codex -> [claude sonnet, kimi, claude opus]; primary claude unparsed, one-shot fallback
    # kimi returns critic_wrote -> nothing parses -> formatter NOT run, chain status error.
    env = {**fake_env, "QM_AGENT_CHAIN_FAKE_UNPARSED_VENDORS": "claude",
           "QM_AGENT_CHAIN_FAKE_CRITIC_WROTE_VENDORS": "kimi"}
    spec = {"kind": "critique", "task": "t",
            "existing_artifact": {"vendor": "codex", "model": "terra", "text": "delivered"}}
    receipt = ac.run_chain(spec, apply=True, cfg=cfg, environ=env)
    statuses = [(s["role"], s["status"]) for s in receipt["stages"]]
    assert statuses == [("creator", "reused"), ("critic", "unparsed"),
                        ("critic", "critic_wrote"), ("formatter", "skipped")]
    assert receipt["status"] == "error" and receipt["critic_verdict"] == "UNPARSED"
