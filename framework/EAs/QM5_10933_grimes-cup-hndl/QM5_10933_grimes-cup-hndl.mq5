#property strict
#property version   "5.0"
#property description "QM5_10933 Grimes Cup Handle Breakout"

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
input int    qm_ea_id                   = 10933;
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
input int    strategy_atr_period             = 20;
input int    strategy_w1_ema_period          = 20;
input int    strategy_w1_slope_bars          = 5;
input int    strategy_base_min_bars          = 15;
input int    strategy_base_max_bars          = 60;
input int    strategy_handle_min_bars        = 3;
input int    strategy_handle_max_bars        = 15;
input double strategy_rim_atr_tolerance      = 1.0;
input double strategy_breakout_atr_buffer    = 0.10;
input double strategy_max_handle_pullback    = 0.50;
input double strategy_stop_atr_buffer        = 0.25;
input double strategy_max_stop_atr           = 3.50;
input double strategy_overextension_atr      = 3.00;
input double strategy_target_r               = 2.00;
input double strategy_breakeven_r            = 1.00;
input double strategy_failure_trigger_r      = 0.75;
input int    strategy_failure_bars           = 3;
input int    strategy_time_exit_bars         = 20;
input double strategy_max_spread_stop_frac   = 0.10;

double   g_pending_signal_rim        = 0.0;
double   g_pending_signal_risk       = 0.0;
int      g_pending_signal_direction  = 0;
ulong    g_active_ticket             = 0;
double   g_active_rim                = 0.0;
double   g_active_initial_risk       = 0.0;
int      g_active_direction          = 0;
bool     g_active_reached_failure_r  = false;
datetime g_active_failure_start_time = 0;

void ResetActiveState()
  {
   g_active_ticket = 0;
   g_active_rim = 0.0;
   g_active_initial_risk = 0.0;
   g_active_direction = 0;
   g_active_reached_failure_r = false;
   g_active_failure_start_time = 0;
  }

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool SelectOurPosition(ulong &ticket,
                       ENUM_POSITION_TYPE &position_type,
                       double &open_price,
                       double &sl,
                       double &tp,
                       datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double LowestLow(const MqlRates &rates[], const int first_idx, const int last_idx, int &low_idx)
  {
   double result = DBL_MAX;
   low_idx = -1;
   for(int i = first_idx; i <= last_idx; ++i)
     {
      if(rates[i].low < result)
        {
         result = rates[i].low;
         low_idx = i;
        }
     }
   return result;
  }

double HighestHigh(const MqlRates &rates[], const int first_idx, const int last_idx, int &high_idx)
  {
   double result = -DBL_MAX;
   high_idx = -1;
   for(int i = first_idx; i <= last_idx; ++i)
     {
      if(rates[i].high > result)
        {
         result = rates[i].high;
         high_idx = i;
        }
     }
   return result;
  }

bool W1TrendAllows(const int direction)
  {
   const double ema_recent = QM_EMA(_Symbol, PERIOD_W1, strategy_w1_ema_period, 1);
   const double ema_prior = QM_EMA(_Symbol, PERIOD_W1, strategy_w1_ema_period, 1 + strategy_w1_slope_bars);
   if(ema_recent <= 0.0 || ema_prior <= 0.0)
      return false;
   return (direction > 0) ? (ema_recent > ema_prior) : (ema_recent < ema_prior);
  }

bool FindCupHandlePattern(const int direction,
                          double &rim,
                          double &handle_extreme,
                          double &breakout_close,
                          double &atr)
  {
   rim = 0.0;
   handle_extreme = 0.0;
   breakout_close = 0.0;
   atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0 || !W1TrendAllows(direction))
      return false;

   const int min_needed = strategy_base_max_bars + strategy_handle_max_bars + 4;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, min_needed, rates); // perf-allowed: bounded D1 structural cup/handle geometry, EntrySignal is called only after QM_IsNewBar().
   if(copied < strategy_base_min_bars + strategy_handle_min_bars + 4)
      return false;

   breakout_close = rates[0].close;
   const double ema_d1 = QM_EMA(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ema_d1 <= 0.0 || MathAbs(breakout_close - ema_d1) > strategy_overextension_atr * atr)
      return false;

   for(int handle_len = strategy_handle_min_bars; handle_len <= strategy_handle_max_bars; ++handle_len)
     {
      const int right_idx = handle_len + 1;
      if(right_idx + strategy_base_min_bars >= copied)
         continue;

      int handle_idx = -1;
      const double handle_low = LowestLow(rates, 1, handle_len, handle_idx);
      const double handle_high = HighestHigh(rates, 1, handle_len, handle_idx);

      for(int base_len = strategy_base_min_bars; base_len <= strategy_base_max_bars; ++base_len)
        {
         const int left_idx = right_idx + base_len - 1;
         if(left_idx >= copied)
            break;

         if(direction > 0)
           {
            const double left_rim = rates[left_idx].high;
            const double right_rim = rates[right_idx].high;
            if(left_rim <= 0.0 || right_rim <= 0.0)
               continue;
            if(MathAbs(left_rim - right_rim) > strategy_rim_atr_tolerance * atr)
               continue;

            int base_low_idx = -1;
            const double base_low = LowestLow(rates, right_idx, left_idx, base_low_idx);
            if(base_low_idx > left_idx - 5 || base_low_idx < right_idx + 5)
               continue;

            const double rim_high = MathMax(left_rim, right_rim);
            const double base_depth = rim_high - base_low;
            const double handle_pullback = right_rim - handle_low;
            if(base_depth <= 0.0 || handle_pullback < 0.0)
               continue;
            if(handle_pullback > strategy_max_handle_pullback * base_depth)
               continue;
            if(breakout_close <= right_rim + strategy_breakout_atr_buffer * atr)
               continue;

            rim = right_rim;
            handle_extreme = handle_low;
            return true;
           }
         else
           {
            const double left_rim = rates[left_idx].low;
            const double right_rim = rates[right_idx].low;
            if(left_rim <= 0.0 || right_rim <= 0.0)
               continue;
            if(MathAbs(left_rim - right_rim) > strategy_rim_atr_tolerance * atr)
               continue;

            int base_high_idx = -1;
            const double base_high = HighestHigh(rates, right_idx, left_idx, base_high_idx);
            if(base_high_idx > left_idx - 5 || base_high_idx < right_idx + 5)
               continue;

            const double rim_low = MathMin(left_rim, right_rim);
            const double base_depth = base_high - rim_low;
            const double handle_pullback = handle_high - right_rim;
            if(base_depth <= 0.0 || handle_pullback < 0.0)
               continue;
            if(handle_pullback > strategy_max_handle_pullback * base_depth)
               continue;
            if(breakout_close >= right_rim - strategy_breakout_atr_buffer * atr)
               continue;

            rim = right_rim;
            handle_extreme = handle_high;
            return true;
           }
        }
     }

   return false;
  }

