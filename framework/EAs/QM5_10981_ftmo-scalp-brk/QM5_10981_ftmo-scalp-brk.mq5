#property strict
#property version   "5.0"
#property description "QM5_10981 FTMO M5 Scalping Range Breakout"

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
input int    qm_ea_id                   = 10981;
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
input int    strategy_range_lookback       = 12;
input int    strategy_atr_period           = 14;
input double strategy_range_min_atr        = 0.6;
input double strategy_range_max_atr        = 1.8;
input int    strategy_volume_lookback      = 20;
input double strategy_volume_mult          = 1.25;
input int    strategy_ema_period           = 20;
input double strategy_stop_atr_mult        = 0.8;
input double strategy_stop_range_frac      = 0.5;
input double strategy_tp_r_mult            = 2.0;
input int    strategy_max_hold_bars        = 12;
input int    strategy_spread_lookback      = 20;
input double strategy_spread_mult          = 1.5;
input int    strategy_false_break_minutes  = 30;
input int    strategy_cash_open_skip_min   = 5;

double   g_breakout_range_high = 0.0;
double   g_breakout_range_low  = 0.0;
datetime g_entry_signal_time   = 0;
int      g_last_trade_window_key = -1;

double BarHigh(const int shift)   { return iHigh(_Symbol, PERIOD_M5, shift); }     // perf-allowed: bounded closed-bar range scan from card
double BarLow(const int shift)    { return iLow(_Symbol, PERIOD_M5, shift); }      // perf-allowed: bounded closed-bar range scan from card
double BarClose(const int shift)  { return iClose(_Symbol, PERIOD_M5, shift); }    // perf-allowed: bounded closed-bar breakout/exit read from card
datetime BarTime(const int shift) { return iTime(_Symbol, PERIOD_M5, shift); }     // perf-allowed: closed-bar timestamp for card state
long BarVolume(const int shift)   { return iVolume(_Symbol, PERIOD_M5, shift); }   // perf-allowed: bounded tick-volume median from card

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int LastSundayOfMonth(const int year, const int month)
  {
   for(int day = QM_DSTAware_DaysInMonth(year, month); day >= 1; --day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon = month;
      dt.day = day;
      dt.hour = 12;
      datetime candidate = StructToTime(dt);
      MqlDateTime checked;
      TimeToStruct(candidate, checked);
      if(checked.day_of_week == 0)
         return day;
     }
   return 0;
  }

bool EuropeBerlinDSTUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);

   MqlDateTime start_dt;
   ZeroMemory(start_dt);
   start_dt.year = dt.year;
   start_dt.mon = 3;
   start_dt.day = LastSundayOfMonth(dt.year, 3);
   start_dt.hour = 1;
   datetime start_utc = StructToTime(start_dt);

   MqlDateTime end_dt;
   ZeroMemory(end_dt);
   end_dt.year = dt.year;
   end_dt.mon = 10;
   end_dt.day = LastSundayOfMonth(dt.year, 10);
   end_dt.hour = 1;
   datetime end_utc = StructToTime(end_dt);

   return (utc_time >= start_utc && utc_time < end_utc);
  }

datetime BrokerToBerlin(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return utc_time + (EuropeBerlinDSTUTC(utc_time) ? 2 * 3600 : 3600);
  }

bool IsUSIndexSymbol()
  {
   return (StringFind(_Symbol, "NDX") >= 0 || StringFind(_Symbol, "WS30") >= 0);
  }

bool IsDaxSymbol()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "GER40") >= 0);
  }

int CurrentLiquidityWindow(const datetime broker_time)
  {
   const datetime berlin = BrokerToBerlin(broker_time);
   const int minute = MinuteOfDay(berlin);
   const int skip = MathMax(0, strategy_cash_open_skip_min);

   if(IsDaxSymbol())
     {
      if(minute >= 8 * 60 + skip && minute < 11 * 60)
         return 1;
      if(minute >= 15 * 60 + 30 + skip && minute < 17 * 60 + 30)
         return 2;
     }

   if(IsUSIndexSymbol())
     {
      if(minute >= 15 * 60 + 30 + skip && minute < 18 * 60)
         return 1;
     }

   return 0;
  }

int CurrentWindowKey(const datetime broker_time)
  {
   const int window = CurrentLiquidityWindow(broker_time);
   if(window <= 0)
      return -1;
   return DayKey(BrokerToBerlin(broker_time)) * 10 + window;
  }

double HighestHigh(const int start_shift, const int count)
  {
   double highest = -DBL_MAX;
   for(int i = 0; i < count; ++i)
      highest = MathMax(highest, BarHigh(start_shift + i));
   return highest;
  }

double LowestLow(const int start_shift, const int count)
  {
   double lowest = DBL_MAX;
   for(int i = 0; i < count; ++i)
      lowest = MathMin(lowest, BarLow(start_shift + i));
   return lowest;
  }

double Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   for(int i = 1; i < count; ++i)
     {
      double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }

   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

