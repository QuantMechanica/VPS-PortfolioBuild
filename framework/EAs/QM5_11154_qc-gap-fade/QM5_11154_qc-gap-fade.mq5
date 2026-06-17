#property strict
#property version   "5.0"
#property description "QM5_11154 qc-gap-fade — Opening cash-session gap fade (long-only, M1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11154 qc-gap-fade
// -----------------------------------------------------------------------------
// Source: QuantConnect Boot Camp "Fading The Gap" (Greg Kendall forum mirror).
// Card: artifacts/cards_approved/QM5_11154_qc-gap-fade.md (g0_status APPROVED).
//
// .DWX GAP REALIZATION (read this before judging the logic) -------------------
//   The source defines gap = OpenToday - CloseYesterday on a daily equity
//   (TSLA) that has a true overnight gap. The .DWX index CFDs (SP500/NDX/WS30)
//   are GAPLESS 24h symbols in the MT5 tester: open[0] == close[1], so a raw
//   bar gap is ALWAYS zero and a literal port makes ZERO trades.
//
//   Realization used here: the "overnight gap" is the move across the CASH
//   SESSION boundary — from the PRIOR cash-session CLOSE to the CURRENT
//   cash-session OPEN, both in BROKER time (DXZ NY-Close, GMT+2/+3 DST-aware).
//   On a gapless 24h feed this equals the cumulative price move over the
//   overnight/dead window between the two session-boundary timestamps, which
//   is exactly the economic quantity the source's daily gap captures. This is
//   NOT a raw bar gap and NOT a prior-RANGE comparison; it references the prior
//   cash CLOSE (invariant #6). The realization is flagged in build_result.
//
// Mechanics (long-only, M1, broker-time sessions, closed-bar reads) -----------
//   Session  : cash open  ~16:30 broker, cash close ~23:00 broker (US indices),
//              both as setfile inputs in broker hour:minute (per-symbol/DST).
//   On the cash-OPEN bar:
//     gap   = cash_open_price - prior_cash_close_price.
//     gapStd= rolling std of the last N signed session gaps (own ring buffer;
//             bespoke series the framework readers cannot supply).
//   Entry  : LONG if gapStd >= min noise floor AND |gap| > spread+slip buffer
//            AND gap < -GapStdMultiplier * gapStd  (large gap DOWN, buy rebound).
//   Stop   : entry - StopGapMult * |gap|  (price distance, normalized).
//   Exit   : ExitMinutesAfterOpen min after cash open, OR at cash close,
//            whichever comes first (timed exit; no TP — source has none).
//   Sizing : RISK_FIXED (backtest) / RISK_PERCENT (live), framework-sized.
//   One open position per symbol/magic; no shorting upside gaps (source rule).
//
// Only the 5 Strategy_* hooks + a small per-new-bar state advance + Strategy
// inputs are EA-specific. Everything else is framework wiring and MUST stay.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11154;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Cash-session boundaries in BROKER time (DXZ NY-Close). US index cash open
// 09:30 ET ~= broker 16:30; cash close 16:00 ET ~= broker 23:00. Tune per
// symbol / DST in the setfile.
input int    strategy_cash_open_hour    = 16;     // broker hour of cash open
input int    strategy_cash_open_minute  = 30;     // broker minute of cash open
input int    strategy_cash_close_hour   = 23;     // broker hour of cash close
input int    strategy_cash_close_minute = 0;      // broker minute of cash close
// Gap-fade parameters.
input int    strategy_gap_std_lookback  = 30;     // # recent session gaps for rolling std
input double strategy_gap_std_mult      = 1.5;    // fade trigger: gap < -mult * gapStd
input double strategy_stop_gap_mult     = 1.25;   // stop distance = mult * |gap|
input int    strategy_exit_minutes      = 45;     // close this many min after cash open
input int    strategy_min_noise_points  = 5;      // min gapStd, in points (noise floor)
input int    strategy_slip_buffer_points = 3;     // |gap| must exceed this (points)

// -----------------------------------------------------------------------------
// File-scope cached state (advanced ONCE per closed M1 bar)
// -----------------------------------------------------------------------------
double   g_prior_cash_close   = 0.0;   // close captured at the last cash-close bar
bool     g_have_prior_close   = false; // becomes true after the first cash close

double   g_gaps[];                     // ring buffer of recent signed session gaps
int      g_gap_count          = 0;     // number of valid entries in g_gaps
int      g_gap_head           = 0;     // next write index in the ring

double   g_today_gap          = 0.0;   // gap measured on today's cash-open bar
double   g_today_gap_std      = 0.0;   // rolling std at today's open
bool     g_open_signal_ready  = false; // set on the cash-open bar, consumed by entry
datetime g_signal_bar_time    = 0;     // bar-open time of the cash-open bar (anti-dup)

datetime g_entry_open_time    = 0;     // bar-open broker time the position entered on
bool     g_in_trade_window    = false; // we currently hold a fade position

// -----------------------------------------------------------------------------
// Helpers (bespoke session/gap math — not provided by the framework readers)
// -----------------------------------------------------------------------------

// Minute-of-day (broker time) for a given broker datetime.
int MinuteOfDayBroker(const datetime broker_t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_t, dt);
   return dt.hour * 60 + dt.min;
  }

