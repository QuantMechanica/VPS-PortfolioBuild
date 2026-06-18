#property strict
#property version   "5.0"
#property description "QM5_1097 Unger Gold Intraday Bias"

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
input int    qm_ea_id                   = 1097;
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
input int    strategy_long_slot_hour          = 8;
input int    strategy_short_slot_hour         = 14;
input int    strategy_slot_hold_minutes       = 60;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 1.0;
input int    strategy_atr_median_days         = 60;
input double strategy_min_atr_median_mult     = 0.60;
input int    strategy_spread_median_days      = 20;
input double strategy_spread_max_median_mult  = 2.0;
input int    strategy_friday_last_entry_hour  = 18;

const string STRATEGY_ALLOWED_SYMBOL = "XAUUSD.DWX";
datetime     g_trade_day_key         = 0;

datetime Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

void Strategy_SortAscending(double &values[], const int count)
  {
   for(int i = 1; i < count; ++i)
     {
      const double v = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > v)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = v;
     }
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   Strategy_SortAscending(values, count);
   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

double Strategy_CurrentEntryPrice(const QM_OrderType type)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(type == QM_BUY)
      return (ask > 0.0 ? ask : bid);
   return (bid > 0.0 ? bid : ask);
  }

double Strategy_SpreadMedianPoints()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_median_days > 64)
      return 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, rates); // perf-allowed: bounded D1 spread sample, called only inside the framework new-bar entry gate.
   if(copied <= 0)
      return 0.0;

   double samples[64];
   int count = 0;
   for(int i = 0; i < copied && count < 64; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      samples[count] = (double)rates[i].spread;
      ++count;
     }

   return Strategy_Median(samples, count);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   const double median_spread = Strategy_SpreadMedianPoints();
   if(median_spread <= 0.0)
      return true;

   return ((double)current_spread <= median_spread * strategy_spread_max_median_mult);
  }

double Strategy_H1ATRMedian()
  {
   if(strategy_atr_median_days <= 0 || strategy_atr_median_days > 120)
      return 0.0;

   double samples[120];
   int count = 0;
   for(int day = 1; day <= strategy_atr_median_days && count < 120; ++day)
     {
      const int shift = day * 24;
      const double atr_value = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
      if(atr_value <= 0.0)
         continue;
      samples[count] = atr_value;
      ++count;
     }

   return Strategy_Median(samples, count);
  }

bool Strategy_ATRRegimeAllowsEntry()
  {
   const double current_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double median_atr = Strategy_H1ATRMedian();
   if(current_atr <= 0.0 || median_atr <= 0.0)
      return false;

   return (current_atr >= strategy_min_atr_median_mult * median_atr);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_ALLOWED_SYMBOL)
      return true;
   if(strategy_long_slot_hour < 0 || strategy_long_slot_hour > 23)
      return true;
   if(strategy_short_slot_hour < 0 || strategy_short_slot_hour > 23)
      return true;
   if(strategy_long_slot_hour == strategy_short_slot_hour)
      return true;
   if(strategy_slot_hold_minutes <= 0 || strategy_slot_hold_minutes > 240)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_atr_median_days <= 0 || strategy_min_atr_median_mult <= 0.0)
      return true;
   if(strategy_spread_median_days <= 0 || strategy_spread_max_median_mult <= 0.0)
      return true;
   if(strategy_friday_last_entry_hour < 0 || strategy_friday_last_entry_hour > 23)
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

   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);

   if(dt.min != 0)
      return false;
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_last_entry_hour)
      return false;

   const datetime day_key = Strategy_DayKey(broker_now);
   if(day_key > 0 && day_key == g_trade_day_key)
      return false;

   int direction = 0;
   if(dt.hour == strategy_long_slot_hour)
      direction = 1;
   else if(dt.hour == strategy_short_slot_hour)
      direction = -1;
   else
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(!Strategy_ATRRegimeAllowsEntry())
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = Strategy_CurrentEntryPrice(req.type);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1097_LONG_SLOT" : "QM5_1097_SHORT_SLOT";
   g_trade_day_key = day_key;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, partial close, or take-profit.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0)
         continue;
      if(Strategy_DayKey(open_time) != Strategy_DayKey(broker_now))
         return true;
      if((broker_now - open_time) >= strategy_slot_hold_minutes * 60)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2(...)
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
