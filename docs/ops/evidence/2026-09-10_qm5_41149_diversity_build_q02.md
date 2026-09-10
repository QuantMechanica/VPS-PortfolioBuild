# QM5_41149 diversity build and Q02 intake — 2026-09-10

## Scope and authority

- Branch: `agents/board-advisor`
- Build task: `8a6b57f0-4911-431d-8c1c-4f1be85fd431`
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_41149_audusd-local-session-inventory-drift.md`
- G0: `APPROVED`
- Diversity target: `AUDUSD.DWX`, H1, structural Australia/Sydney local-session inventory drift
- Registry precondition: EA 41149 and magic `411490000` for slot 0 / `AUDUSD.DWX` were already active and resolver-clean.

No live terminal, AutoTrading control, deploy manifest, portfolio gate, or `T_Live` artifact was touched.

## Artifacts and bindings

| Artifact | SHA-256 |
|---|---|
| MQ5 source | `833a96b8e9eb42cd5ab4e7109afdc4052dd0ae473d4d097251e3a32f11f69d72` |
| EX5 binary | `0e2b57da5d55048dd5a76715b1cb38367006cf93126057c3df13b04387f3730e` |
| AUDUSD H1 backtest setfile | `481de9d5d1916f5f56b236741e5789c5beafb781b2e4e1ebd8dceba47b013dc7` |

The canonical setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and contains exactly the two declared strategy values: H1 ATR period 14 and hard-stop multiple 1.5.

## Binding framework-input-pin audit

The required command was run after source creation and again immediately before each compile enqueue (initial and source-repair successor):

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41149_audusd-local-session-inventory-drift/QM5_41149_audusd-local-session-inventory-drift.mq5"
```

Exact final result:

```json
{
  "ok": true,
  "predicate": "EA_FRAMEWORK_INPUT_PINNED",
  "source_count": 1,
  "hit_count": 0,
  "hits": []
}
```

The source equality-locks only `strategy_atr_period_h1`, `strategy_hard_stop_atr`, `qm_ea_id`, `qm_magic_slot_offset`, and `RISK_PERCENT=0`. `RISK_FIXED` is only required to be finite and positive. RNG, news, and Friday inputs are not compared. Stress rejection is checked only for finiteness and inclusive 0..1 range.

## Verification

- Python reference tests: `4 passed`.
- Initial governed compile row `5f08ec91-6422-4b24-89c8-5b401ad0e911` failed with four local compiler errors plus the initialized-request static guard. It is preserved as append-only evidence.
- The bounded repair changed only this EA: use the registered kill-switch exit reason, treat tester zero spread as valid, call the void Global Variables flush correctly, initialize `QM_EntryRequest`, and use registered event vocabulary.
- Governed repair-successor compile row: `72ea3a08-296e-4eaf-92f3-15282343e002`.
- Compile result: `PASS`, 0 errors, 0 warnings.
- Strict build check: `PASS`, 0 failures, 0 warnings.
- Authenticated compile evidence: `D:\QM\reports\work_items\72ea3a08-296e-4eaf-92f3-15282343e002\QM5_41149\COMPILE_EA\compile_evidence.json`.

## Funnel handoff

`farmctl intake-first-q02` first passed read-only eligibility checks, including exact current EX5 binding, exactly one active magic row, canonical setfile, fixed-risk values, and absence of any prior Q02 row. It then appended exactly one Q02 canary:

- Work item: `12134047-e835-498f-9a5e-c10598be9749`
- State at handoff: `pending`
- Symbol/timeframe: `AUDUSD.DWX` / H1
- Receipt: `D:\QM\strategy_farm\artifacts\receipts\first_q02_intake\72ea3a08-296e-4eaf-92f3-15282343e002_12134047-e835-498f-9a5e-c10598be9749.json`
- Receipt SHA-256: `5dc7ac55a22cf35644d100588ac6f67b3ca5f419c136fbfb527776be6b45186a`

No local smoke or backtest was started by this build unit; Q02 execution remains owned by the paced terminal fleet.
