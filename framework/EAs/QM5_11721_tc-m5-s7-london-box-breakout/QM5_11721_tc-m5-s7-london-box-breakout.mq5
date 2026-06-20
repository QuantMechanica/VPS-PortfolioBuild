#property strict
#property version   "5.0"
#property description "QM5_11721 TC M5 S7 London Box Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 11721;
input int    qm_magic_slot_offset           = 0;
input uint   qm_rng_seed                    = 42;

input group "Risk"
input double RISK_PERCENT                   = 0.0;
input double RISK_FIXED                     = 1000.0;
input double PORTFOLIO_WEIGHT               = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours        = 336;
input string qm_news_min_impact             = "high";
input QM_NewsMode qm_news_mode_legacy       = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = true;
input int    qm_friday_close_hour_broker    = 21;

input group "Stress"
input double qm_stress_reject_probability   = 0.0;

input group "Strategy"
input int    strategy_session_start_hour_broker = 15;
input int    strategy_signal_valid_hours         = 1;
input double strategy_breakout_pct              = 0.20;
input double strategy_tp_box_multiple           = 4.0;
input double strategy_trail_box_multiple        = 1.0;
input int    strategy_box_minutes               = 60;
input int    strategy_min_box_points            = 5;
input int    strategy_max_spread_pips           = 8;

double g_box_high = 0.0;
double g_box_low = 0.0;
double g_box_height = 0.0;
int    g_box_session_key = 0;

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime SessionStartForBar(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   dt.hour = strategy_session_start_hour_broker;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool ReadOneRate(const int shift, MqlRates &rate)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: Strategy_EntrySignal is called only after the skeleton QM_IsNewBar gate.
   const int copied = CopyRates(_Symbol, _Period, shift, 1, rates);
   if(copied != 1)
      return false;
   rate = rates[0];
   return true;
  }

bool RefreshSessionBox(const datetime current_bar_time)
  {
   const datetime session_start = SessionStartForBar(current_bar_time);
   const datetime box_start = session_start - strategy_box_minutes * 60;
   const datetime box_end = session_start - 1;
   const int session_key = DateKey(session_start);

   if(g_box_session_key == session_key && g_box_height > 0.0)
      return true;

   MqlRates box_rates[];
   ArraySetAsSeries(box_rates, true);
   // perf-allowed: bounded 60-minute session-box read, advanced only on the closed-bar entry gate.
   const int copied = CopyRates(_Symbol, _Period, box_start, box_end, box_rates);
   if(copied <= 0)
      return false;

   double high = -DBL_MAX;
   double low = DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      if(box_rates[i].high > high)
         high = box_rates[i].high;
      if(box_rates[i].low < low)
         low = box_rates[i].low;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(high <= low || point <= 0.0)
      return false;
   if((high - low) / point < strategy_min_box_points)
      return false;

   g_box_high = QM_StopRulesNormalizePrice(_Symbol, high);
   g_box_low = QM_StopRulesNormalizePrice(_Symbol, low);
   g_box_height = g_box_high - g_box_low;
   g_box_session_key = session_key;
   return (g_box_height > 0.0);
  }

bool IsSignalWindow(const datetime current_bar_time)
  {
   const datetime session_start = SessionStartForBar(current_bar_time);
   const datetime session_end = session_start + strategy_signal_valid_hours * 3600;
   return (current_bar_time >= session_start && current_bar_time < session_end);
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(max_spread > 0.0 && ask > bid && (ask - bid) > max_spread)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOurOpenPosition())
      return false;

   MqlRates current_bar;
   if(!ReadOneRate(0, current_bar))
      return false;

   if(!IsSignalWindow(current_bar.time))
      return false;
   if(!RefreshSessionBox(current_bar.time))
      return false;

   MqlRates signal_bar;
   if(!ReadOneRate(1, signal_bar))
      return false;

   const double long_trigger = g_box_high + strategy_breakout_pct * g_box_height;
   const double short_trigger = g_box_low - strategy_breakout_pct * g_box_height;
   const double long_tp = QM_StopRulesNormalizePrice(_Symbol, g_box_high + strategy_tp_box_multiple * g_box_height);
   const double short_tp = QM_StopRulesNormalizePrice(_Symbol, g_box_low - strategy_tp_box_multiple * g_box_height);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(signal_bar.close > long_trigger && ask > 0.0 && ask < long_tp)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_box_low);
      req.tp = long_tp;
      req.reason = "TC_S7_LONG_BOX_BREAKOUT";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl < ask && req.tp > ask);
     }

   if(signal_bar.close < short_trigger && bid > 0.0 && bid > short_tp)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_box_high);
      req.tp = short_tp;
      req.reason = "TC_S7_SHORT_BOX_BREAKOUT";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl > bid && req.tp < bid);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(g_box_height <= 0.0 || strategy_trail_box_multiple <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double trail_distance = g_box_height * strategy_trail_box_multiple;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market = (pos_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double target_sl = QM_StopRulesNormalizePrice(_Symbol,
         (pos_type == POSITION_TYPE_BUY) ? (market - trail_distance) : (market + trail_distance));
      if(target_sl <= 0.0)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (pos_type == POSITION_TYPE_BUY ? (target_sl > current_sl) : (target_sl < current_sl));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "box_height_trailing_stop");
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11721_tc-m5-s7-london-box-breakout\"}");
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
