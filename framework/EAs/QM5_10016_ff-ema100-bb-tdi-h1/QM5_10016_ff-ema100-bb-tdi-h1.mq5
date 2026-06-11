#property strict
#property version   "5.0"
#property description "QM5_10016 ForexFactory EMA100 Bollinger TDI Pullback H1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10016;
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
input int    strategy_ema_period          = 100;
input int    strategy_bb_period           = 20;
input double strategy_bb_deviation        = 2.0;
input int    strategy_atr_period          = 14;
input int    strategy_tdi_rsi_period      = 7;
input int    strategy_tdi_green_sma       = 2;
input int    strategy_tdi_red_sma         = 7;
input int    strategy_bandwidth_lookback  = 100;
input double strategy_bandwidth_percentile = 25.0;
input int    strategy_ema_cross_lookback  = 20;
input int    strategy_max_ema_crosses     = 3;
input int    strategy_swing_lookback      = 5;
input double strategy_ema_sl_buffer_pips  = 5.0;
input double strategy_fx_min_stop_pips    = 20.0;
input double strategy_fx_max_stop_pips    = 30.0;
input double strategy_xau_atr_sl_mult     = 0.8;
input int    strategy_time_stop_bars      = 20;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   if(_Digits == 3 || _Digits == 5)
      return point * 10.0;
   return point;
  }

bool Strategy_IsXau()
  {
   return (StringFind(_Symbol, "XAUUSD") >= 0);
  }

bool Strategy_ReadRates(MqlRates &rates[], const int count)
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, count, rates); // perf-allowed: bounded closed-bar OHLC window; EntrySignal is only called after the framework QM_IsNewBar gate.
   return (copied == count);
  }

double Strategy_TdiSma(const int shift, const int length)
  {
   if(length <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < length; ++i)
     {
      const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_tdi_rsi_period, shift + i);
      if(rsi <= 0.0)
         return 0.0;
      sum += rsi;
     }
   return sum / (double)length;
  }

int Strategy_TdiCross()
  {
   const double green1 = Strategy_TdiSma(1, strategy_tdi_green_sma);
   const double red1   = Strategy_TdiSma(1, strategy_tdi_red_sma);
   const double green2 = Strategy_TdiSma(2, strategy_tdi_green_sma);
   const double red2   = Strategy_TdiSma(2, strategy_tdi_red_sma);
   if(green1 <= 0.0 || red1 <= 0.0 || green2 <= 0.0 || red2 <= 0.0)
      return 0;

   if(green1 > red1 && green2 <= red2)
      return 1;
   if(green1 < red1 && green2 >= red2)
      return -1;
   return 0;
  }

