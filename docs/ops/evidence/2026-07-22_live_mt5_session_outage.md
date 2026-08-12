# 2026-07-22 — Incident: beide Live-MT5 nach Desktop-/Session-Ausfall offline

## Kurzfassung

Am 2026-07-22 verschwand die interaktive `qm-admin`-Session 3 gegen 04:04 Uhr
lokaler Zeit. Damit wurden sowohl der Darwinex-Zero-Live-Terminal (DXZ/T_Live) als
auch der FTMO-Terminal beendet. Beide Terminals liefen erst nach der erneuten
Anmeldung um 06:17:25 Uhr wieder; die gemeinsame Downtime betrug damit ungefähr
2 Stunden 13 Minuten.

Das war **kein normaler RDP-Disconnect**, kein konfigurierter Session-Timeout, kein
Benutzer-Logoff und kein Windows-Reboot. Die unmittelbare Ursache war der Verlust
des interaktiven Desktop-/Session-Kontexts. Der genaue interne Windows-Auslöser ist
nicht beweisbar; die zeitgleichen Desktop- und User-Service-Fehler sprechen für eine
Degradation des Session-/Desktop-Subsystems mit DLL-Initialisierungsfehlern unter
hohem Ressourcen-Churn. Der zweite, vollständig belegte Fehler war die Recovery-
Architektur: Der alte SYSTEM-Watchdog konnte einen `InteractiveToken`-Task ohne
vorhandene interaktive Session nicht tatsächlich starten und überwachte FTMO gar
nicht. Dadurch blieb der Ausfall bis zum nächsten Login bestehen.

Der Fix entkoppelt die Live-Recovery vom Factory-Status. Ein residenter Supervisor
im `qm-admin`-Desktop kann einen einzelnen abgestürzten Terminal auch dann neu
starten, wenn RDP getrennt ist. Ein minütlicher SYSTEM-Watchdog prüft beide Prozesse,
Supervisor, Session, Profile und Autologon. Bei bestätigtem Verlust **beider**
Terminals und fehlgeschlagener Session-Recovery fordert er einen kontrollierten
Reboot an. Autologon erzeugt danach eine neue interaktive Session; die At-Logon-
Tasks starten Terminals und Supervisor. Der Watchdog-Reboot ist technisch
ausgeschlossen, solange auch nur einer der beiden Live-Prozesse läuft.

## Auswirkung

- DXZ/T_Live: offline von ca. 04:04 bis 06:17 Uhr lokal.
- FTMO: offline im selben Zeitraum.
- Beide Live-Systeme lagen auf demselben Windows-Host und in derselben interaktiven
  Session; deshalb wurden sie durch denselben Fehler gleichzeitig getroffen.
- Es gab keinen erzwungenen Prozessabbruch und keine manuelle Änderung von
  AutoTrading. Der spätere OWNER-autorisierte V1→V2-Wechsel verwendete ausschließlich
  ein normales `WM_CLOSE` und einen validierten Startpfad; FTMO blieb unangetastet.

## Belegte Zeitleiste (Europe/Berlin)

| Zeitpunkt | Befund |
|---|---|
| 2026-07-22 04:03:56 | Sessionbezogener `UMFD-3`-Kontext wird abgemeldet. |
| 2026-07-22 04:04:06 | `Application Popup`, Event 26: `python.exe` kann mit `0xc0000142` nicht initialisiert werden. |
| 2026-07-22 04:04:08 | `DWM-3`-Kontexte werden abgemeldet; mehrere per-user Dienste der Session `_7926e2f` brechen ab bzw. können wegen `Access denied` nicht neu gestartet werden. |
| 2026-07-22 ca. 04:04 | Beide `terminal64.exe`-Prozesse verschwinden. Der letzte FTMO-Terminaleintrag um 03:04:14 Terminalzeit entspricht wegen des einstündigen Offsets etwa 04:04 lokaler Zeit. |
| 2026-07-22 04:05–06:15 | Der alte `QM_T_Live_Watchdog` läuft alle fünf Minuten. Insgesamt 27 Anläufe reichen `QM_T_Live_AtLogon` lediglich in die Task-Scheduler-Queue ein; ohne interaktive Session gibt es keine Action-Start-/Action-Complete-Ereignisse. FTMO besitzt in dieser Kette keinen Watchdog. |
| 2026-07-22 06:17:25 | Neue `qm-admin`-Session 4; beide At-Logon-Tasks starten DXZ und FTMO. |
| 2026-07-22 07:24:13 | OWNER-autorisierter DXZ-Wechsel: alter PID 11648 beendet sich nach `WM_CLOSE` sauber mit Exit 0; FTMO PID 9788 läuft weiter. |
| 2026-07-22 07:25:53–07:26:06 | DXZ PID 9524 startet in Session 4, authentifiziert Konto 4000090541, synchronisiert 1 Position/3 Orders und lädt 24 Strategie-EAs plus Account-Monitor. |
| 2026-07-22 07:29:23–07:30 | 24/24 Strategie-EAs melden `INIT_OK`; keine frischen `ERROR`/`FATAL`-Events. |
| 2026-07-22 07:49 | Residenter Session-Supervisor PID 16328 läuft in Session 4; SYSTEM-Watchdog meldet `healthy`. |
| 2026-07-22 08:19:20 | Der direkte Supervisor wird unter gesetztem Wartungsflag durch die Task-Scheduler-Instanz PID 6772 ersetzt. `RunEx` startet sie nachweislich in der getrennten Session 4 (Events 110/129/100/200); beide Live-PIDs bleiben unverändert. |

