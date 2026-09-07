# OWNER-Vorlage 2026-09-07 — B′: Kriterienbeschluss für den Newskalender (ROT)

Stand 05:35Z (lokal 07:35), CEO-Loop. Folge deines JA zur Karte OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907.
Evidenz: `docs/ops/evidence/2026-09-07_f3a94b87_scoped_calendar_b_activation.md` (+ Dry-Run-JSON),
`docs/ops/evidence/2026-09-07_news_calendar_e1d34_continuation.md`, `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect/`.

## Was dein JA (Option B) heute gebracht hat

Consumer B ist aktiviert, fail-closed, mit Marker und Fußnote. Der Produktions-Dry-Run über alle 47 wartenden Q10_NEWS-Zeilen:
**0 zulässig, 47 ausgeschlossen.** Gründe (Mehrfachnennung): 38 ohne versiegeltes Q10-Fenster, 30 Intraday (H1/H4/M5/M1),
19 mit Nicht-USD-Exposition, 9 mit Deklarationsüberlappung. **11196/XAUUSD (a909ee18) ist ein H4-EA → ausgeschlossen.**

Zwei Dinge daraus:
1. **9 D1/USD-Zeilen** (12567, 1556×2, 10513×4, 10145/SP500, 1230/XAUUSD) scheitern *nur* am fehlenden Fenster-Siegel. Das ist
   Handwerk (Codex-Ticket läuft: Nachfolgezeilen mit Fenster aus der Q09-Linie, append-only). Danach kann ich sie zeilenweise
   freigeben — unter deinem bestehenden JA, ohne neue Entscheidung.
2. **Alle Intraday-Zeilen — und damit 11196 — bleiben ausgeschlossen**, weil B nach E1-C nur D1 zulässt. Der Grund für die
   D1-Grenze war der Zeitstempeldefekt (US-08:30-ET-Releases ~17 h zu früh): Intraday-EAs sind ihm ausgesetzt, D1-EAs faktisch nicht.

## Der Punkt

Der Kandidatenkalender aus E1-D3/D4 hat genau diese USD-08:30-ET-Zeilen **aus dem nativen MT5-Export korrigiert** (Join gegen
2 440 native Zeilen, NFP/Retail/CPI/Claims 100 % verschoben und ersetzt, Input-Drift 0, alle offiziellen Instants ingestiert).
Was am Kandidaten „fehlt", sind Dinge, die es strukturell nicht geben kann: 1 865 Event-by-Event-Zeilen ohne offiziellen
Zeitplan und Tick-Footprints jenseits der Fabrik-History (endet 31.12.2024). Unter den heutigen Gate-Kriterien kann der Kandidat
deshalb nie „gemessen PASS" werden — obwohl er für USD-Exposition nachweislich besser ist als das gepinnte Bundle.

## Entscheidung B′ (ROT — Gate-Kriterium; keine Auffangregel)

**Frage:** Darf der Kandidatenkalender (Manifest 5f28c2f3…, Bindung b12615d8…) als Adjudikationsbasis für Q10_NEWS gelten für
**USD-exponierte Zeilen aller Timeframes**, mit **deklarierten Residuen** (Nicht-USD-Klassen und Event-by-Event-Einträge
ohne offiziellen Zeitplan bleiben ausgeschlossen bzw. halten die betroffenen Zeilen) — statt „alle acht Gates gemessen PASS"?

| Option | Inhalt | Wirkung | Risiko |
|---|---|---|---|
| **JA = B′ (Empfehlung)** | Kriterium: Vollsiegel = gemessene Gates + *deklarierte* Residuen für strukturell unankerbare Klassen und Instants außerhalb der History; Consumer-B-Zulässigkeit von D1 auf alle Timeframes erweitert, sofern die Exposition USD-only ist oder die Nicht-USD-Klassen der Zeile deklariert ausgeschlossen sind | 11196/XAUUSD (H4, USD-exponiert) wird adjudizierbar; weitere Intraday-USD-Zeilen ebenso; Nicht-USD-Zeilen bleiben gehalten | Adjudikation auf einem Kalender, der für Nicht-USD nicht verifiziert ist — genau deshalb bleiben diese Zeilen draußen; Re-Adjudikation, sobald ein besserer Kalender gepinnt wird (append-only) |
| NEIN | Kriterien unverändert; B bleibt D1-only | 9 D1-Zeilen nach Fenster-Siegel; 11196 und alle Intraday-Zeilen bleiben stehen | Zähler-Pfad für Intraday-Paare bleibt ohne Endpunkt |
| VERTAGT | — | wie NEIN bis zur Wiedervorlage | — |

**Empfehlung: JA.** Es ist eine Kriterienänderung, deshalb deine Entscheidung; sie ersetzt aber kein Messen durch Behaupten:
gemessen wird weiter alles Messbare, deklariert wird nur, was nachweislich nicht messbar ist, und jede so adjudizierte Zeile
trägt den Marker und die Fußnote.

## Was ein JA auslöst — genau ein Claude-Auftrag

1. Codex-Ticket: Kriterium im Kalender-Gate-Vertrag (`news_calendar_gate` / `full_scope_seal`) als „measured + declared residual"
   formalisieren; Consumer-B-Admissibility auf alle Timeframes bei USD-only-Exposition erweitern (Nicht-USD-Klassen je Zeile
   deklariert ausgeschlossen = Zeile bleibt gehalten); Tests; Dry-Run-Liste neu.
2. Zeilenweise Freigabe (append-only), 11196 zuerst; Fußnote bleibt; Re-Adjudikationsticket 235e5119 bleibt an einen späteren
   besseren Kalender gebunden.
3. Kein Repin des Produktionsbundles, kein Publish, kein T_Live, keine Schwellenwertänderung an Q-Gates.

## Was ein NEIN auslöst

Dokumentation; die 9 D1-Zeilen laufen nach dem Fenster-Siegel; alles Intraday bleibt gehalten.

## Rollback

Kriterium zurücksetzen, Consumer-Konfiguration auf D1-only; adjudizierte Zeilen bleiben als markierte Evidenz erhalten
(append-only), werden bei Bedarf neu adjudiziert. Verdikte werden nie überschrieben.
