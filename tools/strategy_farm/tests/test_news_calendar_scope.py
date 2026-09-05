from copy import deepcopy
import json
import pytest
from tools.strategy_farm.news_calendar_scope import declare_scope


def gates():
    return {
        '6.1_anchor_shares':{'pass':False,'failed_groups':[{'class':'CPI m/m','year':2025,'source':'primary'}],'native_name_error':'NATIVE_TARGET_NAMES_MISSING: Core PPI m/m'},
        '6.2_coverage':{'pass':False,'fresh_currencies_with_confirmed_official_anchor':[],
                       'fresh_exports':{c:{'present':False,'rows':0,'errors':[],'monthly_rows':{}} for c in ['USD','EUR','GBP','JPY','AUD','CAD']},
                       'unexplained_zero_months':{'primary':['2026-01'],'secondary':[]}},
        '6.3_cross_file_identity':{'pass':True},'6.4_nonusd_completeness':{'pass':True},
        '6.5_tick_footprints':{'pass':False},'6.6_no_row_loss':{'pass':True},
        '6.7_detector_clean':{'pass':False,'input_changes':[]},'6.8_schema':{'pass':True}}


def test_every_failed_basis_gets_bounded_declarations_without_a_pass(tmp_path):
    actual=gates(); original=deepcopy(actual)
    records=declare_scope(actual,[{'currency':'USD','event':'CPI m/m','month':'2025-02','reason':'UNANCHORED'}],
        [{'currency':'AUD','event_code':'rba-interest-rate-decision','utc':'2025-02-18T03:30Z','status':'MISSING_M5'}],[],[],tmp_path)
    assert {k:v['pass'] for k,v in actual.items()}=={k:v['pass'] for k,v in original.items()}
    assert all(v['scope_status'] in ['MEASURED_PASS','COVERED_BY_DECLARATION'] for v in actual.values())
    assert all(r['currency'] and r['event_class'] and r['months'] and not r['production_use_permitted'] for r in records)
    assert len({r['id'] for r in records})==len(records)
    assert all(len(m)==7 for r in records for m in r['months'])


def test_input_mutation_cannot_be_scoped_away(tmp_path):
    actual=gates();actual['6.7_detector_clean']['input_changes']=['source.csv']
    declare_scope(actual,[],[],[],[],tmp_path)
    assert actual['6.7_detector_clean']['scope_status']=='UNRESOLVED_INPUT_MUTATION'
    assert not actual['6.7_detector_clean']['pass']


def test_undated_footprint_cannot_silently_be_declared(tmp_path):
    with pytest.raises(ValueError,match='bounds'):
        declare_scope(gates(),[],[{'currency':'AUD','event_code':'rate','status':'MISSING_OFFICIAL_INSTANT'}],[],[],tmp_path)
