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
import re
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from decimal import Decimal, ROUND_FLOOR
from pathlib import Path
from typing import Iterable


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
    replay_ordinal: int | None = None

    def __post_init__(self):
        for name in ('end_of_session','traded','flat'):
            if type(getattr(self,name)) is not bool:
                raise ValueError(f'{name} must be a boolean, not a truthy value')
        if self.replay_ordinal is not None and (type(self.replay_ordinal) is not int or self.replay_ordinal < 0):
            raise ValueError('replay_ordinal must be a nonnegative integer')


def timestamp_ns(value: str) -> int:
    """Parse exact ISO time; datetime alone silently truncates nanoseconds."""
    match = re.fullmatch(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})', value)
    if not match:
        raise ValueError('Timestamps require ISO seconds, up to nanoseconds and an explicit UTC offset')
    stamp = datetime.fromisoformat(match[1] + match[3].replace('Z', '+00:00'))
    delta = stamp.astimezone(timezone.utc) - datetime(1970, 1, 1, tzinfo=timezone.utc)
    return (delta.days * 86400 + delta.seconds) * 10**9 + int((match[2] or '').ljust(9, '0'))


def evaluate(points: Iterable[Point], rules: Rules, *, retain_trace: bool = True) -> dict:
    floor = rules.starting_balance-rules.drawdown
    watermark = rules.starting_balance
    previous_time = None
    previous_ordinal = None
    ordered_mode = None
    point_count = 0
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
        timestamp = timestamp_ns(point.timestamp)
        has_ordinal = point.replay_ordinal is not None
        if ordered_mode is None:
            ordered_mode = has_ordinal
        if ordered_mode != has_ordinal:
            raise ValueError('Every event must use the same explicit ordering mode')
        if previous_time is not None:
            if timestamp < previous_time or (timestamp == previous_time and not ordered_mode):
                raise ValueError('Equity time cannot decrease; equal times require explicit replay ordinals')
            if ordered_mode and point.replay_ordinal <= previous_ordinal:
                raise ValueError('Replay ordinals must strictly increase without dropping equal-time extrema')
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
        previous_ordinal = point.replay_ordinal
        point_count += 1
        session_traded = session_traded or point.traded
        if rules.trailing_mode == 'intraday_equity':
            watermark = max(watermark,equity)
            floor = max(floor,min(watermark-rules.drawdown,rules.floor_cap))
        # Equality is conservatively a breach. Never hide a hit behind a later recovery.
        if equity <= floor and breach is None:
            breach = {'index':i,'timestamp':point.timestamp,'replay_ordinal':point.replay_ordinal,'equity':str(equity),'floor':str(floor)}
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
        if retain_trace:
            trace.append({'timestamp':point.timestamp,'replay_ordinal':point.replay_ordinal,'session':point.session,'balance':str(balance),
                          'equity':str(equity),'floor':str(floor),'room':str(equity-floor)})
    if not point_count:
        raise ValueError('Empty equity path')
    if not session_closed:
        raise ValueError('Final session is incomplete')
    return {'rules':asdict(rules),'sampled_path_survived':breach is None,
            'breach':breach,'first_evaluation_conditions_met_at':passed_at,
            'evaluation_status':'FAILED' if breach else ('CONDITIONS_MET' if passed_at else 'TARGET_OR_DAYS_OR_CONSISTENCY_UNMET'),
            'daily':daily,'trace':trace,'point_count':point_count,'trace_retained':retain_trace,
            'ordering':'UTC_NS_AND_REPLAY_ORDINAL' if ordered_mode else 'STRICT_UTC_NS',
            'limitation':'Sampled NET equity diagnostic only. Missing intraday marks, fills, provider limits, news/holding rules, fees or payout policies invalidate any funding conclusion.'}


def contracts_for_risk(risk_usd, stop_ticks: int, tick_value, round_trip_fee, adverse_ticks: int = 0) -> int:
    if type(stop_ticks) is not int or stop_ticks <= 0 or type(adverse_ticks) is not int or adverse_ticks < 0:
        raise ValueError('Tick counts must be nonnegative integers and stop must be positive')
    risk,tick,fee=map(money,(risk_usd,tick_value,round_trip_fee))
    if risk < 0 or tick <= 0 or fee < 0:
        raise ValueError('Invalid risk, tick value or fee')
    return int((risk/((stop_ticks+adverse_ticks)*tick+fee)).to_integral_value(rounding=ROUND_FLOOR))


