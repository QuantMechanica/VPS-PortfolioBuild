"""Inert live-mode trial set derivation from database-bound sealed baselines.

This creates review artifacts only. It never installs sets or authorizes execution.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sqlite3

TRIAL_ROOT = Path('D:/QM/strategy_farm/artifacts/ftmo_trial_sets_review')
DATABASE = Path('D:/QM/strategy_farm/state/farm_state.sqlite')
RULEPACK = Path('C:/QM/repo/tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json')
CANDIDATES = ((10706, 'GBPUSD'), (11421, 'EURUSD'), (11422, 'USDCAD'), (11910, 'NZDUSD'), (13054, 'XTIUSD'), (1537, 'XAGUSD'), (20048, 'XTIUSD'), (21505, 'XAGUSD'))
LANES = {'XAUUSD':'XAUUSD', 'GER40':'GER40.cash', 'GBPUSD':'GBPUSD', 'EURUSD':'EURUSD', 'USDCAD':'USDCAD', 'NZDUSD':'NZDUSD', 'XTIUSD':'USOIL.cash', 'XAGUSD':'XAGUSD'}
ALLOWED = frozenset(('RISK_FIXED', 'RISK_PERCENT', 'qm_news_temporal', 'qm_news_compliance', 'qm_news_stale_max_hours'))

class Refusal(ValueError):
    pass


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def values(text: str) -> dict[str, str]:
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        if '=' not in line:
            raise Refusal('malformed_set_line')
        key, value = (part.strip() for part in line.split('=', 1))
        if not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', key) or key in result or not value:
            raise Refusal('duplicate_or_invalid_parameter')
        if '||' in value:
            raise Refusal('optimization_range_not_trial_input')
        result[key] = value
    return result


def decode(raw: bytes) -> str:
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')


def identity(params: dict[str, str]) -> str:
    return sha(json.dumps({k:v for k,v in params.items() if k not in ALLOWED}, sort_keys=True, separators=(',', ':')).encode())


def verify_derivation(before: str, after: str) -> str:
    left, right = values(before), values(after)
    if {k:v for k,v in left.items() if k not in ALLOWED} != {k:v for k,v in right.items() if k not in ALLOWED}:
        raise Refusal('strategy_parameters_changed')
    return identity(left)


def derive(source: bytes, risk_percent: float) -> tuple[bytes, dict]:
    if not math.isfinite(risk_percent) or not 0 < risk_percent <= 1:
        raise Refusal('risk_percent_outside_dry_run_cap')
    text = decode(source)
    before = values(text)
    if float(before.get('RISK_FIXED', 'nan')) <= 0 or not math.isfinite(float(before.get('RISK_FIXED', 'nan'))) or float(before.get('RISK_PERCENT', 'nan')) != 0:
        raise Refusal('source_not_fixed_risk_backtest')
    stale = float(before.get('qm_news_stale_max_hours', '336'))
    if not math.isfinite(stale) or not 0 < stale <= 336:
        raise Refusal('stale_news_guard_invalid')
    updates = {'RISK_FIXED':'0', 'RISK_PERCENT':format(risk_percent, '.10g'), 'qm_news_temporal':'3', 'qm_news_compliance':'2', 'qm_news_stale_max_hours':format(stale, '.10g')}
    lines = []
    seen = set()
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith(';'):
            if re.match(r';\s*(environment|risk_mode)\s*:', stripped):
                continue
            lines.append(line)
            continue
        key = stripped.split('=', 1)[0].strip()
        if key in updates:
            lines.append(key + '=' + updates[key]); seen.add(key)
        else:
            lines.append(line)
    lines += [k+'='+v for k,v in updates.items() if k not in seen]
    lines += ['; environment: live', '; risk_mode: PERCENT', '; trial_status: INERT_REVIEW_ONLY; NOT_INSTALLABLE', '; ENV is provenance metadata; these EAs have no ENV input.']
    output = '\n'.join(lines) + '\n'
    proof = verify_derivation(text, output)
    return output.encode(), {'strategy_identity_sha256':proof, 'strategy_parameter_count':len([k for k in before if k not in ALLOWED]), 'changes':{k:{'before':before.get(k), 'after':v} for k,v in updates.items() if before.get(k) != v}}


def sealed_source(conn: sqlite3.Connection, ea: int, symbol: str) -> tuple[bytes, dict]:
    row = conn.execute("SELECT id,setfile_path,evidence_path,setfile_sha256 FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q10_NEWS' AND status='done' AND verdict='CONFIG_LOCKED' ORDER BY updated_at DESC LIMIT 1", (f'QM5_{ea}', symbol+'.DWX')).fetchone()
    if row is None:
        raise Refusal(f'unsealed_source:{ea}:{symbol}')
    task, source_name, seal_name, db_hash = row
    source_path, seal_path = Path(source_name).resolve(), Path(seal_name).resolve()
    seal_bytes = seal_path.read_bytes()
    seal = json.loads(seal_bytes)
    if seal.get('verdict') != 'CONFIG_LOCKED' or seal.get('schema_version') not in ('q09-news-adjudication/v2', 'q09-news-adjudication/v3'):
        raise Refusal('seal_not_locked')
    expected = seal.get('identities', {}).get('baseline_setfile_sha256')
    raw = source_path.read_bytes()
    if not expected or sha(raw) != expected or (db_hash and db_hash != expected):
        raise Refusal('sealed_source_hash_drift')
    return raw, {'ea_id':ea, 'symbol':symbol, 'native_symbol':LANES[symbol], 'seal_work_item_id':task, 'source_path':str(source_path), 'source_sha256':expected, 'seal_path':str(seal_path), 'seal_sha256':sha(seal_bytes), 'source_role':'SEALED_BASELINE_STRATEGY_PARAMETERS', 'original_selected_news_config':seal.get('chosen_config'), 'ex5_sha256':seal.get('identities', {}).get('ex5_sha256')}


def output_path(run_name: str) -> Path:
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}', run_name):
        raise Refusal('invalid_run_name')
    root = TRIAL_ROOT.resolve()
    # Refuse junction/symlink redirection out of the literal review tree.
    if str(root).replace('\\','/').casefold() != str(TRIAL_ROOT.absolute()).replace('\\','/').casefold():
        raise Refusal('review_root_redirected')
    target = root / run_name
    if target.exists() or target.resolve().parent != root:
        raise Refusal('output_exists_or_escapes_trial_root')
    return target


def generate(run_name: str, risk_percent: float, *, database: Path = DATABASE, rulepack: Path = RULEPACK) -> dict:
    target = output_path(run_name)
    rule_bytes = rulepack.read_bytes()
    rule = json.loads(rule_bytes)
    if rule.get('rulepack_id') != 'FTMO_2S_100K_SWING_V2':
        raise Refusal('wrong_rulepack')
    rules = {item['rule_id']:item for item in rule['official_rules']}
    daily = float(rules['ftmo_2s_max_daily_loss']['parameters']['percent_of_initial_simulated_capital'])
    total = float(rules['ftmo_2s_maximum_loss']['parameters']['percent_of_initial_simulated_capital'])
    if not 0 < daily <= 5 or not 0 < total <= 10:
        raise Refusal('rulepack_drawdown_limits_invalid')
    planned = []
    with sqlite3.connect(database.resolve().as_uri()+'?mode=ro', uri=True) as conn:
        for ea,symbol in CANDIDATES:
            raw, binding = sealed_source(conn, ea, symbol)
            data, proof = derive(raw, risk_percent)
            filename = f'QM5_{ea}_{symbol}_live_trial.set'
            planned.append((filename,data,dict(binding, **proof, output_path=filename, output_sha256=sha(data))))
    manifest = {'schema':'qm.ftmo-trial-setpath/v1', 'status':'INERT_REVIEW_ONLY', 'installed':False, 'installable':False, 'mode':'DRY_RUN', 'ENV':'live', 'risk_percent':risk_percent, 'risk_authority':'DRY_RUN_EXAMPLE_ONLY', 'rulepack':{'path':str(rulepack.resolve()),'sha256':sha(rule_bytes),'id':rule['rulepack_id']}, 'constraints':{'max_daily_loss_percent':daily,'max_total_loss_percent':total,'timezone':'Europe/Prague','news_blackout':'PRE30_POST30_PLUS_FTMO_COMPLIANCE','calendar_binding':'NATIVE_MT5_CALENDAR_LIVE; seed health and execution must be verified before installation','governor_enforcement':'REQUIRES_SEPARATE_ACCEPTED_TRIAL_GOVERNOR; NOT_PROVEN_BY_SET'}, 'candidates':[p[2] for p in planned]}
    # Validate the whole batch before writing any set; no active-set destination option.
    target.mkdir(parents=True)
    for filename,data,_ in planned:
        with (target / filename).open('xb') as handle:
            handle.write(data)
    (target/'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True)+'\n',encoding='utf-8')
    for filename,data,binding in planned:
        if sha((target/filename).read_bytes()) != binding['output_sha256']:
            raise Refusal('output_hash_mismatch')
        verify_derivation(decode(Path(binding['source_path']).read_bytes()),decode(data))
    return dict(manifest, directory=str(target))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-name', required=True)
    parser.add_argument('--risk-percent', type=float, required=True, help='Explicit dry-run example; not trading authority')
    parser.add_argument('--dry-run', action='store_true', required=True)
    args = parser.parse_args()
    result = generate(args.run_name, args.risk_percent)
    print(json.dumps({'directory':result['directory'],'sets':len(result['candidates']),'status':result['status']}))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
