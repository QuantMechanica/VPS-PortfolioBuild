#property strict
#property version   "5.0"
#property description "QM5_10234 TradingView RSI ATR Reversal Band"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy-specific implementation for QM5_10234_tv-rsi-atr-band.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10234;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M15;
input int             strategy_rsi_period        = 14;
input int             strategy_atr_period        = 14;
input double          strategy_band_atr_mult     = 2.0;
input double          strategy_min_rsi_pressure  = 0.10;
input int             strategy_state_lookback    = 120;
input double          strategy_min_diff_pct      = 2.0;
input double          strategy_atr_emergency_mult = 2.0;
input double          strategy_max_spread_atr_pct = 10.0;
input bool            strategy_longs_enabled     = true;
input bool            strategy_shorts_enabled    = true;

double g_band_upper = 0.0;
double g_band_lower = 0.0;
double g_band_source = 0.0;
double g_band_rsi = 0.0;
double g_band_atr = 0.0;
bool   g_band_long_cross = false;
bool   g_band_short_cross = false;
bool   g_band_ready = false;

bool BuildHeikinAshiSeries(const MqlRates &rates[],
                           const int count,
                           double &ha_open[],
                           double &ha_high[],
                           double &ha_low[],
                           double &ha_close[])
  {
   if(count < 3)
      return false;

   ArrayResize(ha_open, count);
   ArrayResize(ha_high, count);
   ArrayResize(ha_low, count);
   ArrayResize(ha_close, count);

   double prev_ha_open = 0.0;
   double prev_ha_close = 0.0;
   for(int i = count - 1; i >= 0; --i)
     {
      const double raw_open = rates[i].open;
      const double raw_high = rates[i].high;
      const double raw_low = rates[i].low;
      const double raw_close = rates[i].close;
      if(raw_open <= 0.0 || raw_high <= 0.0 || raw_low <= 0.0 || raw_close <= 0.0)
         return false;

      const double close_ha = (raw_open + raw_high + raw_low + raw_close) * 0.25;
      const double open_ha = (i == count - 1)
                             ? (raw_open + raw_close) * 0.5
                             : (prev_ha_open + prev_ha_close) * 0.5;

      ha_close[i] = close_ha;
      ha_open[i] = open_ha;
      ha_high[i] = MathMax(raw_high, MathMax(open_ha, close_ha));
      ha_low[i] = MathMin(raw_low, MathMin(open_ha, close_ha));

      prev_ha_open = open_ha;
      prev_ha_close = close_ha;
     }

   return true;
  }

double HeikinAshiRSI(const double &ha_close[], const int count, const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period >= count)
      return 0.0;

   double gains = 0.0;
   double losses = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double delta = ha_close[i] - ha_close[i + 1];
      if(delta > 0.0)
         gains += delta;
      else
         losses -= delta;
     }

   if(gains <= 0.0 && losses <= 0.0)
      return 50.0;
   if(losses <= 0.0)
      return 100.0;

   const double rs = gains / losses;
   return 100.0 - (100.0 / (1.0 + rs));
  }

double HeikinAshiATR(const double &ha_high[],
                     const double &ha_low[],
                     const double &ha_close[],
                     const int count,
                     const int shift,
                     const int period)
  {
   if(period <= 0 || shift < 0 || shift + period >= count)
      return 0.0;

   double tr_sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double range = ha_high[i] - ha_low[i];
      const double high_close = MathAbs(ha_high[i] - ha_close[i + 1]);
      const double low_close = MathAbs(ha_low[i] - ha_close[i + 1]);
      const double tr = MathMax(range, MathMax(high_close, low_close));
      tr_sum += tr;
     }

   return tr_sum / (double)period;
  }

double ClampPressure(const double value)
  {
   if(value < strategy_min_rsi_pressure)
      return strategy_min_rsi_pressure;
   if(value > 1.0)
      return 1.0;
   return value;
  }

