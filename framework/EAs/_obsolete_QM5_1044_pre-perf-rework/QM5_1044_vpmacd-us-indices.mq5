#property strict
#property version   "5.0"
#property description "QM5_1044 Volume-Price-Adjusted MACD on US Equity Indices"
// Strategy Card: QM5_1044_vpmacd-us-indices, CEO G0 APPROVED 2026-05-15.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 1044;
input int    qm_magic_slot_offset           = 0;

input group "Risk"
input double RISK_PERCENT                   = 0.0;
input double RISK_FIXED                     = 1000.0;
input double PORTFOLIO_WEIGHT               = 1.0;

input group "News"
input QM_NewsMode qm_news_mode              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = true;
input int    qm_friday_close_hour_broker    = 21;

input group "Strategy"
input int    strategy_fast_ema              = 12;
input int    strategy_slow_ema              = 26;
input int    strategy_signal_ema            = 9;
input double strategy_lambda                = 0.88;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 2.5;
input int    strategy_session_start_hhmm    = 1530;
input int    strategy_session_end_hhmm      = 2200;
input int    strategy_max_spread_points     = 250;
input int    strategy_m5_copy_cap           = 400;

datetime g_last_bar_time = 0;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

int SymbolSlotForCurrentSymbol()
  {
   if(_Symbol == "WS30.DWX")
      return 0;
   if(_Symbol == "NDX.DWX")
      return 1;
   return qm_magic_slot_offset;
  }

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
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
      return true;
     }

   return false;
  }

bool NoTradeFilter()
  {
   // No Trade Filter (time, spread, news)
   if(!QM_KillSwitchCheck())
      return false;
   if(!NewsFilterHook(TimeCurrent()))
      return false;

   const int hhmm = Hhmm(TimeCurrent());
   if(hhmm < strategy_session_start_hhmm || hhmm > strategy_session_end_hhmm)
      return false;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return false;

   return true;
  }

bool NewsFilterHook(const datetime t)
  {
   // News Filter Hook (callable for P8 News Impact phase)
   return QM_NewsAllowsTrade(_Symbol, t, qm_news_mode);
  }

bool CalcPStarForDailyShift(const int shift, double &out_pstar)
  {
   out_pstar = 0.0;
   const datetime day_start = iTime(_Symbol, PERIOD_D1, shift);
   if(day_start <= 0)
      return false;

   datetime day_end = 0;
   if(shift > 0)
      day_end = iTime(_Symbol, PERIOD_D1, shift - 1);
   if(day_end <= day_start)
      day_end = day_start + 24 * 60 * 60;

   MqlRates bars[];
   ArraySetAsSeries(bars, false);
   int copied = CopyRates(_Symbol, PERIOD_M5, day_start, day_end - 1, bars);
   if(copied <= 0)
     {
      const double close_price = iClose(_Symbol, PERIOD_D1, shift);
      if(close_price <= 0.0)
         return false;
      out_pstar = close_price;
      return true;
     }

   if(strategy_m5_copy_cap > 0 && copied > strategy_m5_copy_cap)
      copied = strategy_m5_copy_cap;

   double weighted_sum = 0.0;
   double volume_sum = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      const double price = bars[i].close;
      const double volume = (double)bars[i].tick_volume;
      const double range = bars[i].high - bars[i].low;
      if(price <= 0.0 || volume <= 0.0 || range <= 0.0)
         continue;

      const double direction = (bars[i].close - bars[i].open) / range;
      const double sigma = range;
      weighted_sum += price * volume * sigma * direction;
      volume_sum += volume;
     }

   if(volume_sum <= 0.0)
     {
      const double close_price = iClose(_Symbol, PERIOD_D1, shift);
      if(close_price <= 0.0)
         return false;
      out_pstar = close_price;
      return true;
     }

   out_pstar = weighted_sum / volume_sum;
   return true;
  }

