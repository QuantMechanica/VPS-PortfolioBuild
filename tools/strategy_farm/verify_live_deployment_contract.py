#!/usr/bin/env python3
"""verify_live_deployment_contract.py -- WS-E3 (ULTRACODE programme).

Read-only verifier that binds the *deployed live MT5 profile* AND *fresh runtime
identity evidence* against a signed deployment manifest.

GENERALIZED, NOT RE-PARSED
--------------------------
The `.chr` chart-contract grammar is NOT re-implemented here. It lives in ONE
shared module -- ``tools/strategy_farm/liveops_profile_contract.ps1`` -- which the
two existing fail-closed PowerShell verifiers now dot-source and delegate to:

  * prepare_dxz_v2_liveops_profile.ps1        (uses shared Get-ChartContract)
  * verify_ftmo_round25_live_contract.ps1     (uses shared Get-ChartContract /
                                               Get-UniqueValue / Get-Sha256)

This tool consumes the SAME module through its JSON adapter
(``-EmitProfileJson`` / ``-EmitCommonIni``). There is exactly one parser for the
MT5 `.chr` and common.ini grammar across all three consumers.

Why a shared module (option a) rather than "invoke the existing PS functions"
(option b): the two existing scripts are not import-safe. Dot-sourcing either one
executes its top-level body -- prepare_dxz can *create/verify the operational
T_Live profile* and verify_ftmo runs the full FTMO contract check and exits. You
cannot call just their `Get-ChartContract` without extracting it into an
import-safe unit first -- which IS the shared module. Option (a) is therefore the
smaller *honest* diff and the only side-effect-free one.

TWO SEPARATELY LABELLED TRUTH LAYERS
------------------------------------
  (A) DISK-PROFILE truth  -- parsed from the `.chr` files on disk (the *recovery
      profile*). An on-disk `.chr` does NOT prove the running session has that
      chart open.
  (B) RUNTIME truth       -- fresh post-start INIT_OK / magic / EA identity
      heartbeats in the MQL5\\Files\\QM event logs, plus the AccountMonitor
      account-snapshot heartbeat.

Disk truth is never presented as runtime truth, and vice versa.

IDENTITY BINDING (exact tuple)
------------------------------
Per sleeve the intended bound tuple is:
  (account, server, deployment_epoch, manifest_SHA, symbol, timeframe, EA,
   EA_binary_SHA, magic, risk)
Every element that the manifest does NOT carry is reported as an explicit
UNKNOWN (never silently treated as a match). The tool emits a machine-readable
``identity_binding`` block and can write a *deploy-stamp contract*
(``--deploy-stamp-out``) that lists exactly which fields tonight's manifest must
add before the run can be a signed deployment-contract PASS rather than a
read-only diagnostic snapshot.

STRICTLY READ-ONLY. No auto-correction. Opens no database. Writes only the
output paths given on the command line.

Exit codes: 0 GREEN, 1 AMBER, 2 RED, 3 UNKNOWN/tool-error.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List, Optional, Tuple

TOOL_NAME = "verify_live_deployment_contract"
TOOL_VERSION = "2.0"
SCHEMA_VERSION = "wse3-live-deployment-contract/1"

# ---------------------------------------------------------------------------
# Defaults for the DXZ T_Live deployment. Every one is overridable on the CLI
# so the tool is generic (fixtures point these at synthetic dirs).
# ---------------------------------------------------------------------------
DEFAULT_PROFILE_DIR = r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Profiles\Charts\DarwinexZero_V2_LiveOps"
DEFAULT_EVENT_LOG_DIR = r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM"
DEFAULT_ACCOUNT_SNAPSHOT = r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\account_snapshot.json"
DEFAULT_COMMON_INI = r"C:\QM\mt5\T_Live\MT5_Base\config\common.ini"
DEFAULT_MONITOR_NAME = "QM_AccountMonitor"
DEFAULT_FRESHNESS_HOURS = 24.0
DEFAULT_SNAPSHOT_STALE_MIN = 30.0
DEFAULT_MODULE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "liveops_profile_contract.ps1")
# Symbol suffixes that distinguish a backtest custom symbol from the live broker
# symbol (DXZ trades AUDUSD live; backtests use AUDUSD.DWX). Stripped for compare.
SYMBOL_SUFFIXES = (".DWX", ".cash")
RISK_TOL = 1e-4  # absolute tolerance on RISK_PERCENT (a real mis-size is >> this)


# ---------------------------------------------------------------------------
# Shared-parser bridge. The `.chr`/common.ini grammar is owned by the PowerShell
# module; we only invoke it and consume its JSON. No `.chr` parsing lives here.
# ---------------------------------------------------------------------------
def find_powershell() -> Optional[str]:
    for exe in ("pwsh", "powershell"):
        p = shutil.which(exe)
        if p:
            return p
    for cand in (r"C:\Program Files\PowerShell\7\pwsh.exe",
                 r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"):
        if os.path.exists(cand):
            return cand
    return None


def run_shared_module(module_path: str, ps_exe: str, *ps_args: str) -> Any:
    """Invoke the shared PS parsing module in adapter mode and return parsed JSON.
    Read-only: the module reads only the given path(s) and writes nothing."""
    cmd = [ps_exe, "-NoProfile", "-NonInteractive", "-File", module_path, *ps_args]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError("shared parser %s failed (rc=%s): %s" % (
            os.path.basename(module_path), proc.returncode,
            (proc.stderr or proc.stdout).strip()))
    out = proc.stdout.strip()
    if not out:
        raise RuntimeError("shared parser %s produced no output" % os.path.basename(module_path))
    return json.loads(out)


def sha256_file(path: str) -> Optional[str]:
    try:
        h = hashlib.sha256()
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
        return h.hexdigest().upper()
    except OSError:
        return None


def tf_from_period(period_type: Optional[str], period_size: Optional[str]) -> Optional[str]:
    """Map a `.chr` (period_type, period_size) pair to an MT5 timeframe token.
    This is downstream *interpretation* of parsed fields, not `.chr` parsing.
    period_type=1 -> hour base (1->H1, 4->H4, 24->D1, 168->W1, 720->MN1);
    period_type=0 -> minute base (5->M5, 30->M30, ...)."""
    try:
        pt = int(period_type)
        ps = int(period_size)
    except (TypeError, ValueError):
        return None
    if pt == 0:
        return "M%d" % ps
    if pt == 1:
        if ps == 24:
            return "D1"
        if ps == 168:
            return "W1"
        if ps == 720:
            return "MN1"
        return "H%d" % ps
    return None


_TF_TOKEN_RE = re.compile(r"[_.](MN1|W1|D1|H12|H8|H6|H4|H3|H2|H1|M30|M20|M15|M12|M10|M6|M5|M4|M3|M2|M1)(?=[_.])")


def tf_from_pathlike(*paths: Optional[str]) -> Optional[str]:
    """Extract an explicit timeframe token from a set/preset filename such as
    ..._USDJPY.DWX_M30_backtest.set -> M30. The last token found is used."""
    for p in paths:
        if not p:
            continue
        toks = _TF_TOKEN_RE.findall(p)
        if toks:
            return toks[-1]
    return None


@dataclass
class ChartExpert:
    name: Optional[str] = None
    path: Optional[str] = None
    expertmode: Optional[str] = None
    qm_ea_id: Optional[str] = None
    qm_magic_slot_offset: Optional[str] = None
    magic: Optional[int] = None
    risk_percent: Optional[str] = None
    risk_fixed: Optional[str] = None
    portfolio_weight: Optional[str] = None
    risk_cap_pct: Optional[str] = None


@dataclass
class ParsedChart:
    file: str
    exists: bool = True
    empty: bool = False
    parseable: bool = False
    error: Optional[str] = None
    encoding_bom: Optional[str] = None
    symbol: Optional[str] = None
    period_type: Optional[str] = None
    period_size: Optional[str] = None
    tf: Optional[str] = None
    n_experts: int = 0
    expert: Optional[ChartExpert] = None
    is_monitor: bool = False


def _record_to_parsedchart(rec: dict, monitor_name: str) -> ParsedChart:
    """Adapt one shared-module chart record (already parsed by the PS grammar)
    into a ParsedChart. This does NO `.chr` parsing -- it only interprets the
    fields the shared parser produced."""
    pc = ParsedChart(file=rec.get("file"))
    pc.exists = bool(rec.get("exists"))
    pc.empty = bool(rec.get("empty"))
    pc.encoding_bom = rec.get("bom")
    pc.n_experts = int(rec.get("n_experts") or 0)
    pc.symbol = rec.get("symbol")
    pc.period_type = rec.get("period_type")
    pc.period_size = rec.get("period_size")
    pc.tf = tf_from_period(pc.period_type, pc.period_size)
    pc.error = rec.get("error")
    if (not pc.exists) or pc.empty or pc.n_experts != 1:
        # missing / empty / not-exactly-one-expert -> not parseable (error set by module)
        return pc
    exd = rec.get("expert") or {}
    ex = ChartExpert(
        name=exd.get("name"),
        path=exd.get("path"),
        expertmode=exd.get("expertmode"),
        qm_ea_id=exd.get("qm_ea_id"),
        qm_magic_slot_offset=exd.get("qm_magic_slot_offset"),
        risk_percent=exd.get("RISK_PERCENT"),
        risk_fixed=exd.get("RISK_FIXED"),
        portfolio_weight=exd.get("PORTFOLIO_WEIGHT"),
        risk_cap_pct=exd.get("qm_risk_cap_pct"),
    )
    if ex.qm_ea_id is not None and ex.qm_magic_slot_offset is not None:
        try:
            ex.magic = int(ex.qm_ea_id) * 10000 + int(ex.qm_magic_slot_offset)
        except ValueError:
            ex.magic = None
    pc.expert = ex
    pc.is_monitor = (ex.name == monitor_name) and (ex.qm_ea_id is None)
    if pc.is_monitor:
        pc.parseable = True
    else:
        pc.parseable = ex.magic is not None
        if ex.magic is None and pc.error is None:
            pc.error = "trading chart missing qm_ea_id/qm_magic_slot_offset"
    return pc


def parse_profile_charts(profile_dir: str, monitor_name: str,
                         module_path: str, ps_exe: str) -> List[ParsedChart]:
    """Return ParsedChart for every chart*.chr in profile_dir, parsed by the
    shared PowerShell grammar module (single source of truth)."""
    data = run_shared_module(module_path, ps_exe, "-EmitProfileJson", profile_dir)
    charts = data.get("charts") or []
    return [_record_to_parsedchart(rec, monitor_name) for rec in charts]


def read_common_ini(path: Optional[str], module_path: str, ps_exe: str) -> Tuple[Optional[str], Optional[str]]:
    """Login/Server from common.ini, parsed by the shared module (same grammar
    verify_ftmo uses via Get-IniValue). Returns (None, None) if unreadable."""
    if not path or not os.path.exists(path):
        return None, None
    try:
        d = run_shared_module(module_path, ps_exe, "-EmitCommonIni", path)
        return d.get("Login"), d.get("Server")
    except Exception:
        return None, None


def read_account_snapshot(path: Optional[str]) -> Optional[dict]:
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None


# ---------------------------------------------------------------------------
# Manifest normalization.
# ---------------------------------------------------------------------------
@dataclass
class ExpectedSleeve:
    ea_id: Optional[int]
    ea_label: Optional[str]
    symbol: Optional[str]
    magic: Optional[int]
    risk_percent: Optional[float]
    tf: Optional[str]
    ex5_path: Optional[str]
    ex5_sha256: Optional[str]  # expected deployed-binary SHA if the manifest pins it


@dataclass
class ManifestInfo:
    path: str
    file_sha256: Optional[str]
    declared_status: Optional[str]
    declared_approved_by: Optional[str]
    declared_signed: Optional[bool]
    declared_signature: Optional[str]
    book: Optional[str]
    expected_account: Optional[str]
    expected_account_source: str
    expected_server: Optional[str]
    deployment_epoch: Optional[str]
    deployment_epoch_source: str
    sleeves: List[ExpectedSleeve] = field(default_factory=list)


def _book_to_account(book: Optional[str]) -> Optional[str]:
    if not book:
        return None
    m = re.search(r"(\d{6,})", book)
    return m.group(1) if m else None


def load_manifest(path: str, cli_account: Optional[str], cli_server: Optional[str],
                  cli_epoch: Optional[str]) -> ManifestInfo:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    raw_sleeves = data.get("sleeves") or data.get("legs") or []
    sleeves: List[ExpectedSleeve] = []
    for s in raw_sleeves:
        ea_id = s.get("ea_id")
        try:
            ea_id = int(ea_id) if ea_id is not None else None
        except (TypeError, ValueError):
            ea_id = None
        magic = s.get("magic_number", s.get("magic"))
        if magic is None and ea_id is not None and s.get("magic_slot") is not None:
            try:
                magic = ea_id * 10000 + int(s["magic_slot"])
            except (TypeError, ValueError):
                magic = None
        try:
            magic = int(magic) if magic is not None else None
        except (TypeError, ValueError):
            magic = None
        risk = s.get("risk_percent")
        if risk is None:
            sfe = s.get("set_file_expectation") or {}
            risk = sfe.get("RISK_PERCENT")
        try:
            risk = float(risk) if risk is not None else None
        except (TypeError, ValueError):
            risk = None
        tf = s.get("timeframe") or s.get("tf")
        if not tf:
            tf = tf_from_pathlike(s.get("backtest_set"), s.get("deployed_preset"),
                                  s.get("set"), s.get("preset"))
        sleeves.append(ExpectedSleeve(
            ea_id=ea_id,
            ea_label=s.get("ea_label") or s.get("slug") or s.get("name"),
            symbol=s.get("symbol"),
            magic=magic,
            risk_percent=risk,
            tf=tf,
            ex5_path=s.get("ex5_path"),
            ex5_sha256=(s.get("ex5_sha256") or s.get("binary_sha") or s.get("binary_sha256")),
        ))
    # Expected account: explicit field wins; else account digits embedded in book.
    if cli_account:
        account, account_src = cli_account, "cli"
    elif data.get("expected_account") or data.get("account"):
        account = data.get("expected_account") or data.get("account")
        account_src = "manifest_field"
    elif _book_to_account(data.get("book")):
        account = _book_to_account(data.get("book"))
        account_src = "book_digits"
    else:
        account, account_src = None, "absent"
    server = cli_server or data.get("expected_server") or data.get("server")
    epoch = cli_epoch or data.get("deployment_epoch") or data.get("deployed_at_utc")
    epoch_source = ("cli" if cli_epoch else
                    ("manifest" if (data.get("deployment_epoch") or data.get("deployed_at_utc"))
                     else "absent"))
    signed = data.get("signed")
    if signed is None:
        # DRAFT/STAGE_ONLY manifests are not signed; a LIVE status with an
        # approver line is the closest thing to a signature these manifests carry.
        if str(data.get("status", "")).upper() == "LIVE" and data.get("approved_by"):
            signed = True
        elif str(data.get("status", "")).upper() in ("DRAFT", "STAGE_ONLY", "STAGE"):
            signed = False
    return ManifestInfo(
        path=path,
        file_sha256=sha256_file(path),
        declared_status=data.get("status"),
        declared_approved_by=data.get("approved_by"),
        declared_signed=signed,
        declared_signature=data.get("signature") or data.get("manifest_sha256"),
        book=data.get("book"),
        expected_account=str(account) if account is not None else None,
        expected_account_source=account_src,
        expected_server=str(server) if server is not None else None,
        deployment_epoch=epoch,
        deployment_epoch_source=epoch_source,
        sleeves=sleeves,
    )


# ---------------------------------------------------------------------------
# Runtime event-log truth.
# ---------------------------------------------------------------------------
LIFECYCLE_ATTACH = "INIT_OK"
LIFECYCLE_DETACH = "DEINIT"


@dataclass
class RuntimeSleeve:
    magic: int
    ea_id: Optional[int]
    expected_symbol: Optional[str]
    log_path: Optional[str]
    log_exists: bool
    last_event: Optional[str] = None
    last_ts_utc: Optional[str] = None
    last_init_ok_utc: Optional[str] = None
    last_deinit_utc: Optional[str] = None
    n_init_ok: int = 0
    runtime_symbol: Optional[str] = None
    identity_symbol_match: Optional[bool] = None
    state: str = "ABSENT"          # ATTACHED_FRESH | ATTACHED_STALE | DETACHED | ABSENT
    fresh: Optional[bool] = None


def _parse_iso_utc(s: Optional[str]) -> Optional[_dt.datetime]:
    if not s:
        return None
    try:
        s2 = s.replace("Z", "+00:00")
        d = _dt.datetime.fromisoformat(s2)
        if d.tzinfo is None:
            d = d.replace(tzinfo=_dt.timezone.utc)
        return d.astimezone(_dt.timezone.utc)
    except ValueError:
        return None


def _index_event_logs(event_log_dir: str) -> Dict[int, str]:
    """Map ea_id -> newest matching QM5_<eaid>_ea-*.log path."""
    out: Dict[int, str] = {}
    pattern = os.path.join(event_log_dir, "QM5_*_ea-*.log")
    for f in glob.glob(pattern):
        m = re.match(r"QM5_(\d+)_ea", os.path.basename(f))
        if not m:
            continue
        eaid = int(m.group(1))
        prev = out.get(eaid)
        if prev is None or os.path.getmtime(f) > os.path.getmtime(prev):
            out[eaid] = f
    return out


def scan_runtime(magic: int, ea_id: Optional[int], expected_symbol: Optional[str],
                 log_index: Dict[int, str], now_utc: _dt.datetime,
                 epoch_dt: Optional[_dt.datetime], freshness_hours: float) -> RuntimeSleeve:
    log_path = log_index.get(ea_id) if ea_id is not None else None
    rt = RuntimeSleeve(magic=magic, ea_id=ea_id, expected_symbol=expected_symbol,
                       log_path=log_path, log_exists=bool(log_path and os.path.exists(log_path)))
    if not rt.log_exists:
        return rt
    last_init = None
    last_deinit = None
    with open(log_path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            # A single ea_id log can host several magics (multi-slot EAs); filter.
            if obj.get("magic") != magic:
                continue
            ev = obj.get("event")
            ts = obj.get("ts_utc")
            rt.last_event = ev
            rt.last_ts_utc = ts
            if obj.get("symbol"):
                rt.runtime_symbol = obj.get("symbol")
            if ev == LIFECYCLE_ATTACH:
                last_init = ts
                rt.n_init_ok += 1
            elif ev == LIFECYCLE_DETACH:
                last_deinit = ts
    rt.last_init_ok_utc = last_init
    rt.last_deinit_utc = last_deinit
    if expected_symbol is not None and rt.runtime_symbol is not None:
        rt.identity_symbol_match = _norm_symbol(rt.runtime_symbol) == _norm_symbol(expected_symbol)

    init_dt = _parse_iso_utc(last_init)
    deinit_dt = _parse_iso_utc(last_deinit)
    if init_dt is None:
        rt.state = "DETACHED" if deinit_dt is not None else "ABSENT"
        rt.fresh = False
        return rt
    attached = (deinit_dt is None) or (init_dt > deinit_dt)
    if not attached:
        rt.state = "DETACHED"
        rt.fresh = False
        return rt
    # attached on the timeline; is the attach fresh?
    if epoch_dt is not None:
        fresh = init_dt >= epoch_dt
    else:
        fresh = (now_utc - init_dt) <= _dt.timedelta(hours=freshness_hours)
    rt.fresh = fresh
    rt.state = "ATTACHED_FRESH" if fresh else "ATTACHED_STALE"
    return rt


def _norm_symbol(sym: Optional[str]) -> Optional[str]:
    if sym is None:
        return None
    s = sym.strip()
    for suf in SYMBOL_SUFFIXES:
        if s.upper().endswith(suf.upper()):
            return s[: -len(suf)].upper()
    return s.upper()


# ---------------------------------------------------------------------------
# Findings.
# ---------------------------------------------------------------------------
CRITICAL, WARN, INFO = "CRITICAL", "WARN", "INFO"


def _finding(severity, category, layer, detail, magic=None, ea_id=None, symbol=None,
             chart=None, evidence=None) -> dict:
    return {
        "severity": severity, "category": category, "layer": layer,
        "magic": magic, "ea_id": ea_id, "symbol": symbol, "chart": chart,
        "detail": detail, "evidence": evidence,
    }


# ---------------------------------------------------------------------------
# Main verification.
# ---------------------------------------------------------------------------
def verify(args) -> dict:
    now_utc = _dt.datetime.now(_dt.timezone.utc)
    findings: List[dict] = []

    ps_exe = getattr(args, "ps_exe", None) or find_powershell()
    if not ps_exe:
        raise RuntimeError("no PowerShell (pwsh/powershell) found; the shared .chr "
                           "parser module cannot be invoked")
    module_path = getattr(args, "module", None) or DEFAULT_MODULE
    if not os.path.exists(module_path):
        raise RuntimeError("shared parser module not found: %s" % module_path)

    manifest = load_manifest(args.manifest, args.expected_account, args.expected_server,
                             args.deployment_epoch)
    epoch_dt = _parse_iso_utc(manifest.deployment_epoch)

    # ----- expected sleeves keyed by magic; index by (ea_id, symbol) for wrong-magic -----
    expected_by_magic: Dict[int, ExpectedSleeve] = {}
    expected_by_ea_sym: Dict[Tuple[Optional[int], Optional[str]], ExpectedSleeve] = {}
    for sl in manifest.sleeves:
        if sl.magic is not None:
            expected_by_magic[sl.magic] = sl
        expected_by_ea_sym[(sl.ea_id, _norm_symbol(sl.symbol))] = sl

    # =====================================================================
    # LAYER A -- DISK-PROFILE TRUTH  (parsed by the shared PS grammar module)
    # =====================================================================
    parsed: List[ParsedChart] = parse_profile_charts(
        args.profile_dir, args.monitor_name, module_path, ps_exe)
    chart_files = [pc.file for pc in parsed]

    monitor_charts = [pc for pc in parsed if pc.is_monitor]
    unparseable = [pc for pc in parsed if not pc.parseable and not pc.is_monitor]
    trading_parsed = [pc for pc in parsed if pc.parseable and not pc.is_monitor]

    # disk map magic -> [charts]
    disk_by_magic: Dict[int, List[ParsedChart]] = {}
    for pc in trading_parsed:
        disk_by_magic.setdefault(pc.expert.magic, []).append(pc)

    disk_sleeves: List[dict] = []
    present = missing = duplicates = wrong = 0
    binary_unpinned = 0
    for sl in manifest.sleeves:
        rec: Dict[str, Any] = {
            "magic": sl.magic, "ea_id": sl.ea_id, "symbol": sl.symbol,
            "ea_label": sl.ea_label, "expected_tf": sl.tf,
            "expected_risk_percent": sl.risk_percent,
            "expected_binary_sha256": (sl.ex5_sha256.upper() if sl.ex5_sha256 else None),
        }
        charts = disk_by_magic.get(sl.magic, []) if sl.magic is not None else []
        if len(charts) == 0:
            rec["present"] = False
            rec["status"] = "MISSING"
            rec["observed"] = None
            missing += 1
            hint = None
            for u in unparseable:
                if u.expert and u.expert.magic == sl.magic:
                    hint = u.file
                    break
            rec["unparseable_hint"] = hint
            findings.append(_finding(
                CRITICAL, "MISSING_CHART", "disk",
                "no parseable chart carries magic %s (EA %s / %s%s)" % (
                    sl.magic, sl.ea_id, sl.symbol,
                    "; a chart file is present but UNPARSEABLE: %s" % hint if hint else ""),
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=hint,
                evidence=args.profile_dir))
            disk_sleeves.append(rec)
            continue
        if len(charts) > 1:
            rec["present"] = True
            rec["status"] = "DUPLICATE"
            rec["charts"] = [c.file for c in charts]
            duplicates += 1
            findings.append(_finding(
                CRITICAL, "DUPLICATE_CHART", "disk",
                "magic %s appears in %d charts: %s" % (
                    sl.magic, len(charts), ", ".join(c.file for c in charts)),
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol,
                chart=charts[0].file, evidence=args.profile_dir))
        pc = charts[0]
        ex = pc.expert
        observed = {
            "chart": pc.file, "symbol": pc.symbol, "tf": pc.tf,
            "period_type": pc.period_type, "period_size": pc.period_size,
            "name": ex.name, "expertmode": ex.expertmode, "magic": ex.magic,
            "risk_percent": ex.risk_percent,
            "risk_fixed": ex.risk_fixed, "portfolio_weight": ex.portfolio_weight,
            "binary_path": ex.path,
        }
        checks: Dict[str, Any] = {}
        checks["symbol"] = (_norm_symbol(pc.symbol) == _norm_symbol(sl.symbol))
        if not checks["symbol"]:
            findings.append(_finding(CRITICAL, "WRONG_SYMBOL", "disk",
                "chart symbol %r != manifest %r" % (pc.symbol, sl.symbol),
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=pc.file))
        if sl.tf:
            checks["tf"] = (pc.tf == sl.tf)
            if not checks["tf"]:
                findings.append(_finding(CRITICAL, "WRONG_TIMEFRAME", "disk",
                    "chart tf %r (pt=%s ps=%s) != manifest %r" % (pc.tf, pc.period_type, pc.period_size, sl.tf),
                    magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=pc.file))
        else:
            checks["tf"] = None  # manifest carries no explicit tf -> UNKNOWN, not a pass
        if sl.ea_label:
            checks["ea_name"] = (ex.name == sl.ea_label)
            if not checks["ea_name"]:
                findings.append(_finding(CRITICAL, "WRONG_EA", "disk",
                    "chart EA name %r != manifest label %r" % (ex.name, sl.ea_label),
                    magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=pc.file))
        checks["magic"] = True  # matched by construction
        checks["expertmode"] = (ex.expertmode == "1")
        if not checks["expertmode"]:
            findings.append(_finding(CRITICAL, "EXPERT_DISABLED", "disk",
                "expertmode=%r (expected 1) -- EA will not trade" % ex.expertmode,
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=pc.file))
        risk_fixed_ok = _to_float(ex.risk_fixed) == 0.0
        risk_pct_ok = None
        if sl.risk_percent is not None:
            obs = _to_float(ex.risk_percent)
            risk_pct_ok = (obs is not None and abs(obs - sl.risk_percent) <= RISK_TOL)
        checks["risk_fixed_zero"] = risk_fixed_ok
        checks["risk_percent"] = risk_pct_ok
        if not risk_fixed_ok:
            findings.append(_finding(CRITICAL, "WRONG_RISK", "disk",
                "RISK_FIXED=%r (live must be 0)" % ex.risk_fixed,
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=pc.file))
        if risk_pct_ok is False:
            findings.append(_finding(CRITICAL, "WRONG_RISK", "disk",
                "RISK_PERCENT=%r != manifest %s (tol %g)" % (ex.risk_percent, sl.risk_percent, RISK_TOL),
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=pc.file))
        # binary SHA (only if manifest pins it; else explicit UNKNOWN)
        bin_status = "UNKNOWN"
        observed_sha = None
        if ex.path:
            bin_abs = _resolve_binary(args.profile_dir, args.terminal_mql5_dir, ex.path)
            observed["binary_abs"] = bin_abs
            if bin_abs and os.path.exists(bin_abs):
                observed_sha = sha256_file(bin_abs)
        observed["binary_sha256"] = observed_sha
        if sl.ex5_sha256:
            exp = sl.ex5_sha256.upper()
            if observed_sha is None:
                bin_status = "UNKNOWN"
                findings.append(_finding(WARN, "BINARY_UNKNOWN", "disk",
                    "manifest pins binary SHA but deployed binary unreadable (path %r)" % (ex.path,),
                    magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=pc.file))
            elif observed_sha == exp:
                bin_status = "MATCH"
            else:
                bin_status = "MISMATCH"
                findings.append(_finding(CRITICAL, "WRONG_BINARY", "disk",
                    "deployed binary SHA %s != manifest %s" % (observed_sha, exp),
                    magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, chart=pc.file,
                    evidence=observed.get("binary_abs")))
        else:
            bin_status = "UNKNOWN_NO_MANIFEST_PIN"
            binary_unpinned += 1
        checks["binary"] = bin_status
        rec["observed"] = observed
        rec["checks"] = checks
        if len(charts) == 1:
            hard_ok = (checks["symbol"] and checks.get("expertmode") and risk_fixed_ok
                       and (checks.get("tf") in (True, None))
                       and (checks.get("ea_name") in (True, None))
                       and (risk_pct_ok in (True, None))
                       and bin_status in ("MATCH", "UNKNOWN", "UNKNOWN_NO_MANIFEST_PIN"))
            if hard_ok:
                rec["present"] = True
                rec["status"] = "OK"
                present += 1
            else:
                rec["present"] = True
                rec["status"] = "FIELD_MISMATCH"
                wrong += 1
        disk_sleeves.append(rec)

    if binary_unpinned:
        findings.append(_finding(INFO, "BINARY_UNKNOWN", "disk",
            "manifest pins no binary SHA for %d sleeve(s); observed SHAs are recorded in "
            "disk_profile.sleeves[].observed.binary_sha256 but cannot be verified against the manifest "
            "(add per-sleeve ex5_sha256 -- see deploy_stamp_contract)" % binary_unpinned,
            evidence=os.path.abspath(args.manifest)))

    # orphan charts: parseable trading charts whose magic is not expected
    orphan_charts: List[dict] = []
    for pc in trading_parsed:
        if pc.expert.magic not in expected_by_magic:
            alt = expected_by_ea_sym.get((_to_int(pc.expert.qm_ea_id), _norm_symbol(pc.symbol)))
            if alt is not None and alt.magic is not None:
                findings.append(_finding(CRITICAL, "WRONG_MAGIC", "disk",
                    "chart %s (EA %s / %s) derives magic %s but manifest expects %s" % (
                        pc.file, pc.expert.qm_ea_id, pc.symbol, pc.expert.magic, alt.magic),
                    magic=alt.magic, ea_id=alt.ea_id, symbol=pc.symbol, chart=pc.file,
                    evidence=os.path.join(args.profile_dir, pc.file)))
                orphan_charts.append({"chart": pc.file, "magic": pc.expert.magic,
                                      "classified": "WRONG_MAGIC", "expected_magic": alt.magic})
            else:
                findings.append(_finding(CRITICAL, "ORPHAN_CHART", "disk",
                    "chart %s carries magic %s (EA %s / %s) not present in the manifest" % (
                        pc.file, pc.expert.magic, pc.expert.qm_ea_id, pc.symbol),
                    magic=pc.expert.magic, ea_id=_to_int(pc.expert.qm_ea_id), symbol=pc.symbol,
                    chart=pc.file, evidence=os.path.join(args.profile_dir, pc.file)))
                orphan_charts.append({"chart": pc.file, "magic": pc.expert.magic,
                                      "classified": "ORPHAN"})

    unparseable_records = []
    for u in unparseable:
        unparseable_records.append({"chart": u.file, "empty": u.empty, "error": u.error,
                                    "n_experts": u.n_experts})
        findings.append(_finding(CRITICAL, "UNPARSEABLE_CHART", "disk",
            "chart %s is unparseable: %s" % (u.file, u.error),
            chart=u.file, evidence=os.path.join(args.profile_dir, u.file)))

    if len(monitor_charts) == 0:
        findings.append(_finding(CRITICAL, "MISSING_MONITOR", "disk",
            "no %s chart found in profile" % args.monitor_name, evidence=args.profile_dir))
        monitor_status = "MISSING"
    elif len(monitor_charts) > 1:
        findings.append(_finding(CRITICAL, "DUPLICATE_MONITOR", "disk",
            "%d %s charts found: %s" % (len(monitor_charts), args.monitor_name,
                                        ", ".join(m.file for m in monitor_charts)),
            evidence=args.profile_dir))
        monitor_status = "DUPLICATE"
    else:
        monitor_status = "OK"

    disk_status = _rollup([f for f in findings if f["layer"] == "disk"])

    # =====================================================================
    # LAYER B -- RUNTIME TRUTH
    # =====================================================================
    log_index = _index_event_logs(args.event_log_dir)
    runtime_sleeves: List[dict] = []
    for sl in manifest.sleeves:
        if sl.magic is None:
            continue
        rt = scan_runtime(sl.magic, sl.ea_id, sl.symbol, log_index, now_utc,
                          epoch_dt, args.freshness_hours)
        rtd = asdict(rt)
        runtime_sleeves.append(rtd)
        if rt.state == "ATTACHED_FRESH":
            pass
        elif rt.state == "ATTACHED_STALE":
            findings.append(_finding(WARN, "RUNTIME_STALE", "runtime",
                "last INIT_OK %s is not fresh (epoch/window); EA attached in a prior session only" % rt.last_init_ok_utc,
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, evidence=rt.log_path))
        elif rt.state == "DETACHED":
            findings.append(_finding(CRITICAL, "RUNTIME_DETACHED", "runtime",
                "last lifecycle event is DEINIT (%s); EA is NOT attached at runtime" % rt.last_deinit_utc,
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, evidence=rt.log_path))
        else:  # ABSENT
            findings.append(_finding(WARN, "RUNTIME_ABSENT", "runtime",
                "no INIT_OK/DEINIT lifecycle evidence for magic %s%s" % (
                    sl.magic, "" if rt.log_exists else " (no event log)"),
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, evidence=rt.log_path))
        if rt.identity_symbol_match is False:
            findings.append(_finding(CRITICAL, "RUNTIME_IDENTITY_MISMATCH", "runtime",
                "runtime symbol %r != expected %r for magic %s" % (
                    rt.runtime_symbol, sl.symbol, sl.magic),
                magic=sl.magic, ea_id=sl.ea_id, symbol=sl.symbol, evidence=rt.log_path))

    # terminal / monitor heartbeat + account identity
    login_ini, server_ini = read_common_ini(args.common_ini, module_path, ps_exe)
    snap = read_account_snapshot(args.account_snapshot)
    # UNKNOWN, not silent-pass, when the manifest carries no expectation.
    if manifest.expected_account is None:
        config_account_match: Optional[bool] = None
    elif login_ini is None:
        config_account_match = None
    else:
        config_account_match = (str(login_ini) == str(manifest.expected_account))
    if manifest.expected_server is None:
        config_server_match: Optional[bool] = None
    elif server_ini is None:
        config_server_match = None
    else:
        config_server_match = (str(server_ini).upper() == str(manifest.expected_server).upper())
    identity = {
        "expected_account": manifest.expected_account,
        "expected_account_source": manifest.expected_account_source,
        "expected_server": manifest.expected_server,
        "config_account": login_ini,
        "config_server": server_ini,
        "config_account_match": config_account_match,
        "config_server_match": config_server_match,
        "runtime_account": None,
        "terminal_heartbeat_utc": None,
        "terminal_heartbeat_age_sec": None,
        "terminal_heartbeat_fresh": None,
    }
    if config_account_match is False:
        findings.append(_finding(CRITICAL, "ACCOUNT_MISMATCH", "account",
            "common.ini Login=%s != expected %s" % (login_ini, manifest.expected_account),
            evidence=args.common_ini))
    if config_server_match is False:
        findings.append(_finding(CRITICAL, "SERVER_MISMATCH", "account",
            "common.ini Server=%s != expected %s" % (server_ini, manifest.expected_server),
            evidence=args.common_ini))
    if snap is not None:
        acc = snap.get("account_login")
        identity["runtime_account"] = acc
        hb = snap.get("time_utc") or snap.get("updated_utc")
        identity["terminal_heartbeat_utc"] = hb
        hb_dt = _parse_iso_utc(hb)
        if hb_dt is not None:
            age = (now_utc - hb_dt).total_seconds()
            identity["terminal_heartbeat_age_sec"] = round(age, 1)
            identity["terminal_heartbeat_fresh"] = age <= args.snapshot_stale_min * 60
            if age > args.snapshot_stale_min * 60:
                findings.append(_finding(WARN, "TERMINAL_SNAPSHOT_STALE", "runtime",
                    "AccountMonitor snapshot is %.0f min old (> %.0f) -- terminal/monitor heartbeat stale" % (
                        age / 60.0, args.snapshot_stale_min),
                    evidence=args.account_snapshot))
        if manifest.expected_account is not None and acc is not None and str(acc) != str(manifest.expected_account):
            findings.append(_finding(CRITICAL, "ACCOUNT_MISMATCH", "runtime",
                "account_snapshot account_login=%s != expected %s" % (acc, manifest.expected_account),
                evidence=args.account_snapshot))
    else:
        findings.append(_finding(WARN, "TERMINAL_SNAPSHOT_STALE", "runtime",
            "no readable account snapshot heartbeat", evidence=args.account_snapshot))

    runtime_status = _rollup([f for f in findings if f["layer"] in ("runtime", "account")])

    # =====================================================================
    # IDENTITY BINDING -- the exact tuple, with explicit UNKNOWNs.
    # =====================================================================
    n_sleeves = len(manifest.sleeves)
    n_pinned = sum(1 for s in manifest.sleeves if s.ex5_sha256)
    n_tf = sum(1 for s in manifest.sleeves if s.tf)
    account_known = manifest.expected_account is not None
    server_known = manifest.expected_server is not None
    epoch_known = manifest.deployment_epoch is not None
    binary_known = (n_sleeves > 0 and n_pinned == n_sleeves)
    signed_known = bool(manifest.declared_signed)
    identity_binding = {
        "expected_tuple": "(account, server, deployment_epoch, manifest_SHA, symbol, "
                          "timeframe, EA, EA_binary_SHA, magic, risk)",
        "account": {"known": account_known, "value": manifest.expected_account,
                    "source": manifest.expected_account_source},
        "server": {"known": server_known, "value": manifest.expected_server},
        "deployment_epoch": {"known": epoch_known, "value": manifest.deployment_epoch,
                             "source": manifest.deployment_epoch_source},
        "manifest_sha256": {"known": manifest.file_sha256 is not None,
                            "value": manifest.file_sha256},
        "manifest_signed": {"known": manifest.declared_signed is not None,
                            "value": manifest.declared_signed,
                            "status": manifest.declared_status,
                            "approved_by": bool(manifest.declared_approved_by)},
        "per_sleeve": {
            "symbol": {"known_count": sum(1 for s in manifest.sleeves if s.symbol), "total": n_sleeves},
            "timeframe": {"known_count": n_tf, "total": n_sleeves},
            "magic": {"known_count": sum(1 for s in manifest.sleeves if s.magic is not None), "total": n_sleeves},
            "risk": {"known_count": sum(1 for s in manifest.sleeves if s.risk_percent is not None), "total": n_sleeves},
            "ea_binary_sha256": {"known_count": n_pinned, "total": n_sleeves},
        },
        "fully_bound": bool(account_known and server_known and epoch_known
                            and binary_known and signed_known),
    }
    missing_fields = _identity_missing_fields(identity_binding)
    identity_binding["missing_fields"] = missing_fields

    # UNKNOWN findings (do not force RED, but forbid a "signed PASS" claim).
    if not account_known:
        findings.append(_finding(WARN, "ACCOUNT_EXPECTATION_UNKNOWN", "identity",
            "manifest pins no expected account (book=%r has no account digits); account "
            "identity cannot be bound -- add expected_account" % manifest.book,
            evidence=os.path.abspath(args.manifest)))
    if not server_known:
        findings.append(_finding(WARN, "SERVER_EXPECTATION_UNKNOWN", "identity",
            "manifest pins no expected_server; server identity cannot be bound "
            "(absent expected server is NOT a match) -- add expected_server",
            evidence=os.path.abspath(args.manifest)))
    if not epoch_known:
        findings.append(_finding(WARN, "DEPLOYMENT_EPOCH_UNKNOWN", "identity",
            "manifest pins no deployment_epoch; runtime freshness falls back to a %.0fh "
            "window and is heuristic, not epoch-bound -- add deployment_epoch" % args.freshness_hours,
            evidence=os.path.abspath(args.manifest)))
    if not binary_known:
        findings.append(_finding(WARN, "BINARY_IDENTITY_UNKNOWN", "identity",
            "manifest pins ex5_sha256 for %d/%d sleeve(s); deployed-binary identity is "
            "UNKNOWN for the rest -- add per-sleeve ex5_sha256" % (n_pinned, n_sleeves),
            evidence=os.path.abspath(args.manifest)))
    if manifest.declared_signed is False or (manifest.declared_signed is None and not manifest.declared_approved_by):
        findings.append(_finding(WARN, "MANIFEST_UNSIGNED", "identity",
            "manifest status=%r, signed=%r, approver=%s -- this run is a read-only "
            "diagnostic snapshot, NOT a signed deployment-contract PASS" % (
                manifest.declared_status, manifest.declared_signed,
                bool(manifest.declared_approved_by)),
            evidence=os.path.abspath(args.manifest)))

    # =====================================================================
    # ROLL-UP
    # =====================================================================
    n_crit = sum(1 for f in findings if f["severity"] == CRITICAL)
    n_warn = sum(1 for f in findings if f["severity"] == WARN)
    n_info = sum(1 for f in findings if f["severity"] == INFO)
    if n_crit > 0:
        overall = "RED"
    elif n_warn > 0:
        overall = "AMBER"
    else:
        overall = "GREEN"

    headline = _headline(overall, missing, duplicates, wrong, len(orphan_charts),
                         len(unparseable_records), monitor_status, n_crit, n_warn,
                         manifest, disk_sleeves, runtime_sleeves)

    # WS-E2 consumer vocabulary (live_chart_inventory.json). GREEN->ok, AMBER->drift,
    # RED->fail. `matched` = disk sleeves fully OK; `mismatches` = crit/warn findings.
    e2_status = {"GREEN": "ok", "AMBER": "drift", "RED": "fail"}.get(overall, "unknown")
    e2_mismatches = [
        {"magic": f["magic"], "category": f["category"], "layer": f["layer"],
         "severity": f["severity"], "detail": f["detail"]}
        for f in findings if f["severity"] in (CRITICAL, WARN)
    ]

    state = {
        "tool": TOOL_NAME,
        "version": TOOL_VERSION,
        "schema_version": SCHEMA_VERSION,
        "generated_utc": now_utc.isoformat(),
        # ---- WS-E2 live_chart_inventory.json consumer contract (top-level aliases) ----
        "checked_at_utc": now_utc.isoformat(),
        "status": e2_status,
        "overall": e2_status,
        "expected_charts": n_sleeves,
        "matched": present,
        "mismatches": e2_mismatches,
        # ---- rich verdict ----
        "trigger": args.trigger,
        "overall_status": overall,
        "resolved_paths": {
            "manifest": os.path.abspath(args.manifest),
            "profile_dir": os.path.abspath(args.profile_dir),
            "event_log_dir": os.path.abspath(args.event_log_dir),
            "account_snapshot": os.path.abspath(args.account_snapshot) if args.account_snapshot else None,
            "common_ini": os.path.abspath(args.common_ini) if args.common_ini else None,
            "shared_parser_module": os.path.abspath(module_path),
            "powershell": ps_exe,
            "database": "none (this tool opens no DB; strictly read-only filesystem)",
        },
        "manifest": {
            "path": os.path.abspath(args.manifest),
            "file_sha256": manifest.file_sha256,
            "declared_status": manifest.declared_status,
            "declared_signed": manifest.declared_signed,
            "declared_approved_by": manifest.declared_approved_by,
            "declared_signature": manifest.declared_signature,
            "book": manifest.book,
            "n_expected_sleeves": n_sleeves,
            "deployment_epoch": manifest.deployment_epoch,
            "deployment_epoch_source": manifest.deployment_epoch_source,
            "freshness_window_hours": args.freshness_hours,
        },
        "identity_binding": identity_binding,
        "identity": identity,
        "disk_profile": {
            "label": "DISK-PROFILE TRUTH (recovery profile on disk; NOT proof of runtime attachment)",
            "status": disk_status,
            "profile_dir": os.path.abspath(args.profile_dir),
            "chart_files_total": len(chart_files),
            "trading_parseable": len(trading_parsed),
            "unparseable": len(unparseable_records),
            "monitor_count": len(monitor_charts),
            "monitor_status": monitor_status,
            "expected_present_ok": present,
            "expected_missing": missing,
            "expected_field_mismatch": wrong,
            "duplicates": duplicates,
            "orphans": len(orphan_charts),
            "sleeves": disk_sleeves,
            "orphan_charts": orphan_charts,
            "unparseable_charts": unparseable_records,
        },
        "runtime": {
            "label": "RUNTIME TRUTH (fresh post-start INIT_OK / magic / EA identity heartbeats)",
            "status": runtime_status,
            "event_log_dir": os.path.abspath(args.event_log_dir),
            "n_logs_indexed": len(log_index),
            "sleeves": runtime_sleeves,
        },
        "findings": findings,
        "summary": {
            "critical": n_crit, "warn": n_warn, "info": n_info,
            "headline": headline,
        },
    }
    return state


def _identity_missing_fields(ib: dict) -> List[dict]:
    """The exact fields the manifest must add to make the run a signed PASS."""
    missing: List[dict] = []
    if not ib["account"]["known"]:
        missing.append({"scope": "manifest", "field": "expected_account",
                        "why": "bind the T_Live account login"})
    if not ib["server"]["known"]:
        missing.append({"scope": "manifest", "field": "expected_server",
                        "why": "bind the broker server (absent != match)"})
    if not ib["deployment_epoch"]["known"]:
        missing.append({"scope": "manifest", "field": "deployment_epoch",
                        "why": "ISO-8601 UTC; runtime INIT_OK must be >= this to be 'fresh'"})
    per = ib["per_sleeve"]
    if per["ea_binary_sha256"]["known_count"] < per["ea_binary_sha256"]["total"]:
        missing.append({"scope": "per_sleeve", "field": "ex5_sha256",
                        "why": "pin deployed-binary SHA-256 (%d/%d present)" % (
                            per["ea_binary_sha256"]["known_count"],
                            per["ea_binary_sha256"]["total"])})
    if per["timeframe"]["known_count"] < per["timeframe"]["total"]:
        missing.append({"scope": "per_sleeve", "field": "timeframe",
                        "why": "explicit TF token (%d/%d present; rest derived from set-name)" % (
                            per["timeframe"]["known_count"], per["timeframe"]["total"])})
    if not ib["manifest_signed"]["known"] or ib["manifest_signed"]["value"] is not True:
        missing.append({"scope": "manifest", "field": "signed/approved_by/signature",
                        "why": "OWNER signature + manifest SHA self-declaration; without it "
                               "this is a diagnostic snapshot, not a signed PASS"})
    return missing


def _resolve_binary(profile_dir: str, terminal_mql5_dir: Optional[str], rel_path: str) -> Optional[str]:
    """Resolve a chart expert `path=` (e.g. 'Experts\\Live EAs\\QM5_x.ex5') to an
    absolute path under the terminal MQL5 dir. If not given, infer it from the
    profile dir (…\\MQL5\\Profiles\\Charts\\<profile>)."""
    rel = rel_path.replace("\\", os.sep).replace("/", os.sep)
    if terminal_mql5_dir:
        return os.path.join(terminal_mql5_dir, rel)
    p = os.path.abspath(profile_dir)
    marker = os.sep + "Profiles" + os.sep + "Charts" + os.sep
    idx = p.lower().find(marker.lower())
    if idx == -1:
        return None
    mql5 = p[:idx]
    return os.path.join(mql5, rel)


def _to_float(v) -> Optional[float]:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _to_int(v) -> Optional[int]:
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def _rollup(layer_findings: List[dict]) -> str:
    if any(f["severity"] == CRITICAL for f in layer_findings):
        return "RED"
    if any(f["severity"] == WARN for f in layer_findings):
        return "AMBER"
    return "GREEN"


def _headline(overall, missing, duplicates, wrong, orphans, unparseable, monitor_status,
              n_crit, n_warn, manifest, disk_sleeves, runtime_sleeves) -> str:
    n = len(manifest.sleeves)
    ok = sum(1 for s in disk_sleeves if s.get("status") == "OK")
    attached = sum(1 for s in runtime_sleeves if s.get("state") == "ATTACHED_FRESH")
    bits = ["%s" % overall,
            "disk %d/%d ok" % (ok, n),
            "runtime %d/%d attached-fresh" % (attached, n),
            "monitor %s" % monitor_status]
    if missing:
        bits.append("%d MISSING" % missing)
    if unparseable:
        bits.append("%d UNPARSEABLE" % unparseable)
    if duplicates:
        bits.append("%d DUPLICATE" % duplicates)
    if orphans:
        bits.append("%d ORPHAN" % orphans)
    if wrong:
        bits.append("%d FIELD-MISMATCH" % wrong)
    return "; ".join(bits)


# ---------------------------------------------------------------------------
# Deploy-stamp contract (the fields tonight's manifest must add).
# ---------------------------------------------------------------------------
def render_deploy_stamp_contract(state: dict) -> str:
    ib = state["identity_binding"]
    m = state["manifest"]
    L: List[str] = []
    A = L.append
    A("# Deploy-stamp contract -- fields the signed manifest must carry")
    A("")
    A("Generated by `%s` v%s (%s) against:" % (state["tool"], state["version"], state["schema_version"]))
    A("")
    A("- manifest: `%s`" % m["path"])
    A("- manifest SHA-256: `%s`" % m["file_sha256"])
    A("- declared status: **%s** | signed: %s | approver present: %s" % (
        m["declared_status"], m["declared_signed"], bool(m["declared_approved_by"])))
    A("- expected sleeves: %d" % m["n_expected_sleeves"])
    A("")
    A("This run verifies the observed profile/runtime **consistency** it can see. It is a "
      "read-only diagnostic snapshot, **not** a signed deployment-contract PASS, until the "
      "manifest carries every field below. Each absent field is reported as an explicit "
      "UNKNOWN in `identity_binding`, never as a silent match.")
    A("")
    A("## Exact tuple to bind")
    A("`%s`" % ib["expected_tuple"])
    A("")
    A("## Currently bound")
    A("| element | bound? | value / source |")
    A("|---|---|---|")
    A("| account | %s | %s (source: %s) |" % (
        "YES" if ib["account"]["known"] else "**UNKNOWN**", ib["account"]["value"], ib["account"]["source"]))
    A("| server | %s | %s |" % (
        "YES" if ib["server"]["known"] else "**UNKNOWN**", ib["server"]["value"]))
    A("| deployment_epoch | %s | %s (source: %s) |" % (
        "YES" if ib["deployment_epoch"]["known"] else "**UNKNOWN**",
        ib["deployment_epoch"]["value"], ib["deployment_epoch"]["source"]))
    A("| manifest_SHA | %s | `%s` |" % (
        "YES" if ib["manifest_sha256"]["known"] else "**UNKNOWN**", ib["manifest_sha256"]["value"]))
    A("| manifest signed | %s | signed=%s status=%s |" % (
        "YES" if ib["manifest_signed"]["value"] is True else "**UNKNOWN/NO**",
        ib["manifest_signed"]["value"], ib["manifest_signed"]["status"]))
    per = ib["per_sleeve"]
    A("| per-sleeve symbol | %d/%d | |" % (per["symbol"]["known_count"], per["symbol"]["total"]))
    A("| per-sleeve timeframe | %d/%d | rest derived from set-name (add explicit token) |" % (
        per["timeframe"]["known_count"], per["timeframe"]["total"]))
    A("| per-sleeve magic | %d/%d | |" % (per["magic"]["known_count"], per["magic"]["total"]))
    A("| per-sleeve risk | %d/%d | |" % (per["risk"]["known_count"], per["risk"]["total"]))
    A("| per-sleeve EA_binary_SHA | %d/%d | **add ex5_sha256** |" % (
        per["ea_binary_sha256"]["known_count"], per["ea_binary_sha256"]["total"]))
    A("")
    A("## Fields tonight's deploy stamp MUST add")
    if not ib["missing_fields"]:
        A("- (none -- manifest is fully bound)")
    else:
        for mf in ib["missing_fields"]:
            A("- **%s** `%s` -- %s" % (mf["scope"], mf["field"], mf["why"]))
    A("")
    A("## WS-E2 coordination")
    A("- This tool writes its state to the WS-E2 consumer path "
      "`D:\\QM\\reports\\state\\live_chart_inventory.json` (top-level keys "
      "`checked_at_utc`, `status` in {ok,drift,fail,unknown}, `expected_charts`, `matched`, "
      "`mismatches[]`; schema `%s`)." % state["schema_version"])
    A("- The signed manifest itself must be the one the WS-E2 deployment pointer resolves: "
      "`tools/strategy_farm/config/live_deployment.json` (repo default) overridden by "
      "`D:\\QM\\reports\\state\\live_deployment_pointer.json` (runtime). WS-E2 must "
      "authenticate `signed`/`approved_by`/manifest SHA there, not merely `status`.")
    A("")
    A("_Read-only. No auto-correction. Scheduling is an ops action performed in the "
      "controlled window, not by this tool._")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------------------
# Human report.
# ---------------------------------------------------------------------------
def render_report(state: dict) -> str:
    L: List[str] = []
    A = L.append
    A("# Live Deployment Contract Verification -- %s" % state["overall_status"])
    A("")
    A("- tool: `%s` v%s (schema `%s`)" % (state["tool"], state["version"], state["schema_version"]))
    A("- generated (UTC): %s" % state["generated_utc"])
    A("- trigger: %s" % state["trigger"])
    A("- headline: **%s**" % state["summary"]["headline"])
    A("- WS-E2 lamp status: **%s** (matched %s/%s, %s mismatches)" % (
        state["status"], state["matched"], state["expected_charts"], len(state["mismatches"])))
    A("")
    A("## Resolved sources (read-only)")
    for k, v in state["resolved_paths"].items():
        A("- %s: `%s`" % (k, v))
    m = state["manifest"]
    A("")
    A("## Signed-manifest binding")
    A("- path: `%s`" % m["path"])
    A("- file SHA-256: `%s`" % m["file_sha256"])
    A("- declared status: %s | signed: %s | approver present: %s" % (
        m["declared_status"], m["declared_signed"], bool(m["declared_approved_by"])))
    A("- book: %s" % m["book"])
    A("- expected sleeves: %d" % m["n_expected_sleeves"])
    A("- deployment_epoch: %s (source: %s; freshness window %.1f h)" % (
        m["deployment_epoch"], m["deployment_epoch_source"], m["freshness_window_hours"]))
    ib = state["identity_binding"]
    A("")
    A("## Identity binding (exact tuple)")
    A("`%s`" % ib["expected_tuple"])
    A("- account: %s (%s) | server: %s | deployment_epoch: %s | manifest signed: %s" % (
        "KNOWN" if ib["account"]["known"] else "**UNKNOWN**",
        ib["account"]["source"],
        "KNOWN" if ib["server"]["known"] else "**UNKNOWN**",
        "KNOWN" if ib["deployment_epoch"]["known"] else "**UNKNOWN**",
        "YES" if ib["manifest_signed"]["value"] is True else "**UNKNOWN/NO**"))
    A("- per-sleeve EA_binary_SHA pinned: %d/%d | timeframe explicit: %d/%d" % (
        ib["per_sleeve"]["ea_binary_sha256"]["known_count"], ib["per_sleeve"]["ea_binary_sha256"]["total"],
        ib["per_sleeve"]["timeframe"]["known_count"], ib["per_sleeve"]["timeframe"]["total"]))
    A("- **fully_bound: %s**" % ib["fully_bound"])
    if ib["missing_fields"]:
        A("- fields the manifest must add (see deploy_stamp_contract):")
        for mf in ib["missing_fields"]:
            A("  - %s `%s` -- %s" % (mf["scope"], mf["field"], mf["why"]))
    idn = state["identity"]
    A("")
    A("## Account / server identity")
    A("- expected account: %s (%s) | common.ini Login: %s | match: %s" % (
        idn["expected_account"], idn["expected_account_source"], idn["config_account"],
        idn["config_account_match"]))
    A("- expected server: %s | common.ini Server: %s | match: %s" % (
        idn["expected_server"], idn["config_server"], idn["config_server_match"]))
    A("- runtime account (snapshot): %s | heartbeat UTC: %s | age: %ss | fresh: %s" % (
        idn["runtime_account"], idn["terminal_heartbeat_utc"],
        idn["terminal_heartbeat_age_sec"], idn["terminal_heartbeat_fresh"]))

    dp = state["disk_profile"]
    A("")
    A("## LAYER A -- %s" % dp["label"])
    A("- status: **%s**" % dp["status"])
    A("- chart files: %d | trading parseable: %d | unparseable: %d | monitor: %d (%s)" % (
        dp["chart_files_total"], dp["trading_parseable"], dp["unparseable"],
        dp["monitor_count"], dp["monitor_status"]))
    A("- present-ok: %d | missing: %d | field-mismatch: %d | duplicates: %d | orphans: %d" % (
        dp["expected_present_ok"], dp["expected_missing"], dp["expected_field_mismatch"],
        dp["duplicates"], dp["orphans"]))
    A("")
    A("| magic | ea | symbol | tf | status | chart | binary |")
    A("|---|---|---|---|---|---|---|")
    for s in dp["sleeves"]:
        obs = s.get("observed") or {}
        A("| %s | %s | %s | %s | %s | %s | %s |" % (
            s.get("magic"), s.get("ea_id"), s.get("symbol"), s.get("expected_tf"),
            s.get("status"), obs.get("chart") or s.get("unparseable_hint") or "-",
            (s.get("checks") or {}).get("binary", "-")))
    if dp["orphan_charts"]:
        A("")
        A("### Orphan / wrong-magic charts")
        for o in dp["orphan_charts"]:
            A("- %s: magic %s (%s%s)" % (o["chart"], o["magic"], o["classified"],
              "; expected %s" % o.get("expected_magic") if o.get("expected_magic") else ""))
    if dp["unparseable_charts"]:
        A("")
        A("### Unparseable charts")
        for u in dp["unparseable_charts"]:
            A("- %s: %s" % (u["chart"], u["error"]))

    rt = state["runtime"]
    A("")
    A("## LAYER B -- %s" % rt["label"])
    A("- status: **%s**" % rt["status"])
    A("- event logs indexed: %d" % rt["n_logs_indexed"])
    A("")
    A("| magic | ea | state | fresh | last_event | last_init_ok_utc | last_deinit_utc |")
    A("|---|---|---|---|---|---|---|")
    for s in rt["sleeves"]:
        A("| %s | %s | %s | %s | %s | %s | %s |" % (
            s.get("magic"), s.get("ea_id"), s.get("state"), s.get("fresh"),
            s.get("last_event"), s.get("last_init_ok_utc"), s.get("last_deinit_utc")))

    A("")
    A("## Findings (%d critical / %d warn / %d info)" % (
        state["summary"]["critical"], state["summary"]["warn"], state["summary"]["info"]))
    order = {CRITICAL: 0, WARN: 1, INFO: 2}
    for f in sorted(state["findings"], key=lambda x: order.get(x["severity"], 3)):
        A("- **%s** [%s/%s] magic=%s: %s" % (
            f["severity"], f["layer"], f["category"], f["magic"], f["detail"]))
    if not state["findings"]:
        A("- (none)")
    A("")
    A("_Disk-profile truth and runtime truth are reported separately and never conflated. "
      "The `.chr`/common.ini grammar is parsed by the shared "
      "`liveops_profile_contract.ps1` module (also used by the two PowerShell verifiers). "
      "This tool performs no auto-correction and writes only its own outputs._")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------------------
# CLI.
# ---------------------------------------------------------------------------
def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--manifest", required=True, help="signed deployment manifest JSON")
    p.add_argument("--profile-dir", default=DEFAULT_PROFILE_DIR, help="MT5 Profiles\\Charts\\<profile> dir")
    p.add_argument("--event-log-dir", default=DEFAULT_EVENT_LOG_DIR, help="MQL5\\Files\\QM event-log dir")
    p.add_argument("--account-snapshot", default=DEFAULT_ACCOUNT_SNAPSHOT, help="AccountMonitor account_snapshot.json")
    p.add_argument("--common-ini", default=DEFAULT_COMMON_INI, help="MT5 config\\common.ini for Login/Server")
    p.add_argument("--terminal-mql5-dir", default=None,
                   help="MQL5 root for resolving chart binary paths (default: inferred from --profile-dir)")
    p.add_argument("--module", default=DEFAULT_MODULE,
                   help="shared liveops_profile_contract.ps1 (single .chr parser)")
    p.add_argument("--ps-exe", default=None, help="PowerShell executable (default: auto-detect pwsh/powershell)")
    p.add_argument("--monitor-name", default=DEFAULT_MONITOR_NAME, help="expected AccountMonitor EA name")
    p.add_argument("--expected-account", default=None, help="override expected account login")
    p.add_argument("--expected-server", default=None, help="override expected server")
    p.add_argument("--deployment-epoch", default=None,
                   help="ISO-8601 UTC deployment epoch; INIT_OK must be >= this to be 'fresh'")
    p.add_argument("--freshness-hours", type=float, default=DEFAULT_FRESHNESS_HOURS,
                   help="if no epoch: an INIT_OK within this many hours of now is 'fresh'")
    p.add_argument("--snapshot-stale-min", type=float, default=DEFAULT_SNAPSHOT_STALE_MIN,
                   help="AccountMonitor snapshot older than this many minutes is stale")
    p.add_argument("--trigger", default="manual", choices=["manual", "periodic", "post_recovery"],
                   help="label recorded in the state JSON (scheduling is external)")
    p.add_argument("--json-out", default=None, help="write state JSON here")
    p.add_argument("--report-out", default=None, help="write human report here")
    p.add_argument("--deploy-stamp-out", default=None, help="write the deploy-stamp contract markdown here")
    p.add_argument("--quiet", action="store_true", help="do not print the report to stdout")
    return p


def main(argv: Optional[List[str]] = None) -> int:
    args = build_arg_parser().parse_args(argv)
    try:
        state = verify(args)
    except FileNotFoundError as exc:
        sys.stderr.write("verify_live_deployment_contract: input not found: %s\n" % exc)
        return 3
    except Exception as exc:  # pragma: no cover - defensive
        sys.stderr.write("verify_live_deployment_contract: tool error: %s\n" % exc)
        return 3

    if args.json_out:
        os.makedirs(os.path.dirname(os.path.abspath(args.json_out)), exist_ok=True)
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(state, fh, indent=2)
    report = render_report(state)
    if args.report_out:
        os.makedirs(os.path.dirname(os.path.abspath(args.report_out)), exist_ok=True)
        with open(args.report_out, "w", encoding="utf-8") as fh:
            fh.write(report)
    if args.deploy_stamp_out:
        os.makedirs(os.path.dirname(os.path.abspath(args.deploy_stamp_out)), exist_ok=True)
        with open(args.deploy_stamp_out, "w", encoding="utf-8") as fh:
            fh.write(render_deploy_stamp_contract(state))
    if not args.quiet:
        sys.stdout.write(report)
    # Hard-rail: print the resolved manifest + parser + DB line. This tool uses NO db.
    sys.stdout.write("\nRESOLVED manifest=%s sha256=%s | profile=%s | parser=%s | DB=none(read-only)\n" % (
        state["manifest"]["path"], state["manifest"]["file_sha256"],
        state["resolved_paths"]["profile_dir"], state["resolved_paths"]["shared_parser_module"]))

    return {"GREEN": 0, "AMBER": 1, "RED": 2}.get(state["overall_status"], 3)


if __name__ == "__main__":
    raise SystemExit(main())
