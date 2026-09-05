"""E1-A offline candidate builder. Always staging-only; exit 2 on any failed gate.

Incomplete candidates preserve unresolved source rows for audit continuity. They
are explicitly NOT publishable. No stored-date wall-clock reconstruction, rate
offset guesses, impact relabeling, terminal operation or production writer exists.
"""
from __future__ import annotations

import argparse
import ast
import calendar
from collections import Counter, defaultdict
import csv
from dataclasses import replace
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import statistics

try:
    import news_calendar_diagnose as diagnose
    import news_calendar_gate as gate
    from research.quantify_news_calendar_defect import NAME_MAP_USD, ET_0830_CLASS, broker_epoch_to_utc
except ModuleNotFoundError:
    from tools.strategy_farm import news_calendar_diagnose as diagnose, news_calendar_gate as gate
    from tools.strategy_farm.research.quantify_news_calendar_defect import NAME_MAP_USD, ET_0830_CLASS, broker_epoch_to_utc

UTC = timezone.utc
SCHEMA = "qm.news-calendar-repair-e1a/v1"
DECISION = "OWNER-DEC-CALENDAR-E1A-20260905"
STAGING = Path("D:/QM/reports/news_calendar/repair_e1a")
CANONICAL = Path("C:/QM/repo")
NATIVE_DIR = Path("D:/QM/mt5/T_Export/MQL5/Files")
PRIMARY_FIELDS = "datetime,currency,event_name,impact,actual,forecast,previous,impact_numeric,is_high_impact,is_nfp,is_fomc,is_ecb,is_boe,is_gdp,is_cpi,is_pmi,day_of_week,hour,day,is_first_friday".split(",")
SECONDARY_FIELDS = "Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,Actual,Forecast,Previous".split(",")
CCYS = ("USD", "EUR", "GBP", "JPY", "AUD", "CAD")
EXTENDED_USD = {**NAME_MAP_USD,
    "FOMC Statement": "Fed Interest Rate Decision",
    "FOMC Economic Projections": "Fed Interest Rate Decision",
    "Core PPI m/m": "Core PPI m/m",
    "Empire State Manufacturing Index": "NY Fed Empire State Manufacturing Index",
    "Building Permits": "Building Permits",
    "Trade Balance": "Trade Balance"}
RATE_CODES = {"EUR":"ecb-interest-rate-decision", "GBP":"boe-interest-rate-decision",
              "JPY":"boj-interest-rate-decision", "AUD":"rba-interest-rate-decision",
              "CAD":"boc-interest-rate-decision"}
M5_SYMBOLS = {"USD":"EURUSD", "EUR":"EURUSD", "GBP":"GBPUSD", "JPY":"USDJPY", "AUD":"AUDUSD", "CAD":"USDCAD"}
NONUSD_MAP = {ccy:dict(mapping) for ccy,mapping in diagnose.NATIVE_NAME_MAP.items() if ccy != "USD"}
NONUSD_MAP.update(AUD={"Cash Rate":"RBA Interest Rate Decision", "RBA Rate Statement":"RBA Interest Rate Decision"},
                  CAD={"Overnight Rate":"BoC Interest Rate Decision", "BOC Rate Statement":"BoC Interest Rate Decision"})
ZERO_TOLERANCE = {"non-farm employment change", "nonfarm payrolls", "retail sales m/m", "unemployment rate", "cpi m/m"}
HOLE_START = datetime(2025,5,1,tzinfo=UTC)
HOLE_END = datetime(2026,7,1,tzinfo=UTC)


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""): h.update(chunk)
    return h.hexdigest()


def stamp(value: str) -> datetime:
    result = datetime.fromisoformat(value.replace("Z","+00:00"))
    if result.tzinfo is None: raise ValueError("official anchor must carry UTC offset")
    return result.astimezone(UTC)


def write_json(path: Path, value) -> None:
    with path.open("x",encoding="utf-8",newline="\n") as f:
        json.dump(value,f,indent=2,sort_keys=True,ensure_ascii=False); f.write("\n")


def write_csv(path: Path, rows: list[dict], fields=None) -> None:
    with path.open("x",encoding="utf-8",newline="") as f:
        writer=csv.DictWriter(f,fieldnames=fields or list(rows[0]),lineterminator="\n")
        writer.writeheader();writer.writerows(rows)


def output_guard(out: Path, staging_root=STAGING) -> Path:
    root=Path(staging_root).resolve();out=out.resolve()
    if out == root or root not in out.parents:
        raise ValueError(f"outputs must be in a NEW child of {root}")
    if out.exists(): raise ValueError("existing output directory: overwrite refused")
    return out


def literal_assignment(path: Path, name: str):
    for node in ast.parse(path.read_text(encoding="utf-8-sig")).body:
        if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id==name for t in node.targets):
            return ast.literal_eval(node.value)
    raise ValueError(f"missing literal {name} in {path}")


