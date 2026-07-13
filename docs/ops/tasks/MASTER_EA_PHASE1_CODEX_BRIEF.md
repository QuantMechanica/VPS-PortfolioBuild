# Phase-1 Delegations-Auftrag — headless Codex: Framework-Multi-Magic

**Rolle:** headless Codex (Framework-Executor). **Auftraggeber:** Claude (PM).
**Kontext:** `docs/ops/MASTER_EA_SYMBOL_CONSOLIDATION_PLAN_2026-07-13.md`.
**Worktree:** `agents/codex-*` (nie direkt main). **Non-live, reversibel.**

## Auftrag

Das V5-Framework so erweitern, dass EIN EA mehrere Strategien mit je eigener Magic +
eigenem Risk fahren kann — **rückwärtskompatibel** (bestehende Single-Magic-EAs unverändert).

## Anforderungen

1. **Multi-Magic-Kontext.** Heute: `QM_FrameworkInit(ea_id,...)` setzt EIN
   `g_qm_fw_magic = QM_MagicChecked(ea_id, slot, _Symbol)`; `QM_FrameworkMagic()` gibt es
   zurück. Neu: eine API, die pro Sub-Strategie einen Magic-Kontext (sub_ea_id, sub_slot →
   Magic) bereitstellt, ohne die globale Single-Magic-Semantik für Alt-EAs zu brechen.
   Vorschlag: `QM_MagicFor(int ea_id, int slot)` (dünner Wrapper um `QM_MagicChecked`) +
   ein optionaler per-Call-Magic-Pfad in der Trade-Schicht.
2. **`QM_TM_OpenPosition`**: per-Call-Magic akzeptieren. Wenn der Aufrufer eine explizite
   Magic übergibt, diese verwenden; sonst wie bisher `g_qm_fw_magic`. Prüfen, ob
   `QM_EntryRequest` bereits genug trägt (symbol_slot) — falls ea_id fehlt, ergänzen.
3. **Per-Strategie-Risk.** `QM_LotsForRisk`/RiskSizer: ein per-Call-Risk%-Pfad, damit jede
   Sub-Strategie mit eigenem RISK_PERCENT sizen kann. Der Hard-Cap-Schutz bleibt.
4. **q08-Stream:** nichts ändern — der Two-Pass-Walk ordnet bereits über die Eröffnungs-
   Magic zu. Nur sicherstellen, dass per-Call-Magic korrekt in den Deals landet.
5. **Rückwärtskompatibilität:** Default-Pfad (kein per-Call-Magic/Risk) = bit-identisches
   Verhalten. Keine Signatur-Brüche an bestehenden Aufrufen (überladen/optional-Parameter).

## Acceptance-Gate (MUSS grün sein, sonst kein Merge)

Ein bestehender Single-Magic-EA (nimm **QM5_12567_cum-rsi2-commodity**, XAUUSD.DWX D1)
nach dem Change **force-rebuilden** (compile_one erzwingt echten Build) und Full-History
2017–2025 Model 4 backtesten. Der q08-Stream MUSS die verifizierte Referenz **centgenau**
reproduzieren: **73 Trades / Net $4.676,76** (13.07.-Sweep, `docs/ops/evidence/dxz23_verification_sweep_2026-07-12.md`).
Abweichung = Regression = Blocker.

## Deliverable

PR auf `agents/codex-*` mit: Framework-Änderungen, kurzer Design-Notiz (welche Funktionen,
warum rückwärtskompatibel), dem grünen 12567-Regressions-Report-Pfad. Claude reviewt +
merged. KEINE EA-Portierung (das ist Phase 3, Sonnet).
