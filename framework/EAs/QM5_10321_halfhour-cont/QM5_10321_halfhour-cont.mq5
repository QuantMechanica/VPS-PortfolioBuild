#property strict
#property version   "5.0"
#property description "QM5_10321 Half-Hour Return Periodicity Continuation (halfhour-cont)"
// Strategy Card: QM5_10321 (halfhour-cont), G0 APPROVED 2026-05-21.
// Source: Heston/Korajczyk/Sadka, "Intraday Patterns in the Cross-Section of
// Stock Returns", SSRN 1107590. Same-slot lagged-return continuation on M30.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — framework skeleton (wiring intact; only the 5
// Strategy_* hooks + strategy inputs are EA-specific).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10321;
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
// Card "Mechanik" defaults. The strategy operates on fixed 30-minute slots; on
// the M30 base timeframe one bar == one slot.
input int    strategy_lag_days              = 1;     // same-slot return lag (previous trading day).
input int    strategy_avg_days              = 5;     // persistence filter: prior-N same-slot average.
input int    strategy_min_history_days      = 10;    // require >= N complete prior same-slot days.
input double strategy_atr_sl_mult           = 0.50;  // emergency stop = mult * ATR(period, M30).
input int    strategy_atr_period            = 14;    // ATR period for the stop.
input int    strategy_session_start_hhmm    = 0;     // broker-time session start (HHMM); 0 = derive from data.
input int    strategy_session_end_hhmm      = 0;     // broker-time session end   (HHMM); 0 = derive from data.
input int    strategy_skip_first_slots      = 1;     // skip first N slots of the session (open momentum).
input int    strategy_skip_last_slots       = 1;     // skip last N slots of the session (close momentum).
input double strategy_spread_cap_pips       = 6.0;   // block genuinely wide spread only (fail-open on 0).

// -----------------------------------------------------------------------------
// File-scope cached signal state. Advanced ONCE per new M30 bar (intraday
// discipline) inside the new-bar gate; the per-tick path only reads it.
// -----------------------------------------------------------------------------
bool     g_signal_ready   = false;   // true when a valid entry was computed for the just-opened bar.
int      g_signal_dir     = 0;       // +1 long / -1 short / 0 none.
datetime g_signal_bar     = 0;       // iTime(0) of the bar this signal belongs to.
datetime g_entry_bar_time = 0;       // iTime(0) recorded when we opened our position (for slot-close exit).

// Maximum number of M30 bars scanned backward when collecting same-slot history.
// A regular index session is <= ~48 M30 bars/day; cap covers >10 trading days
// of same-slot lookback with margin while staying bounded for smoke runtime.
#define QM5_10321_MAX_SCAN_BARS 800

// -----------------------------------------------------------------------------
// Helpers (bounded; called only from the new-bar gate).
// -----------------------------------------------------------------------------

// Broker-time HHMM of a datetime.
int QM5_10321_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

// Day key (year*1000 + day-of-year) to detect a broker-day change.
long QM5_10321_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (long)dt.year * 1000 + (long)dt.day_of_year;
  }

// Per-bar return of a closed M30 bar at the given shift: (close-open)/open.
bool QM5_10321_BarReturn(const int shift, double &out_ret)
  {
   out_ret = 0.0;
   const double o = iOpen(_Symbol, _Period, shift);
   const double c = iClose(_Symbol, _Period, shift);
   if(o <= 0.0 || c <= 0.0)
      return false;
   out_ret = (c - o) / o;
   return true;
  }

// Collect same-time-of-day returns for the prior trading days. Walks backward
// from shift 1, takes at most ONE bar per distinct prior broker-day whose HHMM
// equals target_hhmm, recent-first. Returns the count actually filled.
int QM5_10321_CollectSameSlotReturns(const int target_hhmm,
                                     const int max_days,
                                     double &returns[])
  {
   int filled = 0;
   long last_day = -1;
   const int avail = Bars(_Symbol, _Period) - 1;
   int cap = QM5_10321_MAX_SCAN_BARS;
   if(avail < cap)
      cap = avail;

   for(int shift = 1; shift <= cap && filled < max_days; ++shift)
     {
      const datetime bt = iTime(_Symbol, _Period, shift);
      if(bt <= 0)
         break;
      if(QM5_10321_Hhmm(bt) != target_hhmm)
         continue;

      const long dk = QM5_10321_DayKey(bt);
      if(dk == last_day)
         continue;             // one same-slot bar per prior day only.
      last_day = dk;

      double r = 0.0;
      if(!QM5_10321_BarReturn(shift, r))
         continue;

      returns[filled] = r;
      filled++;
     }
   return filled;
  }

// Derive the first/last slot HHMM of the symbol's regular session from recent
// history when the operator leaves the session inputs at 0. Anchors on the
// first complete prior broker-day and records its min/max traded HHMM.
void QM5_10321_DeriveSession(int &start_hhmm, int &end_hhmm)
  {
   start_hhmm = 2400;
   end_hhmm   = -1;
   long ref_day = -1;
   const int avail = Bars(_Symbol, _Period) - 1;
   int cap = QM5_10321_MAX_SCAN_BARS;
   if(avail < cap)
      cap = avail;

   for(int shift = 1; shift <= cap; ++shift)
     {
      const datetime bt = iTime(_Symbol, _Period, shift);
      if(bt <= 0)
         break;
      const long dk = QM5_10321_DayKey(bt);
      if(ref_day < 0)
        {
         // Skip the latest (possibly partial) day; anchor on the next one.
         ref_day = dk;
         continue;
        }
      if(dk != ref_day)
        {
         if(end_hhmm >= 0)      // one complete prior day already collected.
            break;
         ref_day = dk;
        }
      if(dk != ref_day)
         continue;
      const int hhmm = QM5_10321_Hhmm(bt);
      if(hhmm < start_hhmm)
         start_hhmm = hhmm;
      if(hhmm > end_hhmm)
         end_hhmm = hhmm;
     }

   if(end_hhmm < 0)             // no usable history yet.
     {
      start_hhmm = 0;
      end_hhmm   = 2330;
     }
  }

