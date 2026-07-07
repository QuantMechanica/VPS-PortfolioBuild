#property strict
#property version   "5.0"
#property description "QM5_12933 Alpha Architect turn-of-month 10-month SMA timing"

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
input int    qm_ea_id                   = 12933;
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
input int    strategy_sma_months        = 10;
input int    strategy_bucket_day        = 21;
input int    strategy_bucket_count      = 21;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 3.0;
input int    strategy_min_daily_bars    = 220;
input int    strategy_min_bucket_obs    = 11;
input int    strategy_max_spread_points = 0;

#define STRATEGY_MAX_D1_BARS 420
#define STRATEGY_MAX_MONTHS  24
#define STRATEGY_MAX_DAYS    32

int  g_signal_month_key       = 0;
bool g_signal_ready           = false;
bool g_signal_long            = false;
int  g_entry_fired_month_key  = 0;
double g_signal_bucket_close  = 0.0;
double g_signal_sma           = 0.0;

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_ClampInt(const int value, const int lo, const int hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

int Strategy_SelectedBucketIndex(const int requested_bucket, const int month_days)
  {
   if(month_days <= 0)
      return 0;

   const int bucket_count = Strategy_ClampInt(strategy_bucket_count, 1, STRATEGY_MAX_DAYS);
   const int bucket = Strategy_ClampInt(requested_bucket, 1, bucket_count);
   int selected = (int)MathRound(((double)bucket * (double)month_days) / (double)bucket_count);
   selected = Strategy_ClampInt(selected, 1, month_days);
   return selected;
  }

double Strategy_SelectedMonthClose(const int month_index,
                                   const int &month_counts[],
                                   const double &month_closes[][STRATEGY_MAX_DAYS])
  {
   if(month_index < 0 || month_index >= STRATEGY_MAX_MONTHS)
      return 0.0;

   const int count = month_counts[month_index];
   const int selected = Strategy_SelectedBucketIndex(strategy_bucket_day, count);
   if(selected <= 0 || selected > count)
      return 0.0;

   return month_closes[month_index][selected - 1];
  }

void Strategy_RefreshMonthlySignal()
  {
   if(!QM_IsNewCalendarPeriod(PERIOD_D1))
      return;

   g_signal_ready = false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, STRATEGY_MAX_D1_BARS, rates); // perf-allowed: bounded D1 monthly bucket reconstruction once per D1 calendar edge.
   if(copied <= strategy_min_daily_bars)
      return;

   int month_keys[STRATEGY_MAX_MONTHS];
   int month_counts[STRATEGY_MAX_MONTHS];
   double month_closes[STRATEGY_MAX_MONTHS][STRATEGY_MAX_DAYS];
   for(int i = 0; i < STRATEGY_MAX_MONTHS; ++i)
     {
      month_keys[i] = 0;
      month_counts[i] = 0;
      for(int j = 0; j < STRATEGY_MAX_DAYS; ++j)
         month_closes[i][j] = 0.0;
     }

   int month_total = 0;
   for(int i = copied - 1; i >= 1; --i)
     {
      const int key = Strategy_MonthKey(rates[i].time);
      if(key <= 0 || rates[i].close <= 0.0)
         continue;

      if(month_total == 0 || month_keys[month_total - 1] != key)
        {
         if(month_total >= STRATEGY_MAX_MONTHS)
            break;
         month_keys[month_total] = key;
         month_counts[month_total] = 0;
         month_total++;
        }

      const int month_index = month_total - 1;
      const int day_index = month_counts[month_index];
      if(day_index < STRATEGY_MAX_DAYS)
        {
         month_closes[month_index][day_index] = rates[i].close;
         month_counts[month_index]++;
        }
     }

   if(month_total < strategy_min_bucket_obs || month_total <= strategy_sma_months)
      return;

   const int current_month_key = Strategy_MonthKey(rates[0].time);
   int target_index = -1;
   for(int i = month_total - 1; i >= 0; --i)
     {
      if(month_keys[i] < current_month_key)
        {
         target_index = i;
         break;
        }
     }

   if(target_index < strategy_sma_months)
      return;

   const int target_month_key = month_keys[target_index];
   if(target_month_key == g_signal_month_key)
     {
      g_signal_ready = true;
      return;
     }

   const double target_close = Strategy_SelectedMonthClose(target_index, month_counts, month_closes);
   if(target_close <= 0.0)
      return;

   double sma_sum = 0.0;
   int observations = 0;
   for(int i = target_index - strategy_sma_months; i < target_index; ++i)
     {
      const double close_i = Strategy_SelectedMonthClose(i, month_counts, month_closes);
      if(close_i <= 0.0)
         return;
      sma_sum += close_i;
      observations++;
     }

   if(observations < strategy_sma_months)
      return;

   g_signal_month_key = target_month_key;
   g_signal_bucket_close = target_close;
   g_signal_sma = sma_sum / (double)strategy_sma_months;
   g_signal_long = (g_signal_bucket_close > g_signal_sma);
   g_signal_ready = true;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(ask > bid && ((ask - bid) / point) > (double)strategy_max_spread_points)
      return false;
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
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_signal_ready || !g_signal_long)
      return false;
   if(g_signal_month_key <= 0 || g_entry_fired_month_key == g_signal_month_key)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.sl = sl;
   req.reason = StringFormat("AA_TOM_SMA10_LONG_%d", g_signal_month_key);
   g_entry_fired_month_key = g_signal_month_key;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   Strategy_RefreshMonthlySignal();
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_signal_ready)
      return false;
   if(g_signal_month_key <= 0)
      return false;
   if(!g_signal_long)
      return true;
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
