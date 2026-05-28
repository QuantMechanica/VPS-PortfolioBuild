#property strict
#property version   "5.0"
#property description "QM5_10216 TradingView breakout retest"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10216;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pivot_left             = 5;
input int    strategy_pivot_right            = 5;
input int    strategy_pivot_lookback         = 40;
input int    strategy_atr_period             = 14;
input int    strategy_direction_mode         = 2;     // 0 long, 1 short, 2 both
input double strategy_stop_percent           = 1.0;
input double strategy_fx_stop_atr_mult       = 2.0;
input double strategy_profit_threshold_pct   = 1.0;
input double strategy_trailing_stop_pct      = 1.0;
input double strategy_min_retest_atr_mult    = 0.25;
input double strategy_max_spread_atr_mult    = 0.20;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;
   if(strategy_max_spread_atr_mult > 0.0 && (ask - bid) > atr * strategy_max_spread_atr_mult)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static double resistance_level = 0.0;
   static double support_level = 0.0;
   static int pending_dir = 0;
   static double pending_level = 0.0;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 ||
      strategy_pivot_lookback < strategy_pivot_left + strategy_pivot_right + 2 ||
      strategy_atr_period < 1 || strategy_stop_percent <= 0.0 ||
      strategy_fx_stop_atr_mult <= 0.0 || strategy_trailing_stop_pct <= 0.0)
      return false;

   const int pivot_first = strategy_pivot_right + 1;
   const int pivot_last = MathMin(strategy_pivot_lookback, Bars(_Symbol, _Period) - strategy_pivot_left - 2);
   for(int shift = pivot_first; shift <= pivot_last; ++shift)
     {
      const double center_high = iHigh(_Symbol, _Period, shift);
      bool is_pivot_high = (center_high > 0.0);
      for(int i = 1; i <= strategy_pivot_left && is_pivot_high; ++i)
         if(iHigh(_Symbol, _Period, shift + i) >= center_high)
            is_pivot_high = false;
      for(int i = 1; i <= strategy_pivot_right && is_pivot_high; ++i)
         if(iHigh(_Symbol, _Period, shift - i) > center_high)
            is_pivot_high = false;
      if(is_pivot_high)
        {
         resistance_level = center_high;
         break;
        }
     }

   for(int shift = pivot_first; shift <= pivot_last; ++shift)
     {
      const double center_low = iLow(_Symbol, _Period, shift);
      bool is_pivot_low = (center_low > 0.0);
      for(int i = 1; i <= strategy_pivot_left && is_pivot_low; ++i)
         if(iLow(_Symbol, _Period, shift + i) <= center_low)
            is_pivot_low = false;
      for(int i = 1; i <= strategy_pivot_right && is_pivot_low; ++i)
         if(iLow(_Symbol, _Period, shift - i) < center_low)
            is_pivot_low = false;
      if(is_pivot_low)
        {
         support_level = center_low;
         break;
        }
     }

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double close_2 = iClose(_Symbol, _Period, 2);
   const double low_1 = iLow(_Symbol, _Period, 1);
   const double high_1 = iHigh(_Symbol, _Period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(close_1 <= 0.0 || close_2 <= 0.0 || low_1 <= 0.0 || high_1 <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || point <= 0.0 || atr <= 0.0)
      return false;

   if(resistance_level > 0.0 && close_2 <= resistance_level && close_1 > resistance_level)
     {
      pending_dir = 1;
      pending_level = resistance_level;
      return false;
     }
   if(support_level > 0.0 && close_2 >= support_level && close_1 < support_level)
     {
      pending_dir = -1;
      pending_level = support_level;
      return false;
     }

   const double spread = ask - bid;
   const double min_retest_distance = spread + atr * strategy_min_retest_atr_mult;
   const bool long_allowed = (strategy_direction_mode == 0 || strategy_direction_mode == 2);
   const bool short_allowed = (strategy_direction_mode == 1 || strategy_direction_mode == 2);
   const bool long_signal = (pending_dir == 1 && long_allowed &&
                             low_1 <= pending_level && close_1 > pending_level &&
                             MathAbs(pending_level - low_1) >= min_retest_distance);
   const bool short_signal = (pending_dir == -1 && short_allowed &&
                              high_1 >= pending_level && close_1 < pending_level &&
                              MathAbs(high_1 - pending_level) >= min_retest_distance);
   if(!long_signal && !short_signal)
      return false;

   const int magic = QM_FrameworkMagic();
   const ENUM_POSITION_TYPE opposite_type = long_signal ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == opposite_type)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         pending_dir = 0;
         pending_level = 0.0;
         return false;
        }
     }

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? ask : bid;
   const bool is_fx = (StringFind(_Symbol, "USD") >= 0 &&
                       StringFind(_Symbol, "XAU") < 0 &&
                       StringFind(_Symbol, "XAG") < 0 &&
                       StringFind(_Symbol, "XTI") < 0 &&
                       StringFind(_Symbol, "XNG") < 0);
   const double stop_distance = is_fx ? atr * strategy_fx_stop_atr_mult
                                      : entry * strategy_stop_percent / 100.0;
   const double sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, stop_distance);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = long_signal ? "BREAK_RETEST_LONG" : "BREAK_RETEST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   pending_dir = 0;
   pending_level = 0.0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0)
         continue;

      const double profit_pct = is_buy
         ? (market - open_price) / open_price * 100.0
         : (open_price - market) / open_price * 100.0;
      if(profit_pct < strategy_profit_threshold_pct)
         continue;

      const double trail_distance = market * strategy_trailing_stop_pct / 100.0;
      const double target_sl = QM_StopRulesStopFromDistance(_Symbol, is_buy ? QM_BUY : QM_SELL, market, trail_distance);
      if(target_sl <= 0.0)
         continue;
      if(current_sl <= 0.0 ||
         (is_buy && target_sl > current_sl) ||
         (!is_buy && target_sl < current_sl))
         QM_TM_MoveSL(ticket, target_sl, "percent_trailing_stop");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
