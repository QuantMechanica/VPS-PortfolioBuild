"""Task 55eaa2ee: synthetic two-leg basket encodings through the ACTUAL book consumers.

Read-only against C:/QM/repo. Fixture rows only (one basket, two legs closing at the
same instant). No historical stream, no Monte Carlo, no book run, no provider call.
Checks: monetary scaling, daily-low (loss-rule) proxy, commission/stress host-symbol
substitution, nominal risk metadata (concentration / expectancy denominator).
"""
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

REPO = Path('C:/QM/repo')
sys.path[:0] = [str(REPO), str(REPO / 'tools/strategy_farm')]
from tools.strategy_farm.ftmo import book_sim as book  # noqa: E402
from tools.strategy_farm.ftmo import first_passage as fp  # noqa: E402

FIX = Path('D:/QM/strategy_farm/artifacts/task_55eaa2ee-0380-4799-9141-5639a0f6548a/fixtures')
FIX.mkdir(parents=True, exist_ok=True)
OUT = Path(__file__).with_name('consumer_contract_check.json')

ENTRY = int(dt.datetime(2021, 1, 4, 8, tzinfo=dt.timezone.utc).timestamp())
CLOSE = int(dt.datetime(2021, 1, 6, 10, tzinfo=dt.timezone.utc).timestamp())
START, END = dt.date(2021, 1, 4), dt.date(2021, 1, 8)
R = 0.15625  # basket target risk; native source = aggregate $1000 on $100k = 1.0 %


def leg(symbol, profit, mae, volume, notional):
    return dict(event='TRADE_CLOSED', entry_time=ENTRY, time=CLOSE, symbol=symbol,
                side='BUY' if symbol.startswith('XAU') else 'SELL', profit=profit,
                net=profit, swap=0.0, commission=0.0, fee=0.0, mae_acct=mae,
                mfe_acct=max(profit, 0.0), volume=volume, notional=notional)


XAU = leg('XAUUSD.DWX', 500.0, -100.0, 0.50, 95000.0)
XAG = leg('XAGUSD.DWX', -300.0, -800.0, 0.60, 75000.0)
REGISTRY = book._load_commission_registry(book.DEFAULT_COMMISSION_REGISTRY)


def spec(name, rows, symbol, risk):
    path = FIX / f'{name}.jsonl'
    path.write_text(''.join(json.dumps(r) + '\n' for r in rows), encoding='utf-8')
    return book.SleeveSpec(id=name, ea_id=41112, symbol=symbol, timeframe='D1',
                           stream_path=str(path),
                           stream_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                           risk_percent=risk, family='XAUXAG_RV_BASKET')


def prepare(specs, cost=book.CostConfig()):
    return [book.prepare_sleeve(s, commission_registry=REGISTRY, cost=cost,
                                financing_module=None, financing_status='FIXTURE',
                                financing_label='UNFINANCED') for s in specs]


def fp_book_low(sleeves):
    tz = ZoneInfo(str(fp.load_rules()['timezone']))
    roster = book._to_first_passage_roster(sleeves, start=START, end=END, timezone=str(tz))
    grid = fp.build_grid(roster['sleeves'])
    return round(float(grid['low'].min()), 6), round(float(grid['net'].sum()), 6)


def case(name, specs, cost=book.CostConfig()):
    sleeves = prepare(specs, cost)
    metrics, _ = book.account_path_metrics(sleeves, start=START, end=END)
    fp_low, fp_net = fp_book_low(sleeves)
    return {
        'sleeves': [{'id': s['id'], 'symbol': s['symbol'], 'risk_percent': s['risk_percent'],
                     'rows': len(s['trades'])} for s in sleeves],
        'net_scaled_total': round(sum(t['net_scaled'] for s in sleeves for t in s['trades']), 6),
        'commission_scaled_total': round(sum(t['commission_scaled'] for s in sleeves for t in s['trades']), 6),
        'spread_stress_scaled_total': round(sum(t['spread_stress_scaled'] for s in sleeves for t in s['trades']), 6),
        'slippage_stress_scaled_total': round(sum(t['slippage_stress_scaled'] for s in sleeves for t in s['trades']), 6),
        'account_path_worst_daily_low': metrics['BOOK_WORST_DAILY_LOSS_MAE_PROXY'],
        'first_passage_grid_worst_low': fp_low,
        'first_passage_grid_net': fp_net,
        'BOOK_EXPECTANCY': metrics['BOOK_EXPECTANCY'],
        'concentration': book._concentration(sleeves),
    }


