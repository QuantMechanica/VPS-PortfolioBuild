from __future__ import annotations

import dataclasses
import hashlib
import json
from decimal import Decimal
from pathlib import Path

import pytest

from tools.strategy_farm import build_slippage_ledger_v2 as subject


REPO_ROOT = Path(__file__).resolve().parents[3]
ALIAS_PATH = REPO_ROOT / "framework" / "registry" / "execution_symbol_aliases_v1.json"


def _aliases() -> subject.AliasPolicy:
    return subject.load_alias_policy_bytes(ALIAS_PATH.read_bytes(), label=str(ALIAS_PATH))


def _provenance(tag: str, line: int = 1) -> subject.Provenance:
    return subject.Provenance(
        source_id=tag,
        path=f"C:/{tag}.log",
        line_number=line,
        line_sha256=hashlib.sha256(f"{tag}:{line}".encode()).hexdigest(),
    )


def _request(
    *,
    order: int | None = None,
    deal: int | None = None,
    hint: int | None = None,
    side: str = "BUY",
    volume: str = "1",
    reference: str = "100",
    raw_symbol: str = "NDX",
    venue: str = "DXZ_LIVE",
    account: str = "4000090541",
    server: str = "Darwinex-Live",
    kind: str = "REQUEST_EXACT",
    execution_kind: str = "MARKET_ENTRY",
    tag: str = "request",
) -> subject.RequestRecord:
    return subject.RequestRecord(
        venue_id=venue,
        account_id=account,
        server=server,
        raw_symbol=raw_symbol,
        side=side,
        volume=Decimal(volume),
        reference_price=Decimal(reference),
        reference_kind=kind,
        execution_kind=execution_kind,
        order_ticket=order,
        deal_ticket=deal,
        ticket_hint=hint,
        magic=123,
        ea_id=10,
        request_time="2026-07-10T10:00:00Z",
        result_request_id=555 if deal is not None else None,
        provenance=(_provenance(tag),),
    )


def _deal(
    deal: int,
    *,
    order: int | None = None,
    side: str = "BUY",
    volume: str = "1",
    fill: str = "101",
    raw_symbol: str = "NDX",
    venue: str = "DXZ_LIVE",
    account: str = "4000090541",
    server: str = "Darwinex-Live",
    server_reference: str | None = None,
    reason: str | None = None,
    tag: str | None = None,
) -> subject.DealRecord:
    return subject.DealRecord(
        venue_id=venue,
        account_id=account,
        server=server,
        raw_symbol=raw_symbol,
        side=side,
        volume=Decimal(volume),
        fill_price=Decimal(fill),
        deal_ticket=deal,
        order_ticket=order,
        position_id=9000 + deal,
        fill_time=f"20260710T10:00:{deal % 60:02d}.000",
        entry_kind="DEAL_ENTRY_OUT" if reason else "DEAL_ENTRY_IN",
        reason=reason,
        server_reference_price=Decimal(server_reference)
        if server_reference is not None
        else None,
        server_reference_kind="SERVER_LEVEL_EXACT"
        if server_reference is not None
        else None,
        magic=123,
        provenance=(_provenance(tag or f"deal-{deal}"),),
    )


def _properties(
    *,
    venue: str = "DXZ_LIVE",
    account: str = "4000090541",
    raw_symbol: str = "NDX",
    point: str = "1",
    volume_step: str = "0.01",
) -> dict[tuple[str, str, str], subject.SymbolProperties]:
    properties = subject.SymbolProperties(
        venue_id=venue,
        account_id=account,
        raw_symbol=raw_symbol,
        point=Decimal(point),
        digits=max(0, -Decimal(point).as_tuple().exponent),
        trade_tick_size=Decimal(point),
        volume_step=Decimal(volume_step),
    )
    return {(venue, account, raw_symbol): properties}


def _observation_by_order(rows: list[dict], order: int) -> dict:
    return next(row for row in rows if row["order_ticket"] == order)


