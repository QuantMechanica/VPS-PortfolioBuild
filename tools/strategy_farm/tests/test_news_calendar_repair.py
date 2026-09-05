from __future__ import annotations
import csv
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path

import pytest
from tools.strategy_farm import news_calendar_repair as repair
from tools.strategy_farm import news_calendar_diagnose as diagnose

UTC=timezone.utc


def row(source,utc,event,ccy="USD",impact="high"):
    t=repair.stamp(utc)
    raw=dict.fromkeys(repair.PRIMARY_FIELDS if source=="primary" else repair.SECONDARY_FIELDS,"")
    if source=="primary":raw.update(currency=ccy,event_name=event,impact=impact,actual="1.20",forecast="1.0",previous="1.1")
    else:raw.update(Currency=ccy,Event=event,Impact=impact.title(),Actual="1.20",Forecast="1.0",Previous="1.1")
    r=diagnose.CalendarRow(source,t,ccy,impact,event,raw)
    return diagnose.CalendarRow(source,t,ccy,impact,event,repair.project(r,t))


def native(utc,event,ccy="USD",code="nfp",eid="1"):
    return {"currency":ccy,"event":event,"instant":repair.stamp(utc),"event_id":eid,"code":code,"source":"synthetic_native_fixture","kind":"native"}


def test_shift_seam_fomc_and_impact_identity():
    data=[("2024-02-01T20:30Z","Non-Farm Employment Change","2024-02-02T13:30Z","Nonfarm Payrolls"),
          ("2024-03-15T11:30Z","CPI m/m","2024-03-15T12:30Z","CPI m/m"),
          ("2024-03-19T19:00Z","FOMC Statement","2024-03-20T18:00Z","Fed Interest Rate Decision")]
    p=[row("primary",old,event) for old,event,new,name in data]
    s=[row("secondary",old,event,impact="medium") for old,event,new,name in data]
    n=[native(new,name,eid=str(i)) for i,(old,event,new,name) in enumerate(data)]
    out,*_=repair.transform(p,s,n,[])
    assert [r.instant for r in out["primary"]]==[repair.stamp(v[2]) for v in data]
    assert [r.instant for r in out["primary"]]==[r.instant for r in out["secondary"]]
    assert out["primary"][0].raw["day_of_week"]=="4"
    assert out["primary"][0].raw["is_first_friday"]=="1"
    assert out["primary"][0].raw["actual"]=="1.20"
    assert out["secondary"][0].raw["Impact"]=="Medium"
    assert out["primary"][2].raw["is_fomc"]=="1"
    assert all(r.raw["is_high_impact"]=="1" for r in out["primary"])


def test_shutdown_native_anchor_and_hole_backfill_are_not_calendar_rules():
    n=[native("2025-11-20T13:30Z","Nonfarm Payrolls")]
    p=[row("primary","2025-11-19T20:30Z","Non-Farm Employment Change")]
    out,audit,gaps,counts,backfill,truth=repair.transform(p,[],n,[])
    corrected=out["primary"][0]
    assert corrected.instant==repair.stamp("2025-11-20T13:30Z")
    assert corrected.raw["day_of_week"]=="3" and corrected.raw["is_first_friday"]=="0"
    details,_=diagnose.diagnose_native_anchors(out["primary"],repair.expectation_catalog(truth))
    assert all(v["status"]=="PASS" for v in details)
    assert backfill=={"primary":1,"secondary":1}
    assert any(v["transform"]=="HOLE_BACKFILL_NATIVE_OR_OFFICIAL" for v in counts)


def test_eu_display_and_us_broker_rules_are_separate():
    t=repair.stamp("2024-03-15T12:30Z")
    assert repair.utc_to_eet(t).hour==14
    assert repair.broker_epoch_to_utc(int((t+timedelta(hours=3)).timestamp()))==t
    assert repair.utc_to_eet(repair.stamp("2024-04-05T12:30Z")).hour==15
    assert repair.utc_to_eet(repair.stamp("2024-11-01T12:30Z")).hour==14


