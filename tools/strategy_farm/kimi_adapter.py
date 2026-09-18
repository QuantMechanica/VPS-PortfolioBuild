#!/usr/bin/env python3
"""QuantMechanica - Kimi Code CLI adapter (the single choke point for every Kimi call).

Every Kimi invocation - orchestration lane, Creator/Critic/Formatter chain, ad-hoc
research - goes through ``run_kimi``. It pins the executable, serializes calls with a
machine-wide single-flight lock (the OAuth 15-min rolling token is a shared-file
refresh race), delivers the prompt by a short argv pointer to a prompt file, parses
Kimi's ``stream-json`` to the final assistant text, classifies errors, enforces a
read-only posture for critics, appends a usage-ledger line, and lets the governor set
the low-quota flag.

Probe-battery findings that shape this module (evidence:
docs/ops/evidence/2026-09-15_kimi_integration/probe_battery/):
  * ``-p`` (prompt) mode is already non-interactive AND auto-runs tools (Read/Write ran
    with no approval, no hang). ``--auto`` and ``--plan`` BOTH refuse to combine with
    ``-p`` ("Cannot combine --prompt with --auto/--plan"). So creators/research use plain
    ``-p``; the adapter never passes ``--auto``.
  * stream-json is JSONL: ``{"role":"meta",...}`` (version banner / resume hint),
    ``{"role":"assistant","content":"..."}`` (assistant text - the last one is the answer),
    ``{"role":"assistant","tool_calls":[...]}`` (a tool call, no content), and
    ``{"role":"tool",...}`` (tool result). Parser: last assistant line with a non-empty
    string ``content``. Tolerant of unknown roles/types (the CLI auto-updates).
  * Critic read-only posture = an ``--agent-file`` whose ``tools:`` allowlist excludes
    Write/Edit/Bash (proven: the model had no Write tool and refused to write). Backed by
    a scratch-only cwd and a before/after git-hash guard on C:/QM/repo.
  * Missing credential -> exit 1, stderr "No model configured ... /login to sign in";
    config resolves via USERPROFILE/HOME so a SYSTEM run must set them to the agent home.

No secret is ever printed or logged: only credential FIELD NAMES / the file PATH.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kimi_governor  # noqa: E402

# --------------------------------------------------------------------------- constants

CONFIG_PATH = Path(__file__).with_name("config") / "kimi_adapter.v1.json"
# Pinned - Kimi is NOT on PATH (audit kimi_cli.md sec1). Overridable via config.bin.
KIMI_BIN = Path(r"C:/Users/Administrator/.kimi-code/bin/kimi.exe")
AGENT_USER_HOME = Path(r"C:/Users/Administrator")

# 'research' is the unattended writer role (orchestration lane): its --agent-file
# allowlist grants Read/Grep/Glob/List/Write/Edit but NO Bash/PowerShell, so a
# prompt-injected run cannot shell out to farmctl/close-review/git/T_Live. 'creator'
# and 'formatter' share that no-shell posture. 'research_ml' is the ONLY shell-capable
# role and run_kimi accepts it only when the caller passes allow_shell=True (the
# orchestration lane and agent_chain never do; only the research package tooling may).
VALID_ROLES = {"creator", "critic", "formatter", "research", "research_ml"}
STATUS_OK = "ok"
STATUS_TIMEOUT = "timeout"
STATUS_AUTH_EXPIRED = "auth_expired"
STATUS_RATE_LIMITED = "rate_limited"
# A hard subscription-period cap (weekly/monthly), distinct from a transient
# rate_limited: retrying in 20-60s is pointless (evidence 2026-09-18, task
# d797e68f - the quota fetcher's rolling_7d read 1.1e-05 while the CLI returned
# "403 ... reached your weekly (7-day) usage limit" two minutes earlier). Never
# added to retry_statuses; kimi_governor treats it as an immediate, fetcher-
# independent EXHAUSTED signal (see kimi_governor.compute_state).
STATUS_QUOTA_EXHAUSTED = "quota_exhausted"
STATUS_MALFORMED = "malformed_output"
STATUS_SCHEMA_MISMATCH = "schema_mismatch"  # valid JSONL, no recognizable assistant content
STATUS_CLI_MISSING = "cli_missing"
STATUS_ERROR = "error"
STATUS_CRITIC_WROTE = "critic_wrote"
STATUS_PROTECTED_WRITE = "protected_write"  # a non-critic role touched a protected tree

RETRYABLE_DEFAULT = {STATUS_TIMEOUT, STATUS_RATE_LIMITED}

# Trees a Kimi run must never mutate (verdict/evidence state + live terminal). The
# before/after listing hash of these (skipping absent paths) backs the mutation guard
# in addition to the repo git-porcelain hash. Overridable via config.protected_trees.
DEFAULT_PROTECTED_TREES = (
    "D:/QM/strategy_farm/state",
    "D:/QM/reports/state",
    "D:/QM/strategy_farm/artifacts/cards_approved",
    "C:/QM/mt5/T_Live/MT5_Base/MQL5",
    "C:/QM/mt5/T_Live/MT5_Base/config",
)


# --------------------------------------------------------------------------- helpers

def load_config(path: Path | str = CONFIG_PATH) -> dict[str, Any]:
    cfg = json.loads(Path(path).read_text(encoding="utf-8"))
    if cfg.get("schema") != "qm.kimi-adapter.v1":
        raise ValueError(f"unexpected kimi adapter config schema: {cfg.get('schema')!r}")
    return cfg


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _utc_iso(ts: dt.datetime | None = None) -> str:
    return (ts or _now()).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _sha256_text(text: str) -> str:
    return hashlib.sha256((text or "").encode("utf-8")).hexdigest()


def _creationflags() -> int:
    return subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0  # type: ignore[attr-defined]


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def _env(environ: dict[str, str] | None) -> dict[str, str]:
    return dict(os.environ if environ is None else environ)


# --------------------------------------------------------------------------- stream-json parsing

def parse_stream_json(raw: str) -> str | None:
    """Final assistant text from Kimi stream-json (JSONL), or None if unparseable.

    Rule: the LAST line with ``role == 'assistant'`` and a non-empty string
    ``content``. Assistant lines carrying only ``tool_calls`` and every ``meta`` /
    ``tool`` line are ignored. Tolerant of blank/garbage lines and unknown roles so
    a CLI auto-update that adds event types does not silently break parsing.
    """
    if not raw:
        return None
    answer: str | None = None
    saw_any_json = False
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        saw_any_json = True
        if not isinstance(obj, dict):
            continue
        if obj.get("role") == "assistant":
            content = obj.get("content")
            if isinstance(content, str) and content.strip():
                answer = content
    if not saw_any_json:
        return None
    return answer


def _has_json_lines(raw: str) -> bool:
    """True iff at least one line of ``raw`` parses as JSON. Distinguishes a
    valid-JSONL-but-unrecognized-schema run (schema_mismatch) from non-JSON garbage
    (malformed_output) - a CLI auto-update that renames event shapes must fail with a
    distinct, operator-visible class rather than collapsing into malformed_output."""
    for line in (raw or "").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            json.loads(line)
            return True
        except ValueError:
            continue
    return False


def extract_cli_version(raw: str) -> str | None:
    """The version banner is the first stream-json meta line:
    {"role":"meta","type":"system.version","version":"0.43.1"}."""
    for line in (raw or "").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        if isinstance(obj, dict) and obj.get("type") == "system.version" and obj.get("version"):
            return str(obj["version"])
    return None


_RESUME_PREFIX = "To resume this session:"


def strip_text_mode(raw: str) -> str:
    """Last-resort cleanup of TEXT-mode output: drop the leading ``kimi version``
    banner, ``\u2022 `` thinking bullets, and the trailing resume trailer."""
    out: list[str] = []
    for line in (raw or "").splitlines():
        s = line.strip()
        if s.startswith("kimi version "):
            continue
        if s.startswith("\u2022 "):  # thinking bullet
            continue
        if s.startswith(_RESUME_PREFIX):
            continue
        out.append(line)
    return "\n".join(out).strip()


# --------------------------------------------------------------------------- error classification

def classify_error(rc: int, stderr: str, stdout: str, cfg: dict[str, Any]) -> str:
    """Map a failed/empty run to an error class using the config patterns.

    Only called when a run did not produce a clean parseable answer. ``timeout``,
    ``cli_missing`` and ``auth_expired`` (missing-credential pre-flight) are set by
    the caller before this runs; here we detect auth/rate patterns in the output.
    """
    blob = f"{stderr or ''}\n{stdout or ''}".lower()
    for entry in cfg.get("error_class_patterns") or []:
        status = entry.get("status")
        for pat in entry.get("patterns") or []:
            if str(pat).lower() in blob:
                return str(status)
    return STATUS_ERROR


# --------------------------------------------------------------------------- single-flight lock

class _LockBusy(Exception):
    pass


def _acquire_single_flight(lock_path: Path, wait_s: int, stale_s: int) -> Path:
    """Machine-wide single-flight lock. Returns the lock path once held; raises
    _LockBusy after wait_s. A lock whose stamp is older than stale_s is stolen."""
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + max(0, wait_s)
    while True:
        try:
            fd = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(json.dumps({"pid": os.getpid(), "stamp": _utc_iso()}))
            return lock_path
        except FileExistsError:
            # stale?
            try:
                info = json.loads(lock_path.read_text(encoding="utf-8"))
                stamp = kimi_governor._parse_ts(info.get("stamp"))
            except Exception:
                stamp = None
            if stamp is not None and (_now() - stamp).total_seconds() > stale_s:
                try:
                    lock_path.unlink()
                except Exception:
                    pass
                continue
            if time.monotonic() >= deadline:
                raise _LockBusy()
            time.sleep(1.0)


def _release_single_flight(lock_path: Path) -> None:
    try:
        lock_path.unlink()
    except Exception:
        pass


# --------------------------------------------------------------------------- repo-mutation guard

def _repo_porcelain_hash(repo_root: Path) -> str | None:
    """sha256 of ``git status --porcelain`` for the repo, or None if unavailable.
    Read-only; used to detect a call that mutated the repo (critic guard)."""
    try:
        if not (repo_root / ".git").exists() and not repo_root.exists():
            return None
        proc = subprocess.run(
            ["git", "-C", str(repo_root), "status", "--porcelain"],
            capture_output=True, text=True, timeout=60, creationflags=_creationflags(),
        )
        if proc.returncode != 0:
            return None
        return hashlib.sha256(proc.stdout.encode("utf-8")).hexdigest()
    except Exception:
        return None


def _dir_listing_hash(root: Path) -> str | None:
    """sha256 of (relpath, size, mtime) for every file under root - cheap change
    detector for a creator's scratch dir."""
    try:
        entries: list[str] = []
        for p in sorted(root.rglob("*")):
            if p.is_file():
                st = p.stat()
                entries.append(f"{p.relative_to(root).as_posix()}|{st.st_size}|{int(st.st_mtime)}")
        return hashlib.sha256("\n".join(entries).encode("utf-8")).hexdigest()
    except Exception:
        return None