def test_alias_policy_is_exact_and_never_pools_venues_for_qualification() -> None:
    policy = _aliases()

    assert policy.resolve("DXZ_LIVE", "4000090541", "Darwinex-Live", "NDX") == "NDX.DWX"
    assert policy.resolve("FTMO_TRIAL", "1513845506", "FTMO-Demo", "US100.cash") == "NDX.DWX"
    assert policy.qualification_scope == "VENUE_ACCOUNT_LOGICAL_SYMBOL"
    assert policy.cross_venue_pooling is False
    with pytest.raises(subject.LedgerError, match="no exact symbol alias"):
        policy.resolve("DXZ_LIVE", "4000090541", "Darwinex-Live", "ndx")


def test_alias_policy_rejects_duplicate_json_keys() -> None:
    with pytest.raises(subject.LedgerError, match="duplicate JSON key"):
        subject.load_alias_policy_bytes(
            b'{"schema_version":1,"schema_version":1}', label="duplicate.json"
        )


def test_buy_sell_sign_and_improvement_are_direction_correct() -> None:
    requests = [
        _request(order=10, side="BUY", reference="100", tag="buy-request"),
        _request(order=20, side="SELL", reference="100", tag="sell-request"),
        _request(order=30, side="BUY", reference="100", tag="improve-request"),
    ]
    deals = [
        _deal(1, order=10, side="BUY", fill="101"),
        _deal(2, order=20, side="SELL", fill="99"),
        _deal(3, order=30, side="BUY", fill="99"),
    ]

    rows = subject.build_observations(
        requests, deals, aliases=_aliases(), symbol_properties=_properties()
    )

    assert _observation_by_order(rows, 10)["signed_slip_points"] == "1"
    assert _observation_by_order(rows, 10)["adverse_points"] == "1"
    assert _observation_by_order(rows, 20)["signed_slip_points"] == "1"
    assert _observation_by_order(rows, 20)["adverse_points"] == "1"
    assert _observation_by_order(rows, 30)["signed_slip_points"] == "-1"
    assert _observation_by_order(rows, 30)["adverse_points"] == "0"


def test_entry_ticket_joins_exact_order_and_exact_deal_fallback() -> None:
    requests = [
        _request(hint=100, tag="order-hint"),
        _request(hint=202, tag="deal-hint"),
    ]
    deals = [
        _deal(101, order=100),
        _deal(202, order=None),
    ]

    rows = subject.build_observations(
        requests, deals, aliases=_aliases(), symbol_properties=_properties()
    )

    order_row = _observation_by_order(rows, 100)
    fallback_row = next(row for row in rows if row["deal_tickets"] == [202])
    assert order_row["join_method"] == "ENTRY_TICKET_TO_ORDER_EXACT"
    assert fallback_row["join_method"] == "ENTRY_TICKET_TO_DEAL_EXACT"
    assert order_row["eligibility"] == fallback_row["eligibility"] == "QUALIFICATION"


def test_result_deal_join_has_precedence_for_close() -> None:
    request = _request(
        order=800,
        deal=801,
        side="SELL",
        reference="100",
        execution_kind="MARKET_CLOSE",
    )
    row = subject.build_observations(
        [request],
        [_deal(801, order=800, side="SELL", fill="99")],
        aliases=_aliases(),
        symbol_properties=_properties(),
    )[0]

    assert row["join_method"] == "RESULT_DEAL_EXACT"
    assert row["execution_kind"] == "MARKET_CLOSE"
    assert row["signed_slip_points"] == "1"


