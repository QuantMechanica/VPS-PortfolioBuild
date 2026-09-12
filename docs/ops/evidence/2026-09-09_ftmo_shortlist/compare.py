"""Compare only explicitly exposed streams in the frozen intake, without OOS reads."""
import csv,datetime as dt,hashlib,json,statistics,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT))
from tools.strategy_farm.portfolio import ftmo_cost_adjusted_export as export
OUT=Path(__file__).resolve().parent
INTAKE=ROOT/'docs/ops/evidence/2026-09-09_ftmo_acceleration/intake.json'
TERMS=ROOT/'docs/ops/evidence/2026-09-05_ftmo_current_pool_cost_snapshot.json'
NATIVE=ROOT/'docs/ops/evidence/2026-09-06_ftmo_demo_install/terminal_snapshot.json'
RECEIPT_MANIFEST=ROOT/'docs/ops/evidence/2026-09-12_ftmo_native_cost_receipts/manifest.json'
SLIPPAGE_MANIFEST=Path(r'D:/QM/reports/ftmo/slippage_stream/20260907_20260912_taskf8ffb1c5/manifest.json')
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def drawdown(values):
    total=peak=dd=0.
    for n in values:total+=n;peak=max(peak,total);dd=max(dd,peak-total)
    return dd
def correlation(a,b):
    start=max(min(a),min(b));end=min(max(a),max(b));days=[]
    while start<=end:
        days.append(start);start+=dt.timedelta(days=1)
    x=[a.get(d,0) for d in days];y=[b.get(d,0) for d in days]
    if len(days)<30 or not statistics.pstdev(x) or not statistics.pstdev(y):return None,len(days)
    return statistics.correlation(x,y),len(days)
def analyze(pair,term_source,native,receipt,slippage_receipt):
    row={'ea_id':pair['ea_id'],'symbol':pair['symbol'],'evidence_class':'EXPOSED_HISTORICAL_EXPLORATORY_NOT_CURRENT_BINARY','news_reason':pair['active_reader_result']['reason_code'],'prospective_roster_selected':False,'cost_eligible':False,'spread_delta':None,'fill_slippage':None,'realized_ftmo_commission':None}
    if receipt:
        row.update(native_cost_receipt=receipt['_path'],native_cost_receipt_sha256=receipt['_sha256'],fill_slippage=receipt['fill_slippage'],realized_ftmo_commission=receipt['native_commission'],cost_eligible=bool(receipt['cost_eligible']))
    if slippage_receipt:
        slippage=slippage_receipt['stream']
        commission=(receipt or {}).get('native_commission') or {}
        row.update(slippage_stream_receipt=slippage_receipt['_path'],slippage_stream_receipt_sha256=slippage_receipt['_sha256'],fill_slippage=slippage,cost_eligible=commission.get('status')=='OBSERVED_NATIVE_DEALS' and slippage.get('status')=='COMPLETE' and slippage.get('value_for_cost_model') is not None)
    old=pair['historical_cost_projection_before_spread']
    if old is None:return dict(row,reason='NO_EXPOSED_COST_STREAM_IN_FROZEN_INTAKE'),{}
    sleeve=next(s for s in term_source['sleeves'] if s['sleeve_id']==old['sleeve_id'])
    p=Path(sleeve['trade_stream_path'])
    if sha(p)!=old['trade_stream_sha256']:raise ValueError(f'exposed stream hash drift: {p}')
    trades=export._load_q08(p,source_symbol=pair['symbol'],sleeve_id=sleeve['sleeve_id'],allow_zero_lifecycle=True)
    term=dict(next(t for t in term_source['consumer_instrument_rows'] if t['code']==sleeve['ftmo_code']))
    symbol='USOIL.cash' if pair['symbol']=='XTIUSD.DWX' else pair['symbol'].removesuffix('.DWX')
    spec=next(s for s in native['symbols'] if s['name']==symbol)
    term.update(tripleWeekday=(spec['swap_triple_day']+6)%7,swapLong=spec['swap_long'],swapShort=spec['swap_short'],contractSize=spec['contract_size'],digits=spec['digits'])
    buckets={export._bucket_name(t,60):0. for trade in trades for t in (trade.entry_utc,trade.exit_utc)}
    adjusted=[export._adjust_trade(t,term=term,buckets=buckets,bucket_minutes=60) for t in trades]
    pnls=[a.source.profit+a.source.fee-a.ftmo_entry_commission_charge-a.ftmo_exit_commission_charge+a.ftmo_swap_cash for a in adjusted]
    total=sum(pnls);lots=sum(a.target_volume for a in adjusted)
    daily={}
    for a,n in zip(adjusted,pnls):daily[a.source.exit_utc.date()]=daily.get(a.source.exit_utc.date(),0)+n
    dd=drawdown([daily[d] for d in sorted(daily)])
    first=min(t.entry_utc for t in trades);last=max(t.exit_utc for t in trades);years=max((last-first).total_seconds()/86400/365.25,1/365.25)
    row.update(stream_path=str(p),stream_sha256=sha(p),trades=len(trades),first_entry=first.isoformat(),last_exit=last.isoformat(),active_trade_span_years=years,trades_per_active_span_year=len(trades)/years,mean_holding_hours=statistics.mean((t.exit_utc-t.entry_utc).total_seconds()/3600 for t in trades),native_source_net=sum(t.net for t in trades),provisional_net_before_spread=total,old_projection_net=old['projected_ftmo_net_before_spread'],native_rollover_correction=total-old['projected_ftmo_net_before_spread'],target_lots_rt=lots,expectancy_usd_per_trade=total/len(trades),expectancy_usd_per_target_lot=total/lots,closed_daily_drawdown_usd=dd,return_to_closed_daily_drawdown=total/max(dd,1),provisional_swap_usd=sum(a.ftmo_swap_cash for a in adjusted),provisional_commission_usd=-sum(a.ftmo_entry_commission_charge+a.ftmo_exit_commission_charge for a in adjusted),break_even_additional_usd_per_rt_lot=total/lots,mt5_triple_day=spec['swap_triple_day'],python_triple_weekday=term['tripleWeekday'],reason='NEGATIVE_BEFORE_SPREAD' if total<=0 else 'CURRENT_IDENTITY_NATIVE_UNITS_AND_MATCHED_COSTS_INCOMPLETE')
    return row,daily
