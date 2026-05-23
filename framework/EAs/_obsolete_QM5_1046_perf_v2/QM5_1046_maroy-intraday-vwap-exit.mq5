#property strict
#property version   "5.0"
#property description "QM5_1046 Maroy Intraday VWAP Exit"
// Strategy Card: QM5_1046_maroy-intraday-vwap-exit, CEO G0 APPROVED 2026-05-16.

#include <QM/QM_Common.mqh>

enum MAROY_EXIT_VARIANT
  {
   MAROY_EXIT_VWAP = 0,
   MAROY_EXIT_LADDER = 1,
   MAROY_EXIT_HYBRID = 2
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 1046;
input int    qm_magic_slot_offset          = 0;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsMode qm_news_mode             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Strategy"
input int    strategy_session_open_hhmm    = 1630;
input int    strategy_session_close_hhmm   = 2255;
input int    strategy_vol_lookback_days    = 10;
input double strategy_vol_multiplier_k     = 1.0;
input MAROY_EXIT_VARIANT strategy_exit_variant = MAROY_EXIT_VWAP;
input int    strategy_atr_period           = 14;
input double strategy_atr_mult             = 3.0;
input double strategy_max_session_dd_pct   = 20.0;
input double strategy_ladder_long_mfe_pct  = 1.0;
input double strategy_ladder_short_mfe_pct = 2.0;
input double strategy_ladder_close_pct     = 75.0;
input int    strategy_max_spread_points    = 0;

datetime g_last_m5_bar_time = 0;
datetime g_last_m30_bar_time = 0;
int      g_session_day_key = -1;
double   g_session_open_price = 0.0;
double   g_session_vwap_pv = 0.0;
double   g_session_vwap_vol = 0.0;
double   g_session_vwap = 0.0;
double   g_prev_vwap_close = 0.0;
double   g_prev_vwap_value = 0.0;
double   g_session_high_equity = 0.0;
ulong    g_ladder_ticket = 0;
bool     g_ladder_done = false;
double   g_best_favorable_price = 0.0;

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

bool IsCashSessionTime(const datetime t)
  {
   const int hhmm = Hhmm(t);
   return (hhmm >= strategy_session_open_hhmm && hhmm < strategy_session_close_hhmm);
  }

bool IsHalfHourClock(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.min == 0 || dt.min == 30);
  }

double NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool NewsFilterHook(const datetime broker_time)
  {
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode);
  }

void ResetSession(const int day_key, const double open_price)
  {
   g_session_day_key = day_key;
   g_session_open_price = open_price;
   g_session_vwap_pv = 0.0;
   g_session_vwap_vol = 0.0;
   g_session_vwap = 0.0;
   g_prev_vwap_close = 0.0;
   g_prev_vwap_value = 0.0;
   g_session_high_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_ladder_ticket = 0;
   g_ladder_done = false;
   g_best_favorable_price = 0.0;
  }

void UpdateSessionEquityHigh()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_session_high_equity <= 0.0 || equity > g_session_high_equity)
      g_session_high_equity = equity;
  }

bool SessionDrawdownCapHit()
  {
   if(strategy_max_session_dd_pct <= 0.0 || g_session_high_equity <= 0.0)
      return false;
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double dd_pct = 100.0 * (g_session_high_equity - equity) / g_session_high_equity;
   return (dd_pct >= strategy_max_session_dd_pct);
  }

bool NoTradeFilter(const datetime broker_time)
  {
   if(!IsCashSessionTime(broker_time))
      return true;
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }
   if(!NewsFilterHook(broker_time))
      return true;
   if(SessionDrawdownCapHit())
      return true;
   return false;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, double &price_open, double &volume, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   price_open = 0.0;
   volume = 0.0;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      ticket = t;
      return true;
     }
   return false;
  }

void AdvanceVwapOnNewM5Bar()
  {
   const datetime current_m5 = iTime(_Symbol, PERIOD_M5, 0);
   if(current_m5 <= 0 || current_m5 == g_last_m5_bar_time)
      return;
   g_last_m5_bar_time = current_m5;

   const datetime bar_time = iTime(_Symbol, PERIOD_M5, 1);
   if(bar_time <= 0)
      return;

   const double close_price = iClose(_Symbol, PERIOD_M5, 1);
   if(close_price <= 0.0)
      return;

   const int day_key = DayKey(bar_time);
   if(day_key != g_session_day_key && Hhmm(bar_time) >= strategy_session_open_hhmm)
      ResetSession(day_key, close_price);

   if(!IsCashSessionTime(bar_time))
      return;

   const double high_price = iHigh(_Symbol, PERIOD_M5, 1);
   const double low_price = iLow(_Symbol, PERIOD_M5, 1);
   const long tick_vol = iVolume(_Symbol, PERIOD_M5, 1);
   if(high_price <= 0.0 || low_price <= 0.0 || tick_vol <= 0)
      return;

   g_prev_vwap_close = close_price;
   g_prev_vwap_value = g_session_vwap;

   const double typical = (high_price + low_price + close_price) / 3.0;
   const double vol = (double)tick_vol;
   g_session_vwap_pv += typical * vol;
   g_session_vwap_vol += vol;
   if(g_session_vwap_vol > 0.0)
      g_session_vwap = g_session_vwap_pv / g_session_vwap_vol;
  }

