# OWNER-Vorlage 2026-09-07 — Zähler-Pfad steht am Kalender-Taint (ROT-Entscheid: Option B fürs Zählen?)

Stand 02:45Z (lokal 04:45), CEO-Loop. Evidenz: `docs/ops/evidence/2026-09-07_news_calendar_e1d_full_scope_seal.md`,
`docs/ops/evidence/2026-09-06_dsr-single-config-declaration-20260906_5bf3bf5e_execution.md`, OPEN_ITEMS-Addenda 01:50Z/02:00Z.

## Lage in fünf Sätzen

1. Die DSR-Ausführung (dein JA vom 06.09.) ist abgenommen: **11196/XAUUSD** hat Q08 mit DSR V2 bestanden, Q09 bestanden
   und steht seit 00:55Z in **Q10_NEWS** (Zeile a909ee18). 11167/XAUUSD ist ausgeschieden (FAIL_SOFT, Saisonalität + PBO).
2. Q10_NEWS ist seit 05.09. **bewusst stillgelegt**: der gepinnte Newskalender (Bundle 86b2c0b5) ist als tainted erklärt
   (US-08:30-ET-Releases ~17 h zu früh, Loch 2025-05..2026-06). 47 Q10_NEWS-Zeilen warten im Taint-Hold, 0 laufen.
3. Die Reparaturkette E1-A/B1/B2/B3 ist integriert, aber der Kandidatenkalender ist **scope-begrenzt**: 4 von 8 Gates
   gemessen PASS, 4 (Ankeranteile, Nicht-USD-Abdeckung, Tick-Footprints, Detektor) nur per 18 279 Ausschlussdeklarationen.
   Du hast am 05.09. entschieden: **A bleibt** (tainted Bundle gepinnt), scoped consumer B nur als inaktive Implementierung.
4. E1-D (heute Nacht, Codex) hat den Vollsiegel-Versuch ehrlich gemessen: **NOT_READY**. Offen: AUD/CAD-M5-Exporte fehlen,
   EUR/JPY/AUD/CAD-Anker unbestätigt, 2 591 HIGH-Zeilen unverifiziert, ein Manifest-Input gedriftet. Folgeaufträge E1-D2
   (Exporte) und E1-D3/D4 (Anker, Detektor, Kandidat neu bauen, acht Gates, Dry-Run-Repin) laufen bei Codex.
5. **Konsequenz für den Zähler:** Kein Paar kann über Q10_NEWS zählen, solange kein untainted Bundle gepinnt ist. Der Zähler
   bleibt strukturell bei 12/25, unabhängig vom Fabrikdurchsatz (98–120 Zensus-Zellen/h laufen weiter, Q02-Intakes laufen).

## Cost of Wait

- Pro Tag Wartezeit: 0 Zählerfortschritt; 47 fertige Kandidatenzeilen (+ 11196) altern im Hold. Fabrikevidenz (Q02–Q09) läuft
  weiter und ist nicht betroffen.
- Realistische Dauer des Vollsiegels: **Tage, nicht Stunden** (Datenbeschaffung für Nicht-USD-Anker, zwei M5-Exporte über die
  Export-Lane, 2 591 Zeilen verifizieren, Kandidat neu bauen). Frühester ehrlicher Termin: Mittwoch 09.09., ohne Garantie.

## Optionen

| Option | Inhalt | Wirkung auf den Zähler | Risiko |
|---|---|---|---|
| **A (Empfehlung heute)** | Vollsiegel abwarten (E1-D2–D4), Q10_NEWS bleibt im Hold; Wiedervorlage Mittwoch 09.09. | 0 bis zum Repin, danach 47 Zeilen + 11196 fließen | Zeit; Zähler-Ziel verschiebt sich |
| **B (ROT, deine Entscheidung)** | Scoped consumer B **aktivieren**: Q10_NEWS adjudiziert gegen den Kandidatenkalender mit deklarierten Ausschlüssen; Intraday-/nicht-USD-exponierte Paare bleiben per Deklaration ausgeschlossen (bleiben im Hold); D1-Paare mit USD-Ankern werden adjudiziert und zählen | Sofort: die D1-USD-Teilmenge der 47 Zeilen + 11196 kann Q10_NEWS passieren und weiterlaufen (Q11–Q14) | Evidenz ist scope-begrenzt; jedes so gezählte Paar trägt die Fußnote „Kalender scope-begrenzt", Re-Adjudikation nach Vollsiegel (append-only) |
| C (ROT, nicht empfohlen) | Q10_NEWS aus dem Zählpfad nehmen (Zählregel OWNER-DEC-A1 ändern) | Sofort, aber ohne News-Evidenz | Widerspricht „Evidenz vor Zählerstand"; nicht empfohlen |

