#!/usr/bin/env python3
"""F4: explicit, auditable cohort-membership matrix for ALL manifest tick symbols.

READ-ONLY. Reads only the signed archive manifest.

The prior write-up asserted "27 symbols = every FX pair" using an unstated
0.40 size-ratio threshold (202510 size / 202509 size). That silently exonerated
at least one FX pair sitting close to the threshold. This script emits, for
every tick symbol the manifest covers:

  symbol, is_fx_pair, 202509 size, 202510 size, 202511 size,
  ratio_1011_vs_09 (=202510/202509), ratio_11_vs_09 (=202511/202509),
  in_cohort_at_0_35, in_cohort_at_0_40, in_cohort_at_0_50,
  threshold_sensitive (membership differs across the three thresholds)

so no symbol is excluded by an unexamined threshold choice.

Output: f4_cohort_threshold_matrix.csv (same directory).
"""
import csv
import json
import os
from collections import defaultdict

MANIFEST = (r'D:\QM\strategy_farm\artifacts\ops'
            r'\custom_history_custom_history_variant_a_20260809'
            r'\archive_manifest_owner_approved.json')
OUT_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'f4_cohort_threshold_matrix.csv')
THRESHOLDS = (0.35, 0.40, 0.50)

# ISO-4217 majors used by the DWX universe; a symbol is an "FX pair" iff its
# base name is exactly two of these concatenated. Derived, not hand-listed.
CCY = {'AUD', 'CAD', 'CHF', 'EUR', 'GBP', 'JPY', 'NZD', 'USD', 'SEK', 'NOK',
       'SGD', 'HKD', 'MXN', 'PLN', 'TRY', 'ZAR', 'CNH', 'DKK', 'CZK', 'HUF'}


def is_fx_pair(symbol):
    base = symbol.split('.')[0]
    return len(base) == 6 and base[:3] in CCY and base[3:] in CCY


def monthly_sizes():
    with open(MANIFEST, 'r', encoding='utf-8') as fh:
        d = json.load(fh)
    sz = defaultdict(dict)
    for f in d['files']:
        rp = f['relative_path']
        if not rp.startswith('ticks/'):
            continue
        _, sym, mon = rp.split('/')
        sz[sym][mon.replace('.tkc', '')] = f['size']
    return sz


def main():
    sz = monthly_sizes()
    rows = []
    for sym in sorted(sz):
        m = sz[sym]
        s09 = m.get('202509')
        s10 = m.get('202510')
        s11 = m.get('202511')
        ratio10 = (s10 / s09) if (s09 and s10 is not None) else None
        ratio11 = (s11 / s09) if (s09 and s11 is not None) else None
        memb = {}
        for t in THRESHOLDS:
            memb[t] = (ratio10 is not None and ratio10 < t)
        rows.append({
            'symbol': sym,
            'is_fx_pair': is_fx_pair(sym),
            'size_202509': s09 if s09 is not None else '',
            'size_202510': s10 if s10 is not None else '',
            'size_202511': s11 if s11 is not None else '',
            'ratio_202510_vs_202509': round(ratio10, 4) if ratio10 is not None else '',
            'ratio_202511_vs_202509': round(ratio11, 4) if ratio11 is not None else '',
            'in_cohort_at_0_35': memb[0.35],
            'in_cohort_at_0_40': memb[0.40],
            'in_cohort_at_0_50': memb[0.50],
            'threshold_sensitive': len(set(memb.values())) > 1,
        })

    with open(OUT_CSV, 'w', newline='', encoding='utf-8') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    fx = [r for r in rows if r['is_fx_pair']]
    print('manifest tick symbols:', len(rows), ' FX pairs:', len(fx),
          ' non-FX:', len(rows) - len(fx))
    for t, key in ((0.35, 'in_cohort_at_0_35'),
                   (0.40, 'in_cohort_at_0_40'),
                   (0.50, 'in_cohort_at_0_50')):
        sel = [r['symbol'] for r in rows if r[key]]
        selfx = [r['symbol'] for r in fx if r[key]]
        print(f'threshold {t}: cohort={len(sel)} (FX pairs in cohort={len(selfx)})')
    flip = [r for r in rows if r['threshold_sensitive']]
    print('threshold-sensitive symbols:',
          [(r['symbol'], r['ratio_202510_vs_202509']) for r in flip])
    fx_out = [(r['symbol'], r['ratio_202510_vs_202509'])
              for r in fx if not r['in_cohort_at_0_50']]
    print('FX pairs NOT in cohort even at the loosest (0.50) threshold:', fx_out)
    print('wrote', OUT_CSV)


if __name__ == '__main__':
    main()
