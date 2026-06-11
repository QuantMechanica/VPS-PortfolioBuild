#property strict
#property version   "5.0"
#property description "QM5_9919 ForexFactory HOLO H1 Open Fade M5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9919;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period                  = 14;
input double strategy_through_atr_mult            = 0.20;
input int    strategy_retest_window_bars          = 12;
input double strategy_signal_extreme_atr_max      = 1.50;
input int    strategy_min_completed_h1_bars       = 3;
input int    strategy_skip_day_open_minutes       = 90;
input int    strategy_adr_period_days             = 14;
input double strategy_daily_range_adr_max         = 1.30;
input int    strategy_fixed_stop_pips             = 15;
input double strategy_atr_stop_mult               = 1.20;
input double strategy_atr_stop_cap_mult           = 2.20;
input double strategy_tp_rr                       = 1.20;
input int    strategy_tp_cap_pips                 = 15;
input int    strategy_be_trigger_pips             = 5;
input int    strategy_be_buffer_pips              = 1;
input int    strategy_time_stop_bars              = 24;
input int    strategy_session_close_hour_broker   = 22;
input int    strategy_session_close_min_broker    = 0;

struct HoloLevels
  {
   bool   ok;
   double highest_open;
   double lowest_open;
   int    completed_h1_bars;
  };

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool HasOurOpenPosition()
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
      return true;
     }
   return false;
  }

bool LoadCurrentDayH1OpenLevels(HoloLevels &levels)
  {
   levels.ok = false;
   levels.highest_open = 0.0;
   levels.lowest_open = 0.0;
   levels.completed_h1_bars = 0;

   MqlRates h1_rates[];
   ArraySetAsSeries(h1_rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, 30, h1_rates); // perf-allowed: bounded current-day H1-open structural read inside framework QM_IsNewBar-gated EntrySignal.
   if(copied <= 0)
      return false;

   const int today = DayKey(TimeCurrent());
   double hi_open = -DBL_MAX;
   double lo_open = DBL_MAX;
   int count = 0;

   for(int i = 0; i < copied; ++i)
     {
      if(h1_rates[i].time <= 0 || DayKey(h1_rates[i].time) != today)
         continue;
      if(h1_rates[i].open <= 0.0)
         return false;

      hi_open = MathMax(hi_open, h1_rates[i].open);
      lo_open = MathMin(lo_open, h1_rates[i].open);
      count++;
     }

   if(count < strategy_min_completed_h1_bars || hi_open <= 0.0 || lo_open <= 0.0)
      return false;

   levels.ok = true;
   levels.highest_open = hi_open;
   levels.lowest_open = lo_open;
   levels.completed_h1_bars = count;
   return true;
  }

bool DailyRangeAllowsTrade()
  {
   if(strategy_adr_period_days <= 0)
      return true;

   MqlRates d1_rates[];
   ArraySetAsSeries(d1_rates, true);
   const int needed = strategy_adr_period_days + 1;
   if(CopyRates(_Symbol, PERIOD_D1, 0, needed, d1_rates) != needed) // perf-allowed: bounded ADR/current-day range structural read behind NoTradeFilter.
      return false;

   const double current_range = d1_rates[0].high - d1_rates[0].low;
   if(current_range <= 0.0)
      return true;

   double adr_sum = 0.0;
   int adr_count = 0;
   for(int i = 1; i < needed; ++i)
     {
      const double day_range = d1_rates[i].high - d1_rates[i].low;
      if(day_range <= 0.0)
         continue;
      adr_sum += day_range;
      adr_count++;
     }

   if(adr_count <= 0)
      return false;

   const double adr = adr_sum / adr_count;
   if(adr <= 0.0)
      return false;

   return (current_range <= strategy_daily_range_adr_max * adr);
  }

double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

bool IsXau()
  {
   return (StringFind(_Symbol, "XAU") >= 0);
  }

double InitialStopDistance(const double atr_m5)
  {
   if(atr_m5 <= 0.0)
      return 0.0;

   double stop_dist = strategy_atr_stop_mult * atr_m5;
   if(!IsXau())
     {
      const double fixed_dist = PipDistance(strategy_fixed_stop_pips);
      if(fixed_dist <= 0.0)
         return 0.0;
      stop_dist = MathMax(fixed_dist, stop_dist);
     }

   const double cap_dist = strategy_atr_stop_cap_mult * atr_m5;
   if(cap_dist > 0.0)
      stop_dist = MathMin(stop_dist, cap_dist);

   return stop_dist;
  }

double TakeProfitDistance(const double risk_dist)
  {
   const double pip_cap = PipDistance(strategy_tp_cap_pips);
   if(risk_dist <= 0.0 || pip_cap <= 0.0)
      return 0.0;
   return MathMin(strategy_tp_rr * risk_dist, pip_cap);
  }