**Empfehlung:** heute **A** (NEIN zu B), mit fester Wiedervorlage am Mittwoch 09.09. 08:00: liefert E1-D3/D4 bis dahin kein
Vollsiegel-Dry-Run, empfehle ich B für die D1-USD-Teilmenge (dann als eigener JA-Entscheid).

Warum nicht sofort B: B zählt Paare auf einer Evidenz, die du am 05.09. bewusst als „nur inaktiv" eingestuft hast; die
Vollsiegel-Arbeit ist beauftragt und kostet nur Zeit, keine Evidenzqualität. Zwei Tage Wartezeit sind billiger als eine
Zählung, die wir nach dem Repin wieder anfassen müssten.

## Was ein JA (= Option B) auslöst — genau ein Claude-Auftrag

1. Codex-Ticket: scoped consumer B aktivieren (Konfiguration + Taint-Policy: Lift nur für Zeilen, die B adjudiziert; alle
   anderen bleiben im Hold), Zähler-Fußnote in Cockpit/OPEN_ITEMS/Vault, Re-Adjudikationspflicht nach Vollsiegel als Ticket.
2. Freigabe der 47 + 1 Zeilen zeilenweise (append-only, nie Verdict-Overwrite), priority_track auf 11196.
3. Kein Repin, kein Kalender-Publish, kein T_Live, kein Gate-Schwellenwert.

## Was ein NEIN (= Option A) auslöst

Dokumentation (Vault/OPEN_ITEMS), Wiedervorlage Mittwoch 09.09. 08:00 als To-Do, E1-D2–D4 laufen weiter. Kein Code.

## Rollback

B ist reversibel: Policy wieder auf „inaktiv", freigegebene Zeilen bleiben als Evidenz erhalten (append-only), Zähler-Fußnote
bleibt bis zur Re-Adjudikation. Verdikte werden nie überschrieben.

## Nachtrag 03:05Z — E1-D2/D3/D4 gemessen: das „Vollsiegel" ist mit Datenarbeit allein NICHT erreichbar

Codex hat beide Folgeaufträge in der Nacht abgeschlossen (ehrlich, fail-closed, 75 Tests):
- **E1-D2:** AUDUSD/USDCAD-M5-Exporte über die governed `T_Export`-Lane erzeugt (kein T1–T10/T_Live berührt). Die
  Footprint-Prüfungen scheitern trotzdem: **sechs der sieben AUD/CAD-Instants liegen 2025, die Fabrik-Custom-History endet
  am 31.12.2024** — dort kann kein Tick-Footprint existieren. Gate 6.5 gesamt: 27 PASS / 24 FAIL_FOOTPRINT, davon ein
  Großteil außerhalb der History.
- **E1-D3/D4:** alle neun angefragten offiziellen Instants ingestiert (58 Anker), Kandidat auf aktuellen Hashes neu gebaut
  (Input-Drift 0), Detektor-Zeilen adjudiziert: **39 Klassen / 726 Zeilen** sind über offizielle Zeitpläne ankerbar,
  **40 Klassen / 1 865 Zeilen sind Event-by-Event-Einträge ohne offiziellen Zeitplan** und bleiben strukturell „deklariert".
  GBP/AUD-2026-H1-Exporte tragen gemischte Offsets (DST-Regime) und bleiben ausgeschlossen. Gates 6.1/6.2/6.5/6.7 FAIL,
  Ingress REFUSED, kein Repin.

**Was das heißt:** Ein Kalender, bei dem alle acht Gates *gemessen* PASS sind, ist nicht durch mehr Datenarbeit erreichbar:
1 865 Zeilen haben keine offizielle Quelle, und Footprints jenseits der History gibt es nicht. Option A („warten") würde
auf ein Siegel warten, das es unter den heutigen Gate-Kriterien nicht geben kann.

**Geänderte Empfehlung:** **JA = Option B jetzt** — scoped consumer B aktivieren, Zählung nur für die D1/USD-Teilmenge mit
deklarierten Ausschlüssen, Fußnote „Kalender scope-begrenzt", Re-Adjudikation, sobald ein Kriterienbeschluss (Option B')
das Siegel mit *deklarierten* Residuen zulässt. Alternativ B': die Gate-Kriterien so fassen, dass strukturell unankerbare
Event-by-Event-Klassen und Instants außerhalb der History als deklarierte Residuen zulässig sind — das ist eine
Kriterienänderung (ROT), die ich dir als eigene Karte vorlege, wenn du sie willst. Evidenz:
`docs/ops/evidence/2026-09-07_news_calendar_e1d2_m5_exports.md`, `…_e1d34_continuation.md`.

