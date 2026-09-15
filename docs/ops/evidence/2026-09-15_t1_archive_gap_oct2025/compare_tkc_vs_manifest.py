#!/usr/bin/env python3
"""Q1/Q2: compare on-disk .tkc files (T1/T2/T5, 202510+202511) against the
signed archive manifest. READ-ONLY. No file mutated, no terminal started.

Manifest source_custom == D:\\QM\\mt5\\T1\\Bases\\Custom, so the manifest hashes
were built FROM T1's archive on 2026-08-09.

Classification per (terminal, symbol, month):
  INTACT       - file present AND size==manifest.size AND sha256==manifest.sha256
  HOLE         - file present but size/sha differs from manifest, OR file missing
                 while manifest expects it (an on-disk deviation from signed state)
  UNVERIFIABLE - manifest has no entry for this symbol/month (cannot judge)
"""
import hashlib
import json
import os
import sys
import csv

MANIFEST = r'D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\archive_manifest_owner_approved.json'
TERMINALS = ['T1', 'T2', 'T5']
MONTHS = ['202510', '202511']
OUT_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'q1q2_tkc_vs_manifest.csv')


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    d = json.load(open(MANIFEST))
    # index manifest: relative_path -> {size, sha256}
    man = {}
    tick_syms = set()
    for f in d['files']:
        rp = f['relative_path']
        man[rp] = {'size': f['size'], 'sha256': f['sha256']}
        if rp.startswith('ticks/'):
            tick_syms.add(rp.split('/')[1])

    rows = []
    for term in TERMINALS:
        ticks_dir = rf'D:\QM\mt5\{term}\bases\Custom\ticks'
        # all symbol dirs present on disk for this terminal
        try:
            on_disk_syms = sorted(x for x in os.listdir(ticks_dir) if x.endswith('.DWX'))
        except FileNotFoundError:
            on_disk_syms = []
        all_syms = sorted(set(on_disk_syms) | tick_syms)
        for sym in all_syms:
            for mon in MONTHS:
                rp = f'ticks/{sym}/{mon}.tkc'
                fp = os.path.join(ticks_dir, sym, f'{mon}.tkc')
                present = os.path.isfile(fp)
                disk_size = os.path.getsize(fp) if present else None
                disk_sha = sha256_file(fp) if present else None
                m = man.get(rp)
                if m is None:
                    cls = 'UNVERIFIABLE'
                    note = 'manifest has no entry for this symbol/month'
                    exp_size = exp_sha = ''
                else:
                    exp_size = m['size']
                    exp_sha = m['sha256']
                    if not present:
                        cls = 'HOLE'
                        note = 'manifest expects file but it is MISSING on disk'
                    elif disk_size == m['size'] and disk_sha == m['sha256']:
                        cls = 'INTACT'
                        note = 'size+sha256 match signed manifest'
                    else:
                        cls = 'HOLE'
                        note = f'deviation size {disk_size} vs {m["size"]}, sha {"match" if disk_sha==m["sha256"] else "MISMATCH"}'
                rows.append({
                    'terminal': term, 'symbol': sym, 'month': mon,
                    'present': present,
                    'disk_size': disk_size if disk_size is not None else '',
                    'manifest_size': exp_size,
                    'disk_sha256': disk_sha or '',
                    'manifest_sha256': exp_sha,
                    'classification': cls, 'note': note,
                })

    with open(OUT_CSV, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    # summary to stdout
    from collections import Counter
    for term in TERMINALS:
        c = Counter(r['classification'] for r in rows if r['terminal'] == term)
        print(term, dict(c))
    print('wrote', OUT_CSV, 'rows', len(rows))


if __name__ == '__main__':
    main()
