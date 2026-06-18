#property strict
#property version   "5.0"
#property description "QM5_1349 Larry Williams Volatility Breakout — prev-day range x factor (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_1349 williams-vol-breakout-prevday-range-h1 (single)
// -----------------------------------------------------------------------------
// Source: Larry R. Williams — "How I Made One Million Dollars Last Year Trading
// Commodities" (1979) ch.8 volatility-breakout primitive; refined to 0.6 x
// prev-day range in "Long-Term Secrets to Short-Term Trading" (Wiley, 1999) ch.7.
//
// Mechanic (H1 chart, broker-time NY-Close GMT+2/+3 DST session day):
//   prev_day_range = high_D1[1] - low_D1[1]   (yesterday's full broker-day range)
//   anchor         = close_D1[1]               (yesterday's broker-day CLOSE)
//   BUY_trigger    = anchor + vb_factor * prev_day_range
//   SELL_trigger   = anchor - vb_factor * prev_day_range
// Entry = the FIRST intraday cross of a trigger level THIS broker-day. The trigger
// level is STATE (recomputed once per broker-day on the closed D1 bar); the cross
// is the single trigger EVENT. Daily-trend bias EMA(50,D1) gates direction. Hard
// day-end exit at 21:00 broker; counter-trigger reversal exit; 1.5R TP; ATR
// time/structure stop; 6-bar time-stop.
//
// .DWX BACKTEST INVARIANTS honoured:
//  - Anchor is the prior CLOSE, NOT today's open (build note 6: DWX index/FX CFDs
//    are gapless so open[0]==close[1]; referencing the prior CLOSE is gap-robust
//    and the card's "fraction-of-prev-day-range" projection is preserved).
//  - Spread guard fails OPEN on zero/degenerate spread (build note 1): only a
//    genuinely wide quoted spread blocks; DWX ask==bid never blocks.
//  - No swap gate (build note 2).
//  - QM_IsNewBar() consumed ONCE per OnTick for the H1 entry gate; the per-day
//    trigger-level recompute is keyed off the closed D1 bar timestamp, not a
//    second new-bar consume.
//  - Session/day-end windows in BROKER time (TimeCurrent() is broker time); D1
//    bars already roll at the broker-day boundary (NY-close convention).
//  - prev_day_range thresholds compared against ATR(20,D1) (multi-bar baseline),
//    not a single-bar value.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1349;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_vb_factor            = 0.6;   // Williams 1999 prev-day-range projection factor (P3 sweep 0.4-0.8)
input int    strategy_ema_period           = 50;    // daily-trend bias EMA period (D1)
input int    strategy_atr_period_h1        = 20;    // ATR period for SL sizing (H1)
input int    strategy_atr_period_d1        = 20;    // ATR period for prev-day-range gate (D1)
input double strategy_atr_sl_mult          = 1.0;   // initial ATR-stop multiple (P3 sweep 0.7-1.5)
input double strategy_atr_sl_cap_mult      = 2.0;   // max initial-SL distance cap (x ATR(20,H1))
input double strategy_range_atr_gate       = 0.5;   // prev_day_range must exceed this x ATR(20,D1)
input double strategy_tp_rr                = 1.5;   // TP R-multiple from trigger anchor (P3 sweep 1.0-2.5)
input int    strategy_session_start_hour   = 0;     // entry window start (broker time)
input int    strategy_session_end_hour     = 18;    // entry window end, exclusive (broker time)
input int    strategy_day_end_close_hour   = 21;    // hard day-end exit hour (broker time)
input int    strategy_time_stop_bars       = 6;     // H1 bars without TP/SL hit -> exit
input double strategy_spread_atr_gate      = 0.3;   // skip entry if spread > this x ATR(20,H1)

// -----------------------------------------------------------------------------
// Per-broker-day STATE (recomputed once per closed D1 bar)
// -----------------------------------------------------------------------------
datetime g_day_anchor      = 0;     // iTime(D1,0) of the broker-day the state was built for
double   g_buy_trigger     = 0.0;
double   g_sell_trigger    = 0.0;
double   g_prev_range      = 0.0;
double   g_ema_bias        = 0.0;   // EMA(50,D1) at shift 1
double   g_prev_close_d1   = 0.0;   // close_D1[1]
bool     g_range_ok        = false; // prev_day_range > gate x ATR(20,D1)
bool     g_buy_crossed     = false; // BUY trigger already crossed this broker-day
bool     g_sell_crossed    = false; // SELL trigger already crossed this broker-day
bool     g_traded_today    = false; // re-arm guard: one entry per broker-day (any exit -> no re-entry same day)

datetime g_entry_bar_time  = 0;     // H1 bar-open time at entry (for the bar time-stop)

