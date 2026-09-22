"""Fixed June-2019 offline development reference: 20 dates x 3 arms x 3 costs.

Prepare immutable hash-bound plan before execution. No network, key, purchase,
strategy selection, frozen trial promotion or data repair. Cash-window raw bytes
are extracted in one bounded pass per needed source, with full source hash checks.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import asdict, replace
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import struct

import numpy as np

from replay_adapter import MBP, STATUS, ReplayEvent, iter_source_records, merge_events
from strategy_runner import (
    ARM_IDS, DEFAULT_CONFIG, FROZEN_SHA256, HERE, NS, DataInvalid, SessionPolicy,
    candidate_contract, cash_ns, load_frozen, policy_outcome, run_session_reference,
    sha256_file, timestamp_ns, trade_bars,
)
from validate_databento_pilot import fingerprint, read_header

EVIDENCE = Path("D:/QM/reports/research/futures_pivot_20260922/progress_20260922")
DATA_VALIDATION = EVIDENCE / "june2019_data_validation_v2.json"
CALENDAR = EVIDENCE / "june2019_observed_calendar.json"
NEWS = EVIDENCE / "news_calendar_june2019.json"
SCENARIOS = ("BASE","ADVERSE","SEVERE")
TRADE = struct.Struct("<BBHIQqIBBBBQiI")
ORDINAL = struct.Struct("<Q")
MAX_CASH_RECORDS_PER_SOURCE_DAY = 2_000_000
MAX_SOURCE_CACHE_BYTES = 768*1024*1024
SCHEMA = "qm.june2019-reference-plan/v1"


def need(condition: bool, message: str):
    if not condition:
        raise DataInvalid(message)


def read_json(path: Path):
    return json.loads(path.read_bytes())


def save_exclusive(path: Path, value: dict):
    with path.open("x",encoding="utf-8",newline="\n") as stream:
        json.dump(value,stream,indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def dates() -> list[str]:
    start = date(2019,6,3)
    return [(start+timedelta(days=i)).isoformat() for i in range(26)
            if (start+timedelta(days=i)).weekday() < 5]


def binding(path: Path) -> dict:
    return {"path":str(path.resolve()),"sha256":sha256_file(path),"bytes":path.stat().st_size}


def verify_binding(row: dict):
    path = Path(row["path"])
    need(path.stat().st_size == row["bytes"] and sha256_file(path) == row["sha256"],"BOUND_INPUT_CHANGED:"+str(path))


def make_policies(validation: dict, calendar: dict, news: dict, now_ns: int) -> dict[str,SessionPolicy]:
    need(validation["status"] == "RAW_VALIDATED_QUALITY_FLAGS_RETAINED","RAW_VALIDATION_NOT_COMPLETE")
    need(news["complete_for_covered_sessions"] is True and news["point_in_time"] is False,"NEWS_ARCHIVE_CLASSIFICATION")
    session_rows = {row["day"]:row for row in calendar["sessions"]}
    need(set(session_rows) == set(dates()),"CALENDAR_NOT_ALL_TWENTY_DATES")
    covered = set(news["covered_session_dates"])
    need(covered <= set(dates()),"NEWS_COVERAGE_OUTSIDE_FIXED_MONTH")
    event_times = []
    for event in news["events"]:
        need(event["currency"] == "USD" and event["impact"] == "HIGH" and event["time_status"] == "TIMED","NEWS_EVENT_IDENTITY")
        event_times.append(timestamp_ns(event["timestamp_utc"]))
    outputs = {}
    for day in dates():
        row = session_rows[day]
        symbol,roll = candidate_contract("MES",day)
        need(row["symbol"] == symbol and row["roll_excluded"] is roll,"CALENDAR_ROLL_MISMATCH")
        definition = next(item for item in validation["files"] if item["symbol"] == symbol and item["schema"] == "definition")
        outputs[day] = SessionPolicy(day=day,calendar_verified=True,
            regular_cash_session=row.get("regular_cash_session_observed",False),
            news_covered=day in covered,news_as_of_ns=timestamp_ns(news["extracted_at_utc"]),
            high_usd_event_ns=tuple(event_times),definitions_verified=True,
            raw_contract_data_verified=True,stage1_technical_pass=False,
            fill_instrument_id=int(definition["instrument_id"]),
            calendar_basis="OBSERVED_CME_STATUS_WITH_DATED_RULES_REFERENCE_ONLY")
        # Evaluate now so stale/missing calendar choices are recorded pre-result.
        policy_outcome(outputs[day],now_ns,1)
    return outputs


def prepare(output: Path, *, news_path: Path = NEWS) -> Path:
    need(not output.exists(),"OUTPUT_DIRECTORY_ALREADY_EXISTS")
    config = load_frozen()
    now = datetime.now(timezone.utc)
    now_ns = timestamp_ns(now.isoformat())
    validation,calendar,news = map(read_json,(DATA_VALIDATION,CALENDAR,news_path))
    policies = make_policies(validation,calendar,news,now_ns)
    refs = {"validation":binding(DATA_VALIDATION),"calendar":binding(CALENDAR),"news":binding(news_path),
            "config":binding(DEFAULT_CONFIG)}
    need(calendar["raw_validation_sha256"] == sha256_file(EVIDENCE/"june2019_data_validation.json"),"CALENDAR_ORIGINAL_VALIDATION_BINDING")
    refs["calendar_original_validation"] = binding(EVIDENCE/"june2019_data_validation.json")
    refs["calendar_primary_source"] = binding(Path(calendar["primary_source_extract"]))
    need(refs["calendar_primary_source"]["sha256"] == calendar["primary_source_extract_sha256"],"CALENDAR_PRIMARY_SOURCE_HASH")
    for symbol in ("MESM9","MESU9","ESM9","ESU9"):
        raw = next(row for row in validation["files"] if row["symbol"] == symbol and row["schema"] == "definition")
        proof_path = Path(raw["path"]).with_name("definition.proof.json")
        proof = read_json(proof_path)
        need(proof["status"] == "DEFINITION_VERIFIED" and proof["file_sha256"] == raw["file_sha256"],"DEFINITION_PROOF_BINDING")
        need(sha256_file(Path(raw["path"])) == raw["file_sha256"],"DEFINITION_FILE_CHANGED")
        multiplier = "5" if symbol.startswith("MES") else "50"
        need(all(row["raw_symbol"] == symbol and row["price_increment"] == "0.25" and row["multiplier"] == multiplier
                 and row["currency"] == "USD" for row in proof["rows"]) and proof["rows"],"DEFINITION_ECONOMICS")
        refs[symbol+"_definition_proof"] = binding(proof_path)
        refs[symbol+"_definition_raw"] = binding(Path(raw["path"]))
    for suffix in ("M9","U9"):
        micro = read_json(Path(refs["MES"+suffix+"_definition_proof"]["path"]))
        mini = read_json(Path(refs["ES"+suffix+"_definition_proof"]["path"]))
        need({row["expiration_ns"] for row in micro["rows"]} == {row["expiration_ns"] for row in mini["rows"]},"MINI_MICRO_EXPIRY_MISMATCH")
    code = {name:binding(HERE/name) for name in (
        "strategy_runner.py","run_june2019_reference.py","replay_adapter.py","preregister.py",
        "validate_databento_pilot.py","strategy_run_plan.md")}
    sessions = [{"day":day,"policy":asdict(policies[day]),
                 "pre_result_exclusion":policy_outcome(policies[day],now_ns,1)} for day in dates()]
    cells = [{"arm_id":arm,"period_id":"development","scenario_id":scenario,"day":day,
              "result_status":"NOT_RUN"} for day in dates() for arm in ARM_IDS[:3] for scenario in SCENARIOS]
    need(len(cells) == 180,"SESSION_ROW_COUNT")
    output.mkdir(parents=True,exist_ok=False)
    plan = {"schema":SCHEMA,"prepared_at_utc":now.isoformat(),"prepared_at_ns":now_ns,
        "classification":"DEVELOPMENT_REFERENCE_DIAGNOSTIC_NOT_FROZEN_TRIAL",
        "config_sha256":FROZEN_SHA256,"bindings":refs,"source_code":code,
        "sessions":sessions,"rows":cells,"session_count":20,"session_row_count":180,
        "frozen_trial_cells":60,"frozen_trial_status":"NOT_RUN",
        "inputs":validation["files"],"runtime":{"tzdata":importlib.metadata.version("tzdata"),
        "numpy":np.__version__,"nautilus_available":importlib.metadata.version("nautilus_trader")},
        "limitations":["Reference executor, not native Nautilus strategy parity.",
            f"Named-vendor reconstructed news covers {len(news['covered_session_dates'])} of20 planned dates; missing dates are skipped.",
            "Observed status calendar is not a complete official 2019 holiday archive.",
            "Micro action-T in MBP-1 is used as a descriptive last-trade source; independent trade-schema equivalence is not proven.",
            "No statistical significance, validation advance, holdout or payout claim from this diagnostic.",
            "Any DATA_INVALID poisons its arm/scenario account path; no reset to50000 on later sessions."]}
    target = output/"plan.json"
    save_exclusive(target,plan)
    print(json.dumps({"status":"PREPARED","plan":str(target),"plan_sha256":sha256_file(target),"session_rows":180}),flush=True)
    return target


def extract_cash(row: dict, selected_days: list[str]) -> dict[str,bytes]:
    """Single read of a bound source; returned records keep original ordinals."""
    schema = row["schema"]
    decoder = MBP if schema == "mbp-1" else TRADE
    expected_code = 1 if schema == "mbp-1" else 4
    path = Path(row["path"])
    before = fingerprint(path)
    digest = hashlib.sha256()
    buffers = {day:bytearray() for day in selected_days}
    windows = {day:(cash_ns(day,"09:30:00"),cash_ns(day,"16:00:00")) for day in selected_days}
    dtype = np.dtype({"names":["recv"],"formats":["<u8"],"offsets":[32],"itemsize":decoder.size})
    count = 0
    with path.open("rb") as stream:
        meta = read_header(stream,digest)
        need(meta["dbn_version"] == 3 and meta["schema_code"] == expected_code,"CASH_SOURCE_HEADER")
        while True:
            block = stream.read(16384*decoder.size)
            if not block:
                break
            need(len(block) % decoder.size == 0,"CASH_SOURCE_FRAMING")
            digest.update(block)
            recv = np.frombuffer(block,dtype=dtype)["recv"]
            for day,(start,end) in windows.items():
                for index in np.flatnonzero((recv >= start) & (recv < end)):
                    offset = int(index)*decoder.size
                    buffers[day].extend(ORDINAL.pack(count+int(index)))
                    buffers[day].extend(block[offset:offset+decoder.size])
                need(len(buffers[day]) <= MAX_CASH_RECORDS_PER_SOURCE_DAY*(decoder.size+8),"CASH_CACHE_RECORD_CAP")
            count += len(recv)
            need(sum(map(len,buffers.values())) <= MAX_SOURCE_CACHE_BYTES,"TOTAL_SOURCE_CASH_CACHE_CAP")
    need(fingerprint(path) == before and digest.hexdigest() == row["file_sha256"]
         and count == row["record_count"],"CASH_SOURCE_HASH_OR_COUNT_CHANGED")
    print(json.dumps({"status":"CASH_CACHE_VERIFIED","symbol":row["symbol"],"schema":schema,
        "all_source_records_hashed":count,"retained":{day:len(buf)//(decoder.size+8) for day,buf in buffers.items()}}),flush=True)
    return {day:bytes(value) for day,value in buffers.items()}


def cached_records(data: bytes, decoder):
    width = decoder.size+8
    need(len(data) % width == 0,"CACHE_FRAME")
    for offset in range(0,len(data),width):
        source_ordinal = ORDINAL.unpack_from(data,offset)[0]
        raw = data[offset+8:offset+width]
        yield source_ordinal,raw,decoder.unpack(raw)


def session_statuses(row: dict, day: str):
    records = list(iter_source_records(Path(row["path"]),"status",row))
    start,end = cash_ns(day,"09:30:00"),cash_ns(day,"16:00:00")
    prior = [record for record in records if record[2][5] < start]
    need(bool(prior),"NO_REAL_PRECEDING_SESSION_STATUS")
    return [prior[-1]]+[record for record in records if start <= record[2][5] < end]


def mini_events(data: bytes):
    for ordinal,(source_ordinal,raw,row) in enumerate(cached_records(data,TRADE)):
        yield ReplayEvent(kind="trades",replay_ordinal=ordinal,source_ordinal=source_ordinal,
            ts_recv_ns=row[11],ts_exchange_ns=row[4],instrument_id=row[3],publisher_id=row[2],
            source_sequence=row[13],action=row[7],side=row[8],flags=row[9],
            trade_price_raw=row[5],trade_size=row[6],raw_record=raw)


def carry_forward(state: dict, row: dict):
    """An unknown path never becomes a new flat $50k account on the next day."""
    if not row["account_path_valid"] or row["ending_balance_usd"] is None:
        state["valid"] = False
        state["balance"] = None
        state["invalid_at"] = state.get("invalid_at",row["chicago_trade_date"])
        return
    need(state["valid"],"CANNOT_RESUME_POISONED_ACCOUNT")
    state.update(balance=Decimal(row["ending_balance_usd"]),
                 high=Decimal(row["high_watermark_usd"]),halt=state["halt"] or row["research_halt"])


def execute(plan_path: Path) -> Path:
    plan = read_json(plan_path)
    need(plan["schema"] == SCHEMA and plan["session_row_count"] == 180,"PLAN_IDENTITY")
    need(plan["frozen_trial_status"] == "NOT_RUN" and plan["config_sha256"] == FROZEN_SHA256,"FROZEN_PLAN_IDENTITY")
    for row in list(plan["bindings"].values())+list(plan["source_code"].values()):
        verify_binding(row)
    plan_sha = sha256_file(plan_path)
    output = plan_path.parent
    save_exclusive(output/"attempt.json",{"status":"EXECUTION_STARTED","at_utc":datetime.now(timezone.utc).isoformat(),"plan_sha256":plan_sha})
    config = load_frozen()
    policies = {row["day"]:SessionPolicy(**{**row["policy"],"high_usd_event_ns":tuple(row["policy"]["high_usd_event_ns"]),
                                              "input_manifest_sha256":plan_sha}) for row in plan["sessions"]}
    now_ns = timestamp_ns(datetime.now(timezone.utc).isoformat())
    eligible = [day for day in dates() if policy_outcome(policies[day],now_ns,1) is None]
    need(eligible == [r["day"] for r in plan["sessions"] if r["pre_result_exclusion"] is None],"PREBOUND_NEWS_SCOPE_CHANGED")
    row_for = {(row["symbol"],row["schema"]):row for row in plan["inputs"]}
    caches = {}
    for root,schema in (("MES","mbp-1"),("ES","trades")):
        for symbol in sorted({candidate_contract(root,day)[0] for day in eligible}):
            selected = [day for day in eligible if candidate_contract(root,day)[0] == symbol]
            caches[symbol] = extract_cash(row_for[symbol,schema],selected)
    materialized = {}
    diagnostics = {}
    for day in eligible:
        fill_symbol,_ = candidate_contract("MES",day)
        signal_symbol,_ = candidate_contract("ES",day)
        statuses = session_statuses(row_for[fill_symbol,"status"],day)
        # Replay inputs remain lazily re-iterable from bounded raw cash bytes.
        def micro_events(day=day,statuses=statuses,fill_symbol=fill_symbol):
            return merge_events(cached_records(caches[fill_symbol][day],MBP),iter(statuses))
        per_day = {"events":micro_events,fill_symbol:None,signal_symbol:None,"errors":{}}
        for symbol,events in ((fill_symbol,micro_events()),(signal_symbol,mini_events(caches[signal_symbol][day]))):
            try:
                per_day[symbol] = tuple(trade_bars(events,symbol,end_watermark_ns=cash_ns(day,"16:00:00")))
            except DataInvalid as exc:
                per_day["errors"][symbol] = str(exc)
        materialized[day] = per_day
        diagnostics[day] = {"bar_counts":{symbol:len(per_day[symbol]) if per_day[symbol] is not None else None for symbol in (fill_symbol,signal_symbol)},
                            "bar_errors":per_day["errors"],"status_seed_original_ns":statuses[0][2][5]}
    states = {(arm,scenario):{"valid":True,"balance":Decimal("50000"),"high":Decimal("50000"),"halt":False}
              for arm in ARM_IDS[:3] for scenario in SCENARIOS}
    results = []
    for planned in plan["rows"]:
        day,arm,scenario = planned["day"],planned["arm_id"],planned["scenario_id"]
        state = states[arm,scenario]
        per_day = materialized.get(day)
        p = policies[day]
        if not state["valid"]:
            row = {"arm_id":arm,"scenario_id":scenario,"chicago_trade_date":day,"period_id":"development",
                "signal_raw_symbol":candidate_contract("ES" if arm == ARM_IDS[1] else "MES",day)[0],
                "fill_raw_symbol":candidate_contract("MES",day)[0],"outcome":"DATA_INVALID",
                "reason_code":"PRIOR_ACCOUNT_PATH_INVALID","account_path_valid":False,
                "ending_balance_usd":None,"net_profit_usd":None,"net_R":None,
                "classification":"DEVELOPMENT_REFERENCE_DIAGNOSTIC","frozen_trial_result_status":"NOT_RUN",
                "economic_success_certified":False,"input_manifest_sha256":plan_sha,"config_sha256":FROZEN_SHA256,
                "calendar_exclusion_if_independent":policy_outcome(p,now_ns,1),"invalid_since":state["invalid_at"]}
        else:
            if per_day:
                fill_symbol,_ = candidate_contract("MES",day)
                signal_symbol = candidate_contract("ES",day)[0] if arm == ARM_IDS[1] else fill_symbol
                fill_bars = per_day[fill_symbol] or ()
                signal_bars = per_day[signal_symbol] or ()
                events = per_day["events"]()
            else:
                fill_bars,signal_bars,events = (),(),()
            row = run_session_reference(config,arm,scenario,p,signal_bars,fill_bars,events,now_ns=now_ns,
                mode="DEVELOPMENT_DIAGNOSTIC",starting_balance=state["balance"],
                prior_high_watermark=state["high"],prior_halt=state["halt"])
            if per_day and per_day["errors"]:
                row["source_bar_errors"] = per_day["errors"]
            carry_forward(state,row)
        results.append(row)
        if len(results) % 9 == 0:
            print(json.dumps({"status":"SESSION_ROWS_RETAINED","through_day":day,"rows":len(results)}),flush=True)
    need(len(results) == 180,"RESULT_ROW_LOSS")
    summary = []
    for arm in ARM_IDS[:3]:
        for scenario in SCENARIOS:
            rows = [r for r in results if r["arm_id"] == arm and r["scenario_id"] == scenario]
            known = [Decimal(r["net_profit_usd"]) for r in rows if r["net_profit_usd"] is not None]
            complete = all(r["account_path_valid"] for r in rows)
            summary.append({"arm_id":arm,"scenario_id":scenario,"session_rows":len(rows),
                "outcomes":dict(Counter(r["outcome"] for r in rows)),"account_path_valid":complete,
                "known_prefix_net_profit_usd":str(sum(known,Decimal(0))),
                "full_path_net_profit_usd":str(sum(known,Decimal(0))) if complete else None})
    result = {"schema":"qm.june2019-reference-result/v1","at_utc":datetime.now(timezone.utc).isoformat(),
        "classification":"DEVELOPMENT_REFERENCE_DIAGNOSTIC","plan_sha256":plan_sha,
        "frozen_trial_status":"NOT_RUN","frozen_trial_cells":60,"economic_success_certified":False,
        "session_row_count":180,"session_count":20,"eligible_news_dates":eligible,
        "input_diagnostics":diagnostics,"summary":summary,"rows":results,"limitations":plan["limitations"]}
    need(sha256_file(plan_path) == plan_sha,"PLAN_CHANGED_DURING_EXECUTION")
    target = output/"result.json"
    save_exclusive(target,result)
    save_exclusive(output/"completion.json",{"status":"REFERENCE_COMPLETE","plan_sha256":plan_sha,
        "result_sha256":sha256_file(target),"result":str(target),"session_rows":180,
        "frozen_trial_status":"NOT_RUN","economic_success_certified":False})
    print(json.dumps({"status":"REFERENCE_COMPLETE","result":str(target),"summary":summary}),flush=True)
    return target


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--prepare",type=Path,help="New output directory; immutable plan only")
    group.add_argument("--execute-plan",type=Path,help="Execute an unchanged prepared plan once")
    parser.add_argument("--news",type=Path,default=NEWS,help="Verified calendar revision to bind before preparing the plan")
    args = parser.parse_args(argv)
    if args.prepare:
        prepare(args.prepare,news_path=args.news)
    else:
        execute(args.execute_plan)


if __name__ == "__main__":
    main()
