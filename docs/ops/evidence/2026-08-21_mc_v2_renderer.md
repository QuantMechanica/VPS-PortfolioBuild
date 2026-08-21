# Mission Control v2 — SHADOW renderer (evidence)

**Date:** 2026-08-21 · **Author:** Claude (Design-Lane) · **Task:** MC v2 renderer, Umsetzungsschritt 4 (Shadow)
**Spec:** `docs/ops/MISSION_CONTROL_V2_RENDER_SPEC.md` · **Contract:** `docs/ops/MISSION_CONTROL_V2_DATA_CONTRACT.md`

## What was built

- `tools/strategy_farm/render_cockpit_v2.py` — shadow renderer. Imports the
  contract builder `build_contract` from `mission_control_v2_data.py` and binds
  the emitted fields verbatim (zero data decisions; no duplicated queries).
- `tools/strategy_farm/tests/test_render_cockpit_v2.py` — 7 spec tests, all pass.
- Output: `D:\QM\strategy_farm\dashboards\cockpit_v2.html` (written by a live run).

## Shadow / scope discipline

- `cockpit.html`, `render_cockpit.py`, `style.css` untouched — confirmed via
  `git status` (not in the diff; only `render_cockpit_v2.py` +
  `test_render_cockpit_v2.py` are new).
- Renderer writes only `cockpit_v2.html`. Read-only page — no `<button>` /
  `<form>` / `onclick` / `<input>` (asserted on the live output and by test 6).
- `<link rel="stylesheet" href="style.css">` (co-located in the output dir) plus
  a page-grid `<style>` block using **only** `var(--*)` tokens. Live check:
  zero `#hex` literals in the style block, no `border-radius`, no
  gradient/shadow/blur/motion.

## Factory traffic-light mapping (spec §1, renderer-side)

`map_factory_light(factory_state)` maps the emitter enum onto the ratified
ampel: `NOMINAL → var(--pass)` (green), `MAINTENANCE → var(--warn)` (amber, from
`FACTORY_OFF.flag`), `DEGRADED → var(--warn)` (amber, health-FAIL while
running), `CRITICAL → var(--fail)` (red, only when truly down). The raw emitter
state + `factory_state_reason` are always shown as a subline. Unit-tested for all
four cases (test 3), incl. the invariant that red is reserved for CRITICAL.

## Test run

```
$ python -m pytest tools/strategy_farm/tests/test_render_cockpit_v2.py -q
.......                                                                  [100%]
7 passed in 0.32s
```

1. all 10 terminals rendered, idle cards carry a reason (6× "no active farm claim")
2. no `\bP[0-9]\b` gate token in HTML (Qxx only; P50/P90 percentiles do not match)
3. factory-ampel mapping — 4 cases
4. decision queue caps at 5 + "… n weitere"
5. STALE badge for `staleness=STALE` and for `--from-json`
6. no action elements (read-only)
7. queue subtotals add to totals (`executable + parked = pending_total`;
   `pending_total + active = queue_total`)

## Live render

```
$ python tools/strategy_farm/render_cockpit_v2.py
[render_cockpit_v2] factory=CRITICAL terminals_running=4 owner_open=31 bytes=31301 -> D:\QM\strategy_farm\dashboards\cockpit_v2.html
```

Live output checks (over `cockpit_v2.html`): `P-gate tokens: []`; button/form/
onclick/input all `False`; `style.css` linked and present in dir; all 10
terminals present; SHADOW footer present; `cockpit.html` still present/untouched.

`--from-json <snapshot>` fallback renders a header `STALE · SNAPSHOT · vor …`
badge (verified live).

## Sections (spec order)

Sticky 6-cell control strip (Factory / Freshness / Queue / Terminals / Clear-ETA
/ OWNER) → Owner Decision Queue (≤5 + overflow) → Fortschrittsvergleich
(Heute · Gestern · 7-Tage-Ø · Gesamt; infra row dimmed; caveats + counting_basis
footnotes) → Terminal Board T1–T10 (5×2 grid, idle reasons) → Queue & Engpass
(executable vs parked tables + bottleneck + ETA basis) → Ausnahmen &
Datenqualität (`<details open>`, degraded/stale/caveats) → footer
(generated_at / schema / source-db / Renderdauer / SHADOW notice). Numbers are
right-aligned JetBrains Mono; relative time via one inline script, no libraries.