Für 04:04 gibt es weder einen System-Reboot noch einen Logoff des Kontos
`qm-admin`. Die RDS-Richtlinien standen bereits auf unbegrenzt
(`MaxDisconnectionTime=0`, `MaxIdleTime=0`, `MaxConnectionTime=0`,
`fResetBroken=0`, `fInheritReconnectSame=1`). Ein normaler RDP-Disconnect hätte die
Session und ihre Prozesse daher erhalten müssen.

Der am Vortag als gefährlich erkannte Task `QM_TSCon_Console_OnDisconnect` war seit
2026-07-21 ca. 20:49 Uhr lokal deaktiviert und lief beim Vorfall nicht. Er war
**nicht** der Auslöser dieses Incidents und bleibt dauerhaft deaktiviert. Der
separate Reboot vom 2026-07-21 19:15 Uhr war ein kontrollierter Watchdog-Reboot und
gehört nicht zur Ausfallsequenz vom 22. Juli.

## Ursachenanalyse

### 1. Unmittelbare technische Ursache

Die interaktive Session 3 und damit ihr Desktop-Kontext starben. MT5 ist eine
GUI-Anwendung und lief in genau diesem Kontext; mit dem Sessionverlust endeten beide
Terminals. Die zeitlich korrelierten `DWM`-/`UMFD`-Logoffs, der Fehler
`0xc0000142` und die ausfallenden per-user Dienste belegen eine Störung des
Session-/Desktop-Subsystems.

Der **exakte Windows-Trigger ist nicht bewiesen**. Als wahrscheinlichste Erklärung
gilt eine fortschreitende Desktop-/LSM-/DLL-Initialisierungs-Degradation unter dem
hohen Prozess-, Handle- und Desktop-Heap-Churn der Factory. Diese Einordnung ist
eine Korrelation, keine abgeschlossene Root-Cause-Bestätigung.

### 2. Warum der Ausfall 2:13 Stunden dauerte

Der alte `QM_T_Live_Watchdog` lief als SYSTEM in Session 0, überwachte nur DXZ und
rief bei einem Fehler `Start-ScheduledTask QM_T_Live_AtLogon` auf. Dieser Task nutzt
`InteractiveToken`: Ohne existierende interaktive `qm-admin`-Session kann Windows
die GUI-Aktion nicht ausführen. Der Scheduler nahm die Anforderungen an, wodurch der
Watchdog fälschlich Erfolg meldete, startete aber keine Action. 27 Wiederholungen
änderten daran nichts.

FTMO war nicht Bestandteil des Watchdogs. Die einzige bereits vorhandene
Sessionverlust-Recovery hing außerdem am Factory-Watchdog und wurde nur aktiv, wenn
die Factory eingeschaltet war. Da Factory OFF war, blieb auch der Reboot-/Autologon-
Pfad wirkungslos. Live-Uptime war damit irrtümlich an Factory ON gekoppelt.

## Umgesetzte Abhilfe

### Dual-Live-Watchdog und Startpfade

