"""Strategy Archive Matrix — Prototyp (OWNER-Auftrag 2026-08-23).

Spezifikation: ``docs/ops/STRATEGY_ARCHIVE_MATRIX_SPEC_2026-08-23.md`` (v1.0).

Eine Fläche: Zeile = Strategy Card, Spalte = Gate, Feld = ein Chip je Symbol.
Der Zweck der Seite ist NICHT, Erfolge zu zeigen, sondern **Löcher**: Zellen, deren
Vorgänger-Gate bestanden ist und die trotzdem keine einzige Zeile besitzen.

Read-only. Keine Aktionspfade, kein Schreibzugriff auf die Datenbank, keine
Verdikt-Interpretation außerhalb der bestehenden ``work_items_clean``-Taxonomie.

Aufruf:
    python tools/strategy_farm/dashboards/render_archive_matrix_prototype.py
"""
from __future__ import annotations

import datetime as dt
import html
import json
import os
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from phase_ids import PHASE_NAME  # noqa: E402
from work_item_clean_view import open_clean_view_connection  # noqa: E402

FARM_ROOT = Path("D:/QM/strategy_farm")
DB = FARM_ROOT / "state" / "farm_state.sqlite"
CARDS_APPROVED = FARM_ROOT / "artifacts" / "cards_approved"
OUT = FARM_ROOT / "dashboards" / "strategy_archive_matrix_prototype.html"

# Spaltenreihenfolge = FLUSS (OWNER-Entscheid F2): der Optimierungszweig steht dort,
# wo er durchlaufen wird — zwischen Q10 und Q11. Die Zweigstufen tragen ihren künftigen
# Namen (Q10.1-Q10.3, Manifest v4) mit dem heute gültigen Token als Kleinschrift.
COLUMNS: list[tuple[str, str, str, str]] = [
    # (Speichertoken, Anzeigename, Gruppe, Untertitel)
    ("Q02", "Q02", "eval", ""), ("Q03", "Q03", "eval", ""), ("Q04", "Q04", "eval", ""),
    ("Q05", "Q05", "eval", ""), ("Q06", "Q06", "eval", ""), ("Q07", "Q07", "eval", ""),
    ("Q08", "Q08", "eval", ""), ("Q09", "Q09", "eval", ""), ("Q10", "Q10", "eval", ""),
    ("Q14", "Q10.1", "opt", "heute Q14"),
    ("Q15", "Q10.2", "opt", "heute Q15"),
    ("Q16", "Q10.3", "opt", "heute Q16"),
    ("Q11", "Q11", "port", ""), ("Q12", "Q12", "port", ""), ("Q13", "Q13", "port", ""),
]
GATE_TOKENS = [c[0] for c in COLUMNS]
GATE_IDX = {g: i for i, g in enumerate(GATE_TOKENS)}
# Die gewöhnliche Kette für den Lochtest — der Optimierungszweig ist ein Abzweig und
# erzeugt niemals ein "Loch" (er ist optional, kein ausstehender Schritt).
ORDINARY = ["Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10", "Q11", "Q12", "Q13"]

GROUP_LABEL = {"eval": "Evaluierung", "opt": "Optimierung", "port": "Portfolio-Build"}

# Zellzustände (OWNER-Entscheid F3). Reihenfolge = Rangfolge bei der Verdichtung.
ST_PASS, ST_SOFT, ST_FAIL, ST_VOID, ST_OPEN, ST_HOLE, ST_NONE = range(7)
ST_CLASS = {ST_PASS: "p", ST_SOFT: "s", ST_FAIL: "f", ST_VOID: "v",
            ST_OPEN: "o", ST_HOLE: "h", ST_NONE: ""}
ST_NAME = {ST_PASS: "PASS", ST_SOFT: "PASS bedingt", ST_FAIL: "FAIL", ST_VOID: "VOID",
           ST_OPEN: "läuft/Queue", ST_HOLE: "Loch", ST_NONE: "—"}

RETIRE_TOKENS = ("RETIRE", "RETIRED_LOW_FREQ", "OBSOLETE_NON_DWX_SYMBOL",
                 "SUPERSEDED", "SUPERSEDED_BY_LOGICAL_BASKET", "CANCELLED")


