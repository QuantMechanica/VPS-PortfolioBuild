"""Observed June2019 session calendar for reference diagnostics, not holiday proof."""
import hashlib
import json
from datetime import datetime, timezone, timedelta, date
from pathlib import Path
from strategy_runner import cash_ns

BASE=Path('D:/QM/reports/research/futures_pivot_20260922/progress_20260922')

def main():
    source=BASE/'cme_2019_session_sources_web.json';rawfile=BASE/'june2019_data_validation.json'
    raw=json.loads(rawfile.read_text());assert raw['status']=='RAW_VALIDATED_QUALITY_FLAGS_RETAINED'
    status={r['symbol']:r for r in raw['files'] if r['schema']=='status'}
    rows=[]
    for n in range(26):
        day=date(2019,6,3)+timedelta(days=n)
        if day.weekday()>4:continue
        symbol='MESM9' if day<date(2019,6,17) else 'MESU9'
        startns=cash_ns(str(day),'09:30:00');endns=cash_ns(str(day),'16:00:00')
        records=status[symbol]['status_records']
        before=[r for r in records if r['ts_recv']<=startns]
        seed=before[-1] if before else None
        intraday=[r for r in records if startns<r['ts_recv']<endns]
        usable=lambda r:r and r['action']==7 and r['is_trading']==89 and r['is_quoting']==89
        known=bool(usable(seed) and all(usable(r) for r in intraday))
        rows.append({'day':str(day),'symbol':symbol,'roll_excluded':day==date(2019,6,17),
                     'cash_open_ns':startns,'cash_close_ns':endns,
                     'regular_cash_session_observed':known,'status_seed':seed,
                     'status_events_in_cash_session':intraday,'status_file_sha256':status[symbol]['file_sha256'],
                     'calendar_basis':'OBSERVED_CME_STATUS_WITH_DATED_RULES_REFERENCE_ONLY',
                     'official_holiday_archive_complete':False})
    out={'schema':'qm.june2019-observed-session-calendar/v1','at_utc':datetime.now(timezone.utc).isoformat(),
         'primary_source_extract':str(source),'primary_source_extract_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
         'source_hash_kind':'CAPTURED_WEB_TOOL_EXTRACT_NOT_ORIGINAL_PDF_BYTES',
         'raw_validation_sha256':hashlib.sha256(rawfile.read_bytes()).hexdigest(),
         'classification':'REFERENCE_DIAGNOSTIC_ONLY_NOT_FULL_ARCHIVAL_HOLIDAY_CALENDAR','sessions':rows,
         'notes':['Contemporaneous CME2019 product notices establish 17:00-16:00 Chicago regular session plus15:15-15:30 halt; halt is after research15:55NewYork flat.',
          'Actual historical trading/quoting status independently checked over every cash session; unexpected nontrading/missing seed invalidates reference session.',
          'Separate dated holiday/earlyclose table is still missing. This does not satisfy the frozen trial calendar requirement.',
          'Juneteenth observation began2022 per datedCME notice. Modern holiday calendars are not applied retroactively.']}
    with (BASE/'june2019_observed_calendar.json').open('x',encoding='utf-8') as f:json.dump(out,f,indent=2);f.write('\n')
    print(json.dumps({'sessions':len(rows),'regular_observed':sum(r['regular_cash_session_observed'] for r in rows),
                      'dates_without_continuous_status':[r['day'] for r in rows if not r['regular_cash_session_observed']]}))

if __name__=='__main__':main()
