# DL-070 — Swing / Low-Frequency Q08 (Davey) Track

**Date:** 2026-06-05
**Status:** Decided (OWNER + Claude) — ausgeliefert auf agents/board-advisor + origin/main
**Supersedes:** none — kalibriert die Trade-Count-Schwellen aus dem Q08-Davey-10-Sub-Gate-Set
**Related:** `framework/scripts/q08_davey/sub_8_8_edge_decay.py`, `sub_8_9_runs_test.py`, `project_qm_q08_subgate_miswired_2026-06-01` (8.2-Kalibrierung deferred), `project_qm_q08_funnel_dl068_2026-06-05`, `project_qm_pipeline_rewrite_2026-05-23` (Q08 Davey)

## Kontext (OWNER 2026-06-05)

OWNER: „Wenn ein EA ~10x/Jahr tradet, ist das Aussage genug — ca. 1x/Monat, für Swing-Trading
genügt das." Q08 läuft über **9 Jahre (2017-2025)**; ein ~10-Trades/Jahr-EA hat also ~**90 Trades**.
Die Davey-Sub-Gates haben absolute Mindest-Trade-Zahlen, die faktisch Hochfrequenz verlangen und
gültige Swing-EAs als **INVALID (insufficient_trade_count)** abweisen — ein Hauptgrund des leeren
Buch-Funnels. Diagnose: bei ~90 Trades sind nur **8.8 (≥200)** und **8.9 (≥100)** die Blocker;
8.6 (≥50) ist erfüllt, 8.2 ist tagesrenditen- (nicht trade-) basiert.

## Entscheidung

Swing/Low-Freq-tauglich machen, OHNE Statistiken zu verfälschen (eine 10-Punkt-Statistik bleibt
wertlos — daher Fenster an verfügbares N anpassen, nicht Schwellen blind senken):

- **8.9 runs-test:** Mindest-Trades **100 → 40**. Runs-Test ist bei ~40+ noch valide (geringere
  Power), die ~90 eines 10/Jahr-Swing-EA reichen. Der Test selbst beurteilt weiter die
  Zufälligkeit der Gewinn/Verlust-Serien.
- **8.8 edge-decay:** **adaptiv**. ≥200 Trades → präzises rolling-12mo (unverändert). 30-199 Trades
  → **erste-Hälfte vs zweite-Hälfte** der aktiven Monate (statt am 200-Floor zu scheitern; braucht
  ≥12 Monate Coverage). <30 Trades → INVALID. Die 40%-Decline-Schwelle bleibt.
- **Absoluter Floor 30 Trades** (8.8): darunter ist nichts bewertbar.
- **Unverändert:** 8.1-8.7, 8.10, die 40%-Decline-Schwelle, sowie alle absoluten P&L/DD/PF-Gates.
  8.6 (≥50) bleibt — bei OWNERs ~90 erfüllt.

## Trade-off (ehrlich)

Weniger Trades = weniger statistische Power bei edge-decay/runs-test. Das wird für den Swing-Stil
bewusst akzeptiert (OWNER-Risikoentscheidung). Der 30-Trade-Floor + die unveränderten
Robustheits-/PBO-/seasonal-/regime-Gates fangen überfittetes/sterbendes Zeug weiter ab — der Sinn
von Davey bleibt erhalten.

## Verifikation

Synthetischer 90-Trade-EA (10/Jahr, 9 Jahre): 8.8 → PASS (`mode=swing_half_vs_half`), 8.9 wird
evaluiert (vorher beide auto-INVALID). 20-Trade-EA → INVALID (Floor). Compile clean.

## Wirksamkeit

Gilt für künftige Q08-Läufe (die q08_davey-Sub-Gates werden pro Lauf importiert). Bereits als
INVALID/FAIL abgelegte Low-Freq-EAs profitieren beim Re-Run (z.B. die re-queued Q08-EAs). Falls
die terminal_worker das Modul in-process cachen, greift es spätestens nach Worker-Neustart.

## Revert-Bedingung

Wenn sich zeigt, dass Low-Freq-PASSes live nicht halten (überfittet trotz Floor), Floor/Power
nachschärfen — evidenzbasiert gegen die dann real existierende Swing-Kohorte.