bool RecentThroughAbove(const double level, const double threshold)
  {
   MqlRates m5_rates[];
   ArraySetAsSeries(m5_rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 2, strategy_retest_window_bars, m5_rates); // perf-allowed: bounded 12-bar HOLO through-state scan inside framework QM_IsNewBar-gated EntrySignal.
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      if(DayKey(m5_rates[i].time) != DayKey(TimeCurrent()))
         continue;
      if(m5_rates[i].high >= level + threshold)
         return true;
     }
   return false;
  }

bool RecentThroughBelow(const double level, const double threshold)
  {
   MqlRates m5_rates[];
   ArraySetAsSeries(m5_rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 2, strategy_retest_window_bars, m5_rates); // perf-allowed: bounded 12-bar HOLO through-state scan inside framework QM_IsNewBar-gated EntrySignal.
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      if(DayKey(m5_rates[i].time) != DayKey(TimeCurrent()))
         continue;
      if(m5_rates[i].low <= level - threshold)
         return true;
     }
   return false;
  }

bool LoadRecentM5(MqlRates &signal_bar, MqlRates &prior_bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 2, rates) != 2) // perf-allowed: two closed M5 bars for return-close confirmation.
      return false;
   signal_bar = rates[0];
   prior_bar = rates[1];
   return (signal_bar.close > 0.0 && prior_bar.close > 0.0);
  }

bool FillShortRequest(QM_EntryRequest &req, const double level, const double atr_m5)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_dist = InitialStopDistance(atr_m5);
   if(entry <= 0.0 || stop_dist <= 0.0)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, entry + stop_dist);
   const double risk_dist = sl - entry;
   const double tp_dist = TakeProfitDistance(risk_dist);
   if(sl <= entry || tp_dist <= 0.0)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, entry - tp_dist);
   req.reason = "FF_HOLO_H1_OPEN_FADE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.tp > 0.0 && req.tp < entry && level > 0.0);
  }

bool FillLongRequest(QM_EntryRequest &req, const double level, const double atr_m5)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double stop_dist = InitialStopDistance(atr_m5);
   if(entry <= 0.0 || stop_dist <= 0.0)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, entry - stop_dist);
   const double risk_dist = entry - sl;
   const double tp_dist = TakeProfitDistance(risk_dist);
   if(sl <= 0.0 || sl >= entry || tp_dist <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist);
   req.reason = "FF_HOLO_H1_OPEN_FADE_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.tp > entry && level > 0.0);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return true;

   const datetime broker_now = TimeCurrent();
   if(MinuteOfDay(broker_now) < strategy_skip_day_open_minutes)
      return true;

   const int session_close = strategy_session_close_hour_broker * 60 + strategy_session_close_min_broker;
   if(session_close > 0 && MinuteOfDay(broker_now) >= session_close && !HasOurOpenPosition())
      return true;

   if(!DailyRangeAllowsTrade())
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOurOpenPosition())
      return false;

   HoloLevels levels;
   if(!LoadCurrentDayH1OpenLevels(levels))
      return false;

   MqlRates signal_bar;
   MqlRates prior_bar;
   if(!LoadRecentM5(signal_bar, prior_bar))
      return false;
   if(DayKey(signal_bar.time) != DayKey(TimeCurrent()))
      return false;

   const double atr_m5 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr_m5 <= 0.0)
      return false;

   const double through_threshold = strategy_through_atr_mult * atr_m5;
   const double signal_extreme_max = strategy_signal_extreme_atr_max * atr_m5;

   if(signal_bar.close < levels.highest_open &&
      prior_bar.close >= levels.highest_open &&
      signal_bar.high <= levels.highest_open + signal_extreme_max &&
      RecentThroughAbove(levels.highest_open, through_threshold))
      return FillShortRequest(req, levels.highest_open, atr_m5);

   if(signal_bar.close > levels.lowest_open &&
      prior_bar.close <= levels.lowest_open &&
      signal_bar.low >= levels.lowest_open - signal_extreme_max &&
      RecentThroughBelow(levels.lowest_open, through_threshold))
      return FillLongRequest(req, levels.lowest_open, atr_m5);

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, strategy_be_buffer_pips);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int session_close = strategy_session_close_hour_broker * 60 + strategy_session_close_min_broker;
   const bool after_session_close = (session_close > 0 && MinuteOfDay(TimeCurrent()) >= session_close);
   const int max_hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_M5);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(after_session_close)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && max_hold_seconds > 0 && TimeCurrent() - opened_at >= max_hold_seconds)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