bool RecalculateBandState()
  {
   g_band_ready = false;
   g_band_long_cross = false;
   g_band_short_cross = false;

   if(strategy_rsi_period <= 1 ||
      strategy_atr_period <= 1 ||
      strategy_band_atr_mult <= 0.0 ||
      strategy_min_rsi_pressure < 0.0 ||
      strategy_min_rsi_pressure > 0.5 ||
      strategy_state_lookback < 10 ||
      strategy_min_diff_pct <= 0.0 ||
      strategy_atr_emergency_mult <= 0.0)
      return false;

   const int max_period = (strategy_rsi_period > strategy_atr_period) ? strategy_rsi_period : strategy_atr_period;
   int bars_needed = strategy_state_lookback + max_period + 8;
   if(bars_needed < 60)
      bars_needed = 60;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, bars_needed, rates); // perf-allowed: bounded Heikin-Ashi source window; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied <= max_period + 4)
      return false;

   double ha_open[];
   double ha_high[];
   double ha_low[];
   double ha_close[];
   if(!BuildHeikinAshiSeries(rates, copied, ha_open, ha_high, ha_low, ha_close))
      return false;

   int oldest = strategy_state_lookback;
   const int oldest_allowed = copied - max_period - 2;
   if(oldest > oldest_allowed)
      oldest = oldest_allowed;
   if(oldest < 2)
      return false;

   int bias = 0;
   double highest_since_cross = 0.0;
   double lowest_since_cross = 0.0;
   double prev_source = 0.0;
   double prev_upper = 0.0;
   double prev_lower = 0.0;
   bool have_prev = false;

   for(int shift = oldest; shift >= 0; --shift)
     {
      const double source = ha_close[shift];
      const double rsi = HeikinAshiRSI(ha_close, copied, shift, strategy_rsi_period);
      const double atr = HeikinAshiATR(ha_high, ha_low, ha_close, copied, shift, strategy_atr_period);
      if(source <= 0.0 || rsi <= 0.0 || atr <= 0.0)
         continue;

      if(bias == 0)
        {
         bias = (rsi >= 50.0) ? 1 : -1;
         highest_since_cross = source;
         lowest_since_cross = source;
        }

      if(source > highest_since_cross)
         highest_since_cross = source;
      if(source < lowest_since_cross)
         lowest_since_cross = source;

      const double bull_pressure = ClampPressure((100.0 - rsi) / 100.0);
      const double bear_pressure = ClampPressure(rsi / 100.0);
      double lower = lowest_since_cross + (atr * strategy_band_atr_mult * bull_pressure);
      double upper = highest_since_cross - (atr * strategy_band_atr_mult * bear_pressure);
      if(upper <= lower)
        {
         const double mid = (upper + lower) * 0.5;
         upper = mid + (atr * 0.5);
         lower = mid - (atr * 0.5);
        }

      bool long_cross = false;
      bool short_cross = false;
      if(have_prev)
        {
         long_cross = (prev_source <= prev_lower && source > lower);
         short_cross = (prev_source >= prev_upper && source < upper);
         if(long_cross && !short_cross)
           {
            bias = 1;
            highest_since_cross = source;
            lowest_since_cross = source;
           }
         else if(short_cross && !long_cross)
           {
            bias = -1;
            highest_since_cross = source;
            lowest_since_cross = source;
           }
        }

      if(shift == 0)
        {
         g_band_source = source;
         g_band_rsi = rsi;
         g_band_atr = atr;
         g_band_upper = upper;
         g_band_lower = lower;
         g_band_long_cross = long_cross;
         g_band_short_cross = short_cross;
         g_band_ready = true;
        }

      prev_source = source;
      prev_upper = upper;
      prev_lower = lower;
      have_prev = true;
     }

   return g_band_ready;
  }

bool HasOurPosition(ENUM_POSITION_TYPE &position_type)
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool UsesAtrEmergencyStop()
  {
   if(StringFind(_Symbol, "XAU") >= 0)
      return true;
   if(StringFind(_Symbol, "XAG") >= 0)
      return true;
   if(StringFind(_Symbol, "XTI") >= 0)
      return true;
   if(StringFind(_Symbol, "XNG") >= 0)
      return true;
   return false;
  }

double MinimumBracketDistance(const double entry)
  {
   if(entry <= 0.0)
      return 0.0;

   if(UsesAtrEmergencyStop())
     {
      const double atr = (g_band_atr > 0.0) ? g_band_atr : QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
      if(atr <= 0.0)
         return 0.0;
      return atr * strategy_atr_emergency_mult;
     }

   return entry * (strategy_min_diff_pct / 100.0);
  }

double NormalizeStrategyPrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): no card time window; framework
   // handles news, while this hook applies the card's standard spread filter.
   if(strategy_max_spread_atr_pct <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(atr <= 0.0 || point <= 0.0 || spread_points < 0)
      return true;

   const double spread_price = (double)spread_points * point;
   return (spread_price > atr * strategy_max_spread_atr_pct / 100.0);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: source crosses up through the active lower band for long,
   // or crosses down through the active upper band for short, on confirmed bar.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!RecalculateBandState())
      return false;

   QM_OrderType side = QM_BUY;
   if(strategy_longs_enabled && g_band_long_cross)
      side = QM_BUY;
   else if(strategy_shorts_enabled && g_band_short_cross)
      side = QM_SELL;
   else
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (side == QM_BUY) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const double min_dist = MinimumBracketDistance(entry);
   if(min_dist <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(side == QM_BUY)
     {
      sl = (g_band_lower > 0.0 && g_band_lower < entry) ? g_band_lower : entry - min_dist;
      tp = (g_band_upper > entry) ? g_band_upper : entry + min_dist;
      if(entry - sl < min_dist)
         sl = entry - min_dist;
      if(tp - entry < min_dist)
         tp = entry + min_dist;
      req.reason = "HA_RSI_ATR_BAND_LONG";
     }
   else
     {
      sl = (g_band_upper > entry) ? g_band_upper : entry + min_dist;
      tp = (g_band_lower > 0.0 && g_band_lower < entry) ? g_band_lower : entry - min_dist;
      if(sl - entry < min_dist)
         sl = entry + min_dist;
      if(entry - tp < min_dist)
         tp = entry - min_dist;
      req.reason = "HA_RSI_ATR_BAND_SHORT";
     }

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeStrategyPrice(sl);
   req.tp = NormalizeStrategyPrice(tp);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: no card-authorized trailing, partial close, or BE rule.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   // Trade Close: cached band flip/opposite cross from the last confirmed bar.
   if(!g_band_ready)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!HasOurPosition(position_type))
      return false;

   if(position_type == POSITION_TYPE_BUY && g_band_short_cross)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_band_long_cross)
      return true;
   return false;
  }

// Optional news-filter override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no strategy-specific override; defer to framework.
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