- `tools/strategy_farm/T_Live_Watchdog.ps1`
  - läuft als SYSTEM jede Minute;
  - identifiziert DXZ und FTMO über ihre exakten Executable-Pfade, nicht über einen
    unspezifischen Prozessnamen;
  - prüft gezielt die `qm-admin`-Session;
  - akzeptiert einen Prozess nur dann als gesund, wenn seine Session-ID zur
    `qm-admin`-Session gehört;
  - prüft `ProfileLast` und `[Experts] Enabled=1` für beide Terminals;
  - delegiert einen einzelnen Terminalausfall an den bereits in der User-Session
    laufenden `QM_Live_MT5_SessionSupervisor`, statt einen in `Disc` nachweislich
    nicht ausführbaren `InteractiveToken`-Demand-Start anzufordern;
  - bestätigt einen Totalausfall über zwei aufeinanderfolgende Zyklen;
  - fordert nur dann einen kontrollierten Reboot an, wenn **beide** Terminals noch
    immer fehlen, Startup-Grace und Reboot-Cooldown erfüllt sind, Autologon samt
    korrekter lokaler Domain und nichtleerem SYSTEM-lesbarem LSA-Secret bereit ist
    und alle drei Recovery-Tasks ihrem exakten Principal-/Action-/Trigger-/Settings-
    Vertrag entsprechen;
  - prüft unmittelbar vor `shutdown.exe` über zwei Prozess-APIs erneut und bricht bei
    einem unbekannten Ergebnis ab; das Wartungsflag wird nach den finalen Probes,
    unmittelbar vor `shutdown.exe` sowie in jeder Sekunde des Reboot-Countdowns neu
    gelesen. Ein Wartungsflag oder verspäteter erfolgreicher MT5-Start bricht den
    angeforderten Reboot mit `shutdown /a` ab;
  - ist unabhängig von Factory ON/OFF;
  - hält `QM_TSCon_Console_OnDisconnect` deaktiviert.
- `tools/strategy_farm/T_Live_ON.ps1` und
  `tools/strategy_farm/FTMO_ON.ps1` sind idempotent, validieren Executable und
  Profil-/Datenverzeichnis, ändern ausschließlich `ProfileLast` und `[Experts]
  Enabled`, verifizieren beide Werte vor dem Start und melden einen fehlgeschlagenen
  Prozessstart mit einem Fehlercode. Beide Process-Probes sind fail-closed und beide
  Startpfade besitzen einen globalen target-spezifischen Mutex. `-Force` wird
  abgewiesen, damit nie ein zweiter Live-Prozess entsteht.
- `tools/strategy_farm/Live_MT5_SessionSupervisor.ps1`
  - läuft resident als `qm-admin` in derselben Session wie beide MT5;
  - prüft alle zehn Sekunden per zwei Prozess-APIs, exaktem Pfad und Session-ID;
  - startet erst nach zwei bestätigten Fehlproben und nie bei Probe-Unsicherheit,
    Duplikaten, falscher Session oder Wartungsflag;
  - startet ausschließlich den fehlenden Terminal über einen separaten, versteckten
    Child-Prozess und verändert/beendet den gesunden Peer nie;
  - schreibt einen atomaren Heartbeat nach
    `D:\QM\reports\state\live_session_supervisor.json`.
- `tools/strategy_farm/Start_Live_SessionSupervisor.ps1` nutzt
  `IRegisteredTask::RunEx` mit `TASK_RUN_USE_SESSION_ID`, um den Supervisor auch in
  einer bestehenden getrennten RDP-Session Scheduler-verwaltet zu starten. Erfolg
  gilt nur, wenn Task-Engine-PID, Windows-Session, Heartbeat-PID und User-SID
  übereinstimmen. Der SYSTEM-Watchdog verwendet diesen Pfad bei fehlendem oder
  veraltetem Supervisor-Heartbeat.
- `tools/strategy_farm/install_live_uptime_tasks.ps1` registriert bzw. aktualisiert
  beide logon-only Terminal-Tasks, den residenten Supervisor (`InteractiveToken`,
  `PT0S`, Restart 255×/1 min) und den minütlichen SYSTEM-Watchdog. Demand-Starts der
  Terminal-One-Shots sind deaktiviert; nur der Supervisor erlaubt den expliziten,
  Session-gebundenen `RunEx`-Start. Außerdem deaktiviert es den unsicheren tscon-
  und den ungeprüften Hygiene-Reboot-Task.

Installation bzw. idempotente Reparatur der Task-Definitionen:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\install_live_uptime_tasks.ps1 -RunNow
```

Sicherer Diagnosemodus ohne Persistenz, Task-Start oder Reboot:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\T_Live_Watchdog.ps1 -DryRun -NoReboot
```

### Alarme und präventive Hygiene

