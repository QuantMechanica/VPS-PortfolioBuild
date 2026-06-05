#property strict
#property version   "5.0"
#property description "QM5_10781 TradingView ORB 100 EMA"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10781;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
enum Strategy_ORBSession
  {
   STRATEGY_SESSION_ASIA = 0,
   STRATEGY_SESSION_LONDON = 1,
   STRATEGY_SESSION_NEWYORK = 2
  };

enum Strategy_EntryMode
  {
   STRATEGY_ENTRY_BREAKOUT_CLOSE = 0,
   STRATEGY_ENTRY_RETEST_ONLY = 1,
   STRATEGY_ENTRY_BREAKOUT_PLUS_RETEST = 2
  };

input Strategy_ORBSession strategy_session = STRATEGY_SESSION_LONDON;
input int    strategy_opening_range_minutes = 30;
input int    strategy_ema_period = 100;
input Strategy_EntryMode strategy_entry_mode = STRATEGY_ENTRY_BREAKOUT_CLOSE;
input double strategy_target_rr = 1.0;
input bool   strategy_session_end_flat = true;
input int    strategy_max_spread_points = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

datetime g_orb_session_start = 0;
datetime g_orb_session_end = 0;
bool     g_orb_range_ready = false;
double   g_orb_high = 0.0;
double   g_orb_low = 0.0;
bool     g_orb_break_seen_long = false;
bool     g_orb_break_seen_short = false;
bool     g_orb_retested_long = false;
bool     g_orb_retested_short = false;
bool     g_orb_trade_taken = false;

int Strategy_SessionOpenHour()
  {
   if(strategy_session == STRATEGY_SESSION_ASIA)
      return 0;
   if(strategy_session == STRATEGY_SESSION_NEWYORK)
      return 14;
   return 8;
  }

int Strategy_SessionEndHour()
  {
   if(strategy_session == STRATEGY_SESSION_ASIA)
      return 8;
   if(strategy_session == STRATEGY_SESSION_NEWYORK)
      return 22;
   return 17;
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

void Strategy_SyncSession(const datetime broker_time)
  {
   const datetime day_start = Strategy_DayStart(broker_time);
   datetime session_start = day_start + Strategy_SessionOpenHour() * 3600;
   datetime session_end = day_start + Strategy_SessionEndHour() * 3600;
   if(session_end <= session_start)
      session_end += 86400;

   if(broker_time < session_start)
     {
      session_start -= 86400;
      session_end -= 86400;
     }

   if(session_start != g_orb_session_start)
     {
      g_orb_session_start = session_start;
      g_orb_session_end = session_end;
      g_orb_range_ready = false;
      g_orb_high = 0.0;
      g_orb_low = 0.0;
      g_orb_break_seen_long = false;
      g_orb_break_seen_short = false;
      g_orb_retested_long = false;
      g_orb_retested_short = false;
      g_orb_trade_taken = false;
     }
  }

int Strategy_RangeSeconds()
  {
   if(strategy_opening_range_minutes <= 0)
      return 1800;
   return strategy_opening_range_minutes * 60;
  }

bool Strategy_LoadClosedBars(MqlRates &closed_bar, MqlRates &prior_bar)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, bars); // perf-allowed: Strategy_EntrySignal/Exit use only a 3-bar closed-bar snapshot.
   if(copied < 3)
      return false;
   closed_bar = bars[1];
   prior_bar = bars[2];
   return (closed_bar.time > 0 && prior_bar.time > 0);
  }

bool Strategy_RefreshOpeningRange(const datetime reference_time)
  {
   Strategy_SyncSession(reference_time);
   const datetime range_end = g_orb_session_start + Strategy_RangeSeconds();
   if(reference_time < range_end)
      return false;
   if(g_orb_range_ready)
      return true;

   MqlRates range_bars[];
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, g_orb_session_start, range_end - 1, range_bars); // perf-allowed: opening range is loaded once per session after the framework new-bar gate.
   if(copied <= 0)
      return false;

   double high = -DBL_MAX;
   double low = DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      high = MathMax(high, range_bars[i].high);
      low = MathMin(low, range_bars[i].low);
     }

   if(high <= 0.0 || low <= 0.0 || high <= low)
      return false;

   g_orb_high = high;
   g_orb_low = low;
   g_orb_range_ready = true;
   return true;
  }

