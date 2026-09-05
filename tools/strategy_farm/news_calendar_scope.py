"""E1-B3 explicit scope accounting. Declarations never turn measured FAIL into PASS."""
import csv
from datetime import datetime, timezone
import hashlib
import json
from collections import defaultdict
from pathlib import Path


def declare_scope(gates, gaps, footprints, offsets, native_inputs, native_dir):
    records={}
    def add(gate, currency, event, months, reason, evidence):
        months=sorted(set(months))
        if not currency or not event or not months or any(len(m)!=7 or m[4]!='-' for m in months):
            raise ValueError('inadmissibility requires explicit currency/class/month bounds')
        record={'gate':gate,'currency':currency,'event_class':event,'months':months,
                'reason':reason,'required_evidence':evidence,'usage':'INADMISSIBLE',
                'production_use_permitted':False}
        key=hashlib.sha256(json.dumps(record,sort_keys=True).encode()).hexdigest()
        records[key]={'id':'E1B3-'+key[:16],**record}

    for group in gates['6.1_anchor_shares'].get('failed_groups',[]):
        for gate in ['6.1_anchor_shares','6.7_detector_clean']:
            add(gate,'USD',group['class'],[f"{group['year']}-{m:02d}" for m in range(1,13)],
                'CLASS_YEAR_ANCHOR_SHARE_BELOW_EXISTING_REQUIREMENT',f"diagnose anchor group {group['source']}/{group['class']}/{group['year']}")
    missing=gates['6.1_anchor_shares'].get('native_name_error')
    if missing:
        for event in missing.split(': ',1)[-1].split(', '):
            add('6.1_anchor_shares','USD',event,[f'{y}-{m:02d}' for y in range(2018,2027) for m in range(1,13) if y<2026 or m<=6],
                'REQUIRED_NATIVE_NAME_NOT_ANCHORED','native target catalog')
    # Every existing unresolved currency/class/month remains unavailable for use.
    for gap in gaps:
        month=gap.get('month') or str(gap.get('original_utc') or gap.get('utc') or '')[:7]
        if month:
            add('6.7_detector_clean',gap.get('currency','USD'),gap.get('event') or 'ALL_UNRESOLVED',
                [month],gap['reason'],'repair_gaps.json')
    for currency in ['USD','EUR','GBP','JPY','AUD','CAD']:
        fresh=gates['6.2_coverage']['fresh_exports'][currency]
        if (currency not in gates['6.2_coverage']['fresh_currencies_with_confirmed_official_anchor']
                or not fresh['present'] or not fresh['rows'] or fresh['errors']
                or (currency=='USD' and any(not fresh['monthly_rows'].get(f'2026-{m:02d}') for m in range(1,7)))):
            add('6.2_coverage',currency,'ALL_HIGH',[f'2026-{m:02d}' for m in range(1,7)],
                'H1_COVERAGE_OR_OFFICIAL_ANCHOR_UNCONFIRMED','fresh_export_anchor_checks.json; native_monthly_coverage.csv')
    for source, months in gates['6.2_coverage']['unexplained_zero_months'].items():
        if months:
            for gate in ['6.2_coverage','6.7_detector_clean']:
                add(gate,'USD','ALL_HIGH',months,'ZERO_MONTH_'+source.upper(),'diagnose coverage.json')
    for check in footprints:
        if check['status']=='PASS':continue
        month=str(check.get('utc') or check.get('requested_date') or '')[:7]
        add('6.5_tick_footprints',check['currency'],check['event_code'],[month],check['status'],
            check.get('m5_path') or check.get('source') or 'official timestamp and M5 window required')
    for decision in offsets:
        if decision.get('confirmed'):continue
        currency=decision['currency']
        months=sorted({datetime.fromtimestamp(int(r['broker_time']),timezone.utc).strftime('%Y-%m')
                       for p in Path(native_dir).glob(f'T_EXPORT_{currency}_HIGH_*_NATIVE.csv')
                       for r in csv.DictReader(p.open(encoding='utf-8-sig'))})
        add('6.5_tick_footprints',currency,'ALL_RATE_AND_NONRATE',months,
            'CURRENCY_FOOTPRINT_SELECTOR_UNCONFIRMED','nonusd_offset_decisions.json')
    for item in native_inputs:
        if item.get('role')!='UNVERIFIED_TIMESTAMP_EXCLUDED_FROM_TRUTH':continue
        path=Path(item['path']);groups=defaultdict(set)
        with path.open(encoding='utf-8-sig') as stream:
            for row in csv.DictReader(stream):
                groups[row['event_name']].add(datetime.fromtimestamp(int(row['broker_time']),timezone.utc).strftime('%Y-%m'))
        currency=path.name.split('_')[2]
        for event,months in groups.items():
            add('6.7_detector_clean',currency,event,months,'FILE_TIMESTAMP_ENCODING_UNVERIFIED',str(path))
            if currency=='USD' and gates['6.1_anchor_shares'].get('native_name_error'):
                add('6.1_anchor_shares',currency,event,months,'TARGET_EXPORT_NOT_ANCHORED',str(path))
    result=sorted(records.values(),key=lambda r:(r['gate'],r['currency'],r['event_class'],r['months'],r['id']))
    # Explicitly separate scoped accounting from full-envelope publication.
    for name,gate in gates.items():
        relevant=[r['id'] for r in result if r['gate']==name]
        gate['scope_status']='MEASURED_PASS' if gate['pass'] else ('COVERED_BY_DECLARATION' if relevant else 'UNRESOLVED')
        if name=='6.7_detector_clean' and gate.get('input_changes'):
            gate['scope_status']='UNRESOLVED_INPUT_MUTATION'
        gate['inadmissible_range_ids']=relevant
        gate['declaration_is_measured_pass']=False
    return result
