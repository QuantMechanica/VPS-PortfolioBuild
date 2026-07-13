# Phase-1.5 Delegations-Auftrag — headless Codex: q08-Stream per-Magic

**Rolle:** headless Codex. **PM:** Claude. **Worktree:** `agents/codex-master-ea-p15`
(nie main, nie T_Live). **Non-live, reversibel.**
Kontext: `docs/ops/MASTER_EA_SYMBOL_CONSOLIDATION_PLAN_2026-07-13.md` (Phase 1.5).

## Befund (aus Phase-1-Review)

Der q08-JSONL-Writer (`framework/include/QM/QM_Common.mqh`, Two-Pass-History-Walk beim
OnDeinit) sammelt owned position_ids und emittiert TRADE_CLOSED-Rows, aber **ohne die
Eröffnungs-Magic je Row**. Es entsteht EINE Host-EA-Datei. Für den Master-EA (mehrere
Sub-Magics in einer Instanz) lässt sich der Stream so NICHT je Strategie zerlegen.

## Auftrag

Jede q08-TRADE_CLOSED-Row um ein Feld **`"magic"`** ergänzen = die Magic des
**Eröffnungs-Deals** dieser Position (der Two-Pass-Walk kennt die Ownership bereits über
die Eröffnungs-Deal-Magic; genau diese Magic in die Row schreiben).

## Anforderungen

- **Backward-kompatibel als Format-SUPERSET:** bestehende Konsumenten (portfolio_common
  `load_streams`/`to_daily_pnl`, Q08/Q09-Aggregatoren, live_book_pulse) dürfen nicht
  brechen — sie ignorieren unbekannte Felder oder nutzen `net`/`time`. Ein neues Feld ist
  additiv. NICHT bestehende Feldnamen umbenennen.
- Single-Magic-EAs: die Row trägt schlicht die (einzige) Host-Magic — kein Sonderfall.
- Keine anderen Streams/Serializer anfassen. Zwei-Pass-Ownership-Logik unverändert lassen,
  nur das Magic-Feld ergänzen.

## Acceptance-Gate (MUSS grün)

`QM5_12567_cum-rsi2-commodity` XAUUSD.DWX D1 nach dem Change force-rebuilden + Full-History
2017–2025 Model 4 backtesten (T6–T10). Es MUSS:
1. weiter **73 Trades / Net $4.676,76** centgenau liefern (kein Verhaltens-Regress), UND
2. **jede Row `"magic":125670003`** tragen (die registrierte 12567/XAU-slot3-Magic).
Beweise beides im Report (Trade/Net + ein `head` der JSONL mit dem magic-Feld).

## Deliverable

PR auf `agents/codex-master-ea-p15`: die Serializer-Änderung, kurze Design-Notiz, der
grüne Gate-Nachweis (Zahlen + JSONL-Row-Beispiel). Claude reviewt + fährt das authoritative
Gate + merged. Keine Master-EA-Arbeit (das ist Phase 2).
