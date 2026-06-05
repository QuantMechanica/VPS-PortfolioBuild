#property strict
#property version   "5.0"
#property description "QM5_10780 TradingView NY ORB Dynamic System"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10780 — TradingView "NY ORB - Full Dynamic System" (card tv-ny-orb-dyn)
// -----------------------------------------------------------------------------
// New York opening-range breakout. The opening range is built from the NY
// pre-market window (source default 08:30-08:45 NY). After the range completes,
// breakouts in the entry window (default 08:50-12:00 NY) trigger a single
// position per day. All open trades are force-flat at the hard-exit time
// (default 13:25 NY). Stops are ATR(14) capped at the opening-range size; the
// profit target is a fixed R multiple of the stop.
//
// INTRADAY PERFORMANCE NOTE: session state (opening range high/low + session
// VWAP) is advanced ONCE per closed bar (AdvanceState_OnNewBar) using single-
// shift closed-bar reads — O(1) per bar. No per-tick CopyRates, no per-bar
// re-summing of the whole session. The per-tick path (NoTradeFilter / Manage /
// ExitSignal) is O(1). This is the QM5_1044/1046 METATESTER_HUNG-avoidance
// pattern from the Intraday Discipline. Raw closed-bar series reads carry an
// explicit `// perf-allowed` tag because the opening range is bespoke
// structural session math the framework indicator readers do not cover.
//
// Optional ablation axes (second-breakout, confirmation candles, VWAP / SMMA /
// MACD / RSI filters) are implemented as inputs but default OFF for the P2
// baseline (filter_mode=0) so the cleanest breakout is measured first.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10780;
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
// Session windows are expressed in NEW YORK local time (HHMM); the EA converts
// the broker bar time to NY internally (DST-aware) so the windows track the
// US session year-round.
input int    strategy_or_start_hhmm      = 830;     // NY opening-range start (incl.)
input int    strategy_or_end_hhmm        = 845;     // NY opening-range end (excl.)
input int    strategy_entry_start_hhmm   = 850;     // NY entry window start (incl.)
input int    strategy_entry_end_hhmm     = 1200;    // NY entry window end (incl.)
input int    strategy_hard_exit_hhmm     = 1325;    // NY hard flat time
input bool   strategy_second_breakout    = false;   // require break->return->break (ablation)
input int    strategy_confirmation_bars  = 0;       // close N bars pre-break inside range (0/1/2)
input int    strategy_filter_mode        = 0;       // 0 none,1 VWAP,2 +SMMA,3 +MACD+RSI
input int    strategy_rsi_period         = 14;
input double strategy_rsi_overbought     = 70.0;
input double strategy_rsi_oversold       = 30.0;
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input int    strategy_smma_period        = 50;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.0;
input bool   strategy_cap_at_or_range    = true;    // cap ATR stop at OR-range multiple
input double strategy_or_cap_mult        = 1.0;
input double strategy_rr_target          = 2.0;     // fixed R profit target
input int    strategy_max_spread_points  = 0;       // 0 disables non-card spread gate

// -----------------------------------------------------------------------------
// Cached per-day session state. Advanced exactly once per closed bar by
// AdvanceState_OnNewBar() (reached only after the framework QM_IsNewBar() gate
// in OnTick). No file-scope timestamp gate of our own — the framework owns the
// new-bar cadence.
// -----------------------------------------------------------------------------
int      g_day_ymd      = -1;     // NY calendar date (YYYYMMDD) of the active day
double   g_or_high      = 0.0;
double   g_or_low       = 0.0;
bool     g_or_active    = false;  // >=1 opening-range bar observed
bool     g_or_complete  = false;  // opening-range window finished
bool     g_traded_today = false;  // one position per symbol per day
double   g_vwap_num     = 0.0;    // sum(typical*vol) since session start
double   g_vwap_den     = 0.0;    // sum(vol) since session start
double   g_vwap         = 0.0;    // session VWAP (anchored at OR start)
int      g_long_phase   = 0;      // second-breakout long: 0 none,1 broke up,2 returned
int      g_short_phase  = 0;      // second-breakout short: 0 none,1 broke down,2 returned

