"""Synthetic strategy variations around proven winners.

OWNER 2026-05-17: "Statt nur ±25% Random-Ablation, eine breitere Suche
(verschiedene Symbole, andere Halterungs-Tage, Volatilitäts-Filter ein/aus).
1 Winner finden vs. 50 Random testen = bessere Erwartung."

Difference from ablate.py:
  * ablate.py = numeric perturbation of strategy_* inputs (±25%) on the
    SAME EA + same symbols.
  * synth_variants.py = BROADER search: also tries different symbols (not
    just the ones the winner passed on), flips bool inputs (regime_filter
    on/off, etc.), and exhausts the cross-product of "what if we changed
    one structural axis".

Triggers: when an EA accumulates ≥3 P2-PASS work_items (a meaningful edge,
not noise), we spawn synthetic variants — same EA code, different setfile
combos exploring: { all DWX symbols ∩ matching tf } × { bool flags } ×
{ a 3-point grid of numeric inputs }.

Output: new pending P2 work_items for the variants. MT5 dispatcher picks
them up via the priority-queue (winner-EA gets `_winner_rank=0`).

Capped at 30 new variants per (ea_id, run) to avoid exploding MT5 queue.
Idempotent: tracks via `synthetic_variants_spawned_at` field on the EA's
build_ea task.
"""

from __future__ import annotations

import itertools
import json
import re
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path

# Compatible DWX symbol sets by asset class — synthetic variant explores
# whether the edge generalizes to siblings in the same class.
SYMBOL_FAMILY = {
    "indices_us":   ["NDX.DWX", "WS30.DWX", "SP500.DWX"],
    "indices_eu":   ["GDAXI.DWX", "UK100.DWX", "FCHI.DWX", "STOXX50E.DWX"],
    "indices_all":  ["NDX.DWX", "WS30.DWX", "SP500.DWX", "GDAXI.DWX", "UK100.DWX"],
    "forex_majors": ["EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX", "USDCAD.DWX"],
    "forex_yens":   ["USDJPY.DWX", "EURJPY.DWX", "GBPJPY.DWX"],
    "metals":       ["XAUUSD.DWX", "XAGUSD.DWX"],
}


_INPUT_LINE_RE = re.compile(
    r"input\s+(int|double|long|float|bool)\s+(strategy_\w+)\s*=\s*(\S+?)\s*;",
    re.IGNORECASE,
)


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.") + (
        datetime.now(timezone.utc).strftime("%f")[:6]
    ) + "Z"


def extract_strategy_inputs(ea_mq5_path: Path) -> list[dict]:
    """Like ablate.extract_strategy_inputs but also captures bool inputs."""
    if not ea_mq5_path.exists():
        return []
    text = ea_mq5_path.read_text(encoding="utf-8", errors="ignore")
    out: list[dict] = []
    for m in _INPUT_LINE_RE.finditer(text):
        typ = m.group(1).lower()
        name = m.group(2)
        raw = m.group(3).strip()
        if typ == "bool":
            default = raw.lower() in ("true", "1")
            out.append({"name": name, "type": typ, "default": default})
        else:
            try:
                default = float(raw)
            except ValueError:
                continue
            out.append({"name": name, "type": typ, "default": default})
    return out


def _infer_symbol_family(winner_symbols: list[str]) -> list[str]:
    """Pick the broadest matching family for a winning EA's symbol set."""
    sets = {k: set(v) for k, v in SYMBOL_FAMILY.items()}
    winner_set = set(winner_symbols)
    # Prefer the smallest family that fully contains the winner's symbols
    candidates = []
    for fam, members in sets.items():
        if winner_set.issubset(members):
            candidates.append((len(members), fam, members))
    if not candidates:
        return winner_symbols  # no family match; just use what we have
    candidates.sort()
    _, _, picked = candidates[0]
    return sorted(picked)


def _read_setfile(path: Path) -> dict[str, str]:
    """Parse a .set file into {input_name: value_string}."""
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def _write_setfile(path: Path, header_text: str, overrides: dict[str, str]) -> None:
    """Write a new setfile copying parent header + applying overrides."""
    body = [header_text.rstrip()]
    body.append(f"; --- synthetic variant ({path.stem}) ---")
    for k, v in overrides.items():
        body.append(f"{k}={v}")
    path.write_text("\n".join(body) + "\n", encoding="utf-8", newline="\n")


