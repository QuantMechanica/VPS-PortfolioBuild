from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
from pathlib import Path
from typing import Any, Sequence

# Basket stream-key resolution is CANONICAL in portfolio_common (review
# b4e2a62b, 2026-07-06): load_streams itself aliases logical basket candidate
# keys to their stream files, so the book and every consumer stay correct.
# This module keeps a thin wrapper for its artifact notes and older callers.


def _resolve_basket_stream_key(candidate, common_dir: Path):
    return resolve_basket_stream_key(
        (int(candidate[0]), str(candidate[1])), Path(common_dir)
    )

try:
    from . import portfolio_admission
    from .portfolio_common import (
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        Trade,
        key_label,
        load_streams,
        read_candidates,
        resolve_basket_stream_key,
    )
    from .portfolio_manifest import DEFAULT_STARTING_CAPITAL
except ImportError:  # pragma: no cover - direct script execution
    import portfolio_admission  # type: ignore
    from portfolio_common import (  # type: ignore
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        Trade,
        key_label,
        load_streams,
        read_candidates,
        resolve_basket_stream_key,
    )
    from portfolio_manifest import DEFAULT_STARTING_CAPITAL  # type: ignore


Key = tuple[int, str]
DEFAULT_MIN_PORTFOLIO_TRADES = 20

# Volatile MT5 export area the recompiled EA writes its TRADE_CLOSED stream to. The Q08
# aggregator clears it every run and sub-gate perturbation/fold runs overwrite it, so it
# is UNRELIABLE as evidence and is deliberately NOT a stream-repair source (gate-repair
# WP-6 defect-1, 2026-07-25 — Codex review wp2346): a stream that cannot be tied by count
# AND lineage to the Q08 run that produced the authoritative trade count is never accepted.
# Kept only for diagnostics / provenance notes. Keyed off APPDATA to match
# ftmo_stream_reconciliation rather than hard-coding one username.
COMMON_FILES_Q08_DIR = (
    Path(os.environ.get("APPDATA", r"C:\Users\Administrator\AppData\Roaming"))
    / "MetaQuotes" / "Terminal" / "Common" / "Files" / "QM" / "q08_trades"
)


def monthly_returns(trades: Sequence[Trade]) -> dict[str, float]:
    monthly: dict[str, float] = {}
    for trade in trades:
        stamp = dt.datetime.fromtimestamp(int(trade.time), tz=dt.UTC)
        key = f"{stamp.year:04d}-{stamp.month:02d}"
        monthly[key] = monthly.get(key, 0.0) + float(trade.net_of_cost)
    return {key: round(value, 6) for key, value in sorted(monthly.items())}


def equity_curve(trades: Sequence[Trade]) -> list[dict[str, Any]]:
    equity = 0.0
    rows: list[dict[str, Any]] = []
    for trade in sorted(trades, key=lambda item: int(item.time)):
        equity += float(trade.net_of_cost)
        rows.append(
            {
                "time": int(trade.time),
                "equity": round(equity, 6),
                "net_of_cost": round(float(trade.net_of_cost), 6),
            }
        )
    return rows


def _load_sleeve_trades(common_dir: Path, stream_key: Key) -> tuple[list[Trade], str | None]:
    """Load the durable admission stream, hardened against a malformed stream.

    ``load_streams`` -> ``_load_one_stream`` coerces per-row ``volume``/``net``/``time``
    with bare ``float()``/``int()``: a row carrying ``volume: null`` (or any non-numeric
    value) raises ``TypeError``/``ValueError`` deep in the loader. That is a data-quality
    failure, not a gradeable outcome — a crash here previously stranded a sleeve after a
    malformed stream had already been installed (WP-6 defect-4, 2026-07-25 Codex
    re-review). Catch it and return ``(trades, reason)``; ``reason`` is ``None`` on
    success so the caller can route a bad stream to NEED_MORE_DATA instead of crashing.
    """
    try:
        streams = load_streams(common_dir, candidates=[stream_key])
    except (TypeError, ValueError, KeyError) as exc:
        return [], f"q08_stream_unloadable:{type(exc).__name__}"
    return streams.get(stream_key, []), None


