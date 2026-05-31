#property strict
#property version   "5.0"
#property description "QM5_10700 TradingView Liquidity Contraction Breakout"

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
input int    qm_ea_id                   = 10700;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_contraction_lookback = 10;
input int    strategy_liquidity_length     = 20;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input double strategy_target_rr            = 2.0;
input bool   strategy_use_fixed_pct_stop   = false;
input double strategy_fixed_stop_pct       = 0.01;
input bool   strategy_allow_long           = true;
input bool   strategy_allow_short          = true;
input int    strategy_max_spread_points    = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool IsAllowedBaselineTimeframe()
  {
   return (_Period == PERIOD_H1 || _Period == PERIOD_H4 || _Period == PERIOD_H6);
  }

bool IsPivotHighAt(const int shift, const int lookback)
  {
   const double candidate = iHigh(_Symbol, _Period, shift);
   if(candidate <= 0.0)
      return false;

   for(int j = 1; j <= lookback; ++j)
     {
      const double newer = iHigh(_Symbol, _Period, shift - j);
      const double older = iHigh(_Symbol, _Period, shift + j);
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(newer > candidate || older > candidate)
         return false;
     }
   return true;
  }

bool IsPivotLowAt(const int shift, const int lookback)
  {
   const double candidate = iLow(_Symbol, _Period, shift);
   if(candidate <= 0.0)
      return false;

   for(int j = 1; j <= lookback; ++j)
     {
      const double newer = iLow(_Symbol, _Period, shift - j);
      const double older = iLow(_Symbol, _Period, shift + j);
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(newer < candidate || older < candidate)
         return false;
     }
   return true;
  }

bool FindTwoRecentPivotHighs(const int lookback,
                             const int scan_bars,
                             double &latest_high,
                             double &previous_high)
  {
   latest_high = 0.0;
   previous_high = 0.0;

   const int first_shift = lookback + 1;
   const int last_shift = MathMax(first_shift + 1, scan_bars);
   if(Bars(_Symbol, _Period) <= last_shift + lookback + 2)
      return false;

   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!IsPivotHighAt(shift, lookback))
         continue;

      if(latest_high <= 0.0)
         latest_high = iHigh(_Symbol, _Period, shift);
      else
        {
         previous_high = iHigh(_Symbol, _Period, shift);
         return (previous_high > 0.0);
        }
     }
   return false;
  }

bool FindTwoRecentPivotLows(const int lookback,
                            const int scan_bars,
                            double &latest_low,
                            double &previous_low)
  {
   latest_low = 0.0;
   previous_low = 0.0;

   const int first_shift = lookback + 1;
   const int last_shift = MathMax(first_shift + 1, scan_bars);
   if(Bars(_Symbol, _Period) <= last_shift + lookback + 2)
      return false;

   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!IsPivotLowAt(shift, lookback))
         continue;

      if(latest_low <= 0.0)
         latest_low = iLow(_Symbol, _Period, shift);
      else
        {
         previous_low = iLow(_Symbol, _Period, shift);
         return (previous_low > 0.0);
        }
     }
   return false;
  }

bool PriorLiquidityLevels(const int length, double &upper, double &lower)
  {
   upper = 0.0;
   lower = 0.0;
   if(length <= 1 || Bars(_Symbol, _Period) <= length + 3)
      return false;

   for(int shift = 2; shift <= length + 1; ++shift)
     {
      const double h = iHigh(_Symbol, _Period, shift);
      const double l = iLow(_Symbol, _Period, shift);
      if(h <= 0.0 || l <= 0.0)
         return false;

      if(upper <= 0.0 || h > upper)
         upper = h;
      if(lower <= 0.0 || l < lower)
         lower = l;
     }
   return (upper > lower && lower > 0.0);
  }

bool ContractionDetected(double &range_high, double &range_low)
  {
   range_high = 0.0;
   range_low = 0.0;

   const int lookback = MathMax(2, strategy_contraction_lookback);
   const int scan_bars = MathMax(strategy_liquidity_length + lookback * 4, lookback * 8);

   double latest_high = 0.0;
   double previous_high = 0.0;
   double latest_low = 0.0;
   double previous_low = 0.0;
   if(!FindTwoRecentPivotHighs(lookback, scan_bars, latest_high, previous_high))
      return false;
   if(!FindTwoRecentPivotLows(lookback, scan_bars, latest_low, previous_low))
      return false;

   if(!(latest_high < previous_high && latest_low > previous_low))
      return false;

   range_high = latest_high;
   range_low = latest_low;
   return (range_high > range_low && range_low > 0.0);
  }

bool ContractionRangeClearsStopDistance(const double range_high, const double range_low)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || range_high <= range_low)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level <= 0)
      return true;

   const double range_points = (range_high - range_low) / point;
   return (range_points >= stops_level);
  }

bool BuildBreakoutRequest(const QM_OrderType side,
                          const double entry_price,
                          const string reason,
                          QM_EntryRequest &req)
  {
   req.type = side;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(entry_price <= 0.0)
      return false;

   if(strategy_use_fixed_pct_stop)
     {
      const double stop_dist = entry_price * strategy_fixed_stop_pct;
      if(stop_dist <= 0.0)
         return false;
      req.sl = NormalizeStrategyPrice(QM_OrderTypeIsBuy(side) ? entry_price - stop_dist
                                                              : entry_price + stop_dist);
     }
   else
     {
      req.sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
     }

   req.tp = QM_TakeRR(_Symbol, side, entry_price, req.sl, strategy_target_rr);
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!IsAllowedBaselineTimeframe())
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_contraction_lookback < 2 ||
      strategy_liquidity_length < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_target_rr <= 0.0)
      return false;

   double contraction_high = 0.0;
   double contraction_low = 0.0;
   if(!ContractionDetected(contraction_high, contraction_low))
      return false;
   if(!ContractionRangeClearsStopDistance(contraction_high, contraction_low))
      return false;

   double liquidity_high = 0.0;
   double liquidity_low = 0.0;
   if(!PriorLiquidityLevels(strategy_liquidity_length, liquidity_high, liquidity_low))
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double close_2 = iClose(_Symbol, _Period, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   if(strategy_allow_long && close_2 <= liquidity_high && close_1 > liquidity_high)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return BuildBreakoutRequest(QM_BUY, ask, "TV_LIQ_BREAK_LONG", req);
     }

   if(strategy_allow_short && close_2 >= liquidity_low && close_1 < liquidity_low)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return BuildBreakoutRequest(QM_SELL, bid, "TV_LIQ_BREAK_SHORT", req);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // P2 baseline has no discretionary management beyond fixed SL/TP.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // P2 baseline exits by ATR SL, fixed 2R TP, and framework Friday close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