- Der Silent-Failure-Monitor wertet den Live-Watchdog-Zustand und dessen Aktualität
  aus; kritische oder veraltete Zustände fließen in den bestehenden Gmail-Alarm.
- Der Gmail-Alarm wird stündlich statt nur einmal täglich geplant.
- `QM_StrategyFarm_HygieneReboot` ist `ENFORCE_DISABLED`. Der Altpfad kann trotz
  gesunder Live-Terminals einen erzwungenen Reboot auslösen und besitzt noch nicht
  die exakten Recovery-Verträge und die abbrechbare Wartungs-/Prozesskante des neuen
  Watchdogs. Ein späterer präventiver Reboot erfolgt erst nach separater Härtung oder
  als kontrolliertes, angekündigtes Wartungsfenster.
- `tester_cache_purge.ps1` bewahrt den beim Eintritt erfassten Factory-ON/OFF-
  Zustand. Bei Factory OFF wird kein `FactoryON_AtLogon` mehr eingereiht. Bei Factory
  ON startet der Job nach einer Bereinigung nur fehlende Worker über den interaktiven
  `WorkerDedupe`-Task, statt die gesamte Factory im 20-Minuten-Takt neu aufzubauen.
  Das beseitigt einen nachgewiesenen unnötigen Prozess-/Desktop-Churn-Pfad; ob dieser
  Churn den Session-Tod um 04:04 konkret ausgelöst hat, bleibt offen.

## Produktionsverifikation am 2026-07-22

- Installer und SYSTEM-Smoke-Test erfolgreich; LSA-Probe:
  `autologon_ready=true`, `autologon_secret_probe=present`.
- `QM_T_Live_Watchdog`: SYSTEM, Wiederholung `PT1M`, Ergebnis `0`.
- Aktueller Zustand nach kontrolliertem V2-Wechsel: DXZ PID `9524`, FTMO PID
  `9788`, Scheduler-Supervisor PID `6772`, alle Session `4`; Watchdog `healthy`,
  `session_supervisor_ready=true`, `session_supervisor_scheduler_owned=true` und
  Recovery-Task-Vertrag `true`.
- FTMO PID und Startzeit `06:17:25` blieben während des gesamten DXZ-Wechsels
  unverändert.
- Read-only Broker-API-Abschlussprobe: DXZ `Darwinex-Live` verbunden und
  Trading/Expert-Trading freigegeben (1 Position/3 Orders); FTMO `FTMO-Demo`
  ebenfalls verbunden und freigegeben (3 Positionen/0 Orders). Die bekannten
  DXZ-Tickets `3167706100`, `3168039625`, `3168039626` und `3168122102` sind
  unverändert vorhanden.
- `QM_TSCon_Console_OnDisconnect`: `Disabled`.
- `QM_StrategyFarm_HygieneReboot`: `Disabled` und im Manifest
  `ENFORCE_DISABLED`; es gibt keinen automatischen Wochen-Reboot mehr.
- FTMO-Recovery-Vertrag read-only `PASS`: Konto/Server, 12 Charts/12 EAs,
  Parameter, Presets und beide Sätze der 12 SHA-gepinnten `.ex5` stimmen.
- LSM-Probe aktuell `ok`: `qwinsta`, Logon-Enumeration und Prozess-Spawn gesund,
  `tasks_failing_count=0`. Ein absichtlich deaktivierter Factory-Task wird nicht
  mehr fälschlich wegen ausbleibender Kadenz als LSM-Degradation gezählt.
- Gmail-Alarm: von täglich auf `PT1H` korrigiert; Lauf 07:00 lokal erfolgreich und
  Alarm zur aktuellen DXZ-Profilabweichung versandt.
- Realer Cache-Purge-Lauf 07:00 lokal: Factory OFF erkannt, nur inaktiver T5-Cache
  bearbeitet, Factory-Restart übersprungen, beide Live-PIDs unverändert.
- Abschlussauswahl: 29 relevante Pytests bestanden; 13/13
  Windows-PowerShell-5.1-Parser, Python-AST-Prüfung und `git diff --check` sauber.

## Evidenz und Betriebskontrolle

Der neue Watchdog schreibt den aktuellen Zustand und eine append-only Historie nach:

```text
D:\QM\reports\state\live_uptime_watchdog.json
D:\QM\reports\state\live_uptime_watchdog.jsonl
D:\QM\reports\state\live_session_supervisor.json
```

Relevante Terminalprotokolle:

