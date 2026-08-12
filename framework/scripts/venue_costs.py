"""Per-symbol venue cost model for Q04 walk-forward grading (DL-082 §2).

Reads ``framework/registry/venue_cost_model.json`` — the OWNER-ratified 2026-07-19
per-symbol, per-venue round-trip commission truth (built on ``live_commission.json``
+ the DXZ tester Groups schedule + FTMO published rates). It replaces the legacy
flat ``$7/lot`` Q04 cost input (``q04_walkforward.py`` line 41) with the real venue
schedule, in three selectable variants:

  ``dxz``  (default) : ``max(DXZ, FTMO)`` worst-case per round-trip lot
                       (``worst_case_rt_per_lot_usd``). %-of-notional instruments
                       (forex, commodity) are computed from the 0.5 bp convention
                       against the trade's real notional when the caller has that
                       context; flat margin-ccy instruments (indices) use the
                       per-symbol USD-equivalent per-lot. This is the gate default.
  ``ftmo``           : the FTMO side of the model — ``$0`` indices / ``$0`` energy,
                       ``$5`` flat forex, %-notional metals.
  ``flat7``          : legacy flat ``$7/lot`` round-trip — reproduction only.

DL-082 §2 is an INPUT correction, not a threshold change: the fold thresholds and
all fold logic in ``q04_walkforward.py`` are untouched; only the per-trade cost fed
into PF-net changes.

Fallback discipline (OWNER: "never silently $0, never invent"): a symbol that is
missing from the model, or whose variant figure is ``null``, falls back to the
class-conservative value — the MAX per-symbol ``worst_case_rt_per_lot_usd`` inside
that asset class (forex ~$6.35, index ~$6.99, commodity ~$20.37: all real,
model-sourced, non-zero, and the harshest = never under-costs) — and emits a WARN
line naming the symbol. FTMO's genuine ``$0`` (commission-free indices/energy) is a
REAL venue rate, not a missing-data ``$0``, so it is used as-is.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL_PATH = REPO_ROOT / "framework" / "registry" / "venue_cost_model.json"

# 0.5 bp round-trip; the shared convention across DXZ %-notional instruments and the
# live_commission.json class model. Used when the class model cannot be read.
_FALLBACK_PCT_RATE_RT = 0.00005
_FALLBACK_CLASS_FLAT = {"forex": 5.0, "index": 5.5, "commodity": 0.0}
# Ultimate never-$0 conservative per-lot if the model cannot be scanned at all.
_HARD_CONSERVATIVE_PER_LOT = 7.0

VALID_VARIANTS = ("dxz", "ftmo", "flat7")
FLAT7_PER_LOT = 7.00  # legacy reproduction constant


def _warn(msg: str) -> None:
    print(f"WARN venue_costs: {msg}", file=sys.stderr)


class VenueCostModel:
    """Per-symbol round-trip commission, sourced from venue_cost_model.json.

    Loading is lenient: any failure degrades to the class model constants (never a
    crash inside a Q04 fold). Warnings for missing/null symbols are de-duplicated so
    a per-trade loop does not spam the log.
    """

    def __init__(self, model_path: str | Path = DEFAULT_MODEL_PATH) -> None:
        self.model_path = Path(model_path)
        self.generated = "unknown"
        self.degraded = False
        self._symbols: dict[str, dict] = {}   # resolution index (upper-cased keys)
        self._entries: dict[str, dict] = {}    # canonical entry name -> entry
        self._pct_rate: dict[str, float] = dict(
            (cls, _FALLBACK_PCT_RATE_RT) for cls in _FALLBACK_CLASS_FLAT
        )
        self._class_flat: dict[str, float] = dict(_FALLBACK_CLASS_FLAT)
        self._class_conservative: dict[str, float] = {}
        self._warned: set[str] = set()
        try:
            self._load()
        except Exception as exc:  # never let a cost lookup crash a fold
            self.degraded = True
            _warn(f"could not load {self.model_path.name} ({exc!r}); "
                  f"degraded to class-model constants")

    # -- loading -----------------------------------------------------------
    def _load(self) -> None:
        data = json.loads(self.model_path.read_text(encoding="utf-8-sig"))
        self.generated = str(data.get("generated") or "unknown")

        class_model = ((data.get("canonical_engine") or {}).get("class_model")) or {}
        for cls, vals in class_model.items():
            try:
                self._pct_rate[cls] = float(vals["pct_rate_rt"])
                self._class_flat[cls] = float(vals["flat_per_lot_rt"])
            except (KeyError, TypeError, ValueError):
                continue

        symbols = data.get("symbols") or {}
        # First pass: register canonical entries and their .DWX aliases.
        for name, entry in symbols.items():
            if not isinstance(entry, dict):
                continue
            self._entries[name.upper()] = entry
            self._symbols[name.upper()] = entry
            dwx = entry.get("dwx_symbol")
            if dwx:
                self._symbols[str(dwx).upper()] = entry
        # Second pass: resolve alias_of -> target entry.
        for name, entry in symbols.items():
            alias = entry.get("alias_of") if isinstance(entry, dict) else None
            if alias:
                target = self._entries.get(str(alias).upper())
                if target is not None:
                    self._symbols[name.upper()] = target
                    dwx = entry.get("dwx_symbol")
                    if dwx:
                        self._symbols[str(dwx).upper()] = target

        # Per-class conservative = MAX per-symbol worst_case within the class.
        by_class: dict[str, list[float]] = {}
        for entry in self._entries.values():
            cls = entry.get("asset_class")
            wc = entry.get("worst_case_rt_per_lot_usd")
            if cls and isinstance(wc, (int, float)):
                by_class.setdefault(cls, []).append(float(wc))
        for cls, vals in by_class.items():
            self._class_conservative[cls] = max(vals)

    # -- resolution --------------------------------------------------------
    def resolve(self, symbol: str) -> tuple[dict | None, str]:
        """Return (entry_or_None, asset_class). Handles .DWX suffix + aliases."""
        up = str(symbol).upper().strip()
        entry = self._symbols.get(up)
        if entry is None and up.endswith(".DWX"):
            entry = self._symbols.get(up[:-4])
        if entry is not None:
            return entry, str(entry.get("asset_class") or self._class_for(up))
        return None, self._class_for(up)

    def _class_for(self, up: str) -> str:
        """Best-effort asset class for an unmodeled symbol (default forex)."""
        base = up[:-4] if up.endswith(".DWX") else up
        if base in ("XAUUSD", "XAGUSD", "XPTUSD", "XPDUSD"):
            return "commodity"
        if base in ("XTIUSD", "XBRUSD", "XNGUSD", "USOIL", "UKOIL"):
            return "commodity"
        if base in ("NDX", "SP500", "US100", "US500", "US30", "WS30",
                    "GDAXI", "GER40", "UK100", "DJ30", "NAS100"):
            return "index"
        return "forex"

    def _conservative_per_lot(self, asset_class: str) -> float:
        val = self._class_conservative.get(asset_class)
        if val is None:
            # No modeled worst-case for the class -> class flat, but never $0.
            val = self._class_flat.get(asset_class, 0.0)
        if not val:
            val = max(self._class_flat.get(asset_class, 0.0),
                      _HARD_CONSERVATIVE_PER_LOT)
        return float(val)

    def _warn_once(self, key: str, msg: str) -> None:
        if key not in self._warned:
            self._warned.add(key)
            _warn(msg)

    # -- FTMO helpers ------------------------------------------------------
    @staticmethod
    def _ftmo_model(entry: dict) -> str:
        return str((entry.get("ftmo") or {}).get("commission_model") or "")

    def _ftmo_per_lot(self, entry: dict) -> float | None:
        ftmo = entry.get("ftmo") or {}
        model = self._ftmo_model(entry)
        if model == "commission_free":
            return 0.0
        for key in ("commission_rt_per_lot_usd", "commission_rt_per_lot_usd_indicative"):
            v = ftmo.get(key)
            if isinstance(v, (int, float)):
                return float(v)
        return None

    # -- public API --------------------------------------------------------
    def per_lot_rt(self, symbol: str, variant: str = "dxz") -> float:
        """A single per-lot round-trip USD figure (EA-side flat injection + the
        provenance headline). %-notional symbols return their indicative per-lot."""
        variant = variant.lower()
        if variant == "flat7":
            return FLAT7_PER_LOT
        entry, asset_class = self.resolve(symbol)
        if entry is None:
            per_lot = self._conservative_per_lot(asset_class)
            self._warn_once(
                f"{symbol}:{variant}",
                f"symbol {symbol} missing in venue_cost_model.json (variant "
                f"{variant}); fell back to {asset_class} class-conservative "
                f"${per_lot:.2f}/lot",
            )
            return per_lot
        if variant == "ftmo":
            val = self._ftmo_per_lot(entry)
            if val is None:
                per_lot = self._conservative_per_lot(asset_class)
                self._warn_once(
                    f"{symbol}:ftmo",
                    f"symbol {symbol} has no FTMO per-lot figure; fell back to "
                    f"{asset_class} class-conservative ${per_lot:.2f}/lot",
                )
                return per_lot
            return val
        # dxz (default): worst-case per-lot.
        wc = entry.get("worst_case_rt_per_lot_usd")
        if not isinstance(wc, (int, float)):
            per_lot = self._conservative_per_lot(asset_class)
            self._warn_once(
                f"{symbol}:dxz",
                f"symbol {symbol} has null worst_case_rt_per_lot_usd; fell back to "
                f"{asset_class} class-conservative ${per_lot:.2f}/lot",
            )
            return per_lot
        return float(wc)

    def cost_round_trip(self, symbol: str, volume: float,
                        notional_acct: float | None, variant: str = "dxz") -> float:
        """Realistic per-trade round-trip cost (USD) for the stream grading path.

        %-of-notional instruments use ``max(pct_rate*notional, flat_floor*vol)`` when
        notional is available (faithful to the venue convention and scales with the
        real trade price); flat margin-ccy indices use ``per_lot*vol``. When notional
        is missing the indicative per-lot ``per_lot_rt`` is used * volume.
        """
        variant = variant.lower()
        try:
            volume = float(volume)
        except (TypeError, ValueError):
            volume = 0.0
        if variant == "flat7":
            return FLAT7_PER_LOT * volume

        entry, asset_class = self.resolve(symbol)
        pct = self._pct_rate.get(asset_class, _FALLBACK_PCT_RATE_RT)

        if entry is None:
            # Class-model max(); never $0 for real notional. Flat floor guarded so a
            # missing commodity (flat $0) still costs a conservative per-lot.
            flat_floor = self._class_flat.get(asset_class, 0.0)
            if notional_acct is not None:
                cost = max(pct * float(notional_acct), flat_floor * volume)
                if cost <= 0:
                    cost = self._conservative_per_lot(asset_class) * volume
            else:
                cost = self._conservative_per_lot(asset_class) * volume
            self._warn_once(
                f"{symbol}:{variant}:stream",
                f"symbol {symbol} missing in venue_cost_model.json (variant "
                f"{variant}); graded at {asset_class} class-conservative model",
            )
            return cost

        if variant == "ftmo":
            model = self._ftmo_model(entry)
            if model == "commission_free":
                return 0.0  # real FTMO rate (indices / energy), not missing-data $0
            if "pct_notional" in model:  # FTMO metals
                if notional_acct is not None:
                    return pct * float(notional_acct)
                return self.per_lot_rt(symbol, "ftmo") * volume
            # flat_per_lot_rt (forex) or anything else with a per-lot figure
            return self.per_lot_rt(symbol, "ftmo") * volume

        # dxz (default)
        dxz_model = str((entry.get("dxz") or {}).get("commission_model") or "")
        if "pct_notional" in dxz_model:  # forex / commodity
            flat_floor = self._class_flat.get(asset_class, 0.0)
            if notional_acct is not None:
                return max(pct * float(notional_acct), flat_floor * volume)
            return self.per_lot_rt(symbol, "dxz") * volume
        # flat_margin_ccy / flat_margin_ccy_or_pct (indices): per-symbol USD flat/lot.
        return self.per_lot_rt(symbol, "dxz") * volume

    def source_tag(self) -> str:
        return f"venue_cost_model.json {self.generated}"


_MODEL_CACHE: dict[str, VenueCostModel] = {}


def load_venue_model(model_path: str | Path = DEFAULT_MODEL_PATH) -> VenueCostModel:
    """Cached loader (one instance per path so warnings de-dupe across a run)."""
    key = str(model_path)
    model = _MODEL_CACHE.get(key)
    if model is None:
        model = VenueCostModel(model_path)
        _MODEL_CACHE[key] = model
    return model