def _gate_of(phase: str | None) -> str | None:
    """Speicherphase → Matrixspalte. P2 ist ein Legacy-Alias von Q02."""
    if not phase:
        return None
    if phase.startswith("Q09"):
        return "Q09"
    if phase == "P2":
        return "Q02"
    return phase if phase in GATE_IDX else None


def _state_of(taxonomy: str, verdict: str) -> int:
    """Taxonomie + Verdikt → Zellzustand. Die Taxonomie ist die bestehende
    ``work_items_clean``-Ableitung; hier wird sie nur auf sieben Zustände verdichtet."""
    if taxonomy == "open":
        return ST_OPEN
    if taxonomy in ("infra", "invalid"):
        return ST_VOID
    if taxonomy == "strategy":
        if verdict in ("PASS_SOFT", "PASS_LOWFREQ"):
            return ST_SOFT
        if verdict.startswith("PASS"):
            return ST_PASS
        return ST_FAIL
    # governance / review / draft_defect / measurement / unknown tragen kein
    # wirtschaftliches Urteil und sind auch kein offener Lauf.
    return ST_VOID


def load_card_targets() -> dict[str, list[str]]:
    """Zielsymbole aus dem Frontmatter der freigegebenen Karten.

    ZWEITE QUELLE — bewusst getrennt gehalten und auf der Seite als solche
    ausgewiesen (F8: die Matrix selbst steht auf ``work_items`` allein)."""
    out: dict[str, list[str]] = {}
    if not CARDS_APPROVED.is_dir():
        return out
    pat = re.compile(r"^target_symbols:\s*\[([^\]]*)\]", re.M)
    for path in CARDS_APPROVED.glob("QM5_*.md"):
        ea = path.name.split("_", 2)[0] + "_" + path.name.split("_", 2)[1]
        try:
            head = path.read_text(encoding="utf-8", errors="replace")[:4000]
        except OSError:
            continue
        m = pat.search(head)
        if not m:
            continue
        syms = [s.strip().strip('"\'') for s in m.group(1).split(",") if s.strip()]
        if syms:
            out[ea] = syms
    return out


