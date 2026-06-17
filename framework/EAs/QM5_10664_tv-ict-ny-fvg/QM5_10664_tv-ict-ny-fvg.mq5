#property strict
#property version   "5.0"
#property description "QM5_10664 TradingView ICT NY Kill Zone FVG + Order Block"

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
input int    qm_ea_id                   = 10664;
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
// ICT NY Kill Zone FVG + Order Block (TradingView "ICT NY Kill Zone Auto Trading",
// author EisperICT). NY Kill Zone window is expressed in NEW YORK local time and
// converted to broker time DST-aware at runtime (DXZ broker = NY-Close GMT+2/+3).
// 09:30-11:00 ET (cash NY open kill zone) => broker ~14:30-16:00 GMT+2 / ~15:30-17:00
// GMT+3. We compute NY wall-clock from broker time so the window is symbol-correct
// year-round (the card's NY Kill Zone is the same ET window in summer and winter).
input int    strategy_kz_start_hhmm     = 930;   // NY Kill Zone start (HHMM, New York local)
input int    strategy_kz_end_hhmm       = 1100;  // NY Kill Zone end   (HHMM, New York local)
input int    strategy_sl_pips           = 30;    // fixed stop-loss, pips (card)
input int    strategy_tp_pips           = 60;    // fixed take-profit, pips (card)
input int    strategy_ob_lookback       = 20;    // bars back to search for aligning OB
input int    strategy_max_spread_points = 0;     // 0 = disabled (DWX quotes 0 spread in tester)

// File-scope per-NY-day state. Advanced once per closed bar via the new-bar gate.
int    g_ny_day_key       = 0;
bool   g_trade_taken_today = false;

int HHMMToMinutes(const int hhmm)
  {
   const int hour   = hhmm / 100;
   const int minute = hhmm % 100;
   return hour * 60 + minute;
  }

// Convert a broker timestamp to New York local time. Broker = DXZ NY-close
// (GMT+2 standard / GMT+3 during US DST). New York = GMT-5 standard / GMT-4
// during US DST. We route via UTC so both DST transitions are handled by the
// single canonical US-DST helper (no UK/JP DST involved here).
datetime BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   const int offset_hours  = QM_IsUSDSTUTC(utc_time) ? -4 : -5;
   return utc_time + offset_hours * 3600;
  }

int NYDayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int NYMinutes(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return dt.hour * 60 + dt.min;
  }

void RefreshNYDayState()
  {
   const int day_key = NYDayKey(TimeCurrent());
   if(day_key == g_ny_day_key)
      return;
   g_ny_day_key        = day_key;
   g_trade_taken_today = false;
  }

bool InKillZone()
  {
   const int now_minutes = NYMinutes(TimeCurrent());
   return (now_minutes >= HHMMToMinutes(strategy_kz_start_hhmm) &&
           now_minutes <= HHMMToMinutes(strategy_kz_end_hhmm));
  }

bool KillZoneEnded()
  {
   return (NYMinutes(TimeCurrent()) > HHMMToMinutes(strategy_kz_end_hhmm));
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

bool SpreadAllowed()
  {
   // .DWX quotes ask==bid (0 modeled spread) in the tester — never fail-closed
   // on zero spread. Only block a genuinely wide spread when a cap is set.
   if(strategy_max_spread_points <= 0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true; // fail-open: do not block on bad/zero quotes in the tester
   if(ask <= bid)
      return true; // zero/negative modeled spread is fine
   return ((ask - bid) / point <= strategy_max_spread_points);
  }

// --- ICT structural primitives (closed-bar reads) --------------------------
// A bullish FVG (fair-value gap / 3-candle imbalance) exists when the low of
// the most recent closed bar (shift `mid-1`) is above the high of the bar two
// before it (shift `mid+1`): low[mid-1] > high[mid+1]. The gap sits at the
// middle bar `mid`. Mirror for a bearish FVG. We evaluate the gap formed by
// the three most recently CLOSED bars: shifts 1 (newest), 2 (middle), 3.

bool BullishFVG(double &gap_low, double &gap_high)
  {
   const double low_new  = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);  // perf-allowed: card-defined 3-bar FVG, closed bars.
   const double high_old = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed: card-defined 3-bar FVG, closed bars.
   if(low_new <= 0.0 || high_old <= 0.0)
      return false;
   if(low_new <= high_old)
      return false;
   gap_low  = high_old;
   gap_high = low_new;
   return true;
  }

bool BearishFVG(double &gap_low, double &gap_high)
  {
   const double high_new = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: card-defined 3-bar FVG, closed bars.
   const double low_old  = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 3);  // perf-allowed: card-defined 3-bar FVG, closed bars.
   if(high_new <= 0.0 || low_old <= 0.0)
      return false;
   if(high_new >= low_old)
      return false;
   gap_low  = high_new;
   gap_high = low_old;
   return true;
  }

