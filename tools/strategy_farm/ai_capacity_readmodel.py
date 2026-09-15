"""AI factory capacity & routing read-model (``qm.ai-capacity/v1``).

Deterministically composes ``D:/QM/reports/state/ai_capacity.json`` from
**read-only** inputs so Mission Control, the vault ``AI Factory Capacity &
Routing`` page and the 15-minute book-evolution state build can all read one
authoritative provider-capacity surface instead of re-deriving it from raw
governor state.

Directive basis: OWNER follow-up 2026-09-15 (third; ``OWNER-DEC-D3-20260915``)
§2 (maximize the whole factory, not individual providers), §8 (AI capacity has a
shadow price), §9 (quota pacing uses all available capacity — re-measure now),
§10 (cross-provider review uses spare capacity), §36 (the AI Factory Capacity &
Routing vault page must distinguish CONTRACT from CURRENT RUNTIME STATE), §43A
(re-measure AI capacity), §13 (record the NO-VPS-UPGRADE OWNER decision — carried
by the decision record, not this read-model).

This read-model is the CURRENT-RUNTIME-STATE half. The CONTRACT half (allowed
capabilities, routing/pacing/review policy, the never-granted list) is the
hand-written section of ``docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md`` and the
vault page — never generated.

Read-only inputs (never opened writable, no process started):
  * ``agent_router.DEFAULT_AGENT_REGISTRY`` + ``TASK_TYPE_CAPABILITIES`` — the
    contract capabilities, enabled flag, cost_rank and max_parallel per lane.
  * ``config/agent_chain.v1.json`` — per-vendor model/tier ids and the
    cross-vendor critic table (independent-review availability).
  * ``config/agent_quota_gate.v1.json`` — Codex model tiers and Claude models.
  * ``D:/QM/reports/state/`` governor/quota state files
    (``quota_governor_state.json``, ``codex_budget_line.json``, ``agy_quota.json``,
    ``agy_governor_state.json``, ``kimi_governor_state.json``,
    ``kimi_quota_state.json``) + ``quota_governor.log`` / ``agy_governor.log``
    for the best-effort burn rate.
  * ``D:/QM/strategy_farm/*.flag`` — quota + burn flags (presence + expiry).
  * ``D:/QM/strategy_farm/state/agent_chain/tasks/*.json`` — critic-chain
    receipts, for fleet review independence (``same_vendor_share``).

Determinism: all *content* is a pure function of the inputs. The only
wall-clock value is ``generated_at_utc`` and the ``hours_to_reset`` / age
classifications, which take a single injectable ``now`` (tests pass a fixed
``now`` for byte-identical output). Missing inputs are explicit
(``EVIDENCE_MISSING`` / ``UNKNOWN`` / ``NOT_EVALUATED``), never zero-forged.

Shadow price (§8) — documented formula, see ``compute_shadow_prices``::

    sustainable_burn_pct_per_hour = remaining_pct / max(hours_to_reset, EPS)
    fleet_median = median(sustainable_burn_pct_per_hour over providers that have
                          a measurable quota AND are auth_ok)
    shadow_price = fleet_median / max(sustainable_burn_pct_per_hour, EPS)

  shadow_price > 1  -> scarcer than the fleet median: expensive to spend, prefer
                       offloading its work to a cheaper provider.
  shadow_price ~ 1  -> at the fleet median.
  shadow_price < 1  -> more spare capacity per remaining hour than the median: a
                       good offload TARGET.
  Providers with no measurable quota get shadow_price ``NOT_EVALUATED``.

CLI::

    python tools/strategy_farm/ai_capacity_readmodel.py build
    python tools/strategy_farm/ai_capacity_readmodel.py build --stdout
    python tools/strategy_farm/ai_capacity_readmodel.py render   # refresh md runtime blocks
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import re
import statistics
from pathlib import Path
from typing import Any

try:  # package import (normal) / direct-script fallback
    from tools.strategy_farm import agent_router  # type: ignore
except ModuleNotFoundError:  # pragma: no cover - direct execution
    import agent_router  # type: ignore

SCHEMA_VERSION = "qm.ai-capacity/v1"

# --- canonical paths (module-level so tests can monkeypatch) ---
FARM_ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_STATE = Path(r"D:\QM\reports\state")
CONFIG_DIR = Path(__file__).with_name("config")
FLAG_DIR = FARM_ROOT
AGENT_CHAIN_RECEIPT_DIR = FARM_ROOT / "state" / "agent_chain" / "tasks"
OUTPUT_PATH = REPORTS_STATE / "ai_capacity.json"

QUOTA_GOVERNOR_STATE = REPORTS_STATE / "quota_governor_state.json"
QUOTA_GOVERNOR_LOG = REPORTS_STATE / "quota_governor.log"
CODEX_BUDGET_LINE = REPORTS_STATE / "codex_budget_line.json"
AGY_QUOTA = REPORTS_STATE / "agy_quota.json"
AGY_GOVERNOR_STATE = REPORTS_STATE / "agy_governor_state.json"
AGY_GOVERNOR_LOG = REPORTS_STATE / "agy_governor.log"
KIMI_GOVERNOR_STATE = REPORTS_STATE / "kimi_governor_state.json"
KIMI_QUOTA_STATE = REPORTS_STATE / "kimi_quota_state.json"

AGENT_CHAIN_CONFIG = CONFIG_DIR / "agent_chain.v1.json"
AGENT_QUOTA_GATE_CONFIG = CONFIG_DIR / "agent_quota_gate.v1.json"

# Documentation runtime-block markers (idempotent replace).
BLOCK_BEGIN = "<!-- BEGIN GENERATED ai-capacity (qm.ai-capacity/v1) -->"
BLOCK_END = "<!-- END GENERATED ai-capacity -->"

DOCS_PAGE = Path(__file__).resolve().parents[2] / "docs" / "ops" / "AI_FACTORY_CAPACITY_AND_ROUTING.md"
VAULT_PAGE = Path(r"G:\My Drive\QuantMechanica - Company Reference\02 Org\AI Factory Capacity & Routing.md")

# Provider -> router lane. ``gemini`` is the router lane name that executes via the
# agy CLI (CLAUDE.md); the human ``owner`` lane is reported but has no quota.
PROVIDER_LANES = {
    "claude": "claude",
    "codex": "codex",
    "agy": "gemini",
    "kimi": "kimi",
    "owner": "owner",
}

QUOTA_FLAGS = {
    "claude": "CLAUDE_DISABLED.flag",
    "codex": "CODEX_LOW_TOKENS.flag",
    "agy": "AGY_LOW_QUOTA.flag",
    "kimi": "KIMI_LOW_QUOTA.flag",
}
BURN_FLAGS = {
    "claude": "CLAUDE_BURN_AUTHORIZED.flag",
    "codex": "CODEX_BURN_AUTHORIZED.flag",
}

# Shadow-price arithmetic guards + offload thresholds.
_EPS = 1e-6
SHADOW_PRICE_CAP = 9999.0       # readability clamp for a fully-exhausted provider (remaining≈0)
SATURATED_SHADOW_PRICE = 1.5    # >= this = scarce enough to look for an offload target
SPARE_SHADOW_PRICE = 0.67       # <= this = spare per remaining hour (fast-recovering window)
# Absolute-headroom fallbacks so a provider is judged spare/saturated on total
# remaining budget too, not only the per-hour rate — a long reset window (e.g.
# Kimi's 7-day rolling budget) otherwise dilutes a genuinely near-empty-usage
# provider below the spare bar (directive §8: "Kimi largely unused -> route to Kimi").
SPARE_REMAINING_PCT = 50.0      # >= this remaining AND routable = spare regardless of window
SATURATED_REMAINING_PCT = 25.0  # <= this remaining = saturated regardless of window
# Capabilities whose offload requires a NEW scoped grant (directive §5) and is
# therefore benchmark-gated (slice b1). Everything else the spare provider already
# holds in-contract, so the offload is immediately actionable once auth is up.
EXPANSION_CAPABILITIES = frozenset({"code", "tests", "repo_edit", "repo", "ops", "scalpel_mechanization"})


# --------------------------------------------------------------------------- utils
def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(when: dt.datetime | None) -> str | None:
    if when is None:
        return None
    if when.tzinfo is None:
        when = when.replace(tzinfo=dt.timezone.utc)
    return when.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _parse_ts(value: Any) -> dt.datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        try:
            return dt.datetime.fromtimestamp(float(value), dt.timezone.utc)
        except (OverflowError, OSError, ValueError):
            return None
    s = str(value).strip()
    if not s:
        return None
    try:
        x = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
        return x if x.tzinfo else x.replace(tzinfo=dt.timezone.utc)
    except ValueError:
        return None


def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        obj = json.loads(Path(path).read_text(encoding="utf-8"))
        return obj if isinstance(obj, dict) else None
    except (OSError, json.JSONDecodeError):
        return None


def _hours_to(reset: dt.datetime | None, now: dt.datetime) -> float | None:
    if reset is None:
        return None
    return round((reset - now).total_seconds() / 3600.0, 2)


# --------------------------------------------------------------------------- flags
def _flag_info(provider: str, *, now: dt.datetime) -> dict[str, Any]:
    name = QUOTA_FLAGS.get(provider)
    out: dict[str, Any] = {"gate_flag": name, "gate_flag_on": False, "burn_authorized": False}
    if name:
        p = FLAG_DIR / name
        out["gate_flag_on"] = p.exists()
    bname = BURN_FLAGS.get(provider)
    if bname:
        bp = FLAG_DIR / bname
        if bp.exists():
            expires = None
            try:
                for line in bp.read_text(encoding="utf-8", errors="replace").splitlines():
                    if line.lower().startswith("expires_at="):
                        expires = _parse_ts(line.split("=", 1)[1])
                        break
            except OSError:
                expires = None
            out["burn_flag"] = bname
            out["burn_flag_expires_utc"] = _iso(expires)
            out["burn_authorized"] = bool(expires and expires > now)
    return out


# --------------------------------------------------------------------------- models / tiers
def _models_for(provider: str) -> list[dict[str, Any]]:
    """Model/tier ids from agent_chain.v1.json + agent_quota_gate.v1.json."""
    chain = _read_json(AGENT_CHAIN_CONFIG) or {}
    vendors = chain.get("vendors") or {}
    out: list[dict[str, Any]] = []
    seen: set[str] = set()

    def add(model_id: str, *, tier: str | None = None, role: str | None = None) -> None:
        key = f"{tier or ''}:{model_id}"
        if not model_id or key in seen:
            return
        seen.add(key)
        entry: dict[str, Any] = {"model": model_id}
        if tier:
            entry["tier"] = tier
        if role:
            entry["role"] = role
        out.append(entry)

    if provider == "codex":
        gate = _read_json(AGENT_QUOTA_GATE_CONFIG) or {}
        tiers = (((gate.get("model_matrix") or {}).get("codex") or {}).get("tiers")) or {}
        for tname, t in tiers.items():
            add(str(t.get("model") or tname), tier=tname, role=t.get("role"))
        # agent_chain critic tiers (may name a subset) as a cross-check.
        for tname, mid in ((vendors.get("codex") or {}).get("tiers") or {}).items():
            add(str(mid), tier=tname)
    elif provider == "claude":
        gate = _read_json(AGENT_QUOTA_GATE_CONFIG) or {}
        cl = (gate.get("model_matrix") or {}).get("claude") or {}
        for m in cl.get("allowed_models") or []:
            add(str(m), tier=m)
        for tname, mid in ((vendors.get("claude") or {}).get("models") or {}).items():
            add(str(mid or tname), tier=tname)
    else:
        vkey = provider  # agy / kimi
        for tname, mid in ((vendors.get(vkey) or {}).get("models") or {}).items():
            add(str(mid or tname), tier=tname)
    return out


# --------------------------------------------------------------------------- quota per provider
def _quota_for(provider: str, *, now: dt.datetime,
               gov_agents: dict[str, Any], gov_ts: str | None,
               agy_q: dict[str, Any], kimi_gov: dict[str, Any]) -> dict[str, Any] | None:
    if provider in ("claude", "codex"):
        m = gov_agents.get(provider) or {}
        used = m.get("used_pct")
        if used is None:
            return {"window": "weekly", "used_pct": None, "remaining_pct": None,
                    "reset_utc": None, "hours_to_reset": None,
                    "source": "quota_governor_state.json", "measured_at_utc": gov_ts,
                    "status": "EVIDENCE_MISSING"}
        reset = _parse_ts(m.get("week_reset"))
        q = {
            "window": "weekly",
            "used_pct": round(float(used), 2),
            "remaining_pct": round(100.0 - float(used), 2),
            "reset_utc": _iso(reset),
            "hours_to_reset": _hours_to(reset, now),
            "five_hour_used_pct": m.get("five_hour_used_pct"),
            "elapsed_pct": m.get("elapsed_pct"),
            "projected_eow_pct": m.get("projected_eow_pct"),
            "source": "quota_governor_state.json (quota_pull.py vendor usage endpoint)",
            "measured_at_utc": gov_ts,
        }
        return q
    if provider == "agy":
        if not agy_q:
            return {"window": "rolling", "remaining_pct": None, "source": "agy_quota.json",
                    "measured_at_utc": None, "status": "EVIDENCE_MISSING"}
        rem = agy_q.get("binding_remaining_pct")
        reset = _parse_ts(agy_q.get("binding_reset"))
        return {
            "window": "rolling_binding",
            "used_pct": None if rem is None else round(100.0 - float(rem), 2),
            "remaining_pct": None if rem is None else round(float(rem), 2),
            "reset_utc": _iso(reset),
            "hours_to_reset": _hours_to(reset, now),
            "source": "agy_quota.json (Gemini Code Assist usage API)",
            "measured_at_utc": agy_q.get("checked_at"),
        }
    if provider == "kimi":
        rq = (kimi_gov.get("real_quota") or {}) if kimi_gov else {}
        d7 = rq.get("rolling_7d") or {}
        d5 = rq.get("rolling_5h") or {}
        used_ratio = d7.get("used_ratio")
        reset = _parse_ts(d7.get("reset_at"))
        if used_ratio is None:
            return {"window": "rolling_7d", "remaining_pct": None,
                    "source": "kimi_governor_state.json", "measured_at_utc": kimi_gov.get("computed_at"),
                    "status": "EVIDENCE_MISSING" if not rq else "UNKNOWN"}
        return {
            "window": "rolling_7d",
            "used_pct": round(float(used_ratio) * 100.0, 2),
            "remaining_pct": round((1.0 - float(used_ratio)) * 100.0, 2),
            "reset_utc": _iso(reset),
            "hours_to_reset": _hours_to(reset, now),
            "rolling_5h_used_pct": None if d5.get("used_ratio") is None else round(float(d5["used_ratio"]) * 100.0, 2),
            "call_counts": kimi_gov.get("counts"),
            "runaway_guard": kimi_gov.get("runaway_guard") or kimi_gov.get("caps"),
            "source": "kimi_governor_state.json (managed usage endpoint)",
            "measured_at_utc": rq.get("source_timestamp") or kimi_gov.get("computed_at"),
        }
    return None  # owner (human lane) has no quota


# --------------------------------------------------------------------------- burn rate
_LOG_LINE = re.compile(
    r"^(?P<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\s+(?P<agent>\w+):\s+used=(?P<used>[\d.]+)%")


def _burn_rate_from_log(log_path: Path, agent_key: str) -> dict[str, Any]:
    """Best-effort %-used-per-hour from the last two same-agent governor log samples."""
    try:
        lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return {"value": "NOT_EVALUATED", "reason": "log_missing"}
    samples: list[tuple[dt.datetime, float]] = []
    for line in lines:
        m = _LOG_LINE.match(line.strip())
        if not m or m.group("agent") != agent_key:
            continue
        ts = _parse_ts(m.group("ts"))
        if ts is None:
            continue
        samples.append((ts, float(m.group("used"))))
    if len(samples) < 2:
        return {"value": "NOT_EVALUATED", "reason": "insufficient_samples"}
    (t0, u0), (t1, u1) = samples[-2], samples[-1]
    dh = (t1 - t0).total_seconds() / 3600.0
    if dh <= 0:
        return {"value": "NOT_EVALUATED", "reason": "non_monotonic_time"}
    if u1 < u0:
        return {"value": "NOT_EVALUATED", "reason": "reset_crossed", "delta_pct": round(u1 - u0, 2)}
    return {
        "value": round((u1 - u0) / dh, 3),
        "unit": "pct_per_hour",
        "window": {"from_utc": _iso(t0), "to_utc": _iso(t1), "hours": round(dh, 3)},
    }


# --------------------------------------------------------------------------- review independence
def _critic_seat_vendors(chain_cfg: dict[str, Any]) -> dict[str, set[str]]:
    """Vendor -> set of creator-vendors it is listed as a cross-vendor critic for."""
    out: dict[str, set[str]] = {}
    table = (((chain_cfg.get("roles") or {}).get("critic") or {}).get("by_creator_vendor")) or {}
    for creator, seats in table.items():
        if creator == "unknown":  # pseudo-creator (default table), not a real provider
            continue
        for seat in seats or []:
            v = agent_router_normalize(seat.get("vendor"))
            if v and v != creator:
                out.setdefault(v, set()).add(creator)
    return out


def agent_router_normalize(value: str | None) -> str | None:
    if not value:
        return None
    aliases = {"gemini": "agy", "antigravity": "agy", "anthropic": "claude", "openai": "codex"}
    v = str(value).strip().lower()
    return aliases.get(v, v)


def _review_independence(receipt_dir: Path, *, recent_limit: int = 12) -> dict[str, Any]:
    files = sorted(glob.glob(str(Path(receipt_dir) / "*.json")))
    if not files:
        return {"present": False, "degraded_reason": "EVIDENCE_MISSING", "receipt_dir": str(receipt_dir)}
    completed = cross_false = fallback = 0
    recent: list[dict[str, Any]] = []
    for f in files:
        r = _read_json(Path(f))
        if not r:
            continue
        plan_critic = (r.get("plan") or {}).get("critic") or {}
        critic_stages = [s for s in (r.get("stages") or []) if s.get("role") == "critic"]
        cross_vendor = None
        for s in critic_stages:
            if s.get("cross_vendor") is not None:
                cross_vendor = s.get("cross_vendor")
        if cross_vendor is None:
            cross_vendor = plan_critic.get("cross_vendor")
        fb = bool(r.get("critic_fallback_used"))
        is_completed = r.get("status") in {"ok", "partial"} and bool(critic_stages)
        if is_completed:
            completed += 1
            if cross_vendor is False:
                cross_false += 1
            if fb:
                fallback += 1
        recent.append({
            "chain_id": r.get("chain_id"),
            "creator_vendor": ((r.get("plan") or {}).get("creator") or {}).get("vendor"),
            "critic_vendor": (r.get("critic_seat_final") or plan_critic or {}).get("vendor"),
            "cross_vendor": cross_vendor,
            "critic_fallback_used": fb,
            "generated_at_utc": r.get("generated_at_utc"),
        })
    recent.sort(key=lambda x: (x.get("generated_at_utc") or ""), reverse=True)
    return {
        "present": True,
        "receipt_dir": str(receipt_dir),
        "receipts_considered": len(files),
        "completed": completed,
        "cross_vendor_false": cross_false,
        "same_vendor_share": round(cross_false / completed, 3) if completed else None,
        "critic_fallback_used": fallback,
        "independence_degraded": completed > 0 and cross_false > 0,
        "recent": recent[:recent_limit],
    }


# --------------------------------------------------------------------------- shadow price
def compute_shadow_prices(providers: list[dict[str, Any]]) -> float | None:
    """Attach ``shadow_price`` + ``sustainable_burn_pct_per_hour`` in place.

    Returns the fleet-median sustainable burn (or ``None`` if no measurable
    provider). See module docstring for the documented formula.
    """
    rates: dict[str, float] = {}
    for p in providers:
        q = p.get("quota") or {}
        rem = q.get("remaining_pct")
        htr = q.get("hours_to_reset")
        if not p.get("auth_ok") or rem is None or htr is None:
            p["sustainable_burn_pct_per_hour"] = "NOT_EVALUATED"
            continue
        rate = float(rem) / max(float(htr), _EPS)
        rates[p["provider"]] = rate
        p["sustainable_burn_pct_per_hour"] = round(rate, 4)
    if not rates:
        for p in providers:
            p.setdefault("shadow_price", "NOT_EVALUATED")
        return None
    median = statistics.median(rates.values())
    for p in providers:
        rate = rates.get(p["provider"])
        if rate is None:
            p["shadow_price"] = "NOT_EVALUATED"
            continue
        p["shadow_price"] = round(min(median / max(rate, _EPS), SHADOW_PRICE_CAP), 3)
    return round(median, 4)


# --------------------------------------------------------------------------- offload
def _offload_opportunities(providers: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Saturated provider + spare qualified provider pairs, by capability.

    A saturated provider (shadow_price >= SATURATED_SHADOW_PRICE, or gated) that
    holds a capability is paired with every spare provider (shadow_price <=
    SPARE_SHADOW_PRICE, auth_ok, routable) that also holds it. Expansion
    capabilities (§5) are benchmark-gated (slice b1 scorecard); in-contract
    capabilities the spare provider already holds are immediately actionable.
    """
    by_name = {p["provider"]: p for p in providers}

    def sp(p: dict[str, Any]) -> float | None:
        v = p.get("shadow_price")
        return v if isinstance(v, (int, float)) else None

    def _rem(p: dict[str, Any]) -> float | None:
        v = (p.get("quota") or {}).get("remaining_pct")
        return v if isinstance(v, (int, float)) else None

    def is_saturated(p: dict[str, Any]) -> bool:
        s = sp(p)
        rem = _rem(p)
        return (bool(p.get("pacing_gated"))
                or (s is not None and s >= SATURATED_SHADOW_PRICE)
                or (rem is not None and rem <= SATURATED_REMAINING_PCT))

    def is_spare(p: dict[str, Any]) -> bool:
        if not p.get("routable_now"):
            return False
        s = sp(p)
        rem = _rem(p)
        return ((s is not None and s <= SPARE_SHADOW_PRICE)
                or (rem is not None and rem >= SPARE_REMAINING_PCT))

    out: list[dict[str, Any]] = []
    for sat in providers:
        if sat["provider"] == "owner" or not is_saturated(sat):
            continue
        sat_caps = set(sat.get("contract_capabilities") or [])
        for cap in sorted(sat_caps):
            spares = [
                q["provider"] for q in providers
                if q["provider"] != sat["provider"] and q["provider"] != "owner"
                and cap in set(q.get("contract_capabilities") or []) and is_spare(q)
            ]
            # Also surface an EXPANSION offload: a spare provider that does NOT
            # yet hold the capability but could be granted it after benchmarking.
            expansion_targets = []
            if cap in EXPANSION_CAPABILITIES:
                expansion_targets = [
                    q["provider"] for q in providers
                    if q["provider"] not in (sat["provider"], "owner")
                    and cap not in set(q.get("contract_capabilities") or [])
                    and is_spare(q)
                ]
            if not spares and not expansion_targets:
                continue
            out.append({
                "capability": cap,
                "saturated_provider": sat["provider"],
                "saturated_shadow_price": sat.get("shadow_price"),
                "spare_in_contract": spares,
                "spare_needs_grant": expansion_targets,
                "benchmark_gated": bool(cap in EXPANSION_CAPABILITIES or expansion_targets),
                "actionable_now": bool(spares) and cap not in EXPANSION_CAPABILITIES,
                "status": (
                    "AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)"
                    if (cap in EXPANSION_CAPABILITIES or expansion_targets)
                    else "ACTIONABLE (spare provider already holds this capability in-contract)"
                ),
            })
    return out


