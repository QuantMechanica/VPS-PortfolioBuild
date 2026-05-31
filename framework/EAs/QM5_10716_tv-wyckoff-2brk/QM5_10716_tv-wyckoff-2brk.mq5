#property strict
#property version   "5.0"
#property description "QM5_10716 TradingView Wyckoff Second Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10716;
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
input int    strategy_left_bars                 = 4;
input int    strategy_right_bars                = 2;
input int    strategy_max_bars_after_breakout   = 20;
input int    strategy_atr_period                = 14;
input double strategy_stop_atr_buffer           = 0.20;
input double strategy_min_stop_atr              = 0.50;
input double strategy_max_stop_atr              = 4.00;
input int    strategy_body_short_period         = 10;
input int    strategy_body_long_period          = 50;
input int    strategy_range_long_period         = 100;
input double strategy_low_liquidity_ratio       = 0.75;
input double strategy_expansion_body_mult       = 1.50;
input double strategy_expansion_range_atr_mult  = 1.00;
input double strategy_expansion_close_pct       = 0.30;

double g_last_pivot_high = 0.0;
double g_last_pivot_low  = 0.0;

int    g_long_state = 0;
int    g_long_age   = 0;
double g_long_h2    = 0.0;
double g_long_low   = 0.0;

int    g_short_state = 0;
int    g_short_age   = 0;
double g_short_l2    = 0.0;
double g_short_high  = 0.0;

void ResetLongSetup()
  {
   g_long_state = 0;
   g_long_age = 0;
   g_long_h2 = 0.0;
   g_long_low = 0.0;
  }

void ResetShortSetup()
  {
   g_short_state = 0;
   g_short_age = 0;
   g_short_l2 = 0.0;
   g_short_high = 0.0;
  }

bool HasOpenPositionForThisMagic()
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

bool LoadClosedRates(MqlRates &rates[])
  {
   const int min_required = MathMax(strategy_range_long_period,
                            MathMax(strategy_body_long_period,
                            strategy_left_bars + strategy_right_bars + 5));
   const int bars_needed = MathMax(min_required + 5, 120);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars_needed, rates); // perf-allowed: closed-bar structural pivot cache
   return (copied >= min_required);
  }

double AverageBody(MqlRates &rates[], const int period)
  {
   if(period <= 0 || ArraySize(rates) < period)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < period; ++i)
      sum += MathAbs(rates[i].close - rates[i].open);
   return sum / (double)period;
  }

double AverageRange(MqlRates &rates[], const int period)
  {
   if(period <= 0 || ArraySize(rates) < period)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < period; ++i)
      sum += MathMax(0.0, rates[i].high - rates[i].low);
   return sum / (double)period;
  }

bool ConfirmedPivotHigh(MqlRates &rates[], const int left, const int right, double &price)
  {
   price = 0.0;
   if(left < 1 || right < 1 || ArraySize(rates) <= left + right)
      return false;

   const int candidate = right;
   const double h = rates[candidate].high;
   for(int i = 1; i <= left; ++i)
      if(h <= rates[candidate + i].high)
         return false;
   for(int j = 1; j <= right; ++j)
      if(h <= rates[candidate - j].high)
         return false;

   price = h;
   return (price > 0.0);
  }

bool ConfirmedPivotLow(MqlRates &rates[], const int left, const int right, double &price)
  {
   price = 0.0;
   if(left < 1 || right < 1 || ArraySize(rates) <= left + right)
      return false;

   const int candidate = right;
   const double l = rates[candidate].low;
   for(int i = 1; i <= left; ++i)
      if(l >= rates[candidate + i].low)
         return false;
   for(int j = 1; j <= right; ++j)
      if(l >= rates[candidate - j].low)
         return false;

   price = l;
   return (price > 0.0);
  }

bool IsLowLiquidity(MqlRates &rates[])
  {
   const double body_short = AverageBody(rates, strategy_body_short_period);
   const double body_long = AverageBody(rates, strategy_body_long_period);
   const double range_short = AverageRange(rates, strategy_body_short_period);
   const double range_long = AverageRange(rates, strategy_range_long_period);
   if(body_short <= 0.0 || body_long <= 0.0 || range_short <= 0.0 || range_long <= 0.0)
      return false;

   return (body_short < body_long * strategy_low_liquidity_ratio &&
           range_short < range_long * strategy_low_liquidity_ratio);
  }

bool IsTrendExpansion(MqlRates &rates[], const bool is_long, const double atr)
  {
   if(ArraySize(rates) < strategy_body_long_period || atr <= 0.0)
      return false;

   const double avg_body = AverageBody(rates, strategy_body_long_period);
   const double body = MathAbs(rates[0].close - rates[0].open);
   const double range = rates[0].high - rates[0].low;
   if(avg_body <= 0.0 || range <= 0.0)
      return false;

   const double top_threshold = rates[0].high - range * strategy_expansion_close_pct;
   const double bottom_threshold = rates[0].low + range * strategy_expansion_close_pct;
   const bool close_ok = is_long ? (rates[0].close >= top_threshold)
                                 : (rates[0].close <= bottom_threshold);
   return (body > strategy_expansion_body_mult * avg_body &&
           range > strategy_expansion_range_atr_mult * atr &&
           close_ok);
  }

