#property strict
#property version   "5.0"
#property description "QM5_12919 AMP value momentum cross-asset"

#include <QM/QM_Common.mqh>

#define STRATEGY_SYMBOL_COUNT 8

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12919;
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
input int    strategy_top_n                    = 3;
input int    strategy_min_eligible_symbols     = 6;
input int    strategy_skip_recent_days         = 21;
input int    strategy_momentum_lookback_days   = 252;
input int    strategy_value_lookback_days      = 1260;
input double strategy_momentum_weight          = 0.50;
input double strategy_value_weight             = 0.50;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 3.0;
input int    strategy_rebalance_start_hour     = 0;
input int    strategy_rebalance_end_hour       = 23;
input int    strategy_max_spread_points        = 0;

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "GDAXI.DWX",
   "NDX.DWX",
   "UK100.DWX",
   "WS30.DWX",
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX"
  };

int g_last_entry_month_key = 0;
int g_last_exit_month_key = 0;

int Strategy_MaxInt(const int a, const int b)
  {
   return (a > b ? a : b);
  }

int Strategy_MinInt(const int a, const int b)
  {
   return (a < b ? a : b);
  }

int Strategy_SymbolSlot(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == symbol)
         return i;
   return -1;
  }

bool Strategy_IsTarget()
  {
   const int slot = Strategy_SymbolSlot(_Symbol);
   if(slot < 0)
      return false;
   if(qm_magic_slot_offset != slot)
      return false;
   return ((ENUM_TIMEFRAMES)_Period == PERIOD_M30);
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

bool Strategy_RebalanceHourAllowed()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_rebalance_start_hour && dt.hour <= strategy_rebalance_end_hour);
  }

bool Strategy_IsFirstTradingDayOfMonth()
  {
   const int current_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int previous_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   return (current_month > 0 && previous_month > 0 && current_month != previous_month);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

bool Strategy_RawSignals(const string symbol, double &momentum, double &value)
  {
   momentum = 0.0;
   value = 0.0;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   const int max_lookback = Strategy_MaxInt(strategy_momentum_lookback_days, strategy_value_lookback_days);
   const int required_bars = strategy_skip_recent_days + max_lookback + 5;
   if(Bars(symbol, PERIOD_D1) < required_bars) // perf-allowed: monthly D1 history sufficiency check.
      return false;

   const int signal_shift = strategy_skip_recent_days;
   const int momentum_shift = strategy_skip_recent_days + strategy_momentum_lookback_days;
   const int value_shift = strategy_skip_recent_days + strategy_value_lookback_days;

   const double signal_close = iClose(symbol, PERIOD_D1, signal_shift);     // perf-allowed: monthly cross-sectional D1 close read.
   const double momentum_close = iClose(symbol, PERIOD_D1, momentum_shift); // perf-allowed: monthly cross-sectional D1 close read.
   const double value_close = iClose(symbol, PERIOD_D1, value_shift);       // perf-allowed: monthly cross-sectional D1 close read.
   if(signal_close <= 0.0 || momentum_close <= 0.0 || value_close <= 0.0)
      return false;

   momentum = (signal_close / momentum_close) - 1.0;
   value = -1.0 * ((signal_close / value_close) - 1.0);
   return true;
  }

double Strategy_Mean(const double &values[], const bool &eligible[])
  {
   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(!eligible[i])
         continue;
      sum += values[i];
      count++;
     }
   if(count <= 0)
      return 0.0;
   return sum / (double)count;
  }

double Strategy_StdDev(const double &values[], const bool &eligible[], const double mean)
  {
   double variance = 0.0;
   int count = 0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(!eligible[i])
         continue;
      const double diff = values[i] - mean;
      variance += diff * diff;
      count++;
     }
   if(count < 2)
      return 0.0;
   return MathSqrt(variance / (double)count);
  }

