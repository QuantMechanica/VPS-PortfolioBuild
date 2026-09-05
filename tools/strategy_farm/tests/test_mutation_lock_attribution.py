import datetime as dt
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from mutation_lock_attribution import summarize


def test_historical_intervals_unknowns_and_new_event_deduplication():
    start = dt.datetime(2026, 9, 5, tzinfo=dt.UTC)
    stamp = lambda seconds: (start + dt.timedelta(seconds=seconds)).isoformat()
    holds = [
        {"event": "ACQUIRED", "timestamp_utc": stamp(0), "nonce": "a", "owner": "worker:T3", "pid": 3},
        {"event": "RELEASED", "timestamp_utc": stamp(10), "nonce": "a"},
    ]
    events = [
        {"event": "claim_declined", "reason": "factory_mutation_lock_busy", "at_utc": stamp(2), "terminal": "T1"},
        {"event": "claim_declined", "reason": "factory_mutation_lock_busy", "at_utc": stamp(11), "terminal": "T1"},
        {"event": "claim_lock_busy", "at_utc": stamp(20), "terminal": "T1", "lock_owner": {"owner": "purge", "age_seconds": 4, "pid": 2}},
        {"event": "claim_declined", "reason": "factory_mutation_lock_busy", "at_utc": stamp(20), "terminal": "T1"},
        {"event": "claim_lock_busy", "at_utc": stamp(21), "terminal": "T1", "lock_owner": {"status": "read_timeout"}},
    ]
    result = summarize(holds, events, start=start, end=start+dt.timedelta(hours=2))
    assert result["busy_event_count"] == 4
    table = {row["owner"]: row for row in result["owner_table"]}
    assert table["worker:T3"]["count"] == 1
    assert table["worker:T3"]["median_age_seconds"] == 2
    assert table["UNKNOWN"]["count"] == 2
    assert table["purge"]["count"] == 1
    assert result["post_deployment_window_proven"] is False


def test_ambiguous_overlapping_holders_remain_unknown():
    start = dt.datetime(2026, 9, 5, tzinfo=dt.UTC)
    holds = [{"event": event, "timestamp_utc": (start+dt.timedelta(seconds=seconds)).isoformat(),
              "nonce": nonce, "owner": nonce, "pid": 1}
             for nonce in ("a", "b") for event, seconds in (("ACQUIRED", 0), ("RELEASED", 10))]
    event = {"event": "claim_declined", "reason": "factory_mutation_lock_busy", "at_utc": (start+dt.timedelta(seconds=5)).isoformat()}
    result = summarize(holds, [event], start=start, end=start+dt.timedelta(hours=2))
    assert result["owner_table"][0]["owner"] == "UNKNOWN"
