import json
from tools.strategy_farm.tests.test_ftmo_q09_admission import _database, _locked
from tools.strategy_farm.portfolio import ftmo_q09_admission as a
from tools.strategy_farm import q09_news_contract as c

def convert(conn,path,**updates):
    p=path/'aggregate.json';doc=json.loads(p.read_text());doc.pop('adjudication_sha256')
    doc.update(schema_version=c.ADJUDICATION_SCHEMA_VERSION_V3,seed_provenance={'executed_seed_set':[17],'selector_seed_set':list(c.SEEDS),'inert_seed_fanout':True})
    doc.update(updates);doc['adjudication_sha256']=c.sha256_bytes(c.canonical_json_bytes(doc));p.write_bytes(c.canonical_json_bytes(doc))
    conn.execute('update q09_news_tests set aggregate_sha256=?',(c.sha256_file(p),))
    conn.execute('delete from q09_news_cells where seed!=17');conn.commit()

def test_v3_single_native_seed_is_equivalent_to_v2_inert_selector(tmp_path):
    conn=_database(tmp_path);_locked(conn,tmp_path,target='FTMO',scope='7x1_target_compliance')
    before=a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX');convert(conn,tmp_path)
    after=a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX')
    assert before['admitted'] and after['admitted']
    assert a.deployment_news_inputs(before)==a.deployment_news_inputs(after)
    assert conn.execute('select count(*) from q09_news_cells').fetchone()[0]==1

def test_v3_expanded_ftmo_coverage_uses_real_native_seed(tmp_path):
    conn=_database(tmp_path);_locked(conn,tmp_path,target='DXZ',scope='7x4');convert(conn,tmp_path)
    assert a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX')['admitted']
    conn.execute("delete from q09_news_cells where temporal_mode='SKIP_DAY'")
    assert a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX')['reason_code']==a.FTMO_CELLS_INCOMPLETE

def test_v3_dxz_single_column_stays_ineligible(tmp_path):
    conn=_database(tmp_path);_locked(conn,tmp_path,target='DXZ',scope='7x1_target_compliance');convert(conn,tmp_path)
    assert a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX')['reason_code']==a.SCOPE_NOT_FTMO

def test_v3_false_seed_provenance_and_unknown_schema_fail(tmp_path):
    conn=_database(tmp_path);_locked(conn,tmp_path,target='FTMO',scope='7x1_target_compliance')
    convert(conn,tmp_path,seed_provenance={'executed_seed_set':list(c.SEEDS),'inert_seed_fanout':True})
    assert a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX')['reason_code']==a.EVIDENCE_UNAUTHENTICATED
    convert(conn,tmp_path,schema_version='q09-news-adjudication/v99')
    assert a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX')['reason_code']==a.EVIDENCE_UNAUTHENTICATED

def test_v3_tampered_aggregate_cannot_be_reused(tmp_path):
    conn=_database(tmp_path);_locked(conn,tmp_path,target='FTMO',scope='7x1_target_compliance');convert(conn,tmp_path)
    p=tmp_path/'aggregate.json';p.write_bytes(p.read_bytes()+b' ')
    assert a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX')['reason_code']==a.EVIDENCE_UNAUTHENTICATED

def test_v2_does_not_inherit_single_seed_exception(tmp_path):
    conn=_database(tmp_path);_locked(conn,tmp_path,target='FTMO',scope='7x1_target_compliance')
    conn.execute('delete from q09_news_cells where seed!=17')
    assert not a.evaluate_ftmo_q09_admission(conn,42,'EURUSD.DWX')['admitted']
