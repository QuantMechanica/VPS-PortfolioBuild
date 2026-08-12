#property strict
#property version   "5.0"
#property description "QM5_20091 PriceBob extreme reversal fade GDAXI"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_20091_pricebob-extreme-reversal-fade-gdaxi
// Five strategy hooks only; lifecycle, risk, magic, news and Friday-close
// behavior remain owned by the V5 framework.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20091;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;     // live setfile: 0.5; disabled in tester
input double RISK_FIXED                 = 1000.0;  // tester default per HR4
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// Card filter: stand down for high-impact events. The two-axis framework
// default supplies the standing 30-minute pre/post blackout.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_session_start_hhmm       = 1000; // DAX cash open in DXZ broker time
input int    strategy_session_end_hhmm         = 1830; // DAX cash close in DXZ broker time
input int    strategy_atr_period               = 14;
input double strategy_bar_tr_atr_max           = 0.60;
input double strategy_envelope_atr_buffer      = 0.10;
input double strategy_extreme_proximity        = 0.15;
input double strategy_d1_box_floor_atr         = 0.15;
input double strategy_spread_box_max           = 0.25;
input double strategy_tp_session_range_mult    = 0.50;
input double strategy_tp_box_range_cap         = 2.00;
input int    strategy_extreme_buffer_pips      = 5;
input int    strategy_max_signals_per_session  = 2;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
// Session and box-relative spread checks live in Strategy_EntrySignal because
// the framework calls this hook before management. Returning false here keeps
// the session-end close path alive; the central news gate remains entry-only.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int start_hour = strategy_session_start_hhmm / 100;
   const int start_min = strategy_session_start_hhmm % 100;
   const int end_hour = strategy_session_end_hhmm / 100;
   const int end_min = strategy_session_end_hhmm % 100;
   if(start_hour < 0 || start_hour > 23 || start_min < 0 || start_min > 59 ||
      end_hour < 0 || end_hour > 23 || end_min < 0 || end_min > 59)
      return false;

   const int session_start_minute = start_hour * 60 + start_min;
   const int session_end_minute = end_hour * 60 + end_min;
   if(session_start_minute >= session_end_minute || strategy_atr_period < 2 ||
      strategy_bar_tr_atr_max <= 0.0 || strategy_envelope_atr_buffer < 0.0 ||
      strategy_extreme_proximity <= 0.0 || strategy_extreme_proximity >= 0.5 ||
      strategy_d1_box_floor_atr <= 0.0 || strategy_spread_box_max <= 0.0 ||
      strategy_tp_session_range_mult <= 0.0 || strategy_tp_box_range_cap <= 0.0 ||
      strategy_extreme_buffer_pips <= 0 || strategy_max_signals_per_session < 1)
      return false;

   // Five fixed closed bars provide four true ranges (each uses the prior
   // close). QM_ReadBar is the framework OHLC reader; this hook is already
   // behind the single QM_IsNewBar() consume in the canonical OnTick.
   MqlRates bars[5];
   for(int i = 0; i < 5; ++i)
     {
      if(!QM_ReadBar(_Symbol, PERIOD_M5, i + 1, bars[i]))
         return false;
     }

   MqlDateTime bar_dt;
   TimeToStruct(bars[0].time, bar_dt);
   const int bar_minute = bar_dt.hour * 60 + bar_dt.min;
   if(bar_minute < session_start_minute || bar_minute >= session_end_minute)
      return false;

   const int session_key = bar_dt.year * 10000 + bar_dt.mon * 100 + bar_dt.day;
   static int cached_session_key = 0;
   static double session_high = 0.0;
   static double session_low = 0.0;
   static int signals_this_session = 0;

   if(cached_session_key != session_key)
     {
      cached_session_key = session_key;
      session_high = bars[0].high;
      session_low = bars[0].low;
      signals_this_session = 0;

      // Restart-safe session reconstruction. This bounded scan runs only on
      // the first closed M5 bar observed for a session, never per tick/bar.
      if(bar_minute > session_start_minute)
        {
         MqlDateTime start_dt = bar_dt;
         start_dt.hour = start_hour;
         start_dt.min = start_min;
         start_dt.sec = 0;
         const datetime session_start = StructToTime(start_dt);
         MqlRates session_rates[];
         const int copied = CopyRates(_Symbol,
                                      PERIOD_M5,
                                      session_start,
                                      bars[0].time,
                                      session_rates); // perf-allowed: once-per-session bounded reconstruction
         if(copied > 0)
           {
            for(int i = 0; i < copied; ++i)
              {
               session_high = MathMax(session_high, session_rates[i].high);
               session_low = MathMin(session_low, session_rates[i].low);
              }
           }
        }
     }
   else
     {
      session_high = MathMax(session_high, bars[0].high);
      session_low = MathMin(session_low, bars[0].low);
     }

   // All four TTR bars must be part of the same configured cash session.
   for(int i = 0; i < 4; ++i)
     {
      MqlDateTime member_dt;
      TimeToStruct(bars[i].time, member_dt);
      const int member_key = member_dt.year * 10000 + member_dt.mon * 100 + member_dt.day;
      const int member_minute = member_dt.hour * 60 + member_dt.min;
      if(member_key != session_key || member_minute < session_start_minute ||
         member_minute >= session_end_minute)
         return false;
     }

   // Card: do not scan a new box while our position or pending order exists.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic)
         return false;
     }
   if(signals_this_session >= strategy_max_signals_per_session)
      return false;

   const double atr_m5 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_m5 <= 0.0 || atr_d1 <= 0.0)
      return false;

   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   for(int i = 0; i < 4; ++i)
     {
      if(bars[i].high <= 0.0 || bars[i].low <= 0.0 || bars[i].high < bars[i].low ||
         bars[i + 1].close <= 0.0)
         return false;
      const double true_range = MathMax(bars[i].high - bars[i].low,
                                        MathMax(MathAbs(bars[i].high - bars[i + 1].close),
                                                MathAbs(bars[i].low - bars[i + 1].close)));
      if(true_range > strategy_bar_tr_atr_max * atr_m5)
         return false;
      box_high = MathMax(box_high, bars[i].high);
      box_low = MathMin(box_low, bars[i].low);
     }

   // Literal non-expanding-envelope reading: the complete four-bar envelope
   // may extend no farther than 0.1 M5 ATR beyond the oldest box member.
   const double envelope_buffer = strategy_envelope_atr_buffer * atr_m5;
   if(box_high > bars[3].high + envelope_buffer ||
      box_low < bars[3].low - envelope_buffer)
      return false;

   const double box_range = box_high - box_low;
   const double session_range = session_high - session_low;
   if(box_range <= 0.0 || session_range <= 0.0 ||
      box_range < strategy_d1_box_floor_atr * atr_d1)
      return false;

   const double proximity_distance = strategy_extreme_proximity * session_range;
   const bool near_high = (session_high - box_high) <= proximity_distance;
   const bool near_low = (box_low - session_low) <= proximity_distance;
   // A box simultaneously near both extremes has no unambiguous fade side.
   if(near_high == near_low)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
      return false;
   // .DWX Model-4 quotes may have ask==bid; zero modeled spread is valid.
   if(tick.ask > tick.bid &&
      (tick.ask - tick.bid) > strategy_spread_box_max * box_range)
      return false;

   const double stop_buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                               strategy_extreme_buffer_pips);
   const double take_distance = MathMin(strategy_tp_session_range_mult * session_range,
                                         strategy_tp_box_range_cap * box_range);
   if(stop_buffer <= 0.0 || take_distance <= 0.0)
      return false;

   MqlDateTime end_dt = bar_dt;
   end_dt.hour = end_hour;
   end_dt.min = end_min;
   end_dt.sec = 0;
   const datetime session_end = StructToTime(end_dt);
   const datetime broker_now = TimeCurrent();
   if(session_end <= broker_now)
      return false;
   req.expiration_seconds = (int)(session_end - broker_now);

   if(near_high)
     {
      req.type = QM_SELL_STOP;
      req.price = QM_StopRulesNormalizePrice(_Symbol, box_low);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, session_high + stop_buffer);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, req.price - take_distance);
      if(req.price <= 0.0 || req.price >= tick.bid || req.sl <= req.price ||
         req.tp <= 0.0 || req.tp >= req.price)
         return false;
      req.reason = "PRICEBOB_TTR_EXTREME_SHORT";
      signals_this_session++;
      return true;
     }

   req.type = QM_BUY_STOP;
   req.price = QM_StopRulesNormalizePrice(_Symbol, box_high);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, session_low - stop_buffer);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.price + take_distance);
   if(req.price <= tick.ask || req.sl <= 0.0 || req.sl >= req.price ||
      req.tp <= req.price)
      return false;
   req.reason = "PRICEBOB_TTR_EXTREME_LONG";
   signals_this_session++;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // No trailing, break-even or partial close. Remove an unfilled fade stop
   // once the configured session has ended so it cannot trigger overnight.
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_minute = now_dt.hour * 60 + now_dt.min;
   const int start_minute = (strategy_session_start_hhmm / 100) * 60 +
                            (strategy_session_start_hhmm % 100);
   const int end_minute = (strategy_session_end_hhmm / 100) * 60 +
                          (strategy_session_end_hhmm % 100);
   if(now_minute >= start_minute && now_minute < end_minute)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "PRICEBOB_SESSION_END");
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   // Card time-stop: flatten at session end (and recover any position still
   // present before the next session begins). SL/TP otherwise own the exit.
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_minute = now_dt.hour * 60 + now_dt.min;
   const int start_minute = (strategy_session_start_hhmm / 100) * 60 +
                            (strategy_session_start_hhmm % 100);
   const int end_minute = (strategy_session_end_hhmm / 100) * 60 +
                          (strategy_session_end_hhmm % 100);
   return (now_minute < start_minute || now_minute >= end_minute);
  }

// News Filter Hook (callable for P8 News Impact)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The central two-axis high-impact blackout gates only the entry path.
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — copied from framework/templates/EA_Skeleton.mq5.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Both the strategy override and central news blackout are entry-only.
   // Management and the session time-stop above continue through news windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
