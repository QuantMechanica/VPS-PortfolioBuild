#property strict
#property version   "5.0"
#property description "QM5_12562 FX London Open Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12562  fx-london-open-breakout
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_12562_fx-london-open-breakout.md
// Strategy: London-session opening-range breakout on FX majors (M15).
//   - OR = first 4 M15 bars after London 08:00 local (DST-aware broker time).
//   - Entry: closed M15 bar breaks above OR_high (long) or below OR_low (short)
//     within a 3-hour window after OR forms, with ATR confirmation filters.
//   - Exit: 2R TP, 1R BE, 17:00 London session exit, 10-bar time-stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12562;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_or_bars             = 4;     // Number of M15 bars for Opening Range
input int    strategy_entry_window_h      = 3;     // Entry window hours after OR forms
input int    strategy_atr_period          = 14;    // ATR period (M15 and D1)
input double strategy_bb_atr_mult         = 0.5;   // Breakout bar range >= mult * ATR(14,M15)
input double strategy_or_width_atr_mult   = 0.6;   // OR width >= mult * ATR(14,D1)/4
input double strategy_sl_buffer_atr       = 0.2;   // SL buffer = mult * ATR(14,M15) beyond OR extreme
input double strategy_sl_cap_atr          = 1.6;   // Max SL distance in ATR(14,M15) multiples
input double strategy_tp_rr               = 2.0;   // Take profit R-multiple
input double strategy_be_r                = 1.0;   // Breakeven trigger R-multiple
input int    strategy_time_stop_bars      = 10;    // Exit if profit < 0.5R within N bars
input double strategy_time_stop_r         = 0.5;   // Minimum R for time-stop check

// -----------------------------------------------------------------------------
// Per-day state (reset each broker trading day)
// -----------------------------------------------------------------------------
datetime g_today_broker_date    = 0;
datetime g_london_open_broker   = 0;   // 08:00 London in broker time (DST-aware)
datetime g_or_end_broker        = 0;   // london_open + 4*15min
datetime g_entry_window_end     = 0;   // or_end + strategy_entry_window_h hours
datetime g_session_exit_broker  = 0;   // 17:00 London = london_open + 9h

double   g_or_high              = 0.0;
double   g_or_low               = 1e20;
bool     g_or_complete          = false;
bool     g_entered_today        = false;

// Per-position state (live until position closes)
double   g_entry_price          = 0.0;
double   g_entry_sl_initial     = 0.0;  // SL set at entry (for 1R/0.5R calculations)
bool     g_entry_long           = false;
datetime g_entry_bar_open       = 0;    // M15 bar open time when position was entered
bool     g_be_applied           = false;

// -----------------------------------------------------------------------------
// UK-BST helper (last Sunday March 01:00 UTC to last Sunday October 01:00 UTC)
// -----------------------------------------------------------------------------
int LastSundayOfMonth(const int year, const int month)
  {
   int last_day = QM_DSTAware_DaysInMonth(year, month);
   for(int d = last_day; d >= 1; d--)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year; dt.mon = month; dt.day = d;
      dt.hour = 12; dt.min = 0; dt.sec = 0;
      datetime t = StructToTime(dt);
      if(QM_DSTAware_DayOfWeek(t) == SUNDAY) return d;
     }
   return 1;
  }

bool IsUKBST(datetime utc_time)
  {
   // Raw UTC timestamp arithmetic (StructToTime treats fields as UTC)
   datetime utc_mid = utc_time - (utc_time % 86400);
   int      utc_h   = (int)((utc_time - utc_mid) / 3600);
   MqlDateTime dt;
   TimeToStruct(utc_mid, dt);   // fields are UTC year/month/day at midnight
   int y = dt.year, m = dt.mon, d = dt.day;

   if(m < 3 || m > 10) return false;
   if(m > 3 && m < 10) return true;

   int sun_mar = LastSundayOfMonth(y, 3);
   int sun_oct = LastSundayOfMonth(y, 10);

   if(m == 3) return (d > sun_mar || (d == sun_mar && utc_h >= 1));
   // m == 10
   return (d < sun_oct || (d == sun_oct && utc_h < 1));
  }

// Compute 08:00 London local time in broker time for today.
// utc_midnight_today = g_today_broker_date = UTC midnight of the current broker calendar day.
// For DXZ (UTC+2/+3): broker midnight raw == UTC midnight raw of the same calendar day,
// so g_today_broker_date is a valid UTC midnight input here.
datetime ComputeLondonOpenBroker(datetime utc_midnight_today)
  {
   // London 08:00 local: UTC 07:00 in BST, UTC 08:00 in GMT
   datetime utc_check  = utc_midnight_today + 7 * 3600 + 30 * 60;  // 07:30 UTC
   bool     is_bst     = IsUKBST(utc_check);
   int      london_utc_h = is_bst ? 7 : 8;
   datetime london_utc   = utc_midnight_today + (datetime)(london_utc_h * 3600);
   bool     is_us_dst  = QM_IsUSDSTUTC(london_utc);
   int      broker_off = is_us_dst ? 3 : 2;
   return london_utc + (datetime)(broker_off * 3600);
  }

