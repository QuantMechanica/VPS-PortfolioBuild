#property strict
#property version   "5.0"
#property description "QM5_10351 et-rally-x"

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
input int    qm_ea_id                   = 10351;
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
input double strategy_forex_threshold_pct     = 0.12;
input double strategy_index_threshold_pct     = 0.18;
input double strategy_commodity_threshold_pct = 0.50;
input int    strategy_detect_window_minutes   = 20;
input int    strategy_wait_bars               = 2;
input int    strategy_entry_window_minutes    = 60;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 1.0;
input int    strategy_forex_session_start     = 800;
input int    strategy_eu_index_session_start  = 900;
input int    strategy_us_index_session_start  = 1630;
input int    strategy_commodity_session_start = 1530;
input int    strategy_session_close           = 2100;
input double strategy_min_threshold_spreads   = 4.0;
input double strategy_max_spread_median_mult  = 2.5;
input int    strategy_spread_median_bars      = 64;

int      g_session_ymd = 0;
bool     g_anchor_ready = false;
datetime g_anchor_time = 0;
double   g_anchor_price = 0.0;
double   g_long_threshold = 0.0;
double   g_short_threshold = 0.0;
bool     g_long_touched = false;
bool     g_short_touched = false;
bool     g_long_retested = false;
bool     g_short_retested = false;
bool     g_long_taken = false;
bool     g_short_taken = false;
int      g_long_touch_elapsed = -1;
int      g_short_touch_elapsed = -1;
double   g_spread_samples[];
int      g_spread_count = 0;
int      g_spread_index = 0;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

int Ymd(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

bool SymbolContains(const string needle)
  {
   return (StringFind(_Symbol, needle) >= 0);
  }

bool IsForexSymbol()
  {
   return (SymbolContains("EUR") || SymbolContains("GBP") || SymbolContains("USD") ||
           SymbolContains("JPY") || SymbolContains("CHF") || SymbolContains("AUD") ||
           SymbolContains("CAD") || SymbolContains("NZD"));
  }

bool IsCommoditySymbol()
  {
   return (SymbolContains("XAU") || SymbolContains("XAG") || SymbolContains("XTI") ||
           SymbolContains("XNG"));
  }

int SessionStartHhmm()
  {
   if(IsCommoditySymbol())
      return strategy_commodity_session_start;
   if(SymbolContains("NDX") || SymbolContains("SP500") || SymbolContains("WS30"))
      return strategy_us_index_session_start;
   if(SymbolContains("GDAXI") || SymbolContains("GER") || SymbolContains("UK100"))
      return strategy_eu_index_session_start;
   return strategy_forex_session_start;
  }

double ThresholdPct()
  {
   if(IsCommoditySymbol())
      return strategy_commodity_threshold_pct;
   if(IsForexSymbol())
      return strategy_forex_threshold_pct;
   return strategy_index_threshold_pct;
  }

bool IsInsideSession(const datetime t)
  {
   const int now_hhmm = Hhmm(t);
   const int start_hhmm = SessionStartHhmm();
   if(start_hhmm <= strategy_session_close)
      return (now_hhmm >= start_hhmm && now_hhmm < strategy_session_close);
   return (now_hhmm >= start_hhmm || now_hhmm < strategy_session_close);
  }

double CurrentSpreadPrice()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(point > 0.0 && spread_points > 0)
      return (double)spread_points * point;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > bid)
      return ask - bid;
   return 0.0;
  }

void UpdateSpreadMedian()
  {
   const int capacity = MathMax(1, MathMin(strategy_spread_median_bars, 256));
   if(ArraySize(g_spread_samples) != capacity)
     {
      ArrayResize(g_spread_samples, capacity);
      g_spread_count = 0;
      g_spread_index = 0;
     }

   const double spread = CurrentSpreadPrice();
   if(spread <= 0.0)
      return;

   g_spread_samples[g_spread_index] = spread;
   g_spread_index = (g_spread_index + 1) % capacity;
   if(g_spread_count < capacity)
      g_spread_count++;
  }