double MedianTickVolume(const int start_shift, const int count)
  {
   if(count <= 0)
      return 0.0;
   double values[];
   ArrayResize(values, count);
   for(int i = 0; i < count; ++i)
      values[i] = (double)BarVolume(start_shift + i);
   return Median(values, count);
  }

double MedianSpreadPoints(const int start_shift, const int count)
  {
   if(count <= 0)
      return 0.0;
   double values[];
   ArrayResize(values, count);
   for(int i = 0; i < count; ++i)
      values[i] = (double)iSpread(_Symbol, PERIOD_M5, start_shift + i);
   return Median(values, count);
  }

bool SpreadAllowsTrade()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double median_spread = MedianSpreadPoints(1, strategy_spread_lookback);
   if(current_spread <= 0 || median_spread <= 0.0)
      return false;
   return ((double)current_spread <= strategy_spread_mult * median_spread);
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool HadRecentFalseBreakout(const int lookback_minutes)
  {
   const int bars = MathMax(1, lookback_minutes / 5);
   for(int shift = 2; shift < 2 + bars; ++shift)
     {
      const double prior_high = HighestHigh(shift + 1, strategy_range_lookback);
      const double prior_low = LowestLow(shift + 1, strategy_range_lookback);
      const double high = BarHigh(shift);
      const double low = BarLow(shift);
      const double close = BarClose(shift);

      if(prior_high <= 0.0 || prior_low <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0)
         return true;
      if(high > prior_high && close <= prior_high)
         return true;
      if(low < prior_low && close >= prior_low)
         return true;
     }
   return false;
  }

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5)
      return true;

   if(HasOurOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(CurrentLiquidityWindow(broker_now) <= 0)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);

   const datetime broker_now = TimeCurrent();
   const int window_key = CurrentWindowKey(broker_now);
   if(window_key <= 0 || window_key == g_last_trade_window_key)
      return false;
   if(HasOurOpenPosition())
      return false;
   if(!SpreadAllowsTrade())
      return false;
   if(HadRecentFalseBreakout(strategy_false_break_minutes))
      return false;

   const int range_lookback = MathMax(2, strategy_range_lookback);
   const double range_high = HighestHigh(2, range_lookback);
   const double range_low = LowestLow(2, range_lookback);
   const double range_height = range_high - range_low;
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(range_high <= 0.0 || range_low <= 0.0 || range_height <= 0.0 || atr <= 0.0)
      return false;
   if(range_height < strategy_range_min_atr * atr || range_height > strategy_range_max_atr * atr)
      return false;

   const double close1 = BarClose(1);
   const double ema = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1);
   const long volume1 = BarVolume(1);
   const double median_volume = MedianTickVolume(2, strategy_volume_lookback);
   if(close1 <= 0.0 || ema <= 0.0 || volume1 <= 0 || median_volume <= 0.0)
      return false;
   if((double)volume1 <= strategy_volume_mult * median_volume)
      return false;

   const double stop_r = MathMax(strategy_stop_atr_mult * atr, strategy_stop_range_frac * range_height);
   if(stop_r <= 0.0)
      return false;

   if(close1 > range_high && close1 > ema)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = range_high - stop_r;
      const double actual_r = entry_price - sl;
      if(entry_price <= 0.0 || sl <= 0.0 || actual_r <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = entry_price + strategy_tp_r_mult * actual_r;
      req.reason = "FTMO_M5_RANGE_BREAKOUT_LONG";
      g_breakout_range_high = range_high;
      g_breakout_range_low = range_low;
      g_entry_signal_time = BarTime(1);
      g_last_trade_window_key = window_key;
      return true;
     }

   if(close1 < range_low && close1 < ema)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = range_low + stop_r;
      const double actual_r = sl - entry_price;
      if(entry_price <= 0.0 || sl <= 0.0 || actual_r <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = entry_price - strategy_tp_r_mult * actual_r;
      req.reason = "FTMO_M5_RANGE_BREAKOUT_SHORT";
      g_breakout_range_high = range_high;
      g_breakout_range_low = range_low;
      g_entry_signal_time = BarTime(1);
      g_last_trade_window_key = window_key;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double risk = MathAbs(open_price - current_sl);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(risk <= 0.0 || market_price <= 0.0)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      const bool already_be = is_buy ? (current_sl >= open_price) : (current_sl <= open_price);
      if(moved >= risk && !already_be)
         QM_TM_MoveSL(ticket, open_price, "ftmo_scalp_break_even_1r");
     }
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
      const int max_hold_seconds = MathMax(1, strategy_max_hold_bars) * PeriodSeconds(PERIOD_M5);
      if(TimeCurrent() - open_time >= max_hold_seconds)
         return true;

      if(g_breakout_range_high > g_breakout_range_low &&
         TimeCurrent() - open_time >= PeriodSeconds(PERIOD_M5) &&
         QM_IsNewBar(_Symbol, PERIOD_M5))
        {
         const double close1 = BarClose(1);
         if(close1 > g_breakout_range_low && close1 < g_breakout_range_high)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(false && broker_time > 0)
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
