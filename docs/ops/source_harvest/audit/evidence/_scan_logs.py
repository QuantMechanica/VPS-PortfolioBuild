import os, glob, json

def readtext(p):
    with open(p,"rb") as f: raw=f.read()
    if raw.startswith(b"\xff\xfe"): return raw.decode("utf-16-le")
    if raw.startswith(b"\xfe\xff"): return raw.decode("utf-16-be")
    if raw.startswith(b"\xef\xbb\xbf"): return raw.decode("utf-8-sig")
    # heuristic: many nulls -> utf-16-le
    if raw[:400].count(b"\x00") > 20:
        try: return raw.decode("utf-16-le")
        except: pass
    try: return raw.decode("utf-8")
    except: return raw.decode("cp1252")

TERM = r"C:\QM\mt5\T_Live\MT5_Base\logs"
EXP  = r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Logs"

# recent dated logs (most recent first)
def dated(dirp):
    fs = sorted(glob.glob(os.path.join(dirp, "202*.log")))
    return fs

magics = ["15560004","104400003","109110003","111320000","114210000","125670002","129690000","131280000"]
names = ["QM5_1556_aa-zak-mom12","QM5_10440_mql5-ohlc-mtf","QM5_10911_grimes-complex-pb",
         "QM5_11132_tm-cum-rsi2","QM5_11421_ohlc-daily-squeeze-reversal-d1","QM5_12567_cum-rsi2-commodity",
         "QM5_12969_usdjpy-gotobi-nakane-fix","QM5_13128_pre-fomc-drift-ndx"]
name_short = ["1556_aa-zak","10440_mql5-ohlc","10911_grimes-complex","11132_tm-cum-rsi2",
              "11421_ohlc-daily-squeeze","12567_cum-rsi2-commodity","12969_usdjpy-gotobi","13128_pre-fomc-drift"]
keywords = ["KILL_SWITCH","KS_","daily_loss_halt","DAILY_LOSS","FRIDAY_CLOSE","friday","news","calendar",
            "PORTFOLIO_DD","portfolio_dd","halt_pct","INIT","kill","killswitch","MaxDD","max_dd","dd_kill"]

toks = set(magics) | set(names) | set(name_short)

out = {"terminal_logs": {}, "expert_logs": {}, "files_scanned": []}

def scan(files, bucket):
    for p in files:
        try:
            t = readtext(p)
        except Exception as e:
            out[bucket][os.path.basename(p)] = {"error": str(e)}
            continue
        out["files_scanned"].append(p)
        lines = t.splitlines()
        hits = []
        for i, ln in enumerate(lines, 1):
            low = ln.lower()
            hit_tok = [tk for tk in toks if tk in ln]
            hit_kw = [kw for kw in keywords if kw.lower() in low]
            if hit_tok or hit_kw:
                hits.append({"line": i, "text": ln.strip(), "tok": hit_tok, "kw": hit_kw})
        out[bucket][os.path.basename(p)] = {"path": p, "n_lines": len(lines), "hits": hits, "n_hits": len(hits)}

scan(dated(TERM), "terminal_logs")
scan(dated(EXP), "expert_logs")

with open(r"C:\QM\repo\docs\ops\source_harvest\audit\evidence\compliance1__tlive_log_scan.json","w",encoding="utf-8") as f:
    json.dump(out, f, indent=1, ensure_ascii=False)
print("written; term files:", len(dated(TERM)), "exp files:", len(dated(EXP)))
