#property strict
#property version   "5.0"
#property description "QM5_1046 Maroy Intraday VWAP Exit"

#include <QM/QM_Common.mqh>

enum MAROY_EXIT_VARIANT
  {
   MAROY_EXIT_VWAP = 0,
   MAROY_EXIT_LADDER = 1,
   MAROY_EXIT_HYBRID = 2
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1046;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_session_open_hhmm  = 1630;
input int    strategy_session_close_hhmm = 2255;
input int    strategy_vol_lookback_days  = 10;
input double strategy_vol_multiplier_k   = 1.0;
input MAROY_EXIT_VARIANT strategy_exit_variant = MAROY_EXIT_VWAP;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 3.0;
input double strategy_ladder_long_mfe_pct = 1.0;
input double strategy_ladder_short_mfe_pct = 2.0;
input double strategy_ladder_close_pct   = 75.0;
input double strategy_max_session_dd_pct = 20.0;
input int    strategy_max_spread_points  = 250;

int      g_session_day_key = -1;
double   g_session_open_price = 0.0;
double   g_session_high_equity = 0.0;
double   g_vwap_pv = 0.0;
double   g_vwap_vol = 0.0;
double   g_vwap = 0.0;
double   g_prev_vwap = 0.0;
double   g_prev_vwap_close = 0.0;
double   g_last_vwap_close = 0.0;
ulong    g_ladder_ticket = 0;
bool     g_ladder_done = false;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool InSession(const datetime t)
  {
   const int hhmm = Hhmm(t);
   return (hhmm >= strategy_session_open_hhmm && hhmm < strategy_session_close_hhmm);
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool GetOurPosition(ulong &ticket,
                    ENUM_POSITION_TYPE &ptype,
                    double &open_price,
                    double &volume)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   volume = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      return true;
     }

   return false;
  }

bool HasOurPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   return GetOurPosition(ticket, ptype, open_price, volume);
  }

void ResetSession(const int day_key, const double open_price)
  {
   g_session_day_key = day_key;
   g_session_open_price = open_price;
   g_session_high_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_vwap_pv = 0.0;
   g_vwap_vol = 0.0;
   g_vwap = 0.0;
   g_prev_vwap = 0.0;
   g_prev_vwap_close = 0.0;
   g_last_vwap_close = 0.0;
   g_ladder_ticket = 0;
   g_ladder_done = false;
  }

void UpdateSessionEquity()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return;
   if(g_session_high_equity <= 0.0 || equity > g_session_high_equity)
      g_session_high_equity = equity;
  }

bool SessionDrawdownExceeded()
  {
   if(strategy_max_session_dd_pct <= 0.0 || g_session_high_equity <= 0.0)
      return false;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return false;

   const double dd_pct = 100.0 * (g_session_high_equity - equity) / g_session_high_equity;
   return (dd_pct >= strategy_max_session_dd_pct);
  }

void UpdateSessionVwap()
  {
   if(!QM_IsNewBar(_Symbol, PERIOD_M5))
      return;

   const datetime bar_time = iTime(_Symbol, PERIOD_M5, 1);
   if(bar_time <= 0)
      return;
   if(!InSession(bar_time))
      return;

   const int day_key = DayKey(bar_time);
   const double open_price = iOpen(_Symbol, PERIOD_M5, 1);
   if(day_key != g_session_day_key)
     {
      if(open_price <= 0.0)
         return;
      ResetSession(day_key, open_price);
     }

   const double high_price = iHigh(_Symbol, PERIOD_M5, 1);
   const double low_price = iLow(_Symbol, PERIOD_M5, 1);
   const double close_price = iClose(_Symbol, PERIOD_M5, 1);
   long tick_volume = iVolume(_Symbol, PERIOD_M5, 1);
   if(high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0)
      return;
   if(tick_volume <= 0)
      tick_volume = 1;

   g_prev_vwap = g_vwap;
   g_prev_vwap_close = iClose(_Symbol, PERIOD_M5, 2);
   g_last_vwap_close = close_price;

   const double typical = (high_price + low_price + close_price) / 3.0;
   g_vwap_pv += typical * (double)tick_volume;
   g_vwap_vol += (double)tick_volume;
   if(g_vwap_vol > 0.0)
      g_vwap = g_vwap_pv / g_vwap_vol;
  }

