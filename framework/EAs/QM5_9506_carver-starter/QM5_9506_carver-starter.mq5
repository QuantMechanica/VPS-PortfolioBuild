#property strict
#property version   "5.0"
#property description "QM5_9506 Carver Starter SMA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9506;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_sma_period     = 16;
input int    strategy_slow_sma_period     = 64;
input int    strategy_risk_lookback_bars  = 256;
input int    strategy_atr_period          = 25;
input double strategy_annual_risk_mult    = 0.50;
input double strategy_min_atr_stop_mult   = 2.0;
input double strategy_max_atr_stop_mult   = 8.0;
input int    strategy_max_hold_bars       = 252;
input int    strategy_min_history_bars    = 300;
input int    strategy_spread_median_days  = 60;
input double strategy_spread_mult         = 2.0;

double CurrentSpreadPoints()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return -1.0;
   if(ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

double MedianPositiveD1SpreadPoints()
  {
   if(strategy_spread_median_days <= 0)
      return 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, rates); // perf-allowed: bounded D1 spread sample, called only from the framework new-bar entry hook.
   if(copied <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[count] = (double)rates[i].spread;
         ++count;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(spreads, count);
   ArraySort(spreads);
   if((count % 2) == 1)
      return spreads[count / 2];
   return 0.5 * (spreads[(count / 2) - 1] + spreads[count / 2]);
  }

bool SpreadAllowsEntry()
  {
   const double current_spread = CurrentSpreadPoints();
   if(current_spread < 0.0)
      return false;

   const double median_spread = MedianPositiveD1SpreadPoints();
   if(median_spread <= 0.0)
      return (current_spread <= 0.0);

   return (current_spread <= strategy_spread_mult * median_spread);
  }

bool HasEnoughHistory()
  {
   const int required = MathMax(strategy_min_history_bars,
                                MathMax(strategy_slow_sma_period + 3,
                                        strategy_risk_lookback_bars + 2));
   return (Bars(_Symbol, PERIOD_D1) >= required); // perf-allowed: cheap D1 history guard, new-bar entry path only.
  }

double AnnualizedStdDevPrice()
  {
   const int lookback = MathMax(30, strategy_risk_lookback_bars);
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 return window for Carver stop sizing.
   if(copied < lookback + 1)
      return 0.0;

   double mean = 0.0;
   double returns[];
   ArrayResize(returns, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
         return 0.0;
      returns[i] = MathLog(closes[i] / closes[i + 1]);
      mean += returns[i];
     }
   mean /= (double)lookback;

   double var = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double d = returns[i] - mean;
      var += d * d;
     }

   const double daily_sd = MathSqrt(var / (double)MathMax(1, lookback - 1));
   const double last_close = closes[0];
   return last_close * daily_sd * MathSqrt(252.0);
  }

double StopDistancePrice()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return 0.0;

   double dist = strategy_annual_risk_mult * AnnualizedStdDevPrice();
   const double min_dist = strategy_min_atr_stop_mult * atr;
   const double max_dist = strategy_max_atr_stop_mult * atr;
   if(dist <= 0.0)
      dist = min_dist;
   if(dist < min_dist)
      dist = min_dist;
   if(dist > max_dist)
      dist = max_dist;
   return dist;
  }

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool CrossedLong()
  {
   const double fast_now = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1);
   const double slow_now = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 1);
   const double fast_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 2);
   const double slow_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 2);
   return (fast_now > slow_now && fast_prev <= slow_prev);
  }

bool CrossedShort()
  {
   const double fast_now = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1);
   const double slow_now = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 1);
   const double fast_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 2);
   const double slow_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 2);
   return (fast_now < slow_now && fast_prev >= slow_prev);
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_D1);
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

   ulong ticket = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(SelectOurPosition(ticket, pos_type, open_time))
      return false;
   if(!HasEnoughHistory())
      return false;
   if(!SpreadAllowsEntry())
      return false;

   const bool long_signal = CrossedLong();
   const bool short_signal = CrossedShort();
   if(!long_signal && !short_signal)
      return false;

   const double stop_dist = StopDistancePrice();
   if(stop_dist <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(long_signal)
     {
      req.type = QM_BUY;
      req.sl = ask - stop_dist;
      req.reason = "CARVER_STARTER_SMA_LONG";
     }
   else
     {
      req.type = QM_SELL;
      req.sl = bid + stop_dist;
      req.reason = "CARVER_STARTER_SMA_SHORT";
     }

   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!SelectOurPosition(ticket, pos_type, open_time))
      return false;

   const double fast_now = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1);
   const double slow_now = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 1);
   if(pos_type == POSITION_TYPE_BUY && fast_now < slow_now)
      return true;
   if(pos_type == POSITION_TYPE_SELL && fast_now > slow_now)
      return true;

   if(strategy_max_hold_bars > 0 && open_time > 0)
     {
      const long max_seconds = (long)strategy_max_hold_bars * 86400L;
      if((long)(TimeCurrent() - open_time) >= max_seconds)
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
