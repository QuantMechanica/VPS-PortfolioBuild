"""Read-only source checks for router 85e4d7d4; writes only its evidence JSON."""
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal
from collections import defaultdict, Counter
import ast
import csv
import hashlib
import json
import subprocess
import sys
sys.path.insert(0,"C:/QM/repo")
from tools.strategy_farm.portfolio.validate_ftmo_readiness_part1 import holding_stats

ROOT=Path("C:/QM/repo")
FILES={"part1":"docs/ops/evidence/2026-09-05_ftmo_readiness_part1.md",
       "part2":"docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md",
       "runbook":"docs/ops/FTMO_STAGE_TRANSITION_RUNBOOK_2026-09.md"}
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:Path(p).read_text(encoding="utf-8-sig")
docs={k:subprocess.check_output(["git","-C",str(ROOT),"show","95343b30e9:"+v]).decode("utf-8") for k,v in FILES.items()}
identities={k:{"path":str(ROOT/v),"sha256":sha(ROOT/v),"matches_reviewed_commit_lf":read(ROOT/v).replace("\r\n","\n")==docs[k].replace("\r\n","\n")} for k,v in FILES.items()}
assert all(v["matches_reviewed_commit_lf"] for v in identities.values())
validation_path=ROOT/"docs/ops/evidence/2026-09-05_ftmo_readiness_part1_validation.json"
validation=json.loads(read(validation_path))
cost_path=ROOT/"docs/ops/evidence/2026-09-05_ftmo_current_pool_cost_snapshot.json"
cost=json.loads(read(cost_path))
pointer_path=Path("D:/QM/reports/state/live_deployment_pointer.json")
pointer=json.loads(read(pointer_path))
rule_path=ROOT/"tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json"
rules=json.loads(read(rule_path))
anchors=[]

def add(group,claim,doc_needle,path,source_locator,actual,expected,match=None):
    lines=docs[group].splitlines()
    line=next(i for i,s in enumerate(lines,1) if doc_needle in s)
    anchors.append({"group":group,"claim":claim,"document_line":line,"document_quote":lines[line-1],
                    "source":str(path),"source_sha256":sha(path),"source_locator":source_locator,
                    "actual":actual,"expected":expected,"matches":actual==expected if match is None else match})

holds={}
for key,v in validation["holding_periods"].items():
    got=holding_stats(Path(v["report"]["path"]));holds[key]=got
    assert got["trade_count"]==v["trade_count"] and got["median_holding_hours"]==v["median_holding_hours"]
    add("part1",key+" trade count",key.replace(":","/"),Path(v["report"]["path"]),"native Deals IN/OUT lifecycles",got["trade_count"],v["trade_count"])
    add("part1",key+" median holding hours","Median holding period (now measured",Path(v["report"]["path"]),"native Deals paired close_time-open_time median",got["median_holding_hours"],v["median_holding_hours"])

# Independent Decimal reconstruction of position lifecycles, not a second bootstrap.
deal_path=Path(validation["live_attribution"]["deal_export"]["path"])
positions=defaultdict(list)
for r in csv.DictReader(deal_path.open(encoding="utf-8-sig")):
    if r["type"]!="BALANCE" and int(r["position_id"] or 0)>0:positions[r["position_id"]].append(r)
roster={int(r["magic_number"]) for r in pointer["expected_sleeves"]["roster"]}
closed=[]
for pid,rows in positions.items():
    exits=[r for r in rows if r["entry"] in {"OUT","OUT_BY","INOUT"}]
    magics={int(r["magic"]) for r in rows if int(r["magic"])!=0}
    if exits and len(magics)==1 and next(iter(magics)) in roster:
        closed.append((max(r["time_utc"] for r in exits)[:10],sum(Decimal(r["net_actual"]) for r in rows)))
