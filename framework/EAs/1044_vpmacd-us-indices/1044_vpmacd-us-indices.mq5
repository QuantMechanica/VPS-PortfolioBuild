#property strict
#property version   "5.0"
#property description "QM5_1044 Volume-Price-Adjusted MACD on US Equity Indices"
// Strategy Card: QM5_1044_vpmacd-us-indices, G0 APPROVED 2026-05-15.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1044;
input int    qm_magic_slot_offset         = 1;

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
input int    strategy_fast_ema            = 12;
input int    strategy_slow_ema            = 26;
input int    strategy_signal_ema          = 9;
input double strategy_lambda              = 0.86;
input int    strategy_atr_period          = 14;
input double strategy_atr_mult            = 2.5;
input int    strategy_m5_vol_period       = 14;
input int    strategy_cash_open_hhmm      = 1530;
input int    strategy_cash_close_hhmm     = 2200;
input int    strategy_max_spread_points   = 5000;

datetime g_last_bar_time = 0;
datetime g_last_entry_d1 = 0;
datetime g_last_exit_d1  = 0;
int      g_atr_handle    = INVALID_HANDLE;
datetime g_pstar_times[];
double   g_pstar_values[];

// No Trade Filter (time, spread, news)
int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
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

bool Strategy_NoTradeFilter()
  {
   if(!QM_KillSwitchCheck())
      return true;
   if(!NewsFilterHook(TimeCurrent()))
      return true;

   const int now_hhmm = Hhmm(TimeCurrent());
   if(now_hhmm < strategy_cash_open_hhmm || now_hhmm >= strategy_cash_close_hhmm)
      return true;

   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   return false;
  }

double BarSigma(const MqlRates &rates[], const int index)
  {
   const int start = MathMax(0, index - strategy_m5_vol_period + 1);
   double sum = 0.0;
   int n = 0;
   for(int i = start; i <= index; ++i)
     {
      sum += MathMax(0.0, rates[i].high - rates[i].low);
      ++n;
     }
   if(n <= 0)
      return 0.0;
   return sum / n;
  }

double VPPriceForD1Shift(const int d1_shift)
  {
   const datetime day_start = iTime(_Symbol, PERIOD_D1, d1_shift);
   const datetime next_start = iTime(_Symbol, PERIOD_D1, d1_shift - 1);
   if(day_start <= 0 || next_start <= day_start)
      return iClose(_Symbol, PERIOD_D1, d1_shift);

   for(int i = 0; i < ArraySize(g_pstar_times); ++i)
     {
      if(g_pstar_times[i] == day_start)
         return g_pstar_values[i];
     }

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_M5, day_start, next_start - 1, rates);
   if(copied <= strategy_m5_vol_period)
      return iClose(_Symbol, PERIOD_D1, d1_shift);

   ArraySetAsSeries(rates, false);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double weighted_sum = 0.0;
   double volume_sum = 0.0;

   for(int i = 0; i < copied; ++i)
     {
      const double volume = (double)rates[i].tick_volume;
      if(volume <= 0.0)
         continue;

      const double price = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      const double range = MathMax(point, rates[i].high - rates[i].low);
      const double sigma = BarSigma(rates, i);
      const double signed_strength = (rates[i].close - rates[i].open) / range;
      const double direction = MathMax(0.0, 1.0 + signed_strength);

      weighted_sum += price * volume * sigma * direction;
      volume_sum += volume;
     }

   double pstar = iClose(_Symbol, PERIOD_D1, d1_shift);
   if(volume_sum > 0.0 && weighted_sum != 0.0)
      pstar = weighted_sum / volume_sum;

   const int n = ArraySize(g_pstar_times);
   ArrayResize(g_pstar_times, n + 1);
   ArrayResize(g_pstar_values, n + 1);
   g_pstar_times[n] = day_start;
   g_pstar_values[n] = pstar;
   return pstar;
  }

