"""Frozen QM5_9241 raw-signal census; ONLY 2019, never a performance test.
Extract actual MQL entry/predicate bodies, syntax-translate to C#, feed resampled
broker-clock M1. No MT5 process, trades, risk, news, cost, or economic gate result.
"""
from pathlib import Path
import csv, hashlib, json, re, shutil, subprocess, sys, tempfile
from collections import defaultdict

REPO=Path("C:/QM/repo")
LABEL="QM5_9241_mql5-engulf-retest"
SOURCE=REPO/"framework/EAs"/LABEL/(LABEL+".mq5")
SYMBOLS=("EURUSD.DWX","GBPUSD.DWX","XAUUSD.DWX")
YEAR=2019
sys.path.insert(0,str(REPO/"tools/strategy_farm/session_tools"))
import hcc_m1_reader_0921 as HCC


def method(code,name):
    start=re.search(rf"(?:bool|int) {name}\([^)]*\)\s*\{{",code).start()
    return code[start:code.index("\n}",start)+2]


def csharp():
    code=SOURCE.read_text(encoding="utf-8")
    names=("Strategy_EngulfDirection","Strategy_Invalidated","Strategy_Retest","Strategy_EntrySignal")
    body="\n".join(method(code,n) for n in names)
    body=body.replace("const ","").replace("MqlRates &","MqlRates ").replace("QM_EntryRequest &","QM_EntryRequest ")
    body=re.sub(r"(?m)^(bool|int) (Strategy_\w+)",r"public static \1 \2",body)
    body=re.sub(r"MqlRates (\w+), (\w+);",r"MqlRates \1=new MqlRates(), \2=new MqlRates();",body)
    body=re.sub(r"MqlRates (\w+);",r"MqlRates \1=new MqlRates();",body)
    body=body.replace("MathMin(","Math.Min(").replace("MathMax(","Math.Max(")
    prefix="""using System; using System.IO; using System.Globalization; using System.Collections.Generic;
public class MqlRates {public double open,high,low,close,atr; public long time;}
public class QM_EntryRequest {public int symbol_slot,type;public double sl,tp;public string reason;}
public static class Census9241 {
static List<MqlRates> bars=new List<MqlRates>(); static int current;
static string _Symbol="fixture"; static int PERIOD_H1=60,SYMBOL_ASK=1,SYMBOL_BID=2;
static int QM_BUY=1,QM_SELL=-1,qm_magic_slot_offset=0,strategy_retest_bars=8,strategy_atr_period=14;
static double strategy_min_engulf_atr=0.5,strategy_wick_threshold=0.35,strategy_stop_buffer_atr=0.3,strategy_target_r=2;
static int QM_FrameworkMagic(){return 92410000;}
static bool Strategy_NoTradeFilter(){return false;}
static bool QM_ReadBar(string s,int tf,int shift,MqlRates dest){int k=current-shift;if(k<0||k>=current)return false;
var b=bars[k];dest.open=b.open;dest.high=b.high;dest.low=b.low;dest.close=b.close;return true;}
static double QM_ATR(string s,int tf,int p,int shift){int k=current-shift;return k<0?0:bars[k].atr;}
static double SymbolInfoDouble(string s,int key){return bars[current].open;}
static double QM_TM_NormalizePrice(string s,double p){return p;}
static void ZeroMemory(QM_EntryRequest r){r.symbol_slot=0;r.type=0;r.sl=0;r.tp=0;r.reason="";}
"""
    suffix="""
public static string Run(string file){bars.Clear();
foreach(var line in File.ReadAllLines(file)){var c=line.Split(',');bars.Add(new MqlRates{
time=long.Parse(c[0]),open=double.Parse(c[1],CultureInfo.InvariantCulture),high=double.Parse(c[2],CultureInfo.InvariantCulture),
low=double.Parse(c[3],CultureInfo.InvariantCulture),close=double.Parse(c[4],CultureInfo.InvariantCulture),atr=double.Parse(c[5],CultureInfo.InvariantCulture)});}
int buys=0,sells=0,engulfs=0; long first=0,last=0;var req=new QM_EntryRequest();
for(current=25;current<bars.Count;current++){
var b=new MqlRates();var z=new MqlRates();int d=Strategy_EngulfDirection(1,b,z);if(d==1||d==-1)engulfs++;
if(Strategy_EntrySignal(req)){if(req.type==1)buys++;else sells++;if(first==0)first=bars[current].time;last=bars[current].time;}}
return buys+","+sells+","+engulfs+","+first+","+last;
}}
"""
    return prefix+body+suffix


