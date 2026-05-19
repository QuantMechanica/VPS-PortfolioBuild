#property strict
#property version   "5.0"
#property description "QM5_1062 Unger Opening-Range Breakout Index CFD Basket"

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
input int    qm_ea_id                   = 1062;
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
input int    strategy_or_window_minutes = 30;
input int    strategy_atr_period_d1     = 14;
input double strategy_atr_cap_mult      = 2.0;
input double strategy_narrow_atr_mult   = 0.5;
input int    strategy_entry_offset_pips = 1;
input int    strategy_news_pause_minutes = 30;
input int    strategy_spread_samples    = 20;

CTrade   g_orb_trade;
datetime g_session_day = 0;
bool     g_or_ready = false;
bool     g_orders_armed_today = false;
bool     g_trade_taken_today = false;
double   g_or_high = 0.0;
double   g_or_low = 0.0;
datetime g_last_spread_bar = 0;
int      g_spread_ring[256];
int      g_spread_count = 0;
int      g_spread_pos = 0;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime NthSunday(const int year, const int month, const int n)
  {
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = 1;
   dt.hour = 2;
   dt.min = 0;
   dt.sec = 0;
   datetime t = StructToTime(dt);
   TimeToStruct(t, dt);
   const int add_days = (7 - dt.day_of_week) % 7 + (n - 1) * 7;
   return t + add_days * 86400;
  }

bool IsUsDstByBrokerDate(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const datetime dst_start = NthSunday(dt.year, 3, 2);
   const datetime dst_end = NthSunday(dt.year, 11, 1);
   return (broker_time >= dst_start && broker_time < dst_end);
  }

void SessionTimes(datetime &session_open, datetime &or_end, datetime &expiry, datetime &session_close)
  {
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   const datetime day = StructToTime(dt);

   int open_h = 9;
   int open_m = 0;
   int close_h = 17;
   int close_m = 30;
   if(_Symbol == "NDX.DWX" || _Symbol == "WS30.DWX")
     {
      open_h = IsUsDstByBrokerDate(now) ? 15 : 16;
      open_m = 30;
      close_h = IsUsDstByBrokerDate(now) ? 22 : 23;
      close_m = 0;
     }

   session_open = day + open_h * 3600 + open_m * 60;
   or_end = session_open + strategy_or_window_minutes * 60;
   session_close = day + close_h * 3600 + close_m * 60;
   expiry = session_close - 5 * 60;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

void CancelOurPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   g_orb_trade.SetExpertMagicNumber(magic);
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         g_orb_trade.OrderDelete(ticket);
     }
  }

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

void ResetNewSessionIfNeeded()
  {
   const datetime today = DateKey(TimeCurrent());
   if(today == g_session_day)
      return;
   g_session_day = today;
   g_or_ready = false;
   g_orders_armed_today = false;
   g_trade_taken_today = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
  }

bool BuildOpeningRange(const datetime session_open, const datetime or_end)
  {
   if(strategy_or_window_minutes < 5 || (strategy_or_window_minutes % 5) != 0)
      return false;

   const int bars_needed = strategy_or_window_minutes / 5;
   double high = -DBL_MAX;
   double low = DBL_MAX;
   for(int i = 1; i <= 96; ++i)
     {
      const datetime bt = iTime(_Symbol, PERIOD_M5, i);
      if(bt < session_open)
         break;
      if(bt >= or_end)
         continue;
      const double h = iHigh(_Symbol, PERIOD_M5, i);
      const double l = iLow(_Symbol, PERIOD_M5, i);
      if(h <= 0.0 || l <= 0.0)
         return false;
      high = MathMax(high, h);
      low = MathMin(low, l);
     }

   if(high == -DBL_MAX || low == DBL_MAX || high <= low)
      return false;

   g_or_high = high;
   g_or_low = low;
   g_or_ready = (bars_needed > 0);
   return g_or_ready;
  }