def _protected_snapshot(roots: list[Any], excludes: set[str]) -> dict[str, str]:
    """{abs_path: 'size|mtime_ns'} for every file under each protected tree, skipping
    absent trees and the adapter's own ledger/lock/state files (``excludes``). Used
    before/after every run to detect a write into a verdict/evidence/T_Live tree."""
    snap: dict[str, str] = {}
    for root in roots:
        try:
            rp = Path(str(root))
        except Exception:
            continue
        if not rp.exists():
            continue
        try:
            files = [rp] if rp.is_file() else [p for p in rp.rglob("*") if p.is_file()]
        except OSError:
            continue
        for p in files:
            sp = str(p)
            if sp in excludes:
                continue
            try:
                st = p.stat()
            except OSError:
                continue
            snap[sp] = f"{st.st_size}|{st.st_mtime_ns}"
    return snap


def _snapshot_diff(before: dict[str, str], after: dict[str, str]) -> list[str]:
    """Sorted list of paths that were added, removed, or changed between snapshots."""
    changed: set[str] = {k for k, v in after.items() if before.get(k) != v}
    changed |= {k for k in before if k not in after}
    return sorted(changed)


def _protected_excludes(cfg: dict[str, Any]) -> set[str]:
    """The adapter's own ledger/lock/governor-state files, which live inside the
    protected trees and would otherwise trip the guard on every call."""
    gov = cfg.get("governor") or {}
    candidates = [
        cfg.get("ledger_path"),
        (cfg.get("single_flight") or {}).get("lock_path"),
        gov.get("state_path"),
        gov.get("log_path"),
        gov.get("flag_path"),
        gov.get("ledger_path"),
    ]
    return {str(Path(str(p))) for p in candidates if p}


