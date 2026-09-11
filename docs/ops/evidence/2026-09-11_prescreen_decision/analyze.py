"""Read-only pilot analysis; writes only into this evidence directory. No launches."""
from pathlib import Path
import csv, json, hashlib, math, sqlite3, datetime, collections
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = Path('C:/QM/repo')
TASK = '3bc4034e-2432-4fd5-a839-330ca463d5f7'
B = 20000
SEED = 20260911

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def write(name, value):
    (HERE/name).write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False)+'\n', encoding='utf-8')

def ranks(x):
    x = np.asarray(x)
    return (x[..., :, None] > x[..., None, :]).sum(-1) + .5*(x[..., :, None] == x[..., None, :]).sum(-1) + .5

def rho(x, y):
    a, b = ranks(x), ranks(y)
    a, b = a-a.mean(-1, keepdims=True), b-b.mean(-1, keepdims=True)
    den = np.sqrt((a*a).sum(-1)*(b*b).sum(-1))
    return np.divide((a*b).sum(-1), den, out=np.full_like(den, np.nan), where=den>0)

def ci(values):
    v = np.asarray(values)
    finite = v[np.isfinite(v)]
    return {'percentile_95':np.quantile(finite,[.025,.975]).tolist(), 'valid':len(finite), 'degenerate':int(len(v)-len(finite))}

def wilson(k,n):
    z=1.959963984540054
    p=k/n; d=1+z*z/n
    a=(p+z*z/(2*n))/d; h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/d
    return [max(0,a-h),min(1,a+h)]

def top(rows, col, k):
    return {(r['year'],r['cell_key']) for r in sorted(rows,key=lambda r:(-float(r[col]),r['year'],r['cell_key']))[:k]}

