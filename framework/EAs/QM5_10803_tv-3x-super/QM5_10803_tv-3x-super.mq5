#property strict
#property version   "5.0"
#property description "QM5_10803 Triple Supertrend Trend Filter"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10803;
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
input int    strategy_fast_atr_period    = 7;
input int    strategy_medium_atr_period  = 10;
input int    strategy_slow_atr_period    = 14;
input double strategy_fast_multiplier    = 2.0;
input double strategy_medium_multiplier  = 3.0;
input double strategy_slow_multiplier    = 4.0;
input int    strategy_stop_atr_period    = 14;
input double strategy_stop_atr_mult      = 2.0;
input int    strategy_supertrend_warmup_bars = 160;
input bool   strategy_trade_window_enabled = false;
input int    strategy_trade_start_hour   = 0;
input int    strategy_trade_end_hour     = 24;

int  g_fast_dir_1   = 0;
int  g_fast_dir_2   = 0;
int  g_medium_dir_1 = 0;
int  g_slow_dir_1   = 0;
bool g_signal_cache_ready = false;

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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

int Strategy_SupertrendDirection(const int atr_period,
                                 const double multiplier,
                                 const int target_shift)
  {
   if(atr_period <= 0 || multiplier <= 0.0 || target_shift < 1)
      return 0;

   const int warmup = MathMax(strategy_supertrend_warmup_bars, atr_period + 20);
   const int count = MathMin(MathMax(warmup, 40), 500);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, target_shift, count, rates); // perf-allowed: bounded closed-bar Supertrend OHLC window; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < MathMin(count, atr_period + 5))
      return 0;

   double final_upper = 0.0;
   double final_lower = 0.0;
   int dir = 0;

   for(int idx = copied - 1; idx >= 0; --idx)
     {
      const int shift = target_shift + idx;
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, atr_period, shift);
      if(atr <= 0.0 || rates[idx].high <= 0.0 || rates[idx].low <= 0.0 || rates[idx].close <= 0.0)
         continue;

      const double median_price = (rates[idx].high + rates[idx].low) * 0.5;
      const double basic_upper = median_price + multiplier * atr;
      const double basic_lower = median_price - multiplier * atr;

      if(final_upper <= 0.0 || final_lower <= 0.0)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         dir = (rates[idx].close >= median_price) ? 1 : -1;
         continue;
        }

      const double prev_close = (idx + 1 < copied) ? rates[idx + 1].close : rates[idx].close;
      const double prev_upper = final_upper;
      const double prev_lower = final_lower;

      final_upper = (basic_upper < prev_upper || prev_close > prev_upper) ? basic_upper : prev_upper;
      final_lower = (basic_lower > prev_lower || prev_close < prev_lower) ? basic_lower : prev_lower;

      if(dir < 0 && rates[idx].close > final_upper)
         dir = 1;
      else if(dir > 0 && rates[idx].close < final_lower)
         dir = -1;
     }

   return dir;
  }

bool Strategy_UpdateSignalCache()
  {
   g_signal_cache_ready = false;
   g_fast_dir_1 = Strategy_SupertrendDirection(strategy_fast_atr_period, strategy_fast_multiplier, 1);
   g_fast_dir_2 = Strategy_SupertrendDirection(strategy_fast_atr_period, strategy_fast_multiplier, 2);
   g_medium_dir_1 = Strategy_SupertrendDirection(strategy_medium_atr_period, strategy_medium_multiplier, 1);
   g_slow_dir_1 = Strategy_SupertrendDirection(strategy_slow_atr_period, strategy_slow_multiplier, 1);

   g_signal_cache_ready = (g_fast_dir_1 != 0 &&
                           g_fast_dir_2 != 0 &&
                           g_medium_dir_1 != 0 &&
                           g_slow_dir_1 != 0);
   return g_signal_cache_ready;
  }

bool Strategy_NoTradeFilter()
  {
   if(!strategy_trade_window_enabled)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_hour = MathMax(0, MathMin(23, strategy_trade_start_hour));
   const int end_hour = MathMax(0, MathMin(24, strategy_trade_end_hour));

   if(start_hour == end_hour)
      return false;
   if(start_hour < end_hour)
      return !(dt.hour >= start_hour && dt.hour < end_hour);
   return !(dt.hour >= start_hour || dt.hour < end_hour);
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

   if(!Strategy_UpdateSignalCache())
      return false;
   if(Strategy_HasOurPosition())
      return false;

   const bool long_signal = (g_fast_dir_1 > 0 && g_fast_dir_2 < 0 &&
                             g_medium_dir_1 > 0 && g_slow_dir_1 > 0);
   const bool short_signal = (g_fast_dir_1 < 0 && g_fast_dir_2 > 0 &&
                              g_medium_dir_1 < 0 && g_slow_dir_1 < 0);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double stop = QM_StopATR(_Symbol, side, entry, strategy_stop_atr_period, strategy_stop_atr_mult);
   if(stop <= 0.0)
      return false;

   req.type = side;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = long_signal ? "TRIPLE_ST_FAST_FLIP_LONG" : "TRIPLE_ST_FAST_FLIP_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!g_signal_cache_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_fast_dir_1 < 0 && g_fast_dir_2 > 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_fast_dir_1 > 0 && g_fast_dir_2 < 0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10803_tv-3x-super\"}");
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
