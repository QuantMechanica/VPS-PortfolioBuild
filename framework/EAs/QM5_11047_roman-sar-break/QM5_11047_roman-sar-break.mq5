#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 11047;
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
input double strategy_sar_step                = 0.02;
input double strategy_sar_maximum             = 0.20;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 1.50;
input double strategy_tp_sl_ratio             = 1.00;
input int    strategy_max_bars_in_trade       = 24;
input int    strategy_atr_percentile_lookback = 100;
input double strategy_atr_min_percentile      = 20.0;
input int    strategy_median_spread_points    = 20;
input double strategy_spread_limit_mult       = 2.0;
input bool   strategy_session_filter_enabled  = false;
input int    strategy_session_start_hour      = 7;
input int    strategy_session_end_hour        = 21;
input bool   strategy_breakeven_enabled       = true;
input double strategy_breakeven_rr            = 0.75;
input int    strategy_breakeven_buffer_points = 2;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int Strategy_SARHandle()
  {
   const string key = StringFormat("SAR|%s|%d|%.5f|%.5f",
                                   _Symbol,
                                   (int)PERIOD_H1,
                                   strategy_sar_step,
                                   strategy_sar_maximum);
   int handle = QM_IndicatorsLookup(key);
   if(handle != INVALID_HANDLE)
      return handle;

   handle = iSAR(_Symbol, PERIOD_H1, strategy_sar_step, strategy_sar_maximum);
   return QM_IndicatorsRegister(key, handle);
  }

double Strategy_SAR(const int shift)
  {
   return QM_IndicatorReadBuffer(Strategy_SARHandle(), 0, shift);
  }

bool Strategy_ReadOpen(const int shift, double &open_price)
  {
   open_price = 0.0;
   double values[];
   ArraySetAsSeries(values, true);
   const int copied = CopyOpen(_Symbol, PERIOD_H1, shift, 1, values); // perf-allowed
   if(copied != 1)
      return false;
   open_price = values[0];
   return (open_price > 0.0);
  }

int Strategy_SAROpenSignal()
  {
   const double sar_recent = Strategy_SAR(1);
   const double sar_older  = Strategy_SAR(2);
   double open_recent = 0.0;
   double open_older  = 0.0;
   if(sar_recent <= 0.0 || sar_older <= 0.0)
      return 0;
   if(!Strategy_ReadOpen(1, open_recent) || !Strategy_ReadOpen(2, open_older))
      return 0;

   const bool short_signal = (sar_recent < open_recent && sar_older > open_older);
   const bool long_signal  = (sar_recent > open_recent && sar_older < open_older);
   if(long_signal && !short_signal)
      return 1;
   if(short_signal && !long_signal)
      return -1;
   return 0;
  }

bool Strategy_ATRPassesFilter()
  {
   if(strategy_atr_percentile_lookback <= 1 || strategy_atr_min_percentile <= 0.0)
      return true;

   const double current_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   double samples[];
   ArrayResize(samples, strategy_atr_percentile_lookback);
   int sample_count = 0;
   for(int shift = 1; shift <= strategy_atr_percentile_lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      samples[sample_count] = atr;
      sample_count++;
     }

   if(sample_count < 10)
      return true;

   ArrayResize(samples, sample_count);
   ArraySort(samples);
   double pct = strategy_atr_min_percentile;
   if(pct < 0.0)
      pct = 0.0;
   if(pct > 100.0)
      pct = 100.0;

   int idx = (int)MathFloor((pct / 100.0) * (double)(sample_count - 1));
   if(idx < 0)
      idx = 0;
   if(idx >= sample_count)
      idx = sample_count - 1;

   return (current_atr >= samples[idx]);
  }

bool Strategy_SessionAllowsTrade()
  {
   if(!strategy_session_filter_enabled)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_hour = strategy_session_start_hour;
   const int end_hour = strategy_session_end_hour;
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (dt.hour >= start_hour && dt.hour < end_hour);
   return (dt.hour >= start_hour || dt.hour < end_hour);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_median_spread_points > 0 && strategy_spread_limit_mult > 0.0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      const double max_spread = (double)strategy_median_spread_points * strategy_spread_limit_mult;
      if((double)spread_points > max_spread)
         return true;
     }

   if(!Strategy_SessionAllowsTrade())
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!Strategy_ATRPassesFilter())
      return false;

   const int signal = Strategy_SAROpenSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry_price = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry_price, sl, strategy_tp_sl_ratio);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry_price;
   req.sl = sl;
   req.tp = tp;
   req.reason = (signal > 0) ? "sar_open_cross_long" : "sar_open_cross_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_breakeven_enabled || strategy_breakeven_rr <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - current_sl);
      if(risk_distance <= 0.0)
         continue;

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double favorable_move = is_buy ? (market_price - open_price)
                                           : (open_price - market_price);
      if(favorable_move < risk_distance * strategy_breakeven_rr)
         continue;

      const double buffer = (double)strategy_breakeven_buffer_points * point;
      const double target_sl = is_buy ? (open_price + buffer) : (open_price - buffer);
      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(!improves)
         continue;

      QM_TM_MoveSL(ticket, target_sl, "sar_break_breakeven_075r");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int signal = Strategy_SAROpenSignal();
   if(signal != 0)
      return true;

   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds(PERIOD_H1);
   if(strategy_max_bars_in_trade <= 0 || period_seconds <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at <= 0)
         continue;

      if((TimeCurrent() - opened_at) >= strategy_max_bars_in_trade * period_seconds)
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
