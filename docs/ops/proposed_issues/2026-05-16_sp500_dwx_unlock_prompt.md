# Aufgabe: SP500.DWX als verfügbares Backtest-Symbol freischalten + QM5_1045 reopen

**Auftraggeber:** OWNER
**Empfänger:** Claude Code (strategy_farm policy-edit session)
**Datum:** 2026-05-16
**Geschätzte Dauer:** 30–45 Minuten (reine Datei-Edits + Card-Move + Smoke-Verify)

---

## Kontext (Stand vor Aufgabe)

Bis 2026-05-16 morgens galt: SP500/SPX500/SPY/ES sind im Darwinex-Broker-Feed **nicht verfügbar** (keine Tickdaten). Strategy_farm-Prompts + QB-Kriterien + `dwx_symbol_matrix.csv` codieren das als „permanently unavailable" + R3 REJECT für SPY-intraday-spezifische Karten.

Am **2026-05-16T19:15Z** hat OWNER externe SP500 Tick + M1 Bar-Daten (2018-07 → 2026-05) als **Custom Symbol `SP500.DWX`** auf T1 angelegt und Board Advisor hat das byte-exakt auf T2–T5 gespiegelt. Evidence:

```
C:/QM/repo/docs/ops/evidence/2026-05-16T191500Z_sp500_dwx_custom_symbol_t2_t5_rollout.md
```

**Folge:** SP500.DWX ist jetzt auf T1–T5 backtest-fähig. OWNER (2026-05-16): „ja, wir können das alles jetzt auf verfügbar stellen und angehen."

**Unverändert wichtig (nicht aufweichen):** SP500 ist beim Broker (DXZ) **nicht orderbar**. Live-Trading auf SP500.DWX ist physisch unmöglich — das ist eine **P10/T6-Gate**-Frage, nicht strategy_farm-Sache. Live-Promotion-Sperre für SP500-only-EAs bleibt; sie wird vom Board Advisor am T6-Gate enforced, nicht hier.

---

## Was zu tun (in dieser Reihenfolge)

### 1. Registry-Update: `framework/registry/dwx_symbol_matrix.csv`

Neue Zeile für `SP500.DWX` einfügen (alphabetisch sortiert zwischen `NZDUSD.DWX` und `UK100.DWX`):

- `symbol`: `SP500.DWX`
- `asset_class`: `indices`
- `import_log_path`: `(leer)` — kein autoimport, OWNER-manual
- `first_imported_at`: `2026-05-16T19:15:00`
- `canonical_name_verified`: `true`
- `evidence_source`: `owner_custom_symbol`  *(neue Kategorie; falls Downstream-Parser strikt nur `skip_as`/`path` akzeptieren, fallback auf `path` mit dem Evidence-Doc-Pfad in `evidence_line`)*
- `evidence_line`: `"[2026-05-16T19:15Z]   owner_custom_symbol | SP500.DWX: Custom Symbol auf T1-T5, OWNER-provided ticks 2018-07→2026-05 (9.4GB) + M1 bars; backtest-only (broker routet keine Orders auf SP500); evidence=docs/ops/evidence/2026-05-16T191500Z_sp500_dwx_custom_symbol_t2_t5_rollout.md"`

Prüfen: brechen Downstream-Konsumenten (`farmctl.py` registry-Loader, evtl. `verify_build_deployment.py`) auf der neuen `evidence_source` Kategorie? Wenn ja: auf `path` zurückfallen, oder den Loader minimal-invasiv erweitern.

### 2. Prompt-Update: `tools/strategy_farm/prompts/codex_build_ea.md` (Zeilen ~78–95 und ~110)

Aktuell (Zeile 78–85):
```
- **Permanently unavailable from Darwinex (no tick data, confirmed OWNER 2026-05-16)**:
  - **SP500 / SPX500 / SPX / SPY / ES futures** — these CANNOT be backtested
    on this VPS, period. Do NOT register `SPX500.DWX`, `SPY.DWX`, etc.
  - If a card requires SPY/SPX intraday cash-session microstructure
    specifically (no port preserves the strategy edge): set
    `blocked_reason: "SP500/SPY required; permanently unavailable in DWX feed"`.
  - If a card's concept ports cleanly: use **WS30.DWX** (Dow 30) +
    **NDX.DWX** (Nasdaq 100) as the available US large-cap index proxies.
```