bool Strategy_HasOpenPosition()
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

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

// Return TRUE to BLOCK trading this tick. No Trade Filter: time window,
// optional spread cap, and standard framework news handling via the hook below.
bool Strategy_NoTradeFilter()
  {
   Strategy_SyncSession(TimeCurrent());

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_session_end_flat && TimeCurrent() >= g_orb_session_end)
      return true;

   if(TimeCurrent() < g_orb_session_start + Strategy_RangeSeconds())
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(g_orb_trade_taken || Strategy_HasOpenPosition())
      return false;

   MqlRates closed_bar;
   MqlRates prior_bar;
   if(!Strategy_LoadClosedBars(closed_bar, prior_bar))
      return false;

   if(!Strategy_RefreshOpeningRange(closed_bar.time))
      return false;

   if(closed_bar.time < g_orb_session_start + Strategy_RangeSeconds() ||
      closed_bar.time >= g_orb_session_end)
      return false;

   const double ema = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   const bool ema_inside_range = (ema >= g_orb_low && ema <= g_orb_high);
   if(ema_inside_range)
      return false;

   const bool long_allowed = (g_orb_low > ema);
   const bool short_allowed = (g_orb_high < ema);
   const bool long_breakout = (prior_bar.close <= g_orb_high && closed_bar.close > g_orb_high);
   const bool short_breakout = (prior_bar.close >= g_orb_low && closed_bar.close < g_orb_low);

   if(long_breakout)
      g_orb_break_seen_long = true;
   if(short_breakout)
      g_orb_break_seen_short = true;

   if(g_orb_break_seen_long && prior_bar.close > g_orb_high &&
      closed_bar.low <= g_orb_high && closed_bar.close > g_orb_high)
      g_orb_retested_long = true;
   if(g_orb_break_seen_short && prior_bar.close < g_orb_low &&
      closed_bar.high >= g_orb_low && closed_bar.close < g_orb_low)
      g_orb_retested_short = true;

   const bool allow_breakout = (strategy_entry_mode == STRATEGY_ENTRY_BREAKOUT_CLOSE ||
                                strategy_entry_mode == STRATEGY_ENTRY_BREAKOUT_PLUS_RETEST);
   const bool allow_retest = (strategy_entry_mode == STRATEGY_ENTRY_RETEST_ONLY ||
                              strategy_entry_mode == STRATEGY_ENTRY_BREAKOUT_PLUS_RETEST);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || strategy_target_rr <= 0.0)
      return false;

   if(long_allowed && ((allow_breakout && long_breakout) ||
      (allow_retest && g_orb_retested_long && closed_bar.close > g_orb_high)))
     {
      const double entry = ask;
      const double sl = g_orb_low;
      const double risk = entry - sl;
      if(risk <= point)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = Strategy_NormalizePrice(entry + risk * strategy_target_rr);
      req.reason = "ORB100EMA_LONG";
      g_orb_trade_taken = true;
      return true;
     }

   if(short_allowed && ((allow_breakout && short_breakout) ||
      (allow_retest && g_orb_retested_short && closed_bar.close < g_orb_low)))
     {
      const double entry = bid;
      const double sl = g_orb_high;
      const double risk = sl - entry;
      if(risk <= point)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = Strategy_NormalizePrice(entry - risk * strategy_target_rr);
      req.reason = "ORB100EMA_SHORT";
      g_orb_trade_taken = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Source has no trailing, break-even, partial, or add-on management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   Strategy_SyncSession(TimeCurrent());

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(strategy_session_end_flat && TimeCurrent() >= g_orb_session_end)
         return true;

      if(!g_orb_range_ready)
         return false;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ptype == POSITION_TYPE_BUY && bid > 0.0 && bid < g_orb_low)
         return true;
      if(ptype == POSITION_TYPE_SELL && ask > 0.0 && ask > g_orb_high)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
