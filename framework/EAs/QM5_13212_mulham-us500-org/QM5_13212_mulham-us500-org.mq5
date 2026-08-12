#property strict
#property version   "5.0"
#property description "QM5_13212 Mulham US500 Opening-Range-Gap Continuation (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13212 mulham-us500-org — Opening-Range-Gap (ORG) continuation, M15.
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_13212_mulham-us500-org.md
//
// State machine (card "Implementation notes"):
//   WAIT_OPEN -> ORG_SET (+veto/size checks) -> WAIT_RETRACE -> WAIT_CONFIRM ->
//   IN_TRADE/NO_TRADE -> FLAT (22:30) -> RESET (07:00)
//
// Fixed broker-time anchors (card's declared data model, ET+7):
//   23:00 broker = prior RTH close (M15 close price of the 22:45-23:00 bar)
//   16:30 broker = RTH open        (M15 open price of the 16:30-16:45 bar)
//   07:00 broker = daily state reset
// These are structural constants of the card's session mapping, not tunable
// sweep params (unlike the Implementation-notes "Inputs:" list below).
// =============================================================================

enum QM_TpMode
  {
   QM_TP_POST_OPEN_EXTREME = 0,
   QM_TP_ORG_STDEV_1       = 1,
   QM_TP_ORG_STDEV_2       = 2
  };