def test_enriched_close_event_parses_while_legacy_close_is_ignored(tmp_path: Path) -> None:
    path = tmp_path / "close.log"
    legacy = {
        "event": "TM_CLOSE",
        "ea_id": 10,
        "payload": {"ticket": 1, "symbol": "NDX", "lots": 1, "ok": True},
    }
    enriched = {
        "ts_utc": "2026-07-20T10:00:00Z",
        "ea_id": 10,
        "event": "TM_PARTIAL_CLOSE",
        "payload": {
            "schema_version": 2,
            "symbol": "NDX",
            "ok": True,
            "request_type": 1,
            "request_volume": 1,
            "request_price": 100,
            "result_order": 700,
            "result_deal": 701,
            "result_request_id": 702,
            "magic": 123,
        },
    }
    path.write_text(
        json.dumps(legacy) + "\n" + json.dumps(enriched) + "\n", encoding="utf-8"
    )
    captured = subject.capture_source(
        subject.SourceSpec(
            "C", "DXZ_LIVE", "4000090541", "Darwinex-Live", "EA_JSON_LOG", path
        )
    )

    requests = subject.parse_ea_json_log(captured)

    assert len(requests) == 1
    assert requests[0].execution_kind == "MARKET_CLOSE"
    assert requests[0].side == "SELL"
    assert requests[0].order_ticket == 700
    assert requests[0].deal_ticket == 701
    assert requests[0].result_request_id == 702


def test_partial_deals_form_one_volume_weighted_order_sample() -> None:
    request = _request(order=77, volume="3", reference="100")
    deals = [
        _deal(701, order=77, volume="1", fill="101"),
        _deal(702, order=77, volume="2", fill="103"),
    ]

    rows = subject.build_observations(
        [request], deals, aliases=_aliases(), symbol_properties=_properties()
    )

    assert len(rows) == 1
    assert rows[0]["deal_tickets"] == [701, 702]
    assert rows[0]["filled_volume"] == "3"
    assert rows[0]["fill_vwap"].startswith("102.333333333333333333")
    assert rows[0]["volume_complete"] is True
    assert rows[0]["eligibility"] == "QUALIFICATION"


def test_incomplete_partial_is_diagnostic_and_overfill_fails() -> None:
    request = _request(order=77, volume="3")
    incomplete = subject.build_observations(
        [request],
        [_deal(701, order=77, volume="2")],
        aliases=_aliases(),
        symbol_properties=_properties(),
    )[0]
    assert incomplete["eligibility"] == "DIAGNOSTIC"
    assert incomplete["diagnostic_reasons"] == ["PARTIAL_VOLUME_INCOMPLETE"]

    with pytest.raises(subject.LedgerError, match="filled volume exceeds request"):
        subject.build_observations(
            [request],
            [_deal(702, order=77, volume="3.02")],
            aliases=_aliases(),
            symbol_properties=_properties(),
        )


def test_identical_deal_duplicates_merge_provenance_but_conflicts_fail() -> None:
    first = _deal(1, order=10, tag="journal")
    duplicate = dataclasses.replace(first, provenance=(_provenance("history"),))

    merged = subject.deduplicate_deals([first, duplicate])

    assert len(merged) == 1
    assert {item.source_id for item in merged[0].provenance} == {"journal", "history"}
    with pytest.raises(subject.LedgerError, match="conflicting duplicate deal"):
        subject.deduplicate_deals(
            [first, dataclasses.replace(duplicate, fill_price=Decimal("101.01"))]
        )


def test_history_duplicate_enriches_journal_deal_without_double_counting() -> None:
    journal = dataclasses.replace(_deal(10, order=11, tag="journal"), entry_kind=None)
    history = dataclasses.replace(
        journal,
        fill_time="1780000000000",
        entry_kind="DEAL_ENTRY_OUT",
        reason="DEAL_REASON_SL",
        server_reference_price=Decimal("100"),
        server_reference_kind="SERVER_LEVEL_EXACT",
        provenance=(_provenance("history"),),
    )

    merged = subject.deduplicate_deals([journal, history])

    assert len(merged) == 1
    assert merged[0].fill_time == "1780000000000"
    assert merged[0].server_reference_price == Decimal("100")
    assert {item.source_id for item in merged[0].provenance} == {"journal", "history"}


def test_conflicting_duplicate_request_fails() -> None:
    first = _request(hint=44, reference="100", tag="one")
    second = dataclasses.replace(
        first,
        reference_price=Decimal("100.1"),
        provenance=(_provenance("two"),),
    )
    with pytest.raises(subject.LedgerError, match="conflicting duplicate request"):
        subject.deduplicate_requests([first, second])


