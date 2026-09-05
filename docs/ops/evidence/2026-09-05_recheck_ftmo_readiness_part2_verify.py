"""Narrow read-only recheck of the exact 355d88586e documentation revision."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path('C:/QM/repo');REV='355d88586ec00b99c9739db349dd4c16b52ff667'
PATHS=['docs/ops/evidence/2026-09-05_ftmo_readiness_part1.md','docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md',
 'docs/ops/FTMO_STAGE_TRANSITION_RUNBOOK_2026-09.md','tools/strategy_farm/ftmo_lane_runner.py',
 'framework/monitor/QM_FTMO_TrialTelemetry.mq5','tools/strategy_farm/portfolio/ftmo_trial_telemetry.py',
 'tools/strategy_farm/generate_live_deployment_pointer.py','tools/strategy_farm/risk_freeze.py']
docs={};bindings=[]
for rel in PATHS:
    raw=subprocess.check_output(['git','show',REV+':'+rel],cwd=ROOT)
    current=(ROOT/rel).read_bytes()
    docs[rel]=raw.decode('utf-8-sig')
    bindings.append({'path':rel,'reviewed_lf_sha256':hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest(),
                     'current_sha256':hashlib.sha256(current).hexdigest(),
                     'current_matches_reviewed_lf':current.replace(b'\r\n',b'\n')==raw.replace(b'\r\n',b'\n')})
tree=ast.parse(docs[PATHS[3]])
symbol_lanes=None
for n in tree.body:
    if isinstance(n,ast.AnnAssign) and isinstance(n.target,ast.Name) and n.target.id=='SYMBOL_LANES':symbol_lanes=ast.literal_eval(n.value)
assert symbol_lanes and len(symbol_lanes)==8
assert symbol_lanes['USOIL.cash']['evaluator_symbol']=='XTIUSD'
p2=docs[PATHS[1]]
checks={
 'F5_blocked_dependency_present':'Runtime signed mint is currently blocked while freeze is ACTIVE' in p2,
 'F5_atomic_act_removed':'one atomic OWNER act' not in p2,
 'N1_eight_lane_statement_present':'defines eight lanes' in p2 and 'NATIVE_SYMBOLS = tuple(SYMBOL_LANES)' in p2,
 'N2_implementation_heading_present':'implementation delivered, not yet accepted' in p2,
 'N2_B4_delivery_present':'The delivered pair `QM_FTMO_TrialTelemetry.mq5` + `ftmo_trial_telemetry.py`' in p2,
 'caption_closed':'**Earlier captured swaps**' in docs[PATHS[0]],
 'runbook_freeze_closed':'this sequence starts only after the separately reviewed ceremony dependency is resolved' in docs[PATHS[2]],
 'runbook_blackout_closed':'QM news blackout mandatory; preserve the approved calendar/filter contract' in docs[PATHS[2]],
 'B2_absence_claim_remains':'Until that collector exists' in p2,
 'B2_symbol_gap_remains':'symbol (limit 2) gaps' in p2,
 'B7_absence_claim_remains':'AND the new Prague-day-keyed interval-minimum collector (B.2 hard limit 3) exists' in p2,
 'B6_new_tool_commission_remains':'collector** (new tool)' in p2,
 'generator_signed_write_calls_freeze_guard':'if args.signed and not args.dry_run:\n        risk_freeze.assert_live_book_mutation_allowed' in docs[PATHS[6]],
 'freeze_requires_lift_state_proof':'if result.get("lift_authority") and result.get("lifted_at_utc"):' in docs[PATHS[7]],
 'telemetry_append_and_one_second':'FileSeek(handle,0,SEEK_END)' in docs[PATHS[4]] and 'InpTimerSeconds  = 1' in docs[PATHS[4]],
 'telemetry_prague_consumer':'Europe/Prague' in docs[PATHS[5]],
}
assert all(checks.values()),checks
assert all(b['current_matches_reviewed_lf'] for b in bindings)
result={'task_id':'91ffb9e6-b484-4434-acb2-314898d504fa','reviewed_commit':REV,'verdict':'REJECT',
        'checks':checks,'symbol_lanes':symbol_lanes,'bindings':bindings,'runtime_action':False}
out=ROOT/'docs/ops/evidence/2026-09-05_recheck_ftmo_readiness_part2.json'
with out.open('x',encoding='utf-8') as f:json.dump(result,f,indent=2,sort_keys=True);f.write('\n')
print(json.dumps({'verdict':result['verdict'],'assertions':len(checks),'source_bindings':len(bindings),'out':str(out)}))