double PointValue()
  {
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  }

// Recompute the per-day trigger levels off the CLOSED D1 bar. Called once when a
// new broker-day's D1 bar appears. Reads prior-day (shift 1) closed values only.
void AdvanceState_OnNewDay()
  {
   g_buy_crossed  = false;
   g_sell_crossed = false;
   g_traded_today = false;
   g_buy_trigger  = 0.0;
   g_sell_trigger = 0.0;
   g_range_ok     = false;

   const double hi_prev = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: fixed closed D1 bar, only on D1 rollover.
   const double lo_prev = iLow(_Symbol, PERIOD_D1, 1);    // perf-allowed: fixed closed D1 bar, only on D1 rollover.
   const double cl_prev = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: fixed closed D1 bar, only on D1 rollover.
   if(hi_prev <= 0.0 || lo_prev <= 0.0 || cl_prev <= 0.0)
      return;

   g_prev_range    = hi_prev - lo_prev;
   g_prev_close_d1 = cl_prev;
   if(g_prev_range <= 0.0)
      return;

   g_buy_trigger  = cl_prev + strategy_vb_factor * g_prev_range;
   g_sell_trigger = cl_prev - strategy_vb_factor * g_prev_range;

   g_ema_bias = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   // prev-day-range meaningfulness gate vs a multi-bar ATR baseline (build note 7).
   g_range_ok = (atr_d1 > 0.0 && g_prev_range > strategy_range_atr_gate * atr_d1);
  }

// Detect / advance the broker-day boundary using the D1 closed-bar timestamp.
// Returns true when a new broker-day was rolled (state recomputed).
bool MaybeRollDay()
  {
   const datetime d0 = iTime(_Symbol, PERIOD_D1, 0);   // perf-allowed: current D1 bar-open = broker-day boundary.
   if(d0 <= 0)
      return false;
   if(d0 == g_day_anchor)
      return false;
   g_day_anchor = d0;
   AdvanceState_OnNewDay();
   return true;
  }

bool InEntryWindow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);   // broker time
   return (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
  }

bool AtOrAfterDayEnd()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);   // broker time
   return (dt.hour >= strategy_day_end_close_hour);
  }

bool HasPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

void ClosePositions(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_ClosePosition(t, reason);
     }
  }

// =============================================================================
// No Trade Filter (time, spread, news)
// =============================================================================
bool Strategy_NoTradeFilter()
  {
   if(!InEntryWindow())
      return true;

   // Spread guard: skip entry if quoted spread > gate x ATR(20,H1).
   // .DWX INVARIANT (build note 1): fail OPEN on zero/degenerate spread.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period_h1, 1);
      if(atr_h1 > 0.0 && (ask - bid) > strategy_spread_atr_gate * atr_h1)
         return true;
     }
   return false;
  }

