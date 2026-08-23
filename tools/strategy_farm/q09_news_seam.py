"""Pure Q09 contract-v3 full-window reconstruction.

Contract v3 executes the sealed selection and holdout windows and derives the
contiguous full-window metrics from their authenticated daily equity streams.
It changes evidence production cost only; Q09 selection thresholds stay in
``q09_news_contract``.
"""

from __future__ import annotations

import json
import math
import statistics
from pathlib import Path
from typing import Any, Mapping


SEAM_ERROR_BOUND_PCT = 0.584
SEAM_ERROR_SOURCE = "pilot_46409fc4_carry_forward"


class SeamError(ValueError):
    """Raised when two authenticated window streams cannot form one seam."""


def equity_snapshots(path: Path) -> list[tuple[int, float]]:
    """Read the ordered, account-scope daily equity series from a logger JSONL."""

    snapshots: list[tuple[int, float]] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise SeamError(f"cannot read logger sample {path}: {exc}") from exc
    for line_number, line in enumerate(lines, 1):
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise SeamError(f"invalid logger JSON at {path}:{line_number}") from exc
        if not isinstance(row, Mapping) or row.get("event") != "EQUITY_SNAPSHOT":
            continue
        payload = row.get("payload")
        if not isinstance(payload, Mapping) or payload.get("scope") not in (None, "account"):
            continue
        try:
            day = int(payload["day_key"])
            equity = float(payload["equity"])
        except (KeyError, TypeError, ValueError) as exc:
            raise SeamError(f"malformed equity snapshot at {path}:{line_number}") from exc
        if not math.isfinite(equity) or equity <= 0:
            raise SeamError(f"non-positive/non-finite equity at {path}:{line_number}")
        if snapshots and day <= snapshots[-1][0]:
            raise SeamError(f"equity snapshot days are not strictly increasing: {path}")
        snapshots.append((day, equity))
    if not snapshots:
        raise SeamError(f"logger sample has no account equity snapshots: {path}")
    return snapshots


def _drawdown_pct(equities: list[float]) -> float:
    peak = equities[0]
    worst = 0.0
    for equity in equities:
        peak = max(peak, equity)
        worst = max(worst, (peak - equity) / peak * 100.0)
    return worst


def _daily_sharpe(equities: list[float]) -> float:
    returns = [
        (current / previous) - 1.0
        for previous, current in zip(equities, equities[1:])
        if previous > 0
    ]
    if len(returns) < 2 or statistics.stdev(returns) == 0:
        return 0.0
    return statistics.fmean(returns) / statistics.stdev(returns) * math.sqrt(252.0)


def reconstruct_full_metrics(
    selection: Mapping[str, Any],
    holdout: Mapping[str, Any],
    *,
    selection_logger_path: Path,
    holdout_logger_path: Path,
    selection_gross_profit: float,
    selection_gross_loss: float,
    holdout_gross_profit: float,
    holdout_gross_loss: float,
) -> dict[str, Any]:
    """Return v3 full metrics plus explicit seam provenance."""

    selection_series = equity_snapshots(selection_logger_path)
    holdout_series = equity_snapshots(holdout_logger_path)
    if selection_series[-1][0] >= holdout_series[0][0]:
        raise SeamError("selection/holdout equity streams overlap or are reversed")
    offset = selection_series[-1][1] - holdout_series[0][1]
    combined = [equity for _, equity in selection_series] + [
        equity + offset for _, equity in holdout_series
    ]
    if any(equity <= 0 for equity in combined):
        raise SeamError("seam offset produced non-positive equity")

    gross_profit = float(selection_gross_profit) + float(holdout_gross_profit)
    gross_loss = float(selection_gross_loss) + float(holdout_gross_loss)
    if not all(math.isfinite(value) for value in (gross_profit, gross_loss)):
        raise SeamError("gross profit/loss seam inputs must be finite")
    loss_magnitude = abs(gross_loss)
    profit_factor = gross_profit / loss_magnitude if loss_magnitude else (999.0 if gross_profit > 0 else 0.0)

    additive = ("trades", "original_entries", "blocked_entries", "affected_entries")
    metrics: dict[str, Any] = {
        key: int(selection[key]) + int(holdout[key]) for key in additive
    }
    metrics.update({
        "profit_factor": profit_factor,
        "drawdown_pct": _drawdown_pct(combined),
        "sharpe": _daily_sharpe(combined),
        "net_r": float(selection["net_r"]) + float(holdout["net_r"]),
    })
    return {
        "metrics": metrics,
        "seam_reconstructed": True,
        "full_window_synthesized": True,
        "selection_snapshot_count": len(selection_series),
        "holdout_snapshot_count": len(holdout_series),
        "equity_offset": offset,
        "seam_net_profit_error_bound_pct": SEAM_ERROR_BOUND_PCT,
        "seam_error_source": SEAM_ERROR_SOURCE,
        "selection_logger_path": str(selection_logger_path.resolve()),
        "holdout_logger_path": str(holdout_logger_path.resolve()),
    }
