#property strict
#property version   "5.0"
#property description "QM5_12773 OPEC WTI Post-Window Impulse Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12773 - OPEC WTI Post-Window Impulse Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - detects a qualifying June/December OPEC-window impulse during days 1-14
//   - fades stretched same-direction follow-through during days 15-24
//   - exits on SMA mean reversion, fade-window end, max hold, Friday close, or SL
// Runtime uses MT5 OHLC/broker calendar only; no OPEC/EIA feed, news API, CSV,
// futures curve, analyst forecast, or external data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12773;
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
input int    strategy_event_month_a        = 6;
input int    strategy_event_month_b        = 12;
input int    strategy_window_start_day     = 1;
input int    strategy_window_end_day       = 14;
input int    strategy_fade_start_day       = 15;
input int    strategy_fade_end_day         = 24;
input int    strategy_trend_period         = 50;
input int    strategy_atr_period           = 20;
input double strategy_min_event_return_pct = 1.00;
input double strategy_min_event_range_atr  = 0.80;
input double strategy_min_follow_return_pct = 0.35;
input double strategy_min_close_location   = 0.65;
input double strategy_min_stretch_atr      = 0.65;
input double strategy_atr_sl_mult          = 2.75;
input int    strategy_max_hold_days        = 5;
input int    strategy_max_spread_points    = 1000;

int g_last_entry_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_DayOfMonth(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day;
  }

bool Strategy_IsEventMonth(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.mon == strategy_event_month_a || dt.mon == strategy_event_month_b);
  }

bool Strategy_InEventWindow(const datetime t)
  {
   if(t <= 0 || !Strategy_IsEventMonth(t))
      return false;
   const int day = Strategy_DayOfMonth(t);
   return (day >= strategy_window_start_day && day <= strategy_window_end_day);
  }

bool Strategy_InFadeWindow(const datetime t)
  {
   if(t <= 0 || !Strategy_IsEventMonth(t))
      return false;
   const int day = Strategy_DayOfMonth(t);
   return (day >= strategy_fade_start_day && day <= strategy_fade_end_day);
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

bool Strategy_LoadClosedState(double &close_last,
                              double &close_prev,
                              double &return_pct,
                              double &sma_last,
                              double &atr_last,
                              datetime &signal_time,
                              int &signal_day_key)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 2, rates) < 2) // perf-allowed: closed D1 post-OPEC state, new-bar gated.
      return false;

   signal_time = rates[0].time;
   signal_day_key = Strategy_DayKey(signal_time);
   close_last = rates[0].close;
   close_prev = rates[1].close;
   if(signal_time <= 0 || signal_day_key <= 0 || close_last <= 0.0 || close_prev <= 0.0)
      return false;

   return_pct = ((close_last / close_prev) - 1.0) * 100.0;
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_last <= 0.0 || atr_last <= 0.0)
      return false;

   return MathIsValidNumber(return_pct);
  }

