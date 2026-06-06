#property strict
#property version   "5.0"
#property description "QM5_10870 TradingView 15-minute ORB volume breakout"

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
input int    qm_ea_id                   = 10870;
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
input int    strategy_range_start_hour_ny = 9;
input int    strategy_range_start_min_ny  = 30;
input int    strategy_opening_range_min   = 15;
input int    strategy_trade_end_hour_ny   = 11;
input int    strategy_trade_end_min_ny    = 30;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 1.2;
input double strategy_min_stop_atr_mult   = 0.6;
input double strategy_target_r            = 1.5;
input int    strategy_volume_sma_period   = 20;
input double strategy_volume_mult         = 1.2;
input bool   strategy_or_width_filter     = true;
input double strategy_or_min_atr_mult     = 0.3;
input double strategy_or_max_atr_mult     = 2.0;
input double strategy_max_spread_stop_pct = 0.10;

int    g_session_day_key       = 0;
bool   g_or_have_range         = false;
bool   g_or_complete           = false;
bool   g_trade_attempted_today = false;
double g_or_high               = 0.0;
double g_or_low                = 0.0;

datetime BrokerToNY(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   const int offset_hours = QM_IsUSDSTUTC(utc_time) ? -4 : -5;
   return utc_time + (datetime)(offset_hours * 3600);
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int RangeStartMinute()
  {
   return MathMax(0, MathMin(23, strategy_range_start_hour_ny)) * 60
          + MathMax(0, MathMin(59, strategy_range_start_min_ny));
  }

int RangeEndMinute()
  {
   return RangeStartMinute() + MathMax(1, strategy_opening_range_min);
  }

int TradeEndMinute()
  {
   return MathMax(0, MathMin(23, strategy_trade_end_hour_ny)) * 60
          + MathMax(0, MathMin(59, strategy_trade_end_min_ny));
  }

void ResetSessionIfNeeded(const datetime ny_time)
  {
   const int day_key = DayKey(ny_time);
   if(day_key == g_session_day_key)
      return;

   g_session_day_key = day_key;
   g_or_have_range = false;
   g_or_complete = false;
   g_trade_attempted_today = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
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

double VolumeSMA(const int period, const int first_shift)
  {
   if(period <= 0 || first_shift <= 0)
      return 0.0;

   double sum = 0.0;
   int count = 0;
   for(int i = first_shift; i < first_shift + period; ++i)
     {
      // perf-allowed: bounded tick-volume read for the card's ORB volume filter.
      const long volume = iVolume(_Symbol, _Period, i);
      if(volume <= 0)
         continue;
      sum += (double)volume;
      count++;
     }

   return (count > 0) ? (sum / count) : 0.0;
  }

void AdvanceOpeningRangeOnClosedBar()
  {
   // perf-allowed: session ORB state advances once per framework new-bar call.
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return;

   const datetime bar_open_ny = BrokerToNY(bar_open_broker);
   ResetSessionIfNeeded(bar_open_ny);

   const int bar_minute = MinuteOfDay(bar_open_ny);
   const int range_start = RangeStartMinute();
   const int range_end = RangeEndMinute();
   const int bar_minutes = MathMax(1, PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60);

   if(bar_minute >= range_start && bar_minute < range_end)
     {
      const double bar_high = iHigh(_Symbol, _Period, 1);
      const double bar_low = iLow(_Symbol, _Period, 1);
      if(bar_high > 0.0 && bar_low > 0.0)
        {
         if(!g_or_have_range)
           {
            g_or_high = bar_high;
            g_or_low = bar_low;
            g_or_have_range = true;
           }
         else
           {
            g_or_high = MathMax(g_or_high, bar_high);
            g_or_low = MathMin(g_or_low, bar_low);
           }
        }
     }

   if(g_or_have_range && bar_minute + bar_minutes >= range_end)
      g_or_complete = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime ny_now = BrokerToNY(TimeCurrent());
   ResetSessionIfNeeded(ny_now);

   if(HasOurOpenPosition())
      return false;

   MqlDateTime dt;
   TimeToStruct(ny_now, dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return true;

   const int minute = MinuteOfDay(ny_now);
   if(minute < RangeStartMinute() || minute >= TradeEndMinute())
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

   AdvanceOpeningRangeOnClosedBar();

   if(g_trade_attempted_today || HasOurOpenPosition())
      return false;

   // perf-allowed: closed-bar time and close read for the ORB breakout candle.
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return false;

   const datetime bar_open_ny = BrokerToNY(bar_open_broker);
   const int bar_minute = MinuteOfDay(bar_open_ny);
   if(bar_minute < RangeEndMinute() || bar_minute >= TradeEndMinute())
      return false;

   if(!g_or_complete || !g_or_have_range || g_or_high <= g_or_low)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double or_width = g_or_high - g_or_low;
   if(strategy_or_width_filter)
     {
      if(or_width < strategy_or_min_atr_mult * atr || or_width > strategy_or_max_atr_mult * atr)
         return false;
     }

   const double volume_last = (double)iVolume(_Symbol, _Period, 1);
   const double volume_avg = VolumeSMA(strategy_volume_sma_period, 2);
   if(volume_last <= 0.0 || volume_avg <= 0.0 || volume_last < strategy_volume_mult * volume_avg)
      return false;

   const double close_last = iClose(_Symbol, _Period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_last <= 0.0 || bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return false;

   const double min_stop = strategy_min_stop_atr_mult * atr;
   if(min_stop <= 0.0)
      return false;

   if(close_last > g_or_high)
     {
      const double entry = ask;
      double sl = MathMax(g_or_low, entry - strategy_atr_stop_mult * atr);
      if(entry - sl < min_stop)
         sl = entry - min_stop;
      const double stop_dist = entry - sl;
      if(stop_dist <= 0.0 || ask - bid > strategy_max_spread_stop_pct * stop_dist)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = entry + strategy_target_r * stop_dist;
      req.reason = "ORB_VOL_LONG";
      g_trade_attempted_today = true;
      return true;
     }

   if(close_last < g_or_low)
     {
      const double entry = bid;
      double sl = MathMin(g_or_high, entry + strategy_atr_stop_mult * atr);
      if(sl - entry < min_stop)
         sl = entry + min_stop;
      const double stop_dist = sl - entry;
      if(stop_dist <= 0.0 || ask - bid > strategy_max_spread_stop_pct * stop_dist)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = entry - strategy_target_r * stop_dist;
      req.reason = "ORB_VOL_SHORT";
      g_trade_attempted_today = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card normalizes source partials/trailing to a full-position bracket only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;

   const datetime ny_now = BrokerToNY(TimeCurrent());
   const int minute = MinuteOfDay(ny_now);
   if(minute >= TradeEndMinute())
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework news filter.
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