def lab_policy(root: Path) -> dict:
    """Read data literals, never execute private builders or their pandas imports."""
    nonusd=root/".private/secret_strategy_lab/native_calendar_multicurrency/build_validated_supplement.py"
    usd=root/".private/secret_strategy_lab/xau_breadth_tuesday_rebound_ftmo/build_native_usd_calendar.py"
    fan={}
    for node in ast.parse(nonusd.read_text(encoding="utf-8-sig")).body:
        if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="OFFSETS" for t in node.targets):
            for key,value in zip(node.value.keys,node.value.values):
                offsets=[]
                for call in value.elts:
                    if not isinstance(call,ast.Call) or not isinstance(call.func,ast.Attribute) or call.func.attr != "Timedelta":
                        raise ValueError("unrecognized lab offset expression")
                    if call.args:
                        if len(call.args)!=1 or ast.literal_eval(call.args[0])!=0: raise ValueError("invalid zero offset")
                        offsets.append(0)
                    else:
                        if len(call.keywords)!=1 or call.keywords[0].arg!="hours": raise ValueError("invalid hour offset")
                        offsets.append(ast.literal_eval(call.keywords[0].value))
                fan[ast.literal_eval(key)]=offsets
    if set(fan)!=set(RATE_CODES): raise ValueError("lab offset currencies changed")
    anchors=[{"currency":c,"event_code":code,"utc":utc,"source":str(nonusd),"kind":"rate" if code==RATE_CODES[c] else "nonrate"}
             for c,code,utc in sorted(literal_assignment(nonusd,"ANCHORS"))]
    anchors += [{"currency":"USD","event_code":code,"utc":utc,"source":str(usd),"kind":"usd"}
                for code,utc in sorted(literal_assignment(usd,"ANCHORS"))]
    return {"offsets":fan,"anchors":anchors,"official_usd_revised":literal_assignment(usd,"OFFICIAL_2025_REVISED"),
            "inputs":[{"path":str(p),"sha256":sha(p)} for p in (nonusd,usd)]}


def load_native(native_dir: Path, policy: dict) -> tuple[list[dict],list[dict],dict]:
    result=[];inputs=[];fresh={};seen=set()
    for ccy in CCYS:
        paths=[native_dir/f"T_EXPORT_{ccy}_HIGH_2018_2025_NATIVE.csv"]
        if ccy=="USD": paths.append(native_dir/"T_EXPORT_USD_HIGH_2025_NATIVE.csv")
        sidecars=sorted(set(native_dir.glob(f"T_EXPORT_{ccy}_HIGH_*2026H1*_NATIVE.csv")))
        paths += [p for p in sidecars if p not in paths]
        catalog_paths=sorted(native_dir.glob("T_EXPORT_USD_ALL_*_2018_2025_NATIVE.csv")) if ccy=="USD" else []
        paths += catalog_paths
        fresh_rows=[];fresh_errors=[]
        for path in paths:
            if not path.exists():
                if path.name.endswith("HIGH_2025_NATIVE.csv"): continue
                raise ValueError(f"native input missing: {path}")
            input_hash=sha(path)
            with path.open(encoding="utf-8-sig",newline="") as f:
                reader=csv.DictReader(f)
                if not {"broker_time","event_id","event_code","event_name","importance"} <= set(reader.fieldnames or []):
                    raise ValueError(f"native schema invalid: {path}")
                rows=list(reader)
            if sha(path)!=input_hash:raise ValueError(f"native changed while reading: {path}")
            input_record={"path":str(path.resolve()),"sha256":input_hash,"rows":len(rows),"role":"AUTHORITATIVE_NATIVE"}
            inputs.append(input_record)
            # New query exports carry raw server-civil epochs. The old full-range
            # sidecar is independently anchored UTC; its encoding cannot be
            # inherited by a fresh query (the observed 2025 sidecar differs +3h).
            # Preserve and hash every export, but require file-specific official
            # anchors before allowing its instants into the candidate truth set.
            offset=None
            if path in sidecars or path in catalog_paths:
                offsets=[];anchor_keys=set()
                for anchor in policy.get("anchors",[]):
                    if anchor["currency"]!=ccy:continue
                    anchor_key=(anchor["event_code"],anchor["utc"])
                    if anchor_key in anchor_keys:continue
                    anchor_keys.add(anchor_key)
                    expected=stamp(anchor["utc"])
                    matches=[datetime.fromtimestamp(int(r["broker_time"]),UTC) for r in rows
                             if r["event_code"]==anchor["event_code"]
                             and abs(datetime.fromtimestamp(int(r["broker_time"]),UTC)-expected)<timedelta(days=2)]
                    if len(matches)==1:offsets.append(int((expected-matches[0]).total_seconds()))
                if len(offsets)>=3 and len(set(offsets))==1 and offsets[0]%3600==0 and abs(offsets[0])<=12*3600:
                    offset=offsets[0]
                    input_record.update(utc_offset_seconds=offset,official_anchor_count=len(offsets))
                else:
                    input_record.update(role="UNVERIFIED_TIMESTAMP_EXCLUDED_FROM_TRUTH",
                                        official_anchor_count=len(offsets),observed_offsets_seconds=offsets)
            if ccy=="USD" and path.name=="T_EXPORT_USD_HIGH_2025_NATIVE.csv":
                # The separate range export is a CROSS-CHECK, never a second
                # truth stream. Its actual 480 rows are all +3h vs the full
                # export. Importing that union would recreate bad blackouts.
                deltas=Counter();unmatched=0
                for r in rows:
                    t=datetime.fromtimestamp(int(r["broker_time"]),UTC)
                    candidates=[n for n in result if n["currency"]==ccy and n["code"]==r["event_code"]]
                    match=nearest(t,candidates)
                    if match:deltas[str(int((t-match["instant"]).total_seconds()))]+=1
                    else:unmatched+=1
                input_record.update(role="CROSSCHECK_ONLY_EXCLUDED_FROM_TRUTH",
                                    delta_seconds_from_full_export=dict(sorted(deltas.items())),unmatched_rows=unmatched)
                continue
            prior=None;local_seen=set()
            for r in rows:
                instant=datetime.fromtimestamp(int(r["broker_time"]),UTC)
                key=(ccy,r["event_id"],int(r["broker_time"]))
                if path in sidecars:
                    # event_id identifies a recurring class; value_id identifies a release.
                    release_key=r.get("value_id") or (r["event_id"],r["broker_time"])
                    if release_key in local_seen:fresh_errors.append("duplicate_release_identity")
                    if prior and instant<prior:fresh_errors.append("nonmonotonic_broker_time")
                    if not datetime(2026,1,1,tzinfo=UTC)<=instant<HOLE_END:fresh_errors.append("sidecar_outside_2026_H1")
                    local_seen.add(release_key);prior=instant;fresh_rows.append(r)
                if key in seen:continue
                seen.add(key)
                if path not in catalog_paths and r["importance"].lower()!="high":raise ValueError(f"non-high row in high export: {path}")
                if path in catalog_paths and r["event_name"] not in {"Core PPI m/m","NY Fed Empire State Manufacturing Index","Building Permits","Trade Balance"}:
                    raise ValueError(f"unrequested catalog class: {path}")
                if input_record["role"]=="UNVERIFIED_TIMESTAMP_EXCLUDED_FROM_TRUTH":continue
                if offset is not None:instant+=timedelta(seconds=offset)
                result.append({"currency":ccy,"event":r["event_name"],"code":r["event_code"],"instant":instant,
                               "event_id":r["event_id"],"source":str(path.resolve()),"kind":"native",
                               "importance":r["importance"].lower()})
        fresh[ccy]={"present":bool(sidecars),"rows":len(fresh_rows),"errors":sorted(set(fresh_errors)),
                    "monthly_rows":dict(sorted(Counter(datetime.fromtimestamp(int(r["broker_time"]),UTC).strftime("%Y-%m") for r in fresh_rows).items()))}
    for index,(code,name,utc) in enumerate(policy.get("official_usd_revised",[])):
        instant=stamp(utc)
        if any(n["currency"]=="USD" and n["code"]==code and n["instant"]==instant for n in result):continue
        result.append({"currency":"USD","event":name,"code":code,"instant":instant,"event_id":f"official-{index}",
                       "source":"lab pinned official BLS revised-release literals","kind":"official"})
    return sorted(result,key=lambda n:(n["instant"],n["currency"],n["event_id"])),inputs,fresh