```text
C:\QM\mt5\T_Live\MT5_Base\logs\20260722.log
C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\logs\20260722.log
```

Read-only Kontrollen:

```powershell
Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" |
  Select-Object ProcessId, SessionId, ExecutablePath, CommandLine

Get-ScheduledTask -TaskName 'QM_T_Live_AtLogon','QM_FTMO_AtLogon',`
  'QM_Live_MT5_SessionSupervisor','QM_T_Live_Watchdog',`
  'QM_TSCon_Console_OnDisconnect','QM_StrategyFarm_HygieneReboot' |
  Select-Object TaskName, State

Get-ScheduledTaskInfo -TaskName 'QM_T_Live_Watchdog'
Get-Content -LiteralPath 'D:\QM\reports\state\live_uptime_watchdog.json' -Raw
powershell.exe -NoProfile -File C:\QM\repo\tools\strategy_farm\Start_Live_SessionSupervisor.ps1 -SessionId 4 -ProbeOnly

Get-WinEvent -FilterHashtable @{ LogName='System'; StartTime=[datetime]'2026-07-22 03:55'; EndTime=[datetime]'2026-07-22 04:15' }
Get-WinEvent -FilterHashtable @{ LogName='Application'; StartTime=[datetime]'2026-07-22 03:55'; EndTime=[datetime]'2026-07-22 04:15' }
```

Die Task-Scheduler-Historie unterscheidet das bloße Queuing (`110`/`325`) vom
tatsächlichen Action-Start (`129`/`200`). Das war für den Nachweis der 27
wirkungslosen Wiederstartversuche entscheidend.

## Wartung, Kill-Switch und Rollback

Vor einer geplanten Wartung wird die automatische Live-Recovery ohne Löschen von
Tasks pausiert:

```powershell
New-Item -ItemType File -Force -Path 'D:\QM\reports\state\LIVE_UPTIME_MAINTENANCE.flag'
```

Während das Flag existiert, protokollieren Watchdog und Supervisor `maintenance`,
starten keinen Terminal und fordern keinen Reboot an. Nach Abschluss:

```powershell
Remove-Item -LiteralPath 'D:\QM\reports\state\LIVE_UPTIME_MAINTENANCE.flag'
Start-ScheduledTask -TaskName 'QM_T_Live_Watchdog'
```

Als technischer Rollback der automatischen Recovery kann der Watchdog deaktiviert
werden:

```powershell
Disable-ScheduledTask -TaskName 'QM_T_Live_Watchdog'
```

Die At-Logon-Tasks bleiben dabei als Cold-Start-Schutz erhalten. Der tscon-Task darf
nicht als Rollback reaktiviert werden; er hat in einem früheren Incident selbst
Session-Arbitrations-Races verursacht. Der Hygiene-Reboot bleibt als Task
deaktiviert; sein alter Kill-Switch ist nur zusätzliche Absicherung:

```powershell
New-Item -ItemType File -Force -Path 'D:\QM\reports\state\HYGIENE_REBOOT_DISABLED.flag'
```

## Kontrollierter DXZ-Wechsel auf das genehmigte V2-Buch

Der OWNER-autorisierte Wechsel ist abgeschlossen. Das versiegelte
`DarwinexZero_V2` blieb unverändert. Weil dieses Profil den später eingeführten,
read-only `QM_AccountMonitor` nicht enthält, erzeugt
`prepare_dxz_v2_liveops_profile.ps1` deterministisch
`DarwinexZero_V2_LiveOps`: byte-identische 24 V2-Strategiecharts und `order.wnd`
plus den SHA-gebundenen Monitor als `chart25.chr`.

Post-Start-Verifikation:

- Konto `4000090541`, Server `Darwinex-Live`, verbunden; Account-, Expert- und
  Terminal-Trading jeweils freigegeben.
- 24/24 Strategie-EAs geladen und `INIT_OK`, einschließlich
  `QM5_10919_grimes-overshoot` auf XTIUSD H4, Magic `109190001`.
- Zusätzlich `QM_AccountMonitor` geladen; `account_snapshot.json` aktualisiert sich
  wieder minütlich.
- XAUUSD-Position `3167706100` (0,02 Lot) und XAUUSD-Pendings `3168039625` /
  `3168039626` blieben unverändert.
- EURUSD Buy Stop wurde erwartungsgemäß durch EA 11421 von Ticket `3168115864`,
  0,46 Lot auf Ticket `3168122102`, 0,43 Lot mit identischem Entry/SL/TP und Magic
  `114210000` neu gesetzt; dies bildet das niedrigere V2-Risikogewicht ab.
