"""Profile canonical dry-run sweep, with SQLite writes mechanically refused."""
from pathlib import Path
import cProfile
import io
import os
import pstats
import runpy
import sqlite3
import sys
import time
import json

OUT=Path(__file__).resolve().parent
reports=OUT/'dry_run_report';(reports/'state').mkdir(parents=True,exist_ok=True)
os.environ['QM_REPORT_ROOT']=str(reports)
os.environ['QM_CANONICAL_REPO_ROOT']='C:/QM/repo'
os.environ['QM_STRATEGY_FARM_ROOT']='D:/QM/strategy_farm'
sys.argv=['C:/QM/repo/tools/strategy_farm/sweep_enqueue_built_eas.py']
sys.path[:0]=['C:/QM/repo/tools/strategy_farm','C:/QM/repo']
original_connect=sqlite3.connect
queries={}


class TimedCursor(sqlite3.Cursor):
    def execute(self, sql, parameters=()):
        started=time.perf_counter()
        try:return super().execute(sql,parameters)
        finally:
            row=queries.setdefault(sql,{'sql':sql,'count':0,'seconds':0.0,'example_parameters':list(parameters)})
            row['count']+=1;row['seconds']+=time.perf_counter()-started


class TimedConnection(sqlite3.Connection):
    def cursor(self, *args, **kwargs):
        kwargs.setdefault('factory',TimedCursor)
        return super().cursor(*args,**kwargs)


def readonly_connect(database,*args,**kwargs):
    kwargs.setdefault('factory',TimedConnection)
    if str(database)==':memory:':return original_connect(database,*args,**kwargs)
    target=str(database)
    if not target.startswith('file:'):
        target='file:'+Path(target).as_posix()+'?mode=ro';kwargs['uri']=True
    conn=original_connect(target,*args,**kwargs);conn.execute('PRAGMA query_only=ON');return conn


sqlite3.connect=readonly_connect
profile=cProfile.Profile()
try:profile.runcall(runpy.run_path,sys.argv[0],run_name='__main__')
finally:
    stream=io.StringIO();pstats.Stats(profile,stream=stream).strip_dirs().sort_stats('cumulative').print_stats(50)
    (OUT/'sweep_profile.txt').write_text(stream.getvalue(),encoding='utf-8')
    (OUT/'sweep_queries.json').write_text(json.dumps(sorted(queries.values(),key=lambda x:x['seconds'],reverse=True),indent=2)+'\n',encoding='utf-8')
    print(stream.getvalue())