Ersetzen durch:
```
- **SP500.DWX is available as a Custom Symbol on T1–T5 since 2026-05-16T19:15Z**
  (OWNER-provided ticks 2018-07→2026-05). It is **backtest-only**: the broker
  does NOT route orders on SP500, so live promotion to T6 is forbidden for
  SP500.DWX-only EAs — that's a Board Advisor T6-gate concern, not yours.
  At build time: SP500.DWX is a valid `magic_numbers.csv` registration target
  exactly like NDX.DWX or WS30.DWX. Use it when the card calls for SP500/SPX/SPY.
- **Permanently unavailable** (still): `SPX500.DWX`, `SPY.DWX`, `ES.DWX`, etc.
  — these are NOT the canonical Custom Symbol name. The single available
  Custom Symbol for the S&P 500 is `SP500.DWX`. Do not invent variants.
- For US large-cap exposure, the available basket is now: **SP500.DWX** (S&P
  500, backtest-only), **NDX.DWX** (Nasdaq 100, live-tradable), **WS30.DWX**
  (Dow 30, live-tradable).
```

Plus Zeile ~110 (P2 SATURATION RULE section). Aktuell:
```
2. R3 row narrates the portable DWX basket (e.g. "DXZ feed limitation 2026-05-16:
   SPX500.DWX has no tick data. Available index basket reduces to **NDX.DWX
   (Nasdaq 100), WS30.DWX (Dow 30), GDAXI.DWX (DAX 40), UK100.DWX (FTSE 100)** —
   four major liquid country indices.").
```

Aktualisieren so dass das Beispiel den SP500.DWX-Fall mitkennt:
```
2. R3 row narrates the portable DWX basket. With SP500.DWX now available
   (backtest-only since 2026-05-16), the US large-cap basket is **SP500.DWX
   (S&P 500), NDX.DWX (Nasdaq 100), WS30.DWX (Dow 30)**. Add GDAXI.DWX (DAX 40)
   + UK100.DWX (FTSE 100) for global multi-index baskets.
```

### 3. Prompt-Update: `tools/strategy_farm/prompts/claude_research_source.md` (Zeilen ~42–46 und ~62–72)

Beide Stellen wo „SP500/SPX500/SPY/ES are permanently unavailable in the DWX feed" steht: ersetzen durch:

```
- **SP500 → SP500.DWX (Custom Symbol, backtest-only, OWNER-provided ticks
  2018-07→2026-05).** Available since 2026-05-16T19:15Z on T1–T5. R3 PASS
  for SPY/SPX-intraday-specific edges. Card MUST note: "Live promotion
  T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on
  SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or
  WS30.DWX before AutoTrading enable." This is Board Advisor's enforcement,
  not yours — but the card must flag it in `## R3` section so it doesn't
  surprise anyone at P10.
- Other US-equity instruments (SPY ETF, ES futures, individual stocks) remain
  unavailable. Port them to SP500.DWX / NDX.DWX / WS30.DWX per the card edge.
```

### 4. Process-Update: `processes/qb_reputable_source_criteria.md` (Zeilen ~50–80)

Die R3-Sektion und die unten doppelt vorhandene „Permanently unavailable" Liste in beiden Stellen so umformulieren dass SP500.DWX backtest-fähig ist, R3 REJECT-Regel für SPY-intraday gestrichen, dafür R3 PASS mit T6-Live-Promotion-Note. Konkret die Sätze:

- „R3 REJECT if the strategy's edge specifically depends on SPY/SPX intraday cash-session microstructure with no port to WS30 or NDX that preserves the edge" → **streichen / umkehren**
- Die zweimal vorkommende Liste „**SP500 / SPX500 / SPX / SPY / ES futures** — Not in dwx_symbol_matrix.csv, cannot be added" → ersetzen durch SP500.DWX-Custom-Symbol-Status

Wortlaut-Vorlage:
```
**SP500/S&P500-equivalent strategies — backtest-only via SP500.DWX Custom Symbol:**
- `SP500.DWX` is in `dwx_symbol_matrix.csv` (since 2026-05-16). OWNER-provided
  ticks 2018-07→2026-05 on T1-T5. Suitable for P0-P9 backtest pipeline.
