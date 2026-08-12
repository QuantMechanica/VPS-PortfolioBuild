import os, json, collections

QMDIR = r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM"
# ea_id -> (magic of my row, logfile)
live = {
 1556:  (15560004, "QM5_1556_ea-1556.log"),
 10440: (104400003,"QM5_10440_ea-10440.log"),
 10911: (109110003,"QM5_10911_ea-10911.log"),
 11132: (111320000,"QM5_11132_ea-11132.log"),
 11421: (114210000,"QM5_11421_ea-11421.log"),
 12567: (125670002,"QM5_12567_ea-12567.log"),  # my row = XNGUSD slot2
 12969: (129690000,"QM5_12969_ea-12969.log"),
 13128: (131280000,"QM5_13128_ea-13128.log"),
}
# candidate former-live logs (informational only)
cand = {
 10692: "QM5_10692_ea-10692.log",
 1567:  "QM5_1567_ea-1567.log",
}

def readlines(p):
    with open(p,"rb") as f: raw=f.read()
    for enc in ("utf-8","cp1252","latin-1"):
        try: return raw.decode(enc).splitlines()
        except: continue
    return raw.decode("latin-1","replace").splitlines()

INTEREST = {"KILL_SWITCH_INIT","KILL_SWITCH_UNCONFIGURED","KILL_SWITCH_HALT","DAILY_LOSS_HALT",
            "PORTFOLIO_DD_HALT","FRIDAY_CLOSE","FRIDAY_CLOSE_FAILED","INIT","DEINIT",
            "SETUP_DATA_MISSING","NEWS_BLOCK","NEWS_FILTER","CALENDAR"}

def analyze(p, want_magic=None):
    lines = readlines(p)
    n = len(lines)
    events = collections.Counter()
    magics = collections.Counter()
    ks_init = []
    ks_unconf = []
    friday = []
    init_ev = []
    news_ev = []
    last_ts = None; first_ts=None
    for i, ln in enumerate(lines, 1):
        ln=ln.strip()
        if not ln: continue
        try:
            o=json.loads(ln)
        except:
            continue
        ev=o.get("event",""); mg=o.get("magic"); ts=o.get("ts_utc")
        if first_ts is None: first_ts=ts
        last_ts=ts
        events[ev]+=1
        magics[mg]+=1
        # for multi-magic files, filter to want_magic for KS/init; keep others as-is
        relevant = (want_magic is None) or (mg==want_magic)
        if ev=="KILL_SWITCH_INIT" and relevant:
            ks_init.append({"line":i,"ts":ts,"magic":mg,"payload":o.get("payload")})
        elif ev=="KILL_SWITCH_UNCONFIGURED" and relevant:
            ks_unconf.append({"line":i,"ts":ts,"magic":mg,"level":o.get("level")})
        elif ev in ("FRIDAY_CLOSE","FRIDAY_CLOSE_FAILED") and relevant:
            friday.append({"line":i,"ts":ts,"magic":mg,"event":ev,"payload":o.get("payload")})
        elif ev=="INIT" and relevant:
            init_ev.append({"line":i,"ts":ts,"magic":mg,"payload":o.get("payload")})
        elif ("NEWS" in ev or "CALENDAR" in ev or (ev=="SETUP_DATA_MISSING")) and relevant:
            news_ev.append({"line":i,"ts":ts,"magic":mg,"event":ev,"payload":o.get("payload")})
    return {
      "path":p,"n_lines":n,"first_ts":first_ts,"last_ts":last_ts,
      "event_counts":dict(events.most_common()),
      "magics_seen":dict(magics),
      "KILL_SWITCH_INIT":ks_init[-3:],
      "KILL_SWITCH_UNCONFIGURED_count":len(ks_unconf),
      "KILL_SWITCH_UNCONFIGURED_sample":ks_unconf[:2],
      "FRIDAY_CLOSE_count":len(friday),
      "FRIDAY_CLOSE_sample":friday[-3:],
      "INIT_sample":init_ev[-3:],
      "NEWS_events_count":len(news_ev),
      "NEWS_events_sample":news_ev[:4],
    }

out={"live":{}, "candidate_former_live":{}}
for eaid,(mg,fn) in live.items():
    p=os.path.join(QMDIR,fn)
    if os.path.exists(p):
        out["live"][mg]=analyze(p, want_magic=mg)
        out["live"][mg]["ea_id"]=eaid
    else:
        out["live"][mg]={"missing":p,"ea_id":eaid}
for eaid,fn in cand.items():
    p=os.path.join(QMDIR,fn)
    if os.path.exists(p):
        out["candidate_former_live"][eaid]=analyze(p, want_magic=None)
    else:
        out["candidate_former_live"][eaid]={"missing":p}

open(r"C:\QM\repo\docs\ops\source_harvest\audit\evidence\compliance1__qm_event_logs.json","w",encoding="utf-8").write(json.dumps(out,indent=1,ensure_ascii=False))
print("written")
