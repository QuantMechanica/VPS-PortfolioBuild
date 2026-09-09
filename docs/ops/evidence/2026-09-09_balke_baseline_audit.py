"""Extract native baseline evidence without mutating the farm or source artifacts."""
import collections, csv, datetime as dt, hashlib, html, json, re
from pathlib import Path
from decimal import Decimal as D

OUT=Path(__file__).parent
ROOT=Path('D:/QM/reports/work_items/2fc84747-27db-5e88-9568-3fdda6c30769/QM5_41398/20260909_135814')
RAW=ROOT/'raw/run_01'
def read(p):
    b=p.read_bytes();return b.decode('utf-16' if b[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig')
def writecsv(name,rows,fields=None):
    with (OUT/name).open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields or list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
def num(s): return D(s.replace(' ','').replace('\xa0','') or '0')
def sunday(y,m,n):
    d=dt.datetime(y,m,1); return d+dt.timedelta(days=(6-d.weekday())%7+7*(n-1))
def dst(u): return sunday(u.year,3,2).replace(hour=7)<=u<sunday(u.year,11,1).replace(hour=6)
def utc(b):
    standard=b-dt.timedelta(hours=2)
    summer=b-dt.timedelta(hours=3)
    return standard if not dst(standard) else summer if dst(summer) else standard
def stamp(b):
    u=utc(b);return {'broker_time':b.isoformat(),'utc_time':u.isoformat()+'Z','season':'summer_US_DST' if dst(u) else 'winter_US_standard','broker_hour':b.hour,'utc_hour':u.hour,'strategy_hour':(u.hour+3)%24}
def pf(values):
    pos=sum(v for v in values if v>0); neg=-sum(v for v in values if v<0)
    return str(pos/neg) if neg else None
def main():
    native=read(RAW/'report.htm')
    section=native[native.rfind('>Deals<'):]
    deals=[]
    for idx,tr in enumerate(re.findall(r'<tr\b[^>]*>(.*?)</tr>',section,re.S),1):
        cells=[html.unescape(re.sub('<[^>]+>','',s)).strip() for s in re.findall(r'<td\b[^>]*>(.*?)</td>',tr,re.S)]
        if len(cells)!=13 or cells[4] not in ('in','out'):continue
        t=dt.datetime.strptime(cells[0],'%Y.%m.%d %H:%M:%S')
        deals.append(dict(zip(('time','deal','symbol','type','direction','volume','price','order','commission','swap','profit','balance','comment'),cells),**stamp(t),native_table_row=idx,source=str(RAW/'report.htm')))
    assert len(deals)==1776 and sum(d['direction']=='in' for d in deals)==888
    writecsv('2026-09-09_balke_baseline_deals.csv',deals)
    trades=[]; current=None
    for d in deals:
        if d['direction']=='in':
            assert current is None;current=d
        else:
            assert current is not None and num(current['volume'])==num(d['volume']) and current['type']!=d['type']
            gross=num(current['profit'])+num(d['profit'])
            commission=num(current['commission'])+num(d['commission']); swap=num(current['swap'])+num(d['swap'])
            trades.append({'entry_deal':current['deal'],'exit_deal':d['deal'],'entry_broker':current['broker_time'],'exit_broker':d['broker_time'],'entry_utc':current['utc_time'],'exit_utc':d['utc_time'],'season':current['season'],'side':current['type'],'volume':current['volume'],'entry_price':current['price'],'exit_price':d['price'],'gross_profit':str(gross),'commission_native':str(commission),'swap_native':str(swap),'net_native':str(gross+commission+swap),'net_dxz_5rt':str(gross+swap-D(5)*num(current['volume'])),'source':str(RAW/'report.htm')})
            current=None
    assert current is None
    writecsv('2026-09-09_balke_baseline_trades.csv',trades)
    groups=collections.Counter((r['direction'],r['season'],r['broker_hour'],r['utc_hour']) for r in deals)
    writecsv('2026-09-09_balke_hour_distribution.csv',[dict(direction=k[0],season=k[1],broker_hour=k[2],utc_hour=k[3],deals=v) for k,v in sorted(groups.items())])
    journal=read(RAW/'20260909.log').splitlines()
    starts=[i for i,s in enumerate(journal) if 'testing of Experts\\QM\\QM5_41398_' in s and 'from 2018.07.02 00:00 to 2022.12.31 00:00 started' in s]
    assert len(starts)==1
    start=starts[0];end=next(i for i in range(start+1,len(journal)) if 'test Experts\\QM\\QM5_41398_' in journal[i] and 'thread finished' in journal[i])
    segment=list(enumerate(journal[start:end+1],start+1))
    attempts=[]; errors=[]; runtime=[]
    pat=re.compile(r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+(failed )?(buy|sell) stop ([\d.]+) USDJPY\.DWX at ([\d.]+) sl: ([\d.]+)(.*)')
    for n,s in segment:
        if 'Test passed in' in s: runtime.append({'line':n,'text':s})
        m=pat.search(s)
        if m:
            t,failed,side,vol,price,sl,tail=m.groups(); b=dt.datetime.strptime(t,'%Y.%m.%d %H:%M:%S')
            q=re.search(r'\(([\d.]+) / ([\d.]+)\)',tail)
            hi=D(price) if side=='buy' else D(sl);lo=D(sl) if side=='buy' else D(price)
            bid=D(q[1]) if q else None;ask=D(q[2]) if q else None
            attempts.append(dict(line=n,date=b.date().isoformat(),side=side,accepted=not bool(failed),price=price,sl=sl,range_high=str(hi),range_low=str(lo),bid=str(bid) if q else '',ask=str(ask) if q else '',outside_high=(ask>hi) if q else '',outside_low=(bid<lo) if q else '',invalid_price='invalid price' in tail.lower(),**stamp(b),log=s,source=str(RAW/'20260909.log')))
        if re.search(r'\binvalid price\b|\b10015\b',s,re.I): errors.append({'line':n,'log':s,'source':str(RAW/'20260909.log')})
    assert attempts
    writecsv('2026-09-09_balke_order_attempts.csv',attempts)
    writecsv('2026-09-09_balke_invalid_price.csv',errors,['line','log','source'])
    daily=[]
    for day in sorted({a['date'] for a in attempts}):
        aa=[a for a in attempts if a['date']==day]; good=[a for a in aa if a['accepted']];bad=[a for a in aa if not a['accepted']]
        sides=set(a['side'] for a in good);qq=[a for a in aa if a['bid']]
        outside=any(a['outside_high'] or a['outside_low'] for a in qq)
        single=len(sides)==1
        tt=[t for t in trades if t['entry_broker'][:10]==day]
        # One accepted opposite stop + rejected breakout leg is directly observed;
        # price snapshot must also demonstrate outside the original unbuffered range.
        fade=single and outside and any(a['invalid_price'] for a in bad)
        daily.append(dict(date=day,accepted_buy=sum(a['side']=='buy' for a in good),accepted_sell=sum(a['side']=='sell' for a in good),failed_attempts=len(bad),invalid_price=sum(a['invalid_price'] for a in bad),quote_observed=bool(qq),outside_at_placement=outside if qq else 'UNKNOWN',single_pending_side=single,confirmed_fade_only=fade,trades=len(tt),net_native=str(sum((D(t['net_native']) for t in tt),D(0))),net_dxz_5rt=str(sum((D(t['net_dxz_5rt']) for t in tt),D(0))),log_lines=','.join(str(a['line']) for a in aa)))
    writecsv('2026-09-09_balke_outside_days.csv',daily)
    monthly=[]
    for month in sorted({t['entry_broker'][:7] for t in trades}):
        tt=[t for t in trades if t['entry_broker'][:7]==month]
        monthly.append(dict(month=month,trades=len(tt),pf_native=pf([D(t['net_native']) for t in tt]),pf_dxz_5rt=pf([D(t['net_dxz_5rt']) for t in tt]),net_native=str(sum(D(t['net_native']) for t in tt))))
    writecsv('2026-09-09_balke_monthly.csv',monthly)
    summary={'baseline_work_item':'2fc84747-27db-5e88-9568-3fdda6c30769','native_report':str(RAW/'report.htm'),'journal_source':str(RAW/'20260909.log'),'journal_isolation':{'start_line':start+1,'end_line':end+1},'baseline_window':{'from':'2018-07-02','to_exclusive':'2022-12-31'},'trades':len(trades),'gross_profit':str(sum(D(t['gross_profit']) for t in trades)),'native_commission':str(sum(D(t['commission_native']) for t in trades)),'native_swap':str(sum(D(t['swap_native']) for t in trades)),'net_native':str(sum(D(t['net_native']) for t in trades)),'net_dxz_5rt':str(sum(D(t['net_dxz_5rt']) for t in trades)),'pf_native':pf([D(t['net_native']) for t in trades]),'pf_dxz_5rt':pf([D(t['net_dxz_5rt']) for t in trades]),'placement_days':len(daily),'quote_observed_days':sum(d['quote_observed'] for d in daily),'outside_observed_days':sum(d['outside_at_placement'] is True for d in daily),'single_pending_side_days':sum(d['single_pending_side'] for d in daily),'invalid_price_lines_isolated':len(errors),'invalid_price_lines_unfiltered':sum(bool(re.search(r'\binvalid price\b|\b10015\b',s,re.I)) for s in journal),'confirmed_fade_only_days':sum(d['confirmed_fade_only'] for d in daily),'fade_only_trades':sum(d['trades'] for d in daily if d['confirmed_fade_only']),'fade_only_net_native':str(sum((D(d['net_native']) for d in daily if d['confirmed_fade_only']),D(0))),'runtime_evidence':runtime,'placement_hour_distribution':[dict(season=k[0],broker_hour=k[1],utc_hour=k[2],attempts=v) for k,v in sorted(collections.Counter((a['season'],a['broker_hour'],a['utc_hour']) for a in attempts).items())],'limitations':['Quote evidence is at actual placement, which can be later than range-end on blocked days; no all-calendar-day 06:00 quote census exists in these artifacts.','Deal fills may occur after the range window. Range-builder code, not fill distribution, establishes which bars form the range.','Native report commission is already present; replacement DXZ commission is computed from gross plus swap, not subtracted twice.','Logger ts_utc uses tester clock behavior; derived UTC uses broker timestamp and QM_DSTAware algorithm.'],'input_hashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (RAW/'report.htm',RAW/'20260909.log',RAW/'tester.ini',ROOT/'summary.json')}}
    assert abs(D(summary['net_native'])-D('46636.78'))<D('.01')
    assert sum(g['deals'] for g in [dict(deals=v) for v in groups.values()])==1776
    assert all(a['strategy_hour']==6 for a in attempts)
    summary['focused_verification']='PASS: 888 matched round trips, 1776 deals; native balance reconciled; isolated journal; all attempts strategy hour 6'
    (OUT/'2026-09-09_balke_baseline_summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(summary,indent=2))
if __name__=='__main__': main()