double RollingMedianSpread()
  {
   if(g_spread_count <= 0)
      return 0.0;

   double values[];
   ArrayResize(values, g_spread_count);
   for(int i = 0; i < g_spread_count; ++i)
      values[i] = g_spread_samples[i];

   ArraySort(values);
   const int mid = g_spread_count / 2;
   if((g_spread_count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool SpreadAllowsEntry()
  {
   const double spread = CurrentSpreadPrice();
   const double median = RollingMedianSpread();
   if(spread <= 0.0 || median <= 0.0 || g_spread_count < 10)
      return true;
   return (spread <= median * strategy_max_spread_median_mult);
  }

bool HasOurOpenPosition()
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

bool GetOurPosition(ENUM_POSITION_TYPE &position_type)
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

void ResetSessionState(const datetime anchor_time, const double anchor_price)
  {
   g_session_ymd = Ymd(anchor_time);
   g_anchor_ready = true;
   g_anchor_time = anchor_time;
   g_anchor_price = anchor_price;

   const double threshold = ThresholdPct() / 100.0;
   g_long_threshold = g_anchor_price * (1.0 + threshold);
   g_short_threshold = g_anchor_price * (1.0 - threshold);

   g_long_touched = false;
   g_short_touched = false;
   g_long_retested = false;
   g_short_retested = false;
   g_long_taken = false;
   g_short_taken = false;
   g_long_touch_elapsed = -1;
   g_short_touch_elapsed = -1;
  }

bool ThresholdDistanceAllowsTrade()
  {
   const double spread = CurrentSpreadPrice();
   if(spread <= 0.0 || g_anchor_price <= 0.0)
      return false;
   const double distance = MathAbs(g_long_threshold - g_anchor_price);
   return (distance >= spread * strategy_min_threshold_spreads);
  }

bool BuildEntryRequest(QM_EntryRequest &req, const QM_OrderType side, const string reason)
  {
   const double entry = QM_OrderTypeIsBuy(side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;
   if(!IsInsideSession(TimeCurrent()))
      return true;
   if(!SpreadAllowsEntry())
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

   UpdateSpreadMedian();

   if(_Period != PERIOD_M1)
      return false;
   if(HasOurOpenPosition())
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   const double close_1 = iClose(_Symbol, _Period, 1);
   const double close_2 = iClose(_Symbol, _Period, 2);
   if(bar_time <= 0 || close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   if(!IsInsideSession(bar_time))
      return false;

   const int today = Ymd(bar_time);
   if(!g_anchor_ready || g_session_ymd != today)
     {
      if(Hhmm(bar_time) < SessionStartHhmm())
         return false;
      ResetSessionState(bar_time, close_1);
      return false;
     }

   if(!SpreadAllowsEntry() || !ThresholdDistanceAllowsTrade())
      return false;

   const int elapsed_minutes = (int)((bar_time - g_anchor_time) / 60);
   if(elapsed_minutes < 0)
      return false;

   if(elapsed_minutes <= strategy_detect_window_minutes)
     {
      if(!g_long_touched && close_1 >= g_long_threshold)
        {
         g_long_touched = true;
         g_long_touch_elapsed = elapsed_minutes;
        }
      if(!g_short_touched && close_1 <= g_short_threshold)
        {
         g_short_touched = true;
         g_short_touch_elapsed = elapsed_minutes;
        }
     }

   if(g_long_touched && !g_long_taken &&
      elapsed_minutes >= g_long_touch_elapsed + strategy_wait_bars &&
      elapsed_minutes <= strategy_entry_window_minutes)
     {
      if(close_1 <= g_long_threshold)
         g_long_retested = true;
      if(g_long_retested && close_2 <= g_long_threshold && close_1 > g_long_threshold)
        {
         if(BuildEntryRequest(req, QM_BUY, "ET_RALLY_RETEST_LONG"))
           {
            g_long_taken = true;
            return true;
           }
        }
     }

   if(g_short_touched && !g_short_taken &&
      elapsed_minutes >= g_short_touch_elapsed + strategy_wait_bars &&
      elapsed_minutes <= strategy_entry_window_minutes)
     {
      if(close_1 >= g_short_threshold)
         g_short_retested = true;
      if(g_short_retested && close_2 >= g_short_threshold && close_1 < g_short_threshold)
        {
         if(BuildEntryRequest(req, QM_SELL, "ET_RALLY_RETEST_SHORT"))
           {
            g_short_taken = true;
            return true;
           }
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!GetOurPosition(position_type))
      return false;

   if(!IsInsideSession(TimeCurrent()))
      return true;

   if(!g_anchor_ready)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(position_type == POSITION_TYPE_BUY && bid > 0.0 && bid < g_long_threshold)
      return true;
   if(position_type == POSITION_TYPE_SELL && ask > 0.0 && ask > g_short_threshold)
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
