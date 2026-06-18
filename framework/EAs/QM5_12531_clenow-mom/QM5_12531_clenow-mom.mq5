#property strict
#property version   "5.0"
#property description "QM5_12531 Clenow-style cross-sectional momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12531;
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
input int    strategy_momentum_lookback_d1 = 90;
input double strategy_top_percent          = 20.0;
input int    strategy_market_sma_period    = 200;
input int    strategy_exit_sma_period      = 100;
input int    strategy_atr_period           = 20;
input double strategy_atr_stop_mult        = 3.0;
input int    strategy_rebalance_weekday    = 1;
input int    strategy_min_active_basket    = 5;
input int    strategy_spread_lookback_d1   = 60;

bool Strategy_NoTradeFilter()
  {
   return false;
  }

double LatestCloseD1(const string symbol)
  {
   double close_buf[];
   const int copied = CopyClose(symbol, PERIOD_D1, 1, 1, close_buf); // perf-allowed: closed-bar basket read
   if(copied != 1)
      return 0.0;
   return close_buf[0];
  }

bool MomentumScoreD1(const string symbol, const int lookback, double &score)
  {
   score = 0.0;
   if(lookback < 10)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   double closes[];
   const int copied = CopyClose(symbol, PERIOD_D1, 1, lookback, closes); // perf-allowed: bounded weekly regression window
   if(copied < lookback)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_yy = 0.0;
   double sum_xy = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      const double x = (double)i;
      const double y = MathLog(closes[i]);
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_yy += y * y;
      sum_xy += x * y;
     }

   const double n = (double)lookback;
   const double denom_x = n * sum_xx - sum_x * sum_x;
   const double denom_y = n * sum_yy - sum_y * sum_y;
   if(denom_x <= 0.0 || denom_y <= 0.0)
      return false;

   const double slope = (n * sum_xy - sum_x * sum_y) / denom_x;
   const double corr_num = n * sum_xy - sum_x * sum_y;
   const double r2 = (corr_num * corr_num) / (denom_x * denom_y);
   score = (MathExp(slope * 252.0) - 1.0) * r2;
   return MathIsValidNumber(score);
  }

int BasketSymbols(string &symbols[])
  {
   ArrayResize(symbols, 8);
   symbols[0] = "EURUSD.DWX";
   symbols[1] = "GBPUSD.DWX";
   symbols[2] = "USDJPY.DWX";
   symbols[3] = "AUDUSD.DWX";
   symbols[4] = "USDCAD.DWX";
   symbols[5] = "NDX.DWX";
   symbols[6] = "WS30.DWX";
   symbols[7] = "XAUUSD.DWX";
   return 8;
  }

bool IsRebalanceDay()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int target = strategy_rebalance_weekday;
   if(target < 0)
      target = 0;
   if(target > 6)
      target = 6;
   return (dt.day_of_week == target);
  }

bool MarketRegimeAllowsLong()
  {
   const string regime_symbol = "SP500.DWX";
   if(QM_SymbolAssertOrLog(regime_symbol))
     {
      const double sp_close = LatestCloseD1(regime_symbol);
      const double sp_sma = QM_SMA(regime_symbol, PERIOD_D1, strategy_market_sma_period, 1, PRICE_CLOSE);
      if(sp_close > 0.0 && sp_sma > 0.0)
         return (sp_close > sp_sma);
     }

   string symbols[];
   const int n = BasketSymbols(symbols);
   double ratio_sum = 0.0;
   int active = 0;
   for(int i = 0; i < n; ++i)
     {
      const double close_i = LatestCloseD1(symbols[i]);
      const double sma_i = QM_SMA(symbols[i], PERIOD_D1, strategy_market_sma_period, 1, PRICE_CLOSE);
      if(close_i <= 0.0 || sma_i <= 0.0)
         continue;
      ratio_sum += close_i / sma_i;
      active++;
     }
   if(active < strategy_min_active_basket)
      return false;
   return (ratio_sum / (double)active > 1.0);
  }

bool SpreadAllowsEntry()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(ask <= bid)
      return true;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_lookback_d1, rates); // perf-allowed: bounded closed-bar spread median
   if(copied <= 0)
      return true;

   double spreads[];
   int n = 0;
   ArrayResize(spreads, copied);
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread < 0)
         continue;
      spreads[n] = (double)rates[i].spread;
      n++;
     }
   if(n <= 0)
      return true;

   for(int i = 1; i < n; ++i)
     {
      const double v = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > v)
        {
         spreads[j + 1] = spreads[j];
         j--;
        }
      spreads[j + 1] = v;
     }

   const double median_points = spreads[n / 2];
   if(median_points <= 0.0)
      return true;

   const double current_points = (ask - bid) / point;
   return (current_points <= 2.0 * median_points);
  }

bool SymbolInTopMomentumSegment(const string target_symbol, int &active_count, int &target_rank)
  {
   active_count = 0;
   target_rank = 9999;

   double target_score = 0.0;
   if(!MomentumScoreD1(target_symbol, strategy_momentum_lookback_d1, target_score))
      return false;

   string symbols[];
   const int n = BasketSymbols(symbols);
   int better_count = 0;
   for(int i = 0; i < n; ++i)
     {
      double score_i = 0.0;
      if(!MomentumScoreD1(symbols[i], strategy_momentum_lookback_d1, score_i))
         continue;
      active_count++;
      if(score_i > target_score)
         better_count++;
     }

   if(active_count < strategy_min_active_basket)
      return false;

   int top_count = (int)MathCeil((double)active_count * strategy_top_percent / 100.0);
   if(top_count < 1)
      top_count = 1;
   target_rank = better_count + 1;
   return (target_rank <= top_count);
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

   if(_Period != PERIOD_D1)
      return false;
   if(!IsRebalanceDay())
      return false;
   if(!SpreadAllowsEntry())
      return false;
   if(!MarketRegimeAllowsLong())
      return false;

   int active_count = 0;
   int target_rank = 9999;
   if(!SymbolInTopMomentumSegment(_Symbol, active_count, target_rank))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.sl = sl;
   req.reason = StringFormat("CLENOW_LONG rank=%d active=%d", target_rank, active_count);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!IsRebalanceDay())
      return false;

   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   const double close_last = LatestCloseD1(_Symbol);
   const double exit_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_exit_sma_period, 1, PRICE_CLOSE);
   if(close_last > 0.0 && exit_sma > 0.0 && close_last < exit_sma)
      return true;

   int active_count = 0;
   int target_rank = 9999;
   return !SymbolInTopMomentumSegment(_Symbol, active_count, target_rank);
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

   string allowed[];
   ArrayResize(allowed, 9);
   allowed[0] = "EURUSD.DWX";
   allowed[1] = "GBPUSD.DWX";
   allowed[2] = "USDJPY.DWX";
   allowed[3] = "AUDUSD.DWX";
   allowed[4] = "USDCAD.DWX";
   allowed[5] = "NDX.DWX";
   allowed[6] = "WS30.DWX";
   allowed[7] = "XAUUSD.DWX";
   allowed[8] = "SP500.DWX";
   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_D1, 260);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12531_clenow-mom\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
