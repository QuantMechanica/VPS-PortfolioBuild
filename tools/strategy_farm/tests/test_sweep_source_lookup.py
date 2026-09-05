from pathlib import Path
import ast
import sqlite3


def lookup_sql():
    path=Path(__file__).resolve().parents[1]/'sweep_enqueue_built_eas.py'
    tree=ast.parse(path.read_text())
    return next(n.value for n in ast.walk(tree) if isinstance(n,ast.Constant) and isinstance(n.value,str)
                and 'SELECT id,status,payload_json,updated_at' in n.value and 'INDEXED BY' in n.value)


def test_latest_source_lookup_preserves_null_empty_ties_and_filters():
    c=sqlite3.connect(':memory:')
    c.execute('CREATE TABLE work_items(id TEXT,ea_id TEXT,phase TEXT,symbol TEXT,setfile_path TEXT,status TEXT,verdict TEXT,payload_json TEXT,updated_at TEXT)')
    c.execute('CREATE INDEX idx_work_items_ea_phase ON work_items(ea_id,phase)')
    c.execute('CREATE INDEX idx_work_items_verdict_updated ON work_items(verdict,updated_at)')
    values=[
        ('a','EA','Q04','USD',None,'done','INFRA_FAIL','{}','2026-01-01'),
        ('b','EA','Q04','USD','','failed','INFRA_FAIL','{"winner":1}','2026-01-01'),
        ('c','EA','Q04','USD','','active','INFRA_FAIL','{}','2026-02-01'),
        ('d','EA','Q04','USD','','done','PASS','{}','2026-03-01'),
        ('e','EA','Q03','USD','','done','INFRA_FAIL','{}','2026-04-01'),
        ('f','OTHER','Q04','USD','','done','INFRA_FAIL','{}','2026-05-01'),
    ]
    c.executemany('INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?)',values)
    new=lookup_sql();old=new.replace(' INDEXED BY idx_work_items_ea_phase','')
    for setfile in (None,'','present.set'):
        args=('EA','Q04','USD',setfile)
        assert c.execute(new,args).fetchall()==c.execute(old,args).fetchall()
    assert c.execute(new,('EA','Q04','USD',None)).fetchone()[0]=='b'
