#property strict
#property version   "5.0"
#property description "QM5_13095 XTI outside-week exhaustion fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13095 - XTI Outside-Week Exhaustion Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - previous broker week must be an outside week versus its parent week
//   - current week D1 close can confirm exhaustion back inside the parent range
//   - exits on failed fade, SMA mean reach, max hold, ATR stop/target
// Runtime uses MT5 OHLC/broker calendar only; no futures curve/API/CSV/feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13095;
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
input int    strategy_min_week_bars          = 3;
input int    strategy_signal_min_dow         = 1;
input int    strategy_signal_max_dow         = 4;
input int    strategy_atr_period             = 20;
input int    strategy_trend_period           = 60;
input double strategy_min_outside_range_atr  = 1.20;
input double strategy_max_outside_range_atr  = 4.50;
input double strategy_min_parent_range_atr   = 0.80;
input double strategy_reclaim_buffer_atr     = 0.15;
input double strategy_extreme_close_location = 0.65;
input double strategy_min_reversal_close_location = 0.58;
input double strategy_atr_sl_mult            = 2.80;
input double strategy_atr_tp_mult            = 2.20;
input int    strategy_max_hold_days          = 10;
input int    strategy_max_spread_points      = 1000;

int g_last_entry_week_key = 0;

bool     g_outside_ready           = false;
double   g_signal_close_last       = 0.0;
double   g_signal_open_last        = 0.0;
double   g_outside_high            = 0.0;
double   g_outside_low             = 0.0;
double   g_outside_close           = 0.0;
double   g_parent_high             = 0.0;
double   g_parent_low              = 0.0;
double   g_outside_range           = 0.0;
double   g_parent_range            = 0.0;
double   g_atr_last                = 0.0;
double   g_sma_last                = 0.0;
double   g_outside_close_location  = 0.0;
double   g_signal_close_location   = 0.0;
int      g_signal_week_key         = 0;
int      g_signal_dow              = -1;
datetime g_signal_week             = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

