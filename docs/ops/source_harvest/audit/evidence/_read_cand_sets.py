import os, glob, json
BASE=r"C:\QM\repo\framework\EAs"
cands = {
 "1567_XAGUSD":  (r"QM5_1567_demark-td-reverse-sequential-h4", "XAGUSD.DWX", "H4"),
 "10145_XAUUSD": (r"QM5_10145_tsm-meanret", "XAUUSD.DWX", "D1"),
 "10692_NDX":    (r"QM5_10692_tv-ls-ms", "NDX.DWX", "H1"),
 "10815_EURUSD": (r"QM5_10815_tv-post-vwap", "EURUSD.DWX", "H1"),
 "12474_GBPUSD": (r"QM5_12474_gh-dual-thrust", "GBPUSD.DWX", "M1"),
}
def readtext(p):
    with open(p,"rb") as f: raw=f.read()
    if raw.startswith(b"\xff\xfe"): return raw.decode("utf-16-le")
    if raw.startswith(b"\xef\xbb\xbf"): return raw.decode("utf-8-sig")
    try: return raw.decode("utf-8")
    except: return raw.decode("cp1252")
KEYS=["env","risk","fixed","percent","news","calendar","friday","kill","ks_","dd","daily","halt","loss","magic","mode"]
out={}
for key,(d,sym,tf) in cands.items():
    setsdir=os.path.join(BASE,d,"sets")
    # canonical backtest set for the target symbol/tf
    want=f"{d}_{sym}_{tf}_backtest.set"
    p=os.path.join(setsdir,want)
    rec={"expected_path":p,"exists":os.path.exists(p)}
    if not os.path.exists(p):
        # fallback: any backtest.set matching symbol
        alt=glob.glob(os.path.join(setsdir,f"*{sym}_{tf}_backtest.set"))
        rec["alt_matches"]=alt[:5]
        if alt:
            p=alt[0]; rec["used_path"]=p; rec["exists"]=True
    if rec["exists"]:
        st=os.stat(p)
        rec["mtime_iso"]=__import__("datetime").datetime.fromtimestamp(st.st_mtime).isoformat()
        t=readtext(p)
        lines=t.splitlines()
        rec["total_lines"]=len(lines)
        rec["head"]=lines[:16]
        matched=[]
        for i,ln in enumerate(lines,1):
            low=ln.lower()
            if ln.strip().startswith(";"):
                if any(k in low for k in ["risk","env","mode","magic"]): matched.append({"line":i,"text":ln})
                continue
            if any(k in low for k in KEYS): matched.append({"line":i,"text":ln})
        rec["matched_lines"]=matched
    out[key]=rec
open(r"C:\QM\repo\docs\ops\source_harvest\audit\evidence\compliance1__candidate_backtest_sets.json","w",encoding="utf-8").write(json.dumps(out,indent=1,ensure_ascii=False))
print("written")
