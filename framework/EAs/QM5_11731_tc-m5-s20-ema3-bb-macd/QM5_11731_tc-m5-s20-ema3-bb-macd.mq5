#property strict
#property version   "5.0"
#property description "QM5_11731 tc-m5-s20-ema3-bb-macd — EMA(3) x BB(20,3) mid + MACD(12,26,9) zero-window (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11731 tc-m5-s20-ema3-bb-macd
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         Strategy #20, 2013.
// Card: artifacts/cards_approved/QM5_11731_tc-m5-s20-ema3-bb-macd.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trigger EVENT : EMA(3) crosses the BB(20, dev=3) MIDDLE band (SMA20).
//                   LONG  -> EMA3 was <= mid at shift 2 and > mid at shift 1.
//                   SHORT -> EMA3 was >= mid at shift 2 and < mid at shift 1.
//                   Exactly ONE cross event per bar — never paired with a second
//                   fresh cross (avoids the two-cross zero-trade trap).
//   Confirm STATE : MACD(12,26,9) MAIN line is aligned with the trigger side of
//                   zero AND has crossed / is approaching zero within the last
//                   `macd_zero_window` closed bars. Per the card: "MACD crossing
//                   zero upward (long) / downward (short) OR approaching zero
//                   from below/above within N bars". This is a STATE/window read
//                   on already-closed bars, NOT a second fresh cross required on
//                   the SAME bar as the EMA/BB cross.
//                     LONG  -> macd_main(1) > 0 (above zero, momentum up) AND a
//                              upward zero-cross occurred within shifts 1..window
//                              OR macd_main is within `macd_zero_tol` below zero
//                              (approaching from below).
//                     SHORT -> mirror.
//   Stop          : fixed `sl_pips` (pip-scale-correct via QM helper).
//   Take profit   : RR multiple `tp_rr` of the stop distance (1:1 default).
//   Manual exit   : opposite EMA3/BB-mid cross before TP/SL (card "Exit on ...
//                   opposite EMA3/BB middle-band cross").
//   Filter        : optional no new entry on Friday.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11731;
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
input int    strategy_ema_period         = 3;     // fast EMA period (trigger leg)
input int    strategy_bb_period          = 20;    // Bollinger period (SMA mid)
input double strategy_bb_deviation       = 3.0;   // Bollinger deviation (sigma)
input int    strategy_macd_fast          = 12;    // MACD fast EMA
input int    strategy_macd_slow          = 26;    // MACD slow EMA
input int    strategy_macd_signal        = 9;     // MACD signal SMA
input int    strategy_macd_zero_window   = 3;     // bars to look back for a MACD zero-cross
input double strategy_macd_zero_tol_pips = 1.0;   // "approaching zero" tolerance, in pips
input int    strategy_sl_pips            = 12;    // stop distance in pips
input double strategy_tp_rr              = 1.0;   // take-profit as RR multiple of the stop
input bool   strategy_no_friday_entry    = true;  // suppress new entries on Friday
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Helper: was there a MACD MAIN zero-cross in the trigger direction within the
// window of closed bars [1 .. window]? "up" = crossed from <=0 to >0.
bool MacdZeroCrossInWindow(const bool up, const int window)
  {
   for(int s = 1; s <= window; ++s)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s);
      const double m_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s + 1);
      if(up && m_prev <= 0.0 && m_now > 0.0)
         return true;
      if(!up && m_prev >= 0.0 && m_now < 0.0)
         return true;
     }
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No new entry on Friday (optional card filter).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)   // Friday
         return false;
     }

   // --- Trigger leg: EMA(3) at the last two closed bars (shift 1, shift 2) ---
   const double ema_1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;

   // --- BB(period, deviation) MIDDLE band (SMA20) at the same two closed bars ---
   const double bb_mid_1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid_2 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(bb_mid_1 <= 0.0 || bb_mid_2 <= 0.0)
      return false;

   // Trigger EVENT: EMA3 crosses the BB middle band. ONE event per bar.
   const bool crossed_up   = (ema_2 <= bb_mid_2 && ema_1 >  bb_mid_1);
   const bool crossed_down = (ema_2 >= bb_mid_2 && ema_1 <  bb_mid_1);
   if(!crossed_up && !crossed_down)
      return false;

   // --- Confirm STATE: MACD MAIN aligned with the trigger side, having crossed
   //     zero within the window OR approaching zero within tolerance. ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double tol = QM_StopRulesPipsToPriceDistance(_Symbol,
                          (int)MathMax(1.0, strategy_macd_zero_tol_pips));

   QM_OrderType side;
   if(crossed_up)
     {
      // LONG: MACD crossed up through zero within window, OR is above zero, OR is
      // approaching zero from below (within tol). Reject clearly-bearish momentum.
      const bool zero_cross = MacdZeroCrossInWindow(true, strategy_macd_zero_window);
      const bool aligned    = (macd_main > -tol); // above zero or approaching from below
      if(!(zero_cross || aligned))
         return false;
      side = QM_BUY;
     }
   else
     {
      // SHORT: mirror.
      const bool zero_cross = MacdZeroCrossInWindow(false, strategy_macd_zero_window);
      const bool aligned    = (macd_main < tol); // below zero or approaching from above
      if(!(zero_cross || aligned))
         return false;
      side = QM_SELL;
     }

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, (int)strategy_sl_pips);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ema3_bbmid_cross_long" : "ema3_bbmid_cross_short";
   return true;
  }

// Fixed SL/TP only — no active management (manual exit is in Strategy_ExitSignal).
void Strategy_ManageOpenPosition()
  {
  }

// Defensive/manual exit: an OPPOSITE EMA3/BB-mid cross before TP/SL.
// One cross event at shift 1, opposite to the currently-held direction.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double ema_1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;

   const double bb_mid_1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid_2 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(bb_mid_1 <= 0.0 || bb_mid_2 <= 0.0)
      return false;

   const bool crossed_up   = (ema_2 <= bb_mid_2 && ema_1 >  bb_mid_1);
   const bool crossed_down = (ema_2 >= bb_mid_2 && ema_1 <  bb_mid_1);
   if(!crossed_up && !crossed_down)
      return false;

   // Determine the held side and exit on the opposite fresh cross.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && crossed_down)
         return true;  // held long, fresh down-cross -> exit
      if(ptype == POSITION_TYPE_SELL && crossed_up)
         return true;  // held short, fresh up-cross -> exit
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
