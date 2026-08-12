import os
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
    with open(p,"rb") as f: raw=f.read()
    if raw.startswith(b"\xff\xfe"): return raw.decode("utf-16-le")
    if raw.startswith(b"\xef\xbb\xbf"): return raw.decode("utf-8-sig")
    try: return raw.decode("utf-8")
    except: return raw.decode("cp1252")
out=[]
for m,p in SETS.items():
    out.append("========== MAGIC %d :: %s ==========" % (m, os.path.basename(p)))
    t=readtext(p)
    for i,ln in enumerate(t.splitlines(),1):
        out.append("%3d| %s" % (i, ln))
    out.append("")
with open(r"C:\QM\repo\docs\ops\source_harvest\audit\evidence\compliance1__live_setfiles_full.txt","w",encoding="utf-8") as f:
    f.write("\n".join(out))
print("written", len(out), "lines")
