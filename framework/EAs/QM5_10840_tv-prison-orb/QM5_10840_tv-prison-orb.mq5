#property strict
#property version   "5.0"
#property description "QM5_10840 TradingView Prison Escape ORB"

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
input int    qm_ea_id                   = 10840;
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
input int    strategy_chicago_to_broker_hours = 8;
input int    strategy_session_start_hhmm      = 830;
input int    strategy_entry_end_hhmm          = 1030;
input int    strategy_session_exit_hhmm       = 1230;
input int    strategy_zigzag_depth            = 5;
input int    strategy_end_pivots              = 4;
input int    strategy_breakout_mode           = 2;
input int    strategy_atr_period              = 14;
input double strategy_box_min_atr             = 0.5;
input double strategy_box_max_atr             = 4.0;
input double strategy_min_stop_atr            = 0.25;
input double strategy_fallback_stop_atr       = 1.0;
input double strategy_target_r                = 2.0;
input int    strategy_bars_to_scan            = 240;

int    g_session_key = -1;
bool   g_box_locked = false;
bool   g_box_valid = false;
bool   g_trade_taken_session = false;
int    g_first_break_dir = 0;
bool   g_returned_inside = false;
double g_box_high = 0.0;
double g_box_low = 0.0;
double g_box_mid = 0.0;
double g_first_break_extreme = 0.0;

int HhmmToMinutes(const int hhmm)
  {
   const int h = hhmm / 100;
   const int m = hhmm % 100;
   return h * 60 + m;
  }

