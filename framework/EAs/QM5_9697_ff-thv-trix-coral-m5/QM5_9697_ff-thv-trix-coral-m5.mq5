#property strict
#property version   "5.0"
#property description "QM5_9697 ForexFactory THV TRIX-Coral M5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9697;
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
input int    strategy_fast_trix_period      = 9;
input int    strategy_slow_trix_period      = 13;
input int    strategy_trix_warmup_bars      = 220;
input int    strategy_coral_period          = 60;
input double strategy_coral_coeff           = 0.40;
input int    strategy_ichi_tenkan           = 9;
input int    strategy_ichi_kijun            = 26;
input int    strategy_ichi_senkou           = 52;
input int    strategy_no_opposite_bars      = 3;
input int    strategy_swing_lookback_bars   = 8;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 1.10;
input double strategy_tp_rr                 = 1.50;
input int    strategy_time_stop_bars        = 24;
input int    strategy_session_start_hour    = 7;
input int    strategy_session_end_hour      = 17;
input double strategy_max_spread_atr_pct    = 20.0;

bool   g_state_ready = false;
bool   g_entry_long = false;
bool   g_entry_short = false;
bool   g_exit_long = false;
bool   g_exit_short = false;
double g_cached_long_sl = 0.0;
double g_cached_long_tp = 0.0;
double g_cached_short_sl = 0.0;
double g_cached_short_tp = 0.0;

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

bool Strategy_SessionAllows(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour));
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_atr_pct <= 0.0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(point <= 0.0 || atr <= 0.0)
      return false;

   const double spread_price = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   return ((spread_price / atr) * 100.0 <= strategy_max_spread_atr_pct);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SessionAllows(TimeCurrent()))
      return true;
   if(!Strategy_SpreadAllows())
      return true;
   return false;
  }

bool Strategy_BuildTrix(const MqlRates &rates[], const int count, const int period, double &trix[])
  {
   if(period < 2 || count < period + 5)
      return false;

   double ema1[], ema2[], ema3[];
   ArrayResize(ema1, count);
   ArrayResize(ema2, count);
   ArrayResize(ema3, count);
   ArrayResize(trix, count);

   const double alpha = 2.0 / ((double)period + 1.0);
   for(int i = count - 1; i >= 0; --i)
     {
      const double close = rates[i].close;
      if(close <= 0.0)
         return false;

      if(i == count - 1)
        {
         ema1[i] = close;
         ema2[i] = close;
         ema3[i] = close;
         trix[i] = 0.0;
         continue;
        }

      ema1[i] = alpha * close + (1.0 - alpha) * ema1[i + 1];
      ema2[i] = alpha * ema1[i] + (1.0 - alpha) * ema2[i + 1];
      ema3[i] = alpha * ema2[i] + (1.0 - alpha) * ema3[i + 1];
      trix[i] = (ema3[i + 1] != 0.0) ? (100.0 * (ema3[i] - ema3[i + 1]) / ema3[i + 1]) : 0.0;
     }

   return true;
  }

bool Strategy_BuildCoral(const MqlRates &rates[], const int count, double &coral[])
  {
   if(strategy_coral_period < 2 || count < strategy_coral_period + 5)
      return false;

   double e1[], e2[], e3[], e4[], e5[], e6[];
   ArrayResize(e1, count);
   ArrayResize(e2, count);
   ArrayResize(e3, count);
   ArrayResize(e4, count);
   ArrayResize(e5, count);
   ArrayResize(e6, count);
   ArrayResize(coral, count);

   const double alpha = 2.0 / ((double)strategy_coral_period + 1.0);
   const double b = MathMax(0.0, MathMin(1.0, strategy_coral_coeff));
   const double b2 = b * b;
   const double b3 = b2 * b;
   const double c1 = -b3;
   const double c2 = 3.0 * b2 + 3.0 * b3;
   const double c3 = -6.0 * b2 - 3.0 * b - 3.0 * b3;
   const double c4 = 1.0 + 3.0 * b + 3.0 * b2 + b3;

   for(int i = count - 1; i >= 0; --i)
     {
      const double close = rates[i].close;
      if(close <= 0.0)
         return false;

      if(i == count - 1)
        {
         e1[i] = close; e2[i] = close; e3[i] = close;
         e4[i] = close; e5[i] = close; e6[i] = close;
        }
      else
        {
         e1[i] = alpha * close + (1.0 - alpha) * e1[i + 1];
         e2[i] = alpha * e1[i] + (1.0 - alpha) * e2[i + 1];
         e3[i] = alpha * e2[i] + (1.0 - alpha) * e3[i + 1];
         e4[i] = alpha * e3[i] + (1.0 - alpha) * e4[i + 1];
         e5[i] = alpha * e4[i] + (1.0 - alpha) * e5[i + 1];
         e6[i] = alpha * e5[i] + (1.0 - alpha) * e6[i + 1];
        }

      coral[i] = c1 * e6[i] + c2 * e5[i] + c3 * e4[i] + c4 * e3[i];
     }

   return true;
  }

