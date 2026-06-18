#property strict
#property version   "5.0"
#property description "QM5_11550 carter-t-m5-ema50-100-macd-partial — EMA(50/100) trend + MACD trigger, partial exit + breakeven (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11550 carter-t-m5-ema50-100-macd-partial
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #9, self-published 2014.
// Card: artifacts/cards_approved/QM5_11550_carter-t-m5-ema50-100-macd-partial.md
//       (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; both directions):
//   Trend STATE   : close[1] above BOTH EMA(50) and EMA(100)        -> long bias
//                   close[1] below BOTH EMA(50) and EMA(100)        -> short bias
//   Offset STATE  : |close[1] - EMA(50)[1]| >= breakout_pips (10p)  in trend dir
//   Trigger EVENT : MACD main crossed from negative to positive (long) within
//                   the last macd_lookback (5) closed bars; pos->neg for short.
//                   ONE trigger event, evaluated over a lookback window — this
//                   avoids the two-cross-same-bar zero-trade trap (the EMA stack
//                   and the offset are STATES, the MACD cross is the single EVENT).
//   Stop          : structural 5-bar low (long) / high (short), but the stop
//                   DISTANCE is capped at sl_cap_pips (30p).
//   Take profit   : none placed at broker; managed exit below.
//   Partial exit  : at +partial_rr (2.0) R unrealized, close partial_fraction
//                   (50%) of the position via QM_TM_PartialClose, then move the
//                   remainder's SL to break-even (entry) via QM_TM_MoveSL.
//   Remainder exit: close manually when price breaks the EMA(50) by
//                   exit_break_pips (10p) against the trade (below for long).
//   No-Friday-entry: skip new entries on Friday (broker time).
//   Spread guard  : skip only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11550;
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
input int    strategy_ema_fast_period   = 50;     // trend fast EMA
input int    strategy_ema_slow_period   = 100;    // trend slow EMA
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal SMA
input int    strategy_macd_lookback     = 5;      // MACD cross within last N closed bars
input int    strategy_breakout_pips     = 10;     // min |close - EMA(50)| offset in trend dir
input int    strategy_sl_struct_bars    = 5;      // structural stop lookback (bars)
input int    strategy_sl_cap_pips       = 30;     // max stop distance (pips)
input double strategy_partial_rr        = 2.0;    // partial-exit trigger in R-multiples
input double strategy_partial_fraction  = 0.5;    // fraction of position closed at the partial
input int    strategy_exit_break_pips   = 10;     // EMA(50) break (pips) closes remainder
input bool   strategy_no_friday_entry   = true;   // block new entries on Friday
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope state for partial-exit + breakeven management (one position/magic).
// Tracked by ticket so a fresh position resets cleanly. Re-derived from the live
// position when a fill is seen without prior bookkeeping (e.g. after restart).
// -----------------------------------------------------------------------------
ulong  g_managed_ticket   = 0;     // ticket the bookkeeping below refers to
double g_entry_price      = 0.0;   // recorded entry (price open)
double g_initial_risk     = 0.0;   // |entry - initial SL| in price terms (= 1R)
bool   g_is_buy           = false; // direction of the managed position
bool   g_partial_done     = false; // partial already taken on this ticket

void ResetManagedState()
  {
   g_managed_ticket = 0;
   g_entry_price    = 0.0;
   g_initial_risk   = 0.0;
   g_is_buy         = false;
   g_partial_done   = false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (regime/signal work is on the
// closed-bar path). Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop-distance reference for the spread cap (capped structural stop).
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * cap_distance)
      return true;

   return false;
  }

