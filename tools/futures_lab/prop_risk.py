"""Offline drawdown-path diagnostic, not a certified prop-firm rule implementation.

Inputs are NET account balance and marked-to-market equity in USD at each event.
Supply every relevant equity extreme and provider session close. Daily-only input
cannot establish intraday survival. Rules must be bound to a dated contract before
using output to select a paid evaluation. This module never submits orders.
"""
from __future__ import annotations

import argparse
import csv
import json
from dataclasses import asdict, dataclass
from datetime import datetime
from decimal import Decimal, ROUND_FLOOR
from pathlib import Path


def money(value) -> Decimal:
    result = Decimal(str(value))
    if not result.is_finite():
        raise ValueError('Money must be finite')
    return result


@dataclass(frozen=True)
class Rules:
    starting_balance: Decimal = Decimal('50000')
    drawdown: Decimal = Decimal('2000')
    trailing_mode: str = 'eod_balance'
    floor_cap: Decimal = Decimal('50000')
    profit_target: Decimal = Decimal('3000')
    minimum_trading_days: int = 4
    best_day_fraction: Decimal | None = Decimal('0.30')
    label: str = 'UNBOUND_DEMONSTRATION_NOT_A_PROVIDER_PRESET'

    def __post_init__(self):
        for name in ('starting_balance','drawdown','floor_cap','profit_target'):
            object.__setattr__(self,name,money(getattr(self,name)))
        if self.best_day_fraction is not None:
            object.__setattr__(self,'best_day_fraction',money(self.best_day_fraction))
        if self.starting_balance <= 0 or self.drawdown <= 0 or self.profit_target <= 0:
            raise ValueError('Balances, drawdown and target must be positive')
        if self.floor_cap < self.starting_balance-self.drawdown:
            raise ValueError('Cap below initial floor')
        if self.trailing_mode not in ('eod_balance','intraday_equity'):
            raise ValueError('Unknown trailing mode')
        if type(self.minimum_trading_days) is not int or self.minimum_trading_days < 1:
            raise ValueError('minimum_trading_days must be a positive integer')
        if self.best_day_fraction is not None and not 0 < self.best_day_fraction <= 1:
            raise ValueError('Invalid consistency fraction')


@dataclass(frozen=True)
class Point:
    timestamp: str
    session: str
    balance: Decimal
    equity: Decimal
    end_of_session: bool = False
    traded: bool = False
    flat: bool = True

    def __post_init__(self):
        for name in ('end_of_session','traded','flat'):
            if type(getattr(self,name)) is not bool:
                raise ValueError(f'{name} must be a boolean, not a truthy value')