// Convert a broker timestamp to a New-York MqlDateTime (DST-aware). Cheap O(1),
// no series reads.
void BrokerToNyStruct(const datetime broker_time, MqlDateTime &ny_dt)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_off_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   const datetime ny = utc + (ny_off_hours * 3600);
   ZeroMemory(ny_dt);
   TimeToStruct(ny, ny_dt);
  }

// Advance opening-range + VWAP + breakout-phase state by ONE closed bar.
// Called once per new closed bar from Strategy_EntrySignal. O(1) — single-shift
// closed-bar reads only, no loops, no CopyRates.
void AdvanceState_OnNewBar()
  {
   const datetime bar_t = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp for session state
   if(bar_t <= 0)
      return;

   MqlDateTime ny;
   BrokerToNyStruct(bar_t, ny);
   const int ymd  = ny.year * 10000 + ny.mon * 100 + ny.day;
   const int hhmm = ny.hour * 100 + ny.min;

   if(ymd != g_day_ymd)
     {
      g_day_ymd      = ymd;
      g_or_high      = 0.0;
      g_or_low       = 0.0;
      g_or_active    = false;
      g_or_complete  = false;
      g_traded_today = false;
      g_vwap_num     = 0.0;
      g_vwap_den     = 0.0;
      g_vwap         = 0.0;
      g_long_phase   = 0;
      g_short_phase  = 0;
     }
   // Closed-bar OHLCV (single-shift reads) for opening-range + session VWAP.
   const double h1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: closed-bar OR high
   const double l1 = iLow(_Symbol, _Period, 1);    // perf-allowed: closed-bar OR low
   const double c1 = iClose(_Symbol, _Period, 1);  // perf-allowed: closed-bar close
   if(h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return;

   // Opening-range accumulation over the NY OR window.
   if(hhmm >= strategy_or_start_hhmm && hhmm < strategy_or_end_hhmm)
     {
      if(!g_or_active)
        {
         g_or_high   = h1;
         g_or_low    = l1;
         g_or_active = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, h1);
         g_or_low  = MathMin(g_or_low, l1);
        }
     }
   else if(hhmm >= strategy_or_end_hhmm && g_or_active && !g_or_complete)
     {
      g_or_complete = true;
     }

   // Session VWAP anchored at OR start (incremental, one bar's contribution).
   if(hhmm >= strategy_or_start_hhmm)
     {
      const double vol_raw = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: closed-bar volume for session VWAP
      const double vol = (vol_raw > 0.0) ? vol_raw : 1.0;
      const double typical = (h1 + l1 + c1) / 3.0;
      g_vwap_num += typical * vol;
      g_vwap_den += vol;
      if(g_vwap_den > 0.0)
         g_vwap = g_vwap_num / g_vwap_den;
     }

   // Second-breakout sequence (break -> return into range -> re-break). The
   // re-break itself is detected in Strategy_EntrySignal; here we only advance
   // the arming phases. Used only when strategy_second_breakout is enabled.
   if(g_or_complete && g_or_high > g_or_low)
     {
      if(g_long_phase == 0 && c1 > g_or_high)
         g_long_phase = 1;
      else if(g_long_phase == 1 && c1 <= g_or_high)
         g_long_phase = 2;

      if(g_short_phase == 0 && c1 < g_or_low)
         g_short_phase = 1;
      else if(g_short_phase == 1 && c1 >= g_or_low)
         g_short_phase = 2;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-Trade Filter (time / spread / news). Cheap O(1) per-tick checks ONLY.
// Entry session timing is enforced in Strategy_EntrySignal (not here) so that
// returning TRUE never suppresses the per-tick hard-exit in Strategy_ExitSignal.
// News is handled by the framework filter + Strategy_NewsFilterHook.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }
   return false;
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true (one call per closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Advance cached session state by this one closed bar (O(1)).
   AdvanceState_OnNewBar();

   if(!g_or_complete || g_traded_today)
      return false;
   if(!g_or_active || g_or_high <= g_or_low)
      return false;
   // Closed-bar NY time gate for the entry window.
   const datetime bar_t = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp for entry-window gate
   if(bar_t <= 0)
      return false;
   MqlDateTime ny;
   BrokerToNyStruct(bar_t, ny);
   const int hhmm = ny.hour * 100 + ny.min;
   if(hhmm < strategy_entry_start_hhmm || hhmm > strategy_entry_end_hhmm)
      return false;
   // Breakout bar close vs prior bar close (cross + confirmation reads).
   const double c1 = iClose(_Symbol, _Period, 1);  // perf-allowed: breakout bar close
   const double c2 = iClose(_Symbol, _Period, 2);  // perf-allowed: prior bar close (cross / confirmation)
   if(c1 <= 0.0 || c2 <= 0.0)
      return false;

   // Optional confirmation candle(s): close N bars before the breakout must
   // still be inside the opening range.
   if(strategy_confirmation_bars >= 1 && (c2 < g_or_low || c2 > g_or_high))
      return false;
   if(strategy_confirmation_bars >= 2)
     {
      const double c3 = iClose(_Symbol, _Period, 3); // perf-allowed: 2-bars-back confirmation close
      if(c3 <= 0.0 || c3 < g_or_low || c3 > g_or_high)
         return false;
     }

   bool long_break  = false;
   bool short_break = false;
   if(strategy_second_breakout)
     {
      long_break  = (g_long_phase >= 2 && c1 > g_or_high);
      short_break = (g_short_phase >= 2 && c1 < g_or_low);
     }
   else
     {
      long_break  = (c1 > g_or_high && c2 <= g_or_high);
      short_break = (c1 < g_or_low  && c2 >= g_or_low);
     }
   if(long_break == short_break) // neither, or (impossible) both
      return false;

   // Optional filter stack (ablation axes; baseline filter_mode=0 = none).
   if(strategy_filter_mode >= 1) // VWAP
     {
      if(g_vwap <= 0.0)
         return false;
      if(long_break && c1 <= g_vwap)
         return false;
      if(short_break && c1 >= g_vwap)
         return false;
     }
   if(strategy_filter_mode >= 2) // 50-period SMMA
     {
      const double smma = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_smma_period, 1);
      if(smma <= 0.0)
         return false;
      if(long_break && c1 <= smma)
         return false;
      if(short_break && c1 >= smma)
         return false;
     }
   if(strategy_filter_mode >= 3) // MACD line vs signal + RSI guard
     {
      const double macd_main = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      const double macd_sig  = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      const double rsi       = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
      if(rsi <= 0.0)
         return false;
      if(long_break && (macd_main <= macd_sig || rsi >= strategy_rsi_overbought))
         return false;
      if(short_break && (macd_main >= macd_sig || rsi <= strategy_rsi_oversold))
         return false;
     }

   const QM_OrderType side = long_break ? QM_BUY : QM_SELL;
   const double entry = long_break ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   // Capped-ATR stop distance, floored at the broker stops level.
   double stop_distance = atr * strategy_atr_sl_mult;
   const double or_range = g_or_high - g_or_low;
   if(strategy_cap_at_or_range && strategy_or_cap_mult > 0.0 && or_range > 0.0)
      stop_distance = MathMin(stop_distance, or_range * strategy_or_cap_mult);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax(1, stops_level + 2) * point;
   stop_distance = MathMax(stop_distance, min_stop_distance);

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, stop_distance, 1.0);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0; // market — QM_Entry resolves ask/bid
   req.sl = sl;
   req.tp = tp;
   req.reason = long_break ? "NY_ORB_LONG" : "NY_ORB_SHORT";
   g_traded_today = true; // one shot per day, even if the order is rejected
   return true;
  }

// No trailing / break-even / partial: the card baseline uses a fixed ATR/OR
// stop and a fixed-R target set at entry, with a hard time exit.
void Strategy_ManageOpenPosition()
  {
  }

// Force-flat at the NY hard-exit time. Per-tick so the exit is precise rather
// than waiting for a bar close. O(1).
bool Strategy_ExitSignal()
  {
   MqlDateTime ny;
   BrokerToNyStruct(TimeCurrent(), ny);
   const int hhmm = ny.hour * 100 + ny.min;
   return (hhmm >= strategy_hard_exit_hhmm);
  }

// News-filter hook for the P8 News Impact phase. Defers to the central
// framework filter (QM_NewsAllowsTrade) by default.
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