int MedianSpread()
  {
   if(g_spread_count <= 0)
      return 0;
   int tmp[256];
   for(int i = 0; i < g_spread_count; ++i)
      tmp[i] = g_spread_ring[i];
   for(int i = 1; i < g_spread_count; ++i)
     {
      const int key = tmp[i];
      int j = i - 1;
      while(j >= 0 && tmp[j] > key)
        {
         tmp[j + 1] = tmp[j];
         --j;
        }
      tmp[j + 1] = key;
     }
   return tmp[g_spread_count / 2];
  }

void UpdateSpreadSample()
  {
   const datetime bt = iTime(_Symbol, PERIOD_M5, 0);
   if(bt <= 0 || bt == g_last_spread_bar)
      return;
   g_last_spread_bar = bt;
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return;
   const int cap = MathMax(1, MathMin(strategy_spread_samples, 256));
   g_spread_ring[g_spread_pos % cap] = spread;
   g_spread_pos = (g_spread_pos + 1) % cap;
   if(g_spread_count < cap)
      ++g_spread_count;
  }

bool SpreadAllowsEntry()
  {
   const int current = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const int median = MedianSpread();
   if(current <= 0 || median <= 0)
      return true;
   return (current <= 2 * median);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   ResetNewSessionIfNeeded();
   UpdateSpreadSample();

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.day_of_week == 0 || dt.day_of_week == 6) && !HasOurOpenPosition())
      return true;

   if(!HasOurOpenPosition() && !HasOurPendingOrder() && !SpreadAllowsEntry())
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ResetNewSessionIfNeeded();
   if(g_trade_taken_today || g_orders_armed_today || HasOurOpenPosition() || HasOurPendingOrder())
      return false;

   datetime session_open, or_end, expiry, session_close;
   SessionTimes(session_open, or_end, expiry, session_close);
   const datetime now = TimeCurrent();
   if(now < or_end || now >= expiry)
      return false;

   if(strategy_news_pause_minutes > 0 && !QM_NewsAllowsTrade(_Symbol, now, QM_NEWS_PAUSE))
      return false;

   if(!g_or_ready && !BuildOpeningRange(session_open, or_end))
      return false;

   const double pip = PipDistance();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip <= 0.0 || point <= 0.0)
      return false;

   const double or_size = g_or_high - g_or_low;
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(or_size <= 0.0 || atr_d1 <= 0.0)
      return false;

   if(or_size < strategy_narrow_atr_mult * atr_d1)
     {
      g_orders_armed_today = true;
      return false;
     }

   const double offset = strategy_entry_offset_pips * pip;
   const double buy_price = NormalizeDouble(g_or_high + offset, _Digits);
   const double sell_price = NormalizeDouble(g_or_low - offset, _Digits);
   const double atr_cap = strategy_atr_cap_mult * atr_d1;
   const double buy_sl_range = g_or_low - offset;
   const double sell_sl_range = g_or_high + offset;
   const double buy_sl_cap = buy_price - atr_cap;
   const double sell_sl_cap = sell_price + atr_cap;
   const double buy_sl = NormalizeDouble(MathMax(buy_sl_range, buy_sl_cap), _Digits);
   const double sell_sl = NormalizeDouble(MathMin(sell_sl_range, sell_sl_cap), _Digits);
   if(buy_price <= 0.0 || sell_price <= 0.0 || buy_sl <= 0.0 || sell_sl <= 0.0)
      return false;
   if((buy_price - buy_sl) / point <= 0.0 || (sell_sl - sell_price) / point <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_price;
   buy_req.sl = buy_sl;
   buy_req.tp = 0.0;
   buy_req.reason = "UNGER_ORB_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = (int)MathMax(60, expiry - now);

   ulong ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, ticket))
      return false;

   req.type = QM_SELL_STOP;
   req.price = sell_price;
   req.sl = sell_sl;
   req.tp = 0.0;
   req.reason = "UNGER_ORB_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = (int)MathMax(60, expiry - now);
   g_orders_armed_today = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(HasOurOpenPosition())
     {
      g_trade_taken_today = true;
      CancelOurPendingOrders();
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;

   datetime session_open, or_end, expiry, session_close;
   SessionTimes(session_open, or_end, expiry, session_close);
   return (TimeCurrent() >= session_close - 5 * 60);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
