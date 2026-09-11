# Q-PRESCREEN fleet implementation review — fail closed

Router task: `ef55f2ff-2e3d-4d36-bc7f-3d6b0c0d1e34` (priority 95).

## Blocking specification conflict

The task's S1 requires `prescreen_model=2` while calling that value
one-minute OHLC.  The governed controller's verified native mapping is:

| MT5 Model | Controller mapping |
|---:|---|
| 4 | real ticks |
| 1 | M1 OHLC |
| 2 | open prices |

This is confirmed by `research_canary.MODEL_NAMES` and its focused test suite.
Consequently, implementing the literal `Model=2` request would enqueue
open-prices tests under a PRESCREEN label, which contradicts the OWNER decision
and the payload's OHLC-only evidence boundary.  The existing pilot likewise
rejects open-prices adoption.

No worker code, declaration, queue row, ledger, setfile, terminal, or reload
was changed.  In particular, no `PRESCREEN` value can be misreported as
`MEASURED`, and no real-tick selection/verdict/counter/book evidence was
affected.

## Focused verification

```text
python -c "from tools.strategy_farm.research_canary import MODEL_NAMES; \
assert MODEL_NAMES[1] == 'ohlc-m1'; assert MODEL_NAMES[2] == 'open-prices'"
PASS
python -m pytest tools/strategy_farm/tests/test_research_canary.py -q
39 passed
```

## Required review resolution

Resolve the numeric field in S1 before implementation: either use native
`Model=1` for M1 OHLC, or explicitly redefine the owner protocol for native
`Model=2` open prices.  Only the former is consistent with the current OWNER
decision and pilot.  After that resolution, the Default-OFF implementation can
be reviewed against S1--S4 without weakening real-tick-only evidence rules.

**RESULT (Q-only):** Q-PRESCREEN remains REVIEW; implementation is safely
withheld pending resolution of the model-number contradiction.