bool Strategy_CloudAllows(const int idx, const double close, const double coral, const int side)
  {
   const int shift = strategy_ichi_kijun + 1 + idx;
   const double span_a = QM_Ichimoku_SenkouSpanA(_Symbol, PERIOD_M5,
                                                strategy_ichi_tenkan,
                                                strategy_ichi_kijun,
                                                strategy_ichi_senkou,
                                                shift);
   const double span_b = QM_Ichimoku_SenkouSpanB(_Symbol, PERIOD_M5,
                                                strategy_ichi_tenkan,
                                                strategy_ichi_kijun,
                                                strategy_ichi_senkou,
                                                shift);
   if(span_a <= 0.0 || span_b <= 0.0)
      return false;

   const double cloud_high = MathMax(span_a, span_b);
   const double cloud_low = MathMin(span_a, span_b);
   if(side > 0)
      return (cloud_low > coral || close > cloud_high);
   return (cloud_high < coral || close < cloud_low);
  }

bool Strategy_ActiveSignalAt(const MqlRates &rates[], const double &fast[],
                             const double &slow[], const double &coral[],
                             const int idx, const int side)
  {
   const int count = ArraySize(fast);
   if(idx < 0 || idx + 1 >= count)
      return false;

   const double close = rates[idx].close;
   if(close <= 0.0 || coral[idx] <= 0.0)
      return false;

   if(side > 0)
     {
      if(close <= coral[idx])
         return false;
      if(!(fast[idx] > slow[idx] && fast[idx + 1] <= slow[idx + 1]))
         return false;
      if(!(fast[idx] > fast[idx + 1] && slow[idx] > slow[idx + 1]))
         return false;
      return Strategy_CloudAllows(idx, close, coral[idx], side);
     }

   if(close >= coral[idx])
      return false;
   if(!(fast[idx] < slow[idx] && fast[idx + 1] >= slow[idx + 1]))
      return false;
   if(!(fast[idx] < fast[idx + 1] && slow[idx] < slow[idx + 1]))
      return false;
   return Strategy_CloudAllows(idx, close, coral[idx], side);
  }

bool Strategy_NoPriorOppositeSignal(const MqlRates &rates[], const double &fast[],
                                    const double &slow[], const double &coral[],
                                    const int side)
  {
   const int max_prior = MathMax(0, strategy_no_opposite_bars);
   for(int i = 1; i <= max_prior; ++i)
      if(Strategy_ActiveSignalAt(rates, fast, slow, coral, i, -side))
         return false;
   return true;
  }

double Strategy_LowestLow(const MqlRates &rates[], const int lookback)
  {
   const int count = ArraySize(rates);
   const int limit = MathMin(MathMax(1, lookback), count);
   double lo = DBL_MAX;
   for(int i = 0; i < limit; ++i)
      lo = MathMin(lo, rates[i].low);
   return (lo == DBL_MAX) ? 0.0 : lo;
  }

double Strategy_HighestHigh(const MqlRates &rates[], const int lookback)
  {
   const int count = ArraySize(rates);
   const int limit = MathMin(MathMax(1, lookback), count);
   double hi = 0.0;
   for(int i = 0; i < limit; ++i)
      hi = MathMax(hi, rates[i].high);
   return hi;
  }

void Strategy_ResetState()
  {
   g_state_ready = false;
   g_entry_long = false;
   g_entry_short = false;
   g_exit_long = false;
   g_exit_short = false;
   g_cached_long_sl = 0.0;
   g_cached_long_tp = 0.0;
   g_cached_short_sl = 0.0;
   g_cached_short_tp = 0.0;
  }

