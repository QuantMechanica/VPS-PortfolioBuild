#property strict
#property version   "5.0"
#property description "QM5_10996 ftmo-obv-tl"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10996;
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
input int    strategy_donchian_period      = 30;
input int    strategy_atr_period           = 14;
input double strategy_break_atr_mult       = 0.10;
input double strategy_sl_atr_mult          = 0.75;
input double strategy_tp_rr                = 2.0;
input int    strategy_time_exit_bars       = 40;
input double strategy_range_min_atr        = 1.0;
input double strategy_range_max_atr        = 4.0;
input int    strategy_obv_swing_lookback   = 60;
input int    strategy_obv_slope_bars       = 10;
input int    strategy_obv_recent_bars      = 2;
input int    strategy_swing_gap_min        = 8;
input int    strategy_swing_gap_max        = 45;
input double strategy_spread_stop_pct      = 15.0;

#define QM_OBV_MAX_BARS 160

double g_obv[QM_OBV_MAX_BARS];
double g_desc_line[3];
double g_asc_line[3];
double g_donchian_high = 0.0;
double g_donchian_low = 0.0;
double g_atr_value = 0.0;
double g_close_1 = 0.0;
bool   g_state_ready = false;
bool   g_desc_line_ok = false;
bool   g_asc_line_ok = false;
bool   g_long_exit_state = false;
bool   g_short_exit_state = false;

int Strategy_LookbackBars()
  {
   int need = strategy_obv_swing_lookback + 3;
   if(need < strategy_donchian_period + 2)
      need = strategy_donchian_period + 2;
   if(need < strategy_obv_slope_bars + 2)
      need = strategy_obv_slope_bars + 2;
   if(need > QM_OBV_MAX_BARS)
      need = QM_OBV_MAX_BARS;
   return need;
  }

void ResetSignalState()
  {
   g_donchian_high = 0.0;
   g_donchian_low = 0.0;
   g_atr_value = 0.0;
   g_close_1 = 0.0;
   g_state_ready = false;
   g_desc_line_ok = false;
   g_asc_line_ok = false;
   g_long_exit_state = false;
   g_short_exit_state = false;
   for(int i = 0; i < 3; ++i)
     {
      g_desc_line[i] = 0.0;
      g_asc_line[i] = 0.0;
     }
  }

void BuildObvSeries(MqlRates &rates[], const int count)
  {
   for(int i = 0; i < QM_OBV_MAX_BARS; ++i)
      g_obv[i] = 0.0;

   if(count < 2)
      return;

   g_obv[count - 1] = 0.0;
   for(int i = count - 2; i >= 0; --i)
     {
      double value = g_obv[i + 1];
      if(rates[i].close > rates[i + 1].close)
         value += (double)rates[i].tick_volume;
      else if(rates[i].close < rates[i + 1].close)
         value -= (double)rates[i].tick_volume;
      g_obv[i] = value;
     }
  }

bool BuildObvTrendline(const bool swing_high, const double &obv[], const int count,
                       double &line[], bool &line_ok)
  {
   line_ok = false;
   for(int i = 0; i < 3; ++i)
      line[i] = 0.0;

   int scan_last = strategy_obv_swing_lookback;
   if(scan_last > count - 2)
      scan_last = count - 2;
   if(scan_last < 2)
      return false;

   int newer_shift = -1;
   int older_shift = -1;
   double newer_value = 0.0;
   double older_value = 0.0;

   for(int i = 1; i <= scan_last; ++i)
     {
      const double mid = obv[i];
      const double young = obv[i - 1];
      const double old = obv[i + 1];
      bool pivot = false;
      if(swing_high)
         pivot = (mid > young && mid > old);
      else
         pivot = (mid < young && mid < old);

      if(!pivot)
         continue;

      if(newer_shift < 0)
        {
         newer_shift = i;
         newer_value = mid;
        }
      else
        {
         older_shift = i;
         older_value = mid;
         break;
        }
     }

   if(newer_shift < 0 || older_shift < 0)
      return false;

   const int gap = older_shift - newer_shift;
   if(gap < strategy_swing_gap_min || gap > strategy_swing_gap_max)
      return false;

   if(swing_high && newer_value >= older_value)
      return false;
   if(!swing_high && newer_value <= older_value)
      return false;

   const double slope_per_bar = (newer_value - older_value) / (double)gap;
   for(int i = 0; i < 3; ++i)
      line[i] = newer_value + (double)(newer_shift - i) * slope_per_bar;

   line_ok = true;
   return true;
  }

