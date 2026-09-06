"""Opt-in marketing copy of the morning brief; dry-run never opens the network."""
import argparse
import datetime as dt
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import uuid

try:
    from .website_archive_contract import scrub_text, REDACTED
except ImportError:
    from website_archive_contract import scrub_text, REDACTED

CONFIG = Path(__file__).parent / 'config/notion_publisher.v1.json'
ENV = Path('C:/QM/repo/.private/env')
BRIEF = Path('D:/QM/strategy_farm/dashboards/morning_brief.md')
LOCK = Path('D:/QM/strategy_farm/state/notion_morning_brief.lock')


def scrub(text):
    text = scrub_text(text)
    for pattern in (r'\b(?:secret_|ntn_)[A-Za-z0-9_]+', r'\b[A-Za-z_][\w.-]*\s*=\s*[^\s|]+',
                    r'\b(?:account|konto|login|magic|magics|host|hostname|server|vps)\s*[:=#]?\s*[^\s|·]+',
                    r'\b\w*[A-Za-z_]\w*\d{8,}\w*\b|\b\d{8,}\b',
                    r'\b(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}\b', r'https?://\S+'):
        text = re.sub(pattern, REDACTED, text, flags=re.I)
    return text


class SummaryHTML(HTMLParser):
    def __init__(self):
        super().__init__(); self.parts = []; self.hidden = 0
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'): self.hidden += 1
        if tag in ('p', 'div', 'br', 'tr', 'h1', 'h2', 'h3', 'li'): self.parts.append('\n')
        if tag in ('h1', 'h2', 'h3'): self.parts.append('## ')
        if tag == 'li': self.parts.append('- ')
    def handle_endtag(self, tag):
        if tag in ('script', 'style'): self.hidden = max(0, self.hidden-1)
        if tag in ('p', 'div', 'tr', 'h1', 'h2', 'h3', 'li'): self.parts.append('\n')
    def handle_data(self, data):
        if not self.hidden: self.parts.append(data)


def rich(text):
    return [{'type': 'text', 'text': {'content': text[i:i+1900]}} for i in range(0, len(text), 1900)] or [{'type': 'text', 'text': {'content': ''}}]


def blocks(summary):
    if re.search(r'<(?:html|body|p|div|h[123])\b', summary, re.I):
        parser = SummaryHTML(); parser.feed(summary); summary = ''.join(parser.parts)
    summary = scrub(summary)
    output = []; counters = []
    for raw in summary.splitlines():
        line = raw.strip()
        if not line or re.fullmatch(r'[=\-_]+', line): continue
        if re.match(r'(Qualifiziert |Frontier:|Q10 News:|Opt:|Backfill:|3\) FACTORY)', line):
            label, _, value = line.partition(':')
            if not value: label, value = 'Qualifiziert', line.removeprefix('Qualifiziert ')
            counters.append({'object': 'block', 'type': 'table_row', 'table_row': {'cells': [rich(label), rich(value.strip())]}})
            continue
        kind = 'heading_2' if re.match(r'^(#{1,3} |\d\)|WEG ZU)', line) else ('bulleted_list_item' if line.startswith('- ') else 'paragraph')
        line = re.sub(r'^#{1,3}\s+|^-\s+', '', line)
        output.append({'object': 'block', 'type': kind, kind: {'rich_text': rich(line)}})
    if counters:
        output.insert(0, {'object': 'block', 'type': 'table', 'table': {'table_width': 2, 'has_column_header': False, 'has_row_header': True, 'children': counters}})
    if len(output) > 95 or len(json.dumps(output).encode()) > 400000:
        raise ValueError('Brief exceeds bounded Notion payload')
    return output


def token_from_file(path=ENV):
    if not path.is_file(): raise ValueError('Notion integration token missing')
    values = []
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        key, sep, value = line.strip().partition('=')
        if sep and key == 'NOTION_INTEGRATION_TOKEN': values.append(value.strip().strip('"\''))
    if len(values) != 1 or not values[0] or re.search(r'\s', values[0]):
        raise ValueError('Notion integration token missing or ambiguous')
    return values[0]


