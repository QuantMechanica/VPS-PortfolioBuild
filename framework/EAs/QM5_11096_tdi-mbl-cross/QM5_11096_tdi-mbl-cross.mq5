#property strict
#property version   "5.0"
#property description "QM5_11096 TDI Market Base Line Cross"

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
input int    qm_ea_id                   = 11096;
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
input int    strategy_rsi_period              = 13;
input int    strategy_volatility_band_period  = 34;
input double strategy_stddev_mult             = 1.6185;
input int    strategy_rsi_price_line_period   = 2;
input int    strategy_trade_signal_period     = 7;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 2.0;
input int    strategy_time_stop_bars          = 18;

double Strategy_RsiSma(const int period, const int shift)
  {
   if(period <= 0 || shift < 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double value = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift + i, PRICE_CLOSE);
      if(value <= 0.0)
         return 0.0;
      sum += value;
     }

   return sum / (double)period;
  }

double Strategy_RsiStdDev(const int period, const int shift, const double mean)
  {
   if(period <= 1 || shift < 0 || mean <= 0.0)
      return 0.0;

   double sum_sq = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double value = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift + i, PRICE_CLOSE);
      if(value <= 0.0)
         return 0.0;
      const double delta = value - mean;
      sum_sq += delta * delta;
     }

   return MathSqrt(sum_sq / (double)period);
  }

double Strategy_TdiPriceLine(const int shift)
  {
   return Strategy_RsiSma(strategy_rsi_price_line_period, shift);
  }

double Strategy_TdiSignalLine(const int shift)
  {
   return Strategy_RsiSma(strategy_trade_signal_period, shift);
  }

double Strategy_TdiMarketBaseLine(const int shift)
  {
   return Strategy_RsiSma(strategy_volatility_band_period, shift);
  }

bool Strategy_TdiLines(const int shift,
                       double &price_line,
                       double &signal_line,
                       double &market_base_line,
                       double &upper_band,
                       double &lower_band)
  {
   price_line = Strategy_TdiPriceLine(shift);
   signal_line = Strategy_TdiSignalLine(shift);
   market_base_line = Strategy_TdiMarketBaseLine(shift);
   if(price_line <= 0.0 || signal_line <= 0.0 || market_base_line <= 0.0)
      return false;

   const double deviation = Strategy_RsiStdDev(strategy_volatility_band_period, shift, market_base_line);
   if(deviation <= 0.0 || strategy_stddev_mult <= 0.0)
      return false;

   upper_band = market_base_line + deviation * strategy_stddev_mult;
   lower_band = market_base_line - deviation * strategy_stddev_mult;
   return (upper_band > lower_band);
  }

bool Strategy_TdiSignalAndBase(const int shift,
                               double &signal_line,
                               double &market_base_line)
  {
   double price_line = 0.0;
   double upper_band = 0.0;
   double lower_band = 0.0;
   return Strategy_TdiLines(shift, price_line, signal_line, market_base_line, upper_band, lower_band);
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
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
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
   // Card adds no time, spread, or regime filter; news is handled by framework/P8 hook.
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

   if(Strategy_HasOpenPosition())
      return false;

   double signal_1 = 0.0, mbl_1 = 0.0;
   double signal_2 = 0.0, mbl_2 = 0.0;
   if(!Strategy_TdiSignalAndBase(1, signal_1, mbl_1) ||
      !Strategy_TdiSignalAndBase(2, signal_2, mbl_2))
      return false;

   if(signal_2 <= mbl_2 && signal_1 > mbl_1)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "TDI_MBL_CROSS_LONG";
      return (req.sl > 0.0);
     }

   if(signal_2 >= mbl_2 && signal_1 < mbl_1)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "TDI_MBL_CROSS_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing-stop, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   double price_1 = 0.0, signal_1 = 0.0, mbl_1 = 0.0, upper_1 = 0.0, lower_1 = 0.0;
   double price_2 = 0.0, signal_2 = 0.0, mbl_2 = 0.0, upper_2 = 0.0, lower_2 = 0.0;
   const bool have_tdi = Strategy_TdiLines(1, price_1, signal_1, mbl_1, upper_1, lower_1) &&
                         Strategy_TdiLines(2, price_2, signal_2, mbl_2, upper_2, lower_2);
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(strategy_time_stop_bars > 0 && period_seconds > 0)
        {
         const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened_at > 0 && TimeCurrent() - opened_at >= strategy_time_stop_bars * period_seconds)
            return true;
        }

      if(!have_tdi)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         if(signal_2 >= mbl_2 && signal_1 < mbl_1)
            return true;
         if(price_2 >= signal_2 && price_1 < signal_1)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(signal_2 <= mbl_2 && signal_1 > mbl_1)
            return true;
         if(price_2 <= signal_2 && price_1 > signal_1)
            return true;
        }
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