bool ObvAboveDescending()
  {
   if(!g_desc_line_ok)
      return false;
   int recent = strategy_obv_recent_bars;
   if(recent > 2)
      recent = 2;
   for(int i = 0; i <= recent; ++i)
      if(g_obv[i] > g_desc_line[i])
         return true;
   return false;
  }

bool ObvBelowAscending()
  {
   if(!g_asc_line_ok)
      return false;
   int recent = strategy_obv_recent_bars;
   if(recent > 2)
      recent = 2;
   for(int i = 0; i <= recent; ++i)
      if(g_obv[i] < g_asc_line[i])
         return true;
   return false;
  }

bool RefreshSignalState()
  {
   ResetSignalState();

   const int need = Strategy_LookbackBars();
   if(need < 10)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, need, rates); // perf-allowed: EntrySignal is called only after QM_IsNewBar()
   if(copied < need)
      return false;

   BuildObvSeries(rates, copied);
   g_close_1 = rates[0].close;
   g_atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(g_close_1 <= 0.0 || g_atr_value <= 0.0)
      return false;

   if(strategy_donchian_period < 2 || strategy_donchian_period + 1 >= copied)
      return false;

   double hh = -DBL_MAX;
   double ll = DBL_MAX;
   for(int i = 1; i <= strategy_donchian_period; ++i)
     {
      if(rates[i].high > hh)
         hh = rates[i].high;
      if(rates[i].low < ll)
         ll = rates[i].low;
     }
   if(hh <= 0.0 || ll <= 0.0 || hh <= ll)
      return false;

   g_donchian_high = hh;
   g_donchian_low = ll;
   BuildObvTrendline(true, g_obv, copied, g_desc_line, g_desc_line_ok);
   BuildObvTrendline(false, g_obv, copied, g_asc_line, g_asc_line_ok);

   const bool back_inside_long = (g_close_1 < g_donchian_high);
   const bool back_inside_short = (g_close_1 > g_donchian_low);
   g_long_exit_state = (back_inside_long && g_desc_line_ok && g_obv[0] < g_desc_line[0]);
   g_short_exit_state = (back_inside_short && g_asc_line_ok && g_obv[0] > g_asc_line[0]);
   g_state_ready = true;
   return true;
  }

bool SelectStrategyPosition(bool &is_long, datetime &open_time)
  {
   is_long = false;
   open_time = 0;
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

      is_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only -- runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_atr_value <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return false;

   const double spread = ask - bid;
   const double stop_distance = strategy_sl_atr_mult * g_atr_value;
   if(spread > 0.0 && stop_distance > 0.0 &&
      spread > (strategy_spread_stop_pct / 100.0) * stop_distance)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!RefreshSignalState())
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double range_height = g_donchian_high - g_donchian_low;
   if(range_height < strategy_range_min_atr * g_atr_value)
      return false;
   if(range_height > strategy_range_max_atr * g_atr_value)
      return false;

   if(strategy_obv_slope_bars <= 0 || strategy_obv_slope_bars >= QM_OBV_MAX_BARS)
      return false;
   const double obv_slope = g_obv[0] - g_obv[strategy_obv_slope_bars];
   const double break_buffer = strategy_break_atr_mult * g_atr_value;

   if(g_close_1 > g_donchian_high + break_buffer &&
      ObvAboveDescending() &&
      obv_slope > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                        g_donchian_high - strategy_sl_atr_mult * g_atr_value);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ftmo_obv_tl_long";
      return true;
     }

   if(g_close_1 < g_donchian_low - break_buffer &&
      ObvBelowAscending() &&
      obv_slope < 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                        g_donchian_low + strategy_sl_atr_mult * g_atr_value);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ftmo_obv_tl_short";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   bool is_long = false;
   datetime open_time = 0;
   if(!SelectStrategyPosition(is_long, open_time))
      return false;

   const int seconds_per_bar = PeriodSeconds(_Period);
   if(strategy_time_exit_bars > 0 && seconds_per_bar > 0 && open_time > 0)
     {
      if(TimeCurrent() - open_time >= strategy_time_exit_bars * seconds_per_bar)
         return true;
     }

   if(!g_state_ready)
      return false;

   if(is_long && g_long_exit_state)
      return true;
   if(!is_long && g_short_exit_state)
      return true;

   return false;
  }

// Optional news-filter override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring -- do NOT edit below this line unless you know why.
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
