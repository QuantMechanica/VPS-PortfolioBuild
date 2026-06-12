#property strict
#property version   "5.0"
#property description "QM5_12541 Kaufman ER Dual-Regime IDX"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12541;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_D1;
input int             strategy_ker_period      = 20;
input double          strategy_ker_trend_level = 0.35;
input double          strategy_ker_mr_level    = 0.20;
input int             strategy_trend_entry_dc  = 20;
input int             strategy_trend_exit_dc   = 10;
input int             strategy_rsi_period      = 2;
input double          strategy_rsi_mr_level    = 10.0;
input int             strategy_atr_period      = 14;
input double          strategy_trend_atr_mult  = 2.0;
input double          strategy_mr_atr_mult     = 3.0;
input int             strategy_mr_time_exit_days = 5;
input double          strategy_max_spread_points = 0.0;

enum StrategyRegime
  {
   STRATEGY_REGIME_MEANREV = 0,
   STRATEGY_REGIME_TREND   = 1
  };

StrategyRegime g_active_regime = STRATEGY_REGIME_MEANREV;
bool           g_cached_exit_signal = false;

bool Strategy_LoadClosedBars(MqlRates &rates[], const int count)
  {
   ArrayResize(rates, 0);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, count, rates); // perf-allowed: bounded KER/Donchian structural read; Strategy_EntrySignal is framework new-bar gated.
   return (copied >= count);
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &pos_type,
                                datetime &open_time,
                                string &comment)
  {
   ticket = 0;
   pos_type = POSITION_TYPE_BUY;
   open_time = 0;
   comment = "";

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      comment = PositionGetString(POSITION_COMMENT);
      return true;
     }

   return false;
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread >= 0 && (double)spread <= strategy_max_spread_points);
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

double Strategy_DonchianHigh(const MqlRates &rates[], const int start_index, const int period)
  {
   double high = -DBL_MAX;
   const int limit = MathMin(ArraySize(rates), start_index + period);
   for(int i = start_index; i < limit; ++i)
      high = MathMax(high, rates[i].high);
   return (high > -DBL_MAX) ? high : 0.0;
  }

double Strategy_DonchianLow(const MqlRates &rates[], const int start_index, const int period)
  {
   double low = DBL_MAX;
   const int limit = MathMin(ArraySize(rates), start_index + period);
   for(int i = start_index; i < limit; ++i)
      low = MathMin(low, rates[i].low);
   return (low < DBL_MAX) ? low : 0.0;
  }

double Strategy_KER(const MqlRates &rates[])
  {
   const int period = MathMax(1, strategy_ker_period);
   if(ArraySize(rates) <= period)
      return 0.0;

   const double direction = MathAbs(rates[0].close - rates[period].close);
   double path = 0.0;
   for(int i = 0; i < period; ++i)
      path += MathAbs(rates[i].close - rates[i + 1].close);

   if(path <= 0.0)
      return 0.0;
   return direction / path;
  }

void Strategy_UpdateRegime(const double ker)
  {
   if(ker >= strategy_ker_trend_level)
      g_active_regime = STRATEGY_REGIME_TREND;
   else if(ker <= strategy_ker_mr_level)
      g_active_regime = STRATEGY_REGIME_MEANREV;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_BuildMarketRequest(const QM_OrderType side,
                                 const double atr_mult,
                                 const string reason,
                                 QM_EntryRequest &req)
  {
   const double entry = QM_OrderTypeIsBuy(side)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   if(entry <= 0.0 || atr <= 0.0 || atr_mult <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(QM_StopATRFromValue(_Symbol, side, entry, atr, atr_mult));
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return (req.sl > 0.0);
  }

void Strategy_UpdateCachedExit(const MqlRates &rates[])
  {
   g_cached_exit_signal = false;

   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   datetime open_time;
   string comment;
   if(!Strategy_SelectOurPosition(ticket, pos_type, open_time, comment))
      return;

   const bool is_long = (pos_type == POSITION_TYPE_BUY);
   const bool is_trend = (StringFind(comment, "TREND_") >= 0);
   const bool is_meanrev = (StringFind(comment, "MEANREV_") >= 0);
   const int exit_dc = MathMax(1, strategy_trend_exit_dc);

   if(is_trend)
     {
      if(ArraySize(rates) < exit_dc + 1)
         return;
      const double prior_upper = Strategy_DonchianHigh(rates, 1, exit_dc);
      const double prior_lower = Strategy_DonchianLow(rates, 1, exit_dc);
      if(is_long && prior_lower > 0.0 && rates[0].close < prior_lower)
         g_cached_exit_signal = true;
      else if(!is_long && prior_upper > 0.0 && rates[0].close > prior_upper)
         g_cached_exit_signal = true;
      return;
     }

   if(is_meanrev || is_long)
     {
      if(ArraySize(rates) > 1 && rates[1].high > 0.0 && rates[0].close > rates[1].high)
         g_cached_exit_signal = true;
     }
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_signal_tf)
      return true;
   return !Strategy_SpreadAllows();
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   const int need = MathMax(MathMax(strategy_ker_period + 1,
                                    strategy_trend_entry_dc + 2),
                            strategy_trend_exit_dc + 2);
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates, need))
      return false;

   Strategy_UpdateRegime(Strategy_KER(rates));
   Strategy_UpdateCachedExit(rates);

   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   datetime open_time;
   string comment;
   if(Strategy_SelectOurPosition(ticket, pos_type, open_time, comment))
      return false;

   if(!Strategy_SpreadAllows())
      return false;

   const int entry_dc = MathMax(1, strategy_trend_entry_dc);
   const double prior_upper = Strategy_DonchianHigh(rates, 1, entry_dc);
   const double prior_lower = Strategy_DonchianLow(rates, 1, entry_dc);
   const double close_last = rates[0].close;

   if(g_active_regime == STRATEGY_REGIME_TREND)
     {
      if(prior_upper > 0.0 && close_last > prior_upper)
         return Strategy_BuildMarketRequest(QM_BUY, strategy_trend_atr_mult, "TREND_LONG", req);
      if(prior_lower > 0.0 && close_last < prior_lower)
         return Strategy_BuildMarketRequest(QM_SELL, strategy_trend_atr_mult, "TREND_SHORT", req);
      return false;
     }

   const double rsi = QM_RSI(_Symbol, strategy_signal_tf, MathMax(1, strategy_rsi_period), 1);
   if(rsi > 0.0 && rsi < strategy_rsi_mr_level)
      return Strategy_BuildMarketRequest(QM_BUY, strategy_mr_atr_mult, "MEANREV_LONG", req);

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial, or pyramiding logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   datetime open_time;
   string comment;
   if(!Strategy_SelectOurPosition(ticket, pos_type, open_time, comment))
      return false;

   if(StringFind(comment, "MEANREV_") >= 0 && strategy_mr_time_exit_days > 0)
     {
      const int seconds = strategy_mr_time_exit_days * 86400;
      if(open_time > 0 && (TimeCurrent() - open_time) >= seconds)
         return true;
     }

   return g_cached_exit_signal;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   g_active_regime = STRATEGY_REGIME_MEANREV;
   g_cached_exit_signal = false;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12541\",\"strategy\":\"ker_regime_dual_idx\"}");
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
