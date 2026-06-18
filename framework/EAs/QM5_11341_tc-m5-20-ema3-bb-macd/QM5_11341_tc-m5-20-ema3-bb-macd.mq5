#property strict
#property version   "5.0"
#property description "QM5_11341 tc-m5-20-ema3-bb-macd — EMA3 vs Bollinger midband cross with MACD zero-line state (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11341 tc-m5-20-ema3-bb-macd
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #20, page 48.
// Card: artifacts/cards_approved/QM5_11341_tc-m5-20-ema3-bb-macd.md (g0 APPROVED).
//
// Mechanics (closed-bar reads at shift 1/2; one position per magic):
//   Trigger EVENT (the single fresh cross):
//     LONG : EMA(3) crosses ABOVE the Bollinger(period, dev) MIDDLE band.
//     SHORT: EMA(3) crosses BELOW the Bollinger middle band.
//   MACD STATE (confirmation, NOT a second event — see .DWX invariant #4):
//     MACD(12,26,9) main line. MACD is a SIGNED value (can be negative); never
//     reject merely because it is negative.
//     LONG  state valid if EITHER
//       (a) main has crossed up through zero (main[1] > 0 AND main[2] <= 0), OR
//       (b) main is still below zero but APPROACHING it from below: |main|
//           strictly decreasing for `macd_approach_bars` consecutive closed bars
//           while main stays < 0 (rising toward zero).
//     SHORT state is the mirror (cross down through zero, or |main| decreasing
//       while main stays > 0, falling toward zero).
//   Stop / Take : fixed pips (baseline 12), scale-correct via QM_StopFixedPips.
//   Time stop   : close at market after `time_stop_bars` closed M5 bars if
//                 neither SL nor TP hit.
//   Spread guard: fail-OPEN on .DWX zero modeled spread — only a genuinely
//                 wide spread (> spread_cap_points) blocks.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11341;
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
input int    strategy_bb_period         = 20;     // Bollinger Bands period (middle = SMA)
input double strategy_bb_deviation      = 3.0;    // Bollinger deviation (mandatory arg)
input int    strategy_ema_period        = 3;      // fast EMA crossing the BB middle band
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal EMA
input int    strategy_macd_approach_bars = 2;     // |main| must decrease this many bars to count as "approaching zero"
input int    strategy_sl_pips           = 12;     // stop loss in pips (P3 range 10-15)
input int    strategy_tp_pips           = 12;     // take profit in pips (P3 range 10-15)
input int    strategy_time_stop_bars    = 12;     // close after this many closed M5 bars (0 = off)
input int    strategy_spread_cap_points = 20;     // skip only a genuinely wide spread (points)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-OPEN on .DWX zero modeled
// spread — only a genuinely wide spread blocks. Strategy work is on the
// closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double spread = ask - bid;
   // .DWX quotes ask==bid (0 modeled spread): never block on zero/negative.
   // Only a genuinely wide spread (in raw points) blocks.
   if(point > 0.0 && spread > 0.0 && (spread / point) > (double)strategy_spread_cap_points)
      return true;

   return false;
  }

// Helper: MACD-main "approaching zero from below" — |main| strictly decreasing
// for `bars` consecutive closed bars while main stays < 0 (rising toward zero).
// shift 1 is the most recent closed bar.
bool MacdApproachingZeroFromBelow(const int bars)
  {
   if(bars < 1)
      return false;
   // Need readings at shifts 1 .. bars+1 to compare `bars` consecutive deltas.
   double prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                              strategy_macd_signal, bars + 1);
   for(int s = bars; s >= 1; --s)
     {
      const double cur = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                      strategy_macd_signal, s);
      // must stay on the pre-cross side (below zero) and rise toward zero
      if(!(cur < 0.0))
         return false;
      if(!(cur > prev)) // rising toward zero => value increasing (less negative)
         return false;
      prev = cur;
     }
   return true;
  }

// Mirror: MACD-main "approaching zero from above" — main stays > 0 and falls
// toward zero (|main| strictly decreasing) for `bars` consecutive closed bars.
bool MacdApproachingZeroFromAbove(const int bars)
  {
   if(bars < 1)
      return false;
   double prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                              strategy_macd_signal, bars + 1);
   for(int s = bars; s >= 1; --s)
     {
      const double cur = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                      strategy_macd_signal, s);
      if(!(cur > 0.0))
         return false;
      if(!(cur < prev)) // falling toward zero => value decreasing (less positive)
         return false;
      prev = cur;
     }
   return true;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true.
// EVENT = EMA3 vs BB-middle cross; STATE = MACD zero-line confirmation.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger middle band (closed bars). deviation arg is MANDATORY. ---
   const double bb_mid_1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid_2 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(bb_mid_1 <= 0.0 || bb_mid_2 <= 0.0)
      return false;

   // --- EMA(3) at the two most recent closed bars ---
   const double ema_1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;

   // --- Trigger EVENT: fresh EMA3 cross of the BB middle band (one event) ---
   const bool cross_up   = (ema_2 <= bb_mid_2 && ema_1 >  bb_mid_1);
   const bool cross_down = (ema_2 >= bb_mid_2 && ema_1 <  bb_mid_1);
   if(!cross_up && !cross_down)
      return false;

   // --- MACD STATE (signed; negative is fine). Cross OR approach. ---
   const double macd_1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                      strategy_macd_signal, 1);
   const double macd_2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                      strategy_macd_signal, 2);

   QM_OrderType side;
   string reason;
   if(cross_up)
     {
      // LONG: MACD crossed up through zero OR rising toward zero from below.
      const bool macd_cross_up = (macd_2 <= 0.0 && macd_1 > 0.0);
      const bool macd_state    = macd_cross_up || MacdApproachingZeroFromBelow(strategy_macd_approach_bars);
      if(!macd_state)
         return false;
      side   = QM_BUY;
      reason = "ema3_bbmid_cross_up_macd_zero_long";
     }
   else
     {
      // SHORT: MACD crossed down through zero OR falling toward zero from above.
      const bool macd_cross_dn = (macd_2 >= 0.0 && macd_1 < 0.0);
      const bool macd_state    = macd_cross_dn || MacdApproachingZeroFromAbove(strategy_macd_approach_bars);
      if(!macd_state)
         return false;
      side   = QM_SELL;
      reason = "ema3_bbmid_cross_dn_macd_zero_short";
     }

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// No active trade management beyond the fixed pip stop/target + time stop.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: close after `strategy_time_stop_bars` closed M5 bars since the
// position opened. SL/TP are handled by the broker; this is the manual exit.
bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const datetime bar0   = iTime(_Symbol, _Period, 0); // current (forming) bar open
      if(opened <= 0 || bar0 <= 0)
         continue;

      const int period_secs = PeriodSeconds(_Period);
      if(period_secs <= 0)
         continue;

      // Bars elapsed since entry, counted by bar-open timestamps (gapless on .DWX).
      const int bars_held = (int)((bar0 - opened) / period_secs);
      if(bars_held >= strategy_time_stop_bars)
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
