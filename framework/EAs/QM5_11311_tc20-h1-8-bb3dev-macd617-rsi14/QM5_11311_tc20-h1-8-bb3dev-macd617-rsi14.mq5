#property strict
#property version   "5.0"
#property description "QM5_11311 tc20-h1-8-bb3dev-macd617-rsi14 — EMA(3) x BB(20,3) middle, MACD(6,17,1) + RSI(14) states (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11311 tc20-h1-8-bb3dev-macd617-rsi14
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Forex Trading Strategy #8.
// Card: artifacts/cards_approved/QM5_11311_tc20-h1-8-bb3dev-macd617-rsi14.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, all on the same trigger bar):
//   Trigger EVENT (ONE event): EMA(3) crosses the BB(20,3) middle band (SMA20).
//                 LONG  : EMA3[2] <= mid[2] AND EMA3[1] > mid[1].
//                 SHORT : EMA3[2] >= mid[2] AND EMA3[1] < mid[1].
//   STATE 1 (MACD sign): MACD(6,17,1) main > 0 (long) / < 0 (short). MACD can be
//                        negative — this is a level/sign STATE, not a cross event.
//   STATE 2 (RSI level): RSI(14) > 50 (long) / < 50 (short).
//   Stop : nearest of swing-structure (lookback) or the BB(20,3) band on the
//          entry side, whichever is CLOSER to entry; ATR(14)*sl_atr_mult fallback
//          if neither yields a valid stop on the correct side.
//   Take : BB(20,3) upper band (long) / lower band (short) at the trigger bar;
//          fixed tp_fallback_pips if the band is not beyond entry by then.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-OPEN on .DWX zero modeled spread).
//
// 3-sigma Bollinger Bands (wider than standard 2-sigma) per the card — the
// `deviation` arg to QM_BB_* is MANDATORY.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11311;
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
input int    strategy_ema_period         = 3;      // fast EMA crossing the BB middle
input int    strategy_bb_period          = 20;     // Bollinger period (middle = SMA20)
input double strategy_bb_deviation       = 3.0;    // 3-sigma BB per the card (non-standard)
input int    strategy_macd_fast          = 6;      // MACD fast EMA (non-standard)
input int    strategy_macd_slow          = 17;     // MACD slow EMA (non-standard)
input int    strategy_macd_signal        = 1;      // MACD signal period (non-standard)
input int    strategy_rsi_period         = 14;     // RSI period
input double strategy_rsi_level          = 50.0;   // RSI midline state threshold
input int    strategy_struct_lookback    = 10;     // swing-structure lookback for the stop
input int    strategy_atr_period         = 14;     // ATR period (stop fallback)
input double strategy_sl_atr_mult        = 1.5;    // ATR fallback stop = mult * ATR
input int    strategy_tp_fallback_pips   = 50;     // fixed TP if BB band not beyond entry
input double strategy_spread_pct_of_stop = 20.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- BB(20,3) middle (SMA20) at the trigger bar and the bar before it ---
   const double mid_1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double mid_2 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(mid_1 <= 0.0 || mid_2 <= 0.0)
      return false;

   // --- EMA(3) at the trigger bar and the bar before it ---
   const double ema_1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;

   // --- Trigger EVENT: EMA(3) crosses the BB middle band (one event/bar) ---
   const bool cross_up   = (ema_2 <= mid_2 && ema_1 > mid_1);
   const bool cross_down = (ema_2 >= mid_2 && ema_1 < mid_1);
   if(!cross_up && !cross_down)
      return false;

   // --- STATE 1: MACD(6,17,1) main sign on the trigger bar (can be negative) ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);

   // --- STATE 2: RSI(14) relative to the midline on the trigger bar ---
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_1 <= 0.0)
      return false;

   const bool long_states  = (macd_main > 0.0 && rsi_1 > strategy_rsi_level);
   const bool short_states = (macd_main < 0.0 && rsi_1 < strategy_rsi_level);

   QM_OrderType side;
   if(cross_up && long_states)
      side = QM_BUY;
   else if(cross_down && short_states)
      side = QM_SELL;
   else
      return false;

   // --- BB(20,3) bands at the trigger bar (dynamic targets / stop reference) ---
   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_upper <= 0.0 || bb_lower <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: nearest of swing-structure or the BB band on the entry side,
   //     whichever is CLOSER to entry; ATR fallback if neither is valid. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double struct_sl = QM_StopStructure(_Symbol, side, entry, strategy_struct_lookback);

   double sl = 0.0;
   if(side == QM_BUY)
     {
      // candidates must sit BELOW entry; pick the one closest to entry (highest).
      double cand = 0.0;
      if(struct_sl > 0.0 && struct_sl < entry)
         cand = struct_sl;
      if(bb_lower < entry && (cand <= 0.0 || bb_lower > cand))
         cand = bb_lower;
      sl = cand;
     }
   else
     {
      // candidates must sit ABOVE entry; pick the one closest to entry (lowest).
      double cand = 0.0;
      if(struct_sl > entry)
         cand = struct_sl;
      if(bb_upper > entry && (cand <= 0.0 || bb_upper < cand))
         cand = bb_upper;
      sl = cand;
     }

   // ATR fallback if structure/band did not yield a valid stop on the right side.
   if(sl <= 0.0)
     {
      if(atr_value <= 0.0)
         return false;
      sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
     }
   if(sl <= 0.0)
      return false;

   // --- Take profit: opposite BB band if beyond entry, else fixed fallback pips ---
   double tp = 0.0;
   if(side == QM_BUY)
     {
      if(bb_upper > entry)
         tp = bb_upper;
      else
         tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_fallback_pips);
     }
   else
     {
      if(bb_lower < entry)
         tp = bb_lower;
      else
         tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_fallback_pips);
     }
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = (side == QM_BUY) ? "ema3_bbmid_cross_long" : "ema3_bbmid_cross_short";
   return true;
  }

// Static SL/TP exit only (BB-target TP + structure/ATR stop set at entry).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP placed at entry.
bool Strategy_ExitSignal()
  {
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
