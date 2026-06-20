#property strict
#property version   "5.0"
#property description "QM5_9238 MQL5 Hurst MA Regime Switch"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9238;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_ma_period      = 20;
input int    strategy_slow_ma_period      = 80;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.0;
input double strategy_trend_rr            = 2.2;
input double strategy_hurst_deadband_low  = 0.48;
input double strategy_hurst_deadband_high = 0.52;
input int    strategy_max_hold_bars       = 18;
input int    strategy_max_spread_points   = 0;

double g_last_hurst      = 0.5;
double g_prev_hurst      = 0.5;
double g_last_close      = 0.0;
double g_last_fast_ma    = 0.0;
double g_last_slow_ma    = 0.0;
bool   g_signal_cache_ok = false;

bool ReadCloseWindow(const int start_shift, const int count, double &values[])
  {
   if(start_shift < 1 || count < 1)
      return false;

   ArrayResize(values, count);
   ArraySetAsSeries(values, false);
   const int copied = CopyClose(_Symbol, (ENUM_TIMEFRAMES)_Period, start_shift, count, values); // perf-allowed bespoke Hurst closed-bar window
   return (copied == count);
  }

double HurstRS(const int start_shift)
  {
   const int sample_count = strategy_fast_ma_period + strategy_slow_ma_period;
   if(sample_count < 20)
      return 0.5;

   double closes[];
   if(!ReadCloseWindow(start_shift, sample_count, closes))
      return 0.5;

   double mean = 0.0;
   for(int i = 0; i < sample_count; ++i)
      mean += closes[i];
   mean /= (double)sample_count;

   double cumulative = 0.0;
   double max_cum = -DBL_MAX;
   double min_cum = DBL_MAX;
   double variance = 0.0;
   for(int i = 0; i < sample_count; ++i)
     {
      const double deviation = closes[i] - mean;
      cumulative += deviation;
      if(cumulative > max_cum)
         max_cum = cumulative;
      if(cumulative < min_cum)
         min_cum = cumulative;
      variance += deviation * deviation;
     }

   const double range = max_cum - min_cum;
   const double stdev = MathSqrt(variance / (double)sample_count);
   if(range <= 0.0 || stdev <= 0.0)
      return 0.5;

   double hurst = MathLog(range / stdev) / MathLog((double)sample_count);
   if(hurst < 0.0)
      hurst = 0.0;
   if(hurst > 1.0)
      hurst = 1.0;
   return hurst;
  }

bool RefreshSignalCache()
  {
   if(strategy_fast_ma_period < 2 ||
      strategy_slow_ma_period <= strategy_fast_ma_period ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_trend_rr <= 0.0)
      return false;

   double close_value[];
   if(!ReadCloseWindow(1, 1, close_value))
      return false;

   g_last_close = close_value[0];
   g_last_fast_ma = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ma_period, 1, PRICE_CLOSE);
   g_last_slow_ma = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ma_period, 1, PRICE_CLOSE);
   g_last_hurst = HurstRS(1);
   g_prev_hurst = HurstRS(2);

   g_signal_cache_ok = (g_last_close > 0.0 &&
                        g_last_fast_ma > 0.0 &&
                        g_last_slow_ma > 0.0);
   return g_signal_cache_ok;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype,
                    datetime &opened_at,
                    string &comment,
                    ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;
   comment = "";
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      comment = PositionGetString(POSITION_COMMENT);
      ticket = t;
      return true;
     }

   return false;
  }

double MeanReversionTakeProfit(const QM_OrderType type,
                               const double entry_price,
                               const double rr_take)
  {
   if(entry_price <= 0.0 || rr_take <= 0.0 || g_last_fast_ma <= 0.0)
      return rr_take;

   if(type == QM_BUY && g_last_fast_ma > entry_price && g_last_fast_ma < rr_take)
      return QM_StopRulesNormalizePrice(_Symbol, g_last_fast_ma);

   if(type == QM_SELL && g_last_fast_ma < entry_price && g_last_fast_ma > rr_take)
      return QM_StopRulesNormalizePrice(_Symbol, g_last_fast_ma);

   return rr_take;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid && ((ask - bid) / point) > (double)strategy_max_spread_points)
      return true;

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

   if(!RefreshSignalCache())
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_last_hurst >= strategy_hurst_deadband_low &&
      g_last_hurst <= strategy_hurst_deadband_high)
      return false;

   bool trend_regime = (g_last_hurst > 0.5);
   QM_OrderType side = QM_BUY;
   string reason = "";

   if(trend_regime)
     {
      if(g_last_close > g_last_slow_ma)
        {
         side = QM_BUY;
         reason = "HURST_TREND_LONG";
        }
      else if(g_last_close < g_last_slow_ma)
        {
         side = QM_SELL;
         reason = "HURST_TREND_SHORT";
        }
      else
         return false;
     }
   else
     {
      if(g_last_close < g_last_fast_ma)
        {
         side = QM_BUY;
         reason = "HURST_MR_LONG";
        }
      else if(g_last_close > g_last_fast_ma)
        {
         side = QM_SELL;
         reason = "HURST_MR_SHORT";
        }
      else
         return false;
     }

   const double entry_price = (side == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry_price, atr_value, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   double tp = QM_TakeRR(_Symbol, side, entry_price, sl, strategy_trend_rr);
   if(tp <= 0.0)
      return false;

   if(!trend_regime)
      tp = MeanReversionTakeProfit(side, entry_price, tp);

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!g_signal_cache_ok)
      return false;

   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   string comment;
   ulong ticket;
   if(!GetOurPosition(ptype, opened_at, comment, ticket))
      return false;

   if(strategy_max_hold_bars > 0 && opened_at > 0)
     {
      const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(period_seconds > 0 &&
         (TimeCurrent() - opened_at) >= (strategy_max_hold_bars * period_seconds))
         return true;
     }

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const bool trend_trade = (StringFind(comment, "HURST_TREND") >= 0);

   if(trend_trade)
     {
      if(g_last_hurst < 0.5 && g_prev_hurst >= 0.5)
         return true;
      if(is_long && g_last_close < g_last_slow_ma)
         return true;
      if(!is_long && g_last_close > g_last_slow_ma)
         return true;
     }
   else
     {
      if(g_last_hurst > 0.5 && g_prev_hurst <= 0.5)
         return true;
      if(is_long && g_last_close >= g_last_fast_ma)
         return true;
      if(!is_long && g_last_close <= g_last_fast_ma)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9238_mql5-hurst-ma-regime\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