def assert_native_names(native: list[dict]) -> None:
    names={n["event"] for n in native if n["currency"]=="USD"}
    missing=sorted(set(EXTENDED_USD.values())-names)
    if missing:raise ValueError("NATIVE_TARGET_NAMES_MISSING: "+", ".join(missing))


def nearest(instant: datetime, rows: list[dict], *, hours=36, key="instant"):
    values=[r for r in rows if abs((r[key]-instant).total_seconds())<=hours*3600]
    if not values:return None
    values.sort(key=lambda r:(abs((r[key]-instant).total_seconds()),r[key]))
    if len(values)>1 and abs(values[0][key]-instant)==abs(values[1][key]-instant) and values[0][key]!=values[1][key]:return None
    return values[0]


def footprint_checks(anchors: list[dict], native: list[dict], m5_dir: Path, out: Path) -> list[dict]:
    """Stream only anchor/control windows. Volume confirms; it never selects an offset."""
    checks=[];requests=defaultdict(list)
    for i,anchor in enumerate(anchors):
        a={**anchor,"id":f"anchor_{i:03d}","status":"MISSING_M5"}
        if not a.get("utc"):
            a["status"]="MISSING_OFFICIAL_INSTANT";checks.append(a);continue
        t=stamp(a["utc"]);a["instant"]=t
        raw=nearest(t,[n for n in native if n["currency"]==a["currency"] and n["code"]==a["event_code"]])
        a["raw_native_utc"]=raw["instant"].isoformat() if raw else None
        path=m5_dir/(M5_SYMBOLS[a["currency"]]+".DWX_M5.csv");a["m5_path"]=str(path)
        checks.append(a)
        if path.exists():requests[path].append(a)
    for path,group in requests.items():
        path_hash=sha(path)
        # Collect only +/- 3 days of each official date, after broker->UTC conversion.
        days=set()
        for a in group:
            days.update((a["instant"]+timedelta(days=d)).date() for d in range(-3,4))
        selected=[]
        with path.open(encoding="utf-8-sig",newline="") as f:
            for row in csv.DictReader(f):
                raw=int(row["time"])
                # Cheap coarse date reject does not decide the event instant.
                if datetime.fromtimestamp(raw,UTC).date() not in days:continue
                t=broker_epoch_to_utc(raw)
                if t.date() in days:selected.append((t,int(row["tickvol"]),raw))
        for a in group:
            t=a["instant"]; band=[v for u,v,r in selected if abs(u-t)<=timedelta(minutes=15)]
            controls=[v for u,v,r in selected if u.date()!=t.date() and abs((u.hour*60+u.minute)-(t.hour*60+t.minute))<=15]
            pre=stamp(a["raw_native_utc"]) if a["raw_native_utc"] else None
            pre_band=[v for u,v,r in selected if pre and abs(u-pre)<=timedelta(minutes=15)] if pre!=t else []
            median=statistics.median(controls) if controls else None
            peak=max(band) if band else None;pre_peak=max(pre_band) if pre_band else None
            elevated=bool(median and peak and peak>=1.5*median)
            quiet=(pre_peak<peak) if pre_peak is not None and peak is not None else None
            a.update(m5_sha256=path_hash,control_median=median,corrected_peak=peak,raw_encoded_peak=pre_peak,
                     peak_to_control=round(peak/median,4) if median and peak else None,
                     raw_encoded_quieter=quiet,
                     status="PASS" if elevated and quiet is not False else "FAIL_FOOTPRINT")
            # Actual raw native time is a comparison, not an invented pre-repair CSV row.
            rows=[{"broker_epoch":r,"utc":u.isoformat(),"tick_volume":v,
                   "official_band":abs(u-t)<=timedelta(minutes=15),
                   "raw_native_band":bool(pre and abs(u-pre)<=timedelta(minutes=15))}
                  for u,v,r in selected if abs(u-t)<=timedelta(hours=5)]
            write_csv(out/(a["id"]+".csv"),rows,["broker_epoch","utc","tick_volume","official_band","raw_native_band"])
    for a in checks:a.pop("instant",None)
    return checks


