; QuantMechanica V5 default chart template
; Canonical source for chart visual defaults used by V5 EAs.
; Colors are stored in MT5 BGR integer format (0xBBGGRR), aligned to branding/brand_tokens.json.

[meta]
template_name=QM5_Default
version=1.0.0
updated_utc=2026-04-27T00:00:00Z
notes=QM brand palette with conservative grid and dual EMA overlay defaults.

[chart]
background=0x170602
foreground=0xfcfaf8
grid=0x3b291e
volume=0x8b7464
stop_levels=0x0b9ef5
ask_line=0xd4b606
bid_line=0xb8a394
bar_up=0x81b910
bar_down=0x4444ef
bull_candle=0x81b910
bear_candle=0x4444ef
candle_bull_outline=0x81b910
candle_bear_outline=0x4444ef
chart_shift=true
chart_autoscroll=true
chart_show_grid=true
chart_show_volumes=false
chart_show_ohlc=true
chart_show_ask_line=false
chart_show_trade_levels=true

[indicator.ema_fast]
kind=MovingAverage
period=20
method=EMA
applied_price=CLOSE
color=0x99d334
width=1
style=SOLID
enabled=true

[indicator.ema_slow]
kind=MovingAverage
period=50
method=EMA
applied_price=CLOSE
color=0xd4b606
width=1
style=SOLID
enabled=true
