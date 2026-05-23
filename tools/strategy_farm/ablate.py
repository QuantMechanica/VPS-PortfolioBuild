"""Parameter ablation — generate setfile mutations for a P2-PASS work_item.

OWNER 2026-05-16: P2 PASS rate is 14%, P3 PASS rate is 0%. The fastest path to
"more successful EAs" is exhausting the parameter space of strategies that
already work, not generating yet more from-scratch strategies.

Pipeline:
  P2 work_item passes → ablate.mutate_setfile(parent_setfile, ea_dir, N=5) →
  5 new setfiles written next to parent → 5 new pending P2 work_items inserted
  → MT5 dispatcher picks them up → if any also pass, they too get ablated
  (depth-1 only — see `is_ablation` flag in payload to prevent grandchildren).

The mutator reads the EA's .mq5 to discover `input <type> strategy_<name> =
<default>;` declarations, perturbs each numeric one by ±perturb_pct, and
writes N variant setfiles. Bool inputs and inputs with default=0 (sentinel)
are skipped.
"""

from __future__ import annotations

import itertools
import json
import math
import random
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path


_INPUT_LINE_RE = re.compile(
    r"input\s+(int|double|long|float)\s+(strategy_\w+)\s*=\s*([0-9.\-]+)\s*;",
    re.IGNORECASE,
)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.") + (
        datetime.now(timezone.utc).strftime("%f")[:6]
    ) + "Z"


def extract_strategy_inputs(ea_mq5_path: Path) -> list[dict]:
    """Parse `input <type> strategy_<name> = <default>;` declarations.

    Returns list of {name, type, default} dicts. Skips bool, string, and
    non-numeric defaults.
    """
    if not ea_mq5_path.exists():
        return []
    text = ea_mq5_path.read_text(encoding="utf-8", errors="ignore")
    out: list[dict] = []
    for m in _INPUT_LINE_RE.finditer(text):
        typ = m.group(1).lower()
        name = m.group(2)
        try:
            default = float(m.group(3))
        except ValueError:
            continue
        out.append({"name": name, "type": typ, "default": default})
    return out


def mutate_setfile(
    parent_setfile: Path,
    ea_dir: Path,
    n_variants: int = 5,
    perturb_pct: float = 0.25,
    seed: int | None = None,
) -> list[Path]:
    """Generate n_variants ablation setfiles next to parent.

    Each variant overrides numeric strategy_* inputs by a random factor in
    [1-perturb_pct, 1+perturb_pct]. Ints are rounded; sentinel defaults (0)
    are skipped (they typically signal "feature disabled").

    Returns paths to written variant files. Empty list if no perturbable
    inputs found.
    """
    parent_setfile = Path(parent_setfile)
    if not parent_setfile.exists():
        return []
    ea_mq5 = ea_dir / f"{ea_dir.name}.mq5"
    inputs = extract_strategy_inputs(ea_mq5)
    perturbable = [i for i in inputs if i["default"] != 0]
    if not perturbable:
        return []

    rng = random.Random(seed if seed is not None else hash(str(parent_setfile)) & 0xFFFFFFFF)
    parent_text = parent_setfile.read_text(encoding="utf-8", errors="ignore")
    parent_stem = parent_setfile.stem
    out_paths: list[Path] = []

    for i in range(n_variants):
        overrides: dict[str, str] = {}
        for inp in perturbable:
            factor = 1.0 + rng.uniform(-perturb_pct, perturb_pct)
            new_val = inp["default"] * factor
            if inp["type"] in ("int", "long"):
                new_val_str = str(max(1, int(round(new_val))))
            else:
                new_val_str = f"{new_val:.6f}".rstrip("0").rstrip(".")
                if not new_val_str or new_val_str in ("-",):
                    new_val_str = "0"
            overrides[inp["name"]] = new_val_str

        body = [parent_text.rstrip()]
        body.append(
            f"; --- ablation child {i:02d} of {parent_stem} "
            f"(perturb=±{int(perturb_pct*100)}%) ---"
        )
        for k, v in overrides.items():
            body.append(f"{k}={v}")

        out_path = parent_setfile.parent / f"{parent_stem}_ablation_{i:02d}.set"
        out_path.write_text("\n".join(body) + "\n", encoding="utf-8", newline="\n")
        out_paths.append(out_path)

    return out_paths


