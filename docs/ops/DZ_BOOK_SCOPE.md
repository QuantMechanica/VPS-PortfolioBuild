# DZ_BOOK_SCOPE — was für Darwinex Zero gilt und was eine Bewertung kosten würde

**Stand:** 2026-08-19 · Work Order Runde 7 §6.5
**Umfangsklärung. Nichts gerechnet.**

---

## 0 · Der Befund, der die Frage vor der Frage beantwortet

> **Das DZ-Erfolgs-KPI ist im Bestand nicht dokumentiert.** Ich habe keine Stelle gefunden, die
> festhält, **was Darwinex Zero misst, um Fremdkapital zuzuteilen.** Ohne diese Größe ist die Frage
> „schlägt ein neu konstruiertes Buch das bestehende" nicht beantwortbar — es gibt kein „besser".

Das ist keine Nebensächlichkeit, sondern der Grund, warum diese Frage seit Runde 1 liegen geblieben
ist: die FTMO-Spur hatte eine scharfe, extern gesetzte Zielgröße (+10 % in 60 Tagen, −5 %/−10 %), die
DZ-Spur hat im Bestand keine.

**Der einzige verifizierte DZ-Plattformwert, den ich finden konnte**, ist eine Nebenbedingung, kein
Ziel: `DXZ_COMMISSION_RESEARCH_2026-06-01.md` hält fest, dass **D-Score > 60 / Professional** bis zu
−40 % Kommissionsnachlass bringt, und legt für Backtests ausdrücklich den **Standardsatz ohne
Nachlass** fest.

---

## 1 · Was für DZ nachweislich gilt (aus dem Bestand)

| Größe | Wert | Quelle |
|---|---|---|
| Summierte Sleeve-Risikoallokation | **9,75 %** des Kontos | `DXZ_BOOK_ADMISSION_1567_12474_2026-07-15.md` |
| Allokationseinheit | Konto-Prozentpunkte, eine Risikoskala für Cap und Allokation | `DXZ_PORTFOLIO_RESIZE_REMEDIATION.md` |
| Kommissionsbasis für Backtests | Standard, **kein** D-Score-Nachlass | `DXZ_COMMISSION_RESEARCH_2026-06-01.md` |
| Qualifikations-Selektor (Q6-Buch) | Trainingsfenster 2018-07-01…2022-12-31 · ≥ 20 Round Trips · kommissionsbereinigter Trainings-PF ≥ 1,10 · absolute monatliche Korrelation ≤ 0,30 · ein ökonomisch eigener Mechanismus je Platz | `DXZ_Q6_QUALIFICATION_BOOK_DESIGN_2026-07-16.md` |
| Live-Betrieb | „DXZ v2 LiveOps profile", versiegeltes `chart09.chr`, Vorbereitung über `prepare_dxz_v2_liveops_profile.ps1` | `2026-08-13_tlive_recovery_chain_and_wu_reboot.md` |

**Was ausdrücklich fehlt:** kein Zeitfenster, kein Gewinnziel, kein Tagesverlustlimit, keine
statische Gesamtverlustgrenze. **Genau die vier Größen, an denen die gesamte FTMO-Analyse hängt,
gelten hier nicht.**

## 2 · Die Buchgröße konnte ich nicht verifizieren — und das ist selbst ein Befund

Die Work Order nennt **24 Strategien live**. Ich kann das aus den Artefakten nicht bestätigen:

| geprüft | gefunden |
|---|---|
| neueste Portfolio-Manifest-Datei auf D: | `portfolio_manifest_tlive_DRAFT_2026-06-26_deploy.json` — **6 Sleeves**, Status `DRAFT_FOR_OWNER_APPROVAL`, vom 26.06. |
| `T_Live\MT5_Base\MQL5\Experts` | **64 `.ex5`**, überwiegend **nicht** QM5-benannt (`BlackCrows WhiteSoldiers CCI`, `BullishBearish Engulfing MFI` …) |
| `T_Live` Chart-Profile | 115 `.chr` |

**Drei Quellen, drei verschiedene Zahlen, keine davon 24.** Ich nenne die 24 deshalb nicht als
bestätigt — das wäre Nachsprechen, keine Prüfung.

> **Erster Umfangsbefund: das Live-Buch hat kein auffindbares, aktuelles, autoritatives Manifest.**
> Bevor irgendetwas gegen das bestehende Buch verglichen wird, muss feststehen, **was das bestehende
> Buch ist.** Das ist eine Stunde Arbeit, keine Rechnung — und es ist die Voraussetzung für alles
> Weitere.

