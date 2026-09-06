import json
from pathlib import Path
import pytest
from tools.strategy_farm import notion_morning_brief as n

PARENT = '11111111-1111-1111-1111-111111111111'

class Response:
    status_code = 200
    def __init__(self, data): self.data = data
    def json(self): return self.data

class FakeHTTP:
    def __init__(self): self.db = None; self.page = None; self.body = []; self.calls = []
    def request(self, method, url, headers, json, timeout):
        assert headers['Notion-Version'] == '2022-06-28'
        assert headers['Authorization'] == 'Bearer fixture'
        self.calls.append((method, url, json))
        path = url.split('/v1/')[1].split('?')[0]
        if path == 'blocks/'+PARENT+'/children':
            data = {'results': [{'id': 'db', 'type': 'child_database', 'child_database': {'title': 'Morgenbriefing'}}] if self.db else []}
        elif method == 'POST' and path == 'databases': self.db = 'db'; data = {'id': 'db'}
        elif path == 'databases/db/query': data = {'results': [{'id': self.page}] if self.page else []}
        elif path == 'pages' and method == 'POST': self.page = 'page'; self.body = json['children']; data = {'id': self.page}
        elif path == 'blocks/page/children' and method == 'GET': data = {'results': [{'id': 'b'+str(i)} for i in range(len(self.body))]}
        elif method == 'DELETE': self.body = []; data = {}
        elif path == 'blocks/page/children' and method == 'PATCH': self.body = json['children']; data = {}
        elif path == 'pages/page' and method == 'PATCH': data = {}
        else: raise AssertionError((method, path))
        return Response(data)

def test_idempotent_daily_upsert():
    http = FakeHTTP(); client = n.Client('fixture', http)
    a = n.upsert(client, PARENT, '2026-09-06', n.blocks('## Morning\n- Ready'))
    b = n.upsert(client, PARENT, '2026-09-06', n.blocks('## Updated\n- Ready'))
    assert a['page_id'] == b['page_id'] == 'page'
    assert sum(m == 'POST' and u.endswith('/pages') for m,u,b in http.calls) == 1
    assert sum(m == 'POST' and u.endswith('/databases') for m,u,b in http.calls) == 1
    assert http.body == n.blocks('## Updated\n- Ready')

@pytest.mark.parametrize('private', ['D:/QM/private/file.set', 'G:\\My Drive\\Secret\\file', 'host: desktop-private',
    'account: 4000090541', 'DXZ_4000090541', 'magic=42', 'InpRisk=0.1', 'ntn_abcdefg', 'vps.example.net', '192.168.2.4'])
def test_scrub(private):
    assert private not in json.dumps(n.blocks('Ready '+private))

def test_dry_run_without_config_or_token(tmp_path, monkeypatch):
    monkeypatch.setattr(n, 'Client', lambda *a: pytest.fail('network client instantiated'))
    result = n.publish('## News\n- Ready', '2026-09-06', tmp_path/'absent', tmp_path/'absent', True)
    assert result['network'] is False and len(result['children']) == 2

def test_disabled_without_token(tmp_path, monkeypatch):
    monkeypatch.setattr(n, 'Client', lambda *a: pytest.fail('network client instantiated'))
    p = tmp_path/'config'; p.write_text('{"enabled": false}')
    assert n.publish('Ready', '2026-09-06', p, tmp_path/'absent')['status'] == 'DISABLED'

def test_missing_token(tmp_path):
    with pytest.raises(ValueError, match='missing'): n.token_from_file(tmp_path/'absent')

def test_html_and_table():
    result = n.blocks('<style>private CSS</style><h2>Morning</h2><p>Qualifiziert 8/25 Paare</p><li>Ready</li>')
    assert result[0]['type'] == 'table'
    assert 'private CSS' not in json.dumps(result)
    assert result[1]['type'] == 'heading_2'

def test_pagination():
    class Pages:
        def request(self, method, url, **kw):
            return Response({'results': [2]} if 'start_cursor=next' in url else {'results': [1], 'has_more': True, 'next_cursor': 'next'})
    assert n.Client('fixture', Pages()).pages('GET', 'blocks/x/children') == [1,2]

def test_error_body_never_echoed():
    class Bad:
        def request(self, *a, **kw):
            r = Response({'message': 'secret_token'}); r.status_code = 403; return r
    with pytest.raises(RuntimeError, match='HTTP 403') as error: n.Client('fixture', Bad()).call('GET', 'x')
    assert 'secret_token' not in str(error.value)

def test_payload_limit():
    with pytest.raises(ValueError): n.blocks('\n'.join(['line']*100))
