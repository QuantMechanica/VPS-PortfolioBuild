#property strict
#property version   "5.0"
#property description "QM5_10316 Overnight Intraday Reversal"

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
input int    qm_ea_id                   = 10316;
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
input int    strategy_open_hour_broker          = 0;
input int    strategy_open_window_bars          = 1;
input int    strategy_close_hour_broker         = 23;
input int    strategy_selected_legs_per_side    = 2;
input int    strategy_dispersion_lookback_days  = 60;
input double strategy_dispersion_min_mult       = 0.25;
input int    strategy_stop_lookback_days        = 20;
input double strategy_stop_mult                 = 1.0;

string g_strategy_symbols[7] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
  };

int g_last_entry_day_key = 0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_Hour(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

int Strategy_SymbolSlot(const string symbol)
  {
   for(int i = 0; i < ArraySize(g_strategy_symbols); ++i)
     {
      if(g_strategy_symbols[i] == symbol)
         return i;
     }
   return -1;
  }

bool Strategy_OvernightReturn(const string symbol, const int shift, double &ret)
  {
   ret = 0.0;
   const double session_open = iOpen(symbol, PERIOD_D1, shift);
   const double prior_close = iClose(symbol, PERIOD_D1, shift + 1);
   if(session_open <= 0.0 || prior_close <= 0.0)
      return false;
   ret = session_open / prior_close - 1.0;
   return true;
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   ArrayResize(values, count);
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

bool Strategy_CurrentDispersion(double &min_ret, double &max_ret)
  {
   min_ret = DBL_MAX;
   max_ret = -DBL_MAX;
   for(int i = 0; i < ArraySize(g_strategy_symbols); ++i)
     {
      double ret = 0.0;
      if(!Strategy_OvernightReturn(g_strategy_symbols[i], 0, ret))
         return false;
      min_ret = MathMin(min_ret, ret);
      max_ret = MathMax(max_ret, ret);
     }
   return (max_ret > min_ret);
  }

bool Strategy_MedianDispersion(double &median_dispersion)
  {
   median_dispersion = 0.0;
   const int lookback = MathMax(5, strategy_dispersion_lookback_days);
   double dispersions[];
   ArrayResize(dispersions, lookback);
   int count = 0;
   for(int day = 1; day <= lookback; ++day)
     {
      double lo = DBL_MAX;
      double hi = -DBL_MAX;
      bool ok = true;
      for(int i = 0; i < ArraySize(g_strategy_symbols); ++i)
        {
         double ret = 0.0;
         if(!Strategy_OvernightReturn(g_strategy_symbols[i], day, ret))
           {
            ok = false;
            break;
           }
         lo = MathMin(lo, ret);
         hi = MathMax(hi, ret);
        }
      if(ok && hi > lo)
         dispersions[count++] = hi - lo;
     }
   if(count < MathMin(10, lookback))
      return false;
   median_dispersion = Strategy_Median(dispersions, count);
   return (median_dispersion > 0.0);
  }

bool Strategy_MedianIntradayAbsReturn(const string symbol, double &median_abs_return)
  {
   median_abs_return = 0.0;
   const int lookback = MathMax(5, strategy_stop_lookback_days);
   double abs_returns[];
   ArrayResize(abs_returns, lookback);
   int count = 0;
   for(int day = 1; day <= lookback; ++day)
     {
      const double open = iOpen(symbol, PERIOD_D1, day);
      const double close = iClose(symbol, PERIOD_D1, day);
      if(open <= 0.0 || close <= 0.0)
         continue;
      abs_returns[count++] = MathAbs(close / open - 1.0);
     }
   if(count < MathMin(5, lookback))
      return false;
   median_abs_return = Strategy_Median(abs_returns, count);
   return (median_abs_return > 0.0);
  }

int Strategy_RankSide(const string symbol)
  {
   double current_ret = 0.0;
   if(!Strategy_OvernightReturn(symbol, 0, current_ret))
      return 0;

   double min_ret = 0.0;
   double max_ret = 0.0;
   if(!Strategy_CurrentDispersion(min_ret, max_ret))
      return 0;

   double median_dispersion = 0.0;
   if(!Strategy_MedianDispersion(median_dispersion))
      return 0;
   if((max_ret - min_ret) < strategy_dispersion_min_mult * median_dispersion)
      return 0;

   int lower_count = 0;
   int higher_count = 0;
   for(int i = 0; i < ArraySize(g_strategy_symbols); ++i)
     {
      double ret = 0.0;
      if(!Strategy_OvernightReturn(g_strategy_symbols[i], 0, ret))
         return 0;
      if(ret < current_ret)
         ++lower_count;
      if(ret > current_ret)
         ++higher_count;
     }

   const int legs = MathMax(1, MathMin(strategy_selected_legs_per_side, ArraySize(g_strategy_symbols) / 2));
   if(lower_count < legs)
      return 1;
   if(higher_count < legs)
      return -1;
   return 0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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
   if(Strategy_SymbolSlot(_Symbol) < 0)
      return true;
   if(Strategy_HasOpenPosition())
      return false;

   const datetime now = TimeCurrent();
   const int hour = Strategy_Hour(now);
   if(hour < strategy_open_hour_broker)
      return true;
   if(hour >= strategy_close_hour_broker)
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

   const int slot = Strategy_SymbolSlot(_Symbol);
   if(slot < 0 || qm_magic_slot_offset != slot)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const datetime now = TimeCurrent();
   const int hour = Strategy_Hour(now);
   if(hour < strategy_open_hour_broker + MathMax(1, strategy_open_window_bars))
      return false;
   if(hour >= strategy_close_hour_broker)
      return false;

   const int day_key = Strategy_DayKey(now);
   if(g_last_entry_day_key == day_key)
      return false;

   const int side = Strategy_RankSide(_Symbol);
   if(side == 0)
      return false;

   double median_intraday_abs = 0.0;
   if(!Strategy_MedianIntradayAbsReturn(_Symbol, median_intraday_abs))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (side > 0) ? ask : bid;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = entry * median_intraday_abs * strategy_stop_mult;
   if(stop_distance <= point)
      return false;

   req.type = (side > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = (side > 0) ? entry - stop_distance : entry + stop_distance;
   req.tp = 0.0;
   req.reason = (side > 0) ? "OVERNIGHT_INTRADAY_REV_LONG" : "OVERNIGHT_INTRADAY_REV_SHORT";
   req.symbol_slot = slot;

   g_last_entry_day_key = day_key;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies one position per symbol with no scaling or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const int hour = Strategy_Hour(TimeCurrent());
   if(hour >= strategy_close_hour_broker)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