bool BuildEntryForDirection(const int direction, QM_EntryRequest &req)
  {
   double rim = 0.0;
   double handle_extreme = 0.0;
   double close_price = 0.0;
   double atr = 0.0;
   if(!FindCupHandlePattern(direction, rim, handle_extreme, close_price, atr))
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return false;

   const double entry = (direction > 0) ? ask : bid;
   const double sl = (direction > 0)
                     ? (handle_extreme - strategy_stop_atr_buffer * atr)
                     : (handle_extreme + strategy_stop_atr_buffer * atr);
   const double risk = MathAbs(entry - sl);
   if(risk <= 0.0 || risk > strategy_max_stop_atr * atr)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_max_spread_stop_frac * risk)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = (direction > 0) ? (entry + strategy_target_r * risk) : (entry - strategy_target_r * risk);
   req.reason = (direction > 0) ? "grimes_cup_handle_long" : "grimes_cup_handle_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_pending_signal_rim = rim;
   g_pending_signal_risk = risk;
   g_pending_signal_direction = direction;
   return true;
  }

int CountFailureClosesAfterStart(const int direction,
                                 const double rim,
                                 const datetime start_time,
                                 int &bars_seen)
  {
   bars_seen = 0;
   if(rim <= 0.0 || start_time <= 0)
      return 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 12, rates); // perf-allowed: bounded exit check over recent D1 closes only while a position is open.
   if(copied <= 0)
      return 0;

   int failed = 0;
   for(int i = copied - 1; i >= 0; --i)
     {
      if(rates[i].time <= start_time)
         continue;
      bars_seen++;
      const bool beyond_rim = (direction > 0) ? (rates[i].close > rim) : (rates[i].close < rim);
      if(!beyond_rim)
         failed++;
      if(bars_seen >= strategy_failure_bars)
         break;
     }

   return failed;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitEntryRequest(req);

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   datetime open_time = 0;
   if(SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return false;

   if(BuildEntryForDirection(1, req))
      return true;
   if(BuildEntryForDirection(-1, req))
      return true;

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   datetime open_time = 0;
   if(!SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
     {
      ResetActiveState();
      return;
     }

   const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
   if(ticket != g_active_ticket)
     {
      g_active_ticket = ticket;
      g_active_direction = direction;
      g_active_initial_risk = (sl > 0.0) ? MathAbs(open_price - sl) : g_pending_signal_risk;
      g_active_rim = (g_pending_signal_direction == direction) ? g_pending_signal_rim : 0.0;
      g_active_reached_failure_r = false;
      g_active_failure_start_time = 0;
     }

   if(g_active_initial_risk <= 0.0)
      g_active_initial_risk = (sl > 0.0) ? MathAbs(open_price - sl) : 0.0;
   if(g_active_initial_risk <= 0.0)
      return;

   const double market_price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const double move_r = (direction > 0) ? (market_price - open_price) / g_active_initial_risk
                                         : (open_price - market_price) / g_active_initial_risk;
   if(move_r >= strategy_breakeven_r)
     {
      const bool improves = (sl <= 0.0) ||
                            (direction > 0 ? (sl < open_price) : (sl > open_price));
      if(improves)
         QM_TM_MoveSL(ticket, open_price, "grimes_break_even_1R");
     }

   if(!g_active_reached_failure_r && move_r >= strategy_failure_trigger_r)
     {
      g_active_reached_failure_r = true;
      g_active_failure_start_time = TimeCurrent();
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   datetime open_time = 0;
   if(!SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return false;

   if(strategy_time_exit_bars > 0 &&
      open_time > 0 &&
      TimeCurrent() - open_time >= strategy_time_exit_bars * PeriodSeconds(PERIOD_D1))
      return true;

   if(ticket == g_active_ticket &&
      g_active_reached_failure_r &&
      strategy_failure_bars > 0 &&
      g_active_rim > 0.0)
     {
      int bars_seen = 0;
      const int failed = CountFailureClosesAfterStart(g_active_direction,
                                                      g_active_rim,
                                                      g_active_failure_start_time,
                                                      bars_seen);
      if(bars_seen >= strategy_failure_bars && failed >= strategy_failure_bars)
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