uniform = book.CostConfig(spread_bps_rt=1.0, slippage_usd_per_lot_rt=2.0)
per_symbol = book.CostConfig(spread_bps_rt_by_symbol={'XAUUSD.DWX': 1.0, 'XAGUSD.DWX': 3.0},
                             slippage_usd_per_lot_rt_by_symbol={'XAUUSD.DWX': 2.0, 'XAGUSD.DWX': 6.0})
cases = {
    'A_whole_host_XAU_xau_row_first': case('A', [spec('A', [XAU, XAG], 'XAUUSD.DWX', R)]),
    'B_whole_host_XAU_xag_row_first': case('B', [spec('B', [XAG, XAU], 'XAUUSD.DWX', R)]),
    'C_whole_host_XAG_xau_row_first': case('C', [spec('C', [XAU, XAG], 'XAGUSD.DWX', R)]),
    'D_split_full_risk_legs': case('D', [spec('D_xau', [XAU], 'XAUUSD.DWX', R),
                                         spec('D_xag', [XAG], 'XAGUSD.DWX', R)]),
    'E_split_half_risk_legs': case('E', [spec('E_xau', [XAU], 'XAUUSD.DWX', R / 2),
                                         spec('E_xag', [XAG], 'XAGUSD.DWX', R / 2)]),
    'U_whole_uniform_stress': case('U', [spec('U', [XAU, XAG], 'XAUUSD.DWX', R)], uniform),
    'V_split_full_uniform_stress': case('V', [spec('V_xau', [XAU], 'XAUUSD.DWX', R),
                                              spec('V_xag', [XAG], 'XAGUSD.DWX', R)], uniform),
    'P_whole_per_symbol_stress': case('P', [spec('P', [XAU, XAG], 'XAUUSD.DWX', R)], per_symbol),
    'Q_split_full_per_symbol_stress': case('Q', [spec('Q_xau', [XAU], 'XAUUSD.DWX', R),
                                                 spec('Q_xag', [XAG], 'XAGUSD.DWX', R)], per_symbol),
}
# Conservative per-leg envelope for one basket: both legs at their own worst at once.
comm = {k: REGISTRY['classes'][REGISTRY['symbol_class'][k]]['pct_rate_rt'] for k in ('XAUUSD.DWX', 'XAGUSD.DWX')}
envelope = R * ((XAU['mae_acct'] - comm['XAUUSD.DWX'] * XAU['notional'])
                + (XAG['mae_acct'] - comm['XAGUSD.DWX'] * XAG['notional']))
