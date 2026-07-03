"""
Wave-1 param-empty card recovery: inject strategy_params into 49+2 cards,
regenerate setfiles, prepare requeue list.
Task: 9485fdd2-f899-4e5a-b5e5-bd2830cc1724
"""
import re, os, json, datetime, sys

CARDS_ROOT = 'D:/QM/strategy_farm/artifacts/cards_approved'
EA_BASE = 'C:/QM/repo/framework/EAs'
DB_PATH = 'D:/QM/strategy_farm/state/farm_state.sqlite'
REQUEUE_EXCLUDED = 'D:/QM/strategy_farm/state/requeue_excluded_eas.txt'
EVIDENCE_OUT = 'D:/QM/strategy_farm/artifacts/ops/c2_wave1_execution_2026-07-03.json'

ALL_EA_IDS = [
    # Priority first
    'QM5_10307', 'QM5_1328',
    # Scan EAs
    'QM5_10025','QM5_10050','QM5_1060','QM5_10605','QM5_1088','QM5_1093','QM5_1094',
    'QM5_1095','QM5_1096','QM5_1097','QM5_1099','QM5_1101','QM5_1104','QM5_1118',
    'QM5_1119','QM5_1121','QM5_1132','QM5_1149','QM5_1195','QM5_1237','QM5_1359',
    'QM5_1371','QM5_1383','QM5_1385','QM5_1386','QM5_1387','QM5_1395','QM5_1400',
    'QM5_1406','QM5_1433','QM5_1434','QM5_1435','QM5_1440','QM5_1442','QM5_1443',
    'QM5_1448','QM5_1510','QM5_1517','QM5_1518','QM5_1548','QM5_1551','QM5_1554',
    'QM5_1568','QM5_1576','QM5_1703','QM5_1800','QM5_1804','QM5_2010','QM5_9122'
]


def extract_strategy_params(mq5_path):
    """Extract input group Strategy params from MQ5 file."""
    params = {}
    in_strategy_group = False
    with open(mq5_path, 'r', encoding='utf-8-sig', errors='replace') as f:
        for line in f:
            line = line.rstrip()
            m = re.match(r'^\s*input\s+group\s+"([^"]+)"', line)
            if m:
                in_strategy_group = (m.group(1) == 'Strategy')
                continue
            m = re.match(
                r'^\s*input\s+(?:[A-Za-z_][A-Za-z0-9_<>]*\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;]+);',
                line
            )
            if m and in_strategy_group:
                name = m.group(1).strip()
                value = re.sub(r'\s*//.*$', '', m.group(2).strip()).strip()
                params[name] = value
    return params