class Client:
    def __init__(self, token, session=None):
        if not token: raise ValueError('Notion integration token missing')
        if session is None:
            import requests
            session = requests.Session()
        self.session = session
        self.headers = {'Authorization': 'Bearer '+token, 'Notion-Version': '2022-06-28', 'Content-Type': 'application/json'}
    def call(self, method, path, body=None):
        response = self.session.request(method, 'https://api.notion.com/v1/'+path, headers=self.headers, json=body, timeout=30)
        if not 200 <= response.status_code < 300:
            raise RuntimeError('Notion request failed (HTTP '+str(response.status_code)+')')
        return response.json()
    def pages(self, method, path, body=None):
        cursor = None; result = []
        while True:
            payload = dict(body or {})
            if cursor: payload['start_cursor'] = cursor
            target = path
            if method == 'GET':
                target += ('&' if '?' in path else '?')+'page_size=100'+('&start_cursor='+cursor if cursor else '')
            data = self.call(method, target, payload if method != 'GET' else None)
            result.extend(data.get('results', []))
            if not data.get('has_more'): return result
            new = data.get('next_cursor')
            if not new or new == cursor: raise RuntimeError('Invalid Notion pagination')
            cursor = new


def upsert(client, parent, date, content):
    parent = str(uuid.UUID(parent)); dt.date.fromisoformat(date)
    databases = [b for b in client.pages('GET', 'blocks/'+parent+'/children')
                 if b.get('type') == 'child_database' and b['child_database'].get('title') == 'Morgenbriefing']
    if len(databases) > 1: raise ValueError('Multiple Morgenbriefing databases; configure a unique parent')
    database = databases[0]['id'] if databases else client.call('POST', 'databases', {
        'parent': {'type': 'page_id', 'page_id': parent}, 'title': rich('Morgenbriefing'),
        'properties': {'Name': {'title': {}}, 'Date': {'date': {}}}})['id']
    found = client.pages('POST', 'databases/'+database+'/query', {'filter': {'property': 'Date', 'date': {'equals': date}}})
    if len(found) > 1: raise ValueError('Duplicate date pages; manual review required')
    properties = {'Name': {'title': rich('Morgenbriefing '+date)}, 'Date': {'date': {'start': date}}}
    if not found:
        page = client.call('POST', 'pages', {'parent': {'database_id': database}, 'properties': properties, 'children': content})
        return {'status': 'CREATED', 'page_id': page['id']}
    page_id = found[0]['id']
    # This dedicated daily page is publisher-owned. A retry replaces its body.
    for block in client.pages('GET', 'blocks/'+page_id+'/children'):
        client.call('DELETE', 'blocks/'+block['id'])
    client.call('PATCH', 'blocks/'+page_id+'/children', {'children': content})
    client.call('PATCH', 'pages/'+page_id, {'properties': properties})
    return {'status': 'UPDATED', 'page_id': page_id}


def publish(summary, date, config_path=CONFIG, env_path=ENV, dry_run=False):
    content = blocks(summary)
    if dry_run: return {'date': date, 'children': content, 'network': False}
    config = json.loads(config_path.read_text(encoding='utf-8'))
    if config.get('enabled') is not True: return {'status': 'DISABLED'}
    parent = str(uuid.UUID(config['parent_page_id']))
    token = token_from_file(env_path)
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    with LOCK.open('x', encoding='utf-8') as handle: handle.write(date)
    try: return upsert(Client(token), parent, date, content)
    finally: LOCK.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--brief', type=Path, default=BRIEF)
    parser.add_argument('--date', required=True)
    parser.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    dt.date.fromisoformat(args.date)
    print(json.dumps(publish(args.brief.read_text(encoding='utf-8'), args.date, dry_run=not args.publish), ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
