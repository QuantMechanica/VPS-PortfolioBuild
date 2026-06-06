#property strict
#property version   "5.0"
#property description "QM5_10924 Grimes MAC Spike Breakout"

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
input int    qm_ea_id                   = 10924;
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
input int    strategy_return_std_period       = 20;
input double strategy_mac_entry_threshold     = 2.0;
input double strategy_mac_exit_threshold      = 1.5;
input int    strategy_breakout_lookback       = 20;
input int    strategy_consolidation_lookback  = 10;
input int    strategy_consolidation_min_closes = 5;
input double strategy_consolidation_atr_mult  = 1.5;
input int    strategy_atr_period              = 20;
input double strategy_stop_atr_buffer         = 0.25;
input double strategy_max_stop_atr_mult       = 4.0;
input int    strategy_ema_period              = 20;
input double strategy_max_ema_atr_distance    = 3.5;
input double strategy_tp_rr                   = 2.0;
input double strategy_be_trigger_rr           = 1.0;
input int    strategy_max_hold_bars           = 20;
input double strategy_spread_stop_fraction    = 0.10;

bool g_strategy_exit_due = false;

double Strategy_Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 card math, called from closed-bar hook.
  }

double Strategy_High(const int shift)
  {
   return iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 consolidation stop structure.
  }

double Strategy_Low(const int shift)
  {
   return iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 consolidation stop structure.
  }