def select_nonusd(native: list[dict], policy: dict, footprints: list[dict]) -> tuple[list[dict],list[dict]]:
    selected=[];decisions=[]
    for ccy,code in RATE_CODES.items():
        anchor_rows=[a for a in footprints if a["currency"]==ccy]
        passed=list({(a["event_code"],a.get("utc")):a for a in anchor_rows if a["status"]=="PASS"}.values())
        currency_ok=len(passed)>=3 and any(a["kind"]=="nonrate" for a in passed)
        offsets=set();official_by_day={}
        for a in passed:
            if a["event_code"]!=code:continue
            t=stamp(a["utc"]);raw=nearest(t,[n for n in native if n["currency"]==ccy and n["code"]==code])
            if not raw:continue
            matches=[h for h in policy["offsets"][ccy] if abs(raw["instant"]+timedelta(hours=h)-t)<=timedelta(minutes=15)]
            if len(matches)==1: offsets.add(matches[0]);official_by_day[t.date()]=t
            elif ccy=="CAD" and t==datetime(2025,1,29,14,45,tzinfo=UTC):official_by_day[t.date()]=t
        # A varying fan (AUD) has no proved seasonal selector: only individually anchored dates can be used.
        for n in native:
            if n["currency"]!=ccy or n["code"]!=code:continue
            corrected=None;reason="UNCONFIRMED_CURRENCY_FOOTPRINT"
            if currency_ok and n["instant"].date() in official_by_day:
                corrected=official_by_day[n["instant"].date()];reason="INDIVIDUAL_OFFICIAL_ANCHOR"
            elif currency_ok and len(offsets)==1:
                corrected=n["instant"]+timedelta(hours=next(iter(offsets)));reason="CLASS_ANCHOR_SELECTED_OFFSET"
            elif currency_ok:reason="AMBIGUOUS_OFFSET_FAN"
            if corrected:selected.append({**n,"instant":corrected,"raw_instant":n["instant"],"correction":reason})
        decisions.append({"currency":ccy,"passed_footprints":len(passed),"nonrate_footprint_pass":any(a["kind"]=="nonrate" for a in passed),
                          "confirmed":currency_ok,"selected_offsets_hours":sorted(offsets),
                          "selected_rows":sum(n["currency"]==ccy for n in selected)})
    return selected,decisions


def utc_to_eet(t: datetime) -> datetime:
    last_sunday=lambda month:max(w[calendar.SUNDAY] for w in calendar.monthcalendar(t.year,month))
    start=datetime(t.year,3,last_sunday(3),1,tzinfo=UTC);end=datetime(t.year,10,last_sunday(10),1,tzinfo=UTC)
    return t+timedelta(hours=3 if start<=t<end else 2)


def project(row: diagnose.CalendarRow, t: datetime) -> dict:
    r=dict(row.raw);name=row.event.lower()
    if row.source=="primary":
        r.update(datetime=t.strftime("%Y-%m-%d %H:%M:%S"),day_of_week=str(t.weekday()),hour=str(t.hour),day=str(t.day),
                 is_first_friday=str(int(t.weekday()==4 and t.day<=7)),
                 impact_numeric=str({"high":3,"medium":2}.get(row.impact,1)),is_high_impact=str(int(row.impact=="high")))
        needles={"is_nfp":("non-farm","nonfarm"),"is_fomc":("fomc","federal funds"),"is_ecb":("ecb","main refinancing"),
                 "is_boe":("boe","mpc","official bank rate"),"is_gdp":("gdp",),"is_cpi":("cpi",),"is_pmi":("pmi",)}
        r.update({key:str(int(any(v in name for v in values))) for key,values in needles.items()})
    else:
        r.update(Date=t.strftime("%Y.%m.%d"),DateTime_UTC=t.strftime("%Y.%m.%d %H:%M:%S"),
                 DateTime_EET=utc_to_eet(t).strftime("%Y.%m.%d %H:%M:%S"))
    return r