def evaluate(points: list[Point], rules: Rules) -> dict:
    if not points:
        raise ValueError('Empty equity path')
    floor = rules.starting_balance-rules.drawdown
    watermark = rules.starting_balance
    previous_time = None
    active_session = None
    session_closed = False
    seen_sessions = set()
    session_start_balance = rules.starting_balance
    session_traded = False
    daily = []
    trace = []
    passed_at = None
    breach = None
    for i, point in enumerate(points):
        timestamp = datetime.fromisoformat(point.timestamp.replace('Z','+00:00'))
        if timestamp.tzinfo is None or timestamp.utcoffset() is None:
            raise ValueError('Timestamps require an explicit UTC offset')
        if previous_time is not None and timestamp <= previous_time:
            raise ValueError('Equity points must have strictly increasing timestamps')
        if not point.session:
            raise ValueError('Provider session label required')
        if point.session != active_session:
            if active_session is not None and not session_closed:
                raise ValueError('Missing prior session close; refusing an inferred EOD trail')
            if point.session in seen_sessions:
                raise ValueError('Session labels must not repeat')
            seen_sessions.add(point.session)
            active_session = point.session
            session_closed = False
            session_traded = False
        elif session_closed:
            raise ValueError('Data follows a declared session close')
        balance, equity = money(point.balance), money(point.equity)
        if point.flat and balance != equity:
            raise ValueError('Flat equity must equal net balance')
        if point.end_of_session and not point.flat:
            raise ValueError('This bounded intraday model requires a flat session close')
        previous_time = timestamp
        session_traded = session_traded or point.traded
        if rules.trailing_mode == 'intraday_equity':
            watermark = max(watermark,equity)
            floor = max(floor,min(watermark-rules.drawdown,rules.floor_cap))
        # Equality is conservatively a breach. Never hide a hit behind a later recovery.
        if equity <= floor and breach is None:
            breach = {'index':i,'timestamp':point.timestamp,'equity':str(equity),'floor':str(floor)}
        if point.end_of_session:
            pnl = balance-session_start_balance
            daily.append({'session':point.session,'pnl':str(pnl),'traded':session_traded})
            session_start_balance = balance
            session_closed = True
            if rules.trailing_mode == 'eod_balance':
                watermark = max(watermark,balance)
                floor = max(floor,min(watermark-rules.drawdown,rules.floor_cap))
            net_profit = balance-rules.starting_balance
            best = max(Decimal(0),*(money(d['pnl']) for d in daily))
            consistency_ok = rules.best_day_fraction is None or (net_profit > 0 and best <= net_profit*rules.best_day_fraction)
            trading_days = sum(d['traded'] for d in daily)
            if passed_at is None and breach is None and net_profit >= rules.profit_target and trading_days >= rules.minimum_trading_days and consistency_ok:
                passed_at = point.timestamp
        trace.append({'timestamp':point.timestamp,'session':point.session,'balance':str(balance),
                      'equity':str(equity),'floor':str(floor),'room':str(equity-floor)})
    if not session_closed:
        raise ValueError('Final session is incomplete')
    return {'rules':asdict(rules),'sampled_path_survived':breach is None,
            'breach':breach,'first_evaluation_conditions_met_at':passed_at,
            'evaluation_status':'FAILED' if breach else ('CONDITIONS_MET' if passed_at else 'TARGET_OR_DAYS_OR_CONSISTENCY_UNMET'),
            'daily':daily,'trace':trace,
            'limitation':'Sampled NET equity diagnostic only. Missing intraday marks, fills, provider limits, news/holding rules, fees or payout policies invalidate any funding conclusion.'}


def contracts_for_risk(risk_usd, stop_ticks: int, tick_value, round_trip_fee, adverse_ticks: int = 0) -> int:
    if type(stop_ticks) is not int or stop_ticks <= 0 or type(adverse_ticks) is not int or adverse_ticks < 0:
        raise ValueError('Tick counts must be nonnegative integers and stop must be positive')
    risk,tick,fee=map(money,(risk_usd,tick_value,round_trip_fee))
    if risk < 0 or tick <= 0 or fee < 0:
        raise ValueError('Invalid risk, tick value or fee')
    return int((risk/((stop_ticks+adverse_ticks)*tick+fee)).to_integral_value(rounding=ROUND_FLOOR))


def payout_diagnostic(balance, floor, requested_account_debit, trader_share, fees_paid, minimum_room_after) -> dict:
    balance,floor,debit,share,fees,room=map(money,(balance,floor,requested_account_debit,trader_share,fees_paid,minimum_room_after))
    if debit <= 0 or not 0 < share <= 1 or fees < 0 or room < 0:
        raise ValueError('Invalid payout inputs')
    remaining=balance-debit-floor
    return {'account_debit':str(debit),'cash_to_trader_before_tax':str(debit*share),
            'net_cash_after_entered_fees_before_tax':str(debit*share-fees),
            'room_after_payout':str(remaining),
            'survives_unchanged_floor_and_requested_buffer':remaining>0 and remaining>=room,
            'provider_payout_eligibility':'NOT_EVALUATED',
            'note':'Gross account debit convention is explicit; bind exact firm policy separately. Floor never falls merely because money is withdrawn.'}


def read_points(path: Path) -> list[Point]:
    def boolean(value):
        if value not in ('true','false'):
            raise ValueError('Boolean CSV fields must be true or false')
        return value=='true'
    with path.open(encoding='utf-8-sig',newline='') as handle:
        return [Point(r['timestamp'],r['session'],money(r['balance']),money(r['equity']),
                      boolean(r['end_of_session']),boolean(r['traded']),boolean(r['flat'])) for r in csv.DictReader(handle)]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--equity-csv',type=Path,required=True)
    parser.add_argument('--rules-json',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    result=evaluate(read_points(args.equity_csv),Rules(**json.loads(args.rules_json.read_text(encoding='utf-8'))))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,default=str)+'\n',encoding='utf-8')
    print(result['evaluation_status'])


if __name__=='__main__':
    main()