def collect() -> dict:
    t0 = time.perf_counter()
    conn = open_clean_view_connection(DB)

    latest: dict[tuple[str, str, str], tuple[str, str, str, str]] = {}
    retired: set[tuple[str, str]] = set()
    slug: dict[str, str] = {}
    held_items: set[str] = set()
    rows_seen = 0
    skipped_phase: Counter = Counter()

    for wid, ea, sym, phase, verdict, tax, upd, payload in conn.execute(
        "SELECT id, ea_id, symbol, phase, verdict, verdict_taxonomy, updated_at, setfile_path "
        "FROM work_items_clean"
    ):
        rows_seen += 1
        if not ea:
            continue
        gate = _gate_of(phase)
        if gate is None:
            skipped_phase[phase or "<null>"] += 1
            continue
        symbol = (sym or "").strip() or "BASKET"
        v = (verdict or "").upper()
        if any(v.startswith(t) for t in RETIRE_TOKENS):
            retired.add((ea, symbol))
        key = (ea, symbol, gate)
        cur = latest.get(key)
        u = upd or ""
        if cur is None or u > cur[0]:
            latest[key] = (u, v, (tax or "unknown"), wid)
        if payload and ea not in slug:
            pass

    for wid, in conn.execute(
        "SELECT work_item_id FROM work_item_holds WHERE active = 1"
    ):
        held_items.add(wid)

    conn.close()

    # Slug aus den EA-Verzeichnissen (nur Anzeige).
    ea_dir = REPO_ROOT / "framework" / "EAs"
    if ea_dir.is_dir():
        for d in os.scandir(ea_dir):
            if d.is_dir() and d.name.startswith("QM5_"):
                parts = d.name.split("_", 2)
                if len(parts) == 3:
                    slug[f"{parts[0]}_{parts[1]}"] = parts[2]

    targets = load_card_targets()

    # ── Karten aufbauen ───────────────────────────────────────────────
    by_card: dict[str, dict[str, dict[str, tuple]]] = defaultdict(lambda: defaultdict(dict))
    for (ea, symbol, gate), val in latest.items():
        by_card[ea][symbol][gate] = val

    cards = []
    stats = Counter()
    hole_by_gate: Counter = Counter()
    untested_targets = 0

    for ea, sym_map in by_card.items():
        # Zielsymbole ohne jeden Lauf sind ebenfalls ein Loch — aber aus der
        # zweiten Quelle, deshalb getrennt gezählt und markiert.
        for tsym in targets.get(ea, []):
            if tsym not in sym_map:
                sym_map[tsym] = {}
                untested_targets += 1

        symbols = sorted(sym_map)
        cells: dict[str, list[int]] = {}
        n_pass = n_fail = n_void = n_open = n_hole = 0
        hp_idx = -1
        last_upd = ""

        for si, symbol in enumerate(symbols):
            gates = sym_map[symbol]
            is_retired = (ea, symbol) in retired

            # (1) ALLES zeichnen, was in der Datenbank steht. Ein früher Abbruch
            # der Kette darf gemessene Zellen niemals verschlucken — die Seite
            # behauptet, die ganze Datenbank zu zeigen.
            for token, _l, _g, _s in COLUMNS:
                cell = gates.get(token)
                if cell is None:
                    continue
                upd, verdict, tax, wid = cell
                st = ST_OPEN if (wid in held_items and tax == "open") else _state_of(tax, verdict)
                cells.setdefault(token, []).append((si << 3) | st)
                stats[st] += 1
                if st in (ST_PASS, ST_SOFT):
                    n_pass += 1
                    if GATE_IDX[token] > hp_idx:
                        hp_idx = GATE_IDX[token]
                elif st == ST_FAIL:
                    n_fail += 1
                elif st == ST_VOID:
                    n_void += 1
                elif st == ST_OPEN:
                    n_open += 1
                if upd > last_upd:
                    last_upd = upd

            # (2) Getrennt davon: das Loch. Erstes Gate der gewöhnlichen Kette,
            # dessen Vorgänger bestanden ist und das trotzdem keine Zeile hat.
            # Stillgelegte Paare erzeugen kein Loch (F5).
            if is_retired:
                continue
            for gi, gate in enumerate(ORDINARY):
                if gates.get(gate) is not None:
                    continue
                if gi == 0:
                    prev_ok = True
                else:
                    pc = gates.get(ORDINARY[gi - 1])
                    prev_ok = pc is not None and pc[1].startswith("PASS")
                if prev_ok:
                    cells.setdefault(gate, []).append((si << 3) | ST_HOLE)
                    n_hole += 1
                    hole_by_gate[gate] += 1
                break

        cards.append({
            "ea": ea, "slug": slug.get(ea, ""), "symbols": symbols, "cells": cells,
            "hp": hp_idx, "pass": n_pass, "fail": n_fail, "void": n_void,
            "open": n_open, "hole": n_hole, "upd": last_upd,
        })

    # F6: Default = höchstes bestandenes Gate zuerst, danach Löcher.
    cards.sort(key=lambda c: (-c["hp"], -c["hole"], c["ea"]))

    return {
        "cards": cards, "stats": stats, "hole_by_gate": hole_by_gate,
        "rows_seen": rows_seen, "cells": len(latest), "skipped_phase": skipped_phase,
        "untested_targets": untested_targets, "retired_pairs": len(retired),
        "held_items": len(held_items), "collect_s": time.perf_counter() - t0,
        "cards_with_targets": len(targets),
    }


