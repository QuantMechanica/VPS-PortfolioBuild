"""Q07 — Multi-Seed runner.

Per Vault Q07 spec:
  Seeds:    42, 17, 99, 7, 2026  (canonical list, framework/registry/multiseed_seeds.json)
  Window:   full available history
  Stress:   Q06 HARSH settings applied (highest realistic stress)
  Verdict:  PF variance across seeds < 20% AND no seed PF < 1.0

Runs the same setfile 5 times — once per seed — with qm_rng_seed input
overridden to each canonical seed. Per-seed PF/DD/Trades captured.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import (ensure_dir, utc_now_iso, write_json,
                                            resolve_ea_expert_path, period_from_setfile,
                                            full_history_window,
                                            run_with_launch_fault_retry)
from framework.scripts.q05_stress_medium import (
    _find_latest_matching_summary,
    _latest_report_metrics,
    _parse_pf_dd_trades,
    _summary_identity_matches,
    _summary_from_run_smoke_output,
    _text_from_completed_process,
    summary_invalid_reason,
    MIN_TRADES,
    STARTING_EQUITY,
    RUNNER_HEADROOM_SEC,
    _basket_tester_overrides,
)
from framework.scripts.q06_stress_harsh import gen_harsh_setfile_for, _basket_logical_symbol

GATE_NAME = "Q07"
PF_VARIANCE_PCT_MAX = 20.0
PER_SEED_PF_MIN = 1.0
DEFAULT_SEED_TIMEOUT_SEC = 5400


def _seed_from_tester_ini(path: Path) -> int | None:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    match = re.search(
        r"_q06_stress_harsh_seed(?P<seed>\d+)\.set\b",
        text,
        flags=re.IGNORECASE,
    )
    if not match:
        return None
    return int(match.group("seed"))


def _settings_row_label(row_html: str) -> str | None:
    """Label text of a settings-table row's leading colspan-3 cell.

    MT5 renders the tester settings header as rows shaped
    ``<td ... colspan="3">Label:</td><td ... colspan="10"...><b>value</b></td>``.
    Returns the de-tagged label with any trailing ``:`` stripped (``""`` for the
    empty continuation cell that input rows use), or ``None`` when the row is not
    a settings row at all (no leading colspan-3 cell — e.g. a deals-table row, the
    spacer, or the ``Results`` header). This structural key bounds the Inputs
    region without depending on any localized value text.
    """
    match = re.search(
        r'<td\b[^>]*\bcolspan\s*=\s*["\']?3(?!\d)[^>]*>(.*?)</td>',
        row_html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if match is None:
        return None
    return re.sub(r"<[^>]+>", "", match.group(1)).strip().rstrip(":").strip()


def _report_inputs_region(html: str) -> str | None:
    """The slice of the settings header holding only the EA Inputs rows.

    The EA inputs occupy the row labelled ``Inputs:`` plus every following
    continuation row whose leading colspan-3 label cell is EMPTY; the block ends
    at the next labelled settings row (``Company:``, ``Currency:`` ...), the
    ``Results`` section, or any non-settings row. Returns ``None`` when the report
    has no ``Inputs:`` row. Scoping here — rather than a document-wide search — is
    what stops a bold ``<b>qm_rng_seed=N</b>`` fragment in a comment, caption,
    deals-table cell, or unrelated table from authenticating.
    """
    rows = list(re.finditer(r"<tr\b.*?</tr>", html, flags=re.IGNORECASE | re.DOTALL))
    start = None
    for idx, row in enumerate(rows):
        label = _settings_row_label(row.group(0))
        if label is not None and label.casefold() == "inputs":
            start = idx
            break
    if start is None:
        return None
    parts = [rows[start].group(0)]
    for row in rows[start + 1:]:
        label = _settings_row_label(row.group(0))
        if label is None or label != "":
            # a non-settings row, or the next labelled settings row -> region ends
            break
        parts.append(row.group(0))
    return "".join(parts)


def _resolve_run_dir(summary_path: Path, summary: dict) -> Path | None:
    """The raw/run_* directory the accepted summary references.

    Both provenance artifacts (tester.ini, report.htm) for a run live in one
    ``raw/run_NN`` directory. Binding both axes to a single directory is what
    prevents a split-sibling authentication: the tester.ini label of one run and
    the report effective seed of a *different* sibling run must never combine.

    Resolution order:
      1. the run directory named by the accepted (last) run entry's recorded
         report/tester path, rebased onto the summary's own directory (the
         absolute path recorded in summary.json goes stale once the work item is
         archived into a ``.requeued_*`` root);
      2. failing a recorded path, the unique ``raw/run_*`` directory beside the
         summary that actually holds a ``report.htm`` (a Q07 seed run is
         ``-Runs 1``; if retries left several, the newest report's directory is
         the accepted evidence). Both axes are still read from that one directory.
    Returns ``None`` when no such directory can be located — the caller then
    declines to authenticate.
    """
    runs = summary.get("runs") or []
    if runs:
        run = runs[-1]
        for key in ("report_canonical_path", "report_source_path", "tester_ini_path"):
            raw = run.get(key)
            if not raw:
                continue
            recorded = Path(str(raw))
            leaf = recorded.parent.name  # e.g. 'run_01'
            rebased = summary_path.parent / "raw" / leaf
            if rebased.is_dir():
                return rebased
            for candidate in summary_path.parent.rglob(leaf):
                if candidate.is_dir():
                    return candidate
            if recorded.parent.is_dir():
                return recorded.parent
    report_dirs = sorted({r.parent for r in summary_path.parent.rglob("report.htm")})
    if len(report_dirs) == 1:
        return report_dirs[0]
    if len(report_dirs) > 1:
        return max(report_dirs, key=lambda d: (d / "report.htm").stat().st_mtime)
    return None


def _seed_pair_from_summary_path(summary_path: Path) -> tuple[int | None, int | None]:
    """(label_seed, effective_seed) read from the SAME run the summary references.

    * label_seed — the Q07 HARSH seeded set-file (`_q06_stress_harsh_seed<N>.set`)
      named in that run's tester.ini: proves phase + stress + seeded-setfile
      provenance, which the report's effective seed alone cannot establish. Not
      authoritative for the value actually run (a broken injector can mislabel).
    * effective_seed — the qm_rng_seed the tester actually ran, from that run's
      report.htm Inputs cell: proves the label did not lie (the pre-1224d518b
      injector wrote distinct labels 42/17/99/7/2026 that all ran effective 42).

    Both are read from the one directory `_resolve_run_dir` selects, so a mislabeled
    accepted run can never borrow a sibling run's honest effective seed (or vice
    versa). Returns ``(None, None)`` when the referenced run directory cannot be
    located — the pair cannot be co-located, so nothing authenticates.
    """
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return (None, None)
    run_dir = _resolve_run_dir(summary_path, summary)
    if run_dir is None:
        return (None, None)
    label_seed = _seed_from_tester_ini(run_dir / "tester.ini")
    report_path = run_dir / "report.htm"
    effective_seed = _effective_seed_from_report(report_path) if report_path.exists() else None
    return (label_seed, effective_seed)


def _seed_from_summary_path(summary_path: Path) -> int | None:
    """Q07 HARSH seeded set-file label the accepted run dispatched, from its tester.ini.

    Provenance axis, paired with `_effective_seed_from_summary_path` and never used
    alone. Bound to the same run directory as the effective seed (see
    `_seed_pair_from_summary_path`) so the two axes cannot be drawn from different
    sibling runs.
    """
    return _seed_pair_from_summary_path(summary_path)[0]


def _effective_seed_from_report(report_path: Path) -> int | None:
    """Effective qm_rng_seed MT5 actually ran with, from a report.htm inputs table.

    The strategy-tester report echoes every EA input verbatim inside its Inputs
    table, each value rendered in its own bold cell, e.g.
    ``<td ... align="left"><b>qm_rng_seed=42</b></td>``. That cell is the value
    the central RNG was seeded from — authoritative in a way the seeded set-file
    *filename* in tester.ini is not. When the pre-1224d518b injector failed to
    write the override (magic_slot_offset != 0), five distinctly named set-files
    all ran the EA's default seed, and only this cell exposes that.

    The parse is scoped to the report's Inputs region (see `_report_inputs_region`),
    NOT the whole document: a report that merely mentions the string in a comment,
    caption, deals-table cell, or unrelated table — even inside a bold
    ``<b>qm_rng_seed=N</b>`` fragment — must NOT authenticate. The input *name*
    ``qm_rng_seed`` is not localized, and the region is anchored on the same English
    settings chrome (``Inputs:`` ... ``Company:``/``Results``) that
    ``q05._report_cell`` already relies on. Absence or a contradictory value returns
    None: an unauthenticatable run must be re-run, not silently accepted.
    """
    try:
        raw = report_path.read_bytes()
    except OSError:
        return None
    html = ""
    for encoding in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            candidate = raw.decode(encoding, errors="replace")
        except UnicodeError:
            continue
        if "<html" in candidate[:500].lower():
            html = candidate
            break
    if not html:
        return None
    # Scope to the report's Inputs region — NOT the whole document. A document-wide
    # search authenticates a bold `<b>qm_rng_seed=N</b>` fragment sitting in a
    # comment, caption, deals-table cell, or unrelated table; only the Inputs
    # listing proves the value the RNG was actually seeded from.
    region = _report_inputs_region(html)
    if region is None:
        return None
    seeds = {
        int(m) for m in re.findall(
            r"<b>\s*qm_rng_seed\s*=\s*(\d+)\s*</b>",
            region,
            flags=re.IGNORECASE,
        )
    }
    return seeds.pop() if len(seeds) == 1 else None


def _effective_seed_from_summary_path(summary_path: Path) -> int | None:
    """Effective seed for a recovered run, from the report.htm of the SAME run the
    summary references — co-located with the tester.ini `_seed_from_summary_path`
    reads (see `_seed_pair_from_summary_path`). Returns None when the referenced run
    directory cannot be located, the report is absent, or its Inputs cell is missing
    / ambiguous: an unauthenticatable run must be re-run, not silently accepted."""
    return _seed_pair_from_summary_path(summary_path)[1]


def _result_from_existing_seed_summary(*, summary_path: Path, seed: int,
                                       latest_full_year: int | None,
                                       full_history_from: str | None,
                                       ea_id: int, ea_expert: str, symbol: str,
                                       period: str, terminal: str) -> dict | None:
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    if not _summary_identity_matches(
            summary, ea_id=ea_id, ea_expert=ea_expert, symbol=symbol,
            period=period, terminal=terminal):
        return None
    # Authenticate on BOTH provenance axes; neither is sufficient alone.
    #  (a) tester.ini must name THIS slot's Q07 HARSH seeded set-file
    #      (`_q06_stress_harsh_seed<N>.set`) — proves the run was a Q07 HARSH
    #      seeded dispatch, not an arbitrary summary that merely happens to echo
    #      the seed string in its HTML.
    #  (b) the report's effective qm_rng_seed must equal THIS slot — proves the
    #      filename label did not lie (the pre-1224d518b injector wrote five
    #      distinct labels 42/17/99/7/2026 that all ran effective seed 42).
    # (a) alone lets a mislabeled run launder into the wrong slot; (b) alone lets
    # any non-Q07/non-HARSH summary with `qm_rng_seed=<slot>` anywhere in its
    # report fill the slot. Require both, each equal to the requested slot.
    if _seed_from_summary_path(summary_path) != seed:
        return None
    if _effective_seed_from_summary_path(summary_path) != seed:
        return None
    invalid_reason = summary_invalid_reason(summary_path)
    if invalid_reason:
        return None
    pf, dd_money, trades = _parse_pf_dd_trades(summary_path)
    if pf is None or int(trades or 0) < MIN_TRADES:
        return None
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None
    return {
        "seed": seed,
        "pf": pf,
        "dd_money": dd_money,
        "dd_pct": dd_pct,
        "trades": trades,
        "exit_code": 0,
        "timed_out": False,
        "timeout_detail": None,
        "timeout_sec": None,
        "runner_timeout_sec": None,
        "summary_path": str(summary_path),
        "report_path": None,
        "metric_source": "summary_json_reused",
        "history_year": None,
        "history_from": None,
        "history_to": None,
        "latest_full_year": latest_full_year,
        "full_history_from_override": full_history_from,
        "invalid_reason": None,
        "reused_existing_summary": True,
    }


def _recover_existing_seed_results(report_root: Path, seeds: list[int],
                                   latest_full_year: int | None,
                                   full_history_from: str | None, *,
                                   ea_id: int, ea_expert: str, symbol: str,
                                   period: str, terminal: str) -> dict[int, dict]:
    root = Path(report_root)
    search_roots: list[Path] = []
    if root.is_dir():
        search_roots.append(root)
    try:
        search_roots.extend(
            p for p in sorted(root.parent.glob(f"{root.name}.requeued_*"))
            if p.is_dir()
        )
    except OSError:
        pass
    if not search_roots:
        return {}
    wanted = set(seeds)
    recovered: dict[int, dict] = {}
    summaries: list[Path] = []
    for search_root in search_roots:
        summaries.extend(search_root.rglob("summary.json"))
    summaries = sorted(summaries, key=lambda p: p.stat().st_mtime, reverse=True)
    for summary_path in summaries:
        # Authenticate on BOTH provenance axes and require them to AGREE:
        #  - label_seed: the Q07 HARSH seeded set-file named in tester.ini
        #    (`_q06_stress_harsh_seed<N>.set`) — proves phase + stress provenance.
        #  - effective_seed: the qm_rng_seed the tester actually ran, from the
        #    report's bold inputs-table cell — proves the label did not lie.
        # Each axis is independently forgeable: a non-Q07/non-HARSH summary can
        # echo qm_rng_seed=42 in its HTML with no seeded-setfile label, and a
        # mislabeled Q07 run can carry seed<2026> while running effective 42 (the
        # pre-1224d518b defect). A slot is authenticated only when both axes are
        # present and identify the SAME seed. Both are drawn from ONE run directory
        # (the run the summary references) so they can never be split across sibling
        # runs. Every rejection is logged so the evidence trail shows what was
        # refused and why.
        label_seed, effective_seed = _seed_pair_from_summary_path(summary_path)
        if label_seed is None:
            print(f"    reject reused summary {summary_path}: no Q07 HARSH seeded "
                  f"set-file label in tester.ini (effective_seed={effective_seed}) -> re-run")
            continue
        if effective_seed is None:
            print(f"    reject reused summary {summary_path}: effective qm_rng_seed "
                  f"unestablished from report inputs table (filename_label={label_seed}) -> re-run")
            continue
        if label_seed != effective_seed:
            print(f"    reject reused summary {summary_path}: filename_label={label_seed} "
                  f"!= effective_seed={effective_seed} (mislabel/injector defect) -> re-run")
            continue
        seed = effective_seed  # == label_seed; authenticated on both axes
        if seed not in wanted:
            continue
        if seed in recovered:
            print(f"    reject reused summary {summary_path}: seed {seed} already "
                  f"recovered from a newer run (duplicate seed across slots) -> re-run")
            continue
        result = _result_from_existing_seed_summary(
            summary_path=summary_path,
            seed=seed,
            latest_full_year=latest_full_year,
            full_history_from=full_history_from,
            ea_id=ea_id,
            ea_expert=ea_expert,
            symbol=symbol,
            period=period,
            terminal=terminal,
        )
        if result is not None:
            recovered[seed] = result
        else:
            print(f"    reject reused summary {summary_path}: "
                  f"seed {seed} failed identity/validity checks -> re-run")
    return recovered


def _load_canonical_seeds() -> list[int]:
    """Load from framework/registry/multiseed_seeds.json — fail loud if absent."""
    repo_root = Path(__file__).resolve().parents[2]
    path = repo_root / "framework" / "registry" / "multiseed_seeds.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    seeds = data.get("seeds")
    if not isinstance(seeds, list) or len(seeds) != 5:
        raise ValueError(f"bad seed registry shape at {path}")
    return [int(s) for s in seeds]


def _write_seeded_setfile(baseline: Path, seed: int) -> Path:
    """Write a copy of `baseline` with qm_rng_seed=<seed> overridden."""
    text = baseline.read_text(encoding="utf-8", errors="replace")
    seed_line = f"qm_rng_seed={seed}"
    if re.search(r"(?m)^[ \t]*qm_rng_seed\s*=", text):
        new = re.sub(
            r"(?m)^[ \t]*qm_rng_seed\s*=.*$",
            seed_line,
            text,
            count=1,
        )
    else:
        # Slot offsets are not necessarily zero. Insert after the complete input
        # line so every canonical EA receives an actual seed override.
        anchor = re.search(r"(?m)^[ \t]*qm_magic_slot_offset\s*=.*$", text)
        if anchor:
            new = text[:anchor.end()] + f"\n{seed_line}" + text[anchor.end():]
        else:
            new = text.rstrip() + f"\n{seed_line}\n"

    declared = re.findall(r"(?m)^[ \t]*qm_rng_seed\s*=\s*(\d+)\s*$", new)
    if declared != [str(seed)]:
        raise ValueError(
            f"seed injection failed for {baseline}: expected one {seed}, got {declared}"
        )
    out_path = baseline.with_name(f"{baseline.stem}_seed{seed}.set")
    out_path.write_text(new, encoding="utf-8")
    return out_path


def _run_seed(*, ea_id: int, ea_expert: str, symbol: str, setfile: Path,
              seed: int, terminal: str, report_root: Path,
              timeout_sec: int, period: str = "H1",
              latest_full_year: int | None = None,
              full_history_from: str | None = None) -> dict:
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    history_year, history_from, history_to = full_history_window(latest_full_year, full_history_from)
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        "-Year", history_year, "-FromDate", history_from, "-ToDate", history_to,
        "-Terminal", terminal,
        "-Period", period,
        "-DispatchSubGateHash", f"q07_seed{seed}_{ea_id}_{symbol.replace('.', '_')}",
        "-DispatchPhase", "Q07",
        "-DispatchVersion", f"q07_seed_{seed}",
        "-Runs", "1",
        "-MinTrades", str(MIN_TRADES),
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
    ]
    tester_currency, tester_deposit = _basket_tester_overrides(setfile)
    if tester_currency:
        args.extend(["-TesterCurrencyOverride", tester_currency])
    if tester_deposit:
        args.extend(["-TesterDepositOverride", str(tester_deposit)])
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    runner_timeout_sec = timeout_sec + RUNNER_HEADROOM_SEC
    timed_out = False
    timeout_detail = None
    output_text = ""
    started_at = time.time()
    try:
        proc = run_with_launch_fault_retry(
            args,
            runner=subprocess.run,
            capture_output=True,
            text=True,
            timeout=runner_timeout_sec,
            creationflags=creationflags,
        )
        exit_code = proc.returncode
        output_text = _text_from_completed_process(proc)
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        timeout_detail = f"subprocess_timeout_after={exc.timeout}s"
        exit_code = 124
        output_text = _text_from_completed_process(exc)
    summary = _summary_from_run_smoke_output(
        output_text,
        started_at=started_at,
        ea_id=ea_id,
        ea_expert=ea_expert,
        symbol=symbol,
        period=period,
        terminal=terminal,
    ) or _find_latest_matching_summary(
        report_root,
        started_at=started_at,
        ea_id=ea_id,
        ea_expert=ea_expert,
        symbol=symbol,
        period=period,
        terminal=terminal,
    )
    invalid_reason = summary_invalid_reason(summary) if summary else None
    report_metrics = None if summary else _latest_report_metrics(
        report_root,
        started_at=started_at,
        expected_expert=ea_expert,
        expected_symbol=symbol,
        expected_period=period,
    )
    if summary:
        pf, dd_money, trades = _parse_pf_dd_trades(summary)
    elif report_metrics:
        pf = report_metrics["pf"]
        dd_money = report_metrics["dd_money"]
        trades = report_metrics["trades"]
    else:
        pf, dd_money, trades = None, None, 0
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None
    if timed_out and summary is None and report_metrics is None:
        invalid_reason = f"timeout_expired:timeout_sec={timeout_sec}:runner_timeout_sec={runner_timeout_sec}"
    # Fresh-run authentication: the produced evidence must PROVE, on BOTH axes,
    # that the tester ran THIS seed — a completed run is never graded on
    # summary/report metrics alone.
    #   (a) effective_seed — the qm_rng_seed the tester actually ran, from the
    #       report's Inputs cell — must be PRESENT and == the requested seed. A
    #       present-but-different value means the injector regressed: it wrote a
    #       set-file the tester ignored and ran the EA's default seed instead (the
    #       pre-1224d518b defect class), a hard INVALID that must fail loud forever.
    #   (b) label_seed — the run's tester.ini must name THIS seed's Q07 HARSH set-
    #       file (`_q06_stress_harsh_seed<N>.set`) — proves the run was a Q07 HARSH
    #       seeded dispatch, not an arbitrary run whose report happens to echo the
    #       seed. Both axes are read from the SAME run directory (co-located).
    # Absence of either axis — or a harsh label naming a different seed — is
    # `seed_evidence_missing`, also a hard INVALID: a run with otherwise valid
    # metrics must not enter its slot unauthenticated. This block runs only when a
    # prior guard did NOT fire (so a timeout / launch-fault / invalid-summary reason
    # is preserved untouched) AND the run actually produced evidence to authenticate
    # — a run that produced no summary and no report is already an INVALID handled by
    # the timeout / missing-summary guards, and is not relabeled here.
    produced_evidence = summary is not None or (report_metrics and report_metrics.get("report_path"))
    if invalid_reason is None and produced_evidence:
        if summary is not None:
            label_seed, effective_seed = _seed_pair_from_summary_path(Path(summary))
        else:
            report_path = Path(report_metrics["report_path"])
            effective_seed = _effective_seed_from_report(report_path)
            label_seed = _seed_from_tester_ini(report_path.parent / "tester.ini")
        if effective_seed is not None and effective_seed != seed:
            invalid_reason = (
                f"effective_seed_mismatch:requested={seed}:report={effective_seed}"
            )
        elif effective_seed != seed or label_seed != seed:
            invalid_reason = (
                f"seed_evidence_missing:requested={seed}:"
                f"effective={effective_seed}:harsh_label={label_seed}"
            )
    return {"seed": seed, "pf": pf, "dd_money": dd_money, "dd_pct": dd_pct,
            "trades": trades, "exit_code": exit_code,
            "timed_out": timed_out, "timeout_detail": timeout_detail,
            "timeout_sec": timeout_sec, "runner_timeout_sec": runner_timeout_sec,
            "summary_path": str(summary) if summary else None,
            "report_path": report_metrics.get("report_path") if report_metrics else None,
            "metric_source": "summary_json" if summary else ("report_htm" if report_metrics else None),
            "history_year": history_year,
            "history_from": history_from,
            "history_to": history_to,
            "latest_full_year": latest_full_year,
            "full_history_from_override": full_history_from,
            "invalid_reason": invalid_reason}


def evaluate_seeds(seed_results: list[dict]) -> tuple[str, str, dict]:
    """Combined Q07 verdict from per-seed results."""
    invalid_seeds = [
        (r["seed"], r.get("invalid_reason") or f"exit_code={r.get('exit_code')}")
        for r in seed_results
        if r.get("invalid_reason") or (
            int(r.get("trades") or 0) < MIN_TRADES
            and r.get("exit_code") not in (0, "0", None)
        )
    ]
    if invalid_seeds:
        return ("INVALID",
                f"seeds_invalid_evidence:{invalid_seeds}",
                {"per_seed_trades": [(r["seed"], r.get("trades", 0)) for r in seed_results]})

    missing_summary = [
        r["seed"] for r in seed_results
        if not r.get("summary_path") and not r.get("report_path")
    ]
    if missing_summary:
        return ("INVALID",
                f"seeds_missing_summary:{missing_summary}",
                {"per_seed_pf": [(r["seed"], r["pf"]) for r in seed_results]})

    low_trades = [r["seed"] for r in seed_results if int(r.get("trades") or 0) < MIN_TRADES]
    if low_trades:
        return ("FAIL",
                f"seed_trades_below_floor:seeds={low_trades}:floor={MIN_TRADES}",
                {"per_seed_trades": [(r["seed"], r.get("trades", 0)) for r in seed_results]})

    missing_pf = [r["seed"] for r in seed_results if r.get("pf") is None]
    if missing_pf:
        return ("FAIL",
                f"seeds_missing_pf:{missing_pf}",
                {"per_seed_pf": [(r["seed"], r["pf"]) for r in seed_results]})

    pfs = [float(r["pf"]) for r in seed_results]

    mean_pf = sum(pfs) / len(pfs)
    if mean_pf <= 0:
        return "FAIL", "mean_pf_non_positive", {}
    spread = max(pfs) - min(pfs)
    variance_pct = (spread / mean_pf) * 100.0
    floor_breach = [r["seed"] for r in seed_results if r["pf"] < PER_SEED_PF_MIN]

    metrics = {
        "per_seed_pf": [(r["seed"], round(r["pf"], 4)) for r in seed_results],
        "mean_pf": round(mean_pf, 4),
        "spread": round(spread, 4),
        "variance_pct": round(variance_pct, 2),
        "min_pf": round(min(pfs), 4),
        "max_pf": round(max(pfs), 4),
    }

    if floor_breach:
        return ("FAIL",
                f"per_seed_pf_below_floor:seeds={floor_breach}:floor={PER_SEED_PF_MIN}",
                metrics)
    if variance_pct >= PF_VARIANCE_PCT_MAX:
        return ("FAIL",
                f"pf_variance_pct={variance_pct:.2f}>={PF_VARIANCE_PCT_MAX}",
                metrics)
    return ("PASS",
            f"variance_pct={variance_pct:.2f}<{PF_VARIANCE_PCT_MAX}:min_pf={min(pfs):.3f}",
            metrics)


def main() -> int:
    ap = argparse.ArgumentParser(description="Q07 Multi-Seed runner")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--baseline-setfile", type=Path, required=True,
                    help="Q03 plateau-median setfile (Q06 HARSH stress will be applied per Q07 spec)")
    ap.add_argument("--expert",
                    help="Optional pre-deployed MT5 expert path override")
    ap.add_argument("--terminal", default="T2")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--timeout-sec", type=int, default=DEFAULT_SEED_TIMEOUT_SEC)
    ap.add_argument("--latest-full-year", type=int,
                    help="Cap full-history window when validated custom-symbol history ends before default")
    ap.add_argument("--full-history-from",
                    help="Override full-history start date as YYYY.MM.DD for custom-symbol cohorts")
    ap.add_argument("--logical-symbol",
                    help="Basket evidence symbol to record when --symbol is the MT5 host")
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))

    repo_root = Path(__file__).resolve().parents[2]
    ea_expert = args.expert or resolve_ea_expert_path(repo_root, args.ea)
    if ea_expert is None:
        print(f"cannot resolve EA dir for {args.ea}", file=sys.stderr)
        return 2
    period = period_from_setfile(args.baseline_setfile)

    # Q07 runs against Q06 HARSH stress per spec — apply HARSH first, then per-seed.
    harsh_set = gen_harsh_setfile_for(args.baseline_setfile)
    evidence_symbol = args.logical_symbol or _basket_logical_symbol(harsh_set, args.symbol) or args.symbol
    seeds = _load_canonical_seeds()
    print(f"Q07 {args.ea} {evidence_symbol}  runner_symbol={args.symbol}  seeds={seeds}  on top of HARSH stress")

    recovered = _recover_existing_seed_results(
        args.report_root,
        seeds,
        args.latest_full_year,
        args.full_history_from,
        ea_id=ea_id,
        ea_expert=ea_expert,
        symbol=args.symbol,
        period=period,
        terminal=args.terminal,
    )
    seed_results: list[dict] = []
    for seed in seeds:
        if seed in recovered:
            res = recovered[seed]
            print(f"  seed {seed}: reusing {res['summary_path']}")
            print(f"    -> PF={res['pf']}  trades={res['trades']}  exit={res['exit_code']}")
            seed_results.append(res)
            continue
        seeded_set = _write_seeded_setfile(harsh_set, seed)
        print(f"  seed {seed}: running...")
        res = _run_seed(ea_id=ea_id, ea_expert=ea_expert, symbol=args.symbol,
                        setfile=seeded_set, seed=seed,
                        terminal=args.terminal, report_root=args.report_root,
                        timeout_sec=args.timeout_sec, period=period,
                        latest_full_year=args.latest_full_year,
                        full_history_from=args.full_history_from)
        print(f"    -> PF={res['pf']}  trades={res['trades']}  exit={res['exit_code']}")
        seed_results.append(res)

    verdict, reason, metrics = evaluate_seeds(seed_results)
    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q07" / evidence_symbol.replace(".", "_"))
    write_json(out_dir / "aggregate.json", {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "symbol": evidence_symbol,
        "runner_symbol": args.symbol,
        "seeds": seeds,
        "verdict": verdict,
        "reason": reason,
        "metrics": metrics,
        "per_seed_detail": seed_results,
        "latest_full_year": args.latest_full_year,
        "full_history_from_override": args.full_history_from,
        "generated_at_utc": utc_now_iso(),
    })
    print(f"Q07 {args.ea} {args.symbol}: {verdict}")
    print(f"  reason: {reason}")
    return 0 if verdict == "PASS" else (1 if verdict == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
