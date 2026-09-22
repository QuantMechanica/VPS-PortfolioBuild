# Naechster persoenlicher Schritt

Der OWNER wohnt in Oesterreich. Recherche und technische Vorbereitung laufen ohne kostenpflichtiges Konto. Die notwendige erste Registrierung ist bei [Databento](https://databento.com/): Historical / Usage-based, vorerst ohne laufendes Datenabo.

1. Persoenlich registrieren und E-Mail bestaetigen. Bestehende Konten wiederverwenden; keine zweite Identitaet fuer Startguthaben erstellen.
2. Datenverwendung und Kontotyp wahrheitsgemaess bestaetigen. Wohnland, Staatsangehoerigkeit, Nonprofessional-Status und Unternehmensnutzung sind unterschiedliche Angaben.
3. Angezeigtes Startguthaben und Zahlungsbedingungen pruefen. Oeffentlich beworben sind $125 fuer berechtigte neue Teams, sechs Monate gueltig; der Kontobefund entscheidet. Kein $199-Monatsabo fuer den historischen Pilot erforderlich.
4. Im API-Keys-Bereich einen passenden Key erstellen und auf dem QM-Windows-Rechner die Desktop-Verknuepfung **Databento API-Key lokal speichern** oeffnen. Das maskierte Eingabefeld schreibt eine mit Windows CurrentUser-DPAPI verschluesselte Datei unter `D:/QM/futures_lab/private/databento.dpapi`. Zugriff erhaelt der angemeldete Windows-Benutzer sowie SYSTEM; entschluesseln kann der angemeldete Benutzer. Der aktuelle Codex-Prozess laeuft als `qm-admin`. Eingabe unter einem anderen Benutzer ist daher ungeeignet.
5. Im Chat reicht danach **Schluessel lokal gespeichert**, plus das angezeigte Guthaben und eventuelle Zahlungs-/Lizenzhuerden. Den API-Key nicht in Chat, Git oder Google Drive kopieren. Das Eingabefenster sendet keine Anfrage; danach erfolgen zunaechst kostenlose Metadaten-/Preisabfragen.

Falls die Desktop-Verknuepfung fehlt, dieses Skript auf dem QM-Rechner unter demselben Windows-Benutzer starten:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy RemoteSigned -File D:\QM\worktrees\codex-futures-pivot-20260922\tools\futures_lab\Set-DatabentoKey.ps1
```

Der Schluessel wird nicht als Kommandozeilenargument oder dauerhafte Umgebungsvariable hinterlegt. Die lokale Absicherung schuetzt die gespeicherte Datei; Prozesse mit denselben Benutzerrechten und Windows-Administratoren gehoeren weiterhin zur Vertrauensgrenze.

Vor einem Datendownload wird der exakte Request bepreist. Der vorbereitete erste MES-Request ist in `tools/futures_lab/data_requests.json` begrenzt; unbekannte Kosten oder fehlende Kontraktdefinitionen blockieren den Download.

Eine Prop-Challenge kommt nach einem wirtschaftlich tragfaehigen, kostengestressten Holdout und bestaetigter Plattformanbindung. Fuer den Kauf werden die aktuellen Regeln/Preise erneut gelesen. Noch benoetigte Providerklarstellungen sind im Report enthalten; es wurde keine Nachricht an Anbieter gesendet.

## Vorbereitete Fragen an MyFundedFutures

Diese Vorlage wurde nicht versendet. Sie kann bei der spaeteren Anmeldung dem Support gestellt werden:

> I am resident in Austria and plan to run my own low-frequency NinjaScript strategy on a privately controlled Hetzner Windows server, with no VPN/location masking, no shared strategy execution and no third-party account management. Is that exact setup permitted in the current Rapid EOD 50k evaluation, Sim Funded and subsequent Live account? Which NinjaTrader connection and license are included in each phase, and what additional platform, CME data and professional fees apply? Please confirm whether the first $500 payout request requires $2,600 net Sim profit so that the $2,100 buffer remains afterwards, and how the trailing loss floor changes after the debit.

## Vorbereitete Fragen an Tradeify

> I am resident in Austria and would use a personally owned, exclusive low-frequency bot. Your FAQ permits VPS trading after a normal login. Does normal login mean the web dashboard on my personal device, and may the NinjaTrader trading connection itself authenticate and reconnect on my privately controlled Hetzner Windows server? Please confirm the permitted connector/license for Select evaluation, Select Flex and Elite Live, the ownership/exclusivity evidence required for an independently developed strategy, and the exact loss floor after the first payout.

Quellen: [Databento Preise](https://databento.com/pricing), [MFFU Automatisierung](https://help.myfundedfutures.com/en/articles/8444599-fair-play-and-prohibited-trading-practices), [Tradeify VPS-FAQ](https://help.tradeify.co/en/articles/12268494-common-faqs), [Tradeify Bot-Regeln](https://help.tradeify.co/en/articles/10468318-guidelines-for-traders).