def test_unanchored_high_is_declared_and_never_guessed_or_relabelled():
    p=[row("primary","2024-02-01T20:30Z","Core PPI m/m"),row("primary","2024-02-01T10:00Z","CPI y/y","EUR")]
    out,audit,gaps,*_=repair.transform(p,[],[],[])
    assert sorted(r.instant for r in out["primary"])==sorted(r.instant for r in p)
    assert len(gaps)==2 and all(g["retained_unverified_row"] for g in gaps)
    assert all(a["reason"]=="DECLARED_HIGH_GAP" for a in audit)
    assert all(r.impact=="high" for r in out["primary"])
    with pytest.raises(ValueError,match="NATIVE_TARGET_NAMES_MISSING.*Building Permits"):
        repair.assert_native_names([])


def test_class_offset_needs_three_distinct_confirmations_and_a_nonrate():
    native_rows=[];footprints=[]
    for i,utc in enumerate(["2025-02-06T12:00Z","2025-08-07T11:00Z","2025-12-18T12:00Z"]):
        t=repair.stamp(utc)
        native_rows.append(native((t+timedelta(hours=3)).isoformat(),"BoE Interest Rate Decision","GBP",repair.RATE_CODES["GBP"],str(i)))
        footprints.append({"currency":"GBP","event_code":repair.RATE_CODES["GBP"],"utc":t.isoformat(),"kind":"rate","status":"PASS"})
    policy={"offsets":{"GBP":[0,-3]}}
    selected,_=repair.select_nonusd(native_rows,policy,footprints)
    assert selected==[]
    footprints.append({"currency":"GBP","event_code":"cpi","utc":"2025-01-15T07:00Z","kind":"nonrate","status":"PASS"})
    selected,decisions=repair.select_nonusd(native_rows,policy,footprints)
    assert len(selected)==3
    assert all(r["raw_instant"]-r["instant"]==timedelta(hours=3) for r in selected)
    duplicate=[footprints[0]]*3
    assert repair.select_nonusd(native_rows,policy,duplicate)[0]==[]


def test_varying_offset_fan_never_creates_an_unproved_seasonal_selector():
    nr=[];fp=[]
    for i,(utc,h) in enumerate([("2025-02-18T03:30Z",3),("2025-08-12T04:30Z",4),("2025-12-09T03:30Z",3)]):
        t=repair.stamp(utc)
        nr.append(native((t+timedelta(hours=h)).isoformat(),"RBA Interest Rate Decision","AUD",repair.RATE_CODES["AUD"],str(i)))
        fp.append({"currency":"AUD","event_code":repair.RATE_CODES["AUD"],"utc":t.isoformat(),"kind":"rate","status":"PASS"})
    nr.append(native("2025-05-20T07:30Z","RBA Interest Rate Decision","AUD",repair.RATE_CODES["AUD"],"unanchored"))
    fp.append({"currency":"AUD","event_code":"cpi","utc":"2025-01-29T00:30Z","kind":"nonrate","status":"PASS"})
    selected,_=repair.select_nonusd(nr,{"offsets":{"AUD":[0,-3,-4]}},fp)
    assert len(selected)==3 and not any(n["event_id"]=="unanchored" for n in selected)


def test_native_mode_detects_unknown_high_and_retained_hour_seam():
    rows=[row("primary","2024-03-15T11:30Z","CPI m/m"),row("primary","2024-03-15T12:30Z","Unknown HIGH")]
    cat=repair.expectation_catalog([native("2024-03-15T12:30Z","CPI m/m")])
    details,_=diagnose.diagnose_native_anchors(rows,cat)
    assert details[0]["delta_minutes"]==-60 and details[0]["status"]=="FAIL"
    assert details[1]["expected_utc"]=="" and details[1]["status"]=="FAIL"


def export_fixtures(path):
    for ccy in repair.CCYS:
        code=repair.RATE_CODES.get(ccy,"nfp")
        name="Nonfarm Payrolls" if ccy=="USD" else "Rate fixture"
        rows=[{"broker_time":int(repair.stamp("2025-06-06T12:30Z").timestamp()),"event_id":"1","event_code":code,"event_name":name,"importance":"high"}]
        repair.write_csv(path/f"T_EXPORT_{ccy}_HIGH_2018_2025_NATIVE.csv",rows)


