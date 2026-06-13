#property strict
#property version   "5.0"
#property description "QM5_1054 BigDog TMS TDI HMA H4"

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
input int    qm_ea_id                   = 1054;
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
input int    strategy_tdi_rsi_period          = 13;
input int    strategy_tdi_signal_period       = 2;
input double strategy_tdi_midline             = 50.0;
input int    strategy_hma_period              = 20;
input int    strategy_asctrend_band_points    = 30;
input int    strategy_sl_lookback_bars        = 10;
input int    strategy_sl_buffer_points        = 30;
input double strategy_rr_target               = 2.0;
input int    strategy_spread_cap_points       = 25;

double Strategy_Close(const int shift)
  {
   return QM_SMA(_Symbol, PERIOD_H4, 1, shift, PRICE_CLOSE);
  }

double Strategy_TdiGreen(const int shift)
  {
   return QM_RSI(_Symbol, PERIOD_H4, strategy_tdi_rsi_period, shift, PRICE_CLOSE);
  }

double Strategy_TdiRedSignal(const int shift)
  {
   if(strategy_tdi_signal_period <= 0)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int i = 0; i < strategy_tdi_signal_period; ++i)
     {
      const double value = Strategy_TdiGreen(shift + i);
      if(value <= 0.0)
         return 0.0;
      sum += value;
      samples++;
     }

   if(samples <= 0)
      return 0.0;
   return sum / samples;
  }

int Strategy_TdiCrossDirection()
  {
   const double green_1 = Strategy_TdiGreen(1);
   const double red_1 = Strategy_TdiRedSignal(1);
   const double green_2 = Strategy_TdiGreen(2);
   const double red_2 = Strategy_TdiRedSignal(2);
   if(green_1 <= 0.0 || red_1 <= 0.0 || green_2 <= 0.0 || red_2 <= 0.0)
      return 0;

   if(green_1 > red_1 && green_2 <= red_2)
      return 1;
   if(green_1 < red_1 && green_2 >= red_2)
      return -1;
   return 0;
  }

int Strategy_AscTrendColor(const int shift)
  {
   const double close_now = Strategy_Close(shift);
   const double close_prev = Strategy_Close(shift + 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_now <= 0.0 || close_prev <= 0.0 || point <= 0.0)
      return 0;

   const double band = strategy_asctrend_band_points * point;
   if(close_now > close_prev + band)
      return 1;
   if(close_now < close_prev - band)
      return -1;
   return 0;
  }

bool Strategy_HaveOpenPosition(ENUM_POSITION_TYPE &ptype)
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
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
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   if(strategy_spread_cap_points > 0 && spread_points > strategy_spread_cap_points)
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

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy_HaveOpenPosition(existing_type))
      return false;

   const int tdi_cross = Strategy_TdiCrossDirection();
   if(tdi_cross == 0)
      return false;

   const double green_1 = Strategy_TdiGreen(1);
   const double red_1 = Strategy_TdiRedSignal(1);
   const double close_1 = Strategy_Close(1);
   const double hma_1 = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_period, 1, PRICE_CLOSE);
   const int asc_color = Strategy_AscTrendColor(1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(green_1 <= 0.0 || red_1 <= 0.0 || close_1 <= 0.0 || hma_1 <= 0.0 || point <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(tdi_cross > 0 &&
      green_1 > strategy_tdi_midline &&
      red_1 > strategy_tdi_midline &&
      close_1 > hma_1 &&
      asc_color > 0)
     {
      const double entry = ask;
      const double structure_sl = QM_StopStructure(_Symbol, QM_BUY, entry, strategy_sl_lookback_bars);
      const double sl = (structure_sl > 0.0) ? NormalizeDouble(structure_sl - strategy_sl_buffer_points * point, _Digits) : 0.0;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_rr_target);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TMS_TDI_HMA_ASCTREND_LONG";
      return true;
     }

   if(tdi_cross < 0 &&
      green_1 < strategy_tdi_midline &&
      red_1 < strategy_tdi_midline &&
      close_1 < hma_1 &&
      asc_color < 0)
     {
      const double entry = bid;
      const double structure_sl = QM_StopStructure(_Symbol, QM_SELL, entry, strategy_sl_lookback_bars);
      const double sl = (structure_sl > 0.0) ? NormalizeDouble(structure_sl + strategy_sl_buffer_points * point, _Digits) : 0.0;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_rr_target);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TMS_TDI_HMA_ASCTREND_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!Strategy_HaveOpenPosition(ptype))
      return false;

   const int tdi_cross = Strategy_TdiCrossDirection();
   const int asc_color = Strategy_AscTrendColor(1);
   if(ptype == POSITION_TYPE_BUY)
     {
      if(tdi_cross < 0)
         return true;
      if(asc_color < 0)
         return true;
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      if(tdi_cross > 0)
         return true;
      if(asc_color > 0)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Defer to the framework news filter.
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
