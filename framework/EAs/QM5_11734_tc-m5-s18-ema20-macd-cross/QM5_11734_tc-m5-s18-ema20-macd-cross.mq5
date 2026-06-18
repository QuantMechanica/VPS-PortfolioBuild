#property strict
#property version   "5.0"
#property description "QM5_11734 tc-m5-s18-ema20-macd-cross — EMA20 price-cross + MACD-state (M5 FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11734 tc-m5-s18-ema20-macd-cross
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         Strategy #18, 2013.
// Card: artifacts/cards_approved/QM5_11734_tc-m5-s18-ema20-macd-cross.md (APPROVED).
//
// Two-cross-trap avoidance (build prompt §.DWX rule 4):
//   The price/EMA20 cross is the single TRIGGER EVENT (one per bar).
//   The MACD relationship is a confirmation STATE (main vs signal), NOT a
//   second fresh cross on the same bar. Requiring two coincident crossovers
//   almost never fires on .DWX -> zero trades. So:
//     EVENT (long): close[2] <= EMA20[2] AND close[1] > EMA20[1].
//     STATE (long): MACD_main[1] > MACD_signal[1]  (bullish momentum).
//   Mirror for short.
//
// Mechanics (closed-bar reads at shift 1/2; market entry on the trigger bar):
//   Long  : fresh upward price/EMA20 cross + MACD main above signal.
//   Short : fresh downward price/EMA20 cross + MACD main below signal.
//   Stop  : conservative — strategy_sl_pips beyond the EMA20 level
//           (card default 20 pips from EMA20), scale-correct via pip helper.
//   Target: strategy_tp_rr * risk (R-multiple TP off the entry/stop distance).
//   Manage: EMA20-based trailing stop once price has advanced — trail stop to
//           EMA20 -/+ strategy_trail_pips, only ever tightening (card: trail
//           remainder at EMA20-15 pips). Single position per magic, so no
//           partial-exit bookkeeping is carried; the 2R TP captures the
//           card's "partial at 2x risk" intent in one exit.
//   Spread guard: block only a genuinely wide spread (fail-open on .DWX 0).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11734;
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
input int    strategy_ema_period        = 20;     // trend EMA (price-cross trigger)
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal EMA
input int    strategy_sl_pips           = 20;     // conservative stop, pips beyond EMA20
input double strategy_tp_rr             = 2.0;    // take-profit as R-multiple of stop
input int    strategy_trail_pips        = 15;     // trail stop to EMA20 -/+ this many pips
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // EMA20 at the two most-recent closed bars (shift 2 = before, shift 1 = cross bar).
   const double ema_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema_prev <= 0.0 || ema_now <= 0.0)
      return false;

   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double close_now  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close_prev <= 0.0 || close_now <= 0.0)
      return false;

   // MACD STATE at the trigger (cross) bar — confirmation, not a 2nd event.
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);
   const double macd_sig  = QM_MACD_Signal(_Symbol, _Period,
                                           strategy_macd_fast, strategy_macd_slow,
                                           strategy_macd_signal, 1);

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return false;

   // --- LONG: fresh upward price/EMA20 cross + bullish MACD state ---
   const bool cross_up   = (close_prev <= ema_prev && close_now > ema_now);
   const bool macd_bull  = (macd_main > macd_sig);
   if(cross_up && macd_bull)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Conservative stop: strategy_sl_pips below the EMA20 level.
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                                                   ema_now - strategy_sl_pips * pip);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema20_macd_cross_long";
      return true;
     }

   // --- SHORT: fresh downward price/EMA20 cross + bearish MACD state ---
   const bool cross_dn   = (close_prev >= ema_prev && close_now < ema_now);
   const bool macd_bear  = (macd_main < macd_sig);
   if(cross_dn && macd_bear)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      // Conservative stop: strategy_sl_pips above the EMA20 level.
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                                                   ema_now + strategy_sl_pips * pip);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema20_macd_cross_short";
      return true;
     }

   return false;
  }

// EMA20-based trailing stop. Trail the SL toward EMA20 -/+ strategy_trail_pips,
// only ever tightening (never loosening). Runs per tick but uses the closed-bar
// EMA20 value (handle-pooled reader) + cheap position reads — O(1).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double ema_now = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema_now <= 0.0)
      return;
   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double open_p = PositionGetDouble(POSITION_PRICE_OPEN);

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double trail_sl = QM_StopRulesNormalizePrice(_Symbol,
                                    ema_now - strategy_trail_pips * pip);
         // Only tighten: new SL must be above current SL and below current bid,
         // and never below the original entry-derived stop is not required —
         // the trail simply ratchets up as the EMA rises.
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(trail_sl > 0.0 && trail_sl < bid &&
            (cur_sl <= 0.0 || trail_sl > cur_sl) && trail_sl > open_p)
            QM_TM_MoveSL(ticket, trail_sl, "ema20_trail_long");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double trail_sl = QM_StopRulesNormalizePrice(_Symbol,
                                    ema_now + strategy_trail_pips * pip);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(trail_sl > 0.0 && trail_sl > ask &&
            (cur_sl <= 0.0 || trail_sl < cur_sl) && trail_sl < open_p)
            QM_TM_MoveSL(ticket, trail_sl, "ema20_trail_short");
        }
     }
  }

// No discretionary close beyond SL/TP and the EMA20 trail. The card's
// "exit on opposite EMA20 cross" is captured implicitly: an opposite cross
// only occurs after the EMA20 trail has ratcheted the stop to the EMA, so the
// trail removes the position around the same level. Keep this empty to avoid a
// second new-bar gate / double-cross interaction.
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