- **R3 PASS** for SPY/SPX-intraday-specific edges — card includes the standard
  T6-live-promotion caveat (see `claude_research_source.md`).
- `SPY` / `ES.f` / `SPX` individual instrument variants → port to `SP500.DWX`.
```

### 5. Card 1045 reopen: `QM5_1045_zarattini-spy-intraday-momentum`

```bash
# Aktueller Stand: D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1045_*.md
# Schritt 1: Card-Inhalt prüfen (was war der blocked_reason, primary symbol)
cat "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1045_zarattini-spy-intraday-momentum.md"
```

Dann die Card editieren:
- Primary symbol auf `SP500.DWX` setzen (war vermutlich SPX500 oder leer)
- R3-Sektion aktualisieren: „R3 PASS — SP500.DWX Custom Symbol verfügbar seit 2026-05-16. T6-Live-Promotion erfordert parallele NDX/WS30-Validierung (Board Advisor T6-Gate)."
- `blocked_reason` entfernen (falls vorhanden)

Anschließend physisch verschieben + bei farmctl approven:

```bash
mv "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1045_zarattini-spy-intraday-momentum.md" \
   "D:/QM/strategy_farm/artifacts/cards_approved/QM5_1045_zarattini-spy-intraday-momentum.md"

cd C:/QM/repo
python tools/strategy_farm/farmctl.py approve-card \
  --card D:/QM/strategy_farm/artifacts/cards_approved/QM5_1045_zarattini-spy-intraday-momentum.md