def test_same_deal_ticket_on_different_accounts_is_not_deduplicated() -> None:
    dxz = _deal(1, order=10)
    ftmo = _deal(
        1,
        order=10,
        raw_symbol="US100.cash",
        venue="FTMO_TRIAL",
        account="1513845506",
        server="FTMO-Demo",
    )
    assert len(subject.deduplicate_deals([dxz, ftmo])) == 2


def test_exact_server_sl_level_is_qualification_eligible() -> None:
    deal = _deal(
        900,
        order=901,
        side="SELL",
        fill="98",
        server_reference="100",
        reason="DEAL_REASON_SL",
    )

    row = subject.build_observations(
        [], [deal], aliases=_aliases(), symbol_properties=_properties()
    )[0]

    assert row["execution_kind"] == "SL_EXIT"
    assert row["reference_kind"] == "SERVER_LEVEL_EXACT"
    assert row["signed_slip_points"] == "2"
    assert row["eligibility"] == "QUALIFICATION"


def test_unreferenced_legacy_close_stays_diagnostic() -> None:
    row = subject.build_observations(
        [], [_deal(5, order=6)], aliases=_aliases(), symbol_properties=_properties()
    )[0]

    assert row["execution_kind"] == "UNREFERENCED_EXECUTION"
    assert row["reference_kind"] == "NONE"
    assert row["join_method"] == "NO_REQUEST_JOIN"
    assert row["eligibility"] == "DIAGNOSTIC"
    assert row["signed_slip_points"] is None


def test_missing_symbol_properties_and_unknown_alias_fail_closed() -> None:
    request = _request(order=10)
    deal = _deal(1, order=10)
    with pytest.raises(subject.LedgerError, match="missing symbol properties"):
        subject.build_observations(
            [request], deal and [deal], aliases=_aliases(), symbol_properties={}
        )
    unknown = dataclasses.replace(deal, raw_symbol="UNKNOWN")
    unknown_request = dataclasses.replace(request, raw_symbol="UNKNOWN")
    with pytest.raises(subject.LedgerError, match="no exact symbol alias"):
        subject.build_observations(
            [unknown_request],
            [unknown],
            aliases=_aliases(),
            symbol_properties=_properties(raw_symbol="UNKNOWN"),
        )


def test_symbol_properties_reject_nonintegral_tick_to_point_ratio() -> None:
    with pytest.raises(subject.LedgerError, match="integer multiple"):
        subject.load_symbol_properties(
            [
                {
                    "venue_id": "V",
                    "account_id": "A",
                    "raw_symbol": "S",
                    "point": "0.1",
                    "digits": 1,
                    "trade_tick_size": "0.15",
                    "volume_step": "0.01",
                }
            ]
        )


def test_nearest_rank_p95_has_no_interpolation_or_extrapolation() -> None:
    thirty = [Decimal(index) for index in range(1, 31)]
    thirty_one = [Decimal(index) for index in range(1, 32)]
    historical_regression = [
        Decimal(value) for value in (-49, -22, 0, 12, 50, 64, 67, 80, 96, 104, 1378)
    ]

    assert subject.nearest_rank(thirty) == Decimal(29)
    assert subject.nearest_rank(thirty_one) == Decimal(30)
    assert subject.nearest_rank(historical_regression) == Decimal(1378)
    assert subject.nearest_rank(historical_regression) <= max(historical_regression)
    with pytest.raises(subject.LedgerError, match="at least one"):
        subject.nearest_rank([])
    with pytest.raises(subject.LedgerError, match="<= 1"):
        subject.nearest_rank([Decimal(1)], Decimal("1.01"))


def _summary_observations(count: int) -> list[dict]:
    return [
        {
            "venue_id": "DXZ_LIVE",
            "account_id": "4000090541",
            "server": "Darwinex-Live",
            "logical_symbol": "NDX.DWX",
            "raw_symbol": "NDX",
            "eligibility": "QUALIFICATION",
            "adverse_points": str(index),
        }
        for index in range(1, count + 1)
    ]


