#property strict
#property version   "5.0"
#property description "QM5_1098 Unger S&P Pivot-Point Trend Following"

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
input int    qm_ea_id                   = 1098;
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
input int    strategy_entry_hhmm_ny       = 1030;
input int    strategy_cash_open_hhmm_ny   = 930;
input int    strategy_cash_close_hhmm_ny  = 1600;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input bool   strategy_use_rr_tp           = false;
input double strategy_rr_tp               = 2.0;
input double strategy_median_spread_points = 0.0;
input int    strategy_pivot_scan_bars     = 160;

int      g_pivot_day_key = 0;
double   g_cached_r1 = 0.0;
double   g_cached_s1 = 0.0;
int      g_last_entry_eval_day_key = 0;

int HhmmToMinutes(const int hhmm)
  {
   return ((hhmm / 100) * 60) + (hhmm % 100);
  }

datetime BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   return utc + (ny_offset_hours * 3600);
  }

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return (dt.year * 10000) + (dt.mon * 100) + dt.day;
  }

int NewYorkDateKey(const datetime broker_time)
  {
   return DateKey(BrokerToNewYork(broker_time));
  }

int NewYorkMinutes(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return (dt.hour * 60) + dt.min;
  }

bool IsNewYorkWeekday(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
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

bool GetOurPositionType(ENUM_POSITION_TYPE &position_type)
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

double CurrentSpreadPoints()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return 0.0;
   if(ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

bool ComputePreviousCashPivots(const int current_ny_key, double &out_r1, double &out_s1)
  {
   out_r1 = 0.0;
   out_s1 = 0.0;

   if(g_pivot_day_key == current_ny_key && g_cached_r1 > 0.0 && g_cached_s1 > 0.0)
     {
      out_r1 = g_cached_r1;
      out_s1 = g_cached_s1;
      return true;
     }

   const int open_min = HhmmToMinutes(strategy_cash_open_hhmm_ny);
   const int close_min = HhmmToMinutes(strategy_cash_close_hhmm_ny);
   int target_key = 0;
   double prev_high = 0.0;
   double prev_low = 0.0;
   double prev_close = 0.0;

   for(int shift = 1; shift <= strategy_pivot_scan_bars; ++shift)
     {
      const datetime bar_broker = iTime(_Symbol, PERIOD_M30, shift); // perf-allowed: bounded previous cash-session pivot scan, called only inside framework closed-bar entry hook.
      if(bar_broker <= 0)
         continue;

      const datetime bar_ny = BrokerToNewYork(bar_broker);
      const int bar_key = DateKey(bar_ny);
      if(bar_key >= current_ny_key)
         continue;

      MqlDateTime dt;
      ZeroMemory(dt);
      TimeToStruct(bar_ny, dt);
      if(dt.day_of_week < 1 || dt.day_of_week > 5)
         continue;

      const int bar_min = (dt.hour * 60) + dt.min;
      if(bar_min < open_min || bar_min >= close_min)
         continue;

      if(target_key == 0)
        {
         target_key = bar_key;
         prev_close = iClose(_Symbol, PERIOD_M30, shift); // perf-allowed: final bar close of prior cash session for floor pivot.
        }
      else if(bar_key != target_key)
         break;

      const double h = iHigh(_Symbol, PERIOD_M30, shift); // perf-allowed: bounded prior cash-session high for floor pivot.
      const double l = iLow(_Symbol, PERIOD_M30, shift);  // perf-allowed: bounded prior cash-session low for floor pivot.
      if(h <= 0.0 || l <= 0.0)
         continue;
      if(prev_high == 0.0 || h > prev_high)
         prev_high = h;
      if(prev_low == 0.0 || l < prev_low)
         prev_low = l;
     }

   if(prev_high <= 0.0 || prev_low <= 0.0 || prev_close <= 0.0 || prev_high <= prev_low)
      return false;

   const double pivot = (prev_high + prev_low + prev_close) / 3.0;
   g_cached_r1 = QM_StopRulesNormalizePrice(_Symbol, (2.0 * pivot) - prev_low);
   g_cached_s1 = QM_StopRulesNormalizePrice(_Symbol, (2.0 * pivot) - prev_high);
   g_pivot_day_key = current_ny_key;
   out_r1 = g_cached_r1;
   out_s1 = g_cached_s1;
   return (out_r1 > 0.0 && out_s1 > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   const bool has_position = HasOurOpenPosition();

   if(!IsNewYorkWeekday(broker_now) && !has_position)
      return true;

   const int ny_minutes = NewYorkMinutes(broker_now);
   const int open_min = HhmmToMinutes(strategy_cash_open_hhmm_ny);
   const int close_min = HhmmToMinutes(strategy_cash_close_hhmm_ny);
   if((ny_minutes < open_min || ny_minutes > close_min) && !has_position)
      return true;

   const double spread_points = CurrentSpreadPoints();
   if(strategy_median_spread_points > 0.0 &&
      spread_points > (2.0 * strategy_median_spread_points))
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

   if(HasOurOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(!IsNewYorkWeekday(broker_now))
      return false;

   const int ny_key = NewYorkDateKey(broker_now);
   const int ny_minutes = NewYorkMinutes(broker_now);
   if(ny_minutes != HhmmToMinutes(strategy_entry_hhmm_ny))
      return false;

   if(g_last_entry_eval_day_key == ny_key)
      return false;
   g_last_entry_eval_day_key = ny_key;

   double r1 = 0.0;
   double s1 = 0.0;
   if(!ComputePreviousCashPivots(ny_key, r1, s1))
      return false;

   const double close_m30 = iClose(_Symbol, PERIOD_M30, 1); // perf-allowed: fixed closed M30 decision bar at 10:30 NY.
   if(close_m30 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close_m30 > r1)
     {
      req.type = QM_BUY;
      const double entry = (ask > 0.0) ? ask : close_m30;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      if(req.sl <= 0.0)
         return false;
      req.tp = strategy_use_rr_tp ? QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_tp) : 0.0;
      req.reason = "UNGER_PIVOT_R1_BREAK";
      return true;
     }

   if(close_m30 < s1)
     {
      req.type = QM_SELL;
      const double entry = (bid > 0.0) ? bid : close_m30;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      if(req.sl <= 0.0)
         return false;
      req.tp = strategy_use_rr_tp ? QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_tp) : 0.0;
      req.reason = "UNGER_PIVOT_S1_BREAK";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR stop, no trailing, no BE, no partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!GetOurPositionType(position_type))
      return false;

   const datetime broker_now = TimeCurrent();
   const int ny_minutes = NewYorkMinutes(broker_now);
   if(ny_minutes >= HhmmToMinutes(strategy_cash_close_hhmm_ny))
      return true;

   if(g_cached_r1 <= 0.0 || g_cached_s1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && bid < g_cached_s1)
      return true;
   if(position_type == POSITION_TYPE_SELL && ask > g_cached_r1)
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
