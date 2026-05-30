# -*- coding: utf-8 -*-
import sqlite3
import shutil
import os
from pathlib import Path

db_path = r'D:\QM\strategy_farm\state\farm_state.sqlite'
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

cursor.execute("SELECT id, artifact_path FROM agent_tasks WHERE verdict LIKE '%Auto-generated structural MQL5 skeleton%'")
rows = cursor.fetchall()

deleted_dirs = 0
deleted_tasks = 0

for task_id, artifact_path in rows:
    if artifact_path:
        art_path = Path(artifact_path)
        parent_dir = art_path.parent
        if parent_dir.exists() and parent_dir.name.startswith('QM5_'):
            try:
                shutil.rmtree(parent_dir)
                deleted_dirs += 1
            except Exception as e:
                pass
    
    cursor.execute("DELETE FROM agent_tasks WHERE id = ?", (task_id,))
    deleted_tasks += 1

conn.commit()
conn.close()

print(f"Rollback complete: {deleted_dirs} dirs and {deleted_tasks} tasks removed.")