def main():
    result={"schema":"qm.retest-raw-reachability/v1","year":YEAR,
      "source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
      "source_commit":"41c271b988","reader_sha256":hashlib.sha256(Path(HCC.__file__).read_bytes()).hexdigest(),
      "scope":"Raw entry reachability only; not trades, PF, edge or payout probability",
      "assumptions":["M1 aggregated into broker-clock H1 buckets; one observed M1 or more per bucket",
        "ATR proxy is 14-bar simple mean true range; native MT5 parity still required",
        "entry bid=ask=next observed H1 open; no spread/cost/news/open-position suppression or price rounding",
        "no terminal or history mutation; no 2020-2025 files opened; no parameter search"],"symbols":[]}
    with tempfile.TemporaryDirectory(prefix="qm9241_census_") as tmp:
      tmp=Path(tmp);commands=[]
      for symbol in SYMBOLS:
        raw,path=HCC._open_year(symbol,YEAR)
        rows=sorted(HCC.read_year(symbol,YEAR)); seen=set(); groups={};dupes=0
        for t,o,h,l,c,tv,sp in rows:
          if t in seen:dupes+=1;continue
          seen.add(t);hour=t//3600*3600
          if hour not in groups:groups[hour]=[hour,o,h,l,c,1]
          else:
            a=groups[hour];a[2]=max(a[2],h);a[3]=min(a[3],l);a[4]=c;a[5]+=1
        bars=sorted(groups.values());tr=[];output=[]
        for i,b in enumerate(bars):
          prev=bars[i-1][4] if i else b[1]
          tr.append(max(b[2]-b[3],abs(b[2]-prev),abs(b[3]-prev)))
          atr=sum(tr[-14:])/14 if len(tr)>=14 else 0
          output.append([*b[:5],atr])
        csvpath=tmp/(symbol+".csv")
        with csvpath.open('w',newline='') as f:csv.writer(f).writerows(output)
        commands.append("[Census9241]::Run('"+str(csvpath).replace("'","''")+"')")
        result['symbols'].append({'symbol':symbol,'history_path':path,'history_sha256':hashlib.sha256(raw).hexdigest(),
          'm1_rows':len(rows),'duplicate_minutes':dupes,'h1_bars':len(bars),'hours_with_60_minutes':sum(b[5]==60 for b in bars)})
      script="$ErrorActionPreference='Stop'\nAdd-Type -TypeDefinition @'\n"+csharp()+"\n'@\n"+'\n'.join(commands)+'\n'
      ps=tmp/'census.ps1';ps.write_text(script,encoding='utf-8')
      run=subprocess.run([shutil.which('pwsh') or shutil.which('powershell'),'-NoProfile','-NonInteractive','-File',str(ps)],capture_output=True,text=True,timeout=50)
      if run.returncode:raise RuntimeError(run.stdout+run.stderr)
      lines=[line for line in run.stdout.splitlines() if re.fullmatch(r'\d+,\d+,\d+,\d+,\d+',line.strip())]
      assert len(lines)==3,run.stdout+run.stderr
      for row,line in zip(result['symbols'],lines):
        buy,sell,engulf,first,last=map(int,line.split(','));row.update(raw_buy_signals=buy,raw_sell_signals=sell,qualified_engulfings=engulf,first_signal_broker_epoch=first,last_signal_broker_epoch=last)
    Path(__file__).with_name('retest_reachability_2019.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