bool BuildVpMacd(double &macd_prev, double &signal_prev, double &macd_cur, double &signal_cur)
  {
   macd_prev = 0.0;
   signal_prev = 0.0;
   macd_cur = 0.0;
   signal_cur = 0.0;

   if(strategy_fast_ema <= 1 || strategy_slow_ema <= strategy_fast_ema || strategy_signal_ema <= 1)
      return false;

   const int bars_needed = strategy_slow_ema + strategy_signal_ema + 20;
   if(Bars(_Symbol, PERIOD_D1) < bars_needed + 3)
      return false;

   double ema_fast = 0.0;
   double ema_slow = 0.0;
   double ema_signal = 0.0;
   const double alpha_fast = 2.0 / (strategy_fast_ema + 1.0);
   const double alpha_slow = 2.0 / (strategy_slow_ema + 1.0);
   const double alpha_signal = 2.0 / (strategy_signal_ema + 1.0);
   bool initialized = false;

   for(int shift = bars_needed; shift >= 1; --shift)
     {
      const double pstar = VPPriceForD1Shift(shift);
      if(pstar <= 0.0)
         return false;

      if(!initialized)
        {
         ema_fast = pstar;
         ema_slow = pstar;
         ema_signal = 0.0;
         initialized = true;
        }
      else
        {
         ema_fast = alpha_fast * pstar + (1.0 - alpha_fast) * ema_fast;
         ema_slow = alpha_slow * pstar + (1.0 - alpha_slow) * ema_slow;
        }

      const double macd = ema_fast - ema_slow;
      ema_signal = alpha_signal * macd + (1.0 - alpha_signal) * ema_signal;

      if(shift == 2)
        {
         macd_prev = macd;
         signal_prev = ema_signal;
        }
      else if(shift == 1)
        {
         macd_cur = macd;
         signal_cur = ema_signal;
        }
     }

   return initialized;
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
      return true;
     }
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1044_VPMACD_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime signal_day = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_day <= 0 || signal_day == g_last_entry_d1)
      return false;
   g_last_entry_d1 = signal_day;

   double macd_prev, signal_prev, macd_cur, signal_cur;
   if(!BuildVpMacd(macd_prev, signal_prev, macd_cur, signal_cur))
      return false;

   if(!(macd_prev <= strategy_lambda * signal_prev && macd_cur > strategy_lambda * signal_cur))
      return false;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atr_handle, 0, 1, 1, atr) != 1 || atr[0] <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.sl = ask - (atr[0] * strategy_atr_mult);
   req.tp = 0.0;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, scale-in, or partial-close rule.
  }

// Trade Close
bool Strategy_ExitSignal(ulong ticket)
  {
   if(ticket == 0)
      return false;

   const datetime signal_day = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_day <= 0 || signal_day == g_last_exit_d1)
      return false;
   g_last_exit_d1 = signal_day;

   double macd_prev, signal_prev, macd_cur, signal_cur;
   if(!BuildVpMacd(macd_prev, signal_prev, macd_cur, signal_cur))
      return false;

   if(macd_prev >= signal_prev && macd_cur < signal_cur)
     {
      return QM_Exit(ticket, QM_EXIT_STRATEGY);
     }

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

   g_atr_handle = iATR(_Symbol, PERIOD_D1, strategy_atr_period);
   if(g_atr_handle == INVALID_HANDLE)
      return INIT_FAILED;

   QM_ExitInit(QM_FrameworkMagic(), qm_friday_close_enabled, qm_friday_close_hour_broker, 1);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1044_vpmacd-us-indices\"}");
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
   if(Strategy_NoTradeFilter())
      return;
   if(!IsNewBar())
      return;

   ulong ticket;
   if(GetOurPosition(ticket))
     {
      Strategy_ManageOpenPosition();
      Strategy_ExitSignal(ticket);
      return;
     }

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_Entry(req, out_ticket);
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
