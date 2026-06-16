#property strict
#property version   "5.0"
#property description "QM5_11200 ft-fsuper"
// rework v2 2026-06-16 — Supertrend direction seed used close>=final_lower (the lower
// band) instead of close>=hl2 (centerline). For wide multipliers (buy_m2=7, sell_m3=6)
// the seed pinned direction permanently to +1 (close is ~never below hl2-7*ATR), so
// sell3 never went negative (0 short entries) and triple agreement fired ~once/8yr
// (1 trade 2017-2024 GDAXI) -> Q02 MIN_TRADES fail. Seed from hl2 to match canonical
// Supertrend and all sibling EAs (10803/10804/10806/10249/12538).

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
input int    qm_ea_id                   = 11200;
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
input int    buy_m1                       = 4;
input int    buy_m2                       = 7;
input int    buy_m3                       = 1;
input int    buy_p1                       = 8;
input int    buy_p2                       = 9;
input int    buy_p3                       = 8;
input int    sell_m1                      = 1;
input int    sell_m2                      = 3;
input int    sell_m3                      = 6;
input int    sell_p1                      = 16;
input int    sell_p2                      = 18;
input int    sell_p3                      = 18;
input int    atr_stop_period              = 14;
input double atr_stop_mult                = 2.5;
input int    strategy_warmup_bars         = 180;
input double strategy_max_spread_stop_pct = 8.0;
input double strategy_source_stoploss_pct = 26.5;
input double strategy_trailing_positive_pct = 5.0;
input double strategy_trailing_offset_pct = 10.0;
input bool   strategy_trailing_only_offset_is_reached = false;
input int    strategy_roi_1_minutes       = 0;
input double strategy_roi_1_pct           = 10.0;
input int    strategy_roi_2_minutes       = 30;
input double strategy_roi_2_pct           = 75.0;
input int    strategy_roi_3_minutes       = 60;
input double strategy_roi_3_pct           = 5.0;
input int    strategy_roi_4_minutes       = 120;
input double strategy_roi_4_pct           = 2.5;

bool g_strategy_signal_valid = false;
bool g_strategy_volume_ok = false;
bool g_strategy_entry_long = false;
bool g_strategy_entry_short = false;
bool g_strategy_exit_long = false;
bool g_strategy_exit_short = false;

double Strategy_Max3(const double a, const double b, const double c)
  {
   return MathMax(a, MathMax(b, c));
  }

int Strategy_MaxPeriod()
  {
   int max_period = MathMax(MathMax(buy_p1, buy_p2), buy_p3);
   max_period = MathMax(max_period, MathMax(MathMax(sell_p1, sell_p2), sell_p3));
   return max_period;
  }

int Strategy_SupertrendDirection(const MqlRates &rates[],
                                 const int copied,
                                 const int multiplier,
                                 const int period)
  {
   if(copied <= period + 2 || period <= 0 || multiplier <= 0)
      return 0;

   double tr_values[];
   ArrayResize(tr_values, copied);

   double tr_sum = 0.0;
   int tr_count = 0;
   double prev_final_upper = 0.0;
   double prev_final_lower = 0.0;
   int prev_direction = 0;

   for(int i = copied - 1; i >= 0; --i)
     {
      const double high = rates[i].high;
      const double low = rates[i].low;
      const double close = rates[i].close;
      const double prev_close = (i == copied - 1) ? close : rates[i + 1].close;
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high < low)
         continue;

      const double tr = Strategy_Max3(high - low,
                                      MathAbs(high - prev_close),
                                      MathAbs(low - prev_close));
      tr_values[i] = tr;
      tr_sum += tr;
      tr_count++;
      if(tr_count > period)
         tr_sum -= tr_values[i + period];
      if(tr_count < period)
         continue;

      const double atr = tr_sum / (double)period;
      if(atr <= 0.0 || !MathIsValidNumber(atr))
         continue;

      const double hl2 = (high + low) * 0.5;
      const double basic_upper = hl2 + (double)multiplier * atr;
      const double basic_lower = hl2 - (double)multiplier * atr;

      double final_upper = basic_upper;
      double final_lower = basic_lower;
      if(prev_final_upper > 0.0)
         final_upper = (basic_upper < prev_final_upper || prev_close > prev_final_upper)
                       ? basic_upper : prev_final_upper;
      if(prev_final_lower > 0.0)
         final_lower = (basic_lower > prev_final_lower || prev_close < prev_final_lower)
                       ? basic_lower : prev_final_lower;

      int direction = prev_direction;
      if(direction == 0)
         direction = (close >= hl2) ? 1 : -1;
      else if(direction < 0 && close > final_upper)
         direction = 1;
      else if(direction > 0 && close < final_lower)
         direction = -1;

      prev_final_upper = final_upper;
      prev_final_lower = final_lower;
      prev_direction = direction;
     }

   return prev_direction;
  }