void Strategy_AdvanceState_OnNewBar()
  {
   Strategy_ResetState();

   if(strategy_fast_trix_period < 2 || strategy_slow_trix_period < 2 ||
      strategy_coral_period < 2 || strategy_atr_period < 1 ||
      strategy_swing_lookback_bars < 1 || strategy_tp_rr <= 0.0 ||
      strategy_atr_sl_mult <= 0.0)
      return;

   const int largest_period = MathMax(strategy_coral_period,
                              MathMax(strategy_fast_trix_period, strategy_slow_trix_period));
   int bars_needed = MathMax(strategy_trix_warmup_bars, largest_period * 4 + 20);
   bars_needed = MathMin(MathMax(bars_needed, 80), 400);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, bars_needed, rates); // perf-allowed: THV TRIX/Coral custom closed-bar state; called only after the single framework QM_IsNewBar() gate.
   if(copied < MathMin(bars_needed, 80))
      return;

   double fast[], slow[], coral[];
   if(!Strategy_BuildTrix(rates, copied, strategy_fast_trix_period, fast))
      return;
   if(!Strategy_BuildTrix(rates, copied, strategy_slow_trix_period, slow))
      return;
   if(!Strategy_BuildCoral(rates, copied, coral))
      return;

   g_state_ready = true;
   g_entry_long = Strategy_ActiveSignalAt(rates, fast, slow, coral, 0, 1) &&
                  Strategy_NoPriorOppositeSignal(rates, fast, slow, coral, 1);
   g_entry_short = Strategy_ActiveSignalAt(rates, fast, slow, coral, 0, -1) &&
                   Strategy_NoPriorOppositeSignal(rates, fast, slow, coral, -1);

   const bool close_crossed_below_coral = (rates[1].close >= coral[1] && rates[0].close < coral[0]);
   const bool close_crossed_above_coral = (rates[1].close <= coral[1] && rates[0].close > coral[0]);
   g_exit_long = Strategy_ActiveSignalAt(rates, fast, slow, coral, 0, -1) || close_crossed_below_coral;
   g_exit_short = Strategy_ActiveSignalAt(rates, fast, slow, coral, 0, 1) || close_crossed_above_coral;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return;

   const double swing_low = Strategy_LowestLow(rates, strategy_swing_lookback_bars);
   const double swing_high = Strategy_HighestHigh(rates, strategy_swing_lookback_bars);
   if(swing_low <= 0.0 || swing_high <= 0.0)
      return;

   const double atr_dist = atr * strategy_atr_sl_mult;
   g_cached_long_sl = MathMin(swing_low, ask - atr_dist);
   g_cached_short_sl = MathMax(swing_high, bid + atr_dist);

   const double long_r = ask - g_cached_long_sl;
   const double short_r = g_cached_short_sl - bid;
   if(long_r > 0.0)
      g_cached_long_tp = ask + long_r * strategy_tp_rr;
   if(short_r > 0.0)
      g_cached_short_tp = bid - short_r * strategy_tp_rr;
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

   if(!g_state_ready || Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SessionAllows(TimeCurrent()) || !Strategy_SpreadAllows())
      return false;

   if(g_entry_long && g_cached_long_sl > 0.0 && g_cached_long_tp > 0.0)
     {
      req.type = QM_BUY;
      req.sl = NormalizeDouble(g_cached_long_sl, _Digits);
      req.tp = NormalizeDouble(g_cached_long_tp, _Digits);
      req.reason = "THV_TRIX_CORAL_LONG";
      return true;
     }

   if(g_entry_short && g_cached_short_sl > 0.0 && g_cached_short_tp > 0.0)
     {
      req.type = QM_SELL;
      req.sl = NormalizeDouble(g_cached_short_sl, _Digits);
      req.tp = NormalizeDouble(g_cached_short_tp, _Digits);
      req.reason = "THV_TRIX_CORAL_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int period_seconds = PeriodSeconds(PERIOD_M5);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_exit_long)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_exit_short)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(period_seconds > 0 && strategy_time_stop_bars > 0 &&
         ((now - open_time) / period_seconds) >= strategy_time_stop_bars)
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

   const bool new_bar = QM_IsNewBar(_Symbol, PERIOD_M5);
   if(new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_AdvanceState_OnNewBar();
     }

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

   if(!new_bar)
      return;

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
