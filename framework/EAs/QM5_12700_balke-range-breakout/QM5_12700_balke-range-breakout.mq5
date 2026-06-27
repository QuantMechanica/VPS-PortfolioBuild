#property strict
#property version   "5.0"
#property description "QM5_12700 Balke Range Breakout (USDJPY) - improved multi-hour range"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12700: Balke Range Breakout (improved)
// -----------------------------------------------------------------------------
// René Balke style: build a session range, trade the breakout, flat by evening.
//   1. Range: High/Low over the FULL [range_start_hour, range_end_hour) window
//      (server time). FIX vs QM5_5003, which only captured the single start hour.
//   2. Breakout: completed-bar close beyond range +/- buffer (confirmation).
//   3. Filters: range-size vs daily-ATR band, volume surge, spread cap.
//   4. Exit: opposite range edge SL, RR take-profit, OR forced close at exit_hour.
//   5. One trade per day, single position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id              = 12700;
input int    qm_magic_slot_offset  = 0;

input group "Risk"
input double RISK_PERCENT          = 0.0;
input double RISK_FIXED            = 1000.0;
input double PORTFOLIO_WEIGHT      = 1.0;

input group "News"
input QM_NewsMode qm_news_mode     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    range_start_hour      = 3;     // range build start
input int    range_end_hour        = 6;     // range build end / lock (exclusive)
input int    exit_hour             = 20;    // forced flat hour (test 18..22)
input int    exit_min              = 0;
input double entry_buffer_atr      = 0.0;    // breakout buffer (x ATR), 0 = edge
input bool   use_vol_filter        = true;
input double vol_mult              = 1.5;
input double strategy_rr           = 2.5;
input int    strategy_atr_period   = 14;
input double atr_sl_mult           = 1.5;    // fallback SL if range edge invalid
input double min_range_atr_mult    = 0.60;   // reject too-small range (x daily ATR)
input double max_range_atr_mult    = 2.50;   // reject too-large range (x daily ATR)
input int    spread_cap_points     = 30;

// ---- state ----
double   g_range_high = 0.0;
double   g_range_low  = 0.0;
bool     g_range_locked = false;
datetime g_cur_day    = 0;
datetime g_trade_day  = 0;

datetime DayStart(const datetime t) { return (datetime)((long)t / 86400 * 86400); }

void UpdateRange()
  {
   MqlDateTime dt;
   const datetime now = TimeCurrent();
   TimeToStruct(now, dt);
   const datetime day = DayStart(now);

   if(day != g_cur_day)
     {
      g_cur_day = day;
      g_range_high = 0.0; g_range_low = DBL_MAX;
      g_range_locked = false;
     }

   if(!g_range_locked && dt.hour >= range_start_hour && dt.hour < range_end_hour)
     {
      const double h = iHigh(_Symbol, _Period, 1);   // perf-allowed: closed-bar session range high
      const double l = iLow(_Symbol, _Period, 1);    // perf-allowed: closed-bar session range low
      if(h > g_range_high) g_range_high = h;
      if(l < g_range_low)  g_range_low  = l;
     }
   else if(!g_range_locked && dt.hour >= range_end_hour &&
           g_range_high > 0.0 && g_range_low < DBL_MAX)
     {
      g_range_locked = true;
     }
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_cap_points > 0 && spread > spread_cap_points) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   UpdateRange();
   if(HasOpenPosition()) return false;
   if(!g_range_locked) return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < range_end_hour || dt.hour >= exit_hour) return false;  // entry window
   if(g_trade_day == g_cur_day) return false;                         // one trade/day

   // range-size validation vs daily ATR
   const double datr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double range = g_range_high - g_range_low;
   if(datr > 0.0)
     {
      if(range < min_range_atr_mult * datr) return false;
      if(range > max_range_atr_mult * datr) return false;
     }

   // volume surge filter
   if(use_vol_filter)
     {
      const long vol_1 = iVolume(_Symbol, _Period, 1); // perf-allowed: closed-bar tick-volume filter
      double vol_sum = 0;
      for(int i = 1; i <= 20; ++i) vol_sum += (double)iVolume(_Symbol, _Period, i); // perf-allowed: bounded 20-bar volume average
      const double vol_ma = vol_sum / 20.0;
      if(vol_ma <= 0 || (double)vol_1 < vol_ma * vol_mult) return false;
     }

   const double atr   = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double buf   = entry_buffer_atr * atr;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar breakout confirmation

   if(close1 > g_range_high + buf)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_BUY; req.price = 0.0;
      req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;
      req.sl = g_range_low;
      if(req.sl >= bid) req.sl = bid - atr * atr_sl_mult;
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "BALKE_RANGE_LONG";
      if(req.sl > 0.0 && req.tp > 0.0) { g_trade_day = g_cur_day; return true; }
      return false;
     }

   if(close1 < g_range_low - buf)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_SELL; req.price = 0.0;
      req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;
      req.sl = g_range_high;
      if(req.sl <= ask) req.sl = ask + atr * atr_sl_mult;
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
      req.reason = "BALKE_RANGE_SHORT";
      if(req.sl > 0.0 && req.tp > 0.0) { g_trade_day = g_cur_day; return true; }
      return false;
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour > exit_hour || (dt.hour == exit_hour && dt.min >= exit_min)) return true;
   return false;
  }

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
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar()) return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