double Strategy_Bandwidth(const int shift)
  {
   const double upper = QM_BB_Upper(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double lower = QM_BB_Lower(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double mid   = QM_BB_Middle(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, shift);
   if(upper <= 0.0 || lower <= 0.0 || mid <= 0.0)
      return -1.0;
   return (upper - lower) / mid;
  }

bool Strategy_BandwidthPass()
  {
   const int lookback = MathMax(10, strategy_bandwidth_lookback);
   double widths[];
   ArrayResize(widths, lookback);

   for(int i = 0; i < lookback; ++i)
     {
      widths[i] = Strategy_Bandwidth(i + 2);
      if(widths[i] < 0.0)
         return false;
     }

   ArraySort(widths);
   const double pct = MathMax(0.0, MathMin(100.0, strategy_bandwidth_percentile));
   const int idx = (int)MathFloor((pct / 100.0) * (double)(lookback - 1));
   const double current = Strategy_Bandwidth(1);
   return (current > widths[idx]);
  }

int Strategy_EmaCrossCount(const MqlRates &rates[])
  {
   const int lookback = MathMax(1, strategy_ema_cross_lookback);
   int crosses = 0;
   int prev_sign = 0;

   for(int shift = lookback + 1; shift >= 1; --shift)
     {
      const int idx = shift - 1;
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, shift);
      if(ema <= 0.0 || rates[idx].close <= 0.0)
         return strategy_max_ema_crosses + 1;

      const int sign = (rates[idx].close > ema) ? 1 : ((rates[idx].close < ema) ? -1 : 0);
      if(sign == 0)
         continue;
      if(prev_sign != 0 && sign != prev_sign)
         crosses++;
      prev_sign = sign;
     }

   return crosses;
  }

double Strategy_SwingLow(const MqlRates &rates[])
  {
   const int bars = MathMax(1, strategy_swing_lookback);
   double lo = DBL_MAX;
   for(int i = 0; i < bars; ++i)
      lo = MathMin(lo, rates[i].low);
   return lo;
  }

double Strategy_SwingHigh(const MqlRates &rates[])
  {
   const int bars = MathMax(1, strategy_swing_lookback);
   double hi = -DBL_MAX;
   for(int i = 0; i < bars; ++i)
      hi = MathMax(hi, rates[i].high);
   return hi;
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

   if(strategy_ema_period <= 0 || strategy_bb_period <= 0 || strategy_atr_period <= 0)
      return false;
   if(strategy_tdi_green_sma <= 0 || strategy_tdi_red_sma <= 0 || strategy_tdi_rsi_period <= 0)
      return false;

   const int need_bars = MathMax(strategy_ema_cross_lookback + 1, strategy_swing_lookback);
   MqlRates rates[];
   if(!Strategy_ReadRates(rates, need_bars))
      return false;

   if(Strategy_EmaCrossCount(rates) > strategy_max_ema_crosses)
      return false;
   if(!Strategy_BandwidthPass())
      return false;

   const double ema1   = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double mid1   = QM_BB_Middle(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper1 = QM_BB_Upper(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower1 = QM_BB_Lower(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double atr1   = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double pip    = Strategy_PipSize();
   if(ema1 <= 0.0 || mid1 <= 0.0 || upper1 <= 0.0 || lower1 <= 0.0 || atr1 <= 0.0 || pip <= 0.0)
      return false;

   const int tdi_cross = Strategy_TdiCross();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double min_stop = strategy_fx_min_stop_pips * pip;
   const double max_stop = strategy_fx_max_stop_pips * pip;
   const double ema_buffer = strategy_ema_sl_buffer_pips * pip;

   if(rates[0].close > ema1 &&
      (rates[0].low <= mid1 || rates[0].low <= ema1 + 0.25 * atr1) &&
      tdi_cross > 0 &&
      ask > 0.0 &&
      upper1 > ask)
     {
      double stop_dist = 0.0;
      if(Strategy_IsXau())
         stop_dist = strategy_xau_atr_sl_mult * atr1;
      else
        {
         const double structure_sl = MathMin(Strategy_SwingLow(rates), ema1 - ema_buffer);
         stop_dist = ask - structure_sl;
         stop_dist = MathMax(min_stop, MathMin(max_stop, stop_dist));
        }

      if(stop_dist <= 0.0)
         return false;

      req.type = QM_BUY;
      req.sl = ask - stop_dist;
      req.tp = upper1;
      req.reason = "EMA100_BB_TDI_LONG";
      return true;
     }

   if(rates[0].close < ema1 &&
      (rates[0].high >= mid1 || rates[0].high >= ema1 - 0.25 * atr1) &&
      tdi_cross < 0 &&
      bid > 0.0 &&
      lower1 < bid)
     {
      double stop_dist = 0.0;
      if(Strategy_IsXau())
         stop_dist = strategy_xau_atr_sl_mult * atr1;
      else
        {
         const double structure_sl = MathMax(Strategy_SwingHigh(rates), ema1 + ema_buffer);
         stop_dist = structure_sl - bid;
         stop_dist = MathMax(min_stop, MathMin(max_stop, stop_dist));
        }

      if(stop_dist <= 0.0)
         return false;

      req.type = QM_SELL;
      req.sl = bid + stop_dist;
      req.tp = lower1;
      req.reason = "EMA100_BB_TDI_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int tdi_cross = Strategy_TdiCross();
   const int max_hold_seconds = strategy_time_stop_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(max_hold_seconds > 0 && (now - (datetime)PositionGetInteger(POSITION_TIME)) >= max_hold_seconds)
         return true;
      if(ptype == POSITION_TYPE_BUY && tdi_cross < 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && tdi_cross > 0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10016_ff-ema100-bb-tdi-h1\"}");
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