- Rollback-Sicherung:
  `D:\QM\reports\state\dxz_v2_switch_20260722_072222`.

## Was der OWNER im Betrieb tun muss

- Nichts neu starten oder AutoTrading manuell umschalten; der aktuelle Zustand ist
  vollständig aktiv und wird überwacht.
- RDP künftig mit **Disconnect/Trennen**, nicht mit **Sign out/Abmelden**, verlassen.
  Ein normaler Disconnect lässt MT5 und den residenten Supervisor weiterlaufen.
- Den Wartungsflag nur für geplante Arbeiten verwenden und danach wieder entfernen.
- Gmail-Alarme zu `live_mt5_*` nicht ignorieren. Insbesondere
  `live_mt5_session_supervisor` bedeutet, dass die schnelle Einzelterminal-Recovery
  nicht mehr bereit ist.

## Verbleibendes Risiko und Architektur-Empfehlung

Der lokale Fix reduziert die erwartete Recovery-Zeit bei erneutem Sessionverlust
von Stunden auf wenige Minuten. Er kann jedoch keine unterbrechungsfreie Verfügbarkeit
garantieren: DXZ und FTMO teilen weiterhin Host, Betriebssystem, interaktive Session,
Netzwerk und Stromversorgung. Ein Host-, Provider-, OS- oder Storage-Ausfall bleibt
ein gemeinsamer Single Point of Failure.

Für echte Isolation sind die Live-Terminals aus der Factory-/RDP-Workstation
herauszulösen, idealerweise auf einen dedizierten Live-Host; DXZ und FTMO können für
höhere Fehlerdomänen-Trennung zusätzlich auf getrennte Hosts verteilt werden. Eine
MetaTrader-Virtual-Hosting-Migration ist nur nach Kompatibilitätsprüfung zulässig
(unter anderem DLL-, Symbol-, Zeit-/News- und EA-Abhängigkeiten). Zusätzlich ist ein
**off-host** Heartbeat/Alarm erforderlich. Der bestehende Gmail-Alarm auf demselben
Windows-System erkennt einen vollständigen Host- oder Netzwerkausfall nicht zuverlässig.

## Externe technische Referenzen

- Microsoft dokumentiert, dass `tsdiscon` eine Session trennt, während laufende
  Anwendungen weiterlaufen und beim Reconnect wieder erscheinen:
  <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/tsdiscon>
- `InteractiveToken`-Tasks benötigen bereits eine interaktive Anmeldung; Session-0-
  Dienste sind kein unterstützter Desktop für GUI-Anwendungen:
  <https://learn.microsoft.com/en-us/windows/win32/api/taskschd/ne-taskschd-task_logon_type>
  und <https://learn.microsoft.com/en-us/windows/win32/services/interactive-services>
- `0x800710E0` entspricht `ERROR_REQUEST_REFUSED`; Event 325 ist nur ein
  eingereihter Startwunsch, kein Action-Start:
  <https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--4000-5999->
- `PT0S` bedeutet für einen Scheduled Task unbegrenzte Laufzeit; `IgnoreNew`
  verhindert eine zweite parallele Instanz:
  <https://learn.microsoft.com/en-us/windows/win32/taskschd/tasksettings-executiontimelimit>
  und <https://learn.microsoft.com/en-us/windows/win32/api/taskschd/ne-taskschd-task_instances_policy>
- Microsofts RDS-Richtlinienreferenz beschreibt die Disconnect-/Idle-Zeitlimits:
  <https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-terminalserver#ts_sessions_disconnected_timeout_2>
- Sysinternals Autologon speichert das Kennwort als LSA-Secret:
  <https://learn.microsoft.com/en-us/sysinternals/downloads/autologon>
- `IRegisteredTask::RunEx` bindet einen Task mit `TASK_RUN_USE_SESSION_ID` an eine
  konkrete bereits vorhandene Session:
  <https://learn.microsoft.com/en-us/windows/win32/api/taskschd/nf-taskschd-iregisteredtask-runex>
- MetaQuotes beschreibt Virtual Hosting als MT5-spezifische 24/7-Option und dessen
  Migrationsgrenzen:
  <https://www.metatrader5.com/en/terminal/help/virtual_hosting> und
  <https://www.metatrader5.com/en/terminal/help/virtual_hosting/virtual_hosting_migration>
