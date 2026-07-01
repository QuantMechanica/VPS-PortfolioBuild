#property strict
#property version   "5.0"
#property description "QM5_12845 Crude Swing-Structure Trend Tracer"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12845 - Crude Swing-Structure Trend Tracer
// -----------------------------------------------------------------------------
// H4 structural WTI sleeve:
//   - confirmed Williams-fractal swing highs/lows
//   - HH/HL or LH/LL structure gate
//   - close breakout beyond the latest confirmed swing in trend direction
//   - ADX trend filter, swing-protected stop, fixed RR target, time stop
// Runtime uses MT5 OHLC and framework helpers only; no external data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12845;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_swing_wing             = 3;
input int    strategy_swing_scan_bars        = 160;
input int    strategy_adx_period             = 14;
input double strategy_adx_min                = 22.0;
input int    strategy_atr_period             = 14;
input double strategy_stop_buffer_atr        = 0.25;
input double strategy_rr_target              = 2.5;
input int    strategy_max_hold_bars          = 60;
input int    strategy_max_spread_points      = 1000;
input int    strategy_deviation_points       = 20;

struct Strategy_SwingState
  {
   double latest_high;
   double previous_high;
   double latest_low;
   double previous_low;
   int    latest_high_index;
   int    previous_high_index;
   int    latest_low_index;
   int    previous_low_index;
   bool   bullish_structure;
   bool   bearish_structure;
  };

bool Strategy_IsXtiH4()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_H4);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_IsSwingHigh(const MqlRates &rates[], const int index, const int wing)
  {
   const double center = rates[index].high;
   if(center <= 0.0)
      return false;
   for(int d = 1; d <= wing; ++d)
     {
      if(rates[index - d].high >= center)
         return false;
      if(rates[index + d].high >= center)
         return false;
     }
   return true;
  }

bool Strategy_IsSwingLow(const MqlRates &rates[], const int index, const int wing)
  {
   const double center = rates[index].low;
   if(center <= 0.0)
      return false;
   for(int d = 1; d <= wing; ++d)
     {
      if(rates[index - d].low <= center)
         return false;
      if(rates[index + d].low <= center)
         return false;
     }
   return true;
  }

bool Strategy_LoadSwingState(Strategy_SwingState &state, double &close_last, datetime &closed_time)
  {
   state.latest_high = 0.0;
   state.previous_high = 0.0;
   state.latest_low = 0.0;
   state.previous_low = 0.0;
   state.latest_high_index = -1;
   state.previous_high_index = -1;
   state.latest_low_index = -1;
   state.previous_low_index = -1;
   state.bullish_structure = false;
   state.bearish_structure = false;
   close_last = 0.0;
   closed_time = 0;

   const int wing = MathMax(2, strategy_swing_wing);
   const int bars_to_scan = MathMax(strategy_swing_scan_bars, wing * 4 + 20);
   const int bars_needed = bars_to_scan + wing + 1;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, rates); // perf-allowed: bounded H4 swing scan on closed-bar path.
   if(copied < wing * 4 + 10)
      return false;

   close_last = rates[0].close;
   closed_time = rates[0].time;
   if(close_last <= 0.0 || closed_time <= 0)
      return false;

   for(int i = wing; i < copied - wing; ++i)
     {
      if(state.previous_high <= 0.0 && Strategy_IsSwingHigh(rates, i, wing))
        {
         if(state.latest_high <= 0.0)
           {
            state.latest_high = rates[i].high;
            state.latest_high_index = i;
           }
         else
           {
            state.previous_high = rates[i].high;
            state.previous_high_index = i;
           }
        }

      if(state.previous_low <= 0.0 && Strategy_IsSwingLow(rates, i, wing))
        {
         if(state.latest_low <= 0.0)
           {
            state.latest_low = rates[i].low;
            state.latest_low_index = i;
           }
         else
           {
            state.previous_low = rates[i].low;
            state.previous_low_index = i;
           }
        }

      if(state.previous_high > 0.0 && state.previous_low > 0.0)
         break;
     }

   if(state.latest_high <= 0.0 || state.previous_high <= 0.0 ||
      state.latest_low <= 0.0 || state.previous_low <= 0.0)
      return false;

   state.bullish_structure = (state.latest_high > state.previous_high &&
                              state.latest_low > state.previous_low);
   state.bearish_structure = (state.latest_high < state.previous_high &&
                              state.latest_low < state.previous_low);
   return true;
  }

bool Strategy_CloseOppositeBreak(const double close_last, const Strategy_SwingState &state)
  {
   const int magic = QM_FrameworkMagic();
   bool closed_any = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_exit = false;
      if(position_type == POSITION_TYPE_BUY && close_last < state.latest_low)
         should_exit = true;
      if(position_type == POSITION_TYPE_SELL && close_last > state.latest_high)
         should_exit = true;

      if(should_exit)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         closed_any = true;
        }
     }

   return closed_any;
  }

bool Strategy_BuildEntryRequest(const QM_OrderType side,
                                const Strategy_SwingState &state,
                                const double atr_value,
                                QM_EntryRequest &req)
  {
   req.type = side;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "XTI_SWING_STRUCTURE_LONG" : "XTI_SWING_STRUCTURE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || atr_value <= 0.0)
      return false;

   const double buffer = atr_value * strategy_stop_buffer_atr;
   if(req.type == QM_BUY)
      req.sl = QM_StopRulesNormalizePrice(_Symbol, state.latest_low - buffer);
   else
      req.sl = QM_StopRulesNormalizePrice(_Symbol, state.latest_high + buffer);

   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.tp = QM_TakeRR(_Symbol, req.type, entry_price, req.sl, strategy_rr_target);
   if(req.tp <= 0.0)
      return false;

   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiH4())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_swing_wing < 2 || strategy_swing_wing > 12)
      return true;
   if(strategy_swing_scan_bars < 40 || strategy_swing_scan_bars > 500)
      return true;
   if(strategy_adx_period <= 0 || strategy_adx_min < 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_stop_buffer_atr < 0.0 || strategy_rr_target <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0 || strategy_deviation_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12845_TREND_TRACER_CRUDE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_SwingState state;
   double close_last = 0.0;
   datetime closed_time = 0;
   if(!Strategy_LoadSwingState(state, close_last, closed_time))
      return false;

   if(Strategy_CloseOppositeBreak(close_last, state))
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double adx_value = QM_ADX(_Symbol, PERIOD_H4, strategy_adx_period, 1);
   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(adx_value <= strategy_adx_min || atr_value <= 0.0)
      return false;

   const double deviation = (double)MathMax(0, strategy_deviation_points) * _Point;
   if(state.bullish_structure && close_last > state.latest_high + deviation)
      return Strategy_BuildEntryRequest(QM_BUY, state, atr_value, req);
   if(state.bearish_structure && close_last < state.latest_low - deviation)
      return Strategy_BuildEntryRequest(QM_SELL, state, atr_value, req);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_bars) * PeriodSeconds(PERIOD_H4);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12845\",\"ea\":\"trend-tracer-crude\"}");
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
