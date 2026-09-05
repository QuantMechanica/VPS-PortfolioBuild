"""Read-only E1-C decision prototype. No gate/hold/counter/production writes."""
from __future__ import annotations
import collections
import datetime as dt
import hashlib
import json
from pathlib import Path
import sqlite3
import sys

ROOT = Path('C:/QM/repo')
CANDIDATE = Path('D:/QM/reports/news_calendar/repair_e1a/20260905T112500Z_e1b3_candidates')
EXPECTED = 'b33d0a3def6b19dfd78b977cfd13593806eb85f4b483143a5ca42980c2f4eb99'
OUT = Path(__file__).resolve().parent
CURRENCIES = {'USD','EUR','GBP','JPY','CHF','CAD','AUD','NZD','CNY'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def currencies(symbols):
    result = set()
    aliases = {'NDX':'USD','WS30':'USD','SP500':'USD','GDAXI':'EUR','UK100':'GBP',
               'XAUUSD':'USD','XAGUSD':'USD','XTIUSD':'USD','XBRUSD':'USD'}
    for symbol in symbols:
        base = symbol.split('.')[0]
        if base in aliases:
            result.add(aliases[base])
        elif len(base) == 6 and base[:3] in CURRENCIES and base[3:] in CURRENCIES:
            result.update((base[:3], base[3:]))
        else:
            return None  # Never infer custom basket exposure from its name.
    return result or None


def overlaps(record, start, end, relevant):
    if record['currency'] != 'ALL' and record['currency'] not in relevant:
        return False
    # No declaration carries a sufficient immutable impact/class exclusion proof.
    # Conservative proposal: all classes of a relevant currency remain relevant.
    for month in record['months']:
        lo = dt.datetime.strptime(month, '%Y-%m').replace(tzinfo=dt.timezone.utc)
        hi = lo.replace(year=lo.year+1, month=1) if lo.month == 12 else lo.replace(month=lo.month+1)
        if start < hi and end > lo:
            return True
    return False


def main():
    assert sha(CANDIDATE / 'manifest.json') == EXPECTED
    manifest = json.loads((CANDIDATE / 'manifest.json').read_text())
    declarations = json.loads((CANDIDATE / 'declared_inadmissible_ranges.json').read_text())
    assert sha(CANDIDATE / 'verification.json') == manifest['verification_sha256']
    assert sha(CANDIDATE / 'declared_inadmissible_ranges.json') == manifest['declared_inadmissible_ranges_sha256']
    assert declarations == manifest['declared_inadmissible_ranges']
    for row in manifest['files']:
        assert sha(CANDIDATE / row['name']) == row['sha256']
    gates = json.loads((CANDIDATE / 'verification.json').read_text())['gates']
    sys.path.insert(0, str(ROOT / 'tools/strategy_farm'))
    import news_calendar_gate as gate
    import news_calendar_candidate_ingress as ingress
    try:
        ingress.prepare(gate, CANDIDATE, EXPECTED)
    except ValueError as exc:
        ingress_result = str(exc)
    else:
        raise AssertionError('Scoped production ingress unexpectedly accepted')
    c = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
    c.row_factory = sqlite3.Row
    c.execute('BEGIN')
    observed = []
    query = """SELECT w.id,w.ea_id,w.symbol,w.phase,w.payload_json,h.hold_code
      FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
      WHERE h.active=1 AND h.hold_code='NEWS_CALENDAR_TIMESTAMP_DEFECT' ORDER BY w.id"""
    for row in c.execute(query):
        item = dict(row)
        payload = json.loads(item.pop('payload_json') or '{}')
        symbols = payload.get('basket_symbols') or [item['symbol']]
        relevant = currencies(symbols)
        item.update(symbols=symbols, relevant_currencies=sorted(relevant or []),
                    proposed_status='UNCONFIRMED', current_hold_unchanged=True,
                    reason='MISSING_SEALED_WINDOW_OR_SCOPE')
        plan_path = Path(payload.get('q09_run_plan_path') or '__MISSING__')
        if plan_path.is_file() and relevant:
            plan = json.loads(plan_path.read_text())
            inputs_path = Path(plan.get('input_manifest_path') or '__MISSING__')
            if inputs_path.is_file():
                inputs = json.loads(inputs_path.read_text())
                windows = inputs.get('windows', {})
                start, end = windows.get('full_from_utc'), windows.get('full_to_utc')
                item.update(plan_path=str(plan_path), plan_file_sha256=sha(plan_path),
                            input_manifest_path=str(inputs_path), input_file_sha256=sha(inputs_path),
                            observed_windows=windows, existing_plan_revalidated_for_admission=False)
                if start and end:
                    # Widen by one day for the decision prototype; actual consumers
                    # must derive their padding from their sealed axes/lookahead.
                    lo = dt.datetime.fromisoformat(start.replace('Z','+00:00')) - dt.timedelta(days=1)
                    hi = dt.datetime.fromisoformat(end.replace('Z','+00:00')) + dt.timedelta(days=1)
                    matches = [r for r in declarations if overlaps(r, lo, hi, relevant)]
                    item.update(overlap_count=len(matches), overlap_examples=[r['id'] for r in matches[:3]],
                                reason='DECLARED_SCOPE_OVERLAP' if matches else 'NO_OVERLAP_OBSERVED_BINDING_STILL_UNPROVEN')
        observed.append(item)
    c.close()
    at = dt.datetime(2026,2,1,tzinfo=dt.timezone.utc)
    fixture = {'currency':'USD','months':['2026-02']}
    assert overlaps(fixture,at,at+dt.timedelta(seconds=1),{'USD'})
    assert not overlaps(fixture,at-dt.timedelta(seconds=1),at,{'USD'})
    assert not overlaps(fixture,at,at+dt.timedelta(days=1),{'EUR'})
    assert overlaps({**fixture,'currency':'ALL'},at,at+dt.timedelta(days=1),{'EUR'})
    assert currencies(['UNKNOWN']) is None
    by_currency = {}
    for currency in sorted({r['currency'] for r in declarations}):
        months = sorted({m for r in declarations if r['currency']==currency for m in r['months']})
        by_currency[currency] = dict(month_count=len(months), first=months[0], last=months[-1])
    result = dict(schema='qm.e1c-decision-prototype/v1',
                  observed_at_utc=dt.datetime.now(dt.timezone.utc).isoformat(),
                  candidate_manifest_sha256=EXPECTED, gates={k:{'pass':v['pass'],'scope_status':v['scope_status']} for k,v in gates.items()},
                  declaration_count=len(declarations),by_currency=by_currency,
                  by_gate=dict(collections.Counter(r['gate'] for r in declarations)),
                  ingress_refusal=ingress_result,prototype_checks_passed=5,held_rows=observed,
                  pipeline_verdict_written=False, counter_changed=False,
                  source_bindings={str(p):sha(p) for p in [ROOT/'tools/strategy_farm/news_calendar_scope.py',
                    ROOT/'tools/strategy_farm/news_calendar_candidate_ingress.py',
                    ROOT/'tools/strategy_farm/q09_news_contract.py',ROOT/'framework/include/QM/QM_NewsFilter.mqh']})
    with (OUT/'snapshot.json').open('x',encoding='utf-8') as stream:
        json.dump(result,stream,indent=2);stream.write('\n')
    print(json.dumps({'held':len(observed),'reasons':dict(collections.Counter(r['reason'] for r in observed)),
                      'declarations':len(declarations),'prototype_checks_passed':5,'ingress_refusal':ingress_result}))


if __name__ == '__main__':
    main()
