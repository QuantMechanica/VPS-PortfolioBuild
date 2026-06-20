#property strict
#property version   "5.0"
#property description "QM5_9288 MQL5 Gator AD Multi-Timeframe Alignment"
// Strategy Card: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (mql5-gator-ad-mtf), G0 APPROVED 2026-05-19.
// Source: Stephen Njuki, MQL5 Wizard Techniques you should know (Part 78), Pattern 9.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9288;
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
input ENUM_TIMEFRAMES strategy_higher_tf        = PERIOD_H4;
input int    strategy_jaw_period                = 13;
input int    strategy_jaw_shift                 = 8;
input int    strategy_teeth_period              = 8;
input int    strategy_teeth_shift               = 5;
input int    strategy_lips_period               = 5;
input int    strategy_lips_shift                = 3;
input int    strategy_ad_fast_period            = 5;
input int    strategy_ad_slow_period            = 13;
input int    strategy_ad_warmup_bars            = 80;
input int    strategy_atr_period                = 14;
input int    strategy_swing_lookback_bars       = 5;
input double strategy_atr_sl_mult               = 1.0;
input double strategy_rr_take_profit            = 2.2;
input int    strategy_max_hold_bars             = 120;
input int    strategy_spread_cap_points         = 1000;

// =============================================================================
// Strategy helpers
// =============================================================================

bool Strategy_ReadClosedBars(MqlRates &rates[], const int count)
  {
   if(count < 6)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, count, rates); // perf-allowed: bounded closed-bar OHLCV snapshot; EntrySignal is called only after the framework QM_IsNewBar gate.
   return (copied >= count);
  }

double Strategy_GatorUpperValue(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const double jaw = QM_SMMA(_Symbol, tf, strategy_jaw_period,
                              shift + strategy_jaw_shift, PRICE_MEDIAN);
   const double teeth = QM_SMMA(_Symbol, tf, strategy_teeth_period,
                                shift + strategy_teeth_shift, PRICE_MEDIAN);
   if(jaw <= 0.0 || teeth <= 0.0)
      return 0.0;
   return MathAbs(jaw - teeth);
  }

double Strategy_GatorLowerValue(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const double teeth = QM_SMMA(_Symbol, tf, strategy_teeth_period,
                                shift + strategy_teeth_shift, PRICE_MEDIAN);
   const double lips = QM_SMMA(_Symbol, tf, strategy_lips_period,
                               shift + strategy_lips_shift, PRICE_MEDIAN);
   if(teeth <= 0.0 || lips <= 0.0)
      return 0.0;
   return -MathAbs(teeth - lips);
  }

bool Strategy_GatorUpperGreen(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const double curr = Strategy_GatorUpperValue(tf, shift);
   const double prev = Strategy_GatorUpperValue(tf, shift + 1);
   if(curr <= 0.0 || prev <= 0.0)
      return false;
   return (curr > prev);
  }

bool Strategy_GatorLowerGreen(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const double curr = Strategy_GatorLowerValue(tf, shift);
   const double prev = Strategy_GatorLowerValue(tf, shift + 1);
   if(curr == 0.0 || prev == 0.0)
      return false;
   return (curr < prev);
  }

bool Strategy_ReadADOsc(double &ad0, double &ad1, double &ad2, double &ad3)
  {
   ad0 = 0.0;
   ad1 = 0.0;
   ad2 = 0.0;
   ad3 = 0.0;

   if(strategy_ad_fast_period <= 0 ||
      strategy_ad_slow_period <= strategy_ad_fast_period ||
      strategy_ad_warmup_bars < strategy_ad_slow_period + 12)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, strategy_ad_warmup_bars, rates); // perf-allowed: bounded ADL EMA oscillator; EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < strategy_ad_slow_period + 5)
      return false;

   const double alpha_fast = 2.0 / ((double)strategy_ad_fast_period + 1.0);
   const double alpha_slow = 2.0 / ((double)strategy_ad_slow_period + 1.0);
   double adl = 0.0;
   double ema_fast = 0.0;
   double ema_slow = 0.0;
   bool seeded = false;
   bool have0 = false;
   bool have1 = false;
   bool have2 = false;
   bool have3 = false;

   for(int i = copied - 1; i >= 0; --i)
     {
      const double high = rates[i].high;
      const double low = rates[i].low;
      const double close = rates[i].close;
      const double volume = (double)rates[i].tick_volume;
      double money_flow_mult = 0.0;
      if(high > low)
         money_flow_mult = ((close - low) - (high - close)) / (high - low);
      adl += money_flow_mult * volume;

      if(!seeded)
        {
         ema_fast = adl;
         ema_slow = adl;
         seeded = true;
        }
      else
        {
         ema_fast = alpha_fast * adl + (1.0 - alpha_fast) * ema_fast;
         ema_slow = alpha_slow * adl + (1.0 - alpha_slow) * ema_slow;
        }

      const double osc = ema_fast - ema_slow;
      if(i == 1)
        {
         ad0 = osc;
         have0 = true;
        }
      else if(i == 2)
        {
         ad1 = osc;
         have1 = true;
        }
      else if(i == 3)
        {
         ad2 = osc;
         have2 = true;
        }
      else if(i == 4)
        {
         ad3 = osc;
         have3 = true;
        }
     }

   return (have0 && have1 && have2 && have3);
  }