def evaluate_q08_soft_rescue(
    candidate_key: Key,
    *,
    common_dir: Path = portfolio_admission.DEFAULT_ADMISSION_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    q08_summary_path: Path | None = None,
    q08_trade_count: int | None = None,
    min_portfolio_trades: int = DEFAULT_MIN_PORTFOLIO_TRADES,
    max_corr: float = portfolio_admission.DEFAULT_MAX_CORR,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    lineage_payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Grade a Q08 soft-fail sleeve for portfolio contribution on provenance-bound bytes.

    A sleeve is graded only against the exact trade set the Q08 run produced. Beyond the
    trade-count floor and the count-parity check, a ``q08_portfolio_stream/v2`` aggregate
    binds those bytes cryptographically via ``content_sha256``. When that hash is present,
    the loaded durable stream MUST hash to it BEFORE grading — a same-count foreign stream
    is not identity (WP-6 defect-1, round 3, 2026-07-25). A mismatch enters the repair path
    (which re-hashes any recovered source) and, if it cannot be reconciled, returns
    ``NEED_MORE_DATA``/``q08_stream_sha256_mismatch`` rather than grading unproven bytes.

    v1 aggregates carry no such hash: count equality alone remains the accepted (and only
    possible) basis, recorded as ``lineage_basis=count_only`` so the evidence trail is
    explicit about which bar was applied.
    """
    candidate = (int(candidate_key[0]), str(candidate_key[1]))
    stream_key = candidate
    stream_resolution = None
    resolved, note = _resolve_basket_stream_key(candidate, Path(common_dir))
    if resolved is not None:
        stream_key = resolved
        stream_resolution = note
    elif note is not None:
        stream_resolution = note
    trades, load_error = _load_sleeve_trades(common_dir, stream_key)
    trade_count = len(trades)

    q08_summary = _load_json(q08_summary_path)
    regime_catastrophe = _has_regime_catastrophe(q08_summary)
    authoritative = _evidence_trade_count(q08_trade_count, q08_summary)

    # Cryptographic identity of the graded bytes (WP-7). A v2 aggregate binds the exact
    # stream bytes via content_sha256; a v1 aggregate has none (lineage_basis=count_only).
    dst_stream_file = _sleeve_stream_file(common_dir, stream_key)
    content_sha256 = _aggregate_content_sha256(q08_summary)

    base: dict[str, Any] = {
        "candidate": key_label(candidate),
        "phase": "Q09_PORTFOLIO",
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "min_portfolio_trades": int(min_portfolio_trades),
        "trade_count": trade_count,
        "authoritative_q08_trade_count": authoritative,
        "q08_summary_path": str(q08_summary_path) if q08_summary_path else None,
        "q08_regime_catastrophe": regime_catastrophe,
        "stream_key": key_label(stream_key),
        "stream_resolution": stream_resolution,
        "lineage_basis": "sha256" if content_sha256 else "count_only",
        "monthly_returns": monthly_returns(trades),
        "equity_curve": equity_curve(trades),
    }
    if content_sha256:
        base["evidence_content_sha256"] = content_sha256
    if load_error is not None:
        base["stream_load_error"] = load_error

    # Q09 counts the exported STREAM, not the backtest that produced it. A Q08 passer
    # whose durable stream export was truncated (the volatile Common\Files source can
    # hold only a partial copy — see aggregate.py::_persist_durable_sleeve_stream) is
    # stamped NEED_MORE_DATA even though the backtest recorded plenty of trades. When the
    # authoritative Q08 trade count clears the floor but the loaded stream falls short,
    # re-export the stream from a durable, volume-bearing Q08 source and re-load before
    # judging. A stream that cannot be sourced from evidence is NOT repaired — the sleeve
    # stays NEED_MORE_DATA and is never silently passed (gate-repair WP-6, 2026-07-25).
    #
    # Round-2 (2026-07-25 Codex re-review): the equality check must fire on ANY count
    # divergence from the authoritative Q08 count — not only below the admission floor.
    # An above-floor 40-row stream against an authoritative 296 was previously graded to
    # a real verdict on unproven data. We now attempt a provenance-bound re-export
    # whenever the loaded stream is short OR diverges from the authoritative count OR the
    # stream could not even be loaded, and refuse (NEED_MORE_DATA) if it still diverges.
    #
    # Round-3 (2026-07-25 Codex re-check): a same-count destination is NOT proof of
    # identity. When the aggregate binds the graded bytes via content_sha256 (a v2
    # aggregate), the ALREADY-LOADED durable stream must ALSO hash to it before grading. A
    # count-equal foreign stream previously skipped repair entirely (needs_repair was
    # false) and was graded on unproven bytes. Fold the hash check into needs_repair so a
    # mismatch enters the repair path (which re-hashes any recovered source); if it cannot
    # be reconciled the sleeve returns NEED_MORE_DATA / q08_stream_sha256_mismatch below.
    def _destination_sha_mismatch() -> bool:
        # v1 aggregate (no content_sha256): count-only basis, never a hash mismatch.
        if not content_sha256:
            return False
        return _file_sha256(dst_stream_file) != content_sha256

    sha_mismatch = _destination_sha_mismatch()
    needs_repair = (
        trade_count < min_portfolio_trades
        or (authoritative is not None and trade_count != authoritative)
        or load_error is not None
        or sha_mismatch
    )
    if needs_repair:
        reexport = _reexport_short_sleeve_stream(
            stream_key,
            Path(common_dir),
            evidence_trade_count=authoritative,
            loaded_trade_count=trade_count,
            min_portfolio_trades=int(min_portfolio_trades),
            q08_summary=q08_summary,
        )
        base["stream_reexport"] = reexport
        if reexport.get("repaired"):
            trades, load_error = _load_sleeve_trades(common_dir, stream_key)
            trade_count = len(trades)
            base["trade_count"] = trade_count
            base["monthly_returns"] = monthly_returns(trades)
            base["equity_curve"] = equity_curve(trades)
            if load_error is not None:
                base["stream_load_error"] = load_error
        # Re-evaluate identity against the (possibly repaired) destination bytes: a
        # successful re-export replaced dst with the SHA-verified authoritative set.
        sha_mismatch = _destination_sha_mismatch()

    if content_sha256:
        base["destination_sha256"] = _file_sha256(dst_stream_file)

    # A stream that still cannot be loaded (malformed volume/net/time) is not gradeable.
    # Refuse cleanly — never crash, never a verdict on unreadable data (WP-6 defect-4).
    if load_error is not None:
        return {
            **base,
            "verdict": "NEED_MORE_DATA",
            "reason": "q08_stream_unloadable",
        }

    if trade_count < min_portfolio_trades:
        return {
            **base,
            "verdict": "NEED_MORE_DATA",
            "reason": "portfolio_trade_count_below_min",
        }

    # Above the floor but the loaded stream still disagrees with the authoritative Q08
    # count: the bytes that would be graded are NOT the provenance-bound authoritative
    # set (a re-export could not reconcile them). Refuse rather than grade unproven data
    # into a portfolio verdict (WP-6 defect-1, round 2).
    if authoritative is not None and trade_count != authoritative:
        return {
            **base,
            "verdict": "NEED_MORE_DATA",
            "reason": "q08_stream_count_mismatch",
        }

    # Above the floor and count-matched, but the loaded bytes do NOT hash to the aggregate's
    # bound content_sha256: a same-count FOREIGN stream that no re-export could reconcile.
    # Refuse rather than grade unproven bytes (WP-6 defect-1, round 3). Only reachable for a
    # v2 aggregate; a v1 aggregate has no hash and never sets sha_mismatch (count_only basis).
    if content_sha256 and sha_mismatch:
        return {
            **base,
            "verdict": "NEED_MORE_DATA",
            "reason": "q08_stream_sha256_mismatch",
        }

    # DL-078 (OWNER-ratified 2026-06-27): a STANDALONE Q08 8.10 regime catastrophe no
    # longer hard-rejects a portfolio sleeve. DL-075's premise is that the anticorrelation
    # book ABSORBS regime dependence: a sleeve whose bad regime is uncorrelated with the
    # book can still lower the book's drawdown. The standalone reject contradicted that
    # (and was applied inconsistently -- e.g. 10440:NDX was grandfathered in with the same
    # flag while genuine diversifiers were turned away). The decision now defers to
    # portfolio_admission, which admits ONLY when the candidate is sufficiently uncorrelated
    # AND demonstrably improves the book (Sharpe up OR maxDD down) -- the portfolio-context
    # equity curve already spans the candidate's bad regime, so admission proves absorption.
    # This mirrors the F4 (2026-06-03) treatment of standalone PF<1 below. A regime-fragile
    # sleeve that does NOT improve the book still FAILs at the admission check.

    book = read_candidates(candidates_db)
    book = [key for key in book if key not in (candidate, stream_key)]
    try:
        admission_kwargs: dict[str, Any] = {
            "max_corr": max_corr,
            "starting_capital": starting_capital,
        }
        if lineage_payload is not None:
            admission_kwargs["lineage_payload"] = lineage_payload
        admission = portfolio_admission.evaluate_candidate(
            stream_key,
            book,
            common_dir,
            **admission_kwargs,
        )
    except ValueError as exc:
        if "missing q08 trade streams" not in str(exc):
            raise
        return {
            **base,
            "verdict": "NEED_MORE_DATA",
            "reason": "portfolio_admission_missing_streams",
            "admission_error": str(exc),
        }

    if admission.get("reason") == "insufficient_overlap":
        return {
            **base,
            **admission,
            "verdict": "NEED_MORE_DATA",
            "reason": "portfolio_correlation_overlap_below_min",
            "previous_verdict": "FAIL_PORTFOLIO",
            "previous_reason": "insufficient_overlap",
            "sparse_overlap_watchlist": bool(admission.get("diversifies")),
        }

    # Trust portfolio_admission: it admits only when the candidate is sufficiently
    # uncorrelated AND actually improves the book (Sharpe up OR maxDD down). A standalone
    # net PF < 1 does NOT disqualify a portfolio sleeve - that is the whole point of the
    # rescue track, and test_portfolio_admission proves an anti-correlated PF<1 candidate
    # can be admitted when the portfolio improves. Genuinely negative-edge EAs (net PF < 1
    # over the window) are already FAIL_HARD upstream in Q08 and never reach Q09.
    # (OWNER feedback F4 2026-06-03: the standalone_pf>1 gate contradicted admission.)
    verdict = "PASS_PORTFOLIO" if admission.get("admit") else "FAIL_PORTFOLIO"
    reason = str(admission.get("reason") or "").strip() or (
        "portfolio_contribution_pass" if verdict == "PASS_PORTFOLIO" else "portfolio_contribution_fail"
    )
    # DL-078 audit trail: surface when a regime-fragile sleeve was admitted because the
    # book absorbed its regime dependence (vs the pre-DL-078 standalone hard-reject).
    if regime_catastrophe and verdict == "PASS_PORTFOLIO":
        base["regime_catastrophe_absorbed_by_book"] = True
    return {
        **base,
        **admission,
        "verdict": verdict,
        "reason": reason,
    }


def _evidence_trade_count(
    q08_trade_count: int | None,
    q08_summary: dict[str, Any],
) -> int | None:
    """Authoritative Q08 backtest trade count — the number the STREAM should carry.

    Prefer the value farmctl threads from the work-item payload; fall back to the Q08
    aggregate's ``n_trades`` when that evidence is still on disk. ``None`` means the
    backtest count is unknown (no usable Q08 evidence), so a short stream cannot be told
    apart from a genuinely low-frequency strategy and must NOT be repaired.
    """
    for value in (q08_trade_count, q08_summary.get("n_trades")):
        if value is None:
            continue
        try:
            return int(value)
        except (TypeError, ValueError):
            continue
    return None


def _aggregate_content_sha256(q08_summary: dict[str, Any]) -> str:
    """The v2 Q08 aggregate's recorded stream-content hash (normalized), or ``""``.

    A ``q08_portfolio_stream/v2`` aggregate binds the exact graded stream bytes via
    ``portfolio_stream.content_sha256`` (WP-7, 2026-07-25). A v1 aggregate carries no such
    field and returns ``""`` — the count-only lineage basis, the accepted and only-possible
    limitation for legacy evidence (see ``evaluate_q08_soft_rescue``).
    """
    pstream = q08_summary.get("portfolio_stream")
    if not isinstance(pstream, dict):
        return ""
    return str(pstream.get("content_sha256") or "").strip().lower()


def _file_sha256(path: Path) -> str | None:
    """SHA256 hexdigest of a file's raw bytes, or ``None`` if it cannot be read.

    Matches the byte-hash convention the Q08 aggregate uses for ``content_sha256``
    (``_artifact_identity`` in ``q08_davey/aggregate.py``), so a match here proves the
    loaded durable stream IS the exact set the run graded.
    """
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def _sleeve_stream_file(common_dir: Path, key: Key) -> Path:
    """Durable admission stream path load_streams reads for a resolved stream key."""
    return (
        Path(common_dir)
        / "QM"
        / "q08_trades"
        / f"{int(key[0])}_{str(key[1]).replace('.', '_')}.jsonl"
    )


def _volume_bearing_trade_count(path: Path) -> int | None:
    """Count TRADE_CLOSED rows, but ONLY if EVERY one carries a usable per-trade volume.

    A row is volume-bearing only when its ``volume`` field parses to a FINITE POSITIVE
    float. A volume-less stream (the MT5 HTML-report fallback) would zero the portfolio
    commission model, and a row with ``volume: null`` (or any non-numeric / non-positive
    value) would crash ``_load_one_stream``'s ``float(row["volume"])`` after installation
    (WP-6 defect-4, 2026-07-25 Codex re-review). Any such row makes the whole stream an
    invalid re-export source: return ``None`` to reject it rather than let a malformed
    stream be installed and then blow up the admission load path.
    """
    if not path.exists():
        return None
    count = 0
    try:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    return None
                if row.get("event") != "TRADE_CLOSED":
                    continue
                if "volume" not in row:
                    return None
                try:
                    volume = float(row.get("volume"))
                except (TypeError, ValueError):
                    return None
                if not (volume > 0.0) or volume == float("inf"):
                    return None
                count += 1
    except OSError:
        return None
    return count


def _reexport_short_sleeve_stream(
    stream_key: Key,
    common_dir: Path,
    *,
    evidence_trade_count: int | None,
    loaded_trade_count: int,
    min_portfolio_trades: int,
    q08_summary: dict[str, Any],
) -> dict[str, Any]:
    """Rebuild a truncated durable sleeve stream ONLY from a provenance-bound Q08 source.

    Repairs the broken-export case: the backtest recorded >= the trade floor but the stream
    the admission gate reads is short. A recovered stream is accepted ONLY when it can be
    tied to the exact Q08 run that produced the authoritative trade count, by BOTH count and
    lineage (gate-repair WP-6 defect-1, 2026-07-25 — Codex review wp2346):

      * Lineage: the only provenance record is the Q08 aggregate's own ``portfolio_stream``
        block — the path(s) it persisted and the count it wrote. We require the aggregate's
        recorded persisted count to equal the authoritative Q08 count (the run graded and
        persisted the same trades), and we source ONLY from a path the aggregate itself
        recorded persisting (``path`` / ``host_copy``). The dst file being repaired is
        excluded — re-copying it onto itself proves nothing.
      * Cryptographic identity (WP-7, 2026-07-25): a ``q08_portfolio_stream/v2`` aggregate
        additionally records ``content_sha256`` — the hash of the exact stream bytes the
        run graded. When present, the recovered file's bytes MUST hash to it; count
        equality is then only a coarse pre-filter, and a same-count file whose SHA differs
        is refused (``lineage_basis: sha256``). A v1 aggregate carries no such hash, so we
        fall back to count equality alone (``lineage_basis: count_only``). The basis
        actually applied is recorded in the result so the evidence trail is explicit.
      * Count: the recovered file must read back EXACTLY ``evidence_trade_count``
        volume-bearing TRADE_CLOSED rows — not merely >= the floor. A partial, over-count,
        or foreign same-count stream is refused.

    The volatile ``Common\\Files`` export is deliberately NOT a source: the aggregator clears
    it every run and perturbation/fold runs overwrite it, so it cannot prove provenance. The
    MT5 HTML report is not a source either (no per-trade volume). When provenance cannot be
    established the stream is genuinely unrecoverable and is left unrepaired: the caller keeps
    NEED_MORE_DATA rather than laundering a partial/foreign run into a real Q09 verdict.
    """
    dst = _sleeve_stream_file(common_dir, stream_key)
    result: dict[str, Any] = {
        "repaired": False,
        "loaded_trade_count": int(loaded_trade_count),
        "evidence_trade_count": evidence_trade_count,
        "admission_stream_path": str(dst),
    }
    if evidence_trade_count is None:
        result["reason"] = "q08_evidence_trade_count_unavailable"
        return result
    if evidence_trade_count < min_portfolio_trades:
        # Not a broken export — the backtest itself is below the floor.
        result["reason"] = "q08_evidence_trade_count_below_min"
        return result

    # Lineage gate: the Q08 aggregate must survive and its own record of the stream it
    # persisted must agree with the authoritative trade count.
    portfolio_stream = q08_summary.get("portfolio_stream")
    if not isinstance(portfolio_stream, dict):
        result["reason"] = "q08_aggregate_stream_lineage_unavailable"
        return result
    try:
        recorded_n: int | None = int(portfolio_stream.get("n"))
    except (TypeError, ValueError):
        recorded_n = None
    result["aggregate_stream_recorded_n"] = portfolio_stream.get("n")
    if recorded_n != evidence_trade_count:
        result["reason"] = "q08_aggregate_stream_count_mismatch"
        return result

    lineage_candidates: list[Path] = []
    for field in ("path", "host_copy"):
        raw = portfolio_stream.get(field)
        if not raw:
            continue
        candidate = Path(str(raw))
        try:
            is_dst = candidate.resolve() == dst.resolve()
        except OSError:
            is_dst = str(candidate) == str(dst)
        if is_dst or candidate in lineage_candidates:
            continue
        lineage_candidates.append(candidate)
    result["lineage_candidates"] = [str(candidate) for candidate in lineage_candidates]

    # Cryptographic identity gate (WP-7). A v2 aggregate binds the exact graded bytes via
    # content_sha256; a v1 aggregate has none and can only be checked by count.
    content_sha256 = str(portfolio_stream.get("content_sha256") or "").strip().lower()
    lineage_basis = "sha256" if content_sha256 else "count_only"
    result["lineage_basis"] = lineage_basis
    if content_sha256:
        result["evidence_content_sha256"] = content_sha256

    best_path: Path | None = None
    count_matched_but_sha_failed = False
    for candidate in lineage_candidates:
        count = _volume_bearing_trade_count(candidate)
        # Count gate: EXACT match to the authoritative Q08 trade count.
        if count is None or count != evidence_trade_count:
            continue
        # SHA gate: for a v2 aggregate the recovered bytes must hash to the recorded
        # content_sha256. A same-count file whose SHA differs is foreign — refuse it.
        if lineage_basis == "sha256":
            try:
                candidate_sha = hashlib.sha256(candidate.read_bytes()).hexdigest()
            except OSError:
                continue
            if candidate_sha != content_sha256:
                count_matched_but_sha_failed = True
                continue
        best_path = candidate
        break

    if best_path is None:
        result["reason"] = (
            "no_lineage_bound_source_matches_evidence_sha256"
            if count_matched_but_sha_failed
            else "no_lineage_bound_source_matches_evidence_count"
        )
        return result

    # Atomic replacement (gate-repair WP-6 defect-3): stage to a temp file, validate the
    # complete destination, then os.replace into place. A crash mid-write can never leave a
    # truncated durable stream — the exact failure mode that created this defect.
    tmp = dst.with_name(f"{dst.name}.reexport.{os.getpid()}.tmp")
    try:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(best_path, tmp)
        written = _volume_bearing_trade_count(tmp)
        if written != evidence_trade_count:
            result["reason"] = "reexport_destination_count_mismatch"
            result["written_trade_count"] = written
            return result
        # Re-verify the written bytes against the bound identity before publishing.
        if lineage_basis == "sha256":
            try:
                written_sha = hashlib.sha256(tmp.read_bytes()).hexdigest()
            except OSError:
                written_sha = None
            if written_sha != content_sha256:
                result["reason"] = "reexport_destination_sha256_mismatch"
                result["written_sha256"] = written_sha
                return result
        os.replace(tmp, dst)
    except OSError as exc:
        result["reason"] = f"reexport_copy_failed:{exc}"
        return result
    finally:
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass

    result.update(
        repaired=True,
        reason="reexported_from_q08_evidence",
        source_path=str(best_path),
        source_trade_count=int(evidence_trade_count),
    )
    return result


def write_aggregate(artifact: dict[str, Any], out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "aggregate.json"
    out_path.write_text(json.dumps(artifact, indent=2, sort_keys=True), encoding="utf-8")
    return out_path


def _load_json(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _has_regime_catastrophe(q08_summary: dict[str, Any]) -> bool:
    for gate in q08_summary.get("sub_gates") or []:
        if not isinstance(gate, dict):
            continue
        name = str(gate.get("name") or "").lower()
        detail = str(gate.get("detail") or "").lower()
        if name.startswith("8.10") and "unprofitable_regimes" in detail:
            return True
    return False


def _parse_candidate(ea_id: str, symbol: str) -> Key:
    text = str(ea_id).strip()
    if text.startswith("QM5_"):
        text = text.split("_", 2)[1]
    return int(text), str(symbol)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate Q08 soft-fail portfolio contribution.")
    parser.add_argument("--ea-id", required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--report-root", type=Path, required=True)
    parser.add_argument("--q08-summary", type=Path)
    parser.add_argument("--common-dir", type=Path, default=portfolio_admission.DEFAULT_ADMISSION_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument(
        "--q08-trade-count",
        type=int,
        default=None,
        help="Authoritative Q08 backtest trade count (from the work-item payload). Used to "
        "re-export a truncated sleeve stream before the trade-count floor is applied.",
    )
    parser.add_argument("--min-portfolio-trades", type=int, default=DEFAULT_MIN_PORTFOLIO_TRADES)
    parser.add_argument("--max-corr", type=float, default=portfolio_admission.DEFAULT_MAX_CORR)
    parser.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
    parser.add_argument("--lineage-payload-json")
    parser.add_argument("--lineage-payload-file", type=Path)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    candidate = _parse_candidate(args.ea_id, args.symbol)
    lineage_payload = portfolio_admission.load_lineage_payload(
        args.lineage_payload_json,
        args.lineage_payload_file,
    )
    artifact = evaluate_q08_soft_rescue(
        candidate,
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        q08_summary_path=args.q08_summary,
        q08_trade_count=args.q08_trade_count,
        min_portfolio_trades=args.min_portfolio_trades,
        max_corr=args.max_corr,
        starting_capital=args.starting_capital,
        lineage_payload=lineage_payload,
    )
    out_dir = (
        args.report_root
        / f"QM5_{candidate[0]}"
        / "Q09_PORTFOLIO"
        / str(args.symbol).replace(".", "_")
    )
    out_path = write_aggregate(artifact, out_dir)
    print(f"wrote {out_path} verdict={artifact['verdict']} reason={artifact['reason']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
