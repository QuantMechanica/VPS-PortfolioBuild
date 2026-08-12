#property strict
#property version   "5.0"
#property description "QM5_11497 Double 7s SMA200 mean reversion D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11497 connors-alvarez-double7s-sma200-d1
// -----------------------------------------------------------------------------
// Approved card mechanics, evaluated from closed D1 bars:
//   LONG  when close[1] > SMA(200) and close[1] is the lowest close in 7 bars.
//   SHORT when close[1] < SMA(200) and close[1] is the highest close in 7 bars.
//   Exit on the opposite 7-bar closing extreme or after 10 held D1 bars.
//   Protective stop is 2 * ATR(14), with trades skipped above the 100-pip cap.
//   New Friday entries are blocked. The spread cap is entry-only and treats
//   the zero modeled spread of .DWX tester symbols as tradeable.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11497;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period         = 200;
input int    strategy_extreme_lookback   = 7;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 2.0;
input int    strategy_max_sl_pips        = 100;
input int    strategy_max_hold_bars      = 10;
input int    strategy_spread_cap_pips    = 30;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter. The card's spread and Friday rules are entry-only so they
// cannot suspend open-position management or exits. The central framework news
// gate remains below management and exits and gates only the entry path.
bool Strategy_NoTradeFilter()
  {
   // This strategy is D1-only. A wrong chart timeframe is not tradeable.
   return (_Period != PERIOD_D1);
  }

// Trade Entry. Caller guarantees the framework closed-bar gate fired once.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_sma_period < 2 || strategy_extreme_lookback < 2 ||
      strategy_atr_period < 1 || strategy_sl_atr_mult <= 0.0 ||
      strategy_max_sl_pips <= 0 || strategy_max_hold_bars <= 0 ||
      strategy_spread_cap_pips <= 0)
      return false;

   // No new Friday entry (broker time). Framework Friday-close management is
   // independent and remains active for existing positions.
   MqlDateTime broker_dt;
   TimeToStruct(TimeCurrent(), broker_dt);
   if(broker_dt.day_of_week == 5)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(
      _Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;
   // .DWX tester quotes may have ask == bid. Block only a genuinely wide
   // positive spread; zero modeled spread must pass.
   if(ask > bid && (ask - bid) > spread_cap)
      return false;

   // SMA(1) on close is the framework-pooled reader for a closed-bar close;
   // it avoids raw iClose calls while preserving the card's exact arithmetic.
   const double close1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   const double sma    = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double atr    = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close1 <= 0.0 || sma <= 0.0 || atr <= 0.0)
      return false;

   bool is_lowest_close  = true;
   bool is_highest_close = true;
   for(int shift = 2; shift <= strategy_extreme_lookback; ++shift)
     {
      const double prior_close = QM_SMA(_Symbol, PERIOD_D1, 1, shift);
      if(prior_close <= 0.0)
         return false;
      if(prior_close < close1)
         is_lowest_close = false;
      if(prior_close > close1)
         is_highest_close = false;
     }

   const double max_stop_distance = QM_StopRulesPipsToPriceDistance(
      _Symbol, strategy_max_sl_pips);
   if(max_stop_distance <= 0.0)
      return false;

   if(close1 > sma && is_lowest_close)
     {
      const double sl = QM_StopATRFromValue(
         _Symbol, QM_BUY, ask, atr, strategy_sl_atr_mult);
      const double stop_distance = ask - sl;
      if(sl <= 0.0 || stop_distance <= 0.0 ||
         stop_distance > max_stop_distance)
         return false;

      req.type   = QM_BUY;
      req.sl     = sl;
      req.reason = "double7s_long";
      return true;
     }

   if(close1 < sma && is_highest_close)
     {
      const double sl = QM_StopATRFromValue(
         _Symbol, QM_SELL, bid, atr, strategy_sl_atr_mult);
      const double stop_distance = sl - bid;
      if(sl <= 0.0 || stop_distance <= 0.0 ||
         stop_distance > max_stop_distance)
         return false;

      req.type   = QM_SELL;
      req.sl     = sl;
      req.reason = "double7s_short";
      return true;
     }

   return false;
  }

// Trade Management. The approved card specifies only the server-side ATR stop;
// there is no break-even, trailing, scale-in, or partial-close rule.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close. The framework invokes this per tick, so the closed-bar extreme
// result is cached by restart-safe held-period count rather than consuming the
// single QM_IsNewBar event that belongs to the entry gate.
bool Strategy_ExitSignal()
  {
   static ulong cached_ticket = 0;
   static int   cached_held_periods = -1;
   static bool  cached_extreme_exit = false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ulong position_ticket = 0;
   bool  position_is_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      position_ticket = ticket;
      position_is_long =
         ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }

   if(position_ticket == 0)
     {
      cached_ticket       = 0;
      cached_held_periods = -1;
      cached_extreme_exit = false;
      return false;
     }

   const int held_periods = QM_TM_HeldPeriodsForMagic(
      (long)magic, _Symbol, PERIOD_D1);
   if(held_periods < 0)
      return false;

   if(strategy_max_hold_bars > 0 && held_periods >= strategy_max_hold_bars)
      return true;

   if(position_ticket == cached_ticket &&
      held_periods == cached_held_periods)
      return cached_extreme_exit;

   if(strategy_extreme_lookback < 2)
      return false;

   const double close1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   if(close1 <= 0.0)
      return false;

   bool extreme_exit = true;
   for(int shift = 2; shift <= strategy_extreme_lookback; ++shift)
     {
      const double prior_close = QM_SMA(_Symbol, PERIOD_D1, 1, shift);
      if(prior_close <= 0.0)
         return false;

      if(position_is_long && prior_close > close1)
         extreme_exit = false;
      if(!position_is_long && prior_close < close1)
         extreme_exit = false;
     }

   cached_ticket       = position_ticket;
   cached_held_periods = held_periods;
   cached_extreme_exit = extreme_exit;
   return cached_extreme_exit;
  }

// News Filter Hook. No card-specific override; the central fail-closed news
// calendar is callable here and is applied by the canonical entry-only gate.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — copied unchanged from framework/templates/EA_Skeleton.mq5.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
