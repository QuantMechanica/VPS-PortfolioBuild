#property strict
#property version   "5.0"
#property description "QM5_11123 sr-fractal-break"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11123;
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
input int    strategy_fractal_lookback_bars = 160;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 1.5;
input int    strategy_max_hold_bars         = 16;
input double strategy_breakout_atr_min_mult = 0.0;

double g_last_long_break_level = 0.0;
double g_last_short_break_level = 0.0;

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool IsResistanceFractal(const int shift)
  {
   if(shift < 3)
      return false;

   const double h = iHigh(_Symbol, _Period, shift);       // perf-allowed: source fractal structure read on framework closed-bar path.
   const double h1 = iHigh(_Symbol, _Period, shift - 1);  // perf-allowed: source fractal structure read on framework closed-bar path.
   const double h2 = iHigh(_Symbol, _Period, shift - 2);  // perf-allowed: source fractal structure read on framework closed-bar path.
   const double h3 = iHigh(_Symbol, _Period, shift + 1);  // perf-allowed: source fractal structure read on framework closed-bar path.
   const double h4 = iHigh(_Symbol, _Period, shift + 2);  // perf-allowed: source fractal structure read on framework closed-bar path.
   if(h <= 0.0 || h1 <= 0.0 || h2 <= 0.0 || h3 <= 0.0 || h4 <= 0.0)
      return false;

   return (h > h1 && h > h2 && h > h3 && h > h4);
  }

bool IsSupportFractal(const int shift)
  {
   if(shift < 3)
      return false;

   const double l = iLow(_Symbol, _Period, shift);       // perf-allowed: source fractal structure read on framework closed-bar path.
   const double l1 = iLow(_Symbol, _Period, shift - 1);  // perf-allowed: source fractal structure read on framework closed-bar path.
   const double l2 = iLow(_Symbol, _Period, shift - 2);  // perf-allowed: source fractal structure read on framework closed-bar path.
   const double l3 = iLow(_Symbol, _Period, shift + 1);  // perf-allowed: source fractal structure read on framework closed-bar path.
   const double l4 = iLow(_Symbol, _Period, shift + 2);  // perf-allowed: source fractal structure read on framework closed-bar path.
   if(l <= 0.0 || l1 <= 0.0 || l2 <= 0.0 || l3 <= 0.0 || l4 <= 0.0)
      return false;

   return (l < l1 && l < l2 && l < l3 && l < l4);
  }

double LatestResistance()
  {
   const int lookback = MathMax(5, strategy_fractal_lookback_bars);
   for(int shift = 3; shift <= lookback; ++shift)
     {
      if(IsResistanceFractal(shift))
         return iHigh(_Symbol, _Period, shift); // perf-allowed: source fractal resistance buffer emulation on closed-bar path.
     }
   return 0.0;
  }

double LatestSupport()
  {
   const int lookback = MathMax(5, strategy_fractal_lookback_bars);
   for(int shift = 3; shift <= lookback; ++shift)
     {
      if(IsSupportFractal(shift))
         return iLow(_Symbol, _Period, shift); // perf-allowed: source fractal support buffer emulation on closed-bar path.
     }
   return 0.0;
  }

bool BreakoutSignals(double &resistance,
                     double &support,
                     bool &long_signal,
                     bool &short_signal)
  {
   resistance = LatestResistance();
   support = LatestSupport();
   long_signal = false;
   short_signal = false;

   if(resistance <= 0.0 || support <= 0.0)
      return false;

   const double close_current = iClose(_Symbol, _Period, 1); // perf-allowed: source TriggerCandle=Previous close read on closed-bar path.
   const double close_prior = iClose(_Symbol, _Period, 2);   // perf-allowed: source TriggerCandle=Previous close read on closed-bar path.
   if(close_current <= 0.0 || close_prior <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double min_break = (atr > 0.0 && strategy_breakout_atr_min_mult > 0.0)
                            ? atr * strategy_breakout_atr_min_mult : 0.0;

   long_signal = (close_current > resistance + min_break && close_prior <= resistance);
   short_signal = (close_current < support - min_break && close_prior >= support);
   return (long_signal || short_signal);
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &pos_type,
                       datetime &open_time,
                       double &open_price,
                       ulong &ticket)
  {
   pos_type = POSITION_TYPE_BUY;
   open_time = 0;
   open_price = 0.0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      ticket = pos_ticket;
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_bars <= 0)
      return false;

   double resistance = 0.0;
   double support = 0.0;
   bool long_signal = false;
   bool short_signal = false;
   if(!BreakoutSignals(resistance, support, long_signal, short_signal))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(long_signal)
     {
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, resistance - atr * strategy_atr_sl_mult);
      req.reason = "SR_FRACTAL_BREAK_LONG";
      g_last_long_break_level = resistance;
      g_last_short_break_level = 0.0;
      return (req.sl > 0.0);
     }

   if(short_signal)
     {
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, support + atr * strategy_atr_sl_mult);
      req.reason = "SR_FRACTAL_BREAK_SHORT";
      g_last_short_break_level = support;
      g_last_long_break_level = 0.0;
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even, partial close, or add-on logic.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type;
   datetime open_time;
   double open_price;
   ulong ticket;
   if(!SelectOurPosition(pos_type, open_time, open_price, ticket))
      return false;

   if(!QM_IsNewBar())
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds > 0 && open_time > 0)
     {
      const int held_bars = (int)((TimeCurrent() - open_time) / period_seconds);
      if(held_bars >= strategy_max_hold_bars)
         return true;
     }

   double resistance = 0.0;
   double support = 0.0;
   bool long_signal = false;
   bool short_signal = false;
   BreakoutSignals(resistance, support, long_signal, short_signal);

   const double close_current = iClose(_Symbol, _Period, 1); // perf-allowed: source close-back exit read on closed-bar path.
   if(close_current <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
     {
      const double broken_level = (g_last_long_break_level > 0.0) ? g_last_long_break_level : resistance;
      if(broken_level > 0.0 && close_current < broken_level)
         return true;
      if(short_signal)
         return true;
     }
   else if(pos_type == POSITION_TYPE_SELL)
     {
      const double broken_level = (g_last_short_break_level > 0.0) ? g_last_short_break_level : support;
      if(broken_level > 0.0 && close_current > broken_level)
         return true;
      if(long_signal)
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
