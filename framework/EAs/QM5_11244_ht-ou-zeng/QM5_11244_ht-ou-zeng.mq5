#property strict
#property version   "5.0"
#property description "QM5_11244 Hudson Thames OU Zeng Threshold"

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
input int    qm_ea_id                   = 11244;
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
input int    strategy_formation_bars       = 252;
input string strategy_optimize_objective   = "expected_return";
input double strategy_entry_threshold_floor = 1.0;
input double strategy_close_threshold       = 0.25;
input int    strategy_max_hold_bars         = 60;
input double strategy_stop_extra_z          = 1.5;
input int    strategy_max_spread_points     = 0;

bool   g_ou_model_valid = false;
int    g_ou_model_month = 0;
double g_ou_mean = 0.0;
double g_ou_sigma = 0.0;
double g_ou_speed = 0.0;
double g_ou_expected_bars = 0.0;

int CurrentMonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

bool HasOurPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

double CurrentOuZ(const bool for_long_exit)
  {
   if(!g_ou_model_valid || g_ou_sigma <= 0.0)
      return 0.0;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (bid > 0.0 && ask > 0.0) ? 0.5 * (bid + ask) : bid;
   if(for_long_exit && bid > 0.0)
      price = bid;
   if(!for_long_exit && ask > 0.0)
      price = ask;
   if(price <= 0.0)
      return 0.0;
   return (MathLog(price) - g_ou_mean) / g_ou_sigma;
  }

bool RefreshOuModelIfDue()
  {
   const int month_key = CurrentMonthKey();
   if(g_ou_model_valid && g_ou_model_month == month_key)
      return true;

   g_ou_model_valid = false;
   g_ou_model_month = month_key;

   const int bars = MathMax(30, strategy_formation_bars);
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, bars + 1, closes); // perf-allowed: bespoke OU formation window, EntrySignal is framework new-bar gated.
   if(copied < bars + 1)
      return false;

   double logs[];
   ArrayResize(logs, copied);
   for(int i = 0; i < copied; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      logs[i] = MathLog(closes[i]);
     }

   double sum_now = 0.0;
   double sum_prev = 0.0;
   const int pairs = copied - 1;
   for(int i = 0; i < pairs; ++i)
     {
      sum_now += logs[i];
      sum_prev += logs[i + 1];
     }

   const double mean_now = sum_now / pairs;
   const double mean_prev = sum_prev / pairs;
   double cov = 0.0;
   double var_prev = 0.0;
   for(int i = 0; i < pairs; ++i)
     {
      const double dn = logs[i] - mean_now;
      const double dp = logs[i + 1] - mean_prev;
      cov += dn * dp;
      var_prev += dp * dp;
     }
   if(var_prev <= 0.0)
      return false;

   const double beta = cov / var_prev;
   if(beta <= 0.0 || beta >= 0.999)
      return false;

   double alpha = 0.0;
   for(int i = 0; i < pairs; ++i)
      alpha += logs[i] - beta * logs[i + 1];
   alpha /= pairs;

   const double ou_mean = alpha / (1.0 - beta);
   double residual_var = 0.0;
   for(int i = 0; i < pairs; ++i)
     {
      const double resid = logs[i] - (alpha + beta * logs[i + 1]);
      residual_var += resid * resid;
     }
   residual_var /= MathMax(1, pairs - 1);

   const double speed = -MathLog(beta);
   const double sigma = MathSqrt(residual_var) / MathSqrt(1.0 - beta * beta);
   if(speed <= 0.0 || sigma <= 0.0)
      return false;

   const double expected_bars = MathLog(2.0) / speed;
   if(expected_bars <= 0.0 || expected_bars > strategy_max_hold_bars)
      return false;

   g_ou_mean = ou_mean;
   g_ou_sigma = sigma;
   g_ou_speed = speed;
   g_ou_expected_bars = expected_bars;
   g_ou_model_valid = true;
   return true;
  }

double SpreadCostZ()
  {
   if(!g_ou_model_valid || g_ou_sigma <= 0.0)
      return DBL_MAX;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return 0.0;
   return MathLog(ask / bid) / g_ou_sigma;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point > 0.0 && ask > bid)
        {
         const double spread_points = (ask - bid) / point;
         if(spread_points > strategy_max_spread_points)
            return true;
        }
     }
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

   if(HasOurPosition())
      return false;
   if(!RefreshOuModelIfDue())
      return false;
   if(!g_ou_model_valid || g_ou_speed <= 0.0 || g_ou_expected_bars > strategy_max_hold_bars)
      return false;

   const double close_threshold = MathMax(0.0, strategy_close_threshold);
   const double entry_threshold = MathMax(strategy_entry_threshold_floor, close_threshold + 0.05);
   const double cost_z = SpreadCostZ();
   if(MathAbs(entry_threshold - close_threshold) - cost_z <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return false;

   const double mid = 0.5 * (bid + ask);
   const double z = (MathLog(mid) - g_ou_mean) / g_ou_sigma;
   const double stop_z = entry_threshold + MathMax(0.0, strategy_stop_extra_z);

   if(z >= entry_threshold)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = MathExp(g_ou_mean + stop_z * g_ou_sigma);
      req.tp = MathExp(g_ou_mean + close_threshold * g_ou_sigma);
      req.reason = "OU_ZENG_SHORT";
      if(req.sl <= ask || req.tp >= bid)
         return false;
      return true;
     }

   if(z <= -entry_threshold)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = MathExp(g_ou_mean - stop_z * g_ou_sigma);
      req.tp = MathExp(g_ou_mean - close_threshold * g_ou_sigma);
      req.reason = "OU_ZENG_LONG";
      if(req.sl >= bid || req.tp <= ask)
         return false;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even adjustment.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double close_threshold = MathMax(0.0, strategy_close_threshold);
   const double entry_threshold = MathMax(strategy_entry_threshold_floor, close_threshold + 0.05);
   const double stop_z = entry_threshold + MathMax(0.0, strategy_stop_extra_z);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && TimeCurrent() - opened >= (datetime)(strategy_max_hold_bars * 86400))
         return true;

      if(!g_ou_model_valid)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_long = (ptype == POSITION_TYPE_BUY);
      const double z = CurrentOuZ(is_long);
      if(is_long && (z >= -close_threshold || z <= -stop_z))
         return true;
      if(!is_long && (z <= close_threshold || z >= stop_z))
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
