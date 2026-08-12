#property strict
#property version   "5.0"
#property description "QM5_9912 Bandy 5-Day Return Z-Score Mean Reversion"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 9912;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_return_window      = 5;
input int    strategy_zscore_lookback    = 20;
input double strategy_entry_z            = -2.0;
input double strategy_exit_z             = 0.0;
input int    strategy_regime_sma_period  = 200;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 2.5;
input int    strategy_time_stop_bars     = 8;

// -----------------------------------------------------------------------------
// Strategy calculation — bounded and cached once per D1 calendar key.
// -----------------------------------------------------------------------------

bool Strategy_CalculateReturnZ(double &zscore, double &latest_close)
  {
   static int    cached_calendar_key = 0;
   static bool   cached_valid        = false;
   static double cached_zscore       = 0.0;
   static double cached_close        = 0.0;

   zscore = 0.0;
   latest_close = 0.0;

   const int calendar_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(calendar_key <= 0)
      return false;

   if(calendar_key == cached_calendar_key)
     {
      zscore = cached_zscore;
      latest_close = cached_close;
      return cached_valid;
     }

   cached_calendar_key = calendar_key;
   cached_valid = false;
   cached_zscore = 0.0;
   cached_close = 0.0;

   if(strategy_return_window < 1 || strategy_zscore_lookback < 2)
      return false;

   const int bars_needed = strategy_zscore_lookback + strategy_return_window;
   MqlRates rates[];
   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   // perf-allowed: the card requires a bounded custom log-return array; this
   // helper is cached by QM_CalendarPeriodKey and scans once per closed D1 bar.
   if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) != bars_needed) // perf-allowed: bounded cached D1 return-z window.
      return false;

   double returns[];
   ArrayResize(returns, strategy_zscore_lookback);
   double sum = 0.0;
   for(int i = 0; i < strategy_zscore_lookback; ++i)
     {
      const double recent_close = rates[i].close;
      const double earlier_close = rates[i + strategy_return_window].close;
      if(recent_close <= 0.0 || earlier_close <= 0.0)
         return false;
      returns[i] = MathLog(recent_close / earlier_close);
      sum += returns[i];
     }

   const double mean = sum / (double)strategy_zscore_lookback;
   double variance_sum = 0.0;
   for(int i = 0; i < strategy_zscore_lookback; ++i)
     {
      const double deviation = returns[i] - mean;
      variance_sum += deviation * deviation;
     }

   // The card says stdev(ret5, 20) without a sample correction. The literal
   // rolling-series interpretation is population variance divided by N.
   const double variance = variance_sum / (double)strategy_zscore_lookback;
   if(variance <= 0.0)
      return false;

   cached_zscore = (returns[0] - mean) / MathSqrt(variance);
   cached_close = rates[0].close;
   cached_valid = true;

   zscore = cached_zscore;
   latest_close = cached_close;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter: D1 only. The card adds no session or spread restriction;
// zero modeled spread on .DWX therefore remains tradable.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   return (strategy_return_window < 1 ||
           strategy_zscore_lookback < 2 ||
           strategy_entry_z >= strategy_exit_z ||
           strategy_regime_sma_period < 2 ||
           strategy_atr_period < 1 ||
           strategy_atr_stop_mult <= 0.0 ||
           strategy_time_stop_bars < 1);
  }

// Trade Entry: at the next D1 bar open, buy after a completed-bar five-day
// return z-score <= -2 while the completed close is above SMA(200).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   double zscore = 0.0;
   double closed_price = 0.0;
   if(!Strategy_CalculateReturnZ(zscore, closed_price))
      return false;

   if(zscore > strategy_entry_z)
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1,
                                     strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(regime_sma <= 0.0 || closed_price <= regime_sma)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ask <= 0.0 || atr_value <= 0.0)
      return false;

   const double stop_price = QM_StopATRFromValue(_Symbol, QM_BUY, ask,
                                                  atr_value, strategy_atr_stop_mult);
   if(stop_price <= 0.0 || stop_price >= ask)
      return false;

   req.sl = stop_price;
   req.reason = StringFormat("BANDY_RET5_Z_LONG z=%.4f", zscore);
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, partial close,
// or scale-in. The catastrophic ATR stop is attached server-side at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: once per D1 calendar edge, close when the five-day-return
// z-score reaches zero or after eight completed trading bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(!QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol))
      return false;

   double zscore = 0.0;
   double closed_price = 0.0;
   if(Strategy_CalculateReturnZ(zscore, closed_price) && zscore >= strategy_exit_z)
      return true;

   const int held_bars = QM_TM_HeldPeriodsForMagic((long)magic,
                                                    _Symbol,
                                                    PERIOD_D1,
                                                    TimeCurrent());
   return (held_bars >= strategy_time_stop_bars);
  }

// News Filter Hook: no card-specific override. The framework's callable
// two-axis news gate remains available for the P8 News Impact phase.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — unchanged apart from the binding entry-only news order.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: management and exits remain active during news windows.
   Strategy_ManageOpenPosition();

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

   // Both news gates suppress only new entries; neither can suspend risk exits.
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