datetime Strategy_DateMidnight(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_WeekStart(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int dow = dt.day_of_week;
   const int offset_days = (dow == 0) ? 6 : (dow - 1);
   return Strategy_DateMidnight(t) - offset_days * 86400;
  }

int Strategy_WeekKey(const datetime t)
  {
   const datetime start = Strategy_WeekStart(t);
   if(start <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(start, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   if(t <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool Strategy_SameWeek(const datetime t, const datetime week_start)
  {
   if(t <= 0 || week_start <= 0)
      return false;
   const datetime day = Strategy_DateMidnight(t);
   return (day >= week_start && day < week_start + 7 * 86400);
  }

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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_AggregateWeek(const MqlRates &rates[],
                            const int copied,
                            const datetime week_start,
                            double &week_high,
                            double &week_low,
                            double &week_close,
                            int &week_bars)
  {
   week_high = 0.0;
   week_low = 0.0;
   week_close = 0.0;
   week_bars = 0;

   if(week_start <= 0 || copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      if(!Strategy_SameWeek(rates[i].time, week_start))
         continue;
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high < rates[i].low || rates[i].close <= 0.0)
         return false;
      if(week_bars == 0)
        {
         week_high = rates[i].high;
         week_low = rates[i].low;
         week_close = rates[i].close;
        }
      else
        {
         week_high = MathMax(week_high, rates[i].high);
         week_low = MathMin(week_low, rates[i].low);
        }
      ++week_bars;
     }

   return (week_bars >= strategy_min_week_bars && week_high > week_low && week_close > 0.0);
  }

bool Strategy_LoadOutsideSetupForWeek(const datetime signal_week_start,
                                      const MqlRates &rates[],
                                      const int copied,
                                      double &outside_high,
                                      double &outside_low,
                                      double &outside_close,
                                      double &parent_high,
                                      double &parent_low,
                                      double &outside_range,
                                      double &parent_range)
  {
   outside_high = 0.0;
   outside_low = 0.0;
   outside_close = 0.0;
   parent_high = 0.0;
   parent_low = 0.0;
   outside_range = 0.0;
   parent_range = 0.0;

   if(signal_week_start <= 0)
      return false;

   const datetime outside_week_start = signal_week_start - 7 * 86400;
   const datetime parent_week_start = signal_week_start - 14 * 86400;

   int outside_bars = 0;
   int parent_bars = 0;
   double parent_close = 0.0;
   if(!Strategy_AggregateWeek(rates, copied, outside_week_start, outside_high, outside_low, outside_close, outside_bars))
      return false;
   if(!Strategy_AggregateWeek(rates, copied, parent_week_start, parent_high, parent_low, parent_close, parent_bars))
      return false;

   if(outside_high <= parent_high || outside_low >= parent_low)
      return false;

   outside_range = outside_high - outside_low;
   parent_range = parent_high - parent_low;
   return (outside_range > 0.0 && parent_range > 0.0);
  }

bool Strategy_LoadOutsideState(double &close_last,
                               double &open_last,
                               double &outside_high,
                               double &outside_low,
                               double &outside_close,
                               double &parent_high,
                               double &parent_low,
                               double &outside_range,
                               double &parent_range,
                               double &atr_last,
                               double &sma_last,
                               double &outside_close_location,
                               double &signal_close_location,
                               int &signal_week_key,
                               int &signal_dow,
                               datetime &signal_week_start)
  {
   close_last = 0.0;
   open_last = 0.0;
   outside_high = 0.0;
   outside_low = 0.0;
   outside_close = 0.0;
   parent_high = 0.0;
   parent_low = 0.0;
   outside_range = 0.0;
   parent_range = 0.0;
   atr_last = 0.0;
   sma_last = 0.0;
   outside_close_location = 0.0;
   signal_close_location = 0.0;
   signal_week_key = 0;
   signal_dow = -1;
   signal_week_start = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 90, rates); // perf-allowed: bespoke weekly outside-bar state, gated by QM_IsNewBar().
   if(copied < 15)
      return false;

   const datetime signal_time = rates[0].time;
   signal_week_start = Strategy_WeekStart(signal_time);
   signal_week_key = Strategy_WeekKey(signal_time);
   signal_dow = Strategy_DayOfWeek(signal_time);
   if(signal_week_start <= 0 || signal_week_key <= 0)
      return false;

   if(!Strategy_LoadOutsideSetupForWeek(signal_week_start,
                                        rates,
                                        copied,
                                        outside_high,
                                        outside_low,
                                        outside_close,
                                        parent_high,
                                        parent_low,
                                        outside_range,
                                        parent_range))
      return false;

   close_last = rates[0].close;
   open_last = rates[0].open;
   const double high_last = rates[0].high;
   const double low_last = rates[0].low;
   const double bar_range = high_last - low_last;
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(close_last <= 0.0 || open_last <= 0.0 || high_last <= low_last || bar_range <= 0.0)
      return false;
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   outside_close_location = (outside_close - outside_low) / outside_range;
   signal_close_location = (close_last - low_last) / bar_range;
   return (MathIsValidNumber(outside_close_location) && MathIsValidNumber(signal_close_location));
  }

void Strategy_RefreshOutsideState()
  {
   g_outside_ready = Strategy_LoadOutsideState(g_signal_close_last,
                                               g_signal_open_last,
                                               g_outside_high,
                                               g_outside_low,
                                               g_outside_close,
                                               g_parent_high,
                                               g_parent_low,
                                               g_outside_range,
                                               g_parent_range,
                                               g_atr_last,
                                               g_sma_last,
                                               g_outside_close_location,
                                               g_signal_close_location,
                                               g_signal_week_key,
                                               g_signal_dow,
                                               g_signal_week);
  }

bool Strategy_LoadPositionManageState(const datetime open_week_start,
                                      double &outside_high,
                                      double &outside_low,
                                      double &close_last,
                                      double &sma_last)
  {
   outside_high = 0.0;
   outside_low = 0.0;
   close_last = 0.0;
   sma_last = 0.0;

   if(open_week_start <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 90, rates); // perf-allowed: position exit needs the entry week's outside range, gated by QM_IsNewBar().
   if(copied < 15)
      return false;

   double parent_high = 0.0;
   double parent_low = 0.0;
   double outside_close = 0.0;
   double outside_range = 0.0;
   double parent_range = 0.0;
   if(!Strategy_LoadOutsideSetupForWeek(open_week_start,
                                        rates,
                                        copied,
                                        outside_high,
                                        outside_low,
                                        outside_close,
                                        parent_high,
                                        parent_low,
                                        outside_range,
                                        parent_range))
      return false;

   close_last = rates[0].close;
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   return (close_last > 0.0 && sma_last > 0.0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      double outside_high = 0.0;
      double outside_low = 0.0;
      double close_last = 0.0;
      double sma_last = 0.0;
      const datetime open_week_start = Strategy_WeekStart(opened);
      if(Strategy_LoadPositionManageState(open_week_start, outside_high, outside_low, close_last, sma_last))
        {
         const bool profitable = (PositionGetDouble(POSITION_PROFIT) > 0.0);
         if(pos_type == POSITION_TYPE_BUY)
           {
            if(close_last <= outside_low || (profitable && close_last >= sma_last))
               should_close = true;
           }
         else if(pos_type == POSITION_TYPE_SELL)
           {
            if(close_last >= outside_high || (profitable && close_last <= sma_last))
               should_close = true;
           }
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_min_week_bars < 2 || strategy_min_week_bars > 5)
      return true;
   if(strategy_signal_min_dow < 1 || strategy_signal_max_dow > 5 || strategy_signal_min_dow > strategy_signal_max_dow)
      return true;
   if(strategy_atr_period <= 1 || strategy_trend_period <= 1)
      return true;
   if(strategy_min_outside_range_atr <= 0.0 || strategy_max_outside_range_atr <= strategy_min_outside_range_atr)
      return true;
   if(strategy_min_parent_range_atr <= 0.0)
      return true;
   if(strategy_reclaim_buffer_atr < 0.0)
      return true;
   if(strategy_extreme_close_location <= 0.5 || strategy_extreme_close_location >= 1.0)
      return true;
   if(strategy_min_reversal_close_location <= 0.5 || strategy_min_reversal_close_location > 1.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13095_XTI_OUTWEEK_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   if(!g_outside_ready)
      return false;

   if(g_signal_week_key <= 0 || g_signal_week_key == g_last_entry_week_key)
      return false;
   if(g_signal_dow < strategy_signal_min_dow || g_signal_dow > strategy_signal_max_dow)
      return false;
   if(g_outside_range < strategy_min_outside_range_atr * g_atr_last)
      return false;
   if(g_outside_range > strategy_max_outside_range_atr * g_atr_last)
      return false;
   if(g_parent_range < strategy_min_parent_range_atr * g_atr_last)
      return false;

   const double buffer = strategy_reclaim_buffer_atr * g_atr_last;
   if(g_outside_high < g_parent_high + buffer || g_outside_low > g_parent_low - buffer)
      return false;

   const double long_reclaim = MathMax(g_parent_low, g_outside_low + buffer);
   const double short_reclaim = MathMin(g_parent_high, g_outside_high - buffer);
   int direction = 0;
   if(g_outside_close_location <= (1.0 - strategy_extreme_close_location) &&
      g_outside_close < g_sma_last &&
      g_signal_close_last > long_reclaim &&
      g_signal_close_last > g_signal_open_last &&
      g_signal_close_location >= strategy_min_reversal_close_location)
      direction = 1;
   else if(g_outside_close_location >= strategy_extreme_close_location &&
           g_outside_close > g_sma_last &&
           g_signal_close_last < short_reclaim &&
           g_signal_close_last < g_signal_open_last &&
           g_signal_close_location <= (1.0 - strategy_min_reversal_close_location))
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, g_atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = (req.type == QM_BUY)
            ? NormalizeDouble(entry_price + strategy_atr_tp_mult * g_atr_last, digits)
            : NormalizeDouble(entry_price - strategy_atr_tp_mult * g_atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY && req.tp <= entry_price)
      return false;
   if(req.type == QM_SELL && req.tp >= entry_price)
      return false;

   req.reason = (direction > 0) ? "XTI_OUTWEEK_FADE_LONG" : "XTI_OUTWEEK_FADE_SHORT";
   g_last_entry_week_key = g_signal_week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_RefreshOutsideState();
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13095\",\"ea\":\"xti-outweek-fade\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();

   if(is_new_bar)
      Strategy_ManageOpenPosition();

   if(is_new_bar && Strategy_ExitSignal())
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
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
