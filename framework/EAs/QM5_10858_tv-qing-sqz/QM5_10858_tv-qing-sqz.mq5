#property strict
#property version   "5.0"
#property description "QM5_10858 tv-qing-sqz"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10858;
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
input int             strategy_ema_6_period          = 6;
input int             strategy_ema_12_period         = 12;
input int             strategy_ema_20_period         = 20;
input int             strategy_ema_50_period         = 50;
input int             strategy_ema_100_period        = 100;
input int             strategy_ema_200_period        = 200;
input double          strategy_squeeze_tight_pct     = 0.50;
input int             strategy_macd_fast             = 12;
input int             strategy_macd_slow             = 26;
input int             strategy_macd_signal           = 9;
input int             strategy_volume_sma_period     = 20;
input double          strategy_volume_multiplier     = 1.5;
input bool            strategy_htf_filter_enabled    = false;
input ENUM_TIMEFRAMES strategy_htf_filter_tf         = PERIOD_H4;
input int             strategy_atr_period            = 14;
input double          strategy_atr_sl_mult           = 1.5;
input double          strategy_atr_tp_mult           = 3.0;
input double          strategy_max_spread_stop_pct   = 15.0;
input int             strategy_time_exit_bars        = 24;

double Strategy_Close(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(_Symbol, tf, shift); // perf-allowed: closed-bar OHLC reader; no QM_Close helper exists.
  }

long Strategy_TickVolume(const int shift)
  {
   return iVolume(_Symbol, _Period, shift); // perf-allowed: tick-volume confirmation; no QM_Volume helper exists.
  }

double Strategy_Max3(const double a, const double b, const double c)
  {
   return MathMax(a, MathMax(b, c));
  }

double Strategy_Min3(const double a, const double b, const double c)
  {
   return MathMin(a, MathMin(b, c));
  }

bool Strategy_EMASqueezeAtShift(const int shift)
  {
   const double ema6  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_6_period, shift);
   const double ema12 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_12_period, shift);
   const double ema20 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_20_period, shift);
   if(ema6 <= 0.0 || ema12 <= 0.0 || ema20 <= 0.0 || strategy_squeeze_tight_pct <= 0.0)
      return false;

   const double max_ema = Strategy_Max3(ema6, ema12, ema20);
   const double min_ema = Strategy_Min3(ema6, ema12, ema20);
   if(max_ema <= 0.0 || min_ema <= 0.0)
      return false;

   const double spread_pct = ((max_ema - min_ema) / ema20) * 100.0;
   return (spread_pct <= strategy_squeeze_tight_pct);
  }

bool Strategy_VolumeSpike()
  {
   if(strategy_volume_sma_period <= 0 || strategy_volume_multiplier <= 0.0)
      return false;

   const long last_volume = Strategy_TickVolume(1);
   if(last_volume <= 0)
      return false;

   double sum = 0.0;
   int samples = 0;
   for(int shift = 2; shift <= strategy_volume_sma_period + 1; ++shift)
     {
      const long v = Strategy_TickVolume(shift);
      if(v <= 0)
         continue;
      sum += (double)v;
      samples++;
     }

   if(samples <= 0 || sum <= 0.0)
      return false;

   const double avg_volume = sum / (double)samples;
   return ((double)last_volume > avg_volume * strategy_volume_multiplier);
  }

bool Strategy_HTFAllowsLong()
  {
   if(!strategy_htf_filter_enabled)
      return true;

   const double htf_close = Strategy_Close(strategy_htf_filter_tf, 1);
   const double htf_ema200 = QM_EMA(_Symbol, strategy_htf_filter_tf, strategy_ema_200_period, 1);
   return (htf_close > 0.0 && htf_ema200 > 0.0 && htf_close > htf_ema200);
  }

bool Strategy_MACDBullish()
  {
   const double macd1 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                     strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double sig1 = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                      strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd2 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                     strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double sig2 = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                      strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

   return (macd1 > sig1 || (macd2 <= sig2 && macd1 > sig1));
  }

bool Strategy_MACDBearishCross()
  {
   const double macd1 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                     strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double sig1 = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                      strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd2 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                     strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double sig2 = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                      strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

   return (macd2 >= sig2 && macd1 < sig1);
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return true;

   const double spread = ask - bid;
   const double stop_distance = atr * strategy_atr_sl_mult;
   if(stop_distance <= 0.0)
      return true;

   return (spread > stop_distance * strategy_max_spread_stop_pct / 100.0);
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

   const double close1 = Strategy_Close((ENUM_TIMEFRAMES)_Period, 1);
   const double ema6   = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_6_period, 1);
   const double ema12  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_12_period, 1);
   const double ema20  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_20_period, 1);
   const double ema50  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_50_period, 1);
   const double ema100 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_100_period, 1);
   const double ema200 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_200_period, 1);
   if(close1 <= 0.0 || ema6 <= 0.0 || ema12 <= 0.0 || ema20 <= 0.0 ||
      ema50 <= 0.0 || ema100 <= 0.0 || ema200 <= 0.0)
      return false;

   if(!Strategy_EMASqueezeAtShift(2))
      return false;

   if(close1 <= ema6 || close1 <= ema12 || close1 <= ema20 || close1 <= ema200)
      return false;

   if(!Strategy_MACDBullish())
      return false;

   if(!Strategy_VolumeSpike())
      return false;

   if(!Strategy_HTFAllowsLong())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ask <= 0.0 || atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = ask;
   req.sl = NormalizeDouble(ask - atr * strategy_atr_sl_mult, _Digits);
   req.tp = NormalizeDouble(ask + atr * strategy_atr_tp_mult, _Digits);
   req.reason = "QING_EMA_MACD_SQUEEZE_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return (req.sl > 0.0 && req.tp > 0.0 && req.sl < req.price && req.tp > req.price);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR SL/TP at entry and no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   bool have_position = false;
   datetime position_open_time = 0;
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

      have_position = true;
      position_open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(!have_position)
      return false;

   const double close1 = Strategy_Close((ENUM_TIMEFRAMES)_Period, 1);
   const double ema20 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_20_period, 1);
   if(close1 > 0.0 && ema20 > 0.0 && close1 < ema20)
      return true;

   if(Strategy_MACDBearishCross())
      return true;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(strategy_time_exit_bars > 0 && period_seconds > 0 && position_open_time > 0)
     {
      const long held_seconds = (long)TimeCurrent() - (long)position_open_time;
      if(held_seconds >= (long)period_seconds * (long)strategy_time_exit_bars)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10858_tv-qing-sqz\"}");
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