# --------------------------------------------------------------------------- fake mode (tests)

def _fake_ledger_path(cfg: dict[str, Any], env: dict[str, str]) -> Path:
    override = env.get(cfg.get("fake_ledger_env", "QM_KIMI_FAKE_LEDGER"), "")
    if override:
        return Path(override)
    return Path(cfg.get("ledger_path") or "D:/QM/reports/state/kimi_usage_ledger.jsonl")


def _run_fake(cfg: dict[str, Any], *, role: str, capability: str, task_id: str, model: str,
              out_dir: Path, prompt: str, env: dict[str, str]) -> dict[str, Any]:
    forced = env.get(cfg.get("fake_status_env", "QM_KIMI_FAKE_STATUS"), "").strip()
    status = forced or STATUS_OK
    if status == STATUS_OK:
        text = f"[fake-kimi] {role} answer for task {task_id}"
    else:
        text = ""
    raw_path = out_dir / f"{role}_raw.jsonl"
    log_path = out_dir / f"{role}.log"
    _write_text(raw_path, json.dumps({"role": "meta", "type": "system.version", "version": "fake"}) + "\n"
                + (json.dumps({"role": "assistant", "content": text}) + "\n" if text else ""))
    _write_text(log_path, f"[fake mode] status={status}\n")
    result = _finalize(
        cfg, role=role, capability=capability, task_id=task_id, model=model,
        status=status, text=text, rc=0 if status == STATUS_OK else 1,
        latency_s=0.0, cli_version="fake", prompt=prompt,
        retries=0, usage=None, repo_write=False,
        log_path=log_path, raw_path=raw_path, cmd=["<fake>", role, model],
        error="" if status == STATUS_OK else f"forced:{status}",
        env=env, ledger_path=_fake_ledger_path(cfg, env), call_governor=False,
    )
    return result


