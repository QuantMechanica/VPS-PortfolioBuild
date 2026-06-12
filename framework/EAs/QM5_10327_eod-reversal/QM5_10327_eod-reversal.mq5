#property strict
#property version   "5.0"
#property description "QM5_10327 End Of Day Reversal"

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
input int    qm_ea_id                   = 10327;
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
input int    strategy_entry_hhmm_broker       = 2230;
input int    strategy_cash_close_hhmm_broker  = 2300;
input int    strategy_rank_cutoff_hhmm_broker = 2130;
input int    strategy_prior_close_hhmm_broker = 2230;
input int    strategy_atr_period              = 14;
input double strategy_signal_atr_mult         = 0.50;
input double strategy_stop_atr_mult           = 0.50;
input int    strategy_lookback_bars           = 240;
input int    strategy_spread_lookback_bars    = 960;
input double strategy_spread_percentile       = 80.0;
input int    strategy_min_valid_symbols       = 3;
input bool   strategy_skip_us_early_closes    = true;
input bool   strategy_skip_news_days          = true;

string g_strategy_symbols[4] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX"};
int    g_strategy_slots[4]   = {0, 1, 2, 3};
int    g_last_signal_day_key = 0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

int Strategy_NthWeekdayOfMonth(const int year, const int month, const int day_of_week, const int nth)
  {
   int hits = 0;
   for(int day = 1; day <= 31; ++day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon = month;
      dt.day = day;
      const datetime t = StructToTime(dt);

      MqlDateTime checked;
      ZeroMemory(checked);
      TimeToStruct(t, checked);
      if(checked.mon != month)
         break;
      if(checked.day_of_week != day_of_week)
         continue;

      hits++;
      if(hits == nth)
         return day;
     }
   return -1;
  }

bool Strategy_IsUSEarlyCloseDate(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);

   if(dt.mon == 7 && dt.day == 3)
      return true;
   if(dt.mon == 12 && dt.day == 24)
      return true;

   const int thanksgiving = Strategy_NthWeekdayOfMonth(dt.year, 11, 4, 4);
   if(dt.mon == 11 && thanksgiving > 0 && dt.day == thanksgiving + 1)
      return true;

   return false;
  }

double Strategy_Percentile(double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   double p = percentile / 100.0;
   if(p < 0.0)
      p = 0.0;
   if(p > 1.0)
      p = 1.0;

   const int idx = (int)MathFloor((double)(count - 1) * p);
   return values[idx];
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at)
  {
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int Strategy_SymbolSlot(const string symbol)
  {
   for(int i = 0; i < ArraySize(g_strategy_symbols); ++i)
      if(g_strategy_symbols[i] == symbol)
         return g_strategy_slots[i];
   return -1;
  }

bool Strategy_LoadRestOfDayReturn(const string symbol,
                                  const int current_day_key,
                                  double &rest_return,
                                  double &cutoff_close)
  {
   rest_return = 0.0;
   cutoff_close = 0.0;

   if(!SymbolSelect(symbol, true))
      return false;

   MqlRates rates[];
   ArrayResize(rates, strategy_lookback_bars);
   const int copied = CopyRates(symbol, PERIOD_M30, 1, strategy_lookback_bars, rates); // perf-allowed: bounded basket ranking, called only after framework QM_IsNewBar gate.
   if(copied <= 0)
      return false;
   ArraySetAsSeries(rates, true);

   double today_cutoff_close = 0.0;
   double prior_close = 0.0;

   for(int i = 0; i < copied; ++i)
     {
      const int day_key = Strategy_DateKey(rates[i].time);
      const int hhmm = Strategy_Hhmm(rates[i].time);

      if(day_key == current_day_key && hhmm == strategy_rank_cutoff_hhmm_broker)
        {
         today_cutoff_close = rates[i].close;
         continue;
        }

      if(day_key < current_day_key && hhmm == strategy_prior_close_hhmm_broker)
        {
         prior_close = rates[i].close;
         break;
        }
     }

   if(today_cutoff_close <= 0.0 || prior_close <= 0.0)
      return false;

   cutoff_close = today_cutoff_close;
   rest_return = (today_cutoff_close / prior_close) - 1.0;
   return true;
  }

bool Strategy_LoadBasket(double &returns[], int &valid_count, double &current_return, double &current_cutoff_close)
  {
   valid_count = 0;
   current_return = 0.0;
   current_cutoff_close = 0.0;
   ArrayResize(returns, ArraySize(g_strategy_symbols));

   const int current_day_key = Strategy_DateKey(TimeCurrent());

   for(int i = 0; i < ArraySize(g_strategy_symbols); ++i)
     {
      double ret = 0.0;
      double cutoff_close = 0.0;
      if(!Strategy_LoadRestOfDayReturn(g_strategy_symbols[i], current_day_key, ret, cutoff_close))
         continue;

      returns[valid_count] = ret;
      valid_count++;

      if(g_strategy_symbols[i] == _Symbol)
        {
         current_return = ret;
         current_cutoff_close = cutoff_close;
        }
     }

   return (valid_count >= strategy_min_valid_symbols && current_cutoff_close > 0.0);
  }

double Strategy_MedianReturn(double &returns[], const int count)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(returns, count);
   ArraySort(returns);

   const int mid = count / 2;
   if((count % 2) == 1)
      return returns[mid];
   return 0.5 * (returns[mid - 1] + returns[mid]);
  }