double DailyLogReturnSigma(const int lookback_days)
  {
   if(lookback_days < 2)
      return 0.0;

   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;
   for(int i = 1; i <= lookback_days; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_D1, i);
      const double c1 = iClose(_Symbol, PERIOD_D1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         continue;
      const double r = MathLog(c0 / c1);
      sum += r;
      sum_sq += r * r;
      samples++;
     }

   if(samples < 2)
      return 0.0;

   const double mean = sum / samples;
   const double variance = (sum_sq - samples * mean * mean) / (samples - 1);
   if(variance <= 0.0)
      return 0.0;

   return MathSqrt(variance);
  }

bool HalfHourBoundaryBar(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   return (dt.min == 0 || dt.min == 30);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   UpdateSessionVwap();
   UpdateSessionEquity();

   if(HasOurPosition())
      return false;

   const datetime now = TimeCurrent();
   if(!InSession(now))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   if(SessionDrawdownExceeded())
      return true;

   return false;
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

   if(HasOurPosition())
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_M30, 1);
   if(bar_time <= 0 || !InSession(bar_time) || !HalfHourBoundaryBar(bar_time))
      return false;

   if(g_session_open_price <= 0.0 || DayKey(bar_time) != g_session_day_key)
      return false;

   const double close_price = iClose(_Symbol, PERIOD_M30, 1);
   if(close_price <= 0.0)
      return false;

   const double sigma = DailyLogReturnSigma(strategy_vol_lookback_days);
   if(sigma <= 0.0 || strategy_vol_multiplier_k <= 0.0)
      return false;

   const double upper = g_session_open_price * MathExp(strategy_vol_multiplier_k * sigma);
   const double lower = g_session_open_price * MathExp(-strategy_vol_multiplier_k * sigma);
   const double atr = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   if(close_price > upper)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = NormalizeStrategyPrice(entry - atr * strategy_atr_sl_mult);
      req.reason = "QM5_1046_M30_BAND_LONG_VWAP_EXIT";
      return (req.sl > 0.0 && req.sl < entry);
     }

   if(close_price < lower)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = NormalizeStrategyPrice(entry + atr * strategy_atr_sl_mult);
      req.reason = "QM5_1046_M30_BAND_SHORT_VWAP_EXIT";
      return (req.sl > 0.0 && req.sl > entry);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   if(!GetOurPosition(ticket, ptype, open_price, volume))
     {
      g_ladder_ticket = 0;
      g_ladder_done = false;
      return;
     }

   if(g_ladder_ticket != ticket)
     {
      g_ladder_ticket = ticket;
      g_ladder_done = false;
     }

   if(g_ladder_done || strategy_exit_variant == MAROY_EXIT_VWAP)
      return;
   if(open_price <= 0.0 || volume <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const double mfe_pct = is_buy ? (100.0 * (market_price - open_price) / open_price)
                                 : (100.0 * (open_price - market_price) / open_price);
   const double threshold = is_buy ? strategy_ladder_long_mfe_pct : strategy_ladder_short_mfe_pct;
   if(threshold <= 0.0 || mfe_pct < threshold)
      return;

   const double close_lots = volume * strategy_ladder_close_pct / 100.0;
   if(close_lots <= 0.0)
      return;

   if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
      g_ladder_done = true;
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   if(!GetOurPosition(ticket, ptype, open_price, volume))
      return false;

   if(Hhmm(TimeCurrent()) >= strategy_session_close_hhmm)
      return true;

   if(strategy_exit_variant == MAROY_EXIT_LADDER)
      return false;

   if(g_prev_vwap <= 0.0 || g_vwap <= 0.0 || g_prev_vwap_close <= 0.0 || g_last_vwap_close <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && g_prev_vwap_close >= g_prev_vwap && g_last_vwap_close < g_vwap)
      return true;

   if(ptype == POSITION_TYPE_SELL && g_prev_vwap_close <= g_prev_vwap && g_last_vwap_close > g_vwap)
      return true;

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1046_maroy-intraday-vwap-exit\"}");
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

   Strategy_ManageOpenPosition();

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