# --------------------------------------------------------------------------- build
def build_ai_capacity(*, now: dt.datetime | None = None,
                      receipt_dir: Path | None = None) -> dict[str, Any]:
    now = now or _now_utc()
    receipt_dir = receipt_dir or AGENT_CHAIN_RECEIPT_DIR

    registry = agent_router.DEFAULT_AGENT_REGISTRY
    task_caps = getattr(agent_router, "TASK_TYPE_CAPABILITIES", {})
    chain_cfg = _read_json(AGENT_CHAIN_CONFIG) or {}
    critic_vendors = _critic_seat_vendors(chain_cfg)

    gov = _read_json(QUOTA_GOVERNOR_STATE) or {}
    gov_agents = gov.get("agents") or {}
    gov_ts = gov.get("ts")
    budget = _read_json(CODEX_BUDGET_LINE) or {}
    agy_q = _read_json(AGY_QUOTA) or {}
    agy_gov = _read_json(AGY_GOVERNOR_STATE) or {}
    kimi_gov = _read_json(KIMI_GOVERNOR_STATE) or {}

    providers: list[dict[str, Any]] = []
    for provider, lane in PROVIDER_LANES.items():
        reg = registry.get(lane) or {}
        flags = _flag_info(provider, now=now)
        quota = _quota_for(provider, now=now, gov_agents=gov_agents, gov_ts=gov_ts,
                           agy_q=agy_q, kimi_gov=kimi_gov)

        # auth_ok per provider from the authoritative source.
        if provider in ("claude", "codex"):
            auth_ok = bool((gov_agents.get(provider) or {}).get("used_pct") is not None)
        elif provider == "agy":
            auth_ok = bool(agy_q.get("ok")) and not bool(agy_q.get("token_expired"))
        elif provider == "kimi":
            auth_ok = (kimi_gov.get("quota_fetch_status") == "ok")
        else:  # owner
            auth_ok = "N/A"

        # pacing state / gated
        pacing_gated = bool(flags.get("gate_flag_on"))
        if provider == "kimi":
            pacing_state = kimi_gov.get("state") or "UNKNOWN"
            pacing_gated = pacing_state == "EXHAUSTED" or pacing_gated
        elif provider == "codex":
            pacing_state = "THROTTLED" if pacing_gated else "NORMAL"
        elif provider == "claude":
            pacing_state = "THROTTLED_HEADLESS_LANE" if pacing_gated else "NORMAL"
        elif provider == "agy":
            pacing_state = "GATED" if pacing_gated else "NORMAL"
        else:
            pacing_state = "HUMAN_LANE_DISABLED"

        enabled = bool(reg.get("enabled", False))
        routable_now = bool(enabled and (auth_ok is True) and not pacing_gated)

        # burn rate (best-effort, from governor logs)
        if provider in ("claude", "codex"):
            burn = _burn_rate_from_log(QUOTA_GOVERNOR_LOG, provider)
        else:
            burn = {"value": "NOT_EVALUATED", "reason": "no_periodic_used_pct_log"}

        indep = (auth_ok is True) and routable_now and (provider in critic_vendors)

        prov: dict[str, Any] = {
            "provider": provider,
            "lane": lane,
            "models": _models_for(provider),
            "contract_capabilities": list(reg.get("capabilities") or []),
            "cost_rank": reg.get("cost_rank"),
            "max_parallel": reg.get("max_parallel"),
            "enabled": enabled,
            "auth_ok": auth_ok,
            "routable_now": routable_now,
            "quota": quota,
            "burn_rate_per_hour": burn,
            "pacing_state": pacing_state,
            "pacing_gated": pacing_gated,
            "flags": flags,
            "independent_review_available": indep,
            "critic_for_creators": sorted(critic_vendors.get(provider, set())) or None,
            "last_benchmark_utc": "EVIDENCE_MISSING",
            "last_benchmark_note": "AI_CAPABILITY_SCORECARD not yet produced (slice b1 AI_CAPABILITY_BENCHMARK_2026-09).",
        }
        if provider == "codex" and budget:
            prov["budget_line"] = {
                "anchor_used": budget.get("anchor_used"),
                "target_at_reset": budget.get("target_at_reset"),
                "reset_ts": budget.get("reset_ts"),
            }
        if provider == "agy":
            prov["cli_auth_note"] = (
                "agy_quota.json reflects the Gemini Code Assist usage API; the headless "
                "'agy -p' research-lane CLI auth is a separate path — verify with a cheap "
                "probe and record HTTP class in the ops report, not this generator.")
        if provider == "owner":
            prov["note"] = ("human lane, declared-but-disabled (enabled:false, max_parallel:0); "
                            "video_analysis held as awaiting_human_lane:owner. No quota.")
        providers.append(prov)

    fleet_median = compute_shadow_prices(providers)
    offloads = _offload_opportunities(providers)
    review = _review_independence(receipt_dir)

    return {
        "schema": SCHEMA_VERSION,
        "generated_at_utc": _iso(now),
        "decision_basis": "OWNER-DEC-D3-20260915 (§2/§8/§9/§10/§36/§43A)",
        "providers": providers,
        "fleet": {
            "shadow_price_formula": (
                "sustainable_burn_pct_per_hour = remaining_pct / max(hours_to_reset, eps); "
                "fleet_median = median over auth_ok providers with a measurable quota; "
                "shadow_price = fleet_median / max(sustainable_burn_pct_per_hour, eps). "
                ">1 scarce (offload its work away), <1 spare (good offload target)."),
            "fleet_median_sustainable_burn_pct_per_hour": fleet_median,
            "saturated_shadow_price_threshold": SATURATED_SHADOW_PRICE,
            "spare_shadow_price_threshold": SPARE_SHADOW_PRICE,
            "offload_opportunities": offloads,
            "review_independence": review,
        },
        "notes": [
            "CURRENT RUNTIME STATE half of docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md + the "
            "vault page '02 Org/AI Factory Capacity & Routing.md'. The CONTRACT half is hand-written.",
            "Re-measure only via the authoritative governors (quota_governor.py, agy_governor.py, "
            "kimi_governor.py evaluate); never hand-delete a quota flag — the owning governor clears it.",
            "last_benchmark_utc=EVIDENCE_MISSING until slice b1 lands the AI_CAPABILITY_SCORECARD.",
        ],
        "task_type_capabilities": {k: list(v) for k, v in task_caps.items()},
    }


