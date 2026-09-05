"""Freeze existing M1 exports and dated provider terms into research evidence."""
import collections
import datetime as dt
import gzip
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SNAPSHOT = Path('C:/QM/repo/docs/ops/evidence/2026-09-05_ftmo_current_pool_cost_snapshot.json')
SYMBOLS = ('EURUSD','GBPUSD','USDCAD','NZDUSD','XAGUSD','XTIUSD')


def sha(raw):return hashlib.sha256(raw).hexdigest()


def quantile(values,p):
    a=sorted(values);k=(len(a)-1)*p;lo=math.floor(k);hi=math.ceil(k)
    return a[lo]+(a[hi]-a[lo])*(k-lo)


def summary(rows):
    out={}
    for hour in (0,6,12,18):
        values=[v for t,v in rows.items() if hour<=int(t[11:13])<hour+6]
        out[f'{hour:02d}:00-{hour+6:02d}:00']={'n':len(values),'p50':quantile(values,.5) if values else None,'p90':quantile(values,.9) if values else None,'p99':quantile(values,.99) if values else None}
    return out


def main():
    inputs=ROOT/'inputs';inputs.mkdir(exist_ok=False)
    raw=SNAPSHOT.read_bytes();snapshot=json.loads(raw.decode('utf-8-sig'));(inputs/'provider_snapshot.json').write_bytes(raw)
    snapshot_binding={'path':str(SNAPSHOT),'sha256':sha(raw),'retrieved_at_utc':snapshot['retrieved_at_utc']}
    harvest=[];selected={};unpaired=[]
    roots=[Path('D:/QM/mt5')/f'{lane}/MQL5/Files/QM/m1_harvest' for lane in ['FTMO_STREAM1','FTMO_STREAM2',*[f'T{i}' for i in range(1,11)]]]
    for root in roots:
        coverage_files=list(root.glob('*coverage.json'))
        complete_raw={p.with_name(p.name.replace('_coverage.json','_M1.jsonl')) for p in coverage_files}
        unpaired += [str(p) for p in root.glob('*M1.jsonl') if p not in complete_raw]
        for cp in coverage_files:
            craw=cp.read_bytes();c=json.loads(craw.decode('utf-8-sig'));symbol=c['symbol'].replace('.DWX','');symbol='XTIUSD' if symbol=='USOIL.cash' else symbol
            if symbol not in SYMBOLS:continue
            venue='FTMO' if root.parts[3].startswith('FTMO_') else 'DXZ'
            p=cp.with_name(cp.name.replace('_coverage.json','_M1.jsonl'));raw=p.read_bytes();rows={};prior=''
            for line in raw.splitlines():
                r=json.loads(line);t=r['ts'];v=r['spread']
                if t<=prior or isinstance(v,bool) or not isinstance(v,int) or v<0:raise ValueError(f'Invalid row in {p}')
                dt.datetime.fromisoformat(t.replace('Z','+00:00'));rows[t]=v;prior=t
            if c['status']!='COMPLETE' or len(rows)!=c['bar_count'] or min(rows)!=c['first_bar'] or max(rows)!=c['last_bar']:raise ValueError(f'Coverage mismatch {p}')
            name=root.parts[3]+'_'+p.name+'.gz';compressed=gzip.compress(raw,mtime=0);(inputs/name).write_bytes(compressed);(inputs/(root.parts[3]+'_'+cp.name)).write_bytes(craw)
            entry={'venue':venue,'symbol':symbol,'raw_path':str(p),'raw_sha256':sha(raw),'frozen_gzip_path':'inputs/'+name,'frozen_gzip_sha256':sha(compressed),'coverage_path':str(cp),'coverage_sha256':sha(craw),'coverage':c,'zero_spread_fraction':sum(v==0 for v in rows.values())/len(rows),'recorded_clock_bands':summary(rows)}
            harvest.append(entry)
            key=(venue,symbol)
            if key not in selected or c['last_bar']>selected[key][0]['coverage']['last_bar']:selected[key]=(entry,rows)
    ftmo=[selected[('FTMO',s)] for s in SYMBOLS];common=set.intersection(*(set(rows) for _,rows in ftmo))
    if not common:raise ValueError('No common FTMO minutes')
    coverage={'clock_basis':'RECORDED_TIMESTAMP_ONLY_UTC_SUFFIX_NOT_INDEPENDENTLY_ATTESTED',
              'clock_source_issue':'QM_M1_SpreadHarvest.mq5 IsoMinute formats broker CopyRates timestamps with Z without conversion; source-to-harvest-binary attestation absent.',
              'common_ftmo_first_recorded':min(common),'common_ftmo_last_recorded':max(common),'common_ftmo_minutes':len(common),
              'common_ftmo_minute_set_sha256':sha(('\n'.join(sorted(common))+'\n').encode()),'excluded_incomplete_exports':unpaired,'matched_venue_minutes':{}}
    symbols=[]
    for symbol in SYMBOLS:
        source=next(r for r in snapshot['symbols'] if r['symbol']==symbol);n=source['normalized'];entry,rows=selected[('FTMO',symbol)]
        dx=selected.get(('DXZ',symbol));matched=set(rows)&set(dx[1]) if dx else set();coverage['matched_venue_minutes'][symbol]=len(matched)
        def field(value,unit,provenance='provider-provisional',source_binding=snapshot_binding):
            return {'value':value,'unit':unit,'provenance':provenance,'source':source_binding}
        unknown={'basis':'No bound native contract/fill evidence in inspected snapshot/harvest artifacts.'}
        fields={'commission':field(n['commission_round_trip']['value'],n['commission_round_trip']['unit']),
                'swap_long':field(n['swap']['long'],n['swap']['unit']), 'swap_short':field(n['swap']['short'],n['swap']['unit']),
                'triple_rollover_weekday':field(None,'WEEKDAY','unknown',{'basis':'Provider API omits weekday; prior Wednesday convention remains unconfirmed.'}),
                'contract_size':field(n['contract']['contract_size'],n['contract']['contract_size_unit']),
                'tick_size':field(n['contract']['tick_size'],'PRICE_UNITS_PER_TICK'),
                'tick_value':field(n['contract']['tick_value'],n['contract']['tick_value_unit']),
                'swing_margin_percent':field(n['margin']['swing_margin_percent'],n['margin']['unit']),
                'lot_min':field(None,'TARGET_LOTS','unknown',unknown),'lot_step':field(None,'TARGET_LOTS','unknown',unknown),
                'fill_slippage':field(None,'PRICE_UNITS','unknown',unknown),
                'session_spread':field(summary({t:rows[t] for t in common}),'NATIVE_SYMBOL_POINTS_BY_RECORDED_CLOCK_BAND','measured',{'path':entry['raw_path'],'sha256':entry['raw_sha256'],'clock_admission':'UNVERIFIED_UTC; descriptive bands, not certified market sessions'})}
        symbols.append({'symbol':symbol,'provider_code':source['ftmo_code'],'fields':fields,'coverage':{'FTMO':entry['coverage'],'DXZ':dx[0]['coverage'] if dx else None,'matched_minutes':len(matched),'matched_spread_delta':None,'status':'NO_OVERLAP' if dx and not matched else 'DXZ_MISSING' if not dx else 'MATCHES_REQUIRE_CLOCK_AND_POINT_ATTESTATION'}})
    pack={'schema':'qm.ftmo-cost-version/v1','version_id':'ftmo-six-symbols-2026-09-05-v1','status':'REVIEW_RESEARCH_ONLY','governed_adoption':False,
          'observed_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'snapshot_binding':snapshot_binding,'symbols':symbols,'coverage':coverage,
          'open_items':['Overlapping same-symbol DXZ M1 bid/ask evidence for all six instruments; current EURUSD/GBPUSD windows end before FTMO starts.',
                        'Broker timestamp/DST and point-size attestation before named-session or cross-venue calibration.',
                        'Native FTMO contract evidence: lot minimum/step, triple rollover weekday, exact Swing margin and conversion currency.',
                        'Observed fill/slippage evidence separately from bar spread; CopyRates spread is not execution slippage.',
                        'Refresh provider terms and perform separate review before any governed cost-model adoption.',
                        'The OWNER-scheduled 2026-09-14 backfill must close coverage gaps; it cannot establish FTMO fills or current native symbol contracts.']}
    (ROOT/'cost_version.json').write_text(json.dumps(pack,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    (ROOT/'harvest_inventory.json').write_text(json.dumps({'harvests':harvest,'coverage':coverage,'source_snapshot':snapshot_binding},indent=2)+'\n')
    print(json.dumps({'harvests':len(harvest),'coverage':coverage,'cost_version_sha256':sha((ROOT/'cost_version.json').read_bytes())}))


if __name__=='__main__':main()
