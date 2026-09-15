#!/usr/bin/env python3
"""QuantMechanica - Kimi real quota / usage fetcher (OWNER-DEC-CBE-20260915 sec30-33).

A single read-only GET to the SAME managed usage endpoint the official Kimi Code
CLI usage panel calls - ``GET {base_url}/usages`` with an ``Authorization: Bearer
<oauth access_token>`` read at runtime from the credential file the CLI itself uses
(``C:/Users/Administrator/.kimi-code/credentials/kimi-code.json``). The result is
normalized into ``D:/QM/reports/state/kimi_quota_state.json`` with the directive
sec32 fields and consumed by ``kimi_governor.compute_state`` (real ratios drive
NORMAL/CONSERVE/EXHAUSTED; the local call caps become runaway guards only).

SECRET HYGIENE (directive sec32, mirrors kimi_adapter.py):
  * The OAuth ``access_token`` / ``refresh_token`` are read at runtime ONLY.
  * They are NEVER logged, printed, or written to the state file.
  * Debug output redacts the Authorization header to ``Bearer <redacted>``.
  * ``/me`` PII fields (email/phone/nickname/user_id/global_id/avatar) are
    discarded; only ``user_level_name``/``status``/``region`` are persisted.

FAIL-CLOSED (directive sec33, sec70 'Kimi real quota fetch failure falls back
safely'): every failure path returns a normalized state carrying ``fetch_status``
in {auth_error, network_error, schema_error, disabled}. The governor treats any
non-``ok`` status (or a stale ``ok`` state) as a signal to fall back to the local
ledger path and mark ``usage_source='local_ledger_fallback'``. No exception ever
escapes ``fetch``; the MT5 factory is never affected by a Kimi telemetry failure.

TOKEN REFRESH: the 15-min OAuth token is refreshed by the CLI only on a real
authenticated model call, which costs quota (live-verified 2026-09-15). Re-implementing
the OAuth grant is a documented non-goal (kimi_quota_discovery.md risk 6). So refresh
is best-effort and OFF by default (config ``refresh.via_cli``): a stale token with
refresh disabled -> ``fetch_status='auth_error'`` -> ledger fallback. In production the
frequent adapter research calls keep the token fresh for the governor's fetch.

  python -X utf8 tools/strategy_farm/kimi_quota_fetcher.py fetch
  python -X utf8 tools/strategy_farm/kimi_quota_fetcher.py fetch --print-redacted
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import socket
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

# --------------------------------------------------------------------------- config

CONFIG_PATH = Path(__file__).with_name("config") / "kimi_quota_fetcher.v1.json"
STATE_SCHEMA = "qm.kimi-quota/v1"
SOURCE_LABEL = "api.kimi.com/coding/v1/usages"

# fetch_status enum (directive sec32).
OK = "ok"
AUTH_ERROR = "auth_error"
NETWORK_ERROR = "network_error"
SCHEMA_ERROR = "schema_error"
DISABLED = "disabled"

# The credential-file field names we read (values are NEVER logged). Listed here so a
# reviewer can see exactly which fields are touched.
_TOKEN_FIELD = "access_token"
_EXPIRES_FIELD = "expires_at"

# /me fields we KEEP (everything else, incl. PII, is discarded).
_ME_KEEP = ("user_level_name", "status", "region")


def load_config(path: Path | str = CONFIG_PATH) -> dict[str, Any]:
    cfg = json.loads(Path(path).read_text(encoding="utf-8"))
    if cfg.get("schema") != "qm.kimi-quota-fetcher.v1":
        raise ValueError(f"unexpected kimi quota fetcher config schema: {cfg.get('schema')!r}")
    return cfg


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _utc_iso(ts: dt.datetime | None = None) -> str:
    return (ts or _now()).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _creationflags() -> int:
    return subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0  # type: ignore[attr-defined]


# --------------------------------------------------------------------------- secret hygiene


def redact_headers(headers: dict[str, str]) -> dict[str, str]:
    """Return a copy of ``headers`` safe to log: the Authorization value is masked so
    no token ever reaches a log line."""
    out = dict(headers)
    if "Authorization" in out:
        out["Authorization"] = "Bearer <redacted>"
    return out


def _base_url(cfg: dict[str, Any], env: dict[str, str]) -> str:
    override = env.get(str(cfg.get("base_url_env") or "")) if cfg.get("base_url_env") else None
    base = (override or cfg.get("base_url") or "https://api.kimi.com/coding/v1").strip()
    return base.rstrip("/")


# --------------------------------------------------------------------------- credential / token


def read_access_token(cred_path: Path | str, *, skew_s: int = 60,
                      now: dt.datetime | None = None) -> tuple[str | None, int, bool, str | None]:
    """Read the OAuth access token from the CLI's own credential file.

    Returns ``(token, expires_at_epoch, fresh, error)``. The token VALUE is returned
    for immediate in-process use only and is NEVER logged/printed/persisted. ``fresh``
    is True when the token has more than ``skew_s`` seconds of life left. On any read
    error, returns ``(None, 0, False, <class>)`` where class is a non-secret string.
    """
    path = Path(cred_path)
    if not path.exists():
        return None, 0, False, "credential_file_missing"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None, 0, False, "credential_unreadable"
    token = data.get(_TOKEN_FIELD)
    if not token:
        return None, 0, False, "no_access_token"
    exp_raw = data.get(_EXPIRES_FIELD, 0)
    try:
        exp = int(exp_raw)
    except (TypeError, ValueError):
        exp = 0
    # Tolerate epoch in milliseconds (the CLI writes seconds today; be defensive).
    if exp > 10 ** 11:
        exp = exp // 1000
    now_epoch = int((now or _now()).timestamp())
    fresh = (exp - now_epoch) > int(skew_s)
    return str(token), exp, fresh, None


def _refresh_via_cli(cfg: dict[str, Any], env: dict[str, str]) -> bool:
    """Best-effort token refresh by triggering the CLI's own ensureFresh via a real
    authenticated model call (spends quota). OFF by default (config refresh.via_cli).
    Never re-implements the OAuth grant. Returns True if the CLI ran with rc 0. Any
    failure is swallowed and reported False - the caller falls back."""
    rc_cfg = dict(cfg.get("refresh") or {})
    if not rc_cfg.get("via_cli"):
        return False
    bin_path = Path(str(cfg.get("kimi_bin") or ""))
    if not bin_path.exists():
        return False
    args = list(rc_cfg.get("cli_args") or ["-p", "Reply with the single word OK and nothing else."])
    timeout_s = int(rc_cfg.get("timeout_s", 120))
    try:
        proc = subprocess.run(
            [str(bin_path), *args],
            capture_output=True, text=True, timeout=timeout_s, env=env,
            creationflags=_creationflags(), stdin=subprocess.DEVNULL,
        )
        return proc.returncode == 0
    except Exception:
        return False


def _child_env(environ: dict[str, str] | None) -> dict[str, str]:
    """Ensure the OAuth credential resolves for a child CLI process (mirror
    kimi_adapter._child_env; a SYSTEM run would otherwise miss USERPROFILE/HOME)."""
    env = dict(os.environ if environ is None else environ)
    env["USERPROFILE"] = r"C:\Users\Administrator"
    env["HOME"] = r"C:\Users\Administrator"
    env["HOMEDRIVE"] = "C:"
    env["HOMEPATH"] = r"\Users\Administrator"
    return env


# --------------------------------------------------------------------------- HTTP


def _http_get_json(url: str, token: str, timeout_s: int) -> tuple[str, Any]:
    """Perform the single read-only GET. Returns ``(status, payload_or_detail)`` where
    status is one of ok/auth_error/network_error/schema_error. The token is used only
    to build the header and is never logged."""
    req = urllib.request.Request(
        url, headers={"Authorization": f"Bearer {token}", "Accept": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            raw = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            return AUTH_ERROR, f"http_{exc.code}"
        return NETWORK_ERROR, f"http_{exc.code}"
    except (urllib.error.URLError, socket.timeout, TimeoutError, ConnectionError) as exc:
        return NETWORK_ERROR, type(exc).__name__
    except Exception as exc:  # pragma: no cover - defensive
        return NETWORK_ERROR, type(exc).__name__
    try:
        payload = json.loads(raw)
    except ValueError:
        return SCHEMA_ERROR, "invalid_json"
    if not isinstance(payload, dict):
        return SCHEMA_ERROR, "payload_not_object"
    return OK, payload


# --------------------------------------------------------------------------- normalization


def _ratio(value: Any) -> float | None:
    """Coerce a used_ratio (may be int/float/str) to a float in [0, inf); None if absent."""
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _window(entry: Any) -> dict[str, Any] | None:
    """Map a ``usages`` entry {used_ratio, reset_time} to {used_ratio, reset_at}."""
    if not isinstance(entry, dict):
        return None
    return {"used_ratio": _ratio(entry.get("used_ratio")), "reset_at": entry.get("reset_time")}


def normalize(usages_payload: dict[str, Any] | None, me_plan: dict[str, Any] | None,
              cfg: dict[str, Any], *, fetch_status: str, error: str | None = None,
              now: dt.datetime | None = None) -> dict[str, Any]:
    """Build the normalized quota state (directive sec32 fields). Tolerant of the live
    schema (5h/7d present; monthly/booster may be absent on a low-usage account) and of
    any failure path (usages_payload=None -> null windows, fetch_status carries why)."""
    now = now or _now()
    period = dict(cfg.get("subscription_period") or {})

    monthly: dict[str, Any] | None = None
    rolling_5h: dict[str, Any] | None = None
    rolling_7d: dict[str, Any] | None = None
    breakdown: dict[str, Any] | None = None
    extra_quota_active = False
    observed_keys: list[str] = []

    if isinstance(usages_payload, dict):
        observed_keys = sorted(usages_payload.keys())
        usages = usages_payload.get("usages")
        if isinstance(usages, dict):
            rolling_5h = _window(usages.get("limit_5h"))
            rolling_7d = _window(usages.get("limit_7d"))
            monthly = _window(usages.get("limit_month_total"))
            # Kimi-vs-Code monthly breakdown, if the account exposes it.
            month_total = _ratio((usages.get("limit_month_total") or {}).get("used_ratio")) \
                if isinstance(usages.get("limit_month_total"), dict) else None
            month_code = _ratio((usages.get("limit_month_code") or {}).get("used_ratio")) \
                if isinstance(usages.get("limit_month_code"), dict) else None
            if month_total is not None and month_code is not None:
                breakdown = {"kimi_ratio": max(0.0, month_total - month_code),
                             "code_ratio": month_code}
        booster = usages_payload.get("boosterWallet")
        extra_quota_active = bool(booster)

    plan = None
    plan_status = None
    plan_region = None
    if isinstance(me_plan, dict):
        plan = me_plan.get("user_level_name") or None
        plan_status = me_plan.get("status") or None
        plan_region = me_plan.get("region") or None

    return {
        "schema": STATE_SCHEMA,
        "fetch_status": fetch_status,
        "error": error,
        "source": SOURCE_LABEL,
        "source_timestamp": _utc_iso(now),
        "raw_schema_version": str(cfg.get("raw_schema_version") or "unknown"),
        "observed_top_keys": observed_keys,
        "plan": plan,
        "plan_status": plan_status,
        "plan_region": plan_region,
        "subscription_period": {"start": period.get("start"), "end": period.get("end")},
        "monthly": monthly,
        "rolling_5h": rolling_5h,
        "rolling_7d": rolling_7d,
        "breakdown": breakdown,
        "extra_quota_active": extra_quota_active,
    }


# --------------------------------------------------------------------------- state I/O


def write_state(state: dict[str, Any], state_path: Path | str) -> None:
    """Write the normalized state atomically. The state NEVER contains a token."""
    path = Path(state_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(state, indent=2), encoding="utf-8")
    tmp.replace(path)


def read_state(state_path: Path | str) -> dict[str, Any] | None:
    """Read the last normalized state, or None if absent/unreadable."""
    path = Path(state_path)
    if not path.exists():
        return None
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def is_fresh(state: dict[str, Any] | None, max_age_s: int, now: dt.datetime | None = None) -> bool:
    """True iff ``state`` is an ok fetch whose source_timestamp is within max_age_s."""
    if not isinstance(state, dict) or state.get("fetch_status") != OK:
        return False
    ts = state.get("source_timestamp")
    if not ts:
        return False
    try:
        parsed = dt.datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except ValueError:
        return False
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    age = ((now or _now()) - parsed).total_seconds()
    return 0 <= age <= int(max_age_s)


# --------------------------------------------------------------------------- fetch orchestration


def fetch(cfg: dict[str, Any] | None = None, *, env: dict[str, str] | None = None,
          now: dt.datetime | None = None, write: bool = True) -> dict[str, Any]:
    """Read the token, perform the single read-only GET, normalize, and (by default)
    persist. NEVER raises: every failure becomes a normalized state with a non-``ok``
    fetch_status so callers fall back safely (directive sec33/sec70).
    """
    cfg = cfg or load_config()
    environ = dict(os.environ if env is None else env)
    now = now or _now()

    def _finish(state: dict[str, Any]) -> dict[str, Any]:
        if write:
            try:
                write_state(state, cfg.get("state_path") or "D:/QM/reports/state/kimi_quota_state.json")
            except Exception:
                pass
        return state

    # Kill switch / disabled -> no network call.
    kill_env = str(cfg.get("kill_switch_env") or "")
    if not cfg.get("enabled", True) or (kill_env and environ.get(kill_env) == "0"):
        return _finish(normalize(None, None, cfg, fetch_status=DISABLED, error="disabled", now=now))

    skew_s = int(cfg.get("skew_s", 60))
    token, _exp, fresh, cred_err = read_access_token(
        cfg.get("credential_file") or "", skew_s=skew_s, now=now)
    if cred_err == "credential_file_missing":
        return _finish(normalize(None, None, cfg, fetch_status=DISABLED,
                                 error="credential_file_missing", now=now))
    if token is None:
        return _finish(normalize(None, None, cfg, fetch_status=AUTH_ERROR,
                                 error=cred_err or "no_token", now=now))

    # Stale token: best-effort refresh (OFF by default), then re-read.
    if not fresh:
        if _refresh_via_cli(cfg, _child_env(environ)):
            token, _exp, fresh, cred_err = read_access_token(
                cfg.get("credential_file") or "", skew_s=skew_s, now=now)
        if not fresh or token is None:
            # A guaranteed 401 - short-circuit to auth_error, no wasted request.
            return _finish(normalize(None, None, cfg, fetch_status=AUTH_ERROR,
                                     error="token_stale", now=now))

    base = _base_url(cfg, environ)
    endpoints = dict(cfg.get("endpoints") or {})
    timeout_s = int(cfg.get("timeout_s", 8))
    usages_url = base + str(endpoints.get("usages", "/usages"))

    status, payload = _http_get_json(usages_url, token, timeout_s)
    if status != OK:
        detail = payload if isinstance(payload, str) else None
        return _finish(normalize(None, None, cfg, fetch_status=status, error=detail, now=now))

    # Optional plan lookup; a /me failure must NOT downgrade a good usages fetch.
    me_plan: dict[str, Any] | None = None
    if cfg.get("fetch_me", True):
        me_status, me_payload = _http_get_json(
            base + str(endpoints.get("me", "/me")), token, timeout_s)
        if me_status == OK and isinstance(me_payload, dict):
            me_plan = {k: me_payload.get(k) for k in _ME_KEEP}

    return _finish(normalize(payload, me_plan, cfg, fetch_status=OK, now=now))


# --------------------------------------------------------------------------- CLI


def _print_redacted(state: dict[str, Any]) -> None:
    """Print the normalized state (ratios only). The state carries no token by
    construction; assert it as a defence-in-depth guard before printing."""
    dumped = json.dumps(state, indent=2)
    assert "access_token" not in dumped and "Bearer " not in dumped, "token leak guard"
    print(dumped)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("command", choices=["fetch", "show"], nargs="?", default="fetch")
    ap.add_argument("--config", default=str(CONFIG_PATH))
    ap.add_argument("--print-redacted", action="store_true",
                    help="print the normalized state (ratios only; never a token)")
    ap.add_argument("--no-write", action="store_true", help="do not persist the state file")
    args = ap.parse_args(argv)
    cfg = load_config(args.config)
    if args.command == "show":
        state = read_state(cfg.get("state_path") or "") or {"fetch_status": "absent"}
    else:
        state = fetch(cfg, write=not args.no_write)
    if args.print_redacted or args.command == "show":
        _print_redacted(state)
    else:
        print(json.dumps({"fetch_status": state.get("fetch_status"),
                          "source_timestamp": state.get("source_timestamp"),
                          "plan": state.get("plan")}, indent=2))
    return 0 if state.get("fetch_status") == OK else 1


if __name__ == "__main__":
    raise SystemExit(main())
