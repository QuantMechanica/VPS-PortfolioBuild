#property strict
#property version   "5.0"
#property description "QM5_12404 stock-lowvol — monthly low-volatility CFD basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12404;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_vol_lookback_d1       = 252;
input int    strategy_bucket_size           = 1;
input int    strategy_min_valid_symbols     = 6;
input int    strategy_min_warmup_d1         = 270;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 2.5;
input int    strategy_spread_median_days    = 60;
input double strategy_spread_median_mult    = 2.0;
input bool   strategy_use_sma200_filter     = false;
input int    strategy_sma_period_d1         = 200;
input double strategy_basket_stop_r         = 5.0;

string g_universe[7] = {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
};
const int UNIVERSE_SIZE = 7;

bool   g_is_selected          = false;
bool   g_state_ready          = false;
double g_selected_vol         = 0.0;
int    g_selected_rank        = -1;
int    g_valid_symbol_count   = 0;
double g_median_spread_points = 0.0;
int    g_last_rebalance_mon   = -1;
int    g_last_rebalance_yr    = -1;

bool IsNewMonthBar()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.year != g_last_rebalance_yr || dt.mon != g_last_rebalance_mon);
  }

int UniverseIndex(const string symbol)
  {
   for(int i = 0; i < UNIVERSE_SIZE; i++)
     {
      if(g_universe[i] == symbol)
         return i;
     }
   return -1;
  }

double WeeklyReturnVolatility(const string symbol, const int lookback_bars, bool &valid)
  {
   valid = false;
   if(lookback_bars < 10)
      return 0.0;

   const int close_count = lookback_bars + 1;
   double closes[];
   ArrayResize(closes, close_count);
   const int got = CopyClose(symbol, PERIOD_D1, 1, close_count, closes); // perf-allowed: monthly basket weekly-return volatility; no QM close-array helper exists.
   if(got != close_count)
      return 0.0;

   double returns[];
   int n_returns = 0;
   ArrayResize(returns, lookback_bars / 5 + 2);
   for(int i = 5; i < close_count; i += 5)
     {
      const double c0 = closes[i - 5];
      const double c1 = closes[i];
      if(c0 <= 0.0 || c1 <= 0.0)
         continue;
      returns[n_returns] = (c1 - c0) / c0;
      n_returns++;
     }

   if(n_returns < 8)
      return 0.0;

   double mean = 0.0;
   for(int i = 0; i < n_returns; i++)
      mean += returns[i];
   mean /= (double)n_returns;

   double var = 0.0;
   for(int i = 0; i < n_returns; i++)
     {
      const double d = returns[i] - mean;
      var += d * d;
     }
   var /= (double)(n_returns - 1);

   valid = true;
   return MathSqrt(var);
  }

double MedianSpreadPoints(const string symbol, const int days)
  {
   if(days <= 0)
      return 0.0;

   int spreads[];
   ArrayResize(spreads, days);
   const int got = CopySpread(symbol, PERIOD_D1, 1, days, spreads); // perf-allowed: monthly spread baseline; no QM spread-array helper exists.
   if(got <= 0)
      return 0.0;

   ArrayResize(spreads, got);
   ArraySort(spreads);
   if(got % 2 == 1)
      return (double)spreads[got / 2];
   return ((double)spreads[got / 2 - 1] + (double)spreads[got / 2]) * 0.5;
  }

double ActiveRiskDollars()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED * PORTFOLIO_WEIGHT;
   if(RISK_PERCENT > 0.0)
      return AccountInfoDouble(ACCOUNT_EQUITY) * RISK_PERCENT * 0.01 * PORTFOLIO_WEIGHT;
   return 0.0;
  }

bool HasOurPosition()
  {
   const long magic = (long)QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

void CloseBasketOnEmergencyStop()
  {
   const double one_r = ActiveRiskDollars();
   if(one_r <= 0.0 || strategy_basket_stop_r <= 0.0)
      return;

   double open_pnl = 0.0;
   const long magic_base = (long)qm_ea_id * 10000L;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic < magic_base || magic >= magic_base + UNIVERSE_SIZE)
         continue;
      open_pnl += PositionGetDouble(POSITION_PROFIT);
     }

   if(open_pnl > -strategy_basket_stop_r * one_r)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic < magic_base || magic >= magic_base + UNIVERSE_SIZE)
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_KILLSWITCH);
     }
  }