// =============================================================================
// Trade Entry — first intraday cross of the prev-day-range projected trigger,
// gated by daily EMA bias + prev-day-range meaningfulness.
// =============================================================================
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_buy_trigger <= 0.0 || g_sell_trigger <= 0.0)
      return false;
   if(!g_range_ok)
      return false;

   // Re-arm guard: one entry per broker-day; no re-entry after any same-day exit.
   if(g_traded_today)
      return false;

   ENUM_POSITION_TYPE ptype;
   if(HasPosition(ptype))
      return false;

   // Use the just-closed H1 bar's high/low to detect the FIRST cross this day.
   const double hi = iHigh(_Symbol, PERIOD_H1, 1);   // perf-allowed: fixed closed H1 bar, post new-bar gate.
   const double lo = iLow(_Symbol, PERIOD_H1, 1);    // perf-allowed: fixed closed H1 bar, post new-bar gate.
   if(hi <= 0.0 || lo <= 0.0)
      return false;

   const double point = PointValue();
   if(point <= 0.0)
      return false;
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period_h1, 1);
   if(atr_h1 <= 0.0)
      return false;

   bool fire_buy  = false;
   bool fire_sell = false;

   // BUY: first cross above BUY_trigger this day + bullish daily bias.
   if(!g_buy_crossed && hi >= g_buy_trigger)
     {
      g_buy_crossed = true;
      if(g_ema_bias > 0.0 && g_prev_close_d1 > g_ema_bias)
         fire_buy = true;
     }
   // SELL: first cross below SELL_trigger this day + bearish daily bias.
   if(!fire_buy && !g_sell_crossed && lo <= g_sell_trigger)
     {
      g_sell_crossed = true;
      if(g_ema_bias > 0.0 && g_prev_close_d1 < g_ema_bias)
         fire_sell = true;
     }

   if(!fire_buy && !fire_sell)
      return false;

   const QM_OrderType side = fire_buy ? QM_BUY : QM_SELL;
   const double entry = fire_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop: opposite trigger OR 1x ATR(20,H1), whichever is FARTHER from entry,
   // capped at strategy_atr_sl_cap_mult x ATR(20,H1) (Williams 1999 + sanity floor).
   const double atr_dist     = strategy_atr_sl_mult * atr_h1;
   const double atr_cap_dist = strategy_atr_sl_cap_mult * atr_h1;
   double sl = 0.0;
   if(side == QM_BUY)
     {
      const double opp_dist = entry - g_sell_trigger;        // distance to opposite (SELL) trigger
      double sl_dist = MathMax(atr_dist, opp_dist);          // farther of the two
      sl_dist = MathMin(sl_dist, atr_cap_dist);              // cap
      if(sl_dist <= 0.0)
         sl_dist = atr_dist;
      sl = entry - sl_dist;
     }
   else
     {
      const double opp_dist = g_buy_trigger - entry;         // distance to opposite (BUY) trigger
      double sl_dist = MathMax(atr_dist, opp_dist);
      sl_dist = MathMin(sl_dist, atr_cap_dist);
      if(sl_dist <= 0.0)
         sl_dist = atr_dist;
      sl = entry + sl_dist;
     }
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   // TP: 1.5R from the trigger anchor. For BUY the R-unit is (entry - SELL_trigger);
   // for SELL it is (BUY_trigger - entry). Fall back to ATR R-unit if degenerate.
   double r_unit = (side == QM_BUY) ? (entry - g_sell_trigger) : (g_buy_trigger - entry);
   if(r_unit <= 0.0)
      r_unit = atr_h1;
   double tp = (side == QM_BUY) ? (entry + strategy_tp_rr * r_unit)
                                : (entry - strategy_tp_rr * r_unit);
   tp = QM_TM_NormalizePrice(_Symbol, tp);

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = fire_buy ? "WVB_BUY_PREVRANGE" : "WVB_SELL_PREVRANGE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_traded_today  = true;
   g_entry_bar_time = iTime(_Symbol, PERIOD_H1, 0);   // current H1 bar-open time
   return true;
  }

// =============================================================================
// Trade Management — card specifies hard SL/TP only (no trailing / partial / BE).
// =============================================================================
void Strategy_ManageOpenPosition()
  {
  }

// =============================================================================
// Trade Close — day-end hard close (21:00 broker), counter-trigger reversal,
// H1 bar time-stop. Closes here so it runs every tick (intraday exits).
// =============================================================================
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!HasPosition(ptype))
      return false;

   // 1) Hard day-end exit at/after 21:00 broker — no overnight carry.
   if(AtOrAfterDayEnd())
     {
      ClosePositions(QM_EXIT_FRIDAY_CLOSE);
      return false;
     }

   // 2) Counter-trigger reversal: the opposite breakout fired later this day.
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ptype == POSITION_TYPE_BUY && g_sell_trigger > 0.0 && bid > 0.0 && bid < g_sell_trigger)
     {
      ClosePositions(QM_EXIT_OPPOSITE_SIGNAL);
      return false;
     }
   if(ptype == POSITION_TYPE_SELL && g_buy_trigger > 0.0 && ask > 0.0 && ask > g_buy_trigger)
     {
      ClosePositions(QM_EXIT_OPPOSITE_SIGNAL);
      return false;
     }

   // 3) Time-stop: N H1 bars elapsed since entry without TP/SL hit.
   if(g_entry_bar_time > 0 && strategy_time_stop_bars > 0)
     {
      const datetime cur_bar = iTime(_Symbol, PERIOD_H1, 0);   // perf-allowed: current H1 bar-open time.
      if(cur_bar > 0)
        {
         const int bars_held = (int)((cur_bar - g_entry_bar_time) / (PeriodSeconds(PERIOD_H1)));
         if(bars_held >= strategy_time_stop_bars)
           {
            ClosePositions(QM_EXIT_TIME_STOP);
            return false;
           }
        }
     }
   return false;
  }

// =============================================================================
// News Filter Hook — defer to framework two-axis news filter.
// =============================================================================
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1349\",\"ea\":\"QM5_1349_williams-vol-breakout-prevday-range-h1\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // Roll the per-broker-day trigger STATE off the closed D1 bar (cheap; only acts
   // once per broker-day). Done before the per-tick exit/entry paths.
   MaybeRollDay();

   // Per-tick: intraday discretionary exits (day-end, counter-trigger, time-stop).
   Strategy_ExitSignal();

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   // Per-closed-H1-bar: entry-signal evaluation. Single QM_IsNewBar() consume.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
