#property strict
#property version   "5.0"
#property description "QM5_10683 TradingView Supply Demand Order-Block Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10683;
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
input int    strategy_ema_period              = 50;
input int    strategy_atr_period              = 14;
input int    strategy_macd_fast               = 12;
input int    strategy_macd_slow               = 26;
input int    strategy_macd_signal             = 9;
input int    strategy_zone_lookback_bars      = 40;
input int    strategy_bullish_sequence_bars   = 2;
input double strategy_impulse_atr_mult        = 0.75;
input int    strategy_volume_lookback_bars    = 20;
input double strategy_volume_spike_mult       = 1.20;
input double strategy_sl_atr_buffer_mult      = 0.25;
input double strategy_rr_target               = 2.00;
input double strategy_trail_atr_mult          = 2.00;
input int    strategy_max_spread_points       = 0;

// perf-allowed: bespoke demand-zone/order-block OHLC and tick-volume reads,
// called from Strategy_EntrySignal() only after the framework QM_IsNewBar gate.
double BarOpen(const int shift)      { return iOpen(_Symbol, PERIOD_CURRENT, shift); }     // perf-allowed
double BarHigh(const int shift)      { return iHigh(_Symbol, PERIOD_CURRENT, shift); }     // perf-allowed
double BarLow(const int shift)       { return iLow(_Symbol, PERIOD_CURRENT, shift); }      // perf-allowed
double BarClose(const int shift)     { return iClose(_Symbol, PERIOD_CURRENT, shift); }    // perf-allowed
long   BarVolume(const int shift)    { return iVolume(_Symbol, PERIOD_CURRENT, shift); }   // perf-allowed

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool Strategy_HasOurPosition()
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

bool Strategy_VolumeSpike()
  {
   const int lookback = MathMax(1, strategy_volume_lookback_bars);
   const long current_volume = BarVolume(1);
   if(current_volume <= 0)
      return false;

   double sum = 0.0;
   int samples = 0;
   for(int shift = 2; shift <= lookback + 1; ++shift)
     {
      const long v = BarVolume(shift);
      if(v <= 0)
         continue;
      sum += (double)v;
      samples++;
     }

   if(samples <= 0 || sum <= 0.0)
      return false;

   const double avg = sum / (double)samples;
   return ((double)current_volume >= avg * MathMax(1.0, strategy_volume_spike_mult));
  }

bool Strategy_FindDemandOrderBlock(const double atr,
                                   double &zone_low,
                                   double &zone_high)
  {
   zone_low = 0.0;
   zone_high = 0.0;
   if(atr <= 0.0)
      return false;

   const int lookback = MathMax(6, strategy_zone_lookback_bars);
   const int seq = MathMax(1, strategy_bullish_sequence_bars);

   for(int shift = seq + 1; shift <= lookback; ++shift)
     {
      const double ob_open = BarOpen(shift);
      const double ob_close = BarClose(shift);
      const double ob_high = BarHigh(shift);
      const double ob_low = BarLow(shift);
      if(ob_open <= 0.0 || ob_close <= 0.0 || ob_high <= ob_low || ob_close >= ob_open)
         continue;

      bool bullish_sequence = true;
      for(int offset = 1; offset <= seq; ++offset)
        {
         const int s = shift - offset;
         const double open_s = BarOpen(s);
         const double close_s = BarClose(s);
         if(open_s <= 0.0 || close_s <= 0.0 || close_s <= open_s)
           {
            bullish_sequence = false;
            break;
           }
        }
      if(!bullish_sequence)
         continue;

      const double impulse_close = BarClose(shift - seq);
      if((impulse_close - ob_high) < atr * strategy_impulse_atr_mult)
         continue;

      const double close1 = BarClose(1);
      const double close2 = BarClose(2);
      if(close1 > ob_high && close2 <= ob_high)
        {
         zone_low = ob_low;
         zone_high = ob_high;
         return true;
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1 && (ENUM_TIMEFRAMES)_Period != PERIOD_M15)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
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

   if(Strategy_HasOurPosition())
      return false;
   if(strategy_ema_period < 1 || strategy_atr_period < 1 ||
      strategy_macd_fast < 1 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1)
      return false;

   const double close1 = BarClose(1);
   const double ema = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_period, 1);
   if(close1 <= 0.0 || ema <= 0.0 || close1 <= ema)
      return false;

   if(!Strategy_VolumeSpike())
      return false;

   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         1);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_CURRENT,
                                             strategy_macd_fast,
                                             strategy_macd_slow,
                                             strategy_macd_signal,
                                             1);
   if(macd_main <= macd_signal)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   double zone_low = 0.0;
   double zone_high = 0.0;
   if(!Strategy_FindDemandOrderBlock(atr, zone_low, zone_high))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0 || atr <= 0.0)
      return false;

   const double sl = Strategy_NormalizePrice(zone_low - atr * strategy_sl_atr_buffer_mult);
   if(sl <= 0.0 || ask <= sl + point)
      return false;

   const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_rr_target);
   if(tp <= ask)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "TV_SD_OB_BREAK_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > open_price)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10683_tv-sd-ob-break\"}");
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