def card_has_parseable_params(card_path):
    """Check if card already has param table or YAML list gen_setfile.ps1 can parse."""
    with open(card_path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    if re.search(r'\|\s*param\s*\|\s*default\s*\|', content, re.IGNORECASE):
        return True
    if re.search(r'^\s*-\s*name:\s*[A-Za-z_][A-Za-z0-9_]*\s*$', content, re.MULTILINE):
        return True
    if re.search(r'PARAMETERS\b', content) and re.search(r'^\s*-\s*[A-Za-z_]\w+\s*=\s*\S', content, re.MULTILINE):
        return True
    return False


def card_has_params_section(card_path):
    """Detect existing ## Parameters section to avoid duplicate."""
    with open(card_path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    return bool(re.search(r'^##\s+Parameters', content, re.IGNORECASE | re.MULTILINE))


def add_params_table_to_card(card_path, params):
    """Append a ## Parameters section with markdown table to the card."""
    with open(card_path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    table_lines = [
        '',
        '## Parameters',
        '',
        '| param | default |',
        '|---|---|',
    ]
    for k, v in params.items():
        table_lines.append('| {} | {} |'.format(k, v))

    new_content = content.rstrip() + '\n' + '\n'.join(table_lines) + '\n'
    with open(card_path, 'w', encoding='utf-8') as f:
        f.write(new_content)


def build_ea_dir_map():
    ea_dir_map = {}
    for d in os.listdir(EA_BASE):
        if not d.startswith('QM5_'):
            continue
        parts = d.split('_', 2)
        if len(parts) >= 2:
            eid = parts[0] + '_' + parts[1]
            if eid not in ea_dir_map:
                ea_dir_map[eid] = []
            ea_dir_map[eid].append(d)
    return ea_dir_map


def load_excluded_eas():
    excluded = set()
    if os.path.exists(REQUEUE_EXCLUDED):
        with open(REQUEUE_EXCLUDED, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    excluded.add(line)
    return excluded


def run():
    ea_dir_map = build_ea_dir_map()
    excluded_eas = load_excluded_eas()
    print('Excluded EAs: {}'.format(len(excluded_eas)))

    results = {
        'task_id': '9485fdd2-f899-4e5a-b5e5-bd2830cc1724',
        'generated_at_utc': datetime.datetime.utcnow().isoformat(),
        'cards_updated': [],
        'cards_already_had_params': [],
        'no_strategy_params': [],
        'skipped_excluded': [],
        'errors': []
    }

    for eid in ALL_EA_IDS:
        dirs = ea_dir_map.get(eid, [])
        if not dirs:
            results['errors'].append({'ea': eid, 'error': 'no_directory'})
            continue

        for dir_name in dirs:
            if dir_name in excluded_eas or eid in excluded_eas:
                results['skipped_excluded'].append(dir_name)
                print('SKIP (excluded): {}'.format(dir_name))
                continue

            mq5_path = os.path.join(EA_BASE, dir_name, dir_name + '.mq5')
            card_path = os.path.join(CARDS_ROOT, dir_name + '.md')

            if not os.path.exists(mq5_path):
                results['errors'].append({'ea': dir_name, 'error': 'no_mq5'})
                continue
            if not os.path.exists(card_path):
                results['errors'].append({'ea': dir_name, 'error': 'no_card'})
                continue

            params = extract_strategy_params(mq5_path)
            if not params:
                results['no_strategy_params'].append(dir_name)
                print('SKIP (no strategy params): {}'.format(dir_name))
                continue

            if card_has_parseable_params(card_path):
                results['cards_already_had_params'].append(dir_name)
                print('SKIP (already has params): {}'.format(dir_name))
            else:
                try:
                    if card_has_params_section(card_path):
                        results['errors'].append({
                            'ea': dir_name,
                            'error': 'card_has_params_section_but_unparseable'
                        })
                        print('WARN: {} has ## Parameters but not parseable'.format(dir_name))
                    else:
                        add_params_table_to_card(card_path, params)
                        results['cards_updated'].append({
                            'ea': dir_name,
                            'card': card_path,
                            'params_count': len(params),
                            'params': params
                        })
                        print('UPDATED: {} ({} params)'.format(dir_name, len(params)))
                except Exception as e:
                    results['errors'].append({'ea': dir_name, 'error': str(e)})
                    print('ERROR: {} -> {}'.format(dir_name, e))

    print()
    print('Summary:')
    print('  Cards updated: {}'.format(len(results['cards_updated'])))
    print('  Already had params: {}'.format(len(results['cards_already_had_params'])))
    print('  No strategy params in MQ5: {}'.format(len(results['no_strategy_params'])))
    print('  Skipped (excluded): {}'.format(len(results['skipped_excluded'])))
    print('  Errors: {}'.format(len(results['errors'])))

    os.makedirs(os.path.dirname(EVIDENCE_OUT), exist_ok=True)
    with open(EVIDENCE_OUT, 'w') as f:
        json.dump(results, f, indent=2)
    print('\nEvidence saved to {}'.format(EVIDENCE_OUT))

    return results


if __name__ == '__main__':
    results = run()
    sys.exit(0 if not results['errors'] else 1)