# --------------------------------------------------------------------------- ledger + finalize

def _ledger_line(cfg: dict[str, Any], *, task_id: str, role: str, capability: str, model: str,
                 prompt_sha256: str, output_sha256: str, latency_s: float, status: str,
                 retries: int, cli_version: str | None, usage: Any) -> dict[str, Any]:
    period = cfg.get("subscription_period") or {"start": "2026-09-15", "end": "2026-10-15"}
    return {
        "schema": cfg.get("ledger_schema", "qm.kimi-usage/v1"),
        "ts_utc": _utc_iso(),
        "task_id": task_id,
        "role": role,
        "capability": capability,
        "model": model,
        "prompt_sha256": prompt_sha256,
        "output_sha256": output_sha256,
        "latency_s": round(float(latency_s), 3),
        "status": status,
        "retries": retries,
        "cli_version": cli_version,
        "usage": usage,  # never invented; null unless the CLI actually printed one
        "subscription_period": {"start": period.get("start"), "end": period.get("end")},
    }


def _append_ledger(ledger_path: Path, line: dict[str, Any]) -> None:
    try:
        ledger_path.parent.mkdir(parents=True, exist_ok=True)
        with ledger_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(line) + "\n")
    except Exception:
        pass


def _finalize(cfg: dict[str, Any], *, role: str, capability: str, task_id: str, model: str,
              status: str, text: str, rc: int, latency_s: float, cli_version: str | None,
              prompt: str, retries: int, usage: Any, repo_write: bool, log_path: Path,
              raw_path: Path, cmd: list[str], error: str, env: dict[str, str],
              ledger_path: Path, call_governor: bool = True,
              protected_write: bool = False, changed_paths: list[str] | None = None) -> dict[str, Any]:
    prompt_sha = _sha256_text(prompt)
    output_sha = _sha256_text(text)
    line = _ledger_line(
        cfg, task_id=task_id, role=role, capability=capability, model=model,
        prompt_sha256=prompt_sha, output_sha256=output_sha, latency_s=latency_s,
        status=status, retries=retries, cli_version=cli_version, usage=usage,
    )
    _append_ledger(ledger_path, line)
    if call_governor:
        try:
            kimi_governor.record(line, cfg=cfg)
        except Exception:
            pass  # a governor hiccup must never corrupt the call result
    return {
        "status": status,
        "text": text,
        "rc": rc,
        "latency_s": round(float(latency_s), 3),
        "cli_version": cli_version,
        "model": model,
        "prompt_sha256": prompt_sha,
        "output_sha256": output_sha,
        "retries": retries,
        "usage": usage,
        "repo_write": repo_write,
        "protected_write": protected_write,
        "changed_paths": list(changed_paths or []),
        "log_path": str(log_path),
        "raw_path": str(raw_path),
        "cmd": cmd,
        "error": error,
    }


