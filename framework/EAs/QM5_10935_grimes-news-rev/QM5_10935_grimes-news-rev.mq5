#property strict
#property version   "5.0"
#property description "QM5_10935 Grimes Bad-News Reversal Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10935;
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
input int    strategy_atr_period                 = 20;
input double strategy_gap_d1_atr_mult            = 0.75;
input int    strategy_first_hour_bars            = 6;
input int    strategy_recovery_min_bars          = 4;
input int    strategy_recovery_max_bars          = 12;
input int    strategy_preopen_proxy_bars         = 16;
input double strategy_failed_reclaim_atr_mult    = 0.25;
input double strategy_entry_buffer_atr_mult      = 0.10;
input double strategy_stop_buffer_atr_mult       = 0.25;
input double strategy_target_r_mult              = 2.00;
input double strategy_max_stop_d1_atr_mult       = 1.25;
input double strategy_spread_stop_fraction       = 0.10;
input int    strategy_session_start_hour         = 15;
input int    strategy_session_start_minute       = 30;
input int    strategy_session_end_hour           = 22;
input int    strategy_session_end_minute         = 0;
input double strategy_latest_entry_session_frac  = 0.75;

int    g_trade_day_key = -1;
bool   g_trade_submitted_today = false;
ulong  g_active_ticket = 0;
double g_active_entry = 0.0;
double g_active_initial_r = 0.0;
bool   g_active_be_done = false;

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int SessionStartMinute()
  {
   return strategy_session_start_hour * 60 + strategy_session_start_minute;
  }

int SessionEndMinute()
  {
   return strategy_session_end_hour * 60 + strategy_session_end_minute;
  }

bool SelectOurPosition(ulong &ticket,
                       ENUM_POSITION_TYPE &ptype,
                       double &open_price,
                       double &sl)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      return true;
     }
   return false;
  }

void TrackPosition(const ulong ticket,
                   const double open_price,
                   const double sl)
  {
   if(ticket == g_active_ticket)
      return;

   g_active_ticket = ticket;
   g_active_entry = open_price;
   g_active_initial_r = MathAbs(open_price - sl);
   g_active_be_done = false;
   if(open_price > 0.0 && sl > 0.0)
     {
      g_trade_day_key = DayKey(TimeCurrent());
      g_trade_submitted_today = true;
     }
  }

void ResetPositionTracking()
  {
   g_active_ticket = 0;
   g_active_entry = 0.0;
   g_active_initial_r = 0.0;
   g_active_be_done = false;
  }

bool BuildSessionBars(const MqlRates &rates[],
                      const int copied,
                      const int day_key,
                      const int session_start,
                      MqlRates &session[])
  {
   ArrayResize(session, 0);
   for(int i = copied - 1; i >= 1; --i)
     {
      if(DayKey(rates[i].time) != day_key)
         continue;
      const int minute = MinuteOfDay(rates[i].time);
      if(minute < session_start)
         continue;

      const int n = ArraySize(session);
      ArrayResize(session, n + 1);
      session[n] = rates[i];
     }
   return (ArraySize(session) > 0);
  }

void BuildPreopenProxy(const MqlRates &rates[],
                       const int copied,
                       const int day_key,
                       const int session_start,
                       double &preopen_low,
                       double &preopen_high)
  {
   preopen_low = DBL_MAX;
   preopen_high = -DBL_MAX;
   int seen = 0;
   for(int i = copied - 1; i >= 1; --i)
     {
      if(DayKey(rates[i].time) != day_key)
         continue;
      const int minute = MinuteOfDay(rates[i].time);
      if(minute >= session_start)
         continue;
      if(minute < session_start - strategy_preopen_proxy_bars * PeriodSeconds(PERIOD_M15) / 60)
         continue;
      preopen_low = MathMin(preopen_low, rates[i].low);
      preopen_high = MathMax(preopen_high, rates[i].high);
      seen++;
     }

   if(seen <= 0)
     {
      preopen_low = 0.0;
      preopen_high = 0.0;
     }
  }

bool TradeAlreadySubmittedToday()
  {
   const int today = DayKey(TimeCurrent());
   if(g_trade_day_key != today)
     {
      g_trade_day_key = today;
      g_trade_submitted_today = false;
      return false;
     }

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   if(SelectOurPosition(ticket, ptype, open_price, sl))
      return true;

   return g_trade_submitted_today;
  }

