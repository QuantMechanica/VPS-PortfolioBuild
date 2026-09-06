"""Check public prose against the archive whitelist. Usage: python check_prose.py <json file with a list of {public_id,name,tagline}>
Prints one line per failing field (public_id | field | reasons | text) and a summary; exit 1 if any failure."""
import json, re, sys
sys.path.insert(0, 'C:/QM/repo/tools/strategy_farm')
import website_archive_v3 as v3, website_archive_contract as legacy
items = json.load(open(sys.argv[1], encoding='utf-8'))
items = items.get('names', items) if isinstance(items, dict) else items
bad = 0
for e in items:
    for field in ('name', 'tagline'):
        v = e.get(field) or ''
        why = []
        if v3.PRIVATE.search(v): why.append('PRIVATE(' + v3.PRIVATE.search(v).group(0) + ')')
        if re.search(r'\d', v): why.append('DIGIT')
        m = v3.NUMBER_WORDS.search(v)
        if m: why.append('NUMBER_WORD(' + m.group(0) + ')')
        if legacy.scrub_text(v) != v: why.append('SCRUB')
        if field == 'tagline' and len(v.split()) > 16: why.append('OVER_16_WORDS')
        if why:
            bad += 1; print(e.get('public_id'), '|', field, '|', ','.join(why), '|', v)
print('FAILURES', bad, 'of', len(items) * 2, 'fields')
sys.exit(1 if bad else 0)
