#property strict
#property version   "5.0"
#property description "QM5_9239 MQL5 DMA Angle Band"

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
input int    qm_ea_id                   = 9239;
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
input int    strategy_dma_period         = 34;
input int    strategy_angle_lookback     = 8;
input double strategy_entry_angle_min    = 12.0;
input double strategy_entry_angle_max    = 30.0;
input double strategy_exit_steep_angle   = 35.0;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.9;
input double strategy_take_rr            = 2.1;
input int    strategy_max_hold_bars      = 36;

bool ReadCloseWindow(const int shift, const int count, double &closes[])
  {
   if(shift < 0 || count <= 0)
      return false;
   ArrayResize(closes, count);
   ArraySetAsSeries(closes, false);
   const int copied = CopyClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift, count, closes); // perf-allowed: bounded DMA sample inside closed-bar strategy logic.
   return (copied == count);
  }

double ClosedClose(const int shift)
  {
   double close_buf[];
   if(!ReadCloseWindow(shift, 1, close_buf))
      return 0.0;
   return close_buf[0];
  }

double DecayingMA(const int shift)
  {
   if(strategy_dma_period <= 1)
      return 0.0;

   double closes[];
   if(!ReadCloseWindow(shift, strategy_dma_period, closes))
      return 0.0;

   double weighted_sum = 0.0;
   double weight_sum = 0.0;
   for(int i = 0; i < strategy_dma_period; ++i)
     {
      const double weight = 1.0 / MathPow(2.0, (double)(strategy_dma_period - i));
      weighted_sum += closes[i] * weight;
      weight_sum += weight;
     }

   if(weight_sum <= 0.0)
      return 0.0;
   return weighted_sum / weight_sum;
  }

double DMAAngle(const int shift)
  {
   if(strategy_angle_lookback <= 1)
      return 0.0;

   const double dma_now = DecayingMA(shift);
   const double dma_prior = DecayingMA(shift + strategy_angle_lookback);
   if(dma_now <= 0.0 || dma_prior <= 0.0)
      return 0.0;

   double range_max = DecayingMA(shift + strategy_angle_lookback + 1);
   double range_min = range_max;
   if(range_max <= 0.0)
      return 0.0;

   for(int i = shift + strategy_angle_lookback + 2; i < shift + (2 * strategy_angle_lookback); ++i)
     {
      const double dma = DecayingMA(i);
      if(dma <= 0.0)
         return 0.0;
      if(dma > range_max)
         range_max = dma;
      if(dma < range_min)
         range_min = dma;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double time_base = MathMax(point, range_max - range_min);
   if(time_base <= 0.0)
      return 0.0;

   const double price_delta = dma_now - dma_prior;
   double angle = (180.0 / 3.14159265358979323846) * MathArctan(MathAbs(price_delta) / time_base);
   if(price_delta < 0.0)
      angle *= -1.0;
   return angle;
  }

bool FindOurPosition(ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
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

   if(strategy_entry_angle_min < 0.0 ||
      strategy_entry_angle_max <= strategy_entry_angle_min ||
      strategy_exit_steep_angle <= strategy_entry_angle_max ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_take_rr <= 0.0)
      return false;

   const double angle = DMAAngle(1);
   const double dma = DecayingMA(1);
   const double close_price = ClosedClose(1);
   if(dma <= 0.0 || close_price <= 0.0)
      return false;

   QM_OrderType order_type = QM_BUY;
   bool signal = false;
   if(angle >= strategy_entry_angle_min && angle <= strategy_entry_angle_max && close_price > dma)
     {
      order_type = QM_BUY;
      signal = true;
     }
   else if(angle <= -strategy_entry_angle_min && angle >= -strategy_entry_angle_max && close_price < dma)
     {
      order_type = QM_SELL;
      signal = true;
     }

   if(!signal)
      return false;

   const double entry = QM_OrderTypeIsBuy(order_type) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, order_type, entry, atr, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, order_type, entry, req.sl, strategy_take_rr);
   req.reason = QM_OrderTypeIsBuy(order_type) ? "DMA_ANGLE_BAND_LONG" : "DMA_ANGLE_BAND_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, break-even, or scale-in logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time = 0;
   if(!FindOurPosition(position_type, open_time))
      return false;

   if(strategy_max_hold_bars > 0 && open_time > 0)
     {
      const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(period_seconds > 0 && (TimeCurrent() - open_time) >= (strategy_max_hold_bars * period_seconds))
         return true;
     }

   const double angle = DMAAngle(1);
   if(position_type == POSITION_TYPE_BUY)
      return (angle < 0.0 || angle > strategy_exit_steep_angle);
   if(position_type == POSITION_TYPE_SELL)
      return (angle > 0.0 || angle < -strategy_exit_steep_angle);

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