c = cases
checks = {
    'monetary_scaling_whole_equals_split_full': c['A_whole_host_XAU_xau_row_first']['net_scaled_total'] == c['D_split_full_risk_legs']['net_scaled_total'],
    'split_half_is_half_of_whole': abs(c['E_split_half_risk_legs']['net_scaled_total'] * 2 - c['A_whole_host_XAU_xau_row_first']['net_scaled_total']) < 1e-5,  # 6-dp rounding
    'commission_host_substitution_null_current_registry': c['A_whole_host_XAU_xau_row_first']['commission_scaled_total'] == c['C_whole_host_XAG_xau_row_first']['commission_scaled_total'] == c['D_split_full_risk_legs']['commission_scaled_total'],
    'uniform_stress_host_substitution_null': (c['U_whole_uniform_stress']['spread_stress_scaled_total'], c['U_whole_uniform_stress']['slippage_stress_scaled_total']) == (c['V_split_full_uniform_stress']['spread_stress_scaled_total'], c['V_split_full_uniform_stress']['slippage_stress_scaled_total']),
    'per_symbol_stress_host_substitution_differs': (c['P_whole_per_symbol_stress']['spread_stress_scaled_total'], c['P_whole_per_symbol_stress']['slippage_stress_scaled_total']) != (c['Q_split_full_per_symbol_stress']['spread_stress_scaled_total'], c['Q_split_full_per_symbol_stress']['slippage_stress_scaled_total']),
    'whole_basket_daily_low_is_row_order_dependent': c['A_whole_host_XAU_xau_row_first']['account_path_worst_daily_low'] != c['B_whole_host_XAU_xag_row_first']['account_path_worst_daily_low'],
    'whole_basket_daily_low_above_leg_envelope': c['A_whole_host_XAU_xau_row_first']['account_path_worst_daily_low'] > round(envelope, 6),
    'split_full_daily_low_equals_leg_envelope': abs(c['D_split_full_risk_legs']['account_path_worst_daily_low'] - envelope) < 1e-6,
    'fp_grid_matches_account_path_low_A': abs(c['A_whole_host_XAU_xau_row_first']['first_passage_grid_worst_low'] - c['A_whole_host_XAU_xau_row_first']['account_path_worst_daily_low']) < 1e-6,
    'fp_grid_matches_account_path_low_D': abs(c['D_split_full_risk_legs']['first_passage_grid_worst_low'] - c['D_split_full_risk_legs']['account_path_worst_daily_low']) < 1e-6,
    'split_full_book_risk_metadata_double': abs(c['D_split_full_risk_legs']['concentration']['book_risk_percent'] - 2 * R) < 1e-9,
    'whole_basket_concentration_all_on_host': list(c['A_whole_host_XAU_xau_row_first']['concentration']['risk_by_symbol_percent']) == ['XAUUSD.DWX'],
}
# Work-item rows label the basket with a logical symbol, not a DWX leg symbol.
LOGICAL = book._normalize_symbol('QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1')
logical_class = REGISTRY.get('symbol_class', {}).get(LOGICAL, REGISTRY.get('default_class'))
flat_row = dict(XAG, volume=1.0, notional=10000.0)
checks['logical_basket_label_falls_to_default_class'] = logical_class == REGISTRY.get('default_class') != REGISTRY['symbol_class']['XAGUSD.DWX']
checks['logical_label_commission_differs_from_leg'] = (
    book._commission_for_trade(flat_row, LOGICAL, REGISTRY)[0]
    != book._commission_for_trade(flat_row, 'XAGUSD.DWX', REGISTRY)[0])
logical_label = {'normalized': LOGICAL, 'class': logical_class,
                 'commission_logical': book._commission_for_trade(flat_row, LOGICAL, REGISTRY)[0],
                 'commission_leg': book._commission_for_trade(flat_row, 'XAGUSD.DWX', REGISTRY)[0],
                 'row': {'volume': 1.0, 'notional': 10000.0}}
result = {
    'logical_label_commission_case': logical_label,
    'task_id': '55eaa2ee-0380-4799-9141-5639a0f6548a',
    'scope': 'Synthetic one-basket fixture through actual book_sim/first_passage consumers; not book, execution or economic evidence.',
    'fixture': {'xau_leg': XAU, 'xag_leg': XAG, 'basket_target_risk_percent': R,
                'source_risk_percent': book.SOURCE_RISK_PERCENT},
    'per_leg_conservative_envelope_scaled': round(envelope, 6),
    'cases': cases,
    'checks': checks,
    'all_checks_true': all(checks.values()),
    'bound_sources_sha256': {p: hashlib.sha256((REPO / p).read_bytes()).hexdigest() for p in (
        'tools/strategy_farm/ftmo/book_sim.py', 'tools/strategy_farm/ftmo/first_passage.py',
        'framework/registry/live_commission.json')},
}
OUT.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n', encoding='utf-8')
print(json.dumps({'checks': checks, 'all': result['all_checks_true'],
                  'envelope': result['per_leg_conservative_envelope_scaled'],
                  'lows': {k: (v['account_path_worst_daily_low'], v['first_passage_grid_worst_low'], v['net_scaled_total']) for k, v in cases.items()}}, indent=1))
