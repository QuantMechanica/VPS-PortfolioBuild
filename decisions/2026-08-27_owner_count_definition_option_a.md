# OWNER-Entscheid 2026-08-27 abends: Zaehldefinition >=25-Trigger → Option A

**Receipt (wörtlich):** „A" — Antwort auf die Vier-Optionen-Vorlage (Ticket 523e958f,
docs/ops/evidence/523e958f_eta_to_25_mission_control_2026-08-27.md).

## Versiegelte Definition

**STRICT_V4_CONTIGUOUS_Q14:** Ein (EA, Symbol)-Paar zaehlt fuer den >=25-Buch-Trigger
(OWNER-DEC-A1) genau dann, wenn seine kanonische v4-Evidenz **lueckenlos bis zum
terminalen Q14** durchgeht (`highest_contiguous_valid_gate = Q14`). Historische
v3-Q14-Label zaehlen nicht; die drei No-Change-Piloten zaehlen erst nach terminalem
Abschluss ihrer echten deklarierten Sweeps. Distinkte EAs und Strategie-Familien bleiben
Diversitaetskontrollen daneben (A1 unveraendert).

## Umsetzungsbindung

Mission Control rendert Option A als versiegelte Definition (Fussnote „provisorisch"
entfaellt, Decision-Referenz rein); uebrige Zaehlungen (B/C/D) duerfen als sekundaere
Diagnostik sichtbar bleiben, niemals als Trigger. Eine spaetere Uebersetzungs-Politik
fuer Alt-Evidenz (Option-C-Pfad) waere ein separater OWNER-Entscheid.