# --------------------------------------------------------------------------- markdown render
def _fmt_pct(v: Any) -> str:
    return f"{v:g}%" if isinstance(v, (int, float)) else str(v)


def render_runtime_markdown(state: dict[str, Any]) -> str:
    """Render the CURRENT-RUNTIME-STATE block from an ai_capacity.json object."""
    lines: list[str] = []
    lines.append(BLOCK_BEGIN)
    lines.append("")
    lines.append(f"_Generated `{state.get('generated_at_utc')}` from `{OUTPUT_PATH.as_posix()}` "
                 f"(schema `{state.get('schema')}`). Regenerated by "
                 f"`tools/strategy_farm/ai_capacity_readmodel.py render`; do not hand-edit inside "
                 f"the markers._")
    lines.append("")
    lines.append("| Provider | Lane | Enabled | Auth | Routable | Window | Used | Remaining | h→reset | Pacing | Shadow price | Indep. review |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for p in state.get("providers", []):
        q = p.get("quota") or {}
        lines.append(
            f"| {p['provider']} | {p.get('lane')} | {p.get('enabled')} | {p.get('auth_ok')} | "
            f"{p.get('routable_now')} | {q.get('window', '—')} | {_fmt_pct(q.get('used_pct'))} | "
            f"{_fmt_pct(q.get('remaining_pct'))} | {q.get('hours_to_reset', '—')} | "
            f"{p.get('pacing_state')} | {p.get('shadow_price')} | {p.get('independent_review_available')} |")
    lines.append("")
    fleet = state.get("fleet") or {}
    lines.append(f"Fleet median sustainable burn: "
                 f"`{fleet.get('fleet_median_sustainable_burn_pct_per_hour')}` %/h. "
                 f"Shadow-price formula: {fleet.get('shadow_price_formula')}")
    lines.append("")
    offloads = fleet.get("offload_opportunities") or []
    lines.append(f"**Offload opportunities ({len(offloads)}):**")
    if not offloads:
        lines.append("- none at this measurement.")
    for o in offloads:
        tgt = o.get("spare_in_contract") or o.get("spare_needs_grant") or []
        lines.append(f"- `{o.get('capability')}`: saturated **{o.get('saturated_provider')}** "
                     f"→ spare {tgt} — {o.get('status')}")
    lines.append("")
    rev = fleet.get("review_independence") or {}
    if rev.get("present"):
        lines.append(f"Review independence: {rev.get('completed')} completed chains, "
                     f"same_vendor_share=`{rev.get('same_vendor_share')}`, "
                     f"degraded=`{rev.get('independence_degraded')}`.")
    else:
        lines.append(f"Review independence: `{rev.get('degraded_reason', 'EVIDENCE_MISSING')}`.")
    lines.append("")
    lines.append(BLOCK_END)
    return "\n".join(lines)


def update_marked_block(path: Path, block: str) -> dict[str, Any]:
    """Idempotently replace the region between BLOCK_BEGIN..BLOCK_END in ``path``.

    If the file lacks the markers, the block is appended under a runtime heading.
    Returns {"path", "changed", "created"}.
    """
    path = Path(path)
    created = not path.exists()
    old = "" if created else path.read_text(encoding="utf-8")
    if BLOCK_BEGIN in old and BLOCK_END in old:
        pre = old.split(BLOCK_BEGIN, 1)[0]
        post = old.split(BLOCK_END, 1)[1]
        new = pre + block + post
    elif created:
        new = block + "\n"
    else:
        sep = "" if old.endswith("\n") else "\n"
        new = old + sep + "\n" + block + "\n"
    changed = new != old
    if changed:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(new, encoding="utf-8")
    return {"path": str(path), "changed": changed, "created": created}


# --------------------------------------------------------------------------- CLI
def _write_output(state: dict[str, Any]) -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(state, indent=2), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("command", nargs="?", default="build", choices=["build", "render"])
    ap.add_argument("--stdout", action="store_true", help="print the JSON, do not write the file")
    ap.add_argument("--no-render", action="store_true", help="build only, skip the markdown runtime blocks")
    ap.add_argument("--docs-page", default=str(DOCS_PAGE))
    ap.add_argument("--vault-page", default=str(VAULT_PAGE))
    args = ap.parse_args(argv)

    if args.command == "render":
        state = _read_json(OUTPUT_PATH)
        if not state:
            print(f"ERROR: {OUTPUT_PATH} missing — run 'build' first")
            return 1
    else:
        state = build_ai_capacity()
        if args.stdout:
            print(json.dumps(state, indent=2))
            return 0
        _write_output(state)
        print(f"wrote {OUTPUT_PATH} ({len(state.get('providers', []))} providers)")

    if args.no_render:
        return 0
    block = render_runtime_markdown(state)
    for target in (args.docs_page, args.vault_page):
        try:
            res = update_marked_block(Path(target), block)
            print(f"render {res['path']}: changed={res['changed']} created={res['created']}")
        except OSError as exc:
            print(f"render {target}: SKIPPED ({exc})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