def main():
    intake,terms,native=read(INTAKE),read(TERMS),read(NATIVE)
    receipt_manifest=read(RECEIPT_MANIFEST);receipts={}
    for item in receipt_manifest['receipts']:
        p=RECEIPT_MANIFEST.parent/item['path']
        if sha(p)!=item['sha256']:raise ValueError(f'native receipt hash drift: {p}')
        receipt=read(p);receipt['_path']=str(p);receipt['_sha256']=item['sha256'];receipts[item['symbol']]=receipt
    slippage_manifest=read(SLIPPAGE_MANIFEST);slippage_receipts={}
    for item in slippage_manifest['receipts']:
        p=SLIPPAGE_MANIFEST.parent/item['path']
        if sha(p)!=item['sha256']:raise ValueError(f'slippage receipt hash drift: {p}')
        receipt=read(p);receipt['_path']=str(p);receipt['_sha256']=item['sha256'];slippage_receipts[item['symbol']]=receipt
    rows=[];daily={}
    for pair in intake['pairs']:
        native_symbol='USOIL.cash' if pair['symbol']=='XTIUSD.DWX' else pair['symbol'].removesuffix('.DWX')
        row,series=analyze(pair,terms,native,receipts.get(native_symbol),slippage_receipts.get(native_symbol));rows.append(row)
        if series:daily[pair['ea_id']+':'+pair['symbol']]=series
    correlations=[];keys=sorted(daily)
    for i,a in enumerate(keys):
        for b in keys[i+1:]:
            r,n=correlation(daily[a],daily[b]);correlations.append({'a':a,'b':b,'pearson_closed_daily_cash':r,'overlap_calendar_days':n,'zero_filled_nonexit_days':True,'not_mark_to_market':True})
    sensitivity=[{'ea_id':r['ea_id'],'symbol':r['symbol'],'additional_roundtrip_usd_per_target_lot':q,'provisional_net_after_additional_cost':r['provisional_net_before_spread']-q*r['target_lots_rt']} for r in rows if 'target_lots_rt' in r for q in (0,1,2,5,10,20,50)]
    units={'contract_size':'UNDERLYING_UNITS_PER_TARGET_LOT','swap_long':'POINTS_PER_TARGET_LOT_PER_ROLLOVER_UNIT','swap_short':'POINTS_PER_TARGET_LOT_PER_ROLLOVER_UNIT','swap_triple_day':'MT5_SUNDAY_0','lot_min':None,'lot_step':None,'tick_size':None,'tick_value_account_currency':None,'margin_order_calc':None,'realized_commission':None}
    bindings={str(p):sha(p) for p in (INTAKE,TERMS,NATIVE,RECEIPT_MANIFEST,SLIPPAGE_MANIFEST)}
    bindings.update({r['_path']:r['_sha256'] for r in receipts.values()})
    bindings.update({r['_path']:r['_sha256'] for r in slippage_receipts.values()})
    eligible=sum(bool(r.get('cost_eligible')) for r in rows)
    result={'schema':'qm.ftmo-exposed-shortlist-review/v1','task_id':'f8ffb1c5-83fe-46e7-9bf2-ffa8bbb6e986','predecessor_task':'17758960-375c-4ce5-80db-a14c261838dd','input_bindings':bindings,'native_receipt_manifest':receipt_manifest,'slippage_receipt_manifest':slippage_manifest,'native_spec_observed_at':native['checked_at_utc'],'native_spec_freshness':'HISTORICAL_SEPT6_NOT_CURRENT_AT_USE','native_specs':native['symbols'],'native_units_and_gaps':units,'account_type':'STANDARD_2STEP_100K_FREE_TRIAL_HISTORICAL_OWNER_RECORD','cost_class':'NATIVE_SEPT6_SWAP_PLUS_PROVISIONAL_PROVIDER_COMMISSION_PLUS_REQUEST_TIME_BROKER_TICK_SLIPPAGE_NO_MATCHED_SPREAD','pairs':rows,'correlations':correlations,'sensitivity':sensitivity,'selected_pairs':[],'selection_reason':f'ABSTAIN: {eligible}/4 investigation symbols are cost_eligible; USDCAD/USOIL.cash have no native fill/commission/slippage sample and matched spread remains incomplete','investigation_pairs':['QM5_10706:GBPUSD.DWX','QM5_11421:EURUSD.DWX','QM5_11422:USDCAD.DWX','QM5_13054:XTIUSD.DWX'],'reuse_tasks':['3032534e-eaf0-5b68-b09f-2127ebb315b0','f6d18a6e-0170-47c7-bbfd-e1b33d9d01c8'],'new_downloads':0,'native_runs':0}
    (OUT/'comparison.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    fields=list(dict.fromkeys(k for r in rows for k in r))
    with (OUT/'comparison.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader();writer.writerows(rows)
    print(json.dumps({'pairs':len(rows),'exposed_measured':len(daily),'selected':0,'comparisons':correlations,'normalized':[ {k:r.get(k) for k in ('ea_id','symbol','trades','expectancy_usd_per_target_lot','return_to_closed_daily_drawdown','native_rollover_correction','reason')} for r in rows]},indent=2))
if __name__=='__main__':main()
