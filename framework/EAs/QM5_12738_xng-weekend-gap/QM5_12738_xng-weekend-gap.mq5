#property strict
#property version   "5.0"
#property description "QM5_12738 XNG Weekend Weather-Gap Continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12738 - XNG Weekend Weather-Gap Continuation
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - inspects completed Monday bars for weekend gap repricing
//   - enters continuation after same-day confirmation
//   - exits on signal-close invalidation, max hold, Friday close, or ATR stop
// Runtime uses MT5 OHLC/broker calendar only; no weather, EIA, storage, API,
// CSV, forecast, or futures-curve feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12738;
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
input int    strategy_atr_period          = 20;
input double strategy_min_gap_atr         = 0.35;
input double strategy_min_body_atr        = 0.20;
input double strategy_atr_sl_mult         = 2.75;
input int    strategy_max_hold_days       = 4;
input int    strategy_max_spread_points   = 2500;

int g_last_signal_day_key = 0;
int g_active_direction = 0;
double g_active_signal_close = 0.0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
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

bool Strategy_LoadClosedState(double &open_last,
                              double &high_last,
                              double &low_last,
                              double &close_last,
                              double &close_prev,
                              double &atr_last,
                              datetime &signal_time,
                              int &signal_day_key)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 2, rates) < 2) // perf-allowed: D1 weekend-gap signal state, new-bar gated.
      return false;

   signal_time = rates[0].time;
   signal_day_key = Strategy_DayKey(signal_time);
   open_last = rates[0].open;
   high_last = rates[0].high;
   low_last = rates[0].low;
   close_last = rates[0].close;
   close_prev = rates[1].close;
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(signal_time <= 0 || signal_day_key <= 0)
      return false;
   if(open_last <= 0.0 || high_last <= 0.0 || low_last <= 0.0 ||
      close_last <= 0.0 || close_prev <= 0.0)
      return false;
   if(high_last < low_last || atr_last <= 0.0)
      return false;
   return true;
  }

void Strategy_SyncActiveSignalFromPosition()
  {
   if(g_active_direction != 0 && g_active_signal_close > 0.0)
      return;

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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      g_active_direction = (pos_type == POSITION_TYPE_BUY ? 1 : -1);
      g_active_signal_close = PositionGetDouble(POSITION_PRICE_OPEN);
      return;
     }

   g_active_direction = 0;
   g_active_signal_close = 0.0;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double open_last = 0.0;
   double high_last = 0.0;
   double low_last = 0.0;
   double close_last = 0.0;
   double close_prev = 0.0;
   double atr_last = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   const bool have_state = Strategy_LoadClosedState(open_last, high_last, low_last,
                                                    close_last, close_prev, atr_last,
                                                    signal_time, signal_day_key);

   Strategy_SyncActiveSignalFromPosition();

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

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
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(g_active_direction > 0 && pos_type == POSITION_TYPE_BUY &&
         have_state && g_active_signal_close > 0.0 && close_last < g_active_signal_close)
         should_close = true;
      if(g_active_direction < 0 && pos_type == POSITION_TYPE_SELL &&
         have_state && g_active_signal_close > 0.0 && close_last > g_active_signal_close)
         should_close = true;
      if((g_active_direction > 0 && pos_type != POSITION_TYPE_BUY) ||
         (g_active_direction < 0 && pos_type != POSITION_TYPE_SELL))
         should_close = true;

      if(should_close)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         g_active_direction = 0;
         g_active_signal_close = 0.0;
        }
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_min_gap_atr <= 0.0 || strategy_min_body_atr <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12738_XNG_WEEKEND_GAP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double open_last = 0.0;
   double high_last = 0.0;
   double low_last = 0.0;
   double close_last = 0.0;
   double close_prev = 0.0;
   double atr_last = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   if(!Strategy_LoadClosedState(open_last, high_last, low_last, close_last,
                                close_prev, atr_last, signal_time, signal_day_key))
      return false;
   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;
   if(Strategy_DayOfWeek(signal_time) != 1)
      return false;

   const double gap = open_last - close_prev;
   const double body = close_last - open_last;
   const double min_gap = strategy_min_gap_atr * atr_last;
   const double min_body = strategy_min_body_atr * atr_last;
   int direction = 0;
   if(gap >= min_gap && body >= min_body)
      direction = 1;
   else if(gap <= -min_gap && body <= -min_body)
      direction = -1;
   else
      return false;

   req.type = (direction > 0 ? QM_BUY : QM_SELL);
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0 ? "XNG_WEEKEND_WEATHER_GAP_LONG" : "XNG_WEEKEND_WEATHER_GAP_SHORT");
   g_last_signal_day_key = signal_day_key;
   g_active_direction = direction;
   g_active_signal_close = close_last;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12738\",\"ea\":\"xng-weekend-gap\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