// Advance the cached entry signal for the bar that just opened (bar 0). Reads
// only closed bars (shift >= 1). Sets g_signal_* for the per-tick entry path.
void QM5_10321_AdvanceSignal()
  {
   g_signal_ready = false;
   g_signal_dir   = 0;
   g_signal_bar   = iTime(_Symbol, _Period, 0);

   if(g_signal_bar <= 0)
      return;

   // Slot we are entering = the just-opened bar's time-of-day.
   const int slot_hhmm = QM5_10321_Hhmm(g_signal_bar);

   // Resolve session bounds (operator override or derived from data).
   int sess_start = strategy_session_start_hhmm;
   int sess_end   = strategy_session_end_hhmm;
   if(sess_start <= 0 && sess_end <= 0)
      QM5_10321_DeriveSession(sess_start, sess_end);

   // Skip the first / last 30-minute slots of the session (open/close momentum).
   const int slot_min   = (slot_hhmm / 100) * 60 + (slot_hhmm % 100);
   const int start_min  = (sess_start / 100) * 60 + (sess_start % 100) + strategy_skip_first_slots * 30;
   const int end_min    = (sess_end / 100) * 60 + (sess_end % 100) - strategy_skip_last_slots * 30;
   if(slot_min < start_min || slot_min > end_min)
      return;                 // outside the eligible slot window.

   // Collect same-slot returns over the prior trading days (recent-first).
   int need = strategy_min_history_days;
   if(strategy_lag_days > need)
      need = strategy_lag_days;
   if(strategy_avg_days > need)
      need = strategy_avg_days;
   if(need < 1)
      return;

   double rets[];
   ArrayResize(rets, need);
   const int got = QM5_10321_CollectSameSlotReturns(slot_hhmm, need, rets);

   // Require a complete same-slot history of at least min_history_days.
   if(got < strategy_min_history_days)
      return;
   if(strategy_lag_days < 1 || got < strategy_lag_days)
      return;
   if(strategy_avg_days < 1 || got < strategy_avg_days)
      return;

   // Lagged same-slot return (previous trading day's same slot).
   const double lag_ret = rets[strategy_lag_days - 1];

   // Persistence filter: average same-slot return over the prior N days.
   double sum = 0.0;
   for(int i = 0; i < strategy_avg_days; ++i)
      sum += rets[i];
   const double avg_ret = sum / (double)strategy_avg_days;

   // Card entry rules:
   //   Long  if lag_ret > 0 and avg_ret >= 0.
   //   Short if lag_ret < 0 and avg_ret <= 0.
   if(lag_ret > 0.0 && avg_ret >= 0.0)
     {
      g_signal_dir   = +1;
      g_signal_ready = true;
     }
   else if(lag_ret < 0.0 && avg_ret <= 0.0)
     {
      g_signal_dir   = -1;
      g_signal_ready = true;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick block: fail-open spread guard for the .DWX tester.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;                   // genuinely unpriced — block.

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only block a genuinely WIDE spread; never block on zero (.DWX quotes ask==bid).
   if(cap > 0.0 && ask > bid && (ask - bid) > cap)
      return true;

   return false;
  }

// Populate `req` with the entry order. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Only one position per magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Signal must have been computed for THIS just-opened bar.
   if(!g_signal_ready || g_signal_dir == 0)
      return false;
   if(g_signal_bar != iTime(_Symbol, _Period, 0))
      return false;

   const QM_OrderType side = (g_signal_dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Emergency stop = mult * ATR(period, M30). No take-profit: the position is
   // closed at the end of the same 30-minute slot (Strategy_ExitSignal).
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;            // framework fills market price at send.
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = (side == QM_BUY) ? "QM5_10321_HHCONT_LONG" : "QM5_10321_HHCONT_SHORT";

   // Record the entry bar so the slot-close exit fires on the next M30 bar.
   g_entry_bar_time = iTime(_Symbol, _Period, 0);
   return true;
  }

// No trailing / partial / break-even: slot-bounded hold.
void Strategy_ManageOpenPosition()
  {
  }

// Slot-close exit: close at the end of the same 30-minute slot. On M30 the
// slot ends when a new bar opens, so close any open position whose entry bar
// is no longer the current bar (max hold = one M30 bar). No overnight holding.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime cur_bar = iTime(_Symbol, _Period, 0);
   if(cur_bar <= 0)
      return false;

   // Open position + the bar has advanced past the entry bar => slot closed.
   if(g_entry_bar_time > 0 && cur_bar != g_entry_bar_time)
     {
      g_entry_bar_time = 0;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10321_halfhour_cont\"}");
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

   // Intraday discipline: advance the cached entry signal once per closed bar.
   QM5_10321_AdvanceSignal();

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