def mutate_setfile_grid(
    parent_setfile: Path,
    ea_dir: Path,
    n_target: int = 50,
    perturb_pct: float = 0.30,
) -> list[Path]:
    """Systematic parameter-grid sweep around parent defaults.

    For exploitation of a confirmed-good setpoint (P3-PASS), generate a dense
    grid of perturbations instead of 5 random samples. Picks the top N
    numeric strategy_* inputs (cap N=4), sweeps each across M values spaced
    uniformly across [-perturb_pct, +perturb_pct] around default, takes the
    cartesian product, slices to n_target.

    Grid shape decision:
      - 1 input  → M=n_target linearly spaced
      - 2 inputs → M=ceil(sqrt(n_target))  (49 / 64 / 81 etc.)
      - 3 inputs → M=ceil(cbrt(n_target))  (27 / 64 / 125)
      - 4+ inputs (capped) → M=ceil(n_target^(1/4))

    Default n_target=50: with 3 inputs → M=4 → 64 combos → first 50 written.
    Setfile naming: <parent>_grid_NN.set (NN zero-padded).
    """
    parent_setfile = Path(parent_setfile)
    if not parent_setfile.exists():
        return []
    ea_mq5 = ea_dir / f"{ea_dir.name}.mq5"
    inputs = extract_strategy_inputs(ea_mq5)
    perturbable = [i for i in inputs if i["default"] != 0]
    if not perturbable:
        return []

    n_dims = min(len(perturbable), 4)
    sweep_inputs = perturbable[:n_dims]
    m_per_dim = max(2, int(math.ceil(n_target ** (1.0 / n_dims))))
    if n_dims == 1:
        m_per_dim = n_target

    # M values centred on default: linearly spaced across [-perturb, +perturb]
    if m_per_dim == 1:
        factors = [1.0]
    else:
        factors = [
            1.0 + (-perturb_pct + 2.0 * perturb_pct * i / (m_per_dim - 1))
            for i in range(m_per_dim)
        ]

    combos = list(itertools.product(factors, repeat=n_dims))[:n_target]
    parent_text = parent_setfile.read_text(encoding="utf-8", errors="ignore")
    parent_stem = parent_setfile.stem
    out_paths: list[Path] = []

    for idx, combo in enumerate(combos):
        overrides: dict[str, str] = {}
        for inp, factor in zip(sweep_inputs, combo):
            new_val = inp["default"] * factor
            if inp["type"] in ("int", "long"):
                new_val_str = str(max(1, int(round(new_val))))
            else:
                new_val_str = f"{new_val:.6f}".rstrip("0").rstrip(".")
                if not new_val_str or new_val_str in ("-",):
                    new_val_str = "0"
            overrides[inp["name"]] = new_val_str

        body = [parent_text.rstrip()]
        body.append(
            f"; --- grid child {idx:03d}/{len(combos):03d} of {parent_stem} "
            f"(n_dims={n_dims} m_per_dim={m_per_dim} perturb=±{int(perturb_pct*100)}%) ---"
        )
        for k, v in overrides.items():
            body.append(f"{k}={v}")

        out_path = parent_setfile.parent / f"{parent_stem}_grid_{idx:03d}.set"
        out_path.write_text("\n".join(body) + "\n", encoding="utf-8", newline="\n")
        out_paths.append(out_path)

    return out_paths


def spawn_ablation_workitems(
    conn,  # sqlite3.Connection
    parent_work_item: dict,
    framework_eas_dir: Path,
    n_variants: int = 5,
    perturb_pct: float = 0.25,
    method: str = "random",
) -> dict:
    """For a PASS work_item, generate ablation setfiles and insert new work_items.

    Returns:
        {
            "parent_id": str,
            "ea_id": str,
            "symbol": str,
            "children_count": int,
            "children_ids": [...],
            "setfile_paths": [...],
            "reason": str | None,  # if children_count == 0
        }
    """
    parent_id = parent_work_item["id"]
    ea_id = parent_work_item["ea_id"]
    symbol = parent_work_item["symbol"]
    phase = parent_work_item["phase"]
    parent_setfile = Path(parent_work_item["setfile_path"])
    parent_payload = json.loads(parent_work_item.get("payload_json") or "{}")

    # Resolve ea_dir: parent of parent of setfile (sets/<file> -> <ea_dir>)
    ea_dir = parent_setfile.parent.parent
    if not ea_dir.exists() or not (ea_dir / f"{ea_dir.name}.mq5").exists():
        # Fallback: scan framework/EAs for directory starting with ea_id
        candidates = [d for d in framework_eas_dir.iterdir()
                      if d.is_dir() and d.name.startswith(ea_id)]
        if not candidates:
            return {
                "parent_id": parent_id, "ea_id": ea_id, "symbol": symbol,
                "children_count": 0, "children_ids": [], "setfile_paths": [],
                "reason": f"ea_dir not found for {ea_id}",
            }
        ea_dir = candidates[0]

    if method == "grid":
        new_setfiles = mutate_setfile_grid(
            parent_setfile, ea_dir,
            n_target=n_variants, perturb_pct=perturb_pct,
        )
    else:
        new_setfiles = mutate_setfile(
            parent_setfile, ea_dir,
            n_variants=n_variants, perturb_pct=perturb_pct,
        )
    if not new_setfiles:
        return {
            "parent_id": parent_id, "ea_id": ea_id, "symbol": symbol,
            "method": method, "children_count": 0,
            "children_ids": [], "setfile_paths": [],
            "reason": "no perturbable strategy_* inputs in EA .mq5",
        }

    now = _utc_now_iso()
    children_ids: list[str] = []
    for set_path in new_setfiles:
        child_id = str(uuid.uuid4())
        child_payload = {
            "is_ablation": True,
            "ablation_method": method,
            "parent_work_item_id": parent_id,
            "perturb_pct": perturb_pct,
            "parent_setfile": str(parent_setfile),
        }
        conn.execute(
            """
            INSERT INTO work_items(
                id, kind, phase, ea_id, symbol, setfile_path, status,
                verdict, attempt_count, parent_task_id, evidence_path,
                claimed_by, payload_json, created_at, updated_at
            )
            VALUES (?, 'backtest', ?, ?, ?, ?, 'pending',
                    NULL, 0, ?, NULL, NULL, ?, ?, ?)
            """,
            (child_id, phase, ea_id, symbol, str(set_path),
             parent_payload.get("parent_task_id"),
             json.dumps(child_payload, sort_keys=True),
             now, now),
        )
        children_ids.append(child_id)

    # Mark parent as ablated so we don't re-spawn
    parent_payload["ablated_at"] = now
    parent_payload["ablation_child_count"] = len(new_setfiles)
    conn.execute(
        "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=?",
        (json.dumps(parent_payload, sort_keys=True), now, parent_id),
    )
    conn.commit()

    return {
        "parent_id": parent_id, "ea_id": ea_id, "symbol": symbol,
        "method": method,
        "children_count": len(new_setfiles),
        "children_ids": children_ids,
        "setfile_paths": [str(p) for p in new_setfiles],
        "reason": None,
    }
