#property strict
#property version   "5.0"
#property description "QM5_10095 GitHub ICT Weekly Open Order Block"

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
input int    qm_ea_id                   = 10095;
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
input int    strategy_look_back             = 24;
input double strategy_order_block_threshold = 10.0;
input double strategy_h1_range_adr_ratio    = 0.80;
input int    strategy_daily_body_days       = 5;
input int    strategy_fast_sma              = 5;
input int    strategy_slow_sma              = 30;
input double strategy_rr_low_range          = 3.0;
input double strategy_rr_high_range         = 4.0;
input double strategy_high_range_threshold  = 10.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

bool Strategy_TradedToday()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const datetime day_start = Strategy_DayStart(now);
   if(!HistorySelect(day_start, now))
      return false;

   const int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
     }
   return false;
  }

double Strategy_AverageDailyBody()
  {
   const int days = (strategy_daily_body_days > 1) ? strategy_daily_body_days : 1;
   double sum = 0.0;
   int count = 0;
   for(int shift = 1; shift <= days; ++shift)
     {
      const double d_open = iOpen(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 body filter, closed-bar gated by skeleton
      const double d_close = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 body filter, closed-bar gated by skeleton
      if(d_open <= 0.0 || d_close <= 0.0)
         continue;
      sum += MathAbs(d_close - d_open);
      count++;
     }
   if(count <= 0)
      return 0.0;
   return sum / (double)count;
  }

bool Strategy_CurrentRangeAllowed(const double avg_daily_body)
  {
   if(avg_daily_body <= 0.0 || strategy_h1_range_adr_ratio <= 0.0)
      return false;

   const double h1_high = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: order-block H1 range, closed-bar gated by skeleton
   const double h1_low = iLow(_Symbol, PERIOD_H1, 1);   // perf-allowed: order-block H1 range, closed-bar gated by skeleton
   if(h1_high <= 0.0 || h1_low <= 0.0 || h1_high <= h1_low)
      return false;

   return ((h1_high - h1_low) <= avg_daily_body * strategy_h1_range_adr_ratio);
  }

bool Strategy_FindWeeklyOpen(double &weekly_open)
  {
   weekly_open = 0.0;
   for(int shift = 1; shift <= 120; ++shift)
     {
      const datetime bt = iTime(_Symbol, PERIOD_H1, shift); // perf-allowed: weekly-open reference scan, closed-bar gated by skeleton
      if(bt <= 0)
         continue;

      MqlDateTime dt;
      TimeToStruct(bt, dt);
      if(dt.day_of_week == 1 && dt.hour == 0)
        {
         weekly_open = iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed: Monday H1 open, closed-bar gated by skeleton
         return (weekly_open > 0.0);
        }
     }
   return false;
  }

bool Strategy_FastSmaAboveSlow()
  {
   const int lookback = (strategy_look_back > 1) ? strategy_look_back : 1;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double fast = QM_SMA(_Symbol, PERIOD_H1, strategy_fast_sma, shift);
      const double slow = QM_SMA(_Symbol, PERIOD_H1, strategy_slow_sma, shift);
      if(fast <= 0.0 || slow <= 0.0 || fast <= slow)
         return false;
     }
   return true;
  }

bool Strategy_FastSmaBelowSlow()
  {
   const int lookback = (strategy_look_back > 1) ? strategy_look_back : 1;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double fast = QM_SMA(_Symbol, PERIOD_H1, strategy_fast_sma, shift);
      const double slow = QM_SMA(_Symbol, PERIOD_H1, strategy_slow_sma, shift);
      if(fast <= 0.0 || slow <= 0.0 || fast >= slow)
         return false;
     }
   return true;
  }

bool Strategy_PreviousCandleBullish()
  {
   const double o1 = iOpen(_Symbol, PERIOD_H1, 1);  // perf-allowed: order-block candle read, closed-bar gated by skeleton
   const double c1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: order-block candle read, closed-bar gated by skeleton
   return (o1 > 0.0 && c1 > o1);
  }

bool Strategy_PreviousCandleBearish()
  {
   const double o1 = iOpen(_Symbol, PERIOD_H1, 1);  // perf-allowed: order-block candle read, closed-bar gated by skeleton
   const double c1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: order-block candle read, closed-bar gated by skeleton
   return (o1 > 0.0 && c1 < o1);
  }

