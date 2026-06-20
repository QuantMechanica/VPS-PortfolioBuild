#property strict
#property version   "5.0"
#property description "QM5_9285 MQL5 Gator AD Trap Confirmation"
// Strategy Card: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (mql5-gator-ad-trap), G0 APPROVED 2026-05-19.
// Source: Stephen Njuki, MQL5 Wizard Techniques you should know (Part 78), Pattern 5.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9285;
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
input int    strategy_jaw_period        = 13;
input int    strategy_jaw_shift         = 8;
input int    strategy_teeth_period      = 8;
input int    strategy_teeth_shift       = 5;
input int    strategy_lips_period       = 5;
input int    strategy_lips_shift        = 3;
input int    strategy_ad_fast_period    = 5;
input int    strategy_ad_slow_period    = 13;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.0;
input double strategy_rr_take_profit    = 2.0;
input int    strategy_max_hold_bars     = 96;
input int    strategy_ad_warmup_bars    = 80;

// =============================================================================
// Strategy helpers
// =============================================================================

bool ReadClosedBars(MqlRates &rates[], const int count)
  {
   if(count < 4)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, count, rates); // perf-allowed: bounded ADL/OHLC snapshot
   return (copied >= count);
  }

double GatorUpperValue(const int shift)
  {
   const double jaw = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_jaw_period,
                              shift + strategy_jaw_shift, PRICE_MEDIAN);
   const double teeth = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_teeth_period,
                                shift + strategy_teeth_shift, PRICE_MEDIAN);
   if(jaw <= 0.0 || teeth <= 0.0)
      return 0.0;
   return MathAbs(jaw - teeth);
  }

double GatorLowerValue(const int shift)
  {
   const double teeth = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_teeth_period,
                                shift + strategy_teeth_shift, PRICE_MEDIAN);
   const double lips = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_lips_period,
                               shift + strategy_lips_shift, PRICE_MEDIAN);
   if(teeth <= 0.0 || lips <= 0.0)
      return 0.0;
   return -MathAbs(teeth - lips);
  }

bool GatorUpperRed(const int shift)
  {
   const double curr = GatorUpperValue(shift);
   const double prev = GatorUpperValue(shift + 1);
   if(curr <= 0.0 || prev <= 0.0)
      return false;
   return (curr < prev);
  }

bool GatorLowerGreen(const int shift)
  {
   const double curr = GatorLowerValue(shift);
   const double prev = GatorLowerValue(shift + 1);
   if(curr == 0.0 || prev == 0.0)
      return false;
   return (curr < prev);
  }

bool ReadADOsc(double &ad0, double &ad1, double &ad2)
  {
   ad0 = 0.0;
   ad1 = 0.0;
   ad2 = 0.0;

   if(strategy_ad_fast_period <= 0 ||
      strategy_ad_slow_period <= strategy_ad_fast_period ||
      strategy_ad_warmup_bars < strategy_ad_slow_period + 10)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, strategy_ad_warmup_bars, rates); // perf-allowed: bounded ADL EMA oscillator
   if(copied < strategy_ad_slow_period + 4)
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
     }

   return (have0 && have1 && have2);
  }

bool HasOpenPosition()
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

bool GetPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
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

   if(HasOpenPosition())
      return false;

   if(!GatorUpperRed(1) || !GatorUpperRed(2) ||
      !GatorLowerGreen(1) || !GatorLowerGreen(2))
      return false;

   MqlRates rates[];
   if(!ReadClosedBars(rates, 4))
      return false;

   double ad0 = 0.0;
   double ad1 = 0.0;
   double ad2 = 0.0;
   if(!ReadADOsc(ad0, ad1, ad2))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double low_stop = MathMin(rates[1].low, MathMin(rates[2].low, rates[3].low)) -
                           strategy_atr_sl_mult * atr;
   const double high_stop = MathMax(rates[1].high, MathMax(rates[2].high, rates[3].high)) +
                            strategy_atr_sl_mult * atr;

   if(rates[1].close > rates[2].high && rates[1].close > rates[3].high &&
      ad0 >= MathMax(ad1, ad2))
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, low_stop);
      if(sl <= 0.0 || sl >= ask)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, req.sl, strategy_rr_take_profit);
      req.reason = "GATOR_AD_TRAP_LONG";
      return (req.tp > ask);
     }

   if(rates[1].close < rates[2].low && rates[1].close < rates[3].low &&
      ad0 <= MathMin(ad1, ad2))
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, high_stop);
      if(sl <= bid)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, req.sl, strategy_rr_take_profit);
      req.reason = "GATOR_AD_TRAP_SHORT";
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
   if(!GetPosition(ptype, open_time))
      return false;

   int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      period_seconds = 1800;
   if(TimeCurrent() - open_time >= (long)strategy_max_hold_bars * period_seconds)
      return true;

   MqlRates rates[];
   if(!ReadClosedBars(rates, 4))
      return false;

   double ad0 = 0.0;
   double ad1 = 0.0;
   double ad2 = 0.0;
   if(!ReadADOsc(ad0, ad1, ad2))
      return false;

   if(ptype == POSITION_TYPE_BUY)
     {
      if(rates[1].close < rates[2].low)
         return true;
      if(ad0 < ad1 && ad1 < ad2)
         return true;
     }
   else
     {
      if(rates[1].close > rates[2].high)
         return true;
      if(ad0 > ad1 && ad1 > ad2)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"mql5-gator-ad-trap\",\"ea\":\"QM5_9285\"}");
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
