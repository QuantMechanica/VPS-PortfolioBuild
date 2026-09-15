"""Creator -> Critic -> Formatter prompt chain with a cross-vendor critic (OWNER 2026-09-15).

Why
---
Until 2026-09-15 the strategy farm had an automated critic only for EA builds
(codex_build_ea -> codex_review_ea -> claude_review_ea).  Every other lane
delivery (ops tickets, research, reports) reached the orchestrator's REVIEW
queue with a single self-written verdict, and the only critic was the
orchestrator itself - same vendor whenever the creator was the Claude/Sonnet
lane.  OWNER 2026-09-15: establish the three-stage chain (Creator -> Critic ->
Formatter) as an automated background step, cross-model by construction.

What this module does
---------------------
* ``run``               - full chain over raw inputs: creator (default Claude
                          Sonnet) -> critic (cross-vendor) -> formatter (Haiku).
* ``critique``          - chain over an EXISTING lane delivery (agent_tasks row in
                          REVIEW): stage 1 is the delivered artifact, stage 2 a
                          critic from a different vendor than the executing lane,
                          stage 3 the A/B document the orchestrator reads first.
* ``critique-pending``  - bounded sweep over REVIEW rows without a receipt.

Every stage writes its prompt and output to
``D:/QM/strategy_farm/artifacts/agent_chain/<chain_id>/`` and the receipt to
``D:/QM/strategy_farm/state/agent_chain/``.  The chain NEVER changes an
``agent_tasks`` row, a verdict, a work item or a file in the repo: the critic
seats run read-only (Claude ``--allowedTools Read Grep Glob``, Codex
``--sandbox read-only``).  Default invocation is a dry run that resolves seats
and gates without spending a token; ``--apply`` spawns.

Cross-vendor rule (config ``roles.critic.by_creator_vendor``): candidates are
tried in order; a vendor is skipped when its quota gate is closed
(``CLAUDE_DISABLED.flag``, ``CODEX_LOW_TOKENS.flag`` + Codex budget line,
``AGY_LOW_QUOTA.flag``).  A same-vendor candidate may only be the last resort
and is recorded as ``cross_vendor=false``.  Kill switch: ``QM_AGENT_CHAIN=0``.
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Callable

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = Path(__file__).with_name("config") / "agent_chain.v1.json"
PROMPT_DIR = Path(__file__).with_name("prompts") / "chain"
KILL_SWITCH_ENV = "QM_AGENT_CHAIN"
FAKE_ENV = "QM_AGENT_CHAIN_FAKE"
PYTHON_EXE = Path(sys.executable)
CLAUDE_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\claude.cmd")
CODEX_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\codex.cmd")
AGY_BIN = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\Administrator\AppData\Local")) / "agy" / "bin" / "agy.exe"
CONPTY_RUNNER = Path(__file__).with_name("agy_conpty_run.py")
AGENT_USER_HOME = Path(r"C:\Users\Administrator")
CODEX_HOME = Path(os.environ.get("CODEX_HOME", r"C:\Users\Administrator\.codex"))
RECEIPT_SCHEMA = "qm.agent-chain.receipt.v1"
CRITIC_SCHEMA = "qm.agent-chain.critic.v1"
VENDOR_ALIASES = {"gemini": "agy", "antigravity": "agy", "anthropic": "claude", "openai": "codex"}


class ChainError(Exception):
    """Configuration or contract error (never a stage failure)."""


class ChainGated(ChainError):
    """No seat available for a role (quota gates / kill switch)."""


@dataclasses.dataclass(frozen=True)
class Seat:
    vendor: str
    model: str
    effort: str | None = None
    note: str = ""

    def label(self) -> str:
        eff = f"/{self.effort}" if self.effort else ""
        return f"{self.vendor}:{self.model}{eff}"

    def as_dict(self) -> dict[str, Any]:
        return {"vendor": self.vendor, "model": self.model, "effort": self.effort, "note": self.note}


@dataclasses.dataclass
class StageResult:
    role: str
    seat: dict[str, Any] | None
    status: str  # ok | error | timeout | gated | skipped | reused
    returncode: int | None = None
    output_path: str | None = None
    prompt_path: str | None = None
    sha256: str | None = None
    duration_s: float | None = None
    cost_usd: float | None = None
    usage: dict[str, Any] | None = None
    cross_vendor: bool | None = None
    reason: str = ""
    text: str = dataclasses.field(default="", repr=False)

    def as_dict(self) -> dict[str, Any]:
        data = dataclasses.asdict(self)
        data.pop("text", None)
        return data


# --------------------------------------------------------------------------- helpers

def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def utc_iso(ts: dt.datetime | None = None) -> str:
    return (ts or utc_now()).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def utc_stamp(ts: dt.datetime | None = None) -> str:
    return (ts or utc_now()).strftime("%Y%m%dT%H%M%SZ")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_config(path: Path = CONFIG_PATH) -> dict[str, Any]:
    cfg = json.loads(Path(path).read_text(encoding="utf-8"))
    if cfg.get("schema") != "qm.agent-chain.v1":
        raise ChainError(f"unexpected config schema: {cfg.get('schema')!r}")
    return cfg


def kill_switch_active(environ: dict[str, str] | None = None) -> bool:
    env = os.environ if environ is None else environ
    return str(env.get(KILL_SWITCH_ENV, "1")).strip() == "0"


def fake_mode(environ: dict[str, str] | None = None) -> bool:
    env = os.environ if environ is None else environ
    return str(env.get(FAKE_ENV, "")).strip() == "1"


def normalize_vendor(value: str | None) -> str:
    v = str(value or "").strip().lower()
    v = VENDOR_ALIASES.get(v, v)
    return v if v in {"claude", "codex", "agy"} else "unknown"


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def _write_json(path: Path, data: Any) -> None:
    _write_text(path, json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True) + "\n")


# --------------------------------------------------------------------------- gates

def vendor_gate(
    vendor: str,
    cfg: dict[str, Any],
    environ: dict[str, str] | None = None,
    *,
    budget_eval: Callable[[], dict[str, Any]] | None = None,
) -> str | None:
    """Return the reason a vendor is unavailable right now, or None when open."""
    env = os.environ if environ is None else environ
    if kill_switch_active(env):
        return "kill_switch_QM_AGENT_CHAIN=0"
    gates = cfg.get("gates") or {}
    if vendor == "claude":
        flag = Path(str(gates.get("claude_disabled_flag") or ""))
        if str(flag) and flag.exists():
            return "claude_disabled_flag"
        return None
    if vendor == "codex":
        flag = Path(str(gates.get("codex_low_tokens_flag") or ""))
        if str(flag) and flag.exists():
            return "codex_low_tokens_flag"
        if gates.get("codex_budget_line"):
            try:
                if budget_eval is None:
                    sys.path.insert(0, str(Path(__file__).parent))
                    import codex_budget_line  # type: ignore

                    verdict = codex_budget_line.evaluate(persist=False)
                else:
                    verdict = budget_eval()
            except Exception as exc:  # noqa: BLE001 - the gate must fail closed, not crash the chain
                return f"codex_budget_line_unreadable:{type(exc).__name__}"
            if not verdict.get("allowed", False):
                return f"codex_budget_line:{verdict.get('reason', 'denied')}"
        return None
    if vendor == "agy":
        flag = Path(str(gates.get("agy_low_quota_flag") or ""))
        if str(flag) and flag.exists():
            return "agy_low_quota_flag"
        if not fake_mode(env) and not AGY_BIN.exists() and shutil.which("agy") is None:
            return "agy_missing"
        return None
    return f"unknown_vendor:{vendor}"


GateFn = Callable[[str], str | None]


def _seat_from(entry: dict[str, Any]) -> Seat:
    return Seat(
        vendor=normalize_vendor(entry.get("vendor")),
        model=str(entry.get("model") or "default"),
        effort=(str(entry["effort"]) if entry.get("effort") else None),
        note=str(entry.get("note") or ""),
    )


def resolve_critic(
    creator_vendor: str,
    cfg: dict[str, Any],
    gate: GateFn,
    *,
    allow_agy: bool = True,
) -> tuple[Seat, bool, list[dict[str, Any]]]:
    """Pick the first open critic seat for this creator vendor; record the trace."""
    creator_vendor = normalize_vendor(creator_vendor)
    open_seats, trace = open_critic_seats(creator_vendor, cfg, gate, allow_agy=allow_agy)
    if not open_seats:
        raise ChainGated(f"no critic seat available for creator vendor {creator_vendor!r}: {trace}")
    seat, cross = open_seats[0]
    return seat, cross, trace


def open_critic_seats(
    creator_vendor: str,
    cfg: dict[str, Any],
    gate: GateFn,
    *,
    allow_agy: bool = True,
) -> tuple[list[tuple[Seat, bool]], list[dict[str, Any]]]:
    """All open critic seats in config order (first = selected, the rest = runtime fallbacks)."""
    creator_vendor = normalize_vendor(creator_vendor)
    table = (cfg.get("roles") or {}).get("critic", {}).get("by_creator_vendor", {})
    candidates = table.get(creator_vendor) or table.get("unknown") or []
    trace: list[dict[str, Any]] = []
    open_seats: list[tuple[Seat, bool]] = []
    for entry in candidates:
        seat = _seat_from(entry)
        if seat.vendor == "agy" and not allow_agy:
            trace.append({"seat": seat.label(), "skipped": "agy_not_allowed_for_this_spec"})
            continue
        reason = gate(seat.vendor)
        if reason:
            trace.append({"seat": seat.label(), "skipped": reason})
            continue
        cross = seat.vendor != creator_vendor
        trace.append({"seat": seat.label(), "selected": not open_seats, "fallback": bool(open_seats), "cross_vendor": cross})
        open_seats.append((seat, cross))
    return open_seats, trace


def resolve_formatter(cfg: dict[str, Any], gate: GateFn) -> tuple[Seat, list[dict[str, Any]]]:
    role = (cfg.get("roles") or {}).get("formatter", {})
    trace: list[dict[str, Any]] = []
    for entry in [role.get("default") or {}, *(role.get("fallback") or [])]:
        if not entry:
            continue
        seat = _seat_from(entry)
        reason = gate(seat.vendor)
        if reason:
            trace.append({"seat": seat.label(), "skipped": reason})
            continue
        trace.append({"seat": seat.label(), "selected": True})
        return seat, trace
    raise ChainGated(f"no formatter seat available: {trace}")


def resolve_creator(spec: dict[str, Any], cfg: dict[str, Any], gate: GateFn) -> tuple[Seat, list[dict[str, Any]]]:
    entry = spec.get("creator") or (cfg.get("roles") or {}).get("creator", {}).get("default") or {}
    seat = _seat_from(entry)
    reason = gate(seat.vendor)
    if reason:
        raise ChainGated(f"creator seat {seat.label()} unavailable: {reason}")
    return seat, [{"seat": seat.label(), "selected": True}]


# --------------------------------------------------------------------------- prompts

_PLACEHOLDER = re.compile(r"{{\s*([a-zA-Z0-9_]+)\s*}}")


def render(template: str, fields: dict[str, str], prompt_dir: Path = PROMPT_DIR) -> str:
    text = (Path(prompt_dir) / f"{template}.md").read_text(encoding="utf-8")

    def sub(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in fields:
            raise ChainError(f"prompt {template}: unbound placeholder {{{{{key}}}}}")
        return str(fields[key])

    return _PLACEHOLDER.sub(sub, text)


def inline_inputs(
    input_paths: list[str],
    input_texts: dict[str, str],
    cfg: dict[str, Any],
) -> tuple[str, list[dict[str, Any]]]:
    limits = cfg.get("limits") or {}
    inline_max = int(limits.get("inline_input_max_bytes") or 60000)
    total_max = int(limits.get("input_max_bytes") or 240000)
    parts: list[str] = []
    bindings: list[dict[str, Any]] = []
    budget = total_max
    for raw in input_paths:
        path = Path(raw)
        if not path.is_absolute():
            path = REPO_ROOT / path
        if not path.exists():
            parts.append(f"### {raw}\n\n(MISSING on disk - treat every claim about this file as unverifiable)\n")
            bindings.append({"path": str(path), "exists": False})
            continue
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        bindings.append({"path": str(path), "exists": True, "bytes": len(data), "sha256": digest})
        text = data.decode("utf-8", errors="replace")
        cap = min(inline_max, max(budget, 0))
        if len(text.encode("utf-8")) > cap:
            text = text.encode("utf-8")[:cap].decode("utf-8", errors="ignore") + (
                f"\n\n[... TRUNCATED for the prompt at {cap} bytes; the full file is at {path} - read it there ...]\n"
            )
        budget -= len(text.encode("utf-8"))
        parts.append(f"### {path} (sha256 {digest[:16]}, {len(data)} bytes)\n\n{text}\n")
    for label, text in input_texts.items():
        parts.append(f"### {label}\n\n{text}\n")
    return "\n".join(parts) if parts else "(no inputs)", bindings


# --------------------------------------------------------------------------- adapters

def resolve_cli(vendor: str) -> str:
    if vendor == "codex":
        return shutil.which("codex.cmd") or shutil.which("codex") or str(CODEX_FALLBACK)
    if vendor == "claude":
        return shutil.which("claude.cmd") or shutil.which("claude") or str(CLAUDE_FALLBACK)
    if vendor == "agy":
        return str(AGY_BIN) if AGY_BIN.exists() else (shutil.which("agy") or str(AGY_BIN))
    raise ChainError(f"unsupported vendor: {vendor}")


def seat_env(vendor: str, base: dict[str, str] | None = None) -> dict[str, str]:
    env = dict(os.environ if base is None else base)
    env["QM_AGENT_ID"] = vendor if vendor != "agy" else "gemini"
    env["QM_AGENT_CHAIN_STAGE"] = "1"
    if vendor == "codex":
        env["CODEX_HOME"] = str(CODEX_HOME)
    if vendor in {"claude", "agy"}:
        env["USERPROFILE"] = str(AGENT_USER_HOME)
        env["HOME"] = str(AGENT_USER_HOME)
        env["HOMEDRIVE"] = "C:"
        env["HOMEPATH"] = r"\Users\Administrator"
    if vendor == "agy":
        env.setdefault("TERM", "dumb")
        env.setdefault("NO_COLOR", "1")
        env.setdefault("FORCE_COLOR", "0")
        env.setdefault("CI", "1")
    return env


def _creationflags() -> int:
    return subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0  # type: ignore[attr-defined]


def _model_id(seat: Seat, cfg: dict[str, Any]) -> str:
    vendors = cfg.get("vendors") or {}
    if seat.vendor == "codex":
        tiers = (vendors.get("codex") or {}).get("tiers") or {}
        return str(tiers.get(seat.model) or seat.model)
    if seat.vendor == "claude":
        models = (vendors.get("claude") or {}).get("models") or {}
        return str(models.get(seat.model) or seat.model)
    return ""


def _kill_tree(proc: subprocess.Popen[Any]) -> None:
    """Kill the whole process tree (shell=True leaves the CLI alive when only the shell dies)."""
    try:
        if sys.platform == "win32":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True,
                           creationflags=_creationflags(), timeout=60)
        proc.kill()
    except Exception:  # noqa: BLE001 - best effort; the caller records the timeout regardless
        pass
    try:
        proc.wait(timeout=30)
    except Exception:  # noqa: BLE001
        pass


def _wait_or_kill(proc: subprocess.Popen[Any], timeout: int) -> bool:
    """True when the process ended in time; False after a tree kill on timeout."""
    try:
        proc.wait(timeout=timeout)
        return True
    except subprocess.TimeoutExpired:
        _kill_tree(proc)
        return False


def _run_claude(
    seat: Seat,
    prompt: str,
    *,
    cfg: dict[str, Any],
    cwd: Path,
    add_dirs: list[Path],
    timeout: int,
    log_path: Path,
    prompt_path: Path,
    out_path: Path,
    environ: dict[str, str] | None,
) -> dict[str, Any]:
    """Headless Claude Code with a HARD read-only envelope.

    Live finding 2026-09-15 07:1xZ: ``--allowedTools`` alone does not restrict a
    headless run when the user settings carry ``permissions.defaultMode: auto`` -
    the first live critic ran Bash. Hence: ``--tools`` (the built-in tool set is
    reduced to Read/Grep/Glob), ``--disallowedTools`` as the second belt,
    ``--permission-mode dontAsk`` (anything that would prompt is denied, never
    blocks), ``--strict-mcp-config`` with an empty config (no connectors such as
    Gmail/Notion reach the critic), ``--max-turns`` to bound tool loops.
    """
    claude_cfg = (cfg.get("vendors") or {}).get("claude") or {}
    tools = list(claude_cfg.get("read_only_tools") or ["Read", "Grep", "Glob"])
    disallowed = list(claude_cfg.get("disallowed_tools") or
                      ["Bash", "PowerShell", "Edit", "Write", "MultiEdit", "NotebookEdit", "WebFetch", "WebSearch",
                       "Agent", "Workflow", "Artifact"])
    max_turns = int(claude_cfg.get("max_turns") or 40)
    mcp_empty = out_path.parent / "mcp_empty.json"
    if not mcp_empty.exists():
        _write_json(mcp_empty, {"mcpServers": {}})
    cmd = [resolve_cli("claude"), "-p", "--model", _model_id(seat, cfg), "--output-format", "json",
           "--permission-mode", "dontAsk", "--max-turns", str(max_turns),
           "--strict-mcp-config", "--mcp-config", str(mcp_empty)]
    for d in add_dirs:
        cmd += ["--add-dir", str(d)]
    cmd += ["--tools", *tools, "--disallowedTools", *disallowed]
    started = time.monotonic()
    with open(prompt_path, "rb") as stdin_f, open(out_path, "wb") as out_f, open(log_path, "wb") as log_f:
        proc = subprocess.Popen(
            cmd,
            cwd=str(cwd),
            stdin=stdin_f,
            stdout=out_f,
            stderr=log_f,
            env=seat_env("claude", environ),
            shell=True,
            creationflags=_creationflags(),
        )
        finished = _wait_or_kill(proc, timeout)
    raw = out_path.read_text(encoding="utf-8", errors="replace") if out_path.exists() else ""
    if not finished:
        return {"rc": -9, "status": "timeout", "text": raw, "cmd": cmd, "duration_s": time.monotonic() - started,
                "reason": f"timeout_after_{timeout}s_tree_killed"}
    result: dict[str, Any] = {"rc": proc.returncode, "cmd": cmd, "duration_s": time.monotonic() - started}
    try:
        data = json.loads(raw)
    except ValueError:
        result.update({"status": "error" if proc.returncode else "ok", "text": raw, "reason": "non_json_output"})
        return result
    text = str(data.get("result") or "")
    result.update({
        "text": text,
        "status": "error" if (proc.returncode or data.get("is_error")) else "ok",
        "cost_usd": data.get("total_cost_usd"),
        "usage": data.get("usage"),
        "session_id": data.get("session_id"),
        "model_usage": data.get("modelUsage"),
        "permission_denials": data.get("permission_denials"),
    })
    if data.get("is_error"):
        result["reason"] = f"claude_is_error:{str(data.get('result'))[:200]}"
    return result


def _run_codex(
    seat: Seat,
    prompt: str,
    *,
    cfg: dict[str, Any],
    cwd: Path,
    timeout: int,
    log_path: Path,
    prompt_path: Path,
    out_path: Path,
    environ: dict[str, str] | None,
) -> dict[str, Any]:
    sandbox = str(((cfg.get("vendors") or {}).get("codex") or {}).get("sandbox") or "read-only")
    effort = seat.effort or "medium"
    cmd = [
        resolve_cli("codex"), "exec", "-m", _model_id(seat, cfg),
        "-c", f'model_reasoning_effort="{effort}"',
        "-s", sandbox, "--skip-git-repo-check", "-C", str(cwd), "-o", str(out_path),
    ]
    started = time.monotonic()
    popen_kwargs: dict[str, Any] = {
        "env": seat_env("codex", environ),
        "shell": True,
        "creationflags": _creationflags(),
        "close_fds": True,
    }
    with open(prompt_path, "rb") as stdin_f, open(log_path, "wb") as log_f:
        popen_kwargs.update({"stdin": stdin_f, "stdout": log_f, "stderr": subprocess.STDOUT})
        proc: subprocess.Popen[Any]
        try:
            sys.path.insert(0, str(Path(__file__).parent))
            import managed_codex  # type: ignore

            proc, _lease = managed_codex.spawn_managed_codex(
                Path(str((cfg.get("paths") or {}).get("farm_root") or r"D:\QM\strategy_farm")),
                cmd,
                purpose="agent_chain",
                cwd=cwd,
                max_age_minutes=max(5, timeout // 60 + 5),
                dedupe_key="agent_chain:codex",
                metadata={"log": str(log_path), "out": str(out_path)},
                **popen_kwargs,
            )
        except ImportError:
            proc = subprocess.Popen(cmd, cwd=str(cwd), **popen_kwargs)
        if not _wait_or_kill(proc, timeout):
            return {"rc": -9, "status": "timeout", "text": "", "cmd": cmd, "duration_s": time.monotonic() - started,
                    "reason": f"timeout_after_{timeout}s_tree_killed"}
    text = out_path.read_text(encoding="utf-8", errors="replace") if out_path.exists() else ""
    status = "ok" if proc.returncode == 0 and text.strip() else "error"
    return {"rc": proc.returncode, "status": status, "text": text, "cmd": cmd,
            "duration_s": time.monotonic() - started,
            "reason": "" if status == "ok" else f"codex_rc={proc.returncode}_empty={not text.strip()}"}


def _run_agy(
    seat: Seat,
    prompt: str,
    *,
    cfg: dict[str, Any],
    cwd: Path,
    add_dirs: list[Path],
    timeout: int,
    log_path: Path,
    prompt_path: Path,
    out_path: Path,
    environ: dict[str, str] | None,
) -> dict[str, Any]:
    # agy reads no stdin: pointer prompt + instruction to write the answer file.
    pointer = (
        f"Read the file '{prompt_path}' and execute its instructions exactly. Write your complete answer "
        f"to the file '{out_path}' (overwrite), then print it and exit. Do not modify any other file."
    )
    cmd = [str(PYTHON_EXE), str(CONPTY_RUNNER), resolve_cli("agy"), "--dangerously-skip-permissions",
           "--print-timeout", f"{max(1, timeout // 60)}m"]
    for d in [cwd, *add_dirs, out_path.parent]:
        cmd += ["--add-dir", str(d)]
    cmd += ["-p", pointer]
    started = time.monotonic()
    with open(log_path, "wb") as log_f:
        proc = subprocess.Popen(cmd, cwd=str(cwd), stdout=log_f, stderr=subprocess.STDOUT,
                                env=seat_env("agy", environ), shell=False, creationflags=_creationflags())
        if not _wait_or_kill(proc, timeout + 60):
            return {"rc": -9, "status": "timeout", "text": "", "cmd": cmd, "duration_s": time.monotonic() - started,
                    "reason": f"timeout_after_{timeout + 60}s_tree_killed"}
    text = out_path.read_text(encoding="utf-8", errors="replace") if out_path.exists() else ""
    if not text.strip() and log_path.exists():
        text = log_path.read_text(encoding="utf-8", errors="replace")
    status = "ok" if proc.returncode == 0 and text.strip() else "error"
    return {"rc": proc.returncode, "status": status, "text": text, "cmd": cmd,
            "duration_s": time.monotonic() - started, "reason": "" if status == "ok" else f"agy_rc={proc.returncode}"}


def _fake_adapter(seat: Seat, role: str, prompt: str, environ: dict[str, str] | None) -> dict[str, Any]:
    env = os.environ if environ is None else environ
    override = env.get(f"{FAKE_ENV}_{role.upper()}_FILE", "")
    unparsed_vendors = {v.strip() for v in env.get(f"{FAKE_ENV}_UNPARSED_VENDORS", "").split(",") if v.strip()}
    if override and Path(override).exists():
        text = Path(override).read_text(encoding="utf-8")
    elif role == "critic" and seat.vendor in unparsed_vendors:
        text = "[fake] critic returned prose only, no JSON block (simulated timeout / partial output)\n"
    elif role == "creator":
        text = "## Summary\n\nFAKE creator summary.\n\n## Facts with sources\n\n| fact | source | kind |\n|---|---|---|\n| f | p:1 | measured |\n\n## Unknowns\n\n- none\n"
    elif role == "critic":
        text = (
            "## Audit notes\n\nFAKE critic audit.\n\n```json\n"
            + json.dumps({
                "schema": CRITIC_SCHEMA, "verdict": "GAPS",
                "findings": [{"id": "F1", "severity": "major", "claim": "c", "problem": "p", "evidence": "e:1",
                              "check_performed": "read", "action": "a"}],
                "unverifiable_claims": [], "open_questions": [], "scope_drift": "none",
            }, indent=2)
            + "\n```\n"
        )
    else:
        text = "## A. Zusammenfassung\n\nFAKE.\n\n## B. Identifizierte Lücken & Handlungsbedarf\n\n| # | Schwere | Befund | Evidenz | Handlung |\n|---|---|---|---|---|\n| F1 | major | p | e:1 | a |\n\nKritiker-Urteil: GAPS\n"
    return {"rc": 0, "status": "ok", "text": text, "cmd": ["fake", seat.label(), role], "duration_s": 0.0,
            "cost_usd": 0.0}


def run_seat(
    seat: Seat,
    role: str,
    prompt: str,
    *,
    cfg: dict[str, Any],
    out_dir: Path,
    stage_name: str,
    cwd: Path,
    add_dirs: list[Path],
    timeout: int,
    environ: dict[str, str] | None = None,
) -> dict[str, Any]:
    prompt_path = out_dir / f"{stage_name}_prompt.md"
    _write_text(prompt_path, prompt)
    if fake_mode(environ):
        result = _fake_adapter(seat, role, prompt, environ)
    else:
        log_path = out_dir / f"{stage_name}_{seat.vendor}.log"
        out_path = out_dir / f"{stage_name}_{seat.vendor}_answer.md"
        if seat.vendor == "claude":
            result = _run_claude(seat, prompt, cfg=cfg, cwd=cwd, add_dirs=add_dirs, timeout=timeout,
                                 log_path=log_path, prompt_path=prompt_path,
                                 out_path=out_dir / f"{stage_name}_{seat.vendor}_raw.json", environ=environ)
        elif seat.vendor == "codex":
            result = _run_codex(seat, prompt, cfg=cfg, cwd=cwd, timeout=timeout, log_path=log_path,
                                prompt_path=prompt_path, out_path=out_path, environ=environ)
        elif seat.vendor == "agy":
            result = _run_agy(seat, prompt, cfg=cfg, cwd=cwd, add_dirs=add_dirs, timeout=timeout,
                              log_path=log_path, prompt_path=prompt_path, out_path=out_path, environ=environ)
        else:
            raise ChainError(f"unsupported vendor {seat.vendor}")
        result["log_path"] = str(log_path)
    result["prompt_path"] = str(prompt_path)
    return result


# --------------------------------------------------------------------------- critic parsing

_FENCE = re.compile(r"```(?:json)?\s*\n(.*?)\n```", re.DOTALL)


def parse_critic_json(text: str) -> dict[str, Any] | None:
    """Return the LAST fenced JSON block carrying the critic schema, or None."""
    for block in reversed(_FENCE.findall(text or "")):
        try:
            data = json.loads(block)
        except ValueError:
            continue
        if isinstance(data, dict) and data.get("schema") == CRITIC_SCHEMA and isinstance(data.get("findings"), list):
            return data
    return None


def critic_verdict(data: dict[str, Any] | None) -> str:
    if not data:
        return "UNPARSED"
    severities = {str(f.get("severity", "")).lower() for f in data.get("findings", []) if isinstance(f, dict)}
    if "blocking" in severities:
        return "REJECT"
    if "major" in severities:
        return "GAPS"
    declared = str(data.get("verdict") or "").upper()
    return declared if declared in {"PASS", "GAPS", "REJECT"} else "PASS"


# --------------------------------------------------------------------------- chain

def _stage_from(role: str, seat: Seat | None, result: dict[str, Any], out_dir: Path, stage_name: str,
                cross_vendor: bool | None = None) -> StageResult:
    text = str(result.get("text") or "")
    output_path = out_dir / f"{stage_name}.md"
    _write_text(output_path, text)
    return StageResult(
        role=role,
        seat=seat.as_dict() if seat else None,
        status=str(result.get("status") or "error"),
        returncode=result.get("rc"),
        output_path=str(output_path),
        prompt_path=result.get("prompt_path"),
        sha256=sha256_text(text),
        duration_s=(round(float(result["duration_s"]), 3) if result.get("duration_s") is not None else None),
        cost_usd=result.get("cost_usd"),
        usage=result.get("usage"),
        cross_vendor=cross_vendor,
        reason=str(result.get("reason") or ""),
        text=text,
    )


def _bindings_section(receipt: dict[str, Any]) -> str:
    lines = ["", "## C. Bindings (runner-generated)", ""]
    lines.append(f"- chain_id: `{receipt['chain_id']}` · kind: {receipt['kind']} · status: **{receipt['status']}**")
    for st in receipt["stages"]:
        seat = st.get("seat") or {}
        label = f"{seat.get('vendor')}:{seat.get('model')}" if seat else "-"
        cv = "" if st.get("cross_vendor") is None else f" · cross_vendor={st['cross_vendor']}"
        cost = f" · cost_usd={st['cost_usd']:.4f}" if isinstance(st.get("cost_usd"), (int, float)) else ""
        lines.append(f"- {st['role']}: {label} · {st['status']}{cv}{cost} · sha256 {str(st.get('sha256') or '')[:16]} · `{st.get('output_path')}`")
    lines.append(f"- critic verdict: **{receipt.get('critic_verdict')}** · findings: {receipt.get('finding_counts')}")
    for b in receipt.get("input_bindings") or []:
        lines.append(f"- input: `{b.get('path')}` exists={b.get('exists')} sha256 {str(b.get('sha256') or '')[:16]}")
    lines.append(f"- generated_at_utc: {receipt['generated_at_utc']} · receipt: `{receipt.get('receipt_path')}`")
    return "\n".join(lines) + "\n"


def run_chain(
    spec: dict[str, Any],
    *,
    apply: bool,
    cfg: dict[str, Any] | None = None,
    environ: dict[str, str] | None = None,
    gate: GateFn | None = None,
) -> dict[str, Any]:
    cfg = cfg or load_config()
    env = os.environ if environ is None else environ
    gate = gate or (lambda vendor: vendor_gate(vendor, cfg, env))
    limits = cfg.get("limits") or {}
    paths = cfg.get("paths") or {}
    chain_id = str(spec.get("chain_id") or f"{utc_stamp()}_{sha256_text(json.dumps(spec, sort_keys=True))[:8]}")
    out_dir = Path(spec.get("out_dir") or (Path(str(paths.get("artifact_root"))) / chain_id))
    receipt_root = Path(str(paths.get("receipt_root")))
    timeout = int(spec.get("timeout_seconds") or limits.get("stage_timeout_seconds") or 900)
    language = str(spec.get("language") or "English")
    max_rounds = max(1, int(spec.get("max_rounds") or limits.get("max_rounds") or 1))
    existing = spec.get("existing_artifact") or None
    cwd = Path(spec.get("cwd") or REPO_ROOT)
    add_dirs = [Path(p) for p in (spec.get("critic_add_dirs") or [])]

    receipt: dict[str, Any] = {
        "schema": RECEIPT_SCHEMA,
        "chain_id": chain_id,
        "kind": str(spec.get("kind") or "run"),
        "task_id": spec.get("task_id"),
        "apply": bool(apply),
        "generated_at_utc": utc_iso(),
        "out_dir": str(out_dir),
        "spec_sha256": sha256_text(json.dumps(spec, sort_keys=True, ensure_ascii=False)),
        "kill_switch": kill_switch_active(env),
        "fake_mode": fake_mode(env),
        "stages": [],
        "seat_trace": {},
        "status": "planned",
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    _write_json(out_dir / "chain_spec.json", spec)

    # ---- seat resolution (no tokens spent)
    creator_seat: Seat | None = None
    creator_vendor = "unknown"
    try:
        if existing:
            creator_vendor = normalize_vendor(existing.get("vendor"))
            receipt["seat_trace"]["creator"] = [{"reused_artifact": existing.get("path"), "vendor": creator_vendor,
                                                 "model": existing.get("model")}]
        else:
            creator_seat, trace = resolve_creator(spec, cfg, gate)
            creator_vendor = creator_seat.vendor
            receipt["seat_trace"]["creator"] = trace
        critic_candidates, trace = open_critic_seats(creator_vendor, cfg, gate,
                                                      allow_agy=bool(spec.get("allow_agy", True)))
        if not critic_candidates:
            raise ChainGated(f"no critic seat available for creator vendor {creator_vendor!r}: {trace}")
        critic_seat, cross_vendor = critic_candidates[0]
        receipt["seat_trace"]["critic"] = trace
        formatter_seat, trace = resolve_formatter(cfg, gate)
        receipt["seat_trace"]["formatter"] = trace
    except ChainGated as exc:
        receipt["status"] = "gated"
        receipt["reason"] = str(exc)
        receipt["receipt_path"] = str(receipt_root / f"{chain_id}.json")
        _write_json(out_dir / "chain_receipt.json", receipt)
        _write_json(receipt_root / f"{chain_id}.json", receipt)
        return receipt

    receipt["plan"] = {
        "creator": (creator_seat.as_dict() if creator_seat else {"reused": True, "vendor": creator_vendor}),
        "critic": {**critic_seat.as_dict(), "cross_vendor": cross_vendor},
        "formatter": formatter_seat.as_dict(),
        "max_rounds": max_rounds,
        "timeout_seconds": timeout,
    }
    inputs_text, input_bindings = inline_inputs(list(spec.get("input_paths") or []),
                                                dict(spec.get("input_texts") or {}), cfg)
    receipt["input_bindings"] = input_bindings
    if not apply:
        receipt["status"] = "dry_run"
        _write_json(out_dir / "chain_plan.json", receipt)
        return receipt

    # ---- stage 1: creator (or the delivered artifact)
    task = str(spec.get("task") or "")
    if existing:
        art_path = Path(str(existing.get("path") or ""))
        text = str(existing.get("text") or "")
        if not text and art_path.exists():
            text = art_path.read_text(encoding="utf-8", errors="replace")
        stage1 = _stage_from("creator", None, {"status": "reused" if text else "error", "text": text,
                                                  "reason": "" if text else "artifact_missing"},
                             out_dir, "stage1_creator")
        stage1.seat = {"vendor": creator_vendor, "model": existing.get("model"), "reused_artifact": str(art_path)}
    else:
        prompt = render("creator", {"task": task, "language": language, "inputs": inputs_text})
        result = run_seat(creator_seat, "creator", prompt, cfg=cfg, out_dir=out_dir, stage_name="stage1_creator",
                          cwd=cwd, add_dirs=add_dirs, timeout=timeout, environ=environ)
        stage1 = _stage_from("creator", creator_seat, result, out_dir, "stage1_creator")
    receipt["stages"].append(stage1.as_dict())
    if stage1.status not in {"ok", "reused"}:
        receipt["status"] = "error"
        receipt["reason"] = f"creator_{stage1.status}:{stage1.reason}"
        receipt["receipt_path"] = str(receipt_root / f"{chain_id}.json")
        _write_json(out_dir / "chain_receipt.json", receipt)
        _write_json(receipt_root / f"{chain_id}.json", receipt)
        return receipt

    # ---- stage 2 (+ bounded revision rounds)
    creator_text = stage1.text
    critic_data: dict[str, Any] | None = None
    verdict = "UNPARSED"
    stage2: StageResult | None = None
    fallback_used = False
    for round_no in range(1, max_rounds + 1):
        critic_inputs = f"### Stage 1 output (creator {creator_vendor})\n\n{creator_text}\n\n### Original inputs\n\n{inputs_text}"
        prompt = render("critic", {
            "task": task, "inputs": critic_inputs,
            "creator_vendor": creator_vendor,
            "creator_model": str((stage1.seat or {}).get("model") or "unknown"),
        })
        # A critic that returns nothing parseable (timeout, empty answer, no JSON block) is replaced by the
        # next open seat ONCE (live finding 2026-09-15: agy print-timeout after 15 min left no answer file).
        attempt_seats = [(critic_seat, cross_vendor)] + [c for c in critic_candidates[1:2]]
        for attempt, (seat_try, cross_try) in enumerate(attempt_seats):
            stage_name = ("stage2_critic" if round_no == 1 else f"stage2_critic_round{round_no}") + ("" if attempt == 0 else f"_fallback{attempt}")
            result = run_seat(seat_try, "critic", prompt, cfg=cfg, out_dir=out_dir, stage_name=stage_name,
                              cwd=cwd, add_dirs=add_dirs, timeout=timeout, environ=environ)
            stage2 = _stage_from("critic", seat_try, result, out_dir, stage_name, cross_vendor=cross_try)
            critic_data = parse_critic_json(stage2.text) if stage2.status == "ok" else None
            if stage2.status == "ok" and critic_data is None:
                stage2.status = "unparsed"
                stage2.reason = "critic_json_missing"
            receipt["stages"].append(stage2.as_dict())
            if critic_data is not None:
                _write_json(out_dir / f"{stage_name}.json", critic_data)
                if attempt > 0:
                    fallback_used = True
                    critic_seat, cross_vendor = seat_try, cross_try
                break
        verdict = critic_verdict(critic_data)
        if stage2 is None or stage2.status != "ok" or verdict in {"PASS", "UNPARSED"} or existing or round_no == max_rounds:
            break
        # revision: the creator gets the findings and revises (AutoGen-style, bounded)
        revise_task = (
            f"{task}\n\nREVISION ROUND {round_no}: a cross-vendor auditor returned verdict {verdict} with these findings. "
            f"Revise your output so every blocking/major finding is closed with evidence, or state explicitly why a finding "
            f"is wrong (quote the source).\n\n{stage2.text}"
        )
        prompt = render("creator", {"task": revise_task, "language": language, "inputs": inputs_text})
        result = run_seat(creator_seat, "creator", prompt, cfg=cfg, out_dir=out_dir,
                          stage_name=f"stage1_creator_round{round_no + 1}", cwd=cwd, add_dirs=add_dirs,
                          timeout=timeout, environ=environ)
        revised = _stage_from("creator", creator_seat, result, out_dir, f"stage1_creator_round{round_no + 1}")
        receipt["stages"].append(revised.as_dict())
        if revised.status != "ok":
            break
        creator_text = revised.text

    counts: dict[str, int] = {}
    for f in (critic_data or {}).get("findings", []):
        if isinstance(f, dict):
            sev = str(f.get("severity", "unknown")).lower()
            counts[sev] = counts.get(sev, 0) + 1
    receipt["critic_verdict"] = verdict
    receipt["finding_counts"] = counts
    receipt["critic_fallback_used"] = fallback_used
    receipt["critic_seat_final"] = critic_seat.as_dict()
    receipt["scope_drift"] = (critic_data or {}).get("scope_drift")

    # ---- stage 3: formatter
    if stage2 is not None and stage2.status == "ok":
        prompt = render("formatter", {
            "language": language, "creator_vendor": creator_vendor, "critic_vendor": critic_seat.vendor,
            "creator_output": creator_text, "critic_output": stage2.text,
        })
        result = run_seat(formatter_seat, "formatter", prompt, cfg=cfg, out_dir=out_dir, stage_name="stage3_final",
                          cwd=cwd, add_dirs=[], timeout=timeout, environ=environ)
        stage3 = _stage_from("formatter", formatter_seat, result, out_dir, "stage3_final")
        receipt["stages"].append(stage3.as_dict())
    else:
        stage3 = StageResult(role="formatter", seat=formatter_seat.as_dict(), status="skipped",
                             reason="critic_stage_failed")
        receipt["stages"].append(stage3.as_dict())

    # An unparsed critic attempt that a fallback seat superseded does not degrade the chain.
    statuses = [s["status"] for s in receipt["stages"] if not (s["role"] == "critic" and s["status"] == "unparsed" and critic_data is not None)]
    if all(s in {"ok", "reused"} for s in statuses) and critic_data is not None:
        receipt["status"] = "ok"
    elif stage2 is not None and stage2.status == "ok":
        receipt["status"] = "partial"
    else:
        receipt["status"] = "error"
        receipt["reason"] = f"critic_{stage2.status if stage2 else 'missing'}:{stage2.reason if stage2 else ''}"
    receipt["receipt_path"] = str(receipt_root / f"{chain_id}.json")
    receipt["final_path"] = str(out_dir / "final.md")

    final_text = stage3.text if stage3.status == "ok" else (
        f"## A. Zusammenfassung\n\n(formatter {stage3.status}: {stage3.reason})\n\n{creator_text}\n\n"
        f"## B. Identifizierte Lücken & Handlungsbedarf\n\n{(stage2.text if stage2 else '')}\n"
    )
    _write_text(out_dir / "final.md", final_text.rstrip() + "\n" + _bindings_section(receipt))
    _write_json(out_dir / "chain_receipt.json", receipt)
    _write_json(receipt_root / f"{chain_id}.json", receipt)
    if receipt.get("task_id"):
        _write_json(receipt_root / "tasks" / f"{receipt['task_id']}.json", receipt)
    return receipt


# --------------------------------------------------------------------------- critique (agent_tasks REVIEW rows)

def _connect_ro(db_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{Path(db_path).as_posix()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def infer_executor(row: sqlite3.Row | dict[str, Any], cfg: dict[str, Any]) -> dict[str, Any]:
    """Which lane/model produced this delivery: assigned_agent first, then payload, then lane logs."""
    assigned = normalize_vendor(row["assigned_agent"] if "assigned_agent" in row.keys() else None)  # type: ignore[union-attr]
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except (ValueError, TypeError):
        payload = {}
    model = None
    if assigned == "claude":
        model = payload.get("claude_headless_model") or "sonnet"
    elif assigned == "codex":
        model = payload.get("codex_model_tier") or payload.get("model_tier") or "sol"
    if assigned != "unknown":
        return {"vendor": assigned, "model": model, "source": "assigned_agent"}
    bound = normalize_vendor(payload.get("decision_bound_agent"))
    if bound != "unknown":
        return {"vendor": bound, "model": model, "source": "decision_bound_agent"}
    log_dir = Path(str((cfg.get("paths") or {}).get("lane_log_dir") or ""))
    task_id = str(row["id"])
    if log_dir.exists():
        try:
            created = dt.datetime.fromisoformat(str(row["created_at"]).replace("Z", "+00:00"))
        except (ValueError, TypeError):
            created = None
        candidates = sorted(log_dir.glob("*_orchestration_slot*"), key=lambda p: p.stat().st_mtime, reverse=True)
        for path in candidates[:120]:
            if created is not None and dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc) < created:
                continue
            try:
                if task_id in path.read_text(encoding="utf-8", errors="ignore"):
                    vendor = normalize_vendor(path.name.split("_", 1)[0])
                    return {"vendor": vendor, "model": None, "source": f"lane_log:{path.name}"}
            except OSError:
                continue
    return {"vendor": "unknown", "model": None, "source": "unresolved"}


def build_critique_spec(task_id: str, cfg: dict[str, Any], conn: sqlite3.Connection,
                        *, allow_agy: bool = True, language: str | None = None) -> dict[str, Any]:
    row = conn.execute(
        "SELECT id, task_type, state, priority, assigned_agent, artifact_path, verdict, payload_json, created_at, updated_at "
        "FROM agent_tasks WHERE id = ? OR id LIKE ?", (task_id, f"{task_id}%")
    ).fetchone()
    if row is None:
        raise ChainError(f"agent task not found: {task_id}")
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except (ValueError, TypeError):
        payload = {}
    executor = infer_executor(row, cfg)
    artifact = str(row["artifact_path"] or "").strip()
    art_path = Path(artifact) if artifact else None
    if art_path is not None and not art_path.is_absolute():
        art_path = REPO_ROOT / art_path
    title = str(payload.get("title") or "")[:600]
    acceptance = payload.get("acceptance") or payload.get("acceptance_criteria") or []
    hard_limits = payload.get("hard_limits") or []
    task_text = (
        f"Audit the REVIEW delivery of agent task `{row['id']}` (type {row['task_type']}, priority {row['priority']}, "
        f"executed by lane {executor['vendor']} model {executor.get('model') or 'unknown'}).\n\n"
        f"Ticket title: {title}\n\nThe lane reports this verdict: {str(row['verdict'] or '')[:1200]}\n\n"
        f"Acceptance criteria the delivery must meet:\n" + "\n".join(f"- {a}" for a in acceptance) +
        "\n\nHard limits the delivery must respect:\n" + "\n".join(f"- {h}" for h in hard_limits)
    )
    add_dirs = [REPO_ROOT]
    if art_path is not None and art_path.exists():
        add_dirs.append(art_path.parent)
    return {
        "kind": "critique",
        "chain_id": f"critique_{str(row['id'])[:8]}_{utc_stamp()}",
        "task_id": str(row["id"]),
        "task": task_text,
        "language": language or "German for the prose; keep paths, identifiers and quoted evidence verbatim",
        "input_paths": [],
        "input_texts": {
            "task_payload (title, why_now, acceptance, hard_limits, evidence)": json.dumps(
                {k: payload.get(k) for k in ("title", "why_now", "acceptance", "acceptance_criteria", "hard_limits",
                                              "evidence", "evidence_paths") if payload.get(k)},
                indent=2, ensure_ascii=False),
            "lane_verdict": str(row["verdict"] or ""),
        },
        "existing_artifact": {
            "vendor": executor["vendor"], "model": executor.get("model"),
            "path": str(art_path) if art_path else "", "executor_source": executor["source"],
        },
        "critic_add_dirs": [str(p) for p in add_dirs],
        "allow_agy": bool(allow_agy),
        "max_rounds": 1,
    }


def pending_review_tasks(cfg: dict[str, Any], conn: sqlite3.Connection, *, limit: int) -> list[sqlite3.Row]:
    crit = cfg.get("critique") or {}
    states = list(crit.get("task_states") or ["REVIEW"])
    skip_types = set(crit.get("skip_task_types") or [])
    receipt_root = Path(str((cfg.get("paths") or {}).get("receipt_root")))
    rows = conn.execute(
        f"SELECT id, task_type, state, priority, assigned_agent, artifact_path, verdict, payload_json, created_at, updated_at "
        f"FROM agent_tasks WHERE state IN ({','.join('?' * len(states))}) ORDER BY priority DESC, updated_at ASC",
        states,
    ).fetchall()
    out: list[sqlite3.Row] = []
    for row in rows:
        if row["task_type"] in skip_types:
            continue
        if (receipt_root / "tasks" / f"{row['id']}.json").exists():
            continue
        out.append(row)
        if len(out) >= limit:
            break
    return out


# --------------------------------------------------------------------------- CLI

def _print(data: Any) -> None:
    print(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True, default=str))


def _summary(receipt: dict[str, Any]) -> dict[str, Any]:
    return {
        "chain_id": receipt.get("chain_id"), "status": receipt.get("status"), "reason": receipt.get("reason"),
        "task_id": receipt.get("task_id"), "critic_verdict": receipt.get("critic_verdict"),
        "finding_counts": receipt.get("finding_counts"), "plan": receipt.get("plan"),
        "seat_trace": receipt.get("seat_trace"), "final_path": receipt.get("final_path"),
        "out_dir": receipt.get("out_dir"),
        "stages": [{k: v for k, v in s.items() if k in ("role", "status", "seat", "cross_vendor", "cost_usd", "duration_s", "reason")}
                   for s in receipt.get("stages", [])],
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--config", type=Path, default=CONFIG_PATH)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_run = sub.add_parser("run", help="full chain over a spec JSON (dry run unless --apply)")
    p_run.add_argument("--spec", type=Path, required=True)
    p_run.add_argument("--apply", action="store_true")
    p_cr = sub.add_parser("critique", help="chain over one agent_tasks REVIEW delivery")
    p_cr.add_argument("--task-id", required=True)
    p_cr.add_argument("--apply", action="store_true")
    p_cr.add_argument("--no-agy", action="store_true", help="never route the critic to Antigravity")
    p_cr.add_argument("--language", default=None)
    p_pend = sub.add_parser("critique-pending", help="bounded sweep over REVIEW rows without a receipt")
    p_pend.add_argument("--apply", action="store_true")
    p_pend.add_argument("--max", type=int, default=None)
    p_pend.add_argument("--no-agy", action="store_true")
    p_st = sub.add_parser("status", help="list the latest receipts")
    p_st.add_argument("--limit", type=int, default=10)
    args = ap.parse_args(argv)
    cfg = load_config(args.config)
    paths = cfg.get("paths") or {}

    if args.cmd == "run":
        spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
        receipt = run_chain(spec, apply=bool(args.apply), cfg=cfg)
        _print(_summary(receipt))
        return 0 if receipt.get("status") in {"ok", "dry_run"} else 1

    if args.cmd in {"critique", "critique-pending"}:
        conn = _connect_ro(Path(str(paths.get("farm_db"))))
        try:
            if args.cmd == "critique":
                spec = build_critique_spec(args.task_id, cfg, conn, allow_agy=not args.no_agy, language=args.language)
                receipt = run_chain(spec, apply=bool(args.apply), cfg=cfg)
                _print(_summary(receipt))
                return 0 if receipt.get("status") in {"ok", "dry_run"} else 1
            limit = int(args.max or (cfg.get("limits") or {}).get("critique_pending_max") or 2)
            rows = pending_review_tasks(cfg, conn, limit=limit)
            results = []
            for row in rows:
                spec = build_critique_spec(str(row["id"]), cfg, conn, allow_agy=not args.no_agy)
                receipt = run_chain(spec, apply=bool(args.apply), cfg=cfg)
                results.append(_summary(receipt))
            _print({"pending_considered": len(rows), "apply": bool(args.apply), "results": results})
            return 0
        finally:
            conn.close()

    if args.cmd == "status":
        root = Path(str(paths.get("receipt_root")))
        files = sorted(root.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[: args.limit] if root.exists() else []
        rows = []
        for f in files:
            try:
                r = json.loads(f.read_text(encoding="utf-8"))
            except ValueError:
                continue
            rows.append({k: r.get(k) for k in ("chain_id", "kind", "task_id", "status", "critic_verdict", "finding_counts", "generated_at_utc")})
        _print(rows)
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
