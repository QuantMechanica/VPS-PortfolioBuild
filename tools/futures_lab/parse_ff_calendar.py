"""Offline June2019 parser for an OWNER-saved Forex Factory HTML snapshot.

No networking, browser access, JavaScript execution, automatic Desktop reads,
or raw-page persistence. Call only after OWNER confirms the save is complete.
Serialize an allowlist of calendar fields; never page settings/profile objects.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

UTC=timezone.utc
NY=ZoneInfo('America/New_York')
START=date(2019,6,1)
END=date(2019,6,30)
SOURCE_URL='https://www.forexfactory.com/calendar?month=jun.2019'
MAX_BYTES=8_000_000
MAX_DAYS=35

def read_json_after(text, pattern):
    m=re.search(pattern,text)
    if not m:
        raise ValueError('Missing field: '+pattern)
    return json.JSONDecoder().raw_decode(text[m.end():])[0]

def exclusion_dates(events, session_dates):
    result={}
    for day in session_dates:
        d=date.fromisoformat(day)
        start=datetime.combine(d,datetime.strptime('09:30','%H:%M').time(),NY)
        end=datetime.combine(d,datetime.strptime('15:59:30','%H:%M:%S').time(),NY)
        ids=[]
        for e in events:
            t=datetime.fromisoformat(e['timestamp_utc'].replace('Z','+00:00')).astimezone(NY)
            if t-timedelta(minutes=30)<=end and t+timedelta(minutes=30)>=start:
                ids.append(e['event_id'])
        result[day]={'excluded':bool(ids),'event_ids':ids}
    return result

def decode_saved_html(raw: bytes):
    # Chrome's HTML-only save can prepend windows-1252 while retaining a later
    # original UTF-8 meta tag. Honor the first actual HTML charset declaration.
    if raw.startswith(b'\xef\xbb\xbf'):
        return raw.decode('utf-8-sig'),'utf-8-bom'
    declared=None
    for tag in re.findall(br'<meta\b[^>]*>',raw[:16384],flags=re.I):
        match=re.search(br'charset\s*=\s*["\x27]?\s*([a-zA-Z0-9_-]+)',tag,flags=re.I)
        if match:
            declared=match[1].decode('ascii').lower()
            break
    codecs={'utf-8':'utf-8','utf8':'utf-8','windows-1252':'cp1252','cp1252':'cp1252','iso-8859-1':'cp1252'}
    label=declared or 'utf-8'
    if label not in codecs:
        raise ValueError('Unsupported declared HTML charset')
    return raw.decode(codecs[label]),label

def parse_month(raw: bytes) -> dict:
    if not raw or len(raw)>MAX_BYTES:
        raise ValueError('Snapshot empty or above bounded8MB limit')
    text,source_encoding=decode_saved_html(raw)
    blocks=re.split(r'window\.calendarComponentStates\[1\]\s*=\s*\{',text)[1:]
    if not 1<=len(blocks)<=4:
        raise ValueError('Calendar component absent or ambiguous')
    parsed=[]
    for block in blocks:
        parsed.append((read_json_after(block,r'^\s*days:\s*'),
            read_json_after(block,r'\n\s*settings:\s*'),
            read_json_after(block,r'\n\s*settingValues:\s*Object\.freeze\(')))
    if any(p!=parsed[0] for p in parsed[1:]):
        raise ValueError('Repeated calendar components disagree')
    days,settings,values=parsed[0]
    if not isinstance(days,list) or not 30<=len(days)<=MAX_DAYS:
        raise ValueError('Month requires30..35 explicit day containers')
    for field in ('currencies','impacts','event_types'):
        if not isinstance(values.get(field),dict) or not values[field]:
            raise ValueError('Missing filter value universe')
        if set(map(str,settings.get(field,[])))!=set(values[field]):
            raise ValueError('Filtered calendar: '+field)
    if 'USD' not in values['currencies'].values() or 'high' not in values['impacts'].values():
        raise ValueError('USD/HIGH classifications absent')
    for key,expected in (('begin_date',START),('end_date',END)):
        if datetime.strptime(settings[key],'%B %d, %Y').date()!=expected:
            raise ValueError('Not exact June1..30 month setting')
    zones=set(re.findall(r"['\"]timezone['\"]\s*:\s*['\"]([^'\"]+)['\"]",text))
    if len(zones)!=1:
        raise ValueError('Missing or ambiguous source timezone')
    source_zone=next(iter(zones))
    tz=ZoneInfo(source_zone)
    events=[]; untimed=[]; receipts=[]; seen_ids=set(); source_dates=[]
    for day in days:
        if type(day.get('dateline')) is not int:
            raise ValueError('Invalid day epoch')
        day_dt=datetime.fromtimestamp(day['dateline'],UTC)
        local=day_dt.astimezone(tz)
        source_day=local.date()
        if local.time()!=datetime.min.time():
            raise ValueError('Day epoch is not local midnight')
        if source_dates and source_day!=source_dates[-1]+timedelta(days=1):
            raise ValueError('Missing, repeated or unordered explicit day')
        source_dates.append(source_day)
        if not isinstance(day.get('events'),list):
            raise ValueError('Explicit event list required even for empty days')
        usd_count=0; high_count=0
        for event in day['events']:
            identifier=str(event.get('id',''))
            if not re.fullmatch(r'[1-9][0-9]*',identifier) or identifier in seen_ids:
                raise ValueError('Invalid or repeated event ID')
            seen_ids.add(identifier)
            currency=event.get('currency')
            impact=event.get('impactName')
            if (currency not in values['currencies'].values() and currency!='All') or impact not in values['impacts'].values():
                raise ValueError('Unknown currency or impact classification')
            if currency=='USD': usd_count+=1
            if currency not in ('USD','All') or impact!='high': continue
            if event.get('timeMasked') is not False or type(event.get('dateline')) is not int or event['dateline']<=0:
                high_count+=1
                if START<=source_day<=END:
                    title=event.get('name')
                    if not isinstance(title,str) or not title.strip() or len(title)>250:
                        raise ValueError('Invalid calendar event title')
                    untimed.append({'event_id':identifier,'title':title,'source_currency':currency,
                        'impact':'HIGH','applies_to_usd':True,'time_status':'UNTIMED',
                        'source_date':str(source_day),'source_timezone':source_zone,
                        'timestamp_utc':None,'source_raw_epoch_seconds':event.get('dateline'),
                        'source_time_label':event.get('timeLabel'),'month_source_url':SOURCE_URL,
                        'source_day_start_utc':day_dt.isoformat().replace('+00:00','Z'),
                        'reason':'UNTIMED_HIGH_ALL_EVENT' if currency=='All' else 'UNTIMED_HIGH_USD_EVENT'})
                continue
            stamp=datetime.fromtimestamp(event['dateline'],UTC)
            if stamp.astimezone(tz).date()!=source_day:
                raise ValueError('Event epoch outside its explicit source day')
            high_count+=1
            if not START<=source_day<=END: continue
            title=event.get('name')
            if not isinstance(title,str) or not title.strip() or len(title)>250:
                raise ValueError('Invalid calendar event title')
            # Construct a source link from validated dates/IDs, never copy page URLs.
            permalink='https://www.forexfactory.com/calendar?day='+source_day.strftime('%b').lower()+str(source_day.day)+'.'+str(source_day.year)+'#detail='+identifier
            events.append({'event_id':identifier,'title':title,'currency':'USD','source_currency':currency,'impact':'HIGH',
                'timestamp_utc':stamp.isoformat().replace('+00:00','Z'),
                'datetime_new_york':stamp.astimezone(NY).isoformat(),'epoch_seconds':event['dateline'],
                'source_timezone':source_zone,'source_url':permalink,'month_source_url':SOURCE_URL,
                'time_status':'TIMED','impact_basis':'FOREX_FACTORY_HISTORICAL_PAGE_AT_RETRIEVAL'})
        receipts.append({'source_date':str(source_day),'in_requested_month':START<=source_day<=END,
            'source_day_start_utc':day_dt.isoformat().replace('+00:00','Z'),
            'all_event_count':len(day['events']),'usd_event_count':usd_count,'high_usd_event_count':high_count,
            'empty_day_explicit':not day['events']})
    required={START+timedelta(days=i) for i in range(30)}
    if not required.issubset(source_dates):
        raise ValueError('June1..30 explicit coverage incomplete')
    if source_dates[0]<START-timedelta(days=5) or source_dates[-1]>END+timedelta(days=5):
        raise ValueError('Extraneous dates outside bounded month context')
    sessions=[str(START+timedelta(days=i)) for i in range(30) if (START+timedelta(days=i)).weekday()<5]
    start_utc=datetime.combine(START,datetime.min.time(),tz).astimezone(UTC)
    end_utc=datetime.combine(END+timedelta(days=1),datetime.min.time(),tz).astimezone(UTC)
    # Month boundaries must cover the full session and its event-search buffer.
    for session in sessions:
        d=date.fromisoformat(session)
        lo=datetime.combine(d,datetime.strptime('09:00','%H:%M').time(),NY).astimezone(UTC)
        hi=datetime.combine(d,datetime.strptime('16:29:30','%H:%M:%S').time(),NY).astimezone(UTC)
        if not start_utc<=lo<=hi<end_utc:
            raise ValueError('Source month boundaries do not cover requested NY sessions')
    events.sort(key=lambda e:(e['timestamp_utc'],e['event_id']))
    exclusion=exclusion_dates(events,sessions)
    for value in exclusion.values():
        value.update(coverage_complete=True,action='NEWS_BLACKOUT' if value['excluded'] else 'NEWS_FILTER_ELIGIBLE',
            reason='HIGH_USD_WINDOW' if value['excluded'] else 'NO_OVERLAPPING_HIGH_USD_EVENT')
    timing_excluded=set()
    for event in untimed:
        local_day=date.fromisoformat(event['source_date'])
        lo=datetime.combine(local_day,datetime.min.time(),tz).astimezone(UTC)-timedelta(minutes=30)
        hi=datetime.combine(local_day+timedelta(days=1),datetime.min.time(),tz).astimezone(UTC)+timedelta(minutes=30)
        affected=[]
        for session in sessions:
            d=date.fromisoformat(session)
            a=datetime.combine(d,datetime.strptime('09:30','%H:%M').time(),NY).astimezone(UTC)
            b=datetime.combine(d,datetime.strptime('15:59:30','%H:%M:%S').time(),NY).astimezone(UTC)
            if lo<=b and hi>=a:
                timing_excluded.add(session); affected.append(session)
                receipt=exclusion[session]
                receipt.update(excluded=True,coverage_complete=False,raw_calendar_day_present=True,
                    reason=event['reason'],action='NEWS_BLACKOUT')
                receipt['event_ids'].append(event['event_id'])
        event['conservative_excluded_ny_sessions']=affected
    covered=[d for d in sessions if d not in timing_excluded]
    return {'schema':'qm.named-vendor-historical-news-calendar.v1',
        'calendar_id':'FF_USD_HIGH_JUNE2019_OWNER_SAVED_MONTH','provider':'Forex Factory',
        'source_url':SOURCE_URL,'point_in_time':False,'status':'COMPLETE_VENDOR_MONTH_WITH_UNTIMED_EXCLUSIONS' if timing_excluded else 'COMPLETE_NAMED_VENDOR_MONTH_AT_RETRIEVAL',
        'historical_revision_warning':'2019 archive saved in2026; event times/names/impact may be revised. Not vintage2019 information or omniscient news coverage.',
        'complete_for_named_vendor':True,'complete_for_covered_sessions':True,
        'completeness_scope':'All explicitly represented June1..30 calendar days with every available currency/impact/event-type filter selected; includes explicit zero-event days. Complete only for this named vendor archive at retrieval.',
        'covered_session_dates':covered,'requested_session_dates':sessions,'missing_session_dates':sorted(timing_excluded),
        'missing_raw_calendar_dates':[],'timing_unresolved_session_dates':sorted(timing_excluded),
        'coverage_start_utc':start_utc.isoformat().replace('+00:00','Z'),'coverage_end_utc':end_utc.isoformat().replace('+00:00','Z'),
        'source_timezone':[source_zone],'source_encoding':source_encoding,'source_sha256':hashlib.sha256(raw).hexdigest(),'source_bytes':len(raw),
        'calendar_validation':{'explicit_day_count':len(days),'june_day_count':30,'all_filters_selected':True,
            'repeated_component_count':len(parsed),'month_begin':str(START),'month_end':str(END)},
        'days':receipts,'events':events,'untimed_high_impact_events':untimed,'session_exclusion':exclusion,
        'counts':{'source_days':len(days),'month_days':30,'all_events_in_month':sum(d['all_event_count'] for d in receipts if d['in_requested_month']),
            'timed_usd_relevant_high_events':len(events),'untimed_usd_relevant_high_events':len(untimed),
            'scheduled_rth_sessions':len(sessions),'covered_rth_sessions':len(covered),'missing_rth_sessions':len(timing_excluded),
            'missing_raw_calendar_days':0,'timing_excluded_rth_sessions':len(timing_excluded),
            'news_eligible_sessions':sum(not x['excluded'] for x in exclusion.values())},
        'frozen_skip_rule':{'currency':'USD','impact':'HIGH','buffer_minutes_before':30,'buffer_minutes_after':30,
            'timezone':'America/New_York','session_start':'09:30:00','session_end':'15:59:30','interval_overlap':'INCLUSIVE_ENDPOINTS','action':'SKIP_WHOLE_SESSION'},
        'untimed_policy':'OWNER-bound before results: All applies to USD. Untimed HIGH events never get invented timestamps; every NY session intersecting their source-local day plus30min is excluded through news_covered=false. Raw calendar days remain present.',
        'privacy':'Only allowlisted calendar fields serialized. Raw HTML and page/profile/settings objects are not persisted by this parser.',
        'reader':'OWNER_SAVED_HTML_OFFLINE_JSON_PARSE','route_authorization':'EXPLICIT_OWNER_PROVIDED_SNAPSHOT',
        'global_adapter_enablement':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-html',required=True,type=Path)
    parser.add_argument('--output-json',required=True,type=Path)
    args=parser.parse_args()
    source=args.source_html.resolve(strict=True)
    if source.stat().st_size>MAX_BYTES:
        raise ValueError('Snapshot exceeds8MB bounded read')
    raw=source.read_bytes()
    result=parse_month(raw)
    result.update(source_path=str(source).replace('\\','/'),
        fetched_at_utc=datetime.fromtimestamp(source.stat().st_mtime,UTC).isoformat(),
        fetched_at_utc_basis='OWNER_SAVED_FILE_MTIME_PROXY_NOT_NETWORK_RECEIPT',
        extracted_at_utc=datetime.now(UTC).isoformat(),
        parser_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    with args.output_json.open('x',encoding='utf-8') as handle:
        json.dump(result,handle,indent=2,ensure_ascii=False)
    print(json.dumps({'output':str(args.output_json),'sha256':hashlib.sha256(args.output_json.read_bytes()).hexdigest(),
        'counts':result['counts'],'eligible_dates':[k for k,v in result['session_exclusion'].items() if not v['excluded']]}))

if __name__=='__main__': main()