CSS = """
:root{--bg:#0c0f16;--s1:#151a23;--s2:#1c2330;--s3:#27303f;--tx:#e8ebf0;--tx2:#b6bdc8;
--tx3:#868e9c;--tx4:#5b6472;--bd:#222a37;--bd2:#313a49;--pass:#30be69;--fail:#f05a5e;
--void:#e19a24;--open:#6b7280;--hole:#84a2ff;--eval:#3455a8;--opt:#a86a20;--port:#6b4ba8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);
font:13px/1.5 "Inter",-apple-system,Segoe UI,system-ui,sans-serif}
code,.mono{font-family:"JetBrains Mono",ui-monospace,Consolas,monospace}
header{padding:18px 22px 12px;border-bottom:1px solid var(--bd);background:var(--s1)}
h1{margin:0 0 4px;font-size:17px;font-weight:600;letter-spacing:-.01em}
.sub{color:var(--tx3);font-size:11.5px}
.warn{margin:10px 22px 0;padding:9px 12px;border-left:3px solid var(--void);
background:rgba(225,154,36,.07);color:var(--tx2);font-size:11.5px;line-height:1.55}
.legend{display:flex;flex-wrap:wrap;gap:14px;padding:11px 22px;border-bottom:1px solid var(--bd);
background:var(--s1);font-size:11.5px;color:var(--tx2);align-items:center}
.legend b{color:var(--tx);font-weight:500}
.controls{display:flex;flex-wrap:wrap;gap:9px;padding:11px 22px;border-bottom:1px solid var(--bd);
align-items:center;background:var(--s1);position:sticky;top:0;z-index:5}
input,select{background:var(--s2);border:1px solid var(--bd2);color:var(--tx);
padding:5px 8px;font-size:12px;border-radius:0;font-family:inherit}
input:focus,select:focus{outline:1px solid var(--hole);border-color:var(--hole)}
.cnt{color:var(--tx3);font-size:11.5px;margin-left:auto}
.cnt strong{color:var(--tx)}
.wrap{overflow:auto;max-height:calc(100vh - 210px)}
table{border-collapse:collapse;width:100%;font-size:12px}
thead th{position:sticky;background:var(--s2);z-index:3;font-weight:500;color:var(--tx2);
border-bottom:1px solid var(--bd2);text-align:left;white-space:nowrap}
thead tr.g th{top:0;font-size:10px;letter-spacing:.08em;text-transform:uppercase;
padding:5px 8px;color:#fff;text-align:center}
thead tr.g th.eval{background:var(--eval)}
thead tr.g th.opt{background:var(--opt)}
thead tr.g th.port{background:var(--port)}
thead tr.g th.blank{background:var(--s2)}
thead tr.h th{top:24px;padding:6px 8px;cursor:pointer;user-select:none}
thead tr.h th:hover{color:var(--tx);background:var(--s3)}
thead tr.h th small{display:block;font-size:9px;color:var(--tx4);font-weight:400}
thead tr.h th.eval{border-bottom:2px solid var(--eval)}
thead tr.h th.opt{border-bottom:2px solid var(--opt)}
thead tr.h th.port{border-bottom:2px solid var(--port)}
tbody td{border-bottom:1px solid var(--bd);padding:3px 8px;vertical-align:middle}
tbody tr:hover{background:var(--s1)}
tr.card{cursor:pointer}
tr.card td.id{white-space:nowrap}
tr.card td.id b{font-family:"JetBrains Mono",monospace;font-weight:500;font-size:11.5px}
tr.card td.id span{color:var(--tx4);margin-left:7px;font-size:11px}
tr.card td.n{color:var(--tx3);text-align:right;font-family:"JetBrains Mono",monospace;
font-size:11px;white-space:nowrap}
tr.pair{background:#10141c}
tr.pair td{padding:2px 8px;border-bottom:1px solid #171d27}
tr.pair td.id{padding-left:26px;color:var(--tx3);font-size:11px;
font-family:"JetBrains Mono",monospace}
td.c{padding:3px 4px;min-width:26px}
.strip{display:flex;gap:2px;flex-wrap:wrap}
i{display:block;width:9px;height:9px;border-radius:0;flex:0 0 auto}
i.p{background:var(--pass)}
i.s{background:transparent;border:1.5px solid var(--pass)}
i.f{background:var(--fail)}
i.v{background:repeating-linear-gradient(45deg,var(--void) 0 2px,transparent 2px 4px);
outline:1px solid var(--void)}
i.o{background:transparent;border:1.5px solid var(--open)}
i.h{background:var(--hole);box-shadow:0 0 0 2px rgba(132,162,255,.30);position:relative}
i.h::after{content:"";position:absolute;inset:3px;background:var(--bg)}
.lg i{display:inline-block;vertical-align:-1px;margin-right:5px}
footer{padding:14px 22px 30px;color:var(--tx4);font-size:11px;line-height:1.7;
border-top:1px solid var(--bd)}
footer b{color:var(--tx3);font-weight:500}
.hidden{display:none}
"""

