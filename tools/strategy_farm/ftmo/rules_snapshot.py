"""Official FTMO rule snapshot: freshness tracking, read-only refresh, rebind.

Directive 2026-09-15 section 63 (OWNER-DEC-CBE-20260915): before any paid
recommendation, major FTMO book rule change, or operational deployment, verify
the current official FTMO rules and track source timestamp/freshness. A snapshot
older than the readiness-blocker age must surface as a readiness blocker.

This module is read-only against the network (GET only, injectable fetcher) and
never mutates gate thresholds. `refresh` writes a new dated snapshot when a live
fetch succeeds and otherwise falls back to the latest snapshot on disk, always
recording an explicit fetch_status. Rebinding updates only the snapshot pointer,
sha256, and freshness metadata in the rulepack - never a go-criterion value.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Callable

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.strategy_farm.ftmo import policy_config

REPO_ROOT = Path(__file__).resolve().parents[3]
EVIDENCE_DIR = REPO_ROOT / "docs" / "ops" / "evidence"
SNAPSHOT_GLOB = "*_ftmo_official_rules_snapshot.json"
DEFAULT_RULEPACK = (
    REPO_ROOT
    / "tools"
    / "strategy_farm"
    / "config"
    / "target_rulepacks"
    / "FTMO_2S_100K_STANDARD_V2.json"
)

# Official Standard-profile sources verified read-only on 2026-09-15.
OFFICIAL_SOURCES = {
    "ftmo_trading_objectives_official": "https://ftmo.com/en/trading-objectives/",
    "ftmo_account_specifications_faq": "https://ftmo.com/en/faq/what-are-the-account-specifications/",
    "ftmo_instruments_strategies_faq": "https://ftmo.com/en/faq/which-instruments-can-i-trade-and-what-strategies-am-i-allowed-to-use/",
}


def _now(now: dt.datetime | None = None) -> dt.datetime:
    return now or dt.datetime.now(dt.timezone.utc)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def latest_snapshot_path(evidence_dir: Path = EVIDENCE_DIR) -> Path | None:
    """Return the newest official-rules snapshot by retrieved_at_utc, else None."""
    candidates = sorted(Path(evidence_dir).glob(SNAPSHOT_GLOB))
    if not candidates:
        return None

    def _key(p: Path) -> str:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            return str(data.get("retrieved_at_utc") or data.get("fetched_utc") or "")
        except (OSError, json.JSONDecodeError):
            return ""

    return max(candidates, key=lambda p: (_key(p), p.name))


def load_latest_snapshot(evidence_dir: Path = EVIDENCE_DIR) -> dict[str, Any] | None:
    path = latest_snapshot_path(evidence_dir)
    if path is None:
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    data.setdefault("_snapshot_path", str(path))
    return data


def snapshot_datetime(snapshot: dict[str, Any]) -> dt.datetime | None:
    raw = snapshot.get("retrieved_at_utc") or snapshot.get("fetched_utc")
    if not raw:
        return None
    try:
        return dt.datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
    except ValueError:
        return None


def freshness_days(snapshot: dict[str, Any], now: dt.datetime | None = None) -> float | None:
    taken = snapshot_datetime(snapshot)
    if taken is None:
        return None
    if taken.tzinfo is None:
        taken = taken.replace(tzinfo=dt.timezone.utc)
    delta = _now(now) - taken
    return round(delta.total_seconds() / 86400.0, 3)


def freshness_blocker(
    snapshot: dict[str, Any] | None,
    now: dt.datetime | None = None,
    *,
    blocker_age_days: int = policy_config.RULE_SNAPSHOT_BLOCKER_AGE_DAYS,
    warn_age_days: int = policy_config.RULE_SNAPSHOT_MAX_AGE_DAYS,
) -> dict[str, Any]:
    """Classify snapshot freshness into a deterministic readiness signal.

    Returns a dict with `blocker` (bool), `severity` (OK|WARN|BLOCKER|UNKNOWN),
    `freshness_days`, and a human `reason`. A missing snapshot is a BLOCKER.
    """
    if snapshot is None:
        return {
            "blocker": True,
            "severity": "BLOCKER",
            "freshness_days": "EVIDENCE_MISSING",
            "reason": "No official FTMO rule snapshot on disk.",
        }
    age = freshness_days(snapshot, now)
    if age is None:
        return {
            "blocker": True,
            "severity": "UNKNOWN",
            "freshness_days": "UNKNOWN",
            "reason": "Snapshot has no parseable retrieved_at_utc.",
        }
    if age > blocker_age_days:
        return {
            "blocker": True,
            "severity": "BLOCKER",
            "freshness_days": age,
            "reason": f"Rule snapshot is {age:.1f} days old (> {blocker_age_days}d blocker).",
        }
    if age > warn_age_days:
        return {
            "blocker": False,
            "severity": "WARN",
            "freshness_days": age,
            "reason": f"Rule snapshot is {age:.1f} days old (> {warn_age_days}d go-criterion); "
            "refresh before a paid decision.",
        }
    return {
        "blocker": False,
        "severity": "OK",
        "freshness_days": age,
        "reason": f"Rule snapshot is {age:.1f} days old (within {warn_age_days}d).",
    }


def _urllib_fetch(url: str, timeout: float = 12.0) -> tuple[int | None, str, str]:
    """Read-only GET. Returns (http_status, body, fetch_status). Never raises."""
    import urllib.error
    import urllib.request

    req = urllib.request.Request(url, method="GET", headers={"User-Agent": "QM-rule-verify/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310 (GET only, official host)
            body = resp.read().decode("utf-8", errors="replace")
            return resp.status, body, "OK"
    except urllib.error.HTTPError as exc:
        return exc.code, "", f"HTTP_{exc.code}"
    except Exception as exc:  # pragma: no cover - network failure path
        return None, "", f"BLOCKED:{type(exc).__name__}"


def fetch_current_rules(
    sources: dict[str, str] = OFFICIAL_SOURCES,
    fetcher: Callable[[str], tuple[int | None, str, str]] = _urllib_fetch,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Attempt a read-only fetch of every official source.

    Returns {'fetched_utc', 'sources': {id: {url, http_status, fetch_status}},
    'any_ok': bool}. Bodies are not retained here (normalization stays a manual,
    reviewed step so nothing silently rewrites the bound §63 fields).
    """
    ts = _now(now).strftime("%Y-%m-%dT%H:%M:%SZ")
    results: dict[str, Any] = {}
    any_ok = False
    for source_id, url in sources.items():
        status, _body, fetch_status = fetcher(url)
        results[source_id] = {
            "url": url,
            "http_status": status,
            "fetch_status": fetch_status,
            "fetched_utc": ts,
        }
        if fetch_status == "OK":
            any_ok = True
    return {"fetched_utc": ts, "sources": results, "any_ok": any_ok}