bool Strategy_RecomputeSignals()
  {
   g_strategy_signal_valid = false;
   g_strategy_volume_ok = false;
   g_strategy_entry_long = false;
   g_strategy_entry_short = false;
   g_strategy_exit_long = false;
   g_strategy_exit_short = false;

   const int min_warmup = MathMax(strategy_warmup_bars, Strategy_MaxPeriod() + 80);
   const int bars_needed = MathMax(min_warmup, 180);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars_needed, rates); // perf-allowed: closed-bar Supertrend state cache; no QM OHLC array helper exists.
   if(copied < min_warmup)
      return false;

   g_strategy_volume_ok = (rates[0].tick_volume > 0);
   if(!g_strategy_volume_ok)
      return false;

   const int buy1 = Strategy_SupertrendDirection(rates, copied, buy_m1, buy_p1);
   const int buy2 = Strategy_SupertrendDirection(rates, copied, buy_m2, buy_p2);
   const int buy3 = Strategy_SupertrendDirection(rates, copied, buy_m3, buy_p3);
   const int sell1 = Strategy_SupertrendDirection(rates, copied, sell_m1, sell_p1);
   const int sell2 = Strategy_SupertrendDirection(rates, copied, sell_m2, sell_p2);
   const int sell3 = Strategy_SupertrendDirection(rates, copied, sell_m3, sell_p3);

   g_strategy_entry_long = (buy1 > 0 && buy2 > 0 && buy3 > 0);
   g_strategy_entry_short = (sell1 < 0 && sell2 < 0 && sell3 < 0);
   g_strategy_exit_long = (sell2 < 0);
   g_strategy_exit_short = (buy2 > 0);
   g_strategy_signal_valid = true;
   return true;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }

   return false;
  }

double Strategy_ProfitPct(const ENUM_POSITION_TYPE position_type,
                          const double open_price,
                          const double market_price)
  {
   if(open_price <= 0.0 || market_price <= 0.0)
      return 0.0;
   if(position_type == POSITION_TYPE_BUY)
      return ((market_price - open_price) / open_price) * 100.0;
   if(position_type == POSITION_TYPE_SELL)
      return ((open_price - market_price) / open_price) * 100.0;
   return 0.0;
  }

double Strategy_CurrentRoiThresholdPct(const int hold_minutes)
  {
   double threshold = strategy_roi_1_pct;
   if(hold_minutes >= strategy_roi_2_minutes)
      threshold = MathMin(threshold, strategy_roi_2_pct);
   if(hold_minutes >= strategy_roi_3_minutes)
      threshold = MathMin(threshold, strategy_roi_3_pct);
   if(hold_minutes >= strategy_roi_4_minutes)
      threshold = MathMin(threshold, strategy_roi_4_pct);
   return threshold;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(buy_m1 <= 0 || buy_m2 <= 0 || buy_m3 <= 0 ||
      buy_p1 <= 0 || buy_p2 <= 0 || buy_p3 <= 0 ||
      sell_m1 <= 0 || sell_m2 <= 0 || sell_m3 <= 0 ||
      sell_p1 <= 0 || sell_p2 <= 0 || sell_p3 <= 0 ||
      atr_stop_period <= 0 || atr_stop_mult <= 0.0 ||
      strategy_warmup_bars <= Strategy_MaxPeriod() ||
      strategy_max_spread_stop_pct < 0.0 ||
      strategy_source_stoploss_pct <= 0.0 ||
      strategy_trailing_positive_pct < 0.0 ||
      strategy_trailing_offset_pct < 0.0 ||
      strategy_roi_1_minutes < 0 ||
      strategy_roi_2_minutes < strategy_roi_1_minutes ||
      strategy_roi_3_minutes < strategy_roi_2_minutes ||
      strategy_roi_4_minutes < strategy_roi_3_minutes)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, atr_stop_period, 1);
   const double planned_stop_distance = atr * atr_stop_mult;
   if(atr <= 0.0 || planned_stop_distance <= 0.0 || !MathIsValidNumber(planned_stop_distance))
      return true;

   const double spread = ask - bid;
   if(spread > planned_stop_distance * strategy_max_spread_stop_pct / 100.0)
      return true;

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

   if(!Strategy_RecomputeSignals())
      return false;
   if(!g_strategy_volume_ok || Strategy_HasOpenPosition())
      return false;
   if(g_strategy_entry_long == g_strategy_entry_short)
      return false;

   const bool long_signal = g_strategy_entry_long;
   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, atr_stop_period, atr_stop_mult);
   if(sl <= 0.0 ||
      (long_signal && sl >= entry) ||
      (!long_signal && sl <= entry))
      return false;

   req.type = side;
   req.sl = sl;
   req.reason = long_signal ? "FSUPER_TRIPLE_ST_LONG" : "FSUPER_TRIPLE_ST_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_trailing_positive_pct <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(market_price <= 0.0 || open_price <= 0.0)
         continue;

      const double profit_pct = Strategy_ProfitPct(position_type, open_price, market_price);
      const double activation_pct = strategy_trailing_only_offset_is_reached
                                    ? strategy_trailing_offset_pct
                                    : strategy_trailing_positive_pct;
      if(profit_pct < activation_pct)
         continue;

      const double trail_distance = market_price * strategy_trailing_positive_pct / 100.0;
      if(trail_distance <= 0.0)
         continue;

      const double new_sl = is_buy ? (market_price - trail_distance)
                                   : (market_price + trail_distance);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (new_sl > current_sl + point * 0.5)
                                    : (new_sl < current_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, new_sl, "fsuper_source_percent_trailing");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(g_strategy_signal_valid && g_strategy_volume_ok)
        {
         if(position_type == POSITION_TYPE_BUY && g_strategy_exit_long)
            return true;
         if(position_type == POSITION_TYPE_SELL && g_strategy_exit_short)
            return true;
        }

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double market_price = (position_type == POSITION_TYPE_BUY)
                                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market_price <= 0.0)
         continue;

      const double profit_pct = Strategy_ProfitPct(position_type, open_price, market_price);
      if(profit_pct <= -strategy_source_stoploss_pct)
         return true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int hold_minutes = (int)((now - opened) / 60);
      const double roi_threshold_pct = Strategy_CurrentRoiThresholdPct(hold_minutes);
      if(roi_threshold_pct >= 0.0 && profit_pct >= roi_threshold_pct)
         return true;
     }

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