JS = """
(function(){
var tb=document.getElementById('tb'),rows=[],pairs={};
var MDL=JSON.parse(document.getElementById('mdl').textContent);
var SYM=JSON.parse(document.getElementById('syms').textContent);
var NCOL=15, SC=['p','s','f','v','o','h',''],
    SN=['PASS','PASS bedingt','FAIL','VOID','laeuft/Queue','Loch','-'];
Array.prototype.forEach.call(tb.rows,function(r){if(r.className==='card')rows.push(r);});
var fq=document.getElementById('q'),ff=document.getElementById('f'),
    fs=document.getElementById('sym'),fo=document.getElementById('so'),
    cn=document.getElementById('cn'),tm=document.getElementById('tm');
function apply(){
  var t0=performance.now();
  var q=(fq.value||'').toLowerCase().trim(),f=ff.value,s=fs.value,v=0;
  document.body.className=s?('symf s'+s):'';
  rows.forEach(function(r){
    var hide=false;
    if(q&&r.getAttribute('data-s').indexOf(q)<0)hide=true;
    if(!hide&&f==='hole'&&r.getAttribute('data-hole')==='0')hide=true;
    if(!hide&&f==='void'&&r.getAttribute('data-void')==='0')hide=true;
    if(!hide&&f==='open'&&r.getAttribute('data-open')==='0')hide=true;
    if(!hide&&s&&r.getAttribute('data-sym').indexOf('|'+s+'|')<0)hide=true;
    r.classList.toggle('hidden',hide);
    if(pairs[r.id])pairs[r.id].forEach(function(p){p.classList.toggle('hidden',hide);});
    if(!hide)v++;
  });
  cn.textContent=v.toLocaleString('de-DE');
  tm.textContent=(performance.now()-t0).toFixed(0);
}
function sort(key,dir){
  var t0=performance.now();
  var sorted=rows.slice().sort(function(a,b){
    var x,y;
    if(key==='ea'){x=a.getAttribute('data-ea');y=b.getAttribute('data-ea');
      return (x<y?-1:x>y?1:0)*dir;}
    x=parseFloat(a.getAttribute('data-'+key))||0;
    y=parseFloat(b.getAttribute('data-'+key))||0;
    if(x===y){var m=a.getAttribute('data-ea'),n=b.getAttribute('data-ea');
      return m<n?-1:m>n?1:0;}
    return (x-y)*dir;
  });
  var frag=document.createDocumentFragment();
  sorted.forEach(function(r){frag.appendChild(r);
    if(pairs[r.id])pairs[r.id].forEach(function(p){frag.appendChild(p);});});
  tb.appendChild(frag);
  tm.textContent=(performance.now()-t0).toFixed(0);
}
function build(tr){
  var idx=parseInt(tr.getAttribute('data-i'),10),model=MDL[idx],out=[],ref=tr.nextSibling;
  model.forEach(function(row){
    var si=row[0],cells=row[1],by={};
    cells.forEach(function(c){by[c[0]]=c[1];});
    var h='<td class="id">'+SYM[si]+'</td><td class="n"></td><td class="n"></td><td class="n"></td>';
    for(var i=0;i<NCOL;i++){
      if(by[i]===undefined){h+='<td class="c"></td>';}
      else{h+='<td class="c"><div class="strip"><i class="'+SC[by[i]]+' y'+si+
              '" t="'+SYM[si]+' '+SN[by[i]]+'"></i></div></td>';}
    }
    var el=document.createElement('tr');el.className='pair';el.innerHTML=h;
    tb.insertBefore(el,ref);out.push(el);
  });
  return out;
}
tb.addEventListener('click',function(e){
  var tr=e.target.closest('tr.card');if(!tr)return;
  var t0=performance.now();
  if(!pairs[tr.id]){pairs[tr.id]=build(tr);}
  else{pairs[tr.id].forEach(function(el){el.classList.toggle('hidden');});}
  tm.textContent=(performance.now()-t0).toFixed(0);
});
document.querySelectorAll('thead th[data-k]').forEach(function(th){
  th.addEventListener('click',function(){
    var k=th.getAttribute('data-k');
    var d=th.getAttribute('data-d')==='1'?-1:1;
    th.setAttribute('data-d',d===1?'1':'0');
    sort(k,k==='ea'?d:-d);
  });
});
fq.addEventListener('input',apply);ff.addEventListener('change',apply);
fs.addEventListener('change',apply);
fo.addEventListener('change',function(){
  var v=fo.value;sort(v==='ea'?'ea':v, v==='ea'?1:-1);});
})();
"""


