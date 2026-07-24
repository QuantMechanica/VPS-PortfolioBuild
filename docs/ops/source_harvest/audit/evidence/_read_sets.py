import json, os, re

SETS = {
 15560004: r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\22_XAUUSD_D1_QM5_1556_aa-zak-mom12.set",
 104400003: r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\15_NDX_H1_QM5_10440_mql5-ohlc-mtf.set",
 109110003: r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\13_GDAXI_H1_QM5_10911_grimes-complex-pb.set",
 111320000: r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\16_SP500_D1_QM5_11132_tm-cum-rsi2.set",
 114210000: r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\09_EURUSD_D1_QM5_11421_ohlc-daily-squeeze-reversal-d1.set",
 125670002: r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\23_XNGUSD_D1_QM5_12567_cum-rsi2-commodity.set",
 129690000: r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\17_USDJPY_M30_QM5_12969_usdjpy-gotobi-nakane-fix.set",
 131280000: r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\14_NDX_H1_QM5_13128_pre-fomc-drift-ndx.set",
}

def readtext(p):
    with open(p, "rb") as f:
        raw = f.read()
    if raw.startswith(b"\xff\xfe"):
        return raw.decode("utf-16-le"), "utf-16-le-bom"
    if raw.startswith(b"\xfe\xff"):
        return raw.decode("utf-16-be"), "utf-16-be-bom"
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig"), "utf-8-sig"
    # no BOM: try utf-8, then cp1252
    try:
        return raw.decode("utf-8"), "utf-8-nobom"
    except Exception:
        return raw.decode("cp1252"), "cp1252"

# keys of interest (case-insensitive substrings)
KEYS = ["env","risk","fixed","percent","news","calendar","friday","close","kill","ks_","dd","daily","halt","loss","mode","lot","magic"]

out = {}
for magic, p in SETS.items():
    rec = {"path": p, "exists": os.path.exists(p)}
    if not os.path.exists(p):
        out[magic] = rec; continue
    st = os.stat(p)
    rec["mtime_iso"] = __import__("datetime").datetime.fromtimestamp(st.st_mtime).isoformat()
    t, enc = readtext(p)
    rec["encoding"] = enc
    lines = t.splitlines()
    rec["total_lines"] = len(lines)
    matched = []
    for i, ln in enumerate(lines, 1):
        low = ln.lower()
        if ln.strip().startswith(";"):  # comment/header
            if any(k in low for k in ["risk","env","mode","kill","news","dd"]):
                matched.append({"line": i, "text": ln})
            continue
        if any(k in low for k in KEYS):
            matched.append({"line": i, "text": ln})
    rec["matched_lines"] = matched
    # also capture first 6 raw lines (header)
    rec["head"] = lines[:6]
    out[magic] = rec

with open(r"C:\QM\repo\docs\ops\source_harvest\audit\evidence\compliance1__live_setfiles.json","w",encoding="utf-8") as f:
    json.dump(out, f, indent=1, ensure_ascii=False)
print("written")

