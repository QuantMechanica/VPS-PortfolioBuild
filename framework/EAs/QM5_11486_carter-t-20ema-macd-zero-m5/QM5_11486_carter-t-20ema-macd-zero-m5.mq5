#property strict
#property version   "5.0"
#property description "QM5_11486 carter-t-20ema-macd-zero-m5 — 20 EMA price cross + MACD zero-line momentum (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11486 carter-t-20ema-macd-zero-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #18 (2014). Card: artifacts/cards_approved/
//         QM5_11486_carter-t-20ema-macd-zero-m5.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE   : price position vs EMA(20).
//   Trigger EVENT : price crosses the EMA(20) on the just-closed bar.
//                     LONG  -> close[2] <= EMA20[2] AND close[1] > EMA20[1]
//                     SHORT -> close[2] >= EMA20[2] AND close[1] < EMA20[1]
//   Momentum STATE: MACD main confirms zero-line momentum WITHIN the last
//                   `macd_lookback` closed bars (NOT on the same bar as the EMA
//                   cross — that two-cross-same-bar requirement almost never
//                   coincides and starves trades). The EMA cross is the single
//                   EVENT; the MACD zero-side is a STATE observed in a window.
//                     LONG  -> any( MACD_main[k] > 0 for k in 1..macd_lookback )
//                     SHORT -> any( MACD_main[k] < 0 for k in 1..macd_lookback )
//   Stop          : conservative — `sl_pips` beyond the EMA(20) (card P2 = 20p,
//                   cap 25). Anchored to EMA20 so the stop tracks the trend line.
//   Take (partial): half the position at +1R (sl distance from entry). On the
//                   first partial fill the remainder is moved to break-even.
//   Trail (rest)  : remainder trails the EMA(20) by `trail_pips` (card = 15p).
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//   No Friday entry (card filter) — handled in Strategy_NoTradeFilter.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11486;
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
input int    strategy_ema_period         = 20;     // trend EMA (state + cross trigger)
input int    strategy_macd_fast          = 12;     // MACD fast EMA
input int    strategy_macd_slow          = 26;     // MACD slow EMA
input int    strategy_macd_signal        = 9;      // MACD signal EMA
input int    strategy_macd_lookback      = 5;      // bars (1..N) for MACD zero-side STATE
input int    strategy_sl_pips            = 20;     // conservative stop: pips beyond EMA20 (card P2; cap 25)
input double strategy_tp_rr              = 1.0;    // first partial take at this R-multiple
input double strategy_partial_fraction   = 0.5;    // fraction of position closed at TP1
input int    strategy_trail_pips         = 15;     // remainder trails EMA20 by this many pips
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance
input bool   strategy_no_friday_entry    = true;   // card filter: no new entries on Friday

// File-scope: tracks whether the open position has already taken its TP1 partial,
// so the partial fires once and the trail/BE engages on the remainder thereafter.
ulong  g_partial_done_ticket = 0;   // ticket that already took its partial (0 = none)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Pip price-distance for `pips` on this symbol (5-digit / JPY scale-correct).
double Strategy_PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// MACD main is on the required zero-line side anywhere in shifts 1..lookback.
bool Strategy_MacdSideWithinLookback(const bool want_positive)
  {
   const int last = (strategy_macd_lookback < 1) ? 1 : strategy_macd_lookback;
   for(int k = 1; k <= last; ++k)
     {
      const double macd = QM_MACD_Main(_Symbol, _Period,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_signal, k);
      if(want_positive && macd > 0.0)
         return true;
      if(!want_positive && macd < 0.0)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard (fail-open on .DWX zero spread) plus
// the card "no Friday entry" filter. Regime/signal work is on the closed-bar
// path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)   // Friday
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = Strategy_PipDistance(strategy_sl_pips);
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

   // --- EMA(20) trend line at the two most-recent closed bars ---
   const double ema_1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close_2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   // --- Trigger EVENT: price crosses the EMA(20) on the just-closed bar ---
   const bool cross_up   = (close_2 <= ema_2 && close_1 > ema_1);
   const bool cross_down = (close_2 >= ema_2 && close_1 < ema_1);
   if(!cross_up && !cross_down)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, (cross_up ? SYMBOL_ASK : SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   if(cross_up)
     {
      // --- Momentum STATE: MACD main positive within the lookback window ---
      if(!Strategy_MacdSideWithinLookback(true))
         return false;

      // Conservative stop: sl_pips below the EMA(20).
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                           ema_1 - Strategy_PipDistance(strategy_sl_pips));
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema20_cross_up_macd_zero_long";
      return true;
     }

   // cross_down -> SHORT
   if(!Strategy_MacdSideWithinLookback(false))
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol,
                        ema_1 + Strategy_PipDistance(strategy_sl_pips));
   if(sl <= 0.0 || sl <= entry)
      return false;
   const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ema20_cross_down_macd_zero_short";
   return true;
  }

// Trade management: take a partial at +1R (the framework's req.tp closes the
// WHOLE position at 1R, so we pre-empt it with a partial + break-even on the
// remainder), then trail the remainder along the EMA(20).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_partial_done_ticket = 0;
      return;
     }

   const double ema_1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double trail_dist = Strategy_PipDistance(strategy_trail_pips);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long   ptype     = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price   = PositionGetDouble(POSITION_SL);
      const double cur_vol     = PositionGetDouble(POSITION_VOLUME);
      const bool   is_buy     = (ptype == POSITION_TYPE_BUY);

      // Risk distance (entry -> stop). Used to locate the +1R partial level.
      double risk_dist = is_buy ? (open_price - sl_price) : (sl_price - open_price);
      if(risk_dist <= 0.0)
         risk_dist = Strategy_PipDistance(strategy_sl_pips);

      const double tp1_level = is_buy ? (open_price + strategy_tp_rr * risk_dist)
                                      : (open_price - strategy_tp_rr * risk_dist);
      const double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(price <= 0.0)
         continue;

      const bool reached_tp1 = is_buy ? (price >= tp1_level) : (price <= tp1_level);

      // --- Stage 1: partial close at +1R, then break-even on the remainder ---
      if(g_partial_done_ticket != ticket && reached_tp1)
        {
         const double partial_vol = QM_TM_NormalizeVolume(_Symbol, cur_vol * strategy_partial_fraction);
         if(partial_vol > 0.0 && partial_vol < cur_vol)
            QM_TM_PartialClose(ticket, partial_vol, QM_EXIT_STRATEGY);
         // Move the (remaining) stop to break-even.
         QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "tp1_breakeven");
         g_partial_done_ticket = ticket;
         continue; // next tick handles trailing on the remainder
        }

      // --- Stage 2: trail the remainder along the EMA(20) ---
      if(g_partial_done_ticket == ticket && ema_1 > 0.0 && trail_dist > 0.0)
        {
         if(is_buy)
           {
            const double new_sl = QM_TM_NormalizePrice(_Symbol, ema_1 - trail_dist);
            // Only ratchet up, never loosen, and stay below current price.
            if(new_sl > sl_price && new_sl < price)
               QM_TM_MoveSL(ticket, new_sl, "ema_trail_long");
           }
         else
           {
            const double new_sl = QM_TM_NormalizePrice(_Symbol, ema_1 + trail_dist);
            if((sl_price <= 0.0 || new_sl < sl_price) && new_sl > price)
               QM_TM_MoveSL(ticket, new_sl, "ema_trail_short");
           }
        }
     }
  }

// No discretionary close beyond SL/TP and the trade-management trail/partial.
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
