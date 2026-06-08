#property strict
#property version   "5.0"
#property description "QM5_11343 Triad Session Open Breakout Scalping"

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
input int    qm_ea_id                   = 11343;
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
input int    strategy_est_to_broker_offset_hours = 7;
input bool   strategy_trade_asian_session        = false;
input bool   strategy_trade_european_session     = false;
input bool   strategy_trade_london_session       = true;
input bool   strategy_trade_ny_session           = true;
input int    strategy_signal_valid_bars          = 3;
input int    strategy_tp_pips                    = 12;
input int    strategy_sl_pips                    = 10;
input double strategy_spread_cap_pips            = 3.0;
input double strategy_min_session_range_pips     = 5.0;

int g_last_long_session_key[4]  = {-1, -1, -1, -1};
int g_last_short_session_key[4] = {-1, -1, -1, -1};

int NormalizeHour(const int hour)
  {
   int h = hour % 24;
   if(h < 0)
      h += 24;
   return h;
  }

int SessionStartHourBroker(const int session_index)
  {
   const int offset = strategy_est_to_broker_offset_hours;
   switch(session_index)
     {
      case 0: return NormalizeHour(19 + offset); // Asian 7pm EST
      case 1: return NormalizeHour(2 + offset);  // European 2am EST
      case 2: return NormalizeHour(3 + offset);  // London 3am EST
      case 3: return NormalizeHour(8 + offset);  // NY 8am EST
     }
   return -1;
  }

bool SessionEnabled(const int session_index)
  {
   switch(session_index)
     {
      case 0: return strategy_trade_asian_session;
      case 1: return strategy_trade_european_session;
      case 2: return strategy_trade_london_session;
      case 3: return strategy_trade_ny_session;
     }
   return false;
  }

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int SessionKey(const datetime t, const int session_index)
  {
   return DateKey(t) * 10 + session_index;
  }

bool IsWithinActiveSessionWindow(const datetime t, int &session_index, int &session_age_bars)
  {
   session_index = -1;
   session_age_bars = -1;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   for(int i = 0; i < 4; ++i)
     {
      if(!SessionEnabled(i))
         continue;

      const int start_hour = SessionStartHourBroker(i);
      const int age = (dt.hour - start_hour + 24) % 24;
      if(age >= 0 && age < strategy_signal_valid_bars)
        {
         session_index = i;
         session_age_bars = age;
         return true;
        }
     }

   return false;
  }

double PipDistance(const double pips)
  {
   if(pips <= 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
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

bool ReadPriorSessionRange(const int signal_age_bars, double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;
   if(signal_age_bars <= 0)
      return false;

   for(int shift = 2; shift <= signal_age_bars + 1; ++shift)
     {
      const double h = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded session-box structural read, called only after QM_IsNewBar gate.
      const double l = iLow(_Symbol, _Period, shift);  // perf-allowed: bounded session-box structural read, called only after QM_IsNewBar gate.
      if(h <= 0.0 || l <= 0.0)
         return false;

      if(h > range_high)
         range_high = h;
      if(l < range_low)
         range_low = l;
     }

   return (range_high > range_low && range_low < DBL_MAX);
  }

void MarkDirectionTraded(const int session_index, const int session_key, const QM_OrderType side)
  {
   if(session_index < 0 || session_index >= 4)
      return;

   if(QM_OrderTypeIsBuy(side))
      g_last_long_session_key[session_index] = session_key;
   else
      g_last_short_session_key[session_index] = session_key;
  }

bool DirectionAlreadyTraded(const int session_index, const int session_key, const QM_OrderType side)
  {
   if(session_index < 0 || session_index >= 4)
      return true;

   if(QM_OrderTypeIsBuy(side))
      return (g_last_long_session_key[session_index] == session_key);
   return (g_last_short_session_key[session_index] == session_key);
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

   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread_cap = PipDistance(strategy_spread_cap_pips);
   if(spread_cap > 0.0 && spread > spread_cap)
      return true;

   int session_index = -1;
   int session_age_bars = -1;
   if(!IsWithinActiveSessionWindow(TimeCurrent(), session_index, session_age_bars))
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

   if(_Period != PERIOD_H1)
      return false;

   const datetime signal_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp for session-box structural logic.
   if(signal_bar_time <= 0)
      return false;

   int session_index = -1;
   int session_age_bars = -1;
   if(!IsWithinActiveSessionWindow(signal_bar_time, session_index, session_age_bars))
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!ReadPriorSessionRange(session_age_bars, range_high, range_low))
      return false;

   const double min_range = PipDistance(strategy_min_session_range_pips);
   if(min_range > 0.0 && (range_high - range_low) < min_range)
      return false;

   const double signal_high = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar breakout read for bespoke session-box logic.
   const double signal_low = iLow(_Symbol, _Period, 1);   // perf-allowed: closed-bar breakout read for bespoke session-box logic.
   if(signal_high <= 0.0 || signal_low <= 0.0)
      return false;

   const int session_key = SessionKey(signal_bar_time, session_index);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(signal_high > range_high && !DirectionAlreadyTraded(session_index, session_key, QM_BUY))
     {
      req.type = QM_BUY;
      req.sl = QM_StopFixedPips(_Symbol, req.type, ask, strategy_sl_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, ask, strategy_tp_pips);
      req.reason = "TRIAD_SESSION_BREAKOUT_LONG";
      if(req.sl <= 0.0 || req.tp <= 0.0)
         return false;
      MarkDirectionTraded(session_index, session_key, req.type);
      return true;
     }

   if(signal_low < range_low && !DirectionAlreadyTraded(session_index, session_key, QM_SELL))
     {
      req.type = QM_SELL;
      req.sl = QM_StopFixedPips(_Symbol, req.type, bid, strategy_sl_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, bid, strategy_tp_pips);
      req.reason = "TRIAD_SESSION_BREAKOUT_SHORT";
      if(req.sl <= 0.0 || req.tp <= 0.0)
         return false;
      MarkDirectionTraded(session_index, session_key, req.type);
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card uses fixed SL/TP only; no trailing, break-even, or partial logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, _Period, open_time, false);
      if(open_shift >= 1)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy))
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