double EmaStep(const double previous, const double value, const int period)
  {
   const double alpha = 2.0 / ((double)period + 1.0);
   return alpha * value + (1.0 - alpha) * previous;
  }

bool CalcMacdForShift(const int shift, double &out_macd)
  {
   out_macd = 0.0;
   if(strategy_fast_ema <= 0 || strategy_slow_ema <= strategy_fast_ema)
      return false;

   const int warmup = strategy_slow_ema + strategy_signal_ema + 10;
   double ema_fast = 0.0;
   double ema_slow = 0.0;
   bool seeded = false;

   for(int s = shift + warmup - 1; s >= shift; --s)
     {
      double pstar = 0.0;
      if(!CalcPStarForDailyShift(s, pstar))
         return false;
      if(!seeded)
        {
         ema_fast = pstar;
         ema_slow = pstar;
         seeded = true;
        }
      else
        {
         ema_fast = EmaStep(ema_fast, pstar, strategy_fast_ema);
         ema_slow = EmaStep(ema_slow, pstar, strategy_slow_ema);
        }
     }

   out_macd = ema_fast - ema_slow;
   return seeded;
  }

bool CalcVpMacdSignalForShift(const int shift, double &out_macd, double &out_signal)
  {
   out_macd = 0.0;
   out_signal = 0.0;
   if(strategy_signal_ema <= 0)
      return false;

   bool seeded = false;
   for(int s = shift + strategy_signal_ema + 8; s >= shift; --s)
     {
      double macd = 0.0;
      if(!CalcMacdForShift(s, macd))
         return false;
      if(!seeded)
        {
         out_signal = macd;
         seeded = true;
        }
      else
         out_signal = EmaStep(out_signal, macd, strategy_signal_ema);

      if(s == shift)
         out_macd = macd;
     }

   return seeded;
  }

bool TradeEntry(QM_EntryRequest &req)
  {
   // Trade Entry
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = SymbolSlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(strategy_lambda <= 0.8 || strategy_lambda >= 1.0)
      return false;

   double macd_curr = 0.0;
   double signal_curr = 0.0;
   double macd_prev = 0.0;
   double signal_prev = 0.0;
   if(!CalcVpMacdSignalForShift(1, macd_curr, signal_curr))
      return false;
   if(!CalcVpMacdSignalForShift(2, macd_prev, signal_prev))
      return false;

   const bool crosses_up = (macd_prev <= strategy_lambda * signal_prev &&
                           macd_curr > strategy_lambda * signal_curr);
   if(!crosses_up)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.reason = "QM5_1044_VPMACD_LONG";
   return true;
  }

void TradeManagement(const ulong ticket)
  {
   // Trade Management
   if(ticket == 0)
      return;
  }

bool TradeClose(const ulong ticket)
  {
   // Trade Close
   if(ticket == 0)
      return false;

   double macd_curr = 0.0;
   double signal_curr = 0.0;
   double macd_prev = 0.0;
   double signal_prev = 0.0;
   if(!CalcVpMacdSignalForShift(1, macd_curr, signal_curr))
      return false;
   if(!CalcVpMacdSignalForShift(2, macd_prev, signal_prev))
      return false;

   const bool crosses_down = (macd_prev >= signal_prev && macd_curr < signal_curr);
   if(!crosses_down)
      return false;

   return QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return TradeEntry(req);
  }

void Strategy_ManageOpenPosition(const ulong ticket)
  {
   TradeManagement(ticket);
  }

bool Strategy_ExitSignal(const ulong ticket)
  {
   return TradeClose(ticket);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1044\",\"ea\":\"QM5_1044_vpmacd-us-indices\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(QM_FrameworkHandleFridayClose())
      return;
   if(!NoTradeFilter())
      return;

   ulong ticket = 0;
   const bool have_position = GetOurPosition(ticket);
   if(have_position)
     {
      Strategy_ManageOpenPosition(ticket);
      Strategy_ExitSignal(ticket);
      return;
     }

   if(!IsNewBar())
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
