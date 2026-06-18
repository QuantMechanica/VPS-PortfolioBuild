#property strict
#property version   "5.0"
#property description "QM5_1347 LeBeau Chandelier-Exit trend-follower (H4) — EMA-cross entry + frozen-ATR ratchet trail"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1347 lebeau-chandelier-exit-trail-h4
// -----------------------------------------------------------------------------
// Source: Charles "Chuck" LeBeau & David Lucas, "Computer Analysis of the Futures
//   Market" (1992, ISBN 1-55623-552-4), ch.7 "Chandelier Exit" + FF Trading-Systems
//   community EMA-cross-entry pairing. Card: artifacts/cards_approved/
//   QM5_1347_lebeau-chandelier-exit-trail-h4.md (g0_status APPROVED).
//
// LeBeau Chandelier Exit = ATR trailing stop "hung" from the highest-high since
// entry (long) / lowest-low since entry (short), offset by k*ATR. The defining
// LeBeau primitives implemented here:
//   * ATR(22) is sampled AT THE ENTRY BAR and held CONSTANT for the trade life
//     (frozen-ATR-at-entry variant — no adaptive widening if vol expands).
//   * The stop is RATCHET-ONLY: it rises with new highs (long) but never falls.
//     Because highest-high-since-entry is monotone non-decreasing and ATR_entry
//     is constant, max_over_bars(HH_so_far - k*ATR_entry) == HH_since_entry -
//     k*ATR_entry, so a single closed-form recompute IS the ratchet (no need to
//     persist prior stop across restarts — it is reconstructed deterministically).
//
// Entry (H4 closed bar, EVENT = first EMA(20)/EMA(50) cross):
//   BUY  : EMA50 rising (EMA50[1] > EMA50[3]) STATE; close[1] > EMA50[1] STATE;
//          EMA20 crosses up through EMA50 -> EMA20[2]<=EMA50[2] AND EMA20[1]>EMA50[1]
//          EVENT; ATR(22,H4) > 0.2*ATR(22,D1) vol-floor STATE; flat (1-pos/magic).
//   SELL : mirror.
//
// Exit (Strategy_ExitSignal / ManageOpenPosition, whichever first):
//   * Chandelier ratchet trail (primary): BUY close[1] < HH_since_entry -
//     k*ATR_entry ; SELL close[1] > LL_since_entry + k*ATR_entry.
//   * Counter-trend MA-cross (secondary, FF amendment): BUY EMA20[1] < EMA50[1]
//     AND >= 12 H4 bars in trade (anti-whipsaw); SELL mirror.
//   * Time stop: 60 H4 bars (~10 trading days).
//   * No fixed TP by design (LeBeau: chandelier IS the only profit-side exit).
//
// Initial protective SL set at entry = entry -/+ k*ATR (== initial chandelier),
// distance capped at 5*ATR. The ratchet exit then tightens it via closed bars.
//
// Re-arm (anti same-trade-loop): after a close, suppress new same-direction entry
// until the fast MA re-crosses to the opposite side (EMA20 below EMA50 for a
// suppressed BUY) and then crosses back — a full cross cycle.
//
// .DWX invariants honoured: fail-OPEN spread guard (never block on zero spread);
// no swap gate; broker-time via framework; prior CLOSE referenced (no gap/range);
// single QM_IsNewBar consume per OnTick (entry-gated); ONE cross EVENT, rest
// STATES; all in-EA math (no ML); RISK_FIXED default; one position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1347;
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
input int    strategy_ema_fast          = 20;     // fast trigger MA (H4)
input int    strategy_ema_slow          = 50;     // slow trend filter MA (H4)
input int    strategy_ema_slope_lookback= 3;      // EMA50 slope window (bars)
input int    strategy_atr_period        = 22;     // LeBeau ATR window (H4)
input double strategy_k_chandelier      = 3.0;    // chandelier ATR multiplier (P3 sweep 2.5-3.5)
input double strategy_sl_cap_atr        = 5.0;    // cap on initial-SL distance in ATR units
input double strategy_atr_floor_mult    = 0.2;    // entry vol-floor: ATR(H4) > mult * ATR(D1)
input int    strategy_counter_cross_min_bars = 12; // min bars in trade before counter-cross exit (~2 days)
input int    strategy_time_stop_bars    = 60;     // ~10 trading days time stop
input double strategy_spread_atr_mult   = 0.6;    // fail-OPEN spread guard: skip if spread > mult*ATR