// Broker-local midnight for given broker timestamp
datetime BrokerDate(datetime broker_ts)
  {
   MqlDateTime dt;
   TimeToStruct(broker_ts, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
  }

// -----------------------------------------------------------------------------
// Advance per-day / OR state on every new M15 bar
// Called at the top of Strategy_EntrySignal (which is gated by QM_IsNewBar)
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   datetime broker_now  = TimeCurrent();
   datetime broker_date = BrokerDate(broker_now);

   // New trading day
   if(broker_date != g_today_broker_date)
     {
      g_today_broker_date   = broker_date;
      g_london_open_broker  = ComputeLondonOpenBroker(g_today_broker_date);
      g_or_end_broker       = g_london_open_broker + (datetime)(strategy_or_bars * 15 * 60);
      g_entry_window_end    = g_or_end_broker + (datetime)(strategy_entry_window_h * 3600);
      g_session_exit_broker = g_london_open_broker + (datetime)(9 * 3600); // 08:00+9h = 17:00 London
      g_or_high             = 0.0;
      g_or_low              = 1e20;
      g_or_complete         = false;
      g_entered_today       = false;
     }

   if(g_london_open_broker <= 0) return;

   datetime bar1_open = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: OR structural scan
   if(bar1_open <= 0) return;

   // Accumulate OR: bar must have opened inside the OR window
   if(!g_or_complete && bar1_open >= g_london_open_broker && bar1_open < g_or_end_broker)
     {
      double h = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed: OR high accumulation
      double l = iLow(_Symbol, PERIOD_M15, 1);  // perf-allowed: OR low accumulation
      if(h > g_or_high) g_or_high = h;
      if(l < g_or_low)  g_or_low  = l;
     }

   // OR is complete once a bar opens at or after or_end with a valid accumulated range
   if(!g_or_complete && bar1_open >= g_or_end_broker && g_or_high > g_or_low && g_or_low < 1e19)
      g_or_complete = true;
  }

