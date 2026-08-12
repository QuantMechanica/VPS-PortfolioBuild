import csv, json, collections

REG = r"C:/QM/repo/framework/registry/magic_numbers.csv"

# my live magics + candidate ea_ids
live_magics = [15560004,104400003,109110003,111320000,114210000,125670002,129690000,131280000]
cand_ea_ids = [1567,10145,10692,10815,12474]
cand_symbols = {1567:"XAGUSD",10145:"XAUUSD",10692:"NDX",10815:"EURUSD",12474:"GBPUSD"}

rows = []
with open(REG, encoding="utf-8") as f:
    reader = csv.reader(f)
    header = next(reader)  # line 1
    lineno = 1
    for r in reader:
        lineno += 1
        rows.append((lineno, r))

# header: ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status
# duplicate magic scan across whole registry
magic_to_lines = collections.defaultdict(list)
for lineno, r in rows:
    if len(r) >= 5:
        magic_to_lines[r[4]].append(lineno)
dups = {m: ls for m, ls in magic_to_lines.items() if len(ls) > 1}

out = {"header": header, "live_magic_rows": {}, "candidate_ea_rows": {}, "duplicate_magics_count": len(dups), "my_magic_collisions": {}}

for m in live_magics:
    hits = [(lineno, r) for lineno, r in rows if len(r) >= 5 and r[4] == str(m)]
    out["live_magic_rows"][m] = [{"line": ln, "row": r} for ln, r in hits]
    out["my_magic_collisions"][m] = dups.get(str(m), "no-collision")

for eid in cand_ea_ids:
    hits = [(lineno, r) for lineno, r in rows if len(r) >= 1 and r[0] == str(eid)]
    out["candidate_ea_rows"][eid] = [{"line": ln, "row": r} for ln, r in hits]

# also record dup examples (first 20)
out["duplicate_magics_sample"] = {m: ls for i,(m,ls) in enumerate(dups.items()) if i < 20}

print(json.dumps(out, indent=1))