window=[r for r in closed if "2026-08-01"<=r[0]<="2026-09-04"]
dates=sorted({d for d,n in closed})[-30:]
literal=[r for r in closed if r[0] in dates]
add("part1","dated governed net","472.96",deal_path,"governed position lifecycles closed 2026-08-01..09-04",str(sum(n for d,n in window)),"-472.96")
add("part1","literal latest 30 close-days net","1,436.59",deal_path,"latest 30 governed close-date set",str(sum(n for d,n in literal)),"-1436.59")
for symbol in ("GBPUSD","XAGUSD"):
    item=next(s for s in cost["symbols"] if s["symbol"]==symbol)
    add("part1",symbol+" provisional swap",symbol+" (",cost_path,"symbols/"+symbol+"/normalized/swap",[item["normalized"]["swap"]["long"],item["normalized"]["swap"]["short"]],[-6.7,-5.2] if symbol=="GBPUSD" else [-23.05,.32])

for field,expected in [("signed",False),("expected_account","4000090541"),("expected_server","Darwinex-Live"),("expected_phase","DXZ_LIVE")]:
    add("part2",field,"24-sleeve",pointer_path,"/"+field,pointer[field],expected)
add("part2","sleeve count","24-sleeve",pointer_path,"/expected_sleeves/count",pointer["expected_sleeves"]["count"],24)
add("part2","missing binaries","n_binary_missing=0",pointer_path,"/binary_setfile_fingerprint/n_binary_missing",pointer["binary_setfile_fingerprint"]["n_binary_missing"],0)
gen=ROOT/"tools/strategy_farm/generate_live_deployment_pointer.py";g=read(gen)
add("part2","signed runtime guard","atomic OWNER act",gen,"main: guard before build_pointer/write","if args.signed and not args.dry_run:" in g,True)
add("part2","dry-run exits before write","--dry-run",gen,"main: if args.dry_run return 0 before _atomic_write_json",g.index("if args.dry_run:\n")<g.index("_atomic_write_json(out_path"),True)
pulse=ROOT/"tools/strategy_farm/ftmo_trial_pulse.py";p=read(pulse)
for token,needle in [('EXPECTED_STATE = "PARKED"',"EXPECTED_STATE='PARKED'"),("EXPECTED_PARKED_POSITION_COUNT = 1","EXPECTED_PARKED_POSITION_COUNT=1"),("EXPECTED_PARKED_POSITION_IDS = {527674048}","527674048")]:
    add("part2",token,needle,pulse,"source literal",token in p,True)
runner=ROOT/"tools/strategy_farm/ftmo_lane_runner.py";r=read(runner)
add("part2","replay risk contract","runner",runner,"setfile must use RISK_FIXED > 0 and RISK_PERCENT = 0","setfile must use RISK_FIXED > 0 and RISK_PERCENT = 0" in r,True)
monitor=ROOT/"framework/monitor/QM_AccountMonitor.mq5"
add("part2","legacy monitor snapshot overwrite","overwritten",monitor,"source header","overwritten each timer tick" in read(monitor),True)
tree=ast.parse(r);lanes=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.AnnAssign) and isinstance(n.target,ast.Name) and n.target.id=="SYMBOL_LANES")
add("part2","only two native symbols claim","Hard limit 2",runner,"SYMBOL_LANES / NATIVE_SYMBOLS",list(lanes),["XAUUSD","GER40.cash"])
collector=ROOT/"framework/monitor/QM_FTMO_TrialTelemetry.mq5"
add("part2","no durable collector on disk claim","Hard limit 3",collector,"append writer and trial schema",collector.exists(),False)
add("part2","FTMO-Demo profile","server=FTMO-Demo",runner,"_safe_profile_identity","FTMO-Demo" in r,True)
contract=ROOT/"docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md"
add("part2","binding lower-95 gate","lower_95",contract,"contract single P1 lower bound",("0.80" in read(contract) and "PENDING_OWNER_RATIFICATION" in read(contract)),True)
add("part2","OWNER signing boundary","OWNER only (ROT)",gen,"module docstring","OWNER/ROT" in g,True)
r5=ROOT/"docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md"
add("part2","R5 LF seal","de549514",r5,"LF-normalized SHA256",hashlib.sha256(r5.read_bytes().replace(b"\r\n",b"\n")).hexdigest(),"de549514fd75e68adb6f972a39451c89b43d7f7e35961e6e3da197903bfa923d")
add("part2","six current pool costs","all six",cost_path,"symbols",len(cost["symbols"]),6)