bool Strategy_PreviousBodyPassesThreshold()
  {
   const double o1 = iOpen(_Symbol, PERIOD_H1, 1);  // perf-allowed: order-block candle read, closed-bar gated by skeleton
   const double c1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: order-block candle read, closed-bar gated by skeleton
   const double h1 = iHigh(_Symbol, PERIOD_H1, 1);  // perf-allowed: order-block candle read, closed-bar gated by skeleton
   const double l1 = iLow(_Symbol, PERIOD_H1, 1);   // perf-allowed: order-block candle read, closed-bar gated by skeleton
   if(o1 <= 0.0 || c1 <= 0.0 || h1 <= l1)
      return false;
   const double body_pct = 100.0 * MathAbs(c1 - o1) / (h1 - l1);
   return (body_pct > strategy_order_block_threshold);
  }

bool Strategy_PreviousCloseIsLowestInLookback()
  {
   const double c1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: order-block close read, closed-bar gated by skeleton
   if(c1 <= 0.0)
      return false;

   const int lookback = (strategy_look_back > 1) ? strategy_look_back : 1;
   for(int shift = 2; shift <= lookback + 1; ++shift)
     {
      const double c = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: shifted close window, closed-bar gated by skeleton
      if(c <= 0.0 || c < c1)
         return false;
     }
   return true;
  }

bool Strategy_PreviousCloseIsHighestInLookback()
  {
   const double c1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: order-block close read, closed-bar gated by skeleton
   if(c1 <= 0.0)
      return false;

   const int lookback = (strategy_look_back > 1) ? strategy_look_back : 1;
   for(int shift = 2; shift <= lookback + 1; ++shift)
     {
      const double c = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: shifted close window, closed-bar gated by skeleton
      if(c <= 0.0 || c > c1)
         return false;
     }
   return true;
  }

double Strategy_NormalizeStopDistance(const double entry_price, const double raw_sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry_price <= 0.0 || raw_sl <= 0.0 || point <= 0.0)
      return 0.0;

   double dist = MathAbs(entry_price - raw_sl);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_dist = MathMax((double)(stops_level + 1) * point, point);
   if(dist < min_dist)
      dist = min_dist;
   return dist;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_H1);
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

   if(Strategy_HasOpenPosition() || Strategy_TradedToday())
      return false;

   double weekly_open = 0.0;
   if(!Strategy_FindWeeklyOpen(weekly_open))
      return false;

   const double avg_daily_body = Strategy_AverageDailyBody();
   if(!Strategy_CurrentRangeAllowed(avg_daily_body))
      return false;

   const double prev_open = iOpen(_Symbol, PERIOD_H1, 1); // perf-allowed: order-block trigger price, closed-bar gated by skeleton
   const double prev_low = iLow(_Symbol, PERIOD_H1, 1);    // perf-allowed: order-block stop price, closed-bar gated by skeleton
   const double prev_high = iHigh(_Symbol, PERIOD_H1, 1);  // perf-allowed: order-block stop price, closed-bar gated by skeleton
   if(prev_open <= 0.0 || prev_low <= 0.0 || prev_high <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double rr = (avg_daily_body >= strategy_high_range_threshold) ? strategy_rr_high_range : strategy_rr_low_range;
   if(bid <= 0.0 || ask <= 0.0 || rr <= 0.0)
      return false;

   if(bid > weekly_open &&
      Strategy_PreviousCandleBearish() &&
      Strategy_PreviousBodyPassesThreshold() &&
      Strategy_PreviousCloseIsLowestInLookback() &&
      bid >= prev_open &&
      Strategy_FastSmaAboveSlow())
     {
      const double stop_dist = Strategy_NormalizeStopDistance(ask, prev_low);
      if(stop_dist <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - stop_dist;
      req.tp = ask + stop_dist * rr;
      req.reason = "ICT_WEEKLY_OPEN_OB_BUY";
      return true;
     }

   if(ask < weekly_open &&
      Strategy_PreviousCandleBullish() &&
      Strategy_PreviousBodyPassesThreshold() &&
      Strategy_PreviousCloseIsHighestInLookback() &&
      ask <= prev_open &&
      Strategy_FastSmaBelowSlow())
     {
      const double stop_dist = Strategy_NormalizeStopDistance(bid, prev_high);
      if(stop_dist <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + stop_dist;
      req.tp = bid - stop_dist * rr;
      req.reason = "ICT_WEEKLY_OPEN_OB_SELL";
      return true;
     }

   return false;
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      if(is_buy && current_sl >= open_price)
         continue;
      if(!is_buy && current_sl <= open_price)
         continue;

      const double initial_risk = MathAbs(open_price - current_sl);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(initial_risk <= 0.0 || market_price <= 0.0)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(moved < initial_risk * 2.0)
         continue;

      const double target_sl = is_buy ? (open_price + initial_risk) : (open_price - initial_risk);
      QM_TM_MoveSL(ticket, target_sl, "ICT_2R_MOVE_SL_TO_1R");
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
