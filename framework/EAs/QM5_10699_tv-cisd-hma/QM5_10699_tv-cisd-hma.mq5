#property strict
#property version   "5.0"
#property description "QM5_10699 TradingView CISD Hull Liquidity Sweep"
// rework v2 2026-06-16 — HMA filter was price-above-rising-HMA, which structurally
// contradicts a post-sweep reversal entry and vetoed ~all signals (->0 trades).
// Relaxed to a pure HMA slope-agreement check per card's "shows bullish/bearish
// condition" so the optional trend filter no longer rejects every valid sweep.

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
input int    qm_ea_id                   = 10699;
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
input int    strategy_pivot_length        = 5;      // Confirmed swing left/right bars.
input int    strategy_swing_scan_bars     = 40;     // Maximum confirmed pivot scan depth.
input int    strategy_cisd_window_bars    = 2;      // Bars allowed from sweep to CISD close.
input int    strategy_hma_period          = 55;     // 0 disables HMA filter; card tests 55/100.
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_sweep_atr_buffer    = 0.1;
input double strategy_rr_target           = 2.0;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_IsPivotHigh(const int center_shift, const int pivot_len)
  {
   const double center = iHigh(_Symbol, _Period, center_shift);
   if(center <= 0.0)
      return false;

   for(int k = 1; k <= pivot_len; ++k)
     {
      if(iHigh(_Symbol, _Period, center_shift - k) >= center)
         return false;
      if(iHigh(_Symbol, _Period, center_shift + k) > center)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotLow(const int center_shift, const int pivot_len)
  {
   const double center = iLow(_Symbol, _Period, center_shift);
   if(center <= 0.0)
      return false;

   for(int k = 1; k <= pivot_len; ++k)
     {
      if(iLow(_Symbol, _Period, center_shift - k) <= center)
         return false;
      if(iLow(_Symbol, _Period, center_shift + k) < center)
         return false;
     }
   return true;
  }

bool Strategy_FindRecentPivotHigh(double &pivot_price, int &pivot_shift)
  {
   pivot_price = 0.0;
   pivot_shift = 0;

   const int pivot_len = MathMax(2, strategy_pivot_length);
   const int max_scan = MathMax(pivot_len + 2, strategy_swing_scan_bars);
   const int bars_total = Bars(_Symbol, _Period);
   if(bars_total <= (pivot_len * 2 + 3))
      return false;

   const int max_shift = MathMin(max_scan, bars_total - pivot_len - 1);
   for(int shift = pivot_len + 1; shift <= max_shift; ++shift)
     {
      if(!Strategy_IsPivotHigh(shift, pivot_len))
         continue;
      pivot_price = iHigh(_Symbol, _Period, shift);
      pivot_shift = shift;
      return (pivot_price > 0.0);
     }
   return false;
  }

bool Strategy_FindRecentPivotLow(double &pivot_price, int &pivot_shift)
  {
   pivot_price = 0.0;
   pivot_shift = 0;

   const int pivot_len = MathMax(2, strategy_pivot_length);
   const int max_scan = MathMax(pivot_len + 2, strategy_swing_scan_bars);
   const int bars_total = Bars(_Symbol, _Period);
   if(bars_total <= (pivot_len * 2 + 3))
      return false;

   const int max_shift = MathMin(max_scan, bars_total - pivot_len - 1);
   for(int shift = pivot_len + 1; shift <= max_shift; ++shift)
     {
      if(!Strategy_IsPivotLow(shift, pivot_len))
         continue;
      pivot_price = iLow(_Symbol, _Period, shift);
      pivot_shift = shift;
      return (pivot_price > 0.0);
     }
   return false;
  }

bool Strategy_BullishCisdConfirmed(const int sweep_shift)
  {
   const int capped = MathMax(1, sweep_shift);
   for(int shift = capped; shift >= 1; --shift)
     {
      const double c = iClose(_Symbol, _Period, shift);
      const double h_prev = iHigh(_Symbol, _Period, shift + 1);
      if(c > 0.0 && h_prev > 0.0 && c > h_prev)
         return true;
     }
   return false;
  }

bool Strategy_BearishCisdConfirmed(const int sweep_shift)
  {
   const int capped = MathMax(1, sweep_shift);
   for(int shift = capped; shift >= 1; --shift)
     {
      const double c = iClose(_Symbol, _Period, shift);
      const double l_prev = iLow(_Symbol, _Period, shift + 1);
      if(c > 0.0 && l_prev > 0.0 && c < l_prev)
         return true;
     }
   return false;
  }

bool Strategy_FindBullishSweep(const double pivot_low, int &sweep_shift)
  {
   sweep_shift = 0;
   const int max_window = MathMax(1, strategy_cisd_window_bars);
   for(int shift = max_window; shift >= 1; --shift)
     {
      const double l = iLow(_Symbol, _Period, shift);
      const double c = iClose(_Symbol, _Period, shift);
      if(l <= 0.0 || c <= 0.0)
         continue;
      if(l < pivot_low && c > pivot_low && Strategy_BullishCisdConfirmed(shift))
        {
         sweep_shift = shift;
         return true;
        }
     }
   return false;
  }

bool Strategy_FindBearishSweep(const double pivot_high, int &sweep_shift)
  {
   sweep_shift = 0;
   const int max_window = MathMax(1, strategy_cisd_window_bars);
   for(int shift = max_window; shift >= 1; --shift)
     {
      const double h = iHigh(_Symbol, _Period, shift);
      const double c = iClose(_Symbol, _Period, shift);
      if(h <= 0.0 || c <= 0.0)
         continue;
      if(h > pivot_high && c < pivot_high && Strategy_BearishCisdConfirmed(shift))
        {
         sweep_shift = shift;
         return true;
        }
     }
   return false;
  }

bool Strategy_HmaAllows(const QM_OrderType side)
  {
   if(strategy_hma_period <= 0)
      return true;

   const double hma_1 = QM_HMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_hma_period, 1);
   const double hma_2 = QM_HMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_hma_period, 2);
   if(hma_1 <= 0.0 || hma_2 <= 0.0)
      return false;

   // rework v2 2026-06-16 — slope-agreement only. The previous price-vs-HMA
   // condition (c1 > hma) is structurally false on a reversal entry that just
   // swept the opposite extreme, so it vetoed essentially every signal. The
   // card calls this an optional trend filter that "shows a bullish/bearish
   // condition" — an HMA turning in the trade direction satisfies that intent.
   if(QM_OrderTypeIsBuy(side))
      return (hma_1 > hma_2);
   return (hma_1 < hma_2);
  }

