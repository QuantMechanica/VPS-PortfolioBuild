# Session-offset registry: archive measurement + XAUUSD/XAGUSD reconciliation

- Router task: `ee0922a7-ea31-48b4-862c-76b536f44978` (claude, priority 70)
- Scope: read-only measurement + analysis. No card mutation, no framework source
  mutation, no build/compile/setfile/work-item action.
- Follow-up to `fea371c2` / `6dfa3117` / the entry-clock discriminator doc
  (`docs/ops/evidence/2026-08-16_entry_clock_discriminator_41015_41021_census_reclassification.md`).

## 1. Concurrent-write notice (read this first)

While this task was in progress, at least one other process was concurrently
writing draft registry files to the same shared checkout
(`C:/QM/repo/framework/registry/`, branch `agents/board-advisor`):
`session_entry_offset_minutes.csv` (the exact filename
`validate_build_guardrails.py`'s `SESSION_OFFSET_REGISTRY_PATH` expects) and a
second, differently-schemad `session_offset_minutes.csv`. Both were observed
uncommitted, and the first was subsequently deleted from disk (not committed)
while this task was still running — i.e. an unrelated concurrent agent is
actively iterating on the same registry file right now. This task did **not**
write to `framework/registry/` to avoid clobbering that in-flight work; an
earlier throwaway JSON draft this task produced there was deleted once the
collision was noticed. **Whoever lands the final
`framework/registry/session_entry_offset_minutes.csv` must incorporate
section 3 below before it is treated as authoritative** — the version
observed in this task assigned `XAUUSD.DWX`/`XAGUSD.DWX` `offset_minutes=0,
enforced=true` on reasoning that section 3 shows is unsound.

## 2. Archive-bar measurement method and validation

Method: for each symbol, read the finest-grained cached intraday export under
`D:/QM/mt5/T_Export/MQL5/Files/<SYMBOL>.DWX_{M5,M15,M30,H1}.csv` (preference
order M5>M15>M30>H1), group bars by broker-day (`epoch // 86400` — D1 exports
confirm bars align exactly to 86400s day boundaries on this feed), and take
each day's first-bar offset from midnight (`first_bar_epoch % 86400`). Report
modal/median/p10/p90 across all sampled days.

**Validation against tick-level ground truth**: applied to `XTIUSD.DWX`
(1,095 sampled days, M15), this method returns a modal offset of exactly
3,600s (60.0 min, 99.5% of days), matching the low end of the independently
tick-measured `fea371c2` value (3,600-3,696s / 60.0-61.6 min, from bound EA
logger timestamps during a real-tick backtest). The ~0-96s residual is
consistent with bar-open-vs-first-tick granularity, not a method error. This
validates archive-bar measurement as a reproducible, if slightly coarser,
proxy for the tick-level definition.

**Coverage**: 26/37 `dwx_symbol_matrix.csv` symbols have a cached intraday
export locally; 11 forex crosses do not (`CADJPY`, `CHFJPY`, `EURCAD`,
`EURCHF`, `EURNZD`, `GBPAUD`, `GBPCAD`, `GBPCHF`, `GBPNZD`, `NZDCHF`,
`NZDJPY`). For those, this task infers offset=0 by asset-class consistency
(17/17 *measured* forex pairs show modal offset 0, i.e. continuous session)
but flags this as inferred, not measured, pending a local export.

**Full results** (symbol: modal offset, %days at mode, sample days):

| Symbol | Asset class | Modal offset (min) | Consistency | Days |
|---|---|---:|---:|---:|
| 17 FX majors/crosses with cached export | forex | 0.0 | 69-100% | 1880-2210 |
| `NDX.DWX` | indices | 60.0 | 98.1% | 1674 |
| `SP500.DWX` | indices | 60.0 | 99.2% | 1933 |
| `UK100.DWX` | indices | 60.0 | 97.1% | 1096 |
| `WS30.DWX` | indices | 60.0 | 98.8% | 1932 |
| `GDAXI.DWX` | indices | **210.0** | 80.9% | 1902 |
| `XAGUSD.DWX` | commodities | **60.0** | 99.8% | 1093 |
| `XAUUSD.DWX` | commodities | **60.0** | 99.5% | 2124 |
| `XNGUSD.DWX` | commodities | 60.0 | 98.2% | 1016 |
| `XTIUSD.DWX` | commodities | 60.0 | 99.5% | 1095 |

Two findings outside this task's original scope, flagged for whoever owns
the registry / future card design, not acted on here:

- **Indices are not offset-free.** `NDX`/`SP500`/`UK100`/`WS30` show the same
  ~60 min energy-like session-break pattern as `XTIUSD`/`XNGUSD`; `GDAXI`
  shows a much larger ~210 min pattern (narrower European day session). The
  `6dfa3117` census reported "0 affected" for indices only because no
  current card uses the grace idiom on them — that remains true today, but
  any future index card using a tight D1-label grace must consult measured
  offsets, not assume continuity.
- **`XCUUSD.DWX` (Copper)** is referenced by at least one card
  (`QM5_20053` per the `session_offset_minutes.csv` draft) but is absent
  from `dwx_symbol_matrix.csv` entirely (the 2026-08-16 coverage trip, per
  memory) — this task could not measure it and did not investigate further.

## 3. XAUUSD/XAGUSD reconciliation: the "continuous session" claim is unsound

The `6dfa3117` census classified metals `NOT_AFFECTED` with the rationale
"continuous session, window is trivially satisfied" — asserted, not measured.
The competing in-flight registry draft observed in section 1 upgraded this to
an explicit `enforced=true, offset_minutes=0.0` row citing "operational
precedent QM5_20019 (XAUUSD.DWX, grace=5) and QM5_20095 (XAUUSD.DWX,
grace=15), both built without the zero-trade clock-mismatch signature."

**That precedent does not test the defect it is cited for.** Both EAs were
checked directly:

- `QM5_20019_xauxag-wkend.mq5:629,659`: `g_current_host_bar =
  iTime(g_leg_xau, PERIOD_H1, 0)` — the entry-grace anchor is the **current
  H1 bar**, not the D1 label.
- `QM5_20095_auag-mon-diff.mq5`: same `PERIOD_H1` host-bar anchor pattern.
- Both gate on `opening_delay = TimeCurrent() - g_current_host_bar >
  grace_minutes*60` (`QM5_20019:519-521`, `QM5_20095:510-512`) — but because
  the anchor re-rolls every hour, this is a "first N minutes of *any* H1
  bar" filter, not a "first N minutes of the trading *day*" filter. It
  cannot exhibit the XTI/XNG defect (fixed D1 00:00 label vs. delayed first
  tick) regardless of whether XAUUSD has a session break, because the H1
  anchor already tracks wherever the first real tick after any gap lands.
  `ea_metrics` confirms both traded normally (`QM5_20019`: 178 trades Q02,
  120 Q04; both non-zero) — consistent with this explanation, not with
  "XAUUSD has no session break."

This task's own archive measurement (section 2: `XAUUSD`/`XAGUSD` modal
offset 60.0 min at 99.5-99.8% consistency, essentially identical to
`XTIUSD`) is unrefuted by the H1-anchored precedent and should be preferred.
**No approved card currently combines `XAUUSD.DWX`/`XAGUSD.DWX` with the
D1-label-anchored tight-grace idiom** (checked: cards co-mentioning
`XAUUSD.DWX`/`XAGUSD.DWX` with `D1 bar open`/`D1 label`/`within N minutes of`
phrasing — 7 files; none use the vulnerable idiom on the gold/silver leg;
`QM5_20010_xau-friday-rush` uses the correct "first tick after previous
close" idiom, not a fixed grace-from-label). So there is no live defect
today, but the registry must not encode metals as
`enforced=true/offset=0/continuous_session_structural` — that would let a
future D1-anchored grace=5 gold/silver card build undetected, recreating
today's XTI/XNG incident on a new symbol.

**Recommendation for the registry owner**: set `XAUUSD.DWX`/`XAGUSD.DWX` to
the same treatment as `XNGUSD.DWX` at minimum (`offset_minutes≈60`,
archive-bar measured per section 2, `enforced` at the registry owner's
evidentiary-bar discretion — this task's measurement is bar-level not
tick-level, same caveat `XNGUSD.DWX` already carries) — never
`continuous_session_structural`/`offset=0`.

## 4. Disposition

No source, card, registry, setfile, or work-item was mutated by this task.
The build-preflight gate code itself
(`tools/strategy_farm/validate_build_guardrails.py::_scan_entry_grace_vs_session_offset`,
wired into `validate_path`) and its regression tests
(`tools/strategy_farm/tests/test_build_guardrails.py`) already exist on
`main` (commit `905c6c100`) — that part of the original task ask is done by
prior work, not this task. The missing piece is the registry CSV data file
itself, which is contested (section 1) and intentionally left for whoever
currently owns it to finish, incorporating section 3.

Companion artifact: the OWNER batch proposal for the 25
`CONFIRMED_AFFECTED` cards, `docs/ops/evidence/2026-08-16_session_offset_grace_batch_proposal_25_cards.md`.