rule_index={r["rule_id"]:r for r in rules["official_rules"]}
checks=[("ftmo_2s_phase1_profit_target","percent_of_initial_simulated_capital","10","+10"),
        ("ftmo_2s_phase1_profit_target","balance_usd","110000","110,000"),
        ("ftmo_2s_verification_profit_target","percent_of_initial_simulated_capital","5","+5"),
        ("ftmo_2s_verification_profit_target","balance_usd","105000","105,000"),
        ("ftmo_2s_max_daily_loss","percent_of_initial_simulated_capital","5","5 %"),
        ("ftmo_2s_max_daily_loss","amount_usd","5000","5.000"),
        ("ftmo_2s_max_daily_loss","timezone","Europe/Prague","Prague"),
        ("ftmo_2s_max_daily_loss","tested_quantity","EQUITY_INCLUDING_OPEN_PNL_SWAPS_COMMISSIONS","EQUITY_INCLUDING_OPEN_PNL_SWAPS_COMMISSIONS"),
        ("ftmo_2s_max_daily_loss","breach_operator","STRICTLY_BELOW_LIMIT","STRICTLY_BELOW_LIMIT"),
        ("ftmo_2s_maximum_loss","model","STATIC_INITIAL","statisch"),
        ("ftmo_2s_maximum_loss","percent_of_initial_simulated_capital","10","10 %"),
        ("ftmo_2s_maximum_loss","floor_usd","90000","90.000"),
        ("ftmo_2s_minimum_trading_days","days",4,"mind. 4"),
        ("ftmo_2s_minimum_trading_days","qualifying_action","POSITION_OPENED","eröffneten"),
        ("ftmo_2s_pass_condition","positions_open",0,"positions_open=0"),
        ("ftmo_2s_pass_condition","balance_operator","STRICTLY_GREATER_THAN_TARGET","balance >"),
        ("ftmo_2s_evaluation_fee","list_fee_usd","540","540"),
        ("ftmo_2s_fee_refund","refund_percent","100","100 %"),
        ("ftmo_2s_reward_split","base_percent","80","80 %"),
        ("ftmo_swing_news","ftmo_account_swing_restricted",False,"news restriction")]
for rid,key,value,needle in checks:
    add("runbook",rid+"."+key,needle,rule_path,"official_rules/"+rid+"/parameters/"+key,rule_index[rid]["parameters"][key],value)

hashes=[{**v,"actual_sha256":sha(v["path"]),"matches":sha(v["path"])==v["sha256"]} for v in validation["inputs"]]
counts=dict(Counter(a["group"] for a in anchors));assert counts=={"part1":20,"part2":20,"runbook":20}
result={"schema":"qm.ftmo-readiness-rereview/v1","task_id":"85e4d7d4-e63b-4cd4-b765-a1defb01e61e","reviewed_commit":"95343b30e9f4d5689cbcda33dad2c78bb440fe62",
        "observed_at_utc":datetime.now(timezone.utc).isoformat(),"documents":identities,"anchors":anchors,"anchor_counts":counts,
        "mismatching_anchors":[a for a in anchors if not a["matches"]],"input_checks":hashes,
        "recomputed_holding_stats":holds,"live_reconstruction":{"window_net":str(sum(n for d,n in window)),"window_closes":len(window),"window_close_days":len({d for d,n in window}),"latest_30_net":str(sum(n for d,n in literal)),"latest_30_closes":len(literal)},
        "authority_boundary":rules["deployment_boundary"]}
out=ROOT/"docs/ops/evidence/2026-09-05_rereview_ftmo_readiness_packs.json"
out.write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print(json.dumps({"anchors":counts,"mismatches":[a["claim"] for a in result["mismatching_anchors"]],"hash_checks":len(hashes),"hash_failures":sum(not h["matches"] for h in hashes),"live":result["live_reconstruction"]},indent=2))