enum QM_OrgState
  {
   QM_ORG_WAIT_OPEN = 0,
   QM_ORG_WAIT_RETRACE,
   QM_ORG_WAIT_CONFIRM,
   QM_ORG_DONE
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13212;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double    strategy_org_min_frac_daily_atr = 0.25;     // degenerate-gap floor: |ORG| < frac*ATR(14,D1) => skip (card rule 1)
input int       strategy_atr_period_d1          = 14;
input int       strategy_atr_period_m15         = 14;
input double    strategy_displacement_atr_mult  = 1.2;      // confirmation-bar range >= mult*ATR(14,M15) (card rule 4)
input int       strategy_entry_window_end_hhmm  = 1900;     // broker HHMM; window 16:30-this (card rule 6)
input int       strategy_flatten_hhmm           = 2230;     // broker HHMM time flatten (card Exit section)
input double    strategy_sl_buffer_atr_mult     = 0.1;      // SL = retrace extreme +/- mult*ATR(14,M15)
input QM_TpMode strategy_tp_mode                = QM_TP_ORG_STDEV_1;
input bool      strategy_fvg_trigger            = false;    // false=ATR displacement trigger, true=3-bar FVG trigger
input double    strategy_spread_cap_atr_frac    = 0.15;     // spread gate: block only if spread > frac*ATR(14,M15) (self-scaling, never zero-spread)

// ----- Always-on daily anchors (persist across the 07:00 reset) -----------
double     g_prior_close       = 0.0;    // RTH close anchor (23:00 broker)
double     g_prior_rth_high    = 0.0;    // finalized previous RTH session high (veto check)
double     g_prior_rth_low     = 0.0;    // finalized previous RTH session low
double     g_session_high      = -DBL_MAX; // in-progress RTH session accumulator
double     g_session_low       = DBL_MAX;
bool       g_session_has_bar   = false;

// ----- Per-cycle ORG state (cleared at 07:00 reset) ------------------------
QM_OrgState g_org_state         = QM_ORG_WAIT_OPEN;
double      g_org_high          = 0.0;
double      g_org_low           = 0.0;
double      g_org_range         = 0.0;
double      g_org_50            = 0.0;
int         g_gap_dir           = 0;     // +1 gap up, -1 gap down
double      g_retrace_extreme   = 0.0;
double      g_post_open_extreme = 0.0;
bool        g_confirmed_signal  = false;

#define QM_ORG_RTH_WINDOW_START_MIN     990    // 16:30 broker
#define QM_ORG_PRIOR_CLOSE_BAR_OPEN_MIN 1365   // 22:45 bar open => closes 23:00 broker (RTH close anchor)
#define QM_ORG_OPEN_ANCHOR_BAR_OPEN_MIN 990    // 16:30 bar open => closes 16:45 broker (RTH open anchor)
#define QM_ORG_RESET_BAR_OPEN_MIN       405    // 06:45 bar open => closes 07:00 broker (daily reset)

int BrokerMinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int HhmmToMinuteOfDay(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
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

// 3-bar Fair Value Gap check (ICT-style): bullish FVG = Low[1] > High[3];
// bearish FVG = High[1] < Low[3]. Bespoke structural pattern, not covered by
// QM_Signals — bounded to 3 closed bars, O(1) per call.
bool HasFvgInDirection(const bool is_up)
  {
   const double high3 = iHigh(_Symbol, PERIOD_M15, 3); // perf-allowed: bounded 3-bar FVG check (card fvg_trigger variant).
   const double low3  = iLow(_Symbol, PERIOD_M15, 3);  // perf-allowed: see above.
   const double high1 = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed: see above.
   const double low1  = iLow(_Symbol, PERIOD_M15, 1);  // perf-allowed: see above.
   if(high3 <= 0.0 || low3 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;
   if(is_up)
      return (low1 > high3);
   return (high1 < low3);
  }

void ResetOrgState()
  {
   g_org_state         = QM_ORG_WAIT_OPEN;
   g_org_high          = 0.0;
   g_org_low           = 0.0;
   g_org_range         = 0.0;
   g_org_50            = 0.0;
   g_gap_dir           = 0;
   g_retrace_extreme   = 0.0;
   g_post_open_extreme = 0.0;
   g_confirmed_signal  = false;
  }

// Called once per closed M15 bar (framework new-bar gate). Advances the
// always-on RTH anchor tracker and the per-day ORG state machine. Strategy_*
// hooks below only ever READ the cached state this function writes — no
// lookback scans on the per-tick path (Intraday Discipline pattern).
void AdvanceDailyState_OnNewBar()
  {
   const datetime bar_open_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: closed-bar anchor read, O(1) per new M15 bar.
   if(bar_open_time <= 0)
      return;
   const int minute = BrokerMinuteOfDay(bar_open_time);

   const double bar_high  = iHigh(_Symbol, PERIOD_M15, 1);  // perf-allowed: ORG anchor/session tracking, O(1) per bar.
   const double bar_low   = iLow(_Symbol, PERIOD_M15, 1);   // perf-allowed: see above.
   const double bar_open  = iOpen(_Symbol, PERIOD_M15, 1);  // perf-allowed: see above.
   const double bar_close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: see above.
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_open <= 0.0 || bar_close <= 0.0)
      return;

   // Always-on RTH session high/low accumulation (16:30-23:00 broker) — feeds
   // NEXT day's veto check ("open printed beyond prior day's RTH high/low").
   if(minute >= QM_ORG_RTH_WINDOW_START_MIN && minute <= QM_ORG_PRIOR_CLOSE_BAR_OPEN_MIN)
     {
      if(!g_session_has_bar)
        {
         g_session_high = bar_high;
         g_session_low  = bar_low;
         g_session_has_bar = true;
        }
      else
        {
         if(bar_high > g_session_high)
            g_session_high = bar_high;
         if(bar_low < g_session_low)
            g_session_low = bar_low;
        }
     }

   // RTH close anchor (23:00 broker) — always-on, independent of the ORG
   // state machine; feeds TOMORROW's 16:30 gap calc.
   if(minute == QM_ORG_PRIOR_CLOSE_BAR_OPEN_MIN)
     {
      g_prior_close = bar_close;
      if(g_session_has_bar)
        {
         g_prior_rth_high = g_session_high;
         g_prior_rth_low  = g_session_low;
        }
      g_session_high = -DBL_MAX;
      g_session_low  = DBL_MAX;
      g_session_has_bar = false;
     }

   // Daily reset (07:00 broker) — clears only the per-cycle ORG state;
   // g_prior_close / g_prior_rth_high / g_prior_rth_low persist (captured the
   // night before, needed at today's 16:30 open).
   if(minute == QM_ORG_RESET_BAR_OPEN_MIN)
      ResetOrgState();

   // ORG anchor set — 16:30 broker open price of THIS closed bar.
   if(g_org_state == QM_ORG_WAIT_OPEN && minute == QM_ORG_OPEN_ANCHOR_BAR_OPEN_MIN)
     {
      if(g_prior_close <= 0.0)
         return; // no prior-close anchor yet (first day in the backtest window)

      const double today_open = bar_open;
      const double gap = today_open - g_prior_close;
      const int dir = (gap > 0.0) ? 1 : ((gap < 0.0) ? -1 : 0);
      if(dir == 0)
         return; // no gap at all — stay WAIT_OPEN, retry tomorrow

      const double org_high  = MathMax(g_prior_close, today_open);
      const double org_low   = MathMin(g_prior_close, today_open);
      const double org_range = org_high - org_low;

      const double daily_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
      if(daily_atr <= 0.0 || org_range < strategy_org_min_frac_daily_atr * daily_atr)
        {
         g_org_state = QM_ORG_DONE; // degenerate gap (card rule 1)
         return;
        }

      // Veto (card rule 5): open already printed beyond prior day's RTH high/low.
      if(g_prior_rth_high > 0.0 && g_prior_rth_low > 0.0 &&
         (today_open > g_prior_rth_high || today_open < g_prior_rth_low))
        {
         g_org_state = QM_ORG_DONE;
         return;
        }

      g_org_high          = org_high;
      g_org_low            = org_low;
      g_org_range          = org_range;
      g_org_50             = (org_high + org_low) / 2.0;
      g_gap_dir            = dir;
      g_retrace_extreme    = today_open;
      g_post_open_extreme  = today_open;
      g_org_state          = QM_ORG_WAIT_RETRACE;
      return;
     }

   // Retrace / hold-confirmation evaluation — only while ORG is set and the
   // entry window (16:30 .. strategy_entry_window_end_hhmm) is still open.
   if(g_org_state == QM_ORG_WAIT_RETRACE || g_org_state == QM_ORG_WAIT_CONFIRM)
     {
      const int window_end_min = HhmmToMinuteOfDay(strategy_entry_window_end_hhmm);
      if(minute < QM_ORG_OPEN_ANCHOR_BAR_OPEN_MIN)
         return; // stale bar from before today's open (defensive; should not happen)
      if(minute >= window_end_min)
        {
         g_org_state = QM_ORG_DONE; // entry window lapsed (card rule 6)
         return;
        }

      const bool is_up = (g_gap_dir > 0);

      if(is_up)
        {
         if(bar_high > g_post_open_extreme)
            g_post_open_extreme = bar_high;
        }
      else
        {
         if(bar_low < g_post_open_extreme)
            g_post_open_extreme = bar_low;
        }

      bool in_confirm_phase = (g_org_state == QM_ORG_WAIT_CONFIRM);
      if(!in_confirm_phase)
        {
         const bool touched = is_up ? (bar_low < g_org_high) : (bar_high > g_org_low);
         if(touched)
           {
            g_retrace_extreme = is_up ? bar_low : bar_high;
            g_org_state = QM_ORG_WAIT_CONFIRM;
            in_confirm_phase = true;
           }
        }

      if(!in_confirm_phase)
         return;

      g_retrace_extreme = is_up ? MathMin(g_retrace_extreme, bar_low)
                                 : MathMax(g_retrace_extreme, bar_high);

      // Invalidation: full gap fill beyond the far anchor (card Exit section).
      const bool filled = is_up ? (bar_close < g_org_low) : (bar_close > g_org_high);
      if(filled)
        {
         g_org_state = QM_ORG_DONE;
         return;
        }

      const bool closed_in_direction = is_up ? (bar_close > bar_open) : (bar_close < bar_open);
      const bool respects_50 = is_up ? (bar_close > g_org_50) : (bar_close < g_org_50);

      bool trigger_ok;
      if(strategy_fvg_trigger)
         trigger_ok = HasFvgInDirection(is_up);
      else
        {
         const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
         trigger_ok = (atr_m15 > 0.0) && ((bar_high - bar_low) >= strategy_displacement_atr_mult * atr_m15);
        }

      if(closed_in_direction && respects_50 && trigger_ok)
         g_confirmed_signal = true;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true; // zero-PRICE guard only — .DWX quotes ask==bid, never gate on zero spread.
   if(strategy_spread_cap_atr_frac <= 0.0)
      return false;
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
   if(atr_m15 <= 0.0)
      return false;
   const double cap = strategy_spread_cap_atr_frac * atr_m15;
   return (ask > bid && (ask - bid) > cap);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_org_state != QM_ORG_WAIT_CONFIRM || !g_confirmed_signal)
      return false;

   g_confirmed_signal = false; // consume the latch — one setup per day either way
   g_org_state = QM_ORG_DONE;

   const bool is_up = (g_gap_dir > 0);
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
   if(atr_m15 <= 0.0)
      return false;

   const QM_OrderType side = is_up ? QM_BUY : QM_SELL;
   const double sl_buffer = strategy_sl_buffer_atr_mult * atr_m15;
   const double sl_price = QM_StopRulesStopFromDistance(_Symbol, side, g_retrace_extreme, sl_buffer);
   if(sl_price <= 0.0)
      return false;

   double tp_price = 0.0;
   if(strategy_tp_mode == QM_TP_POST_OPEN_EXTREME)
      tp_price = g_post_open_extreme;
   else if(strategy_tp_mode == QM_TP_ORG_STDEV_2)
      tp_price = is_up ? (g_org_high + 2.0 * g_org_range) : (g_org_low - 2.0 * g_org_range);
   else // QM_TP_ORG_STDEV_1 (default, card Implementation notes)
      tp_price = is_up ? (g_org_high + 1.0 * g_org_range) : (g_org_low - 1.0 * g_org_range);
   tp_price = QM_StopRulesNormalizePrice(_Symbol, tp_price);

   const double market_price = is_up ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(market_price <= 0.0)
      return false;
   // Sanity-gate the mechanical formula output before sending: sl/tp must
   // bracket the market price. If they don't, the formula degenerated for
   // this bar — skip rather than send a broken bracket.
   if(is_up && !(sl_price < market_price && tp_price > market_price))
      return false;
   if(!is_up && !(sl_price > market_price && tp_price < market_price))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl_price;
   req.tp = tp_price;
   req.reason = StringFormat("MULHAM_ORG_%s org_range=%.5f gap_dir=%d", is_up ? "LONG" : "SHORT", g_org_range, g_gap_dir);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card: single position, hard stop, static SL/TP — no active management.
   // Exit is either SL/TP or the 22:30 time flatten in Strategy_ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   const int minute = BrokerMinuteOfDay(TimeCurrent());
   if(minute < HhmmToMinuteOfDay(strategy_flatten_hhmm))
      return false;
   return HasOurOpenPosition();
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(2) — card uses the framework blackout as-is
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13212\",\"ea\":\"mulham_us500_org\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (22:30 broker flatten). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_M15))
      return;

   // Advance the ORG anchor / retrace / confirmation cache exactly once per
   // closed M15 bar (Intraday Discipline pattern) before reading it below.
   AdvanceDailyState_OnNewBar();

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
