# QM5_21001 Balke GMT3 range-breakout exit challenger C1

This Q15 challenger is a survivor-pure derivative of `QM5_13213_balke-gmt3-range-breakout` for opt-card `OPT-13213-USDJPY-EXIT-SURGERY-1e2bb8e4c42f21f7`.

The parent mechanics, inputs, defaults, range construction, entry orders, stops, trailing, news handling, and Friday-close wiring are unchanged. The only optimization surface is `strategy_exit_hour` with candidates 19 and 20. `strategy_opt_enabled=false` forces the incumbent 18:00 exit, while `true` reads `strategy_exit_hour`.

This identity is development-only. It is not approved for live deployment, T_Live, FTMO, or AutoTrading.