// Returns true and fills `req` if a fresh entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No-Friday-entry filter (broker time).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Trend STATE: EMA(50)/EMA(100) stack relative to close[1] ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = QM_EMA(_Symbol, _Period, 1, 1); // EMA(1)=close[1], scale-correct closed-bar close
   if(close1 <= 0.0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(offset <= 0.0)
      return false;

   const bool long_state  = (close1 > ema_fast && close1 > ema_slow &&
                             (close1 - ema_fast) >= offset);
   const bool short_state = (close1 < ema_fast && close1 < ema_slow &&
                             (ema_fast - close1) >= offset);
   if(!long_state && !short_state)
      return false;

   // --- Trigger EVENT: MACD main crossed in the trend direction within the
   //     last macd_lookback closed bars. ONE crossover event over a window —
   //     the EMA stack/offset are STATES, not a second event on the same bar. ---
   bool macd_trigger = false;
   const int last_shift = strategy_macd_lookback; // shifts 1..lookback (each cross uses shift & shift+1)
   for(int s = 1; s <= last_shift; ++s)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s);
      const double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s + 1);
      if(long_state && m_prev < 0.0 && m_now > 0.0) { macd_trigger = true; break; }
      if(short_state && m_prev > 0.0 && m_now < 0.0) { macd_trigger = true; break; }
     }
   if(!macd_trigger)
      return false;

   // --- Direction + entry price ---
   const QM_OrderType side = long_state ? QM_BUY : QM_SELL;
   const double entry = long_state ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: structural N-bar low/high, but stop DISTANCE capped at sl_cap. ---
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_struct_bars);
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(sl <= 0.0 || cap_distance <= 0.0)
      return false;

   double sl_distance = long_state ? (entry - sl) : (sl - entry);
   if(sl_distance <= 0.0)
      return false; // degenerate structural stop — skip
   if(sl_distance > cap_distance)
     {
      // Tighten the stop to the cap (keeps stop on the protective side).
      sl = long_state ? (entry - cap_distance) : (entry + cap_distance);
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      sl_distance = cap_distance;
     }

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // managed exit (partial + EMA break), no fixed TP
   req.reason = long_state ? "carter_macd_long" : "carter_macd_short";
   return true;
  }

// Per-tick management: take the +partial_rr partial, then move the remainder to
// break-even. Cheap O(1) reads against file-scope bookkeeping.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      ResetManagedState();
      return;
     }

   // Locate this EA's position.
   ulong ticket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      break;
     }
   if(ticket == 0)
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy   = (ptype == POSITION_TYPE_BUY);
   const double open_p = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl     = PositionGetDouble(POSITION_SL);

   // (Re)initialise bookkeeping if this is a new/unknown ticket.
   if(g_managed_ticket != ticket)
     {
      g_managed_ticket = ticket;
      g_entry_price    = open_p;
      g_is_buy         = is_buy;
      g_partial_done   = false;
      g_initial_risk   = is_buy ? (open_p - sl) : (sl - open_p);
     }
   if(g_initial_risk <= 0.0)
      return; // cannot compute R without a valid initial stop

   if(g_partial_done)
      return; // remainder rides on break-even SL + EMA-break exit (Strategy_ExitSignal)

   // Current favourable excursion in price terms.
   const double mkt = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                             : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(mkt <= 0.0)
      return;
   const double moved = is_buy ? (mkt - g_entry_price) : (g_entry_price - mkt);

   if(moved < strategy_partial_rr * g_initial_risk)
      return; // not yet at +partial_rr R

   // Take the partial, then move remainder SL to break-even (entry).
   const double cur_lots   = PositionGetDouble(POSITION_VOLUME);
   const double close_lots = QM_TM_NormalizeVolume(_Symbol, cur_lots * strategy_partial_fraction);
   if(close_lots > 0.0 && close_lots < cur_lots)
      QM_TM_PartialClose(ticket, close_lots, QM_EXIT_STRATEGY);

   const double be_sl = QM_TM_NormalizePrice(_Symbol, g_entry_price);
   if(be_sl > 0.0)
      QM_TM_MoveSL(ticket, be_sl, "partial_then_breakeven");

   g_partial_done = true;
  }

// Remainder exit: price breaks the EMA(50) by exit_break_pips against the trade.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   if(ema_fast <= 0.0)
      return false;
   const double close1 = QM_EMA(_Symbol, _Period, 1, 1); // close[1]
   if(close1 <= 0.0)
      return false;

   const double brk = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_exit_break_pips);
   if(brk <= 0.0)
      return false;

   // Direction from the managed position (fall back to live position type).
   bool is_buy = g_is_buy;
   if(g_managed_ticket == 0)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
         break;
        }
     }

   // Long: close if close[1] breaks below EMA(50) by brk. Short: mirror above.
   if(is_buy)
      return (close1 < (ema_fast - brk));
   return (close1 > (ema_fast + brk));
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      ResetManagedState();
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
