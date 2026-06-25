#property strict
#property version   "5.0"
#property description "QM5_11446 Burke 3-day rectangle breakout M5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11446;
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
input int    strategy_rect_bars         = 3;
input int    strategy_ema_period        = 20;
input int    strategy_height_min_pips   = 20;
input int    strategy_height_max_pips   = 100;
input int    strategy_sl_buffer_pips    = 5;
input int    strategy_sl_cap_pips       = 50;
input double strategy_sl_floor_frac     = 0.5;
input int    strategy_session_start_hr  = 9;
input int    strategy_session_end_hr    = 22;
input int    strategy_spread_cap_pips   = 15;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_now, dt);

   const int hour = dt.hour;
   if(strategy_session_start_hr <= strategy_session_end_hr)
     {
      if(hour < strategy_session_start_hr || hour >= strategy_session_end_hr)
         return true;
     }
   else
     {
      if(hour < strategy_session_start_hr && hour >= strategy_session_end_hr)
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(ask > 0.0 && bid > 0.0 && ask > bid && spread_cap > 0.0 && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_rect_bars < 3)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double rect_high = iHigh(_Symbol, PERIOD_D1, strategy_rect_bars); // perf-allowed: bespoke D1 rectangle anchor
   const double rect_low = iLow(_Symbol, PERIOD_D1, strategy_rect_bars);   // perf-allowed: bespoke D1 rectangle anchor
   if(rect_high <= 0.0 || rect_low <= 0.0 || rect_high <= rect_low)
      return false;

   for(int shift = 1; shift < strategy_rect_bars; ++shift)
     {
      const double day_high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 containment check
      const double day_low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: bounded D1 containment check
      if(day_high <= 0.0 || day_low <= 0.0)
         return false;
      if(day_high > rect_high || day_low < rect_low)
         return false;
     }

   const double rect_height = rect_high - rect_low;
   const double min_height = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_height_min_pips);
   const double max_height = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_height_max_pips);
   if(min_height > 0.0 && rect_height < min_height)
      return false;
   if(max_height > 0.0 && rect_height > max_height)
      return false;

   const double close_m5 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: closed-bar breakout close
   const double ema_m5 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1);
   if(close_m5 <= 0.0 || ema_m5 <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   double breakout_level = 0.0;
   if(close_m5 > rect_high && close_m5 > ema_m5)
     {
      side = QM_BUY;
      breakout_level = rect_high;
     }
   else if(close_m5 < rect_low && close_m5 < ema_m5)
     {
      side = QM_SELL;
      breakout_level = rect_low;
     }
   else
      return false;

   const double entry_price = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double stop_floor = rect_height * strategy_sl_floor_frac;
   const double stop_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(stop_floor > 0.0 && stop_distance < stop_floor)
      stop_distance = stop_floor;
   if(stop_cap > 0.0 && stop_distance > stop_cap)
      stop_distance = stop_cap;
   if(stop_distance <= 0.0)
      return false;

   const double stop_price = (side == QM_BUY)
                             ? QM_StopRulesNormalizePrice(_Symbol, breakout_level - stop_distance)
                             : QM_StopRulesNormalizePrice(_Symbol, breakout_level + stop_distance);
   const double take_price = (side == QM_BUY)
                             ? QM_StopRulesNormalizePrice(_Symbol, entry_price + rect_height)
                             : QM_StopRulesNormalizePrice(_Symbol, entry_price - rect_height);
   if(stop_price <= 0.0 || take_price <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop_price;
   req.tp = take_price;
   req.reason = (side == QM_BUY) ? "burke_rect_breakout_long" : "burke_rect_breakout_short";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook
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