def transform(primary,secondary,native,selected_nonusd):
    truth=[n for n in native if n["currency"]=="USD"]+selected_nonusd
    by_name=defaultdict(list)
    for n in truth:by_name[(n["currency"],n["event"].casefold())].append(n)
    # One time decision for the same event/instant, independent of per-file impact labels.
    cache={};out={"primary":[],"secondary":[]};audit=[];gaps=[];transforms=Counter()
    for row in [*primary,*secondary]:
        key=(row.currency,row.event,row.instant)
        mapping=EXTENDED_USD if row.currency=="USD" else NONUSD_MAP.get(row.currency,{})
        target=mapping.get(row.event,row.event)
        if key not in cache:
            match=nearest(row.instant,by_name.get((row.currency,target.casefold()),[]))
            cache[key]=(match["instant"],match) if match else (row.instant,None)
        t,match=cache[key]
        reason=("A_NATIVE_REPLACED" if t!=row.instant else "A_NATIVE_IDEMPOTENT") if match else (
                "DECLARED_HIGH_GAP" if row.impact=="high" else "D_INERT_UNVERIFIED" if row.currency=="USD" and row.event in ET_0830_CLASS else "E_PRESERVED_UNVERIFIED")
        if match and row.currency!="USD":reason="NONUSD_ANCHORED_RATE"
        if not match and row.impact=="high":
            gaps.append({"source":row.source,"currency":row.currency,"event":row.event,"month":row.instant.strftime("%Y-%m"),
                         "reason":"NO_NATIVE_OR_OFFICIAL_DATE" if row.currency=="USD" else "NONUSD_UNANCHORED_CLASS",
                         "retained_unverified_row":True,"stored_utc":row.instant.isoformat()})
        projected=project(row,t)
        out[row.source].append(replace(row,instant=t,raw=projected))
        audit.append({"source":row.source,"currency":row.currency,"event":row.event,"stored_utc":row.instant.isoformat(),
                      "corrected_utc":t.isoformat(),"reason":reason,"native_source":match["source"] if match else "",
                      "delta_minutes":int((t-row.instant).total_seconds()/60),"impact":row.impact})
        transforms[(row.source,row.currency,row.event,reason)]+=1
    backfill=Counter()
    present={s:{(r.currency,r.event,r.instant) for r in rows} for s,rows in out.items()}
    for n in truth:
        if not HOLE_START<=n["instant"]<HOLE_END:continue
        if n.get("importance","high")!="high":continue
        for source,fields in (("primary",PRIMARY_FIELDS),("secondary",SECONDARY_FIELDS)):
            if (n["currency"],n["event"],n["instant"]) in present[source]:continue
            raw=dict.fromkeys(fields,"")
            if source=="primary":raw.update(currency=n["currency"],event_name=n["event"],impact="high")
            else:raw.update(Currency=n["currency"],Event=n["event"],Impact="High")
            row=diagnose.CalendarRow(source,n["instant"],n["currency"],"high",n["event"],raw)
            out[source].append(replace(row,raw=project(row,row.instant)));backfill[source]+=1
            present[source].add((n["currency"],n["event"],n["instant"]))
            transforms[(source,n["currency"],n["event"],"HOLE_BACKFILL_NATIVE_OR_OFFICIAL")]+=1
            audit.append({"source":source,"currency":n["currency"],"event":n["event"],"stored_utc":"",
                          "corrected_utc":n["instant"].isoformat(),"reason":"HOLE_BACKFILL_NATIVE_OR_OFFICIAL",
                          "native_source":n["source"],"delta_minutes":0,"impact":"high"})
    # Explicit E1-B2 reconciliation: native matches were applied above. For
    # remaining one-minute common events, retain PRIMARY's instant and align
    # SECONDARY only when the matching PRIMARY row is unambiguous. This makes
    # the pair consistent; it does not convert an unverified time into evidence.
    primary_index=defaultdict(list)
    for r in out["primary"]:primary_index[(r.currency,r.event)].append(r)
    reconciled=[]
    for r in out["secondary"]:
        matches=[p for p in primary_index[(r.currency,r.event)] if abs(p.instant-r.instant)<=timedelta(minutes=1)]
        if len(matches)==1 and matches[0].instant!=r.instant:
            t=matches[0].instant
            audit.append({"source":"secondary","currency":r.currency,"event":r.event,
                          "stored_utc":r.instant.isoformat(),"corrected_utc":t.isoformat(),
                          "reason":"COMMON_MINUTE_PRIMARY_FALLBACK_UNVERIFIED","native_source":"",
                          "delta_minutes":int((t-r.instant).total_seconds()/60),"impact":r.impact})
            transforms[("secondary",r.currency,r.event,"COMMON_MINUTE_PRIMARY_FALLBACK_UNVERIFIED")]+=1
            r=replace(r,instant=t,raw=project(r,t))
        reconciled.append(r)
    out["secondary"]=reconciled
    for source in out:out[source].sort(key=lambda r:(r.instant,r.currency,r.event,json.dumps(r.raw,sort_keys=True)))
    return out,audit,gaps,[{"source":s,"currency":c,"event":e,"transform":r,"rows":n} for (s,c,e,r),n in sorted(transforms.items())],dict(backfill),truth


def expectation_catalog(truth: list[dict]) -> dict:
    events=set()
    for n in truth:
        names={n["event"]}
        mapping=EXTENDED_USD if n["currency"]=="USD" else NONUSD_MAP.get(n["currency"],{})
        names.update(k for k,v in mapping.items() if v.casefold()==n["event"].casefold())
        for name in names:events.add((n["currency"],name,n["instant"].isoformat()))
    return {"schema":SCHEMA,"expectation_basis":"NATIVE_OR_PINNED_OFFICIAL_INSTANTS_ONLY",
            "events":[{"currency":c,"event":e,"utc":t} for c,e,t in sorted(events)]}


