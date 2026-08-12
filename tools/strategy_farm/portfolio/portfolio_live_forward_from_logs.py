"""Live-vs-book comparator FROM the T_Live per-EA logs (not the shared q08 Common).

Why this exists
---------------
``portfolio_burnin.py`` was written to read ``QM/q08_trades/<ea>_<symbol>.jsonl`` streams.
Those streams are unusable for a running live book:
  * the EA only dumps them at ``OnDeinit`` (shutdown) with ``FILE_WRITE`` (overwrite), and
  * the path is ``FILE_COMMON`` — SHARED between T_Live and the T1-T10 factory, so a Q08
    backtest of the same (ea, symbol) overwrites any live dump. Empirically all live
    sleeves' q08 streams contain ONLY backtest trades (2017-2025), zero live trades.

The clean live source is the T_Live terminal's **per-EA log**
(``C:\\QM\\mt5\\T_Live\\MT5_Base\\MQL5\\Files\\QM\\QM5_<id>_*.log``): terminal-LOCAL (no
factory contamination), append-written, and it carries a daily ``EQUITY_SNAPSHOT`` event
(``AccountInfoDouble(ACCOUNT_EQUITY)`` = the whole live book / SUM of sleeves) plus trade
open/close events.

E4' repair (ULTRACODE 2026-07-26, Codex WS-E4 REJECT->repair)
-------------------------------------------------------------
The pre-repair comparator produced authoritative-looking but MIS-SCOPED evidence:
  1. it ingested EVERY QM5_*.log with no identity filter;
  2. it bucketed by ``day_key`` — which is ``QM_CalendarPeriodKey`` (the last completed
     D1 bar) and PINS over weekends, so it is NOT a wall-clock date and cannot be matched
     to a deployment epoch (a 07-19 go-live snapshot still carries day_key 20260717);
  3. it fell back to a PLACEHOLDER Monte-Carlo reference (the manifest's own weighted-avg,
     full-history mc_p95) and reported a green DD verdict against the wrong basis.

This module now enforces an explicit **sampling contract** before any divergence number
has meaning (Codex "missing item 11"):
  * bind ONE signed manifest by SHA256 + an explicit deployment epoch (parameter, never
    hard-coded);
  * filter ingested log events to EXACTLY the manifest's (ea_id, symbol, magic) identities;
  * match the observation window on ``ts_utc`` (the real wall-clock emission time), the
    manifest starting capital, the manifest per-sleeve risk weights, and a declared cost
    basis;
  * take the DD reference ONLY from a SUM-of-sleeves Monte-Carlo bound to this exact book
    (built from the actual sleeve streams, or a pre-built artifact carrying the matching
    book fingerprint) — NO placeholder;
  * any missing/mismatched input yields an ``UNKNOWN`` section and a non-green verdict,
    never a silent pass;
  * the report is written atomically (temp + os.replace) and idempotently.

Read-only. Never touches T_Live trading state. Evidence for OWNER only. Cadence stays
Sunday; promotion to daily / money-gate requires fixtures + read-only replay review + an
OWNER decision — not this module.
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import hashlib
import json
import os
import random
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable, Mapping, Optional

try:
    from . import portfolio_burnin as pb
except ImportError:  # pragma: no cover - direct execution
    import portfolio_burnin as pb  # type: ignore

# Stream + Monte-Carlo primitives are REUSED verbatim (no re-implementation) so the
# live-vs-book MC shares the exact arithmetic of make_live_burnin_mc_reference.py.
try:
    from .portfolio_common import load_streams, to_daily_pnl
    from .prop_challenge_sim import _block_bootstrap, _percentile, DEFAULT_BLOCK_DAYS
    from .commission import load_model
except ImportError:  # pragma: no cover - direct execution
    from portfolio_common import load_streams, to_daily_pnl  # type: ignore
    from prop_challenge_sim import _block_bootstrap, _percentile, DEFAULT_BLOCK_DAYS  # type: ignore
    from commission import load_model  # type: ignore

DEFAULT_TLIVE_LOG_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM")
TESTER_DEFAULTS = Path(r"C:\QM\repo\framework\registry\tester_defaults.json")
# Trade-activity events emitted by QM_TradeManager into the per-EA log.
OPEN_EVENTS = {"TM_OPEN", "ENTRY_ACCEPTED"}
CLOSE_EVENTS = {"TM_CLOSE"}
# Attachment/lifecycle events (OnInit success / OnDeinit) — INDEPENDENT of telemetry and
# activity. The comparator reports ATTACHMENT, TELEMETRY, and ACTIVITY as three separate
# per-sleeve states and never collapses them into one "heartbeat" (Codex WS-E4 round-2).
INIT_EVENTS = {"INIT_OK"}
DEINIT_EVENTS = {"DEINIT"}
# The only DD-reference basis this comparator will trust. Anything else -> UNKNOWN.
SUM_MC_BASIS_PREFIX = "sum_of_sleeves"
SUM_MC_BASIS = "sum_of_sleeves_manifest_riskpct_calendar_daily"
UNKNOWN = "UNKNOWN"
# Manifest statuses that can carry an OWNER signature/approval. A DRAFT is never signed.
APPROVED_MANIFEST_STATUSES = {"LIVE", "APPROVED", "SIGNED", "DEPLOYED"}


# --------------------------------------------------------------------------- #
# Manifest identity + binding
# --------------------------------------------------------------------------- #
def _manifest_sha256(path: Path) -> str:
    """SHA256 of the raw manifest bytes — the signed-manifest binding."""
    h = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def manifest_signature_status(manifest: Mapping[str, Any]) -> dict[str, Any]:
    """Classify a manifest as SIGNED / UNSIGNED / DRAFT for the deploy-stamp contract.

    Aligns with the wse2/wse3 deploy-stamp fields (``status`` + ``approved_by`` + file
    SHA + deployment epoch). Binding a manifest by SHA does NOT make it signed: a DRAFT,
    or a manifest with no approver/signature, is UNSIGNED. Only a manifest whose
    ``status`` is an approved live status AND that carries an explicit ``signed`` truthy
    flag OR a non-empty ``approved_by`` counts as SIGNED. The comparator refuses to read
    a binding/PASS verdict from an unsigned manifest (Codex WS-E4 round-2).
    """
    status = str(manifest.get("status") or "").strip().upper()
    approved_by = manifest.get("approved_by") or manifest.get("declared_approved_by")
    has_approver = bool(approved_by and str(approved_by).strip())
    signed_flag = manifest.get("signed")
    epoch_in_manifest = manifest.get("deployment_epoch")
    status_ok = status in APPROVED_MANIFEST_STATUSES
    if signed_flag is not None:
        signed = bool(signed_flag) and status_ok
    else:
        signed = status_ok and has_approver
    if signed:
        label = "SIGNED"
    elif status == "DRAFT":
        label = "DRAFT"
    else:
        label = "UNSIGNED"
    return {
        "signature_label": label,
        "signed": bool(signed),
        "manifest_status": status or None,
        "approved_by": approved_by,
        "has_approver": has_approver,
        "signed_flag_present": signed_flag is not None,
        "deployment_epoch_in_manifest": epoch_in_manifest,
        "criteria": (
            "SIGNED iff status in {LIVE,APPROVED,SIGNED,DEPLOYED} AND (signed=true OR "
            "approved_by present); a DRAFT bound only by SHA is NOT signed."
        ),
    }


def _base_symbol(symbol: str) -> str:
    """Broker-symbol form used in the live logs (manifest carries the .DWX custom form)."""
    return str(symbol).split(".", 1)[0].upper()


def _book_fingerprint(
    sleeves: list[dict[str, Any]],
    starting_capital: float,
    total_risk_pct: Any,
) -> str:
    """Stable hash over the exact deployed composition + weights.

    Binds a Monte-Carlo reference to the book it was built for. Two manifests with the
    same sleeves, magics, and per-sleeve risk map to the same fingerprint; any add/remove/
    re-weight changes it — so a stale reference can never be silently reused.
    """
    basis = {
        "sleeves": sorted(
            [
                [int(s["magic"]), int(s["ea_id"]), s["base_symbol"], round(float(s["risk_percent"]), 8)]
                for s in sleeves
            ]
        ),
        "starting_capital": round(float(starting_capital), 6),
        "total_risk_pct": None if total_risk_pct is None else round(float(total_risk_pct), 6),
    }
    payload = json.dumps(basis, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def manifest_identities(manifest: Mapping[str, Any], manifest_path: Path | None = None) -> dict[str, Any]:
    """Extract the exact (ea_id, symbol, magic, risk_percent) identity set from a manifest.

    The magic number is the tightest identity (it encodes ea_id*10000 + slot) and is the
    field every live log line carries, so it is the primary filter key.
    """
    sleeves: list[dict[str, Any]] = []
    for raw in manifest.get("sleeves") or []:
        ea_id = int(raw["ea_id"])
        symbol = str(raw["symbol"])
        magic = raw.get("magic_number")
        if magic is None:
            raise ValueError(f"manifest sleeve {ea_id}/{symbol} has no magic_number")
        magic = int(magic)
        risk_percent = float(raw.get("risk_percent", raw.get("weight", 0.0)))
        sleeves.append(
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "base_symbol": _base_symbol(symbol),
                "magic": magic,
                "risk_percent": risk_percent,
                "weight": float(raw.get("weight", 0.0)),
            }
        )
    if not sleeves:
        raise ValueError("manifest carries no sleeves; cannot bind live identities")

    magics = {s["magic"] for s in sleeves}
    if len(magics) != len(sleeves):
        raise ValueError("manifest has duplicate magic numbers; identity set is ambiguous")

    starting_capital = float(manifest.get("starting_capital", 100_000.0))
    total_risk_pct = manifest.get("total_risk_pct")
    return {
        "manifest_path": None if manifest_path is None else str(manifest_path),
        "manifest_sha256": None if manifest_path is None else _manifest_sha256(manifest_path),
        "book": manifest.get("book"),
        "status": manifest.get("status"),
        "signature": manifest_signature_status(manifest),
        "n_sleeves": len(sleeves),
        "starting_capital": starting_capital,
        "total_risk_pct": total_risk_pct,
        "magics": magics,
        "by_magic": {s["magic"]: s for s in sleeves},
        "sleeves": sleeves,
        "book_fingerprint": _book_fingerprint(sleeves, starting_capital, total_risk_pct),
    }


def _parse_epoch(value: str | dt.datetime | dt.date | None) -> Optional[dt.datetime]:
    """Parse a deployment epoch into a tz-aware UTC datetime. Date-only -> start of day."""
    if value is None:
        return None
    if isinstance(value, dt.datetime):
        return value if value.tzinfo else value.replace(tzinfo=dt.UTC)
    if isinstance(value, dt.date):
        return dt.datetime(value.year, value.month, value.day, tzinfo=dt.UTC)
    text = str(value).strip()
    if not text:
        return None
    text = text.replace("Z", "+00:00")
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError:
        parsed = dt.datetime.fromisoformat(text + "T00:00:00")
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=dt.UTC)


def _parse_ts_utc(rec: Mapping[str, Any]) -> Optional[dt.datetime]:
    raw = rec.get("ts_utc")
    if not raw:
        return None
    try:
        parsed = dt.datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=dt.UTC)


# --------------------------------------------------------------------------- #
# Log ingestion
# --------------------------------------------------------------------------- #
def _iter_log_events(log_dir: Path, *, magics: Optional[set[int]] = None):
    """Yield parsed JSON records from every QM5_<id>_*.log (skip the unconfigured stub).

    ``magics`` (optional) restricts the stream to log lines whose ``magic`` is one of the
    manifest identities. Callers that want the full stream (e.g. the DXZ journal dashboard)
    omit it and get the legacy no-filter behavior.
    """
    for path in sorted(glob.glob(str(log_dir / "QM5_*.log"))):
        if "QM5_0000_unconfigured" in path:
            continue
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or '"event"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if magics is not None:
                    magic = rec.get("magic")
                    if magic is None or int(magic) not in magics:
                        continue
                yield rec


def read_account_login(log_dir: Path) -> Optional[int]:
    """Read the AccountMonitor journal snapshot's account_login (identity cross-check).

    Log LINES do not carry the account; the T_Live terminal is single-account, so the
    account identity is bound at the terminal/log-dir level and cross-checked here.
    """
    snap = Path(log_dir) / "journal" / "account_snapshot.json"
    if not snap.exists():
        return None
    try:
        data = json.loads(snap.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    login = data.get("account_login")
    return int(login) if login is not None else None


def _day_key_to_date(day_key: int) -> dt.date:
    y, m, d = day_key // 10000, (day_key // 100) % 100, day_key % 100
    return dt.date(y, m, d)


def _collect_legacy_daykey(log_dir: Path, manifest: Mapping[str, Any]) -> dict[str, Any]:
    """Unchanged pre-repair collector (day_key bucketing, no identity filter).

    Retained VERBATIM for the DXZ journal dashboard, which deliberately renders the full
    day_key-bucketed history and labels the go-live split itself. The comparator path uses
    ``_collect_windowed`` instead (ts_utc basis + identity filter + epoch window).
    """
    equity_by_day: dict[int, list[float]] = {}
    trades_by_ea: dict[int, dict[str, int]] = {}
    for rec in _iter_log_events(log_dir):
        event = rec.get("event")
        payload = rec.get("payload") or {}
        if event == "EQUITY_SNAPSHOT":
            day_key = payload.get("day_key")
            equity = payload.get("equity")
            if day_key is not None and equity is not None:
                equity_by_day.setdefault(int(day_key), []).append(float(equity))
        elif event in OPEN_EVENTS or event in CLOSE_EVENTS:
            ea_id = rec.get("ea_id")
            if ea_id is None:
                continue
            bucket = trades_by_ea.setdefault(int(ea_id), {"opens": 0, "closes": 0})
            if event in OPEN_EVENTS:
                bucket["opens"] += 1
            else:
                bucket["closes"] += 1
    days = sorted(equity_by_day)
    dates = [_day_key_to_date(d) for d in days]
    equity_curve = [round(statistics.median(equity_by_day[d]), 2) for d in days]
    starting_capital = float(manifest.get("starting_capital", 100_000.0))
    daily_pnl = [round(equity_curve[i] - equity_curve[i - 1], 2) for i in range(1, len(equity_curve))]
    return {
        "source": "t_live_per_ea_logs",
        "log_dir": str(log_dir),
        "dates": [d.isoformat() for d in dates],
        "equity_curve": equity_curve,
        "daily_pnl": [round(v, 2) for v in daily_pnl],
        "starting_capital": starting_capital,
        "n_days": len(days),
        "trades_by_ea": trades_by_ea,
        "sleeves": {},
    }


def _collect_windowed(
    log_dir: Path,
    identities: Mapping[str, Any],
    deployment_epoch: dt.datetime,
) -> dict[str, Any]:
    """Repaired collector: identity-filtered, ts_utc-windowed live book equity curve.

    * Identity filter: only log lines whose ``magic`` is a manifest sleeve are trusted.
    * Window basis: ``ts_utc`` (real wall-clock emission time), NOT ``day_key`` (which is
      the last completed D1 bar and pins over weekends). The observation window is
      ``ts_utc >= deployment_epoch``.
    * Equity is ACCOUNT-wide (SUM of sleeves); the per-ts_utc-date value is the median of
      that day's trusted snapshots (robust to a single sleeve's floating open position).

    Three INDEPENDENT per-sleeve states are derived and reported separately — NEVER
    collapsed into one "heartbeat" (Codex WS-E4 round-2):
      * ATTACHMENT — lifecycle INIT_OK / DEINIT, all-time (current attachment). The last
        lifecycle event decides ATTACHED (last=INIT_OK) / DETACHED (last=DEINIT) /
        NO_LIFECYCLE (no INIT_OK and no DEINIT observed).
      * TELEMETRY  — EQUITY_SNAPSHOT emission, in-window (and all-time). EMITTING /
        SILENT (with never_emitted vs emitted_before_epoch_only detail).
      * ACTIVITY   — trade events (TM_OPEN/ENTRY_ACCEPTED/TM_CLOSE), in-window.
        TRADING / FLAT.
    A telemetry-SILENT sleeve with a healthy ATTACHED lifecycle is an equity-instrumentation
    gap (missing/failing ``QM_EquityStreamOnNewBar`` emit), NOT an unattached/absent sleeve.
    """
    magics: set[int] = set(identities["magics"])
    by_magic = identities["by_magic"]
    equity_by_date: dict[dt.date, list[float]] = {}
    # Per-magic, per-state accumulators. Lifecycle is all-time (current attachment truth);
    # telemetry/activity are counted in-window (and telemetry also all-time).
    lifecycle: dict[int, dict[str, Any]] = {
        m: {"last_event": None, "last_ts": None, "n_init_ok": 0, "n_deinit": 0,
            "last_init_ok_utc": None, "last_deinit_utc": None}
        for m in magics
    }
    telemetry: dict[int, dict[str, Any]] = {
        m: {"in_window": 0, "all_time": 0, "first_in_window_utc": None,
            "last_in_window_utc": None}
        for m in magics
    }
    activity: dict[int, dict[str, int]] = {m: {"opens": 0, "closes": 0} for m in magics}
    foreign_in_window: set[int] = set()  # NON-book magics emitting telemetry/trade in-window
    n_snapshot_rows_in_book = 0
    n_snapshot_rows_in_window = 0

    for rec in _iter_log_events(log_dir):  # full stream; identity handled explicitly below
        event = rec.get("event")
        magic = rec.get("magic")
        magic = int(magic) if magic is not None else None
        ts = _parse_ts_utc(rec)
        in_book = magic is not None and magic in magics
        in_window = ts is not None and ts >= deployment_epoch

        # Foreign identity is a REAL problem: a non-book magic emitting telemetry or a trade
        # in-window. (Lifecycle events are excluded here — a foreign EA merely (de)initialising
        # is not evidence it is trading on this book.)
        is_liveness = event == "EQUITY_SNAPSHOT" or event in OPEN_EVENTS or event in CLOSE_EVENTS
        if magic is not None and not in_book and in_window and is_liveness:
            foreign_in_window.add(magic)

        if not in_book:
            continue

        # --- ATTACHMENT: lifecycle events (all-time; current attachment state) ---
        if event in INIT_EVENTS:
            lifecycle[magic]["n_init_ok"] += 1
            lifecycle[magic]["last_init_ok_utc"] = rec.get("ts_utc")
        elif event in DEINIT_EVENTS:
            lifecycle[magic]["n_deinit"] += 1
            lifecycle[magic]["last_deinit_utc"] = rec.get("ts_utc")
        if event in INIT_EVENTS or event in DEINIT_EVENTS:
            prev = lifecycle[magic]["last_ts"]
            if prev is None or (ts is not None and ts > prev):
                lifecycle[magic]["last_ts"] = ts
                lifecycle[magic]["last_event"] = event

        # --- TELEMETRY: EQUITY_SNAPSHOT emission (all-time + in-window) ---
        if event == "EQUITY_SNAPSHOT":
            payload = rec.get("payload") or {}
            equity = payload.get("equity")
            if equity is None or ts is None:
                continue
            telemetry[magic]["all_time"] += 1
            n_snapshot_rows_in_book += 1
            if in_window:
                telemetry[magic]["in_window"] += 1
                if telemetry[magic]["first_in_window_utc"] is None:
                    telemetry[magic]["first_in_window_utc"] = rec.get("ts_utc")
                telemetry[magic]["last_in_window_utc"] = rec.get("ts_utc")
                n_snapshot_rows_in_window += 1
                equity_by_date.setdefault(ts.date(), []).append(float(equity))
        # --- ACTIVITY: trade events (in-window) ---
        elif event in OPEN_EVENTS or event in CLOSE_EVENTS:
            if not in_window:
                continue
            if event in OPEN_EVENTS:
                activity[magic]["opens"] += 1
            else:
                activity[magic]["closes"] += 1

    dates = sorted(equity_by_date)
    equity_curve = [round(statistics.median(equity_by_date[d]), 2) for d in dates]
    starting_capital = float(identities["starting_capital"])
    daily_pnl = [round(equity_curve[i] - equity_curve[i - 1], 2) for i in range(1, len(equity_curve))]

    # Derive the three independent states per sleeve.
    sleeve_states: list[dict[str, Any]] = []
    attached: list[int] = []
    detached: list[int] = []
    no_lifecycle: list[int] = []
    telem_emitting: list[int] = []
    telem_silent: list[int] = []
    telem_never: list[int] = []
    act_trading: list[int] = []
    act_flat: list[int] = []
    trades_by_sleeve: dict[str, dict[str, int]] = {}

    for m in sorted(magics):
        s = by_magic[m]
        lc = lifecycle[m]
        tel = telemetry[m]
        ac = activity[m]

        if lc["last_event"] in INIT_EVENTS:
            att_state = "ATTACHED"
            attached.append(m)
        elif lc["last_event"] in DEINIT_EVENTS:
            att_state = "DETACHED"
            detached.append(m)
        else:
            att_state = "NO_LIFECYCLE"
            no_lifecycle.append(m)

        if tel["in_window"] > 0:
            tel_state, tel_detail = "EMITTING", "in_window_snapshots"
            telem_emitting.append(m)
        else:
            tel_state = "SILENT"
            if tel["all_time"] == 0:
                tel_detail = "never_emitted"
                telem_never.append(m)
            else:
                tel_detail = "emitted_before_epoch_only"
            telem_silent.append(m)

        if (ac["opens"] + ac["closes"]) > 0:
            act_state = "TRADING"
            act_trading.append(m)
            trades_by_sleeve[f"{s['ea_id']}:{s['base_symbol']}"] = dict(ac)
        else:
            act_state = "FLAT"
            act_flat.append(m)

        sleeve_states.append({
            "magic": m,
            "ea_id": s["ea_id"],
            "symbol": s["symbol"],
            "base_symbol": s["base_symbol"],
            "attachment": {
                "state": att_state,
                "last_lifecycle_event": lc["last_event"],
                "last_lifecycle_utc": lc["last_ts"].isoformat() if lc["last_ts"] else None,
                "n_init_ok": lc["n_init_ok"],
                "n_deinit": lc["n_deinit"],
                "last_init_ok_utc": lc["last_init_ok_utc"],
                "last_deinit_utc": lc["last_deinit_utc"],
            },
            "telemetry": {
                "state": tel_state,
                "detail": tel_detail,
                "snapshots_in_window": tel["in_window"],
                "snapshots_all_time": tel["all_time"],
                "first_in_window_utc": tel["first_in_window_utc"],
                "last_in_window_utc": tel["last_in_window_utc"],
            },
            "activity": {
                "state": act_state,
                "opens_in_window": ac["opens"],
                "closes_in_window": ac["closes"],
            },
        })

    foreign = sorted(foreign_in_window)

    return {
        "source": "t_live_per_ea_logs",
        "basis": "identity_filtered_ts_utc_windowed_three_state",
        "log_dir": str(log_dir),
        "window": {
            "deployment_epoch_utc": deployment_epoch.isoformat(),
            "first_observed_utc_date": dates[0].isoformat() if dates else None,
            "last_observed_utc_date": dates[-1].isoformat() if dates else None,
            "n_days_observed": len(dates),
            "time_basis": "ts_utc (wall-clock); day_key intentionally NOT used (it pins to "
            "the last completed D1 bar over weekends and cannot be matched to an epoch).",
        },
        "dates": [d.isoformat() for d in dates],
        "equity_curve": equity_curve,
        "daily_pnl": daily_pnl,
        "starting_capital": starting_capital,
        "n_days": len(dates),
        "n_snapshot_rows_in_book": n_snapshot_rows_in_book,
        "n_snapshot_rows_in_window": n_snapshot_rows_in_window,
        "trades_by_sleeve": trades_by_sleeve,
        "sleeve_states": sleeve_states,
        "three_state_coverage": {
            "note": (
                "Three INDEPENDENT per-sleeve states; NEVER collapsed into one heartbeat. "
                "ATTACHMENT = lifecycle INIT_OK/DEINIT (all-time, current attachment); "
                "TELEMETRY = EQUITY_SNAPSHOT emission in-window; ACTIVITY = trade events "
                "in-window. A telemetry-SILENT sleeve with a healthy ATTACHED lifecycle is an "
                "equity-instrumentation gap, NOT an unattached/absent sleeve."
            ),
            "expected_sleeves": identities["n_sleeves"],
            "expected_magics": sorted(magics),
            "attachment": {"attached": attached, "detached": detached, "no_lifecycle": no_lifecycle},
            "telemetry": {
                "emitting": telem_emitting,
                "silent": telem_silent,
                "silent_never_emitted": telem_never,
            },
            "activity": {"trading": act_trading, "flat": act_flat},
            "foreign_emitting_in_window": foreign,
        },
        # Backward-compatible identity_coverage, redefined to the CORRECT semantics: identity
        # is ATTACHMENT completeness + absence of foreign in-window emitters. Telemetry silence
        # is reported SEPARATELY (three_state_coverage.telemetry) and is NOT an identity defect.
        "identity_coverage": {
            "coverage_basis": (
                "attachment lifecycle (INIT_OK/DEINIT) + foreign in-window emitters; telemetry "
                "silence is reported separately and is NOT an identity/attachment defect"
            ),
            "expected_sleeves": identities["n_sleeves"],
            "expected_magics": sorted(magics),
            "attached_in_book": attached,
            "attachment_defect": sorted(detached + no_lifecycle),
            "telemetry_silent": telem_silent,
            "unexpected_magics_emitting": foreign,
            "identities_match": (not detached) and (not no_lifecycle) and (not foreign),
        },
        "sleeves": {},  # per-sleeve equity is not separable from ACCOUNT_EQUITY
    }


def collect_forward_equity_from_logs(
    log_dir: Path,
    manifest: Mapping[str, Any],
    *,
    deployment_epoch: str | dt.datetime | dt.date | None = None,
    identities: Mapping[str, Any] | None = None,
    manifest_path: Path | None = None,
) -> dict[str, Any]:
    """Build the live book equity curve from EQUITY_SNAPSHOT events.

    Backward-compatible: with ``deployment_epoch=None`` (the dashboard call site) this
    returns the legacy day_key-bucketed, unfiltered curve. With an explicit
    ``deployment_epoch`` it returns the repaired identity-filtered, ts_utc-windowed curve.
    """
    epoch = _parse_epoch(deployment_epoch)
    if epoch is None:
        return _collect_legacy_daykey(log_dir, manifest)
    ids = identities or manifest_identities(manifest, manifest_path)
    return _collect_windowed(log_dir, ids, epoch)


# --------------------------------------------------------------------------- #
# SUM-of-sleeves Monte-Carlo (the ONLY trusted DD reference; no placeholder)
# --------------------------------------------------------------------------- #
def _backtest_risk_pct() -> float:
    try:
        with open(TESTER_DEFAULTS, encoding="utf-8") as fh:
            td = json.load(fh)
        return float(td["fixed_risk"]["amount"]) / float(td["initial_deposit"]) * 100.0
    except (OSError, KeyError, ValueError, ZeroDivisionError, json.JSONDecodeError):
        return 1.0


def _resolve_stream_root(manifest: Mapping[str, Any]) -> Optional[Path]:
    basis = manifest.get("stream_basis") or {}
    for key in ("bundle", "incumbents_bundle"):
        value = basis.get(key)
        if value:
            return Path(str(value))
    return None


def build_sum_of_sleeves_mc(
    identities: Mapping[str, Any],
    stream_root: Path,
    *,
    window_days: int,
    block_days: int = DEFAULT_BLOCK_DAYS,
    runs: int = 20000,
    seed: int = 1,
    generated_at_utc: str,
) -> tuple[Optional[dict[str, Any]], str]:
    """Build the SUM-of-sleeves 42d MaxDD MC from THIS manifest's actual sleeve streams.

    Each sleeve's backtest daily P&L (generated at RISK_FIXED = backtest_risk_pct) is scaled
    to its deployed ``risk_percent`` and summed (the deployed SUM-at-per-sleeve-risk book),
    then block-bootstrapped over a ``window_days`` calendar window for the p95 MaxDD%. The
    artifact carries the manifest SHA + book fingerprint so it can only be reused for the
    exact book it was built for. Returns ``(None, reason)`` if any sleeve stream is missing.
    """
    root = Path(stream_root)
    if not (root / "QM" / "q08_trades").exists():
        return None, f"stream_root has no QM/q08_trades: {root}"
    sleeves = identities["sleeves"]
    keys = [(s["ea_id"], s["symbol"]) for s in sleeves]
    model = load_model()
    streams = load_streams(root, candidates=keys, commission_model=model)
    missing = [f"{ea}:{sym}" for (ea, sym) in keys if (ea, sym) not in streams]
    if missing:
        return None, (
            f"{len(missing)} sleeve stream(s) absent under {root}: {', '.join(missing)} "
            "-> cannot build a manifest-bound SUM-of-sleeves MC (single stream_root)."
        )

    backtest_risk = _backtest_risk_pct()
    cap = float(identities["starting_capital"])
    daily: dict[dt.date, float] = defaultdict(float)
    for s in sleeves:
        factor = float(s["risk_percent"]) / backtest_risk
        for day, val in to_daily_pnl(streams[(s["ea_id"], s["symbol"])]).items():
            daily[day] += val * factor
    if not daily:
        return None, "sleeve streams contained no trades; cannot build reference"

    start, end = min(daily), max(daily)
    series: list[float] = []
    d = start
    one = dt.timedelta(days=1)
    while d <= end:
        if d.weekday() < 5:
            series.append(daily.get(d, 0.0))
        d += one

    rng = random.Random(seed)
    maxdds: list[float] = []
    for _ in range(runs):
        path = _block_bootstrap(series, window_days, block_days, rng)
        eq = peak = mdd = 0.0
        for v in path:
            eq += v
            peak = max(peak, eq)
            mdd = max(mdd, peak - eq)
        maxdds.append(mdd / cap * 100.0)
    maxdds.sort()
    dist = {
        "p50": round(_percentile(maxdds, 50.0), 6),
        "p95": round(_percentile(maxdds, 95.0), 6),
        "p99": round(_percentile(maxdds, 99.0), 6),
        "mean": round(sum(maxdds) / len(maxdds), 6),
    }
    artifact = {
        "block_bootstrap": {"max_drawdown_pct": dist},
        "max_drawdown_pct": {"p95": dist["p95"]},
        "_basis": SUM_MC_BASIS,
        "_provenance": {
            "generated_at_utc": generated_at_utc,
            "manifest_sha256": identities.get("manifest_sha256"),
            "book_fingerprint": identities["book_fingerprint"],
            "n_sleeves": identities["n_sleeves"],
            "starting_capital": cap,
            "total_risk_pct": identities.get("total_risk_pct"),
            "backtest_risk_pct": round(backtest_risk, 6),
            "stream_root": str(root),
            "window_days": window_days,
            "block_days": block_days,
            "runs": runs,
            "seed": seed,
            "stream_span": [start.isoformat(), end.isoformat()],
            "business_days": len(series),
            "note": (
                "SUM-of-sleeves MaxDD p95 over a calendar-day window on the DEPLOYED "
                "book at PER-SLEEVE risk_percent (capped inverse-vol weights). Bound to "
                "the manifest SHA + book fingerprint. Cost basis: sleeve-stream "
                "net_of_cost, spread-inclusive .DWX; the stream rows CARRY per-trade .DWX "
                "swap (row net = profit + swap + commission), so swap is NOT $0 — the "
                "residual is stream-swap vs current broker rates (UNKNOWN; WS-D)."
            ),
        },
    }
    return artifact, "ok"


def load_bound_mc(
    path: Path,
    identities: Mapping[str, Any],
) -> tuple[Optional[dict[str, Any]], str]:
    """Load a pre-built MC artifact and REFUSE it unless it is bound to this exact book."""
    try:
        artifact = pb._read_json(path)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        return None, f"could not read --mc-artifact {path}: {exc}"
    basis = str(artifact.get("_basis", ""))
    if not basis.startswith(SUM_MC_BASIS_PREFIX):
        return None, (
            f"--mc-artifact basis {basis!r} is not a SUM-of-sleeves reference; refusing "
            "(a weighted-avg / full-history placeholder is exactly the pre-repair defect)."
        )
    prov = artifact.get("_provenance") or {}
    fp = prov.get("book_fingerprint")
    sha = prov.get("manifest_sha256")
    if fp == identities["book_fingerprint"]:
        return artifact, "bound_by_fingerprint"
    if sha and sha == identities.get("manifest_sha256"):
        return artifact, "bound_by_manifest_sha"
    return None, (
        "--mc-artifact is not bound to this book: fingerprint/manifest_sha mismatch "
        f"(artifact fp={fp}, expected {identities['book_fingerprint']}). Refusing to "
        "compare against a reference built for a different composition/weighting."
    )


# --------------------------------------------------------------------------- #
# Report assembly
# --------------------------------------------------------------------------- #
def _cost_basis_block() -> dict[str, Any]:
    # Codex WS-E4 round-2 correction: the durable book streams DO carry swap. Each stream
    # TRADE_CLOSED row's ``net`` = profit + swap + commission, i.e. the .DWX broker-history
    # swap is already folded into the book P&L (empirically non-zero, e.g. 12969/USDJPY
    # +$3018, 11421/EURUSD -$796, 11165/AUDCAD -$423 lifetime; some like XAU ~$0). The
    # pre-repair "book carries $0 swap" declaration was factually wrong.
    return {
        "live_side": "T_Live ACCOUNT_EQUITY — real fills incl broker commission, spread, "
        "and overnight swap at CURRENT broker rates.",
        "book_side": "sleeve streams net_of_cost; row net = profit + swap + commission, so "
        "each trade CARRIES its .DWX broker-history swap (NON-zero for overnight-held "
        "sleeves) — swap is NOT $0.",
        "asymmetry": "SWAP: both sides carry swap. The residual is the difference between the "
        "HISTORICAL .DWX swap already embedded in the streams and the CURRENT live broker "
        "swap rates (which may differ and are UNKNOWN without a logged-in capture). Tracked "
        "by WS-D: like-for-like replacement of stream swap by current native-report swap on "
        "the attributed sleeves is small (~+$28.55, not +$333); whole-book current-rate "
        "materiality remains UNKNOWN/INCOMPLETE. Do not read a small live-vs-book gap as edge "
        "decay before the current-rate swap reconciliation closes.",
    }


def build_report(
    *,
    manifest: Mapping[str, Any],
    identities: Mapping[str, Any],
    forward_equity: Mapping[str, Any],
    mc_artifact: Optional[Mapping[str, Any]],
    mc_reason: str,
    account_expected: Optional[int],
    account_observed: Optional[int],
    deployment_epoch: dt.datetime,
    config: Mapping[str, Any],
    generated_at_utc: str,
) -> dict[str, Any]:
    tol = config["pass_tolerances"]
    dd_tolerance = float(tol["dd_tolerance"])
    sharpe_band = float(tol["sharpe_band"])
    window = int(config.get("burnin_window_days", 42))
    n_days = int(forward_equity.get("n_days", 0))
    immature = n_days < window

    # Three independent states (never one heartbeat). Fall back gracefully for a minimal
    # forward_equity that predates the three-state collector (e.g. the epoch-absent path).
    three_state = forward_equity.get("three_state_coverage")
    if three_state is None:
        legacy = forward_equity.get("identity_coverage", {})
        three_state = {
            "attachment": {"attached": [], "detached": [], "no_lifecycle": []},
            "telemetry": {"emitting": [], "silent": [], "silent_never_emitted": []},
            "activity": {"trading": [], "flat": []},
            "foreign_emitting_in_window": legacy.get("unexpected_magics_emitting", []),
        }
    att = three_state.get("attachment", {})
    tel = three_state.get("telemetry", {})
    act = three_state.get("activity", {})
    detached = att.get("detached", [])
    no_lifecycle = att.get("no_lifecycle", [])
    telem_silent = tel.get("silent", [])
    foreign = three_state.get("foreign_emitting_in_window", [])
    attachment_ok = (not detached) and (not no_lifecycle) and (not foreign)

    # Signed-manifest contract: a DRAFT bound only by SHA is NOT signed (Codex WS-E4 round-2).
    signature = dict(identities.get("signature") or {})
    signed = bool(signature.get("signed"))

    account_ok = (
        account_expected is None
        or account_observed is None
        or int(account_expected) == int(account_observed)
    )
    account_status = (
        UNKNOWN
        if (account_expected is not None and account_observed is None)
        else ("MATCH" if account_ok else "MISMATCH")
    )

    reasons: list[str] = []
    checks: dict[str, Any] = {}

    # --- realised metrics (only meaningful with in-window equity) ---
    realised: dict[str, Any] = {}
    if n_days == 0:
        reasons.append(
            "no in-window EQUITY_SNAPSHOT after the deployment epoch "
            f"{deployment_epoch.isoformat()} -> nothing to compare"
        )
    else:
        daily_pnl = [float(v) for v in forward_equity.get("daily_pnl", [])]
        realised = pb.metrics_from_daily_pnl(
            daily_pnl,
            n_sleeves=identities["n_sleeves"],
            starting_capital=float(identities["starting_capital"]),
            n_days=len(daily_pnl),
        )

    # --- drawdown-vs-MC check ---
    if mc_artifact is None:
        checks["drawdown_vs_mc"] = {
            "status": UNKNOWN,
            "reason": mc_reason,
            "note": "No manifest-bound SUM-of-sleeves MC. NO placeholder is substituted.",
        }
        reasons.append(f"drawdown reference UNKNOWN: {mc_reason}")
    elif n_days == 0:
        checks["drawdown_vs_mc"] = {"status": UNKNOWN, "reason": "no realised equity in window"}
    else:
        mc_p95 = pb._mc_drawdown_p95(mc_artifact)
        dd_limit = mc_p95 + dd_tolerance
        realised_dd = float(realised["max_drawdown_pct"])
        breach = realised_dd > dd_limit
        checks["drawdown_vs_mc"] = {
            "status": "FAIL" if breach else "PASS",
            "realised_max_drawdown_pct": round(realised_dd, 6),
            "mc_p95_max_drawdown_pct": round(mc_p95, 6),
            "dd_tolerance_pct_points": dd_tolerance,
            "dd_limit_pct": round(dd_limit, 6),
            "mc_basis": str(mc_artifact.get("_basis")),
            "mc_binding": mc_reason,
        }
        if breach:
            reasons.append(
                f"realised max-DD {round(realised_dd, 4)}% exceeds MC p95 {round(mc_p95, 4)}% "
                f"+ tol {dd_tolerance}%"
            )

    # --- Sharpe-band check ---
    bt_sharpe = pb._as_optional_float(pb._nested_get(manifest, ("kpis", "sharpe")))
    rl_sharpe = pb._as_optional_float(realised.get("sharpe")) if realised else None
    if n_days == 0:
        checks["sharpe_band"] = {"status": UNKNOWN, "reason": "no realised equity in window"}
    elif bt_sharpe is None:
        checks["sharpe_band"] = {"status": UNKNOWN, "reason": "manifest backtest Sharpe missing"}
        reasons.append("manifest backtest Sharpe missing")
    elif rl_sharpe is None:
        checks["sharpe_band"] = {"status": UNKNOWN, "reason": "realised forward Sharpe unavailable"}
    else:
        outside = abs(rl_sharpe - bt_sharpe) > sharpe_band
        checks["sharpe_band"] = {
            "status": "HOLD" if outside else "PASS",
            "backtest_sharpe": round(bt_sharpe, 6),
            "realised_sharpe": round(rl_sharpe, 6),
            "sharpe_band": sharpe_band,
            "note": "Sharpe is scale-invariant, so this check is directionally valid even "
            "though the live series is short.",
        }
        if outside:
            reasons.append(
                f"realised Sharpe {round(rl_sharpe, 3)} outside +/-{sharpe_band} of backtest "
                f"{round(bt_sharpe, 3)}"
            )

    # --- signed-manifest check (a DRAFT bound by SHA is NOT signed) ---
    checks["manifest_signature"] = {
        "status": "PASS" if signed else UNKNOWN,
        "signature_label": signature.get("signature_label"),
        "manifest_status": signature.get("manifest_status"),
        "approved_by": signature.get("approved_by"),
        "note": signature.get("criteria"),
    }
    if not signed:
        reasons.append(
            f"manifest is {signature.get('signature_label')} "
            f"(status={signature.get('manifest_status')}, approver="
            f"{'present' if signature.get('has_approver') else 'absent'}); a manifest bound "
            "by SHA but not signed cannot yield a binding/PASS verdict"
        )

    # --- ATTACHMENT coverage (lifecycle INIT_OK/DEINIT) ---
    checks["attachment_coverage"] = {
        "status": "PASS" if (not detached and not no_lifecycle) else UNKNOWN,
        "attached": att.get("attached", []),
        "detached": detached,
        "no_lifecycle": no_lifecycle,
        "note": "Lifecycle per sleeve. DETACHED = last event DEINIT (e.g. lost/zero-byte "
        "chart); NO_LIFECYCLE = no INIT_OK/DEINIT observed. This is the attachment state, "
        "reported independently of telemetry and activity.",
    }
    if detached or no_lifecycle:
        reasons.append(
            f"attachment defect: detached={detached} no_lifecycle={no_lifecycle}"
        )

    # --- TELEMETRY coverage (EQUITY_SNAPSHOT emission) — SEPARATE from attachment ---
    checks["telemetry_coverage"] = {
        "status": "PASS" if not telem_silent else "WARN",
        "emitting": tel.get("emitting", []),
        "silent": telem_silent,
        "silent_never_emitted": tel.get("silent_never_emitted", []),
        "note": "EQUITY_SNAPSHOT emission per sleeve. A SILENT sleeve with a healthy ATTACHED "
        "lifecycle is an equity-instrumentation gap (missing/failing QM_EquityStreamOnNewBar "
        "emit), NOT an unattached sleeve; the account equity curve is built from the emitting "
        "sleeves and remains valid.",
    }
    if telem_silent:
        reasons.append(
            f"telemetry gap (equity-snapshot SILENT; attachment reported separately): {telem_silent}"
        )

    # --- ACTIVITY coverage (trade events) — informational ---
    checks["activity_coverage"] = {
        "status": "INFO",
        "trading": act.get("trading", []),
        "flat": act.get("flat", []),
        "note": "Trade events per sleeve in-window. FLAT may be legitimate (no signal / "
        "low-frequency sleeve), so this is informational, not a defect on its own.",
    }

    # --- foreign identity (non-book magic emitting in-window) ---
    checks["foreign_identity"] = {
        "status": "PASS" if not foreign else UNKNOWN,
        "unexpected_magics_emitting": foreign,
    }
    if foreign:
        reasons.append(f"foreign (non-book) magics emitting in-window: {foreign}")

    # --- account identity ---
    checks["account_identity"] = {
        "status": account_status,
        "expected": account_expected,
        "observed": account_observed,
    }
    if account_status == "MISMATCH":
        reasons.append(
            f"account mismatch: expected {account_expected}, observed {account_observed}"
        )

    # --- overall verdict (FAIL dominates; ANY incomplete input -> UNKNOWN, never a green) ---
    # A telemetry gap (WARN) and an unsigned manifest / attachment defect (UNKNOWN checks)
    # are all "incomplete inputs" and force UNKNOWN, never a silent PASS.
    statuses = [c.get("status") for c in checks.values()]
    incomplete = (
        n_days == 0
        or UNKNOWN in statuses
        or "WARN" in statuses
        or account_status == UNKNOWN
    )
    if "FAIL" in statuses:
        overall = "FAIL"
    elif incomplete:
        overall = UNKNOWN
    elif "HOLD" in statuses:
        overall = "HOLD"
    else:
        overall = "PASS"
    binding = (
        overall in {"PASS", "HOLD", "FAIL"}
        and not immature
        and mc_artifact is not None
        and attachment_ok
        and not telem_silent
        and account_ok
        and signed
    )

    return {
        "status": "EVIDENCE_FOR_OWNER",
        "generated_at_utc": generated_at_utc,
        "source": "t_live_per_ea_logs",
        "comparator": "portfolio_live_forward_from_logs (E4' repaired sampling contract)",
        "manifest_binding": {
            "manifest_path": identities.get("manifest_path"),
            "manifest_sha256": identities.get("manifest_sha256"),
            "book": identities.get("book"),
            "manifest_status": identities.get("status"),
            "signature": signature,
            "n_sleeves": identities.get("n_sleeves"),
            "starting_capital": identities.get("starting_capital"),
            "total_risk_pct": identities.get("total_risk_pct"),
            "book_fingerprint": identities.get("book_fingerprint"),
            "deployment_epoch_utc": deployment_epoch.isoformat(),
        },
        "cost_basis": _cost_basis_block(),
        "dd_reference": {
            "available": mc_artifact is not None,
            "reason": mc_reason,
            "basis": None if mc_artifact is None else str(mc_artifact.get("_basis")),
            "mc_p95_max_drawdown_pct": (
                None if mc_artifact is None else pb._mc_drawdown_p95(mc_artifact)
            ),
            "provenance": {} if mc_artifact is None else mc_artifact.get("_provenance", {}),
        },
        "maturity": {
            "n_days_observed": n_days,
            "burnin_window_days": window,
            "immature": immature,
            "binding": binding,
            "note": (
                "Window not yet filled; verdict advisory-only and NOT binding until "
                f"n_days >= {window}."
            )
            if immature
            else "Window filled.",
        },
        "realised": realised,
        "forward_equity": forward_equity,
        "verdict": {
            "verdict": overall,
            "binding": binding,
            "advisory_only": True,
            "tier0_safety": {
                "tlive_action": "NONE",
                "autotrading_action": "NONE",
                "note": "Read-only evidence; T_Live trading-state control remains OWNER+Claude manual.",
            },
            "checks": checks,
            "reasons": reasons,
        },
    }


# --------------------------------------------------------------------------- #
# Atomic idempotent write
# --------------------------------------------------------------------------- #
def _atomic_write_json(obj: Mapping[str, Any], out_path: Path) -> None:
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_name(f".{out_path.name}.tmp.{os.getpid()}")
    try:
        with tmp.open("w", encoding="utf-8") as fh:
            json.dump(obj, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.replace(tmp, out_path)  # atomic within the same volume
    finally:
        if tmp.exists():
            try:
                tmp.unlink()
            except OSError:
                pass


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--manifest", type=Path, required=True)
    p.add_argument(
        "--deployment-epoch",
        type=str,
        default=None,
        help="ISO date/datetime (UTC) the deployed book went live. REQUIRED for a real "
        "comparison; absence yields an UNKNOWN report (never a green).",
    )
    p.add_argument("--log-dir", type=Path, default=DEFAULT_TLIVE_LOG_DIR)
    p.add_argument("--config", type=Path, default=pb.DEFAULT_CONFIG)
    p.add_argument("--expected-account", type=int, default=None,
                   help="account_login to cross-check against journal/account_snapshot.json")
    p.add_argument("--require-signed", action="store_true",
                   help="refuse (exit 2) unless the manifest is SIGNED (approved live status "
                   "+ approver/signed flag). A DRAFT bound only by SHA is NOT signed.")
    p.add_argument("--mc-artifact", type=Path, default=None,
                   help="pre-built SUM-of-sleeves MC bound to this manifest (fingerprint/SHA)")
    p.add_argument("--build-mc", action="store_true",
                   help="build the SUM-of-sleeves MC inline from the manifest's sleeve streams")
    p.add_argument("--stream-root", type=Path, default=None,
                   help="root containing QM/q08_trades for --build-mc (else manifest stream_basis)")
    p.add_argument("--mc-runs", type=int, default=20000)
    p.add_argument("--mc-seed", type=int, default=1)
    p.add_argument("--mc-block-days", type=int, default=DEFAULT_BLOCK_DAYS)
    p.add_argument("--mc-out", type=Path, default=None,
                   help="write the freshly built MC artifact here (with --build-mc)")
    p.add_argument("--out", type=Path,
                   default=Path(r"D:\QM\reports\portfolio\live_burnin\portfolio_live_burnin_report.json"))
    p.add_argument("--generated-at-utc", type=str, required=True,
                   help="ISO UTC timestamp (scripts have no clock); pass from the caller.")
    return p.parse_args(argv)


def _resolve_mc(
    args: argparse.Namespace,
    identities: Mapping[str, Any],
    manifest: Mapping[str, Any],
    window_days: int,
) -> tuple[Optional[dict[str, Any]], str]:
    """Resolve the DD reference with NO placeholder fallback."""
    if args.mc_artifact is not None:
        return load_bound_mc(args.mc_artifact, identities)
    if args.build_mc:
        stream_root = args.stream_root or _resolve_stream_root(manifest)
        if stream_root is None:
            return None, "--build-mc requested but no --stream-root and no manifest stream_basis"
        artifact, reason = build_sum_of_sleeves_mc(
            identities,
            stream_root,
            window_days=window_days,
            block_days=args.mc_block_days,
            runs=args.mc_runs,
            seed=args.mc_seed,
            generated_at_utc=args.generated_at_utc,
        )
        if artifact is not None and args.mc_out is not None:
            _atomic_write_json(artifact, args.mc_out)
        return artifact, (f"built_inline: {reason}" if artifact is not None else reason)
    return None, (
        "no DD reference supplied (--mc-artifact or --build-mc). NO placeholder is used; "
        "the drawdown check is UNKNOWN."
    )


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        config = pb.load_burnin_config(args.config)
        manifest = pb._read_json(args.manifest)
        identities = manifest_identities(manifest, args.manifest)
        epoch = _parse_epoch(args.deployment_epoch)
        window_days = int(config.get("burnin_window_days", 42))

        sig = identities.get("signature", {})
        print(f"manifest={args.manifest}")
        print(f"manifest_sha256={identities['manifest_sha256']}")
        print(f"book_fingerprint={identities['book_fingerprint']}")
        print(f"manifest_signature={sig.get('signature_label')} "
              f"(status={sig.get('manifest_status')}, signed={sig.get('signed')})")
        print(f"log_dir={args.log_dir}")

        if args.require_signed and not sig.get("signed"):
            print(
                f"live-vs-book compare refused: --require-signed set but manifest is "
                f"{sig.get('signature_label')} (status={sig.get('manifest_status')}, "
                f"approver={'present' if sig.get('has_approver') else 'absent'}). Binding a "
                "manifest by SHA does not make it signed."
            )
            return 2

        account_observed = read_account_login(args.log_dir)

        if epoch is None:
            # Incomplete input: cannot match the observation window -> honest UNKNOWN report.
            forward_equity = {
                "source": "t_live_per_ea_logs",
                "n_days": 0,
                "daily_pnl": [],
                "three_state_coverage": {
                    "attachment": {"attached": [], "detached": [], "no_lifecycle": []},
                    "telemetry": {"emitting": [], "silent": [], "silent_never_emitted": []},
                    "activity": {"trading": [], "flat": []},
                    "foreign_emitting_in_window": [],
                },
                "note": "no --deployment-epoch supplied; window cannot be matched",
            }
            epoch_effective = _parse_epoch("1970-01-01")
            mc_artifact, mc_reason = None, "deployment epoch not supplied -> UNKNOWN"
        else:
            epoch_effective = epoch
            forward_equity = collect_forward_equity_from_logs(
                args.log_dir, manifest, deployment_epoch=epoch, identities=identities,
                manifest_path=args.manifest,
            )
            mc_artifact, mc_reason = _resolve_mc(args, identities, manifest, window_days)

        report = build_report(
            manifest=manifest,
            identities=identities,
            forward_equity=forward_equity,
            mc_artifact=mc_artifact,
            mc_reason=mc_reason,
            account_expected=args.expected_account,
            account_observed=account_observed,
            deployment_epoch=epoch_effective,
            config=config,
            generated_at_utc=args.generated_at_utc,
        )
        _atomic_write_json(report, args.out)
        print(f"wrote {args.out}")
        m = report["maturity"]
        v = report["verdict"]
        r = report.get("realised", {})
        print(f"n_days={m['n_days_observed']} (window {m['burnin_window_days']}, "
              f"immature={m['immature']}, binding={m['binding']})")
        print(f"realised: net={r.get('total_net_of_cost_profit')}  "
              f"maxDD={r.get('max_drawdown_pct')}%  sharpe={r.get('sharpe')}")
        print(f"dd_reference_available={report['dd_reference']['available']} ({mc_reason})")
        tsc = report["forward_equity"].get("three_state_coverage", {})
        if tsc:
            a = tsc.get("attachment", {}); t = tsc.get("telemetry", {}); ac = tsc.get("activity", {})
            print(f"ATTACHMENT attached={len(a.get('attached', []))} "
                  f"detached={a.get('detached', [])} no_lifecycle={a.get('no_lifecycle', [])}")
            print(f"TELEMETRY  emitting={len(t.get('emitting', []))} silent={t.get('silent', [])}")
            print(f"ACTIVITY   trading={len(ac.get('trading', []))} flat={len(ac.get('flat', []))}")
        print(f"verdict={v['verdict']} binding={v['binding']} reasons={v['reasons']}")
        print(pb.note_go_live_is_manual())
        return 0
    except (pb.ConfigError, FileNotFoundError, ValueError, KeyError) as exc:
        print(f"live-vs-book compare refused: {exc}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