// No Trade Filter (time, spread, news). Framework handles news; spread is
// checked in Trade Entry after the card-defined stop distance is known.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M15)
      return true;

   const int start_minute = SessionStartMinute();
   const int end_minute = SessionEndMinute();
   if(start_minute < 0 || start_minute >= 1440 || end_minute <= start_minute || end_minute > 1440)
      return true;

   if(strategy_atr_period <= 0 ||
      strategy_gap_d1_atr_mult <= 0.0 ||
      strategy_first_hour_bars < 1 ||
      strategy_recovery_min_bars < 1 ||
      strategy_recovery_max_bars < strategy_recovery_min_bars ||
      strategy_preopen_proxy_bars < 0 ||
      strategy_failed_reclaim_atr_mult <= 0.0 ||
      strategy_entry_buffer_atr_mult < 0.0 ||
      strategy_stop_buffer_atr_mult < 0.0 ||
      strategy_target_r_mult <= 0.0 ||
      strategy_max_stop_d1_atr_mult <= 0.0 ||
      strategy_spread_stop_fraction <= 0.0 ||
      strategy_latest_entry_session_frac <= 0.0 ||
      strategy_latest_entry_session_frac > 1.0)
      return true;

   const int now_minute = MinuteOfDay(TimeCurrent());
   if(now_minute >= start_minute && now_minute < end_minute)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   return !SelectOurPosition(ticket, ptype, open_price, sl);
  }

// Trade Entry. Called once per closed M15 bar by the framework. It scans a
// bounded current-session window for the card's gap, failed break, recovery
// range, and breakout sequence.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, current_sl;
   if(SelectOurPosition(ticket, ptype, open_price, current_sl))
     {
      TrackPosition(ticket, open_price, current_sl);
      return false;
     }
   ResetPositionTracking();

   if(TradeAlreadySubmittedToday())
      return false;

   const int start_minute = SessionStartMinute();
   const int end_minute = SessionEndMinute();
   const int now_minute = MinuteOfDay(TimeCurrent());
   const double elapsed_fraction = (double)(now_minute - start_minute) / (double)(end_minute - start_minute);
   if(elapsed_fraction > strategy_latest_entry_session_frac)
      return false;

   MqlRates d1[];
   ArraySetAsSeries(d1, true);
   const int d1_copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, d1); // perf-allowed: prior D1 OHLC, QM_IsNewBar() gated caller.
   if(d1_copied != 1)
      return false;

   const double prior_close = d1[0].close;
   const double prior_low = d1[0].low;
   const double prior_high = d1[0].high;
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(prior_close <= 0.0 || prior_low <= 0.0 || prior_high <= 0.0 || atr_d1 <= 0.0 || atr_m15 <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 0, 160, rates); // perf-allowed: bounded intraday session window, QM_IsNewBar() gated caller.
   if(copied < strategy_first_hour_bars + strategy_recovery_min_bars + 3)
      return false;

   const int today = DayKey(rates[1].time);
   MqlRates session[];
   if(!BuildSessionBars(rates, copied, today, start_minute, session))
      return false;

   const int session_count = ArraySize(session);
   if(session_count < strategy_first_hour_bars + strategy_recovery_min_bars + 2)
      return false;

   double preopen_low = 0.0;
   double preopen_high = 0.0;
   BuildPreopenProxy(rates, copied, today, start_minute, preopen_low, preopen_high);

   const double session_open = session[0].open;
   if(session_open <= 0.0)
      return false;

   double first_hour_low = DBL_MAX;
   double first_hour_high = -DBL_MAX;
   for(int i = 0; i < strategy_first_hour_bars && i < session_count; ++i)
     {
      first_hour_low = MathMin(first_hour_low, session[i].low);
      first_hour_high = MathMax(first_hour_high, session[i].high);
     }

   if(first_hour_low == DBL_MAX || first_hour_high <= 0.0)
      return false;

   const bool long_gap = (session_open <= prior_close - strategy_gap_d1_atr_mult * atr_d1);
   const bool short_gap = (session_open >= prior_close + strategy_gap_d1_atr_mult * atr_d1);
   const bool first_hour_broke_low = (first_hour_low < prior_low || (preopen_low > 0.0 && first_hour_low < preopen_low));
   const bool first_hour_broke_high = (first_hour_high > prior_high || (preopen_high > 0.0 && first_hour_high > preopen_high));

   if((!long_gap || !first_hour_broke_low) && (!short_gap || !first_hour_broke_high))
      return false;

   const int signal_idx = session_count - 1;
   const double signal_close = session[signal_idx].close;
   if(signal_close <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   for(int rec_bars = strategy_recovery_min_bars; rec_bars <= strategy_recovery_max_bars; ++rec_bars)
     {
      const int failed_idx = signal_idx - rec_bars - 1;
      if(failed_idx < strategy_first_hour_bars - 1)
         continue;

      double low_to_failed = DBL_MAX;
      double high_to_failed = -DBL_MAX;
      for(int i = 0; i <= failed_idx; ++i)
        {
         low_to_failed = MathMin(low_to_failed, session[i].low);
         high_to_failed = MathMax(high_to_failed, session[i].high);
        }

      double recovery_high = -DBL_MAX;
      double recovery_low = DBL_MAX;
      for(int i = failed_idx + 1; i < signal_idx; ++i)
        {
         recovery_high = MathMax(recovery_high, session[i].high);
         recovery_low = MathMin(recovery_low, session[i].low);
        }

      if(recovery_high <= 0.0 || recovery_low == DBL_MAX)
         continue;

      if(long_gap && first_hour_broke_low)
        {
         const bool made_session_low = (session[failed_idx].low <= low_to_failed + _Point * 0.5);
         const bool reclaimed = (session[failed_idx].close >= first_hour_low + strategy_failed_reclaim_atr_mult * atr_m15);
         const bool broke_recovery = (signal_close >= recovery_high + strategy_entry_buffer_atr_mult * atr_m15);
         if(made_session_low && reclaimed && broke_recovery)
           {
            const double stop = NormalizeDouble(low_to_failed - strategy_stop_buffer_atr_mult * atr_m15, _Digits);
            const double entry = ask;
            const double risk = entry - stop;
            if(risk <= 0.0 || risk > strategy_max_stop_d1_atr_mult * atr_d1)
               return false;
            if((ask - bid) > strategy_spread_stop_fraction * risk)
               return false;

            double target = entry + strategy_target_r_mult * risk;
            if(prior_close > entry)
               target = MathMin(target, prior_close);

            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = stop;
            req.tp = NormalizeDouble(target, _Digits);
            req.reason = "GRIMES_NEWS_REV_LONG";
            g_trade_day_key = today;
            g_trade_submitted_today = true;
            return true;
           }
        }

      if(short_gap && first_hour_broke_high)
        {
         const bool made_session_high = (session[failed_idx].high >= high_to_failed - _Point * 0.5);
         const bool reclaimed = (session[failed_idx].close <= first_hour_high - strategy_failed_reclaim_atr_mult * atr_m15);
         const bool broke_recovery = (signal_close <= recovery_low - strategy_entry_buffer_atr_mult * atr_m15);
         if(made_session_high && reclaimed && broke_recovery)
           {
            const double stop = NormalizeDouble(high_to_failed + strategy_stop_buffer_atr_mult * atr_m15, _Digits);
            const double entry = bid;
            const double risk = stop - entry;
            if(risk <= 0.0 || risk > strategy_max_stop_d1_atr_mult * atr_d1)
               return false;
            if((ask - bid) > strategy_spread_stop_fraction * risk)
               return false;

            double target = entry - strategy_target_r_mult * risk;
            if(prior_close < entry)
               target = MathMax(target, prior_close);

            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = stop;
            req.tp = NormalizeDouble(target, _Digits);
            req.reason = "GRIMES_NEWS_REV_SHORT";
            g_trade_day_key = today;
            g_trade_submitted_today = true;
            return true;
           }
        }
     }

   return false;
  }