```

`farmctl approve-card --help` checken falls Argument-Form anders ist (`--card` vs Positional). State danach via `farmctl pipeline` verifizieren.

**Kein `build-ea` in dieser Session.** OWNER soll selbst entscheiden wann der Build läuft (Codex-Budget). Card landet in `cards_approved/` und wird beim nächsten autonomen Wake oder manuellen `farmctl build-ea` aufgegriffen.

### 6. Cards 1044, 1046–1049: NICHT auto-re-targeten

QM5_1044 (vpmacd-us-indices), 1046 (maroy-intraday-vwap-exit), 1047 (halloween-sell-in-may-idx), 1048 (estrada-lazy-6m-rotation), 1049 (mcconnell-turn-of-month) sind bereits auf NDX.DWX/WS30.DWX gepatcht und teils gebaut (siehe `framework/build/compile/2026-05-16_*`). **Nicht anfassen.** Sunk-cost-Build-Zeit nicht verbrennen. Diese Karten können später (P3+) eine zusätzliche SP500.DWX-Symbol-Slot-Registrierung bekommen, falls OWNER das wünscht — aber das ist ein separater Job, nicht Teil dieser Aufgabe.

### 7. Memory-Update (selbst, optional)

Wenn der Empfänger dieser Aufgabe ein Claude Code mit auto-memory ist: die Memories `reference_dwx_sp500_unavailable.md` und `feedback_spx500_card_port_before_build.md` wurden vom Board Advisor 2026-05-16T19:15Z bereits aktualisiert. Beim Lesen daher zur Ground-Truth nehmen, nicht die hier zitierten alten Snippets.

---

## Acceptance Criteria (alle müssen erfüllt sein)

- [ ] `git diff framework/registry/dwx_symbol_matrix.csv` zeigt **eine** neue Zeile mit `SP500.DWX,indices,...`
- [ ] `grep -i "permanently unavailable" tools/strategy_farm/prompts/ processes/qb_reputable_source_criteria.md` → **0 hits** zu SP500/SPX/SPY (oder nur historische Kontext-Hinweise, kein blocking-Statement)
- [ ] `grep -i "SP500.DWX" tools/strategy_farm/prompts/codex_build_ea.md tools/strategy_farm/prompts/claude_research_source.md processes/qb_reputable_source_criteria.md` → **mindestens 1 hit pro Datei** mit „backtest-only" + „T6-live-promotion-caveat"
- [ ] `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1045_zarattini-spy-intraday-momentum.md` existiert; rejected-Variante existiert nicht mehr
- [ ] `farmctl pipeline` zeigt QM5_1045 in einem aktiven Status (nicht `rejected`/`blocked`)
- [ ] **Smoke-Test**: `farmctl status` läuft ohne Fehler (Registry-CSV parsing bricht nicht durch neue `evidence_source` Kategorie)

---

## Out of Scope (nicht in dieser Session)

- **Kein Codex-Build von QM5_1045 starten** — OWNER triggert manuell wenn Budget passt
- **Kein Re-Targeting von QM5_1044/1046–1049** auf SP500.DWX (sunk-cost-Vermeidung)
- **Kein T6-Live-Promotion-Gate-Code schreiben** — das ist Board-Advisor-Spec-Arbeit für später, nicht jetzt
- **Kein Edit an `framework/EAs/QM5_104*`** EA-Code oder Setfiles — wenn QM5_1045 später gebaut wird, generiert Codex die Setfiles für SP500.DWX neu

---

## Leitprinzipien

- **Evidence-over-claims** (Hard Rule): Jeder Edit im Prompt-Text muss auf die SP500.DWX-Evidence verweisen (`docs/ops/evidence/2026-05-16T191500Z_sp500_dwx_custom_symbol_t2_t5_rollout.md`), nicht nur „OWNER said so".
- **Backwards-compat sanft**: Wenn Downstream-Parser auf neuer `evidence_source` Kategorie brechen, lieber auf bestehendes `path` zurückfallen statt Downstream-Code anfassen. Der CSV-Schemawandel ist nicht das Ziel.
- **Conservative scope**: Wenn beim Editieren weitere Spots im Repo auftauchen die SP500-Banning encoden (z.B. CLAUDE.md-Memos, andere Skripte), **flaggen + listen, nicht stumm mit-editieren**. OWNER entscheidet.
- **Branch**: Auf `agents/strategy-farm-policy` oder Board-Advisor-Branch arbeiten — nicht direkt main (DL-028 Worktree-Disziplin).

---

## Pfade (Quick-Reference)

| Was | Pfad |
|---|---|
| Evidence der SP500.DWX-Installation | `C:/QM/repo/docs/ops/evidence/2026-05-16T191500Z_sp500_dwx_custom_symbol_t2_t5_rollout.md` |
| Registry CSV | `C:/QM/repo/framework/registry/dwx_symbol_matrix.csv` |
| Codex-Build-Prompt | `C:/QM/repo/tools/strategy_farm/prompts/codex_build_ea.md` |
| Claude-Research-Prompt | `C:/QM/repo/tools/strategy_farm/prompts/claude_research_source.md` |
| QB-Reputable-Source-Kriterien | `C:/QM/repo/processes/qb_reputable_source_criteria.md` |
| Card 1045 (rejected) | `D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1045_zarattini-spy-intraday-momentum.md` |
| Cards-approved Ziel | `D:/QM/strategy_farm/artifacts/cards_approved/` |
| farmctl CLI | `C:/QM/repo/tools/strategy_farm/farmctl.py` |
| MT5 SP500.DWX Data (T1) | `D:/QM/mt5/T1/Bases/Custom/{history,ticks}/SP500.DWX/` |
| OWNER-supplied CSV-Quelle | `D:/QM/reports/setup/tick-data-timezone/SP500_GMT+2_US-DST*.csv` |

---

## Output am Ende der Session

Eine kurze Zusammenfassung (5–10 Zeilen) mit:
- Status der 6 Acceptance-Criteria-Checkboxen
- Geänderte Dateien (3 Prompts + 1 CSV + 1 Card-Move)
- `git log -1` + `git status` Snapshot
- Eventuelle Stolperer (Schema-Parser-Fehler, fehlende farmctl-Flags, etc.)
- Risiko-/Follow-up-Hinweise für OWNER (z.B. „Codex-Build von 1045 würde jetzt funktionieren — soll ich triggern?")
