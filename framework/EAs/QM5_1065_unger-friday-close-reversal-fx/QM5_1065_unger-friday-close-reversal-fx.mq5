#property strict
#property version   "5.0"
#property description "QM5_1065 Unger Friday Close Reversal FX"

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
input int    qm_ea_id                   = 1065;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_range_lookback_days = 5;
input double strategy_decile_threshold    = 0.10;
input int    strategy_atr_period          = 20;
input double strategy_sl_atr_mult         = 2.0;
input int    strategy_friday_close_hour   = 21;
input int    strategy_monday_entry_end_h  = 6;
input double strategy_spread_mult         = 3.0;
input int    strategy_spread_lookback_d   = 20;
input bool   strategy_skip_holiday_week   = true;
input bool   strategy_high_impact_news_filter = true;

datetime g_last_signal_friday = 0;
datetime g_last_entry_week = 0;
double   g_signal_mid = 0.0;
int      g_signal_side = 0; // +1 long, -1 short.

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime WeekKeyMonday(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime day_start = StructToTime(dt);
   int days_since_monday = dt.day_of_week - 1;
   if(days_since_monday < 0)
      days_since_monday = 6;
   return day_start - days_since_monday * 86400;
  }

bool IsChristmasNewYearWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.mon == 12 && dt.day >= 24)
      return true;
   if(dt.mon == 1 && dt.day <= 2)
      return true;
   return false;
  }

bool IsMondayEntryWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.day_of_week == 0 && dt.hour >= 21)
      return true;
   if(dt.day_of_week == 1 && dt.hour <= strategy_monday_entry_end_h)
      return true;
   return false;
  }

bool FindLatestFridayD1Shift(int &out_shift)
  {
   out_shift = -1;
   for(int shift = 1; shift <= 10; ++shift)
     {
      const datetime bt = iTime(_Symbol, PERIOD_D1, shift);
      if(bt <= 0)
         continue;
      MqlDateTime dt;
      TimeToStruct(bt, dt);
      if(dt.day_of_week == 5)
        {
         out_shift = shift;
         return true;
        }
     }
   return false;
  }

bool ComputeFridaySignal()
  {
   int friday_shift = -1;
   if(!FindLatestFridayD1Shift(friday_shift))
      return false;

   const datetime friday_bar = iTime(_Symbol, PERIOD_D1, friday_shift);
   if(friday_bar <= 0 || friday_bar == g_last_signal_friday)
      return (g_signal_side != 0);
   if(strategy_skip_holiday_week && IsChristmasNewYearWeek(friday_bar))
      return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i = 0; i < strategy_range_lookback_days; ++i)
     {
      const int shift = friday_shift + i;
      const double bh = iHigh(_Symbol, PERIOD_D1, shift);
      const double bl = iLow(_Symbol, PERIOD_D1, shift);
      if(bh <= 0.0 || bl <= 0.0 || bh <= bl)
         return false;
      hi = MathMax(hi, bh);
      lo = MathMin(lo, bl);
     }

   const double friday_close = iClose(_Symbol, PERIOD_D1, friday_shift);
   const double range = hi - lo;
   if(friday_close <= 0.0 || range <= 0.0)
      return false;

   const double decile_high = hi - strategy_decile_threshold * range;
   const double decile_low = lo + strategy_decile_threshold * range;
   g_last_signal_friday = friday_bar;
   g_signal_mid = NormalizeDouble((hi + lo) * 0.5, _Digits);
   g_signal_side = 0;

   if(friday_close > decile_high)
      g_signal_side = -1;
   else if(friday_close < decile_low)
      g_signal_side = 1;

   return (g_signal_side != 0);
  }

bool HasOpenPositionForMagic()
  {
   const int magic = QM_FrameworkMagic();
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

double MedianD1SpreadPoints()
  {
   double spreads[];
   ArrayResize(spreads, 0);
   for(int shift = 1; shift <= strategy_spread_lookback_d; ++shift)
     {
      const long raw = iSpread(_Symbol, PERIOD_D1, shift);
      if(raw <= 0)
         continue;
      const int n = ArraySize(spreads);
      ArrayResize(spreads, n + 1);
      spreads[n] = (double)raw;
     }

   const int n = ArraySize(spreads);
   if(n <= 0)
      return 0.0;

   for(int i = 1; i < n; ++i)
     {
      const double v = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > v)
        {
         spreads[j + 1] = spreads[j];
         --j;
        }
      spreads[j + 1] = v;
     }

   if((n % 2) == 1)
      return spreads[n / 2];
   return 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

bool SpreadAllowsEntry()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double median_spread = MedianD1SpreadPoints();
   if(current_spread <= 0 || median_spread <= 0.0)
      return false;
   return ((double)current_spread <= strategy_spread_mult * median_spread);
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

   if(strategy_range_lookback_days < 2 || strategy_decile_threshold <= 0.0 || strategy_decile_threshold >= 0.5)
      return false;

   const datetime now = TimeCurrent();
   if(!IsMondayEntryWindow(now))
      return false;
   if(strategy_skip_holiday_week && IsChristmasNewYearWeek(now))
      return false;
   if(HasOpenPositionForMagic())
      return false;

   const datetime week_key = WeekKeyMonday(now);
   if(week_key > 0 && week_key == g_last_entry_week)
      return false;
   if(!ComputeFridaySignal())
      return false;
   if(!SpreadAllowsEntry())
      return false;

   if(strategy_high_impact_news_filter && QM_NewsIsAvailable())
     {
      datetime utc_now = QM_BrokerToUTC(now);
      if(utc_now <= 0)
         utc_now = TimeGMT();
      if(QM_NewsInWindow(utc_now, _Symbol, 240, 240, "HIGH"))
         return false;
     }

   const QM_OrderType side = (g_signal_side > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = atr * strategy_sl_atr_mult;
   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble((side == QM_BUY) ? entry - sl_dist : entry + sl_dist, _Digits);
   req.tp = g_signal_mid;
   req.reason = (side == QM_BUY) ? "FRIDAY_BOTTOM_DECILE_MONDAY_LONG" : "FRIDAY_TOP_DECILE_MONDAY_SHORT";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(side == QM_BUY && req.tp <= entry)
      return false;
   if(side == QM_SELL && req.tp >= entry)
      return false;

   g_last_entry_week = week_key;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!QM_FrameworkFridayCloseNow())
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_friday_close_hour);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!strategy_high_impact_news_filter || !QM_NewsIsAvailable())
      return false;
   if(!IsMondayEntryWindow(broker_time))
      return false;

   datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      utc_time = TimeGMT();
   if(QM_NewsInWindow(utc_time, _Symbol, 240, 240, "HIGH"))
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