// Trade Management. Move the initial stop to breakeven when the open position
// has moved at least 1R in favour, matching the card.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   if(!SelectOurPosition(ticket, ptype, open_price, sl))
     {
      ResetPositionTracking();
      return;
     }

   TrackPosition(ticket, open_price, sl);
   if(g_active_initial_r <= 0.0 || g_active_be_done)
      return;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double current_price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(current_price <= 0.0 || point <= 0.0)
      return;

   const double moved = is_long ? (current_price - g_active_entry)
                                : (g_active_entry - current_price);
   if(moved < g_active_initial_r)
      return;

   const bool improves = is_long ? (sl < g_active_entry - point * 0.5)
                                 : (sl > g_active_entry + point * 0.5);
   if(improves && QM_TM_MoveSL(ticket, NormalizeDouble(g_active_entry, _Digits), "news_rev_breakeven_1r"))
      g_active_be_done = true;
  }

// Trade Close. The card's discretionary close is the cash-session time exit.
bool Strategy_ExitSignal()
  {
   const int now_minute = MinuteOfDay(TimeCurrent());
   if(now_minute < SessionEndMinute())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   return SelectOurPosition(ticket, ptype, open_price, sl);
  }

// News Filter Hook (callable for P8/P9 news-impact phases). This EA has no
// custom event logic beyond the central framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10935_grimes-news-rev\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
