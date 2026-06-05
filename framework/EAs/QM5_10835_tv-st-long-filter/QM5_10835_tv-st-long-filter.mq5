#property strict
#property version   "5.0"
#property description "QM5_10835 TradingView SuperTrend Long Trend Filter"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10835;
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
input int    strategy_atr_period              = 10;
input double strategy_supertrend_multiplier   = 3.0;
input int    strategy_price_source            = 0;    // 0=hl2, 1=close
input int    strategy_trend_ma_period         = 100;
input int    strategy_trend_ma_mode           = 0;    // 0=SMA, 1=EMA
input int    strategy_stop_cap_atr_period     = 14;
input double strategy_stop_cap_atr_mult       = 2.5;
input int    strategy_target_atr_period       = 14;
input double strategy_target_atr_mult         = 3.0;  // 0=off
input int    strategy_supertrend_lookback     = 180;

double g_st_line = 0.0;
double g_st_prev_line = 0.0;
bool   g_st_bull = false;
bool   g_st_prev_bull = false;
bool   g_st_valid = false;

double StrategySourcePrice(const MqlRates &bar)
  {
   if(strategy_price_source == 1)
      return bar.close;
   return (bar.high + bar.low) * 0.5;
  }

bool RefreshSuperTrendCache()
  {
   g_st_valid = false;
   if(strategy_atr_period < 2 || strategy_supertrend_multiplier <= 0.0)
      return false;

   const int min_lookback = strategy_atr_period * 5 + 5;
   const int lookback = (strategy_supertrend_lookback > min_lookback) ? strategy_supertrend_lookback : min_lookback;
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, lookback, rates); // perf-allowed: SuperTrend needs closed-bar OHLC sequence; Strategy_EntrySignal is framework QM_IsNewBar gated.
   if(copied < strategy_atr_period + 3)
      return false;

   double atr = 0.0;
   double tr_sum = 0.0;
   double final_upper = 0.0;
   double final_lower = 0.0;
   double st_line = 0.0;
   bool st_bull = false;
   bool st_ready = false;
   bool have_prev = false;
   bool have_curr = false;

   for(int i = 0; i < copied; ++i)
     {
      const double high = rates[i].high;
      const double low = rates[i].low;
      const double close = rates[i].close;
      if(high <= 0.0 || low <= 0.0 || close <= 0.0)
         return false;

      const double prev_close = (i > 0) ? rates[i - 1].close : close;
      const double tr = MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));

      if(i < strategy_atr_period)
        {
         tr_sum += tr;
         if(i < strategy_atr_period - 1)
            continue;
         atr = tr_sum / (double)strategy_atr_period;
        }
      else
        {
         atr = ((atr * (strategy_atr_period - 1)) + tr) / (double)strategy_atr_period;
        }

      if(atr <= 0.0)
         return false;

      const double source = StrategySourcePrice(rates[i]);
      const double basic_upper = source + strategy_supertrend_multiplier * atr;
      const double basic_lower = source - strategy_supertrend_multiplier * atr;

      if(!st_ready)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         st_line = (close >= source) ? final_lower : final_upper;
         st_bull = (st_line == final_lower);
         st_ready = true;
        }
      else
        {
         const double prev_final_upper = final_upper;
         const double prev_final_lower = final_lower;
         final_upper = (basic_upper < prev_final_upper || prev_close > prev_final_upper) ? basic_upper : prev_final_upper;
         final_lower = (basic_lower > prev_final_lower || prev_close < prev_final_lower) ? basic_lower : prev_final_lower;

         if(st_line == prev_final_upper)
            st_line = (close <= final_upper) ? final_upper : final_lower;
         else
            st_line = (close >= final_lower) ? final_lower : final_upper;

         st_bull = (st_line == final_lower);
        }

      if(i == copied - 2)
        {
         g_st_prev_line = st_line;
         g_st_prev_bull = st_bull;
         have_prev = true;
        }
      if(i == copied - 1)
        {
         g_st_line = st_line;
         g_st_bull = st_bull;
         have_curr = true;
        }
     }

   g_st_valid = (have_prev && have_curr && g_st_line > 0.0 && g_st_prev_line > 0.0);
   return g_st_valid;
  }

bool StrategyHasOpenPosition()
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

double StrategyTrendMA(const int shift)
  {
   if(strategy_trend_ma_period <= 0)
      return 0.0;
   if(strategy_trend_ma_mode == 1)
      return QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_trend_ma_period, shift, PRICE_CLOSE);
   return QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_trend_ma_period, shift, PRICE_CLOSE);
  }

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

   if(!RefreshSuperTrendCache())
      return false;
   if(StrategyHasOpenPosition())
      return false;
   if(!g_st_bull || g_st_prev_bull)
      return false;

   const double close_last = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: single closed-bar price for SuperTrend confirmation after framework new-bar gate.
   const double ma_last = StrategyTrendMA(1);
   if(close_last <= 0.0 || ma_last <= 0.0)
      return false;
   if(close_last <= ma_last)
      return false;
   if(close_last <= g_st_line)
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_cap = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stop_cap_atr_period, 1);
   if(entry_price <= 0.0 || atr_cap <= 0.0)
      return false;

   double stop = g_st_line;
   const double max_stop_distance = atr_cap * strategy_stop_cap_atr_mult;
   if(max_stop_distance <= 0.0)
      return false;
   const double stop_distance = entry_price - stop;
   if(stop <= 0.0 || stop_distance <= 0.0 || stop_distance > max_stop_distance)
      return false;

   req.sl = NormalizeDouble(stop, _Digits);
   if(strategy_target_atr_mult > 0.0)
     {
      const double atr_target = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_target_atr_period, 1);
      if(atr_target > 0.0)
         req.tp = NormalizeDouble(entry_price + atr_target * strategy_target_atr_mult, _Digits);
     }

   req.reason = "supertrend_bull_flip_ma_filter";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!g_st_valid || !g_st_bull || g_st_line <= 0.0)
      return;

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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(bid <= 0.0 || g_st_line >= bid)
         continue;

      const bool improves = (current_sl <= 0.0) || (g_st_line > current_sl + point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, g_st_line, "supertrend_support_trail");
     }
  }

bool Strategy_ExitSignal()
  {
   if(!g_st_valid)
      return false;

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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(!g_st_bull || (bid > 0.0 && g_st_line > 0.0 && bid <= g_st_line))
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