def spawn_synthetic_variants(
    conn: sqlite3.Connection,
    ea_id: str,
    framework_eas_dir: Path,
    parent_setfile: Path | None = None,
    max_variants: int = 30,
    period: str = "D1",
) -> dict:
    """Generate up to `max_variants` synthetic variants for an EA's setfile.

    Workflow:
      1. Pick a "base" setfile to mutate from (prefer a P2-PASS work_item's
         setfile if `parent_setfile` not given).
      2. Discover the EA's strategy_* inputs + family of compatible symbols.
      3. Sample combinations of:
         - symbols from the inferred family (3 values: original, sibling A, sibling B)
         - bool inputs flipped (each bool = 2 options)
         - top 2 numeric inputs at {-30%, 0, +30%} (3 values each)
      4. Write each as a new setfile + insert P2 work_item.

    Returns {ea_id, variant_count, work_item_ids, setfile_paths, reason?}.
    """
    # Find a base setfile
    if parent_setfile is None:
        base_wi = conn.execute(
            """
            SELECT setfile_path FROM work_items
            WHERE ea_id=? AND status='done' AND verdict='PASS' AND phase='P2'
              AND setfile_path NOT LIKE '%_ablation_%'
              AND setfile_path NOT LIKE '%_grid_%'
              AND setfile_path NOT LIKE '%_synth_%'
            ORDER BY updated_at DESC LIMIT 1
            """, (ea_id,),
        ).fetchone()
        if not base_wi:
            return {"ea_id": ea_id, "variant_count": 0, "work_item_ids": [],
                    "setfile_paths": [], "reason": "no P2-PASS base setfile found"}
        parent_setfile = Path(base_wi["setfile_path"])

    if not parent_setfile.exists():
        return {"ea_id": ea_id, "variant_count": 0, "work_item_ids": [],
                "setfile_paths": [], "reason": f"base setfile missing: {parent_setfile}"}

    # Resolve EA dir
    ea_dir = parent_setfile.parent.parent
    if not ea_dir.exists() or not (ea_dir / f"{ea_dir.name}.mq5").exists():
        candidates = [d for d in framework_eas_dir.iterdir()
                      if d.is_dir() and d.name.startswith(ea_id)]
        if not candidates:
            return {"ea_id": ea_id, "variant_count": 0, "work_item_ids": [],
                    "setfile_paths": [], "reason": f"ea_dir not found for {ea_id}"}
        ea_dir = candidates[0]
    ea_mq5 = ea_dir / f"{ea_dir.name}.mq5"

    # Discover inputs + symbol family
    inputs = extract_strategy_inputs(ea_mq5)
    numeric_inputs = [i for i in inputs if i["type"] in ("int", "long", "double", "float")
                      and i["default"] != 0]
    bool_inputs = [i for i in inputs if i["type"] == "bool"]

    winner_syms = sorted({
        r["symbol"] for r in conn.execute(
            "SELECT DISTINCT symbol FROM work_items "
            "WHERE ea_id=? AND status='done' AND verdict='PASS' AND phase='P2'",
            (ea_id,),
        ).fetchall()
    })
    if not winner_syms:
        winner_syms = [parent_setfile.stem.split("_")[-3]] if "_" in parent_setfile.stem else []
    symbol_family = _infer_symbol_family(winner_syms)

    # Build combination axes
    sym_axis = list(symbol_family)[:5]  # cap at 5 symbols
    bool_axis = []
    for b in bool_inputs[:3]:  # max 3 bool flips
        bool_axis.append([(b["name"], "true"), (b["name"], "false")])
    if not bool_axis:
        bool_axis = [[None]]  # one "no-op" bool combo
    num_axis = []
    for inp in numeric_inputs[:2]:  # top 2 numeric
        default = inp["default"]
        is_int = inp["type"] in ("int", "long")
        values = []
        for factor in (0.7, 1.0, 1.3):
            v = default * factor
            if is_int:
                values.append((inp["name"], str(max(1, int(round(v))))))
            else:
                values.append((inp["name"], f"{v:.4f}".rstrip("0").rstrip(".") or "0"))
        num_axis.append(values)
    if not num_axis:
        num_axis = [[None]]

    # Generate combos and slice
    parent_text = parent_setfile.read_text(encoding="utf-8", errors="ignore")
    parent_stem = parent_setfile.stem
    # parent_stem typically has form: <ea_id>_<slug>_<SYMBOL>_<TF>_backtest
    # Extract base prefix (everything before _<SYMBOL>_)
    sym_match = re.search(r"_([A-Z0-9]+\.DWX|[A-Z]+\d+)_", parent_stem)
    if sym_match:
        base_prefix = parent_stem[:sym_match.start()]
        tf_suffix = parent_stem[sym_match.end():]  # e.g. "D1_backtest"
    else:
        base_prefix = parent_stem
        tf_suffix = f"{period}_backtest"

    combos = list(itertools.product(sym_axis, *bool_axis, *num_axis))
    if len(combos) > max_variants:
        # Deterministic slice — take evenly-spaced indices to span the space
        step = len(combos) / max_variants
        combos = [combos[int(i * step)] for i in range(max_variants)]

    written_paths: list[Path] = []
    work_item_ids: list[str] = []
    now = _utc_now()

    for idx, combo in enumerate(combos):
        symbol = combo[0]
        overrides_list = list(combo[1:])  # bools + nums (some may be None)
        overrides: dict[str, str] = {}
        for entry in overrides_list:
            if entry is None:
                continue
            k, v = entry
            overrides[k] = v
        # Filename: <base>_<SYMBOL>_<TF>_synth_NNN.set
        new_name = f"{base_prefix}_{symbol}_{tf_suffix.replace('_backtest','')}_synth_{idx:03d}_backtest.set"
        new_path = parent_setfile.parent / new_name
        _write_setfile(new_path, parent_text, overrides)
        written_paths.append(new_path)

        # Find parent P2 task for this EA to attach work_item to
        parent_task = conn.execute(
            "SELECT id FROM tasks WHERE kind='backtest_p2' "
            "AND payload_json LIKE ? ORDER BY created_at ASC LIMIT 1",
            (f'%"ea_id": "{ea_id}"%',),
        ).fetchone()
        parent_task_id = parent_task["id"] if parent_task else None

        wi_id = str(uuid.uuid4())
        wi_payload = {
            "is_synthetic": True,
            "synth_overrides": overrides,
            "base_setfile": str(parent_setfile),
            "synth_index": idx,
        }
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status,
               attempt_count, parent_task_id, payload_json, created_at, updated_at)
            VALUES (?, 'backtest', 'P2', ?, ?, ?, 'pending', 0, ?, ?, ?, ?)
            """,
            (wi_id, ea_id, symbol, str(new_path), parent_task_id,
             json.dumps(wi_payload, sort_keys=True), now, now),
        )
        work_item_ids.append(wi_id)

    conn.commit()
    return {
        "ea_id": ea_id,
        "variant_count": len(written_paths),
        "work_item_ids": work_item_ids,
        "setfile_paths": [str(p) for p in written_paths],
        "base_setfile": str(parent_setfile),
        "symbol_family": symbol_family,
        "n_numeric_inputs": len(numeric_inputs),
        "n_bool_inputs": len(bool_inputs),
        "reason": None,
    }


def auto_spawn_for_winners(
    conn: sqlite3.Connection,
    framework_eas_dir: Path,
    min_pass_count: int = 3,
    max_variants_per_ea: int = 30,
) -> list[dict]:
    """Trigger synthetic variants for any EA with >= min_pass_count P2-PASS
    work_items that hasn't had synth variants spawned yet.

    Idempotent via build_ea.synthetic_variants_spawned_at field.
    """
    out: list[dict] = []
    # EAs with enough P2 PASSes
    winners = conn.execute(
        """
        SELECT ea_id, COUNT(*) c FROM work_items
        WHERE phase='P2' AND status='done' AND verdict='PASS'
        GROUP BY ea_id HAVING c >= ?
        ORDER BY c DESC
        """, (min_pass_count,),
    ).fetchall()
    for w in winners:
        ea_id = w["ea_id"]
        # Skip if already done
        build_row = conn.execute(
            "SELECT id, payload_json FROM tasks WHERE kind='build_ea' "
            "AND payload_json LIKE ? ORDER BY created_at ASC LIMIT 1",
            (f'%"ea_id": "{ea_id}"%',),
        ).fetchone()
        if not build_row:
            continue
        payload = json.loads(build_row["payload_json"])
        if payload.get("synthetic_variants_spawned_at"):
            continue
        report = spawn_synthetic_variants(
            conn, ea_id, framework_eas_dir,
            max_variants=max_variants_per_ea,
        )
        if report.get("variant_count", 0) > 0:
            payload["synthetic_variants_spawned_at"] = _utc_now()
            payload["synthetic_variants_count"] = report["variant_count"]
            conn.execute(
                "UPDATE tasks SET payload_json=? WHERE id=?",
                (json.dumps(payload), build_row["id"]),
            )
            conn.commit()
        out.append(report)
    return out