// Check if we have an open position for this EA
bool GetOurPosition(ulong &out_ticket,
                    double &out_open_price,
                    double &out_sl,
                    ENUM_POSITION_TYPE &out_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      out_ticket     = t;
      out_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      out_sl         = PositionGetDouble(POSITION_SL);
      out_type       = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Entry window and position checks are handled in EntrySignal (per-bar).
   // Session-exit is handled in ExitSignal (per-tick).
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance per-day / OR state first
   AdvanceState_OnNewBar();

   if(!g_or_complete)      return false;
   if(g_entered_today)     return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0) return false;

   datetime bar1_open = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: entry window gate
   if(bar1_open <= 0) return false;
   // Bar must be inside entry window (3h after OR)
   if(bar1_open < g_or_end_broker || bar1_open >= g_entry_window_end) return false;

   double bar_close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: breakout close
   double bar_high  = iHigh(_Symbol, PERIOD_M15, 1);  // perf-allowed: breakout bar range
   double bar_low   = iLow(_Symbol, PERIOD_M15, 1);   // perf-allowed: breakout bar range
   if(bar_close <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0) return false;

   double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   double atr_d1  = QM_ATR(_Symbol, PERIOD_D1,  strategy_atr_period, 1);
   if(atr_m15 <= 0.0 || atr_d1 <= 0.0) return false;

   double bar_range = bar_high - bar_low;
   double or_width  = g_or_high - g_or_low;

   MqlDateTime _dbg_dt; TimeToStruct(bar1_open, _dbg_dt);
   bool _dbg_2024q1 = (_dbg_dt.year == 2024 && _dbg_dt.mon <= 2);

   // Confirmation filters (dead-opening / fakeout rejection)
   if(bar_range < strategy_bb_atr_mult * atr_m15)
     {
      if(_dbg_2024q1)
         PrintFormat("DBG RANGE_FAIL bar1=%s range=%.5f need=%.5f or_h=%.5f or_l=%.5f",
                     TimeToString(bar1_open,TIME_DATE|TIME_MINUTES),
                     bar_range, strategy_bb_atr_mult*atr_m15, g_or_high, g_or_low);
      return false;
     }
   if(or_width < strategy_or_width_atr_mult * atr_d1 / 4.0)
     {
      if(_dbg_2024q1)
         PrintFormat("DBG ORWIDTH_FAIL bar1=%s orW=%.5f need=%.5f(atr_d1=%.5f)",
                     TimeToString(bar1_open,TIME_DATE|TIME_MINUTES),
                     or_width, strategy_or_width_atr_mult*atr_d1/4.0, atr_d1);
      return false;
     }

   // Breakout direction from OR
   bool is_long  = (bar_close > g_or_high);
   bool is_short = (bar_close < g_or_low);
   if(!is_long && !is_short)
     {
      if(_dbg_2024q1)
         PrintFormat("DBG NO_BREAK bar1=%s close=%.5f or_h=%.5f or_l=%.5f",
                     TimeToString(bar1_open,TIME_DATE|TIME_MINUTES),
                     bar_close, g_or_high, g_or_low);
      return false;
     }

   double entry = 0.0;  // market order

   // Compute SL
   double sl_price;
   if(is_long)
      sl_price = g_or_low - strategy_sl_buffer_atr * atr_m15;
   else
      sl_price = g_or_high + strategy_sl_buffer_atr * atr_m15;

   // Entry for SL distance calculation (use ask for long, bid for short as approximate)
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double entry_approx = is_long ? ask : bid;

   double sl_dist = MathAbs(entry_approx - sl_price);
   double sl_cap  = strategy_sl_cap_atr * atr_m15;
   if(sl_dist > sl_cap) return false;  // oversized stop; skip

   // TP at 2R
   QM_OrderType otype = is_long ? QM_BUY : QM_SELL;
   double tp_price = QM_TakeRR(_Symbol, otype, entry_approx, sl_price, strategy_tp_rr);

   req.type              = otype;
   req.price             = 0.0;       // market order
   req.sl                = sl_price;
   req.tp                = tp_price;
   req.reason            = is_long ? "LOB_LONG" : "LOB_SHORT";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Store entry context for BE and time-stop
   g_entry_price      = entry_approx;
   g_entry_sl_initial = sl_price;
   g_entry_long       = is_long;
   g_entry_bar_open   = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: entry bar start
   g_be_applied       = false;
   g_entered_today    = true;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong                ticket     = 0;
   double               open_price = 0.0;
   double               cur_sl     = 0.0;
   ENUM_POSITION_TYPE   ptype;
   if(!GetOurPosition(ticket, open_price, cur_sl, ptype)) return;

   if(ticket == 0 || g_entry_sl_initial <= 0.0) return;

   double sl_dist = MathAbs(open_price - g_entry_sl_initial);
   if(sl_dist <= 0.0) return;

   // Breakeven trigger at strategy_be_r × R
   if(!g_be_applied)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool be_trigger = false;
      if(ptype == POSITION_TYPE_BUY)
         be_trigger = (bid >= open_price + strategy_be_r * sl_dist);
      else
         be_trigger = (ask <= open_price - strategy_be_r * sl_dist);

      if(be_trigger)
        {
         double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price);
         if(QM_TM_MoveSL(ticket, be_sl, "LOB_BREAKEVEN"))
            g_be_applied = true;
        }
     }
  }

bool Strategy_ExitSignal()
  {
   ulong                ticket     = 0;
   double               open_price = 0.0;
   double               cur_sl     = 0.0;
   ENUM_POSITION_TYPE   ptype;
   if(!GetOurPosition(ticket, open_price, cur_sl, ptype)) return false;

   datetime broker_now = TimeCurrent();

   // Session time exit: close at 17:00 London (london_open + 9h)
   if(g_session_exit_broker > 0 && broker_now >= g_session_exit_broker)
      return true;

   // Time-stop: if not >= 0.5R profitable within strategy_time_stop_bars bars
   if(g_entry_bar_open > 0)
     {
      int elapsed_bars = (int)((broker_now - g_entry_bar_open) / (15 * 60));
      if(elapsed_bars >= strategy_time_stop_bars)
        {
         double sl_dist = MathAbs(open_price - g_entry_sl_initial);
         double half_r  = strategy_time_stop_r * sl_dist;
         if(sl_dist > 0.0)
           {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double cur_price = (ptype == POSITION_TYPE_BUY) ? bid : ask;
            double pnl_price = (ptype == POSITION_TYPE_BUY)
                               ? (cur_price - open_price)
                               : (open_price - cur_price);
            if(pnl_price < half_r) return true;
           }
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 (framework handles EUR/GBP/USD/JPY)
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(t, QM_EXIT_TIME_STOP);
        }
      return;
     }

   if(!QM_IsNewBar())
      return;

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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