void AdvanceState_OnNewMonth()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   g_last_rebalance_yr  = dt.year;
   g_last_rebalance_mon = dt.mon;

   g_state_ready = true;
   g_is_selected = false;
   g_selected_vol = 0.0;
   g_selected_rank = -1;
   g_valid_symbol_count = 0;
   g_median_spread_points = MedianSpreadPoints(_Symbol, strategy_spread_median_days);

   const int my_idx = UniverseIndex(_Symbol);
   if(my_idx < 0)
     {
      QM_LogEvent(QM_INFO, "REBALANCE", "{\"selected\":false,\"reason\":\"symbol_not_in_universe\"}");
      return;
     }

   bool valid[7];
   double vols[7];
   for(int i = 0; i < UNIVERSE_SIZE; i++)
     {
      valid[i] = false;
      vols[i] = 0.0;
      vols[i] = WeeklyReturnVolatility(g_universe[i], strategy_vol_lookback_d1, valid[i]);
      if(valid[i])
         g_valid_symbol_count++;
     }

   if(g_valid_symbol_count < strategy_min_valid_symbols || !valid[my_idx])
     {
      QM_LogEvent(QM_INFO, "REBALANCE",
                  StringFormat("{\"selected\":false,\"reason\":\"insufficient_valid_history\",\"valid_symbols\":%d,\"min_required\":%d}",
                               g_valid_symbol_count, strategy_min_valid_symbols));
      return;
     }

   int rank = 0;
   for(int i = 0; i < UNIVERSE_SIZE; i++)
     {
      if(i == my_idx || !valid[i])
         continue;
      if(vols[i] < vols[my_idx])
         rank++;
     }

   int bucket = strategy_bucket_size;
   if(bucket < 1) bucket = 1;
   if(bucket > g_valid_symbol_count) bucket = g_valid_symbol_count;

   g_selected_rank = rank;
   g_selected_vol = vols[my_idx];
   g_is_selected = (rank < bucket);

   QM_LogEvent(QM_INFO, "REBALANCE",
               StringFormat("{\"selected\":%s,\"rank\":%d,\"bucket\":%d,\"vol\":%.8f,\"valid_symbols\":%d,\"month\":%d}",
                            g_is_selected ? "true" : "false",
                            rank,
                            bucket,
                            g_selected_vol,
                            g_valid_symbol_count,
                            dt.mon));
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && g_median_spread_points > 0.0 && strategy_spread_median_mult > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point > 0.0)
        {
         const double spread_points = (ask - bid) / point;
         if(spread_points > g_median_spread_points * strategy_spread_median_mult)
            return true;
        }
     }

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

   if(!g_state_ready || !g_is_selected)
      return false;
   if(HasOurPosition())
      return false;

   if(strategy_use_sma200_filter)
     {
      const double close_d1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed D1 close for optional card SMA200 filter inside D1 new-bar path.
      const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period_d1, 1);
      if(close_d1 <= 0.0 || sma <= 0.0 || close_d1 <= sma)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= ask)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "monthly_lowvol_long";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   CloseBasketOnEmergencyStop();
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;
   if(g_is_selected)
      return false;
   return HasOurPosition();
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

   QM_SymbolGuardInit(g_universe);

   int warmup = strategy_vol_lookback_d1 + 20;
   if(warmup < strategy_min_warmup_d1 + 10)
      warmup = strategy_min_warmup_d1 + 10;
   if(warmup < strategy_spread_median_days + 10)
      warmup = strategy_spread_median_days + 10;
   QM_BasketWarmupHistory(g_universe, PERIOD_D1, warmup);

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
      const long magic = (long)QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   if(IsNewMonthBar())
      AdvanceState_OnNewMonth();

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