# --------------------------------------------------------------------------- argv / posture

def _resolve_model(cfg: dict[str, Any], role: str, capability: str, model: str | None) -> str:
    if model:
        return model
    by_cap = cfg.get("models_by_capability") or {}
    if capability in by_cap:
        return str(by_cap[capability])
    by_role = cfg.get("models_by_role") or {}
    if role in by_role:
        return str(by_role[role])
    return str(cfg.get("default_model") or "kimi-code/kimi-for-coding")


def _materialize_agent_file(cfg: dict[str, Any], out_dir: Path, kind: str) -> Path:
    """Write the role's --agent-file allowlist into out_dir. ``kind`` selects the
    posture: 'critic' = read-only (no Write/Edit/Bash); 'research' = a no-shell
    writer (Read/Grep/Glob/List/Write/Edit, NO Bash/PowerShell) for the unattended
    creator/research/formatter roles."""
    if kind == "critic":
        name = cfg.get("critic_agent_filename", "kimi_readonly_critic.agent.md")
        content = cfg.get("critic_agent_file_content") or ""
    else:  # 'research' no-shell writer posture
        name = cfg.get("research_agent_filename", "kimi_noshell_research.agent.md")
        content = cfg.get("research_agent_file_content") or ""
    path = out_dir / name
    _write_text(path, content)
    return path


def _materialize_critic_agent_file(cfg: dict[str, Any], out_dir: Path) -> Path:
    """Back-compat shim: the read-only critic agent file."""
    return _materialize_agent_file(cfg, out_dir, "critic")


def build_argv(cfg: dict[str, Any], *, bin_path: Path, role: str, model: str, pointer: str,
               add_dirs: list[Path], out_dir: Path) -> list[str]:
    """Construct the Kimi argv. The prompt is delivered as a short pointer (never
    the prompt contents); the prompt file itself is passed via --add-dir.

    Non-critic unattended roles (creator/research/formatter) carry a no-shell
    --agent-file so their default toolset cannot Bash/PowerShell out of the sandbox;
    'research_ml' deliberately keeps the full shell toolset (no agent file) and is
    only reachable through run_kimi(allow_shell=True)."""
    cmd: list[str] = [str(bin_path), "-p", pointer,
                      "--output-format", str(cfg.get("output_format", "stream-json")),
                      "-m", model]
    roles_cfg = (cfg.get("roles") or {}).get(role) or {}
    if roles_cfg.get("use_agent_file"):
        agent_file = _materialize_agent_file(cfg, out_dir, str(roles_cfg.get("agent_file") or "critic"))
        cmd += ["--agent-file", str(agent_file)]
    for flag in roles_cfg.get("extra_flags") or []:
        cmd.append(str(flag))
    seen: set[str] = set()
    for d in [*add_dirs, out_dir]:
        ds = str(d)
        if ds not in seen:
            cmd += ["--add-dir", ds]
            seen.add(ds)
    return cmd


def _child_env(environ: dict[str, str] | None) -> dict[str, str]:
    """Ensure the OAuth credential resolves (config is found via USERPROFILE/HOME;
    a SYSTEM run would otherwise miss it) - probe 5 finding."""
    env = _env(environ)
    env["USERPROFILE"] = str(AGENT_USER_HOME)
    env["HOME"] = str(AGENT_USER_HOME)
    env["HOMEDRIVE"] = "C:"
    env["HOMEPATH"] = r"\Users\Administrator"
    return env


# --------------------------------------------------------------------------- process run