def plan_spots() -> list[dict]:
    # Explicitly incomplete official-instant requests stay visible; do not guess
    # announcement minutes from the variable-time BoJ raw feed or a stored date.
    entries=[("EUR","ecb-interest-rate-decision","2024-09-12",None,"rate"),
             ("EUR","consumer-price-index-yy","2025-02",None,"nonrate"),
             ("GBP","boe-interest-rate-decision","2024-08-01",None,"rate"),
             ("GBP","consumer-price-index-yy","2025-01-15","2025-01-15T07:00:00+00:00","nonrate"),
             ("JPY","boj-interest-rate-decision","2024-07-31",None,"rate"),
             ("JPY","boj-interest-rate-decision","2025-01-24",None,"rate"),
             ("JPY","tokyo-cpi-excl-food-energy-yy","2025-01",None,"nonrate"),
             ("AUD","rba-interest-rate-decision","2024-11-05",None,"rate"),
             ("AUD","consumer-price-index-qq","2025-01-29",None,"nonrate"),
             ("CAD","consumer-price-index-yy","2025-01-21",None,"nonrate")]
    return [{"currency":c,"event_code":code,"requested_date":day,"utc":utc,"kind":kind,
             "source":"NEWS_CALENDAR_REPAIR_PLAN_2026-09-05 section 3.4; exact instant required where null"}
            for c,code,day,utc,kind in entries]


