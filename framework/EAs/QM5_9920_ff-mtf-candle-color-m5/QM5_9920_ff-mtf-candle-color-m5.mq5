#property strict
#property version   "5.0"
#property description "QM5_9920 ForexFactory MTF Candle Color Scalper M5"

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
input int    qm_ea_id                   = 9920;
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
input int    strategy_atr_period             = 14;
input int    strategy_atr_percentile_lookback = 60;
input double strategy_atr_min_percentile     = 25.0;
input int    strategy_fixed_sl_pips          = 15;
input double strategy_min_sl_atr_mult        = 0.8;
input double strategy_max_sl_atr_mult        = 2.0;
input int    strategy_base_tp_pips           = 15;
input double strategy_tp_rr                  = 1.2;
input int    strategy_extend_trigger_pips    = 12;
input int    strategy_extended_tp_pips       = 20;
input int    strategy_min_same_dir_gap_bars  = 3;
input int    strategy_time_stop_bars         = 12;
input int    strategy_session_start_hour     = 7;
input int    strategy_session_end_hour       = 16;
input int    strategy_max_spread_points      = 35;

int g_bars_since_long_entry = 100000;
int g_bars_since_short_entry = 100000;

double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

int CandleColor(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const double open_price = iOpen(_Symbol, tf, shift);   // perf-allowed: bounded OHLC candle-color read, closed-bar gated by framework
   const double close_price = iClose(_Symbol, tf, shift); // perf-allowed: bounded OHLC candle-color read, closed-bar gated by framework
   if(open_price <= 0.0 || close_price <= 0.0)
      return 0;
   if(close_price > open_price)
      return 1;
   if(close_price < open_price)
      return -1;
   return 0;
  }

bool HigherTimeframesAligned(const int direction)
  {
   if(direction == 0)
      return false;
   return CandleColor(PERIOD_M15, 0) == direction &&
          CandleColor(PERIOD_M30, 0) == direction &&
          CandleColor(PERIOD_H1, 0) == direction;
  }

bool SessionAllowsEntry()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour));
   if(start_h <= end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread >= 0 && spread <= strategy_max_spread_points);
  }

bool VolatilityAllowsEntry()
  {
   if(strategy_atr_period <= 0 || strategy_atr_percentile_lookback < 4)
      return false;

   const double current_atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   double samples[];
   ArrayResize(samples, strategy_atr_percentile_lookback);
   int count = 0;
   for(int i = 0; i < strategy_atr_percentile_lookback; ++i)
     {
      const double value = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1 + i);
      if(value <= 0.0)
         continue;
      samples[count] = value;
      count++;
     }

   if(count < 4)
      return false;
   ArrayResize(samples, count);
   ArraySort(samples);

   const double percentile = MathMax(0.0, MathMin(100.0, strategy_atr_min_percentile));
   int index = (int)MathFloor(((double)(count - 1)) * percentile / 100.0);
   index = MathMax(0, MathMin(count - 1, index));
   return current_atr >= samples[index];
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &ptype, double &price_open, double &sl, double &tp, datetime &opened_at, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   price_open = 0.0;
   sl = 0.0;
   tp = 0.0;
   opened_at = 0;
   ticket = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      ticket = pos_ticket;
      return true;
     }
   return false;
  }

double StopDistance()
  {
   const double fixed_dist = PipDistance(strategy_fixed_sl_pips);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(fixed_dist <= 0.0 || atr <= 0.0)
      return 0.0;

   const double min_dist = strategy_min_sl_atr_mult * atr;
   const double max_dist = strategy_max_sl_atr_mult * atr;
   return MathMin(MathMax(fixed_dist, min_dist), max_dist);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Entry-only time, spread, and volatility gates are applied in EntrySignal
   // so open positions can still receive color-flip and time-stop exits.
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

   g_bars_since_long_entry = MathMin(100000, g_bars_since_long_entry + 1);
   g_bars_since_short_entry = MathMin(100000, g_bars_since_short_entry + 1);

   if(!SessionAllowsEntry() || !SpreadAllowsEntry() || !VolatilityAllowsEntry())
      return false;

   const int m5_color = CandleColor(PERIOD_M5, 1);
   if(m5_color == 0 || !HigherTimeframesAligned(m5_color))
      return false;

   if(m5_color > 0 && g_bars_since_long_entry < strategy_min_same_dir_gap_bars)
      return false;
   if(m5_color < 0 && g_bars_since_short_entry < strategy_min_same_dir_gap_bars)
      return false;

   const QM_OrderType side = (m5_color > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist = StopDistance();
   const double fixed_tp_dist = PipDistance(strategy_base_tp_pips);
   if(entry <= 0.0 || sl_dist <= 0.0 || fixed_tp_dist <= 0.0 || strategy_tp_rr <= 0.0)
      return false;

   const double tp_dist = MathMin(fixed_tp_dist, sl_dist * strategy_tp_rr);

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_dist);
   req.reason = (side == QM_BUY) ? "MTF_CANDLE_COLOR_LONG" : "MTF_CANDLE_COLOR_SHORT";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   if(side == QM_BUY)
      g_bars_since_long_entry = 0;
   else
      g_bars_since_short_entry = 0;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   double price_open;
   double sl;
   double tp;
   datetime opened_at;
   ulong ticket;
   if(!SelectOurPosition(ptype, price_open, sl, tp, opened_at, ticket))
      return;

   const int direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
   if(CandleColor(PERIOD_M5, 1) == -direction)
      return;

   const double trigger = PipDistance(strategy_extend_trigger_pips);
   const double extended = PipDistance(strategy_extended_tp_pips);
   if(trigger <= 0.0 || extended <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double current = (ptype == POSITION_TYPE_BUY) ? bid : ask;
   const double move = (ptype == POSITION_TYPE_BUY) ? (current - price_open) : (price_open - current);
   if(move < trigger)
      return;

   const QM_OrderType side = (ptype == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
   const double extended_tp = QM_StopRulesTakeFromDistance(_Symbol, side, price_open, extended);
   if(extended_tp <= 0.0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   if(tp <= 0.0 || MathAbs(tp - extended_tp) > point)
      QM_TM_MoveTP(ticket, extended_tp, "extended_tp_cap");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   double price_open;
   double sl;
   double tp;
   datetime opened_at;
   ulong ticket;
   if(!SelectOurPosition(ptype, price_open, sl, tp, opened_at, ticket))
      return false;

   const int direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
   if(CandleColor(PERIOD_M5, 1) == -direction)
      return true;

   const int seconds_per_bar = PeriodSeconds(PERIOD_M5);
   if(seconds_per_bar > 0 && strategy_time_stop_bars > 0)
     {
      const int max_seconds = seconds_per_bar * strategy_time_stop_bars;
      if((TimeCurrent() - opened_at) >= max_seconds)
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
