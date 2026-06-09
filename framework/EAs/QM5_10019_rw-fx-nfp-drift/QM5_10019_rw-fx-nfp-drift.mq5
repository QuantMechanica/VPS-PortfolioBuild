#property strict
#property version   "5.0"
#property description "QM5_10019 Robot Wealth FX NFP Drift"

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
input int    qm_ea_id                   = 10019;
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
// NFP is the traded event, so temporal news blackout must be disabled here.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period         = 14;
input double strategy_drift_atr_mult     = 0.20;
input double strategy_sl_atr_mult        = 0.60;
input double strategy_tp_atr_mult        = 0.60;
input bool   strategy_use_atr_tp         = true;
input double strategy_max_spread_atr     = 0.25;
input int    strategy_pre_start_hhmm_ny  = 600;
input int    strategy_entry_hhmm_ny      = 800;
input int    strategy_exit_hhmm_ny       = 825;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: framework handles kill-switch, Friday close, and news.
   // Entry-specific time/spread gates live in Strategy_EntrySignal so the
   // 08:25 NY force-flat cannot be blocked by a wide spread.
   return false;
  }

datetime BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc_time) ? -4 : -5;
   return utc_time + (ny_offset_hours * 3600);
  }

int NewYorkHhmm(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return dt.hour * 100 + dt.min;
  }

bool IsFirstFridayNewYork(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return (dt.day_of_week == 5 && dt.day >= 1 && dt.day <= 7);
  }

bool SameNewYorkDate(const datetime a, const datetime b)
  {
   MqlDateTime da;
   MqlDateTime db;
   TimeToStruct(BrokerToNewYork(a), da);
   TimeToStruct(BrokerToNewYork(b), db);
   return (da.year == db.year && da.mon == db.mon && da.day == db.day);
  }

double PreEventDrift()
  {
   const datetime now = TimeCurrent();
   const double last_close = iClose(_Symbol, _Period, 1); // perf-allowed: bespoke drift scan, gated by QM_IsNewBar
   if(last_close <= 0.0)
      return 0.0;

   for(int shift = 1; shift <= 36; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, _Period, shift); // perf-allowed: bespoke drift scan, gated by QM_IsNewBar
      if(bar_time <= 0 || !SameNewYorkDate(bar_time, now))
         continue;
      if(NewYorkHhmm(bar_time) != strategy_pre_start_hhmm_ny)
         continue;

      const double start_open = iOpen(_Symbol, _Period, shift); // perf-allowed: bespoke drift scan, gated by QM_IsNewBar
      if(start_open <= 0.0)
         return 0.0;
      return last_close - start_open;
     }

   return 0.0;
  }

// Trade Entry: first Friday NFP drift-following entry at 08:00 New York.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!IsFirstFridayNewYork(broker_now) || NewYorkHhmm(broker_now) != strategy_entry_hhmm_ny)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   if((ask - bid) > strategy_max_spread_atr * atr)
      return false;

   const double drift = PreEventDrift();
   const double threshold = strategy_drift_atr_mult * atr;
   if(MathAbs(drift) < threshold)
      return false;

   const bool buy = (drift > 0.0);
   const QM_OrderType side = buy ? QM_BUY : QM_SELL;
   req.type = side;
   const double entry = buy ? ask : bid;
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_sl_atr_mult);
   req.tp = strategy_use_atr_tp ? QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_tp_atr_mult) : 0.0;
   if(req.sl <= 0.0)
      return false;

   req.reason = buy ? "RW_NFP_DRIFT_LONG" : "RW_NFP_DRIFT_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: card defines no trailing, break-even, partial close, or add-on logic.
  }

// Trade Close: force-flat at 08:25 New York, before the NFP release.
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   return (IsFirstFridayNewYork(broker_now) && NewYorkHhmm(broker_now) >= strategy_exit_hhmm_ny);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: this EA trades only the scheduled NFP pre-release window.
   // Holiday-moved releases are skipped by requiring the first Friday calendar date.
   return false; // defer non-custom news behavior to QM_NewsAllowsTrade(...)
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
