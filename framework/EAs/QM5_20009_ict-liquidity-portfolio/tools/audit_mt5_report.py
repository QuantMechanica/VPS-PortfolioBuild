"""Fail-closed native MT5 report audit for QM5_20009 DEV1 research.

The Strategy Tester must emit a zero-commission report.  This tool binds the
native report and its semantic deal stream, reconstructs closed positions, and
then applies the frozen conservative USD commission schedule exactly once.

No MT5 process is started and no tester input is changed by this module.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import unicodedata
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, getcontext
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


getcontext().prec = 34

SCHEMA_VERSION = 1
EXPECTED_EXPERT = "QM5_20009_ict-liquidity-portfolio"
MONEY = Decimal("0.01")
ZERO = Decimal("0")

SUPPORTED_MARKETS: dict[str, dict[str, str]] = {
    "NDX.DWX": {"family": "NDX", "timeframe": "M1"},
    "GDAXI.DWX": {"family": "GDAXI", "timeframe": "M1"},
    "EURUSD.DWX": {"family": "EURUSD", "timeframe": "M5"},
    "GBPUSD.DWX": {"family": "GBPUSD", "timeframe": "M5"},
}


class AuditError(RuntimeError):
    """Base class for a fail-closed report rejection."""


class ReportFormatError(AuditError):
    """The native report cannot be interpreted without guessing."""


class IntegrityError(AuditError):
    """The native report is internally inconsistent or violates its contract."""


class DuplicateFingerprintDrift(IntegrityError):
    """Nominal duplicate reports do not have the same semantic identity."""


class _TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._cell_parts: list[str] | None = None

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        del attrs
        lowered = tag.lower()
        if lowered == "tr":
            self._row = []
        elif lowered in {"td", "th"} and self._row is not None:
            self._cell_parts = []

    def handle_data(self, data: str) -> None:
        if self._cell_parts is not None:
            self._cell_parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        lowered = tag.lower()
        if lowered in {"td", "th"} and self._row is not None:
            if self._cell_parts is not None:
                self._row.append(_clean_text("".join(self._cell_parts)))
            self._cell_parts = None
        elif lowered == "tr" and self._row is not None:
            self.rows.append(self._row)
            self._row = None
            self._cell_parts = None


@dataclass(frozen=True)
class Deal:
    sequence: int
    time: datetime
    deal: str
    symbol: str
    kind: str
    direction: str
    volume: Decimal | None
    price: Decimal | None
    order: str
    commission: Decimal
    swap: Decimal
    profit: Decimal
    balance: Decimal
    comment: str

    @property
    def raw_net(self) -> Decimal:
        return self.profit + self.swap + self.commission

    def canonical(self) -> dict[str, Any]:
        return {
            "sequence": self.sequence,
            "time": self.time.strftime("%Y-%m-%dT%H:%M:%S"),
            "deal": self.deal,
            "symbol": self.symbol,
            "type": self.kind,
            "direction": self.direction,
            "volume": _decimal_canonical(self.volume),
            "price": _decimal_canonical(self.price),
            "order": self.order,
            "commission": _decimal_canonical(self.commission),
            "swap": _decimal_canonical(self.swap),
            "profit": _decimal_canonical(self.profit),
            "balance": _decimal_canonical(self.balance),
            "comment": self.comment,
        }


@dataclass
class _OpenLot:
    deal: Deal
    remaining_volume: Decimal
    remaining_profit: Decimal
    remaining_swap: Decimal
    remaining_commission: Decimal
    remaining_external_cost: Decimal


def _clean_text(value: str) -> str:
    return " ".join(value.replace("\xa0", " ").replace("\u202f", " ").split())


def _norm(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", _clean_text(value))
    asciiish = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    asciiish = asciiish.casefold().replace("ß", "ss").strip().rstrip(":").strip()
    return re.sub(r"\s+", " ", asciiish)


def _alias_set(*values: str) -> frozenset[str]:
    return frozenset(_norm(value) for value in values)


FIELD_ALIASES: dict[str, frozenset[str]] = {
    "expert": _alias_set("Expert", "Experte"),
    "symbol": _alias_set("Symbol"),
    "period": _alias_set("Period", "Periode", "Zeitraum"),
    "inputs": _alias_set("Inputs", "Eingaben", "Eingabeparameter", "Parameter"),
    "currency": _alias_set("Currency", "Währung", "Waehrung", "Kontowährung"),
    "deposit": _alias_set(
        "Initial Deposit", "Ersteinzahlung", "Anfangseinlage", "Startkapital"
    ),
    "net_profit": _alias_set(
        "Total Net Profit", "Gesamtnettogewinn", "Gesamtnettoprofit"
    ),
    "gross_profit": _alias_set("Gross Profit", "Bruttogewinn"),
    "gross_loss": _alias_set("Gross Loss", "Bruttoverlust"),
    "profit_factor": _alias_set("Profit Factor", "Profitfaktor", "Gewinnfaktor"),
    "total_trades": _alias_set(
        "Total Trades", "Trades gesamt", "Gesamtzahl Trades", "Trades insgesamt"
    ),
}

# MT5 serializes input-group headings as ``Heading=`` in native reports.  Most
# frozen QM5_20009 headings cannot be confused with a real MQL input because
# they contain spaces or punctuation.  These two headings are valid MQL
# identifiers, however, so their exact spellings are pinned explicitly rather
# than treating every empty value as a heading.
PINNED_IDENTIFIER_INPUT_GROUP_HEADINGS = frozenset({"Risk", "Stress"})

DEALS_SECTION = _alias_set("Deals", "Geschäfte", "Geschaefte", "Abschlüsse", "Abschluesse")
ORDERS_SECTION = _alias_set("Orders", "Aufträge", "Auftraege")

DEAL_COLUMN_ALIASES: dict[str, frozenset[str]] = {
    "time": _alias_set("Time", "Zeit"),
    "deal": _alias_set("Deal", "Geschäft", "Geschaeft", "Abschluss"),
    "symbol": _alias_set("Symbol"),
    "type": _alias_set("Type", "Typ", "Art"),
    "direction": _alias_set("Direction", "Richtung"),
    "volume": _alias_set("Volume", "Volumen"),
    "price": _alias_set("Price", "Preis", "Kurs"),
    "order": _alias_set("Order", "Auftrag"),
    "commission": _alias_set("Commission", "Kommission", "Provision"),
    "swap": _alias_set("Swap"),
    "profit": _alias_set("Profit", "Gewinn", "Ergebnis"),
    "balance": _alias_set("Balance", "Kontostand", "Saldo"),
    "comment": _alias_set("Comment", "Kommentar"),
}

TYPE_ALIASES = {
    **{value: "buy" for value in _alias_set("buy", "Kauf")},
    **{value: "sell" for value in _alias_set("sell", "Verkauf")},
    **{
        value: "balance"
        for value in _alias_set("balance", "Kontostand", "Saldo", "Einzahlung")
    },
}

DIRECTION_ALIASES = {
    **{value: "in" for value in _alias_set("in", "ein", "Eingang")},
    **{value: "out" for value in _alias_set("out", "aus", "Ausgang")},
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _canonical_sha256(value: Any) -> str:
    raw = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _looks_utf16(raw: bytes, *, odd: bool) -> bool:
    if len(raw) < 8:
        return False
    sample = raw[: min(len(raw), 1024)]
    selected = sample[1::2] if odd else sample[0::2]
    other = sample[0::2] if odd else sample[1::2]
    return selected.count(0) > len(selected) // 4 and selected.count(0) > other.count(0) * 3


def _read_html(path: Path) -> str:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ReportFormatError(f"cannot read report {path}: {exc}") from exc
    if not raw:
        raise ReportFormatError(f"empty report: {path}")
    candidates: list[str] = []
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        candidates.append("utf-16")
    if raw.startswith(b"\xef\xbb\xbf"):
        candidates.append("utf-8-sig")
    if _looks_utf16(raw, odd=True):
        candidates.append("utf-16-le")
    if _looks_utf16(raw, odd=False):
        candidates.append("utf-16-be")
    candidates.extend(("utf-8-sig", "utf-8", "utf-16", "utf-16-le", "utf-16-be"))
    for encoding in dict.fromkeys(candidates):
        try:
            text = raw.decode(encoding)
        except UnicodeError:
            continue
        lowered = text.casefold()
        if "<html" in lowered and "<table" in lowered:
            return text
    raise ReportFormatError(f"report is not recognizable UTF-8/UTF-16 MT5 HTML: {path}")


def _rows(path: Path) -> list[list[str]]:
    parser = _TableParser()
    try:
        parser.feed(_read_html(path))
        parser.close()
    except Exception as exc:  # HTMLParser itself is permissive; fail on custom surprises.
        raise ReportFormatError(f"cannot parse HTML table rows in {path}: {exc}") from exc
    if not parser.rows:
        raise ReportFormatError(f"no HTML table rows in {path}")
    return parser.rows


def _settings_rows(rows: Sequence[Sequence[str]]) -> Sequence[Sequence[str]]:
    """Return only rows before the unique Deals section.

    Deal column names intentionally overlap settings labels (notably Symbol),
    so header discovery must be scoped instead of taking the first plausible
    value from the whole document.
    """

    deal_indices: list[int] = []
    detail_indices: list[int] = []
    for index, row in enumerate(rows):
        nonempty = [cell for cell in row if _clean_text(cell)]
        if len(nonempty) != 1:
            continue
        normalized = _norm(nonempty[0])
        if normalized in DEALS_SECTION:
            deal_indices.append(index)
            detail_indices.append(index)
        elif normalized in ORDERS_SECTION:
            detail_indices.append(index)
    if len(deal_indices) != 1:
        raise ReportFormatError(
            f"expected one Deals section, found {len(deal_indices)}"
        )
    # Native MT5 puts Orders before Deals.  Both tables contain a Symbol
    # header, so settings lookup must stop at the first detail table.
    return rows[: min(detail_indices)]


def _field_value(rows: Sequence[Sequence[str]], name: str, *, required: bool = True) -> str | None:
    aliases = FIELD_ALIASES[name]
    matches: list[str] = []
    for row in rows:
        for index, cell in enumerate(row):
            if _norm(cell) not in aliases:
                continue
            value = next((_clean_text(item) for item in row[index + 1 :] if _clean_text(item)), "")
            if value:
                matches.append(value)
    if not matches:
        if required:
            raise ReportFormatError(f"missing report field: {name}")
        return None
    if len(set(matches)) != 1:
        raise ReportFormatError(f"ambiguous report field {name}: {matches!r}")
    return matches[0]


def _parse_decimal(value: str, label: str) -> Decimal:
    cleaned = _clean_text(value)
    match = re.fullmatch(r"([+-]?)\s*([0-9][0-9\s\u00a0\u202f.,]*)(?:\s*%)?", cleaned)
    if not match:
        raise ReportFormatError(f"{label} is not an unambiguous decimal: {value!r}")
    sign, digits = match.groups()
    digits = digits.replace(" ", "").replace("\xa0", "").replace("\u202f", "")
    if "," in digits and "." in digits:
        decimal_sep = "," if digits.rfind(",") > digits.rfind(".") else "."
        thousands_sep = "." if decimal_sep == "," else ","
        digits = digits.replace(thousands_sep, "").replace(decimal_sep, ".")
    elif "," in digits:
        if digits.count(",") > 1:
            head, tail = digits.rsplit(",", 1)
            digits = head.replace(",", "") + "." + tail
        else:
            digits = digits.replace(",", ".")
    elif digits.count(".") > 1:
        head, tail = digits.rsplit(".", 1)
        digits = head.replace(".", "") + "." + tail
    try:
        parsed = Decimal(sign + digits)
    except InvalidOperation as exc:
        raise ReportFormatError(f"{label} is not numeric: {value!r}") from exc
    if not parsed.is_finite():
        raise ReportFormatError(f"{label} is not finite: {value!r}")
    return parsed


def _parse_optional_decimal(value: str, label: str) -> Decimal | None:
    return None if not _clean_text(value) else _parse_decimal(value, label)


def _money(value: Decimal) -> Decimal:
    return value.quantize(MONEY, rounding=ROUND_HALF_UP)


def _money_string(value: Decimal) -> str:
    return format(_money(value), ".2f")


def _decimal_canonical(value: Decimal | None) -> str | None:
    if value is None:
        return None
    if value == ZERO:
        return "0"
    rendered = format(value, "f")
    if "." in rendered:
        rendered = rendered.rstrip("0").rstrip(".")
    return rendered


def _decimal_string(value: Decimal, places: int = 8) -> str:
    quantum = Decimal(1).scaleb(-places)
    return format(value.quantize(quantum, rounding=ROUND_HALF_UP), f".{places}f")


def _extract_inputs(rows: Sequence[Sequence[str]]) -> tuple[list[str], dict[str, str]]:
    start: tuple[int, int] | None = None
    for row_index, row in enumerate(rows):
        for cell_index, cell in enumerate(row):
            if _norm(cell) in FIELD_ALIASES["inputs"]:
                if start is not None:
                    raise ReportFormatError("multiple Inputs sections")
                start = (row_index, cell_index)
    if start is None:
        raise ReportFormatError("missing Inputs section")
    row_index, cell_index = start
    values = [_clean_text(value) for value in rows[row_index][cell_index + 1 :] if _clean_text(value)]
    for row in rows[row_index + 1 :]:
        if row and _clean_text(row[0]):
            break
        values.extend(_clean_text(value) for value in row[1:] if _clean_text(value))
    if not values:
        raise ReportFormatError("Inputs section is empty")

    mapping: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            continue
        key, raw_value = value.split("=", 1)
        key = key.strip()
        raw_value = raw_value.strip()
        if not raw_value and key in PINNED_IDENTIFIER_INPUT_GROUP_HEADINGS:
            continue
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            continue  # Not a syntactically possible MQL input identifier.
        if key in mapping:
            raise ReportFormatError(f"duplicate report input: {key}")
        mapping[key] = raw_value
    for required in ("qm_ea_id", "InpQMSimCommissionPerLot"):
        if required not in mapping:
            raise IntegrityError(f"required report input is missing: {required}")
    try:
        ea_id = int(mapping["qm_ea_id"])
    except ValueError as exc:
        raise IntegrityError("qm_ea_id is not an integer") from exc
    if ea_id != 20009:
        raise IntegrityError(f"wrong EA id in report Inputs: {ea_id}")
    if _parse_decimal(mapping["InpQMSimCommissionPerLot"], "InpQMSimCommissionPerLot") != ZERO:
        raise IntegrityError("DOUBLE_COUNT_REJECT: InpQMSimCommissionPerLot is not zero")
    return values, mapping


def _parse_period(value: str) -> tuple[str, date, date]:
    match = re.fullmatch(
        r"\s*([A-Za-z][A-Za-z0-9]*)\s*\(\s*"
        r"(\d{4}[./-]\d{2}[./-]\d{2})\s*[-–—]\s*"
        r"(\d{4}[./-]\d{2}[./-]\d{2})\s*\)\s*",
        value,
    )
    if not match:
        raise ReportFormatError(f"Period does not contain a bounded MT5 date window: {value!r}")
    timeframe, start_raw, end_raw = match.groups()
    try:
        start = date.fromisoformat(start_raw.replace(".", "-").replace("/", "-"))
        end = date.fromisoformat(end_raw.replace(".", "-").replace("/", "-"))
    except ValueError as exc:
        raise ReportFormatError(f"invalid Period date window: {value!r}") from exc
    if start > end:
        raise IntegrityError("report Period starts after it ends")
    return timeframe.upper(), start, end


def _canonical_expert(value: str) -> str:
    candidate = value.replace("/", "\\").rsplit("\\", 1)[-1]
    if candidate.casefold().endswith(".ex5"):
        candidate = candidate[:-4]
    return candidate


def _column_name(value: str) -> str | None:
    normalized = _norm(value)
    matches = [name for name, aliases in DEAL_COLUMN_ALIASES.items() if normalized in aliases]
    if len(matches) > 1:
        raise ReportFormatError(f"ambiguous Deals column: {value!r}")
    return matches[0] if matches else None


def _parse_time(value: str, label: str) -> datetime:
    try:
        return datetime.strptime(_clean_text(value), "%Y.%m.%d %H:%M:%S")
    except ValueError as exc:
        raise ReportFormatError(f"{label} is not MT5 server time: {value!r}") from exc


def _new_york_date_from_broker(value: datetime) -> date:
    """Match the frozen V5 broker-clock contract used by the EA.

    QM_DSTAware defines broker time as UTC+2 outside US DST and UTC+3 during
    US DST.  New York is UTC-5/UTC-4 on the same US boundaries, so the
    historical broker-to-New-York wall-clock delta is invariantly seven hours.
    """

    return (value - timedelta(hours=7)).date()


def _numeric_id(value: str, label: str, *, allow_empty: bool = False) -> str:
    cleaned = _clean_text(value).replace(" ", "")
    if allow_empty and not cleaned:
        return ""
    if not re.fullmatch(r"\d+", cleaned):
        raise ReportFormatError(f"{label} is not a numeric MT5 identifier: {value!r}")
    return str(int(cleaned))


def _parse_deals(rows: Sequence[Sequence[str]]) -> list[Deal]:
    section_index: int | None = None
    for index, row in enumerate(rows):
        nonempty = [cell for cell in row if _clean_text(cell)]
        if len(nonempty) == 1 and _norm(nonempty[0]) in DEALS_SECTION:
            if section_index is not None:
                raise ReportFormatError("multiple Deals sections")
            section_index = index
    if section_index is None:
        raise ReportFormatError("Deals table is missing")

    header_index: int | None = None
    columns: list[str] = []
    for index in range(section_index + 1, len(rows)):
        mapped = [_column_name(cell) for cell in rows[index]]
        if "time" in mapped and "deal" in mapped and "commission" in mapped:
            if any(value is None for value in mapped):
                raise ReportFormatError(f"unknown Deals column(s): {rows[index]!r}")
            columns = [str(value) for value in mapped]
            if len(set(columns)) != len(columns):
                raise ReportFormatError(f"duplicate Deals columns: {columns!r}")
            header_index = index
            break
    if header_index is None:
        raise ReportFormatError("Deals header row is missing")
    required = set(DEAL_COLUMN_ALIASES)
    if set(columns) != required:
        missing = sorted(required - set(columns))
        extra = sorted(set(columns) - required)
        raise ReportFormatError(f"Deals columns are not exact; missing={missing}, extra={extra}")

    deals: list[Deal] = []
    seen_ids: set[str] = set()
    for row in rows[header_index + 1 :]:
        if not row or not any(_clean_text(cell) for cell in row):
            continue
        first = _clean_text(row[0])
        if not re.fullmatch(r"\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}", first):
            continue
        if len(row) != len(columns):
            raise ReportFormatError(
                f"Deals data row has {len(row)} cells, expected {len(columns)}: {row!r}"
            )
        raw = dict(zip(columns, row))
        deal_id = _numeric_id(raw["deal"], "Deal")
        if deal_id in seen_ids:
            raise IntegrityError(f"duplicate Deal identifier: {deal_id}")
        seen_ids.add(deal_id)
        raw_type = _norm(raw["type"])
        kind = TYPE_ALIASES.get(raw_type)
        if kind is None:
            raise ReportFormatError(f"unsupported Deal Type: {raw['type']!r}")
        raw_direction = _norm(raw["direction"])
        direction = DIRECTION_ALIASES.get(raw_direction, "" if not raw_direction else "?")
        if direction == "?":
            raise ReportFormatError(f"unsupported Deal Direction: {raw['direction']!r}")
        deals.append(
            Deal(
                sequence=len(deals) + 1,
                time=_parse_time(raw["time"], "Deal Time"),
                deal=deal_id,
                symbol=_clean_text(raw["symbol"]).upper(),
                kind=kind,
                direction=direction,
                volume=_parse_optional_decimal(raw["volume"], "Deal Volume"),
                price=_parse_optional_decimal(raw["price"], "Deal Price"),
                order=_numeric_id(raw["order"], "Deal Order", allow_empty=True),
                commission=_parse_decimal(raw["commission"], "Deal Commission"),
                swap=_parse_decimal(raw["swap"], "Deal Swap"),
                profit=_parse_decimal(raw["profit"], "Deal Profit"),
                balance=_parse_decimal(raw["balance"], "Deal Balance"),
                comment=_clean_text(raw["comment"]),
            )
        )
    if not deals:
        raise ReportFormatError("Deals table contains no ledger rows")
    return deals


def _deal_external_cost(deal: Deal, family: str) -> Decimal:
    assert deal.volume is not None and deal.price is not None
    if family == "NDX":
        rate = Decimal("2.75")
    elif family == "GDAXI":
        rate = Decimal("3.50")
    elif family in {"EURUSD", "GBPUSD"}:
        rate = max(Decimal("2.50"), Decimal("2.50") * deal.price)
    else:  # Protected by the supported-market identity check.
        raise IntegrityError(f"no frozen cost schedule for {family}")
    return _money(rate * deal.volume)


def _allocate(open_lot: _OpenLot, volume: Decimal) -> dict[str, Decimal]:
    if volume <= ZERO or volume > open_lot.remaining_volume:
        raise IntegrityError("invalid FIFO entry allocation volume")
    if volume == open_lot.remaining_volume:
        allocated = {
            "profit": open_lot.remaining_profit,
            "swap": open_lot.remaining_swap,
            "commission": open_lot.remaining_commission,
            "external_cost": open_lot.remaining_external_cost,
        }
    else:
        share = volume / open_lot.remaining_volume
        allocated = {
            "profit": open_lot.remaining_profit * share,
            "swap": open_lot.remaining_swap * share,
            "commission": open_lot.remaining_commission * share,
            "external_cost": open_lot.remaining_external_cost * share,
        }
    open_lot.remaining_volume -= volume
    open_lot.remaining_profit -= allocated["profit"]
    open_lot.remaining_swap -= allocated["swap"]
    open_lot.remaining_commission -= allocated["commission"]
    open_lot.remaining_external_cost -= allocated["external_cost"]
    return allocated


def _reconstruct_closes(deals: Sequence[Deal], family: str) -> list[dict[str, Any]]:
    queues: dict[tuple[str, str], list[_OpenLot]] = {}
    closes: list[dict[str, Any]] = []
    for deal in deals:
        if deal.direction not in {"in", "out"}:
            continue
        if deal.volume is None or deal.volume <= ZERO:
            raise IntegrityError(f"Deal {deal.deal} has non-positive or missing Volume")
        if deal.price is None or deal.price <= ZERO:
            raise IntegrityError(f"Deal {deal.deal} has non-positive or missing Price")
        if deal.kind not in {"buy", "sell"}:
            raise IntegrityError(f"trading Deal {deal.deal} has type {deal.kind!r}")
        external_cost = _deal_external_cost(deal, family)
        if deal.direction == "in":
            queues.setdefault((deal.symbol, deal.kind), []).append(
                _OpenLot(
                    deal=deal,
                    remaining_volume=deal.volume,
                    remaining_profit=deal.profit,
                    remaining_swap=deal.swap,
                    remaining_commission=deal.commission,
                    remaining_external_cost=external_cost,
                )
            )
            continue

        entry_side = "buy" if deal.kind == "sell" else "sell"
        queue = queues.get((deal.symbol, entry_side), [])
        remaining = deal.volume
        entry_net = ZERO
        entry_swap = ZERO
        entry_external_cost = ZERO
        entry_deals: list[str] = []
        entry_times: list[datetime] = []
        while remaining > ZERO:
            if not queue:
                raise IntegrityError(
                    f"exit Deal {deal.deal} volume exceeds FIFO open {entry_side} volume"
                )
            lot = queue[0]
            matched = min(remaining, lot.remaining_volume)
            allocation = _allocate(lot, matched)
            entry_net += allocation["profit"] + allocation["swap"] + allocation["commission"]
            entry_swap += allocation["swap"]
            entry_external_cost += allocation["external_cost"]
            entry_deals.append(lot.deal.deal)
            entry_times.append(lot.deal.time)
            remaining -= matched
            if lot.remaining_volume == ZERO:
                queue.pop(0)
        raw_net = entry_net + deal.raw_net
        total_external_cost = entry_external_cost + external_cost
        adjusted_net = raw_net - total_external_cost
        closes.append(
            {
                "sequence": len(closes) + 1,
                "entry_deals": entry_deals,
                "exit_deal": deal.deal,
                "symbol": deal.symbol,
                "side": entry_side,
                "volume": deal.volume,
                "entry_times": entry_times,
                "exit_time": deal.time,
                "raw_net": raw_net,
                "swap": entry_swap + deal.swap,
                "entry_external_cost": entry_external_cost,
                "exit_external_cost": external_cost,
                "external_cost": total_external_cost,
                "adjusted_net": adjusted_net,
            }
        )
    residual = [
        lot
        for queue in queues.values()
        for lot in queue
        if lot.remaining_volume != ZERO
    ]
    if residual:
        ids = ",".join(lot.deal.deal for lot in residual)
        raise IntegrityError(f"open entry Deals remain after report end: {ids}")
    return closes


def _assert_cent_equal(actual: Decimal, expected: Decimal, label: str) -> None:
    if _money(actual) != _money(expected):
        raise IntegrityError(
            f"{label}: {_money_string(actual)} != {_money_string(expected)}"
        )


def _profit_factor(gross_profit: Decimal, gross_loss: Decimal) -> tuple[str | None, str]:
    if gross_loss < ZERO:
        return _decimal_string(gross_profit / -gross_loss), "FINITE"
    if gross_profit > ZERO:
        return None, "INFINITE_NO_LOSSES"
    return None, "UNDEFINED_NO_PROFIT_OR_LOSS"


def _validate_expected(
    header: Mapping[str, Any],
    inputs: Mapping[str, str],
    expected: Mapping[str, Any] | None,
) -> None:
    if not expected:
        return
    scalar_keys = ("symbol", "timeframe", "from_date", "to_date", "currency")
    for key in scalar_keys:
        if key in expected and str(header[key]) != str(expected[key]):
            raise IntegrityError(
                f"expected {key}={expected[key]!r}, report has {header[key]!r}"
            )
    if "deposit" in expected:
        wanted = _parse_decimal(str(expected["deposit"]), "expected deposit")
        _assert_cent_equal(header["deposit_decimal"], wanted, "expected deposit drift")
    expected_inputs = expected.get("inputs", {})
    if not isinstance(expected_inputs, Mapping):
        raise IntegrityError("expected inputs pin must be an object")
    for key, wanted in expected_inputs.items():
        if key not in inputs:
            raise IntegrityError(f"expected input is absent: {key}")
        if inputs[key] != str(wanted):
            raise IntegrityError(
                f"expected input {key}={wanted!r}, report has {inputs[key]!r}"
            )


def audit_report(
    report_path: Path | str,
    *,
    expected: Mapping[str, Any] | None = None,
    expected_report_sha256: str | None = None,
    expected_deal_sequence_sha256: str | None = None,
    expected_run_fingerprint_sha256: str | None = None,
) -> dict[str, Any]:
    """Audit one report and return a JSON-serializable evidence receipt."""

    path = Path(report_path).resolve()
    report_sha = sha256_file(path)
    if expected_report_sha256 and report_sha != expected_report_sha256.lower():
        raise IntegrityError(
            f"raw report SHA-256 drift: {report_sha} != {expected_report_sha256.lower()}"
        )
    rows = _rows(path)
    settings_rows = _settings_rows(rows)
    expert_raw = str(_field_value(settings_rows, "expert"))
    expert = _canonical_expert(expert_raw)
    if expert != EXPECTED_EXPERT:
        raise IntegrityError(f"wrong Expert: {expert!r} != {EXPECTED_EXPERT!r}")
    symbol = str(_field_value(settings_rows, "symbol")).upper()
    if symbol not in SUPPORTED_MARKETS:
        raise IntegrityError(f"unsupported QM5_20009 DEV1 Symbol: {symbol!r}")
    market = SUPPORTED_MARKETS[symbol]
    period_raw = str(_field_value(settings_rows, "period"))
    timeframe, from_date, to_date = _parse_period(period_raw)
    if timeframe != market["timeframe"]:
        raise IntegrityError(
            f"timeframe mismatch for {symbol}: {timeframe} != {market['timeframe']}"
        )
    currency = str(_field_value(settings_rows, "currency")).upper()
    if currency != "USD":
        raise IntegrityError(f"cost schedule is USD-only, report Currency is {currency!r}")
    deposit = _parse_decimal(
        str(_field_value(settings_rows, "deposit")), "Initial Deposit"
    )
    if deposit <= ZERO:
        raise IntegrityError("Initial Deposit must be positive")
    inputs_raw, inputs = _extract_inputs(settings_rows)
    header: dict[str, Any] = {
        "expert": expert,
        "expert_raw": expert_raw,
        "symbol": symbol,
        "period_raw": period_raw,
        "timeframe": timeframe,
        "from_date": from_date.isoformat(),
        "to_date": to_date.isoformat(),
        "deposit_decimal": deposit,
        "currency": currency,
    }
    _validate_expected(header, inputs, expected)

    report_net = _parse_decimal(
        str(_field_value(settings_rows, "net_profit")), "Total Net Profit"
    )
    report_gross_profit_raw = _field_value(
        settings_rows, "gross_profit", required=False
    )
    report_gross_loss_raw = _field_value(settings_rows, "gross_loss", required=False)
    report_pf_raw = _field_value(settings_rows, "profit_factor", required=False)
    report_total_trades_raw = _field_value(
        settings_rows, "total_trades", required=False
    )
    deals = _parse_deals(rows)

    if deals[0].kind != "balance" or deals[0].direction or deals[0].symbol:
        raise IntegrityError("first Deals row is not the initial balance ledger row")
    nontrade = [deal for deal in deals if not deal.direction]
    if len(nontrade) != 1 or nontrade[0] is not deals[0]:
        raise IntegrityError("unexpected non-trading/deposit Deals after initial balance")
    initial = deals[0]
    if initial.volume is not None or initial.price is not None or initial.order:
        raise IntegrityError("initial balance Deal contains trading fields")
    if initial.commission != ZERO or initial.swap != ZERO:
        raise IntegrityError("initial balance Deal has commission or swap")
    _assert_cent_equal(initial.profit, deposit, "initial balance profit/deposit drift")
    _assert_cent_equal(initial.balance, deposit, "initial balance/deposit drift")

    running_native_balance = deposit
    for deal in deals:
        if not (from_date <= deal.time.date() <= to_date):
            raise IntegrityError(
                f"Deal {deal.deal} time is outside Period window: {deal.time}"
            )
        if deal.commission != ZERO:
            raise IntegrityError(
                f"DOUBLE_COUNT_REJECT: native report Commission on Deal {deal.deal} "
                f"is {_decimal_canonical(deal.commission)}, expected exactly 0"
            )
        if deal is initial:
            continue
        if deal.symbol != symbol:
            raise IntegrityError(
                f"Deal {deal.deal} Symbol {deal.symbol!r} differs from header {symbol!r}"
            )
        running_native_balance += deal.raw_net
        _assert_cent_equal(
            deal.balance,
            running_native_balance,
            f"native Balance recurrence drift on Deal {deal.deal}",
        )

    trading_deals = deals[1:]
    raw_deal_net = sum((deal.raw_net for deal in trading_deals), ZERO)
    _assert_cent_equal(report_net, raw_deal_net, "Total Net Profit/deal-ledger drift")
    closes = _reconstruct_closes(deals, market["family"])
    raw_closed_net = sum((row["raw_net"] for row in closes), ZERO)
    _assert_cent_equal(raw_deal_net, raw_closed_net, "deal-ledger/closed-position drift")
    if report_total_trades_raw is not None:
        reported_trades_decimal = _parse_decimal(report_total_trades_raw, "Total Trades")
        if reported_trades_decimal != reported_trades_decimal.to_integral_value():
            raise IntegrityError("Total Trades is not an integer")
        if int(reported_trades_decimal) != len(closes):
            raise IntegrityError(
                f"Total Trades/closed-position drift: {int(reported_trades_decimal)} != {len(closes)}"
            )

    raw_gross_profit = sum((max(row["raw_net"], ZERO) for row in closes), ZERO)
    raw_gross_loss = sum((min(row["raw_net"], ZERO) for row in closes), ZERO)
    if report_gross_profit_raw is not None:
        _assert_cent_equal(
            _parse_decimal(report_gross_profit_raw, "Gross Profit"),
            raw_gross_profit,
            "Gross Profit/closed-position drift",
        )
    if report_gross_loss_raw is not None:
        _assert_cent_equal(
            _parse_decimal(report_gross_loss_raw, "Gross Loss"),
            raw_gross_loss,
            "Gross Loss/closed-position drift",
        )

    external_cost = sum((row["external_cost"] for row in closes), ZERO)
    adjusted_net = sum((row["adjusted_net"] for row in closes), ZERO)
    adjusted_gross_profit = sum((max(row["adjusted_net"], ZERO) for row in closes), ZERO)
    adjusted_gross_loss = sum((min(row["adjusted_net"], ZERO) for row in closes), ZERO)
    adjusted_pf, adjusted_pf_state = _profit_factor(
        adjusted_gross_profit, adjusted_gross_loss
    )

    peak = deposit
    adjusted_balance = deposit
    max_drawdown = ZERO
    max_drawdown_pct = ZERO
    balance_series: list[dict[str, Any]] = []
    for row in closes:
        adjusted_balance += row["adjusted_net"]
        peak = max(peak, adjusted_balance)
        drawdown = peak - adjusted_balance
        drawdown_pct = ZERO if peak == ZERO else drawdown / peak * Decimal("100")
        max_drawdown = max(max_drawdown, drawdown)
        max_drawdown_pct = max(max_drawdown_pct, drawdown_pct)
        balance_series.append(
            {
                "exit_deal": row["exit_deal"],
                "exit_time": row["exit_time"].strftime("%Y-%m-%dT%H:%M:%S"),
                "raw_net_usd": _money_string(row["raw_net"]),
                "external_cost_usd": _money_string(row["external_cost"]),
                "cost_adjusted_net_usd": _money_string(row["adjusted_net"]),
                "closed_balance_usd": _money_string(adjusted_balance),
                "running_peak_usd": _money_string(peak),
                "drawdown_usd": _money_string(drawdown),
                "drawdown_percent": _decimal_string(drawdown_pct, 6),
            }
        )

    non_same_day = [
        row["exit_deal"]
        for row in closes
        if any(
            _new_york_date_from_broker(entry_time)
            != _new_york_date_from_broker(row["exit_time"])
            for entry_time in row["entry_times"]
        )
    ]
    nonzero_swap = [row["exit_deal"] for row in closes if row["swap"] != ZERO]
    total_swap = sum((row["swap"] for row in closes), ZERO)
    proof_status = (
        "NOT_APPLICABLE_NO_CLOSED_POSITIONS"
        if not closes
        else "PASS"
        if not non_same_day and not nonzero_swap
        else "FAIL"
    )

    canonical_deals = [deal.canonical() for deal in deals]
    deal_sequence_sha = _canonical_sha256(canonical_deals)
    if expected_deal_sequence_sha256 and deal_sequence_sha != expected_deal_sequence_sha256.lower():
        raise IntegrityError(
            "canonical Deal sequence SHA-256 drift: "
            f"{deal_sequence_sha} != {expected_deal_sequence_sha256.lower()}"
        )
    fingerprint_payload = {
        "expert": expert,
        "symbol": symbol,
        "timeframe": timeframe,
        "from_date": from_date.isoformat(),
        "to_date": to_date.isoformat(),
        "deposit": _decimal_canonical(deposit),
        "currency": currency,
        "inputs": dict(sorted(inputs.items())),
        "deal_sequence_sha256": deal_sequence_sha,
    }
    run_fingerprint = _canonical_sha256(fingerprint_payload)
    if expected_run_fingerprint_sha256 and run_fingerprint != expected_run_fingerprint_sha256.lower():
        raise IntegrityError(
            "run fingerprint SHA-256 drift: "
            f"{run_fingerprint} != {expected_run_fingerprint_sha256.lower()}"
        )

    close_evidence = [
        {
            "sequence": row["sequence"],
            "entry_deals": row["entry_deals"],
            "exit_deal": row["exit_deal"],
            "symbol": row["symbol"],
            "side": row["side"],
            "volume": _decimal_canonical(row["volume"]),
            "entry_times": [value.strftime("%Y-%m-%dT%H:%M:%S") for value in row["entry_times"]],
            "exit_time": row["exit_time"].strftime("%Y-%m-%dT%H:%M:%S"),
            "raw_net_usd": _money_string(row["raw_net"]),
            "swap_usd": _money_string(row["swap"]),
            "entry_external_cost_usd": _money_string(row["entry_external_cost"]),
            "exit_external_cost_usd": _money_string(row["exit_external_cost"]),
            "external_cost_usd": _money_string(row["external_cost"]),
            "cost_adjusted_net_usd": _money_string(row["adjusted_net"]),
        }
        for row in closes
    ]

    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20009_DEV1_MT5_REPORT_COST_AUDIT",
        "status": "PASS",
        "report": {
            "path": str(path),
            "sha256": report_sha,
            "encoding_contract": "UTF8_OR_UTF16_MT5_HTML",
        },
        "header": {
            "expert": expert,
            "expert_raw": expert_raw,
            "symbol": symbol,
            "period_raw": period_raw,
            "timeframe": timeframe,
            "from_date": from_date.isoformat(),
            "to_date": to_date.isoformat(),
            "initial_deposit": _money_string(deposit),
            "currency": currency,
            "inputs_ordered": inputs_raw,
            "inputs": inputs,
            "parsed_input_count": len(inputs),
        },
        "identity": {
            "canonical_deal_sequence_sha256": deal_sequence_sha,
            "run_fingerprint_sha256": run_fingerprint,
            "run_fingerprint_payload": fingerprint_payload,
        },
        "native_integrity": {
            "commission_exactly_zero": True,
            "simulated_commission_input_exactly_zero": True,
            "reported_total_net_profit": _money_string(report_net),
            "deal_sum_profit_swap_commission": _money_string(raw_deal_net),
            "reported_gross_profit": report_gross_profit_raw,
            "reported_gross_loss": report_gross_loss_raw,
            "reported_profit_factor": report_pf_raw,
            "reported_total_trades": report_total_trades_raw,
            "ledger_balance_recurrence": "PASS_CENT_EXACT",
            "total_net_reconciliation": "PASS_CENT_EXACT",
        },
        "cost_model": {
            "currency": "USD",
            "application": "PER_DEAL_SIDE_PER_LOT_ROUNDED_HALF_UP_TO_USD_CENT",
            "native_report_commission_required": "EXACT_ZERO",
            "NDX": "2.75_USD_PER_SIDE_PER_LOT",
            "GDAXI": "3.50_USD_PER_SIDE_PER_LOT_CONSERVATIVE_FROZEN",
            "EURUSD": "MAX(2.50_USD,2.50_EUR_CONVERTED_AT_DEAL_PRICE)_PER_SIDE_PER_LOT",
            "GBPUSD": "MAX(2.50_USD,2.50_GBP_CONVERTED_AT_DEAL_PRICE)_PER_SIDE_PER_LOT",
        },
        "closed_positions": close_evidence,
        "metrics": {
            "closed_positions": len(closes),
            "trading_deals": len(trading_deals),
            "external_cost_total_usd": _money_string(external_cost),
            "cost_adjusted_net_profit_usd": _money_string(adjusted_net),
            "cost_adjusted_gross_profit_usd": _money_string(adjusted_gross_profit),
            "cost_adjusted_gross_loss_usd": _money_string(adjusted_gross_loss),
            "cost_adjusted_profit_factor": adjusted_pf,
            "cost_adjusted_profit_factor_state": adjusted_pf_state,
            "final_closed_balance_usd": _money_string(adjusted_balance),
            "max_cumulative_closed_balance_drawdown_usd": _money_string(max_drawdown),
            "max_cumulative_closed_balance_drawdown_percent": _decimal_string(
                max_drawdown_pct, 6
            ),
        },
        "cumulative_closed_balance": balance_series,
        "same_day_swap_proof": {
            "status": proof_status,
            "date_basis": "NEW_YORK_DATE_VIA_FROZEN_BROKER_MINUS_7_HOURS",
            "all_closed_positions_same_day": not non_same_day,
            "all_closed_positions_zero_swap": not nonzero_swap,
            "non_same_day_exit_deals": non_same_day,
            "nonzero_swap_exit_deals": nonzero_swap,
            "total_swap_usd": _money_string(total_swap),
        },
        "warnings": (
            []
            if proof_status == "PASS"
            else [proof_status]
            if proof_status == "NOT_APPLICABLE_NO_CLOSED_POSITIONS"
            else ["SAME_DAY_OR_ZERO_SWAP_PROOF_FAILED"]
        ),
    }


def audit_reports(
    report_paths: Sequence[Path | str],
    *,
    expected: Mapping[str, Any] | None = None,
    expected_report_sha256: str | None = None,
    expected_deal_sequence_sha256: str | None = None,
    expected_run_fingerprint_sha256: str | None = None,
) -> dict[str, Any]:
    """Audit a primary report and optional deterministic duplicates."""

    if not report_paths:
        raise IntegrityError("at least one report is required")
    audits: list[dict[str, Any]] = []
    for index, path in enumerate(report_paths):
        audits.append(
            audit_report(
                path,
                expected=expected,
                expected_report_sha256=expected_report_sha256 if index == 0 else None,
                expected_deal_sequence_sha256=expected_deal_sequence_sha256,
                expected_run_fingerprint_sha256=expected_run_fingerprint_sha256,
            )
        )
    baseline_deals = audits[0]["identity"]["canonical_deal_sequence_sha256"]
    baseline_run = audits[0]["identity"]["run_fingerprint_sha256"]
    drift: list[dict[str, str]] = []
    for audit in audits[1:]:
        if (
            audit["identity"]["canonical_deal_sequence_sha256"] != baseline_deals
            or audit["identity"]["run_fingerprint_sha256"] != baseline_run
        ):
            drift.append(
                {
                    "path": audit["report"]["path"],
                    "deal_sequence_sha256": audit["identity"][
                        "canonical_deal_sequence_sha256"
                    ],
                    "run_fingerprint_sha256": audit["identity"][
                        "run_fingerprint_sha256"
                    ],
                }
            )
    if drift:
        raise DuplicateFingerprintDrift(
            "DUPLICATE_FINGERPRINT_DRIFT: semantic duplicate report(s) differ from "
            f"primary {audits[0]['report']['path']}: {drift!r}"
        )
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20009_DEV1_MT5_REPORT_AUDIT_RECEIPT",
        "status": "PASS",
        "duplicate_count": len(audits),
        "duplicate_fingerprint_check": "PASS",
        "canonical_deal_sequence_sha256": baseline_deals,
        "run_fingerprint_sha256": baseline_run,
        "reports": audits,
    }


def _parse_expected_inputs(values: Iterable[str]) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            raise IntegrityError(f"--expected-input must be KEY=VALUE: {value!r}")
        key, expected = value.split("=", 1)
        if not key or key in parsed:
            raise IntegrityError(f"invalid or duplicate --expected-input key: {key!r}")
        parsed[key] = expected
    return parsed


def _write_receipt(path: Path, payload: Mapping[str, Any]) -> None:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = (json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode(
        "utf-8"
    )
    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    try:
        with os.fdopen(file_descriptor, "wb") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, path)
    except Exception:
        try:
            os.unlink(temporary_name)
        except OSError:
            pass
        raise


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, help="Primary native MT5 report.htm")
    parser.add_argument(
        "--duplicate-report",
        action="append",
        default=[],
        type=Path,
        help="Repeat for deterministic duplicate reports; semantic drift rejects all",
    )
    parser.add_argument("--receipt", type=Path, help="Atomically write the JSON receipt")
    parser.add_argument("--expected-report-sha256")
    parser.add_argument("--expected-deal-sequence-sha256")
    parser.add_argument("--expected-run-fingerprint-sha256")
    parser.add_argument("--expected-symbol")
    parser.add_argument("--expected-timeframe")
    parser.add_argument("--expected-from", dest="expected_from_date")
    parser.add_argument("--expected-to", dest="expected_to_date")
    parser.add_argument("--expected-deposit")
    parser.add_argument("--expected-currency", default="USD")
    parser.add_argument("--expected-input", action="append", default=[])
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    paths = [args.report, *args.duplicate_report]
    try:
        expected_inputs = _parse_expected_inputs(args.expected_input)
        expected = {
            key: value
            for key, value in {
                "symbol": args.expected_symbol,
                "timeframe": args.expected_timeframe,
                "from_date": args.expected_from_date,
                "to_date": args.expected_to_date,
                "deposit": args.expected_deposit,
                "currency": args.expected_currency,
            }.items()
            if value is not None
        }
        expected["inputs"] = expected_inputs
        payload = audit_reports(
            paths,
            expected=expected,
            expected_report_sha256=args.expected_report_sha256,
            expected_deal_sequence_sha256=args.expected_deal_sequence_sha256,
            expected_run_fingerprint_sha256=args.expected_run_fingerprint_sha256,
        )
        exit_code = 0
    except (AuditError, OSError) as exc:
        payload = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "QM5_20009_DEV1_MT5_REPORT_AUDIT_RECEIPT",
            "status": "REJECT",
            "error_type": type(exc).__name__,
            "error": str(exc),
            "reports": [str(path.resolve()) for path in paths],
            "observed_at_utc": datetime.now(timezone.utc).isoformat(),
        }
        exit_code = 2
    if args.receipt:
        try:
            _write_receipt(args.receipt, payload)
        except OSError as exc:
            print(
                json.dumps(
                    {
                        "status": "REJECT",
                        "error_type": type(exc).__name__,
                        "error": f"cannot write receipt: {exc}",
                    },
                    sort_keys=True,
                ),
                file=sys.stderr,
            )
            return 3
    print(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