bool Strategy_IsExtreme(const double value, double &returns[], const int count, const bool weakest)
  {
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      if(weakest && value > returns[i])
         return false;
      if(!weakest && value < returns[i])
         return false;
     }
   return true;
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_spread_lookback_bars <= 0)
      return true;

   MqlRates rates[];
   ArrayResize(rates, strategy_spread_lookback_bars);
   const int copied = CopyRates(_Symbol, PERIOD_M30, 1, strategy_spread_lookback_bars, rates); // perf-allowed: bounded final-half-hour spread percentile, called only after framework QM_IsNewBar gate.
   if(copied <= 0)
      return false;
   ArraySetAsSeries(rates, true);

   double spreads[];
   ArrayResize(spreads, copied);
   int spread_count = 0;

   for(int i = 0; i < copied; ++i)
     {
      if(Strategy_Hhmm(rates[i].time) != strategy_entry_hhmm_broker)
         continue;
      if(rates[i].spread <= 0)
         continue;

      spreads[spread_count] = (double)rates[i].spread;
      spread_count++;
     }

   if(spread_count < 20)
      return true;

   const double threshold = Strategy_Percentile(spreads, spread_count, strategy_spread_percentile);
   if(threshold <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double current_spread = (ask - bid) / point;
   return (current_spread <= threshold);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M30)
      return true;

   if(Strategy_SymbolSlot(_Symbol) < 0)
      return true;

   if(Strategy_Hhmm(TimeCurrent()) < strategy_entry_hhmm_broker)
      return true;

   if(strategy_skip_us_early_closes && Strategy_IsUSEarlyCloseDate(TimeCurrent()))
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

   if(strategy_atr_period <= 0 || strategy_signal_atr_mult <= 0.0 ||
      strategy_stop_atr_mult <= 0.0 || strategy_min_valid_symbols < 3)
      return false;

   if(Strategy_Hhmm(TimeCurrent()) != strategy_entry_hhmm_broker)
      return false;

   const int day_key = Strategy_DateKey(TimeCurrent());
   if(g_last_signal_day_key == day_key)
      return false;

   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   if(Strategy_GetOurPosition(ptype, opened_at))
      return false;

   if(!Strategy_SpreadAllows())
      return false;

   double returns[];
   int valid_count = 0;
   double current_return = 0.0;
   double current_cutoff_close = 0.0;
   if(!Strategy_LoadBasket(returns, valid_count, current_return, current_cutoff_close))
      return false;

   double sorted_returns[];
   ArrayResize(sorted_returns, valid_count);
   for(int i = 0; i < valid_count; ++i)
      sorted_returns[i] = returns[i];

   const double basket_median = Strategy_MedianReturn(sorted_returns, valid_count);
   const double atr = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   if(atr <= 0.0 || current_cutoff_close <= 0.0)
      return false;

   const double signal_threshold = strategy_signal_atr_mult * atr / current_cutoff_close;
   if(signal_threshold <= 0.0)
      return false;

   const bool is_weakest = Strategy_IsExtreme(current_return, returns, valid_count, true);
   const bool is_strongest = Strategy_IsExtreme(current_return, returns, valid_count, false);

   QM_OrderType side = QM_BUY;
   double entry = 0.0;

   if(is_weakest && (basket_median - current_return) >= signal_threshold)
     {
      side = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.reason = "EOD_REV_LONG_WEAKEST";
     }
   else if(is_strongest && (current_return - basket_median) >= signal_threshold)
     {
      side = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.reason = "EOD_REV_SHORT_STRONGEST";
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = sl;
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   g_last_signal_day_key = day_key;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, pyramiding, or averaging.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   if(!Strategy_GetOurPosition(ptype, opened_at))
      return false;

   const datetime broker_now = TimeCurrent();
   if(Strategy_DateKey(broker_now) != Strategy_DateKey(opened_at))
      return true;

   if(Strategy_Hhmm(broker_now) >= strategy_cash_close_hhmm_broker)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(strategy_skip_us_early_closes && Strategy_IsUSEarlyCloseDate(broker_time))
      return true;

   if(strategy_skip_news_days && !QM_NewsAllowsTrade(_Symbol, broker_time, QM_NEWS_SKIP_DAY))
      return true;

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
