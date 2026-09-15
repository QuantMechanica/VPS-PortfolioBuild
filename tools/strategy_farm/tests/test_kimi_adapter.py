"""Kimi adapter (kimi_adapter.py): argv construction, stream-json parsing, error
classification, single-flight lock, kill switch, timeout kill-tree, the critic
repo-mutation guard, the usage-ledger schema, and fake mode.

No live Kimi calls: fake mode + mocked _spawn_once / Popen only. The stream-json
fixtures are the REAL event samples captured by the probe battery (see
docs/ops/evidence/2026-09-15_kimi_integration/probe_battery/).
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import kimi_adapter as ka  # noqa: E402


# --- real stream-json samples from the probe battery -----------------------------

PROBE1_OK = (
    '{"role":"meta","type":"system.version","version":"0.43.1"}\n'
    '{"role":"assistant","content":"OK"}\n'
    '{"role":"meta","type":"session.resume_hint","session_id":"session_a7b69fac",'
    '"command":"kimi -r session_a7b69fac","content":"To resume this session: kimi -r session_a7b69fac"}\n'
)

PROBE2_TOOLS = (
    '{"role":"meta","type":"system.version","version":"0.43.1"}\n'
    '{"role":"assistant","tool_calls":[{"type":"function","id":"t1","function":{"name":"Read","arguments":"{}"}}]}\n'
    '{"role":"tool","tool_call_id":"t1","content":"1\\tThe secret code is BANANA42."}\n'
    '{"role":"assistant","tool_calls":[{"type":"function","id":"t2","function":{"name":"Write","arguments":"{}"}}]}\n'
    '{"role":"tool","tool_call_id":"t2","content":"Wrote 9 bytes to answer_probe2.txt"}\n'
    '{"role":"assistant","content":"BANANA42"}\n'
    '{"role":"meta","type":"session.resume_hint","session_id":"s","command":"c","content":"To resume this session: kimi -r s"}\n'
)


# --- config fixture --------------------------------------------------------------

@pytest.fixture()
def cfg(tmp_path: Path) -> dict:
    c = ka.load_config()
    # redirect every side-effecting path into tmp so tests never touch D:/QM or the repo.
    bin_path = tmp_path / "kimi.exe"
    bin_path.write_text("stub", encoding="utf-8")
    cred = tmp_path / "kimi-code.json"
    cred.write_text("{}", encoding="utf-8")
    c["bin"] = str(bin_path)
    c["credential_file"] = str(cred)
    c["ledger_path"] = str(tmp_path / "ledger.jsonl")
    c["repo_root"] = str(tmp_path / "repo")
    (tmp_path / "repo" / ".git").mkdir(parents=True)
    c["single_flight"] = {"lock_path": str(tmp_path / "kimi.lock"), "wait_s": 0, "stale_s": 7200}
    c["retry"] = {"max_retries": 2, "retry_statuses": ["timeout", "rate_limited"], "backoff_s": [0, 0]}
    c.setdefault("governor", {})
    c["governor"]["ledger_path"] = c["ledger_path"]
    c["governor"]["flag_path"] = str(tmp_path / "KIMI_LOW_QUOTA.flag")
    c["governor"]["state_path"] = str(tmp_path / "kimi_governor_state.json")
    c["governor"]["log_path"] = str(tmp_path / "kimi_governor.log")
    return c


def _fake_spawn(raw: str, *, rc: int = 0, stderr: str = "", timed_out: bool = False, latency: float = 0.1):
    """Return a _spawn_once replacement that writes the canned raw + stderr."""
    def _spawn(cmd, *, cwd, env, timeout_s, raw_path, log_path):
        Path(raw_path).write_text(raw, encoding="utf-8")
        Path(log_path).write_text(stderr, encoding="utf-8")
        return {"rc": (-9 if timed_out else rc), "timed_out": timed_out, "latency_s": latency,
                "raw": raw, "stderr": stderr}
    return _spawn


# --- stream-json parsing ---------------------------------------------------------

def test_parse_stream_json_takes_last_assistant_content() -> None:
    assert ka.parse_stream_json(PROBE1_OK) == "OK"
    # tool_calls-only assistant lines are ignored; the final content line wins.
    assert ka.parse_stream_json(PROBE2_TOOLS) == "BANANA42"


def test_parse_stream_json_ignores_meta_and_tool_and_garbage() -> None:
    noisy = "not json\n" + PROBE1_OK + "\n{broken\n"
    assert ka.parse_stream_json(noisy) == "OK"
    assert ka.parse_stream_json("") is None
    assert ka.parse_stream_json("no json at all\nstill none\n") is None


def test_extract_cli_version_from_meta_line() -> None:
    assert ka.extract_cli_version(PROBE1_OK) == "0.43.1"
    assert ka.extract_cli_version("no meta") is None


def test_strip_text_mode_removes_banner_bullets_resume() -> None:
    raw = ("kimi version 0.43.1\n"
           "\u2022 thinking about it\n"
           "The answer is 42.\n"
           "To resume this session: kimi -r abc\n")
    assert ka.strip_text_mode(raw) == "The answer is 42."


# --- error classification --------------------------------------------------------

def test_classify_error_table(cfg: dict) -> None:
    assert ka.classify_error(1, "error: No model configured. Run kimi and use /login", "", cfg) == "auth_expired"
    assert ka.classify_error(1, "HTTP 429 too many requests", "", cfg) == "rate_limited"
    assert ka.classify_error(1, "rate limit exceeded", "", cfg) == "rate_limited"
    assert ka.classify_error(1, "some other failure", "", cfg) == "error"


# --- argv construction per role --------------------------------------------------

def test_build_argv_creator_has_no_agent_file(cfg: dict, tmp_path: Path) -> None:
    out = tmp_path / "out"
    out.mkdir()
    cmd = ka.build_argv(cfg, bin_path=Path(cfg["bin"]), role="creator", model="kimi-code/kimi-for-coding",
                        pointer="POINTER", add_dirs=[tmp_path / "scratch"], out_dir=out)
    assert cmd[1] == "-p" and cmd[2] == "POINTER"
    assert "--output-format" in cmd and "stream-json" in cmd
    assert "-m" in cmd and "kimi-code/kimi-for-coding" in cmd
    assert "--agent-file" not in cmd
    assert "--auto" not in cmd and "--plan" not in cmd  # probe: both refuse to combine with -p
    assert cmd.count("--add-dir") == 2  # scratch + out_dir
    assert str(out) in cmd


def test_build_argv_critic_materializes_readonly_agent_file(cfg: dict, tmp_path: Path) -> None:
    out = tmp_path / "out"
    out.mkdir()
    cmd = ka.build_argv(cfg, bin_path=Path(cfg["bin"]), role="critic", model="kimi-code/k3-256k",
                        pointer="POINTER", add_dirs=[], out_dir=out)
    assert "--agent-file" in cmd
    agent_path = Path(cmd[cmd.index("--agent-file") + 1])
    assert agent_path.exists()
    body = agent_path.read_text(encoding="utf-8")
    assert "tools:" in body and "Read" in body and "Write" not in body  # allowlist excludes Write


def test_resolve_model_capability_then_role_then_default(cfg: dict) -> None:
    assert ka._resolve_model(cfg, "creator", "research_critic", None) == "kimi-code/k3-256k"
    assert ka._resolve_model(cfg, "critic", "unknown-cap", None) == "kimi-code/k3-256k"
    assert ka._resolve_model(cfg, "creator", "unknown-cap", None) == cfg["default_model"]
    assert ka._resolve_model(cfg, "creator", "research_critic", "override/x") == "override/x"


# --- pointer prompt path: prompt is a FILE, contents never in argv ---------------

def test_run_kimi_pointer_prompt_file_never_in_argv(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(ka, "_spawn_once", _fake_spawn(PROBE1_OK))
    monkeypatch.setattr(ka, "_repo_porcelain_hash", lambda root: "same")
    out = tmp_path / "out"
    secret_prompt = "SUPER-SECRET-PROMPT-BODY that must never appear in argv"
    res = ka.run_kimi(secret_prompt, role="research", capability="research", task_id="t1",
                      cwd=tmp_path, add_dirs=[], out_dir=out, config=cfg,
                      environ={})
    assert res["status"] == "ok" and res["text"] == "OK"
    # prompt written to a file; argv carries the pointer with the path, not the body
    prompt_file = out / "research_prompt.md"
    assert prompt_file.read_text(encoding="utf-8") == secret_prompt
    joined = " ".join(res["cmd"])
    assert secret_prompt not in joined
    assert str(prompt_file) in joined
    assert res["cli_version"] == "0.43.1"


# --- kill switch: never spawn ----------------------------------------------------

def test_kill_switch_returns_error_without_spawning(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    def _boom(*a, **k):
        raise AssertionError("must not spawn when QM_KIMI=0")
    monkeypatch.setattr(ka, "_spawn_once", _boom)
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={"QM_KIMI": "0"})
    assert res["status"] == "error" and res["error"] == "kill_switch"


# --- pre-flight: cli missing / credential missing (never retry) ------------------

def test_cli_missing_status(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    cfg["bin"] = str(tmp_path / "does_not_exist.exe")
    monkeypatch.setattr(ka, "_spawn_once", lambda *a, **k: (_ for _ in ()).throw(AssertionError("no spawn")))
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "cli_missing" and res["retries"] == 0


def test_auth_expired_when_credential_file_missing(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    cfg["credential_file"] = str(tmp_path / "gone.json")
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "auth_expired" and res["retries"] == 0
    assert "gone.json" in res["error"] and res["text"] == ""


# --- single-flight lock ----------------------------------------------------------

def test_single_flight_busy_returns_error(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    lock = Path(cfg["single_flight"]["lock_path"])
    lock.write_text(json.dumps({"pid": 1, "stamp": ka._utc_iso()}), encoding="utf-8")  # fresh, held
    monkeypatch.setattr(ka, "_spawn_once", lambda *a, **k: (_ for _ in ()).throw(AssertionError("no spawn")))
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "error" and res["error"] == "single_flight_busy"


def test_single_flight_steals_stale_lock(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    lock = Path(cfg["single_flight"]["lock_path"])
    import datetime as dt
    old = (ka._now() - dt.timedelta(hours=3)).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    lock.write_text(json.dumps({"pid": 999999, "stamp": old}), encoding="utf-8")
    monkeypatch.setattr(ka, "_spawn_once", _fake_spawn(PROBE1_OK))
    monkeypatch.setattr(ka, "_repo_porcelain_hash", lambda root: "x")
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "ok"


# --- timeout kill-tree (mock Popen) ---------------------------------------------

def test_spawn_once_timeout_kills_tree(tmp_path: Path, monkeypatch) -> None:
    killed = {"taskkill": False}

    class FakeProc:
        pid = 4242
        returncode = None

        def wait(self, timeout=None):
            raise subprocess.TimeoutExpired(cmd="kimi", timeout=timeout)

        def kill(self):
            pass

    def fake_popen(*a, **k):
        return FakeProc()

    def fake_run(cmd, *a, **k):
        if cmd[:1] == ["taskkill"]:
            killed["taskkill"] = True
        class R: returncode = 0
        return R()

    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    monkeypatch.setattr(subprocess, "run", fake_run)
    res = ka._spawn_once(["kimi"], cwd=tmp_path, env={}, timeout_s=1,
                         raw_path=tmp_path / "r.jsonl", log_path=tmp_path / "l.log")
    assert res["timed_out"] is True and res["rc"] == -9
    assert killed["taskkill"] is True


def test_run_kimi_timeout_retries_then_gives_up(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(ka, "_spawn_once", _fake_spawn("", timed_out=True))
    monkeypatch.setattr(ka, "_repo_porcelain_hash", lambda root: "x")
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "timeout" and res["retries"] == 2  # max_retries in cfg


def test_run_kimi_rate_limited_is_retried(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(ka, "_spawn_once", _fake_spawn("", rc=1, stderr="HTTP 429 too many requests"))
    monkeypatch.setattr(ka, "_repo_porcelain_hash", lambda root: "x")
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "rate_limited" and res["retries"] == 2


def test_run_kimi_auth_expired_is_not_retried(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(ka, "_spawn_once",
                        _fake_spawn("", rc=1, stderr="error: No model configured. use /login"))
    monkeypatch.setattr(ka, "_repo_porcelain_hash", lambda root: "x")
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "auth_expired" and res["retries"] == 0


def test_malformed_output_when_rc0_but_unparseable(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(ka, "_spawn_once", _fake_spawn("", rc=0))
    monkeypatch.setattr(ka, "_repo_porcelain_hash", lambda root: "x")
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "malformed_output"


# --- repo-mutation guard -> critic_wrote ----------------------------------------

def test_critic_repo_write_becomes_critic_wrote(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(ka, "_spawn_once", _fake_spawn(PROBE1_OK))
    hashes = iter(["before", "AFTER-CHANGED"])
    monkeypatch.setattr(ka, "_repo_porcelain_hash", lambda root: next(hashes))
    res = ka.run_kimi("x", role="critic", capability="research_critic", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert res["status"] == "critic_wrote"
    assert res["repo_write"] is True
    assert res["text"] == ""  # mutating critic's text is discarded


def test_creator_repo_write_flag_but_status_ok(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(ka, "_spawn_once", _fake_spawn(PROBE1_OK))
    hashes = iter(["before", "AFTER"])
    monkeypatch.setattr(ka, "_repo_porcelain_hash", lambda root: next(hashes))
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    # a creator may legitimately write; repo_write is recorded but status stays ok
    assert res["status"] == "ok" and res["repo_write"] is True and res["text"] == "OK"


# --- fake mode + ledger schema + no invented usage ------------------------------

def test_fake_mode_ok_and_ledger_schema(cfg: dict, tmp_path: Path) -> None:
    ledger = tmp_path / "fake_ledger.jsonl"
    res = ka.run_kimi("prompt", role="creator", capability="edge_discovery", task_id="task-9",
                      cwd=tmp_path, add_dirs=[], out_dir=tmp_path / "o", config=cfg,
                      environ={"QM_KIMI_FAKE": "1", "QM_KIMI_FAKE_LEDGER": str(ledger)})
    assert res["status"] == "ok" and res["cli_version"] == "fake"
    assert res["usage"] is None  # never invented
    lines = ledger.read_text(encoding="utf-8").strip().splitlines()
    assert len(lines) == 1
    row = json.loads(lines[0])
    for key in ("schema", "ts_utc", "task_id", "role", "capability", "model", "prompt_sha256",
                "output_sha256", "latency_s", "status", "retries", "cli_version", "usage",
                "subscription_period"):
        assert key in row, f"ledger missing {key}"
    assert row["schema"] == "qm.kimi-usage/v1"
    assert row["task_id"] == "task-9" and row["capability"] == "edge_discovery"
    assert row["usage"] is None
    assert row["subscription_period"]["start"] == "2026-09-15"
    assert row["prompt_sha256"] == ka._sha256_text("prompt")


def test_fake_mode_forced_status(cfg: dict, tmp_path: Path) -> None:
    ledger = tmp_path / "fake_ledger.jsonl"
    res = ka.run_kimi("p", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg,
                      environ={"QM_KIMI_FAKE": "1", "QM_KIMI_FAKE_LEDGER": str(ledger),
                               "QM_KIMI_FAKE_STATUS": "rate_limited"})
    assert res["status"] == "rate_limited" and res["text"] == ""


def test_no_secret_fields_logged(cfg: dict, tmp_path: Path, monkeypatch) -> None:
    # a missing credential must report the PATH only, never any token contents.
    cfg["credential_file"] = str(tmp_path / "absent-cred.json")
    res = ka.run_kimi("x", role="creator", capability="research", task_id="t", cwd=tmp_path,
                      add_dirs=[], out_dir=tmp_path / "o", config=cfg, environ={})
    assert "absent-cred.json" in res["error"]
    assert "access_token" not in res["error"] and "refresh_token" not in res["error"]
