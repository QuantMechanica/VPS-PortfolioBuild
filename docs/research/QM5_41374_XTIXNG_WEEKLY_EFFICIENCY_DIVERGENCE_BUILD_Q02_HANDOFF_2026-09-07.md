# QM5_41374 XTI/XNG weekly efficiency-divergence build and Q02 handoff

## Status

`QM5_41374_xtixng-weffdiv-rv` is a committed new low-frequency XTI/XNG
relative-value basket. It compares each leg's absolute completed-week body to
its own weekly range, requires strict high/low efficiency divergence, and
fades the high-efficiency leg's body direction with an opposed equal-notional
companion. It is mechanically distinct from outright body momentum, weekly
close-location, multi-session path-efficiency, ratio, residual, flow, and
return-sign strategies.

The reputable source packet, approved Strategy Card, source/G0 decisions,
registry identity, two active magic rows, basket manifest, reference model,
and three fixed-risk backtest setfiles are present. Reference tests passed
`6/6`; card schema/ML lint passed.

## PACER guard and governed compile

Immediately before compile enqueue, the mandatory command

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:\QM\repo\framework\EAs\QM5_41374_xtixng-weffdiv-rv\QM5_41374_xtixng-weffdiv-rv.mq5"
```

returned exit code 0 with zero `EA_FRAMEWORK_INPUT_PINNED` findings. The guard
pins only strategy inputs, `qm_ea_id`, `qm_magic_slot_offset`, and fixed-risk
mode. It does not compare RNG, news, Friday-close, or portfolio-weight inputs;
stress rejection is checked only for finiteness and the inclusive `[0,1]`
range.

The governed compile lane accepted work item
`5621eafd-50aa-4974-93fc-be10f053b99d` for exact source SHA-256
`3b3e9c48acff2e5f2e8747553ae768292f4c3ccb2f83fcd3330928de5041476c`.
Its rollout hold was released against the matching source hash. At handoff it
remained pending; no compile verdict, `.ex5`, or Q01 PASS is claimed.

## CPU stop and Q02 disposition

The 97% backtest CPU ceiling bound before Q02 admission. Five fresh one-second
whole-host samples were `97.2%`, `99.3%`, `95.6%`, `92.0%`, and `95.0%`.
Accordingly, no Q02 work item was enqueued and no tester was dispatched.

After CPU admission clears, the next safe action is to verify the governed
compile evidence and binary, then enqueue exactly one logical-basket Q02 via
the canonical first-Q02 intake path. Do not bypass the CPU gate.

No `T_Live`, AutoTrading, portfolio gate, deploy manifest, or live manifest
was touched.