// -----------------------------------------------------------------------------
// File-scope re-arm suppression latches (advanced once per closed bar inside
// Strategy_EntrySignal, which the framework calls only on a new closed bar).
// After a same-direction close, the latch suppresses re-entry until the fast MA
// has crossed to the opposite side of the slow MA and back (full cross cycle).
// -----------------------------------------------------------------------------
bool     g_buy_suppressed  = false;
bool     g_sell_suppressed = false;
bool     g_had_position    = false;  // was a position open at the previous new-bar eval?
datetime g_last_eval_bar   = 0;      // bar-open time the re-arm state was last advanced for

// -----------------------------------------------------------------------------
// Locate this EA's open position (one per magic per symbol). Returns direction,
// entry price and entry time so the chandelier can reconstruct frozen-ATR +
// extreme-since-entry from history.
// -----------------------------------------------------------------------------
bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type,
                    double &open_price, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

// Bars (H4) elapsed since the position opened. open_time -> bar shift.
int BarsSincePositionOpen(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   return (shift < 0) ? 0 : shift;
  }

// ATR(22,H4) frozen at the entry bar. The entry bar is the just-closed signal bar
// at the moment of entry; we sample ATR at that bar's shift each evaluation.
// ATR of a CLOSED bar never changes retroactively, so this is the constant
// "ATR_at_entry" LeBeau specifies. Returns 0.0 on warmup failure.
double FrozenAtrAtEntry(const datetime open_time)
  {
   if(open_time <= 0)
      return 0.0;
   int entry_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(entry_shift < 0)
      entry_shift = 0;
   // The signal bar that triggered the entry is the bar closed just before the
   // entry fill -> shift entry_shift+1 relative to now (entry_shift==0 means the
   // position opened on the still-forming bar; clamp to >=1 closed bar).
   int signal_shift = entry_shift + 1;
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, signal_shift);
   return (atr > 0.0) ? atr : 0.0;
  }

// Highest high (BUY) / lowest low (SELL) over the bars from entry through the last
// closed bar (shift 1). Bounded loop: capped by the time-stop window (<=60 H4
// bars) + a hard safety cap. iHigh/iLow are perf-allowed bespoke structural reads
// (no QM rolling-extreme helper exists) and are gated by the closed-bar entry path.
double HighestHighSinceEntry(const datetime open_time)
  {
   int entry_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(entry_shift < 1)
      entry_shift = 1;
   int cap = strategy_time_stop_bars + 2;
   if(cap < 2)  cap = 2;
   if(cap > 500) cap = 500;
   if(entry_shift > cap)
      entry_shift = cap;
   double hh = -DBL_MAX;
   for(int i = 1; i <= entry_shift; ++i)
     {
      const double h = iHigh(_Symbol, PERIOD_H4, i); // perf-allowed
      if(h > hh) hh = h;
     }
   return (hh > -DBL_MAX) ? hh : 0.0;
  }

double LowestLowSinceEntry(const datetime open_time)
  {
   int entry_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(entry_shift < 1)
      entry_shift = 1;
   int cap = strategy_time_stop_bars + 2;
   if(cap < 2)  cap = 2;
   if(cap > 500) cap = 500;
   if(entry_shift > cap)
      entry_shift = cap;
   double ll = DBL_MAX;
   for(int i = 1; i <= entry_shift; ++i)
     {
      const double l = iLow(_Symbol, PERIOD_H4, i); // perf-allowed
      if(l < ll) ll = l;
     }
   return (ll < DBL_MAX) ? ll : 0.0;
  }

