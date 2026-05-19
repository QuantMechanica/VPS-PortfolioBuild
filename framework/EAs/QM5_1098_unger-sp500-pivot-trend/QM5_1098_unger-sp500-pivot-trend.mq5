#property strict
#property version   "5.0"
#property description "QM5_1098 Unger S&P Pivot-Point Trend"

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

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_entry_ny_hhmm      = 1030;
input int    strategy_session_open_hhmm  = 930;
input int    strategy_session_close_hhmm = 1600;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.5;
input bool   strategy_use_rr_take_profit = false;
input double strategy_take_profit_rr     = 2.0;
input int    strategy_max_spread_points  = 0;
input int    strategy_session_scan_bars  = 600;

int g_last_entry_day_key = 0;
datetime g_last_entry_eval_bar = 0;
datetime g_last_exit_eval_bar = 0;
bool g_cached_exit_signal = false;

int NyUtcOffsetHours(const datetime utc)
  {
   return QM_IsUSDSTUTC(utc) ? -4 : -5;
  }

datetime BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (NyUtcOffsetHours(utc) * 3600);
  }

int HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKeyFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool IsWeekdayNY(const datetime ny_time)
  {
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

bool IsCashSessionCloseNY(const datetime ny_close_time)
  {
   const int hhmm = HhmmFromTime(ny_close_time);
   return (hhmm > strategy_session_open_hhmm && hhmm <= strategy_session_close_hhmm);
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

bool GetPreviousCashSession(double &out_high, double &out_low, double &out_close, const int current_day_key)
  {
   out_high = 0.0;
   out_low = 0.0;
   out_close = 0.0;

   int target_day = 0;
   bool have_day = false;
   const int max_bars = MathMax(50, strategy_session_scan_bars);
   for(int shift = 2; shift <= max_bars; ++shift)
     {
      const datetime bar_open = iTime(_Symbol, PERIOD_M30, shift);
      if(bar_open <= 0)
         break;

      const datetime ny_close = BrokerToNY(bar_open + PeriodSeconds(PERIOD_M30));
      if(!IsWeekdayNY(ny_close) || !IsCashSessionCloseNY(ny_close))
         continue;

      const int day_key = DayKeyFromTime(ny_close);
      if(day_key >= current_day_key)
         continue;

      if(!have_day)
        {
         target_day = day_key;
         have_day = true;
         out_high = iHigh(_Symbol, PERIOD_M30, shift);
         out_low = iLow(_Symbol, PERIOD_M30, shift);
         out_close = iClose(_Symbol, PERIOD_M30, shift);
         continue;
        }

      if(day_key != target_day)
         break;

      out_high = MathMax(out_high, iHigh(_Symbol, PERIOD_M30, shift));
      out_low = MathMin(out_low, iLow(_Symbol, PERIOD_M30, shift));
     }

   return (have_day && out_high > 0.0 && out_low > 0.0 && out_close > 0.0 && out_high > out_low);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime ny_now = BrokerToNY(TimeCurrent());
   if(!IsWeekdayNY(ny_now))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   if(_Period != PERIOD_M30)
      return false;
   if(HasOpenPositionForMagic())
      return false;

   const datetime signal_open = iTime(_Symbol, PERIOD_M30, 1);
   if(signal_open <= 0)
      return false;
   if(signal_open == g_last_entry_eval_bar)
      return false;
   g_last_entry_eval_bar = signal_open;

   const datetime signal_ny_close = BrokerToNY(signal_open + PeriodSeconds(PERIOD_M30));
   const int signal_day_key = DayKeyFromTime(signal_ny_close);
   if(!IsWeekdayNY(signal_ny_close) || HhmmFromTime(signal_ny_close) != strategy_entry_ny_hhmm)
      return false;
   if(g_last_entry_day_key == signal_day_key)
      return false;

   double prev_high = 0.0;
   double prev_low = 0.0;
   double prev_close = 0.0;
   if(!GetPreviousCashSession(prev_high, prev_low, prev_close, signal_day_key))
      return false;

   const double pivot = (prev_high + prev_low + prev_close) / 3.0;
   const double r1 = 2.0 * pivot - prev_low;
   const double s1 = 2.0 * pivot - prev_high;
   const double signal_close = iClose(_Symbol, PERIOD_M30, 1);
   if(signal_close <= 0.0 || r1 <= s1)
      return false;

   if(signal_close > r1)
      req.type = QM_BUY;
   else if(signal_close < s1)
      req.type = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   if(strategy_use_rr_take_profit)
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr);

   req.reason = (req.type == QM_BUY) ? "UNGER_PIVOT_R1_BREAK" : "UNGER_PIVOT_S1_BREAK";
   g_last_entry_day_key = signal_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card default: no trailing, partial, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   const datetime ny_now = BrokerToNY(TimeCurrent());
   const int hhmm_now = HhmmFromTime(ny_now);
   if(hhmm_now >= strategy_session_close_hhmm)
      return true;

   const datetime signal_open = iTime(_Symbol, PERIOD_M30, 1);
   if(signal_open <= 0)
      return false;
   if(signal_open == g_last_exit_eval_bar)
      return g_cached_exit_signal;

   g_last_exit_eval_bar = signal_open;
   g_cached_exit_signal = false;

   const datetime signal_ny_close = BrokerToNY(signal_open + PeriodSeconds(PERIOD_M30));
   if(!IsCashSessionCloseNY(signal_ny_close))
      return false;

   double prev_high = 0.0;
   double prev_low = 0.0;
   double prev_close = 0.0;
   if(!GetPreviousCashSession(prev_high, prev_low, prev_close, DayKeyFromTime(signal_ny_close)))
      return false;

   const double pivot = (prev_high + prev_low + prev_close) / 3.0;
   const double r1 = 2.0 * pivot - prev_low;
   const double s1 = 2.0 * pivot - prev_high;
   const double signal_close = iClose(_Symbol, PERIOD_M30, 1);
   if(signal_close <= 0.0 || r1 <= s1)
      return false;

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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && signal_close < s1)
        {
         g_cached_exit_signal = true;
         return true;
        }
      if(pos_type == POSITION_TYPE_SELL && signal_close > r1)
        {
         g_cached_exit_signal = true;
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