// Order block: the last opposite-colour candle before the impulse. For a long
// (bullish OB) we look for the most recent down-candle (close<open) within the
// lookback; its body defines the OB zone. Mirror for short. Returns the body
// extent so we can test FVG/OB alignment.
bool FindLastOrderBlock(const bool bullish, double &ob_low, double &ob_high)
  {
   for(int shift = 1; shift <= strategy_ob_lookback; ++shift)
     {
      const double open  = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);  // perf-allowed: bounded OB search, closed bars.
      const double close = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bounded OB search, closed bars.
      if(open <= 0.0 || close <= 0.0)
         continue;

      if(bullish && close < open)        // last bearish candle = bullish OB
        {
         ob_low  = MathMin(open, close);
         ob_high = MathMax(open, close);
         return (ob_low < ob_high);
        }
      if(!bullish && close > open)       // last bullish candle = bearish OB
        {
         ob_low  = MathMin(open, close);
         ob_high = MathMax(open, close);
         return (ob_low < ob_high);
        }
     }
   return false;
  }

// Two price ranges [a_low,a_high] and [b_low,b_high] align when they overlap.
bool RangesOverlap(const double a_low, const double a_high,
                   const double b_low, const double b_high)
  {
   return (a_low <= b_high && b_low <= a_high);
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   RefreshNYDayState();

   // Let trade management / exit run while a position is open.
   if(HasOurOpenPosition())
      return false;

   if(!InKillZone())
      return true;

   if(!SpreadAllowed())
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);
   RefreshNYDayState();

   // One position per symbol/magic per NY day, NY Kill Zone only.
   if(g_trade_taken_today || HasOurOpenPosition() || !InKillZone())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // --- Long: bullish OB aligned with a bullish FVG -----------------------
   double fvg_low = 0.0, fvg_high = 0.0;
   double ob_low  = 0.0, ob_high  = 0.0;
   if(BullishFVG(fvg_low, fvg_high) &&
      FindLastOrderBlock(true, ob_low, ob_high) &&
      RangesOverlap(fvg_low, fvg_high, ob_low, ob_high))
     {
      const double entry = ask;
      const double sl    = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp    = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "TV_ICT_NY_FVG_LONG";
      g_trade_taken_today = true;
      return true;
     }

   // --- Short: bearish OB aligned with a bearish FVG ----------------------
   if(BearishFVG(fvg_low, fvg_high) &&
      FindLastOrderBlock(false, ob_low, ob_high) &&
      RangesOverlap(fvg_low, fvg_high, ob_low, ob_high))
     {
      const double entry = bid;
      const double sl    = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp    = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "TV_ICT_NY_FVG_SHORT";
      g_trade_taken_today = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card uses a fixed 30-pip SL and fixed 60-pip TP only; no BE, trail, or
   // partial close. Force-flat after the kill zone is handled in Strategy_ExitSignal.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card: force flat after the NY Kill Zone — no overnight carry.
   if(!KillZoneEnded())
      return false;
   return HasOurOpenPosition();
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
