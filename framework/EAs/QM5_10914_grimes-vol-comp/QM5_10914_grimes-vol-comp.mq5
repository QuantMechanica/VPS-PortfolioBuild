#property strict
#property version   "5.0"
#property description "QM5_10914 Grimes Volatility Compression Breakout"

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
input int    qm_ea_id                   = 10914;
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
input int    strategy_fast_atr_period         = 5;
input int    strategy_slow_atr_period         = 60;
input int    strategy_entry_atr_period        = 14;
input int    strategy_compression_lookback    = 5;
input int    strategy_compression_min_bars    = 3;
input double strategy_compression_ratio       = 0.75;
input int    strategy_range_lookback_bars     = 20;
input double strategy_range_atr_mult          = 1.25;
input double strategy_breakout_atr_mult       = 0.10;
input double strategy_stop_atr_mult           = 1.20;
input double strategy_min_stop_atr_mult       = 0.80;
input double strategy_target_r_mult           = 1.50;
input double strategy_trail_atr_mult          = 2.00;
input double strategy_spread_stop_frac        = 0.10;
input int    strategy_time_exit_bars          = 20;

ulong  g_strategy_ticket = 0;
double g_strategy_initial_r = 0.0;
bool   g_strategy_target1_done = false;

double StrategyNormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = _Digits;
   return NormalizeDouble(price, digits);
  }

void StrategyInitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool StrategyFindPosition(ulong &ticket,
                          ENUM_POSITION_TYPE &ptype,
                          double &open_price,
                          double &current_sl,
                          double &lots,
                          datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   lots = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl = PositionGetDouble(POSITION_SL);
      lots = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool StrategyHasOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double current_sl;
   double lots;
   datetime open_time;
   return StrategyFindPosition(ticket, ptype, open_price, current_sl, lots, open_time);
  }

bool StrategyInputsValid()
  {
   return (strategy_fast_atr_period >= 2 &&
           strategy_slow_atr_period > strategy_fast_atr_period &&
           strategy_entry_atr_period >= 2 &&
           strategy_compression_lookback >= 1 &&
           strategy_compression_min_bars >= 1 &&
           strategy_compression_min_bars <= strategy_compression_lookback &&
           strategy_compression_ratio > 0.0 &&
           strategy_range_lookback_bars >= 2 &&
           strategy_range_atr_mult > 0.0 &&
           strategy_breakout_atr_mult >= 0.0 &&
           strategy_stop_atr_mult > 0.0 &&
           strategy_min_stop_atr_mult > 0.0 &&
           strategy_target_r_mult > 0.0 &&
           strategy_trail_atr_mult > 0.0 &&
           strategy_spread_stop_frac >= 0.0 &&
           strategy_time_exit_bars > 0);
  }

bool StrategyCompressionActive()
  {
   int compressed = 0;
   for(int shift = 2; shift < 2 + strategy_compression_lookback; ++shift)
     {
      const double fast_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_atr_period, shift);
      const double slow_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_atr_period, shift);
      if(fast_atr > 0.0 && slow_atr > 0.0 && (fast_atr / slow_atr) < strategy_compression_ratio)
         compressed++;
     }
   return (compressed >= strategy_compression_min_bars);
  }

bool StrategyPriorRange(const MqlRates &rates[], double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;
   for(int shift = 2; shift <= strategy_range_lookback_bars + 1; ++shift)
     {
      range_high = MathMax(range_high, rates[shift].high);
      range_low = MathMin(range_low, rates[shift].low);
     }
   return (range_high > -DBL_MAX && range_low < DBL_MAX && range_high > range_low);
  }

bool StrategySpreadAllowed(const double stop_distance)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || stop_distance <= 0.0)
      return false;
   return ((ask - bid) <= strategy_spread_stop_frac * stop_distance);
  }

