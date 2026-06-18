#property strict
#property version   "5.0"
#property description "QM5_1552 Alpha Architect REIT volatility-adjusted momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1552;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 0.3333333333;

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
input int    strategy_momentum_days      = 260;  // 12-month D1 return window
input int    strategy_volatility_days    = 260;  // realized-vol window for score
input int    strategy_top_n              = 3;    // baseline top-3 selection
input int    strategy_min_daily_bars     = 260;  // card minimum bar count
input int    strategy_atr_period         = 20;   // initial SL ATR period
input double strategy_atr_sl_mult        = 3.0;  // initial SL = 3.0 x ATR(20,D1)
input double strategy_max_spread_points  = 0.0;  // 0 = framework/default only

string g_universe[5] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"};
const int UNIVERSE_SIZE = 5;

bool   g_is_selected = false;
bool   g_has_valid_rank = false;
double g_my_score = 0.0;
int    g_my_rank = -1;
int    g_last_month_key = 0;

int CurrentMonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

int CurrentSlot()
  {
   for(int i = 0; i < UNIVERSE_SIZE; ++i)
      if(_Symbol == g_universe[i])
         return i;
   return -1;
  }

bool HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double ComputeReturn(const MqlRates &rates[], const int lookback)
  {
   if(ArraySize(rates) <= lookback)
      return 0.0;
   const double past = rates[0].close;
   const double recent = rates[lookback].close;
   if(recent <= 0.0 || past <= 0.0)
      return 0.0;
   return (recent / past) - 1.0;
  }

double ComputeRealizedVolatility(const MqlRates &rates[], const int lookback)
  {
   if(ArraySize(rates) <= lookback || lookback < 2)
      return 0.0;

   double sum = 0.0;
   double sumsq = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double c0 = rates[i].close;
      const double c1 = rates[i - 1].close;
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double r = MathLog(c0 / c1);
      sum += r;
      sumsq += r * r;
     }

   const double mean = sum / lookback;
   const double variance = (sumsq / lookback) - (mean * mean);
   return (variance > 0.0) ? MathSqrt(variance) : 0.0;
  }

void RefreshMonthlySelection()
  {
   const int my_slot = CurrentSlot();
   g_is_selected = false;
   g_has_valid_rank = false;
   g_my_score = 0.0;
   g_my_rank = -1;

   const int lookback = MathMax(strategy_momentum_days, strategy_volatility_days);
   const int bars_needed = lookback + 1;
   double scores[5];
   double trends[5];
   bool valid[5];

   for(int i = 0; i < UNIVERSE_SIZE; ++i)
     {
      scores[i] = -DBL_MAX;
      trends[i] = 0.0;
      valid[i] = false;

      const string sym = g_universe[i];
      if(Bars(sym, PERIOD_D1) < strategy_min_daily_bars + 2) // perf-allowed: monthly basket bar-count gate
         continue;

      MqlRates rates[];
      const int copied = CopyRates(sym, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: monthly cross-symbol return/volatility ranking, cached until next month
      if(copied < bars_needed)
         continue;

      const double ret = ComputeReturn(rates, strategy_momentum_days);
      const double vol = ComputeRealizedVolatility(rates, strategy_volatility_days);
      if(vol <= 0.0)
         continue;

      trends[i] = ret;
      scores[i] = ret / vol;
      valid[i] = true;
     }

   if(my_slot < 0 || !valid[my_slot])
     {
      QM_LogEvent(QM_INFO, "REBALANCE",
                  StringFormat("{\"selected\":false,\"reason\":\"%s\",\"slot\":%d}",
                               my_slot < 0 ? "symbol_not_in_universe" : "insufficient_data",
                               my_slot));
      return;
     }

   int rank = 0;
   for(int i = 0; i < UNIVERSE_SIZE; ++i)
     {
      if(i == my_slot || !valid[i])
         continue;
      if(scores[i] > scores[my_slot])
         ++rank;
     }

   g_has_valid_rank = true;
   g_my_rank = rank + 1;
   g_my_score = scores[my_slot];
   g_is_selected = (rank < strategy_top_n && trends[my_slot] > 0.0);

   QM_LogEvent(QM_INFO, "REBALANCE",
               StringFormat("{\"selected\":%s,\"rank\":%d,\"score\":%.8f,\"trend\":%.8f,\"top_n\":%d}",
                            g_is_selected ? "true" : "false",
                            g_my_rank,
                            g_my_score,
                            trends[my_slot],
                            strategy_top_n));
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(CurrentSlot() < 0)
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > (int)strategy_max_spread_points)
         return true;
     }

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

   if(!g_has_valid_rank || !g_is_selected)
      return false;
   if(HasOpenPosition())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   req.reason = "aa-reit-vamom-monthly-long";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition())
      return false;
   return (!g_has_valid_rank || !g_is_selected);
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

   QM_SymbolGuardInit(g_universe);
   QM_BasketWarmupHistory(g_universe, PERIOD_D1, strategy_min_daily_bars + 10);

   RefreshMonthlySelection();
   g_last_month_key = CurrentMonthKey();

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1552\",\"ea\":\"QM5_1552_aa-reit-vamom\"}");
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

   const int month_key = CurrentMonthKey();
   if(month_key != g_last_month_key)
     {
      g_last_month_key = month_key;
      RefreshMonthlySelection();
     }

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