// Advance re-arm suppression latches once per closed bar. A suppressed BUY clears
// only after the fast MA has crossed BELOW the slow MA (opposite side) and then
// back ABOVE it — a full cross cycle that breaks the same-trade loop. SELL mirror.
void AdvanceReArmState()
  {
   const double ema_fast_1 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_fast, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_slow, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_fast, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_slow, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return;

   // BUY suppression clears on a fresh bullish cross (fast was below slow, now
   // above) — this can only happen after fast first dropped below, i.e. the full
   // opposite-then-back cycle the card requires.
   if(g_buy_suppressed)
     {
      const bool bullish_cross = (ema_fast_2 <= ema_slow_2) && (ema_fast_1 > ema_slow_1);
      if(bullish_cross)
         g_buy_suppressed = false;
     }
   if(g_sell_suppressed)
     {
      const bool bearish_cross = (ema_fast_2 >= ema_slow_2) && (ema_fast_1 < ema_slow_1);
      if(bearish_cross)
         g_sell_suppressed = false;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: fail-OPEN wide-spread guard only (H4 24x5, no session
// window per card). Never blocks management of an already-open position.
bool Strategy_NoTradeFilter()
  {
   ulong ticket; ENUM_POSITION_TYPE ptype; double oprice; datetime otime;
   if(GetOurPosition(ticket, ptype, oprice, otime))
      return false; // never block management of an open position

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // fail-OPEN: only block a genuinely wide spread; zero modeled spread on .DWX
   // (ask==bid) must NOT block.
   if(ask > 0.0 && bid > 0.0 && ask > bid &&
      (ask - bid) > strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). The first
// EMA(20)/EMA(50) cross is the single trigger EVENT; slope/close-vs-MA/vol-floor
// are STATES on the same closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Advance re-arm latches once per new closed bar (this fn runs on new bars only).
   const datetime bar_open = (datetime)iTime(_Symbol, PERIOD_H4, 0); // perf-allowed: bar-open key
   ulong ticket; ENUM_POSITION_TYPE ptype; double oprice; datetime otime;
   const bool has_pos = GetOurPosition(ticket, ptype, oprice, otime);
   if(bar_open != g_last_eval_bar)
     {
      g_last_eval_bar = bar_open;
      AdvanceReArmState();
      g_had_position = has_pos;
     }

   if(has_pos)
      return false;

   // --- EMAs (closed bar): shift 1 = last closed, 2 = before, slope ref further back. ---
   const double ef1 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_fast, 1);
   const double es1 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_slow, 1);
   const double ef2 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_fast, 2);
   const double es2 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_slow, 2);
   const int slope_shift = 1 + ((strategy_ema_slope_lookback > 0) ? strategy_ema_slope_lookback : 3);
   const double es_slope_ref = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_slow, slope_shift);
   if(ef1 <= 0.0 || es1 <= 0.0 || ef2 <= 0.0 || es2 <= 0.0 || es_slope_ref <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed (closed-bar close)
   if(close1 <= 0.0)
      return false;

   const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_h4 <= 0.0 || atr_d1 <= 0.0)
      return false;
   // Vol-floor: kill entries on dead-low-vol H4 regimes.
   if(atr_h4 <= strategy_atr_floor_mult * atr_d1)
      return false;

   // ---------------------------- BUY ----------------------------
   const bool slope_up    = (es1 > es_slope_ref);                 // STATE: EMA50 rising
   const bool close_above = (close1 > es1);                       // STATE: close above slow MA
   const bool cross_up    = (ef2 <= es2) && (ef1 > es1);          // EVENT: fast crosses above slow
   if(!g_buy_suppressed && cross_up && slope_up && close_above)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Initial SL == initial chandelier = entry - k*ATR, distance capped at 5*ATR.
      double sl_dist = strategy_k_chandelier * atr_h4;
      const double cap = strategy_sl_cap_atr * atr_h4;
      if(sl_dist > cap)
         sl_dist = cap;
      double sl = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — chandelier is the only profit-side exit
      req.reason = "chandelier_long";
      g_buy_suppressed = true; // re-arm: one entry per cross cycle
      return true;
     }

   // ---------------------------- SELL ---------------------------
   const bool slope_dn    = (es1 < es_slope_ref);                 // STATE: EMA50 falling
   const bool close_below = (close1 < es1);                       // STATE: close below slow MA
   const bool cross_dn    = (ef2 >= es2) && (ef1 < es1);          // EVENT: fast crosses below slow
   if(!g_sell_suppressed && cross_dn && slope_dn && close_below)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl_dist = strategy_k_chandelier * atr_h4;
      const double cap = strategy_sl_cap_atr * atr_h4;
      if(sl_dist > cap)
         sl_dist = cap;
      double sl = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist);
      if(sl <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "chandelier_short";
      g_sell_suppressed = true; // re-arm: one entry per cross cycle
      return true;
     }

   return false;
  }