int Strategy_BuildScores(double &scores[], bool &eligible[])
  {
   double momentum[];
   double value[];
   ArrayResize(momentum, STRATEGY_SYMBOL_COUNT);
   ArrayResize(value, STRATEGY_SYMBOL_COUNT);
   ArrayResize(scores, STRATEGY_SYMBOL_COUNT);
   ArrayResize(eligible, STRATEGY_SYMBOL_COUNT);

   int eligible_count = 0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      momentum[i] = 0.0;
      value[i] = 0.0;
      scores[i] = 0.0;
      eligible[i] = false;
      if(!Strategy_RawSignals(g_strategy_symbols[i], momentum[i], value[i]))
         continue;
      eligible[i] = true;
      eligible_count++;
     }

   if(eligible_count < strategy_min_eligible_symbols)
      return eligible_count;

   const double momentum_mean = Strategy_Mean(momentum, eligible);
   const double value_mean = Strategy_Mean(value, eligible);
   const double momentum_sd = Strategy_StdDev(momentum, eligible, momentum_mean);
   const double value_sd = Strategy_StdDev(value, eligible, value_mean);
   if(momentum_sd <= 0.0 || value_sd <= 0.0)
      return 0;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(!eligible[i])
         continue;
      const double z_momentum = (momentum[i] - momentum_mean) / momentum_sd;
      const double z_value = (value[i] - value_mean) / value_sd;
      scores[i] = strategy_momentum_weight * z_momentum + strategy_value_weight * z_value;
     }
   return eligible_count;
  }

int Strategy_DescendingRank(const int symbol_slot,
                            const double &scores[],
                            const bool &eligible[])
  {
   if(symbol_slot < 0 || symbol_slot >= STRATEGY_SYMBOL_COUNT)
      return 999;
   if(!eligible[symbol_slot])
      return 999;

   int rank = 1;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(i == symbol_slot || !eligible[i])
         continue;
      if(scores[i] > scores[symbol_slot])
         rank++;
      else if(scores[i] == scores[symbol_slot] && i < symbol_slot)
         rank++;
     }
   return rank;
  }

bool Strategy_IsSelectedTopScore()
  {
   const int symbol_slot = Strategy_SymbolSlot(_Symbol);
   if(symbol_slot < 0)
      return false;

   double scores[];
   bool eligible[];
   const int eligible_count = Strategy_BuildScores(scores, eligible);
   if(eligible_count < strategy_min_eligible_symbols)
      return false;

   const int selected_n = Strategy_MinInt(strategy_top_n, eligible_count);
   if(selected_n <= 0)
      return false;

   const int rank = Strategy_DescendingRank(symbol_slot, scores, eligible);
   return (rank <= selected_n);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(strategy_top_n <= 0 || strategy_top_n > STRATEGY_SYMBOL_COUNT)
      return true;
   if(strategy_min_eligible_symbols < strategy_top_n || strategy_min_eligible_symbols > STRATEGY_SYMBOL_COUNT)
      return true;
   if(strategy_skip_recent_days < 1)
      return true;
   if(strategy_momentum_lookback_days <= strategy_skip_recent_days)
      return true;
   if(strategy_value_lookback_days <= strategy_momentum_lookback_days)
      return true;
   if(strategy_momentum_weight < 0.0 || strategy_value_weight < 0.0)
      return true;
   if(strategy_momentum_weight + strategy_value_weight <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_rebalance_start_hour < 0 || strategy_rebalance_start_hour > 23)
      return true;
   if(strategy_rebalance_end_hour < strategy_rebalance_start_hour || strategy_rebalance_end_hour > 23)
      return true;
   if(Strategy_WideSpread())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "AMP_VALUE_MOMENTUM_TOP3";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsFirstTradingDayOfMonth())
      return false;
   if(!Strategy_RebalanceHourAllowed())
      return false;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   if(!Strategy_IsSelectedTopScore())
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry_price, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry_price)
      return false;

   g_last_entry_month_key = month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsFirstTradingDayOfMonth())
      return false;
   if(!Strategy_RebalanceHourAllowed())
      return false;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0 || month_key == g_last_exit_month_key)
      return false;

   g_last_exit_month_key = month_key;
   return !Strategy_IsSelectedTopScore();
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

   QM_SymbolGuardInit(g_strategy_symbols);
   const int warmup_bars = strategy_skip_recent_days +
                           Strategy_MaxInt(strategy_momentum_lookback_days, strategy_value_lookback_days) +
                           20;
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, warmup_bars);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_M30, 96);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12919\",\"ea\":\"amp-value-momentum-xasset\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