double StrategyInitialStopDistance(const double entry,
                                   const double opposite_range_side,
                                   const double atr)
  {
   if(entry <= 0.0 || opposite_range_side <= 0.0 || atr <= 0.0)
      return 0.0;
   const double structure_dist = MathAbs(entry - opposite_range_side);
   const double closer_dist = MathMin(structure_dist, strategy_stop_atr_mult * atr);
   return MathMax(closer_dist, strategy_min_stop_atr_mult * atr);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0 || ask <= bid);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   StrategyInitRequest(req);

   if(!StrategyInputsValid() || StrategyHasOpenPosition())
      return false;

   const int need_bars = strategy_range_lookback_bars + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, need_bars, rates); // perf-allowed: bounded closed-bar structural scan for the card's 20-bar compression range.
   if(copied < need_bars)
      return false;

   if(!StrategyCompressionActive())
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!StrategyPriorRange(rates, range_high, range_low))
      return false;

   const double slow_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_atr_period, 2);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_entry_atr_period, 1);
   if(slow_atr <= 0.0 || atr <= 0.0)
      return false;

   if((range_high - range_low) > strategy_range_atr_mult * slow_atr)
      return false;

   const double close1 = rates[1].close;
   const double breakout_buffer = strategy_breakout_atr_mult * atr;

   if(close1 > range_high + breakout_buffer)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double stop_distance = StrategyInitialStopDistance(entry, range_low, atr);
      if(!StrategySpreadAllowed(stop_distance))
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = StrategyNormalizePrice(entry - stop_distance);
      req.tp = 0.0;
      req.reason = "GRIMES_VOL_COMP_LONG";
      return (req.sl > 0.0 && req.sl < entry);
     }

   if(close1 < range_low - breakout_buffer)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double stop_distance = StrategyInitialStopDistance(entry, range_high, atr);
      if(!StrategySpreadAllowed(stop_distance))
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = StrategyNormalizePrice(entry + stop_distance);
      req.tp = 0.0;
      req.reason = "GRIMES_VOL_COMP_SHORT";
      return (req.sl > entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double current_sl;
   double lots;
   datetime open_time;
   if(!StrategyFindPosition(ticket, ptype, open_price, current_sl, lots, open_time))
     {
      g_strategy_ticket = 0;
      g_strategy_initial_r = 0.0;
      g_strategy_target1_done = false;
      return;
     }

   if(ticket != g_strategy_ticket)
     {
      g_strategy_ticket = ticket;
      g_strategy_initial_r = (current_sl > 0.0) ? MathAbs(open_price - current_sl) : 0.0;
      g_strategy_target1_done = false;
     }

   if(g_strategy_initial_r <= 0.0 || open_price <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(!g_strategy_target1_done && moved >= strategy_target_r_mult * g_strategy_initial_r)
     {
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(min_lot > 0.0 && lots >= min_lot * 2.0)
        {
         if(QM_TM_PartialClose(ticket, lots * 0.5, QM_EXIT_PARTIAL))
            g_strategy_target1_done = true;
        }
      else
         g_strategy_target1_done = true;
     }

   if(!g_strategy_target1_done)
      return;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      return;
   int bars_since_open = (int)((TimeCurrent() - open_time) / period_seconds) + 3;
   bars_since_open = MathMax(3, MathMin(strategy_time_exit_bars + 3, bars_since_open));

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_since_open, rates); // perf-allowed: bounded post-target Chandelier scan, capped by the 20-bar time exit.
   if(copied < 2)
      return;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_entry_atr_period, 1);
   if(atr <= 0.0)
      return;

   double anchor = is_buy ? -DBL_MAX : DBL_MAX;
   for(int i = 1; i < copied; ++i)
     {
      if(rates[i].time < open_time)
         continue;
      if(is_buy)
         anchor = MathMax(anchor, rates[i].close);
      else
         anchor = MathMin(anchor, rates[i].close);
     }
   if((is_buy && anchor <= -DBL_MAX) || (!is_buy && anchor >= DBL_MAX))
      return;

   const double trail_sl = is_buy ? StrategyNormalizePrice(anchor - strategy_trail_atr_mult * atr)
                                  : StrategyNormalizePrice(anchor + strategy_trail_atr_mult * atr);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || trail_sl <= 0.0)
      return;

   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (trail_sl > current_sl + point * 0.5)
                                 : (trail_sl < current_sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, trail_sl, "grimes_chandelier_after_target1");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_time_exit_bars <= 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && (TimeCurrent() - open_time) >= strategy_time_exit_bars * period_seconds)
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
