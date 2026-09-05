import copy
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_public_live_performance as live


def deal(id, pos, entry, at, magic, profit='0', commission='0', volume='1'):
    return {'deal_id':str(id),'position_id':str(pos),'entry':entry,'time_utc':at,
            'logical_magic':'','deal_magic':str(magic),'magic':str(magic),'type':'BUY',
            'profit':profit,'commission':commission,'swap':'0','fee':'0',
            'volume':volume,'net_actual':str(live.Decimal(profit)+live.Decimal(commission))}


def rows():
    return [deal(1,11,'IN','2026-07-24T10:00:00Z',42,commission='-2'),
            deal(2,11,'OUT','2026-07-24T23:00:00Z',0,profit='100',commission='-2'),
            deal(3,12,'IN','2026-07-24T10:00:00Z',0),
            deal(4,12,'OUT','2026-07-25T11:00:00Z',0,profit='900')]


def test_position_key_zero_close_attribution_prague_costs_and_zero_days():
    value=live.build(rows(),{42})
    assert value['series']==[['2026-07-24',0.0,0.0,100.0,0],['2026-07-25',96.0,96.0,100.096,1]]
    assert value['totals']['net_pnl']==96
    assert value['totals']['active_days']==1
    assert value['totals']['last_deal_utc']=='2026-07-24T23:00:00Z'
    encoded=json.dumps(value)
    for forbidden in ['magic','position_id','deal_id','symbol','sleeve','C:/','D:/','T_Live','account_id']:
        assert forbidden not in encoded


def test_partial_close_waits_and_complete_position_counted_once():
    data=rows()+[deal(5,13,'IN','2026-07-24T10:00:00Z',42),deal(6,13,'OUT','2026-07-25T11:00:00Z',42,profit='10',volume='.4')]
    assert live.build(data,{42})['totals']['closes']==1
    data.append(deal(7,13,'OUT','2026-07-25T12:00:00Z',42,profit='20',volume='.6'))
    assert live.build(data,{42})['totals']['closes']==2
    assert live.build(data,{42})['totals']['net_pnl']==126


@pytest.mark.parametrize('field,value',[('account_id','private'),('magic',42),('source_path','private'),('sleeves',[])])
def test_additional_fields_rejected(field,value):
    data=live.build(rows(),{42});data[field]=value
    with pytest.raises(ValueError,match='whitelist'):live.validate(data)


@pytest.mark.parametrize('mutation',['duplicate','missing_entry','nan','reverse','overclose','bad_net'])
def test_incomplete_or_invalid_export_fails_closed(mutation):
    data=copy.deepcopy(rows())
    if mutation=='duplicate':data.append(data[0])
    if mutation=='missing_entry':data.pop(0)
    if mutation=='nan':data[0]['net_actual']='NaN'
    if mutation=='reverse':data[1]['entry']='INOUT'
    if mutation=='overclose':data[1]['volume']='2'
    if mutation=='bad_net':data[1]['net_actual']='999'
    with pytest.raises(ValueError):live.build(data,{42})


def test_prague_winter_clock_and_zero_net_active_close():
    data=[deal(1,1,'IN','2026-12-01T10:00:00Z',42),deal(2,1,'OUT','2026-12-01T23:30:00Z',42)]
    result=live.build(data,{42})
    assert result['series'][-1][0]=='2026-12-02'
    assert result['totals']['active_days']==1
    assert result['totals']['net_pnl']==0