def test_fresh_loader_uses_release_identity_not_recurring_event_id(tmp_path):
    export_fixtures(tmp_path)
    path=tmp_path/"T_EXPORT_USD_HIGH_2026H1_NATIVE.csv"
    rows=[{"broker_time":int(repair.stamp(t).timestamp()),"event_id":"same_class","event_code":"nfp","event_name":"Nonfarm Payrolls","importance":"high","value_id":str(i)}
          for i,t in enumerate(["2026-01-09T13:30Z","2026-02-06T13:30Z"])]
    repair.write_csv(path,rows)
    _,_,fresh=repair.load_native(tmp_path,{})
    assert fresh["USD"]["present"] and fresh["USD"]["errors"]==[]
    # Fixture mutation only: duplicate value identities must be rejected by the gate.
    rows[1]["value_id"]=rows[0]["value_id"]
    with path.open("w",newline="") as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    assert "duplicate_release_identity" in repair.load_native(tmp_path,{})[2]["USD"]["errors"]


def test_fresh_and_catalog_exports_need_their_own_timestamp_proof(tmp_path):
    export_fixtures(tmp_path)
    path=tmp_path/"T_EXPORT_USD_ALL_CORE_PPI_2018_2025_NATIVE.csv"
    repair.write_csv(path,[{"broker_time":int(repair.stamp("2025-02-13T16:30Z").timestamp()),
        "event_id":"2","event_code":"core-ppi-mm","event_name":"Core PPI m/m","importance":"medium","value_id":"20"}])
    native,inputs,_=repair.load_native(tmp_path,{})
    assert not any(n["event"]=="Core PPI m/m" for n in native)
    assert next(r for r in inputs if r["path"]==str(path.resolve()))["role"]=="UNVERIFIED_TIMESTAMP_EXCLUDED_FROM_TRUTH"


def test_minute_fallback_aligns_only_unambiguous_common_event_and_preserves_impact():
    p=[row("primary","2024-02-01T10:01Z","Unverified","EUR")]
    s=[row("secondary","2024-02-01T10:00Z","Unverified","EUR",impact="low")]
    out,audit,gaps,*_=repair.transform(p,s,[],[])
    assert out["secondary"][0].instant==p[0].instant
    assert out["secondary"][0].impact=="low"
    assert any(a["reason"]=="COMMON_MINUTE_PRIMARY_FALLBACK_UNVERIFIED" for a in audit)
    assert gaps and gaps[0]["retained_unverified_row"]
    p.append(row("primary","2024-02-01T09:59Z","Unverified","EUR"))
    assert repair.transform(p,s,[],[])[0]["secondary"][0].instant==s[0].instant


def test_catalog_medium_instants_can_correct_existing_without_high_backfill():
    n={**native("2025-06-12T12:30Z","Core PPI m/m"),"importance":"medium"}
    out,_,_,_,backfill,_=repair.transform([],[],[n],[])
    assert out=={"primary":[],"secondary":[]} and backfill=={}


def test_separate_2025_export_is_crosscheck_only_even_when_shifted(tmp_path):
    export_fixtures(tmp_path)
    path=tmp_path/"T_EXPORT_USD_HIGH_2025_NATIVE.csv"
    repair.write_csv(path,[{"broker_time":int(repair.stamp("2025-06-06T15:30Z").timestamp()),
                           "event_id":"1","event_code":"nfp","event_name":"Nonfarm Payrolls","importance":"high"}])
    rows,inputs,_=repair.load_native(tmp_path,{})
    assert len([r for r in rows if r["currency"]=="USD"])==1
    proof=next(r for r in inputs if r["path"]==str(path.resolve()))
    assert proof["role"]=="CROSSCHECK_ONLY_EXCLUDED_FROM_TRUTH"
    assert proof["delta_seconds_from_full_export"]=={"10800":1}


