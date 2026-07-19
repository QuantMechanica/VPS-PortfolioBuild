from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any


LOG = logging.getLogger(__name__)
REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_REGISTRY_PATH = REPO_ROOT / "framework" / "registry" / "live_commission.json"


class CommissionModel:
    def __init__(self, registry_path: str | Path = DEFAULT_REGISTRY_PATH) -> None:
        self.registry_path = Path(registry_path)
        with self.registry_path.open("r", encoding="utf-8") as fh:
            registry = json.load(fh)

        self.classes: dict[str, dict[str, float]] = {
            name: {
                "pct_rate_rt": float(values["pct_rate_rt"]),
                "flat_per_lot_rt": float(values["flat_per_lot_rt"]),
            }
            for name, values in registry["classes"].items()
        }
        self.symbol_class: dict[str, str] = dict(registry["symbol_class"])
        self.default_class: str = str(registry["default_class"])
        self.degraded: bool = False
        self.degraded_symbols: set[str] = set()
        self.unknown_symbols: set[str] = set()

    def cost_round_trip(self, symbol: str, volume: float, notional_acct: float | None) -> float:
        class_name = self._class_for_symbol(symbol)
        rates = self.classes[class_name]
        flat_cost = rates["flat_per_lot_rt"] * float(volume)
        if notional_acct is None:
            self.degraded = True
            self.degraded_symbols.add(symbol)
            return flat_cost
        pct_cost = rates["pct_rate_rt"] * float(notional_acct)
        return max(pct_cost, flat_cost)

    def reset_degraded(self) -> None:
        self.degraded = False
        self.degraded_symbols.clear()

    def _class_for_symbol(self, symbol: str) -> str:
        class_name = self.symbol_class.get(symbol)
        if class_name is None:
            class_name = self.default_class
            if symbol not in self.unknown_symbols:
                LOG.warning(
                    "Unknown commission symbol %s; using default class %s",
                    symbol,
                    class_name,
                )
                self.unknown_symbols.add(symbol)
        if class_name not in self.classes:
            raise ValueError(f"commission class {class_name!r} for {symbol!r} is not defined")
        return class_name


def load_model(registry_path: str | Path = DEFAULT_REGISTRY_PATH) -> CommissionModel:
    return CommissionModel(registry_path)


def describe_model(model: CommissionModel) -> dict[str, Any]:
    return {
        "registry_path": str(model.registry_path),
        "default_class": model.default_class,
        "degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "unknown_symbols": sorted(model.unknown_symbols),
    }
