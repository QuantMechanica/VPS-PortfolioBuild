#!/usr/bin/env python3
"""15-minute cron wrapper for strategy panel refresh (QUAA-234).

Behavior:
- Reuses Company/Analysis/refresh_strategy_panel.py for corpus scan + taxonomy panel payload.
- Compares corpus fingerprint against Company/Analysis/strategy_panel_state.json.
- On change, atomically rewrites strategy panel markdown/json + state cache.
- On change, atomically updates MT5 strategy fragment (strategy_panels.json) in contract envelope.
- Emits a single stdout line: "refreshed: ..." | "no change" | "error: ...".
"""

from __future__ import annotations

import importlib.util
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from tempfile import NamedTemporaryFile
from types import ModuleType
from typing import Any

ROOT = Path(r"G:/Meine Ablage/QuantMechanica")
COMPANY_DIR = ROOT / "Company"
ANALYSIS_DIR = COMPANY_DIR / "Analysis"

REFRESH_MODULE_PATH = ANALYSIS_DIR / "refresh_strategy_panel.py"
PANEL_MD_PATH = ANALYSIS_DIR / "dashboard_panel_strategy.md"
PANEL_JSON_PATH = ANALYSIS_DIR / "dashboard_panel_strategy.json"
STATE_CACHE_PATH = ANALYSIS_DIR / "strategy_panel_state.json"

MT5_OUTPUT_DIR = Path(
    r"C:/Users/fabia/AppData/Roaming/MetaQuotes/Terminal/"
    r"6C3C6A11D1C3791DD4DBF45421BF8028/MQL5/Files/edge_validation/output"
)
STRATEGY_FRAGMENT_PATH = MT5_OUTPUT_DIR / "strategy_panels.json"
FRAGMENT_SCHEMA_VERSION = "v1"
DEFAULT_FRAGMENT_STALE_MINUTES = 45


def _iso_utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _load_module(module_path: Path, module_name: str) -> ModuleType:
    if not module_path.is_file():
        raise FileNotFoundError(f"required module missing: {module_path}")
    spec = importlib.util.spec_from_file_location(module_name, str(module_path))
    if spec is None or spec.loader is None:
        raise ImportError(f"unable to load module spec: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _atomic_write_text(path: Path, content: str) -> None:
    parent = path.parent
    if not parent.is_dir():
        raise FileNotFoundError(f"parent directory missing: {parent}")

    temp_path: Path | None = None
    try:
        with NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="\n",
            dir=str(parent),
            delete=False,
        ) as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
            temp_path = Path(handle.name)

        os.replace(temp_path, path)
        temp_path = None
    finally:
        if temp_path is not None and temp_path.exists():
            try:
                temp_path.unlink()
            except OSError:
                pass


def _atomic_write_json(path: Path, payload: Any) -> None:
    _atomic_write_text(path, json.dumps(payload, indent=2, ensure_ascii=False) + "\n")


def _read_cached_fingerprint(path: Path) -> str | None:
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    value = data.get("fingerprint")
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _build_refresh_payload(refresh_module: ModuleType) -> dict[str, Any]:
    return {
        "refresh_utc": _iso_utc_now(),
        "corpus": refresh_module.scan_terminals(),
        "analysis": refresh_module.load_last_analysis(),
        "state": refresh_module.read_state_snapshot(),
    }


def _build_state_cache(payload: dict[str, Any]) -> dict[str, Any]:
    analysis = payload.get("analysis") or {}
    corpus = payload.get("corpus") or {}
    return {
        "last_refresh_utc": payload.get("refresh_utc"),
        "fingerprint": corpus.get("fingerprint"),
        "total_htm": corpus.get("total_htm"),
        "latest_mtime": corpus.get("latest_mtime"),
        "analysis_source": analysis.get("_path"),
        "analysis_mtime": analysis.get("_mtime"),
    }


def _load_existing_strategy_panels(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    panels = payload.get("panels")
    return panels if isinstance(panels, dict) else {}


def _build_strategy_fragment_payload(panels: dict[str, Any]) -> dict[str, Any]:
    return {
        "fragment": "strategy",
        "schema_version": FRAGMENT_SCHEMA_VERSION,
        "generated_at": _iso_utc_now(),
        "stale_after_minutes": DEFAULT_FRAGMENT_STALE_MINUTES,
        "panels": panels,
    }


def _parse_force_flag(argv: list[str]) -> bool:
    allowed = {"--force-refresh"}
    unknown = [arg for arg in argv if arg not in allowed]
    if unknown:
        raise ValueError(f"unknown argument(s): {' '.join(unknown)}")
    return "--force-refresh" in argv


def _run(force_refresh: bool) -> int:
    if not ANALYSIS_DIR.is_dir():
        raise FileNotFoundError(f"analysis directory missing: {ANALYSIS_DIR}")
    if not MT5_OUTPUT_DIR.is_dir():
        raise FileNotFoundError(f"mt5 output directory missing or unreachable: {MT5_OUTPUT_DIR}")

    refresh_module = _load_module(REFRESH_MODULE_PATH, "qm_refresh_strategy_panel")

    payload = _build_refresh_payload(refresh_module)
    corpus = payload.get("corpus") or {}
    new_fingerprint = corpus.get("fingerprint")
    if not isinstance(new_fingerprint, str) or not new_fingerprint.strip():
        raise RuntimeError("refresh payload missing corpus fingerprint")
    new_fingerprint = new_fingerprint.strip()

    old_fingerprint = _read_cached_fingerprint(STATE_CACHE_PATH)
    has_change = force_refresh or (old_fingerprint != new_fingerprint)
    if not has_change:
        print("no change")
        return 0

    panel_markdown = refresh_module.build_panel(payload)
    state_cache = _build_state_cache(payload)

    existing_panels = _load_existing_strategy_panels(STRATEGY_FRAGMENT_PATH)
    fragment_payload = _build_strategy_fragment_payload(existing_panels)

    _atomic_write_json(PANEL_JSON_PATH, payload)
    _atomic_write_text(PANEL_MD_PATH, panel_markdown)
    _atomic_write_json(STATE_CACHE_PATH, state_cache)
    _atomic_write_json(STRATEGY_FRAGMENT_PATH, fragment_payload)

    from_fingerprint = old_fingerprint if old_fingerprint else "none"
    print(f"refreshed: fingerprint {from_fingerprint} -> {new_fingerprint}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    try:
        force_refresh = _parse_force_flag(args)
        return _run(force_refresh=force_refresh)
    except Exception as exc:
        message = " ".join(str(exc).splitlines()).strip() or exc.__class__.__name__
        print(f"error: {message}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