def rebind_rulepack(
    rulepack_path: Path,
    snapshot_path: Path,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Point a rulepack at `snapshot_path` and record freshness.

    Format-preserving: only the snapshot pointer values (path, sha256,
    retrieved_at_utc) shared by the official_sources entries, the top-level
    `as_of`, and the `rule_snapshot_binding` block are rewritten. Go-criteria
    thresholds and every other field keep their exact text (RED boundary,
    focused diff). Returns the binding block written.
    """
    import re

    rulepack_path = Path(rulepack_path)
    snapshot_path = Path(snapshot_path)
    text = rulepack_path.read_text(encoding="utf-8")
    data = json.loads(text)
    snap = json.loads(snapshot_path.read_text(encoding="utf-8"))
    sha = sha256_file(snapshot_path)
    retrieved = snap.get("retrieved_at_utc") or snap.get("fetched_utc")
    rel = snapshot_path.as_posix()
    if str(REPO_ROOT.as_posix()) in rel:
        rel = rel.split(str(REPO_ROOT.as_posix()) + "/", 1)[-1]

    # The official_sources entries all carry the same old pointer values; replace
    # those exact JSON string literals globally (safe within this file).
    sources = data.get("official_sources", [])
    old_paths = {e.get("snapshot_path") for e in sources if isinstance(e, dict) and e.get("snapshot_path")}
    old_shas = {e.get("snapshot_sha256") for e in sources if isinstance(e, dict) and e.get("snapshot_sha256")}
    old_retr = {e.get("retrieved_at_utc") for e in sources if isinstance(e, dict) and e.get("retrieved_at_utc")}
    for op in old_paths:
        text = text.replace(f'"{op}"', f'"{rel}"')
    for osha in old_shas:
        text = text.replace(f'"{osha}"', f'"{sha}"')
    for oretr in old_retr:
        text = text.replace(f'"{oretr}"', f'"{retrieved}"')

    # top-level as_of (first occurrence only).
    new_as_of = str(retrieved)[:10] if retrieved else data.get("as_of")
    text = re.sub(r'("as_of"\s*:\s*")[^"]*(")', rf'\g<1>{new_as_of}\g<2>', text, count=1)

    binding = {
        "bound_snapshot_path": rel,
        "bound_snapshot_sha256": sha,
        "bound_snapshot_retrieved_at_utc": retrieved,
        "rebound_at_utc": _now(now).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "freshness_max_age_days": policy_config.RULE_SNAPSHOT_MAX_AGE_DAYS,
        "readiness_blocker_age_days": policy_config.RULE_SNAPSHOT_BLOCKER_AGE_DAYS,
        "note": "Freshness tracking only; go-criteria thresholds unchanged (OWNER-only).",
    }
    binding_json = json.dumps(binding, indent=2, ensure_ascii=False)
    # indent the block to sit at top level (2 spaces) matching a 2-space file.
    binding_block = "\n".join(("  " + ln if ln.strip() else ln) for ln in binding_json.splitlines())

    if '"rule_snapshot_binding"' in text:
        text = re.sub(
            r'  "rule_snapshot_binding"\s*:\s*\{.*?\n  \}',
            f'  "rule_snapshot_binding": {binding_block.lstrip()}',
            text,
            flags=re.DOTALL,
        )
    else:
        # insert before the final top-level closing brace.
        idx = text.rstrip().rfind("}")
        head = text[:idx].rstrip()
        if not head.endswith(","):
            head += ","
        text = head + f'\n  "rule_snapshot_binding": {binding_block.lstrip()}\n}}\n'

    rulepack_path.write_text(text, encoding="utf-8")
    return binding


def refresh(
    evidence_dir: Path = EVIDENCE_DIR,
    rulepack_path: Path = DEFAULT_RULEPACK,
    *,
    fetcher: Callable[[str], tuple[int | None, str, str]] = _urllib_fetch,
    rebind: bool = True,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Verify freshness and rebind. Live-fetch is a connectivity probe only; the
    normalized §63 snapshot is authored/reviewed by hand, so `refresh` never
    silently overwrites the bound fields from a scraped body. When the network is
    blocked it falls back to the latest snapshot on disk (recorded explicitly).
    """
    probe = fetch_current_rules(fetcher=fetcher, now=now)
    snapshot = load_latest_snapshot(evidence_dir)
    fresh = freshness_blocker(snapshot, now)
    outcome = {
        "generated_at_utc": _now(now).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "fetch_probe": probe,
        "fetch_status": "LIVE_OK" if probe["any_ok"] else "FELL_BACK_TO_DISK",
        "latest_snapshot_path": snapshot.get("_snapshot_path") if snapshot else None,
        "freshness": fresh,
    }
    if rebind and snapshot is not None:
        outcome["rebind"] = rebind_rulepack(
            rulepack_path, Path(snapshot["_snapshot_path"]), now
        )
    return outcome


def _main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="FTMO official rule snapshot freshness/rebind")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_refresh = sub.add_parser("refresh", help="probe official sources, check freshness, rebind rulepack")
    p_refresh.add_argument("--rulepack", default=str(DEFAULT_RULEPACK))
    p_refresh.add_argument("--no-rebind", action="store_true")
    sub.add_parser("freshness", help="print freshness of the latest snapshot")
    args = parser.parse_args(argv)

    if args.cmd == "refresh":
        out = refresh(rulepack_path=Path(args.rulepack), rebind=not args.no_rebind)
    else:
        out = freshness_blocker(load_latest_snapshot())
    print(json.dumps(out, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