bool Strategy_FillRequest(QM_EntryRequest &req,
                          const QM_OrderType side,
                          const double swept_extreme,
                          const double atr_value,
                          const string reason)
  {
   const double entry = QM_OrderTypeIsBuy(side)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr_value <= 0.0)
      return false;

   const double atr_stop = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_atr_sl_mult);
   double structure_stop = 0.0;
   if(QM_OrderTypeIsBuy(side))
      structure_stop = swept_extreme - (strategy_sweep_atr_buffer * atr_value);
   else
      structure_stop = swept_extreme + (strategy_sweep_atr_buffer * atr_value);

   if(atr_stop <= 0.0 || structure_stop <= 0.0)
      return false;

   double sl = QM_OrderTypeIsBuy(side)
               ? MathMin(atr_stop, structure_stop)
               : MathMax(atr_stop, structure_stop);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
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
   Strategy_ResetRequest(req);

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_rr_target <= 0.0 || strategy_sweep_atr_buffer < 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double pivot_low = 0.0;
   int pivot_low_shift = 0;
   int sweep_shift = 0;
   if(Strategy_FindRecentPivotLow(pivot_low, pivot_low_shift) &&
      Strategy_FindBullishSweep(pivot_low, sweep_shift) &&
      Strategy_HmaAllows(QM_BUY))
      return Strategy_FillRequest(req, QM_BUY, pivot_low, atr, "CISD_SWEEP_HMA_LONG");

   double pivot_high = 0.0;
   int pivot_high_shift = 0;
   if(Strategy_FindRecentPivotHigh(pivot_high, pivot_high_shift) &&
      Strategy_FindBearishSweep(pivot_high, sweep_shift) &&
      Strategy_HmaAllows(QM_SELL))
      return Strategy_FillRequest(req, QM_SELL, pivot_high, atr, "CISD_SWEEP_HMA_SHORT");

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
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