def stats(rows, name):
    rng=np.random.default_rng(SEED)
    x=np.array([float(r['score_cheap']) for r in rows]); y=np.array([float(r['score_real']) for r in rows]); n=len(rows)
    idx=rng.integers(n,size=(B,n))
    out={'scope':name,'n':n,'rho':float(rho(x,y)),'paired_row_bootstrap':ci(rho(x[idx],y[idx])),
         'net_sign_agree':sum(np.sign(float(r['net_cheap']))==np.sign(float(r['net_real'])) for r in rows)/n,
         'trade_count_exact':sum(float(r['trades_cheap'])==float(r['trades_real']) for r in rows)/n,
         'top5_overlap':len(top(rows,'score_real',min(5,n)) & top(rows,'score_cheap',min(5,n))),
         'median_tester_seconds':float(np.median([float(r['tester_seconds_cheap']) for r in rows])), 'cuts':[]}
    if len({r['year'] for r in rows})>1:
        groups=[np.array([i for i,r in enumerate(rows) if r['year']==yr]) for yr in sorted({r['year'] for r in rows})]
        idx=np.concatenate([rng.choice(g,(B,len(g))) for g in groups],axis=1)
        out['year_stratified_bootstrap']=ci(rho(x[idx],y[idx]))
        groups=[np.array([i for i,r in enumerate(rows) if r['cell_key']==key]) for key in sorted({r['cell_key'] for r in rows})]
        vals=[]
        for _ in range(B):
            ix=np.concatenate([groups[i] for i in rng.integers(len(groups),size=len(groups))])
            vals.append(float(rho(x[ix],y[ix])))
        out['window_cluster_bootstrap']=ci(vals)
    truth50=top(rows,'score_real',max(1,n//2))
    for keep in (.3,.5,.7):
        k=max(1,math.floor(n*keep)); truth=top(rows,'score_real',k); kept=top(rows,'score_cheap',k)
        misses=truth-kept; dropped=n-k; controls=math.ceil(.1*dropped)
        out['cuts'].append({'keep_fraction':keep,'keep_n':k,'missed_top_same_k':len(misses),'truth_n':k,
            'fn_same_k':len(misses)/k,'fn_wilson_95_descriptive':wilson(len(misses),k),
            'missed_keys':sorted([f'{a}:{b}' for a,b in misses]),
            'missed_fixed_top50':len(truth50-kept),'fixed_top50_n':len(truth50),
            'sample_controls_rounded':controls,'sample_real_cells_saved':dropped-controls,
            'saved_per_100_candidates':90*(1-keep)})
    return out

def main():
    source=ROOT/'docs/ops/evidence/2026-09-11_t11_prescreen_pilot_orch.csv'
    # Freeze the exact input; later regenerations reuse it rather than a mutable surface.
    frozen=HERE/'pilot_input.csv'
    if not frozen.exists(): frozen.write_bytes(source.read_bytes())
    rows=list(csv.DictReader(frozen.open(encoding='utf-8-sig')))
    valid=[r for r in rows if r['receipt_status']=='COMPLETED']
    assert len(rows)==32 and len(valid)==29
    assert len({(r['mode'],r['year'],r['cell_key']) for r in valid})==29
    assert all(math.isclose(float(r['score_cheap']),float(r['net_cheap'])/max(abs(float(r['maxdd_cheap'])),1),rel_tol=1e-12) for r in valid)
    # Independent small rank fixtures, including ties.
    assert math.isclose(float(rho([1,2,3],[3,2,1])),-1)
    assert ranks([1,1,3]).tolist()==[1.5,1.5,3.0]
    surface_path=HERE/'surface_input.csv'
    if not surface_path.exists():
        surface_path.write_bytes((ROOT/'docs/ops/evidence/2026-09-09_window_sweep_surface.csv').read_bytes())
    surface=list(csv.DictReader(surface_path.open(encoding='utf-8-sig')))
    matches=[]
    for r in valid:
        s=next(s for s in surface if s['year']==r['year'] and s['start']==r['start'] and s['length']==r['length'] and s['exit']=='18')
        assert math.isclose(float(r['score_real']),float(s['score']),rel_tol=1e-12)
        assert math.isclose(float(r['net_real']),float(s['net_native']),abs_tol=.011)
        matches.append({k:s[k] for k in ['cell_key','work_item_id','score','net_native','lots_rt','net_costed_plan','maxdd','native_report','native_report_sha256']})
    out={'bootstrap_replicates':B,'seed':SEED,'numpy_version':np.__version__,
         'input_sha256':sha(frozen),'source_surface_sha256':sha(surface_path),
         'rows':len(rows),'included':len(valid),'excluded':[{'mode':r['mode'],'year':r['year'],'cell_key':r['cell_key'],'reason':r['receipt_status']} for r in rows if r not in valid],
         'score_real_definition':'surface costed (net_native - 5 * entry lots) / max(maxdd,1); NOT net_real / maxdd_real',
         'surface_matches':matches,'scopes':[]}
    for mode,year in [('ohlc-m1',None),('ohlc-m1','2021'),('open-prices','2021'),('ohlc-m1','2019'),('ohlc-m1','2023')]:
        out['scopes'].append(stats([r for r in valid if r['mode']==mode and (year is None or r['year']==year)],mode+':'+(year or 'pooled')))
    out['projections']=[]
    for n in [100,6400,350,21,371]:
        for keep in [.3,.5,.7]:
            savings=n*.9*(1-keep)
            out['projections'].append({'n':n,'keep':keep,'saved_real_cells_expected':savings,
                'released_fleet_hours_at_50_to_45': [savings/50,savings/45],
                'cheap_tester_hours_at_m1_median':n*out['scopes'][0]['median_tester_seconds']/3600,
                't11_wall_hours_at_payload_40_cells_h':n/40})
    out['verification']={'rank_fixtures':'PASS','unique_complete_rows':'PASS','cheap_score_formula':'PASS','real_score_surface_lineage':'PASS'}
    write('analysis.json',out)
    print(json.dumps({k:out[k] for k in ['scopes','verification']},indent=2))

if __name__=='__main__': main()