double ResolveTargetR(MqlRates &rates[], const bool is_long, const double atr)
  {
   if(IsLowLiquidity(rates))
      return 1.0;
   if(IsTrendExpansion(rates, is_long, atr))
      return 3.0;
   return 2.0;
  }

void FillDefaultRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildLongRequest(QM_EntryRequest &req, MqlRates &rates[], const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   const double stop = g_long_low - strategy_stop_atr_buffer * atr;
   const double stop_dist = ask - stop;
   if(stop <= 0.0 || stop_dist < strategy_min_stop_atr * atr || stop_dist > strategy_max_stop_atr * atr)
      return false;

   const double r_mult = ResolveTargetR(rates, true, atr);
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = stop;
   req.tp = ask + r_mult * stop_dist;
   req.reason = StringFormat("WYCKOFF_2BRK_LONG_R%.1f", r_mult);
   return true;
  }

bool BuildShortRequest(QM_EntryRequest &req, MqlRates &rates[], const double atr)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0 || atr <= 0.0)
      return false;

   const double stop = g_short_high + strategy_stop_atr_buffer * atr;
   const double stop_dist = stop - bid;
   if(stop <= 0.0 || stop_dist < strategy_min_stop_atr * atr || stop_dist > strategy_max_stop_atr * atr)
      return false;

   const double r_mult = ResolveTargetR(rates, false, atr);
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = stop;
   req.tp = bid - r_mult * stop_dist;
   req.reason = StringFormat("WYCKOFF_2BRK_SHORT_R%.1f", r_mult);
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   return ((ENUM_TIMEFRAMES)_Period != PERIOD_M15);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   FillDefaultRequest(req);

   if(HasOpenPositionForThisMagic())
      return false;
   if(strategy_left_bars < 1 || strategy_right_bars < 1 || strategy_max_bars_after_breakout < 1)
      return false;

   MqlRates rates[];
   if(!LoadClosedRates(rates))
      return false;

   double pivot = 0.0;
   if(g_long_state == 0 && ConfirmedPivotHigh(rates, strategy_left_bars, strategy_right_bars, pivot))
      g_last_pivot_high = pivot;
   if(g_short_state == 0 && ConfirmedPivotLow(rates, strategy_left_bars, strategy_right_bars, pivot))
      g_last_pivot_low = pivot;

   const double close0 = rates[0].close;
   const double high0 = rates[0].high;
   const double low0 = rates[0].low;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(close0 <= 0.0 || high0 <= 0.0 || low0 <= 0.0 || atr <= 0.0)
      return false;

   if(g_long_state == 0 && g_last_pivot_high > 0.0 && close0 > g_last_pivot_high)
     {
      g_long_state = 1;
      g_long_age = 0;
      g_long_h2 = high0;
      g_long_low = low0;
     }
   else if(g_long_state > 0)
     {
      g_long_age++;
      const double trigger = g_long_h2;
      if(g_long_state == 1 && close0 < trigger)
         g_long_state = 2;
      if(g_long_state == 2 && close0 > trigger && g_long_age <= strategy_max_bars_after_breakout)
        {
         g_long_low = MathMin(g_long_low, low0);
         if(BuildLongRequest(req, rates, atr))
           {
            ResetLongSetup();
            ResetShortSetup();
            return true;
           }
        }

      g_long_h2 = MathMax(g_long_h2, high0);
      g_long_low = MathMin(g_long_low, low0);
      if(g_long_age > strategy_max_bars_after_breakout)
         ResetLongSetup();
     }

   if(g_short_state == 0 && g_last_pivot_low > 0.0 && close0 < g_last_pivot_low)
     {
      g_short_state = 1;
      g_short_age = 0;
      g_short_l2 = low0;
      g_short_high = high0;
     }
   else if(g_short_state > 0)
     {
      g_short_age++;
      const double trigger = g_short_l2;
      if(g_short_state == 1 && close0 > trigger)
         g_short_state = 2;
      if(g_short_state == 2 && close0 < trigger && g_short_age <= strategy_max_bars_after_breakout)
        {
         g_short_high = MathMax(g_short_high, high0);
         if(BuildShortRequest(req, rates, atr))
           {
            ResetLongSetup();
            ResetShortSetup();
            return true;
           }
        }

      g_short_l2 = MathMin(g_short_l2, low0);
      g_short_high = MathMax(g_short_high, high0);
      if(g_short_age > strategy_max_bars_after_breakout)
         ResetShortSetup();
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, no break-even move, no scale-in, and no scale-out.
  }

bool Strategy_ExitSignal()
  {
   // Exits are fixed SL/TP plus the framework Friday close.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10716_tv-wyckoff-2brk\"}");
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
