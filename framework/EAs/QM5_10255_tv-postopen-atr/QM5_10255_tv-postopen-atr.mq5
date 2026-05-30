#property strict
#property version   "5.0"
#property description "QM5_10255 TradingView Post-Open ATR Breakout"

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
input int    qm_ea_id                   = 10255;
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
input ENUM_TIMEFRAMES strategy_signal_tf             = PERIOD_CURRENT;
input int    strategy_bb_period                      = 14;
input double strategy_bb_deviation                   = 1.5;
input int    strategy_ema_fast_period                = 10;
input int    strategy_ema_slow_period                = 200;
input int    strategy_rsi_period                     = 7;
input double strategy_rsi_min                        = 30.0;
input int    strategy_adx_period                     = 7;
input double strategy_adx_min                        = 10.0;
input int    strategy_atr_period                     = 14;
input double strategy_atr_sl_mult                    = 2.0;
input double strategy_atr_tp_mult                    = 4.0;
input int    strategy_resistance_lookback            = 20;
input int    strategy_resistance_min_touches         = 2;
input double strategy_res_touch_tolerance_atr        = 0.05;
input double strategy_lateral_band_fraction          = 0.25;
input double strategy_spread_stop_fraction           = 0.10;

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   if(strategy_signal_tf == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)_Period;
   return strategy_signal_tf;
  }

int Strategy_LastSundayOfMonth(const int year, const int month)
  {
   const int days = QM_DSTAware_DaysInMonth(year, month);
   for(int day = days; day >= 1; --day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon = month;
      dt.day = day;
      const datetime t = StructToTime(dt);
      if(QM_DSTAware_DayOfWeek(t) == SUNDAY)
         return day;
     }
   return days;
  }

bool Strategy_IsEuropeBerlinDstUTC(const datetime utc)
  {
   MqlDateTime base;
   ZeroMemory(base);
   TimeToStruct(utc, base);

   MqlDateTime start;
   ZeroMemory(start);
   start.year = base.year;
   start.mon = 3;
   start.day = Strategy_LastSundayOfMonth(base.year, 3);
   start.hour = 1;

   MqlDateTime stop;
   ZeroMemory(stop);
   stop.year = base.year;
   stop.mon = 10;
   stop.day = Strategy_LastSundayOfMonth(base.year, 10);
   stop.hour = 1;

   const datetime start_utc = StructToTime(start);
   const datetime stop_utc = StructToTime(stop);
   return (utc >= start_utc && utc < stop_utc);
  }

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_InWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

bool Strategy_InSourceSession(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const datetime berlin_time = utc + (Strategy_IsEuropeBerlinDstUTC(utc) ? 2 : 1) * 3600;
   // Source lists German 08:00-12:00 and US-open 15:30-19:00 as human session windows.
   // Convert broker time to Berlin market-clock time before comparing those literals.
   return Strategy_InWindow(Strategy_Hhmm(berlin_time), 800, 1200) ||
          Strategy_InWindow(Strategy_Hhmm(berlin_time), 1530, 1900);
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

bool Strategy_SpreadAllowed(const double atr_value)
  {
   if(atr_value <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_spread_stop_fraction < 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double max_spread = atr_value * strategy_atr_sl_mult * strategy_spread_stop_fraction;
   return ((ask - bid) <= max_spread);
  }

bool Strategy_PreviousResistance(const ENUM_TIMEFRAMES tf, double &resistance, int &touches)
  {
   resistance = 0.0;
   touches = 0;
   if(strategy_resistance_lookback < 2 || strategy_resistance_min_touches < 1)
      return false;

   for(int shift = 2; shift < 2 + strategy_resistance_lookback; ++shift)
     {
      const double high_price = iHigh(_Symbol, tf, shift);
      if(high_price <= 0.0)
         return false;
      if(high_price > resistance)
         resistance = high_price;
     }

   const double atr_value = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double tolerance = atr_value * strategy_res_touch_tolerance_atr;
   for(int shift = 2; shift < 2 + strategy_resistance_lookback; ++shift)
     {
      const double high_price = iHigh(_Symbol, tf, shift);
      if(MathAbs(high_price - resistance) <= tolerance)
         ++touches;
     }

   return (resistance > 0.0 && touches >= strategy_resistance_min_touches);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): entry-only so session-end flatten can run.
   if(Strategy_HasOpenPosition())
      return false;

   if(!Strategy_InSourceSession(TimeCurrent()))
      return true;

   const double atr_value = QM_ATR(_Symbol, Strategy_Timeframe(), strategy_atr_period, 1);
   if(!Strategy_SpreadAllowed(atr_value))
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
   if(!Strategy_InSourceSession(TimeCurrent()))
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_Timeframe();
   double resistance = 0.0;
   int touches = 0;
   if(!Strategy_PreviousResistance(tf, resistance, touches))
      return false;

   const double open1 = iOpen(_Symbol, tf, 1);
   const double close1 = iClose(_Symbol, tf, 1);
   const double open2 = iOpen(_Symbol, tf, 2);
   const double close2 = iClose(_Symbol, tf, 2);
   const double open3 = iOpen(_Symbol, tf, 3);
   const double close3 = iClose(_Symbol, tf, 3);
   if(open1 <= 0.0 || close1 <= 0.0 || open2 <= 0.0 || close2 <= 0.0 ||
      open3 <= 0.0 || close3 <= 0.0)
      return false;

   const double bb_mid2 = QM_BB_Middle(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_upper2 = QM_BB_Upper(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_lower2 = QM_BB_Lower(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double ema_fast1 = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 1);
   const double ema_slow1 = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 1);
   const double rsi1 = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double adx1 = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
   const double atr1 = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(bb_mid2 <= 0.0 || bb_upper2 <= 0.0 || bb_lower2 <= 0.0 ||
      ema_fast1 <= 0.0 || ema_slow1 <= 0.0 || rsi1 <= 0.0 ||
      adx1 <= 0.0 || atr1 <= 0.0)
      return false;
   if(!Strategy_SpreadAllowed(atr1))
      return false;

   const double band_width = bb_upper2 - bb_lower2;
   if(band_width <= 0.0)
      return false;

   const bool lateral_before = (MathAbs(close2 - bb_mid2) <= strategy_lateral_band_fraction * band_width);
   const bool previous_two_not_both_bearish = !((close2 < open2) && (close3 < open3));
   const bool current_bearish = (close1 < open1);

   if(close1 <= resistance ||
      !lateral_before ||
      close1 <= ema_fast1 ||
      close1 <= ema_slow1 ||
      rsi1 <= strategy_rsi_min ||
      adx1 <= strategy_adx_min ||
      !previous_two_not_both_bearish ||
      !current_bearish)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr1, strategy_atr_sl_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr1, strategy_atr_tp_mult);
   req.reason = StringFormat("POSTOPEN_ATR_BREAKOUT_T%d", touches);
   return (req.sl > 0.0 && req.tp > entry);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline uses fixed ATR SL/TP only: no trailing, BE, partials, or add-ons.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return (Strategy_HasOpenPosition() && !Strategy_InSourceSession(TimeCurrent()));
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