int ChicagoDayKey(const datetime broker_time)
  {
   const datetime chicago_time = broker_time - strategy_chicago_to_broker_hours * 3600;
   MqlDateTime dt;
   TimeToStruct(chicago_time, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int ChicagoMinutes(const datetime broker_time)
  {
   const datetime chicago_time = broker_time - strategy_chicago_to_broker_hours * 3600;
   MqlDateTime dt;
   TimeToStruct(chicago_time, dt);
   return dt.hour * 60 + dt.min;
  }

datetime BrokerTimeForChicagoHhmm(const datetime broker_time, const int hhmm)
  {
   datetime chicago_time = broker_time - strategy_chicago_to_broker_hours * 3600;
   MqlDateTime dt;
   TimeToStruct(chicago_time, dt);
   dt.hour = hhmm / 100;
   dt.min = hhmm % 100;
   dt.sec = 0;
   return StructToTime(dt) + strategy_chicago_to_broker_hours * 3600;
  }

void ResetSessionState()
  {
   g_box_locked = false;
   g_box_valid = false;
   g_trade_taken_session = false;
   g_first_break_dir = 0;
   g_returned_inside = false;
   g_box_high = 0.0;
   g_box_low = 0.0;
   g_box_mid = 0.0;
   g_first_break_extreme = 0.0;
  }

void UpdateSessionState(const datetime broker_time)
  {
   const int key = ChicagoDayKey(broker_time);
   if(key != g_session_key)
     {
      g_session_key = key;
      ResetSessionState();
     }
  }

bool CopyClosedRates(MqlRates &rates[], const int requested)
  {
   ArrayResize(rates, 0);
   if(requested <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, requested, rates); // perf-allowed: closed-bar bespoke pivot box, called only after framework QM_IsNewBar gate.
   if(copied <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   if(copied < requested)
      ArrayResize(rates, copied);
   return true;
  }

bool IsPivotHigh(MqlRates &rates[], const int idx, const int depth, const int count)
  {
   const double value = rates[idx].high;
   if(value <= 0.0)
      return false;
   for(int j = idx - depth; j <= idx + depth; ++j)
     {
      if(j < 0 || j >= count)
         return false;
      if(j == idx)
         continue;
      if(rates[j].high >= value)
         return false;
     }
   return true;
  }

bool IsPivotLow(MqlRates &rates[], const int idx, const int depth, const int count)
  {
   const double value = rates[idx].low;
   if(value <= 0.0)
      return false;
   for(int j = idx - depth; j <= idx + depth; ++j)
     {
      if(j < 0 || j >= count)
         return false;
      if(j == idx)
         continue;
      if(rates[j].low <= value)
         return false;
     }
   return true;
  }

bool TryLockVolatilityBox(const datetime broker_now)
  {
   if(g_box_locked)
      return g_box_valid;

   const int depth = (strategy_zigzag_depth < 1) ? 1 : strategy_zigzag_depth;
   int end_pivots = strategy_end_pivots;
   if(end_pivots < 3)
      end_pivots = 3;
   if(end_pivots > 5)
      end_pivots = 5;
   int scan_bars = strategy_bars_to_scan;
   if(scan_bars < 40)
      scan_bars = 40;
   if(scan_bars > 500)
      scan_bars = 500;
   MqlRates rates[];
   if(!CopyClosedRates(rates, scan_bars))
      return false;

   const int count = ArraySize(rates);
   if(count < depth * 2 + end_pivots + 2)
      return false;

   const datetime session_start = BrokerTimeForChicagoHhmm(broker_now, strategy_session_start_hhmm);
   double pivots[5];
   int pivot_count = 0;
   int last_dir = 0;

   for(int i = count - depth - 1; i >= depth && pivot_count < end_pivots; --i)
     {
      if(rates[i].time < session_start)
         continue;

      const bool pivot_high = IsPivotHigh(rates, i, depth, count);
      const bool pivot_low = IsPivotLow(rates, i, depth, count);

      if(pivot_high)
        {
         if(last_dir == 1 && pivot_count > 0)
           {
            if(rates[i].high > pivots[pivot_count - 1])
               pivots[pivot_count - 1] = rates[i].high;
           }
         else
           {
            pivots[pivot_count] = rates[i].high;
            pivot_count++;
            last_dir = 1;
           }
        }

      if(pivot_low && pivot_count < end_pivots)
        {
         if(last_dir == -1 && pivot_count > 0)
           {
            if(rates[i].low < pivots[pivot_count - 1])
               pivots[pivot_count - 1] = rates[i].low;
           }
         else
           {
            pivots[pivot_count] = rates[i].low;
            pivot_count++;
            last_dir = -1;
           }
        }
     }

   if(pivot_count < end_pivots)
      return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i = 0; i < end_pivots; ++i)
     {
      hi = MathMax(hi, pivots[i]);
      lo = MathMin(lo, pivots[i]);
     }

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(hi <= lo || atr <= 0.0)
      return false;

   const double height = hi - lo;
   g_box_high = hi;
   g_box_low = lo;
   g_box_mid = (hi + lo) * 0.5;
   g_box_locked = true;
   g_box_valid = (height >= strategy_box_min_atr * atr && height <= strategy_box_max_atr * atr);
   return g_box_valid;
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
      g_trade_taken_session = true;
      return true;
     }
   return false;
  }

bool FillEntryRequest(QM_EntryRequest &req, const QM_OrderType type, const double entry_price)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || entry_price <= 0.0)
      return false;

   const bool is_buy = QM_OrderTypeIsBuy(type);
   double sl = g_box_mid;
   const double min_stop = strategy_min_stop_atr * atr;
   if(MathAbs(entry_price - sl) < min_stop)
      sl = is_buy ? (g_box_high - strategy_fallback_stop_atr * atr)
                  : (g_box_low + strategy_fallback_stop_atr * atr);

   if(is_buy && sl >= entry_price)
      return false;
   if(!is_buy && sl <= entry_price)
      return false;

   const double risk_dist = MathAbs(entry_price - sl);
   if(risk_dist < point)
      return false;

   const double tp = is_buy ? (entry_price + strategy_target_r * risk_dist)
                            : (entry_price - strategy_target_r * risk_dist);

   req.type = type;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = is_buy ? "PRISON_ORB_LONG_REBREAK" : "PRISON_ORB_SHORT_REBREAK";
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
   // No Trade Filter (time, spread, news): framework handles news/Friday/kill-switch;
   // entry time gating stays in Trade Entry so the 12:30 CST close remains reachable.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: A-D pivot volatility box, two-breakout confirmation baseline.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   UpdateSessionState(broker_now);

   if(g_trade_taken_session || HasOurPosition())
      return false;

   const int now_min = ChicagoMinutes(broker_now);
   if(now_min < HhmmToMinutes(strategy_session_start_hhmm) ||
      now_min > HhmmToMinutes(strategy_entry_end_hhmm))
      return false;

   if(!TryLockVolatilityBox(broker_now))
      return false;

   MqlRates last[];
   if(!CopyClosedRates(last, 1))
      return false;

   const double close1 = last[0].close;
   const double high1 = last[0].high;
   const double low1 = last[0].low;
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(strategy_breakout_mode <= 1)
     {
      if(close1 > g_box_high && FillEntryRequest(req, QM_BUY, ask))
        {
         g_trade_taken_session = true;
         return true;
        }
      if(close1 < g_box_low && FillEntryRequest(req, QM_SELL, bid))
        {
         g_trade_taken_session = true;
         return true;
        }
      return false;
     }

   if(g_first_break_dir == 0)
     {
      if(close1 > g_box_high)
        {
         g_first_break_dir = 1;
         g_first_break_extreme = high1;
        }
      else if(close1 < g_box_low)
        {
         g_first_break_dir = -1;
         g_first_break_extreme = low1;
        }
      return false;
     }

   const bool inside_box = (close1 < g_box_high && close1 > g_box_low);
   if(inside_box)
      g_returned_inside = true;

   if(g_first_break_dir == 1 && g_returned_inside && close1 > g_first_break_extreme)
     {
      if(FillEntryRequest(req, QM_BUY, ask))
        {
         g_trade_taken_session = true;
         return true;
        }
     }

   if(g_first_break_dir == -1 && g_returned_inside && close1 < g_first_break_extreme)
     {
      if(FillEntryRequest(req, QM_SELL, bid))
        {
         g_trade_taken_session = true;
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: card specifies no trailing, partial, or break-even rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: hard session exit at 12:30 America/Chicago.
   const datetime broker_now = TimeCurrent();
   UpdateSessionState(broker_now);
   if(!HasOurPosition())
      return false;
   return (ChicagoMinutes(broker_now) >= HhmmToMinutes(strategy_session_exit_hhmm));
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific news override; framework news mode applies.
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
