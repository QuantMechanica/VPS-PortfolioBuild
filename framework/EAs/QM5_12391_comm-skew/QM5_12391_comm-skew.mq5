#property strict
#property version   "5.0"
#property description "QM5_12391 Commodity Skewness Cross-Section"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12391;
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
input int    strategy_return_lookback_d1 = 252;
input int    strategy_min_warmup_d1      = 260;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_spread_lookback_d1 = 60;
input double strategy_spread_median_mult = 2.0;
input int    strategy_legs_per_side      = 1;

#define STRATEGY_UNIVERSE_COUNT 4

string g_strategy_universe[STRATEGY_UNIVERSE_COUNT] =
  {
   "XAUUSD.DWX",
   "XAGUSD.DWX",
   "XTIUSD.DWX",
   "XNGUSD.DWX"
  };

int g_last_rebalance_close_month = 0;

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, bars) != 2) // perf-allowed: fixed two-bar month-boundary read inside D1 framework gate.
      return false;

   return (Strategy_MonthKey(bars[0].time) != Strategy_MonthKey(bars[1].time));
  }

int Strategy_CurrentSymbolSlot()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
      if(g_strategy_universe[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_HasOurPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;

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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_ComputeSkewness(const string symbol, double &out_skew)
  {
   out_skew = 0.0;

   const int lookback = strategy_return_lookback_d1;
   if(lookback < 20 || lookback > 512)
      return false;
   if(strategy_min_warmup_d1 < lookback + 1)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int needed = MathMax(strategy_min_warmup_d1, lookback + 1);
   if(CopyRates(symbol, PERIOD_D1, 1, needed, rates) < lookback + 1) // perf-allowed: bounded daily return window, called only from framework new-bar gated entry/rebalance logic.
      return false;

   double sum = 0.0;
   double returns[];
   ArrayResize(returns, lookback);

   for(int i = 0; i < lookback; ++i)
     {
      const double c0 = rates[i].close;
      const double c1 = rates[i + 1].close;
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;

      const double r = MathLog(c0 / c1);
      if(!MathIsValidNumber(r))
         return false;
      returns[i] = r;
      sum += r;
     }

   const double mean = sum / (double)lookback;
   double second_sum = 0.0;
   double third_sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double centered = returns[i] - mean;
      const double centered2 = centered * centered;
      second_sum += centered2;
      third_sum += centered2 * centered;
     }

   const double variance = second_sum / (double)lookback;
   if(variance <= 0.0)
      return false;

   const double sigma = MathSqrt(variance);
   if(sigma <= 0.0)
      return false;

   out_skew = (third_sum / (double)lookback) / (sigma * sigma * sigma);
   return MathIsValidNumber(out_skew);
  }

int Strategy_CurrentRankDirection()
  {
   string symbols[STRATEGY_UNIVERSE_COUNT];
   double skew[STRATEGY_UNIVERSE_COUNT];
   int eligible = 0;

   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
     {
      double value = 0.0;
      if(!Strategy_ComputeSkewness(g_strategy_universe[i], value))
         continue;

      symbols[eligible] = g_strategy_universe[i];
      skew[eligible] = value;
      ++eligible;
     }

   if(eligible < STRATEGY_UNIVERSE_COUNT)
      return 0;

   for(int i = 0; i < eligible - 1; ++i)
     {
      for(int j = i + 1; j < eligible; ++j)
        {
         if(skew[j] < skew[i])
           {
            const double skew_tmp = skew[i];
            skew[i] = skew[j];
            skew[j] = skew_tmp;

            const string symbol_tmp = symbols[i];
            symbols[i] = symbols[j];
            symbols[j] = symbol_tmp;
           }
        }
     }

   const int legs = MathMax(1, MathMin(strategy_legs_per_side, eligible / 2));
   for(int i = 0; i < legs; ++i)
      if(symbols[i] == _Symbol)
         return 1;

   for(int i = eligible - legs; i < eligible; ++i)
      if(symbols[i] == _Symbol)
         return -1;

   return 0;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_lookback_d1 <= 0 || strategy_spread_median_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_lookback_d1, rates); // perf-allowed: bounded spread median window, called only from framework new-bar gated entry logic.
   if(copied < MathMin(10, strategy_spread_lookback_d1))
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   for(int i = 0; i < copied; ++i)
      spreads[i] = (double)MathMax(0, rates[i].spread);

   for(int i = 0; i < copied - 1; ++i)
     {
      for(int j = i + 1; j < copied; ++j)
        {
         if(spreads[j] < spreads[i])
           {
            const double tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }
        }
     }

   const double median = (copied % 2 == 1)
                         ? spreads[copied / 2]
                         : 0.5 * (spreads[copied / 2 - 1] + spreads[copied / 2]);
   if(median <= 0.0)
      return true;

   return ((double)current_spread <= strategy_spread_median_mult * median);
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int slot = Strategy_CurrentSymbolSlot();
   if(slot < 0)
      return true;
   if(qm_magic_slot_offset != slot)
      return true;

   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(req.symbol_slot < 0)
      return false;
   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   ENUM_POSITION_TYPE position_type;
   if(Strategy_HasOurPosition(position_type))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_CurrentRankDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "QM5_12391_LOW_SKEW_LONG" : "QM5_12391_HIGH_SKEW_SHORT";
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card specifies monthly rebalance exits and an ATR emergency stop at entry.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOurPosition(position_type))
      return false;
   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int month_key = Strategy_MonthKey(TimeCurrent());
   if(g_last_rebalance_close_month == month_key)
      return false;
   g_last_rebalance_close_month = month_key;

   const int direction = Strategy_CurrentRankDirection();
   if(direction == 0)
      return true;
   if(direction > 0 && position_type != POSITION_TYPE_BUY)
      return true;
   if(direction < 0 && position_type != POSITION_TYPE_SELL)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — unchanged except basket symbol guard and D1 warmup.
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

   QM_SymbolGuardInit(g_strategy_universe);
   QM_BasketWarmupHistory(g_strategy_universe, PERIOD_D1, strategy_min_warmup_d1 + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12391\",\"ea\":\"QM5_12391_comm-skew\"}");
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