def payout_diagnostic(
    balance,
    floor,
    requested_account_debit,
    trader_share,
    fees_paid,
    minimum_room_after,
    post_payout_floor=None,
) -> dict:
    balance,floor,debit,share,fees,room=map(money,(balance,floor,requested_account_debit,trader_share,fees_paid,minimum_room_after))
    if debit <= 0 or not 0 < share <= 1 or fees < 0 or room < 0:
        raise ValueError('Invalid payout inputs')
    effective_floor=floor if post_payout_floor is None else money(post_payout_floor)
    if effective_floor < floor:
        raise ValueError('A payout rule cannot lower the already established loss floor')
    remaining=balance-debit-effective_floor
    survives=remaining > 0 and remaining >= room
    return {'account_debit':str(debit),'cash_to_trader_before_tax':str(debit*share),
            'net_cash_after_entered_fees_before_tax':str(debit*share-fees),
            'pre_payout_floor':str(floor),'post_payout_floor':str(effective_floor),
            'floor_changed_by_payout_rule':effective_floor != floor,
            'room_after_payout':str(remaining),
            'survives_effective_floor_and_requested_buffer':survives,
            'survives_unchanged_floor_and_requested_buffer':survives if effective_floor == floor else None,
            'provider_payout_eligibility':'NOT_EVALUATED',
            'note':'Gross account debit convention is explicit; bind exact firm policy separately. A payout may raise a floor when explicitly supplied, but it never lowers one.'}


def winning_day_diagnostic(daily_net_pnl, required_winning_days: int, minimum_day_profit) -> dict:
    if type(required_winning_days) is not int or required_winning_days < 1:
        raise ValueError('required_winning_days must be a positive integer')
    threshold=money(minimum_day_profit)
    if threshold <= 0:
        raise ValueError('minimum_day_profit must be positive')
    if isinstance(daily_net_pnl,(str,bytes)):
        raise ValueError('daily_net_pnl must be a session sequence, not text')
    values=[money(value) for value in daily_net_pnl]
    if not values:
        raise ValueError('At least one completed session is required')
    qualifying=[index for index,value in enumerate(values) if value >= threshold]
    return {'required_winning_days':required_winning_days,
            'minimum_day_profit':str(threshold),
            'observed_completed_sessions':len(values),
            'qualifying_session_indexes':qualifying,
            'qualifying_winning_days':len(qualifying),
            'remaining_winning_days':max(0,required_winning_days-len(qualifying)),
            'conditions_met':len(qualifying) >= required_winning_days,
            'provider_payout_eligibility':'NOT_EVALUATED',
            'note':'Counts only the supplied net session PnL. It does not evaluate other payout, conduct, news, inactivity, ownership or account-state rules.'}


def read_points(path: Path) -> Iterable[Point]:
    def boolean(value):
        if value not in ('true','false'):
            raise ValueError('Boolean CSV fields must be true or false')
        return value=='true'
    with path.open(encoding='utf-8-sig',newline='') as handle:
        for r in csv.DictReader(handle):
            raw_ordinal = r.get('replay_ordinal')
            if raw_ordinal not in (None,'') and not re.fullmatch(r'[0-9]+',raw_ordinal):
                raise ValueError('CSV replay_ordinal must be a nonnegative integer')
            yield Point(r['timestamp'],r['session'],money(r['balance']),money(r['equity']),
                        boolean(r['end_of_session']),boolean(r['traded']),boolean(r['flat']),
                        None if raw_ordinal in (None,'') else int(raw_ordinal))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--equity-csv',type=Path,required=True)
    parser.add_argument('--rules-json',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--summary-only',action='store_true',help='Stream marks without retaining the per-event trace')
    args=parser.parse_args()
    result=evaluate(read_points(args.equity_csv),Rules(**json.loads(args.rules_json.read_text(encoding='utf-8'))),retain_trace=not args.summary_only)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,default=str)+'\n',encoding='utf-8')
    print(result['evaluation_status'])


if __name__=='__main__':
    main()