bool Strategy_FindEventImpulse(const datetime current_bar_time, int &direction)
  {
   direction = 0;
   if(current_bar_time <= 0 || !Strategy_IsEventMonth(current_bar_time))
      return false;

   const int current_month_key = Strategy_MonthKey(current_bar_time);
   double best_abs_return = 0.0;

   for(int shift = 1; shift < 80; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 event-window scan, new-bar gated.
      if(bar_time <= 0)
         break;

      const int bar_month_key = Strategy_MonthKey(bar_time);
      if(bar_month_key < current_month_key)
         break;
      if(bar_month_key != current_month_key || !Strategy_InEventWindow(bar_time))
         continue;

      const double close_bar = iClose(_Symbol, PERIOD_D1, shift);      // perf-allowed: closed D1 event impulse state.
      const double close_prev = iClose(_Symbol, PERIOD_D1, shift + 1); // perf-allowed: closed D1 event impulse state.
      const double high_bar = iHigh(_Symbol, PERIOD_D1, shift);        // perf-allowed: closed D1 event impulse state.
      const double low_bar = iLow(_Symbol, PERIOD_D1, shift);          // perf-allowed: closed D1 event impulse state.
      const double atr_bar = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(close_bar <= 0.0 || close_prev <= 0.0 || high_bar <= 0.0 || low_bar <= 0.0 || high_bar <= low_bar || atr_bar <= 0.0)
         continue;

      const double range = high_bar - low_bar;
      if(range < atr_bar * strategy_min_event_range_atr)
         continue;

      const double ret_pct = ((close_bar / close_prev) - 1.0) * 100.0;
      if(!MathIsValidNumber(ret_pct) || MathAbs(ret_pct) < strategy_min_event_return_pct)
         continue;

      const double close_location = (close_bar - low_bar) / range;
      const int candidate_direction = (ret_pct > 0.0) ? 1 : -1;
      if(candidate_direction > 0 && close_location < strategy_min_close_location)
         continue;
      if(candidate_direction < 0 && close_location > (1.0 - strategy_min_close_location))
         continue;

      const double abs_ret = MathAbs(ret_pct);
      if(abs_ret > best_abs_return)
        {
         best_abs_return = abs_ret;
         direction = candidate_direction;
        }
     }

   return (direction != 0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 fade-window exit gate.
   const int current_month_key = Strategy_MonthKey(current_bar_time);
   const bool in_fade_window = Strategy_InFadeWindow(current_bar_time);

   double close_last = 0.0;
   double close_prev = 0.0;
   double return_pct = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   const bool have_state = Strategy_LoadClosedState(close_last, close_prev, return_pct,
                                                    sma_last, atr_last, signal_time,
                                                    signal_day_key);

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
      const int opened_month_key = Strategy_MonthKey(opened);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(!in_fade_window)
         should_close = true;
      if(opened_month_key > 0 && current_month_key > 0 && opened_month_key != current_month_key)
         should_close = true;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(have_state && pos_type == POSITION_TYPE_SELL && close_last <= sma_last)
         should_close = true;
      if(have_state && pos_type == POSITION_TYPE_BUY && close_last >= sma_last)
         should_close = true;

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
   if(strategy_event_month_a < 1 || strategy_event_month_a > 12)
      return true;
   if(strategy_event_month_b < 1 || strategy_event_month_b > 12)
      return true;
   if(strategy_window_start_day < 1 || strategy_window_end_day < strategy_window_start_day || strategy_window_end_day > 31)
      return true;
   if(strategy_fade_start_day <= strategy_window_end_day || strategy_fade_end_day < strategy_fade_start_day || strategy_fade_end_day > 31)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0)
      return true;
   if(strategy_min_event_return_pct <= 0.0 || strategy_min_event_range_atr <= 0.0)
      return true;
   if(strategy_min_follow_return_pct <= 0.0 || strategy_min_stretch_atr <= 0.0)
      return true;
   if(strategy_min_close_location <= 0.50 || strategy_min_close_location >= 0.95)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12773_OPEC_WTI_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 post-OPEC fade calendar gate.
   if(current_bar_time <= 0 || !Strategy_InFadeWindow(current_bar_time))
      return false;

   const int current_day_key = Strategy_DayKey(current_bar_time);
   if(current_day_key <= 0 || current_day_key == g_last_entry_day_key)
      return false;

   int impulse_direction = 0;
   if(!Strategy_FindEventImpulse(current_bar_time, impulse_direction))
      return false;

   double close_last = 0.0;
   double close_prev = 0.0;
   double return_pct = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   if(!Strategy_LoadClosedState(close_last, close_prev, return_pct, sma_last,
                                atr_last, signal_time, signal_day_key))
      return false;

   if(impulse_direction > 0)
     {
      if(return_pct < strategy_min_follow_return_pct)
         return false;
      if(close_last <= sma_last || (close_last - sma_last) < atr_last * strategy_min_stretch_atr)
         return false;
      req.type = QM_SELL;
      req.reason = "OPEC_POST_WINDOW_UP_IMPULSE_FADE_SHORT";
     }
   else if(impulse_direction < 0)
     {
      if(return_pct > -strategy_min_follow_return_pct)
         return false;
      if(close_last >= sma_last || (sma_last - close_last) < atr_last * strategy_min_stretch_atr)
         return false;
      req.type = QM_BUY;
      req.reason = "OPEC_POST_WINDOW_DOWN_IMPULSE_FADE_LONG";
     }
   else
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   g_last_entry_day_key = current_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12773\",\"ea\":\"opec-wti-fade\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