double HistoricalVolatilitySigma()
  {
   const int n = MathMax(2, MathMin(14, strategy_vol_lookback_days));
   double values[14];
   double sum = 0.0;
   int count = 0;

   for(int i = 1; i <= n; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_D1, i);
      const double c1 = iClose(_Symbol, PERIOD_D1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double r = MathLog(c0 / c1);
      values[count] = r;
      sum += r;
      ++count;
     }

   if(count < 2)
      return 0.0;

   const double mean = sum / count;
   double ss = 0.0;
   for(int j = 0; j < count; ++j)
     {
      const double d = values[j] - mean;
      ss += d * d;
     }
   return MathSqrt(ss / (count - 1));
  }

bool ReadAtrM30(double &atr_value)
  {
   atr_value = 0.0;
   const int period = MathMax(1, strategy_atr_period);
   double sum = 0.0;
   int count = 0;
   for(int i = 1; i <= period; ++i)
     {
      const double high_price = iHigh(_Symbol, PERIOD_M30, i);
      const double low_price = iLow(_Symbol, PERIOD_M30, i);
      const double prev_close = iClose(_Symbol, PERIOD_M30, i + 1);
      if(high_price <= 0.0 || low_price <= 0.0 || prev_close <= 0.0)
         return false;
      const double tr = MathMax(high_price - low_price, MathMax(MathAbs(high_price - prev_close), MathAbs(low_price - prev_close)));
      sum += tr;
      ++count;
     }
   if(count <= 0)
      return false;
   atr_value = sum / count;
   return (atr_value > 0.0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime current_m30 = iTime(_Symbol, PERIOD_M30, 0);
   if(current_m30 <= 0 || current_m30 == g_last_m30_bar_time)
      return false;
   g_last_m30_bar_time = current_m30;

   const datetime bar_time = iTime(_Symbol, PERIOD_M30, 1);
   if(bar_time <= 0 || !IsCashSessionTime(bar_time) || !IsHalfHourClock(bar_time))
      return false;
   if(g_session_open_price <= 0.0 || NoTradeFilter(bar_time))
      return false;

   const double sigma = HistoricalVolatilitySigma();
   const double close_price = iClose(_Symbol, PERIOD_M30, 1);
   if(sigma <= 0.0 || close_price <= 0.0)
      return false;

   double atr = 0.0;
   if(!ReadAtrM30(atr))
      return false;

   const double upper = g_session_open_price * MathExp(strategy_vol_multiplier_k * sigma);
   const double lower = g_session_open_price * MathExp(-strategy_vol_multiplier_k * sigma);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double stop_dist = atr * strategy_atr_mult;
   if(stop_dist <= 0.0)
      return false;

   if(close_price > upper)
     {
      req.type = QM_BUY;
      req.sl = NormalizePrice(ask - stop_dist);
      req.reason = "MAROY_VOL_BAND_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(close_price < lower)
     {
      req.type = QM_SELL;
      req.sl = NormalizePrice(bid + stop_dist);
      req.reason = "MAROY_VOL_BAND_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

void RefreshMfeState(const ulong ticket, const ENUM_POSITION_TYPE ptype, const double open_price)
  {
   if(ticket != g_ladder_ticket)
     {
      g_ladder_ticket = ticket;
      g_ladder_done = false;
      g_best_favorable_price = open_price;
     }

   if(ptype == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > g_best_favorable_price)
         g_best_favorable_price = bid;
     }
   else
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_best_favorable_price <= 0.0 || ask < g_best_favorable_price)
         g_best_favorable_price = ask;
     }
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   ulong ticket;
   if(!GetOurPosition(ptype, open_price, volume, ticket))
      return;

   RefreshMfeState(ticket, ptype, open_price);
   if(g_ladder_done || strategy_exit_variant == MAROY_EXIT_VWAP)
      return;

   double mfe_pct = 0.0;
   double threshold = strategy_ladder_long_mfe_pct;
   if(ptype == POSITION_TYPE_BUY)
      mfe_pct = 100.0 * (g_best_favorable_price - open_price) / open_price;
   else
     {
      mfe_pct = 100.0 * (open_price - g_best_favorable_price) / open_price;
      threshold = strategy_ladder_short_mfe_pct;
     }

   if(mfe_pct < threshold)
      return;

   const double partial_lots = volume * MathMax(0.0, MathMin(100.0, strategy_ladder_close_pct)) / 100.0;
   if(partial_lots > 0.0 && QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
      g_ladder_done = true;
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   ulong ticket;
   if(!GetOurPosition(ptype, open_price, volume, ticket))
      return false;

   const datetime now = TimeCurrent();
   if(Hhmm(now) >= strategy_session_close_hhmm)
      return QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);

   if(strategy_exit_variant == MAROY_EXIT_LADDER)
      return false;

   if(g_prev_vwap_value <= 0.0 || g_session_vwap <= 0.0)
      return false;

   const double close_price = iClose(_Symbol, PERIOD_M5, 1);
   if(close_price <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && g_prev_vwap_close >= g_prev_vwap_value && close_price < g_session_vwap)
      return QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);

   if(ptype == POSITION_TYPE_SELL && g_prev_vwap_close <= g_prev_vwap_value && close_price > g_session_vwap)
      return QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);

   return false;
  }

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

   QM_ExitInit(QM_FrameworkMagic(), qm_friday_close_enabled, qm_friday_close_hour_broker, 1);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1046\",\"ea\":\"QM5_1046_maroy-intraday-vwap-exit\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   AdvanceVwapOnNewM5Bar();
   UpdateSessionEquityHigh();
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   ulong ticket;
   if(GetOurPosition(ptype, open_price, volume, ticket))
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
