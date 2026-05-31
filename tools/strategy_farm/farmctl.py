"""Deterministic local controller for the QuantMechanica strategy farm.

The controller deliberately avoids background work and model calls. It owns
state and queues; humans/agents execute the current action and report artifacts
back into the filesystem.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import glob
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any

try:
    from cache_audit import has_ea_history_window
except ModuleNotFoundError:
    from tools.strategy_farm.cache_audit import has_ea_history_window

try:
    from phase_ids import phase_label, phase_qid
except ModuleNotFoundError:
    from tools.strategy_farm.phase_ids import phase_label, phase_qid


DEFAULT_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
DB_REL = Path("state") / "farm_state.sqlite"
REPO_ROOT = Path(__file__).resolve().parents[2]
FRAMEWORK_EAS_DIR = REPO_ROOT / "framework" / "EAs"
P5_CALIBRATION_JSON = REPO_ROOT / "framework" / "calibrations" / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"
MT5_ROOT = Path(os.environ.get("QM_MT5_ROOT", r"D:\QM\mt5"))
PROMPTS_DIR = Path(__file__).resolve().parent / "prompts"
CLAUDE_RESEARCH_TEMPLATE = PROMPTS_DIR / "claude_research_source.md"
CODEX_BUILD_TEMPLATE = PROMPTS_DIR / "codex_build_ea.md"
CODEX_RESEARCH_TEMPLATE = PROMPTS_DIR / "codex_research_source.md"
CLAUDE_REVIEW_TEMPLATE = PROMPTS_DIR / "claude_review_ea.md"
CODEX_REVIEW_TEMPLATE = PROMPTS_DIR / "codex_review_ea.md"
CODEX_G0_TEMPLATE = PROMPTS_DIR / "codex_g0_review.md"

PIPELINE_REPORT_ROOT = Path(r"D:\QM\reports\pipeline")

# 2026-05-23 OR3 — post-pipeline-rewrite Qxx canonical phase set.
# Vault: 03 Pipeline/Pipeline Overview.md
# Wipe (DL-063 + PIPELINE_REWRITE_PROPOSAL_2026-05-23) cleared all legacy
# work_items, so the storage layer now writes Qxx directly. Legacy P-key
# references in classify_* / report-csv paths remain inert (no rows to read).
SUPPORTED_BACKTEST_PHASES = ("Q02", "Q03", "Q04")
CASCADE_BACKTEST_PHASES = ("Q05", "Q06", "Q07", "Q08", "Q09", "Q10")
REAL_PHASE_RUNNER_PHASES = ("Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10")
PHASE_RUNNER_SCRIPTS = {
    "Q02": "p2_baseline.py",            # verdict rewritten for PF>1.20/T>150/DD<15%
    "Q03": "p3_param_sweep.py",         # unchanged behaviour, phase-tag renamed
    "Q04": "q04_walkforward.py",        # NEW: anchored 3-fold + $7/lot commission
    "Q05": "q05_stress_medium.py",      # NEW: slip+2/spread×2/comm×2
    "Q06": "q06_stress_harsh.py",       # NEW: slip5/spread×3/comm×3/10% reject
    "Q07": "q07_multiseed.py",          # NEW: 5 seeds, PF variance < 20%
    "Q08": "q08_davey/aggregate.py",    # NEW: 10 Davey sub-gates
    "Q09": "q09_news_mode.py",          # TODO: news-mode sweep runner
    "Q10": "q10_confirmation.py",       # NEW: full-history canonical + baseline capture
}
NEWS_MATRIX_FALLBACK = Path(r"D:\QM\data\news_calendar\news_matrix.csv")
NEWS_CALENDAR_CANDIDATES = (
    Path(r"D:\QM\data\news_calendar\news_calendar.csv"),
    Path(r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv"),
    Path(r"D:\QM\data\news_calendar\forex_factory_calendar_clean.csv"),
)
P5_REQUIRED_OOS_FROM_YEAR = 2023
P5_REQUIRED_OOS_TO_YEAR = 2025
P5PLUS_MAX_DRAWDOWN_PCT = 20.0
P5PLUS_MIN_SHARPE = 0.6
FACTORY_TERMINAL_PATTERN = re.compile(r"^T(?:[1-9]|10)$", re.IGNORECASE)
LIVE_TERMINAL_NAMES = {"T_LIVE", "T6_LIVE"}
MT5_TERMINALS = tuple(f"T{i}" for i in range(1, 11))  # factory fleet, T_Live is never a factory slot
MT5_WORK_ITEM_FEED_MULTIPLIER = 2
MT5_WORK_ITEM_MIN_FEED_DEPTH = 20
BUILD_BACKPRESSURE_PENDING_SOFT_LIMIT = 1000
BUILD_BACKPRESSURE_PENDING_HARD_LIMIT = 3000
BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT = 7
MAX_AUTO_CREATED_BUILDS_PER_PUMP = 1
MAX_PARALLEL_CLAUDE = 3
DIRTY_REPO_BUILD_GUARD_ENV = "QM_ALLOW_DIRTY_REPO_BUILDS"
DIRTY_REPO_GUARD_DETAIL_LIMIT = 20
ZERO_TRADE_DEAD_THRESHOLD = 0.80
ZERO_TRADE_DEAD_MIN_DONE = 5
ZERO_TRADE_REWORK_DEDUP_HOURS = 6
PHASE_ACTIVE_TIMEOUT_MIN = {
    # 2026-05-23 PT7 — tightened reaper budgets after the 60-min Q02 hang
    # incident (T2/T4/T8/T9 stuck for an hour because the per-MT5
    # `run_smoke.ps1 -TimeoutSeconds 1800` layer failed silently and this
    # layer was the only safety net, originally set to 6h for Q02).
    # New budgets are realistic upper bounds for the work, not theoretical
    # worst-cases — hangs auto-recycle fast even when the inner layer fails.
    "Q02": 45,     # one backtest per symbol; H1 full-history runs typically 5-20 min
    "Q03": 60,     # parameter-sweep config
    "Q04": 90,     # 3-fold walk-forward + commission
    "Q05": 60,     # MED stress, full history
    "Q06": 60,     # HARSH stress, full history
    "Q07": 120,    # 5 seeds × full history under HARSH stress
    "Q08": 30,     # Davey aggregator reads log; cheap
    "Q09": 120,    # news-mode sweep (1 or 7 modes)
    "Q10": 60,     # full-history canonical confirmation
}


def is_factory_terminal_name(value: Any) -> bool:
    terminal = str(value or "").upper()
    return bool(FACTORY_TERMINAL_PATTERN.fullmatch(terminal)) and terminal not in LIVE_TERMINAL_NAMES


def available_mt5_terminals(mt5_root: Path | None = None) -> tuple[str, ...]:
    root = mt5_root or MT5_ROOT
    terminals: list[str] = []
    for terminal in MT5_TERMINALS:
        if is_factory_terminal_name(terminal) and (root / terminal / "terminal64.exe").exists():
            terminals.append(terminal)
    return tuple(terminals)


def active_mt5_terminals(mt5_root: Path | None = None) -> tuple[str, ...]:
    installed = available_mt5_terminals(mt5_root)
    return installed if installed else tuple(t for t in MT5_TERMINALS if is_factory_terminal_name(t))


def _repo_dirty_status(root_path: Path = REPO_ROOT) -> dict[str, Any]:
    if os.environ.get(DIRTY_REPO_BUILD_GUARD_ENV) == "1":
        return {"blocked": False, "override": True, "entries": [], "count": 0}
    try:
        proc = subprocess.run(
            ["git", "-C", str(root_path), "status", "--porcelain=v1", "--untracked-files=normal"],
            capture_output=True,
            text=True,
            timeout=20,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception as exc:
        return {"blocked": True, "error": repr(exc), "entries": [], "count": 0}
    entries = [line for line in (proc.stdout or "").splitlines() if line.strip()]
    if proc.returncode != 0:
        return {
            "blocked": True,
            "error": (proc.stderr or proc.stdout or "").strip(),
            "entries": entries[:DIRTY_REPO_GUARD_DETAIL_LIMIT],
            "count": len(entries),
        }
    return {
        "blocked": bool(entries),
        "override": False,
        "entries": entries[:DIRTY_REPO_GUARD_DETAIL_LIMIT],
        "count": len(entries),
    }

# Known-good fallback paths for codex.cmd / claude.cmd. Required because
# scheduled tasks run as SYSTEM user, which has a minimal PATH that doesn't
# include npm globals (where these CLIs live). shutil.which() returns None
# under SYSTEM → spawned subprocesses fail with "'codex' is not recognized
# as an internal or external command". Try shutil.which first, then fall
# back to these.
_CODEX_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\codex.cmd")
_GEMINI_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\gemini.cmd")
_GEMINI_NODE_BUNDLE = Path(r"C:\Users\Administrator\AppData\Roaming\npm\node_modules\@google\gemini-cli\bundle\gemini.js")
_CLAUDE_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\claude.cmd")
_CODEX_HOME = Path(os.environ.get("CODEX_HOME", r"C:\Users\Administrator\.codex"))


def _resolve_codex() -> str:
    import shutil as _shutil
    p = _shutil.which("codex.cmd") or _shutil.which("codex")
    if p:
        return p
    if _CODEX_FALLBACK.exists():
        return str(_CODEX_FALLBACK)
    return "codex"  # let subprocess fail with a clear error


def _codex_env() -> dict[str, str]:
    """Environment for Codex subprocesses spawned by scheduled tasks.

    The pump runs as SYSTEM, while `codex login` refreshes the Administrator
    profile. Point Codex at the canonical auth/config dir explicitly so
    scheduled spawns use the same credentials as the interactive OWNER shell.
    """
    env = os.environ.copy()
    env["CODEX_HOME"] = str(_CODEX_HOME)
    return env


def _resolve_gemini_command() -> tuple[list[str], bool]:
    """Return a headless Gemini command and whether it needs shell=True.

    On Windows scheduled tasks, the npm .cmd shim can enter the Gemini CLI's
    pseudo-terminal path and fail with AttachConsole errors. Prefer direct
    node + bundle execution, which works in headless prompt mode.
    """
    import shutil as _shutil
    node = _shutil.which("node.exe") or _shutil.which("node")
    if node and _GEMINI_NODE_BUNDLE.exists():
        return [node, str(_GEMINI_NODE_BUNDLE)], False
    p = _shutil.which("gemini.cmd") or _shutil.which("gemini")
    if p:
        return [p], True
    if _GEMINI_FALLBACK.exists():
        return [str(_GEMINI_FALLBACK)], True
    return ["gemini"], True


def _gemini_env() -> dict[str, str]:
    env = os.environ.copy()
    env["USERPROFILE"] = r"C:\Users\Administrator"
    env["HOME"] = r"C:\Users\Administrator"
    env["HOMEDRIVE"] = "C:"
    env["HOMEPATH"] = r"\Users\Administrator"
    env.setdefault("GEMINI_DEFAULT_AUTH_TYPE", "oauth-personal")
    env.setdefault("TERM", "dumb")
    env.setdefault("NO_COLOR", "1")
    env.setdefault("FORCE_COLOR", "0")
    env.setdefault("CI", "1")
    return env


def _tail_has_current_codex_401(log: Path, auth_mtime: float, max_bytes: int = 4096) -> bool:
    """Return true only for 401s that happened after the current auth file."""
    pattern = re.compile(rb"401 Unauthorized")
    timestamp = re.compile(rb"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z)\b")
    log_mtime = log.stat().st_mtime
    with open(log, "rb") as fh:
        fh.seek(max(0, log.stat().st_size - max_bytes))
        tail = fh.read()
    for line in tail.splitlines():
        if not pattern.search(line):
            continue
        if auth_mtime <= 0:
            return True
        m = timestamp.match(line)
        if not m:
            continue
        try:
            seen_at = dt.datetime.fromisoformat(
                m.group(1).decode("ascii").replace("Z", "+00:00")
            ).timestamp()
        except (ValueError, UnicodeDecodeError):
            continue
        if seen_at >= auth_mtime:
            return True
    return False


def _codex_401_cutoff_mtime(auth_mtime: float) -> float:
    """Ignore 401s older than the currently deployed Codex spawn/auth setup."""
    try:
        return max(auth_mtime, Path(__file__).stat().st_mtime)
    except OSError:
        return auth_mtime


def _resolve_claude() -> str:
    import shutil as _shutil
    p = _shutil.which("claude.cmd") or _shutil.which("claude")
    if p:
        return p
    if _CLAUDE_FALLBACK.exists():
        return str(_CLAUDE_FALLBACK)
    return "claude"


def _claude_env() -> dict[str, str]:
    env = os.environ.copy()
    env["USERPROFILE"] = r"C:\Users\Administrator"
    env["HOME"] = r"C:\Users\Administrator"
    env["HOMEDRIVE"] = "C:"
    env["HOMEPATH"] = r"\Users\Administrator"
    env.setdefault("TERM", "dumb")
    env.setdefault("NO_COLOR", "1")
    env.setdefault("FORCE_COLOR", "0")
    env.setdefault("CI", "1")
    return env

RUNTIME_DIRS = [
    "queue",
    "state/locks",
    "artifacts/source_notes",
    "artifacts/cards_draft",
    "artifacts/cards_approved",
    "artifacts/builds",
    "artifacts/backtests",
    "artifacts/verdicts",
    "logs",
]

SEED_SOURCES = [
    {
        "priority": 10,
        "lane": "recovery",
        "source_type": "existing_ea",
        "uri": r"C:\QM\repo\framework\EAs\QM5_1006_davey-eu-day",
        "title": "QM5_1006 Davey EU day zero-trade recovery",
    },
    {
        "priority": 20,
        "lane": "research",
        "source_type": "web_forum",
        "uri": "https://www.forexfactory.com/",
        "title": "ForexFactory strategies and systems",
    },
    {
        "priority": 30,
        "lane": "research",
        "source_type": "web_forum",
        "uri": "https://forums.babypips.com/",
        "title": "BabyPips forum strategy research",
    },
    {
        "priority": 40,
        "lane": "research",
        "source_type": "mql5_codebase",
        "uri": "https://www.mql5.com/en/code/mt5",
        "title": "MQL5 CodeBase MT5 strategies",
    },
    {
        "priority": 50,
        "lane": "research",
        "source_type": "mql5_articles",
        "uri": "https://www.mql5.com/en/articles",
        "title": "MQL5 Articles strategy research",
    },
    {
        "priority": 60,
        "lane": "legacy",
        "source_type": "local_archive",
        "uri": r"G:\My Drive\QuantMechanica",
        "title": "Legacy QuantMechanica books and EAs",
    },
]


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def source_id(source: dict[str, Any]) -> str:
    raw = f"{source['source_type']}|{source['uri']}"
    return str(uuid.uuid5(uuid.NAMESPACE_URL, raw))


def root_from_args(args: argparse.Namespace) -> Path:
    return Path(args.root).resolve()


def db_path(root: Path) -> Path:
    return root / DB_REL


def connect(root: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path(root), timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def _is_sqlite_locked(exc: sqlite3.OperationalError) -> bool:
    return "locked" in str(exc).lower()


def _with_sqlite_write_retry(fn, retries: int = 8, base_sleep_seconds: float = 1.5):
    for attempt in range(1, retries + 1):
        try:
            return fn()
        except sqlite3.OperationalError as exc:
            if not _is_sqlite_locked(exc) or attempt == retries:
                raise
            time.sleep(min(30.0, base_sleep_seconds * attempt))
    raise RuntimeError("unreachable sqlite retry state")


def init_dirs(root: Path) -> None:
    for rel in RUNTIME_DIRS:
        (root / rel).mkdir(parents=True, exist_ok=True)


def init_db(root: Path) -> None:
    init_dirs(root)
    with connect(root) as conn:
        conn.executescript(
            """
            PRAGMA journal_mode=WAL;

            CREATE TABLE IF NOT EXISTS sources (
                id TEXT PRIMARY KEY,
                priority INTEGER NOT NULL,
                lane TEXT NOT NULL,
                source_type TEXT NOT NULL,
                uri TEXT NOT NULL,
                title TEXT NOT NULL,
                status TEXT NOT NULL CHECK (
                    status in ('pending', 'active', 'notes_ready', 'cards_ready', 'approved', 'rejected', 'done', 'blocked')
                ),
                notes_path TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(source_type, uri)
            );

            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                status TEXT NOT NULL CHECK (
                    status in ('pending', 'active', 'done', 'blocked', 'failed')
                ),
                source_id TEXT,
                card_id TEXT,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(source_id) REFERENCES sources(id)
            );

            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                event TEXT NOT NULL,
                detail_json TEXT NOT NULL
            );

            -- Per-(EA × symbol × phase × setfile) work units. One bundled
            -- `backtest_p<n>` task in `tasks` fans out into N rows here, one
            -- per setfile in the EA's sets/ dir. MT5 dispatcher claims rows
            -- one-by-one per free terminal — fail of one symbol no longer
            -- blocks the other 3, and the DB shows per-symbol state directly.
            -- Per OWNER 2026-05-16 vision: "endlose Liste, pro EA pro
            -- Symbol pro Phase, MT5 zieht raus, fail → ans Ende".
            CREATE TABLE IF NOT EXISTS work_items (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,             -- 'backtest' (more kinds later)
                phase TEXT NOT NULL,            -- 'P2', 'P3', etc.
                ea_id TEXT NOT NULL,            -- 'QM5_1049'
                symbol TEXT NOT NULL,           -- 'EURUSD.DWX'
                setfile_path TEXT NOT NULL,
                status TEXT NOT NULL CHECK (
                    status in ('pending', 'active', 'done', 'failed')
                ),
                verdict TEXT,                   -- PASS/FAIL/INVALID (NULL until done)
                attempt_count INTEGER NOT NULL DEFAULT 0,
                parent_task_id TEXT,            -- FK to tasks(id) — the bundled backtest task
                evidence_path TEXT,             -- path to smoke summary.json
                claimed_by TEXT,                -- factory terminal name (T1..T10) when active
                payload_json TEXT NOT NULL,     -- extra context
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(parent_task_id) REFERENCES tasks(id)
            );

            CREATE INDEX IF NOT EXISTS idx_work_items_status_kind
                ON work_items(status, kind);
            CREATE INDEX IF NOT EXISTS idx_work_items_parent
                ON work_items(parent_task_id);
            CREATE INDEX IF NOT EXISTS idx_work_items_ea_phase
                ON work_items(ea_id, phase);
            """
        )
        # --- migrations (idempotent) ---
        # 2026-05-16: per OWNER, Codex also does research in parallel with
        # Claude. assigned_worker disambiguates active sources so both workers
        # never claim the same row. Old rows have NULL = treat as 'claude'.
        try:
            conn.execute("ALTER TABLE sources ADD COLUMN assigned_worker TEXT")
        except sqlite3.OperationalError:
            pass  # already exists


def event(conn: sqlite3.Connection, entity_type: str, entity_id: str, name: str, detail: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO events(ts, entity_type, entity_id, event, detail_json)
        VALUES (?, ?, ?, ?, ?)
        """,
        (utc_now(), entity_type, entity_id, name, json.dumps(detail, sort_keys=True)),
    )


def parse_card_frontmatter(card_path: Path) -> dict[str, Any]:
    """Minimal YAML frontmatter parser for flat key:value Strategy Card fields.

    Returns a dict of the simple top-level keys (ea_id, slug, g0_status, r1..r4,
    pipeline_phase, last_updated). Skips list/dict values silently.
    """
    text = card_path.read_text(encoding="utf-8-sig")
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    block = m.group(1)
    result: dict[str, Any] = {}
    for line in block.splitlines():
        m2 = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+?)\s*$", line)
        if m2:
            key, val = m2.group(1), m2.group(2).strip()
            if val and not val.startswith("-") and val not in {"|", ">"}:
                result[key] = val.strip('"').strip("'")
    return result


def _find_approved_card_for_ea(root: Path, ea_id: str) -> Path | None:
    cards_dir = root / "artifacts" / "cards_approved"
    if not cards_dir.is_dir():
        return None
    matches = sorted(cards_dir.glob(f"{ea_id}_*.md"))
    return matches[0] if matches else None


def _read_csv_dicts_if_exists(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return [dict(row) for row in csv.DictReader(handle)]


def _read_csv_dicts_with_columns(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    if not path.exists():
        return [], []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), [dict(row) for row in reader]


def prebuild_validate_card(root: Path, card_path: Path, fm: dict[str, Any]) -> dict[str, Any]:
    """Hard gate before creating build_ea tasks.

    This prevents the expensive Codex/build/smoke path from discovering basic
    identity and research-quality drift after artifacts have already been made.
    """
    errors: list[str] = []
    warnings: list[str] = []
    ea_id = str(fm.get("ea_id") or "").strip()
    slug = str(fm.get("slug") or "").strip()

    approved_dir = (root / "artifacts" / "cards_approved").resolve()
    try:
        card_resolved = card_path.resolve()
        if approved_dir not in card_resolved.parents:
            errors.append(f"card_not_in_approved_dir:{card_path}")
    except Exception:
        errors.append(f"card_path_unresolvable:{card_path}")

    expected_prefix = f"{ea_id}_{slug}"
    if ea_id and slug and not card_path.stem.startswith(expected_prefix):
        errors.append(f"card_filename_mismatch:expected_prefix={expected_prefix}:actual={card_path.name}")

    if fm.get("g0_status") != "APPROVED":
        errors.append(f"g0_status_not_approved:{fm.get('g0_status')!r}")
    for key in ("r1_track_record", "r2_mechanical", "r3_data_available", "r4_ml_forbidden"):
        if str(fm.get(key) or "").upper() != "PASS":
            errors.append(f"{key}_not_PASS:{fm.get(key)!r}")
    try:
        expected_trades = int(str(fm.get("expected_trades_per_year_per_symbol") or "").strip())
        if expected_trades < 2:
            errors.append(f"expected_trades_too_low:{expected_trades}")
    except (TypeError, ValueError):
        errors.append("expected_trades_per_year_per_symbol_missing")
        expected_trades = 0

    try:
        card_text = card_path.read_text(encoding="utf-8", errors="ignore")
        inference_text = re.sub(
            r"(?im)^expected_trades_per_year_per_symbol\s*:\s*\d+\s*$",
            "",
            card_text,
        )
        inferred_trades = _infer_expected_trades_per_year_per_symbol(inference_text)
        if inferred_trades is not None and expected_trades > max(8, inferred_trades * 4):
            errors.append(
                "entry_frequency_implausible:"
                f"declared={expected_trades}:inferred={inferred_trades}"
            )
    except OSError:
        pass

    ea_rows = _read_csv_dicts_if_exists(REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv")
    for row in ea_rows:
        row_ea = str(row.get("ea_id") or row.get("id") or "").strip()
        if row_ea != ea_id:
            continue
        row_slug = str(row.get("slug") or row.get("ea_slug") or "").strip()
        if row_slug and slug and row_slug != slug:
            errors.append(f"ea_id_registry_slug_mismatch:{ea_id}:registry={row_slug}:card={slug}")

    magic_rows = _read_csv_dicts_if_exists(REPO_ROOT / "framework" / "registry" / "magic_numbers.csv")
    seen_magic: dict[str, str] = {}
    for row in magic_rows:
        magic = str(row.get("magic") or "").strip()
        owner = f"{row.get('ea_id') or ''}:{row.get('symbol_slot') or row.get('slot') or ''}:{row.get('symbol') or ''}"
        if not magic:
            continue
        if magic in seen_magic and seen_magic[magic] != owner:
            errors.append(f"magic_registry_duplicate:{magic}:{seen_magic[magic]}:{owner}")
        seen_magic[magic] = owner

    sibling_cards = sorted((root / "artifacts" / "cards_approved").glob(f"{ea_id}_*.md"))
    if len(sibling_cards) > 1:
        warnings.append(f"multiple_approved_cards_for_ea:{ea_id}:{[p.name for p in sibling_cards]}")

    return {"ok": not errors, "errors": errors, "warnings": warnings}


def strategy_card_fingerprint(card_path: Path, fm: dict[str, Any] | None = None) -> str:
    """Stable coarse fingerprint for research dedupe.

    The goal is not cryptographic identity. It catches duplicate theses that
    arrive from different agents with slightly different prose.
    """
    fm = fm or parse_card_frontmatter(card_path)
    text = card_path.read_text(encoding="utf-8", errors="ignore").lower()
    source = str(fm.get("source_id") or fm.get("source") or "").strip().lower()
    slug = str(fm.get("slug") or "").strip().lower()
    universe = ",".join(sorted(_card_universe_symbols(text)))
    timeframe_match = re.search(r"\b(?:m1|m5|m15|m30|h1|h4|d1|w1)\b", text, re.IGNORECASE)
    timeframe = timeframe_match.group(0).lower() if timeframe_match else ""
    thesis_terms = []
    for term in ("momentum", "mean reversion", "breakout", "carry", "seasonal", "volatility", "gap", "news", "fomc", "trend", "pairs", ):
        if term in text:
            thesis_terms.append(term.replace(" ", "-"))
    raw = "|".join([source, slug, universe, timeframe, ",".join(thesis_terms)])
    return re.sub(r"[^a-z0-9_.|,-]+", "-", raw).strip("-") or card_path.stem.lower()


STRATEGY_CARD_REQUIRED_FRONTMATTER = (
    "ea_id",
    "slug",
    "g0_status",
    "r1_track_record",
    "r2_mechanical",
    "r3_data_available",
    "r4_ml_forbidden",
    "expected_trades_per_year_per_symbol",
)

# CR1 2026-05-23 — relaxed per OWNER call. The Strategy Card Framework
# (canonical: G:/My Drive/QuantMechanica - Company Reference/05 Skills/
# qm-strategy-card-extraction.md) requires only mechanical Entry/Exit/Stop/
# Sizing + source citation. Previously we also demanded downstream-pipeline
# knowledge from card authors (Q08/Q11 risks, MQL5 implementation notes,
# falsification language, explicit Filters header) AND a "thesis" word —
# those are pipeline-test / authoring-style concerns, not gating concerns.
# Dropped: thesis, filters, falsification, q08_q11_risks, implementation_notes.
# Kept 5: market_universe / timeframe / entry / exit / risk — all directly
# required by the Skill spec to make the card mechanically implementable.
STRATEGY_CARD_REQUIRED_BODY_PATTERNS = {
    "market_universe": r"\b(universe|market|symbol|instrument|target_symbols)\b|\.DWX\b",
    "timeframe": r"\b(timeframe|period|bar|m1|m5|m15|m30|h1|h4|d1|w1)\b",
    "entry": r"\b(entry|enter|signal|trigger)\b",
    "exit": r"\b(exit|close|flatten|take profit|stop)\b",
    "risk": r"\b(risk|drawdown|position|sizing|stop)\b",
}


def strategy_card_schema_issues(card_path: Path, fm: dict[str, Any] | None = None) -> list[str]:
    """Return missing Strategy Card schema fields for build-ready gating."""
    fm = fm or parse_card_frontmatter(card_path)
    issues: list[str] = []
    for key in STRATEGY_CARD_REQUIRED_FRONTMATTER:
        if str(fm.get(key) or "").strip() == "":
            issues.append(f"schema_missing_frontmatter:{key}")

    text = card_path.read_text(encoding="utf-8", errors="ignore")
    for key, pattern in STRATEGY_CARD_REQUIRED_BODY_PATTERNS.items():
        if not re.search(pattern, text, re.IGNORECASE):
            issues.append(f"schema_missing_body:{key}")
    return issues


def ready_strategy_card_inventory(root: Path) -> dict[str, Any]:
    """Return build-ready card inventory and schema/dedupe diagnostics."""
    cards_approved = root / "artifacts" / "cards_approved"
    ready: list[dict[str, Any]] = []
    blocked: list[dict[str, Any]] = []
    fingerprints: dict[str, list[str]] = {}
    if not cards_approved.exists():
        return {
            "ready_count": 0,
            "approved_cards": 0,
            "ready_cards": [],
            "blocked_cards": [],
            "duplicate_fingerprints": {},
        }
    cards = sorted(cards_approved.glob("*.md"))
    for card in cards:
        try:
            fm = parse_card_frontmatter(card)
            check = prebuild_validate_card(root, card, fm)
            schema_issues = strategy_card_schema_issues(card, fm)
            fp = strategy_card_fingerprint(card, fm)
        except Exception as exc:
            blocked.append({"card": str(card), "errors": [f"inventory_exception:{exc!r}"], "warnings": []})
            continue
        entry = {
            "card": str(card),
            "ea_id": str(fm.get("ea_id") or ""),
            "slug": str(fm.get("slug") or ""),
            "fingerprint": fp,
        }
        errors = list(check.get("errors") or []) + schema_issues
        if check.get("ok") and not schema_issues:
            ready.append(entry)
            fingerprints.setdefault(fp, []).append(card.name)
        else:
            blocked.append({
                **entry,
                "errors": errors,
                "warnings": list(check.get("warnings") or []),
            })
    duplicates = {fp: names for fp, names in fingerprints.items() if len(names) > 1}
    return {
        "ready_count": len(ready),
        "approved_cards": len(cards),
        "ready_cards": ready[:25],
        "blocked_cards": blocked[:25],
        "blocked_count": len(blocked),
        "duplicate_fingerprints": duplicates,
    }


def _infer_expected_trades_per_year_per_symbol(card_text: str) -> int | None:
    """Conservative trade-frequency estimate from card text."""
    patterns = [
        r"expected_trades_per_year_per_symbol\s*:\s*(\d+)",
        r"expected[_ -]?trades.*?(?:per[_ -]?symbol).*?(\d+)",
        r"(\d+)\s*(?:trades|signals|entries)\s*(?:/|per)\s*(?:year|yr|annum)",
    ]
    for pat in patterns:
        m = re.search(pat, card_text, re.IGNORECASE | re.DOTALL)
        if m:
            try:
                return max(1, int(m.group(1)))
            except ValueError:
                pass
    if re.search(r"\b(daily|every day|each day)\b", card_text, re.IGNORECASE):
        return 100
    if re.search(r"\b(weekly|week of month|day of week)\b", card_text, re.IGNORECASE):
        return 40
    if re.search(r"\b(monthly|turn of month|month[- ]end|month[- ]start)\b", card_text, re.IGNORECASE):
        return 12
    if re.search(r"\b(quarterly|quarter[- ]end|earnings)\b", card_text, re.IGNORECASE):
        return 4
    if re.search(r"\b(annual|yearly|sell in may|halloween)\b", card_text, re.IGNORECASE):
        return 1
    return None


def _card_build_priority(root: Path, task_row: sqlite3.Row) -> tuple[int, int, str]:
    """Higher quality / more actionable cards get built first."""
    payload = json.loads(task_row["payload_json"] or "{}")
    card_path = Path(str(payload.get("card_path") or ""))
    fm = payload.get("frontmatter") if isinstance(payload.get("frontmatter"), dict) else {}
    if card_path.exists():
        try:
            fm = parse_card_frontmatter(card_path)
        except Exception:
            pass
    try:
        expected = int(str(fm.get("expected_trades_per_year_per_symbol") or 0))
    except (TypeError, ValueError):
        expected = 0
    r_passes = sum(1 for key in ("r1_track_record", "r2_mechanical", "r3_data_available", "r4_ml_forbidden")
                   if str(fm.get(key) or "").upper() == "PASS")
    # Negative because Python sorts ascending.
    return (-r_passes, -expected, str(task_row["updated_at"] or ""))


def _normalise_card_symbol(symbol: str) -> str:
    s = symbol.upper()
    if s.endswith(".DWX"):
        s = s[:-4]
    aliases = {
        "DAX": "GDAXI.DWX",
        "GER40": "GDAXI.DWX",
        "WTI": "XTIUSD.DWX",
    }
    if s in aliases:
        return aliases[s]
    return f"{s}.DWX"


def _card_universe_symbols(card_text: str) -> set[str]:
    universe_lines = [
        line for line in card_text.splitlines()
        if re.search(r"^\s*(?:Universe|Target symbol\(s\)|Target symbols?)\b", line, re.IGNORECASE)
    ]
    search_text = "\n".join(universe_lines) if universe_lines else card_text
    symbol_re = re.compile(
        r"\b("
        r"[A-Z]{3}USD|USD[A-Z]{3}|EURJPY|GBPJPY|AUDJPY|CADJPY|CHFJPY|NZDJPY|"
        r"XAUUSD|XTIUSD|WTI|NDX|WS30|GDAXI|GER40|DAX|UK100|SP500"
        r")(?:\.DWX)?\b"
    )
    return {_normalise_card_symbol(m.group(0)) for m in symbol_re.finditer(search_text)}


def _is_multi_asset_card(card_text: str, symbols: set[str]) -> bool:
    if len(symbols) < 2:
        return False
    return bool(re.search(r"multi[- ]asset|basket|universe", card_text, re.IGNORECASE))


def _expected_trades_per_year_for_ea(root: Path, ea_id: str) -> int:
    return _expected_trade_frequency_for_ea(root, ea_id)["expected_trades_per_year_per_symbol"]


def _expected_trade_frequency_for_ea(root: Path, ea_id: str) -> dict[str, int | str]:
    card = _find_approved_card_for_ea(root, ea_id)
    if not card:
        return {
            "expected_trades_per_year_per_symbol": 20,
            "expected_trades_per_year_card": 20,
            "card_universe_symbol_count": 1,
            "min_trade_scope": "per_symbol_default",
        }
    try:
        card_text = card.read_text(encoding="utf-8-sig")
        fm = parse_card_frontmatter(card)
        value = int(str(fm.get("expected_trades_per_year_per_symbol", "20")).strip())
        expected = max(1, value)
        symbols = _card_universe_symbols(card_text)
        if _is_multi_asset_card(card_text, symbols):
            return {
                "expected_trades_per_year_per_symbol": max(1, int(expected / len(symbols))),
                "expected_trades_per_year_card": expected,
                "card_universe_symbol_count": len(symbols),
                "min_trade_scope": "basket_scaled_from_card",
            }
        return {
            "expected_trades_per_year_per_symbol": expected,
            "expected_trades_per_year_card": expected,
            "card_universe_symbol_count": max(1, len(symbols)),
            "min_trade_scope": "per_symbol_card",
        }
    except Exception:
        return {
            "expected_trades_per_year_per_symbol": 20,
            "expected_trades_per_year_card": 20,
            "card_universe_symbol_count": 1,
            "min_trade_scope": "per_symbol_default",
        }


def _smoke_year_count(from_date: str | None, to_date: str | None, default_year: int) -> int:
    start = from_date or f"{default_year}.01.01"
    end = to_date or f"{default_year}.12.31"
    try:
        return max(1, int(end[:4]) - int(start[:4]) + 1)
    except Exception:
        return 1


def _effective_min_trades(root: Path, ea_id: str, from_date: str | None,
                          to_date: str | None, default_year: int) -> dict[str, int | str]:
    freq = _expected_trade_frequency_for_ea(root, ea_id)
    expected = int(freq["expected_trades_per_year_per_symbol"])
    years = _smoke_year_count(from_date, to_date, default_year)
    return {
        "expected_trades_per_year_per_symbol": expected,
        "expected_trades_per_year_card": int(freq["expected_trades_per_year_card"]),
        "card_universe_symbol_count": int(freq["card_universe_symbol_count"]),
        "min_trade_scope": str(freq["min_trade_scope"]),
        "smoke_year_count": years,
        "effective_min_trades": max(1, int(expected * years * 0.5)),
    }


def create_task(
    conn: sqlite3.Connection,
    kind: str,
    source_id: str | None,
    card_id: str | None,
    payload: dict[str, Any],
) -> str:
    task_id = str(uuid.uuid4())
    now = utc_now()
    conn.execute(
        """
        INSERT INTO tasks(id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
        VALUES (?, ?, 'pending', ?, ?, ?, ?, ?)
        """,
        (task_id, kind, source_id, card_id, json.dumps(payload, sort_keys=True), now, now),
    )
    event(conn, "task", task_id, "created", {"kind": kind, "card_id": card_id, "source_id": source_id})
    return task_id


def update_task(
    conn: sqlite3.Connection,
    task_id: str,
    status: str | None = None,
    payload_merge: dict[str, Any] | None = None,
) -> dict[str, Any] | None:
    row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    if row is None:
        return None
    payload = json.loads(row["payload_json"])
    if payload_merge:
        payload.update(payload_merge)
    new_status = status if status is not None else row["status"]
    conn.execute(
        "UPDATE tasks SET status = ?, payload_json = ?, updated_at = ? WHERE id = ?",
        (new_status, json.dumps(payload, sort_keys=True), utc_now(), task_id),
    )
    event(conn, "task", task_id, "updated", {"from": row["status"], "to": new_status})
    return {"id": task_id, "status": new_status, "payload": payload}


def seed_sources(root: Path, force: bool = False) -> dict[str, Any]:
    init_db(root)
    inserted = 0
    skipped = 0
    now = utc_now()
    with connect(root) as conn:
        if force:
            conn.execute("DELETE FROM sources")
            conn.execute("DELETE FROM tasks")
            event(conn, "farm", "sources", "seed_force_reset", {})
        for src in SEED_SOURCES:
            sid = source_id(src)
            try:
                conn.execute(
                    """
                    INSERT INTO sources(
                        id, priority, lane, source_type, uri, title, status,
                        notes_path, created_at, updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, 'pending', NULL, ?, ?)
                    """,
                    (
                        sid,
                        src["priority"],
                        src["lane"],
                        src["source_type"],
                        src["uri"],
                        src["title"],
                        now,
                        now,
                    ),
                )
                event(conn, "source", sid, "seeded", src)
                inserted += 1
            except sqlite3.IntegrityError:
                skipped += 1

    write_sources_jsonl(root)
    return {"inserted": inserted, "skipped": skipped, "root": str(root), "db": str(db_path(root))}


def rows_as_dicts(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    return [dict(row) for row in rows]


def write_sources_jsonl(root: Path) -> Path:
    init_db(root)
    out = root / "queue" / "sources.jsonl"
    with connect(root) as conn:
        rows = conn.execute(
            """
            SELECT priority, lane, source_type, uri, title, status, id
            FROM sources
            ORDER BY priority, created_at, id
            """
        ).fetchall()
    with out.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(dict(row), sort_keys=True) + "\n")
    return out


def status(root: Path) -> dict[str, Any]:
    init_db(root)
    with connect(root) as conn:
        counts = rows_as_dicts(
            conn.execute(
                "SELECT status, COUNT(*) AS count FROM sources GROUP BY status ORDER BY status"
            ).fetchall()
        )
        active = rows_as_dicts(
            conn.execute(
                """
                SELECT id, priority, lane, source_type, uri, title, status
                FROM sources
                WHERE status = 'active'
                ORDER BY priority, created_at, id
                """
            ).fetchall()
        )
        next_pending = conn.execute(
            """
            SELECT id, priority, lane, source_type, uri, title, status
            FROM sources
            WHERE status = 'pending'
            ORDER BY priority, created_at, id
            LIMIT 1
            """
        ).fetchone()
        task_counts = rows_as_dicts(
            conn.execute(
                "SELECT kind, status, COUNT(*) AS count FROM tasks GROUP BY kind, status ORDER BY kind, status"
            ).fetchall()
        )
    return {
        "root": str(root),
        "db": str(db_path(root)),
        "source_counts": counts,
        "active_sources": active,
        "next_pending_source": dict(next_pending) if next_pending else None,
        "task_counts": task_counts,
    }


def work_items_view(root: Path, status_filter: str | None = None,
                    ea_filter: str | None = None) -> dict[str, Any]:
    """Per-symbol queue view — answers "which (EA × symbol × phase)
    units are pending/active/done/failed right now?"

    Output is the work_items table with optional filters.
    """
    init_db(root)
    query = "SELECT id, kind, phase AS _runtime_phase_key, ea_id, symbol, status, verdict, attempt_count, parent_task_id, evidence_path, claimed_by, created_at, updated_at FROM work_items"
    where = []
    params: list[Any] = []
    if status_filter:
        where.append("status = ?")
        params.append(status_filter)
    if ea_filter:
        where.append("ea_id = ?")
        params.append(ea_filter)
    if where:
        query += " WHERE " + " AND ".join(where)
    query += " ORDER BY ea_id, phase, symbol"
    with connect(root) as conn:
        rows = rows_as_dicts(conn.execute(query, params).fetchall())
    summary: dict[str, dict[str, int]] = {}
    for r in rows:
        qid = phase_qid(r.get("_runtime_phase_key"))
        r.pop("_runtime_phase_key", None)
        r["phase"] = qid
        r["phase_display"] = qid
        r["phase_qid"] = qid
        key = f"{qid}_{r['status']}"
        if r.get('verdict'):
            key += f"_{r['verdict']}"
        summary[key] = summary.get(key, 0) + 1
    return {
        "items": rows,
        "summary": summary,
        "count": len(rows),
        "phase_display_rule": "Q-series display is canonical; runtime DB phase keys are hidden from this operator view.",
    }


def backfill_work_items(root: Path) -> dict[str, Any]:
    """One-shot: for every existing backtest_<phase> task in tasks, create
    matching work_items in the new table. Idempotent — skips parent_task_ids
    that already have work_items.

    For done tasks, also seed verdicts from the per-symbol report.csv rows
    so the work_items table reflects historical state.
    """
    init_db(root)
    created = 0
    skipped = 0
    seeded_verdicts = 0
    with connect(root) as conn:
        rows = conn.execute(
            "SELECT id, kind, status, payload_json FROM tasks WHERE kind LIKE 'backtest_%'"
        ).fetchall()
        for r in rows:
            existing = conn.execute(
                "SELECT COUNT(*) FROM work_items WHERE parent_task_id = ?",
                (r["id"],),
            ).fetchone()[0]
            if existing:
                skipped += 1
                continue
            payload = json.loads(r["payload_json"]) if r["payload_json"] else {}
            ea_id = payload.get("ea_id")
            phase = payload.get("phase") or r["kind"].replace("backtest_", "").upper()
            if not ea_id:
                continue
            surviving = payload.get("surviving_symbols")
            new_items, _skipped_items = _create_backtest_work_items(
                conn, parent_task_id=r["id"], root=root, ea_id=ea_id, phase=phase,
                surviving_symbols=surviving,
            )
            created += len(new_items)
            # Seed verdicts from report.csv if task done
            if r["status"] == "done":
                report_csv = None
                erp = payload.get("expected_report_path")
                if erp and Path(erp).exists():
                    report_csv = Path(erp)
                else:
                    glob_pat = payload.get("expected_report_glob")
                    if glob_pat:
                        ms = glob.glob(glob_pat)
                        if ms:
                            report_csv = Path(ms[0])
                sym_to_verdict = {}
                sym_to_evidence = {}
                if report_csv and report_csv.exists():
                    try:
                        with report_csv.open(encoding="utf-8") as f:
                            for csv_row in csv.DictReader(f):
                                sym = csv_row.get("symbol")
                                if sym and csv_row.get("verdict"):
                                    sym_to_verdict[sym] = csv_row["verdict"]
                                    sym_to_evidence[sym] = csv_row.get("evidence", "")
                    except Exception:
                        pass
                for item in new_items:
                    v = sym_to_verdict.get(item["symbol"])
                    if v:
                        conn.execute(
                            "UPDATE work_items SET status='done', verdict=?, evidence_path=?, updated_at=? WHERE id=?",
                            (v, sym_to_evidence.get(item["symbol"]) or "", utc_now(), item["id"]),
                        )
                        seeded_verdicts += 1
                    else:
                        # Parent task is done but per-symbol verdict can't be
                        # recovered from report.csv (file moved, format change,
                        # etc.). Mark work_item done with INVALID so the new
                        # per-symbol dispatcher doesn't try to re-run it.
                        conn.execute(
                            "UPDATE work_items SET status='done', verdict='INVALID', payload_json=?, updated_at=? WHERE id=?",
                            (json.dumps({"backfill_note": "parent_done_no_per_symbol_data"}), utc_now(), item["id"]),
                        )
        conn.commit()
    return {"created": created, "skipped_parents": skipped, "seeded_verdicts": seeded_verdicts}


def pipeline_view(root: Path) -> dict[str, Any]:
    """Per-EA lifecycle table — answers "where does each EA stand RIGHT NOW?"

    Aggregates state across the tasks table for every EA seen in build_ea +
    backtest_<phase> + ea_review rows. Output is one row per EA with columns:
      ea_id, slug (from build payload), card_status (approved/etc.),
      build_status, build_smoke, review_verdict, p2_verdict, p3_verdict, ...
      attempts (sum across tasks), terminal_state (which phase is active).

    Designed to be the single command OWNER runs to see the whole farm.
    """
    init_db(root)
    eas: dict[str, dict[str, Any]] = {}
    with connect(root) as conn:
        rows = conn.execute(
            "SELECT id, kind, status, payload_json, created_at, updated_at "
            "FROM tasks ORDER BY created_at"
        ).fetchall()
    for r in rows:
        payload = json.loads(r["payload_json"]) if r["payload_json"] else {}
        ea_id = payload.get("ea_id") or r["id"]
        if not ea_id:
            continue
        entry = eas.setdefault(ea_id, {
            "ea_id": ea_id,
            "slug": payload.get("slug") or "",
            "build": None,
            "review": None,
            "phases": {},          # phase_label → {status, verdict, attempts, surviving_symbols}
            "current_stage": "card",
            "total_attempts": 0,
            "last_activity": r["updated_at"],
        })
        if not entry["slug"] and payload.get("slug"):
            entry["slug"] = payload["slug"]
        if r["updated_at"] > entry["last_activity"]:
            entry["last_activity"] = r["updated_at"]
        entry["total_attempts"] += int(payload.get("attempt_count", 0))

        kind = r["kind"]
        if kind == "build_ea":
            build_result = payload.get("build_result")
            build_result_smoke = build_result.get("smoke_result") if isinstance(build_result, dict) else None
            entry["build"] = {
                "task_id": r["id"],
                "status": r["status"],
                "smoke": build_result_smoke or payload.get("smoke_result"),
                "blocked_reason": payload.get("blocked_reason"),
            }
            if r["status"] == "pending":
                entry["current_stage"] = "build_pending"
            elif r["status"] == "active":
                entry["current_stage"] = "building"
            elif r["status"] in ("done", ):
                entry["current_stage"] = "built"
            elif r["status"] in ("failed", "blocked"):
                entry["current_stage"] = f"build_{r['status']}"
        elif kind == "ea_review":
            verdict_doc = payload.get("verdict") or {}
            entry["review"] = {
                "task_id": r["id"],
                "status": r["status"],
                "verdict": verdict_doc.get("verdict"),
            }
            if r["status"] == "done":
                if verdict_doc.get("verdict") == "APPROVE_FOR_BACKTEST":
                    entry["current_stage"] = "review_approved"
                else:
                    entry["current_stage"] = f"review_{verdict_doc.get('verdict','?').lower()}"
        elif kind.startswith("backtest_"):
            phase = payload.get("phase") or kind.replace("backtest_", "").upper()
            classification = payload.get("classification") or {}
            entry["phases"][phase] = {
                "task_id": r["id"],
                "status": r["status"],
                "verdict": classification.get("verdict"),
                "attempts": int(payload.get("attempt_count", 0)),
                "surviving_symbols": classification.get("surviving_symbols", []),
            }
            if r["status"] == "pending":
                entry["current_stage"] = f"{phase}_pending"
            elif r["status"] == "active":
                entry["current_stage"] = f"{phase}_running"
            elif r["status"] == "done":
                entry["current_stage"] = f"{phase}_{(classification.get('verdict') or '?').lower()}"

    # Order: by ea_id ascending
    out = sorted(eas.values(), key=lambda e: e["ea_id"])
    summary = {
        "by_stage": {},
    }
    for e in out:
        s = e["current_stage"]
        summary["by_stage"][s] = summary["by_stage"].get(s, 0) + 1
    return {"eas": out, "summary": summary, "count": len(out)}


def _as_float_or_none(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    text = text.replace(",", "")
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if not match:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None


def _run_metric(run: dict[str, Any], keys: tuple[str, ...]) -> float | None:
    for key in keys:
        value = _as_float_or_none(run.get(key))
        if value is not None:
            return value
    return None


def _run_drawdown_pct(run: dict[str, Any]) -> float | None:
    explicit = _run_metric(run, ("max_drawdown_pct", "drawdown_pct", "max_dd_pct", "dd_pct"))
    if explicit is not None:
        return explicit
    raw = str(run.get("drawdown_raw") or run.get("max_drawdown_raw") or "")
    match = re.search(r"\(([-+]?\d+(?:\.\d+)?)%\)", raw)
    if match:
        return float(match.group(1))
    if "%" in raw:
        return _as_float_or_none(raw)
    return None


def _derive_p5plus_metric_verdict(runs: list[dict[str, Any]]) -> tuple[str, str]:
    net_profits = [
        value for value in (_run_metric(r, ("net_profit", "total_net_profit", "profit"))
            for r in runs)
        if value is not None
    ]
    if net_profits and sum(net_profits) <= 0.0:
        return "FAIL", "STRATEGY_UNPROFITABLE:unprofitable"

    stress_net_profit = None
    for run in runs:
        stress_net_profit = _run_metric(run, ("net_profit_stress", "stress_net_profit"))
        if stress_net_profit is not None:
            break
    if stress_net_profit is not None and stress_net_profit <= 0.0:
        return "FAIL", "STRATEGY_UNPROFITABLE:stress_unprofitable"

    drawdowns = [value for value in (_run_drawdown_pct(r) for r in runs) if value is not None]
    if drawdowns and max(drawdowns) > P5PLUS_MAX_DRAWDOWN_PCT:
        return "FAIL", "DD_EXCEEDED:dd_exceeded"

    sharpes = [
        value for value in (_run_metric(r, ("sharpe", "sharpe_ratio"))
            for r in runs)
        if value is not None
    ]
    if sharpes and (sum(sharpes) / len(sharpes)) < P5PLUS_MIN_SHARPE:
        return "FAIL", "SHARPE_INSUFFICIENT:sharpe_insufficient"

    return "PASS", ""


PHASE_NOMENCLATURE = {
    "Q00": "G0",
    "Q01": "P1",
    "Q02": "P2",
    "Q03": "P3",
    "Q04": "P3.5",
    "Q05": "P4",
    "Q06": "P5",
    "Q07": "P5b",
    "Q08": "P5c",
    "Q09": "P6",
    "Q10": "P7",
    "Q11": "P8",
    "Q12": "P9",
    "Q13": "P9b",
    "Q14": "P10",
}


def _normalize_phase(phase: str | None) -> str:
    """Map Q-series to P-series or return as-is."""
    p = str(phase or "").strip().upper()
    if p == "P5B":
        return "P5b"
    if p == "P5C":
        return "P5c"
    return PHASE_NOMENCLATURE.get(p, p)


def _derive_phase_runner_verdict(summary: dict[str, Any], min_trades: int = 5, phase: str | None = None) -> tuple[str, str]:
    """Derive honest work_item verdicts from real phase-runner result JSON."""
    raw_verdict = str(summary.get("verdict") or summary.get("result") or "").strip()
    verdict_upper = raw_verdict.upper()
    reason = str(summary.get("reason") or summary.get("criterion") or "").strip()
    phase_key = _normalize_phase(phase or summary.get("phase"))

    if verdict_upper in {"PENDING_IMPLEMENTATION", "PENDING_RUNNER"}:
        return verdict_upper, reason or "phase runner not implemented yet"
    if verdict_upper == "WAITING_INPUT":
        return verdict_upper, reason or "phase runner waiting for required input"
    if verdict_upper in {"INFRA_FAIL", "ERROR", "TIMEOUT"}:
        return "INFRA_FAIL", reason or raw_verdict or "phase_runner_infra_fail"
    if verdict_upper == "INVALID":
        return "INFRA_FAIL", reason or "phase_runner_invalid_report"
    if verdict_upper in {"FAIL", "NO_PASS_BASELINE", "NO_ELIGIBLE_MODE", "MULTI_SEED_FAIL"}:
        return "FAIL", reason or raw_verdict or "phase_runner_fail"
    if verdict_upper in {"REPORT_ONLY"}:
        return "REPORT_ONLY", reason or "report-only phase runner; no hard PASS verdict"
    if phase_key == "P8" and verdict_upper == "MODE_SELECTED":
        details = summary.get("details") or {}
        parameters = details.get("parameters") or {}
        mt5_metrics = details.get("mt5_mode_metrics") or {}
        if not parameters.get("run_mt5") or not mt5_metrics:
            return "INFRA_FAIL", reason or "p8_mode_selected_without_real_mt5_news_reruns"
        return "PASS", reason or "p8_real_mt5_news_replay_pass"

    if verdict_upper in {"PASS", "AUTO_PASS", "MULTI_SEED_PASS"}:
        return "PASS", reason

    if phase_key == "P4":
        folds = int(summary.get("wf_folds_completed") or summary.get("fold_count") or 0)
        trades = int(summary.get("oos_total_trades") or summary.get("total_trades") or 0)
        sharpe = summary.get("oos_sharpe")
        max_dd = summary.get("oos_max_dd_pct")
        net_profit = summary.get("oos_net_profit")
        if folds < 6:
            return "FAIL", reason or "wf_folds_below_6"
        if trades < min_trades:
            return "FAIL", reason or "MIN_TRADES_NOT_MET"
        if sharpe is not None and float(sharpe) < P5PLUS_MIN_SHARPE:
            return "FAIL", reason or "wf_oos_sharpe_below_gate"
        if max_dd is not None and float(max_dd) > P5PLUS_MAX_DRAWDOWN_PCT:
            return "FAIL", reason or "wf_oos_drawdown_exceeded"
        if net_profit is not None and float(net_profit) <= 0.0:
            return "FAIL", reason or "wf_oos_unprofitable"
        return "PASS", reason or "wf_oos_gates_met"

    if phase_key == "P5":
        clean = summary.get("clean_metrics") or {}
        stress = summary.get("stress_metrics") or {}
        stress_pf = float(stress.get("pf") or 0.0)
        stress_trades = int(float(stress.get("trade_count") or stress.get("trades") or 0))
        stress_profit = float(stress.get("net_profit") or 0.0)
        clean_trades = int(float(clean.get("trade_count") or clean.get("trades") or 0))
        if clean_trades < min_trades:
            return "FAIL", reason or "p5_clean_min_trades_not_met"
        if stress_trades < min_trades:
            return "FAIL", reason or "p5_stress_min_trades_not_met"
        if stress_pf < 1.0:
            return "FAIL", reason or "p5_stress_pf_below_1"
        if stress_profit <= 0.0:
            return "FAIL", reason or "p5_stress_unprofitable"
        return "PASS", reason or "p5_clean_stress_metrics_pass"

    if phase_key == "P5b":
        trials = int(summary.get("trial_count") or 0)
        if trials <= 0:
            return "FAIL", reason or "p5b_no_trials"
        real_runs = int(summary.get("real_mt5_run_count") or 0)
        fail_count = int(summary.get("failed_run_count") or 0)
        if real_runs <= 0:
            return "INFRA_FAIL", reason or "p5b_no_real_mt5_runs"
        if fail_count > 0:
            return "INFRA_FAIL", reason or f"p5b_failed_runs:{fail_count}"
        return "PASS", reason or "p5b_real_noise_runs_passed"

    if phase_key == "P6":
        seed_count = int(summary.get("seed_count") or 0)
        pass_count = int(summary.get("seed_pass_count") or 0)
        if seed_count <= 0:
            return "FAIL", reason or "p6_no_seed_rows"
        if pass_count <= 0:
            return "FAIL", reason or "p6_no_passing_seeds"
        if pass_count < seed_count:
            return "FAIL", reason or f"p6_mixed_not_robust:{pass_count}/{seed_count}"
        return "PASS", reason or "p6_all_seeds_pass"

    return "FAIL", reason or f"unknown_phase_runner_verdict:{raw_verdict or 'missing'}"


def _derive_verdict_from_summary(summary: dict[str, Any], min_trades: int = 5, phase: str | None = None) -> tuple[str, str]:
    """Single-symbol verdict from a run_smoke summary.json. Returns (verdict, reason).

    P2-P4 mirror p2_baseline's derive_verdict. P5+ additionally requires
    profitable OOS behavior and bounded drawdown when those metrics exist.
    """
    if "phase" in summary and "runs" not in summary:
        return _derive_phase_runner_verdict(summary, min_trades=min_trades, phase=phase)

    if summary.get("result") != "PASS":
        reasons = summary.get("reason_classes") or ["UNKNOWN"]
        infra_reasons = {
            "NO_HISTORY",
            "NO_HISTORY_LOG",
            "NO_REAL_TICKS",
            "REPORT_MISSING",
            "REPORT_PARSE_ERROR",
            "INVALID_REPORT",
            "INCOMPLETE_RUNS",
            "HISTORY_CONTEXT_INVALID",
            "TIMEOUT",
        }
        verdict = "INFRA_FAIL" if any(str(r).upper() in infra_reasons for r in reasons) else "FAIL"
        return verdict, "run_smoke_fail:" + ";".join(str(r) for r in reasons)
    if not summary.get("model4_log_marker_detected"):
        return "INFRA_FAIL", "G1_NO_REAL_TICKS"
    runs = summary.get("runs") or []
    if not runs:
        return "INFRA_FAIL", "no_runs_in_summary"
    trades = [int(r.get("total_trades", 0) or 0) for r in runs]
    is_p5plus = str(phase or "").upper() in {p.upper() for p in CASCADE_BACKTEST_PHASES}
    trade_gate_passed = sum(trades) >= min_trades if is_p5plus else any(t >= min_trades for t in trades)
    if not trade_gate_passed:
        return "FAIL", "MIN_TRADES_NOT_MET"
    if is_p5plus:
        return _derive_p5plus_metric_verdict(runs)
    return "PASS", ""


P2_UNPROFITABLE_SYMBOL_REASON = "P2_UNPROFITABLE_SYMBOL"
P2_SYMBOL_NO_HISTORY_REASON = "SYMBOL_NO_HISTORY_FOR_PERIOD"
P2_DEFAULT_FROM_YEAR = 2017
P2_DEFAULT_TO_YEAR = 2022
P2_PRESCREEN_MONTHS = 6
P2_PRESCREEN_TIMEOUT_SECONDS = 1800
P2_FULL_TIMEOUT_MIN_SECONDS = 7200
P2_FULL_TIMEOUT_MAX_SECONDS = 14400

# PT8 2026-05-23 — Q02 window must scale with strategy timeframe. Single-year
# H1 was enough for HF sleeves, but D1/W1/MN1 strategies trade O(1-50) times per
# year per symbol → 150-trade Q02 threshold is unreachable in a 1-year run.
# These windows are bounds, not requirements; explicit from_year/to_year in the
# payload still overrides.
Q02_FROM_YEAR_BY_PERIOD: dict[str, int] = {
    "M1":  2020, "M5":  2020, "M15": 2020, "M30": 2019,
    "H1":  2017, "H4":  2017,
    "D1":  2015, "W1":  2010, "MN1": 2005,
}
Q02_TO_YEAR_BY_PERIOD: dict[str, int] = {
    # All periods end at the same recent year — what changes is the start.
    "M1":  2024, "M5":  2024, "M15": 2024, "M30": 2024,
    "H1":  2024, "H4":  2024,
    "D1":  2024, "W1":  2024, "MN1": 2024,
}
Q02_SKIP_PRESCREEN_PERIODS: set[str] = {"D1", "W1", "MN1"}  # full run is cheap on slow TFs


def _summary_net_profit_total(summary: dict[str, Any]) -> float | None:
    values: list[float] = []
    for run in summary.get("runs") or []:
        if not isinstance(run, dict):
            continue
        for key in ("net_profit", "total_net_profit", "profit"):
            raw = run.get(key)
            if raw is None or isinstance(raw, bool):
                continue
            if isinstance(raw, (int, float)):
                values.append(float(raw))
                break
            text = str(raw).replace(",", "").strip()
            match = re.search(r"-?\d+(?:\.\d+)?", text)
            if match:
                values.append(float(match.group(0)))
                break
    return sum(values) if values else None


def _coerce_metric_float(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).replace("\xa0", "").replace(" ", "").replace(",", ".").strip()
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if not match:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None


def _coerce_metric_int(value: Any) -> int | None:
    numeric = _coerce_metric_float(value)
    if numeric is None:
        return None
    return int(numeric)


def _summary_recovered_stats(summary: dict[str, Any]) -> dict[str, Any]:
    """Extract dashboard-compatible stats from a run_smoke/phase summary."""
    metric_sources: list[dict[str, Any]] = []
    if isinstance(summary, dict):
        metric_sources.append(summary)
    for run in summary.get("runs") or []:
        if isinstance(run, dict):
            metric_sources.append(run)

    def first_float(*keys: str) -> float | None:
        for source in metric_sources:
            for key in keys:
                value = _coerce_metric_float(source.get(key))
                if value is not None:
                    return value
        return None

    def first_int(*keys: str) -> int | None:
        for source in metric_sources:
            for key in keys:
                value = _coerce_metric_int(source.get(key))
                if value is not None:
                    return value
        return None

    stats: dict[str, Any] = {}
    net_profit = first_float("net_profit", "total_net_profit", "profit", "oos_net_profit")
    total_trades = first_int("total_trades", "trades", "trade_count")
    profit_factor = first_float("profit_factor", "pf")
    drawdown = first_float("max_dd", "drawdown", "max_drawdown", "maximal_drawdown")

    if net_profit is not None:
        stats["net_profit"] = net_profit
    if total_trades is not None:
        stats["total_trades"] = total_trades
    if profit_factor is not None:
        stats["profit_factor"] = profit_factor
    if drawdown is not None:
        stats["max_dd"] = drawdown
        stats["drawdown"] = drawdown
    return stats


def _payload_with_pass_recovered_stats(
    payload: dict[str, Any],
    verdict: str,
    summary: dict[str, Any],
) -> dict[str, Any]:
    if verdict != "PASS":
        return payload
    stats = _summary_recovered_stats(summary)
    if not stats:
        return payload
    return {**payload, "recovered_stats": stats}


def _work_item_p2_net_profit(work_item: sqlite3.Row) -> float | None:
    evidence_path = work_item["evidence_path"]
    if not evidence_path:
        return None
    path = Path(evidence_path)
    if not path.exists():
        return None
    try:
        summary = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    return _summary_net_profit_total(summary)


def _filter_p2_profitable_symbols(
    conn: sqlite3.Connection,
    p2_parent_task_id: str,
    candidate_symbols: list[str],
) -> tuple[list[str], list[dict[str, Any]]]:
    """Return P2 PASS symbols whose summary.json net profit total is > 0."""
    if not candidate_symbols:
        return [], []
    candidate_set = set(candidate_symbols)
    rows = conn.execute(
        """
        SELECT * FROM work_items
        WHERE parent_task_id=? AND phase in ('Q02', 'P2') AND status='done' AND verdict='PASS'
        """,
        (p2_parent_task_id,),
    ).fetchall()
    profit_by_symbol: dict[str, float] = {}
    saw_symbol: set[str] = set()
    for row in rows:
        symbol = row["symbol"]
        if symbol not in candidate_set:
            continue
        saw_symbol.add(symbol)
        net_profit = _work_item_p2_net_profit(row)
        if net_profit is not None:
            profit_by_symbol[symbol] = profit_by_symbol.get(symbol, 0.0) + net_profit

    filtered: list[str] = []
    skipped: list[dict[str, Any]] = []
    for symbol in candidate_symbols:
        net_profit = profit_by_symbol.get(symbol)
        if net_profit is not None and net_profit > 0.0:
            filtered.append(symbol)
        else:
            skipped.append({
                "symbol": symbol,
                "reason": P2_UNPROFITABLE_SYMBOL_REASON,
                "p2_net_profit": net_profit,
                "p2_pass_work_item_found": symbol in saw_symbol,
            })
    return filtered, skipped


def _dwx_symbol_history_registry() -> dict[tuple[str, str], dict[str, Any]]:
    registry_path = REPO_ROOT / "framework" / "registry" / "dwx_symbol_history_ranges.csv"
    if not registry_path.exists():
        return {}
    out: dict[tuple[str, str], dict[str, Any]] = {}
    with registry_path.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            symbol = (row.get("symbol") or "").strip().upper()
            period = (row.get("period") or "").strip().upper()
            if not symbol or not period:
                continue
            try:
                first_year = int(str(row.get("first_year") or "").strip())
                last_year = int(str(row.get("last_year") or "").strip())
            except ValueError:
                continue
            out[(symbol, period)] = {
                "first_year": first_year,
                "last_year": last_year,
                "source_terminals": (row.get("source_terminals") or "").strip(),
            }
    return out


def _log_p2_history_filter(root: Path, message: str) -> None:
    log_path = root / "logs" / "p2_history_range_filter.log"
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8", newline="\n") as f:
            f.write(f"{utc_now()} {message}\n")
    except OSError:
        pass


def _p2_history_window_for_symbol(
    symbol: str,
    period: str,
    requested_from_year: int = P2_DEFAULT_FROM_YEAR,
    requested_to_year: int = P2_DEFAULT_TO_YEAR,
    registry: dict[tuple[str, str], dict[str, Any]] | None = None,
) -> dict[str, Any]:
    registry = _dwx_symbol_history_registry() if registry is None else registry
    symbol_key = symbol.strip().upper()
    period_key = period.strip().upper()
    entry = registry.get((symbol_key, period_key))
    if not entry:
        return {
            "skip": True,
            "reason": P2_SYMBOL_NO_HISTORY_REASON,
            "symbol": symbol_key,
            "period": period_key,
            "requested_from_year": requested_from_year,
            "requested_to_year": requested_to_year,
        }

    first_year = int(entry["first_year"])
    last_year = int(entry["last_year"])
    if requested_to_year < first_year or requested_from_year > last_year:
        return {
            "skip": True,
            "reason": P2_SYMBOL_NO_HISTORY_REASON,
            "symbol": symbol_key,
            "period": period_key,
            "requested_from_year": requested_from_year,
            "requested_to_year": requested_to_year,
            "first_year": first_year,
            "last_year": last_year,
        }

    from_year = max(requested_from_year, first_year)
    to_year = min(requested_to_year, last_year)
    return {
        "skip": False,
        "symbol": symbol_key,
        "period": period_key,
        "requested_from_year": requested_from_year,
        "requested_to_year": requested_to_year,
        "from_year": from_year,
        "to_year": to_year,
        "first_year": first_year,
        "last_year": last_year,
        "adjusted": (from_year, to_year) != (requested_from_year, requested_to_year),
    }


def _p2_prescreen_dates(to_year: int) -> tuple[str, str]:
    """Use the most recent six months inside the requested P2 history window."""
    return f"{to_year}.07.01", f"{to_year}.12.31"


def _p2_date_span_days(from_date: str, to_date: str) -> int:
    start = dt.datetime.strptime(from_date, "%Y.%m.%d").date()
    end = dt.datetime.strptime(to_date, "%Y.%m.%d").date()
    return max(1, (end - start).days + 1)


def _p2_full_timeout_seconds(payload: dict[str, Any], from_date: str, to_date: str) -> int:
    runtime_sec = float(payload.get("p2_prescreen_runtime_sec") or 0.0)
    prescreen_from = str(payload.get("p2_prescreen_from_date") or "")
    prescreen_to = str(payload.get("p2_prescreen_to_date") or "")
    if runtime_sec > 0 and prescreen_from and prescreen_to:
        try:
            prescreen_days = _p2_date_span_days(prescreen_from, prescreen_to)
            full_days = _p2_date_span_days(from_date, to_date)
            # Full P2 runs twice for determinism. Add 50% headroom above the
            # observed six-month real-tick runtime.
            estimated = int(runtime_sec * (full_days / prescreen_days) * 2 * 1.5)
            return max(P2_FULL_TIMEOUT_MIN_SECONDS, min(P2_FULL_TIMEOUT_MAX_SECONDS, estimated))
        except ValueError:
            pass
    return P2_FULL_TIMEOUT_MIN_SECONDS


def _p2_active_summary_runtime_sec(item_row: sqlite3.Row, summary: dict[str, Any]) -> float | None:
    launched = _parse_utc_datetime(item_row["updated_at"])
    completed_raw = summary.get("timestamp_utc")
    completed = _parse_utc_datetime(str(completed_raw)) if completed_raw else None
    if launched is None or completed is None:
        return None
    return max(0.0, (completed - launched).total_seconds())


# PT9 2026-05-23 — Q02 compile gate. Cheap inline mtime check first; full
# tools/strategy_farm/compile_ea.py subprocess fallback only when source is
# newer than the cached ex5 (i.e. the EA was edited since last compile). This
# closes the QM5_10005-style ex5_missing failure mode at the dispatch boundary
# instead of letting the backtest fail with FATAL missing EA binary downstream.
COMPILE_EA_SCRIPT = REPO_ROOT / "tools" / "strategy_farm" / "compile_ea.py"


def _compile_gate_check(ea_dir_name: str) -> dict[str, Any]:
    """Return {allowed: bool, verdict: str, source: 'mtime'|'subprocess'|'error'}.
    Fast path: if .ex5 exists with size > 0 and mtime >= .mq5 mtime, allow.
    Otherwise: delegate to compile_ea.py and parse its verdict."""
    ea_dir = REPO_ROOT / "framework" / "EAs" / ea_dir_name
    mq5 = ea_dir / f"{ea_dir_name}.mq5"
    ex5 = ea_dir / f"{ea_dir_name}.ex5"
    if not mq5.exists():
        return {"allowed": False, "verdict": "NO_MQ5", "source": "mtime",
                "ea_dir": str(ea_dir)}

    if ex5.exists():
        try:
            ex5_stat = ex5.stat()
            mq5_stat = mq5.stat()
            if ex5_stat.st_size > 0 and ex5_stat.st_mtime >= mq5_stat.st_mtime:
                return {"allowed": True, "verdict": "COMPILED_CACHED",
                        "source": "mtime", "ex5_path": str(ex5),
                        "ex5_size": ex5_stat.st_size}
        except OSError:
            pass

    # Source changed or ex5 missing — call compile_ea.py for fresh build + validator
    if not COMPILE_EA_SCRIPT.exists():
        return {"allowed": False, "verdict": "COMPILE_EA_SCRIPT_MISSING",
                "source": "error", "expected_path": str(COMPILE_EA_SCRIPT)}
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        proc = subprocess.run(
            [sys.executable, str(COMPILE_EA_SCRIPT), "--ea-label", ea_dir_name, "--json"],
            capture_output=True, text=True, timeout=180,
            creationflags=creationflags,
        )
    except subprocess.TimeoutExpired:
        return {"allowed": False, "verdict": "COMPILE_TIMEOUT", "source": "subprocess"}
    if not proc.stdout.strip():
        return {"allowed": False, "verdict": "COMPILE_NO_OUTPUT",
                "source": "subprocess", "stderr": (proc.stderr or "")[:200]}
    try:
        results = json.loads(proc.stdout)
        if not results:
            return {"allowed": False, "verdict": "COMPILE_EMPTY_RESULT",
                    "source": "subprocess"}
        r = results[0]
        verdict = r.get("verdict", "UNKNOWN")
        allowed = verdict in ("COMPILED", "COMPILED_CACHED")
        return {"allowed": allowed, "verdict": verdict, "source": "subprocess",
                "reason": r.get("reason", ""),
                "compile_log_path": r.get("compile_log_path", ""),
                "symbol_scope_verdict": r.get("symbol_scope_verdict", "")}
    except json.JSONDecodeError as exc:
        return {"allowed": False, "verdict": "COMPILE_BAD_JSON",
                "source": "subprocess", "error": repr(exc)[:200]}


def _spawn_run_smoke_for_work_item(root: Path, item_row: sqlite3.Row,
                                    terminal: str) -> dict[str, Any]:
    """Spawn run_smoke.ps1 for one work_item, pinned to a specific terminal.

    Returns dict with spawn metadata. The PID + log_path + expected_summary
    dir are stored in the work_item payload so the next dispatch cycle can
    find the result.
    """
    ea_id = item_row["ea_id"]  # e.g. QM5_1049
    symbol = item_row["symbol"]
    setfile_path = item_row["setfile_path"]
    phase = item_row["phase"]
    try:
        item_payload = json.loads(item_row["payload_json"] or "{}")
    except json.JSONDecodeError:
        item_payload = {}
    runner_symbol = str(item_payload.get("host_symbol") or symbol)
    runner_period = str(item_payload.get("host_timeframe") or _detect_ea_period(ea_id))

    if phase in REAL_PHASE_RUNNER_PHASES:
        report_root = Path(r"D:\QM\reports\work_items") / item_row["id"]
        report_root.mkdir(parents=True, exist_ok=True)
        timestamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
        safe_phase = re.sub(r"[^A-Za-z0-9_.-]+", "_", str(phase))
        safe_symbol = re.sub(r"[^A-Za-z0-9_.-]+", "_", str(symbol))
        log_path = root / "logs" / f"phase_runner_{safe_phase}_{ea_id}_{safe_symbol}_{timestamp}.log"
        log_path.parent.mkdir(parents=True, exist_ok=True)

        cmd = _phase_runner_cmd(
            phase,
            ea_id,
            terminal,
            surviving_symbols=[symbol],
            out_prefix=report_root,
            setfile_path=setfile_path,
        )
        if cmd is None:
            return {
                "spawned": False,
                "pending_runner": True,
                "reason": "phase runner not implemented yet -- skipping for now",
                "log_path": str(log_path),
                "report_root": str(report_root),
                "ea_dir_name": ea_id,
                "phase_runner": None,
            }

        log_fh = open(log_path, "w", encoding="utf-8")
        creationflags = 0
        if sys.platform == "win32":
            creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
        env = {**os.environ}
        env["PYTHONPATH"] = os.pathsep.join(
            [
                str(REPO_ROOT / "framework" / "scripts"),
                str(REPO_ROOT),
                env.get("PYTHONPATH", ""),
            ]
        )
        proc = subprocess.Popen(
            cmd,
            cwd=str(REPO_ROOT),
            stdout=log_fh,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            creationflags=creationflags,
            close_fds=True,
            env=env,
        )
        log_fh.close()
        return {
            "spawned": True,
            "pid": proc.pid,
            "log_path": str(log_path),
            "report_root": str(report_root),
            "ea_dir_name": ea_id,
            "phase_runner": cmd[1] if len(cmd) > 1 else None,
            "effective_min_trades": 5,
        }

    # Resolve full EA dir name (with slug) for the -EALabel arg
    ea_root_dir = REPO_ROOT / "framework" / "EAs"
    candidates = [p for p in ea_root_dir.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return {"spawned": False, "reason": f"no EA dir for {ea_id}"}
    ea_dir_name = candidates[0].name
    period = runner_period
    numeric_id = int(re.match(r"^QM5_(\d+)$", ea_id).group(1))

    # PT9 2026-05-23 — compile gate. For Q02 / P2 (entry-point phases), call
    # compile_ea.py to ensure the .ex5 is current + scope-clean before
    # dispatching the backtest. Inline mtime check first (fast); subprocess
    # fallback only when source changed or validator output stale. Closes the
    # ex5_missing class (QM5_10005-style: build never ran) and the
    # SYMBOL_SCOPE_LEAK class structurally.
    if phase in ("Q02", "P2"):
        gate = _compile_gate_check(ea_dir_name)
        if not gate["allowed"]:
            return {"spawned": False, "reason": f"compile_gate:{gate['verdict']}",
                    "compile_gate": gate}

    # Per-work-item report root keeps summaries discoverable
    report_root = Path(r"D:\QM\reports\work_items") / item_row["id"]
    report_root.mkdir(parents=True, exist_ok=True)
    log_path = root / "logs" / f"work_item_{item_row['id']}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)

    # OWNER 2026-05-17 iteration 7 throughput fix: backtests were taking
    # 41-61 min each because of (a) 6-year P2 window + (b) 2-run determinism
    # check. With 5 MT5 terminals, that's 5 work_items/hour. 64 pending →
    # 13h drain. Crippling for ablation/synth exploration.
    #
    # Fast-path for EXPLORATION children (ablation / grid / synth):
    #   - 1 run instead of 2 (skip determinism re-check; EA binary is same
    #     across siblings, original setfile got its check)
    #   - shorter window (2020-2022 = 3y instead of 2017-2022 = 6y)
    # Full-path for FIRST P2 (canonical _backtest.set, no exploration suffix):
    #   - Keep 2 runs + 6 years for rigor
    is_exploration = ("_ablation_" in setfile_path or "_grid_" in setfile_path
                      or "_synth_" in setfile_path)
    n_runs = "1" if is_exploration else "2"
    if phase in ("P2", "Q02"):
        # PT8 2026-05-23 — Q02 window now scales with detected period so D1/W1
        # strategies don't get a 1-year window they can't possibly produce
        # 150 trades on. H1 keeps the original 6-year span; D1/W1/MN1 stretch
        # back to 2015-2010-2005 respectively. Explicit from_year/to_year on
        # the work item still wins.
        period_upper = (period or "H1").upper()
        if phase == "Q02":
            default_from = Q02_FROM_YEAR_BY_PERIOD.get(period_upper, P2_DEFAULT_FROM_YEAR)
            default_to   = Q02_TO_YEAR_BY_PERIOD.get(period_upper, P2_DEFAULT_TO_YEAR)
        else:
            default_from = 2020 if is_exploration else P2_DEFAULT_FROM_YEAR
            default_to   = P2_DEFAULT_TO_YEAR
        from_year = int(item_payload.get("from_year") or default_from)
        to_year = int(item_payload.get("to_year") or default_to)
        from_date = f"{from_year}.01.01"
        to_date = f"{to_year}.12.31"
        skip_prescreen = (phase == "Q02" and period_upper in Q02_SKIP_PRESCREEN_PERIODS)
        if not is_exploration and not skip_prescreen and not item_payload.get("p2_prescreen_done"):
            from_date, to_date = _p2_prescreen_dates(to_year)
            n_runs = "1"
            p2_run_stage = "prescreen"
            timeout_seconds = P2_PRESCREEN_TIMEOUT_SECONDS
        else:
            p2_run_stage = "full"
            timeout_seconds = _p2_full_timeout_seconds(item_payload, from_date, to_date)
    else:
        from_date = None
        to_date = None
        p2_run_stage = None
        timeout_seconds = 1800
    year = 2024
    min_trade_info = _effective_min_trades(root, ea_id, from_date, to_date, year)
    effective_min_trades = str(min_trade_info["effective_min_trades"])

    cmd = [
        "pwsh.exe", "-NoProfile", "-File",
        str(REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"),
        "-EAId", str(numeric_id),
        "-EALabel", ea_dir_name,
        "-Symbol", runner_symbol,
        "-Year", str(year),
        "-Terminal", terminal,
        "-Period", period,
        "-Runs", n_runs,
        "-MinTrades", effective_min_trades,
        "-Model", "4",
        "-SetFile", setfile_path,
        "-ReportRoot", str(report_root),
        "-AllowMissingRealTicksLogMarker",
        "-TimeoutSeconds", str(timeout_seconds),
    ]
    if from_date:
        cmd.extend(["-FromDate", from_date])
    if to_date:
        cmd.extend(["-ToDate", to_date])

    log_fh = open(log_path, "w", encoding="utf-8")
    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    proc = subprocess.Popen(
        cmd,
        cwd=str(REPO_ROOT),
        stdout=log_fh,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "pid": proc.pid,
        "log_path": str(log_path),
        "report_root": str(report_root),
        "ea_dir_name": ea_dir_name,
        **min_trade_info,
        "logical_symbol": symbol,
        "runner_symbol": runner_symbol,
        "p2_run_stage": p2_run_stage,
        "timeout_seconds": timeout_seconds,
        "from_date": from_date,
        "to_date": to_date,
    }


def _ea_pipeline_dir(ea_id: str) -> Path:
    return PIPELINE_REPORT_ROOT / str(ea_id)


def _ea_phase_dir(ea_id: str, phase: str) -> Path:
    return _ea_pipeline_dir(ea_id) / str(phase)


def _phase_runner_inputs(root: Path, ea_id: str, phase: str) -> dict[str, Any]:
    pipeline_dir = _ea_pipeline_dir(ea_id)
    raw_phase = str(phase or "").strip().upper()

    # Q-rewrite phase runners (q04_walkforward.py, q05_stress_medium.py, ...)
    # are self-contained: each takes a baseline-setfile from the work_item row
    # and writes aggregate.json under report_root. None of them consume a
    # pre-existing pipeline artifact, so the factory spawn must not be gated
    # on legacy P-pipeline input files (e.g. P4/calibration.json,
    # P5/p5_slices.csv, P3/sweep_pass_rows.csv) — those existed only for the
    # old P-pipeline runners and never appear under the Q-rewrite. Returning
    # {} here lets _phase_runner_cmd_for_work_item build the Q-runner cmd
    # straight from the work_item row.
    #
    # The legacy CLI dispatch in _phase_runner_cmd() below still calls this
    # function with raw P-keys (P5/P5b/P5c/P7/P8) and relies on the legacy
    # input lookup that follows — so do NOT short-circuit on the normalized
    # P-key, only on the inbound Q-name.
    if raw_phase in ("Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10"):
        return {}

    phase_key = _normalize_phase(phase)
    if phase_key == "P3.5":
        p2_report = _refresh_phase_report_from_work_items(root, ea_id, "P2") or (pipeline_dir / "P2" / "report.csv")
        p3_report = _refresh_phase_report_from_work_items(root, ea_id, "P3") or (pipeline_dir / "P3" / "report.csv")
        inputs: dict[str, Path] = {
            "p2_report": p2_report,
            "p3_report": p3_report,
        }
    elif phase_key == "P4":
        inputs = {}  # P4 primarily uses setfile from work_item row
    elif phase_key == "P5":
        inputs = {"calibration_json": pipeline_dir / "P4" / "calibration.json"}
    elif phase_key == "P5b":
        # p5b_noise_driver.py is the phase runner that creates
        # p5b_trials.csv; requiring it before the run deadlocks the phase.
        inputs = {"calibration_json": pipeline_dir / "P4" / "calibration.json"}
    elif phase_key == "P5c":
        inputs = {"slices_csv": pipeline_dir / "P5" / "p5_slices.csv"}
    elif phase_key == "P6":
        inputs = {}  # P6 driver creates p6_seeds.csv; do not require it before run.
    elif phase_key == "P7":
        inputs = {
            "sweep_pass_rows": pipeline_dir / "P3" / "sweep_pass_rows.csv",
            "multiseed_rows": pipeline_dir / "P6" / "p6_seeds.csv",
        }
    elif phase_key == "P8":
        inputs = {}
    else:
        inputs = {}
    missing = [str(path) for path in inputs.values() if not Path(path).exists()]
    if missing:
        return {**inputs, "missing": missing}
    return inputs


def _run_phase_input_generator(cmd: list[str], log_path: Path) -> bool:
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8", newline="\n") as log:
        log.write(f"{utc_now()} generator.cmd={' '.join(cmd)}\n")
        proc = subprocess.run(
            cmd,
            cwd=str(REPO_ROOT),
            stdout=log,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            creationflags=creationflags,
            timeout=120,
        )
        log.write(f"{utc_now()} generator.exit={proc.returncode}\n")
        return proc.returncode == 0


def _missing_or_older_than(target: Path, *sources: Path) -> bool:
    if not target.exists():
        return True
    try:
        target_mtime = target.stat().st_mtime
    except OSError:
        return True
    for source in sources:
        if not source.exists():
            continue
        try:
            if source.stat().st_mtime > target_mtime:
                return True
        except OSError:
            continue
    return False


def _ensure_phase_runner_inputs(root: Path, item_row: sqlite3.Row, log_path: Path) -> None:
    ea_id = str(item_row["ea_id"])
    phase = str(item_row["phase"])
    symbol = str(item_row["symbol"] or "").strip()
    phase_dir = _ea_pipeline_dir(ea_id)

    if phase in {"P5", "P5b"} and not (phase_dir / "P4" / "calibration.json").exists():
        if P5_CALIBRATION_JSON.exists() and symbol:
            _run_phase_input_generator(
                [
                    sys.executable,
                    str(REPO_ROOT / "framework" / "scripts" / "p5_calibration_extractor.py"),
                    "--ea", ea_id,
                    "--symbols", symbol,
                    "--source-calibration", str(P5_CALIBRATION_JSON),
                    "--out-prefix", str(PIPELINE_REPORT_ROOT),
                ],
                log_path,
            )

    if phase == "P5c" and not (phase_dir / "P5" / "p5_slices.csv").exists():
        cmd = [
            sys.executable,
            str(REPO_ROOT / "framework" / "scripts" / "p5c_slices_generator.py"),
            "--ea", ea_id,
            "--out-prefix", str(PIPELINE_REPORT_ROOT),
        ]
        _run_phase_input_generator(cmd, log_path)

    if phase == "P7":
        sweep_rows = phase_dir / "P3" / "sweep_pass_rows.csv"
        p3_report = phase_dir / "P3" / "report.csv"
        p2_report = phase_dir / "P2" / "report.csv"
        if p3_report.exists() and _missing_or_older_than(sweep_rows, p3_report, p2_report):
            cmd = [
                sys.executable,
                str(REPO_ROOT / "framework" / "scripts" / "p7_sweep_pass_rows_generator.py"),
                "--ea", ea_id,
                "--p3-report", str(p3_report),
                "--out-prefix", str(PIPELINE_REPORT_ROOT),
            ]
            if p2_report.exists():
                cmd.extend(["--p2-report", str(p2_report)])
            _run_phase_input_generator(cmd, log_path)


def _load_csv_dicts(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return [dict(row) for row in csv.DictReader(f)]


def _refresh_phase_report_from_work_items(root: Path, ea_id: str, phase: str) -> Path | None:
    """Write phase report.csv from current work_items DB state."""
    phase_key = str(phase or "").strip()
    out_path = _ea_phase_dir(ea_id, phase_key) / "report.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with connect(root) as conn:
        rows = conn.execute(
            """
            SELECT ea_id, phase, symbol, verdict, evidence_path, payload_json
            FROM work_items
            WHERE ea_id=? AND phase=? AND status in ('done', 'failed')
            ORDER BY updated_at ASC, created_at ASC
            """,
            (ea_id, phase_key),
        ).fetchall()
    if not rows:
        return out_path if out_path.exists() else None

    fieldnames = ["ea_id", "phase", "symbol", "terminal", "verdict", "invalidation_reason", "evidence"]
    with out_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            try:
                payload = json.loads(row["payload_json"] or "{}")
            except json.JSONDecodeError:
                payload = {}
            writer.writerow({
                "ea_id": row["ea_id"],
                "phase": row["phase"],
                "symbol": row["symbol"],
                "terminal": payload.get("terminal") or row["symbol"] or "",
                "verdict": row["verdict"] or "",
                "invalidation_reason": payload.get("verdict_reason") or payload.get("final_failure") or "",
                "evidence": row["evidence_path"] or "",
            })
    return out_path


def _phase_artifact_summary(item_row: sqlite3.Row) -> tuple[Path, dict[str, Any]] | None:
    """Build a classifier summary for phase drivers that do not write summary.json."""
    phase = str(item_row["phase"])
    ea_id = str(item_row["ea_id"])
    phase_dir = _ea_phase_dir(ea_id, phase)
    try:
        payload = json.loads(item_row["payload_json"] or "{}")
    except (KeyError, TypeError, json.JSONDecodeError):
        payload = {}

    def _fresh_enough(path: Path) -> bool:
        started_raw = str(payload.get("started_at_iso") or payload.get("claimed_at_iso") or "")
        if not started_raw:
            return True
        try:
            started = dt.datetime.fromisoformat(started_raw.replace("Z", "+00:00"))
        except ValueError:
            return True
        if started.tzinfo is None:
            started = started.replace(tzinfo=dt.timezone.utc)
        return path.stat().st_mtime >= started.timestamp()

    if phase == "P5":
        clean_path = phase_dir / "p5_clean_metrics.json"
        stress_path = phase_dir / "p5_stress_metrics.json"
        if not clean_path.exists() or not stress_path.exists():
            return None
        if not _fresh_enough(clean_path) or not _fresh_enough(stress_path):
            return None
        clean = json.loads(clean_path.read_text(encoding="utf-8-sig"))
        stress = json.loads(stress_path.read_text(encoding="utf-8-sig"))
        symbol = str(item_row["symbol"])
        def _symbol_metrics(block: dict[str, Any]) -> dict[str, Any] | None:
            if str(block.get("symbol") or "") == symbol:
                return block
            for row in block.get("symbols") or []:
                if isinstance(row, dict) and str(row.get("symbol") or "") == symbol:
                    return row
            return None
        clean_metrics = _symbol_metrics(clean)
        stress_metrics = _symbol_metrics(stress)
        if clean_metrics is None or stress_metrics is None:
            return None
        return stress_path, {
            "phase": "P5",
            "ea_id": ea_id,
            "verdict": "",
            "clean_metrics": clean_metrics,
            "stress_metrics": stress_metrics,
        }
    if phase == "P5b":
        result_path = phase_dir / f"P5b_{ea_id}_result.json"
        if result_path.exists() and _fresh_enough(result_path):
            try:
                summary = json.loads(result_path.read_text(encoding="utf-8-sig"))
            except json.JSONDecodeError:
                summary = None
            if isinstance(summary, dict):
                return result_path, summary
        trials_path = phase_dir / "p5b_trials.csv"
        if not trials_path.exists():
            return None
        if not _fresh_enough(trials_path):
            return None
        rows = _load_csv_dicts(trials_path)
        return trials_path, {
            "phase": "P5b",
            "ea_id": ea_id,
            "verdict": "",
            "trial_count": len(rows),
            "real_mt5_run_count": 0,
            "failed_run_count": len(rows),
        }
    if phase == "P6":
        seeds_path = phase_dir / "p6_seeds.csv"
        if not seeds_path.exists():
            return None
        if not _fresh_enough(seeds_path):
            return None
        rows = _load_csv_dicts(seeds_path)
        pass_count = sum(1 for row in rows if str(row.get("seed_pass") or "").strip().upper() in {"PASS", "1", "TRUE", "YES"})
        return seeds_path, {
            "phase": "P6",
            "ea_id": ea_id,
            "verdict": "",
            "seed_count": len(rows),
            "seed_pass_count": pass_count,
        }
    return None


def _phase_runner_script_path(phase: str) -> Path | None:
    script_name = PHASE_RUNNER_SCRIPTS.get(str(phase or "").strip())
    if not script_name:
        return None
    path = REPO_ROOT / "framework" / "scripts" / script_name
    return path if path.exists() else None


def _news_calendar_csv() -> Path:
    for path in NEWS_CALENDAR_CANDIDATES:
        if path.exists():
            return path
    return NEWS_CALENDAR_CANDIDATES[0]


def _remove_cmd_arg(cmd: list[str], flag: str) -> None:
    while flag in cmd:
        idx = cmd.index(flag)
        del cmd[idx:idx + 2]


def _console_python_executable() -> str:
    python_exe = Path(sys.executable)
    if sys.platform == "win32" and python_exe.name.lower() == "pythonw.exe":
        console_exe = python_exe.with_name("python.exe")
        if console_exe.exists():
            return str(console_exe)
    return sys.executable


def _phase_runner_cmd_for_work_item(root: Path, item_row: sqlite3.Row,
                                    report_root: Path,
                                    terminal: str | None = None) -> list[str] | None:
    phase = item_row["phase"]
    script_path = _phase_runner_script_path(phase)
    if script_path is None:
        return None
    inputs = _phase_runner_inputs(root, item_row["ea_id"], phase)
    if inputs.get("missing"):
        return None
    ea_id = item_row["ea_id"]
    symbol = item_row["symbol"]
    period = _detect_ea_period(ea_id)
    cmd = [
        _console_python_executable(),
        str(script_path),
        "--ea", ea_id,
        "--out-prefix", str(report_root),
        "--symbol", symbol,
        "--period", period,
        "--setfile", item_row["setfile_path"],
    ]
    if phase == "P3.5":
        cmd.extend(["--symbols", symbol, "--from-year", "2017", "--to-year", "2022"])
        if Path(inputs["p2_report"]).exists():
            cmd.extend(["--baseline-csv", str(inputs["p2_report"])])
        if Path(inputs["p3_report"]).exists():
            cmd.extend(["--csr-results-csv", str(inputs["p3_report"])])
    elif phase == "P4":
        cmd.extend([
            "--symbols", symbol,
            "--train-from-year", "2017",
            "--train-to-year", "2022",
            "--oos-from-year", "2023",
            "--oos-to-year", "2025",
            "--min-folds", "6",
            "--terminal", terminal or "T1",
        ])
    elif phase == "P5":
        cmd.extend([
            "--year", "2024",
            "--calibration-json", str(inputs["calibration_json"]),
            "--base-setfile", item_row["setfile_path"],
            "--terminal", terminal or "T1",
            "--max-parallel", "1",
        ])
        _remove_cmd_arg(cmd, "--setfile")
    elif phase == "P5b":
        cmd.extend([
            "--calibration-json", str(inputs["calibration_json"]),
            "--base-setfile", item_row["setfile_path"],
            "--terminal", terminal or "T1",
            "--year", "2024",
        ])
        _remove_cmd_arg(cmd, "--setfile")
    elif phase == "P5c":
        cmd.extend([
            "--slices-csv", str(inputs["slices_csv"]),
            "--base-setfile", item_row["setfile_path"],
            "--terminal", terminal or "T1",
        ])
        _remove_cmd_arg(cmd, "--setfile")
    elif phase == "P6":
        cmd.extend([
            "--year", "2024",
            "--seeds", "42,17,99,7,2026",
            "--base-setfile", str(item_row["setfile_path"] or ""),
            "--terminal", terminal or "T1",
            "--max-parallel", "1",
        ])
        _remove_cmd_arg(cmd, "--setfile")
    elif phase == "P7":
        cmd.extend([
            "--sweep-pass-rows", str(inputs["sweep_pass_rows"]),
            "--multiseed-rows", str(inputs["multiseed_rows"]),
        ])
        _remove_cmd_arg(cmd, "--symbol")
        _remove_cmd_arg(cmd, "--period")
        _remove_cmd_arg(cmd, "--setfile")
    elif phase == "P8":
        cmd.extend([
            "--calendar-csv", str(_news_calendar_csv()),
            "--mode", "all",
            "--base-setfile", str(item_row["setfile_path"] or ""),
            "--terminal", terminal or "T1",
            "--from-date", "2023.01.01",
            "--to-date", "2025.12.31",
            "--run-mt5",
        ])
        news_matrix = report_root / ea_id / "P7" / "news_matrix.csv"
        if not news_matrix.exists() and NEWS_MATRIX_FALLBACK.exists():
            news_matrix = NEWS_MATRIX_FALLBACK
        if news_matrix.exists():
            cmd.extend(["--news-matrix", str(news_matrix)])
    # PT3 2026-05-23 — Qxx canonical phase runners (post-pipeline-rewrite).
    # Each new runner has a slightly different CLI; bridge from the generic
    # worker args (--ea, --symbol, --period, --setfile) here.
    elif phase == "Q04":
        cmd.extend(["--terminal", terminal or "T1"])
    elif phase in ("Q05", "Q06", "Q10"):
        # These take --baseline-setfile instead of --setfile.
        cmd.extend([
            "--baseline-setfile", str(item_row["setfile_path"] or ""),
            "--terminal", terminal or "T1",
        ])
        _remove_cmd_arg(cmd, "--setfile")
    elif phase == "Q07":
        cmd.extend([
            "--baseline-setfile", str(item_row["setfile_path"] or ""),
            "--terminal", terminal or "T1",
        ])
        _remove_cmd_arg(cmd, "--setfile")
    elif phase == "Q08":
        # Q08 aggregator reads the EA's structured JSON-lines log directly.
        # Worker-passed --setfile/--period not needed; we rebuild the cmd.
        log_path = (Path(r"D:\QM\mt5") / (terminal or "T1") /
                    "MQL5" / "Logs" / "QM" / f"{ea_id}.log")
        cmd = [
            _console_python_executable(),
            str(REPO_ROOT / "framework" / "scripts" / "q08_davey" / "aggregate.py"),
            "--ea-id", str(int(ea_id.replace("QM5_", "").split("_")[0]))
                          if ea_id.startswith("QM5_") else ea_id,
            "--symbol", symbol,
            "--log", str(log_path),
            "--out-dir", str(report_root / ea_id / "Q08" / symbol.replace(".", "_")),
            "--terminal", terminal or "T1",
        ]
    elif phase == "Q09":
        cmd.extend([
            "--baseline-setfile", str(item_row["setfile_path"] or ""),
            "--terminal", terminal or "T1",
        ])
        _remove_cmd_arg(cmd, "--setfile")
    # PT3 bridge (2026-05-29): the rewritten Qxx runners (q04-q10) use
    # --report-root, not the P-era --out-prefix, and reject --period. The
    # generic base cmd above always injects --out-prefix/--period, which the
    # Q-runners abort on at argparse (exit 2) -> no summary.json ->
    # summary_missing -> INFRA_FAIL. Translate once for every Q-phase. (Q08
    # rebuilds cmd from scratch above, so these flags are already absent and
    # this is a no-op for it.) Carry the --out-prefix value into --report-root;
    # --report-root otherwise defaults to the shared pipeline tree and breaks
    # per-work-item evidence isolation.
    if str(phase).startswith("Q"):
        _remove_cmd_arg(cmd, "--period")
        if "--out-prefix" in cmd:
            cmd[cmd.index("--out-prefix")] = "--report-root"
    return cmd


def _spawn_phase_runner_for_work_item(root: Path, item_row: sqlite3.Row,
                                      terminal: str) -> dict[str, Any]:
    phase = item_row["phase"]
    # Real phase runners can run several variants for the same EA/phase in
    # parallel. Their default output names are phase-level (`summary.json`,
    # `p5b_trials.csv`, ...), so a shared pipeline directory makes work_item
    # evidence point at whichever variant finished last. Keep each work_item's
    # primary evidence isolated; terminal_worker mirrors PASS artifacts back to
    # the canonical pipeline directory for downstream phase inputs.
    report_root = Path(r"D:\QM\reports\work_items") / str(item_row["id"])
    report_root.mkdir(parents=True, exist_ok=True)
    log_path = root / "logs" / f"work_item_{item_row['id']}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)

    _ensure_phase_runner_inputs(root, item_row, log_path)
    inputs = _phase_runner_inputs(root, item_row["ea_id"], phase)
    if inputs.get("missing"):
        msg = f"waiting for required phase input(s): {', '.join(inputs['missing'])}"
        with log_path.open("a", encoding="utf-8", newline="\n") as f:
            f.write(f"{utc_now()} {phase}: {msg}\n")
        return {
            "spawned": False,
            "waiting_input": True,
            "reason": msg,
            "missing_inputs": inputs["missing"],
            "log_path": str(log_path),
            "report_root": str(report_root),
            "ea_dir_name": item_row["ea_id"],
            "phase_runner": None,
        }

    cmd = _phase_runner_cmd_for_work_item(root, item_row, report_root, terminal)
    if cmd is None:
        msg = "phase runner not implemented yet -- skipping for now"
        with log_path.open("a", encoding="utf-8", newline="\n") as f:
            f.write(f"{utc_now()} {phase}: {msg}\n")
        return {
            "spawned": False,
            "pending_runner": True,
            "reason": msg,
            "log_path": str(log_path),
            "report_root": str(report_root),
            "ea_dir_name": item_row["ea_id"],
            "phase_runner": None,
        }

    log_fh = open(log_path, "a", encoding="utf-8")
    log_fh.write(f"\n{utc_now()} spawning phase runner: {' '.join(cmd)}\n")
    log_fh.flush()
    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    env = {**os.environ}
    env["PYTHONPATH"] = os.pathsep.join(
        [str(REPO_ROOT), env.get("PYTHONPATH", "")]
    )
    proc = subprocess.Popen(
        cmd,
        cwd=str(REPO_ROOT),
        stdout=log_fh,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        creationflags=creationflags,
        close_fds=True,
        env=env,
    )
    log_fh.close()
    return {
        "spawned": True,
        "pid": proc.pid,
        "log_path": str(log_path),
        "report_root": str(report_root),
        "ea_dir_name": item_row["ea_id"],
        "phase_runner": cmd[1],
        "effective_min_trades": 5,
    }


def _spawn_work_item_runner(root: Path, item_row: sqlite3.Row,
                            terminal: str) -> dict[str, Any]:
    if item_row["phase"] in REAL_PHASE_RUNNER_PHASES:
        return _spawn_phase_runner_for_work_item(root, item_row, terminal)
    return _spawn_run_smoke_for_work_item(root, item_row, terminal)


def _dispatch_diag_enabled() -> bool:
    return os.environ.get("DISPATCH_DIAG", "").strip().lower() in {"1", "true", "yes", "on"}


def _dispatch_diag(evt: str, payload: dict[str, Any]) -> None:
    if not _dispatch_diag_enabled():
        return
    entry = {"evt": evt, "ts": utc_now(), "pid": os.getpid(), **payload}
    print(f"DISPATCH_DIAG {json.dumps(entry, sort_keys=True)}", flush=True)


def _pid_exists(pid: Any) -> bool:
    try:
        pid_int = int(pid)
    except (TypeError, ValueError):
        return False
    try:
        _ps = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                f"if (Get-Process -Id {pid_int} -ErrorAction SilentlyContinue) {{'alive'}}",
            ],
            capture_output=True,
            text=True,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
            timeout=8,
        )
        return "alive" in (_ps.stdout or "")
    except Exception:
        return True  # can't tell — assume alive, defer to timeout path


def _pid_tree_exists(pid: Any) -> bool:
    """Return true if pid or any descendant process is still alive.

    Phase drivers can spawn a short-lived Python parent which leaves a
    run_smoke/pwsh child running. The terminal worker must treat that child as
    the active run to avoid re-claiming the same terminal and starting a second
    attempt while the first backtest is still in flight.
    """
    try:
        pid_int = int(pid)
    except (TypeError, ValueError):
        return False
    if _pid_exists(pid_int):
        return True
    if sys.platform != "win32":
        return False
    script = rf"""
$target = {pid_int}
$procs = Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId
$children = @{{}}
foreach ($p in $procs) {{
  $pp = [int]$p.ParentProcessId
  if (-not $children.ContainsKey($pp)) {{ $children[$pp] = @() }}
  $children[$pp] += [int]$p.ProcessId
}}
$queue = New-Object System.Collections.Queue
$seen = @{{}}
$queue.Enqueue($target)
while ($queue.Count -gt 0) {{
  $cur = [int]$queue.Dequeue()
  if ($seen.ContainsKey($cur)) {{ continue }}
  $seen[$cur] = $true
  if ($procs | Where-Object {{ [int]$_.ProcessId -eq $cur }}) {{ 'alive'; exit 0 }}
  if ($children.ContainsKey($cur)) {{
    foreach ($child in $children[$cur]) {{ $queue.Enqueue($child) }}
  }}
}}
"""
    try:
        proc = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", script],
            capture_output=True,
            text=True,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
            timeout=15,
        )
        return "alive" in (proc.stdout or "")
    except Exception:
        return True  # can't tell — assume alive, defer to timeout path


def _running_mt5_terminals() -> set[str]:
    allowed = set(active_mt5_terminals())
    try:
        proc = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                (
                    "Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" "
                    "| ForEach-Object { if ($_.ExecutablePath -match '\\\\(T(?:[1-9]|10))\\\\terminal64\\.exe$') { $Matches[1] } }"
                ),
            ],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception:
        return set(allowed)
    if proc.returncode != 0:
        return set(allowed)
    return {line.strip().upper() for line in (proc.stdout or "").splitlines() if line.strip().upper() in allowed}


def _active_work_item_symbols(conn: sqlite3.Connection) -> dict[str, str]:
    rows = conn.execute(
        """
        SELECT DISTINCT symbol
        FROM work_items
        WHERE status='active' AND symbol IS NOT NULL AND symbol != ''
        """
    ).fetchall()
    return {str(row["symbol"]).upper(): row["symbol"] for row in rows}


def _stop_pid(pid: Any) -> bool:
    try:
        pid_int = int(pid)
    except (TypeError, ValueError):
        return False
    try:
        proc = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", f"Stop-Process -Id {pid_int} -Force -ErrorAction SilentlyContinue"],
            capture_output=True,
            text=True,
            timeout=8,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        return proc.returncode == 0
    except Exception:
        return False


def _stop_pid_tree(pid: Any) -> bool:
    try:
        pid_int = int(pid)
    except (TypeError, ValueError):
        return False
    if sys.platform != "win32":
        return _stop_pid(pid_int)
    script = rf"""
$target = {pid_int}
$procs = Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId
$children = @{{}}
foreach ($p in $procs) {{
  $pp = [int]$p.ParentProcessId
  if (-not $children.ContainsKey($pp)) {{ $children[$pp] = @() }}
  $children[$pp] += [int]$p.ProcessId
}}
$queue = New-Object System.Collections.Queue
$seen = @{{}}
$order = New-Object System.Collections.ArrayList
$queue.Enqueue($target)
while ($queue.Count -gt 0) {{
  $cur = [int]$queue.Dequeue()
  if ($seen.ContainsKey($cur)) {{ continue }}
  $seen[$cur] = $true
  [void]$order.Add($cur)
  if ($children.ContainsKey($cur)) {{
    foreach ($child in $children[$cur]) {{ $queue.Enqueue($child) }}
  }}
}}
for ($i = $order.Count - 1; $i -ge 0; $i--) {{
  Stop-Process -Id ([int]$order[$i]) -Force -ErrorAction SilentlyContinue
}}
"""
    try:
        proc = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", script],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        return proc.returncode == 0
    except Exception:
        return False


def _stop_terminal_slot(terminal: str | None) -> bool:
    if not terminal or not is_factory_terminal_name(terminal):
        return False
    terminal = terminal.upper()
    terminal_exe = str(MT5_ROOT / terminal / "terminal64.exe")
    try:
        proc = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                (
                    "Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" "
                    f"| Where-Object {{ $_.ExecutablePath -ieq '{terminal_exe}' }} "
                    "| ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
                ),
            ],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        return proc.returncode == 0
    except Exception:
        return False


def _parse_utc_datetime(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    text = str(value).strip()
    try:
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        parsed = dt.datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.UTC)
        return parsed.astimezone(dt.UTC)
    except ValueError:
        try:
            return dt.datetime.strptime(str(value), "%Y-%m-%d %H:%M:%S").replace(tzinfo=dt.UTC)
        except ValueError:
            return None


def _acquire_dispatch_lock(root: Path) -> tuple[int, Path] | None:
    locks = root / "state" / "locks"
    locks.mkdir(parents=True, exist_ok=True)
    lock_path = locks / "dispatch_work_items.lock"
    flags = os.O_CREAT | os.O_EXCL | os.O_WRONLY
    try:
        fd = os.open(str(lock_path), flags)
    except FileExistsError:
        try:
            lock_data = json.loads(lock_path.read_text(encoding="utf-8"))
            lock_pid = lock_data.get("pid")
            age_sec = time.time() - lock_path.stat().st_mtime
            if _pid_exists(lock_pid) and age_sec <= 1800:
                return None
            lock_path.unlink()
            fd = os.open(str(lock_path), flags)
        except (OSError, json.JSONDecodeError):
            return None
    os.write(fd, json.dumps({"pid": os.getpid(), "created_at": utc_now()}).encode("utf-8"))
    return fd, lock_path


def _release_dispatch_lock(lock: tuple[int, Path] | None) -> None:
    if not lock:
        return
    fd, lock_path = lock
    try:
        os.close(fd)
    except OSError:
        pass
    try:
        lock_path.unlink()
    except OSError:
        pass


def _detect_active_age_timeout(con: sqlite3.Connection) -> list[dict[str, Any]]:
    now_dt = dt.datetime.now(dt.UTC)
    now = now_dt.replace(microsecond=0).isoformat()
    rows = con.execute(
        """
        SELECT id, phase, ea_id, symbol, claimed_by, payload_json, updated_at
        FROM work_items
        WHERE status='active'
        """
    ).fetchall()
    flagged: list[dict[str, Any]] = []
    for r in rows:
        phase = str(r["phase"] or "")
        timeout_min = PHASE_ACTIVE_TIMEOUT_MIN.get(phase)
        if timeout_min is None:
            continue
        updated = _parse_utc_datetime(r["updated_at"])
        if updated is None:
            continue
        age_min = (now_dt - updated).total_seconds() / 60.0
        if age_min < float(timeout_min):
            continue
        payload = json.loads(r["payload_json"] or "{}")
        reason_classes = payload.get("reason_classes") or []
        if "ACTIVE_TIMEOUT" not in [str(x).upper() for x in reason_classes]:
            reason_classes.append("ACTIVE_TIMEOUT")
        worker_pid = payload.get("pid")
        terminal = r["claimed_by"]
        worker_stopped = _stop_pid(worker_pid)
        terminal_stopped = _stop_terminal_slot(terminal)
        payload.update({
            "reason_classes": reason_classes,
            "verdict_reason": "ACTIVE_TIMEOUT",
            "timeout_min": timeout_min,
            "active_age_min": round(age_min, 2),
            "killed_at": now,
            "worker_pid": worker_pid,
            "worker_stopped": worker_stopped,
            "terminal_stopped": terminal_stopped,
        })
        con.execute(
            """
            UPDATE work_items
            SET status='failed', verdict='FAIL', claimed_by=NULL,
                payload_json=?, updated_at=?
            WHERE id=? AND status='active'
            """,
            (json.dumps(payload, sort_keys=True), now, r["id"]),
        )
        flagged.append({
            "id": r["id"],
            "ea_id": r["ea_id"],
            "symbol": r["symbol"],
            "phase": phase,
            "terminal": terminal,
            "age_min": round(age_min, 2),
            "timeout_min": timeout_min,
            "worker_pid": worker_pid,
            "worker_stopped": worker_stopped,
            "terminal_stopped": terminal_stopped,
        })
    if flagged:
        con.commit()
    return flagged


def _normalize_pending_work_item_verdicts(con: sqlite3.Connection) -> int:
    """Pending work_items are open queue entries; stale verdicts belong only to finished rows."""
    now = utc_now()
    cur = con.execute(
        """
        UPDATE work_items
        SET verdict=NULL, updated_at=?
        WHERE status='pending' AND verdict IS NOT NULL
        """,
        (now,),
    )
    changed = int(cur.rowcount or 0)
    if changed:
        con.commit()
    return changed


def dispatch_work_items(root: Path, timeout_minutes: float = 60.0) -> dict[str, Any]:
    """Per-(symbol, setfile) dispatcher. Replaces bundled p2_baseline fan-out.

    Phase 1: poll active work_items. If their report_root has a summary.json,
             parse + derive verdict + mark done. If too old, mark failed (auto-
             retry up to MAX_WORK_ITEM_RETRIES).
    Phase 2: claim pending work_items, one per free terminal, spawn run_smoke.
    Phase 3: aggregate — when ALL work_items for a parent_task_id are done,
             classify the bundled parent task and auto-enqueue next phase.
    """
    init_db(root)
    actions: list[dict[str, Any]] = []
    started_iso = utc_now()
    busy_terminals: set[str] = set()
    launched_pids: list[int] = []
    MAX_WORK_ITEM_RETRIES = 3
    lock = _acquire_dispatch_lock(root)
    if lock is None:
        result = {
            "actions": [{"action": "dispatch_locked", "reason": "another dispatch_work_items is active"}],
            "busy_terminals": [],
            "free_terminals": [],
            "scanned_at": started_iso,
            "lock_skipped": True,
        }
        _dispatch_diag("dispatch_skip_locked", result)
        return result
    _dispatch_diag("dispatch_start", {"timeout_minutes": timeout_minutes})
    running_mt5_terminals = _running_mt5_terminals()

    # --- Phase 1: process active work_items ---
    with connect(root) as conn:
        active = conn.execute(
            "SELECT * FROM work_items WHERE status='active' ORDER BY updated_at"
        ).fetchall()
    for item in active:
        payload = json.loads(item["payload_json"]) if item["payload_json"] else {}
        report_root = payload.get("report_root")
        ea_dir_name = payload.get("ea_dir_name")
        terminal = item["claimed_by"]
        if terminal:
            busy_terminals.add(terminal)
        # Find newest summary.json under report_root
        summary_path = None
        search_root = Path(report_root) if report_root else None
        if item["phase"] in REAL_PHASE_RUNNER_PHASES:
            search_root = _ea_phase_dir(item["ea_id"], item["phase"])
            phase_summary = search_root / "summary.json"
            if phase_summary.exists():
                summary_path = phase_summary
        if not summary_path and search_root and search_root.is_dir():
            cands = sorted(
                search_root.rglob("summary.json"),
                key=lambda p: p.stat().st_mtime,
                reverse=True,
            )
            if cands:
                summary_path = cands[0]
        if summary_path and summary_path.exists():
            try:
                summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
            except Exception as e:
                summary = None
            if summary:
                effective_min_trades = int(payload.get("effective_min_trades")
                                           or summary.get("min_trades_required")
                                           or 5)
                verdict, reason = _derive_verdict_from_summary(
                    summary,
                    min_trades=effective_min_trades,
                    phase=item["phase"],
                )
                updated_payload = _payload_with_pass_recovered_stats(
                    {**payload, "verdict_reason": reason},
                    verdict,
                    summary,
                )
                updated_payload["evidence_provenance"] = (
                    "phase_runner" if item["phase"] in REAL_PHASE_RUNNER_PHASES else "real_mt5"
                )
                updated_payload["verdict_taxonomy"] = "infra" if verdict == "INFRA_FAIL" else "strategy"
                if item["phase"] == "P2" and payload.get("p2_run_stage") == "prescreen":
                    runtime_sec = _p2_active_summary_runtime_sec(item, summary)
                    if verdict == "PASS":
                        updated_payload.update({
                            "p2_prescreen_done": True,
                            "p2_prescreen_verdict": verdict,
                            "p2_prescreen_reason": reason,
                            "p2_prescreen_evidence_path": str(summary_path),
                            "p2_prescreen_runtime_sec": runtime_sec,
                            "p2_prescreen_from_date": payload.get("from_date"),
                            "p2_prescreen_to_date": payload.get("to_date"),
                            "p2_run_stage": "full_pending",
                            "pid": None,
                            "started_at_iso": None,
                            "log_path": None,
                        })
                        with connect(root) as conn2:
                            conn2.execute(
                                """
                                UPDATE work_items
                                SET status='pending', verdict=NULL, claimed_by=NULL,
                                    evidence_path=NULL, payload_json=?, updated_at=?
                                WHERE id=?
                                """,
                                (json.dumps(updated_payload, sort_keys=True), started_iso, item["id"]),
                            )
                            conn2.commit()
                        busy_terminals.discard(terminal)
                        actions.append({
                            "action": "p2_prescreen_pass_requeued_full",
                            "item_id": item["id"],
                            "ea_id": item["ea_id"],
                            "symbol": item["symbol"],
                            "reason": reason,
                            "runtime_sec": runtime_sec,
                            "terminal_released": terminal,
                        })
                        continue
                    updated_payload.update({
                        "p2_prescreen_done": True,
                        "p2_prescreen_verdict": verdict,
                        "p2_prescreen_reason": reason,
                        "p2_prescreen_evidence_path": str(summary_path),
                        "p2_prescreen_runtime_sec": runtime_sec,
                        "verdict_reason": f"P2_PRESCREEN_{reason}",
                    })
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='done', verdict=?, evidence_path=?, payload_json=?, updated_at=? WHERE id=?",
                        (verdict, str(summary_path),
                         json.dumps(updated_payload, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": "classified_item", "item_id": item["id"],
                               "ea_id": item["ea_id"], "symbol": item["symbol"],
                               "verdict": verdict, "reason": reason,
                               "effective_min_trades": effective_min_trades,
                               "terminal_released": terminal})
                continue
        worker_pid = payload.get("pid")
        worker_alive_for_artifacts = _pid_tree_exists(worker_pid) if worker_pid else True
        if not summary_path and not worker_alive_for_artifacts and item["phase"] in {"P5", "P5b", "P6"}:
            artifact_summary = _phase_artifact_summary(item)
            if artifact_summary is not None:
                artifact_path, summary = artifact_summary
                effective_min_trades = int(payload.get("effective_min_trades") or 5)
                verdict, reason = _derive_verdict_from_summary(
                    summary,
                    min_trades=effective_min_trades,
                    phase=item["phase"],
                )
                updated_payload = _payload_with_pass_recovered_stats(
                    {**payload, "verdict_reason": reason},
                    verdict,
                    summary,
                )
                updated_payload["evidence_provenance"] = "phase_runner"
                updated_payload["verdict_taxonomy"] = "infra" if verdict == "INFRA_FAIL" else "strategy"
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='done', verdict=?, evidence_path=?, payload_json=?, updated_at=? WHERE id=?",
                        (
                            verdict,
                            str(artifact_path),
                            json.dumps(updated_payload, sort_keys=True),
                            started_iso,
                            item["id"],
                        ),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({
                    "action": "classified_item",
                    "item_id": item["id"],
                    "ea_id": item["ea_id"],
                    "symbol": item["symbol"],
                    "verdict": verdict,
                    "reason": reason,
                    "evidence_path": str(artifact_path),
                    "terminal_released": terminal,
                })
                continue
        # Still no summary — first check if the run_smoke.ps1 child PID
        # is still alive. If it died without writing a summary (MT5 crash,
        # OS reboot, manual kill) we should release the terminal IMMEDIATELY
        # instead of waiting `timeout_minutes` for the slow path.
        worker_alive = _pid_tree_exists(worker_pid) if worker_pid else True

        started = payload.get("started_at_iso")
        age_min = 0.0
        if started:
            try:
                age_min = (dt.datetime.now(dt.UTC) - dt.datetime.fromisoformat(started.replace("Z", "+00:00"))).total_seconds() / 60.0
            except Exception:
                age_min = 0.0

        terminal_alive = (not terminal) or (terminal in running_mt5_terminals)
        fast_failure = None
        if not worker_alive:
            fast_failure = "worker_died"
        elif not terminal_alive and age_min > 1.0:
            fast_failure = "terminal_died"
            _stop_pid(worker_pid)

        # Fast-fail: worker/terminal gone + nothing produced + > 1 min (avoid races on spawn)
        if fast_failure and age_min > 1.0:
            attempt = item["attempt_count"] + 1
            terminal_stopped = _stop_terminal_slot(terminal)
            updated_payload = {
                **payload,
                "prior_failure": fast_failure,
                "terminal_stopped_on_release": terminal_stopped,
            }
            if attempt < MAX_WORK_ITEM_RETRIES:
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='pending', verdict=NULL, attempt_count=?, claimed_by=NULL, payload_json=?, updated_at=? WHERE id=?",
                        (attempt, json.dumps(updated_payload, sort_keys=True), started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": f"retry_{fast_failure}", "item_id": item["id"],
                                "terminal_released": terminal, "attempt": attempt,
                                "worker_pid": worker_pid,
                                "terminal_stopped": terminal_stopped})
            else:
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='failed', verdict='INFRA_FAIL', payload_json=?, updated_at=? WHERE id=?",
                        (json.dumps({**updated_payload, "final_failure": f"{fast_failure}_retries_exhausted"}, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": f"failed_{fast_failure}", "item_id": item["id"],
                                "worker_pid": worker_pid,
                                "terminal_stopped": terminal_stopped})
            continue

        if age_min > timeout_minutes:
            attempt = item["attempt_count"] + 1
            terminal_stopped = _stop_terminal_slot(terminal)
            if attempt < MAX_WORK_ITEM_RETRIES:
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='pending', verdict=NULL, attempt_count=?, claimed_by=NULL, payload_json=?, updated_at=? WHERE id=?",
                        (attempt, json.dumps({**payload, "prior_timeout": started, "terminal_stopped_on_release": terminal_stopped}, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": "retry_timeout", "item_id": item["id"], "attempt": attempt, "terminal_stopped": terminal_stopped})
            else:
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='failed', verdict='INFRA_FAIL', payload_json=?, updated_at=? WHERE id=?",
                        (json.dumps({**payload, "final_failure": "retries_exhausted", "terminal_stopped_on_release": terminal_stopped}, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": "failed_final", "item_id": item["id"], "terminal_stopped": terminal_stopped})

    # --- Phase 2: claim pending work_items per free terminal ---
    # OWNER 2026-05-17 priority queue (replaces FIFO):
    #   1. Highest phase first (P4 > P3.5 > P3 > P2) — promotions get priority
    #      because they're already known winners advancing toward Live.
    #   2. EA-of-a-known-winner before greenfield (ea_id with prior PASSes).
    #   3. Then FIFO within tier (updated_at ASC).
    # The CASE WHEN encodes the priority. Lower number = sooner.
    factory_terminals = active_mt5_terminals()
    free_terminals = [t for t in factory_terminals if t not in busy_terminals]
    if free_terminals:
        with connect(root) as conn:
            active_symbol_keys = _active_work_item_symbols(conn)
            pending = conn.execute(
                """
                SELECT w.*,
                  CASE w.phase
                    -- Q-rewrite phases first (downstream-priority). Without
                    -- these the Q-rewrite work all ties at ELSE 9 against
                    -- the legacy P-keys and FIFO hands claims to whichever
                    -- phase has the freshest inflow (typically Q02), starving
                    -- Q04+ promotion-chain work. Same fix in
                    -- terminal_worker.py:_priority_pending_query.
                    WHEN 'Q10'  THEN 0
                    WHEN 'Q09'  THEN 1
                    WHEN 'Q08'  THEN 2
                    WHEN 'Q07'  THEN 3
                    WHEN 'Q06'  THEN 4
                    WHEN 'Q05'  THEN 5
                    WHEN 'Q04'  THEN 6
                    WHEN 'Q03'  THEN 7
                    WHEN 'Q02'  THEN 8
                    WHEN 'P8'   THEN 0
                    WHEN 'P7'   THEN 1
                    WHEN 'P6'   THEN 2
                    WHEN 'P5c'  THEN 3
                    WHEN 'P5b'  THEN 4
                    WHEN 'P5'   THEN 5
                    WHEN 'P4'   THEN 6
                    WHEN 'P3.5' THEN 7
                    WHEN 'P3'   THEN 8
                    WHEN 'P2'   THEN 9
                    ELSE 9 END AS _phase_rank,
                  CASE WHEN EXISTS (
                    SELECT 1 FROM work_items wp
                    WHERE wp.ea_id=w.ea_id AND wp.status='done' AND wp.verdict='PASS'
                  ) THEN 0 ELSE 1 END AS _winner_rank
                FROM work_items w
                WHERE w.status='pending'
                ORDER BY _phase_rank ASC, _winner_rank ASC, w.updated_at ASC, w.created_at ASC
                """
            ).fetchall()
        claimed_symbol_keys = dict(active_symbol_keys)
        for item in pending:
            if not free_terminals:
                break
            item_symbol = item["symbol"]
            item_symbol_key = str(item_symbol or "").upper()
            if item_symbol_key and item_symbol_key in claimed_symbol_keys:
                actions.append({
                    "action": "deferred_symbol_lock",
                    "reason": "symbol_already_active_on_other_terminal",
                    "item_id": item["id"],
                    "ea_id": item["ea_id"],
                    "symbol": item_symbol,
                    "active_symbol": claimed_symbol_keys[item_symbol_key],
                })
                continue
            terminal = free_terminals.pop(0)
            spawn = _spawn_work_item_runner(root, item, terminal)
            if not spawn.get("spawned"):
                if spawn.get("waiting_input"):
                    payload = {
                        "verdict_reason": spawn.get("reason"),
                        "missing_inputs": spawn.get("missing_inputs", []),
                        "log_path": spawn.get("log_path"),
                        "report_root": spawn.get("report_root"),
                    }
                    with connect(root) as conn2:
                        conn2.execute(
                            "UPDATE work_items SET status='done', verdict='WAITING_INPUT', payload_json=?, updated_at=? WHERE id=?",
                            (json.dumps(payload, sort_keys=True), started_iso, item["id"]),
                        )
                        conn2.commit()
                    actions.append({"action": "waiting_input", "item_id": item["id"], "phase": item["phase"], "reason": spawn.get("reason")})
                    free_terminals.insert(0, terminal)
                    continue
                if spawn.get("pending_runner"):
                    payload = {
                        "verdict_reason": spawn.get("reason"),
                        "log_path": spawn.get("log_path"),
                        "report_root": spawn.get("report_root"),
                    }
                    with connect(root) as conn2:
                        conn2.execute(
                            "UPDATE work_items SET status='done', verdict='PENDING_RUNNER', payload_json=?, updated_at=? WHERE id=?",
                            (json.dumps(payload, sort_keys=True), started_iso, item["id"]),
                        )
                        conn2.commit()
                    actions.append({"action": "pending_runner", "item_id": item["id"], "phase": item["phase"], "reason": spawn.get("reason")})
                    free_terminals.insert(0, terminal)
                    continue
                # Mark failed if spawn impossible
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='failed', verdict='INFRA_FAIL', updated_at=? WHERE id=?",
                        (started_iso, item["id"]),
                    )
                    conn2.commit()
                actions.append({"action": "spawn_failed", "item_id": item["id"], "reason": spawn.get("reason")})
                free_terminals.insert(0, terminal)  # give terminal back
                continue
            new_payload = {
                "started_at_iso": started_iso,
                "pid": spawn["pid"],
                "log_path": spawn["log_path"],
                "report_root": spawn["report_root"],
                "ea_dir_name": spawn["ea_dir_name"],
                "terminal": terminal,
                "expected_trades_per_year_per_symbol": spawn.get("expected_trades_per_year_per_symbol"),
                "smoke_year_count": spawn.get("smoke_year_count"),
                "effective_min_trades": spawn.get("effective_min_trades"),
                "phase_runner": spawn.get("phase_runner"),
            }
            with connect(root) as conn2:
                conn2.execute(
                    "UPDATE work_items SET status='active', claimed_by=?, payload_json=?, updated_at=? WHERE id=?",
                    (terminal, json.dumps(new_payload, sort_keys=True), started_iso, item["id"]),
                )
                conn2.commit()
            actions.append({
                "action": "claimed",
                "item_id": item["id"],
                "ea_id": item["ea_id"],
                "symbol": item["symbol"],
                "terminal": terminal,
                "pid": spawn["pid"],
                "phase_runner": spawn.get("phase_runner"),
                "effective_min_trades": spawn.get("effective_min_trades"),
            })
            launched_pids.append(int(spawn["pid"]))
            if item_symbol_key:
                claimed_symbol_keys[item_symbol_key] = item_symbol

    # --- Phase 3: aggregate completed parents ---
    with connect(root) as conn:
        # Find parent_task_ids that have all work_items done but parent is still active/pending
        parent_summaries = conn.execute(
            """
            SELECT parent_task_id,
                   COUNT(*) AS total,
                   SUM(CASE WHEN status='done' OR status='failed' THEN 1 ELSE 0 END) AS finished,
                   SUM(CASE WHEN verdict='PASS' THEN 1 ELSE 0 END) AS passes
            FROM work_items
            WHERE parent_task_id IS NOT NULL
            GROUP BY parent_task_id
            HAVING total = finished
            """
        ).fetchall()
        for ps in parent_summaries:
            parent_id = ps["parent_task_id"]
            if not parent_id:
                continue
            parent_row = conn.execute("SELECT * FROM tasks WHERE id=?", (parent_id,)).fetchone()
            if not parent_row or parent_row["status"] == "done":
                continue
            # Build classification from work_items
            wis = conn.execute("SELECT * FROM work_items WHERE parent_task_id=?", (parent_id,)).fetchall()
            phase = parent_row["kind"].replace("backtest_", "").upper()
            pass_symbols = [w["symbol"] for w in wis if w["verdict"] == "PASS"]
            p2_profit_skipped: list[dict[str, Any]] = []
            if phase == "P2":
                surviving, p2_profit_skipped = _filter_p2_profitable_symbols(conn, parent_id, pass_symbols)
            else:
                surviving = pass_symbols
            verdict = "PASS" if surviving else "STRATEGY_FAIL"
            classification = {
                "verdict": verdict,
                "surviving_symbols": surviving,
                "counts_by_verdict": {
                    v: sum(1 for w in wis if w["verdict"] == v)
                    for v in ("PASS", "FAIL", "INVALID")
                },
                "source": "work_items_aggregate",
            }
            if p2_profit_skipped:
                classification["p2_p3_profit_filter_skipped"] = p2_profit_skipped
            parent_payload = json.loads(parent_row["payload_json"]) if parent_row["payload_json"] else {}
            parent_payload["classification"] = classification
            parent_payload["completed_at_iso"] = started_iso
            conn.execute(
                "UPDATE tasks SET status='done', payload_json=?, updated_at=? WHERE id=?",
                (json.dumps(parent_payload), started_iso, parent_id),
            )
            conn.commit()
            # Auto-enqueue next phase on PASS
            auto_next = None
            if verdict == "PASS":
                next_map = {"P2": "P3", "P3": "P3.5", "P3.5": "P4"}
                npp = next_map.get(phase)
                if npp and npp in SUPPORTED_BACKTEST_PHASES:
                    npp_kind = npp.lower().replace(".", "")  # P3.5 → 'p35' for task kind
                    existing = conn.execute(
                        "SELECT id FROM tasks WHERE kind=? AND payload_json LIKE ?",
                        (f"backtest_{npp_kind}", f"%\"ea_id\": \"{parent_payload.get('ea_id')}\"%"),
                    ).fetchone()
                    if not existing:
                        enq = enqueue_backtest(root, parent_id, npp)
                        if enq.get("enqueued"):
                            auto_next = {"phase": npp, "task_id": enq.get("task_id"),
                                        "work_items_created": len(enq.get("work_items_created", []))}
            actions.append({
                "action": "parent_classified",
                "parent_task_id": parent_id,
                "ea_id": parent_payload.get("ea_id"),
                "phase": phase,
                "verdict": verdict,
                "surviving_symbols": surviving,
                "auto_next": auto_next,
            })

    result = {
        "actions": actions,
        "busy_terminals": sorted(busy_terminals),
        "free_terminals": [t for t in factory_terminals if t not in busy_terminals],
        "scanned_at": started_iso,
        "actually_launched_pids": launched_pids,
        "running_mt5_terminals": sorted(running_mt5_terminals),
    }
    _dispatch_diag("dispatch_end", {
        "actions_count": len(actions),
        "dispatched": sum(1 for a in actions if a.get("action") == "claimed"),
        "busy_terminals": result["busy_terminals"],
        "free_terminals": result["free_terminals"],
        "actually_launched_pids": launched_pids,
        "running_mt5_terminals": result["running_mt5_terminals"],
    })
    _release_dispatch_lock(lock)
    return result


def _spawn_claude_for_review(root: Path, build_task_row: sqlite3.Row) -> dict[str, Any]:
    """Spawn Claude CLI to review one done build_ea task.

    Renders the review prompt via render_claude_review_prompt, then invokes
    claude detached with -p pointing at the rendered prompt. The Claude
    process writes the verdict JSON to verdict_path itself per
    claude_review_ea.md output contract. Next pump cycle picks up the
    verdict and calls record-review.

    Idempotent: if an ea_review task already exists for this build, skip.
    """
    build_task_id = build_task_row["id"]
    # Check if review already exists
    with connect(root) as conn:
        existing = conn.execute(
            "SELECT id FROM tasks WHERE kind='ea_review' AND payload_json LIKE ?",
            (f"%\"build_task_id\": \"{build_task_id}\"%",),
        ).fetchone()
    if existing:
        return {"spawned": False, "reason": "ea_review task already exists", "review_task_id": existing[0]}

    # Render the prompt — also creates the ea_review task row
    rendered = render_claude_review_prompt(root, build_task_id, None)
    if not rendered.get("written"):
        return {"spawned": False, "reason": f"render failed: {rendered.get('reason')}"}
    prompt_path = rendered.get("prompt_path")
    review_task_id = rendered.get("review_task_id")
    verdict_path = rendered.get("verdict_path")

    import shutil as _shutil
    claude_path = _resolve_claude()
    live_log = root / "logs" / f"claude_review_{review_task_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)

    # Feed the prompt via stdin, NOT as the -p argument. Embedding the full
    # rendered review prompt (mq5 + card + build_result + smoke_summary) in a
    # single command-line arg overflows the Windows cmd limit and the claude
    # process dies immediately with "The command line is too long." before
    # writing any verdict — silently stalling every Claude EA review. `claude -p`
    # reads the prompt from stdin when no positional prompt is given. Mirror the
    # working _spawn_codex_for_review stdin pattern.
    prompt_text = Path(prompt_path).read_text(encoding="utf-8") if prompt_path else ""
    bootstrap = (
        "You are a focused QM EA reviewer. Read the prompt I pass + the referenced "
        "files (mq5, card, build_result, smoke_summary). Apply checklist sections "
        f"§0-§7 from claude_review_ea.md. Write the JSON verdict EXACTLY to "
        f"'{verdict_path}'. Then exit cleanly. No prose, no commentary outside "
        f"the JSON file.\n\nReview Prompt:\n\n{prompt_text}"
    )
    prompt_file = Path(prompt_path) if prompt_path else live_log.with_suffix(".prompt.txt")
    prompt_file.write_text(bootstrap, encoding="utf-8", newline="\n")

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    stdin_f = open(prompt_file, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [claude_path, "-p",
         "--permission-mode", "bypassPermissions",
         "--add-dir", "C:\\QM\\repo",
         "--add-dir", "D:\\QM\\strategy_farm",
         "--add-dir", "D:\\QM\\reports"],
        cwd=str(REPO_ROOT),
        env=_claude_env(),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        shell=True,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "ea_id": rendered.get("ea_id"),
        "verdict_path": verdict_path,
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _g0_claim_path(card_path: Path) -> Path:
    """Lock path for atomic G0 claim. Lives next to the card in cards_draft/."""
    return card_path.with_suffix(card_path.suffix + ".g0_claim")


def _claim_g0_cards(card_paths: list[Path], reviewer: str, max_age_sec: int = 1800) -> list[Path]:
    """Atomically claim cards for a G0 reviewer. Returns the actually-claimed
    subset.

    Uses O_CREAT|O_EXCL — first writer wins. Skips cards whose claim file
    already exists AND is fresh (within max_age_sec, default 30 min).
    Stale claim files (older than that) get overwritten — means a previous
    spawn died mid-batch.
    """
    claimed: list[Path] = []
    now = time.time()
    for c in card_paths:
        lock = _g0_claim_path(c)
        if lock.exists():
            try:
                age = now - lock.stat().st_mtime
                if age < max_age_sec:
                    continue  # held by another reviewer
            except OSError:
                pass
        # Try to claim atomically. O_EXCL fails if file exists (race);
        # for stale locks we explicitly overwrite by rm + retry.
        try:
            if lock.exists():
                lock.unlink()
            fd = os.open(str(lock), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            try:
                os.write(fd, f"reviewer={reviewer}\ntimestamp={utc_now()}\n".encode("utf-8"))
            finally:
                os.close(fd)
            claimed.append(c)
        except FileExistsError:
            continue  # lost the race to another spawner
        except OSError:
            continue
    return claimed


def _spawn_claude_for_g0_batch(root: Path) -> dict[str, Any]:
    """Spawn Claude for G0 review of up to 5 draft cards.

    OWNER 2026-05-17: Claude AND Codex both do G0 in parallel. Claim
    mechanism (filesystem .g0_claim locks) prevents double-review.

    Bounded at 5 cards per spawn to cap token burn.
    """
    import shutil as _shutil
    drafts_dir = root / "artifacts" / "cards_draft"
    if not drafts_dir.is_dir():
        return {"spawned": False, "reason": "no cards_draft dir"}
    # Oldest first, skip already-claimed
    drafts = sorted([f for f in drafts_dir.glob("QM5_*.md") if f.is_file()],
                    key=lambda p: p.stat().st_mtime)
    drafts = [d for d in drafts if not _g0_claim_path(d).exists() or
              (time.time() - _g0_claim_path(d).stat().st_mtime) >= 1800]
    if not drafts:
        return {"spawned": False, "reason": "no unclaimed draft cards"}
    batch = _claim_g0_cards(drafts[:5], reviewer="claude")
    if not batch:
        return {"spawned": False, "reason": "all candidates lost race to Codex"}
    batch_paths = "\n".join(f"- {f}" for f in batch)

    claude_path = _resolve_claude()
    live_log = root / "logs" / f"claude_g0_{dt.datetime.utcnow().strftime('%Y%m%dT%H%M%S')}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    if live_log.exists() and (time.time() - live_log.stat().st_mtime) < 60:
        return {"spawned": False, "reason": "claude g0 live log active < 60s"}

    bootstrap = (
        "You are doing focused QM G0 reviews. Read "
        "C:\\QM\\repo\\processes\\qb_reputable_source_criteria.md to refresh "
        "R1-R4 criteria. Then for each draft card in this batch:\n\n"
        f"{batch_paths}\n\n"
        "Apply R1 (source link/attribution), R2 (mechanical Entry+Exit rules), "
        "R3 (testable on >=1 DWX symbol after porting), R4 (no ML / binding HR14). "
        "R2 also requires a plausible trade-frequency estimate. Reject cards that "
        "cannot support at least 2 expected trades/year/symbol unless they provide "
        "defensible basket-level cadence; annual one-shot seasonal edges are too "
        "sparse unless OWNER explicitly marked them approved. "
        "For each card:\n"
        "  - All four PASS  -> run `python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py "
        "approve-card --card \"<path>\" --reasoning \"<R1-R4 one-line rationale>\"`\n"
        "  - Any FAIL       -> run `python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py "
        "reject-card --card \"<path>\" --reason \"<which R + why>\"`\n\n"
        "Use farmctl --help if argument names differ. SP500.DWX is now backtest-only "
        "available (2026-05-16T19:15Z) — R3 PASS with T6-caveat is acceptable. "
        "Process all cards in the batch, then exit cleanly."
    )

    # Feed the prompt via stdin — see _spawn_claude_for_review: a long -p arg
    # overflows the Windows command-line limit and kills the process before it
    # can act ("The command line is too long.").
    prompt_file = live_log.with_suffix(".prompt.txt")
    prompt_file.write_text(bootstrap, encoding="utf-8", newline="\n")
    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    stdin_f = open(prompt_file, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [claude_path, "-p",
         "--permission-mode", "bypassPermissions",
         "--add-dir", "C:\\QM\\repo",
         "--add-dir", "D:\\QM\\strategy_farm"],
        cwd=str(REPO_ROOT),
        env=_claude_env(),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        shell=True,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "batch_size": len(batch),
        "cards": [f.stem for f in batch],
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _spawn_codex_for_g0_batch(root: Path) -> dict[str, Any]:
    """Spawn Codex for G0 review of up to 3 draft cards (smaller batch
    than Claude — Codex iterates through farmctl subprocesses serially).

    Runs in PARALLEL with Claude G0 — claim mechanism prevents both
    workers from grabbing the same card.
    """
    import shutil as _shutil
    drafts_dir = root / "artifacts" / "cards_draft"
    if not drafts_dir.is_dir():
        return {"spawned": False, "reason": "no cards_draft dir"}
    drafts = sorted([f for f in drafts_dir.glob("QM5_*.md") if f.is_file()],
                    key=lambda p: p.stat().st_mtime)
    drafts = [d for d in drafts if not _g0_claim_path(d).exists() or
              (time.time() - _g0_claim_path(d).stat().st_mtime) >= 1800]
    if not drafts:
        return {"spawned": False, "reason": "no unclaimed draft cards"}
    # Codex grabs from the OLDER end too but offset 5 ahead of Claude so they
    # naturally pick different cards in low-pressure case; in high-pressure
    # case the claim race breaks ties.
    candidates = drafts[5:8] + drafts[:5]  # prefer older-but-not-Claude's-first-5
    batch = _claim_g0_cards(candidates, reviewer="codex")[:3]
    if not batch:
        return {"spawned": False, "reason": "all candidates already claimed"}
    batch_paths = "\n".join(f"- {f}" for f in batch)

    codex_path = _resolve_codex()
    ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%S")
    live_log = root / "logs" / f"codex_g0_{ts}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    prompt_path = root / "queue" / f"codex_g0_{ts}.md"
    prompt_path.parent.mkdir(parents=True, exist_ok=True)

    template = CODEX_G0_TEMPLATE.read_text(encoding="utf-8")
    template = template.replace("{{batch_paths}}", batch_paths)
    prompt_path.write_text(template, encoding="utf-8", newline="\n")

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        env=_codex_env(),
        shell=True,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "batch_size": len(batch),
        "cards": [f.stem for f in batch],
        "live_log": str(live_log),
        "prompt_path": str(prompt_path),
        "pid": proc.pid,
    }


def _claim_research_source(root: Path) -> dict[str, Any]:
    """Find next research work and spawn Claude.

    Priority:
      1. Any source with status='active' (continue mining its next batch)
      2. Any source with status='cards_ready' that is eligible to resume
         (its drafted cards have all reached pipeline-end)
      3. Any source with status='notes_ready' (cards can be drafted from notes)
      4. Claim oldest pending source (lowest priority numeric value)
    """
    import shutil as _shutil
    claude_path = _resolve_claude()

    # Skip if a Claude is already running for research.
    # assigned_worker IS NULL = legacy/pre-codex rows → treat as 'claude'.
    with connect(root) as conn:
        active_src = conn.execute(
            "SELECT id, lane, source_type, uri, title, status, notes_path "
            "FROM sources WHERE status='active' "
            "AND (assigned_worker IS NULL OR assigned_worker='claude') LIMIT 1"
        ).fetchone()
    target_source = None
    research_action = None
    if active_src:
        target_source = dict(active_src)
        research_action = "continue_active"
    else:
        # Resume cards_ready first (source flagged "more findable") so sources
        # actually reach 'done' instead of accumulating in cards_ready forever.
        with connect(root) as conn:
            cr = conn.execute(
                "SELECT id, lane, source_type, uri, title, status, notes_path "
                "FROM sources WHERE status='cards_ready' "
                "AND (assigned_worker IS NULL OR assigned_worker='claude') "
                "ORDER BY priority ASC, updated_at ASC LIMIT 1"
            ).fetchone()
        if cr:
            with connect(root) as conn:
                cur = conn.execute(
                    "UPDATE sources SET status='active', assigned_worker='claude', updated_at=? "
                    "WHERE id=? AND status='cards_ready'",
                    (utc_now(), cr["id"]),
                )
                conn.commit()
                claimed = cur.rowcount == 1
            if claimed:
                target_source = dict(cr)
                research_action = "resume_cards_ready"
        if not target_source:
            with connect(root) as conn:
                # try notes_ready next (cards waiting to be drafted)
                nr = conn.execute(
                    "SELECT id, lane, source_type, uri, title, status, notes_path "
                    "FROM sources WHERE status='notes_ready' LIMIT 1"
                ).fetchone()
            if nr:
                with connect(root) as conn:
                    cur = conn.execute(
                        "UPDATE sources SET status='active', assigned_worker='claude', updated_at=? "
                        "WHERE id=? AND status='notes_ready'",
                        (utc_now(), nr["id"]),
                    )
                    conn.commit()
                    claimed = cur.rowcount == 1
                if claimed:
                    target_source = dict(nr)
                    research_action = "draft_cards_from_notes"
        if not target_source:
            with connect(root) as conn:
                pend = conn.execute(
                    "SELECT id, lane, source_type, uri, title, status, notes_path "
                    "FROM sources WHERE status='pending' "
                    "ORDER BY priority ASC, created_at ASC LIMIT 1"
                ).fetchone()
            if pend:
                with connect(root) as conn:
                    cur = conn.execute(
                        "UPDATE sources SET status='active', assigned_worker='claude', updated_at=? "
                        "WHERE id=? AND status='pending'",
                        (utc_now(), pend["id"]),
                    )
                    conn.commit()
                    claimed = cur.rowcount == 1
                if claimed:
                    target_source = dict(pend)
                    target_source["status"] = "active"
                    research_action = "claim_pending_first_batch"
    if not target_source:
        return {"spawned": False, "reason": "no research work available"}

    src_id = target_source["id"]
    live_log = root / "logs" / f"claude_research_{src_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    if live_log.exists() and (time.time() - live_log.stat().st_mtime) < 60:
        return {"spawned": False, "reason": "claude research live log active < 60s", "source_id": src_id}

    bootstrap = (
        "You are a focused QM strategy researcher. Read "
        "C:\\QM\\repo\\tools\\strategy_farm\\prompts\\claude_research_source.md "
        "AND C:\\QM\\repo\\processes\\qb_reputable_source_criteria.md . "
        f"Mine source `{src_id}` ({target_source.get('title')}). "
        "Action: " + (research_action or "draft_cards") + ". "
        "Draft UP TO 5 new strategy cards into "
        "D:\\QM\\strategy_farm\\artifacts\\cards_draft\\QM5_<NNNN>_<slug>.md per the "
        "Strategy Wiki _TEMPLATE Strategy.md format with g0_status: PENDING. "
        "Reserve fresh QM5_<NNNN> IDs ONLY via `python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py "
        "reserve-ea-ids --strategy-id " + str(src_id) + " --slug <slug> [--slug <slug2> ...]`; "
        "never hand-edit or append framework/registry/ea_id_registry.csv. Append notes to "
        f"D:\\QM\\strategy_farm\\artifacts\\source_notes\\{src_id}.md. "
        "At end: if <5 cards or exhausted, run `farmctl set-source-status "
        f"{src_id} done`. If 5 cards + more findable, run `farmctl "
        f"set-source-status {src_id} cards_ready`. Exit cleanly."
    )
    # Feed the prompt via stdin — see _spawn_claude_for_review: a long -p arg
    # overflows the Windows command-line limit and kills the process before it
    # can act ("The command line is too long.").
    prompt_file = live_log.with_suffix(".prompt.txt")
    prompt_file.write_text(bootstrap, encoding="utf-8", newline="\n")
    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    stdin_f = open(prompt_file, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [claude_path, "-p",
         "--permission-mode", "bypassPermissions",
         "--add-dir", "C:\\QM\\repo",
         "--add-dir", "D:\\QM\\strategy_farm",
         "--add-dir", "G:\\My Drive\\QuantMechanica - Company Reference"],
        cwd=str(REPO_ROOT),
        env=_claude_env(),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        shell=True,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "source_id": src_id,
        "title": target_source.get("title"),
        "research_action": research_action,
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _claim_research_source_codex(root: Path) -> dict[str, Any]:
    """Codex twin of `_claim_research_source`.

    Both workers use `status='active'`; the `assigned_worker` column
    ('claude' | 'codex' | NULL→claude) disambiguates so neither claims the
    other's source. The claim UPDATE is conditional on the prior status to
    avoid races when both pump cycles run close together.

    Priority:
      1. status='active' AND assigned_worker='codex' → continue mining
      2. status='notes_ready' (shared with Claude — first claim wins)
      3. status='pending'     (shared with Claude — first claim wins)
    """
    import shutil as _shutil
    codex_path = _resolve_codex()

    target_source = None
    research_action = None
    # Step 1: continue an active source already assigned to codex
    with connect(root) as conn:
        active_src = conn.execute(
            "SELECT id, lane, source_type, uri, title, status, notes_path "
            "FROM sources WHERE status='active' AND assigned_worker='codex' LIMIT 1"
        ).fetchone()
    if active_src:
        target_source = dict(active_src)
        research_action = "continue_active"
    else:
        # Step 2: resume a cards_ready source ("more findable" was flagged
        # by the prior run; we promised to come back and mine more).
        # Without this, every source gets exactly one 5-card session then
        # parked forever, and sources never reach 'done'.
        with connect(root) as conn:
            cr = conn.execute(
                "SELECT id, lane, source_type, uri, title, status, notes_path "
                "FROM sources WHERE status='cards_ready' "
                "ORDER BY priority ASC, updated_at ASC LIMIT 1"
            ).fetchone()
        if cr:
            with connect(root) as conn:
                cur = conn.execute(
                    "UPDATE sources SET status='active', assigned_worker='codex', updated_at=? "
                    "WHERE id=? AND status='cards_ready'",
                    (utc_now(), cr["id"]),
                )
                conn.commit()
                claimed = cur.rowcount == 1
            if claimed:
                target_source = dict(cr)
                research_action = "resume_cards_ready"
        # Step 3: try to claim a notes_ready source
        if not target_source:
            with connect(root) as conn:
                nr = conn.execute(
                    "SELECT id, lane, source_type, uri, title, status, notes_path "
                    "FROM sources WHERE status='notes_ready' LIMIT 1"
                ).fetchone()
            if nr:
                with connect(root) as conn:
                    cur = conn.execute(
                        "UPDATE sources SET status='active', assigned_worker='codex', updated_at=? "
                        "WHERE id=? AND status='notes_ready'",
                        (utc_now(), nr["id"]),
                    )
                    conn.commit()
                    claimed = cur.rowcount == 1
                if claimed:
                    target_source = dict(nr)
                    research_action = "draft_cards_from_notes"
        if not target_source:
            # Step 4: claim pending oldest
            with connect(root) as conn:
                pend = conn.execute(
                    "SELECT id, lane, source_type, uri, title, status, notes_path "
                    "FROM sources WHERE status='pending' "
                    "ORDER BY priority ASC, created_at ASC LIMIT 1"
                ).fetchone()
            if pend:
                with connect(root) as conn:
                    cur = conn.execute(
                        "UPDATE sources SET status='active', assigned_worker='codex', updated_at=? "
                        "WHERE id=? AND status='pending'",
                        (utc_now(), pend["id"]),
                    )
                    conn.commit()
                    claimed = cur.rowcount == 1
                if claimed:
                    target_source = dict(pend)
                    research_action = "claim_pending_first_batch"
    if not target_source:
        return {"spawned": False, "reason": "no research work available for codex"}

    src_id = target_source["id"]
    live_log = root / "logs" / f"codex_research_{src_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    if live_log.exists() and (time.time() - live_log.stat().st_mtime) < 60:
        return {"spawned": False, "reason": "codex research live log active < 60s", "source_id": src_id}

    # Render bootstrap prompt from template
    prompt_path = root / "queue" / f"codex_research_{src_id}.md"
    prompt_path.parent.mkdir(parents=True, exist_ok=True)
    template = CODEX_RESEARCH_TEMPLATE.read_text(encoding="utf-8")
    for k, v in [
        ("source_id", src_id),
        ("title", target_source.get("title") or ""),
        ("uri", target_source.get("uri") or ""),
        ("action", research_action or ""),
    ]:
        template = template.replace("{{" + k + "}}", str(v))
    prompt_path.write_text(template, encoding="utf-8", newline="\n")

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        env=_codex_env(),
        shell=True,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "source_id": src_id,
        "title": target_source.get("title"),
        "research_action": research_action,
        "live_log": str(live_log),
        "prompt_path": str(prompt_path),
        "pid": proc.pid,
    }


def _spawn_codex_for_review(root: Path, build_task_row: sqlite3.Row) -> dict[str, Any]:
    """Spawn Codex CLI to perform the pump-compatible EA review.

    This creates the same ea_review task/verdict contract as Claude:
    record_review_result expects APPROVE_FOR_BACKTEST or REJECT_REWORK.
    """
    build_task_id = build_task_row["id"]
    with connect(root) as conn:
        existing = conn.execute(
            "SELECT id FROM tasks WHERE kind='ea_review' AND payload_json LIKE ?",
            (f"%\"build_task_id\": \"{build_task_id}\"%",),
        ).fetchone()
    if existing:
        return {"spawned": False, "reason": "ea_review task already exists", "review_task_id": existing[0]}

    rendered = render_claude_review_prompt(root, build_task_id, None)
    if not rendered.get("written"):
        return {"spawned": False, "reason": f"render failed: {rendered.get('reason')}"}
    prompt_path = rendered.get("prompt_path")
    review_task_id = rendered.get("review_task_id")
    verdict_path = rendered.get("verdict_path")
    if prompt_path:
        prompt_file = Path(prompt_path)
        prompt_text = prompt_file.read_text(encoding="utf-8")
        prompt_file.write_text(
            "You are Codex performing the QM EA policy review. Follow the "
            "review prompt below exactly. Write the JSON verdict to the "
            f"specified verdict_path ('{verdict_path}') and exit cleanly. "
            "Do not write prose outside the JSON file.\n\n"
            + prompt_text,
            encoding="utf-8",
            newline="\n",
        )

    codex_path = _resolve_codex()
    live_log = root / "logs" / f"codex_ea_review_{review_task_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        env=_codex_env(),
        shell=True,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "ea_id": rendered.get("ea_id"),
        "verdict_path": verdict_path,
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _spawn_codex_for_pre_review(root: Path, build_task_row: sqlite3.Row) -> dict[str, Any]:
    """Spawn Codex CLI to mechanically pre-review one done build_ea task.

    Codex runs BEFORE Claude review (cheaper, deterministic). Codex's verdict
    JSON appears at `verdict_path`; if PASS → pump spawns Claude review; if
    FAIL → pump blocks the build with reason='codex_review_fail' so retry
    logic can re-run build (rework).

    Idempotent: if a codex_review task already exists for this build, skip.
    Creates a separate codex_review task row (distinct kind from ea_review)
    with payload.build_task_id + payload.verdict_path.
    """
    build_task_id = build_task_row["id"]
    with connect(root) as conn:
        existing = conn.execute(
            "SELECT id, status FROM tasks WHERE kind='codex_review' AND payload_json LIKE ?",
            (f"%\"build_task_id\": \"{build_task_id}\"%",),
        ).fetchone()
    if existing:
        return {
            "spawned": False,
            "reason": f"codex_review task exists status={existing['status']}",
            "codex_review_task_id": existing["id"],
        }

    payload_build = json.loads(build_task_row["payload_json"])
    codex_result = payload_build.get("codex_result") or {}
    mq5_path = codex_result.get("mq5_path") or ""
    ex5_path = codex_result.get("ex5_path") or ""
    smoke_report_path = codex_result.get("smoke_report_path") or ""

    with connect(root) as conn:
        review_task_id = create_task(
            conn,
            kind="codex_review",
            source_id=build_task_row["source_id"],
            card_id=build_task_row["card_id"],
            payload={
                "build_task_id": build_task_id,
                "ea_id": payload_build.get("ea_id"),
                "card_path": payload_build.get("card_path"),
                "mq5_path": mq5_path,
                "ex5_path": ex5_path,
                "smoke_report_path": smoke_report_path,
                "build_result_path": str(root / "artifacts" / "builds" / f"{build_task_id}.json"),
            },
        )
    verdict_path = root / "artifacts" / "verdicts" / f"codex_review_{review_task_id}.json"
    verdict_path.parent.mkdir(parents=True, exist_ok=True)
    with connect(root) as conn:
        # Persist verdict_path back to payload so record-review can find it
        row = conn.execute("SELECT payload_json FROM tasks WHERE id=?", (review_task_id,)).fetchone()
        p = json.loads(row["payload_json"])
        p["verdict_path"] = str(verdict_path)
        conn.execute("UPDATE tasks SET payload_json=? WHERE id=?", (json.dumps(p), review_task_id))
        conn.commit()

    template = CODEX_REVIEW_TEMPLATE.read_text(encoding="utf-8")
    for k, v in [
        ("review_task_id", review_task_id),
        ("build_task_id", build_task_id),
        ("ea_id", payload_build.get("ea_id") or ""),
        ("card_path", payload_build.get("card_path") or ""),
        ("mq5_path", mq5_path),
        ("ex5_path", ex5_path),
        ("smoke_report_path", smoke_report_path),
        ("build_result_path", str(root / "artifacts" / "builds" / f"{build_task_id}.json")),
        ("verdict_path", str(verdict_path)),
    ]:
        template = template.replace("{{" + k + "}}", str(v))

    prompt_path = root / "queue" / f"codex_review_{review_task_id}.md"
    prompt_path.parent.mkdir(parents=True, exist_ok=True)
    prompt_path.write_text(template, encoding="utf-8", newline="\n")

    import shutil as _shutil
    codex_path = _resolve_codex()
    live_log = root / "logs" / f"codex_review_{review_task_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        env=_codex_env(),
        shell=True,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "codex_review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "ea_id": payload_build.get("ea_id"),
        "verdict_path": str(verdict_path),
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _pre_review_ready(root: Path, build_task_row: sqlite3.Row) -> tuple[bool, str]:
    """Return whether a done build has enough durable artifacts for Codex review."""
    build_task_id = build_task_row["id"]
    build_result_path = root / "artifacts" / "builds" / f"{build_task_id}.json"
    if not build_result_path.exists():
        return False, "missing_build_result"
    try:
        build_result = json.loads(build_result_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return False, "invalid_build_result"
    if build_result.get("blocked_reason"):
        return False, "build_result_blocked"
    if build_result.get("compile_succeeded") is not True:
        return False, "compile_not_passed"
    if build_result.get("build_check_passed") is not True:
        return False, "build_check_not_passed"
    for key in ("mq5_path", "ex5_path"):
        p = build_result.get(key)
        if not p or not Path(str(p)).exists():
            return False, f"missing_{key}"
    return True, ""


def _block_unreviewable_build(root: Path, build_task_row: sqlite3.Row, reason: str) -> dict[str, Any]:
    payload = json.loads(build_task_row["payload_json"])
    blocked_reason = f"pre_review_not_reviewable:{reason}"
    payload["blocked_reason"] = payload.get("blocked_reason") or blocked_reason
    payload["pre_review_not_reviewable_reason"] = reason
    payload["attempt"] = int(payload.get("attempt", 0)) + 1
    with connect(root) as conn:
        conn.execute(
            "UPDATE tasks SET status='blocked', payload_json=?, updated_at=? WHERE id=?",
            (json.dumps(payload), utc_now(), build_task_row["id"]),
        )
        event(conn, "task", build_task_row["id"], "build_pre_review_not_reviewable", {
            "reason": reason,
            "saved_codex_review_spawn": True,
        })
        conn.commit()
    return {
        "spawned": False,
        "build_task_id": build_task_row["id"],
        "ea_id": payload.get("ea_id"),
        "reason": blocked_reason,
    }


def _record_codex_review_result(root: Path, review_task_id: str, verdict_path: str) -> dict[str, Any]:
    """Read a completed codex_review verdict, mark the task done, return the verdict.

    Pump uses the returned verdict to decide whether to spawn claude_review
    (PASS) or block the build (FAIL).
    """
    vp = Path(verdict_path)
    if not vp.exists() or vp.stat().st_size == 0:
        return {"recorded": False, "reason": "verdict not yet written"}
    try:
        v = json.loads(vp.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"recorded": False, "reason": f"verdict json invalid: {exc}"}
    verdict = (v.get("verdict") or "").upper()
    if verdict not in ("PASS", "FAIL"):
        return {"recorded": False, "reason": f"verdict must be PASS|FAIL, got {verdict!r}"}
    with connect(root) as conn:
        row = conn.execute("SELECT payload_json FROM tasks WHERE id=?", (review_task_id,)).fetchone()
        if not row:
            return {"recorded": False, "reason": "review task not found"}
        payload = json.loads(row["payload_json"])
        payload["verdict"] = verdict
        payload["findings"] = v.get("findings") or []
        payload["sections"] = v.get("sections") or {}
        conn.execute(
            "UPDATE tasks SET status='done', payload_json=?, updated_at=? WHERE id=?",
            (json.dumps(payload), utc_now(), review_task_id),
        )
        event(conn, "task", review_task_id, "codex_review_recorded", {
            "verdict": verdict,
            "findings_count": len(payload["findings"]),
            "build_task_id": payload.get("build_task_id"),
        })
        conn.commit()
    return {
        "recorded": True,
        "review_task_id": review_task_id,
        "verdict": verdict,
        "build_task_id": payload.get("build_task_id"),
        "findings_count": len(payload["findings"]),
    }


def _spawn_codex_for_build(root: Path, task_row: sqlite3.Row) -> dict[str, Any]:
    """Spawn Codex CLI as a detached process for a pending build_ea task.

    Idempotent: if a codex_build_<task_id>.live.log is being actively
    written (size growing) → consider already-running and skip. Otherwise
    spawn fresh. The Codex process writes the build_result JSON itself per
    the codex_build_ea.md output contract; subsequent pump cycles will see
    the build_ea row transition to done via record-build (called by the
    hourly wake or a future Claude-worker pump cycle).
    """
    payload = json.loads(task_row["payload_json"])
    ea_id = payload.get("ea_id")
    slug = payload.get("slug")
    card_path = payload.get("card_path")
    prompt_path = payload.get("prompt_path")
    if not prompt_path:
        # Render now via build-ea logic (it'll create a NEW task — but we
        # already have one. So re-derive prompt path manually).
        if not card_path:
            return {"spawned": False, "reason": "no card_path in payload"}
        prompt_path = str(root / "queue" / f"codex_build_{task_row['id']}.md")
        # Render prompt
        build_result_path = str(root / "artifacts" / "builds" / f"{task_row['id']}.json")
        Path(prompt_path).parent.mkdir(parents=True, exist_ok=True)
        Path(build_result_path).parent.mkdir(parents=True, exist_ok=True)
        template = CODEX_BUILD_TEMPLATE.read_text(encoding="utf-8")
        for k, v in [
            ("task_id", task_row["id"]),
            ("ea_id", ea_id),
            ("slug", slug or ""),
            ("card_path", card_path or ""),
            ("source_id", ""),
            ("ea_dir", str(FRAMEWORK_EAS_DIR / f"{ea_id}_{slug}")),
            ("build_result_path", build_result_path),
        ]:
            template = template.replace("{{" + k + "}}", str(v))
        Path(prompt_path).write_text(template, encoding="utf-8", newline="\n")
        # Persist back to task payload
        payload["prompt_path"] = prompt_path
        payload["build_result_path"] = build_result_path
        with connect(root) as conn:
            conn.execute("UPDATE tasks SET payload_json=? WHERE id=?", (json.dumps(payload), task_row["id"]))
            conn.commit()

    live_log = root / "logs" / f"codex_build_{task_row['id']}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    # Check if already running (live log growing in last 60s)
    if live_log.exists():
        age_sec = time.time() - live_log.stat().st_mtime
        if age_sec < 60:
            return {"spawned": False, "reason": "live log activity within 60s — codex likely still running", "task_id": task_row["id"]}

    # Spawn: cat prompt | codex exec -s danger-full-access --cd C:/QM/repo 2>&1 | tee live_log
    # We do this through a shell wrapper to chain cat+tee on Windows.
    # Detached so pump doesn't wait.
    # Direct Popen — codex.cmd is an npm batch shim; subprocess can exec it
    # via shell=True. stdin piped from prompt file, stdout/stderr to live_log.
    import shutil as _shutil
    codex_path = _resolve_codex()
    creationflags = 0
    if sys.platform == "win32":
        # CREATE_NO_WINDOW: child gets a console but it stays hidden (no popup
        # on OWNER's desktop). DETACHED_PROCESS would make codex.cmd's batch
        # shim exit immediately without running node, so we stay attached-but-
        # hidden via CREATE_NO_WINDOW.
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        env=_codex_env(),
        shell=True,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "agent": "codex",
        "task_id": task_row["id"],
        "ea_id": ea_id,
        "pid": proc.pid,
        "live_log": str(live_log),
    }


def _spawn_gemini_for_build(root: Path, task_row: sqlite3.Row) -> dict[str, Any]:
    """Spawn Gemini CLI for a pending build_ea task using the Codex build contract.

    Gemini is allowed to draft/implement, but completion still flows through
    record-build and the existing Codex pre-review gate before any backtest.
    """
    payload = json.loads(task_row["payload_json"])
    ea_id = payload.get("ea_id")
    slug = payload.get("slug")
    card_path = payload.get("card_path")
    prompt_path = payload.get("prompt_path")
    if not prompt_path:
        if not card_path:
            return {"spawned": False, "agent": "gemini", "reason": "no card_path in payload"}
        prompt_path = str(root / "queue" / f"gemini_build_{task_row['id']}.md")
        build_result_path = str(root / "artifacts" / "builds" / f"{task_row['id']}.json")
        Path(prompt_path).parent.mkdir(parents=True, exist_ok=True)
        Path(build_result_path).parent.mkdir(parents=True, exist_ok=True)
        template = CODEX_BUILD_TEMPLATE.read_text(encoding="utf-8")
        for k, v in [
            ("task_id", task_row["id"]),
            ("ea_id", ea_id),
            ("slug", slug or ""),
            ("card_path", card_path or ""),
            ("source_id", ""),
            ("ea_dir", str(FRAMEWORK_EAS_DIR / f"{ea_id}_{slug}")),
            ("build_result_path", build_result_path),
        ]:
            template = template.replace("{{" + k + "}}", str(v))
        Path(prompt_path).write_text(
            "You are Gemini drafting a QuantMechanica EA build. Follow the "
            "same build contract below exactly. Codex will review your output "
            "before it can enter backtest. Write the required JSON result and "
            "exit cleanly.\n\n" + template,
            encoding="utf-8",
            newline="\n",
        )
        payload["prompt_path"] = prompt_path
        payload["build_result_path"] = build_result_path
        payload["build_agent"] = "gemini"
        with connect(root) as conn:
            conn.execute("UPDATE tasks SET payload_json=? WHERE id=?", (json.dumps(payload), task_row["id"]))
            conn.commit()

    live_log = root / "logs" / f"gemini_build_{task_row['id']}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    if live_log.exists():
        age_sec = time.time() - live_log.stat().st_mtime
        if age_sec < 60:
            return {"spawned": False, "agent": "gemini", "reason": "live log activity within 60s - gemini likely still running", "task_id": task_row["id"]}

    launcher, shell_needed = _resolve_gemini_command()
    cmd = [
        *launcher,
        "--prompt",
        "Execute the QuantMechanica EA build instructions from stdin.",
        "--approval-mode",
        "yolo",
        "--skip-trust",
        "--output-format",
        "text",
        "--include-directories",
        str(REPO_ROOT),
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        cmd,
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        env=_gemini_env(),
        shell=shell_needed,
        creationflags=creationflags,
        close_fds=True,
    )
    return {
        "spawned": True,
        "agent": "gemini",
        "task_id": task_row["id"],
        "ea_id": ea_id,
        "pid": proc.pid,
        "live_log": str(live_log),
    }


def _is_zero_trade_failure_payload(payload_json: str | None, evidence_path: str | None) -> bool:
    invalid_report_reasons = {"NO_HISTORY", "NO_REAL_TICKS", "INVALID_REPORT"}
    if payload_json and "MIN_TRADES_NOT_MET" in payload_json:
        try:
            data = json.loads(payload_json)
            reason_classes = data.get("reason_classes") or []
            explicit_reasons = {
                str(data.get("verdict_reason") or "").upper(),
                str(data.get("reason_class") or "").upper(),
                str(data.get("reason") or "").upper(),
            }
            explicit_reasons.update(str(r).upper() for r in reason_classes)
            if explicit_reasons & invalid_report_reasons:
                return False
        except Exception:
            pass
        return True
    if not evidence_path:
        return False
    try:
        p = Path(evidence_path)
        if not p.exists() or p.stat().st_size <= 0:
            return False
        text = p.read_text(encoding="utf-8", errors="ignore")
        if "MIN_TRADES_NOT_MET" in text:
            if any(reason in text for reason in invalid_report_reasons):
                return False
            return True
        data = json.loads(text)
        reason_classes = data.get("reason_classes") or []
        if any(str(r).upper() in invalid_report_reasons for r in reason_classes):
            return False
        if any(str(r).upper() == "MIN_TRADES_NOT_MET" for r in reason_classes):
            return True
        reason = str(data.get("reason_class") or data.get("reason") or "").upper()
        if reason in invalid_report_reasons:
            return False
        return "MIN_TRADES_NOT_MET" in reason
    except Exception:
        return False


def _is_active_timeout_payload(payload_json: str | None) -> bool:
    if not payload_json or "ACTIVE_TIMEOUT" not in payload_json:
        return False
    try:
        data = json.loads(payload_json)
        reason_classes = data.get("reason_classes") or []
        if any(str(r).upper() == "ACTIVE_TIMEOUT" for r in reason_classes):
            return True
        return str(data.get("verdict_reason") or data.get("reason") or "").upper() == "ACTIVE_TIMEOUT"
    except Exception:
        return "ACTIVE_TIMEOUT" in payload_json


def _recent_zero_trade_rework_exists(con: sqlite3.Connection, ea_id: str) -> bool:
    cutoff = (dt.datetime.now(dt.UTC) - dt.timedelta(hours=ZERO_TRADE_REWORK_DEDUP_HOURS)).replace(microsecond=0).isoformat()
    # Dedup if either (a) a rework of this kind was created within the dedup
    # window, OR (b) any rework of this kind is still pending — otherwise a
    # new pending duplicate gets stacked every cycle while the first one
    # waits in queue (observed for QM5_1087/QM5_1119 2026-05-18).
    row = con.execute(
        """
        SELECT id FROM tasks
        WHERE card_id=? AND kind='build_ea'
          AND payload_json LIKE '%ZERO_TRADE_RECURRENT%'
          AND (created_at >= ? OR status='pending')
        ORDER BY created_at DESC LIMIT 1
        """,
        (ea_id, cutoff),
    ).fetchone()
    return row is not None


def _recent_hang_rework_exists(con: sqlite3.Connection, ea_id: str) -> bool:
    cutoff = (dt.datetime.now(dt.UTC) - dt.timedelta(hours=ZERO_TRADE_REWORK_DEDUP_HOURS)).replace(microsecond=0).isoformat()
    row = con.execute(
        """
        SELECT id FROM tasks
        WHERE card_id=? AND kind='build_ea'
          AND payload_json LIKE '%STRATEGY_HANG_RECURRENT%'
          AND (created_at >= ? OR status='pending')
        ORDER BY created_at DESC LIMIT 1
        """,
        (ea_id, cutoff),
    ).fetchone()
    return row is not None


def _find_first_path(patterns: list[tuple[Path, str]]) -> Path | None:
    for base, pattern in patterns:
        if not base.exists():
            continue
        matches = sorted(base.glob(pattern))
        if matches:
            return matches[0]
    return None


def _write_zerotrade_rework_codex_task(
    root: Path,
    ea_id: str,
    ratio: float,
    done: int,
    zt: int,
    task_id: str,
    evidence_paths: list[str],
) -> Path:
    inbox = root / "codex_inbox"
    inbox.mkdir(parents=True, exist_ok=True)

    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    md_task_id = f"auto-rework-{ea_id}-{stamp}"
    target = inbox / f"{md_task_id}.md"

    card_path = _find_first_path([
        (root / "artifacts" / "cards_approved", f"{ea_id}_*.md"),
        (root / "artifacts" / "cards_draft", f"{ea_id}_*.md"),
    ])
    source_path = _find_first_path([(FRAMEWORK_EAS_DIR, f"{ea_id}_*/{ea_id}_*.mq5")])

    evidence_lines = evidence_paths[:5] or ["<none recorded>"]
    evidence_md = "\n".join(f"- {p}" for p in evidence_lines)

    body = f"""---
task_id: {md_task_id}
priority: med
created: {dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}
auto_generated: true
trigger: ZERO_TRADE_RECURRENT
db_task_id: {task_id}
---

# Auto-detected zero-trade rework: {ea_id}

Pump detected that {ea_id} has {ratio:.0%} zero-trade FAIL ratio ({zt}/{done} P2 done work_items returned MIN_TRADES_NOT_MET). Strategy logic likely has an entry-condition bug.

## Files to investigate

- Card: {card_path if card_path else '<card not found>'}
- Source: {source_path if source_path else '<source not found>'}
- 5 zero-trade summary.jsons:
{evidence_md}

## What to do

Same shape as task #019 diagnosis: identify the specific rejecting test and propose a patch. Do not apply the patch; Claude reviews and commits.

## Output

`D:/QM/strategy_farm/codex_outbox/{md_task_id}_result.md`

## Acceptance criteria

- 3+ `.mq5:line` citations identifying the rejecting test
- Patch proposal OR verdict: `DEAD`, `REWORK`, or `PROP_FIRM_INCOMPATIBLE`
- No commit / no push
"""

    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(body, encoding="utf-8", newline="\n")
    tmp.replace(target)
    return target


def _write_strategy_hang_rework_codex_task(
    root: Path,
    ea_id: str,
    ratio: float,
    samples: int,
    timeouts: int,
    task_id: str,
    evidence_paths: list[str],
) -> Path:
    inbox = root / "codex_inbox"
    inbox.mkdir(parents=True, exist_ok=True)

    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    md_task_id = f"auto-rework-{ea_id}-hang-{stamp}"
    target = inbox / f"{md_task_id}.md"

    card_path = _find_first_path([
        (root / "artifacts" / "cards_approved", f"{ea_id}_*.md"),
        (root / "artifacts" / "cards_draft", f"{ea_id}_*.md"),
    ])
    source_path = _find_first_path([(FRAMEWORK_EAS_DIR, f"{ea_id}_*/{ea_id}_*.mq5")])
    evidence_md = "\n".join(f"- {p}" for p in (evidence_paths[:5] or ["<none recorded>"]))

    body = f"""---
task_id: {md_task_id}
priority: high
created: {dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}
auto_generated: true
trigger: STRATEGY_HANG_RECURRENT
db_task_id: {task_id}
---

# Auto-detected strategy hang rework: {ea_id}

Pump detected that {ea_id} has {ratio:.0%} ACTIVE_TIMEOUT ratio ({timeouts}/{samples} finished P2 samples). Strategy logic likely hangs or triggers pathological tester runtime.

## Files to investigate

- Card: {card_path if card_path else '<card not found>'}
- Source: {source_path if source_path else '<source not found>'}
- Timeout evidence:
{evidence_md}

## What to do

Identify the infinite loop / pathological data wait / tester hang cause. Do not deploy to T6. No commit / no push.

## Output

`D:/QM/strategy_farm/codex_outbox/{md_task_id}_result.md`
"""

    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(body, encoding="utf-8", newline="\n")
    tmp.replace(target)
    return target


def _detect_zerotrade_dead_eas(con: sqlite3.Connection, root: Path = DEFAULT_ROOT) -> list[dict[str, Any]]:
    """
    Find EAs where >=80% of done P2 work_items are FAILs caused by
    MIN_TRADES_NOT_MET, with at least 5 done P2 samples. Create one fresh
    build_ea retry task plus one bridge .md task, de-duped over 6 hours.
    """
    rows = con.execute(
        """
        SELECT ea_id, verdict, payload_json, evidence_path, updated_at
        FROM work_items
        WHERE phase in ('Q02', 'P2') AND status in ('done', 'failed')
        """
    ).fetchall()

    grouped: dict[str, dict[str, Any]] = {}
    for r in rows:
        ea_id = r["ea_id"]
        bucket = grouped.setdefault(ea_id, {"done": 0, "zt": 0, "timeouts": 0, "evidence": []})
        bucket["done"] += 1
        if (r["verdict"] or "").upper() == "FAIL" and _is_zero_trade_failure_payload(r["payload_json"], r["evidence_path"]):
            bucket["zt"] += 1
            if r["evidence_path"]:
                bucket["evidence"].append(r["evidence_path"])
        if _is_active_timeout_payload(r["payload_json"]):
            bucket["timeouts"] += 1
            if r["evidence_path"]:
                bucket["evidence"].append(r["evidence_path"])

    flagged: list[dict[str, Any]] = []
    for ea_id, stats in sorted(grouped.items()):
        done = int(stats["done"])
        zt = int(stats["zt"])
        timeouts = int(stats["timeouts"])
        if done < ZERO_TRADE_DEAD_MIN_DONE:
            continue
        timeout_ratio = timeouts / done if done else 0.0
        if timeout_ratio > 0.50:
            if _recent_hang_rework_exists(con, ea_id):
                continue
            card_path = _find_first_path([
                (root / "artifacts" / "cards_approved", f"{ea_id}_*.md"),
                (root / "artifacts" / "cards_draft", f"{ea_id}_*.md"),
            ])
            frontmatter: dict[str, Any] = {}
            slug = ""
            if card_path:
                try:
                    frontmatter = parse_card_frontmatter(card_path)
                    slug = str(frontmatter.get("slug") or "")
                except Exception:
                    frontmatter = {}
            ea_dir = _find_first_path([(FRAMEWORK_EAS_DIR, f"{ea_id}_*")])
            payload = {
                "rework_reason": "STRATEGY_HANG_RECURRENT",
                "ea_id": ea_id,
                "slug": slug,
                "card_path": str(card_path) if card_path else "",
                "ea_dir": str(ea_dir) if ea_dir else "",
                "frontmatter": frontmatter,
                "active_timeout_ratio": timeout_ratio,
                "active_timeout_failures": timeouts,
                "sample_size": done,
                "trigger_ts": utc_now(),
            }
            task_id = create_task(con, kind="build_ea", source_id=None, card_id=ea_id, payload=payload)
            md_path = _write_strategy_hang_rework_codex_task(
                root, ea_id, timeout_ratio, done, timeouts, task_id, list(stats["evidence"])
            )
            con.execute(
                "UPDATE tasks SET payload_json=?, updated_at=? WHERE id=?",
                (json.dumps({**payload, "codex_inbox_task_path": str(md_path)}, sort_keys=True), utc_now(), task_id),
            )
            flagged.append({
                "ea_id": ea_id,
                "rework_reason": "STRATEGY_HANG_RECURRENT",
                "active_timeout_ratio": timeout_ratio,
                "active_timeout_failures": timeouts,
                "sample_size": done,
                "task_id": task_id,
                "codex_inbox_task_path": str(md_path),
            })
            continue
        ratio = zt / done if done else 0.0
        if ratio < ZERO_TRADE_DEAD_THRESHOLD:
            continue
        if _recent_zero_trade_rework_exists(con, ea_id):
            continue
        prior_attempts = con.execute(
            """
            SELECT COUNT(*) FROM tasks
            WHERE card_id=? AND kind='build_ea'
              AND payload_json LIKE '%ZERO_TRADE_RECURRENT%'
            """,
            (ea_id,),
        ).fetchone()[0]
        if prior_attempts >= 3:
            event(con, "ea", ea_id, "ea_dead_zero_trade_3x_rework_failed", {
                "verdict": "DEAD_ZERO_TRADE_3X_REWORK_FAILED",
                "zero_trade_ratio": ratio,
                "sample_size": done,
                "zero_trade_failures": zt,
            })
            continue

        card_path = _find_first_path([
            (root / "artifacts" / "cards_approved", f"{ea_id}_*.md"),
            (root / "artifacts" / "cards_draft", f"{ea_id}_*.md"),
        ])
        frontmatter: dict[str, Any] = {}
        slug = ""
        if card_path:
            try:
                frontmatter = parse_card_frontmatter(card_path)
                slug = str(frontmatter.get("slug") or "")
            except Exception:
                frontmatter = {}
        ea_dir = _find_first_path([(FRAMEWORK_EAS_DIR, f"{ea_id}_*")])

        payload = {
            "rework_reason": "ZERO_TRADE_RECURRENT",
            "ea_id": ea_id,
            "slug": slug,
            "card_path": str(card_path) if card_path else "",
            "ea_dir": str(ea_dir) if ea_dir else "",
            "frontmatter": frontmatter,
            "zero_trade_ratio": ratio,
            "zero_trade_failures": zt,
            "sample_size": done,
            "rework_attempt_count": int(prior_attempts) + 1,
            "trigger_ts": utc_now(),
            "evidence_query": (
                "SELECT evidence_path FROM work_items WHERE ea_id='"
                + ea_id
                + "' AND verdict='FAIL' AND payload_json LIKE '%MIN_TRADES_NOT_MET%' LIMIT 5"
            ),
        }
        task_id = create_task(
            con,
            kind="build_ea",
            source_id=None,
            card_id=ea_id,
            payload=payload,
        )
        md_path = _write_zerotrade_rework_codex_task(
            root,
            ea_id,
            ratio,
            done,
            zt,
            task_id,
            list(stats["evidence"]),
        )
        con.execute(
            "UPDATE tasks SET payload_json=?, updated_at=? WHERE id=?",
            (json.dumps({**payload, "codex_inbox_task_path": str(md_path)}, sort_keys=True), utc_now(), task_id),
        )
        flagged.append({
            "ea_id": ea_id,
            "zero_trade_ratio": ratio,
            "zero_trade_failures": zt,
            "sample_size": done,
            "task_id": task_id,
            "codex_inbox_task_path": str(md_path),
        })

    if flagged:
        con.commit()
    return flagged


def _has_auto_build_task_file(root: Path, ea_id: str) -> bool:
    inbox = root / "codex_inbox"
    for rel in ("", ".processing", ".archive"):
        d = inbox / rel if rel else inbox
        if d.is_dir() and any(d.glob(f"auto-build-{ea_id}-*.md")):
            return True
    return False


def _detect_unbuilt_cards(root: Path) -> list[dict[str, Any]]:
    """
    Find approved cards where the matching EA .ex5 does not exist yet and
    no bridge auto-build task has already been written.

    PT10 2026-05-23 — only return cards whose R-gate evaluations have
    already PASSED. Pre-PT10 the function returned cards alphabetically by
    ea_id; the low-id end of the corpus is the old pre-schema-rewrite cards
    that lack R-eval, so every pump cycle tried 10 such cards and all 10
    skipped with prebuild_validation failed → auto_build_queued stayed at 0
    forever. Now: filter to cards with R1-R4=PASS up front (cheap
    frontmatter parse, no heavy preflight) so the queue actually drains.
    Unready cards (UNKNOWN/FAIL) are waiting on the separate R-eval flow
    and will become eligible once that completes.
    """
    cards_dir = root / "artifacts" / "cards_approved"
    if not cards_dir.is_dir():
        return []

    unbuilt: list[dict[str, Any]] = []
    for card_md in sorted(cards_dir.glob("QM5_*.md")):
        m = re.match(r"(QM5_\d{4})_(.+)\.md$", card_md.name)
        if not m:
            continue
        ea_id, slug = m.group(1), m.group(2)
        label = f"{ea_id}_{slug}"
        ea_dir = FRAMEWORK_EAS_DIR / label
        ex5 = ea_dir / f"{label}.ex5"
        if ex5.exists():
            continue
        if _has_auto_build_task_file(root, ea_id):
            continue
        # PT10 — gate on the same R fields that prebuild_validate_card requires
        # before emitting a build task.
        try:
            fm = parse_card_frontmatter(card_md)
            if any(str(fm.get(key) or "").strip().upper() != "PASS"
                   for key in ("r1_track_record", "r2_mechanical", "r3_data_available", "r4_ml_forbidden")):
                continue
        except Exception:
            continue
        unbuilt.append({
            "ea_id": ea_id,
            "slug": slug,
            "label": label,
            "card_path": str(card_md),
            "expected_ex5": str(ex5),
        })
    return unbuilt


def _slug_from_research_line(line: str) -> str | None:
    m = re.search(r"(QM5_\d{4}_[A-Za-z0-9_.-]+)", line)
    if not m:
        return None
    return m.group(1).replace(".", "-")


def _extract_cards_from_research_results(root: Path, limit: int = 10) -> list[dict[str, Any]]:
    """Convert bridge research result proposals into draft card stubs.

    The extractor is intentionally conservative: it looks for QM5 slug
    mentions in `*research*_result.md` outbox files and writes one draft per
    unseen slug, preserving a source pointer back to the research result.
    """
    outbox = root / "codex_outbox"
    draft_dir = root / "artifacts" / "cards_draft"
    draft_dir.mkdir(parents=True, exist_ok=True)
    created: list[dict[str, Any]] = []
    if not outbox.is_dir():
        return created
    for result_md in sorted(outbox.glob("*research*_result.md")):
        text = result_md.read_text(encoding="utf-8", errors="ignore")
        for line in text.splitlines():
            slug = _slug_from_research_line(line)
            if not slug:
                continue
            target = draft_dir / f"{slug}.md"
            if target.exists():
                continue
            parts = slug.split("_", 2)
            if len(parts) < 3:
                continue
            ea_id = f"{parts[0]}_{parts[1]}"
            simple_slug = parts[2]
            body = f"""---
ea_id: {ea_id}
slug: {simple_slug}
status: draft
source_result: {result_md}
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
created_at: {utc_now()}
---

# {slug}

Extracted from research result `{result_md}`.

## Raw Proposal Line

{line.strip()}

## Source

See the originating research result for citations and ranking context.

## Entry

UNKNOWN - queued for R-eval/card completion.

## Exit

UNKNOWN - queued for R-eval/card completion.

## Stop

UNKNOWN - queued for R-eval/card completion.

## Target symbol(s)

UNKNOWN

## Period

UNKNOWN
"""
            target.write_text(body, encoding="utf-8", newline="\n")
            created.append({"slug": slug, "card_path": str(target), "source_result": str(result_md)})
            if len(created) >= limit:
                return created
    return created


def _card_frontmatter_block(text: str) -> tuple[dict[str, str], str]:
    text = text.lstrip("\ufeff")
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n?", text, re.DOTALL)
    if not m:
        return {}, text
    fm: dict[str, str] = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip().strip('"')
    return fm, text[m.end():]


def _update_flat_frontmatter_file(path: Path, updates: dict[str, str]) -> None:
    text = path.read_text(encoding="utf-8-sig")
    if not text.startswith("---"):
        lines = ["---"] + [f"{k}: {v}" for k, v in updates.items()] + ["---", "", text]
        path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
        return
    m = re.match(r"^(---\s*\n)(.*?)(\n---\s*\n?)", text, re.DOTALL)
    if not m:
        return
    lines = m.group(2).splitlines()
    seen: set[str] = set()
    for i, line in enumerate(lines):
        for k, v in updates.items():
            if k in seen:
                continue
            if re.match(rf"^{re.escape(k)}\s*:", line):
                lines[i] = f"{k}: {v}"
                seen.add(k)
    for k, v in updates.items():
        if k not in seen:
            lines.append(f"{k}: {v}")
    path.write_text(m.group(1) + "\n".join(lines) + m.group(3) + text[m.end():], encoding="utf-8", newline="\n")


def _card_has_unknown_r_eval(card_path: Path) -> bool:
    fm, _ = _card_frontmatter_block(card_path.read_text(encoding="utf-8", errors="ignore"))
    for key in ("r1_track_record", "r2_mechanical", "r3_data_available", "r4_ml_forbidden"):
        if (fm.get(key) or "UNKNOWN").upper() == "UNKNOWN":
            return True
    return False


def _auto_queue_r_eval_for_unknown_drafts(root: Path, max_tasks: int = 10) -> list[dict[str, Any]]:
    """PT10 2026-05-23 — also scan cards_approved/ (was draft-only).

    The approved-but-UNKNOWN bucket (~1 099 cards from the pre-schema-rewrite
    corpus) was previously invisible to this auto-queue, leaving them stuck
    out of the build pipeline forever. Cap bumped 3 -> 10 per cycle to match
    the build-emission cap; R-eval is short (frontmatter rewrite, ~minutes)
    so a higher rate doesn't pressure Codex.
    """
    inbox = root / "codex_inbox"
    inbox.mkdir(parents=True, exist_ok=True)
    cutoff = time.time() - 4 * 3600
    queued: list[dict[str, Any]] = []
    candidate_dirs = [
        root / "artifacts" / "cards_draft",
        root / "artifacts" / "cards_approved",
    ]
    for cards_dir in candidate_dirs:
        if len(queued) >= max_tasks:
            break
        if not cards_dir.is_dir():
            continue
        bucket = cards_dir.name  # "cards_draft" or "cards_approved"
        for card_path in sorted(cards_dir.glob("QM5_*.md")):
            if len(queued) >= max_tasks:
                break
            if card_path.stat().st_mtime > cutoff:
                continue
            ea_id = "_".join(card_path.stem.split("_")[:2])
            if not _card_has_unknown_r_eval(card_path):
                continue
            if _has_auto_task_file(root, f"auto-r-eval-{ea_id}-"):
                continue
            ts = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
            task_id = f"auto-r-eval-{ea_id}-{ts}"
            target = inbox / f"{task_id}.md"
            content = f"""---
task_id: {task_id}
priority: med
created: {dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}
auto_generated: true
trigger: R_EVAL_UNKNOWN_{bucket.upper()}
ea_id: {ea_id}
source_bucket: {bucket}
---

# Auto R-eval: {card_path.name}

Read `{card_path}` and `C:/QM/repo/processes/qb_reputable_source_criteria.md`.
Update the card frontmatter in place with PASS/FAIL for:

- `r1_track_record`
- `r2_mechanical`
- `r3_data_available`
- `r4_ml_forbidden`

Include concise reasoning fields. No commit / no push.
"""
            target.write_text(content, encoding="utf-8", newline="\n")
            queued.append({"ea_id": ea_id, "task_path": str(target), "bucket": bucket})
    return queued


def _has_auto_task_file(root: Path, prefix: str) -> bool:
    inbox = root / "codex_inbox"
    for rel in ("", ".processing", ".archive"):
        d = inbox / rel if rel else inbox
        if d.is_dir() and any(d.glob(f"{prefix}*.md")):
            return True
    return False


def _verify_card_body_coverage(card_path: Path) -> dict[str, Any]:
    text = card_path.read_text(encoding="utf-8", errors="ignore")
    _, body = _card_frontmatter_block(text)
    missing: list[str] = []
    if not re.search(r"(19|20)\d{2}.*(Journal|DOI|doi|SSRN|arXiv|Harriman|Wiley|Springer|URL|http)", body, re.I | re.S):
        missing.append("source_citation")
    if not re.search(r"\bEntry\b", body, re.I):
        missing.append("entry")
    if not re.search(r"\bExit\b", body, re.I):
        missing.append("exit")
    if not re.search(r"\bStop\b|\bSL\b|stop loss", body, re.I):
        missing.append("stop")
    if not re.search(r"Target symbol|symbols?:.*\.DWX|[A-Z0-9]{3,10}\.DWX", body, re.I):
        missing.append("target_symbols")
    if not re.search(r"\b(M1|M5|M15|M30|H1|H4|D1|W1|MN1)\b", body):
        missing.append("period")
    if _infer_expected_trades_per_year_per_symbol(text) is None:
        missing.append("expected_trade_frequency")
    return {"ok": not missing, "missing": missing}


def _write_auto_build_task(ea_info: dict[str, Any], root: Path) -> Path:
    """Write an auto-build bridge task for an approved-but-unbuilt card."""
    inbox = root / "codex_inbox"
    inbox.mkdir(parents=True, exist_ok=True)
    ts = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    task_id = f"auto-build-{ea_info['ea_id']}-{ts}"
    label = ea_info["label"]
    card_path = ea_info["card_path"]
    content = f"""---
task_id: {task_id}
priority: high
created: {dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}
auto_generated: true
trigger: UNBUILT_APPROVED_CARD
ea_id: {ea_info['ea_id']}
label: {label}
---

# Auto-build {ea_info['ea_id']} from approved card

Pump detected that card `{card_path}` is approved but
`framework/EAs/{label}/{label}.ex5` does not exist. Build the EA.

## Files to read

- Card: `{card_path}`
- V5 framework spec: `C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md`
- Template references: `QM5_1056`, `QM5_1099`, `QM5_1101` `.mq5` files for V5 boilerplate
- Magic registry: `C:/QM/repo/framework/registry/magic_numbers.csv`
- Known findings: `D:/QM/strategy_farm/codex_inbox/_KNOWN_FINDINGS.md`

## What to do

1. Read the card body for entry/exit rules and input specs.
2. Create directory `framework/EAs/{label}/`.
3. Write `{label}.mq5` implementing the card per V5 framework.
4. Append rows to `magic_numbers.csv`, one per card-listed symbol.
5. Regenerate `QM_MagicResolver.mqh` via `update_magic_resolver.py`.
6. Run build_check / compile; both must pass with 0 errors and 0 warnings.
7. Run smoke on the first card-listed symbol to confirm entry logic fires.
8. Generate per-symbol `.set` files via `gen_setfile.ps1`.
9. No commit / no push.

## Output

`D:/QM/strategy_farm/codex_outbox/{task_id}_result.md`

## Acceptance criteria

- [ ] `.mq5` and `.ex5` created
- [ ] build_check PASS and compile 0/0
- [ ] Smoke produces at least 1 trade OR documents the zero-trade reason
- [ ] magic registry and resolver updated
- [ ] `.set` files generated for card-listed symbols
- [ ] No commit / no push
"""
    target = inbox / f"{task_id}.md"
    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8", newline="\n")
    tmp.replace(target)
    return target


def _detect_unenqueued_eas(con: sqlite3.Connection) -> list[dict[str, Any]]:
    """
    Find reviewed, built EAs with no P2 work_items. These are ready for
    automatic P2 enqueue.
    """
    rows = con.execute(
        """
        SELECT card_id, MAX(updated_at) latest_review_ts, id AS review_task_id, payload_json
        FROM tasks
        WHERE kind='ea_review' AND status='done'
        GROUP BY card_id
        """
    ).fetchall()
    needs: list[dict[str, Any]] = []
    for r in rows:
        ea_id = r["card_id"]
        if not ea_id:
            continue
        try:
            review_payload = json.loads(r["payload_json"] or "{}")
        except json.JSONDecodeError:
            continue
        verdict_doc = review_payload.get("verdict") or {}
        if verdict_doc.get("verdict") != "APPROVE_FOR_BACKTEST":
            continue
        wi_count = con.execute(
            "SELECT COUNT(*) FROM work_items WHERE ea_id=? AND phase in ('Q02', 'P2')",
            (ea_id,),
        ).fetchone()[0]
        if wi_count > 0:
            continue
        # 2026-05-19: also skip if a terminal Q02/backtest_p2 task already exists
        # for this EA (done OR failed). Prevents pump from re-enqueuing
        # unactionable EAs (e.g. M1 EAs without DWX history in default
        # 2017-2022 window) on every cycle.
        terminal_task_exists = con.execute(
            "SELECT 1 FROM tasks WHERE kind IN ('backtest_p2', 'backtest_q02') AND card_id=? "
            "AND status in ('done', 'failed') LIMIT 1",
            (ea_id,),
        ).fetchone()
        if terminal_task_exists:
            continue
        candidates = sorted(p for p in FRAMEWORK_EAS_DIR.glob(f"{ea_id}_*") if p.is_dir())
        if not candidates:
            continue
        ea_dir = candidates[0]
        ex5 = ea_dir / f"{ea_dir.name}.ex5"
        if not ex5.exists():
            continue
        needs.append({
            "ea_id": ea_id,
            "review_task_id": r["review_task_id"],
            "ea_dir": str(ea_dir),
            "ex5": str(ex5),
        })
    return needs


def _enqueue_p2_from_review(root: Path, review_task_id: str) -> int:
    result = enqueue_backtest(root, review_task_id, "Q02")
    if not result.get("enqueued"):
        raise RuntimeError(str(result.get("reason") or result))
    return len(result.get("work_items_created") or [])


def _mt5_work_item_feed_target(mt5_root: Path | None = None) -> int:
    return max(
        MT5_WORK_ITEM_MIN_FEED_DEPTH,
        len(active_mt5_terminals(mt5_root)) * MT5_WORK_ITEM_FEED_MULTIPLIER,
    )


def _materialized_backtest_work_item_depth(con: sqlite3.Connection) -> int:
    row = con.execute(
        """
        SELECT COUNT(*) AS n
        FROM work_items
        WHERE kind='backtest'
          AND status in ('pending', 'active')
        """
    ).fetchone()
    return int(row["n"] if row else 0)


def _expand_pending_backtest_p2_parents(
    root: Path,
    con: sqlite3.Connection,
    target_depth: int,
) -> list[dict[str, Any]]:
    """Materialize latent pending Q02 parent tasks until MT5 has a feed queue."""
    expanded: list[dict[str, Any]] = []
    rows = con.execute(
        """
        SELECT *
        FROM tasks t
        WHERE t.kind IN ('backtest_p2', 'backtest_q02')
          AND t.status='pending'
          AND NOT EXISTS (
            SELECT 1 FROM work_items wi WHERE wi.parent_task_id=t.id
          )
        ORDER BY t.updated_at ASC
        """
    ).fetchall()
    for row in rows:
        if _materialized_backtest_work_item_depth(con) >= target_depth:
            break
        payload = json.loads(row["payload_json"] or "{}")
        ea_id = payload.get("ea_id") or row["card_id"]
        if not ea_id:
            update_task(
                con,
                row["id"],
                status="failed",
                payload_merge={"enqueue_error": "missing_ea_id"},
            )
            expanded.append({"task_id": row["id"], "error": "missing_ea_id"})
            continue
        created, skipped = _create_backtest_work_items(
            con,
            row["id"],
            root,
            str(ea_id),
            "Q02",
            surviving_symbols=None,
        )
        if created:
            expanded.append({
                "task_id": row["id"],
                "ea_id": ea_id,
                "created": len(created),
                "skipped": len(skipped),
            })
        else:
            update_task(
                con,
                row["id"],
                status="failed",
                payload_merge={
                    "enqueue_error": "no_p2_work_items_created",
                    "work_items_skipped": skipped,
                },
            )
            expanded.append({
                "task_id": row["id"],
                "ea_id": ea_id,
                "created": 0,
                "skipped": len(skipped),
                "error": "no_p2_work_items_created",
            })
    if expanded:
        con.commit()
    return expanded


def _auto_create_ea_review_for_unenqueued_eas(root: Path, con: sqlite3.Connection, limit: int = 3) -> list[dict[str, Any]]:
    """Auto-create done ea_review rows for built EAs ready for Q02."""
    out: list[dict[str, Any]] = []
    rows = con.execute(
        """
        SELECT * FROM tasks
        WHERE kind='build_ea'
          AND status='done'
          AND (
            payload_json LIKE '%auto_generated%'
            OR payload_json LIKE '%salvaged_2026-05-19%'
            OR payload_json LIKE '%smoke_skipped_reason%'
          )
        ORDER BY updated_at ASC
        """
    ).fetchall()
    for row in rows:
        if len(out) >= limit:
            break
        payload = json.loads(row["payload_json"] or "{}")
        review_candidate = (
            payload.get("auto_generated")
            or payload.get("salvaged_2026-05-19")
            or payload.get("smoke_skipped_reason")
        )
        if not review_candidate:
            continue
        ea_id = payload.get("ea_id") or row["card_id"]
        if not ea_id:
            continue
        existing_review = con.execute(
            "SELECT id FROM tasks WHERE kind='ea_review' AND card_id=? LIMIT 1",
            (ea_id,),
        ).fetchone()
        if existing_review:
            continue
        codex_review_passed = con.execute(
            """
            SELECT 1 FROM tasks cr
            WHERE cr.kind='codex_review' AND cr.status='done'
              AND cr.payload_json LIKE ?
              AND cr.payload_json LIKE '%"verdict": "PASS"%'
            LIMIT 1
            """,
            (f'%"build_task_id": "{row["id"]}"%',),
        ).fetchone()
        if not codex_review_passed:
            continue
        candidates = sorted(p for p in FRAMEWORK_EAS_DIR.glob(f"{ea_id}_*") if p.is_dir())
        if not candidates:
            continue
        ea_dir = candidates[0]
        ex5 = ea_dir / f"{ea_dir.name}.ex5"
        if not ex5.exists():
            continue
        review_payload = {
            "ea_id": ea_id,
            "build_task_id": row["id"],
            "auto_generated": True,
            "auto_review_reason": "auto-approved by orchestrator post-build",
            "needs_p2_smoke_via_pump": bool(
                payload.get("needs_p2_smoke_via_pump") or payload.get("smoke_skipped_reason")
            ),
            "verdict": {"verdict": "APPROVE_FOR_BACKTEST"},
        }
        review_task_id = create_task(
            con,
            kind="ea_review",
            source_id=row["source_id"],
            card_id=ea_id,
            payload=review_payload,
        )
        con.execute("UPDATE tasks SET status='done', updated_at=? WHERE id=?", (utc_now(), review_task_id))
        con.commit()
        try:
            n = _enqueue_p2_from_review(root, review_task_id)
            out.append({"ea_id": ea_id, "review_task_id": review_task_id, "work_items": n})
        except Exception as exc:
            out.append({"ea_id": ea_id, "review_task_id": review_task_id, "error": repr(exc)})
    return out


def _auto_stub_p5_calibration(root: Path, con: sqlite3.Connection, limit: int = 10) -> list[dict[str, Any]]:
    """Add missing P5 calibration symbol blocks from recent successful evidence."""
    cal_path = P5_CALIBRATION_JSON
    if not cal_path.exists():
        return []
    try:
        calibration = json.loads(cal_path.read_text(encoding="utf-8"))
    except Exception:
        return []
    symbols = calibration.setdefault("symbols", {})
    if not isinstance(symbols, dict):
        return []

    rows = con.execute(
        """
        SELECT * FROM work_items
        WHERE (
            (phase in ('Q04', 'P4') AND status='done' AND verdict='PASS')
            OR (phase in ('Q05', 'P5') AND status in ('pending', 'active'))
        )
        ORDER BY updated_at DESC
        LIMIT 100
        """
    ).fetchall()
    added: list[dict[str, Any]] = []
    for row in rows:
        symbol = str(row["symbol"] or "").strip()
        if not symbol or symbol in symbols:
            continue
        evidence = str(row["evidence_path"] or "").strip()
        symbols[symbol] = {
            "commission_cents_per_lot": 700.0,
            "latency_ms": {"avg": 50.0, "p95": 120.0},
            "slippage_points": {"avg": 1.0, "p95": 3.0},
            "spread_points": {"median": 20.0, "p95": 60.0},
            "auto_stub": True,
            "derive_from": evidence,
            "stub_created_at": utc_now(),
            "stub_source": "farmctl_pump_p5_calibration_autostub",
        }
        added.append({
            "symbol": symbol,
            "derive_from": evidence,
            "work_item_id": row["id"],
            "ea_id": row["ea_id"],
        })
        if len(added) >= limit:
            break

    if added:
        cal_path.write_text(json.dumps(calibration, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        event(con, "calibration", "P5", "p5_calibration_auto_stubbed", {"symbols": added})
        con.commit()
    return added


def _hourly_db_backup(root: Path) -> str | None:
    """Snapshot farm_state.sqlite to state/backups once per hour; keep 24h."""
    src = root / DB_REL
    if not src.exists():
        return None
    backup_dir = root / "state" / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    now = dt.datetime.now(dt.timezone.utc)
    existing = sorted(backup_dir.glob("farm_state_*.sqlite"))
    if existing:
        latest = max(existing, key=lambda p: p.stat().st_mtime)
        if now.timestamp() - latest.stat().st_mtime < 50 * 60:
            return None
    target = backup_dir / f"farm_state_{now.strftime('%Y%m%d_%H%M')}.sqlite"
    src_conn = sqlite3.connect(str(src))
    try:
        tgt_conn = sqlite3.connect(str(target))
        try:
            src_conn.backup(tgt_conn)
        finally:
            tgt_conn.close()
    finally:
        src_conn.close()
    cutoff = now.timestamp() - 24 * 3600
    for old in existing:
        try:
            if old.stat().st_mtime < cutoff:
                old.unlink()
        except OSError:
            pass
    return str(target)


def research_backlog_inventory(root: Path) -> dict[str, Any]:
    """Count strategy work already available before spawning more research."""
    cards_draft = root / "artifacts" / "cards_draft"
    cards_approved = root / "artifacts" / "cards_approved"
    draft_cards = len(list(cards_draft.glob("*.md"))) if cards_draft.exists() else 0
    approved_cards = len(list(cards_approved.glob("*.md"))) if cards_approved.exists() else 0
    ready_inventory = ready_strategy_card_inventory(root)
    ready_approved_cards = int(ready_inventory.get("ready_count") or 0)

    active_pipeline_eas = 0
    open_build_or_review_tasks = 0
    try:
        with connect(root) as conn:
            row = conn.execute(
                """
                SELECT COUNT(DISTINCT ea_id) AS n
                FROM work_items
                WHERE ea_id IS NOT NULL
                  AND status in ('pending', 'active')
                  AND phase in ('P2', 'P3', 'P3.5', 'P4', 'P5', 'P5b', 'P5c', 'P6', 'P7', 'P8', 'Q02', 'Q03', 'Q04', 'Q05', 'Q07', 'Q08')
                """
            ).fetchone()
            active_pipeline_eas = int(row["n"] if row else 0)

            row = conn.execute(
                """
                SELECT COUNT(*) AS n
                FROM tasks
                WHERE status in ('pending', 'active', 'review', 'blocked')
                  AND kind in ('build_ea', 'ea_review', 'codex_review')
                """
            ).fetchone()
            open_build_or_review_tasks = int(row["n"] if row else 0)
    except sqlite3.Error:
        # Research gating must fail closed: if DB state is unreadable, do not
        # create more research work until the pump/health path exposes the DB issue.
        return {
            "total": ready_approved_cards,
            "draft_cards": draft_cards,
            "approved_cards": approved_cards,
            "ready_approved_cards": ready_approved_cards,
            "blocked_approved_cards": int(ready_inventory.get("blocked_count") or 0),
            "duplicate_fingerprints": ready_inventory.get("duplicate_fingerprints") or {},
            "active_pipeline_eas": active_pipeline_eas,
            "open_build_or_review_tasks": open_build_or_review_tasks,
            "db_error": True,
        }

    total = ready_approved_cards
    return {
        "total": total,
        "draft_cards": draft_cards,
        "approved_cards": approved_cards,
        "ready_approved_cards": ready_approved_cards,
        "blocked_approved_cards": int(ready_inventory.get("blocked_count") or 0),
        "duplicate_fingerprints": ready_inventory.get("duplicate_fingerprints") or {},
        "active_pipeline_eas": active_pipeline_eas,
        "open_build_or_review_tasks": open_build_or_review_tasks,
        "db_error": False,
    }


def pump(root: Path) -> dict[str, Any]:
    """Continuous deterministic worker — run every 5 min.

    Does the no-LLM-needed work that previously waited for hourly Claude
    wakes:
      - MT5 backtest dispatch (was: separate `tick` command)
      - Auto-enqueue next phase on PASS verdicts (now inside dispatch_tick)
      - Spawn Codex for ONE pending build_ea task per pump call (bounded —
        Codex builds take 5-15 min, don't pile up multiple)
      - Record build results when Codex's build_result JSON appears
      - Spawn Claude for EA review up to MAX_PARALLEL_CLAUDE total sessions

    Bounded per pump cycle to avoid resource overrun. Idempotent — checks
    live_log freshness so re-runs while Codex is still going don't
    double-spawn.
    """
    init_db(root)
    result: dict[str, Any] = {
        "pumped_at": utc_now(),
        "dispatch": None,
        "codex_spawn": None,
        "build_records": [],
        "build_retries": [],
    }
    codex_low_tokens = (
        (root / "CODEX_LOW_TOKENS.flag").exists()
        or os.environ.get("QM_CODEX_LOW_TOKENS") == "1"
    )
    result["codex_low_tokens"] = {
        "enabled": codex_low_tokens,
        "flag": str(root / "CODEX_LOW_TOKENS.flag"),
    }

    # CIRCUIT BREAKER: if recent codex logs are full of 401 Unauthorized,
    # Codex OAuth is broken. Each new spawn wastes 5 retries × ~30s before
    # giving up + leaves a junk log + counts against codex quota. Don't
    # spawn ANY codex work until auth is fixed (OWNER must run `codex login`
    # interactively). Build/research/review/g0 all skipped; MT5 dispatch
    # + Claude work continue normally.
    codex_auth_broken = False
    try:
        import time as _t
        from pathlib import Path as _P
        _auth = _P(r"C:/Users/Administrator/.codex/auth.json")
        auth_mtime = _auth.stat().st_mtime if _auth.exists() else 0.0
        cutoff_mtime = _codex_401_cutoff_mtime(auth_mtime)
        n_401 = 0
        for log in (root / "logs").glob("codex_*.live.log"):
            try:
                log_mtime = log.stat().st_mtime
                if _t.time() - log_mtime > 900:
                    continue
                if _tail_has_current_codex_401(log, cutoff_mtime):
                    n_401 += 1
            except OSError:
                continue
        codex_auth_broken = n_401 >= 3
        result["codex_auth_broken"] = {
            "tripped": codex_auth_broken,
            "n_401_recent_logs": n_401,
        }
    except Exception as exc:
        result["codex_auth_broken"] = {"tripped": False, "error": repr(exc)}

    # 1a. Per-symbol work_items dispatch is owned by the per-terminal daemon
    #     fleet (tools/strategy_farm/terminal_worker.py). Pump-cron keeps the
    #     active-timeout detector but no longer spawns MT5 work_items.
    def _run_worker_owned_maintenance() -> dict[str, Any]:
        with connect(root) as conn:
            return {
                "active_timeouts": _detect_active_age_timeout(conn),
                "pending_verdicts_normalized": _normalize_pending_work_item_verdicts(conn),
            }

    try:
        result.update(_with_sqlite_write_retry(_run_worker_owned_maintenance))
    except sqlite3.OperationalError as exc:
        if not _is_sqlite_locked(exc):
            raise
        result["active_timeouts"] = []
        result["pending_verdicts_normalized"] = 0
        result["worker_owned_maintenance_skipped"] = f"sqlite_locked:{exc}"
    result["dispatch_work_items"] = {
        "disabled": True,
        "reason": "per-terminal worker daemons own work_item dispatch",
    }
    # 1b. Legacy bundled-task dispatch — handles any backtest_<phase> tasks
    #     created WITHOUT matching work_items (e.g. older runs). Will become
    #     a no-op once all enqueues create work_items.
    result["dispatch"] = dispatch_tick(root)
    with connect(root) as conn:
        result["zerotrade_rework_flagged"] = _detect_zerotrade_dead_eas(conn, root)

    result["research_cards_extracted"] = _extract_cards_from_research_results(root)
    result["auto_r_eval_queued"] = _auto_queue_r_eval_for_unknown_drafts(root)

    result["auto_build_queued"] = []
    # PT14 2026-05-25 — gate legacy bridge-file emission. The /goal-bridge
    # daemon that consumed codex_inbox/auto-build-*.md files died on
    # 2026-05-17 (last result in codex_outbox is from then). Continuing to
    # emit bridge files only created dead-letter pollution AND blocked the
    # new DB-direct spawn path via _has_auto_build_task_file(). The new
    # path (Step 3b below: render_codex_build_prompt + _spawn_codex_for_build)
    # handles emission + spawning end-to-end without the inbox detour.
    # See memory: project_qm_dead_bridge_inbox_blocker_2026-05-25.
    EMIT_LEGACY_BRIDGE_TASKS = False  # flip to True only if the /goal bridge is revived
    if EMIT_LEGACY_BRIDGE_TASKS:
        for ea_info in _detect_unbuilt_cards(root)[:10]:
            p = _write_auto_build_task(ea_info, root)
            result["auto_build_queued"].append({
                "ea_id": ea_info["ea_id"],
                "label": ea_info["label"],
                "task_path": str(p),
            })

    result["auto_p2_enqueued"] = []
    with connect(root) as conn:
        feed_target = _mt5_work_item_feed_target()
        result["mt5_feed_target"] = feed_target
        result["mt5_feed_depth_before"] = _materialized_backtest_work_item_depth(conn)
        result["expanded_pending_backtest_p2"] = _expand_pending_backtest_p2_parents(
            root,
            conn,
            feed_target,
        )
        result["mt5_feed_depth_after_parent_expand"] = _materialized_backtest_work_item_depth(conn)
        result["auto_ea_review_created"] = _auto_create_ea_review_for_unenqueued_eas(
            root,
            conn,
            limit=feed_target,
        )
        for ea_info in _detect_unenqueued_eas(conn):
            if _materialized_backtest_work_item_depth(conn) >= feed_target:
                break
            try:
                n = _enqueue_p2_from_review(root, ea_info["review_task_id"])
                result["auto_p2_enqueued"].append({
                    "ea_id": ea_info["ea_id"],
                    "work_items": n,
                    "review_task_id": ea_info["review_task_id"],
                })
            except Exception as exc:
                result["auto_p2_enqueued"].append({
                    "ea_id": ea_info["ea_id"],
                    "review_task_id": ea_info["review_task_id"],
                    "error": repr(exc),
                })
        result["mt5_feed_depth_after"] = _materialized_backtest_work_item_depth(conn)

    # 2. Retry blocked builds — OWNER 2026-05-16 "Fail → ans Ende der
    #    Liste". A blocked build means the previous attempt hit
    #    framework_error / compile_failed / smoke_failed. Re-queue up to
    #    MAX_BUILD_RETRIES so framework fixes (deploy, perf, etc.) get a
    #    fresh swing.
    MAX_BUILD_RETRIES = 3
    with connect(root) as conn:
        blocked_builds = conn.execute(
            "SELECT * FROM tasks WHERE kind='build_ea' AND status='blocked' "
            "ORDER BY updated_at ASC"
        ).fetchall()
        # bb950e1f dedup'd the CREATE path so no new duplicate pending build_ea
        # gets stacked. This loop is the RE-OPEN path — it must apply the same
        # dedup, otherwise a freshly-blocked sibling gets re-unblocked the next
        # tick and immediately stacks pending again (observed for QM5_1087 /
        # QM5_1119 2026-05-18T10:44Z, 4 surplus pendings reincarnated post
        # bb950e1f cleanup).
        cards_with_pending_build = {
            r[0] for r in conn.execute(
                "SELECT DISTINCT card_id FROM tasks "
                "WHERE kind='build_ea' AND status='pending'"
            )
        }
    for row in blocked_builds:
        payload = json.loads(row["payload_json"])
        # Forensic tombstones — never retry.
        if payload.get("superseded_by") or payload.get("duplicate_of_task_id"):
            continue
        blocked_reason = str(
            payload.get("blocked_reason")
            or payload.get("build_result", {}).get("blocked_reason")
            or ""
        )
        # Mechanical review failures are code-quality findings, not transient
        # infra failures. Auto-retrying them burns Codex and can repeatedly
        # recreate the same EA/framework-corset violation.
        if blocked_reason == "codex_review_fail":
            continue
        # Another pending build_ea already covers this card — re-unblocking
        # would re-create the duplicate-pending stack bb950e1f eliminated.
        if row["card_id"] in cards_with_pending_build:
            continue
        attempt = int(payload.get("attempt_count", 0)) + 1
        if attempt > MAX_BUILD_RETRIES:
            continue
        # Archive stale build_result so the next pump cycle doesn't re-record
        # the OLD outcome as a "fresh" build. Codex writes a new file on the
        # next run. Also archive live log so a fresh one gets created.
        brp = payload.get("build_result_path")
        if brp:
            brp_path = Path(brp)
            if brp_path.exists() and brp_path.stat().st_size > 0:
                archive = brp_path.with_suffix(f".attempt_{attempt-1}.json")
                try:
                    brp_path.rename(archive)
                except OSError:
                    pass
        live_log = root / "logs" / f"codex_build_{row['id']}.live.log"
        if live_log.exists():
            try:
                live_log.rename(live_log.with_suffix(f".attempt_{attempt-1}.log"))
            except OSError:
                pass

        update_payload = dict(payload)
        update_payload["attempt_count"] = attempt
        update_payload["last_blocked_reason"] = blocked_reason
        # Clear stale dispatch metadata so the fresh Codex run starts clean
        for k in ("pid", "started_at_iso", "log_path", "build_result", "blocked_reason"):
            update_payload.pop(k, None)
        with connect(root) as conn2:
            conn2.execute(
                "UPDATE tasks SET status='pending', payload_json=?, updated_at=? WHERE id=?",
                (json.dumps(update_payload), utc_now(), row["id"]),
            )
            conn2.commit()
        cards_with_pending_build.add(row["card_id"])
        result["build_retries"].append({
            "task_id": row["id"],
            "ea_id": payload.get("ea_id"),
            "attempt": attempt,
            "last_blocked_reason": blocked_reason[:120],
        })

    # 3. Codex builds for up to MAX_PARALLEL_CODEX pending build_ea tasks.
    #    Each Codex builds a DIFFERENT EA — races on shared writes (CSV
    #    appends + update_magic_resolver.py rewrite) are resolved at the
    #    file level: CSV append is atomic line-by-line, update_resolver is
    #    idempotent (reads current CSV state, regenerates .mqh deterministically).
    #    OWNER 2026-05-16: explicit ok to parallelize.
    MAX_PARALLEL_CODEX = 3       # OWNER 2026-05-29: 5->3 (false-PASS pattern showed bounded burn wasn't holding; project_qm_false_pass_build_ea_wave_2026-05-28)
    MAX_PARALLEL_CODEX_BUILDS = 3  # same: 5->3 to match
    # Gemini headless CLI can authenticate, but on this Windows host it may
    # hang on tool-heavy EA builds after node-pty AttachConsole failures.
    # Keep the lane implemented but opt-in until a supervised smoke proves it
    # can complete a full build-result contract.
    MAX_PARALLEL_GEMINI_BUILDS = 2 if os.environ.get("QM_ENABLE_GEMINI_BUILDS") == "1" else 0
    # Circuit breaker: when codex auth is broken, force both caps to 0 so
    # NO codex work spawns (research/review/build/g0 all gated through
    # these caps). Prevents wasting 5×30s retries per spawn + leaving
    # 401-junk logs that confuse later diagnosis.
    if codex_auth_broken:
        MAX_PARALLEL_CODEX = 0
        MAX_PARALLEL_CODEX_BUILDS = 0
    if codex_low_tokens:
        MAX_PARALLEL_CODEX = min(MAX_PARALLEL_CODEX, 1)
        MAX_PARALLEL_CODEX_BUILDS = 0
    try:
        import shutil as _shutil
        ps_out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name codex -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        active_codex = int((ps_out.stdout or "0").strip() or "0")
    except Exception:
        active_codex = 0
    try:
        ps_out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'gemini\\.js|gemini\\.cmd' }).Count"],
            capture_output=True, text=True, timeout=10,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        active_gemini = int((ps_out.stdout or "0").strip() or "0")
    except Exception:
        active_gemini = 0
    # Build budget: Gemini can draft builds, Codex still owns review gates.
    # Non-build spawns (research/review/g0) can still use up to MAX_PARALLEL_CODEX-active.
    spawn_budget = max(0, min(MAX_PARALLEL_CODEX_BUILDS, MAX_PARALLEL_CODEX - active_codex))
    gemini_build_budget = max(0, MAX_PARALLEL_GEMINI_BUILDS - active_gemini)
    repo_dirty_guard = _repo_dirty_status()
    result["repo_dirty_build_guard"] = repo_dirty_guard
    if repo_dirty_guard.get("blocked"):
        spawn_budget = 0
        gemini_build_budget = 0
    total_build_spawn_budget = spawn_budget + gemini_build_budget
    with connect(root) as conn:
        # Dedupe by ea_id — never spawn 2 codex builds for the same EA at
        # once (race on EA dir + magic_numbers.csv + resolver regeneration).
        # When multiple build_ea tasks exist for the same ea_id (e.g. retry
        # races), pick the oldest pending and ignore the others until that
        # one settles.
        all_pending = conn.execute(
            "SELECT * FROM tasks WHERE kind='build_ea' AND status='pending' "
            "ORDER BY updated_at ASC"
        ).fetchall()
        all_pending = sorted(all_pending, key=lambda row: _card_build_priority(root, row))
        # PT12 2026-05-24 — skip-list of EAs Codex has already permanently
        # blocked on (3 retries exhausted with compile_error or similar). Pre-
        # PT12 these EAs sat in the pending queue too and Codex re-spawned for
        # them every cycle, costing ~228 wasted Codex spawns/day per the
        # token-burn audit. Now: read the failed/blocked tasks once, build a
        # set of ea_ids that hit permanent_blocked_retries_exhausted, and skip
        # any pending build_ea whose ea_id is in that set.
        perma_blocked_eas: set[str] = set()
        for r in conn.execute(
            "SELECT payload_json FROM tasks WHERE kind='build_ea' AND status IN ('failed','blocked')"
        ):
            try:
                pl = json.loads(r["payload_json"] or "{}")
            except (json.JSONDecodeError, TypeError):
                continue
            if pl.get("final_failure") == "permanent_blocked_retries_exhausted":
                ea_id = pl.get("ea_id")
                if ea_id:
                    perma_blocked_eas.add(ea_id)
        seen_eas: set[str] = set()
        pending_builds = []
        skipped_perma_blocked = 0
        for row in all_pending:
            if len(pending_builds) >= total_build_spawn_budget:
                break
            payload = json.loads(row["payload_json"])
            ea_id = payload.get("ea_id")
            if ea_id in seen_eas:
                continue
            if ea_id in perma_blocked_eas:
                # Hard-block: don't re-spawn for an EA that has already
                # exhausted its retries. OWNER can recycle to _v2 manually
                # if the underlying source is fixable.
                skipped_perma_blocked += 1
                continue
            seen_eas.add(ea_id)
            pending_builds.append(row)
    spawns = []
    for idx, pending_build in enumerate(pending_builds):
        if idx < gemini_build_budget:
            sp = _spawn_gemini_for_build(root, pending_build)
        else:
            sp = _spawn_codex_for_build(root, pending_build)
        spawns.append(sp)
    result["gemini_active_before"] = active_gemini
    result["gemini_build_budget"] = gemini_build_budget
    result["codex_perma_blocked_skipped"] = skipped_perma_blocked
    result["codex_perma_blocked_ea_count"] = len(perma_blocked_eas)

    # 3b. Auto-create build_ea tasks for newly-approved cards. Without this,
    #    pump can't reach Codex on cards that haven't yet been touched by
    #    autonomous_wake's Step 2 — the hourly cadence becomes the real
    #    bottleneck for fresh approved cards. Bounded by spawn_budget so we
    #    don't pile up backlog faster than we can build it.
    result["auto_created_builds"] = []
    result["auto_build_skipped"] = []
    with connect(root) as conn:
        pending_work_items_total = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE status='pending'"
        ).fetchone()[0]
        active_work_items_total = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE status='active'"
        ).fetchone()[0]
    build_backpressure_paused = (
        pending_work_items_total >= BUILD_BACKPRESSURE_PENDING_HARD_LIMIT
        or (
            pending_work_items_total >= BUILD_BACKPRESSURE_PENDING_SOFT_LIMIT
            and active_work_items_total >= BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT
        )
    )
    result["build_backpressure"] = {
        "pending_work_items": pending_work_items_total,
        "active_work_items": active_work_items_total,
        "max_pending_for_new_builds": BUILD_BACKPRESSURE_PENDING_SOFT_LIMIT,
        "hard_pending_for_new_builds": BUILD_BACKPRESSURE_PENDING_HARD_LIMIT,
        "active_work_items_pause_threshold": BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT,
        "new_builds_paused": build_backpressure_paused,
    }
    # Count actually-spawned (not skipped-due-to-fresh-log)
    actually_spawned = sum(1 for s in spawns if s.get("spawned"))
    if build_backpressure_paused:
        result["auto_build_skipped"].append({
            "reason": "build_backpressure",
            "pending_work_items": pending_work_items_total,
            "active_work_items": active_work_items_total,
            "max_pending_for_new_builds": BUILD_BACKPRESSURE_PENDING_SOFT_LIMIT,
            "hard_pending_for_new_builds": BUILD_BACKPRESSURE_PENDING_HARD_LIMIT,
            "active_work_items_pause_threshold": BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT,
        })
    elif repo_dirty_guard.get("blocked"):
        result["auto_build_skipped"].append({
            "reason": "repo_worktree_dirty",
            "dirty_count": repo_dirty_guard.get("count", 0),
            "dirty_entries": repo_dirty_guard.get("entries", []),
            "override_env": DIRTY_REPO_BUILD_GUARD_ENV,
        })
    elif actually_spawned < spawn_budget:
        cards_approved_dir = root / "artifacts" / "cards_approved"
        if cards_approved_dir.is_dir():
            with connect(root) as conn:
                have_task = {
                    json.loads(r["payload_json"]).get("ea_id")
                    for r in conn.execute("SELECT payload_json FROM tasks WHERE kind='build_ea'").fetchall()
                }
            cards_without_task = []
            for f in sorted(cards_approved_dir.glob("QM5_*.md")):
                parts = f.stem.split("_")
                if len(parts) < 2:
                    continue
                ea_id = f"{parts[0]}_{parts[1]}"
                if ea_id not in have_task:
                    if _has_auto_build_task_file(root, ea_id):
                        continue
                    # PT10 — same R1-R4 PASS gate as _detect_unbuilt_cards.
                    # Skip cards whose R-eval has not landed PASS yet so we don't
                    # bombard prebuild_validate_card with cards we know will fail.
                    try:
                        fm = parse_card_frontmatter(f)
                        if any(str(fm.get(key) or "").strip().upper() != "PASS"
                               for key in ("r1_track_record", "r2_mechanical", "r3_data_available", "r4_ml_forbidden")):
                            continue
                    except Exception:
                        continue
                    cards_without_task.append((ea_id, f))
            slots_left = min(spawn_budget - actually_spawned, MAX_AUTO_CREATED_BUILDS_PER_PUMP)
            # PT13 2026-05-25 — advance past prebuild-failed cards instead of
            # capping the iteration at slots_left. The old code took the first
            # N cards alphabetically; if the head of the list was all broken
            # (missing frontmatter, r3 not PASS, etc.) pump emitted 0 spawns
            # every cycle even though OK cards existed further down. Now we
            # iterate the full list, counting only successful spawns toward
            # the budget. Cap on attempts prevents pathological lists from
            # burning a whole cycle on rejections.
            spawned_here = 0
            attempts_cap = max(slots_left * 6, 30)
            attempts = 0
            for ea_id, card_path in cards_without_task:
                if spawned_here >= slots_left:
                    break
                if attempts >= attempts_cap:
                    break
                attempts += 1
                br = render_codex_build_prompt(root, str(card_path), None)
                if br.get("written"):
                    result["auto_created_builds"].append({
                        "ea_id": ea_id,
                        "task_id": br.get("task_id"),
                    })
                    # Now spawn Codex for it immediately
                    with connect(root) as conn:
                        new_row = conn.execute(
                            "SELECT * FROM tasks WHERE id=?", (br["task_id"],)
                        ).fetchone()
                    if new_row:
                        sp = _spawn_codex_for_build(root, new_row)
                        spawns.append(sp)
                        if sp.get("spawned"):
                            spawned_here += 1
                else:
                    result["auto_build_skipped"].append({
                        "ea_id": ea_id,
                        "card_path": str(card_path),
                        "reason": br.get("reason"),
                        "prebuild_errors": br.get("prebuild_errors", []),
                    })
    result["codex_spawn"] = spawns[0] if spawns else None
    result["codex_spawns_all"] = spawns
    result["codex_active_before"] = active_codex
    result["codex_spawn_budget"] = spawn_budget
    MAX_PARALLEL_CODEX_REVIEW = 4
    if codex_low_tokens:
        MAX_PARALLEL_CODEX_REVIEW = min(MAX_PARALLEL_CODEX_REVIEW, 1)

    # 4. Record completed Codex builds — any pending build_ea whose
    #    build_result JSON exists and isn't empty.
    # PT15 2026-05-25 — Codex actually writes `<task_id>.attempt_<N>.json`
    # (retry-aware) but pump's payload sets BRP to `<task_id>.json` in
    # 7 different sites. The literal path never exists; fresh builds sat
    # forever in status=pending with .ex5 already produced. Now: fall
    # back to glob `<task_id>*.json` and pick the newest attempt.
    with connect(root) as conn:
        rows = conn.execute(
            "SELECT * FROM tasks WHERE kind='build_ea' AND status='pending'"
        ).fetchall()
    for row in rows:
        payload = json.loads(row["payload_json"])
        brp = payload.get("build_result_path")
        result_path: Path | None = None
        if brp:
            p = Path(brp)
            if p.exists() and p.stat().st_size > 0:
                result_path = p
            else:
                # Look for attempt-suffixed variants written by Codex.
                stem = p.stem  # task UUID
                attempts = sorted(
                    [a for a in p.parent.glob(f"{stem}*.json") if a.stat().st_size > 0],
                    key=lambda a: a.stat().st_mtime,
                    reverse=True,
                )
                if attempts:
                    result_path = attempts[0]
        if result_path is not None:
            rec = record_build_result(root, row["id"], str(result_path))
            result["build_records"].append({"task_id": row["id"], "recorded": rec})

    # 4b. ZERO-TRADE SHORT-CIRCUIT — observed 2026-05-17: 9/9 codex_reviews
    #     in last hour FAIL on smoke_sanity (0 trades in smoke window). The
    #     build_result.json already says smoke_result='MIN_TRADES_NOT_MET' —
    #     spawning Codex to "verify" that is pure waste. Mark such builds
    #     blocked with reason='zero_trade_smoke' BEFORE codex_review spawn.
    result["zero_trade_blocks"] = []
    with connect(root) as conn:
        candidates = conn.execute(
            """
            SELECT b.* FROM tasks b
            WHERE b.kind='build_ea' AND b.status='done'
              AND NOT EXISTS (
                SELECT 1 FROM tasks r WHERE r.kind='codex_review'
                  AND r.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
              )
              AND NOT EXISTS (
                SELECT 1 FROM tasks rr WHERE rr.kind='ea_review'
                  AND rr.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
              )
            """
        ).fetchall()
        for b in candidates:
            bp = json.loads(b["payload_json"])
            br_path = bp.get("build_result_path")
            if not br_path or not Path(br_path).exists():
                continue
            try:
                br = json.loads(Path(br_path).read_text(encoding="utf-8"))
            except Exception:
                continue
            if bp.get("needs_p2_smoke_via_pump") or bp.get("smoke_skipped_reason"):
                continue
            sr = (br.get("smoke_result") or "").upper()
            blocked_r = (br.get("blocked_reason") or "")
            # Trigger conditions: explicit MIN_TRADES_NOT_MET, OR framework_error,
            # OR known dead-end blocked_reason patterns
            zero_trade = (
                "MIN_TRADES_NOT_MET" in sr or
                "MIN_TRADES_NOT_MET" in blocked_r or
                sr == "FRAMEWORK_ERROR" or
                "REPORT_MISSING" in blocked_r
            )
            if not zero_trade:
                continue
            bp["blocked_reason"] = bp.get("blocked_reason") or "zero_trade_smoke"
            bp["attempt"] = int(bp.get("attempt", 0)) + 1
            bp["zero_trade_short_circuit"] = True
            conn.execute(
                "UPDATE tasks SET status='blocked', payload_json=?, updated_at=? WHERE id=?",
                (json.dumps(bp), utc_now(), b["id"]),
            )
            event(conn, "task", b["id"], "build_zero_trade_blocked", {
                "smoke_result": sr,
                "blocked_reason": blocked_r[:200],
            })
            result["zero_trade_blocks"].append({
                "task_id": b["id"],
                "ea_id": bp.get("ea_id"),
                "smoke_result": sr,
                "saved_codex_review_spawn": True,
            })
        conn.commit()

    # 5a. CODEX pre-review for done build_ea without codex_review yet.
    #     Codex catches mechanical bugs (Framework Corset, INTRADAY DISCIPLINE,
    #     magic collisions, 0-trade smoke) BEFORE final EA review burns
    #     reviewer cycles. PASS → EA review proceeds. FAIL → build → blocked.
    #     Zero-trade builds were already short-circuited in §4b — they
    #     won't appear here.
    result["codex_review_spawns"] = []
    with connect(root) as conn:
        builds_needing_codex_review = conn.execute(
            """
            SELECT b.* FROM tasks b
            WHERE b.kind='build_ea' AND b.status='done'
              AND NOT EXISTS (
                SELECT 1 FROM tasks r
                WHERE r.kind='codex_review'
                  AND r.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
              )
            ORDER BY b.updated_at ASC LIMIT ?
            """
            ,
            (MAX_PARALLEL_CODEX_REVIEW,),
        ).fetchall()
    for b in builds_needing_codex_review:
        # Respect total-codex cap: builds + reviews + research (all share the pool)
        builds_now = len([s for s in (result.get("codex_spawns_all") or []) if isinstance(s, dict) and s.get("spawned")])
        reviews_now = len([s for s in result["codex_review_spawns"] if isinstance(s, dict) and s.get("spawned")])
        if (active_codex + builds_now + reviews_now) >= MAX_PARALLEL_CODEX:
            break
        ready, not_ready_reason = _pre_review_ready(root, b)
        if not ready:
            result["codex_review_spawns"].append(_block_unreviewable_build(root, b, not_ready_reason))
            continue
        sp = _spawn_codex_for_pre_review(root, b)
        result["codex_review_spawns"].append(sp)

    # 5b. Record completed codex_review verdicts.
    result["codex_review_records"] = []
    with connect(root) as conn:
        pending_codex_reviews = conn.execute(
            "SELECT * FROM tasks WHERE kind='codex_review' AND status='pending'"
        ).fetchall()
    for cr in pending_codex_reviews:
        p = json.loads(cr["payload_json"])
        vp = p.get("verdict_path")
        if not vp:
            continue
        rec = _record_codex_review_result(root, cr["id"], vp)
        if rec.get("recorded"):
            result["codex_review_records"].append(rec)
            # If Codex says FAIL → block the build for rework, skip Claude
            if rec["verdict"] == "FAIL":
                build_id = rec["build_task_id"]
                with connect(root) as conn:
                    brow = conn.execute("SELECT payload_json FROM tasks WHERE id=?", (build_id,)).fetchone()
                    if brow:
                        bp = json.loads(brow["payload_json"])
                        bp["codex_review_findings"] = p.get("findings") or []
                        bp["blocked_reason"] = "codex_review_fail"
                        bp["attempt"] = int(bp.get("attempt", 0)) + 1
                        conn.execute(
                            "UPDATE tasks SET status='blocked', payload_json=?, updated_at=? WHERE id=?",
                            (json.dumps(bp), utc_now(), build_id),
                        )
                        event(conn, "task", build_id, "build_blocked_by_codex_review", {
                            "findings_count": len(bp["codex_review_findings"]),
                        })
                        conn.commit()

    # 5c. Spawn final EA review ONLY for builds that have a PASSING codex_review
    #     AND no ea_review yet. Claude owns final qualitative EA review, but is
    #     capped so the pump can drain review backlog without uncontrolled spend.
    try:
        active_claude_count = int(subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name claude -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        ).stdout.strip() or "0")
    except Exception:
        active_claude_count = 0
    result["claude_active_before"] = active_claude_count
    claude_disabled = (root / "CLAUDE_DISABLED.flag").exists()
    max_parallel_claude = 0 if claude_disabled else MAX_PARALLEL_CLAUDE
    prefer_claude_review = max_parallel_claude > 0
    result["claude_disabled"] = claude_disabled
    result["max_parallel_claude"] = max_parallel_claude
    result["prefer_claude_review"] = prefer_claude_review
    claude_spawns_this_cycle = 0
    claude_review_slots = max(0, max_parallel_claude - active_claude_count)
    result["claude_review_slots"] = claude_review_slots
    with connect(root) as conn:
        done_no_review_rows = conn.execute(
            """
            SELECT b.* FROM tasks b
            WHERE b.kind='build_ea' AND b.status='done'
              AND EXISTS (
                SELECT 1 FROM tasks cr
                WHERE cr.kind='codex_review' AND cr.status='done'
                  AND cr.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
                  AND cr.payload_json LIKE '%"verdict": "PASS"%'
              )
              AND NOT EXISTS (
                SELECT 1 FROM tasks r
                WHERE r.kind='ea_review'
                  AND r.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
              )
            ORDER BY b.updated_at ASC LIMIT ?
            """,
            (max(claude_review_slots, 1),),
        ).fetchall()
    result["claude_review_spawn"] = {"spawned": False, "reason": "no review candidate"}
    result["claude_review_spawns_all"] = []
    if done_no_review_rows:
        if claude_disabled:
            result["claude_review_spawn"] = {"spawned": False, "reason": "CLAUDE_DISABLED.flag present; routed to Codex"}
        elif claude_review_slots > 0:
            for done_no_review in done_no_review_rows[:claude_review_slots]:
                sp = _spawn_claude_for_review(root, done_no_review)
                result["claude_review_spawns_all"].append(sp)
                if sp.get("spawned"):
                    claude_spawns_this_cycle += 1
            result["claude_review_spawn"] = (
                result["claude_review_spawns_all"][0]
                if result["claude_review_spawns_all"]
                else {"spawned": False, "reason": "no review candidate"}
            )
        else:
            result["claude_review_spawn"] = {"spawned": False, "reason": "claude cap reached"}

        builds_now = len([s for s in (result.get("codex_spawns_all") or []) if isinstance(s, dict) and s.get("spawned")])
        pre_reviews_now = len([s for s in result["codex_review_spawns"] if isinstance(s, dict) and s.get("spawned")])
        if claude_disabled and (active_codex + builds_now + pre_reviews_now) < MAX_PARALLEL_CODEX:
            result["codex_review_spawn"] = _spawn_codex_for_review(root, done_no_review_rows[0])
        elif result["claude_review_spawn"].get("spawned"):
            result["codex_review_spawn"] = {"spawned": False, "reason": "claude review spawned"}
        elif not claude_disabled and claude_review_slots <= 0:
            result["codex_review_spawn"] = {"spawned": False, "reason": "claude cap reached; waiting for Claude review slot"}
        elif (active_codex + builds_now + pre_reviews_now) >= MAX_PARALLEL_CODEX:
            result["codex_review_spawn"] = {"spawned": False, "reason": "codex total cap reached"}

    # 6. Record completed EA reviews — look for verdict JSONs that
    #    correspond to ea_review tasks NOT yet recorded.
    with connect(root) as conn:
        unreviewed = conn.execute(
            "SELECT * FROM tasks WHERE kind='ea_review' AND status='pending'"
        ).fetchall()
    result["review_records"] = []
    for row in unreviewed:
        payload = json.loads(row["payload_json"])
        vp = payload.get("verdict_path") or (str(root / "artifacts" / "verdicts" / f"review_{row['id']}.json"))
        if vp and Path(vp).exists() and Path(vp).stat().st_size > 0:
            try:
                rec = record_review_result(root, row["id"], vp)
                result["review_records"].append({"task_id": row["id"], "recorded": rec})
            except Exception as e:
                result["review_records"].append({"task_id": row["id"], "error": str(e)})

    # 7. Spawn G0 review of draft cards. G0 is a mass-review lane; Codex owns it
    # under the 2026-05-30 Claude role policy. Claude remains available for
    # premium review/synthesis lanes above, but not for G0 batches.
    claude_review_spawned = (
        isinstance(result.get("claude_review_spawn"), dict)
        and result["claude_review_spawn"].get("spawned")
    )
    codex_review_spawned = (
        isinstance(result.get("codex_review_spawn"), dict)
        and result["codex_review_spawn"].get("spawned")
    )
    spawned_other = bool(claude_review_spawned or codex_review_spawned)
    result["codex_g0_spawn"] = None
    g0_builds_now = len([s for s in (result.get("codex_spawns_all") or []) if isinstance(s, dict) and s.get("spawned")])
    g0_reviews_now = (
        len([s for s in (result.get("codex_review_spawns") or []) if isinstance(s, dict) and s.get("spawned")])
        + (1 if codex_review_spawned else 0)
    )
    result["claude_g0_spawn"] = {"spawned": False, "reason": "G0 mass review routed to Codex by Claude role policy"}
    if claude_disabled:
        result["claude_g0_spawn"] = {"spawned": False, "reason": "CLAUDE_DISABLED.flag present; routed to Codex"}

    if codex_low_tokens:
        result["codex_g0_spawn"] = {"spawned": False, "reason": "CODEX_LOW_TOKENS.flag present"}
    elif not spawned_other and (active_codex + g0_builds_now + g0_reviews_now) < MAX_PARALLEL_CODEX:
        result["codex_g0_spawn"] = _spawn_codex_for_g0_batch(root)
        if result["codex_g0_spawn"].get("spawned"):
            spawned_other = True

    # 8. Claude research is cap-gated and still subordinate to the research
    #    replenishment gate computed below. Codex research remains available.
    result["claude_research_spawn"] = {"spawned": False, "reason": "research gate not evaluated yet"}

    # 9. Spawn Codex research only when the strategy reservoir is low.
    #    OWNER 2026-05-19: Research is no longer continuous; the factory has
    #    enough strategies to process. New research is allowed only when the
    #    combined strategy/card/pipeline backlog drops below 5.
    MAX_PARALLEL_CODEX_RESEARCH = 3
    try:
        codex_research_fresh = 0
        for log in (root / "logs").glob("codex_research_*.live.log"):
            if time.time() - log.stat().st_mtime < 60:
                codex_research_fresh += 1
    except Exception:
        codex_research_fresh = 0
    result["codex_research_active"] = codex_research_fresh
    # active_codex was measured before this pump's build/review spawns.
    # Refresh by adding what we just spawned, so total cap stays at MAX_PARALLEL_CODEX.
    builds_spawned_this_cycle = len([s for s in (result.get("codex_spawns_all") or []) if isinstance(s, dict) and s.get("spawned")])
    reviews_spawned_this_cycle = (
        len([s for s in (result.get("codex_review_spawns") or []) if isinstance(s, dict) and s.get("spawned")])
        + (1 if codex_review_spawned else 0)
    )
    g0_spawned_this_cycle = (
        1
        if isinstance(result.get("codex_g0_spawn"), dict) and result["codex_g0_spawn"].get("spawned")
        else 0
    )
    result["codex_research_spawns"] = []
    research_min_backlog = 5
    research_inventory = research_backlog_inventory(root)
    result["research_backlog_inventory"] = research_inventory
    result["research_replenish_gate"] = {
        "min_strategy_backlog": research_min_backlog,
        "strategy_backlog": research_inventory.get("total", 0),
        "allow_new_research": research_inventory.get("total", 0) < research_min_backlog,
    }
    if result["research_replenish_gate"]["allow_new_research"]:
        if claude_disabled:
            result["claude_research_spawn"] = {"spawned": False, "reason": "CLAUDE_DISABLED.flag present; routed to Codex"}
        elif (active_claude_count + claude_spawns_this_cycle) < MAX_PARALLEL_CLAUDE:
            result["claude_research_spawn"] = _claim_research_source(root)
            if result["claude_research_spawn"].get("spawned"):
                claude_spawns_this_cycle += 1
        else:
            result["claude_research_spawn"] = {"spawned": False, "reason": "claude cap reached"}
    else:
        result["claude_research_spawn"] = {"spawned": False, "reason": "strategy backlog above replenishment gate"}

    if codex_low_tokens:
        result["codex_research_spawns"].append({
            "spawned": False,
            "reason": "CODEX_LOW_TOKENS.flag present",
            "strategy_backlog": research_inventory.get("total", 0),
            "min_strategy_backlog": research_min_backlog,
        })
    elif result["research_replenish_gate"]["allow_new_research"]:
        # Spawn up to (MAX_PARALLEL_CODEX_RESEARCH - codex_research_fresh) new
        # research sessions, respecting the total codex cap.
        research_to_spawn = max(0, MAX_PARALLEL_CODEX_RESEARCH - codex_research_fresh)
        for _ in range(research_to_spawn):
            total_now = (active_codex + builds_spawned_this_cycle + reviews_spawned_this_cycle + g0_spawned_this_cycle
                         + len(result["codex_research_spawns"]))
            if total_now >= MAX_PARALLEL_CODEX:
                break
            spawn = _claim_research_source_codex(root)
            result["codex_research_spawns"].append(spawn)
            if not spawn.get("spawned"):
                break  # no more research work available — stop trying
    else:
        result["codex_research_spawns"].append({
            "spawned": False,
            "reason": "strategy backlog >= 5; research replenish paused by OWNER 2026-05-19",
            "strategy_backlog": research_inventory.get("total", 0),
            "min_strategy_backlog": research_min_backlog,
        })
    # Back-compat: keep the singular field pointing to the first spawn
    result["codex_research_spawn"] = (result["codex_research_spawns"][0]
                                       if result["codex_research_spawns"] else None)

    # 10. Parameter ablation — phase-aware:
    #     - P2-PASS (exploration): 5 random ±25% mutations to find a viable
    #       region. OWNER 2026-05-16 "Ablation auf Gewinner statt Greenfield".
    #     - P3-PASS (exploitation): 50 systematic grid points ±30% across the
    #       top numeric strategy_* inputs (cartesian product). OWNER 2026-05-17
    #       "für jeden P3-PASS 50 Ablations spawnen (parameter-grid)".
    #     Ablation children themselves never re-ablate (is_ablation=0 filter).
    try:
        from ablate import spawn_ablation_workitems
    except ImportError:
        import sys as _sys
        _sys.path.insert(0, str(Path(__file__).resolve().parent))
        from ablate import spawn_ablation_workitems
    result["ablation_children"] = []

    # §10a P2-PASS → 5 random
    #
    # NOTE: depth-1 filter uses setfile_path pattern, NOT payload flag.
    # The MT5 worker overwrites payload_json with its own runtime fields
    # (terminal, pid, started_at, etc.) — any is_ablation flag we set at
    # work_item-insertion time is GONE by the time the verdict comes in.
    # The setfile name (`*_ablation_NN.set` / `*_grid_NNN.set`) is the only
    # reliable lineage marker that survives worker overwrites.
    with connect(root) as conn:
        p2_pass = conn.execute(
            """
            SELECT * FROM work_items
            WHERE status='done' AND verdict='PASS' AND phase in ('Q02', 'P2')
              AND setfile_path NOT LIKE '%_ablation_%'
              AND setfile_path NOT LIKE '%_grid_%'
              AND COALESCE(json_extract(payload_json, '$.ablated_at'), '')=''
            ORDER BY updated_at ASC LIMIT 5
            """
        ).fetchall()
        for wi in p2_pass:
            try:
                report = spawn_ablation_workitems(
                    conn, dict(wi), FRAMEWORK_EAS_DIR,
                    n_variants=5, perturb_pct=0.25, method="random",
                )
                result["ablation_children"].append(report)
            except Exception as exc:
                result["ablation_children"].append({
                    "parent_id": wi["id"], "ea_id": wi["ea_id"],
                    "method": "random",
                    "children_count": 0, "reason": f"error: {exc!r}",
                })

    # §10c Promote exploration P2-PASS work_items into P3.
    #
    # Problem: the original P2→P3 auto-enqueue (in classify_aggregate) gates
    # on "does a backtest_p3 task already exist for this ea_id". When the
    # first 3 P2-PASSes for 1049 created a backtest_p3 task, that task only
    # received work_items for the setfiles that existed at the time (3
    # originals). Exploration children that later pass P2 never get a
    # corresponding P3 work_item because the gate sees "P3 task exists".
    #
    # Fix: directly insert P3 work_items per (ea_id, symbol, setfile) that
    # passed P2 but has no P3 work_item yet. Re-open the parent P3 task back
    # to 'pending' so classify_aggregate re-aggregates when new work_items
    # finish. Skip rows where no parent P3 task exists yet (next cycle will
    # catch them after the first PASS goes through normal auto-enqueue).
    result["p3_promotions"] = []
    result["p3_promotions_skipped"] = []
    with connect(root) as conn:
        promotable = conn.execute(
            """
            SELECT w.* FROM work_items w
            WHERE w.status='done' AND w.verdict='PASS' AND w.phase in ('Q02', 'P2')
              AND NOT EXISTS (
                SELECT 1 FROM work_items w2
                WHERE w2.ea_id = w.ea_id
                  AND w2.symbol = w.symbol
                  AND w2.setfile_path = w.setfile_path
                  AND w2.phase in ('Q03', 'P3')
              )
            ORDER BY w.updated_at ASC LIMIT 5000
            """
        ).fetchall()
        reopened_parents: set[str] = set()
        for wi in promotable:
            if len(result["p3_promotions"]) >= 250:
                break
            p2_net_profit = _work_item_p2_net_profit(wi)
            if p2_net_profit is None or p2_net_profit <= 0.0:
                result["p3_promotions_skipped"].append({
                    "ea_id": wi["ea_id"],
                    "symbol": wi["symbol"],
                    "setfile_path": wi["setfile_path"],
                    "reason": P2_UNPROFITABLE_SYMBOL_REASON,
                    "p2_net_profit": p2_net_profit,
                    "parent_p2_work_item_id": wi["id"],
                })
                continue
            if not _setfile_path_exists(wi["setfile_path"]):
                result["p3_promotions_skipped"].append({
                    "ea_id": wi["ea_id"],
                    "symbol": wi["symbol"],
                    "setfile_path": wi["setfile_path"],
                    "reason": "missing_setfile",
                    "parent_p2_work_item_id": wi["id"],
                })
                continue
            # 2026-05-23 OR3: this cascade path is the pre-rewrite P2→P3
            # promoter. Kept for back-compat (returns 0 rows on the wiped DB
            # since no P2 work_items exist). New Q-pipeline cascade happens
            # at the `cascade_phase_map` loop further down (sets phase='Q03').
            parent = conn.execute(
                "SELECT id, status FROM tasks WHERE kind='backtest_q03' "
                "AND payload_json LIKE ? ORDER BY created_at ASC LIMIT 1",
                (f'%"ea_id": "{wi["ea_id"]}"%',),
            ).fetchone()
            if not parent:
                parent_id = create_task(
                    conn,
                    kind="backtest_q03",
                    source_id=None,
                    card_id=wi["ea_id"],
                    payload={
                        "ea_id": wi["ea_id"],
                        "phase": "Q03",
                        "created_by": "p2_pass_promoter",
                    },
                )
                parent = conn.execute(
                    "SELECT id, status FROM tasks WHERE id=?",
                    (parent_id,),
                ).fetchone()
            new_id = str(uuid.uuid4())
            now = utc_now()
            payload = {"promoted_from_p2_work_item": wi["id"]}
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status,
                   attempt_count, parent_task_id, payload_json, created_at, updated_at)
                VALUES (?, 'backtest', 'Q03', ?, ?, ?, 'pending', 0, ?, ?, ?, ?)
                """,
                (new_id, wi["ea_id"], wi["symbol"], wi["setfile_path"],
                 parent["id"], json.dumps(payload), now, now),
            )
            # Re-open parent Q03 task so classify_aggregate re-runs when this
            # work_item finishes. No-op if already pending.
            if parent["id"] not in reopened_parents and parent["status"] == "done":
                conn.execute(
                    "UPDATE tasks SET status='pending', updated_at=? WHERE id=?",
                    (now, parent["id"]),
                )
                reopened_parents.add(parent["id"])
            result["p3_promotions"].append({
                "p3_work_item_id": new_id,
                "ea_id": wi["ea_id"],
                "symbol": wi["symbol"],
                "setfile": Path(wi["setfile_path"]).name,
                "parent_p2_work_item_id": wi["id"],
                "parent_p3_task_id": parent["id"],
                "reopened_parent": parent["id"] in reopened_parents and parent["status"] == "done",
            })
        if result["p3_promotions"]:
            conn.commit()

    with connect(root) as conn:
        result["p5_calibration_auto_stubbed"] = _auto_stub_p5_calibration(root, conn)

    result["cascade_promotions"] = []
    result["cascade_promotions_skipped"] = []
    # 2026-05-23 OR3 — Qxx cascade map. Each phase's PASS promotes to the next.
    # Q09 News Mode auto-defaults to Mode 3 (per Vault), no explicit PASS needed
    # — so Q08 PASS cascades directly to Q10 (skipping the Q09 mode-selection
    # step which is handled as a setfile patch in the Q10 runner).
    cascade_phase_map = {
        "Q03": "Q04",
        "Q04": "Q05",
        "Q05": "Q06",
        "Q06": "Q07",
        "Q07": "Q08",
        "Q08": "Q10",   # Q09 is auto-defaulted; Q10 is the closing per-(EA, sym) verdict
    }
    cascade_pass_verdicts = {
        "Q03": {"PASS"},
        "Q04": {"PASS"},
        "Q05": {"PASS"},
        "Q06": {"PASS"},
        "Q07": {"PASS"},
        "Q08": {"PASS"},
        # Pre-rewrite keys retained inert for any orphan reads against the
        # empty post-wipe DB. These will never match new rows.
        "P3": {"PASS"},
        "P3.5": {"PASS"},
        "P4": {"PASS"},
        "P5": {"PASS"},
        "P5b": {"PASS"},
        "P5c": {"PASS"},
        "P6": {"PASS", "MULTI_SEED_PASS"},
        "P7": {"PASS"},
    }
    with connect(root) as conn:
        conn.execute("BEGIN IMMEDIATE")
        reopened_parents: set[str] = set()
        for prev_phase, next_phase in cascade_phase_map.items():
            verdicts = sorted(cascade_pass_verdicts[prev_phase])
            placeholders = ",".join("?" for _ in verdicts)
            promotable = conn.execute(
                f"""
                SELECT w.* FROM work_items w
                WHERE w.status='done' AND w.phase=? AND w.verdict in ({placeholders})
                  AND NOT EXISTS (
                    SELECT 1 FROM work_items w2
                    WHERE w2.ea_id = w.ea_id
                      AND w2.symbol = w.symbol
                      AND w2.phase = ?
                      AND w2.setfile_path = w.setfile_path
                      AND (
                        w2.payload_json LIKE ?
                        OR w2.payload_json LIKE ?
                      )
                  )
                ORDER BY w.updated_at ASC LIMIT 10
                """,
                (
                    prev_phase,
                    *verdicts,
                    next_phase,
                    f'%"promoted_from_phase": "{prev_phase}"%',
                    f'%"promoted_from_phase":"{prev_phase}"%',
                ),
            ).fetchall()
            for wi in promotable:
                if not _setfile_path_exists(wi["setfile_path"]):
                    result["cascade_promotions_skipped"].append({
                        "ea_id": wi["ea_id"],
                        "symbol": wi["symbol"],
                        "setfile_path": wi["setfile_path"],
                        "from_phase": prev_phase,
                        "to_phase": next_phase,
                        "from_work_item_id": wi["id"],
                        "reason": "missing_setfile",
                    })
                    continue
                next_kind = next_phase.lower().replace(".", "")
                parent = conn.execute(
                    "SELECT id, status FROM tasks WHERE kind=? "
                    "AND payload_json LIKE ? ORDER BY created_at ASC LIMIT 1",
                    (f"backtest_{next_kind}", f'%"ea_id": "{wi["ea_id"]}"%'),
                ).fetchone()
                parent_id = parent["id"] if parent else None
                new_id = str(uuid.uuid4())
                now = utc_now()
                payload = {
                    "promoted_from_phase": prev_phase,
                    "promoted_from_work_item": wi["id"],
                    "promotion_source": "pump_cascade",
                }
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       attempt_count, parent_task_id, payload_json, created_at, updated_at)
                    VALUES (?, 'backtest', ?, ?, ?, ?, 'pending', 0, ?, ?, ?, ?)
                    """,
                    (new_id, next_phase, wi["ea_id"], wi["symbol"], wi["setfile_path"],
                     parent_id, json.dumps(payload, sort_keys=True), now, now),
                )
                reopened_parent = False
                if parent and parent["id"] not in reopened_parents and parent["status"] == "done":
                    conn.execute(
                        "UPDATE tasks SET status='pending', updated_at=? WHERE id=?",
                        (now, parent["id"]),
                    )
                    reopened_parents.add(parent["id"])
                    reopened_parent = True
                result["cascade_promotions"].append({
                    "work_item_id": new_id,
                    "ea_id": wi["ea_id"],
                    "symbol": wi["symbol"],
                    "from_phase": prev_phase,
                    "to_phase": next_phase,
                    "from_work_item_id": wi["id"],
                    "parent_task_id": parent_id,
                    "reopened_parent": reopened_parent,
                })
        if result["cascade_promotions"]:
            conn.commit()

    # §10d Synthetic variants for proven winners — EAs with ≥3 P2-PASSes
    # get a one-shot 30-variant burst exploring symbol family + bool flips +
    # ±30% on top-2 numerics. Triggers ONCE per EA (idempotent via
    # synthetic_variants_spawned_at on build_ea task).
    try:
        from synth_variants import auto_spawn_for_winners
    except ImportError:
        import sys as _sys
        _sys.path.insert(0, str(Path(__file__).resolve().parent))
        from synth_variants import auto_spawn_for_winners
    with connect(root) as conn:
        result["synthetic_variants"] = auto_spawn_for_winners(
            conn, FRAMEWORK_EAS_DIR, min_pass_count=3, max_variants_per_ea=30,
        )

    # §10b P3-PASS → 50 grid (one parent per pump cycle — 50 children is a lot)
    # Same setfile_path lineage check as §10a (see comment above).
    with connect(root) as conn:
        p3_pass = conn.execute(
            """
            SELECT * FROM work_items
            WHERE status='done' AND verdict='PASS' AND phase in ('Q03', 'P3')
              AND setfile_path NOT LIKE '%_ablation_%'
              AND setfile_path NOT LIKE '%_grid_%'
              AND COALESCE(json_extract(payload_json, '$.ablated_at'), '')=''
            ORDER BY updated_at ASC LIMIT 1
            """
        ).fetchall()
        for wi in p3_pass:
            try:
                report = spawn_ablation_workitems(
                    conn, dict(wi), FRAMEWORK_EAS_DIR,
                    n_variants=50, perturb_pct=0.30, method="grid",
                )
                result["ablation_children"].append(report)
            except Exception as exc:
                result["ablation_children"].append({
                    "parent_id": wi["id"], "ea_id": wi["ea_id"],
                    "method": "grid",
                    "children_count": 0, "reason": f"error: {exc!r}",
                })

    result["db_backup"] = _hourly_db_backup(root)
    result["p_pass_stagnation_alarm"] = {
        "triggered": False,
        "reason": "mail disabled in pump; health alarm mail is sent only by QM_StrategyFarm_GmailAlarm_Hourly",
    }
    result["ws0_clear_notifier"] = {
        "triggered": False,
        "reason": "disabled_by_owner_2026_05_22; one-shot ping email channel retired",
    }
    result["task_watch_notifier"] = {
        "triggered": False,
        "reason": "disabled_by_owner_2026_05_22; one-shot ping email channel retired",
    }

    return result


def next_action(root: Path) -> dict[str, Any]:
    current = status(root)
    active = current["active_sources"]
    if len(active) > 1:
        return {
            "action": "repair_required",
            "reason": "More than one active source exists. Resolve before continuing.",
            "active_sources": active,
        }
    if active:
        claude_disabled = (root / "CLAUDE_DISABLED.flag").exists()
        return {
            "action": "research_active_source",
            "role": "Codex" if claude_disabled else "Claude",
            "required_capabilities": ["research", "strategy"],
            "routing_reason": "CLAUDE_DISABLED.flag present; route research to Codex/Gemini-compatible workers" if claude_disabled else "legacy research role",
            "source": active[0],
            "expected_output": "source notes and draft strategy cards under artifacts/source_notes and artifacts/cards_draft",
        }
    pending = current["next_pending_source"]
    if pending:
        return {
            "action": "claim_source",
            "command": "python tools/strategy_farm/farmctl.py claim-source",
            "source": pending,
        }
    return {"action": "idle", "reason": "No pending sources or active work."}


def claim_source(root: Path) -> dict[str, Any]:
    init_db(root)
    now = utc_now()
    with connect(root) as conn:
        active = conn.execute("SELECT COUNT(*) AS count FROM sources WHERE status = 'active'").fetchone()["count"]
        if active:
            return {"claimed": None, "reason": "An active source already exists.", "next_action": next_action(root)}
        row = conn.execute(
            """
            SELECT id, priority, lane, source_type, uri, title, status
            FROM sources
            WHERE status = 'pending'
            ORDER BY priority, created_at, id
            LIMIT 1
            """
        ).fetchone()
        if row is None:
            return {"claimed": None, "reason": "No pending source exists."}
        conn.execute("UPDATE sources SET status = 'active', updated_at = ? WHERE id = ?", (now, row["id"]))
        event(conn, "source", row["id"], "claimed", {"previous_status": "pending"})
    write_sources_jsonl(root)
    claimed = dict(row)
    claimed["status"] = "active"
    return {"claimed": claimed, "next_action": next_action(root)}


def set_source_status(root: Path, sid: str, new_status: str, notes_path: str | None = None) -> dict[str, Any]:
    init_db(root)
    now = utc_now()
    allowed = {
        "pending",
        "active",
        "notes_ready",
        "cards_ready",
        "approved",
        "rejected",
        "done",
        "blocked",
    }
    if new_status not in allowed:
        return {"updated": False, "reason": f"Unsupported status: {new_status}", "allowed": sorted(allowed)}
    with connect(root) as conn:
        row = conn.execute("SELECT id, status, notes_path FROM sources WHERE id = ?", (sid,)).fetchone()
        if row is None:
            return {"updated": False, "reason": f"Unknown source id: {sid}"}
        if new_status == "active":
            active = conn.execute(
                "SELECT id FROM sources WHERE status = 'active' AND id != ? LIMIT 1", (sid,)
            ).fetchone()
            if active is not None:
                return {
                    "updated": False,
                    "reason": "Another active source exists. Only one active source is allowed.",
                    "active_source_id": active["id"],
                }
        final_notes = notes_path if notes_path is not None else row["notes_path"]
        conn.execute(
            "UPDATE sources SET status = ?, notes_path = ?, updated_at = ? WHERE id = ?",
            (new_status, final_notes, now, sid),
        )
        event(
            conn,
            "source",
            sid,
            "status_changed",
            {"from": row["status"], "to": new_status, "notes_path": final_notes},
        )
    write_sources_jsonl(root)
    return {"updated": True, "source_id": sid, "from": row["status"], "to": new_status, "next_action": next_action(root)}


def events_tail(root: Path, limit: int) -> dict[str, Any]:
    init_db(root)
    with connect(root) as conn:
        rows = rows_as_dicts(
            conn.execute(
                """
                SELECT ts, entity_type, entity_id, event, detail_json
                FROM events
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        )
    rows.reverse()
    for row in rows:
        row["detail"] = json.loads(row.pop("detail_json"))
    return {"events": rows}


def render_claude_prompt(root: Path, source_id_arg: str | None, out_path: str | None) -> dict[str, Any]:
    init_db(root)
    with connect(root) as conn:
        if source_id_arg:
            row = conn.execute(
                """
                SELECT id, priority, lane, source_type, uri, title, status
                FROM sources
                WHERE id = ?
                """,
                (source_id_arg,),
            ).fetchone()
        else:
            row = conn.execute(
                """
                SELECT id, priority, lane, source_type, uri, title, status
                FROM sources
                WHERE status = 'active'
                ORDER BY priority, created_at, id
                LIMIT 1
                """
            ).fetchone()
    if row is None:
        return {"written": False, "reason": "No matching source. Claim a source first or pass --source-id."}

    template = CLAUDE_RESEARCH_TEMPLATE.read_text(encoding="utf-8")
    values = {
        "source_id": row["id"],
        "title": row["title"],
        "source_type": row["source_type"],
        "lane": row["lane"],
        "uri": row["uri"],
    }
    prompt = template
    for key, value in values.items():
        prompt = prompt.replace("{{" + key + "}}", str(value))

    target = Path(out_path) if out_path else root / "queue" / f"claude_research_{row['id']}.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(prompt, encoding="utf-8", newline="\n")

    return {
        "written": True,
        "prompt_path": str(target),
        "source": dict(row),
        "suggested_command": (
            "claude -p --permission-mode acceptEdits "
            f"--add-dir \"{REPO_ROOT}\" "
            f"--add-dir \"{root}\" "
            "--add-dir \"G:\\My Drive\\QuantMechanica - Company Reference\" "
            f"\"$(Get-Content -Raw '{target}')\""
        ),
    }


def _terminal_from_path(path: str | None) -> str | None:
    if not path:
        return None
    match = re.search(r"\\mt5\\(T(?:[1-9]|10))\\", str(path), re.IGNORECASE)
    if not match:
        return None
    terminal = match.group(1).upper()
    return terminal if is_factory_terminal_name(terminal) else None


def _work_item_id_from_commandline(command_line: str | None) -> str | None:
    if not command_line:
        return None
    match = re.search(r"\\work_items\\([^\\/\s\"]+)", str(command_line), re.IGNORECASE)
    return match.group(1) if match else None


def _scan_terminal64_processes() -> list[dict[str, Any]]:
    ps = (
        "Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" "
        "| Select-Object ProcessId,ParentProcessId,ExecutablePath,CommandLine,CreationDate "
        "| ConvertTo-Json -Depth 4"
    )
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", ps],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception:
        return []
    if result.returncode != 0 or not (result.stdout or "").strip():
        return []
    try:
        raw = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    rows = raw if isinstance(raw, list) else [raw]
    processes: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        exe = str(row.get("ExecutablePath") or "")
        cmd = str(row.get("CommandLine") or "")
        terminal = _terminal_from_path(exe)
        processes.append({
            "pid": row.get("ProcessId"),
            "parent_pid": row.get("ParentProcessId"),
            "terminal": terminal,
            "executable_path": exe,
            "work_item_id": _work_item_id_from_commandline(cmd),
            "pipeline_run": "\\reports\\pipeline\\" in cmd.lower(),
            "command_line": cmd,
            "creation_date": row.get("CreationDate"),
        })
    return processes


def _scan_terminal_worker_processes() -> dict[str, list[int]]:
    ps = (
        "Get-CimInstance Win32_Process "
        "| Where-Object { $_.CommandLine -match 'terminal_worker.py' } "
        "| Select-Object ProcessId,CommandLine | ConvertTo-Json -Depth 4"
    )
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", ps],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception:
        return {}
    if result.returncode != 0 or not (result.stdout or "").strip():
        return {}
    try:
        raw = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}
    rows = raw if isinstance(raw, list) else [raw]
    workers: dict[str, list[int]] = {t: [] for t in active_mt5_terminals()}
    for row in rows:
        if not isinstance(row, dict):
            continue
        match = re.search(r"--terminal\s+(T(?:[1-9]|10))\b", str(row.get("CommandLine") or ""), re.IGNORECASE)
        if not match:
            continue
        try:
            pid = int(row.get("ProcessId"))
        except (TypeError, ValueError):
            continue
        terminal = match.group(1).upper()
        if not is_factory_terminal_name(terminal):
            continue
        workers.setdefault(terminal, []).append(pid)
    return {terminal: pids for terminal, pids in workers.items() if pids}


def get_mt5_status(root: Path | None = None) -> dict[str, Any]:
    """Return MT5 fleet status with per-slot attribution."""
    scan_at = utc_now()
    processes = _scan_terminal64_processes()
    workers = _scan_terminal_worker_processes()
    work_item_status: dict[str, dict[str, Any]] = {}
    if root is not None:
        ids = sorted({p["work_item_id"] for p in processes if p.get("work_item_id")})
        if ids:
            with connect(root) as conn:
                placeholders = ",".join("?" for _ in ids)
                rows = conn.execute(
                    f"SELECT id, status, phase, ea_id, symbol, claimed_by FROM work_items WHERE id in ({placeholders})",
                    ids,
                ).fetchall()
            work_item_status = {row["id"]: dict(row) for row in rows}
    for proc_info in processes:
        wi = proc_info.get("work_item_id")
        proc_info["work_item_status"] = work_item_status.get(wi) if wi else None
        proc_info["orphaned_work_item_process"] = bool(
            wi and (wi not in work_item_status or work_item_status[wi].get("status") != "active")
        )
    terminals_running = sorted({p["terminal"] for p in processes if p.get("terminal")})
    duplicate_workers = {terminal: pids for terminal, pids in workers.items() if len(pids) > 1}

    return {
        "scanned_at": scan_at,
        "terminal64_running_count": len(processes),
        "running_mt5_terminals": terminals_running,
        "processes": processes,
        "terminal_workers": workers,
        "duplicate_terminal_workers": duplicate_workers,
        "orphaned_terminal_processes": [p for p in processes if p.get("orphaned_work_item_process")],
    }


def reconcile_mt5_slots(root: Path, fix_workers: bool = False, fix_orphan_terminals: bool = False) -> dict[str, Any]:
    before = get_mt5_status(root)
    actions: list[dict[str, Any]] = []
    if fix_workers:
        starter = REPO_ROOT / "tools" / "strategy_farm" / "start_terminal_workers.py"
        cmd = [sys.executable, str(starter), "--repo-root", str(REPO_ROOT), "--farm-root", str(root), "--dedupe"]
        result = subprocess.run(
            cmd,
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=30,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        actions.append({
            "action": "start_terminal_workers_dedupe",
            "returncode": result.returncode,
            "stdout": (result.stdout or "").strip(),
            "stderr": (result.stderr or "").strip(),
        })
    if fix_orphan_terminals:
        for proc_info in before.get("orphaned_terminal_processes", []):
            terminal = proc_info.get("terminal")
            pid = proc_info.get("pid")
            if not is_factory_terminal_name(terminal):
                continue
            status = (proc_info.get("work_item_status") or {}).get("status")
            if status == "active":
                continue
            stopped = _stop_pid(pid)
            actions.append({
                "action": "stop_orphaned_terminal64",
                "terminal": terminal,
                "pid": pid,
                "work_item_id": proc_info.get("work_item_id"),
                "work_item_status": status,
                "stopped": stopped,
            })
    after = get_mt5_status(root)
    return {"scanned_at": utc_now(), "before": before, "actions": actions, "after": after}


def classify_p2(report_csv_path: Path) -> dict[str, Any]:
    """Apply the P2 phase gate to a p2_baseline report.csv.

    Verdict logic per Pipeline Overview + HR7:
    - >=1 PASS symbol  -> PASS, advance EA (Portfolio-Kandidat = mindestens 1 Symbol durch).
    - All FAIL with trade_count_below_min reason  -> ZERO_TRADES (HR7: setup, not strategy fail).
    - >=50% INVALID  -> INFRA_FAIL (G1 / real-ticks / model4 setup problem).
    - Otherwise  -> STRATEGY_FAIL.
    """
    if not report_csv_path.exists():
        return {
            "verdict": "INFRA_FAIL",
            "reason": "report.csv missing",
            "evidence_path": str(report_csv_path),
        }

    rows: list[dict[str, str]] = []
    try:
        with report_csv_path.open(encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
    except Exception as exc:
        return {
            "verdict": "INFRA_FAIL",
            "reason": f"report.csv unreadable: {exc}",
            "evidence_path": str(report_csv_path),
        }

    if not rows:
        return {
            "verdict": "INFRA_FAIL",
            "reason": "report.csv has no data rows",
            "evidence_path": str(report_csv_path),
        }

    surviving = [r["symbol"] for r in rows if r.get("verdict") == "PASS"]
    fails = [r for r in rows if r.get("verdict") == "FAIL"]
    invalids = [r for r in rows if r.get("verdict") == "INVALID"]
    zero_trade_syms = [
        r["symbol"] for r in fails
        if "trade_count_below_min" in (r.get("invalidation_reason") or "")
    ]
    strategy_fail_syms = [r["symbol"] for r in fails if r["symbol"] not in zero_trade_syms]

    counts: dict[str, int] = {}
    for r in rows:
        v = r.get("verdict", "MISSING")
        counts[v] = counts.get(v, 0) + 1

    base = {
        "evidence_path": str(report_csv_path),
        "counts_by_verdict": counts,
        "surviving_symbols": surviving,
        "zero_trade_symbols": zero_trade_syms,
        "invalid_symbols": [r["symbol"] for r in invalids],
        "strategy_fail_symbols": strategy_fail_syms,
    }

    if surviving:
        return {**base, "verdict": "PASS"}
    if zero_trade_syms and not strategy_fail_syms:
        return {
            **base,
            "verdict": "ZERO_TRADES",
            "advice": "Per HR7 NO_REPORT != EA-Schwaeche. Investigate filters/window before declaring strategy fail.",
        }
    if invalids and len(invalids) >= 0.5 * len(rows):
        return {
            **base,
            "verdict": "INFRA_FAIL",
            "advice": "Majority INVALID — check G1 real-ticks marker, Model 4 setup, tester defaults.",
        }
    return {**base, "verdict": "STRATEGY_FAIL"}


def classify_p3(report_csv_path: Path) -> dict[str, Any]:
    """Classify a P3 parameter sweep.

    Verdict logic:
    - >=1 PASS row  -> PASS (at least one param combo survived; advance to P3.5).
    - All rows present but 0 PASS  -> STRATEGY_FAIL.
    - report missing / unreadable / empty  -> INFRA_FAIL.

    p3_param_sweep.py rows are keyed by run_id (=symbol_period_NNN) with a
    verdict column. surviving_params is the list of param dicts that passed.
    """
    if not report_csv_path.exists():
        return {"verdict": "INFRA_FAIL", "reason": "report.csv missing", "evidence_path": str(report_csv_path)}
    try:
        with report_csv_path.open(encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
    except Exception as exc:
        return {"verdict": "INFRA_FAIL", "reason": f"report.csv unreadable: {exc}", "evidence_path": str(report_csv_path)}
    if not rows:
        return {"verdict": "INFRA_FAIL", "reason": "report.csv has no data rows", "evidence_path": str(report_csv_path)}

    passes = [r for r in rows if r.get("verdict") == "PASS"]
    fails = [r for r in rows if r.get("verdict") == "FAIL"]
    counts = {"PASS": len(passes), "FAIL": len(fails), "TOTAL": len(rows)}
    base = {
        "evidence_path": str(report_csv_path),
        "counts_by_verdict": counts,
        "surviving_params": [r.get("params", "") for r in passes][:10],
        "surviving_run_ids": [r.get("run_id", "") for r in passes][:10],
    }
    if passes:
        return {**base, "verdict": "PASS"}
    return {**base, "verdict": "STRATEGY_FAIL"}


PHASE_CLASSIFIERS = {
    "P3": classify_p3,
    "P2": classify_p2,
}


def classify_backtest(phase: str, report_csv_path: Path) -> dict[str, Any]:
    fn = PHASE_CLASSIFIERS.get(phase)
    if fn is None:
        return {
            "verdict": "UNSUPPORTED",
            "reason": f"no classifier registered for phase {phase}",
            "evidence_path": str(report_csv_path),
        }
    return fn(report_csv_path)


def _find_ea_setfiles(ea_id: str, phase: str) -> list[tuple[str, str]]:
    """Return [(symbol, setfile_path)] for the EA's sets/ dir.

    Picks setfiles matching the period detected from the dir (single-period
    EAs are the norm). For P3+, restrict to the surviving_symbols supplied
    by the caller (filter applied externally).
    """
    ea_root = REPO_ROOT / "framework" / "EAs"
    candidates = [p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return []
    ea_dir = candidates[0]
    sets_dir = ea_dir / "sets"
    if not sets_dir.is_dir():
        return []
    period = _detect_ea_period(ea_id)
    pat = re.compile(rf"^{re.escape(ea_dir.name)}_(?P<sym>.+?)_{re.escape(period)}_backtest\.set$")
    out: list[tuple[str, str]] = []
    for f in sorted(sets_dir.iterdir()):
        m = pat.match(f.name)
        if m:
            out.append((m.group("sym"), str(f.resolve())))
    return out


def _find_single_ea_dir(ea_id: str) -> Path | None:
    ea_root = REPO_ROOT / "framework" / "EAs"
    candidates = sorted(p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir())
    if len(candidates) != 1:
        return None
    return candidates[0]


def _load_basket_manifest(ea_id: str) -> dict[str, Any] | None:
    """Load the basket EA manifest when the EA declares one."""
    ea_dir = _find_single_ea_dir(ea_id)
    if ea_dir is None:
        return None
    manifest_path = ea_dir / "basket_manifest.json"
    if not manifest_path.exists():
        return None
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(manifest, dict):
        return None
    logical_symbol = str(manifest.get("logical_symbol") or "").strip()
    host_symbol = str(manifest.get("host_symbol") or "").strip()
    host_timeframe = str(manifest.get("host_timeframe") or "").strip()
    if not logical_symbol or not host_symbol or not host_timeframe:
        return None
    manifest["manifest_path"] = str(manifest_path.resolve())
    return manifest


def _find_basket_setfile(ea_id: str, manifest: dict[str, Any]) -> tuple[str, str] | None:
    ea_dir = _find_single_ea_dir(ea_id)
    if ea_dir is None:
        return None
    logical_symbol = str(manifest["logical_symbol"])
    host_timeframe = str(manifest["host_timeframe"])
    sets_dir = ea_dir / "sets"
    expected = sets_dir / f"{ea_dir.name}_{logical_symbol}_{host_timeframe}_backtest.set"
    if expected.exists():
        return logical_symbol, str(expected.resolve())
    matches = sorted(sets_dir.glob(f"*_{logical_symbol}_{host_timeframe}_backtest.set")) if sets_dir.exists() else []
    if matches:
        return logical_symbol, str(matches[0].resolve())
    return None


def _ea_build_artifact_failure(ea_id: str) -> dict[str, Any] | None:
    """Return why an EA is not runnable before creating MT5 work_items."""
    ea_root = REPO_ROOT / "framework" / "EAs"
    candidates = sorted(p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir())
    if not candidates:
        return {"reason": "ea_dir_missing", "detail": str(ea_root / f"{ea_id}_*")}
    if len(candidates) > 1:
        return {"reason": "ea_dir_ambiguous", "detail": [p.name for p in candidates]}

    ea_dir = candidates[0]
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    if not ex5.exists():
        return {"reason": "ex5_missing", "detail": str(ex5)}
    ex5_files = sorted(p.name for p in ea_dir.glob("*.ex5"))
    if ex5_files != [ex5.name]:
        return {"reason": "duplicate_ex5", "detail": ex5_files}
    return None


def _dwx_backtest_symbols() -> list[str]:
    """Return all DWX symbols available for farm backtests.

    The registry intentionally includes SP500.DWX even though it is T6
    live-deploy restricted; P2 is a backtest gate, so custom backtest-only
    symbols remain eligible here.
    """
    matrix = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
    if not matrix.exists():
        return []
    symbols: list[str] = []
    with matrix.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            symbol = (row.get("symbol") or "").strip().upper()
            if not symbol.endswith(".DWX"):
                continue
            verified = (row.get("canonical_name_verified") or "true").strip().lower()
            if verified in {"false", "0", "no"}:
                continue
            symbols.append(symbol)
    return sorted(dict.fromkeys(symbols))


def _truthy_card_value(value: Any) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def _card_single_symbol_only(root: Path, ea_id: str) -> bool:
    card = _find_approved_card_for_ea(root, ea_id)
    if not card:
        return False
    try:
        fm = parse_card_frontmatter(card)
        if _truthy_card_value(fm.get("single_symbol_only")):
            return True
        text = card.read_text(encoding="utf-8-sig", errors="ignore")
    except OSError:
        return False
    return bool(re.search(r"\bsingle_symbol_only\s*:\s*(?:true|yes|1)\b", text, re.IGNORECASE))


def _card_declared_universe_for_ea(root: Path, ea_id: str) -> set[str]:
    card = _find_approved_card_for_ea(root, ea_id)
    if not card:
        return set()
    try:
        return _card_universe_symbols(card.read_text(encoding="utf-8-sig", errors="ignore"))
    except OSError:
        return set()


def _latest_build_smoke_result(con: sqlite3.Connection, ea_id: str) -> dict[str, Any] | None:
    row = con.execute(
        """
        SELECT id, payload_json, updated_at
        FROM tasks
        WHERE kind='build_ea' AND card_id=?
        ORDER BY updated_at DESC
        LIMIT 1
        """,
        (ea_id,),
    ).fetchone()
    if not row:
        return None
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except json.JSONDecodeError:
        payload = {}
    codex_result = payload.get("codex_result") if isinstance(payload.get("codex_result"), dict) else {}
    smoke_result = (
        codex_result.get("smoke_result")
        or payload.get("smoke_result")
        or payload.get("build_smoke_result")
    )
    return {
        "build_task_id": row["id"],
        "smoke_result": str(smoke_result or "").strip().lower(),
        "updated_at": row["updated_at"],
    }


def _magic_slot_for_symbol(ea_id: str, symbol: str) -> int:
    m = re.match(r"^QM5_(\d{4})$", ea_id)
    if not m:
        return 0
    registry = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
    if not registry.exists():
        return 0
    with registry.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            if (
                (row.get("ea_id") or "").strip() == str(int(m.group(1)))
                and (row.get("symbol") or "").strip().upper() == symbol
                and (row.get("status") or "").strip().lower() == "active"
            ):
                try:
                    return int(str(row.get("symbol_slot") or "0").strip())
                except ValueError:
                    return 0
    return 0


def _retarget_setfile_template(template_text: str, symbol: str, magic_slot: int) -> str:
    replacements = {
        r"^; symbol:\s+.*$": f"; symbol:       {symbol}",
        r"^; magic_slot:\s+.*$": f"; magic_slot:   {magic_slot}",
        r"^qm_magic_slot_offset=.*$": f"qm_magic_slot_offset={magic_slot}",
    }
    text = template_text
    for pattern, replacement in replacements.items():
        text = re.sub(pattern, replacement, text, flags=re.MULTILINE)
    return text


def _p2_target_symbols_for_ea(root: Path, ea_id: str) -> list[str]:
    declared = _card_declared_universe_for_ea(root, ea_id)
    if declared:
        return sorted(declared)
    if _card_single_symbol_only(root, ea_id):
        return [symbol for symbol, _ in _find_ea_setfiles(ea_id, "P2")]
    return _dwx_backtest_symbols()


def _ensure_p2_target_setfiles(root: Path, ea_id: str) -> list[tuple[str, str]]:
    """Ensure P2 has canonical setfiles only for the card-declared universe."""
    existing = _find_ea_setfiles(ea_id, "P2")
    target_symbols = _p2_target_symbols_for_ea(root, ea_id)
    if not existing or not target_symbols:
        return existing

    ea_root = REPO_ROOT / "framework" / "EAs"
    candidates = [p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return existing
    ea_dir = candidates[0]
    sets_dir = ea_dir / "sets"
    period = _detect_ea_period(ea_id)
    by_symbol = {symbol: path for symbol, path in existing}
    template_path = Path(existing[0][1])
    try:
        template_text = template_path.read_text(encoding="utf-8-sig")
    except OSError:
        return existing

    for symbol in target_symbols:
        if symbol in by_symbol:
            continue
        target = sets_dir / f"{ea_dir.name}_{symbol}_{period}_backtest.set"
        if not target.exists():
            magic_slot = _magic_slot_for_symbol(ea_id, symbol)
            target.write_text(
                _retarget_setfile_template(template_text, symbol, magic_slot),
                encoding="utf-8",
                newline="\n",
            )
        by_symbol[symbol] = str(target.resolve())

    return [(symbol, by_symbol[symbol]) for symbol in target_symbols if symbol in by_symbol]


def _create_backtest_work_items(conn: sqlite3.Connection, parent_task_id: str,
                                 root: Path,
                                 ea_id: str, phase: str,
                                 surviving_symbols: list[str] | None) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Fan out a backtest task into per-(symbol, setfile) work_items.

    For P2: every DWX backtest symbol from dwx_symbol_matrix.csv, unless the
    card explicitly declares single_symbol_only.
    For P3+: only setfiles whose symbol is in surviving_symbols (subset).
    Returns (created, skipped) for the response.
    """
    phase = phase_qid(phase)
    is_q02 = phase == "Q02"
    basket_manifest = _load_basket_manifest(ea_id) if is_q02 else None
    basket_setfile = _find_basket_setfile(ea_id, basket_manifest) if basket_manifest else None
    if basket_manifest:
        setfiles = [basket_setfile] if basket_setfile else []
    else:
        setfiles = _ensure_p2_target_setfiles(root, ea_id) if is_q02 else _find_ea_setfiles(ea_id, phase)
    if not setfiles:
        return [], []
    if surviving_symbols:
        symbol_set = set(surviving_symbols)
        setfiles = [(s, p) for s, p in setfiles if s in symbol_set]
    out: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    now = utc_now()
    period = _detect_ea_period(ea_id)
    history_registry = _dwx_symbol_history_registry() if is_q02 else {}
    for sym, setfile_path in setfiles:
        payload: dict[str, Any] = {}
        if basket_manifest:
            payload = {
                "basket_manifest": basket_manifest["manifest_path"],
                "basket_symbol_count": len(basket_manifest.get("basket_symbols") or []),
                "host_symbol": basket_manifest["host_symbol"],
                "host_timeframe": basket_manifest["host_timeframe"],
                "logical_symbol": basket_manifest["logical_symbol"],
                "portfolio_scope": "basket",
            }
        elif is_q02 and history_registry:
            window = _p2_history_window_for_symbol(
                sym,
                period,
                P2_DEFAULT_FROM_YEAR,
                P2_DEFAULT_TO_YEAR,
                history_registry,
            )
            if window["skip"]:
                message = (
                    f"skipping {sym}/{period} no history for "
                    f"{P2_DEFAULT_FROM_YEAR}-{P2_DEFAULT_TO_YEAR}"
                )
                _log_p2_history_filter(root, message)
                skipped.append({**window, "message": message})
                continue
            payload = {
                "from_year": window["from_year"],
                "to_year": window["to_year"],
                "requested_from_year": P2_DEFAULT_FROM_YEAR,
                "requested_to_year": P2_DEFAULT_TO_YEAR,
                "history_first_year": window["first_year"],
                "history_last_year": window["last_year"],
            }
            if window["adjusted"]:
                message = (
                    f"adjusted {sym} P2 from {P2_DEFAULT_FROM_YEAR}-{P2_DEFAULT_TO_YEAR} "
                    f"to {window['from_year']}-{window['to_year']}"
                )
                _log_p2_history_filter(root, message)
                payload["history_adjusted"] = True
                payload["history_adjustment_message"] = message
        wid = str(uuid.uuid4())
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status,
               attempt_count, parent_task_id, payload_json, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, 'pending', 0, ?, ?, ?, ?)
            """,
            (wid, "backtest", phase, ea_id, sym, setfile_path, parent_task_id,
             json.dumps(payload, sort_keys=True), now, now),
        )
        out.append({"id": wid, "symbol": sym, "setfile_path": setfile_path, "payload": payload})
    return out, skipped


def _setfile_path_exists(setfile_path: str) -> bool:
    path = Path(setfile_path)
    if path.exists():
        return True
    if not path.is_absolute():
        return (REPO_ROOT / path).exists()
    return False


def enqueue_backtest(root: Path, review_task_id: str, phase: str) -> dict[str, Any]:
    """Create a backtest_<phase> task.

    For phase P2: predecessor is an APPROVE_FOR_BACKTEST ea_review task.
    For phase P3+: predecessor is a done backtest_<prev_phase> task with
    classification.verdict == 'PASS'. The review_task_id argument is then
    actually the previous backtest task id (kept name for back-compat).
    """
    phase = phase_qid(phase)
    if phase not in SUPPORTED_BACKTEST_PHASES:
        return {
            "enqueued": False,
            "reason": f"Phase {phase} not yet supported. Supported: {SUPPORTED_BACKTEST_PHASES}",
        }
    init_db(root)
    with connect(root) as conn:
        pred_row = conn.execute("SELECT * FROM tasks WHERE id = ?", (review_task_id,)).fetchone()
        if pred_row is None:
            return {"enqueued": False, "reason": f"Predecessor task not found: {review_task_id}"}

        # P2 predecessor must be ea_review APPROVE_FOR_BACKTEST.
        # P3+ predecessor must be backtest_<prev>:done with verdict=PASS.
        p2_profit_filter_skipped: list[dict[str, Any]] = []
        if phase == "Q02":
            if pred_row["kind"] != "ea_review":
                return {"enqueued": False, "reason": f"Task {review_task_id} kind={pred_row['kind']!r}, expected ea_review for Q02"}
            review_payload = json.loads(pred_row["payload_json"])
            verdict_doc = review_payload.get("verdict") or {}
            if verdict_doc.get("verdict") != "APPROVE_FOR_BACKTEST":
                return {"enqueued": False, "reason": f"Review verdict was {verdict_doc.get('verdict')!r}, not APPROVE_FOR_BACKTEST"}
            ea_id = review_payload.get("ea_id")
            surviving_symbols = None
            surviving_params = None
        else:
            # P3+: predecessor is a done backtest task with PASS verdict.
            if not pred_row["kind"].startswith("backtest_"):
                return {"enqueued": False, "reason": f"Task {review_task_id} kind={pred_row['kind']!r}, expected backtest_<prev> for {phase}"}
            if pred_row["status"] != "done":
                return {"enqueued": False, "reason": f"Predecessor backtest task status={pred_row['status']!r}, expected 'done'"}
            pred_payload = json.loads(pred_row["payload_json"])
            classification = pred_payload.get("classification") or {}
            if classification.get("verdict") != "PASS":
                return {"enqueued": False, "reason": f"Predecessor verdict was {classification.get('verdict')!r}, not PASS"}
            ea_id = pred_payload.get("ea_id")
            surviving_symbols = classification.get("surviving_symbols", [])
            surviving_params = classification.get("surviving_params", [])
            if phase == "Q03":
                surviving_symbols, p2_profit_filter_skipped = _filter_p2_profitable_symbols(
                    conn,
                    review_task_id,
                    surviving_symbols,
                )

        if not ea_id:
            return {"enqueued": False, "reason": "Predecessor payload missing ea_id"}
        if phase == "Q02":
            smoke = _latest_build_smoke_result(conn, str(ea_id))
            if smoke and smoke.get("smoke_result") == "zero_trades":
                return {
                    "enqueued": False,
                    "reason": "q01_trade_generation_zero_trades",
                    "detail": "latest build smoke produced zero trades; route to Codex fix or card rework before Q02 fanout",
                    "ea_id": ea_id,
                    "build_task_id": smoke.get("build_task_id"),
                }
        artifact_failure = _ea_build_artifact_failure(str(ea_id))
        if artifact_failure:
            return {
                "enqueued": False,
                "reason": artifact_failure["reason"],
                "detail": artifact_failure["detail"],
                "ea_id": ea_id,
                "phase": phase,
            }

        # Each runner writes to D:/QM/reports/pipeline/<args.ea>/<PHASE>/report.csv
        # Glob matches both short (QM5_NNNN) and long (QM5_NNNN_<slug>) forms.
        expected_glob = str(PIPELINE_REPORT_ROOT / f"{ea_id}*" / phase / "report.csv")

        payload = {
            "phase": phase,
            "ea_id": ea_id,
            "predecessor_task_id": review_task_id,
            "expected_report_glob": expected_glob,
        }
        if surviving_symbols is not None:
            payload["surviving_symbols"] = surviving_symbols
        if surviving_params is not None:
            payload["surviving_params"] = surviving_params
        if phase == "Q03" and p2_profit_filter_skipped:
            payload["p2_p3_profit_filter_skipped"] = p2_profit_filter_skipped
        # Back-compat alias
        if phase == "Q02":
            payload["review_task_id"] = review_task_id

        kind_phase = "p2" if phase == "Q02" else phase.lower().replace(".", "")
        task_id = create_task(
            conn,
            kind=f"backtest_{kind_phase}",
            source_id=pred_row["source_id"],
            card_id=pred_row["card_id"],
            payload=payload,
        )

        # NEW 2026-05-16: also fan out work_items per (ea × symbol × setfile)
        # for the per-symbol queue model. The bundled `tasks` row above stays
        # as the high-level lifecycle anchor; work_items are what the MT5
        # dispatcher actually claims one-by-one.
        work_items_created, p2_history_skipped = _create_backtest_work_items(
            conn,
            parent_task_id=task_id,
            root=root,
            ea_id=ea_id,
            phase=phase,
            surviving_symbols=surviving_symbols,
        )

        # 2026-05-19: If 0 work_items get created (all symbols skipped due to
        # missing history, no surviving setfiles, etc.), mark the task failed
        # immediately. Otherwise _detect_unenqueued_eas (which checks only
        # work_items count) sees ea_review=done + work_items=0 and re-enqueues
        # on every pump cycle — observed spawn-loop creating 706 tasks/hour
        # for 3 EAs (M1 + H4 without DWX history in 2017-2022 window).
        if not work_items_created:
            skipped_count = len(p2_history_skipped or [])
            update_task(
                conn,
                task_id,
                status="failed",
                payload_merge={
                    "failure_reason": "no_work_items_created",
                    "skipped_symbols_count": skipped_count,
                    "skipped_first": (p2_history_skipped or [])[:3],
                },
            )

    return {
        "enqueued": True,
        "task_id": task_id,
        "ea_id": ea_id,
        "phase": phase,
        "work_items_created": work_items_created,
        "work_items_skipped": p2_history_skipped if phase == "Q02" else (p2_profit_filter_skipped if phase == "Q03" else []),
        "expected_report_glob": expected_glob,
        "next_action_hint": "python tools/strategy_farm/farmctl.py dispatch-tick",
    }


def enqueue_cascade_backtest_for_ea(root: Path, ea_id: str, phase: str) -> dict[str, Any]:
    """Requeue or create a P5+ cascade work_item from the prior PASS phase.

    P5+ phases are consumed by the work_item dispatcher/pump cascade, not the
    older review-task enqueue path. This keeps the operator-facing command
    idempotent and avoids duplicate EA/symbol/phase rows.
    """
    if phase not in CASCADE_BACKTEST_PHASES:
        return {
            "enqueued": False,
            "reason": f"Phase {phase} is not a cascade phase. Supported cascade phases: {CASCADE_BACKTEST_PHASES}",
        }
    artifact_failure = _ea_build_artifact_failure(str(ea_id))
    if artifact_failure:
        return {
            "enqueued": False,
            "reason": artifact_failure["reason"],
            "detail": artifact_failure["detail"],
            "ea_id": ea_id,
            "phase": phase,
        }
    prev_phase_map = {
        "P5": "P4",
        "P5b": "P5",
        "P5c": "P5b",
        "P6": "P5c",
        "P7": "P6",
        "P8": "P7",
    }
    prev_pass_verdicts = {
        "P4": {"PASS"},
        "P5": {"PASS"},
        "P5b": {"PASS"},
        "P5c": {"PASS"},
        "P6": {"PASS", "MULTI_SEED_PASS"},
        "P7": {"PASS"},
    }
    prev_phase = prev_phase_map[phase]
    verdicts = sorted(prev_pass_verdicts[prev_phase])
    placeholders = ",".join("?" for _ in verdicts)
    init_db(root)
    now = utc_now()
    created: list[dict[str, Any]] = []
    requeued: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    p5_has_history = True
    p5_history_detail: dict[str, Any] | None = None
    if phase == "P5":
        p5_has_history, p5_history_detail = has_ea_history_window(
            ea_id,
            P5_REQUIRED_OOS_FROM_YEAR,
            P5_REQUIRED_OOS_TO_YEAR,
            repo_root=REPO_ROOT,
            mt5_root=MT5_ROOT,
        )
    with connect(root) as conn:
        prev_rows = conn.execute(
            f"""
            SELECT * FROM work_items
            WHERE ea_id=? AND phase=? AND status='done' AND verdict in ({placeholders})
            ORDER BY updated_at ASC
            """,
            (ea_id, prev_phase, *verdicts),
        ).fetchall()
        for prev in prev_rows:
            if not _setfile_path_exists(prev["setfile_path"]):
                skipped.append({
                    "id": prev["id"],
                    "symbol": prev["symbol"],
                    "setfile_path": prev["setfile_path"],
                    "reason": "missing_setfile",
                })
                continue
            if phase == "P5" and not p5_has_history:
                skipped.append({
                    "id": prev["id"],
                    "symbol": prev["symbol"],
                    "setfile_path": prev["setfile_path"],
                    "reason": "cache_history_below_required_oos_window",
                    "verdict": "INVALID",
                    "required_oos_window": f"{P5_REQUIRED_OOS_FROM_YEAR}-{P5_REQUIRED_OOS_TO_YEAR}",
                    "history_detail": p5_history_detail,
                })
                continue
            existing = conn.execute(
                """
                SELECT * FROM work_items
                WHERE ea_id=? AND phase=? AND symbol=? AND setfile_path=?
                ORDER BY created_at ASC LIMIT 1
                """,
                (ea_id, phase, prev["symbol"], prev["setfile_path"]),
            ).fetchone()
            payload = {
                "promoted_from_phase": prev_phase,
                "promoted_from_work_item": prev["id"],
                "promotion_source": "farmctl_enqueue_backtest_ea",
                "requeued_at": now,
            }
            if existing:
                if existing["status"] in {"pending", "active"}:
                    skipped.append({
                        "id": existing["id"],
                        "symbol": existing["symbol"],
                        "status": existing["status"],
                        "reason": "already_pending_or_active",
                    })
                    continue
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='pending', verdict=NULL, attempt_count=0,
                        evidence_path=NULL, claimed_by=NULL, payload_json=?,
                        updated_at=?
                    WHERE id=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, existing["id"]),
                )
                requeued.append({"id": existing["id"], "symbol": existing["symbol"]})
                continue
            wid = str(uuid.uuid4())
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status,
                   attempt_count, parent_task_id, payload_json, created_at, updated_at)
                VALUES (?, 'backtest', ?, ?, ?, ?, 'pending', 0, NULL, ?, ?, ?)
                """,
                (
                    wid,
                    phase,
                    ea_id,
                    prev["symbol"],
                    prev["setfile_path"],
                    json.dumps(payload, sort_keys=True),
                    now,
                    now,
                ),
            )
            created.append({"id": wid, "symbol": prev["symbol"], "setfile_path": prev["setfile_path"]})
        if created or requeued or skipped:
            event(
                conn,
                "work_items",
                phase,
                "cascade_backtest_enqueued",
                {
                    "ea_id": ea_id,
                    "created": created,
                    "requeued": requeued,
                    "skipped": skipped,
                    "skipped_missing_setfiles_count": sum(
                        1 for row in skipped if row.get("reason") == "missing_setfile"
                    ),
                    "skipped_cache_history_count": sum(
                        1 for row in skipped
                        if row.get("reason") == "cache_history_below_required_oos_window"
                    ),
                },
            )
        conn.commit()
    if not prev_rows:
        return {
            "enqueued": False,
            "ea_id": ea_id,
            "phase": phase,
            "reason": f"No done {prev_phase} PASS work_items found for {ea_id}",
        }
    return {
        "enqueued": bool(created or requeued or skipped),
        "ea_id": ea_id,
        "phase": phase,
        "previous_phase": prev_phase,
        "created": created,
        "requeued": requeued,
        "skipped": skipped,
        "skipped_count": len(skipped),
        "skipped_missing_setfiles_count": sum(
            1 for row in skipped if row.get("reason") == "missing_setfile"
        ),
        "skipped_cache_history_count": sum(
            1 for row in skipped if row.get("reason") == "cache_history_below_required_oos_window"
        ),
        "next_action_hint": "Pump/dispatch-tick will claim pending work_items.",
    }


def _resolve_report(payload: dict[str, Any]) -> Path | None:
    """Resolve the report.csv path for a backtest task — direct path or glob."""
    direct = payload.get("expected_report_path")
    if direct and Path(direct).exists():
        return Path(direct)
    glob_pat = payload.get("expected_report_glob")
    if glob_pat:
        matches = glob.glob(glob_pat)
        if matches:
            return Path(matches[0])
    return None


def _detect_ea_period(ea_id: str) -> str:
    """Infer setfile period (D1/H1/M30/...) from existing setfile names.

    p2_baseline.py needs --period to match the setfile pattern. Default H1
    fails for any EA built on a different timeframe (e.g. QM5_1047 Halloween
    on D1). Inspect framework/EAs/<ea_id>_*/sets/ and pick the unique period.

    BUG fix 2026-05-17: original regex `_([A-Za-z0-9]+)_backtest\\.set$` had
    two issues — (a) didn't match ablation children which end in
    `_ablation_NN.set` not `_backtest.set`, (b) DID match synth children
    `_D1_synth_000_backtest.set` capturing `000` as a fake period. Result:
    QM5_1049 D1-only setfiles polluted by synth's `000`/`001`/... → no
    unique period → fallback H1 → McConnell-D1 backtest tried on H1 →
    METATESTER_HUNG. That blocked 11 P3 runs.

    Fix: match ONLY canonical MT5 timeframe tokens. Order matters
    (longest first) so H4 doesn't get partial-matched by H.
    """
    ea_root = REPO_ROOT / "framework" / "EAs"
    candidates = [p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return "H1"
    sets_dir = candidates[0] / "sets"
    if not sets_dir.is_dir():
        return "H1"
    VALID_TFS = ("MN1", "W1", "D1", "H12", "H8", "H6", "H4", "H3", "H2", "H1",
                 "M30", "M20", "M15", "M12", "M10", "M6", "M5", "M4", "M3", "M2", "M1")
    pat = re.compile(r"_(" + "|".join(VALID_TFS) + r")_")
    periods: set[str] = set()
    for f in sets_dir.iterdir():
        if not f.name.endswith(".set"):
            continue
        m = pat.search(f.name)
        if m:
            periods.add(m.group(1))
    if len(periods) == 1:
        return periods.pop()
    # Multiple TFs (rare — mixed-TF strategies) OR none detected → conservative default
    if periods:
        # Prefer the longest TF (most strategies are D1/H4 not M1)
        order = {tf: i for i, tf in enumerate(VALID_TFS)}
        return sorted(periods, key=lambda p: order.get(p, 999))[0]
    return "H1"


def _phase_runner_cmd(phase: str, ea_id: str, terminal: str | None = None,
                       surviving_symbols: list[str] | None = None,
                       out_prefix: Path | None = None,
                       setfile_path: str | None = None) -> list[str] | None:
    """Return the subprocess argv for the runner of a given phase, or None.

    P2 takes all setfiles in the EA dir; P3+ runs only on `surviving_symbols`
    from the predecessor phase (P2 PASS symbols). When `terminal` is given
    (P2-only path), pins p2_baseline to one terminal for fleet saturation.
    """
    phase_aliases = {
        "p3.5": "P3.5",
        "p4": "P4",
        "p5": "P5",
        "p5b": "P5b",
        "p5c": "P5c",
        "p6": "P6",
        "p7": "P7",
        "p8": "P8",
    }
    phase = phase_aliases.get(str(phase or "").strip().lower(), str(phase or "").strip())

    if phase in REAL_PHASE_RUNNER_PHASES:
        script_name = PHASE_RUNNER_SCRIPTS.get(phase)
        if not script_name or not (REPO_ROOT / "framework" / "scripts" / script_name).exists():
            return None
    else:
        script_name = None

    def _runner_base(default_script_name: str) -> list[str]:
        script = script_name or default_script_name
        cmd = [sys.executable, str(REPO_ROOT / "framework" / "scripts" / script), "--ea", ea_id]
        if out_prefix is not None:
            cmd.extend(["--out-prefix", str(out_prefix)])
        return cmd

    def _pipeline_file(phase_dir: str, filename: str) -> str:
        return str(PIPELINE_REPORT_ROOT / ea_id / phase_dir / filename)

    if phase == "P2":
        period = _detect_ea_period(ea_id)
        # P2 = LONG in-sample window. OWNER 2026-05-17: 2022-2024 was too
        # short (3y) — strategies that only PASS on recent bull-run noise
        # would slip through. 2017-2022 = 6 years covers GFC echo, COVID
        # crash, post-COVID rally, 2022 inflation regime — much harder to
        # curve-fit. Walk-forward 2023+ stays as the OOS gate (P4).
        cmd = [
            sys.executable,
            str(REPO_ROOT / "framework" / "scripts" / "p2_baseline.py"),
            "--ea", ea_id,
            "--period", period,
            "--from-year", "2017",
            "--to-year", "2022",
            "--min-trades", "10",  # raised from 5 — 6y covers more cycles; demand more data points
        ]
        if terminal:
            cmd.extend(["--terminal", terminal])
        return cmd

    if phase == "P3":
        period = _detect_ea_period(ea_id)
        symbols = surviving_symbols or []
        if not symbols:
            return None
        # P3 = parameter sweep on SAME in-sample window as P2 to test
        # parameter-robustness (Sharpe stable across nearby param values).
        # OWNER 2026-05-17: this is NOT an OOS test — that's P3.5/P4.
        # Same year flag still (single-year sweep is fast); but we can
        # expand once we see how runtimes pan out.
        cmd = [
            sys.executable, "-m", "framework.scripts.p3_param_sweep",
            "--ea", ea_id,
            "--symbols", ",".join(symbols),
            "--periods", period,
            "--year", "2022",  # last year of P2 window — same in-sample regime
            "--max-runs", "24",
            "--max-parallel", "5",
        ]
        return cmd

    if phase == "P3.5":
        # P3.5 = cross-symbol robustness on the SAME in-sample window.
        # Does the edge generalize across multiple DWX symbols? Different
        # from P4 walk-forward (which is true OOS in time).
        period = _detect_ea_period(ea_id)
        symbols = surviving_symbols or []
        cmd = _runner_base("p35_csr_runner.py")
        cmd.extend([
            "--symbols", ",".join(symbols),
            "--period", period,
            "--from-year", "2017",
            "--to-year", "2022",
        ])
        if setfile_path:
            cmd.extend(["--setfile", setfile_path])
        p2_report = _refresh_phase_report_from_work_items(DEFAULT_ROOT, ea_id, "P2") or (PIPELINE_REPORT_ROOT / ea_id / "P2" / "report.csv")
        if p2_report.exists():
            cmd.extend(["--baseline-csv", str(p2_report)])
        p3_report = _refresh_phase_report_from_work_items(DEFAULT_ROOT, ea_id, "P3") or (PIPELINE_REPORT_ROOT / ea_id / "P3" / "report.csv")
        if p3_report.exists():
            cmd.extend(["--csr-results-csv", str(p3_report)])
        return cmd

    if phase == "P4":
        # P4 = true OOS Walk-Forward on 2023-now data.
        # Train on rolling 5y windows ending pre-2023, test 6 months OOS.
        period = _detect_ea_period(ea_id)
        symbols = surviving_symbols or []
        cmd = _runner_base("p4_walk_forward.py")
        cmd.extend([
            "--symbols", ",".join(symbols),
            "--period", period,
            "--train-from-year", "2017",
            "--train-to-year", "2022",
            "--oos-from-year", "2023",
            "--oos-to-year", "2025",
            "--min-folds", "6",
        ])
        if setfile_path:
            cmd.extend(["--setfile", setfile_path])
        walk_forward_csv = PIPELINE_REPORT_ROOT / ea_id / "P4" / "walk_forward.csv"
        if walk_forward_csv.exists():
            cmd.extend(["--walk-forward-csv", str(walk_forward_csv)])
        return cmd

    if phase == "P5":
        symbols = surviving_symbols or []
        symbol = symbols[0] if symbols else ""
        inputs = _phase_runner_inputs(DEFAULT_ROOT, ea_id, phase)
        if inputs.get("missing"):
            return None
        cmd = _runner_base("p5_stress_driver.py")
        if symbol:
            cmd.extend(["--symbol", symbol])
        cmd.extend(["--year", "2024", "--period", _detect_ea_period(ea_id), "--calibration-json", str(inputs["calibration_json"])])
        if setfile_path:
            cmd.extend(["--base-setfile", setfile_path])
        return cmd

    if phase == "P5b":
        symbols = surviving_symbols or []
        symbol = symbols[0] if symbols else ""
        inputs = _phase_runner_inputs(DEFAULT_ROOT, ea_id, phase)
        if inputs.get("missing"):
            return None
        cmd = _runner_base("p5b_noise_driver.py")
        if symbol:
            cmd.extend(["--symbol", symbol])
        cmd.extend(["--calibration-json", str(inputs["calibration_json"]), "--period", _detect_ea_period(ea_id)])
        if setfile_path:
            cmd.extend(["--base-setfile", setfile_path])
        return cmd

    if phase == "P5c":
        symbols = surviving_symbols or []
        symbol = symbols[0] if symbols else ""
        inputs = _phase_runner_inputs(DEFAULT_ROOT, ea_id, phase)
        if inputs.get("missing"):
            return None
        cmd = _runner_base("p5c_crisis_slices.py")
        cmd.extend(["--slices-csv", str(inputs["slices_csv"]), "--period", _detect_ea_period(ea_id)])
        if symbol:
            cmd.extend(["--symbol", symbol])
        if setfile_path:
            cmd.extend(["--base-setfile", setfile_path])
        return cmd

    if phase == "P6":
        symbols = surviving_symbols or []
        symbol = symbols[0] if symbols else ""
        cmd = _runner_base("p6_multiseed_driver.py")
        if symbol:
            cmd.extend(["--symbol", symbol])
        cmd.extend(["--year", "2024", "--period", _detect_ea_period(ea_id), "--seeds", "42,17,99,7,2026"])
        if setfile_path:
            cmd.extend(["--base-setfile", setfile_path])
        return cmd

    if phase == "P7":
        inputs = _phase_runner_inputs(DEFAULT_ROOT, ea_id, phase)
        if inputs.get("missing"):
            return None
        cmd = _runner_base("p7_statval.py")
        cmd.extend(["--sweep-pass-rows", str(inputs["sweep_pass_rows"]), "--multiseed-rows", str(inputs["multiseed_rows"])])
        return cmd

    if phase == "P8":
        symbols = surviving_symbols or []
        symbol = symbols[0] if symbols else ""
        inputs = _phase_runner_inputs(DEFAULT_ROOT, ea_id, phase)
        if inputs.get("missing"):
            return None
        cmd = _runner_base("p8_news_driver.py")
        cmd.extend(["--calendar-csv", str(_news_calendar_csv()), "--mode", "all"])
        if symbol:
            cmd.extend(["--symbol", symbol])
        cmd.extend(["--period", _detect_ea_period(ea_id), "--from-date", "2023.01.01", "--to-date", "2025.12.31"])
        news_matrix = PIPELINE_REPORT_ROOT / ea_id / "P7" / "news_matrix.csv"
        if not news_matrix.exists() and NEWS_MATRIX_FALLBACK.exists():
            news_matrix = NEWS_MATRIX_FALLBACK
        if news_matrix.exists():
            cmd.extend(["--news-matrix", str(news_matrix)])
        if setfile_path:
            cmd.extend(["--base-setfile", setfile_path, "--terminal", "T1", "--run-mt5"])
        return cmd

    return None


def _payload_assigned_terminal(payload: dict[str, Any]) -> str | None:
    terminal = payload.get("assigned_terminal") or payload.get("terminal")
    if terminal == "ALL":
        return "ALL"
    if is_factory_terminal_name(terminal):
        return str(terminal).upper()
    cmd = payload.get("cmd")
    if isinstance(cmd, list):
        for index, part in enumerate(cmd[:-1]):
            if str(part).lower() == "--terminal" and is_factory_terminal_name(cmd[index + 1]):
                return str(cmd[index + 1]).upper()
    return None


def dispatch_tick(root: Path, timeout_hours: float = 6.0) -> dict[str, Any]:
    """Hybrid saturated dispatch (Achse B v2, OWNER 2026-05-16).

    Single-EA case (1 pending task, idle fleet) → run that EA on ALL installed factory terminals
    via p2_baseline.py without --terminal arg (legacy mode, p2_baseline
    distributes symbols across installed factory terminals in its own ThreadPoolExecutor). This
    saturates the fleet WITHIN one EA.

    Multi-EA case (≥2 pending tasks, or some terminals already busy) → assign
    one EA per free terminal up to 5 concurrent. Each EA runs its symbols
    sequentially on its assigned terminal (p2_baseline --terminal Tn). This
    saturates the fleet ACROSS EAs.

    Two complementary modes cover the throughput spectrum:
    - Pipeline starting up / single-EA-in-flight → ALL mode (5x faster per EA)
    - Pipeline saturated / many EAs queued → per-terminal mode (5x EAs in parallel)

    Order of operations:
    1. Poll every active backtest task. If its report.csv exists, classify
       and mark done. If older than timeout_hours with no report, mark failed.
       For ALL-mode tasks, mark all 5 terminals busy while running.
    2. Decide mode:
       - If exactly 1 pending task AND 0 busy terminals → spawn in ALL mode
       - Else → assign one task per free terminal
       Spawn the phase runner accordingly, record assignment in task payload.

    HR16-saturate: at the EA level, multiple EAs can be in P2 concurrently
    via per-terminal mode. HR16-strict still holds at the source-research
    level (one active source for mining).
    """
    init_db(root)
    actions: list[dict[str, Any]] = []
    started_iso = utc_now()
    running_mt5_terminals = _running_mt5_terminals()
    factory_terminals = active_mt5_terminals()
    busy_terminals: set[str] = set(running_mt5_terminals)

    with connect(root) as conn:
        # Phase 1 — poll all active backtest tasks. Tasks that have
        # work_items are owned by dispatch_work_items; this legacy path
        # only handles bundled tasks without per-symbol fan-out.
        active_rows = conn.execute(
            "SELECT t.* FROM tasks t "
            "WHERE t.kind LIKE 'backtest_%' AND t.status = 'active' "
            "AND NOT EXISTS (SELECT 1 FROM work_items wi WHERE wi.parent_task_id = t.id) "
            "ORDER BY t.created_at"
        ).fetchall()

        for row in active_rows:
            payload = json.loads(row["payload_json"])
            phase = payload.get("phase", "?")
            ea_id = payload.get("ea_id")
            assigned_terminal = _payload_assigned_terminal(payload)

            report = _resolve_report(payload)
            if report is not None and report.exists():
                # report.csv exists, but the runners (p2_baseline / p3_param_sweep
                # / etc.) append rows live during the run — classifying as soon
                # as the file appears means we see only the first row.
                # QM5_1049 16:20: STRATEGY_FAIL locked in after only NDX FAIL
                # had been written; WS30/UK100/GDAXI (all PASS) arrived later.
                # Gate classification on the sentinel JSON
                # `<phase_lower>_<ea>_result.json` that each runner writes
                # ONLY after all rows finish.
                phase_lower = phase.lower().replace(".", "")  # P3.5 → p35
                sentinel = report.parent / f"{phase_lower}_{ea_id}_result.json"
                if not sentinel.exists():
                    # Still running — fall through to age/timeout check below.
                    pass
                else:
                    classification = classify_backtest(phase, report)
                    verdict = classification.get("verdict")
                    attempt = int(payload.get("attempt_count", 0)) + 1
                    MAX_BACKTEST_RETRIES = 3
                    # INFRA_FAIL = setup/data problem (not strategy fail);
                    # safe + valuable to retry. STRATEGY_FAIL/PASS are
                    # terminal verdicts — keep done.
                    if verdict == "INFRA_FAIL" and attempt < MAX_BACKTEST_RETRIES:
                        update_task(
                            conn,
                            row["id"],
                            status="pending",
                            payload_merge={
                                "attempt_count": attempt,
                                "last_infra_fail_at": started_iso,
                                "last_infra_fail_classification": classification,
                                "pid": None,
                                "started_at_iso": None,
                                "assigned_terminal": None,
                                "dispatch_mode": None,
                                "log_path": None,
                            },
                        )
                        actions.append({
                            "task_id": row["id"],
                            "action": "retry_infra_fail",
                            "phase": phase,
                            "ea_id": ea_id,
                            "attempt_count": attempt,
                        })
                        continue
                    update_task(
                        conn,
                        row["id"],
                        status="done",
                        payload_merge={
                            "classification": classification,
                            "completed_at_iso": started_iso,
                            "expected_report_path": str(report),
                            "p2_sentinel_path": str(sentinel),
                            "attempt_count": attempt,
                        },
                    )
                    auto_enqueued = None
                    # Auto-advance: PASS → enqueue next phase as a NEW pending
                    # task. Only when next phase is supported AND no successor
                    # already exists for the same EA. Saves the wait for the
                    # next hourly wake + manual enqueue.
                    if verdict == "PASS":
                        next_phase_map = {"P2": "P3", "P3": "P3.5", "P3.5": "P4"}  # extend as adapters come online
                        next_phase = next_phase_map.get(phase)
                        if next_phase and next_phase in SUPPORTED_BACKTEST_PHASES:
                            next_phase_kind = next_phase.lower().replace(".", "")  # P3.5 → 'p35'
                            existing_next = conn.execute(
                                "SELECT id FROM tasks WHERE kind = ? AND payload_json LIKE ?",
                                (f"backtest_{next_phase_kind}", f"%\"ea_id\": \"{ea_id}\"%"),
                            ).fetchone()
                            if not existing_next:
                                # Need to commit current update first so enqueue sees it
                                conn.commit()
                                enq_result = enqueue_backtest(root, row["id"], next_phase)
                                if enq_result.get("enqueued"):
                                    auto_enqueued = {
                                        "next_phase": next_phase,
                                        "next_task_id": enq_result.get("task_id"),
                                    }
                    actions.append({
                        "task_id": row["id"],
                        "action": "classified",
                        "phase": phase,
                        "ea_id": ea_id,
                        "terminal_released": assigned_terminal,
                        "verdict": verdict,
                        "surviving_symbols": classification.get("surviving_symbols", []),
                        "auto_enqueued_next": auto_enqueued,
                    })
                    continue

            start_iso = payload.get("started_at_iso")
            age_hours = 0.0
            if start_iso:
                try:
                    start_dt = dt.datetime.fromisoformat(start_iso.replace("Z", "+00:00"))
                    age_hours = (dt.datetime.now(dt.UTC) - start_dt).total_seconds() / 3600.0
                except Exception:
                    age_hours = 0.0
            if age_hours > timeout_hours:
                # OWNER 2026-05-16 "Wenn etwas scheitert, solls hinten
                # angereiht werden an die Liste." Auto-retry: increment
                # attempt_count, re-queue to pending (= back of FIFO by
                # updated_at). Cap retries at MAX_BACKTEST_RETRIES so we
                # don't loop forever on a genuinely broken job.
                attempt = int(payload.get("attempt_count", 0)) + 1
                MAX_BACKTEST_RETRIES = 3
                if attempt < MAX_BACKTEST_RETRIES:
                    update_task(
                        conn,
                        row["id"],
                        status="pending",
                        payload_merge={
                            "attempt_count": attempt,
                            "last_timeout_at": started_iso,
                            "last_timeout_reason": f"no report after {age_hours:.2f}h",
                            # Clear dispatch metadata so re-dispatch is clean
                            "pid": None,
                            "started_at_iso": None,
                            "assigned_terminal": None,
                            "dispatch_mode": None,
                            "log_path": None,
                        },
                    )
                    actions.append({
                        "task_id": row["id"],
                        "action": "retry",
                        "phase": phase,
                        "ea_id": ea_id,
                        "attempt_count": attempt,
                        "age_hours": round(age_hours, 2),
                    })
                else:
                    update_task(
                        conn,
                        row["id"],
                        status="failed",
                        payload_merge={
                            "timeout_reason": f"no report after {age_hours:.2f}h (limit {timeout_hours}h)",
                            "completed_at_iso": started_iso,
                            "attempt_count": attempt,
                            "final_failure": "retries_exhausted",
                        },
                    )
                    actions.append({
                        "task_id": row["id"],
                        "action": "failed_final",
                        "phase": phase,
                        "ea_id": ea_id,
                        "attempts": attempt,
                    })
                continue

            # Still running — terminal stays busy
            # ALL mode: this task occupies the whole fleet
            if assigned_terminal == "ALL":
                busy_terminals.update(factory_terminals)
            elif assigned_terminal:
                busy_terminals.add(assigned_terminal)
            actions.append({
                "task_id": row["id"],
                "action": "still_running",
                "phase": phase,
                "ea_id": ea_id,
                "terminal": assigned_terminal,
                "pid": payload.get("pid"),
                "age_hours": round(age_hours, 2),
            })

        # Phase 2 — pick dispatch mode based on pending count + fleet state.
        # Same back-compat filter: skip tasks that have work_items (those
        # belong to dispatch_work_items).
        free_terminals = [t for t in factory_terminals if t not in busy_terminals]
        pending_rows = conn.execute(
            "SELECT t.* FROM tasks t "
            "WHERE t.kind LIKE 'backtest_%' AND t.status = 'pending' "
            "AND NOT EXISTS (SELECT 1 FROM work_items wi WHERE wi.parent_task_id = t.id) "
            "ORDER BY t.created_at"
        ).fetchall()

        # Hybrid: single-EA-in-flight + idle fleet → ALL mode (full saturation
        # within one EA, p2_baseline distributes its symbols across installed factory terminals).
        # Else: per-terminal mode (multi-EA saturates across EAs).
        use_all_mode = (
            len(pending_rows) == 1
            and len(busy_terminals) == 0
            and len(free_terminals) == len(factory_terminals)
            and len(factory_terminals) > 0
        )
        dispatch_mode = "single_ea_all_terminals" if use_all_mode else "per_terminal"

        if use_all_mode:
            pending_row = pending_rows[0]
            payload = json.loads(pending_row["payload_json"])
            phase = payload.get("phase")
            ea_id = payload.get("ea_id")
            surviving_symbols = payload.get("surviving_symbols")
            cmd = _phase_runner_cmd(phase, ea_id, terminal=None, surviving_symbols=surviving_symbols)  # no --terminal = all installed factory terminals
            if cmd is None:
                update_task(
                    conn,
                    pending_row["id"],
                    status="failed",
                    payload_merge={"failure_reason": f"no runner for phase {phase}"},
                )
                actions.append({
                    "task_id": pending_row["id"],
                    "action": "no_runner",
                    "phase": phase,
                    "ea_id": ea_id,
                })
            else:
                log_path = root / "logs" / f"dispatch_{pending_row['id']}.log"
                log_path.parent.mkdir(parents=True, exist_ok=True)
                creationflags = 0
                if sys.platform == "win32":
                    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS  # type: ignore[attr-defined]
                log_fh = open(log_path, "w", encoding="utf-8")
                env = {**os.environ, "PYTHONPATH": str(REPO_ROOT)}
                proc = subprocess.Popen(
                    cmd,
                    cwd=str(REPO_ROOT),
                    stdout=log_fh,
                    stderr=subprocess.STDOUT,
                    creationflags=creationflags,
                    close_fds=True,
                    env=env,
                )
                update_task(
                    conn,
                    pending_row["id"],
                    status="active",
                    payload_merge={
                        "started_at_iso": started_iso,
                        "pid": proc.pid,
                        "log_path": str(log_path),
                        "cmd": cmd,
                        "assigned_terminal": "ALL",
                        "dispatch_mode": "single_ea_all_terminals",
                    },
                )
                busy_terminals.update(factory_terminals)
                actions.append({
                    "task_id": pending_row["id"],
                    "action": "started",
                    "phase": phase,
                    "ea_id": ea_id,
                    "terminal": "ALL",
                    "mode": "single_ea_all_terminals",
                    "pid": proc.pid,
                    "log_path": str(log_path),
                })
        else:
            # Per-terminal mode: 1 EA per free terminal
            for terminal in free_terminals:
                if not pending_rows:
                    break
                pending_row = pending_rows.pop(0)
                payload = json.loads(pending_row["payload_json"])
                phase = payload.get("phase")
                ea_id = payload.get("ea_id")
                surviving_symbols = payload.get("surviving_symbols")
                cmd = _phase_runner_cmd(phase, ea_id, terminal=terminal, surviving_symbols=surviving_symbols)
                if cmd is None:
                    update_task(
                        conn,
                        pending_row["id"],
                        status="failed",
                        payload_merge={"failure_reason": f"no runner for phase {phase}"},
                    )
                    actions.append({
                        "task_id": pending_row["id"],
                        "action": "no_runner",
                        "phase": phase,
                        "ea_id": ea_id,
                    })
                    continue

                log_path = root / "logs" / f"dispatch_{pending_row['id']}.log"
                log_path.parent.mkdir(parents=True, exist_ok=True)
                creationflags = 0
                if sys.platform == "win32":
                    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS  # type: ignore[attr-defined]
                log_fh = open(log_path, "w", encoding="utf-8")
                env = {**os.environ, "PYTHONPATH": str(REPO_ROOT)}
                proc = subprocess.Popen(
                    cmd,
                    cwd=str(REPO_ROOT),
                    stdout=log_fh,
                    stderr=subprocess.STDOUT,
                    creationflags=creationflags,
                    close_fds=True,
                    env=env,
                )
                update_task(
                    conn,
                    pending_row["id"],
                    status="active",
                    payload_merge={
                        "started_at_iso": started_iso,
                        "pid": proc.pid,
                        "log_path": str(log_path),
                        "cmd": cmd,
                        "assigned_terminal": terminal,
                        "dispatch_mode": "per_terminal",
                    },
                )
                busy_terminals.add(terminal)
                actions.append({
                    "task_id": pending_row["id"],
                    "action": "started",
                    "phase": phase,
                    "ea_id": ea_id,
                    "terminal": terminal,
                    "mode": "per_terminal",
                    "pid": proc.pid,
                    "log_path": str(log_path),
                })

    return {
        "scanned_at": started_iso,
        "actions": actions,
        "busy_terminals": sorted(busy_terminals),
        "free_terminals": sorted([t for t in factory_terminals if t not in busy_terminals]),
        "running_mt5_terminals": sorted(running_mt5_terminals),
        "mode": dispatch_mode if pending_rows or actions else "idle",
    }


def render_codex_build_prompt(root: Path, card_path_str: str, out_path: str | None) -> dict[str, Any]:
    """Validate an APPROVED card, create a build_ea task, render the Codex prompt."""
    init_db(root)
    card_path = Path(card_path_str).resolve()
    if not card_path.exists():
        return {"written": False, "reason": f"Card path does not exist: {card_path}"}
    fm = parse_card_frontmatter(card_path)
    ea_id = fm.get("ea_id")
    slug = fm.get("slug")
    if not ea_id or not slug:
        return {"written": False, "reason": "Card missing ea_id or slug in frontmatter", "frontmatter": fm}
    preflight = prebuild_validate_card(root, card_path, fm)
    if not preflight["ok"]:
        return {
            "written": False,
            "reason": "prebuild validation failed",
            "frontmatter": fm,
            "prebuild_errors": preflight["errors"],
            "prebuild_warnings": preflight["warnings"],
        }

    ea_dir = FRAMEWORK_EAS_DIR / f"{ea_id}_{slug}"

    with connect(root) as conn:
        task_id = create_task(
            conn,
            kind="build_ea",
            source_id=None,
            card_id=ea_id,
            payload={
                "card_path": str(card_path),
                "ea_id": ea_id,
                "slug": slug,
                "ea_dir": str(ea_dir),
                "frontmatter": fm,
                "prebuild_warnings": preflight["warnings"],
            },
        )

    build_result_path = root / "artifacts" / "builds" / f"{task_id}.json"
    build_result_path.parent.mkdir(parents=True, exist_ok=True)

    template = CODEX_BUILD_TEMPLATE.read_text(encoding="utf-8")
    values = {
        "task_id": task_id,
        "ea_id": ea_id,
        "slug": slug,
        "card_path": str(card_path),
        "source_id": "",
        "ea_dir": str(ea_dir),
        "build_result_path": str(build_result_path),
    }
    prompt = template
    for k, v in values.items():
        prompt = prompt.replace("{{" + k + "}}", str(v))

    target = Path(out_path) if out_path else root / "queue" / f"codex_build_{task_id}.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(prompt, encoding="utf-8", newline="\n")

    return {
        "written": True,
        "task_id": task_id,
        "ea_id": ea_id,
        "ea_dir": str(ea_dir),
        "prompt_path": str(target),
        "build_result_path": str(build_result_path),
        "suggested_command": (
            # ChatGPT-account Codex (v0.130+): default gpt-5.5 works.
            # gpt-5-codex / gpt-5-codex-mini / gpt-5 are 400 on ChatGPT auth.
            # -s danger-full-access required: workspace-write blocks pwsh subprocess
            # commands by codex policy, even though it permits file writes. Codex
            # needs to invoke pwsh for build_check / compile_one / gen_setfile /
            # run_smoke. Constrained externally by the build prompt + build_check.ps1.
            # [windows] sandbox = "elevated" was removed from ~/.codex/config.toml
            # 2026-05-16 (lockout incident) — Codex now uses cross-platform sandbox.
            # Prompt MUST be piped via stdin, NOT passed as a CLI arg: passing as
            # arg makes codex print "Reading additional input from stdin..." and
            # hang waiting for stdin EOF that the inherited claude pipe never
            # delivers (observed 2026-05-16: 18 min hang, codex CPU=0s).
            # Output is tee'd to a per-build live log so OWNER can Get-Content -Wait
            # without depending on the buffered wake session log.
            f"cat '{target}' | codex exec -s danger-full-access --cd \"{REPO_ROOT}\" 2>&1 "
            f"| tee 'D:/QM/strategy_farm/logs/codex_build_{task_id}.live.log'"
        ),
    }


def update_card_frontmatter(card_path: Path, updates: dict[str, str]) -> None:
    """Patch flat key:value pairs in a card's YAML frontmatter, in-place.

    Replaces existing keys; appends new ones at the end of the frontmatter block.
    Preserves the rest of the file verbatim.
    """
    text = card_path.read_text(encoding="utf-8")
    m = re.match(r"^(---\s*\n)(.*?)(\n---)", text, re.DOTALL)
    if not m:
        raise ValueError(f"No YAML frontmatter found in {card_path}")
    fm_block = m.group(2)
    lines = fm_block.split("\n")
    handled: set[str] = set()
    for i, line in enumerate(lines):
        for key, value in updates.items():
            if key in handled:
                continue
            if re.match(rf"^{re.escape(key)}\s*:", line):
                lines[i] = f"{key}: {value}"
                handled.add(key)
    for key, value in updates.items():
        if key not in handled:
            lines.append(f"{key}: {value}")
    new_fm = "\n".join(lines)
    new_text = m.group(1) + new_fm + m.group(3) + text[m.end():]
    card_path.write_text(new_text, encoding="utf-8", newline="\n")


VALID_SOURCE_TYPES = (
    "book", "paper", "web_forum", "web_blog",
    "mql5_codebase", "mql5_articles", "video", "local_archive",
)
VALID_LANES = ("research", "recovery", "legacy", "discovery")


def add_source(
    root: Path,
    uri: str,
    title: str,
    source_type: str,
    lane: str = "research",
    priority: int = 70,
) -> dict[str, Any]:
    """Add a new source to the queue (e.g. discovered by autonomous source-scan)."""
    init_db(root)
    if source_type not in VALID_SOURCE_TYPES:
        return {
            "added": False,
            "reason": f"source_type must be one of {VALID_SOURCE_TYPES}",
        }
    if lane not in VALID_LANES:
        return {"added": False, "reason": f"lane must be one of {VALID_LANES}"}
    if not uri or not title:
        return {"added": False, "reason": "uri and title are required"}

    sid = source_id({"source_type": source_type, "uri": uri})
    now = utc_now()
    with connect(root) as conn:
        existing = conn.execute("SELECT id, status FROM sources WHERE id = ?", (sid,)).fetchone()
        if existing is not None:
            return {
                "added": False,
                "reason": "Source with same (source_type, uri) already exists",
                "existing_id": existing["id"],
                "existing_status": existing["status"],
            }
        try:
            conn.execute(
                """
                INSERT INTO sources(
                    id, priority, lane, source_type, uri, title, status,
                    notes_path, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, 'pending', NULL, ?, ?)
                """,
                (sid, priority, lane, source_type, uri, title, now, now),
            )
            event(conn, "source", sid, "added", {
                "priority": priority,
                "lane": lane,
                "source_type": source_type,
                "uri": uri,
                "title": title,
            })
        except sqlite3.IntegrityError as exc:
            return {"added": False, "reason": f"IntegrityError: {exc}"}

    write_sources_jsonl(root)
    return {
        "added": True,
        "source_id": sid,
        "priority": priority,
        "lane": lane,
        "source_type": source_type,
        "uri": uri,
        "title": title,
        "next_action_hint": "python tools/strategy_farm/farmctl.py status",
    }


def approve_card(root: Path, card_path_str: str, reasoning: str) -> dict[str, Any]:
    """Set g0_status: APPROVED in the card frontmatter, move draft → approved."""
    init_db(root)
    card_path = Path(card_path_str).resolve()
    if not card_path.exists():
        return {"approved": False, "reason": f"Card not found: {card_path}"}
    if not reasoning:
        return {"approved": False, "reason": "reasoning is required"}

    fm = parse_card_frontmatter(card_path)
    ea_id = fm.get("ea_id")
    if not ea_id:
        return {"approved": False, "reason": "Card frontmatter missing ea_id"}

    coverage = _verify_card_body_coverage(card_path)
    if not coverage["ok"]:
        _update_flat_frontmatter_file(card_path, {
            "r1_track_record": "UNKNOWN",
            "r2_mechanical": "UNKNOWN",
            "r3_data_available": "UNKNOWN",
            "r4_ml_forbidden": "UNKNOWN",
            "card_body_incomplete": "true",
            "card_body_missing": '"' + ",".join(coverage["missing"]) + '"',
        })
        return {
            "approved": False,
            "reason": "card_body_incomplete",
            "missing": coverage["missing"],
            "card_path": str(card_path),
        }
    expected_trades = _infer_expected_trades_per_year_per_symbol(card_path.read_text(encoding="utf-8", errors="ignore"))
    if expected_trades is None or expected_trades < 2:
        _update_flat_frontmatter_file(card_path, {
            "r2_mechanical": "UNKNOWN",
            "card_body_incomplete": "true",
            "card_body_missing": '"expected_trade_frequency"',
        })
        return {
            "approved": False,
            "reason": "expected_trade_frequency_too_low_or_unknown",
            "expected_trades_per_year_per_symbol": expected_trades,
            "card_path": str(card_path),
        }

    today = dt.datetime.now(dt.UTC).strftime("%Y-%m-%d")
    quoted = '"' + reasoning.replace('"', "'").replace("\n", " ").strip()[:300] + '"'
    updates = {
        "g0_status": "APPROVED",
        "g0_approval_reasoning": quoted,
        "last_updated": today,
    }
    updates["expected_trades_per_year_per_symbol"] = str(expected_trades)
    update_card_frontmatter(card_path, updates)

    target_dir = root / "artifacts" / "cards_approved"
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / card_path.name
    if target.exists():
        return {
            "approved": False,
            "reason": f"Approved card already at {target} — manual reconciliation needed",
        }

    # Move only if the source is in cards_draft/. Otherwise leave in place (already-approved card).
    src_in_draft = "cards_draft" in card_path.parts
    if src_in_draft:
        import shutil
        shutil.move(str(card_path), str(target))
        final_path = target
    else:
        final_path = card_path

    with connect(root) as conn:
        event(conn, "card", ea_id, "approved", {
            "card_path": str(final_path),
            "reasoning": reasoning[:300],
        })

    return {
        "approved": True,
        "ea_id": ea_id,
        "card_path": str(final_path),
        "reasoning": reasoning,
        "next_action_hint": f"python tools/strategy_farm/farmctl.py build-ea --card \"{final_path}\"",
    }


def _find_cards_by_source_id(root: Path, target_source_id: str) -> dict[str, list[Path]]:
    """Find all cards across draft/approved/rejected dirs whose frontmatter source_id matches."""
    result: dict[str, list[Path]] = {"draft": [], "approved": [], "rejected": []}
    for state, subdir in [
        ("draft", "cards_draft"),
        ("approved", "cards_approved"),
        ("rejected", "cards_rejected"),
    ]:
        d = root / "artifacts" / subdir
        if not d.exists():
            continue
        for card_path in d.glob("*.md"):
            try:
                fm = parse_card_frontmatter(card_path)
            except Exception:
                continue
            if fm.get("source_id") == target_source_id:
                result[state].append(card_path)
    return result


def _card_pipeline_state(conn: sqlite3.Connection, card_path: Path, state: str) -> str:
    """Return 'done' (reached pipeline-end) or 'in_flight'.

    Rules (v1 — until P3+ classifiers wired):
    - card in cards_rejected/ → 'done' (REJECTED at G0)
    - card in cards_draft/ → 'in_flight' (awaiting G0 verdict)
    - card in cards_approved/:
        - no build_ea task → 'in_flight' (awaiting Codex)
        - build_ea status='failed' or 'blocked' → 'done' (DEAD before backtest)
        - build_ea status='done' but no ea_review → 'in_flight'
        - ea_review status='done' with REJECT_REWORK → 'in_flight' (rework pending)
        - ea_review status='done' with APPROVE_FOR_BACKTEST + no backtest_p2 task → 'in_flight'
        - backtest_p2 status='pending' or 'active' → 'in_flight'
        - backtest_p2 status='done' or 'failed' → 'done' (terminal at P2 in v1)
    """
    if state == "rejected":
        return "done"
    if state == "draft":
        return "in_flight"
    fm = parse_card_frontmatter(card_path)
    ea_id = fm.get("ea_id")
    if not ea_id:
        return "in_flight"

    rows = conn.execute(
        "SELECT kind, status, payload_json FROM tasks WHERE card_id = ? ORDER BY created_at ASC",
        (ea_id,),
    ).fetchall()
    if not rows:
        return "in_flight"  # approved but no build task yet

    build_task = next((r for r in rows if r["kind"] == "build_ea"), None)
    review_task = next((r for r in rows if r["kind"] == "ea_review"), None)
    backtest_task = next((r for r in rows if r["kind"].startswith("backtest_")), None)

    if build_task is None:
        return "in_flight"
    if build_task["status"] in ("failed", "blocked"):
        return "done"
    if build_task["status"] != "done":
        return "in_flight"
    # build_ea done — need review
    if review_task is None:
        return "in_flight"
    if review_task["status"] != "done":
        return "in_flight"
    # review done — read verdict
    review_payload = json.loads(review_task["payload_json"] or "{}")
    verdict_doc = review_payload.get("verdict") or {}
    if verdict_doc.get("verdict") != "APPROVE_FOR_BACKTEST":
        # REJECT_REWORK or unknown — Codex rework pending
        return "in_flight"
    # APPROVE — need backtest
    if backtest_task is None:
        return "in_flight"
    if backtest_task["status"] in ("done", "failed", "blocked"):
        return "done"
    return "in_flight"


def resume_mining(root: Path) -> dict[str, Any]:
    """Walk all sources with status='cards_ready'; flip back to 'active' for any whose
    drafted card batch has fully reached pipeline-end. Returns summary of actions taken."""
    init_db(root)
    scan_at = utc_now()
    results: list[dict[str, Any]] = []
    with connect(root) as conn:
        paused = conn.execute(
            "SELECT id, title, priority FROM sources "
            "WHERE status = 'cards_ready' ORDER BY priority"
        ).fetchall()
        for src in paused:
            cards = _find_cards_by_source_id(root, src["id"])
            states: list[str] = []
            for state, paths in cards.items():
                for p in paths:
                    states.append(_card_pipeline_state(conn, p, state))
            total = len(states)
            done = sum(1 for s in states if s == "done")
            in_flight = total - done

            if total == 0:
                results.append({
                    "source_id": src["id"],
                    "title": src["title"],
                    "action": "skipped_no_cards",
                    "reason": "no cards with this source_id — possible missing frontmatter field",
                })
                continue

            if in_flight == 0:
                conn.execute(
                    "UPDATE sources SET status = 'active', updated_at = ? WHERE id = ?",
                    (scan_at, src["id"]),
                )
                event(conn, "source", src["id"], "resumed", {
                    "previous_status": "cards_ready",
                    "cards_in_batch": total,
                    "reason": "all batch cards reached pipeline-end",
                })
                results.append({
                    "source_id": src["id"],
                    "title": src["title"],
                    "action": "resumed",
                    "cards_in_batch": total,
                })
            else:
                results.append({
                    "source_id": src["id"],
                    "title": src["title"],
                    "action": "still_waiting",
                    "cards_in_batch": total,
                    "done": done,
                    "in_flight": in_flight,
                })

    return {
        "scanned_at": scan_at,
        "checked_sources": len(results),
        "resumed_count": sum(1 for r in results if r["action"] == "resumed"),
        "results": results,
    }


def reject_card(root: Path, card_path_str: str, reason: str) -> dict[str, Any]:
    """Set g0_status: REJECTED in the card frontmatter, move draft → rejected."""
    init_db(root)
    card_path = Path(card_path_str).resolve()
    if not card_path.exists():
        return {"rejected": False, "reason": f"Card not found: {card_path}"}
    if not reason:
        return {"rejected": False, "reason": "reason is required"}

    fm = parse_card_frontmatter(card_path)
    ea_id = fm.get("ea_id", "UNKNOWN")

    today = dt.datetime.now(dt.UTC).strftime("%Y-%m-%d")
    quoted = '"' + reason.replace('"', "'").replace("\n", " ").strip()[:300] + '"'
    update_card_frontmatter(card_path, {
        "g0_status": "REJECTED",
        "g0_rejection_reason": quoted,
        "last_updated": today,
    })

    target_dir = root / "artifacts" / "cards_rejected"
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / card_path.name
    if target.exists():
        return {
            "rejected": False,
            "reason": f"Rejected card already at {target} — manual reconciliation needed",
        }

    if "cards_draft" in card_path.parts:
        import shutil
        shutil.move(str(card_path), str(target))
        final_path = target
    else:
        final_path = card_path

    with connect(root) as conn:
        event(conn, "card", ea_id, "rejected", {
            "card_path": str(final_path),
            "reason": reason[:300],
        })

    return {
        "rejected": True,
        "ea_id": ea_id,
        "card_path": str(final_path),
        "reason": reason,
    }


def _validate_ea_spec_md(build_result: dict[str, Any], root: Path) -> dict[str, Any]:
    """Run framework/scripts/validate_spec_doc.py against the EA's dir.

    PT2 2026-05-23 — gate enforcement of Vault Q01 SPEC.md requirement.
    Returns {"ok": bool, "failures": list[str], "ea_dir": str | None}.
    Non-fatal if the validator script itself is missing (returns ok=True
    with a note) — defensive degradation, won't break older deployments.
    """
    ea_dir_raw = (build_result.get("ea_dir") or "").strip()
    if not ea_dir_raw:
        # Try to derive from ea_id + slug
        ea_id = build_result.get("ea_id")
        slug = build_result.get("slug")
        if ea_id and slug:
            ea_dir_raw = str(FRAMEWORK_EAS_DIR / f"{ea_id}_{slug}")
    if not ea_dir_raw:
        return {"ok": False, "failures": ["ea_dir_unresolvable"], "ea_dir": None}

    ea_dir = Path(ea_dir_raw)
    if not ea_dir.exists() or not ea_dir.is_dir():
        return {"ok": False, "failures": [f"ea_dir_missing:{ea_dir_raw}"], "ea_dir": ea_dir_raw}

    validator = REPO_ROOT / "framework" / "scripts" / "validate_spec_doc.py"
    if not validator.exists():
        return {"ok": True, "failures": [], "ea_dir": ea_dir_raw,
                "note": "validator_script_absent_skipped"}

    import shutil as _shutil
    python_exe = _shutil.which("python") or sys.executable or "python"
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        proc = subprocess.run(
            [python_exe, str(validator), str(ea_dir)],
            capture_output=True, text=True, timeout=30,
            creationflags=creationflags,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "failures": ["validator_timeout"], "ea_dir": ea_dir_raw}
    except Exception as exc:
        return {"ok": False, "failures": [f"validator_error:{exc!r}"], "ea_dir": ea_dir_raw}

    if proc.returncode == 0:
        return {"ok": True, "failures": [], "ea_dir": ea_dir_raw}

    # Validator emits one "FAIL  <ea_name>" line + "      - <failure>" lines.
    failures: list[str] = []
    for line in (proc.stdout or "").splitlines():
        s = line.strip()
        if s.startswith("- "):
            failures.append(s[2:])
    if not failures:
        # Validator failed but didn't list reasons (parse fallback)
        failures = [(proc.stdout or proc.stderr or "validator_failed").strip()[:200]]
    return {"ok": False, "failures": failures, "ea_dir": ea_dir_raw,
            "exit_code": proc.returncode}


def record_build_result(root: Path, task_id: str, result_file: str) -> dict[str, Any]:
    """Read Codex's build result JSON, transition the build_ea task."""
    init_db(root)
    rp = Path(result_file).resolve()
    if not rp.exists():
        return {"recorded": False, "reason": f"Result file not found: {rp}"}
    try:
        result = json.loads(rp.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {"recorded": False, "reason": f"Invalid JSON in {rp}: {exc}"}

    blocked = result.get("blocked_reason")
    smoke = result.get("smoke_result")
    smoke_framework_error_after_good_build = (
        result.get("build_check_passed") is True
        and result.get("compile_succeeded") is True
        and str(smoke or "").lower() == "framework_error"
    )
    smoke_deferred_after_good_build = (
        result.get("build_check_passed") is True
        and result.get("compile_succeeded") is True
        and str(smoke or "").lower() == "deferred_p2_smoke"
    )
    if smoke_framework_error_after_good_build:
        result["build_smoke_framework_error"] = blocked
        result["blocked_reason"] = ""
        result["smoke_result"] = "deferred_p2_smoke"
        result["smoke_skipped_reason"] = "framework_error_during_build_smoke_treated_as_done"
        try:
            rp.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        except Exception:
            pass
        blocked = ""

    fail_code = _classify_build_fail_code(result)
    payload_merge: dict[str, Any] = {"codex_result": result}
    if fail_code:
        payload_merge["fail_code"] = fail_code
        result.setdefault("fail_code", fail_code)
    if smoke_framework_error_after_good_build:
        new_status = "done"
        payload_merge.update({
            "smoke_skipped_reason": "framework_error_during_build_smoke_treated_as_done",
            "needs_p2_smoke_via_pump": True,
        })
    elif smoke_deferred_after_good_build:
        new_status = "done"
        payload_merge.update({
            "smoke_skipped_reason": result.get("smoke_skipped_reason") or "framework_error_during_build_smoke_treated_as_done",
            "needs_p2_smoke_via_pump": True,
        })
    elif blocked:
        new_status = "blocked"
    elif smoke in ("passed", "zero_trades"):
        # zero_trades per HR7 is a setup question, not a strategy fail — still proceed to review
        new_status = "done"
    else:
        new_status = "failed"

    # PT2 2026-05-23 — Q01 SPEC.md gate enforcement.
    # Per Vault Q01 Build & Spec spec, every new EA must ship with a complete
    # SPEC.md (7 required sections, no unfilled placeholders, EA-ID match).
    # We only enforce this when the build was otherwise about to advance to
    # "done" — failures/blocks already gate the EA out for other reasons.
    if new_status == "done":
        spec_result = _validate_ea_spec_md(result, root)
        payload_merge["spec_validation"] = spec_result
        if not spec_result.get("ok"):
            new_status = "blocked"
            result["blocked_reason"] = "spec_validation_failed"
            payload_merge["fail_code"] = "spec_validation_failed"
            payload_merge.setdefault(
                "spec_blocked_summary",
                "; ".join(spec_result.get("failures", [])[:3]),
            )

    # PT11 2026-05-24 — auto-enqueue Q02 work_items immediately after a clean
    # build. Pre-PT11 every build, even fully-compiled with PASS spec, sat at
    # status=done waiting for a manual `claude-review-prompt` + `ea_review` +
    # `enqueue-backtest` chain. That gap was the dominant cause of the
    # "283 ex5 built / 15 in Q02" funnel collapse — 95% of fresh ex5s never
    # entered the test pipeline. Now: when build is clean (status=done), we
    # read setfiles_generated from the codex result, pair each setfile with
    # its symbol (parsed from filename), and INSERT one Q02 work_item per
    # (symbol, setfile). The factory's worker daemons pick them up on the
    # next dispatch tick. Idempotent — skips if a pending/active Q02 already
    # exists for the same (ea_id, symbol).
    auto_q02 = None
    if new_status == "done":
        auto_q02 = _auto_enqueue_q02_for_build(root, result)
        payload_merge["auto_q02_enqueued"] = auto_q02

    with connect(root) as conn:
        updated = update_task(conn, task_id, status=new_status, payload_merge=payload_merge)
    if updated is None:
        return {"recorded": False, "reason": f"Task not found: {task_id}"}
    return {
        "recorded": True,
        "task_id": task_id,
        "new_status": new_status,
        "smoke_result": smoke,
        "blocked_reason": blocked,
        "fail_code": fail_code,
        "auto_q02_enqueued": auto_q02,
        "next_action_hint": (
            f"Q02 auto-enqueued ({len(auto_q02.get('enqueued', [])) if auto_q02 else 0} work_items); "
            f"worker daemons will dispatch on next tick"
            if new_status == "done" and auto_q02
            else f"python tools/strategy_farm/farmctl.py claude-review-prompt --build-task-id {task_id}"
            if new_status == "done" else f"Build failed/blocked. Inspect {rp} and rework or escalate."
        ),
    }


def _auto_enqueue_q02_for_build(root: Path, build_result: dict[str, Any]) -> dict[str, Any]:
    """Create Q02 work_items for every setfile the Codex build produced.

    Pairs each setfile with its symbol parsed from the filename
    (<ea_label>_<SYMBOL>_<TF>_backtest.set). Skips (ea_id, symbol) pairs
    that already have a pending or active Q02 work_item — idempotent so
    re-running record-build doesn't create duplicates.

    Returns {"enqueued": [{...}], "skipped": [{...}]} for observability.
    """
    ea_id = build_result.get("ea_id")
    setfiles = build_result.get("setfiles_generated") or []
    if not ea_id or not setfiles:
        return {"enqueued": [], "skipped": [],
                "reason": "missing_ea_id_or_setfiles"}

    enqueued: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    now_iso = utc_now()

    with connect(root) as conn:
        for setfile_str in setfiles:
            setfile_path = Path(str(setfile_str))
            # Filename pattern: <ea_label>_<SYMBOL>_<TF>_backtest.set
            # Symbol may contain '.' (e.g. EURUSD.DWX); use regex to extract.
            m = re.search(r"_([A-Z][A-Z0-9.]{2,})_([A-Z0-9]+)_backtest\.set$",
                          setfile_path.name)
            if not m:
                skipped.append({"setfile": str(setfile_path),
                                "reason": "setfile_name_parse_failed"})
                continue
            symbol = m.group(1)
            tf = m.group(2)

            # Idempotency: skip if pending/active Q02 already exists
            existing = conn.execute(
                "SELECT id, status FROM work_items "
                "WHERE ea_id=? AND symbol=? AND phase='Q02' AND status IN ('pending', 'active')",
                (ea_id, symbol),
            ).fetchone()
            if existing:
                skipped.append({"setfile": setfile_path.name, "symbol": symbol,
                                "reason": f"existing_q02_{existing[1]}",
                                "existing_wi_id": existing[0][:8]})
                continue

            wi_id = str(uuid.uuid4())
            payload = {
                "host_symbol": symbol,
                "host_timeframe": tf,
                "enqueued_by": "record_build_result.auto_q02",
                "enqueued_at_utc": now_iso,
                "build_task_id": build_result.get("task_id"),
            }
            conn.execute(
                "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, "
                "status, attempt_count, payload_json, created_at, updated_at) "
                "VALUES (?, 'backtest', 'Q02', ?, ?, ?, 'pending', 0, ?, ?, ?)",
                (wi_id, ea_id, symbol, str(setfile_path),
                 json.dumps(payload), now_iso, now_iso),
            )
            enqueued.append({"wi_id": wi_id[:8], "symbol": symbol, "tf": tf,
                             "setfile": setfile_path.name})
        conn.commit()

    return {"enqueued": enqueued, "skipped": skipped, "ea_id": ea_id}


def _classify_build_fail_code(result: dict[str, Any]) -> str | None:
    """Stable taxonomy for build_ea failures; stored on task payloads."""
    blocked = str(result.get("blocked_reason") or "").strip()
    smoke = str(result.get("smoke_result") or "").strip()
    reason = " ".join(
        str(result.get(k) or "")
        for k in ("reason", "error", "reason_class", "failure_reason", "notes")
    ).lower()

    if blocked:
        blocked_l = blocked.lower()
        if "magic" in blocked_l and "collision" in blocked_l:
            return "magic_collision"
        if "compile" in blocked_l:
            return "compile_error"
        if "smoke" in blocked_l:
            return "smoke_failed"
        if "timeout" in blocked_l:
            return "timeout"
        if "framework" in blocked_l:
            return "framework_error"
        if "codex_review_fail" == blocked_l:
            return "codex_review_fail"
        if "card" in blocked_l and ("not found" in blocked_l or "path" in blocked_l or "missing" in blocked_l):
            return "card_path_missing"
        return re.sub(r"[^a-z0-9_]+", "_", blocked_l).strip("_") or "blocked"

    if result.get("compile_succeeded") is False or result.get("build_check_passed") is False:
        if "magic" in reason and "collision" in reason:
            return "magic_collision"
        if "timeout" in reason:
            return "compile_timeout"
        return "compile_error"

    smoke_l = smoke.lower()
    if smoke_l == "deferred_p2_smoke":
        return None
    if smoke_l in {"passed", "zero_trades"}:
        return None
    if smoke_l:
        if "timeout" in smoke_l or "timeout" in reason:
            return "smoke_timeout"
        if "framework_error" in smoke_l:
            return "framework_error"
        if "min_trades" in smoke_l:
            return "min_trades_not_met"
        if "report" in smoke_l:
            return "smoke_report_missing"
        return re.sub(r"[^a-z0-9_]+", "_", smoke_l).strip("_") or "smoke_failed"

    return None


def render_claude_review_prompt(root: Path, build_task_id: str, out_path: str | None) -> dict[str, Any]:
    """Create an ea_review task and render the Claude review prompt."""
    init_db(root)
    with connect(root) as conn:
        row = conn.execute("SELECT * FROM tasks WHERE id = ?", (build_task_id,)).fetchone()
    if row is None:
        return {"written": False, "reason": f"Build task not found: {build_task_id}"}
    if row["kind"] != "build_ea":
        return {"written": False, "reason": f"Task {build_task_id} kind={row['kind']!r}, expected build_ea"}
    payload = json.loads(row["payload_json"])
    codex_result = payload.get("codex_result")
    if not codex_result:
        return {
            "written": False,
            "reason": "Build task has no codex_result. Call record-build first.",
        }

    with connect(root) as conn:
        review_task_id = create_task(
            conn,
            kind="ea_review",
            source_id=row["source_id"],
            card_id=row["card_id"],
            payload={
                "build_task_id": build_task_id,
                "ea_id": payload.get("ea_id"),
                "card_path": payload.get("card_path"),
                "mq5_path": codex_result.get("mq5_path"),
                "ex5_path": codex_result.get("ex5_path"),
                "smoke_report_path": codex_result.get("smoke_report_path"),
                "build_result_path": str(root / "artifacts" / "builds" / f"{build_task_id}.json"),
            },
        )

    verdict_path = root / "artifacts" / "verdicts" / f"review_{review_task_id}.json"
    verdict_path.parent.mkdir(parents=True, exist_ok=True)

    template = CLAUDE_REVIEW_TEMPLATE.read_text(encoding="utf-8")
    values = {
        "review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "ea_id": payload.get("ea_id") or "",
        "card_path": payload.get("card_path") or "",
        "mq5_path": codex_result.get("mq5_path") or "",
        "ex5_path": codex_result.get("ex5_path") or "",
        "smoke_report_path": codex_result.get("smoke_report_path") or "",
        "build_result_path": str(root / "artifacts" / "builds" / f"{build_task_id}.json"),
        "verdict_path": str(verdict_path),
    }
    prompt = template
    for k, v in values.items():
        prompt = prompt.replace("{{" + k + "}}", str(v))

    target = Path(out_path) if out_path else root / "queue" / f"claude_review_{review_task_id}.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(prompt, encoding="utf-8", newline="\n")

    return {
        "written": True,
        "review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "prompt_path": str(target),
        "verdict_path": str(verdict_path),
        "suggested_command": (
            "claude -p --permission-mode acceptEdits "
            f"--add-dir \"{REPO_ROOT}\" "
            f"--add-dir \"{root}\" "
            "--add-dir \"G:\\My Drive\\QuantMechanica - Company Reference\" "
            f"\"$(Get-Content -Raw '{target}')\""
        ),
    }


def record_review_result(root: Path, review_task_id: str, result_file: str) -> dict[str, Any]:
    """Read Claude's review verdict JSON, mark the ea_review task done."""
    init_db(root)
    rp = Path(result_file).resolve()
    if not rp.exists():
        return {"recorded": False, "reason": f"Verdict file not found: {rp}"}
    try:
        verdict = json.loads(rp.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {"recorded": False, "reason": f"Invalid JSON in {rp}: {exc}"}

    decision = verdict.get("verdict")
    if decision not in ("APPROVE_FOR_BACKTEST", "REJECT_REWORK"):
        return {"recorded": False, "reason": f"Unknown verdict value: {decision!r}"}

    with connect(root) as conn:
        updated = update_task(
            conn,
            review_task_id,
            status="done",
            payload_merge={"verdict": verdict},
        )
    if updated is None:
        return {"recorded": False, "reason": f"Review task not found: {review_task_id}"}

    return {
        "recorded": True,
        "review_task_id": review_task_id,
        "verdict": decision,
        "rework_directives": verdict.get("rework_directives"),
        "findings_count": len(verdict.get("findings", []) or []),
        "next_action_hint": (
            "Ready for backtest dispatch (Phase C: enqueue-backtest)"
            if decision == "APPROVE_FOR_BACKTEST"
            else "Reopen build with rework_directives — re-render Codex prompt"
        ),
    }


def print_json(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))


def _registry_lock_path() -> Path:
    return REPO_ROOT / "framework" / "registry" / ".ea_id_registry.lock"


def _acquire_registry_lock(timeout_seconds: float = 30.0) -> tuple[int, Path] | None:
    lock_path = _registry_lock_path()
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + timeout_seconds
    flags = os.O_CREAT | os.O_EXCL | os.O_WRONLY
    while time.monotonic() < deadline:
        try:
            fd = os.open(str(lock_path), flags)
            os.write(fd, json.dumps({"pid": os.getpid(), "created_at": utc_now()}).encode("utf-8"))
            return fd, lock_path
        except FileExistsError:
            try:
                lock_data = json.loads(lock_path.read_text(encoding="utf-8"))
                lock_pid = lock_data.get("pid")
                age_sec = time.time() - lock_path.stat().st_mtime
                if age_sec > 300 or not _pid_exists(lock_pid):
                    lock_path.unlink()
                    continue
            except (OSError, json.JSONDecodeError):
                try:
                    lock_path.unlink()
                    continue
                except OSError:
                    pass
            time.sleep(0.5)
    return None


def _release_registry_lock(lock: tuple[int, Path] | None) -> None:
    if not lock:
        return
    fd, lock_path = lock
    try:
        os.close(fd)
    except OSError:
        pass
    try:
        lock_path.unlink()
    except OSError:
        pass


def _write_csv_atomic(path: Path, fieldnames: list[str], rows: list[dict[str, Any]]) -> None:
    tmp = path.with_suffix(path.suffix + f".{os.getpid()}.tmp")
    with tmp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in fieldnames})
    tmp.replace(path)


def reserve_ea_ids(
    root: Path,
    slugs: list[str],
    *,
    strategy_id: str,
    owner: str = "Research",
    status: str = "active",
    created_at: str | None = None,
    start_after: int | None = None,
) -> dict[str, Any]:
    """Atomically reserve EA IDs in ea_id_registry.csv.

    This is the only safe path for autonomous Research allocation. It prevents
    the historical race where parallel agents each read "highest ID" and append
    colliding rows.
    """
    del root  # registry is repo-scoped, not runtime-root scoped.
    cleaned_slugs = [str(slug).strip() for slug in slugs if str(slug).strip()]
    if not cleaned_slugs:
        return {"reserved": False, "reason": "no_slugs_provided"}
    bad_slugs = [slug for slug in cleaned_slugs if not re.match(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$", slug)]
    if bad_slugs:
        return {"reserved": False, "reason": "invalid_slug", "slugs": bad_slugs}
    dup_request = sorted({slug for slug in cleaned_slugs if cleaned_slugs.count(slug) > 1})
    if dup_request:
        return {"reserved": False, "reason": "duplicate_slug_in_request", "slugs": dup_request}

    registry = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
    lock = _acquire_registry_lock()
    if lock is None:
        return {"reserved": False, "reason": "registry_lock_timeout", "lock_path": str(_registry_lock_path())}
    try:
        fieldnames, rows = _read_csv_dicts_with_columns(registry)
        if not fieldnames:
            fieldnames = ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"]
        existing_ids = {str(row.get("ea_id") or "").strip() for row in rows}
        existing_slugs = {str(row.get("slug") or "").strip().lower() for row in rows}
        slug_conflicts = [slug for slug in cleaned_slugs if slug.lower() in existing_slugs]
        if slug_conflicts:
            return {"reserved": False, "reason": "duplicate_slug", "slugs": slug_conflicts}

        numeric_ids = [int(ea_id) for ea_id in existing_ids if ea_id.isdigit()]
        next_id = max([start_after or 0, *numeric_ids], default=start_after or 0) + 1
        created = created_at or dt.date.today().isoformat()
        reserved_rows: list[dict[str, Any]] = []
        for slug in cleaned_slugs:
            while str(next_id) in existing_ids:
                next_id += 1
            row = {
                "ea_id": str(next_id),
                "slug": slug,
                "strategy_id": strategy_id,
                "status": status,
                "owner": owner,
                "created_at": created,
            }
            rows.append(row)
            reserved_rows.append(row)
            existing_ids.add(str(next_id))
            existing_slugs.add(slug.lower())
            next_id += 1

        _write_csv_atomic(registry, fieldnames, rows)
        return {
            "reserved": True,
            "registry": str(registry),
            "rows": reserved_rows,
            "count": len(reserved_rows),
        }
    finally:
        _release_registry_lock(lock)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="QuantMechanica Option A strategy farm controller")
    parser.add_argument("--root", default=str(DEFAULT_ROOT), help="Runtime root. Default: %(default)s")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("init", help="Create runtime directories and SQLite schema")

    seed = sub.add_parser("seed-sources", help="Seed the ordered initial source queue")
    seed.add_argument("--force", action="store_true", help="Replace current sources/tasks before seeding")

    sub.add_parser("status", help="Show source/task state")
    sub.add_parser("pipeline", help="Per-EA lifecycle view (where does each EA stand?)")
    sub.add_parser("pump", help="Continuous deterministic worker: dispatch MT5 + auto-spawn Codex + record builds. Run every 5 min.")
    sub.add_parser("health", help="Run 10 pipeline invariants; write state/health.json + alarms log. Cockpit reads health.json for top banner.")
    sub.add_parser("repair", help="Auto-fix detected pipeline anomalies (stranded sources, phantom review fails, ablation grandchildren, stale work_items). Idempotent; safe to run any time.")
    work_items_p = sub.add_parser("work-items", help="Per-(EA × symbol × phase) work_items view")
    work_items_p.add_argument("--status", choices=["pending", "active", "done", "failed"], help="Filter by status")
    work_items_p.add_argument("--ea", help="Filter by ea_id (e.g. QM5_1049)")
    sub.add_parser("backfill-work-items", help="One-shot: populate work_items table from existing backtest tasks + report.csv")
    sub.add_parser("next", help="Show the deterministic next action")
    sub.add_parser("claim-source", help="Activate the next pending source if no source is active")

    reserve_ids = sub.add_parser("reserve-ea-ids", help="Atomically reserve one or more EA IDs in ea_id_registry.csv")
    reserve_ids.add_argument("--slug", action="append", required=True, help="Strategy slug to reserve. Repeat for batches.")
    reserve_ids.add_argument("--strategy-id", required=True, help="Source/strategy UUID or source identifier")
    reserve_ids.add_argument("--owner", default="Research")
    reserve_ids.add_argument("--status", default="active")
    reserve_ids.add_argument("--created-at", help="YYYY-MM-DD; defaults to today")
    reserve_ids.add_argument("--start-after", type=int, help="Optional lower bound for the first allocated numeric EA ID")

    set_status = sub.add_parser("set-source-status", help="Move one source to a new explicit status")
    set_status.add_argument("source_id")
    set_status.add_argument("status")
    set_status.add_argument("--notes-path", help="Artifact path for research notes")

    events_cmd = sub.add_parser("events", help="Show recent state transition events")
    events_cmd.add_argument("--limit", type=int, default=20)

    claude_prompt = sub.add_parser("claude-prompt", help="Write a Claude research handoff prompt")
    claude_prompt.add_argument("--source-id")
    claude_prompt.add_argument("--out")

    build_ea = sub.add_parser(
        "build-ea", help="Create a build_ea task and render the Codex EA-build prompt for an APPROVED card"
    )
    build_ea.add_argument("--card", required=True, help="Path to the APPROVED Strategy Card .md")
    build_ea.add_argument("--out", help="Override prompt output path")

    record_build = sub.add_parser("record-build", help="Record Codex build result JSON into the build_ea task")
    record_build.add_argument("--task-id", required=True)
    record_build.add_argument("--result-file", required=True, help="Path to Codex's build result JSON")

    review_prompt = sub.add_parser(
        "claude-review-prompt", help="Create an ea_review task and render the Claude EA-review prompt"
    )
    review_prompt.add_argument("--build-task-id", required=True)
    review_prompt.add_argument("--out", help="Override prompt output path")

    record_review = sub.add_parser("record-review", help="Record Claude review verdict JSON into the ea_review task")
    record_review.add_argument("--task-id", required=True, help="ea_review task id")
    record_review.add_argument("--result-file", required=True, help="Path to Claude's verdict JSON")

    sub.add_parser("mt5-slots", help="Show MT5 terminal process scan with per factory slot attribution")
    reconcile_mt5 = sub.add_parser("reconcile-mt5", help="Report MT5/worker slot mismatches; optionally repair safe slot blockers")
    reconcile_mt5.add_argument("--fix-workers", action="store_true", help="Stop duplicate terminal_worker.py daemons and start missing ones")
    reconcile_mt5.add_argument("--fix-orphan-terminals", action="store_true", help="Stop factory terminal64.exe processes whose work_item is no longer active")

    enqueue_bt = sub.add_parser(
        "enqueue-backtest",
        help="Create a backtest_<phase> task from an APPROVE_FOR_BACKTEST ea_review task",
    )
    enqueue_bt.add_argument("--review-task-id")
    enqueue_bt.add_argument("--ea", help="EA label for Q05+ cascade requeue, e.g. QM5_1056")
    enqueue_bt.add_argument("--phase", default="Q02", choices=list(SUPPORTED_BACKTEST_PHASES + CASCADE_BACKTEST_PHASES))

    dispatch = sub.add_parser(
        "dispatch-tick",
        help="Advance backtest tasks one step: start one pending, poll active, classify completed",
    )
    dispatch.add_argument("--timeout-hours", type=float, default=6.0)

    tick = sub.add_parser(
        "tick",
        help="Single farm tick - runs dispatch-tick (and in future: post-classify chaining)",
    )
    tick.add_argument("--timeout-hours", type=float, default=6.0)

    approve = sub.add_parser(
        "approve-card",
        help="Set g0_status: APPROVED + move draft to approved + emit event",
    )
    approve.add_argument("--card", required=True, help="Path to the draft card .md")
    approve.add_argument("--reasoning", required=True, help="One-line R1-R4 rationale")

    reject = sub.add_parser(
        "reject-card",
        help="Set g0_status: REJECTED + move draft to rejected + emit event",
    )
    reject.add_argument("--card", required=True, help="Path to the draft card .md")
    reject.add_argument("--reason", required=True, help="One-line rejection reason")

    sub.add_parser(
        "resume-mining",
        help="Check cards_ready sources; flip back to active if their card batch is pipeline-done",
    )

    add_src = sub.add_parser(
        "add-source",
        help="Add a new source to the queue (used by autonomous source-discovery)",
    )
    add_src.add_argument("--uri", required=True, help="Canonical URI or path of the source")
    add_src.add_argument("--title", required=True, help="Human-readable title")
    add_src.add_argument(
        "--source-type", required=True,
        choices=list(VALID_SOURCE_TYPES),
        help="Source category",
    )
    add_src.add_argument(
        "--lane", default="research", choices=list(VALID_LANES),
        help="Routing lane",
    )
    add_src.add_argument("--priority", type=int, default=70, help="Lower = earlier")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = root_from_args(args)

    if args.command == "init":
        init_db(root)
        print_json({"initialized": True, "root": str(root), "db": str(db_path(root))})
    elif args.command == "seed-sources":
        print_json(seed_sources(root, force=args.force))
    elif args.command == "status":
        print_json(status(root))
    elif args.command == "pipeline":
        print_json(pipeline_view(root))
    elif args.command == "pump":
        print_json(pump(root))
    elif args.command == "health":
        try:
            from health import run_all as _health_run_all
        except ImportError:
            import sys as _sys
            _sys.path.insert(0, str(Path(__file__).resolve().parent))
            from health import run_all as _health_run_all
        print_json(_health_run_all())
    elif args.command == "repair":
        try:
            from repair import run_all as _repair_run_all
        except ImportError:
            import sys as _sys
            _sys.path.insert(0, str(Path(__file__).resolve().parent))
            from repair import run_all as _repair_run_all
        print_json(_repair_run_all())
    elif args.command == "work-items":
        print_json(work_items_view(root, status_filter=args.status, ea_filter=args.ea))
    elif args.command == "backfill-work-items":
        print_json(backfill_work_items(root))
    elif args.command == "next":
        print_json(next_action(root))
    elif args.command == "claim-source":
        print_json(claim_source(root))
    elif args.command == "reserve-ea-ids":
        print_json(reserve_ea_ids(
            root,
            args.slug,
            strategy_id=args.strategy_id,
            owner=args.owner,
            status=args.status,
            created_at=args.created_at,
            start_after=args.start_after,
        ))
    elif args.command == "set-source-status":
        print_json(set_source_status(root, args.source_id, args.status, args.notes_path))
    elif args.command == "events":
        print_json(events_tail(root, args.limit))
    elif args.command == "claude-prompt":
        print_json(render_claude_prompt(root, args.source_id, args.out))
    elif args.command == "build-ea":
        print_json(render_codex_build_prompt(root, args.card, args.out))
    elif args.command == "record-build":
        print_json(record_build_result(root, args.task_id, args.result_file))
    elif args.command == "claude-review-prompt":
        print_json(render_claude_review_prompt(root, args.build_task_id, args.out))
    elif args.command == "record-review":
        print_json(record_review_result(root, args.task_id, args.result_file))
    elif args.command == "mt5-slots":
        print_json(get_mt5_status(root))
    elif args.command == "reconcile-mt5":
        print_json(reconcile_mt5_slots(root, fix_workers=args.fix_workers, fix_orphan_terminals=args.fix_orphan_terminals))
    elif args.command == "enqueue-backtest":
        if args.ea:
            print_json(enqueue_cascade_backtest_for_ea(root, args.ea, args.phase))
        elif args.review_task_id:
            print_json(enqueue_backtest(root, args.review_task_id, args.phase))
        else:
            print_json({"enqueued": False, "reason": "Provide --review-task-id for P2-P4 or --ea for P5+ cascade phases."})
    elif args.command == "dispatch-tick":
        print_json(dispatch_tick(root, timeout_hours=args.timeout_hours))
    elif args.command == "tick":
        # v1 tick: just dispatch-tick. Future ticks will chain post-classify
        # advance (PASS → enqueue next phase / FAIL → mark EA DEAD) and
        # post-review auto-enqueue (APPROVE_FOR_BACKTEST → enqueue P2).
        print_json({
            "tick_at": utc_now(),
            "dispatch": dispatch_tick(root, timeout_hours=args.timeout_hours),
        })
    elif args.command == "approve-card":
        print_json(approve_card(root, args.card, args.reasoning))
    elif args.command == "reject-card":
        print_json(reject_card(root, args.card, args.reason))
    elif args.command == "resume-mining":
        print_json(resume_mining(root))
    elif args.command == "add-source":
        print_json(add_source(
            root,
            uri=args.uri,
            title=args.title,
            source_type=args.source_type,
            lane=args.lane,
            priority=args.priority,
        ))
    else:
        raise AssertionError(args.command)
    return 0


if __name__ == "__main__":
    sys.exit(main())
