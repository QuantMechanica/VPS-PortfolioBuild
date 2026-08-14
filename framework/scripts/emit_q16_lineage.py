#!/usr/bin/env python3
"""Deterministic emitter for Q16 lineage evidence (``qm.q16-lineage/v1``).

Assembles a PARENT or CHALLENGER lineage artifact from already-sealed,
SHA-bound inputs: binary, setfile, frozen trade stream, and Q10 PASS
evidence. For a CHALLENGER it additionally assembles the Q07/Q08
trial-count blocks that ``q16_head_to_head.validate_trial_ledger`` enforces
against the trial ledger (framework/scripts/q16_head_to_head.py:289-317).

The Q07/Q08 ``trial_ledger_declared_count``/``observed_trial_count`` values
are read from the bound Q07/Q08 evidence files, never taken as a CLI
argument -- a caller cannot assert a count the evidence does not itself
carry. A mismatch against the trial ledger's own ``declared_trial_count``
is a hard error before anything is written.

``selection_trial_count`` is recorded as a field distinct from
``trial_ledger_declared_count``: per Plan v2 E0-1 (measurement is not
selection), a pre-registered predicate has ``selection_trial_count=1`` even
when the census measured all 154 cells in its sleeve. It is supplied
explicitly and never derived from, defaulted to, or collapsed into the
measured trial count.

This script never launches MT5, never writes to the farm database, and never
decides which trial is promoted -- it assembles evidence for a promotion
decision made elsewhere. Dry-run is the default; ``--apply`` writes the
artifact to ``--out``. Every run also self-checks the written bytes through
the real ``q16_head_to_head`` loader (``load_lineage`` / for CHALLENGER also
``validate_trial_ledger``), so this script cannot emit something Q16 would
reject.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path
from typing import Any, Mapping, Sequence

REPO_ROOT = Path(__file__).resolve().parents[2]
if __package__ in (None, ""):
    sys.path.insert(0, str(REPO_ROOT))

from framework.scripts import q16_head_to_head as q16

LINEAGE_SCHEMA = q16.LINEAGE_SCHEMA
TRIAL_LEDGER_SCHEMA = q16.TRIAL_LEDGER_SCHEMA
RESULT_SCHEMA = "qm.emit-q16-lineage-result/v1"
ROLES = {"PARENT", "CHALLENGER"}


class EmitQ16LineageError(RuntimeError):
    """A fail-closed input or assembly error."""


def _read_json(path: Path, label: str) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise EmitQ16LineageError(f"{label} is missing or invalid: {path}: {exc}") from exc


def _binding(path: Path, label: str) -> dict[str, Any]:
    try:
        return q16._binding(path)
    except q16.Q16Error as exc:
        raise EmitQ16LineageError(f"{label}: {exc}") from exc


def _require_positive_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise EmitQ16LineageError(f"{label} must be a positive integer, got {value!r}")
    return value


def _require_nonneg_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise EmitQ16LineageError(f"{label} must be a non-negative integer, got {value!r}")
    return value


def _phase_trial_counts(payload: Any, *, phase: str, label: str) -> tuple[int, int]:
    if not isinstance(payload, Mapping):
        raise EmitQ16LineageError(f"{label} is not an object")
    if str(payload.get("phase") or "").upper() != phase:
        raise EmitQ16LineageError(f"{label} does not declare phase={phase}")
    block = payload.get("trial_ledger", payload)
    if not isinstance(block, Mapping):
        raise EmitQ16LineageError(f"{label} lacks a trial_ledger block")
    declared = _require_nonneg_int(block.get("declared_trial_count"), f"{label} declared_trial_count")
    observed = _require_nonneg_int(block.get("observed_trial_count"), f"{label} observed_trial_count")
    return declared, observed


def _validate_q10_evidence(path: Path) -> dict[str, Any]:
    payload = _read_json(path, "Q10 evidence")
    if (
        not isinstance(payload, Mapping)
        or str(payload.get("phase") or "").upper() != "Q10"
        or str(payload.get("verdict") or "").upper() != "PASS"
    ):
        raise EmitQ16LineageError(f"Q10 evidence {path} is not a Q10 PASS artifact")
    return {"verdict": "PASS", "evidence": _binding(path, "Q10 evidence")}


def _validate_ledger(path: Path) -> dict[str, Any]:
    ledger = _read_json(path, "trial ledger")
    if not isinstance(ledger, Mapping) or ledger.get("schema") != TRIAL_LEDGER_SCHEMA:
        raise EmitQ16LineageError(f"trial ledger schema must be {TRIAL_LEDGER_SCHEMA}")
    trials = ledger.get("trials")
    if not isinstance(trials, list):
        raise EmitQ16LineageError("trial ledger trials must be a list")
    declared = _require_nonneg_int(ledger.get("declared_trial_count"), "trial ledger declared_trial_count")
    if declared != len(trials):
        raise EmitQ16LineageError(f"trial ledger undercount: declared={declared}, rows={len(trials)}")
    return {"card_id": ledger.get("card_id"), "declared_trial_count": declared}


def build_lineage(
    *,
    role: str,
    ea_id: int,
    symbol: str,
    binary_path: Path,
    setfile_path: Path,
    stream_path: Path,
    stream_risk_fixed: float,
    stream_risk_percent: float,
    stream_trade_count: int,
    q10_evidence_path: Path,
    ledger_path: Path | None,
    q07_evidence_path: Path | None,
    q08_evidence_path: Path | None,
    selection_trial_count: int | None,
) -> dict[str, Any]:
    role = role.strip().upper()
    if role not in ROLES:
        raise EmitQ16LineageError(f"role must be one of {sorted(ROLES)}, got {role!r}")

    try:
        q16._set_risk_contract(setfile_path, f"{role} setfile")
    except q16.Q16Error as exc:
        raise EmitQ16LineageError(str(exc)) from exc
    if q16._is_mutable_mt5_storage(stream_path):
        raise EmitQ16LineageError(f"{role} stream resolves to mutable MT5 storage: {stream_path}")
    if (stream_risk_fixed, stream_risk_percent) != (q16.RISK_FIXED, q16.RISK_PERCENT):
        raise EmitQ16LineageError(
            f"{role} stream must be RISK_FIXED={q16.RISK_FIXED}/RISK_PERCENT={q16.RISK_PERCENT}, "
            f"got RISK_FIXED={stream_risk_fixed}/RISK_PERCENT={stream_risk_percent}"
        )
    trade_count = _require_nonneg_int(stream_trade_count, f"{role} stream trade_count")

    lineage: dict[str, Any] = {
        "schema": LINEAGE_SCHEMA,
        "role": role,
        "ea_id": ea_id,
        "symbol": symbol,
        "binary": _binding(binary_path, f"{role} binary"),
        "setfile": _binding(setfile_path, f"{role} setfile"),
        "stream": {
            **_binding(stream_path, f"{role} stream"),
            "frozen": True,
            "risk_fixed": stream_risk_fixed,
            "risk_percent": stream_risk_percent,
            "trade_count": trade_count,
        },
        "q10": _validate_q10_evidence(q10_evidence_path),
    }

    if role != "CHALLENGER":
        return lineage

    if ledger_path is None or q07_evidence_path is None or q08_evidence_path is None:
        raise EmitQ16LineageError("CHALLENGER lineage requires --ledger, --q07-evidence, and --q08-evidence")
    if selection_trial_count is None:
        raise EmitQ16LineageError(
            "CHALLENGER lineage requires --selection-trial-count (pre-registered selection "
            "multiplicity; measurement is not selection -- Plan v2 E0-1)"
        )

    ledger_info = _validate_ledger(ledger_path)
    declared = ledger_info["declared_trial_count"]
    selection_count = _require_positive_int(selection_trial_count, "--selection-trial-count")
    if selection_count > declared:
        raise EmitQ16LineageError(
            f"--selection-trial-count ({selection_count}) cannot exceed the measured trial "
            f"ledger declared_trial_count ({declared})"
        )

    for phase, evidence_path in (("Q07", q07_evidence_path), ("Q08", q08_evidence_path)):
        payload = _read_json(evidence_path, f"{phase} evidence")
        evidence_declared, evidence_observed = _phase_trial_counts(
            payload, phase=phase, label=f"{phase} evidence {evidence_path}"
        )
        if evidence_declared != declared:
            raise EmitQ16LineageError(
                f"{phase} evidence declared_trial_count ({evidence_declared}) differs from the "
                f"trial ledger's declared_trial_count ({declared})"
            )
        if evidence_observed > declared:
            raise EmitQ16LineageError(
                f"{phase} evidence observed_trial_count ({evidence_observed}) exceeds the "
                f"trial ledger's declared_trial_count ({declared})"
            )
        lineage[phase.lower()] = {
            "trial_ledger_declared_count": evidence_declared,
            "observed_trial_count": evidence_observed,
            "selection_trial_count": selection_count,
            "evidence": _binding(evidence_path, f"{phase} evidence"),
        }

    return lineage


def _canonical_text(value: Any) -> str:
    return json.dumps(value, indent=2, sort_keys=True) + "\n"


def _self_check(lineage: Mapping[str, Any], *, role: str, card_path: Path | None, ledger_path: Path | None) -> None:
    """Round-trip the assembled artifact through the real q16 consumer functions."""
    with tempfile.TemporaryDirectory(prefix="emit_q16_lineage_selfcheck_") as tmp:
        check_path = Path(tmp) / "lineage.json"
        check_path.write_text(_canonical_text(lineage), encoding="utf-8")
        try:
            loaded = q16.load_lineage(check_path, role)
            if role == "CHALLENGER":
                if card_path is None or ledger_path is None:
                    raise EmitQ16LineageError(
                        "CHALLENGER self-check requires --card so validate_trial_ledger can run"
                    )
                card_raw = _read_json(card_path, "opt-card")
                q16.validate_trial_ledger(card_raw, ledger_path, loaded)
        except q16.Q16Error as exc:
            raise EmitQ16LineageError(f"assembled lineage fails Q16's own consumer validation: {exc}") from exc


def run_emit_q16_lineage(
    *,
    role: str,
    ea_id: int,
    symbol: str,
    binary_path: Path,
    setfile_path: Path,
    stream_path: Path,
    stream_risk_fixed: float,
    stream_risk_percent: float,
    stream_trade_count: int,
    q10_evidence_path: Path,
    card_path: Path | None,
    ledger_path: Path | None,
    q07_evidence_path: Path | None,
    q08_evidence_path: Path | None,
    selection_trial_count: int | None,
    out_path: Path,
    apply: bool = False,
) -> dict[str, Any]:
    lineage = build_lineage(
        role=role,
        ea_id=ea_id,
        symbol=symbol,
        binary_path=binary_path,
        setfile_path=setfile_path,
        stream_path=stream_path,
        stream_risk_fixed=stream_risk_fixed,
        stream_risk_percent=stream_risk_percent,
        stream_trade_count=stream_trade_count,
        q10_evidence_path=q10_evidence_path,
        ledger_path=ledger_path,
        q07_evidence_path=q07_evidence_path,
        q08_evidence_path=q08_evidence_path,
        selection_trial_count=selection_trial_count,
    )
    _self_check(lineage, role=lineage["role"], card_path=card_path, ledger_path=ledger_path)

    body = _canonical_text(lineage)
    result: dict[str, Any] = {
        "schema": RESULT_SCHEMA,
        "role": lineage["role"],
        "ea_id": lineage["ea_id"],
        "symbol": lineage["symbol"],
        "applied": bool(apply),
        "body_sha256": q16.sha256_bytes(body.encode("utf-8")),
    }
    if apply:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(body, encoding="utf-8")
        result["out_path"] = str(out_path.resolve())
    else:
        result["lineage"] = lineage
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Emit a qm.q16-lineage/v1 artifact from sealed inputs (dry-run default)"
    )
    parser.add_argument("--role", required=True, choices=sorted(ROLES))
    parser.add_argument("--ea-id", required=True, type=int)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--setfile", required=True)
    parser.add_argument("--stream", required=True)
    parser.add_argument("--stream-risk-fixed", required=True, type=float)
    parser.add_argument("--stream-risk-percent", required=True, type=float)
    parser.add_argument("--stream-trade-count", required=True, type=int)
    parser.add_argument("--q10-evidence", required=True)
    parser.add_argument("--card", help="required for --role CHALLENGER (self-check)")
    parser.add_argument("--ledger", help="required for --role CHALLENGER")
    parser.add_argument("--q07-evidence", help="required for --role CHALLENGER")
    parser.add_argument("--q08-evidence", help="required for --role CHALLENGER")
    parser.add_argument("--selection-trial-count", type=int, help="required for --role CHALLENGER")
    parser.add_argument("--out", required=True)
    parser.add_argument("--apply", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = run_emit_q16_lineage(
            role=args.role,
            ea_id=args.ea_id,
            symbol=args.symbol,
            binary_path=Path(args.binary),
            setfile_path=Path(args.setfile),
            stream_path=Path(args.stream),
            stream_risk_fixed=args.stream_risk_fixed,
            stream_risk_percent=args.stream_risk_percent,
            stream_trade_count=args.stream_trade_count,
            q10_evidence_path=Path(args.q10_evidence),
            card_path=Path(args.card) if args.card else None,
            ledger_path=Path(args.ledger) if args.ledger else None,
            q07_evidence_path=Path(args.q07_evidence) if args.q07_evidence else None,
            q08_evidence_path=Path(args.q08_evidence) if args.q08_evidence else None,
            selection_trial_count=args.selection_trial_count,
            out_path=Path(args.out),
            apply=bool(args.apply),
        )
    except EmitQ16LineageError as exc:
        print(json.dumps({"schema": RESULT_SCHEMA, "verdict": "FAIL", "error": str(exc)}, indent=2, sort_keys=True))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