def _kill_tree(proc: subprocess.Popen[Any]) -> None:
    try:
        if sys.platform == "win32":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True,
                           creationflags=_creationflags(), timeout=60)
        proc.kill()
    except Exception:
        pass
    try:
        proc.wait(timeout=30)
    except Exception:
        pass


def _spawn_once(cmd: list[str], *, cwd: Path, env: dict[str, str], timeout_s: int,
                raw_path: Path, log_path: Path) -> dict[str, Any]:
    """One process attempt with an external watchdog + tree kill on timeout."""
    started = time.monotonic()
    with open(raw_path, "wb") as out_f, open(log_path, "wb") as log_f:
        proc = subprocess.Popen(
            cmd, cwd=str(cwd), stdin=subprocess.DEVNULL, stdout=out_f, stderr=log_f,
            env=env, shell=False, creationflags=_creationflags(),
        )
        try:
            proc.wait(timeout=timeout_s)
            timed_out = False
        except subprocess.TimeoutExpired:
            _kill_tree(proc)
            timed_out = True
    latency = time.monotonic() - started
    raw = raw_path.read_text(encoding="utf-8", errors="replace") if raw_path.exists() else ""
    stderr = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    return {"rc": (-9 if timed_out else proc.returncode), "timed_out": timed_out,
            "latency_s": latency, "raw": raw, "stderr": stderr}


# --------------------------------------------------------------------------- public entry point