def test_summary_gate_is_unresolved_at_29_and_passes_at_30() -> None:
    unresolved = subject.build_ledger_summary(
        "L", "2026-07-19T00:00:00Z", "2026-07-20T00:00:00Z", _summary_observations(29)
    )
    passing = subject.build_ledger_summary(
        "L", "2026-07-19T00:00:00Z", "2026-07-20T00:00:00Z", _summary_observations(30)
    )

    assert unresolved["symbols"][0]["qualification_status"] == "UNRESOLVED"
    assert passing["symbols"][0]["qualification_status"] == "PASS"
    assert passing["symbols"][0]["p95_adverse_points"] == "29"
    assert passing["symbols"][0]["observed_max_adverse_points"] == "30"


def test_summary_does_not_pool_same_logical_symbol_across_venues() -> None:
    rows = _summary_observations(15)
    rows.extend(
        {
            **row,
            "venue_id": "FTMO_TRIAL",
            "account_id": "1513845506",
            "server": "FTMO-Demo",
            "raw_symbol": "US100.cash",
        }
        for row in _summary_observations(15)
    )

    summary = subject.build_ledger_summary(
        "L", "2026-07-19T00:00:00Z", "2026-07-20T00:00:00Z", rows
    )

    assert len(summary["symbols"]) == 2
    assert {row["eligible_samples"] for row in summary["symbols"]} == {15}
    assert {row["qualification_status"] for row in summary["symbols"]} == {"UNRESOLVED"}


def test_source_binding_detects_hash_drift(tmp_path: Path) -> None:
    source_path = tmp_path / "source.log"
    source_path.write_text("first\n", encoding="utf-8")
    spec = subject.SourceSpec("S", "V", "A", "SERVER", "EA_JSON_LOG", source_path)
    binding = subject.capture_source(spec).binding

    subject.verify_source_binding(binding)
    source_path.write_text("second\n", encoding="utf-8")
    with pytest.raises(subject.LedgerError, match="drift"):
        subject.verify_source_binding(binding)


