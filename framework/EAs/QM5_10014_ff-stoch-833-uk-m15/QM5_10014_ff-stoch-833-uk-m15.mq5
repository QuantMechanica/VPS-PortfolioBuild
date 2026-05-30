#property strict
#property version   "5.0"
#property description "QM5_10014 ForexFactory Stochastic 8/3/3 UK M15 Scalp"

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
input int    qm_ea_id                   = 10014;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_M15;
input int    strategy_stoch_k_period      = 8;
input int    strategy_stoch_d_period      = 3;
input int    strategy_stoch_slowing       = 3;
input int    strategy_arm_lookback_bars   = 3;
input double strategy_long_arm_level      = 20.0;
input double strategy_long_cross_level    = 30.0;
input double strategy_short_arm_level     = 80.0;
input double strategy_short_cross_level   = 70.0;
input int    strategy_stop_pips           = 20;
input int    strategy_tp_pips_fx_major    = 10;
input int    strategy_tp_pips_jpy_cross   = 15;
input int    strategy_breakeven_pips      = 10;
input int    strategy_max_hold_bars       = 8;
input int    strategy_uk_start_hhmm       = 600;
input int    strategy_uk_end_hhmm         = 1000;
input double strategy_max_spread_stop_pct = 15.0;

int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4) == 0 && (year % 100) != 0) || ((year % 400) == 0);
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

int Strategy_LastSundayDay(const int year, const int month)
  {
   for(int day = Strategy_DaysInMonth(year, month); day >= 1; --day)
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
      if(checked.day_of_week == 0)
         return day;
     }
   return -1;
  }

datetime Strategy_UKDSTBoundaryUTC(const int year, const int month)
  {
   const int day = Strategy_LastSundayDay(year, month);
   if(day < 1)
      return 0;

   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = 1;
   return StructToTime(dt);
  }

bool Strategy_IsUKDSTUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_time, dt);

   const datetime start_utc = Strategy_UKDSTBoundaryUTC(dt.year, 3);
   const datetime end_utc = Strategy_UKDSTBoundaryUTC(dt.year, 10);
   if(start_utc <= 0 || end_utc <= 0)
      return false;
   return (utc_time >= start_utc && utc_time < end_utc);
  }

datetime Strategy_BrokerToUKTime(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return utc_time + (Strategy_IsUKDSTUTC(utc_time) ? 3600 : 0);
  }

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_IsUKEntrySession(const datetime broker_time)
  {
   const int hhmm = Strategy_HHMM(Strategy_BrokerToUKTime(broker_time));
   return (hhmm >= strategy_uk_start_hhmm && hhmm < strategy_uk_end_hhmm);
  }

bool Strategy_IsUKCloseTime(const datetime broker_time)
  {
   return (Strategy_HHMM(Strategy_BrokerToUKTime(broker_time)) >= strategy_uk_end_hhmm);
  }

bool Strategy_IsJPYCross()
  {
   return (StringFind(_Symbol, "JPY") >= 0);
  }

int Strategy_TakeProfitPips()
  {
   return Strategy_IsJPYCross() ? strategy_tp_pips_jpy_cross : strategy_tp_pips_fx_major;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type,
                                datetime &open_time,
                                ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      ticket = t;
      return true;
     }
   return false;
  }

bool Strategy_HasOurPosition()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time = 0;
   ulong ticket = 0;
   return Strategy_SelectOurPosition(position_type, open_time, ticket);
  }

bool Strategy_LongArmed()
  {
   for(int shift = 1; shift <= strategy_arm_lookback_bars; ++shift)
     {
      const double k = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      const double d = QM_Stoch_D(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      if(k > 0.0 && d > 0.0 && k < strategy_long_arm_level && d < strategy_long_arm_level)
         return true;
     }
   return false;
  }

bool Strategy_ShortArmed()
  {
   for(int shift = 1; shift <= strategy_arm_lookback_bars; ++shift)
     {
      const double k = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      const double d = QM_Stoch_D(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      if(k > strategy_short_arm_level && d > strategy_short_arm_level)
         return true;
     }
   return false;
  }

bool Strategy_LongTrigger()
  {
   if(!Strategy_LongArmed())
      return false;

   const double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   return (k2 <= strategy_long_cross_level && k1 > strategy_long_cross_level);
  }

bool Strategy_ShortTrigger()
  {
   if(!Strategy_ShortArmed())
      return false;

   const double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   return (k2 >= strategy_short_cross_level && k1 < strategy_short_cross_level);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurPosition())
      return false;

   if(!Strategy_IsUKEntrySession(TimeCurrent()))
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double spread_ref_sl = QM_StopFixedPips(_Symbol, QM_BUY, bid, strategy_stop_pips);
   if(bid <= 0.0 || ask <= 0.0 || spread_ref_sl <= 0.0)
      return true;

   const double stop_distance = MathAbs(bid - spread_ref_sl);
   return ((ask - bid) > stop_distance * strategy_max_spread_stop_pct / 100.0);
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

   if(Strategy_HasOurPosition())
      return false;
   if(!Strategy_IsUKEntrySession(TimeCurrent()))
      return false;

   const bool long_signal = Strategy_LongTrigger();
   const bool short_signal = Strategy_ShortTrigger();
   if(!long_signal && !short_signal)
      return false;
   if(long_signal && short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_stop_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, Strategy_TakeProfitPips());
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "FF_STOCH_833_UK_M15_LONG" : "FF_STOCH_833_UK_M15_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_MoveToBreakEven(ticket, strategy_breakeven_pips, 0);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time = 0;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(position_type, open_time, ticket))
      return false;

   const datetime now = TimeCurrent();
   if(Strategy_IsUKCloseTime(now))
      return true;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_timeframe);
   if(hold_seconds > 0 && open_time > 0 && (now - open_time) >= hold_seconds)
      return true;

   if(position_type == POSITION_TYPE_BUY && Strategy_ShortTrigger())
      return true;
   if(position_type == POSITION_TYPE_SELL && Strategy_LongTrigger())
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
