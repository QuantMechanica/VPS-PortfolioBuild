#property strict
#property version   "5.0"
#property description "QM5_11828 carter-m5-s18-ema20-macd-10pip-m5 — EMA20 state + MACD cross, fixed 10-pip TP (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11828 carter-m5-s18-ema20-macd-10pip-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         2014, Strategy 18.
// Card: artifacts/cards_approved/QM5_11828_carter-m5-s18-ema20-macd-10pip-m5.md
//       (g0_status APPROVED). Timeframe M5.
//
// Mechanics (closed-bar reads at shift 1; one position per magic):
//   Trend STATE  : price clearly on one side of EMA(20) by an offset cushion.
//                  Long  -> close[1] > EMA20[1] + offset_pips (uptrend).
//                  Short -> close[1] < EMA20[1] - offset_pips (downtrend).
//                  The 10-pip offset (Carter's offset-entry idea) is expressed
//                  as a STATE cushion so we don't trigger right at the EMA touch.
//   Trigger EVENT: ONE event — MACD(12,26,9) main crosses signal in the trend
//                  direction. Long = main crosses up over signal; short = down.
//                  STATE (EMA side) + single EVENT (one cross) avoids the
//                  two-cross-same-bar zero-trade trap.
//   Take profit  : FIXED ~10-pip target via QM_TakeFixedPips (Carter's quick
//                  5-min scalp target). Scale-correct on 5-digit / JPY symbols.
//   Stop loss    : QM_StopFixedPips, sl_pips cushion (initial protective stop).
//   Trade mgmt   : EMA-referenced trailing stop — tighten SL toward
//                  EMA20 -/+ trail_pips while the position runs (source's
//                  EMA-trailing exit), never loosening.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11828;
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
input int    strategy_ema_period         = 20;    // trend EMA (Carter EMA20)
input int    strategy_macd_fast          = 12;    // MACD fast EMA
input int    strategy_macd_slow          = 26;    // MACD slow EMA
input int    strategy_macd_signal        = 9;     // MACD signal SMA
input int    strategy_offset_pips        = 10;    // STATE cushion: price beyond EMA by this many pips
input int    strategy_tp_pips            = 10;    // fixed ~10-pip take profit
input int    strategy_sl_pips            = 15;    // initial protective stop distance (pips)
input int    strategy_trail_pips         = 15;    // EMA-referenced trailing stop offset (pips)
input double strategy_spread_pct_of_tp   = 25.0;  // skip if spread > this % of TP distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Cap reference: the fixed TP distance in price terms (scale-correct).
   const double tp_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(tp_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_tp / 100.0) * tp_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   if(offset <= 0.0)
      return false;

   // --- Trigger EVENT: ONE MACD main/signal cross (shift 2 -> shift 1) ---
   const double macd_main_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                              strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_now   = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                                strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                              strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_prev  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                                strategy_macd_slow, strategy_macd_signal, 2);

   const bool macd_cross_up   = (macd_main_prev <= macd_sig_prev && macd_main_now > macd_sig_now);
   const bool macd_cross_down = (macd_main_prev >= macd_sig_prev && macd_main_now < macd_sig_now);

   // --- Trend STATE: price clearly above/below EMA by the offset cushion ---
   const bool uptrend_state   = (close1 > ema + offset);
   const bool downtrend_state = (close1 < ema - offset);

   QM_OrderType side;
   string reason;
   if(uptrend_state && macd_cross_up)        // STATE long + single EVENT
     {
      side   = QM_BUY;
      reason = "ema20_up_macd_cross_up";
     }
   else if(downtrend_state && macd_cross_down) // STATE short + single EVENT
     {
      side   = QM_SELL;
      reason = "ema20_dn_macd_cross_dn";
     }
   else
      return false;

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

// EMA-referenced trailing stop. Tighten SL toward EMA20 -/+ trail offset while
// the position runs; never loosen. Reads closed-bar EMA (shift 1).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return;

   const double trail_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trail_pips);
   if(trail_dist <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype  = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double new_sl = QM_TM_NormalizePrice(_Symbol, ema - trail_dist);
         // Only move the stop UP (tighten), never down.
         if(new_sl > 0.0 && (cur_sl <= 0.0 || new_sl > cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "ema_trail");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double new_sl = QM_TM_NormalizePrice(_Symbol, ema + trail_dist);
         // Only move the stop DOWN (tighten), never up.
         if(new_sl > 0.0 && (cur_sl <= 0.0 || new_sl < cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "ema_trail");
        }
     }
  }

// No discretionary exit beyond the fixed TP, protective SL, and the EMA trail.
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
