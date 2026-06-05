#property strict
#property version   "5.0"
#property description "QM5_10789 TradingView Band Zigzag TrendFollower"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - tv-band-zigzag
// -----------------------------------------------------------------------------
// Card mechanics:
//   - Select a fixed band family: Bollinger, Keltner, or Donchian.
//   - Register band-zigzag pivot highs only on upper-band breaks and pivot lows
//     only on lower-band breaks.
//   - Long when price breaks above the upper band, pivot structure is HH/HL,
//     the pivot ratio is above threshold, and percentB confirms breakout.
//   - Short mirrors long on lower-band breaks with LL/LH structure.
//   - Exit on opposite band-zigzag trend state, ATR/structure safety stop, or
//     max-bars-in-trade when reversal is delayed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10789;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_band_type         = 0;      // 0 Bollinger, 1 Keltner, 2 Donchian
input int    strategy_band_length       = 20;
input double strategy_band_mult         = 2.0;
input double strategy_pivot_ratio_min   = 1.0;
input double strategy_percentb_long_min = 1.0;
input double strategy_percentb_short_max = 0.0;
input bool   strategy_use_adx_filter    = true;
input int    strategy_adx_period        = 14;
input double strategy_adx_min           = 20.0;
input bool   strategy_use_atr_filter    = false;
input int    strategy_atr_period        = 14;
input int    strategy_atr_filter_lookback = 50;
input double strategy_atr_filter_min_ratio = 0.75;
input double strategy_atr_stop_mult     = 2.0;
input int    strategy_max_bars_in_trade = 96;
input bool   strategy_allow_shorts      = true;

struct StrategyBand
  {
   double         upper;
   double         middle;
   double         lower;
  };

double g_prev_pivot_high = 0.0;
double g_last_pivot_high = 0.0;
double g_prev_pivot_low  = 0.0;
double g_last_pivot_low  = 0.0;
double g_close_last      = 0.0;
double g_percentb_last   = 0.5;
double g_bull_ratio      = 0.0;
double g_bear_ratio      = 0.0;
bool   g_last_break_up   = false;
bool   g_last_break_down = false;
long   g_bars_seen       = 0;

bool Strategy_GetOpenPosition(ENUM_POSITION_TYPE &out_type, ulong &out_ticket)
  {
   out_type = POSITION_TYPE_BUY;
   out_ticket = 0;

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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      out_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      out_ticket = ticket;
      return true;
     }

   return false;
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

double Strategy_DonchianHigh(const int shift, const int length)
  {
   double high = -DBL_MAX;
   for(int i = shift; i < shift + length; ++i)
      high = MathMax(high, iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i)); // perf-allowed: closed-bar Donchian structural band
   return (high == -DBL_MAX) ? 0.0 : high;
  }

double Strategy_DonchianLow(const int shift, const int length)
  {
   double low = DBL_MAX;
   for(int i = shift; i < shift + length; ++i)
      low = MathMin(low, iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i)); // perf-allowed: closed-bar Donchian structural band
   return (low == DBL_MAX) ? 0.0 : low;
  }

bool Strategy_ReadBand(const int shift, StrategyBand &band)
  {
   band.upper = 0.0;
   band.middle = 0.0;
   band.lower = 0.0;

   if(strategy_band_length < 2 || strategy_band_mult <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   if(strategy_band_type == 1)
     {
      band.middle = QM_EMA(_Symbol, tf, strategy_band_length, shift);
      const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, shift);
      if(band.middle <= 0.0 || atr <= 0.0)
         return false;
      band.upper = band.middle + strategy_band_mult * atr;
      band.lower = band.middle - strategy_band_mult * atr;
      return (band.upper > band.lower);
     }

   if(strategy_band_type == 2)
     {
      band.upper = Strategy_DonchianHigh(shift, strategy_band_length);
      band.lower = Strategy_DonchianLow(shift, strategy_band_length);
      band.middle = 0.5 * (band.upper + band.lower);
      return (band.upper > band.lower);
     }

   band.upper = QM_BB_Upper(_Symbol, tf, strategy_band_length, strategy_band_mult, shift);
   band.middle = QM_BB_Middle(_Symbol, tf, strategy_band_length, strategy_band_mult, shift);
   band.lower = QM_BB_Lower(_Symbol, tf, strategy_band_length, strategy_band_mult, shift);
   return (band.upper > band.lower && band.middle > 0.0);
  }

void Strategy_AddPivotHigh(const double value)
  {
   if(value <= 0.0)
      return;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_last_pivot_high > 0.0 && MathAbs(value - g_last_pivot_high) <= point * 0.5)
      return;
   g_prev_pivot_high = g_last_pivot_high;
   g_last_pivot_high = value;
  }

void Strategy_AddPivotLow(const double value)
  {
   if(value <= 0.0)
      return;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_last_pivot_low > 0.0 && MathAbs(value - g_last_pivot_low) <= point * 0.5)
      return;
   g_prev_pivot_low = g_last_pivot_low;
   g_last_pivot_low = value;
  }

void Strategy_RefreshPivotRatios()
  {
   g_bull_ratio = 0.0;
   g_bear_ratio = 0.0;

   if(g_prev_pivot_high > 0.0 && g_last_pivot_high > 0.0 && g_last_pivot_low > 0.0)
     {
      const double denom = g_prev_pivot_high - g_last_pivot_low;
      if(denom > 0.0)
         g_bull_ratio = (g_last_pivot_high - g_last_pivot_low) / denom;
     }

   if(g_prev_pivot_low > 0.0 && g_last_pivot_low > 0.0 && g_last_pivot_high > 0.0)
     {
      const double denom = g_last_pivot_high - g_prev_pivot_low;
      if(denom > 0.0)
         g_bear_ratio = (g_last_pivot_high - g_last_pivot_low) / denom;
     }
  }

