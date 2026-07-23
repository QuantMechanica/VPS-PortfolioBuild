#property strict
#property version   "5.0"
#property description "QM5_12517 hlhb-trend — HLHB Forex Trend-Catcher (EMA5/10 median + RSI10 + ADX14, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12517 hlhb-trend
// -----------------------------------------------------------------------------
// Source: Backtest Rookies "Tradingview - HLHB Forex Trend-Catcher System"
//   (Rookie1, 2019-03-28), original "Hucklekiwi Pip - HLHB Trend-Catcher".
// Card: artifacts/cards_approved/QM5_12517_hlhb-trend.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, median price for the EMAs):
//   Trigger EVENT (long) : EMA(fast) crosses ABOVE EMA(slow) on the median price.
//   Trigger EVENT (short): EMA(fast) crosses BELOW EMA(slow) on the median price.
//   Confirm STATE        : RSI(rsi_period) above 50 (long) / below 50 (short).
//                          STATE not a second EVENT — avoids the two-cross trap.
//   Regime filter STATE  : ADX(adx_period) >= adx_min (default 25, toggleable).
//   Stop loss            : initial protective stop at trailing_stop pips.
//   Take profit          : take_profit pips from entry.
//   Trade management      : trailing stop at trailing_stop pips (QM_TM_TrailStep).
//   Opposite-signal exit : a fresh EMA cross the other way closes the position
//                          (one-position-per-magic; framework re-enters next tick).
//   Weekly flat          : framework Friday-close handles no-weekend-exposure.
//
// Pip distances are converted scale-correctly via QM_StopRulesPipsToPriceDistance
// (handles 5-digit FX). Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything below the wiring line is framework boilerplate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12517;
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
input int    strategy_ema_fast_period   = 5;      // HLHB fast EMA (median price)
input int    strategy_ema_slow_period   = 10;     // HLHB slow EMA (median price)
input int    strategy_rsi_period        = 10;     // RSI momentum filter period
input double strategy_rsi_centerline    = 50.0;   // RSI centerline (above=bull state)
input bool   strategy_use_adx_filter    = true;   // source toggle; default ON
input int    strategy_adx_period        = 14;     // ADX trend-strength period
input double strategy_adx_min           = 25.0;   // minimum ADX to allow entry
input int    strategy_take_profit_pips  = 400;    // profit target in pips
input int    strategy_trailing_stop_pips = 150;   // initial stop + trailing distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread/swap gating (.DWX models 0 spread/swap),
// so this never fail-closes the strategy. Regime/signal work is on the
// closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// EMA-cross direction on the median price at a given closed-bar shift.
// Returns +1 fresh bullish cross at `shift`, -1 fresh bearish cross, 0 none.
int EmaCrossDir(const int shift)
  {
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift,     PRICE_MEDIAN);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift,     PRICE_MEDIAN);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift + 1, PRICE_MEDIAN);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift + 1, PRICE_MEDIAN);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return 0;
   if(fast_prev <= slow_prev && fast_now > slow_now)
      return +1;
   if(fast_prev >= slow_prev && fast_now < slow_now)
      return -1;
   return 0;
  }

// Long or short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: a fresh EMA(fast)/EMA(slow) cross on the closed bar. ---
   const int cross = EmaCrossDir(1);
   if(cross == 0)
      return false;

   // --- Confirm STATE: RSI above/below its centerline (NOT a second event). ---
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

   // --- Regime filter STATE: ADX trend strength (toggleable, default ON). ---
   if(strategy_use_adx_filter)
     {
      const double adx_now = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      if(adx_now <= 0.0 || adx_now < strategy_adx_min)
         return false;
     }

   QM_OrderType side;
   if(cross > 0 && rsi_now > strategy_rsi_centerline)
      side = QM_BUY;
   else if(cross < 0 && rsi_now < strategy_rsi_centerline)
      side = QM_SELL;
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trailing_stop_pips);
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_take_profit_pips);
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   double sl, tp;
   if(side == QM_BUY)
     {
      sl = entry - sl_dist;
      tp = entry + tp_dist;
     }
   else
     {
      sl = entry + sl_dist;
      tp = entry - tp_dist;
     }

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason = (side == QM_BUY) ? "hlhb_trend_long" : "hlhb_trend_short";
   return true;
  }

// Trailing stop at the configured pip distance once price moves favourably.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      // Trail the stop by trailing_stop_pips; trigger at the same distance so
      // it engages once the trade is at least one stop-width in profit.
      QM_TM_TrailStep(ticket, strategy_trailing_stop_pips, strategy_trailing_stop_pips);
     }
  }

// Opposite-signal exit: a fresh EMA cross the other way closes the position.
// The framework re-enters on the next closed bar via Strategy_EntrySignal.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int cross = EmaCrossDir(1);
   if(cross == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && cross < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && cross > 0)
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (opposite-signal). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
