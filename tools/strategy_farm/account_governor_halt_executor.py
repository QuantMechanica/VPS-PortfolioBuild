#!/usr/bin/env python3
r"""File-based, EA-native enforcement executor for the account/portfolio governor.

This is the missing gap-G6 executor
(``docs/ops/evidence/2026-09-13_governor_v2_cutover_package.md`` §4). It closes
the DISABLED decision->action boundary of
``account_governor_action_adapter.run_adapter`` WITHOUT any MT5 API, MT5 bridge,
order send, or recompile of the live inventory: it drives the halt channel the
already-deployed binaries poll.

WHAT THE DEPLOYED EAs ACTUALLY DO (``framework/include/QM/QM_KillSwitch.mqh``)
-----------------------------------------------------------------------------
Two, and only two, file channels are polled (:495-499 sets the defaults):

  * ``QM\halt\<ea_id>.halt``          -> ``KS_MANUAL``      (:669-674)
  * ``QM\halt\portfolio_dd.signal``   -> ``KS_PORTFOLIO_DD`` (:420-441, :676-695)

Both land in the SAME handler, ``QM_KillSwitchTrip`` (:449-470), which is not an
entry freeze at all:

  1. latches ``g_qm_ks_halted = true`` and persists it (:453-458) so the halt
     survives a terminal restart;
  2. ``QM_KillSwitchCloseOwnedPositions()`` -> closes every position carrying an
     owned magic (:392-399, :262-310);
  3. ``QM_KillSwitchDeleteOwnedPendings()`` -> deletes every owned pending
     (:317-338, :400-407);
  4. every later ``QM_KillSwitchCheck()`` returns false (:634-659), so the EA
     opens nothing again, and re-sweeps any residual exposure once per 60 s
     (:639-657).

Existence alone trips it: the manual halt file is never read
(``QM_KillSwitchFileExists``, :62-74), and the portfolio signal fails safe to a
trip when its value cannot be parsed (:438-440). Nothing in the deployed code
clears a halt; only deleting the file plus removing the persisted
``QM\halt\ks_state_<ea_id>_<magic>.state`` releases it.

CONSEQUENCE FOR THE L1/L2/L3 MAPPING
------------------------------------
There is NO entry-freeze-only channel in the deployed binaries.

  * **L1 ``ENTRY_FREEZE``** is **not expressible**. It is also the fail-closed
    default that flaps on any stale/incomplete snapshot (cutover package §4),
    so wiring it to a halt would flatten the book on a telemetry hiccup. This
    executor REFUSES level 1 and writes nothing.
  * **L2 ``PENDING_CANCEL_AND_ENTRY_FREEZE``** is expressible only as a strict
    SUPERSET: the halt cancels the pendings and freezes entries as asked, but
    also closes the open positions. That over-action is refused by default and
    requires the explicit ``l2_over_action_authorized`` opt-in.
  * **L3 ``CONTROLLED_FLATTEN_AUTHORIZED``** maps exactly: halt == flatten +
    cancel + freeze.

WHY PER-SLEEVE ``<ea_id>.halt`` AND NOT ``portfolio_dd.signal``
--------------------------------------------------------------
  * ``portfolio_dd.signal`` already has exactly one writer,
    ``live_book_dd_guard.py``:54-57. A second writer would race the book-DD
    guard's latch and its state file.
  * The per-sleeve channel is enumerable, receiptable and clearable one sleeve
    at a time; the signal file is all-or-nothing.
  * It is the FTMO-proven precedent: ``QM5_13206_ftmo-account-governor.mq5``
    :244-263 writes exactly ``QM\halt\<ea_id>.halt``, existence-latched, never
    overwriting, never clearing.

The scope is nevertheless the WHOLE live manifest, because all four governed
limits are account aggregates (gross leverage, currency net, planned stop, free
margin) and the evaluator's own ticket lists are "every recognized ticket"
(``account_portfolio_governor.py``:473-478) -- an account-wide breach does not
identify a culprit sleeve, so no sleeve-subset would be evidence-backed.

SAFETY
------
  * Fail-safe: manifest, halt dirs and policy inputs are validated BEFORE any
    write. Any unreadable input -> refusal, zero files written.
  * Latching: an existing halt file is never overwritten, never deleted by an
    apply. Clearing is OWNER-only and in writing -- ``--clear`` demands a
    ``decisions/`` artifact carrying the exact line
    ``GOVERNOR-HALT: CLEAR DXZ <date>`` (mirrors the DD guard rule,
    ``decisions/2026-07-24_live_book_dd_guard.md``, and book_build_guard's
    owner-order parsing).
  * Idempotent on ``instruction['decision_id']``: a repeat writes nothing and
    reports ``idempotent_skip``.
  * Atomic: every file is written tmp -> ``os.replace`` in the same directory.
  * Receipted: one JSON receipt per apply/clear with per-file SHA-256, paths,
    timestamp, reason, and the refusal reason when it refuses.
  * FILE_COMMON is OFF by default. ``QM_KillSwitchFileExists`` checks the
    terminal-local path first and ``FILE_COMMON`` second (:62-74), so a common
    write is machine-wide and would also trip the FTMO terminal's untagged
    sleeves -- the same reason ``live_book_dd_guard.py``:46-52 dropped it.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

try:  # package import preferred; bare fallback for CLI use
    from tools.strategy_farm.account_governor_action_adapter import AccountActionExecutor
except ImportError:  # pragma: no cover - standalone script path
    from account_governor_action_adapter import AccountActionExecutor  # type: ignore


RECEIPT_SCHEMA = "qm.account-governor.halt-executor-receipt/v1"
CLEAR_RECEIPT_SCHEMA = "qm.account-governor.halt-clear-receipt/v1"
EXECUTOR_NAME = "halt-file"

# Relative halt-file templates, copied from the deployed kill switch
# (QM_KillSwitch.mqh:495-499). ``HALT_FILE_TEMPLATE`` is what we write;
# ``PORTFOLIO_DD_SIGNAL_RELPATH`` is what we must NEVER write (DD guard owner).
HALT_FILE_TEMPLATE = "{ea_id}.halt"
HALT_DIR_RELPATH = "QM/halt"
PORTFOLIO_DD_SIGNAL_RELPATH = "QM/halt/portfolio_dd.signal"

DEFAULT_MANIFEST = Path(
    r"D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json"
)
# Terminal-local sandbox halt dir of the DXZ live terminal. Writing here is the
# safety action itself; this module never runs against it without an OWNER
# enforce order routed through the adapter.
DEFAULT_SANDBOX_HALT_DIR = Path(r"C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/halt")
DEFAULT_RECEIPT_DIR = Path(r"D:/QM/reports/governor/halt_executor")

DEFAULT_BOOK = "DXZ_4000090541"
DEFAULT_VENUE = "dxz"

# OWNER clearance artifact (book_build_guard.py:36-39 naming style).
CLEAR_ORDER_NAME = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})_owner_governor_halt_clear_"
    r"(?P<venue>dxz|ftmo)\.md$"
)
CLEAR_ORDER_LINE = "GOVERNOR-HALT: CLEAR {venue} {date}"

LEVEL_L1_REFUSAL = "l1_entry_freeze_not_expressible_via_halt_channel"
LEVEL_L2_REFUSAL = "l2_halt_is_flatten_over_action_not_authorized"


class HaltExecutorError(RuntimeError):
    """Structured refusal; never a traceback on the operator surface."""


@dataclass(frozen=True)
class Sleeve:
    ea_id: int
    magics: tuple[int, ...]
    symbols: tuple[str, ...]
    labels: tuple[str, ...]


def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def _sha256_bytes(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


def _sha256_file(path: Path) -> str | None:
    try:
        return _sha256_bytes(path.read_bytes())
    except OSError:
        return None


def load_live_manifest(path: Path) -> tuple[list[Sleeve], dict[str, Any]]:
    """Read + validate the OWNER live portfolio manifest.

    Refuses (raises) on anything ambiguous: unreadable file, wrong shape,
    declared/actual sleeve-count mismatch, non-positive ea_id, or a magic that
    does not satisfy the registry formula ``ea_id * 10000 + slot``
    (CLAUDE.md T_Live verification rule). Never returns a partial roster.
    """
    resolved = Path(path).resolve()
    try:
        raw = json.loads(resolved.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise HaltExecutorError(f"manifest_unreadable:{resolved}:{exc!r}") from exc
    if not isinstance(raw, dict):
        raise HaltExecutorError(f"manifest_not_object:{resolved}")
    rows = raw.get("sleeves")
    if not isinstance(rows, list) or not rows:
        raise HaltExecutorError(f"manifest_sleeves_missing:{resolved}")
    declared = raw.get("n_sleeves")
    if not isinstance(declared, int) or declared != len(rows):
        raise HaltExecutorError(
            f"manifest_sleeve_count_mismatch:declared={declared!r}:rows={len(rows)}"
        )

    by_ea: dict[int, dict[str, list[Any]]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise HaltExecutorError(f"manifest_row_not_object:{index}")
        ea_id = row.get("ea_id")
        magic = row.get("magic_number")
        if not isinstance(ea_id, int) or ea_id <= 0:
            raise HaltExecutorError(f"manifest_ea_id_invalid:{index}:{ea_id!r}")
        if not isinstance(magic, int) or magic <= 0:
            raise HaltExecutorError(f"manifest_magic_invalid:{index}:{magic!r}")
        if magic // 10000 != ea_id:
            raise HaltExecutorError(
                f"manifest_magic_not_derived_from_ea_id:{index}:ea_id={ea_id}:magic={magic}"
            )
        slot = by_ea.setdefault(ea_id, {"magics": [], "symbols": [], "labels": []})
        slot["magics"].append(magic)
        slot["symbols"].append(str(row.get("symbol") or ""))
        slot["labels"].append(str(row.get("ea_label") or ""))

    sleeves = [
        Sleeve(
            ea_id=ea_id,
            magics=tuple(sorted(set(data["magics"]))),
            symbols=tuple(sorted(set(s for s in data["symbols"] if s))),
            labels=tuple(sorted(set(s for s in data["labels"] if s))),
        )
        for ea_id, data in sorted(by_ea.items())
    ]
    meta = {
        "path": str(resolved),
        "sha256": _sha256_bytes(resolved.read_bytes()),
        "book": str(raw.get("book") or ""),
        "status": str(raw.get("status") or ""),
        "declared_sleeve_rows": declared,
        # One halt file per ea_id: QM_KillSwitch.mqh:494-496 keys the manual
        # halt on ea_id ONLY, so every chart/slot of that ea_id halts together.
        "distinct_ea_ids": len(sleeves),
    }
    return sleeves, meta


def _probe_writable(directory: Path) -> None:
    """Create the halt dir if needed and prove we can write+replace in it."""
    try:
        directory.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise HaltExecutorError(f"halt_dir_uncreatable:{directory}:{exc!r}") from exc
    probe = directory / f".qm_halt_probe_{os.getpid()}.tmp"
    try:
        probe.write_text("probe\n", encoding="ascii")
        probe.unlink()
    except OSError as exc:
        raise HaltExecutorError(f"halt_dir_unwritable:{directory}:{exc!r}") from exc


def _atomic_write(path: Path, payload: str) -> None:
    tmp = path.with_name(path.name + f".{os.getpid()}.tmp")
    tmp.write_text(payload, encoding="ascii", newline="")
    os.replace(tmp, path)


def halt_file_body(
    *,
    ea_id: int,
    book: str,
    decision_id: str,
    decision_level: int,
    decision_name: str,
    written_at_utc: str,
) -> str:
    """``key=value`` CRLF body, mirroring QM5_13206's WriteHaltFile (:253-258).

    The kill switch never reads this file (existence-trip,
    QM_KillSwitch.mqh:62-74); the body exists purely for forensics.
    """
    lines = [
        "source=account_governor_halt_executor",
        f"book={book}",
        f"ea_id={ea_id}",
        f"decision_id={decision_id}",
        f"decision_level={decision_level}",
        f"decision_name={decision_name}",
        f"written_at_utc={written_at_utc}",
        "clear_authority=OWNER_ONLY",
    ]
    return "".join(f"{line}\r\n" for line in lines)


class HaltFileExecutor(AccountActionExecutor):
    """``AccountActionExecutor`` that enforces through the EA halt channel.

    Injected into ``account_governor_action_adapter.run_adapter`` only when the
    OWNER enforce order, the signed policy, the activation artifact and the
    explicit ``--executor halt-file`` selection are all present.
    """

    def __init__(
        self,
        *,
        manifest_path: Path = DEFAULT_MANIFEST,
        halt_dirs: Sequence[Path] = (DEFAULT_SANDBOX_HALT_DIR,),
        receipt_dir: Path | None = DEFAULT_RECEIPT_DIR,
        book: str = DEFAULT_BOOK,
        l2_over_action_authorized: bool = False,
        now_fn: Any = _now_utc,
    ) -> None:
        self.manifest_path = Path(manifest_path)
        self.halt_dirs = tuple(Path(d) for d in halt_dirs)
        self.receipt_dir = Path(receipt_dir) if receipt_dir is not None else None
        self.book = book
        self.l2_over_action_authorized = bool(l2_over_action_authorized)
        self._now_fn = now_fn
        if not self.halt_dirs:
            raise HaltExecutorError("halt_dirs_empty")

    # ---------------------------------------------------------------- helpers
    def targets_for(self, sleeves: Iterable[Sleeve]) -> list[tuple[int, Path]]:
        out: list[tuple[int, Path]] = []
        for sleeve in sleeves:
            for directory in self.halt_dirs:
                out.append(
                    (sleeve.ea_id, directory / HALT_FILE_TEMPLATE.format(ea_id=sleeve.ea_id))
                )
        return out

    def _refuse(
        self, reason: str, *, instruction: dict[str, Any], now: dt.datetime
    ) -> dict[str, Any]:
        receipt = {
            "schema": RECEIPT_SCHEMA,
            "executor": EXECUTOR_NAME,
            "generated_at_utc": now.isoformat(),
            "decision_id": instruction.get("decision_id"),
            "decision_level": instruction.get("decision_level"),
            "decision_name": instruction.get("decision_name"),
            "book": self.book,
            "outcome": "EXECUTOR_REFUSED",
            "refused": True,
            "applied": False,
            "idempotent_skip": False,
            "refusal_reason": reason,
            "files_written": [],
            "files_already_latched": [],
            "files_failed": [],
        }
        self._write_receipt(receipt)
        return receipt

    def _write_receipt(self, receipt: dict[str, Any]) -> str | None:
        if self.receipt_dir is None:
            return None
        decision_id = str(receipt.get("decision_id") or "no_decision_id")
        kind = "clear" if receipt.get("schema") == CLEAR_RECEIPT_SCHEMA else "apply"
        try:
            self.receipt_dir.mkdir(parents=True, exist_ok=True)
            target = self.receipt_dir / f"halt_executor_{kind}_{decision_id}.json"
            _atomic_write(
                target,
                json.dumps(receipt, indent=2, sort_keys=True).replace("\r\n", "\n"),
            )
        except (OSError, ValueError):
            # A receipt failure must never abort or half-apply a safety action.
            receipt["receipt_path"] = None
            return None
        receipt["receipt_path"] = str(target)
        return str(target)

    # ------------------------------------------------------------------ apply
    def apply(self, instruction: dict[str, Any]) -> dict[str, Any]:
        """Enforce one governor decision through the halt channel.

        Returns a receipt dict. ``refused`` / ``idempotent_skip`` / ``applied``
        are the keys the adapter reads.
        """
        now = self._now_fn()
        decision_id = str(instruction.get("decision_id") or "").strip()
        if not decision_id:
            return self._refuse("decision_id_missing", instruction=instruction, now=now)
        level = instruction.get("decision_level")
        if not isinstance(level, int):
            return self._refuse(
                f"decision_level_not_int:{level!r}", instruction=instruction, now=now
            )
        if level < 1:
            return self._refuse(
                f"decision_level_below_action:{level}", instruction=instruction, now=now
            )
        if level == 1:
            return self._refuse(LEVEL_L1_REFUSAL, instruction=instruction, now=now)
        if level == 2 and not self.l2_over_action_authorized:
            return self._refuse(LEVEL_L2_REFUSAL, instruction=instruction, now=now)

        # ---- fail-safe pre-flight: validate EVERYTHING before any write ----
        try:
            sleeves, manifest_meta = load_live_manifest(self.manifest_path)
            for directory in self.halt_dirs:
                _probe_writable(directory)
        except HaltExecutorError as exc:
            return self._refuse(str(exc), instruction=instruction, now=now)

        targets = self.targets_for(sleeves)
        written: list[dict[str, Any]] = []
        latched: list[dict[str, Any]] = []
        failed: list[dict[str, Any]] = []
        stamp = now.replace(microsecond=0).isoformat()

        for ea_id, target in targets:
            if target.exists():
                # LATCH: never overwrite an existing halt (FTMO precedent
                # QM5_13206:247-248). Its provenance is whoever wrote it first.
                latched.append(
                    {"ea_id": ea_id, "path": str(target), "sha256": _sha256_file(target)}
                )
                continue
            body = halt_file_body(
                ea_id=ea_id,
                book=self.book,
                decision_id=decision_id,
                decision_level=level,
                decision_name=str(instruction.get("decision_name") or ""),
                written_at_utc=stamp,
            )
            try:
                _atomic_write(target, body)
            except OSError as exc:
                # Direction of failure is safe (fewer halts than intended, never
                # fewer than before). We do NOT roll back: un-halting on error
                # would be the unsafe direction.
                failed.append({"ea_id": ea_id, "path": str(target), "error": repr(exc)})
                continue
            written.append(
                {
                    "ea_id": ea_id,
                    "path": str(target),
                    "sha256": _sha256_bytes(body.encode("ascii")),
                    "bytes": len(body),
                }
            )

        idempotent_skip = not written and not failed
        if failed:
            outcome = "EXECUTOR_APPLIED_PARTIAL"
        elif idempotent_skip:
            outcome = "EXECUTOR_IDEMPOTENT_NOOP"
        else:
            outcome = "EXECUTOR_APPLIED"

        receipt = {
            "schema": RECEIPT_SCHEMA,
            "executor": EXECUTOR_NAME,
            "generated_at_utc": now.isoformat(),
            "decision_id": decision_id,
            "decision_level": level,
            "decision_name": instruction.get("decision_name"),
            "book": self.book,
            "action_class": "SLEEVE_HALT_FLATTEN_CANCEL_AND_ENTRY_FREEZE",
            "action_semantics": (
                "QM_KillSwitchTrip: closes owned positions, deletes owned pendings, "
                "latches the halt across restarts (QM_KillSwitch.mqh:449-470, :634-659)"
            ),
            "over_action_vs_decision": level == 2,
            "l2_over_action_authorized": self.l2_over_action_authorized,
            "manifest": manifest_meta,
            "halt_dirs": [str(d) for d in self.halt_dirs],
            "portfolio_dd_signal_untouched": PORTFOLIO_DD_SIGNAL_RELPATH,
            "requested_cancel_order_tickets": list(
                instruction.get("cancel_order_tickets") or []
            ),
            "requested_flatten_position_tickets": list(
                instruction.get("flatten_position_tickets") or []
            ),
            "sleeve_count": len(sleeves),
            "target_count": len(targets),
            "files_written": written,
            "files_already_latched": latched,
            "files_failed": failed,
            "outcome": outcome,
            "refused": False,
            "applied": bool(written),
            "idempotent_skip": idempotent_skip,
            "refusal_reason": None,
            "latching": "never cleared by this tool; OWNER-only clear, in writing",
        }
        self._write_receipt(receipt)
        return receipt

    # ------------------------------------------------------------------ plan
    def plan(self) -> dict[str, Any]:
        """Read-only: what WOULD be written, and the current latch state."""
        now = self._now_fn()
        try:
            sleeves, manifest_meta = load_live_manifest(self.manifest_path)
        except HaltExecutorError as exc:
            return {
                "schema": RECEIPT_SCHEMA,
                "executor": EXECUTOR_NAME,
                "generated_at_utc": now.isoformat(),
                "outcome": "PLAN_REFUSED",
                "refusal_reason": str(exc),
            }
        rows = [
            {
                "ea_id": ea_id,
                "path": str(target),
                "exists": target.exists(),
                "sha256": _sha256_file(target) if target.exists() else None,
            }
            for ea_id, target in self.targets_for(sleeves)
        ]
        return {
            "schema": RECEIPT_SCHEMA,
            "executor": EXECUTOR_NAME,
            "generated_at_utc": now.isoformat(),
            "outcome": "PLAN_ONLY",
            "book": self.book,
            "manifest": manifest_meta,
            "halt_dirs": [str(d) for d in self.halt_dirs],
            "l2_over_action_authorized": self.l2_over_action_authorized,
            "min_actionable_level": 2 if self.l2_over_action_authorized else 3,
            "targets": rows,
            "already_latched": sum(1 for row in rows if row["exists"]),
        }

    # ------------------------------------------------------------------ clear
    def clear(
        self, *, owner_clearance: Path, venue: str = DEFAULT_VENUE, today: dt.date | None = None
    ) -> dict[str, Any]:
        """OWNER-only, in-writing release of the halt latch.

        Mirrors the DD guard rule (``decisions/2026-07-24_live_book_dd_guard.md``
        -- "The signal is never cleared automatically"): requires a
        ``decisions/`` artifact whose NAME matches
        ``<date>_owner_governor_halt_clear_<venue>.md`` and whose body carries
        the exact line ``GOVERNOR-HALT: CLEAR <VENUE> <date>``.

        NOTE for the operator: deleting the halt file is necessary but not
        sufficient. ``QM_KillSwitch`` persists the trip in
        ``QM\\halt\\ks_state_<ea_id>_<magic>.state`` (:497-500) and restores it on
        init, so a halted chart stays halted until that state is also cleared
        and the chart reloaded. Those state files are listed, never deleted,
        here.
        """
        now = self._now_fn()
        today = today or now.date()
        try:
            order_path = _validate_clear_order(Path(owner_clearance), venue=venue, today=today)
            sleeves, manifest_meta = load_live_manifest(self.manifest_path)
        except HaltExecutorError as exc:
            receipt = {
                "schema": CLEAR_RECEIPT_SCHEMA,
                "executor": EXECUTOR_NAME,
                "generated_at_utc": now.isoformat(),
                "decision_id": f"clear_refused_{now.strftime('%Y%m%dT%H%M%SZ')}",
                "outcome": "CLEAR_REFUSED",
                "refused": True,
                "refusal_reason": str(exc),
                "files_removed": [],
            }
            self._write_receipt(receipt)
            return receipt

        removed: list[dict[str, Any]] = []
        absent: list[str] = []
        failed: list[dict[str, Any]] = []
        residual_state: list[str] = []
        for ea_id, target in self.targets_for(sleeves):
            if not target.exists():
                absent.append(str(target))
                continue
            sha = _sha256_file(target)
            try:
                target.unlink()
            except OSError as exc:
                failed.append({"ea_id": ea_id, "path": str(target), "error": repr(exc)})
                continue
            removed.append({"ea_id": ea_id, "path": str(target), "sha256_before": sha})
        for directory in self.halt_dirs:
            try:
                residual_state.extend(str(p) for p in sorted(directory.glob("ks_state_*.state")))
            except OSError:
                pass

        receipt = {
            "schema": CLEAR_RECEIPT_SCHEMA,
            "executor": EXECUTOR_NAME,
            "generated_at_utc": now.isoformat(),
            "decision_id": f"clear_{now.strftime('%Y%m%dT%H%M%SZ')}",
            "book": self.book,
            "owner_clearance_artifact": str(order_path),
            "owner_clearance_sha256": _sha256_file(order_path),
            "manifest": manifest_meta,
            "halt_dirs": [str(d) for d in self.halt_dirs],
            "files_removed": removed,
            "files_absent": absent,
            "files_failed": failed,
            "residual_ks_state_files_not_touched": residual_state,
            "operator_note": (
                "chart reload required: QM_KillSwitchRestoreState re-arms a halt "
                "from ks_state_<ea_id>_<magic>.state (QM_KillSwitch.mqh:497-500)"
            ),
            "outcome": "CLEAR_PARTIAL" if failed else "CLEAR_APPLIED",
            "refused": False,
            "refusal_reason": None,
        }
        self._write_receipt(receipt)
        return receipt


def _validate_clear_order(path: Path, *, venue: str, today: dt.date) -> Path:
    """book_build_guard-style OWNER order validation (book_build_guard.py:173-199)."""
    resolved = Path(path).resolve()
    match = CLEAR_ORDER_NAME.fullmatch(resolved.name)
    if match is None:
        raise HaltExecutorError(f"owner_clear_order_name_invalid:{resolved.name}")
    if match.group("venue") != venue:
        raise HaltExecutorError(
            f"owner_clear_order_wrong_venue:requested={venue}:artifact={match.group('venue')}"
        )
    raw_date = match.group("date")
    try:
        artifact_date = dt.date.fromisoformat(raw_date)
    except ValueError as exc:
        raise HaltExecutorError(f"owner_clear_order_invalid_date:{resolved}") from exc
    if artifact_date > today:
        raise HaltExecutorError(f"owner_clear_order_future_dated:{resolved}:{raw_date}")
    expected = CLEAR_ORDER_LINE.format(venue=venue.upper(), date=raw_date)
    try:
        lines = resolved.read_text(encoding="utf-8-sig").splitlines()
    except (OSError, UnicodeError) as exc:
        raise HaltExecutorError(f"owner_clear_order_unreadable:{resolved}:{exc!r}") from exc
    if expected not in (line.strip() for line in lines):
        raise HaltExecutorError(
            f"owner_clear_order_line_missing:{resolved}:expected={expected!r}"
        )
    return resolved


def build_executor(
    *,
    manifest_path: Path = DEFAULT_MANIFEST,
    halt_dirs: Sequence[Path] = (DEFAULT_SANDBOX_HALT_DIR,),
    receipt_dir: Path | None = DEFAULT_RECEIPT_DIR,
    book: str = DEFAULT_BOOK,
    l2_over_action_authorized: bool = False,
) -> HaltFileExecutor:
    """Factory used by the adapter CLI (keeps the wiring one line there)."""
    return HaltFileExecutor(
        manifest_path=manifest_path,
        halt_dirs=halt_dirs,
        receipt_dir=receipt_dir,
        book=book,
        l2_over_action_authorized=l2_over_action_authorized,
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument(
        "--halt-dir",
        type=Path,
        action="append",
        help="Halt directory (repeatable). Default: the T_Live sandbox halt dir.",
    )
    parser.add_argument("--receipt-dir", type=Path, default=DEFAULT_RECEIPT_DIR)
    parser.add_argument("--book", default=DEFAULT_BOOK)
    parser.add_argument("--venue", default=DEFAULT_VENUE, choices=["dxz", "ftmo"])
    parser.add_argument(
        "--status", action="store_true", help="Read-only plan + latch state (default)."
    )
    parser.add_argument(
        "--clear",
        action="store_true",
        help="OWNER-only halt release; requires --owner-clearance.",
    )
    parser.add_argument("--owner-clearance", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI. Applies NOTHING: enforcement runs only through the adapter.

    The only write path here is ``--clear``, and it demands the OWNER artifact.
    """
    args = _parser().parse_args(argv)
    halt_dirs = tuple(args.halt_dir) if args.halt_dir else (DEFAULT_SANDBOX_HALT_DIR,)
    executor = HaltFileExecutor(
        manifest_path=args.manifest,
        halt_dirs=halt_dirs,
        receipt_dir=args.receipt_dir,
        book=args.book,
    )
    if args.clear:
        if args.owner_clearance is None:
            print(
                json.dumps(
                    {
                        "schema": CLEAR_RECEIPT_SCHEMA,
                        "outcome": "CLEAR_REFUSED",
                        "refusal_reason": "owner_clearance_artifact_required",
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
            return 3
        receipt = executor.clear(owner_clearance=args.owner_clearance, venue=args.venue)
        print(json.dumps(receipt, indent=2, sort_keys=True))
        return 0 if receipt["outcome"] == "CLEAR_APPLIED" else 3
    print(json.dumps(executor.plan(), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