def run_repair(primary_path: Path,secondary_path: Path,native_dir: Path,m5_dir: Path,out: Path,*,
               canonical_root=CANONICAL,extra_anchors=None,staging_root=STAGING,coverage_end=None) -> dict:
    out=output_guard(out,staging_root);out.mkdir(parents=True)
    footprints_dir=out/"footprints";footprints_dir.mkdir()
    input_records=[{"path":str(p.resolve()),"sha256":sha(p)} for p in (primary_path,secondary_path)]
    primary,errors_p=diagnose._parse_primary(primary_path);secondary,errors_s=diagnose._parse_secondary(secondary_path)
    if errors_p or errors_s:raise ValueError("source parse errors: no row loss allowed")
    for path,fields in ((primary_path,PRIMARY_FIELDS),(secondary_path,SECONDARY_FIELDS)):
        with path.open(encoding="utf-8-sig",newline="") as f:
            if next(csv.reader(f))!=fields:raise ValueError(f"exact source schema required: {path}")
    _,cross_before=diagnose.compare_cross_file(primary,secondary)
    if any(sha(Path(p["path"]))!=p["sha256"] for p in input_records):raise ValueError("source changed while capturing baseline")
    baseline={"schema":SCHEMA,"primary_rows":len(primary),"secondary_rows":len(secondary),
              "primary_rows_with_identical_ff_instant":cross_before["identical_instant"],"cross_file":cross_before,"inputs":input_records}
    write_json(out/"baseline.json",baseline)
    authority=Path(canonical_root)/"decisions/2026-09-02_owner_receipts_ceo_asks.md"
    if not any("| 9 | E1:" in line and "YES" in line for line in authority.read_text(encoding="utf-8-sig").splitlines()):
        raise ValueError("E1-A OWNER receipt row 9 missing")
    input_records.append({"path":str(authority.resolve()),"sha256":sha(authority)})
    policy=lab_policy(Path(canonical_root))
    if extra_anchors:
        extra=json.loads(Path(extra_anchors).read_text(encoding="utf-8-sig"))
        if extra.get("decision_id")!=DECISION or not extra.get("approved_by") or not extra.get("approved_at"):
            raise ValueError("extra official anchors require E1-A OWNER receipt fields")
        stamp(extra["approved_at"])
        for a in extra["anchors"]:
            stamp(a["utc"])
            if not a.get("source") or a["currency"] not in CCYS:raise ValueError("invalid extra official anchor")
        policy["anchors"]+=extra["anchors"]
        input_records.append({"path":str(Path(extra_anchors).resolve()),"sha256":sha(Path(extra_anchors))})
    input_records+=policy["inputs"]
    native,native_inputs,fresh=load_native(native_dir,policy);input_records+=native_inputs
    name_error=None
    try:assert_native_names(native)
    except ValueError as exc:name_error=str(exc)
    spots=[a for a in policy["anchors"] if not a["utc"].startswith("2026-")]+plan_spots()
    # Extra official anchors can satisfy otherwise unresolved dated requests.
    for spot in spots:
        if spot.get("utc") is None:
            candidates=[a for a in policy["anchors"] if a["currency"]==spot["currency"] and a["event_code"]==spot["event_code"] and a["utc"].startswith(spot["requested_date"])]
            if len(candidates)==1:spot.update(utc=candidates[0]["utc"],source=candidates[0]["source"])
    footprints=footprint_checks(spots,native,m5_dir,footprints_dir)
    input_records += [{"path":p,"sha256":h} for p,h in sorted({(a["m5_path"],a["m5_sha256"]) for a in footprints if a.get("m5_sha256")})]
    selected,offsets=select_nonusd(native,policy,footprints)
    corrected,audit,gaps,transforms,backfill,truth=transform(primary,secondary,native,selected)
    for source,name,fields in (("primary",gate.PRIMARY_NAME,PRIMARY_FIELDS),("secondary",gate.SECONDARY_NAME,SECONDARY_FIELDS)):
        write_csv(out/name,[r.raw for r in corrected[source]],fields)
    write_csv(out/"row_transform.csv",audit)
    write_json(out/"per_class_transforms.json",transforms)
    write_json(out/"footprint_summary.json",footprints)
    write_json(out/"nonusd_offset_decisions.json",offsets)
    catalog=expectation_catalog(truth);write_json(out/"native_anchor_expectations.json",catalog)
    # Report-only diagnostic, with a new explicit native-truth mode. Legacy rule
    # mode remains available and is never used to synthesize corrected dates.
    diag=diagnose.run_diagnostics(out/gate.PRIMARY_NAME,out/gate.SECONDARY_NAME,native_dir,out/"diagnose",
        coverage_start="2015-01",coverage_end=coverage_end,native_anchor_catalog=catalog)
    groups=diag["anchors"]["per_class_year"]
    anchor_fail=[r for r in groups if r["share_within_5_minutes"] < (1.0 if r["class"].casefold() in ZERO_TOLERANCE else .99)]
    months=diag["coverage"]["zero_months"]
    for ccy in CCYS:
        for month in diagnose._month_range("2025-05","2026-06"):
            gaps.append({"source":"both","currency":ccy,"event":"ALL_MEDIUM_LOW","month":month,
                         "reason":"HIGH_ONLY_NATIVE_SOURCE","retained_unverified_row":False})
        if not fresh[ccy]["present"]:
            for month in diagnose._month_range("2026-01","2026-06"):
                gaps.append({"source":"both","currency":ccy,"event":"ALL_HIGH","month":month,
                             "reason":"AWAITING_2026_H1_EXPORT","retained_unverified_row":False})
    completeness=[];inventory=[]
    for ccy in RATE_CODES:
        for year in sorted({n["instant"].year for n in native if n["currency"]==ccy}):
            annual=[n for n in native if n["currency"]==ccy and n["instant"].year==year]
            rate=[n for n in annual if n["code"]==RATE_CODES[ccy]]
            accepted=[n for n in selected if n["currency"]==ccy and n["instant"].year==year]
            completeness.append({"currency":ccy,"year":year,"native_high_rows":len(annual),"rate_rows":len(rate),
                                 "rate_fraction":len(rate)/len(annual),"confirmed_rows":len(accepted),"unconfirmed_rows":len(annual)-len(accepted)})
            for n in annual:
                if not any(a["event_id"]==n["event_id"] and a.get("raw_instant")==n["instant"] for a in accepted):
                    inventory.append({"currency":ccy,"event":n["event"],"month":n["instant"].strftime("%Y-%m"),
                        "reason":"UNCONFIRMED_RATE" if n["code"]==RATE_CODES[ccy] else "NONRATE_SCOPE_GAP",
                        "affected_symbol_examples":{"EUR":"GDAXI;EURUSD","GBP":"UK100;GBPUSD;GBPJPY","JPY":"USDJPY;GBPJPY","AUD":"AUDUSD;AUDCAD","CAD":"USDCAD;AUDCAD"}[ccy],
                        "pre30_post30_potential_underblock_minutes_upper_bound":60,"followup":"E2_AND_E4"})
    gaps.extend({**r,"source":"native","retained_unverified_row":False} for r in inventory)
    write_json(out/"repair_gaps.json",{"schema":SCHEMA,"decision_id":DECISION,"gaps":gaps})
    write_csv(out/"nonusd_completeness.csv",completeness)
    write_csv(out/"e2_e4_gap_inventory.csv",inventory,["currency","event","month","reason","affected_symbol_examples","pre30_post30_potential_underblock_minutes_upper_bound","followup"])
    _,cross_after=diagnose.compare_cross_file(corrected["primary"],corrected["secondary"])
    parsed=[];schema_errors=[]
    for name in gate.CALENDAR_NAMES:
        try:
            p=gate._parse_calendar_file(out/name,name)
            parsed.append({"name":name,"sha256":p.sha256,"row_count":p.row_count,"first_event_utc":p.first_event_utc,"last_event_utc":p.last_event_utc})
        except gate.CalendarParseError as exc:schema_errors.append(str(exc))
    declared_months={g["month"] for g in gaps if g["reason"]=="AWAITING_2026_H1_EXPORT"}
    unexplained={s:[m for m in missing if m not in declared_months] for s,missing in months.items()}
    fresh_ok=all(v["present"] and v["rows"]>0 and not v["errors"] for v in fresh.values())
    fresh_ok=fresh_ok and all(fresh["USD"]["monthly_rows"].get(m,0)>0 for m in diagnose._month_range("2026-01","2026-06"))
    fresh_anchor_results=[]
    for a in policy["anchors"]:
        if not a["utc"].startswith("2026-"):continue
        expected=stamp(a["utc"])
        actual=nearest(expected,[n for n in truth if n["currency"]==a["currency"] and n["code"]==a["event_code"]])
        ok=actual is not None and abs(actual["instant"]-expected)<=timedelta(minutes=5 if a["currency"]=="USD" else 15)
        fresh_anchor_results.append({**a,"pass":ok})
    fresh_anchor_ccys={a["currency"] for a in fresh_anchor_results if a["pass"]}
    write_json(out/"fresh_export_anchor_checks.json",fresh_anchor_results)
    native_monthly=Counter((n["currency"],n["instant"].strftime("%Y-%m")) for n in native)
    corrected_monthly=Counter((r.currency,r.instant.strftime("%Y-%m")) for r in corrected["primary"] if r.impact=="high")
    monthly=[{"currency":c,"month":m,"native_high_rows":native_monthly[(c,m)],
              "candidate_primary_high_rows":corrected_monthly[(c,m)],
              "usd_40_50_band":40<=native_monthly[(c,m)]<=50 if c=="USD" else "NOT_APPLICABLE",
              "count_basis":"NATIVE_OBSERVED_NO_SCHEDULE_SYNTHESIS"}
             for c,m in sorted(set(native_monthly)|set(corrected_monthly))]
    write_csv(out/"native_monthly_coverage.csv",monthly)
    row_loss=all(len(corrected[s])>=baseline[s+"_rows"]+backfill.get(s,0) for s in corrected)
    input_changes=[v["path"] for v in input_records if sha(Path(v["path"]))!=v["sha256"]]
    gates={
        "6.1_anchor_shares":{"pass":not anchor_fail and not name_error,"failed_groups":anchor_fail,"native_name_error":name_error},
        "6.2_coverage":{"pass":not any(unexplained.values()) and fresh_ok and fresh_anchor_ccys==set(CCYS),
                        "zero_months":months,"unexplained_zero_months":unexplained,"fresh_exports":fresh,
                        "fresh_currencies_with_confirmed_official_anchor":sorted(fresh_anchor_ccys)},
        "6.3_cross_file_identity":{"pass":cross_after["identical_instant"]>=baseline["primary_rows_with_identical_ff_instant"] and cross_after["matched"]==cross_after["identical_instant"],
                                   "before":cross_before,"after":cross_after},
        "6.4_nonusd_completeness":{"pass":len(completeness)>0,"currency_years":len(completeness),"gap_inventory_rows":len(inventory)},
        "6.5_tick_footprints":{"pass":all(a["status"]=="PASS" for a in footprints) and all(o["confirmed"] for o in offsets),
                               "checks":len(footprints),"status_counts":dict(Counter(a["status"] for a in footprints))},
        "6.6_no_row_loss":{"pass":row_loss,"backfill_rows":backfill,"declared_drops":0},
        "6.7_detector_clean":{"pass":diag["anchors"]["failed"]==0 and not any(unexplained.values()) and not input_changes
                               and not any(i.get("role")=="UNVERIFIED_TIMESTAMP_EXCLUDED_FROM_TRUTH" for i in input_records),
                               "failed_or_unverified_high_rows":diag["anchors"]["failed"],"input_changes":input_changes,
                               "unverified_native_exports":[i["path"] for i in input_records if i.get("role")=="UNVERIFIED_TIMESTAMP_EXCLUDED_FROM_TRUTH"]},
        "6.8_schema":{"pass":not schema_errors,"errors":schema_errors}}
    success=all(g["pass"] for g in gates.values())
    verification={"schema":SCHEMA,"decision_id":DECISION,"status":"PASS" if success else "FAIL",
                  "publishable":success,"exit_code":0 if success else 2,"gates":gates,
                  "message":"READY_FOR_CEO_REVIEW" if success else "INCOMPLETE_CANDIDATES_NOT_PUBLISHABLE; unresolved verification inputs and native timestamp anchors"}
    write_json(out/"verification.json",verification)
    manifest={"schema":SCHEMA,"decision_id":DECISION,"candidate_status":verification["message"],"publishable":success,
              "input_files":input_records,"files":parsed,"baseline_sha256":sha(out/"baseline.json"),
              "verification_sha256":sha(out/"verification.json"),"gap_list_sha256":sha(out/"repair_gaps.json"),
              "transform_counts_sha256":sha(out/"per_class_transforms.json"),"tool_sha256":sha(Path(__file__)),
              "timestamp_policy":"USD native/official instants; non-USD confirmed rate offsets only; unresolved rows retained as declared gaps; no stored-date reconstruction",
              "eet_display_rule":"EU last-Sunday March/October at 01:00Z; UTC+2 standard / UTC+3 summer; display only",
              "m5_rule":"qm.dst_rule.us.v1 broker wall epoch -> UTC before comparison; 15-minute band peak >= 1.5x same-slot control median",
              "gap_count":len(gaps),"production_write":False}
    write_json(out/"manifest.json",manifest)
    return {"output":str(out),"manifest_sha256":sha(out/"manifest.json"),**verification}


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--primary",type=Path,default=gate.DEFAULT_SOURCE_DIR/gate.PRIMARY_NAME)
    parser.add_argument("--secondary",type=Path,default=gate.DEFAULT_SOURCE_DIR/gate.SECONDARY_NAME)
    parser.add_argument("--native-dir",type=Path,default=NATIVE_DIR)
    parser.add_argument("--m5-dir",type=Path,default=NATIVE_DIR)
    parser.add_argument("--canonical-root",type=Path,default=CANONICAL)
    parser.add_argument("--extra-anchors",type=Path)
    parser.add_argument("--out",type=Path,default=STAGING/datetime.now(UTC).strftime("%Y%m%dT%H%M%S%fZ"))
    args=parser.parse_args()
    try:
        result=run_repair(args.primary,args.secondary,args.native_dir,args.m5_dir,args.out,
                          canonical_root=args.canonical_root,extra_anchors=args.extra_anchors)
    except (OSError,ValueError,KeyError) as exc:
        print(json.dumps({"status":"FAIL","publishable":False,"error":str(exc)},indent=2));return 2
    print(json.dumps({k:v for k,v in result.items() if k!="gates"},indent=2));return result["exit_code"]


if __name__=="__main__":raise SystemExit(main())
