#property strict
#property version   "5.0"
#property description "QM5_1045 Zarattini SPY Intraday Momentum"
// Strategy Card: QM5_1045_zarattini-spy-intraday-momentum, G0 APPROVED 2026-05-16.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1045;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_cash_open_hhmm      = 1430;
input int    strategy_cash_close_hhmm     = 2100;
input int    strategy_lookback_days       = 14;
input int    strategy_atr_period          = 14;
input double strategy_atr_mult            = 3.0;
input int    strategy_max_spread_points   = 5000;

datetime g_last_bar_time = 0;
int      g_atr_handle    = INVALID_HANDLE;
int      g_trade_day_key = -1;
bool     g_trade_taken_today = false;

// No Trade Filter (time, spread, news)
int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 1000 + dt.day_of_year);
  }

datetime DayAtHhmm(const datetime day_anchor, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(day_anchor, dt);
   dt.hour = MathMax(0, MathMin(23, hhmm / 100));
   dt.min = MathMax(0, MathMin(59, hhmm % 100));
   dt.sec = 0;
   return StructToTime(dt);
  }

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

bool NewsFilterHook(const datetime t)
  {
   return QM_NewsAllowsTrade(_Symbol, t, qm_news_mode);
  }

void RefreshTradeDayState(const datetime t)
  {
   const int key = DayKey(t);
   if(key != g_trade_day_key)
     {
      g_trade_day_key = key;
      g_trade_taken_today = false;
     }
  }

bool InCashSession(const datetime t)
  {
   const int now_hhmm = Hhmm(t);
   return (now_hhmm >= strategy_cash_open_hhmm && now_hhmm < strategy_cash_close_hhmm);
  }

bool Strategy_NoTradeFilter()
  {
   if(!QM_KillSwitchCheck())
      return true;
   if(!NewsFilterHook(TimeCurrent()))
      return true;
   if(!InCashSession(TimeCurrent()))
      return true;

   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   return false;
  }

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      g_trade_taken_today = true;
      return true;
     }
   return false;
  }

bool SessionRangeForDay(const datetime day_anchor,
                        const int elapsed_seconds,
                        double &session_high,
                        double &session_low)
  {
   session_high = -DBL_MAX;
   session_low = DBL_MAX;

   const datetime start_t = DayAtHhmm(day_anchor, strategy_cash_open_hhmm);
   const datetime end_t = start_t + MathMax(0, elapsed_seconds);
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_M30, start_t, end_t, rates);
   if(copied <= 0)
      return false;

   ArraySetAsSeries(rates, false);
   for(int i = 0; i < copied; ++i)
     {
      session_high = MathMax(session_high, rates[i].high);
      session_low = MathMin(session_low, rates[i].low);
     }

   return (session_high > -DBL_MAX && session_low < DBL_MAX && session_high > session_low);
  }

double AverageHistoricalMove(const datetime signal_t)
  {
   const datetime today_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(today_d1 <= 0 || strategy_lookback_days <= 0)
      return 0.0;

   const datetime today_open_t = DayAtHhmm(today_d1, strategy_cash_open_hhmm);
   const int elapsed_seconds = (int)MathMax(0, signal_t - today_open_t);
   double sum = 0.0;
   int count = 0;

   for(int shift = 1; shift < 80 && count < strategy_lookback_days; ++shift)
     {
      const datetime day_anchor = iTime(_Symbol, PERIOD_D1, shift);
      if(day_anchor <= 0)
         break;

      double hi, lo;
      if(!SessionRangeForDay(day_anchor, elapsed_seconds, hi, lo))
         continue;

      sum += (hi - lo);
      ++count;
     }

   if(count <= 0)
      return 0.0;
   return sum / count;
  }

bool BoundaryLevels(const datetime signal_t, double &upper, double &lower)
  {
   upper = 0.0;
   lower = 0.0;

   const datetime today_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(today_d1 <= 0 || prior_d1 <= 0)
      return false;

   const double open_today = iOpen(_Symbol, PERIOD_D1, 0);
   const double close_prior = iClose(_Symbol, PERIOD_D1, 1);
   if(open_today <= 0.0 || close_prior <= 0.0)
      return false;

   const double move = AverageHistoricalMove(signal_t);
   if(move <= 0.0)
      return false;

   const double gap = MathAbs(open_today - close_prior);
   double gap_adj_up = 0.0;
   double gap_adj_dn = 0.0;
   if(open_today < close_prior)
      gap_adj_up = gap;
   else if(open_today > close_prior)
      gap_adj_dn = gap;

   upper = open_today + move + gap_adj_up;
   lower = open_today - move - gap_adj_dn;
   return (upper > lower && lower > 0.0);
  }

double AtrStopDistance()
  {
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atr_handle, 0, 1, 1, atr) != 1 || atr[0] <= 0.0)
      return 0.0;
   return atr[0] * strategy_atr_mult;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime signal_t = iTime(_Symbol, _Period, 1);
   if(signal_t <= 0)
      return false;

   RefreshTradeDayState(signal_t);
   if(g_trade_taken_today)
      return false;
   if(!InCashSession(signal_t))
      return false;

   const int signal_hhmm = Hhmm(signal_t);
   if((signal_hhmm % 100) != 0 && (signal_hhmm % 100) != 30)
      return false;

   double upper, lower;
   if(!BoundaryLevels(signal_t, upper, lower))
      return false;

   const double close_t = iClose(_Symbol, _Period, 1);
   const double stop_dist = AtrStopDistance();
   if(close_t <= 0.0 || stop_dist <= 0.0)
      return false;

   if(close_t > upper)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = ask - stop_dist;
      req.reason = "QM5_1045_NOISE_BOUNDARY_LONG";
      return true;
     }

   if(close_t < lower)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = bid + stop_dist;
      req.reason = "QM5_1045_NOISE_BOUNDARY_SHORT";
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Baseline has no trailing, break-even, partial-exit, or pyramiding rule.
  }

// Trade Close
bool Strategy_ExitSignal(ulong ticket)
  {
   if(ticket == 0)
      return false;

   if(Hhmm(TimeCurrent()) >= strategy_cash_close_hhmm)
      return QM_Exit(ticket, QM_EXIT_TIME_STOP);

   return false;
  }

int OnInit()
  {
   if(_Period != PERIOD_M30)
      Print("QM5_1045 expects M30 primary timeframe per card.");

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   g_atr_handle = iATR(_Symbol, PERIOD_M30, strategy_atr_period);
   if(g_atr_handle == INVALID_HANDLE)
      return INIT_FAILED;

   QM_ExitInit(QM_FrameworkMagic(), qm_friday_close_enabled, qm_friday_close_hour_broker, 1);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1045_zarattini-spy-intraday-momentum\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(QM_FrameworkHandleFridayClose())
      return;

   RefreshTradeDayState(TimeCurrent());

   ulong ticket;
   if(GetOurPosition(ticket))
     {
      Strategy_ManageOpenPosition();
      Strategy_ExitSignal(ticket);
      return;
     }

   if(Strategy_NoTradeFilter())
      return;
   if(!IsNewBar())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_Entry(req, out_ticket) == QM_ENTRY_OK)
         g_trade_taken_today = true;
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
