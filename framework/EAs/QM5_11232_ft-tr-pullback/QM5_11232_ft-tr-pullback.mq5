#property strict
#property version   "5.0"
#property description "QM5_11232 Freqtrade TrendRider EMA Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11232;
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
input int    strategy_ema_fast          = 9;
input int    strategy_ema_pullback      = 16;
input int    strategy_ema_trend_fast    = 50;
input int    strategy_ema_trend_slow    = 200;
input int    strategy_rsi_period        = 16;
input double strategy_rsi_min           = 30.0;
input double strategy_rsi_max           = 65.0;
input int    strategy_adx_period        = 14;
input double strategy_adx_min           = 18.0;
input double strategy_volume_factor     = 0.70;
input int    strategy_volume_lookback   = 20;
input int    strategy_obv_ema_period    = 20;
input int    strategy_obv_warmup_bars   = 220;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 3.0;
input double strategy_source_stop_pct   = 6.0;
input double strategy_trail_start_pct   = 5.0;
input double strategy_trail_pct         = 3.0;

bool Strategy_LoadRates(MqlRates &rates[], const int count)
  {
   ArrayResize(rates, count);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, count, rates); // perf-allowed: closed-bar entry hook computes OBV/tick-volume ratio unavailable as QM helpers.
   return (copied == count);
  }

bool Strategy_OBVAboveEMA(MqlRates &rates[], const int count, const int ema_period)
  {
   if(count < ema_period + 2)
      return false;

   const double alpha = 2.0 / ((double)ema_period + 1.0);
   double obv = 0.0;
   double ema = 0.0;
   bool seeded = false;

   for(int i = count - 2; i >= 0; --i)
     {
      if(rates[i].close > rates[i + 1].close)
         obv += (double)rates[i].tick_volume;
      else if(rates[i].close < rates[i + 1].close)
         obv -= (double)rates[i].tick_volume;

      if(!seeded)
        {
         ema = obv;
         seeded = true;
        }
      else
         ema = alpha * obv + (1.0 - alpha) * ema;
     }

   return (obv > ema);
  }

bool Strategy_VolumeRatioOK(MqlRates &rates[], const int count, const int lookback, const double factor)
  {
   if(lookback <= 0 || count < lookback + 1)
      return false;

   double sum = 0.0;
   int samples = 0;
   for(int i = 1; i <= lookback; ++i)
     {
      sum += (double)rates[i].tick_volume;
      samples++;
     }

   if(samples <= 0 || sum <= 0.0)
      return false;

   const double avg = sum / (double)samples;
   return ((double)rates[0].tick_volume > avg * factor);
  }

bool Strategy_SelectOurPosition(ulong &ticket)
  {
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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      ticket = t;
      return true;
     }

   return false;
  }

double Strategy_LongProfitPct()
  {
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(open_price <= 0.0 || bid <= 0.0)
      return 0.0;
   return 100.0 * (bid - open_price) / open_price;
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
   req.reason = "FT_TR_PULLBACK_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int rates_needed = MathMax(strategy_obv_warmup_bars, strategy_volume_lookback + 2);
   MqlRates rates[];
   if(!Strategy_LoadRates(rates, rates_needed))
      return false;

   const double close1 = rates[0].close;
   const double open1 = rates[0].open;
   const double low1 = rates[0].low;
   if(close1 <= 0.0 || open1 <= 0.0 || low1 <= 0.0)
      return false;

   const double ema200 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend_slow, 1);
   const double ema50 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend_fast, 1);
   const double ema16 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_pullback, 1);
   if(ema200 <= 0.0 || ema50 <= 0.0 || ema16 <= 0.0)
      return false;
   if(!(close1 > ema200 && ema50 > ema200))
      return false;
   if(!(low1 <= ema16 * 1.02 && close1 > ema16 && close1 > open1))
      return false;

   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   if(!(rsi > strategy_rsi_min && rsi < strategy_rsi_max && rsi < 70.0))
      return false;

   const double adx = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   const double plus_di = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   if(!(adx > strategy_adx_min && plus_di > minus_di))
      return false;

   if(!Strategy_VolumeRatioOK(rates, rates_needed, strategy_volume_lookback, strategy_volume_factor))
      return false;
   if(!Strategy_OBVAboveEMA(rates, rates_needed, strategy_obv_ema_period))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   const double source_stop_distance = ask * (strategy_source_stop_pct / 100.0);
   const double atr_stop_distance = atr * strategy_atr_stop_mult;
   const double stop_distance = MathMin(source_stop_distance, atr_stop_distance);
   if(stop_distance <= 0.0)
      return false;

   req.sl = NormalizeDouble(ask - stop_distance, _Digits);
   req.tp = 0.0;
   return (req.sl > 0.0 && req.sl < ask);
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return;

   const double profit_pct = Strategy_LongProfitPct();
   if(profit_pct < strategy_trail_start_pct)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double current_sl = PositionGetDouble(POSITION_SL);
   if(bid <= 0.0)
      return;

   const double target_sl = NormalizeDouble(bid * (1.0 - strategy_trail_pct / 100.0), _Digits);
   if(target_sl <= 0.0)
      return;
   if(current_sl <= 0.0 || target_sl > current_sl + _Point * 0.5)
      QM_TM_MoveSL(ticket, target_sl, "source_trail_3pct_after_5pct");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;

   const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
   const double hours_open = (opened_at > 0) ? ((double)(TimeCurrent() - opened_at) / 3600.0) : 0.0;
   const double profit_pct = Strategy_LongProfitPct();
   if(hours_open >= 24.0)
      return true;
   if(hours_open >= 16.0 && profit_pct < 1.0)
      return true;
   if(hours_open >= 8.0 && profit_pct < 0.5)
      return true;
   if(hours_open >= 4.0 && profit_pct < 0.0)
      return true;
   if(hours_open >= 2.0 && profit_pct < -1.5)
      return true;

   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   if(rsi > 78.0)
      return true;

   const double ema9_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 1);
   const double ema16_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_pullback, 1);
   const double ema9_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 2);
   const double ema16_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_pullback, 2);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H1, 12, 26, 9, 1);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H1, 12, 26, 9, 1);
   const double macd_hist = macd_main - macd_signal;
   if(ema9_now < ema16_now && ema9_prev >= ema16_prev && macd_hist < 0.0 && rsi > 50.0)
      return true;

   MqlRates rates[];
   if(!Strategy_LoadRates(rates, 3))
      return false;

   const double ema200_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend_slow, 1);
   const double ema200_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend_slow, 2);
   if(rates[0].close < ema200_now * 0.99 && rates[1].close >= ema200_prev * 0.99)
      return true;

   const double macd_main_prev = QM_MACD_Main(_Symbol, PERIOD_H1, 12, 26, 9, 2);
   const double macd_signal_prev = QM_MACD_Signal(_Symbol, PERIOD_H1, 12, 26, 9, 2);
   const double macd_hist_prev = macd_main_prev - macd_signal_prev;
   if(rates[0].close < ema200_now * 0.995 && rsi > 72.0 && macd_hist < macd_hist_prev)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11232_ft_tr_pullback\"}");
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