def esc(s) -> str:
    return html.escape(str(s), quote=True)


def fmt(n: int) -> str:
    """Tausenderpunkt, deutsch."""
    return f"{n:,}".replace(",", ".")


def render(data: dict) -> str:
    cards = data["cards"]
    stats = data["stats"]
    hbg = data["hole_by_gate"]
    all_syms = sorted({s for c in cards for s in c["symbols"]})
    sym_idx = {s: i for i, s in enumerate(all_syms)}
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()

    def strip(cells: list[int], symbols: list[str], gate: str) -> str:
        if not cells:
            return ""
        out = []
        for packed in cells:
            si, st = packed >> 3, packed & 7
            sym = symbols[si]
            cls = ST_CLASS[st]
            out.append(f'<i class="{cls} y{sym_idx[sym]}" '
                       f't="{esc(sym)} {gate} {ST_NAME[st]}"></i>')
        return '<div class="strip">' + "".join(out) + "</div>"

    body = []
    detail_model: list = []
    for n, c in enumerate(cards):
        symbols = c["symbols"]
        tds = []
        for token, _label, _grp, _sub in COLUMNS:
            tds.append(f'<td class="c">{strip(c["cells"].get(token, []), symbols, token)}</td>')
        # Detailzeilen werden NICHT als HTML eingebettet — das hat die Seite auf
        # 19 MB getrieben. Stattdessen ein kompaktes Zahlenmodell, aus dem das
        # Skript die Paarzeile erst beim Aufklappen baut.
        model = []
        for si, sym in enumerate(symbols):
            gcells = []
            for ci, (token, _l, _g, _s) in enumerate(COLUMNS):
                for packed in c["cells"].get(token, []):
                    if (packed >> 3) == si:
                        gcells.append([ci, packed & 7])
                        break
            model.append([sym_idx[sym], gcells])
        detail_model.append(model)

        symkey = "|" + "|".join(str(sym_idx[s]) for s in symbols) + "|"
        search = f'{c["ea"]} {c["slug"]}'.lower()
        hp = COLUMNS[c["hp"]][1] if c["hp"] >= 0 else "—"
        body.append(
            f'<tr class="card" id="r{n}" data-i="{n}" data-ea="{esc(c["ea"])}" data-hp="{c["hp"]}" '
            f'data-hole="{c["hole"]}" data-void="{c["void"]}" data-open="{c["open"]}" '
            f'data-pass="{c["pass"]}" data-s="{esc(search)}" data-sym="{esc(symkey)}">' 
            f'<td class="id"><b>{esc(c["ea"])}</b><span>{esc(c["slug"][:34])}</span></td>'
            f'<td class="n">{hp}</td><td class="n">{c["hole"] or ""}</td>'
            f'<td class="n">{c["void"] or ""}</td>'
            + "".join(tds) + "</tr>")

    # Kopfgruppen
    g1, g2 = [], []
    g1.append('<th class="blank" colspan="4"></th>')
    for grp, label in (("eval", "Evaluierung"), ("opt", "Optimierung"), ("port", "Portfolio-Build")):
        n = sum(1 for c in COLUMNS if c[2] == grp)
        g1.append(f'<th class="{grp}" colspan="{n}">{label}</th>')
    g2.append('<th data-k="ea">Strategy Card</th>'
              '<th data-k="hp">höchstes&nbsp;PASS</th>'
              '<th data-k="hole">Löcher</th><th data-k="void">VOID</th>')
    for token, label, grp, sub in COLUMNS:
        name = PHASE_NAME.get(token, token)
        sub_html = f"<small>{esc(sub)}</small>" if sub else ""
        g2.append(f'<th class="{grp}" data-k="hp" title="{esc(name)}">{esc(label)}{sub_html}</th>')

    sym_css = "".join(
        f"body.symf.s{i} i:not(.y{i}){{opacity:.10}}" for i in range(len(all_syms)))
    # F7: handelbare DWX-Symbole zuerst (nach Verbreitung), alles Übrige gebündelt
    # unter "legacy" — nichts wird verworfen, nur einsortiert.
    use = Counter()
    for c in cards:
        for s in c["symbols"]:
            use[s] += 1
    dwx = sorted((s for s in all_syms if s.endswith(".DWX") or s == "BASKET"),
                 key=lambda s: (-use[s], s))
    legacy = sorted(s for s in all_syms if not (s.endswith(".DWX") or s == "BASKET"))
    sym_opts = (
        '<optgroup label="handelbar (DWX) + Basket">'
        + "".join(f'<option value="{sym_idx[s]}">{esc(s)} · {use[s]}</option>' for s in dwx)
        + '</optgroup><optgroup label="legacy / obsolet">'
        + "".join(f'<option value="{sym_idx[s]}">{esc(s)} · {use[s]}</option>' for s in legacy)
        + "</optgroup>")

    tot_cells = sum(stats.values())
    legend = (
        f'<span class="lg"><i class="p"></i><b>PASS</b> {fmt(stats[ST_PASS])}</span>'
        f'<span class="lg"><i class="s"></i><b>PASS bedingt</b> {fmt(stats[ST_SOFT])}</span>'
        f'<span class="lg"><i class="f"></i><b>FAIL</b> {fmt(stats[ST_FAIL])}</span>'
        f'<span class="lg"><i class="v"></i><b>VOID — Lauf verbrannt</b> {fmt(stats[ST_VOID])}</span>'
        f'<span class="lg"><i class="o"></i><b>läuft / Queue</b> {fmt(stats[ST_OPEN])}</span>'
        f'<span class="lg"><i class="h"></i><b>erreichbares Loch</b> '
        f'{fmt(sum(hbg.values()))}</span>'
        '<span class="lg" style="color:var(--tx4)">leeres Feld = kein Lauf und keiner fällig</span>'
    )

    holes = " · ".join(f"{g} {fmt(n)}" for g, n in
                       sorted(hbg.items(), key=lambda kv: -kv[1]) if n)

    return f"""<!doctype html><html lang="de"><head><meta charset="utf-8">
<title>Strategy Archive Matrix — Prototyp</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>{CSS}{sym_css}</style></head><body>
<header>
<h1>Strategy Archive Matrix <span style="color:var(--tx4);font-weight:400">· Prototyp</span></h1>
<div class="sub">{fmt(len(cards))} Strategy Cards · {fmt(tot_cells)} belegte Zellen ·
{fmt(sum(hbg.values()))} erreichbare Löcher · Stand {now} · Quelle
<code>work_items_clean</code> über <code>farm_state.sqlite</code></div>
</header>
<div class="warn">
<b>Prototyp, kein abgenommenes Cockpit.</b> Zwei Dinge sind bewusst anders als in der
Spezifikation: (1) Der <b>Stale-Pass-Chip (F4) fehlt</b> — die Messung ergab, dass die
Datenbank keine belastbare Build-Identität je Zelle führt (<code>expected_ex5_sha256</code>
in 0,3 % der Zeilen; der Dateizeitstempel des <code>.ex5</code> würde 73,6 % aller PASS-Zeilen
als veraltet markieren und ist durch Recompiles verrauscht). Bis dahin gilt der
vorregistrierte Rückfall: jüngstes Verdikt, sichtbar gewarnt.
(2) Die Zweigspalten tragen ihren künftigen Namen <b>Q10.1–Q10.3</b>; im Speicher heißen sie
bis zum Gate-Manifest v4 weiterhin Q14–Q16.
</div>
<div class="legend">{legend}</div>
<div class="controls">
<input id="q" type="search" placeholder="Card oder Slug suchen…" style="width:210px">
<select id="f"><option value="">alle Karten</option>
<option value="hole">nur mit Löchern</option>
<option value="void">nur mit VOID</option>
<option value="open">nur mit laufenden Zellen</option></select>
<select id="sym"><option value="">alle Symbole</option>{sym_opts}</select>
<select id="so"><option value="hp">Sortierung: höchstes bestandenes Gate</option>
<option value="hole">Sortierung: meiste Löcher</option>
<option value="void">Sortierung: meiste VOID</option>
<option value="ea">Sortierung: Card-Nummer</option></select>
<span class="cnt"><strong id="cn">{fmt(len(cards))}</strong> Karten sichtbar ·
letzte Operation <strong id="tm">0</strong> ms</span>
</div>
<div class="wrap"><table>
<thead><tr class="g">{''.join(g1)}</tr><tr class="h">{''.join(g2)}</tr></thead>
<tbody id="tb">{''.join(body)}</tbody></table></div>
<footer>
<b>Löcher je Gate:</b> {holes or '—'}<br>
<b>Was diese Seite NICHT zeigt:</b> Karten ohne jede Gate-Zeile erscheinen nicht
(OWNER-Entscheid F8: eine Quelle, eine Frische). Der Stau <i>vor</i> der Fabrik —
freigegebene Karten, die nie gebaut wurden — ist Sache des Drain-Programms, nicht dieser
Seite. Abwesenheit hier ist kein Beleg für Vollständigkeit.<br>
<b>Zweite Quelle, getrennt gehalten:</b> {fmt(data['untested_targets'])} Zielsymbole aus dem
Karten-Frontmatter haben keinen einzigen Lauf und erscheinen als Loch in Q02
({fmt(data['cards_with_targets'])} Karten mit <code>target_symbols</code> gelesen).<br>
<b>Leer statt Loch:</b> {fmt(data['retired_pairs'])} (Card, Symbol)-Paare sind über
RETIRE/OBSOLETE/SUPERSEDED stillgelegt, {fmt(data['held_items'])} Work Items stehen unter einem
aktiven Hold — beide erzeugen kein Loch.<br>
<b>Nicht dargestellte Speicherphasen:</b>
{esc(', '.join(f'{k} {v}' for k, v in data['skipped_phase'].most_common(6))) or '—'}<br>
Read-only. Keine Aktionspfade. Erhebung {data['collect_s']:.1f}s über
{fmt(data['rows_seen'])} Work-Item-Zeilen.
</footer>
<script id="mdl" type="application/json">{json.dumps(detail_model, separators=(",", ":"))}</script>
<script id="syms" type="application/json">{json.dumps(all_syms, separators=(",", ":"), ensure_ascii=False)}</script>
<script>{JS}</script></body></html>"""


def main() -> int:
    data = collect()
    t0 = time.perf_counter()
    doc = render(data)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(doc, encoding="utf-8")
    size = OUT.stat().st_size
    print(json.dumps({
        "output": str(OUT),
        "bytes": size,
        "mb": round(size / 1048576, 2),
        "cards": len(data["cards"]),
        "cells": data["cells"],
        "states": {ST_NAME[k]: v for k, v in sorted(data["stats"].items())},
        "holes_total": sum(data["hole_by_gate"].values()),
        "holes_by_gate": dict(data["hole_by_gate"].most_common()),
        "untested_target_symbols": data["untested_targets"],
        "retired_pairs": data["retired_pairs"],
        "active_holds": data["held_items"],
        "skipped_phases": dict(data["skipped_phase"].most_common()),
        "collect_s": round(data["collect_s"], 2),
        "render_s": round(time.perf_counter() - t0, 2),
    }, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