def run_kimi(prompt: str, *, role: str, capability: str, task_id: str, model: str | None = None,
             cwd: Path, add_dirs: list[Path] | None = None, timeout_s: int = 600,
             out_dir: Path, environ: dict[str, str] | None = None,
             config: dict[str, Any] | None = None, allow_shell: bool = False) -> dict[str, Any]:
    """The single choke point for every Kimi call. See the module docstring for the
    contract. Returns a dict with keys: status, text, rc, latency_s, cli_version,
    model, prompt_sha256, output_sha256, retries, usage, repo_write, protected_write,
    changed_paths, log_path, raw_path, cmd, error.

    ``allow_shell`` gates the shell-capable roles: a role whose config carries
    ``requires_allow_shell`` (i.e. 'research_ml') raises ValueError unless the caller
    opts in explicitly. The orchestration lane and agent_chain never pass it."""
    cfg = config or load_config()
    env = _env(environ)
    if role not in VALID_ROLES:
        raise ValueError(f"invalid role {role!r}; expected one of {sorted(VALID_ROLES)}")
    roles_cfg = (cfg.get("roles") or {}).get(role) or {}
    if roles_cfg.get("requires_allow_shell") and not allow_shell:
        raise ValueError(
            f"role {role!r} is shell-capable and requires allow_shell=True "
            "(only the research package tooling may opt in; the orchestration lane "
            "and agent_chain never do)"
        )

    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    cwd = Path(cwd)
    add_dirs = [Path(d) for d in (add_dirs or [])]
    model = _resolve_model(cfg, role, capability, model)
    raw_path = out_dir / f"{role}_raw.jsonl"
    log_path = out_dir / f"{role}.log"
    ledger_path = Path(cfg.get("ledger_path") or "D:/QM/reports/state/kimi_usage_ledger.jsonl")

    # 1) Kill switch - never spawn.
    kill_env = cfg.get("kill_switch_env", "QM_KIMI")
    if str(env.get(kill_env, "")).strip() == "0":
        return _finalize(cfg, role=role, capability=capability, task_id=task_id, model=model,
                         status=STATUS_ERROR, text="", rc=0, latency_s=0.0, cli_version=None,
                         prompt=prompt, retries=0, usage=None, repo_write=False,
                         log_path=log_path, raw_path=raw_path, cmd=[], error="kill_switch",
                         env=env, ledger_path=ledger_path)

    # 2) Fake mode (tests).
    if str(env.get(cfg.get("fake_env", "QM_KIMI_FAKE"), "")).strip() == "1":
        return _run_fake(cfg, role=role, capability=capability, task_id=task_id, model=model,
                         out_dir=out_dir, prompt=prompt, env=env)

    bin_path = Path(cfg.get("bin") or KIMI_BIN)

    # 3) Pre-flight: CLI present? (never retry)
    if not bin_path.exists():
        return _finalize(cfg, role=role, capability=capability, task_id=task_id, model=model,
                         status=STATUS_CLI_MISSING, text="", rc=-1, latency_s=0.0, cli_version=None,
                         prompt=prompt, retries=0, usage=None, repo_write=False,
                         log_path=log_path, raw_path=raw_path, cmd=[str(bin_path)],
                         error=f"kimi CLI not found: {bin_path}", env=env, ledger_path=ledger_path)

    # 4) Pre-flight: credential present? (never retry; report the PATH only, never contents)
    cred = Path(cfg.get("credential_file") or "")
    if str(cred) and not cred.exists():
        return _finalize(cfg, role=role, capability=capability, task_id=task_id, model=model,
                         status=STATUS_AUTH_EXPIRED, text="", rc=-1, latency_s=0.0, cli_version=None,
                         prompt=prompt, retries=0, usage=None, repo_write=False,
                         log_path=log_path, raw_path=raw_path, cmd=[str(bin_path)],
                         error=f"credential file missing: {cred}", env=env, ledger_path=ledger_path)

    # 5) Timeout clamp.
    tmax = int(cfg.get("timeout_max_s", 1800))
    tdef = int(cfg.get("timeout_default_s", 600))
    timeout_s = int(timeout_s or tdef)
    timeout_s = max(1, min(timeout_s, tmax))

    # 6) Prompt file + short argv pointer.
    prompt_path = out_dir / f"{role}_prompt.md"
    answer_path = out_dir / f"{role}_answer.md"
    _write_text(prompt_path, prompt)
    try:
        if answer_path.exists():
            answer_path.unlink()
    except Exception:
        pass
    pointer_tmpl = cfg.get("prompt_pointer_template") or (
        "Read the file '{prompt_path}' and execute its instructions exactly; "
        "write your complete answer to '{answer_path}' and also print it; then exit.")
    pointer = pointer_tmpl.format(prompt_path=str(prompt_path), answer_path=str(answer_path))
    cmd = build_argv(cfg, bin_path=bin_path, role=role, model=model, pointer=pointer,
                     add_dirs=add_dirs, out_dir=out_dir)
    child_env = _child_env(environ)

    # 7) Single-flight lock around the whole spawn+retry sequence.
    sf = cfg.get("single_flight") or {}
    lock_path = Path(sf.get("lock_path") or "D:/QM/strategy_farm/state/kimi_adapter.lock")
    wait_s = int(sf.get("wait_s", 300))
    stale_s = int(sf.get("stale_s", 7200))
    try:
        _acquire_single_flight(lock_path, wait_s, stale_s)
    except _LockBusy:
        return _finalize(cfg, role=role, capability=capability, task_id=task_id, model=model,
                         status=STATUS_ERROR, text="", rc=-1, latency_s=0.0, cli_version=None,
                         prompt=prompt, retries=0, usage=None, repo_write=False,
                         log_path=log_path, raw_path=raw_path, cmd=cmd,
                         error="single_flight_busy", env=env, ledger_path=ledger_path)

    repo_root = Path(cfg.get("repo_root") or "C:/QM/repo")
    is_critic = bool(roles_cfg.get("read_only"))
    repo_before = _repo_porcelain_hash(repo_root)
    protected_roots = list(cfg.get("protected_trees", DEFAULT_PROTECTED_TREES) or [])
    protected_excludes = _protected_excludes(cfg)
    protected_before = _protected_snapshot(protected_roots, protected_excludes)

    retry_cfg = cfg.get("retry") or {}
    max_retries = int(retry_cfg.get("max_retries", 2))
    retry_statuses = set(retry_cfg.get("retry_statuses") or RETRYABLE_DEFAULT)
    backoff = list(retry_cfg.get("backoff_s") or [20, 60])

    attempt = 0
    result_run: dict[str, Any] = {}
    status = STATUS_ERROR
    text = ""
    error = ""
    cli_version: str | None = None
    try:
        while True:
            result_run = _spawn_once(cmd, cwd=cwd, env=child_env, timeout_s=timeout_s,
                                     raw_path=raw_path, log_path=log_path)
            raw = result_run["raw"]
            stderr = result_run["stderr"]
            cli_version = extract_cli_version(raw) or cli_version
            if result_run["timed_out"]:
                status, text, error = STATUS_TIMEOUT, "", f"timeout_after_{timeout_s}s_tree_killed"
            else:
                parsed = parse_stream_json(raw)
                saw_json = _has_json_lines(raw)
                if parsed is None:
                    # fallback: the answer file the model may have written
                    if answer_path.exists():
                        parsed = answer_path.read_text(encoding="utf-8", errors="replace").strip() or None
                if parsed is None and raw.strip() and not saw_json:
                    # last-ditch text-mode stripping - ONLY when the output was not
                    # JSON at all, so valid JSONL with a renamed schema is not
                    # mistaken for plain text (would mask a schema_mismatch).
                    stripped = strip_text_mode(raw)
                    parsed = stripped or None
                if result_run["rc"] == 0 and parsed:
                    status, text, error = STATUS_OK, parsed, ""
                elif result_run["rc"] == 0 and not parsed and saw_json:
                    # valid JSON, but no recognizable assistant content (unknown/renamed
                    # event shapes) - a config-class error distinct from non-JSON garbage.
                    status, text, error = STATUS_SCHEMA_MISMATCH, "", "valid_json_no_assistant_content"
                elif result_run["rc"] == 0 and not parsed:
                    status, text, error = STATUS_MALFORMED, "", "empty_or_unparseable_output"
                else:
                    status = classify_error(result_run["rc"], stderr, raw, cfg)
                    text, error = "", f"rc={result_run['rc']}:{status}"

            if status in retry_statuses and attempt < max_retries:
                delay = backoff[min(attempt, len(backoff) - 1)] if backoff else 0
                attempt += 1
                time.sleep(max(0, int(delay)))
                continue
            break
    finally:
        _release_single_flight(lock_path)

    # 8) Mutation guard - two scopes: (a) the repo git-porcelain hash, and (b) a
    #    before/after listing hash of the protected verdict/evidence/T_Live trees.
    repo_after = _repo_porcelain_hash(repo_root)
    repo_write = bool(repo_before is not None and repo_after is not None and repo_before != repo_after)
    protected_after = _protected_snapshot(protected_roots, protected_excludes)
    changed_paths = _snapshot_diff(protected_before, protected_after)
    protected_write = bool(changed_paths)
    if is_critic and (repo_write or protected_write):
        # a critic that mutated anything is a failed run; discard its text
        status = STATUS_CRITIC_WROTE
        text = ""
        error = "critic_mutated_protected" if protected_write else "critic_mutated_repo"
    elif protected_write and status == STATUS_OK:
        # a non-critic role (research/creator/formatter) wrote into a protected tree:
        # keep its text, but flag it loudly so the lane result and review can see it.
        status = STATUS_PROTECTED_WRITE
        error = "protected_write:" + ";".join(changed_paths[:5])

    return _finalize(cfg, role=role, capability=capability, task_id=task_id, model=model,
                     status=status, text=text, rc=result_run.get("rc", -1),
                     latency_s=result_run.get("latency_s", 0.0), cli_version=cli_version,
                     prompt=prompt, retries=attempt, usage=None, repo_write=repo_write,
                     log_path=log_path, raw_path=raw_path, cmd=cmd, error=error,
                     env=env, ledger_path=ledger_path,
                     protected_write=protected_write, changed_paths=changed_paths)


# --------------------------------------------------------------------------- CLI (manual smoke)

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Kimi adapter manual smoke call")
    ap.add_argument("--role", default="research", choices=sorted(VALID_ROLES))
    ap.add_argument("--capability", default="research")
    ap.add_argument("--task-id", default="manual-smoke")
    ap.add_argument("--model", default=None)
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--cwd", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--timeout-s", type=int, default=600)
    args = ap.parse_args(argv)
    res = run_kimi(args.prompt, role=args.role, capability=args.capability, task_id=args.task_id,
                   model=args.model, cwd=Path(args.cwd), add_dirs=[], timeout_s=args.timeout_s,
                   out_dir=Path(args.out_dir))
    printable = {k: v for k, v in res.items() if k != "text"}
    print(json.dumps(printable, indent=2))
    print("--- text ---")
    print(res.get("text", ""))
    return 0 if res.get("status") == STATUS_OK else 1


if __name__ == "__main__":
    raise SystemExit(main())
