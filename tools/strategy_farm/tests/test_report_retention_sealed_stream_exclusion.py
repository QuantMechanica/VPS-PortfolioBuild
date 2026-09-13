"""The write-once Q08 sealed-stream sidecar is invisible to the report-retention scan.

Router ticket 9c76957c.  Nine Q14-qualified pairs lost the graded per-trade bytes their
Q08 aggregate pins by ``content_sha256`` while the aggregate still said
``persisted:true``.  Those bytes cannot be rebuilt from ``report.htm`` (no ``mae_acct``,
no ``notional``, no ``entry_time``) and are reproducible only by a full backtest re-run,
so the durable sidecar must be outside every retention class.  ``report_retention.scan``
is the entry point for BOTH of that job's destructive actions -- age-out removal and
gzip compression -- so an artifact the scan never yields can be touched by neither.

Real ``D:`` paths are never read: ``REPORT_ROOTS`` is monkeypatched onto ``tmp_path``.
"""
from __future__ import annotations

import datetime as dt
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q08_durable_stream_export as dse  # noqa: E402
import report_retention as mod  # noqa: E402


WID = "11111111-2222-3333-4444-555555555555"


def _run_dir(root: Path) -> Path:
    d = root / "work_items" / WID / "QM5_9101" / "Q08" / "EURUSD_DWX"
    d.mkdir(parents=True)
    return d


def _age(path: Path, days: int) -> None:
    old = (dt.datetime.now() - dt.timedelta(days=days)).timestamp()
    import os

    os.utime(path, (old, old))


def test_scan_never_yields_the_sealed_stream_sidecar(tmp_path, monkeypatch):
    root = tmp_path / "reports"
    run = _run_dir(root)
    monkeypatch.setattr(mod, "REPORT_ROOTS", (root / "work_items",))

    aggregate = run / "aggregate.json"
    aggregate.write_text("{}", encoding="utf-8")
    sidecar = run / dse.sealed_sidecar_name("c0ffee" + "0" * 58)
    sidecar.write_bytes(b'{"event":"TRADE_CLOSED","volume":1.0}\n')
    for p in (aggregate, sidecar):
        _age(p, 400)

    cutoff = dt.datetime.now(dt.UTC) - dt.timedelta(days=mod.MIN_AGE_DAYS)
    found = [p for p, _m, _s in mod.scan(cutoff)["by_item"][WID]]

    assert aggregate in found                     # ordinary evidence is still scanned
    assert sidecar not in found                   # the sealed bytes are not
    assert sidecar.is_file()


def test_exclusion_holds_if_jsonl_is_ever_added_to_artifact_suffixes(tmp_path, monkeypatch):
    """The sidecar is excluded by NAME, not by its extension happening to be absent
    from ARTIFACT_SUFFIXES -- widening that tuple must not start eating sealed bytes."""
    root = tmp_path / "reports"
    run = _run_dir(root)
    monkeypatch.setattr(mod, "REPORT_ROOTS", (root / "work_items",))
    monkeypatch.setattr(mod, "ARTIFACT_SUFFIXES", mod.ARTIFACT_SUFFIXES + (".jsonl",))

    sidecar = run / dse.sealed_sidecar_name("d" * 64)
    sidecar.write_bytes(b"x\n")
    plain = run / "9101_EURUSD_DWX.jsonl"
    plain.write_bytes(b"y\n")
    for p in (sidecar, plain):
        _age(p, 400)

    cutoff = dt.datetime.now(dt.UTC) - dt.timedelta(days=mod.MIN_AGE_DAYS)
    found = [p for p, _m, _s in mod.scan(cutoff)["by_item"][WID]]

    assert plain in found
    assert sidecar not in found
