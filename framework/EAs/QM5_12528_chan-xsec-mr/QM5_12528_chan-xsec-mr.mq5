#property strict
#property version   "5.0"
#property description "QM5_12528 Chan Cross-Sectional Mean Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12528;
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
input int    strategy_return_lookback_days = 1;
input int    strategy_min_basket_size      = 5;
input double strategy_min_abs_weight       = 0.05;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_spread_median_days   = 60;

#define STRATEGY_BASKET_COUNT 8

string g_strategy_basket[STRATEGY_BASKET_COUNT] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "XAUUSD.DWX"
  };

int Strategy_BasketIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
      if(g_strategy_basket[i] == symbol)
         return i;
   return -1;
  }

double Strategy_ReturnForSymbol(const string symbol, const int lookback)
  {
   if(lookback < 1)
      return 0.0;

   const double c0 = iClose(symbol, PERIOD_D1, 1);            // perf-allowed: fixed closed D1 close for card cross-sectional return, called only after D1 new-bar gate.
   const double c1 = iClose(symbol, PERIOD_D1, 1 + lookback); // perf-allowed: fixed closed D1 lookback close for card cross-sectional return, called only after D1 new-bar gate.
   if(c0 <= 0.0 || c1 <= 0.0)
      return 0.0;

   return (c0 - c1) / c1;
  }

bool Strategy_TargetWeightForSymbol(const string symbol,
                                    double &target_weight,
                                    int &active_count)
  {
   target_weight = 0.0;
   active_count = 0;

   const int target_index = Strategy_BasketIndexForSymbol(symbol);
   if(target_index < 0)
      return false;

   double returns[STRATEGY_BASKET_COUNT];
   bool active[STRATEGY_BASKET_COUNT];
   ArrayInitialize(returns, 0.0);
   ArrayInitialize(active, false);

   double mean_return = 0.0;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      const double r = Strategy_ReturnForSymbol(g_strategy_basket[i], strategy_return_lookback_days);
      if(r == 0.0)
         continue;

      returns[i] = r;
      active[i] = true;
      mean_return += r;
      ++active_count;
     }

   if(active_count < strategy_min_basket_size)
      return false;
   if(!active[target_index])
      return false;

   mean_return /= (double)active_count;

   double denominator = 0.0;
   double target_score = 0.0;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      if(!active[i])
         continue;

      const double score = -(returns[i] - mean_return);
      denominator += MathAbs(score);
      if(i == target_index)
         target_score = score;
     }

   if(denominator <= 0.0)
      return false;

   target_weight = target_score / denominator;
   return true;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
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

double Strategy_CurrentSpreadPoints()
  {
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > 0) ? (double)spread_points : 0.0;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_median_days <= 1)
      return true;

   const double current_spread = Strategy_CurrentSpreadPoints();
   if(current_spread <= 0.0)
      return true;

   MqlRates rates[];
   const int requested = MathMax(2, strategy_spread_median_days);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: bounded 60D spread-history read, called only after D1 new-bar gate.
   if(copied <= 0)
      return true;

   double spreads[];
   ArrayResize(spreads, copied);
   int used = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[used] = (double)rates[i].spread;
      ++used;
     }

   if(used <= 0)
      return true;

   ArrayResize(spreads, used);
   ArraySort(spreads);
   const int mid = used / 2;
   double median_spread = spreads[mid];
   if((used % 2) == 0)
      median_spread = 0.5 * (spreads[mid - 1] + spreads[mid]);

   if(median_spread <= 0.0)
      return true;

   return (current_spread <= 2.0 * median_spread);
  }

// No Trade Filter — block non-basket symbols; news and Friday close are framework gates.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_BasketIndexForSymbol(_Symbol) < 0)
      return true;
   return false;
  }

// Trade Entry — daily contrarian cross-sectional target weight.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_POSITION_TYPE position_type;
   if(Strategy_HasOpenPosition(position_type))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double target_weight = 0.0;
   int active_count = 0;
   if(!Strategy_TargetWeightForSymbol(_Symbol, target_weight, active_count))
      return false;

   if(MathAbs(target_weight) <= strategy_min_abs_weight)
      return false;

   QM_OrderType side = QM_BUY;
   double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   string reason = "CHAN_XSEC_MR_LONG";
   if(target_weight < -strategy_min_abs_weight)
     {
      side = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      reason = "CHAN_XSEC_MR_SHORT";
     }

   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = reason;

   if(req.sl <= 0.0)
      return false;
   if(side == QM_BUY && req.sl >= entry)
      return false;
   if(side == QM_SELL && req.sl <= entry)
      return false;

   return true;
  }

// Trade Management — card specifies no trailing, partial close, or break-even logic.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — daily rebalance exits positions whose target weight disappears or flips.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   double target_weight = 0.0;
   int active_count = 0;
   if(!Strategy_TargetWeightForSymbol(_Symbol, target_weight, active_count))
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return (target_weight < strategy_min_abs_weight);
   if(position_type == POSITION_TYPE_SELL)
      return (target_weight > -strategy_min_abs_weight);

   return false;
  }

// News Filter Hook — defer to the framework two-axis news filter.
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

   QM_SymbolGuardInit(g_strategy_basket);
   QM_BasketWarmupHistory(g_strategy_basket, PERIOD_D1, MathMax(strategy_atr_period + 10, strategy_spread_median_days + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12528\",\"ea\":\"QM5_12528_chan-xsec-mr\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

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