// Per-tick management: ratchet the broker-side SL up to the chandelier level so
// the protective stop tracks the trailing exit between closed bars. Ratchet-only
// (LeBeau): SL never loosened. Computed from frozen ATR-at-entry + extreme since
// entry. Heavy reads are bounded (<=62 bars) and only run when a position exists.
void Strategy_ManageOpenPosition()
  {
   ulong ticket; ENUM_POSITION_TYPE ptype; double oprice; datetime otime;
   if(!GetOurPosition(ticket, ptype, oprice, otime))
      return;

   const double atr_entry = FrozenAtrAtEntry(otime);
   if(atr_entry <= 0.0)
      return;
   const double k = strategy_k_chandelier;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double hh = HighestHighSinceEntry(otime);
      if(hh <= 0.0)
         return;
      double chand = QM_StopRulesNormalizePrice(_Symbol, hh - k * atr_entry);
      if(chand <= 0.0)
         return;
      const double cur_sl = PositionGetDouble(POSITION_SL);
      // Ratchet-only: raise SL toward chandelier, never lower it; keep below price.
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(chand > cur_sl && (bid <= 0.0 || chand < bid))
         QM_TM_MoveSL(ticket, chand, "chandelier_ratchet_long");
     }
   else // POSITION_TYPE_SELL
     {
      const double ll = LowestLowSinceEntry(otime);
      if(ll <= 0.0)
         return;
      double chand = QM_StopRulesNormalizePrice(_Symbol, ll + k * atr_entry);
      if(chand <= 0.0)
         return;
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      // Ratchet-only: lower SL toward chandelier, never raise it; keep above price.
      if((cur_sl <= 0.0 || chand < cur_sl) && (ask <= 0.0 || chand > ask))
         QM_TM_MoveSL(ticket, chand, "chandelier_ratchet_short");
     }
  }

// Closed-bar discretionary exits (whichever first):
//   * Chandelier trail breach: BUY close[1] < HH_since_entry - k*ATR_entry.
//   * Counter-trend MA cross after >= counter_cross_min_bars in trade.
//   * Time stop at strategy_time_stop_bars H4 bars.
bool Strategy_ExitSignal()
  {
   ulong ticket; ENUM_POSITION_TYPE ptype; double oprice; datetime otime;
   if(!GetOurPosition(ticket, ptype, oprice, otime))
      return false;

   const int bars_since = BarsSincePositionOpen(otime);

   // Time stop.
   if(strategy_time_stop_bars > 0 && bars_since >= strategy_time_stop_bars)
      return true;

   const double atr_entry = FrozenAtrAtEntry(otime);
   const double k = strategy_k_chandelier;
   const double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed (closed-bar close)
   if(close1 <= 0.0)
      return false;

   const double ef1 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_fast, 1);
   const double es1 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_slow, 1);

   if(ptype == POSITION_TYPE_BUY)
     {
      // Chandelier trail breach (frozen ATR + ratcheted highest-high).
      if(atr_entry > 0.0)
        {
         const double hh = HighestHighSinceEntry(otime);
         if(hh > 0.0)
           {
            const double chand = hh - k * atr_entry;
            if(close1 < chand)
               return true;
           }
        }
      // Counter-trend MA cross after the anti-whipsaw dwell.
      if(ef1 > 0.0 && es1 > 0.0 &&
         bars_since >= strategy_counter_cross_min_bars && ef1 < es1)
         return true;
      return false;
     }

   // POSITION_TYPE_SELL
   if(atr_entry > 0.0)
     {
      const double ll = LowestLowSinceEntry(otime);
      if(ll > 0.0)
        {
         const double chand = ll + k * atr_entry;
         if(close1 > chand)
            return true;
        }
     }
   if(ef1 > 0.0 && es1 > 0.0 &&
      bars_since >= strategy_counter_cross_min_bars && ef1 > es1)
      return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1347\",\"strategy\":\"lebeau_chandelier_exit_h4\"}");
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
