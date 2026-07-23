#property strict
#property version   "5.1"
#property description "QM5_13075 XTI Inside-Week Compression Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13075;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_min_week_bars        = 3;
input int    strategy_signal_min_dow       = 1;
input int    strategy_signal_max_dow       = 4;
input int    strategy_atr_period           = 20;
input int    strategy_trend_period         = 60;
input double strategy_min_inside_range_atr = 0.60;
input double strategy_max_inside_range_atr = 2.40;
input double strategy_min_parent_range_atr = 1.20;
input double strategy_entry_buffer_atr     = 0.08;
input double strategy_min_close_location   = 0.58;
input double strategy_atr_sl_mult          = 2.60;
input double strategy_atr_tp_mult          = 3.20;
input int    strategy_max_hold_days        = 8;
input int    strategy_max_spread_points    = 1000;

int      g_last_entry_week_key = 0;
bool     g_state_ready         = false;
double   g_close_last          = 0.0;
double   g_inside_high         = 0.0;
double   g_inside_low          = 0.0;
double   g_atr_last            = 0.0;
double   g_sma_last            = 0.0;
double   g_close_location      = 0.0;
double   g_inside_range        = 0.0;
double   g_parent_range        = 0.0;
int      g_signal_week_key     = 0;
int      g_signal_dow          = -1;

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
   const int offset_days = (dt.day_of_week == 0) ? 6 : dt.day_of_week - 1;
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
   MqlDateTime dt;
   if(t <= 0 || !TimeToStruct(t, dt))
      return -1;
   return dt.day_of_week;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_LoadState()
  {
   g_state_ready = false;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 45, rates);
   if(copied < 12)
      return false;

   const datetime signal_time = rates[0].time;
   const datetime signal_week = Strategy_WeekStart(signal_time);
   if(signal_week <= 0)
      return false;

   int first_previous = -1;
   int first_parent = -1;
   for(int i = 0; i < copied; ++i)
     {
      const datetime week = Strategy_WeekStart(rates[i].time);
      if(week < signal_week && first_previous < 0)
         first_previous = i;
      else if(first_previous >= 0 && week < Strategy_WeekStart(rates[first_previous].time))
        {
         first_parent = i;
         break;
        }
     }
   if(first_previous < 0 || first_parent < 0)
      return false;

   const datetime previous_week = Strategy_WeekStart(rates[first_previous].time);
   const datetime parent_week = Strategy_WeekStart(rates[first_parent].time);
   double inside_high = -DBL_MAX;
   double inside_low = DBL_MAX;
   double parent_high = -DBL_MAX;
   double parent_low = DBL_MAX;
   int inside_bars = 0;
   int parent_bars = 0;

   for(int i = first_previous; i < copied; ++i)
     {
      const datetime week = Strategy_WeekStart(rates[i].time);
      if(week == previous_week)
        {
         inside_high = MathMax(inside_high, rates[i].high);
         inside_low = MathMin(inside_low, rates[i].low);
         ++inside_bars;
        }
      else if(week == parent_week)
        {
         parent_high = MathMax(parent_high, rates[i].high);
         parent_low = MathMin(parent_low, rates[i].low);
         ++parent_bars;
        }
      else if(week < parent_week)
         break;
     }

   if(inside_bars < strategy_min_week_bars || parent_bars < strategy_min_week_bars)
      return false;
   if(inside_high > parent_high || inside_low < parent_low)
      return false;

   g_close_last = rates[0].close;
   g_inside_high = inside_high;
   g_inside_low = inside_low;
   g_inside_range = inside_high - inside_low;
   g_parent_range = parent_high - parent_low;
   g_atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   g_sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   const double signal_range = rates[0].high - rates[0].low;
   if(g_close_last <= 0.0 || g_inside_range <= 0.0 || g_parent_range <= 0.0 ||
      g_atr_last <= 0.0 || g_sma_last <= 0.0 || signal_range <= 0.0)
      return false;

   g_close_location = (g_close_last - rates[0].low) / signal_range;
   g_signal_week_key = Strategy_WeekKey(signal_time);
   g_signal_dow = Strategy_DayOfWeek(signal_time);
   g_state_ready = MathIsValidNumber(g_close_location);
   return g_state_ready;
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
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool close_position = (opened > 0 && now - opened >= hold_seconds);
      if(g_state_ready && type == POSITION_TYPE_BUY &&
         (g_close_last < g_inside_high || g_close_last < g_sma_last))
         close_position = true;
      if(g_state_ready && type == POSITION_TYPE_SELL &&
         (g_close_last > g_inside_low || g_close_last > g_sma_last))
         close_position = true;
      if(close_position)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XTIUSD.DWX" || _Period != PERIOD_D1 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_min_week_bars < 1 || strategy_min_week_bars > 5)
      return true;
   if(strategy_signal_min_dow < 1 || strategy_signal_max_dow > 5 ||
      strategy_signal_min_dow > strategy_signal_max_dow)
      return true;
   if(strategy_atr_period <= 0 || strategy_trend_period <= 1)
      return true;
   if(strategy_min_inside_range_atr <= 0.0 ||
      strategy_max_inside_range_atr <= strategy_min_inside_range_atr ||
      strategy_min_parent_range_atr <= 0.0)
      return true;
   if(strategy_entry_buffer_atr < 0.0 ||
      strategy_min_close_location <= 0.5 || strategy_min_close_location > 1.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0 ||
      strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13075_XTI_INSIDE_WEEK_BREAKOUT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition() || !g_state_ready)
      return false;
   if(g_signal_week_key <= 0 || g_signal_week_key == g_last_entry_week_key)
      return false;
   if(g_signal_dow < strategy_signal_min_dow || g_signal_dow > strategy_signal_max_dow)
      return false;
   if(strategy_max_spread_points > 0 &&
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return false;
   if(g_inside_range < strategy_min_inside_range_atr * g_atr_last ||
      g_inside_range > strategy_max_inside_range_atr * g_atr_last ||
      g_parent_range < strategy_min_parent_range_atr * g_atr_last)
      return false;

   const double buffer = strategy_entry_buffer_atr * g_atr_last;
   int direction = 0;
   if(g_close_last > g_inside_high + buffer && g_close_last > g_sma_last &&
      g_close_location >= strategy_min_close_location)
      direction = 1;
   else if(g_close_last < g_inside_low - buffer && g_close_last < g_sma_last &&
           g_close_location <= 1.0 - strategy_min_close_location)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_tp_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (direction > 0) ? "XTI_INSIDE_WEEK_BREAKOUT_LONG" : "XTI_INSIDE_WEEK_BREAKOUT_SHORT";
   g_last_entry_week_key = g_signal_week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_LoadState();
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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13075\",\"ea\":\"xti-inweek-brk\"}");
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
   if(QM_FrameworkHandleFridayClose() || Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      Strategy_ManageOpenPosition();

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !is_new_bar)
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