double Strategy_SwingLow(MqlRates &rates[], const int lookback)
  {
   double low = DBL_MAX;
   const int available = ArraySize(rates) - 1;
   int bars = lookback;
   if(bars > available)
      bars = available;
   if(bars < 1)
      return 0.0;

   for(int i = 1; i <= bars; ++i)
      low = MathMin(low, rates[i].low);
   return low;
  }

double Strategy_SwingHigh(MqlRates &rates[], const int lookback)
  {
   double high = -DBL_MAX;
   const int available = ArraySize(rates) - 1;
   int bars = lookback;
   if(bars > available)
      bars = available;
   if(bars < 1)
      return 0.0;

   for(int i = 1; i <= bars; ++i)
      high = MathMax(high, rates[i].high);
   return high;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

bool Strategy_GetPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   if(strategy_spread_cap_points <= 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_spread_cap_points)
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

   if(Strategy_HasOpenPosition())
      return false;

   const ENUM_TIMEFRAMES primary_tf = (ENUM_TIMEFRAMES)_Period;
   if(!Strategy_GatorUpperGreen(primary_tf, 1) ||
      !Strategy_GatorLowerGreen(primary_tf, 1))
      return false;

   if(!Strategy_GatorUpperGreen(strategy_higher_tf, 1) &&
      !Strategy_GatorLowerGreen(strategy_higher_tf, 1))
      return false;

   int bars_needed = strategy_swing_lookback_bars + 2;
   if(bars_needed < 6)
      bars_needed = 6;

   MqlRates rates[];
   if(!Strategy_ReadClosedBars(rates, bars_needed))
      return false;

   const double h4_close_1 = iClose(_Symbol, strategy_higher_tf, 1); // perf-allowed: single closed H4 close read; no QM close reader exists.
   const double h4_close_2 = iClose(_Symbol, strategy_higher_tf, 2); // perf-allowed: single closed H4 close read; no QM close reader exists.
   if(h4_close_1 <= 0.0 || h4_close_2 <= 0.0)
      return false;

   double ad0 = 0.0;
   double ad1 = 0.0;
   double ad2 = 0.0;
   double ad3 = 0.0;
   if(!Strategy_ReadADOsc(ad0, ad1, ad2, ad3))
      return false;

   const double atr = QM_ATR(_Symbol, primary_tf, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_rr_take_profit <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double prior_ad_min = MathMin(ad1, MathMin(ad2, ad3));
   const double prior_ad_max = MathMax(ad1, MathMax(ad2, ad3));

   if(rates[1].close > rates[2].high &&
      h4_close_1 > h4_close_2 &&
      ad0 >= prior_ad_min)
     {
      const double swing_low = Strategy_SwingLow(rates, strategy_swing_lookback_bars);
      if(swing_low <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, swing_low - strategy_atr_sl_mult * atr);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, req.sl, strategy_rr_take_profit);
      req.reason = "GATOR_AD_MTF_LONG";
      return (req.tp > ask);
     }

   if(rates[1].close < rates[2].low &&
      h4_close_1 < h4_close_2 &&
      ad0 <= prior_ad_max)
     {
      const double swing_high = Strategy_SwingHigh(rates, strategy_swing_lookback_bars);
      if(swing_high <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, swing_high + strategy_atr_sl_mult * atr);
      if(sl <= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, req.sl, strategy_rr_take_profit);
      req.reason = "GATOR_AD_MTF_SHORT";
      return (req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_GetPosition(ptype, open_time))
      return false;

   int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      period_seconds = 1800;
   const long max_hold_seconds = (long)strategy_max_hold_bars * (long)period_seconds;
   if(strategy_max_hold_bars > 0 && TimeCurrent() - open_time >= max_hold_seconds)
      return true;

   const double m30_close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: O(1) closed-bar exit check; no QM close reader exists.
   const double m30_low_2 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);     // perf-allowed: O(1) closed-bar exit check; no QM low reader exists.
   const double m30_high_2 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);   // perf-allowed: O(1) closed-bar exit check; no QM high reader exists.
   const double h4_close_1 = iClose(_Symbol, strategy_higher_tf, 1);        // perf-allowed: O(1) closed H4 exit check; no QM close reader exists.
   const double h4_close_2 = iClose(_Symbol, strategy_higher_tf, 2);        // perf-allowed: O(1) closed H4 exit check; no QM close reader exists.
   const double h4_close_3 = iClose(_Symbol, strategy_higher_tf, 3);        // perf-allowed: O(1) closed H4 exit check; no QM close reader exists.

   if(m30_close_1 <= 0.0 || m30_low_2 <= 0.0 || m30_high_2 <= 0.0 ||
      h4_close_1 <= 0.0 || h4_close_2 <= 0.0 || h4_close_3 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
     {
      if(h4_close_1 < h4_close_2 && h4_close_2 < h4_close_3)
         return true;
      if(m30_close_1 < m30_low_2)
         return true;
     }
   else
     {
      if(h4_close_1 > h4_close_2 && h4_close_2 > h4_close_3)
         return true;
      if(m30_close_1 > m30_high_2)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line.
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"mql5-gator-ad-mtf\",\"ea\":\"QM5_9288\"}");
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