bool Strategy_SelectPosition(ENUM_POSITION_TYPE &ptype,
                             double &open_price,
                             double &sl,
                             ulong &ticket,
                             datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   ticket = 0;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      ticket = t;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_MacSpike(double &mac_spike)
  {
   mac_spike = 0.0;
   if(strategy_return_std_period < 2)
      return false;

   const double c1 = Strategy_Close(1);
   const double c2 = Strategy_Close(2);
   if(c1 <= 0.0 || c2 <= 0.0)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;
   for(int shift = 2; shift < 2 + strategy_return_std_period; ++shift)
     {
      const double c_now = Strategy_Close(shift);
      const double c_prev = Strategy_Close(shift + 1);
      if(c_now <= 0.0 || c_prev <= 0.0)
         return false;

      const double ret = c_now - c_prev;
      sum += ret;
      sum_sq += ret * ret;
      samples++;
     }

   if(samples < strategy_return_std_period)
      return false;

   const double mean = sum / samples;
   double variance = (sum_sq / samples) - (mean * mean);
   if(variance < 0.0 && variance > -1e-12)
      variance = 0.0;
   if(variance <= 0.0)
      return false;

   mac_spike = (c1 - c2) / MathSqrt(variance);
   return true;
  }

bool Strategy_Breakout(const bool want_long)
  {
   if(strategy_breakout_lookback < 1)
      return false;

   const double close_last = Strategy_Close(1);
   if(close_last <= 0.0)
      return false;

   double boundary = want_long ? -DBL_MAX : DBL_MAX;
   for(int shift = 2; shift <= 1 + strategy_breakout_lookback; ++shift)
     {
      const double c = Strategy_Close(shift);
      if(c <= 0.0)
         return false;
      if(want_long)
         boundary = MathMax(boundary, c);
      else
         boundary = MathMin(boundary, c);
     }

   return want_long ? (close_last > boundary) : (close_last < boundary);
  }

bool Strategy_Consolidation(double &consolidation_low,
                            double &consolidation_high,
                            const double atr_value)
  {
   consolidation_low = DBL_MAX;
   consolidation_high = -DBL_MAX;
   if(strategy_consolidation_lookback < strategy_consolidation_min_closes ||
      strategy_consolidation_min_closes < 2 ||
      atr_value <= 0.0 ||
      strategy_consolidation_atr_mult <= 0.0)
      return false;

   double closes[];
   ArrayResize(closes, strategy_consolidation_lookback);
   for(int idx = 0; idx < strategy_consolidation_lookback; ++idx)
     {
      const int shift = 2 + idx;
      const double c = Strategy_Close(shift);
      const double h = Strategy_High(shift);
      const double l = Strategy_Low(shift);
      if(c <= 0.0 || h <= 0.0 || l <= 0.0)
         return false;

      closes[idx] = c;
      consolidation_low = MathMin(consolidation_low, l);
      consolidation_high = MathMax(consolidation_high, h);
     }

   const double allowed_range = strategy_consolidation_atr_mult * atr_value;
   for(int anchor = 0; anchor < strategy_consolidation_lookback; ++anchor)
     {
      int count = 0;
      const double lower = closes[anchor];
      const double upper = lower + allowed_range;
      for(int j = 0; j < strategy_consolidation_lookback; ++j)
        {
         if(closes[j] >= lower && closes[j] <= upper)
            count++;
        }
      if(count >= strategy_consolidation_min_closes)
         return true;
     }

   return false;
  }

void Strategy_UpdateExitState()
  {
   g_strategy_exit_due = false;

   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   ulong ticket;
   datetime open_time;
   if(!Strategy_SelectPosition(ptype, open_price, sl, ticket, open_time))
      return;

   if(strategy_max_hold_bars > 0 && open_time > 0)
     {
      const int open_shift = iBarShift(_Symbol, PERIOD_D1, open_time, false); // perf-allowed: one D1 bar age lookup on closed-bar hook.
      if(open_shift >= strategy_max_hold_bars)
        {
         g_strategy_exit_due = true;
         return;
        }
     }

   double mac_spike = 0.0;
   if(!Strategy_MacSpike(mac_spike))
      return;

   if(ptype == POSITION_TYPE_BUY && mac_spike <= -strategy_mac_exit_threshold)
      g_strategy_exit_due = true;
   if(ptype == POSITION_TYPE_SELL && mac_spike >= strategy_mac_exit_threshold)
      g_strategy_exit_due = true;
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
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_UpdateExitState();

   ENUM_POSITION_TYPE ptype;
   double open_price;
   double current_sl;
   ulong ticket;
   datetime open_time;
   if(Strategy_SelectPosition(ptype, open_price, current_sl, ticket, open_time))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   const double close_last = Strategy_Close(1);
   if(atr <= 0.0 || ema <= 0.0 || close_last <= 0.0)
      return false;

   if(MathAbs(close_last - ema) > strategy_max_ema_atr_distance * atr)
      return false;

   double mac_spike = 0.0;
   if(!Strategy_MacSpike(mac_spike))
      return false;

   const bool long_setup = (mac_spike >= strategy_mac_entry_threshold && Strategy_Breakout(true));
   const bool short_setup = (mac_spike <= -strategy_mac_entry_threshold && Strategy_Breakout(false));
   if(!long_setup && !short_setup)
      return false;

   double consolidation_low = 0.0;
   double consolidation_high = 0.0;
   if(!Strategy_Consolidation(consolidation_low, consolidation_high, atr))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const bool is_long = long_setup;
   const QM_OrderType side = is_long ? QM_BUY : QM_SELL;
   const double entry = is_long ? ask : bid;
   const double raw_sl = is_long ? (consolidation_low - strategy_stop_atr_buffer * atr)
                                 : (consolidation_high + strategy_stop_atr_buffer * atr);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0)
      return false;
   if(is_long && sl >= entry)
      return false;
   if(!is_long && sl <= entry)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr_mult * atr)
      return false;

   const double spread = ask - bid;
   if(strategy_spread_stop_fraction > 0.0 && spread > strategy_spread_stop_fraction * stop_distance)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = is_long ? "GRIMES_MAC_SPIKE_LONG" : "GRIMES_MAC_SPIKE_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   ulong ticket;
   datetime open_time;
   if(!Strategy_SelectPosition(ptype, open_price, sl, ticket, open_time))
      return;

   if(open_price <= 0.0 || sl <= 0.0 || strategy_be_trigger_rr <= 0.0)
      return;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double current_price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(current_price <= 0.0)
      return;

   const double initial_risk = MathAbs(open_price - sl);
   if(initial_risk <= 0.0)
      return;

   const double moved = is_long ? (current_price - open_price)
                                : (open_price - current_price);
   if(moved < strategy_be_trigger_rr * initial_risk)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const bool improves = is_long ? (sl < open_price - point * 0.5)
                                 : (sl > open_price + point * 0.5);
   if(improves)
      QM_TM_MoveSL(ticket, open_price, "grimes_mac_spike_be_1r");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_strategy_exit_due)
      return false;

   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   ulong ticket;
   datetime open_time;
   if(!Strategy_SelectPosition(ptype, open_price, sl, ticket, open_time))
     {
      g_strategy_exit_due = false;
      return false;
     }

   return true;
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