def test_build_aborts_without_publication_when_source_drifts(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec_path = _write_offline_fixture(tmp_path)
    output = tmp_path / "bundle"
    original = subject.parse_ea_json_log

    def parse_then_mutate(captured: subject.CapturedSource) -> list[subject.RequestRecord]:
        rows = original(captured)
        captured.spec.path.write_bytes(captured.raw_bytes + b"\n")
        return rows

    monkeypatch.setattr(subject, "parse_ea_json_log", parse_then_mutate)

    with pytest.raises(subject.LedgerError, match="drift"):
        subject.build_bundle(
            spec_path, output, generated_utc="2026-07-20T00:00:00Z"
        )
    assert not output.exists()


def test_json_parser_rejects_nonfinite_numbers() -> None:
    with pytest.raises(subject.LedgerError, match="non-finite"):
        subject.strict_json_loads('{"price":NaN}', label="nan.json")


def test_utf16_journal_and_utf8_entry_log_parse_and_join(tmp_path: Path) -> None:
    journal_path = tmp_path / "20260710.log"
    journal_line = (
        "FF\t0\t15:59:57.256\tTrades\t'4000090541': deal #147536274 buy "
        "0.08 NDX at 29725.2 done (based on order #3165578509)\r\n"
    )
    journal_path.write_text(journal_line, encoding="utf-16")
    entry_path = tmp_path / "QM5_10692_ea-10692.log"
    event = {
        "ts_utc": "2026-07-10T13:59:57.796Z",
        "ea_id": 10692,
        "symbol": "NDX",
        "event": "ENTRY_ACCEPTED",
        "payload": {
            "ticket": 3165578509,
            "symbol": "NDX",
            "type": "QM_BUY",
            "lots": 0.08,
            "price": 29724.2,
            "magic": 106920005,
        },
    }
    entry_path.write_text(json.dumps(event) + "\n", encoding="utf-8")
    journal = subject.capture_source(
        subject.SourceSpec(
            "J", "DXZ_LIVE", "4000090541", "Darwinex-Live", "TERMINAL_JOURNAL", journal_path
        )
    )
    entries = subject.capture_source(
        subject.SourceSpec(
            "E", "DXZ_LIVE", "4000090541", "Darwinex-Live", "EA_JSON_LOG", entry_path
        )
    )

    requests = subject.parse_ea_json_log(entries)
    deals = subject.parse_terminal_journal(journal)
    row = subject.build_observations(
        requests,
        deals,
        aliases=_aliases(),
        symbol_properties=_properties(point="0.1", volume_step="0.01"),
    )[0]

    assert row["join_method"] == "ENTRY_TICKET_TO_ORDER_EXACT"
    assert row["signed_slip_price"] == "1"
    assert row["signed_slip_points"] == "10"
    assert row["eligibility"] == "QUALIFICATION"


def _history_row(**overrides: object) -> dict:
    row = {
        "account_id": "4000090541",
        "server": "Darwinex-Live",
        "deal_ticket": 1001,
        "order_ticket": 1002,
        "position_id": 1003,
        "time_msc": 1780000000000,
        "type": "DEAL_TYPE_SELL",
        "entry": "DEAL_ENTRY_OUT",
        "reason": "DEAL_REASON_SL",
        "magic": 106920005,
        "symbol": "NDX",
        "volume": 1,
        "price": 98,
        "sl": 100,
        "tp": 110,
        "commission": 0,
        "swap": 0,
        "profit": -2,
        "fee": 0,
    }
    row.update(overrides)
    return row


def test_history_export_supplies_exact_sl_reference(tmp_path: Path) -> None:
    path = tmp_path / "history.jsonl"
    path.write_text(json.dumps(_history_row()) + "\n", encoding="utf-8")
    captured = subject.capture_source(
        subject.SourceSpec(
            "H", "DXZ_LIVE", "4000090541", "Darwinex-Live", "HISTORY_DEALS_JSONL", path
        )
    )

    deals = subject.parse_history_deals_jsonl(captured)
    row = subject.build_observations(
        [], deals, aliases=_aliases(), symbol_properties=_properties()
    )[0]

    assert deals[0].server_reference_price == Decimal(100)
    assert row["execution_kind"] == "SL_EXIT"
    assert row["reference_price"] == "100"
    assert row["signed_slip_points"] == "2"


def _write_offline_fixture(tmp_path: Path, *, reverse_sources: bool = False) -> Path:
    entry_path = tmp_path / "entry.log"
    entry_path.write_text(
        json.dumps(
            {
                "ts_utc": "2026-07-10T13:59:57Z",
                "ea_id": 10692,
                "symbol": "NDX",
                "event": "ENTRY_ACCEPTED",
                "payload": {
                    "ticket": 500,
                    "symbol": "NDX",
                    "type": "QM_BUY",
                    "lots": 1,
                    "price": 100,
                    "magic": 106920005,
                },
            },
            separators=(",", ":"),
        )
        + "\n",
        encoding="utf-8",
    )
    journal_path = tmp_path / "20260710.log"
    journal_path.write_text(
        "AA\t0\t10:00:00.000\tTrades\t'4000090541': deal #501 buy 1 NDX at 101 "
        "done (based on order #500)\r\n",
        encoding="utf-16",
    )
    sources = [
        {
            "source_id": "ENTRY",
            "venue_id": "DXZ_LIVE",
            "account_id": "4000090541",
            "server": "Darwinex-Live",
            "role": "EA_JSON_LOG",
            "path": str(entry_path),
        },
        {
            "source_id": "JOURNAL",
            "venue_id": "DXZ_LIVE",
            "account_id": "4000090541",
            "server": "Darwinex-Live",
            "role": "TERMINAL_JOURNAL",
            "path": str(journal_path),
        },
    ]
    if reverse_sources:
        sources.reverse()
    spec = {
        "schema_version": 1,
        "ledger_id": "OFFLINE_TEST",
        "cutoff_utc": "2026-07-19T23:59:59Z",
        "alias_policy": str(ALIAS_PATH),
        "symbol_properties": [
            {
                "venue_id": "DXZ_LIVE",
                "account_id": "4000090541",
                "raw_symbol": "NDX",
                "point": "1",
                "digits": 0,
                "trade_tick_size": "1",
                "volume_step": "0.01",
            }
        ],
        "sources": sources,
    }
    spec_path = tmp_path / ("spec-reversed.json" if reverse_sources else "spec.json")
    spec_path.write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")
    return spec_path


def test_offline_bundle_has_hash_bound_manifest_and_no_self_hash(tmp_path: Path) -> None:
    spec_path = _write_offline_fixture(tmp_path)
    output = tmp_path / "bundle"

    manifest = subject.build_bundle(
        spec_path, output, generated_utc="2026-07-20T00:00:00Z"
    )

    manifest_bytes = (output / "manifest.json").read_bytes()
    ledger_bytes = (output / "ledger.json").read_bytes()
    observations_bytes = (output / "observations.jsonl").read_bytes()
    detached = (output / "manifest.json.sha256").read_text(encoding="ascii")
    assert "manifest_sha256" not in manifest
    assert "artifact_payload_sha256" not in manifest
    assert detached == f"{hashlib.sha256(manifest_bytes).hexdigest()}  manifest.json\n"
    assert manifest["artifacts"]["ledger"]["sha256"] == hashlib.sha256(ledger_bytes).hexdigest()
    assert manifest["artifacts"]["observations"]["sha256"] == hashlib.sha256(
        observations_bytes
    ).hexdigest()
    assert manifest["counts"] == {"observations": 1, "eligible": 1, "diagnostic": 0}
    assert {path.name for path in output.iterdir()} == {
        "ledger.json",
        "manifest.json",
        "manifest.json.sha256",
        "observations.jsonl",
    }


def test_source_order_does_not_change_observations_or_ledger(tmp_path: Path) -> None:
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    normal_spec = _write_offline_fixture(data_dir)
    reverse_spec = _write_offline_fixture(data_dir, reverse_sources=True)
    normal_bundle = tmp_path / "normal-bundle"
    reverse_bundle = tmp_path / "reverse-bundle"

    subject.build_bundle(
        normal_spec, normal_bundle, generated_utc="2026-07-20T00:00:00Z"
    )
    subject.build_bundle(
        reverse_spec, reverse_bundle, generated_utc="2026-07-20T00:00:00Z"
    )

    assert (normal_bundle / "observations.jsonl").read_bytes() == (
        reverse_bundle / "observations.jsonl"
    ).read_bytes()
    assert (normal_bundle / "ledger.json").read_bytes() == (
        reverse_bundle / "ledger.json"
    ).read_bytes()


def test_bundle_publication_is_exclusive(tmp_path: Path) -> None:
    spec_path = _write_offline_fixture(tmp_path)
    output = tmp_path / "bundle"
    subject.build_bundle(spec_path, output, generated_utc="2026-07-20T00:00:00Z")

    with pytest.raises(subject.LedgerError, match="already exists"):
        subject.build_bundle(spec_path, output, generated_utc="2026-07-20T00:00:00Z")


def test_input_spec_requires_explicit_sources_and_rejects_extra_keys(tmp_path: Path) -> None:
    spec_path = _write_offline_fixture(tmp_path)
    payload = json.loads(spec_path.read_text(encoding="utf-8"))
    payload["unexpected"] = True
    spec_path.write_text(json.dumps(payload), encoding="utf-8")

    with pytest.raises(subject.LedgerError, match="keys invalid"):
        subject.build_bundle(
            spec_path, tmp_path / "bundle", generated_utc="2026-07-20T00:00:00Z"
        )


def test_input_spec_rejects_reserved_source_ids(tmp_path: Path) -> None:
    spec_path = _write_offline_fixture(tmp_path)
    payload = json.loads(spec_path.read_text(encoding="utf-8"))
    payload["sources"][0]["source_id"] = "GENERATOR"
    spec_path.write_text(json.dumps(payload), encoding="utf-8")

    with pytest.raises(subject.LedgerError, match="source_id is reserved"):
        subject.build_bundle(
            spec_path, tmp_path / "bundle", generated_utc="2026-07-20T00:00:00Z"
        )