// Push a signed gap into the ring buffer.
void PushGap(const double gap)
  {
   if(strategy_gap_std_lookback <= 0)
      return;
   if(ArraySize(g_gaps) != strategy_gap_std_lookback)
     {
      ArrayResize(g_gaps, strategy_gap_std_lookback);
      ArrayInitialize(g_gaps, 0.0);
      g_gap_count = 0;
      g_gap_head  = 0;
     }
   g_gaps[g_gap_head] = gap;
   g_gap_head = (g_gap_head + 1) % strategy_gap_std_lookback;
   if(g_gap_count < strategy_gap_std_lookback)
      g_gap_count++;
  }

// Population standard deviation of the buffered gaps.
double GapStd()
  {
   if(g_gap_count < 2)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < g_gap_count; ++i)
      sum += g_gaps[i];
   const double mean = sum / g_gap_count;
   double var = 0.0;
   for(int i = 0; i < g_gap_count; ++i)
     {
      const double d = g_gaps[i] - mean;
      var += d * d;
     }
   var /= g_gap_count;
   return MathSqrt(var);
  }

// Advance cached session state on each new closed M1 bar. Reads the LAST closed
// bar (shift 1). Cheap and O(1)+O(lookback) only when a session gap is formed.
void AdvanceState_OnNewBar()
  {
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1); // closed bar, broker time
   if(bar_open_broker <= 0)
      return;

   const double bar_open_price  = iOpen(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double bar_close_price = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(bar_open_price <= 0.0 || bar_close_price <= 0.0)
      return;

   const int mod = MinuteOfDayBroker(bar_open_broker);
   const int open_mod  = strategy_cash_open_hour  * 60 + strategy_cash_open_minute;
   const int close_mod = strategy_cash_close_hour * 60 + strategy_cash_close_minute;

   // Cash CLOSE bar: latch the prior-session close used as the gap baseline.
   if(mod == close_mod)
     {
      g_prior_cash_close = bar_close_price;
      g_have_prior_close = true;
     }

   // Cash OPEN bar: form the session gap vs the prior cash close.
   if(mod == open_mod && g_have_prior_close)
     {
      // gap across the overnight/dead window: current cash open vs prior close.
      const double gap = bar_open_price - g_prior_cash_close;
      g_today_gap_std    = GapStd();        // std BEFORE adding today's gap
      g_today_gap        = gap;
      g_open_signal_ready = true;
      g_signal_bar_time   = bar_open_broker;
      PushGap(gap);                         // include today's gap for future bars
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing/zero quote

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // .DWX models zero spread — fail OPEN, do not block

   // Only a genuinely wide spread relative to the slip buffer blocks.
   const double cap = (double)strategy_slip_buffer_points * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5.0;
   if(cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Long-only entry. Fires only on the cash-open bar when the gap-down threshold
// is met. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_open_signal_ready)
      return false;
   g_open_signal_ready = false; // consume the per-session signal exactly once

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   // Noise floor: skip if the gap distribution is too tight to be meaningful.
   const double noise_floor = (double)strategy_min_noise_points * point;
   if(g_today_gap_std < noise_floor)
      return false;

   // Skip if the gap itself is within the slip/spread buffer (not tradable).
   const double slip_buffer = (double)strategy_slip_buffer_points * point;
   if(MathAbs(g_today_gap) <= slip_buffer)
      return false;

   // Fade only large gap DOWN (buy the rebound). Source does not short up-gaps.
   if(!(g_today_gap < -strategy_gap_std_mult * g_today_gap_std))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   // Stop = StopGapMult * |gap| below entry (price distance), normalized.
   const double stop_distance = strategy_stop_gap_mult * MathAbs(g_today_gap);
   if(stop_distance <= 0.0)
      return false;
   const double sl = QM_StopRulesNormalizePrice(_Symbol, entry - stop_distance);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no TP — timed exit drives the close
   req.reason = "gap_fade_long";

   g_entry_open_time = g_signal_bar_time;
   g_in_trade_window = true;
   return true;
  }

// No active SL/TP management — fixed stop + timed exit only.
void Strategy_ManageOpenPosition()
  {
  }

// Timed exit: close ExitMinutes after the cash open, or at/after cash close.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_in_trade_window = false;
      return false;
     }
   if(!g_in_trade_window || g_entry_open_time <= 0)
      return false;

   const datetime now_bar = iTime(_Symbol, _Period, 0); // current forming bar open (broker)
   if(now_bar <= 0)
      return false;

   // (a) ExitMinutes after cash open.
   const datetime exit_at = g_entry_open_time + (datetime)strategy_exit_minutes * 60;

   // (b) at/after the cash-close minute-of-day on the SAME or later calendar day.
   const int now_mod   = MinuteOfDayBroker(now_bar);
   const int close_mod = strategy_cash_close_hour * 60 + strategy_cash_close_minute;
   const bool at_close = (now_mod >= close_mod);

   if(now_bar >= exit_at || at_close)
     {
      g_in_trade_window = false;
      return true;
     }
   return false;
  }

// Defer to the central news filter.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!QM_IsNewBar())
      return;

   // FIRST after the new-bar gate: advance cached session/gap state.
   AdvanceState_OnNewBar();

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
