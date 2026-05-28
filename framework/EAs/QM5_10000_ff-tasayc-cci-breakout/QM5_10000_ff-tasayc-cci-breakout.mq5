#property strict
#property version   "5.0"
#property description "QM5_10000 ForexFactory TASAYC CCI Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10000;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cci_period        = 20;
input double strategy_cci_threshold     = 100.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_buffer     = 0.10;
input double strategy_max_range_atr     = 2.50;
input double strategy_tp_r_multiple     = 2.0;
input int    strategy_time_stop_bars    = 36;

bool   g_long_excursion_active          = false;
bool   g_short_excursion_active         = false;
double g_current_long_peak              = 0.0;
double g_current_short_trough           = 0.0;
double g_prior_long_peak                = 0.0;
double g_prior_short_trough             = 0.0;
bool   g_has_prior_long_peak            = false;
bool   g_has_prior_short_trough         = false;

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_cci_period <= 0 || strategy_atr_period <= 0 || strategy_cci_threshold <= 0.0 ||
      strategy_atr_sl_buffer < 0.0 || strategy_max_range_atr <= 0.0 || strategy_tp_r_multiple <= 0.0)
      return false;

   datetime utc_time = QM_BrokerToUTC(TimeCurrent());
   if(utc_time <= 0)
      utc_time = TimeGMT();
   if(QM_NewsInWindow(utc_time, _Symbol, 120, 120, "HIGH"))
      return false;

   const double cci = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double high = iHigh(_Symbol, PERIOD_H1, 1);
   const double low = iLow(_Symbol, PERIOD_H1, 1);
   const double close = iClose(_Symbol, PERIOD_H1, 1);
   const double range = high - low;

   bool signal_long = false;
   bool signal_short = false;
   if(atr > 0.0 && high > 0.0 && low > 0.0 && close > 0.0 && range > 0.0 &&
      range <= strategy_max_range_atr * atr)
     {
      signal_long = (g_has_prior_long_peak && cci > strategy_cci_threshold && cci > g_prior_long_peak);
      signal_short = (g_has_prior_short_trough && cci < -strategy_cci_threshold && cci < g_prior_short_trough);
     }

   if(cci > strategy_cci_threshold)
     {
      if(!g_long_excursion_active)
        {
         g_long_excursion_active = true;
         g_current_long_peak = cci;
        }
      else
         g_current_long_peak = MathMax(g_current_long_peak, cci);
     }
   else if(g_long_excursion_active)
     {
      g_prior_long_peak = g_current_long_peak;
      g_has_prior_long_peak = true;
      g_long_excursion_active = false;
      g_current_long_peak = 0.0;
     }

   if(cci < -strategy_cci_threshold)
     {
      if(!g_short_excursion_active)
        {
         g_short_excursion_active = true;
         g_current_short_trough = cci;
        }
      else
         g_current_short_trough = MathMin(g_current_short_trough, cci);
     }
   else if(g_short_excursion_active)
     {
      g_prior_short_trough = g_current_short_trough;
      g_has_prior_short_trough = true;
      g_short_excursion_active = false;
      g_current_short_trough = 0.0;
     }

   if(signal_long)
     {
      const double sl = low - strategy_atr_sl_buffer * atr;
      const double risk = close - sl;
      if(risk <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = close + strategy_tp_r_multiple * risk;
      req.reason = "TASAYC_CCI_LONG";
      g_has_prior_long_peak = false;
      return true;
     }

   if(signal_short)
     {
      const double sl = high + strategy_atr_sl_buffer * atr;
      const double risk = sl - close;
      if(risk <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = close - strategy_tp_r_multiple * risk;
      req.reason = "TASAYC_CCI_SHORT";
      g_has_prior_short_trough = false;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || sl <= 0.0 || market <= 0.0)
         continue;

      const double initial_risk = is_buy ? (open_price - sl) : (sl - open_price);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(initial_risk <= 0.0 || moved < initial_risk)
         continue;

      const bool already_be = is_buy ? (sl >= open_price - point * 0.5)
                                     : (sl <= open_price + point * 0.5);
      if(!already_be)
         QM_TM_MoveSL(ticket, open_price, "TASAYC_BE_AT_1R");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int seconds = PeriodSeconds(PERIOD_H1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_time_stop_bars > 0 && seconds > 0 && open_time > 0 &&
         TimeCurrent() - open_time >= strategy_time_stop_bars * seconds)
         return true;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(point <= 0.0 || open_price <= 0.0 || sl <= 0.0)
         continue;

      const bool before_one_r = is_buy ? (sl < open_price - point * 0.5)
                                       : (sl > open_price + point * 0.5);
      if(!before_one_r)
         continue;

      const double cci = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 1);
      if(is_buy && cci <= 0.0)
         return true;
      if(!is_buy && cci >= 0.0)
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
