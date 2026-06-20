#property strict
#property version   "5.0"
#property description "QM5_9572 Chande StochRSI Volatility-Regime Cross H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9572;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input ENUM_TIMEFRAMES strategy_timeframe        = PERIOD_H4;
input int    strategy_rsi_period                = 14;
input int    strategy_stochrsi_lookback         = 14;
input int    strategy_stochrsi_k_sma            = 3;
input int    strategy_stochrsi_d_sma            = 3;
input int    strategy_vr_fast_atr_period        = 7;
input int    strategy_vr_slow_atr_period        = 28;
input double strategy_vr_entry_min              = 1.30;
input double strategy_vr_exit_max               = 0.90;
input int    strategy_ema_period                = 100;
input double strategy_long_pullback_max         = 0.15;
input double strategy_short_pullback_min        = 0.85;
input double strategy_long_rsi_min              = 45.0;
input double strategy_short_rsi_max             = 55.0;
input double strategy_long_exit_k_min           = 0.75;
input double strategy_short_exit_k_max          = 0.25;
input int    strategy_atr_sl_period             = 14;
input double strategy_atr_sl_mult               = 1.60;
input double strategy_spread_atr_fraction       = 0.15;
input int    strategy_max_hold_bars             = 20;
input double strategy_neutral_k_low             = 0.45;
input double strategy_neutral_k_high            = 0.55;

double g_k_1 = 0.0;
double g_d_1 = 0.0;
double g_k_2 = 0.0;
double g_d_2 = 0.0;
double g_vr_1 = 0.0;
double g_vr_2 = 0.0;
double g_rsi_1 = 0.0;
double g_close_1 = 0.0;
double g_ema_1 = 0.0;
bool   g_cache_ready = false;
bool   g_long_reentry_ready = true;
bool   g_short_reentry_ready = true;

double Strategy_Clamp01(const double value)
  {
   if(value < 0.0)
      return 0.0;
   if(value > 1.0)
      return 1.0;
   return value;
  }

double Strategy_StochRsiRaw(const int shift)
  {
   const int lookback = MathMax(2, strategy_stochrsi_lookback);
   const int rsi_period = MathMax(2, strategy_rsi_period);
   const double rsi_now = QM_RSI(_Symbol, strategy_timeframe, rsi_period, shift, PRICE_CLOSE);
   double rsi_high = rsi_now;
   double rsi_low = rsi_now;

   for(int i = 0; i < lookback; ++i)
     {
      const double rsi_value = QM_RSI(_Symbol, strategy_timeframe, rsi_period, shift + i, PRICE_CLOSE);
      if(i == 0 || rsi_value > rsi_high)
         rsi_high = rsi_value;
      if(i == 0 || rsi_value < rsi_low)
         rsi_low = rsi_value;
     }

   const double range = rsi_high - rsi_low;
   if(range <= 0.0000001)
      return 0.5;
   return Strategy_Clamp01((rsi_now - rsi_low) / range);
  }

double Strategy_StochRsiK(const int shift)
  {
   const int smooth = MathMax(1, strategy_stochrsi_k_sma);
   double total = 0.0;
   for(int i = 0; i < smooth; ++i)
      total += Strategy_StochRsiRaw(shift + i);
   return total / smooth;
  }

double Strategy_StochRsiD(const int shift)
  {
   const int smooth = MathMax(1, strategy_stochrsi_d_sma);
   double total = 0.0;
   for(int i = 0; i < smooth; ++i)
      total += Strategy_StochRsiK(shift + i);
   return total / smooth;
  }

double Strategy_VR(const int shift)
  {
   const double atr_fast = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_vr_fast_atr_period), shift);
   const double atr_slow = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_vr_slow_atr_period), shift);
   if(atr_fast <= 0.0 || atr_slow <= 0.0)
      return 0.0;
   return atr_fast / atr_slow;
  }

void Strategy_UpdateSignalCache()
  {
   g_k_1 = Strategy_StochRsiK(1);
   g_d_1 = Strategy_StochRsiD(1);
   g_k_2 = Strategy_StochRsiK(2);
   g_d_2 = Strategy_StochRsiD(2);
   g_vr_1 = Strategy_VR(1);
   g_vr_2 = Strategy_VR(2);
   g_rsi_1 = QM_RSI(_Symbol, strategy_timeframe, MathMax(2, strategy_rsi_period), 1, PRICE_CLOSE);
   g_close_1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: one closed-bar close for EMA bias; no QM close reader exists.
   g_ema_1 = QM_EMA(_Symbol, strategy_timeframe, MathMax(2, strategy_ema_period), 1, PRICE_CLOSE);
   g_cache_ready = true;

   if(g_k_1 >= strategy_neutral_k_low && g_k_1 <= strategy_neutral_k_high)
     {
      g_long_reentry_ready = true;
      g_short_reentry_ready = true;
     }
  }

bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_atr_sl_period), 1);
   if(ask > bid && atr > 0.0 && strategy_spread_atr_fraction > 0.0)
     {
      const double spread = ask - bid;
      if(spread > atr * strategy_spread_atr_fraction)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_UpdateSignalCache();
   if(!g_cache_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const bool long_cross = (g_k_2 <= g_d_2 && g_k_1 > g_d_1 && g_k_2 < strategy_long_pullback_max);
   const bool short_cross = (g_k_2 >= g_d_2 && g_k_1 < g_d_1 && g_k_2 > strategy_short_pullback_min);
   const bool long_bias = (g_vr_1 > strategy_vr_entry_min && g_close_1 > g_ema_1 && g_rsi_1 > strategy_long_rsi_min);
   const bool short_bias = (g_vr_1 > strategy_vr_entry_min && g_close_1 < g_ema_1 && g_rsi_1 < strategy_short_rsi_max);

   QM_OrderType side = QM_BUY;
   bool should_enter = false;
   string reason = "";
   if(g_long_reentry_ready && long_bias && long_cross)
     {
      side = QM_BUY;
      should_enter = true;
      reason = "stochrsi_vr_long";
      g_long_reentry_ready = false;
     }
   else if(g_short_reentry_ready && short_bias && short_cross)
     {
      side = QM_SELL;
      should_enter = true;
      reason = "stochrsi_vr_short";
      g_short_reentry_ready = false;
     }

   if(!should_enter)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, MathMax(1, strategy_atr_sl_period), strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
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
   if(!g_cache_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int period_seconds = PeriodSeconds(strategy_timeframe);
      if(period_seconds > 0 && opened > 0 && TimeCurrent() - opened >= strategy_max_hold_bars * period_seconds)
         return true;

      if(g_vr_1 < strategy_vr_exit_max && g_vr_2 < strategy_vr_exit_max)
         return true;

      if(position_type == POSITION_TYPE_BUY)
        {
         if(g_k_2 >= strategy_long_exit_k_min && g_k_2 >= g_d_2 && g_k_1 < g_d_1)
            return true;
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         if(g_k_2 <= strategy_short_exit_k_max && g_k_2 <= g_d_2 && g_k_1 > g_d_1)
            return true;
        }
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
                        60,
                        60,
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
