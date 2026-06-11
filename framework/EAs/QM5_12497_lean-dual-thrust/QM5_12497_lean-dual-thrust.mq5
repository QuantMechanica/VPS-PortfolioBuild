#property strict
#property version   "5.0"
#property description "QM5_12497 Lean Dual Thrust Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12497;
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
input double strategy_k1                    = 0.63;
input double strategy_k2                    = 0.63;
input int    strategy_range_period          = 20;
input int    strategy_consolidator_minutes  = 30;
input int    strategy_hold_days             = 5;
input int    strategy_atr_period            = 14;
input double strategy_atr_stop_mult         = 2.5;
input double strategy_atr_floor_points      = 0.0;

double   g_dt_upper_line = 0.0;
double   g_dt_lower_line = 0.0;
datetime g_dt_band_time  = 0;
bool     g_dt_band_ready = false;

bool Strategy_NoTradeFilter()
  {
   if(strategy_atr_floor_points <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   return ((atr / point) < strategy_atr_floor_points);
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

   if(strategy_k1 <= 0.0 || strategy_k2 <= 0.0 ||
      strategy_range_period < 2 || strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0)
      return false;

   ENUM_TIMEFRAMES signal_tf = PERIOD_M30;
   if(strategy_consolidator_minutes == 15)
      signal_tf = PERIOD_M15;
   else if(strategy_consolidator_minutes == 30)
      signal_tf = PERIOD_M30;
   else if(strategy_consolidator_minutes == 60)
      signal_tf = PERIOD_H1;
   else
      return false;

   // Caller reaches this hook only after QM_IsNewBar() in OnTick.
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, signal_tf, 1, strategy_range_period, rates);
   if(copied < strategy_range_period)
      return false;

   double highest_high = -DBL_MAX;
   double highest_close = -DBL_MAX;
   double lowest_close = DBL_MAX;
   double lowest_low = DBL_MAX;

   for(int i = 0; i < strategy_range_period; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].close <= 0.0)
         return false;
      highest_high = MathMax(highest_high, rates[i].high);
      highest_close = MathMax(highest_close, rates[i].close);
      lowest_close = MathMin(lowest_close, rates[i].close);
      lowest_low = MathMin(lowest_low, rates[i].low);
     }

   const double range = MathMax(highest_high - lowest_close, highest_close - lowest_low);
   const double close_last = rates[0].close;
   if(range <= 0.0 || close_last <= 0.0)
      return false;

   g_dt_upper_line = close_last + strategy_k1 * range;
   g_dt_lower_line = close_last - strategy_k2 * range;
   g_dt_band_time = rates[0].time;
   g_dt_band_ready = true;

   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ask > g_dt_upper_line)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
      req.tp = 0.0;
      req.reason = "LEAN_DUAL_THRUST_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(bid < g_dt_lower_line)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_stop_mult);
      req.tp = 0.0;
      req.reason = "LEAN_DUAL_THRUST_SHORT";
      return (req.sl > 0.0 && req.sl > bid);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies a hard ATR stop only; no trailing, break-even, or partial close.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_hold_days > 0 && open_time > 0 &&
         (long)(now - open_time) >= (long)strategy_hold_days * 86400)
         return true;

      if(!g_dt_band_ready || bid <= 0.0 || ask <= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && bid < g_dt_lower_line)
         return true;
      if(ptype == POSITION_TYPE_SELL && ask > g_dt_upper_line)
         return true;
     }

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