void Strategy_AdvanceState()
  {
   StrategyBand band;
   if(!Strategy_ReadBand(1, band))
      return;
   const double high_1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);  // perf-allowed: single closed-bar band-zigzag pivot read
   const double low_1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);    // perf-allowed: single closed-bar band-zigzag pivot read
   const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: single closed-bar breakout confirmation
   if(high_1 <= 0.0 || low_1 <= 0.0 || close_1 <= 0.0)
      return;

   g_close_last = close_1;
   g_last_break_up = (close_1 > band.upper);
   g_last_break_down = (close_1 < band.lower);
   g_percentb_last = (band.upper > band.lower) ? ((close_1 - band.lower) / (band.upper - band.lower)) : 0.5;

   if(high_1 > band.upper)
      Strategy_AddPivotHigh(high_1);
   if(low_1 < band.lower)
      Strategy_AddPivotLow(low_1);

   Strategy_RefreshPivotRatios();
   g_bars_seen++;
  }

bool Strategy_BullishStructure()
  {
   return (g_prev_pivot_high > 0.0 && g_prev_pivot_low > 0.0 &&
           g_last_pivot_high > g_prev_pivot_high &&
           g_last_pivot_low > g_prev_pivot_low &&
           g_bull_ratio >= strategy_pivot_ratio_min);
  }

bool Strategy_BearishStructure()
  {
   return (g_prev_pivot_high > 0.0 && g_prev_pivot_low > 0.0 &&
           g_last_pivot_low < g_prev_pivot_low &&
           g_last_pivot_high < g_prev_pivot_high &&
           g_bear_ratio >= strategy_pivot_ratio_min);
  }

bool Strategy_TrendFilterAllows()
  {
   if(strategy_use_adx_filter)
     {
      const double adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
      if(adx < strategy_adx_min)
         return false;
     }

   if(strategy_use_atr_filter)
     {
      if(strategy_atr_filter_lookback < 2 || strategy_atr_filter_min_ratio <= 0.0)
         return false;

      const double current_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      double sum_atr = 0.0;
      for(int i = 2; i < 2 + strategy_atr_filter_lookback; ++i)
         sum_atr += QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, i);
      const double avg_atr = sum_atr / (double)strategy_atr_filter_lookback;
      if(current_atr <= 0.0 || avg_atr <= 0.0 || current_atr / avg_atr < strategy_atr_filter_min_ratio)
         return false;
     }

   return true;
  }

double Strategy_LongStop(const double entry)
  {
   const double atr_stop = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_stop_mult);
   double structure_stop = 0.0;
   if(g_last_pivot_low > 0.0 && g_last_pivot_low < entry)
      structure_stop = g_last_pivot_low;

   double stop = atr_stop;
   if(structure_stop > 0.0 && structure_stop > atr_stop)
      stop = structure_stop;
   return Strategy_NormalizePrice(stop);
  }

double Strategy_ShortStop(const double entry)
  {
   const double atr_stop = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period, strategy_atr_stop_mult);
   double structure_stop = 0.0;
   if(g_last_pivot_high > 0.0 && g_last_pivot_high > entry)
      structure_stop = g_last_pivot_high;

   double stop = atr_stop;
   if(structure_stop > 0.0 && structure_stop < atr_stop)
      stop = structure_stop;
   return Strategy_NormalizePrice(stop);
  }

bool Strategy_PositionTooOld()
  {
   if(strategy_max_bars_in_trade <= 0)
      return false;

   ENUM_POSITION_TYPE position_type;
   ulong ticket;
   if(!Strategy_GetOpenPosition(position_type, ticket))
      return false;

   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(opened <= 0 || seconds_per_bar <= 0)
      return false;

   const long age_seconds = (long)(TimeCurrent() - opened);
   return (age_seconds >= (long)strategy_max_bars_in_trade * (long)seconds_per_bar);
  }

// No Trade Filter - no strategy-specific time/spread gate in the card. The
// central framework handles kill-switch, news, Friday close, and tester guards.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry - called once per new closed bar by the framework.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   Strategy_AdvanceState();

   if(g_bars_seen < MathMax(strategy_band_length, strategy_atr_period) + 5)
      return false;
   if(strategy_pivot_ratio_min <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   ENUM_POSITION_TYPE position_type;
   ulong ticket;
   if(Strategy_GetOpenPosition(position_type, ticket))
      return false;
   if(!Strategy_TrendFilterAllows())
      return false;

   if(g_last_break_up && Strategy_BullishStructure() && g_percentb_last >= strategy_percentb_long_min)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double sl = Strategy_LongStop(entry);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "tv_band_zigzag_long";
      return true;
     }

   if(strategy_allow_shorts && g_last_break_down && Strategy_BearishStructure() &&
      g_percentb_last <= strategy_percentb_short_max)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double sl = Strategy_ShortStop(entry);
      if(sl <= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "tv_band_zigzag_short";
      return true;
     }

   return false;
  }

// Trade Management - no break-even, partial close, pyramiding, or trailing in
// the card baseline. Safety is via initial SL plus Trade Close reversal/time.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close - reversal of the band-zigzag trend state, plus max-bars safety.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   ulong ticket;
   if(!Strategy_GetOpenPosition(position_type, ticket))
      return false;

   if(Strategy_PositionTooOld())
      return true;

   if(position_type == POSITION_TYPE_BUY && Strategy_BearishStructure())
      return true;
   if(position_type == POSITION_TYPE_SELL && Strategy_BullishStructure())
      return true;

   return false;
  }

// News Filter Hook - P8 News Impact callable. Defer to the central framework
// news filter; this card has no bespoke news rule.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10789_tv-band-zigzag\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