def test_footprint_converts_broker_time_before_comparing(tmp_path):
    utc=repair.stamp("2025-06-06T12:30Z");raw_time=utc+timedelta(hours=3)
    rows=[]
    for day in range(-3,4):
        for minute in range(-15,196,5):
            t=utc+timedelta(days=day,minutes=minute)
            rows.append({"time":int((t+timedelta(hours=3)).timestamp()),"tickvol":400 if day==0 and minute==0 else 100})
    repair.write_csv(tmp_path/"EURUSD.DWX_M5.csv",rows)
    out=tmp_path/"out";out.mkdir()
    anchors=[{"currency":"USD","event_code":"nfp","utc":utc.isoformat(),"kind":"usd","source":"fixture"}]
    checks=repair.footprint_checks(anchors,[native(raw_time.isoformat(),"Nonfarm Payrolls")],tmp_path,out)
    assert checks[0]["status"]=="PASS" and checks[0]["corrected_peak"]==400
    assert checks[0]["raw_encoded_peak"]==100
    with (out/"anchor_000.csv").open() as f: evidence=list(csv.DictReader(f))
    assert any(r["utc"]==utc.isoformat() and r["tick_volume"]=="400" for r in evidence)


def test_candidate_run_is_deterministic_fail_closed_and_input_immutable(tmp_path,monkeypatch):
    source=tmp_path/"source";source.mkdir();native_dir=tmp_path/"native";native_dir.mkdir()
    root=tmp_path/"repo";(root/"decisions").mkdir(parents=True)
    (root/"decisions/2026-09-02_owner_receipts_ceo_asks.md").write_text("| 9 | E1: fixture | YES |\n")
    export_fixtures(native_dir)
    p=row("primary","2025-06-05T19:30Z","Non-Farm Employment Change")
    s=row("secondary","2025-06-05T19:30Z","Non-Farm Employment Change")
    pp=source/repair.gate.PRIMARY_NAME;sp=source/repair.gate.SECONDARY_NAME
    repair.write_csv(pp,[p.raw],repair.PRIMARY_FIELDS);repair.write_csv(sp,[s.raw],repair.SECONDARY_FIELDS)
    monkeypatch.setattr(repair,"lab_policy",lambda _: {"anchors":[],"offsets":{c:[0,-3] for c in repair.RATE_CODES},"inputs":[]})
    before={f:repair.sha(f) for f in [pp,sp,*native_dir.glob("*.csv")]}
    results=[]
    for name in ["first","second"]:
        out=tmp_path/"staging"/name
        r=repair.run_repair(pp,sp,native_dir,native_dir,out,canonical_root=root,staging_root=tmp_path/"staging",coverage_end="2026-06")
        assert r["exit_code"]==2 and not r["publishable"]
        # E1-B2 (93198a4d2d) generalised the fail-closed message: the run is not publishable while any verification input is unresolved
    assert "NOT_PUBLISHABLE" in r["message"]
        assert r["gates"]["6.6_no_row_loss"]["pass"]
        assert r["gates"]["6.8_schema"]["pass"]
        assert r["gates"]["6.3_cross_file_identity"]["pass"]
        results.append(out)
    assert repair.sha(results[0]/repair.gate.PRIMARY_NAME)==repair.sha(results[1]/repair.gate.PRIMARY_NAME)
    assert repair.sha(results[0]/repair.gate.SECONDARY_NAME)==repair.sha(results[1]/repair.gate.SECONDARY_NAME)
    assert before=={f:repair.sha(f) for f in before}
    assert len(json.loads((results[0]/"repair_gaps.json").read_text())["gaps"])>0


def test_output_path_and_overwrite_guards(tmp_path):
    with pytest.raises(ValueError,match="NEW child"):
        repair.output_guard(tmp_path/"production",tmp_path/"staging")
    existing=tmp_path/"staging"/"prior";existing.mkdir(parents=True)
    with pytest.raises(ValueError,match="overwrite refused"):
        repair.output_guard(existing,tmp_path/"staging")