## 3 · Was aus der FTMO-Arbeit übertragbar ist

| Größe | übertragbar? | Begründung |
|---|---|---|
| **Renditeverteilung je Sleeve** | **ja, unverändert** | Eigenschaft der Trade-Reihe, nicht der Plattform |
| **Ko-Exzedenz / gemeinsame Tagesamplitude** | **ja** | dieselbe Rechnung; sie beschreibt das Buch, nicht die Regel |
| **Korrelationsstruktur** | **ja** | und sie ist bei DZ sogar *zentraler*: der Q6-Selektor führt Korrelation ≤ 0,30 als hartes Kriterium |
| **Überlebensdauer bis zum Bruch** | **nein** | „Bruch" ist als −5 %/−10 % definiert; ohne diese Limits existiert das Ereignis nicht |
| **Bestehenswahrscheinlichkeit P(P1), E[Versuche]** | **nein** | kein Challenge-Fenster, keine Versuche, keine Gebühr |
| **Sizing-Schranke 0,44×–0,50×** | **nein** | sie folgt aus dem 5-%-Tageslimit. Bei DZ ist die bindende Größe die 9,75-%-Summenallokation |
| **Intraday-Pfad gegen ein Tageslimit** | **nein für die Zulassung**, ja für die Bewertung | ohne Tageslimit ist der Intraday-Tiefpunkt kein Ausschlusskriterium mehr — er bleibt aber für die Kapitalgeber-Wahrnehmung relevant |
| **Der gesamte Obergrenzen-Beweis** (`UPPER_BOUND_CALC.md`) | **nein** | er misst gegen die 80-%-Bar, ein FTMO-Konstrukt |

**Das ist die eigentliche Nachricht dieses Dokuments:** von sechs Revisionen Audit sind **drei
Größen** übertragbar — Rendite, Ko-Exzedenz, Korrelation. Der Rest ist an FTMO-Nebenbedingungen
gebunden und für DZ wertlos.

**Und deshalb kann das DZ-Buch tatsächlich besser dastehen:** die Sleeves, die an der 0,44×-Schranke
und am 5-%-Tageslimit scheitern, scheitern an Bedingungen, die bei DZ nicht existieren. Das ist die
einzige offene Frage der Serie, die noch nach oben zeigen könnte — die Work Order hat darin recht.

## 4 · Was eine Bewertung kosten würde

| Schritt | Kosten | Fabrikzeit |
|---|---|---|
| 1 · **Live-Buch feststellen** — autoritatives Manifest, Sleeve-Liste, Allokationen, seit wann live | ~1 h | **keine** |
| 2 · **DZ-Erfolgs-KPI klären** — was misst die Plattform, was löst Allokation aus | Recherche + OWNER-Bestätigung; **nicht aus dem Bestand beantwortbar** | keine |
| 3 · **Bestehendes Buch nachrechnen** unter dem KPI aus Schritt 2 | Rechnung auf vorhandenen Streams | **keine**, sofern die Sleeves Streams haben |
| 4 · **Neues Buch konstruieren** aus dem Q6-Selektor über den heutigen Bestand | Rechnung; der Selektor existiert bereits als Code | **keine** |
| 5 · **Vergleich** unter demselben KPI | Rechnung | keine |
| 6 · Fehlende Streams nachziehen | je Paar ein Q08-Lauf | **nur falls Schritt 3 Lücken zeigt** |

**Größenordnung: ein bis zwei Tage Analyse, null bis wenige Fabrikstunden** — deutlich billiger als
der vereinte Batch, den Runde 5 bepreist hat. Der teure Teil ist Schritt 2, und der ist keine
Rechnung, sondern eine Klärung.

## 5 · Empfehlung zum Umfang

**Eine eigene Runde wert — aber erst nach Schritt 1 und 2.** Schritt 3 bis 5 ohne geklärtes KPI zu
rechnen, würde denselben Fehler wiederholen, den diese Serie sechs Revisionen gekostet hat: eine
Zielgröße anzuwenden, bevor geprüft ist, ob sie die richtige ist.

**Vorschlag:** Schritt 1 nehme ich mit, sobald die Fabrik wieder Kapazität hat — er kostet nichts und
beantwortet nebenbei, ob die 24 stimmen. Schritt 2 braucht OWNER oder eine Quelle.
