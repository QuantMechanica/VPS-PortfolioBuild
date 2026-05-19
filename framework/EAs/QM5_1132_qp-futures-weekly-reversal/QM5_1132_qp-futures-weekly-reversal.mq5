#property strict
#property version   "5.0"
#property description "QM5_1132 Quantpedia futures weekly reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1132;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input bool   strategy_volume_only        = true;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_min_d1_bars        = 270;
input int    strategy_min_weekly_volume_obs = 60;
input int    strategy_volume_avg_weeks   = 52;
input double strategy_high_volume_quantile = 0.50;
input int    strategy_rebalance_weekday  = 3;
input int    strategy_max_hold_days      = 7;
input int    strategy_max_spread_points  = 0;

#define STRATEGY_SYMBOL_COUNT 37

string g_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "AUDCAD.DWX","AUDCHF.DWX","AUDJPY.DWX","AUDNZD.DWX","AUDUSD.DWX",
   "CADCHF.DWX","CADJPY.DWX","CHFJPY.DWX",
   "EURAUD.DWX","EURCAD.DWX","EURCHF.DWX","EURGBP.DWX","EURJPY.DWX","EURNZD.DWX","EURUSD.DWX",
   "GBPAUD.DWX","GBPCAD.DWX","GBPCHF.DWX","GBPJPY.DWX","GBPNZD.DWX","GBPUSD.DWX",
   "GDAXI.DWX","NDX.DWX",
   "NZDCAD.DWX","NZDCHF.DWX","NZDJPY.DWX","NZDUSD.DWX",
   "SP500.DWX","UK100.DWX",
   "USDCAD.DWX","USDCHF.DWX","USDJPY.DWX",
   "WS30.DWX","XAGUSD.DWX","XAUUSD.DWX","XNGUSD.DWX","XTIUSD.DWX"
  };

datetime g_last_entry_d1_bar = 0;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(SymbolSlot(_Symbol) != qm_magic_slot_offset)
      return true;

   if(strategy_max_spread_points <= 0)
      return false;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > strategy_max_spread_points);
  }

int SymbolSlot(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == symbol)
         return i;
   return -1;
  }

bool LastClosedD1IsRebalanceDay()
  {
   const datetime t = iTime(_Symbol, PERIOD_D1, 1);
   if(t <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week == strategy_rebalance_weekday);
  }

int FindD1WeekdayShift(const string symbol, const int weekday, const int start_shift)
  {
   for(int shift = start_shift; shift < 20; ++shift)
     {
      const datetime t = iTime(symbol, PERIOD_D1, shift);
      if(t <= 0)
         return -1;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      if(dt.day_of_week == weekday)
         return shift;
     }
   return -1;
  }

double PriorWednesdayReturn(const string symbol)
  {
   const int recent_wed = FindD1WeekdayShift(symbol, strategy_rebalance_weekday, 1);
   if(recent_wed < 0)
      return 0.0;
   const int prior_wed = FindD1WeekdayShift(symbol, strategy_rebalance_weekday, recent_wed + 1);
   if(prior_wed < 0)
      return 0.0;

   const double c_recent = iClose(symbol, PERIOD_D1, recent_wed);
   const double c_prior = iClose(symbol, PERIOD_D1, prior_wed);
   if(c_recent <= 0.0 || c_prior <= 0.0)
      return 0.0;
   return (c_recent / c_prior) - 1.0;
  }

double WeeklyVolumeScore(const string symbol)
  {
   if(iBars(symbol, PERIOD_W1) < strategy_min_weekly_volume_obs)
      return 0.0;

   const long v_current = iVolume(symbol, PERIOD_W1, 1);
   const long v_prior = iVolume(symbol, PERIOD_W1, 2);
   if(v_current <= 0 || v_prior <= 0)
      return 0.0;

   double sum = 0.0;
   int count = 0;
   const int max_weeks = MathMin(strategy_volume_avg_weeks, iBars(symbol, PERIOD_W1) - 1);
   for(int i = 1; i <= max_weeks; ++i)
     {
      const long v = iVolume(symbol, PERIOD_W1, i);
      if(v <= 0)
         continue;
      sum += (double)v;
      ++count;
     }

   if(count < strategy_min_weekly_volume_obs || sum <= 0.0)
      return 0.0;

   const double avg = sum / (double)count;
   if(avg <= 0.0)
      return 0.0;
   return ((double)v_current - (double)v_prior) / avg;
  }

bool HasOpenPositionForThisMagic(ulong &ticket, datetime &open_time)
  {
   ticket = 0;
   open_time = 0;
   const int magic = QM_FrameworkMagic();
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int SelectSignalForSymbol(const string symbol)
  {
   double returns[STRATEGY_SYMBOL_COUNT];
   double volume_scores[STRATEGY_SYMBOL_COUNT];
   int eligible[STRATEGY_SYMBOL_COUNT];
   int n = 0;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      const string s = g_symbols[i];
      if(iBars(s, PERIOD_D1) < strategy_min_d1_bars)
         continue;

      const double r = PriorWednesdayReturn(s);
      const double v = WeeklyVolumeScore(s);
      if(v == 0.0)
         continue;

      returns[n] = r;
      volume_scores[n] = v;
      eligible[n] = i;
      ++n;
     }

   if(n < 2)
      return 0;

   double sorted_vol[STRATEGY_SYMBOL_COUNT];
   for(int i = 0; i < n; ++i)
      sorted_vol[i] = volume_scores[i];

   for(int i = 0; i < n - 1; ++i)
      for(int j = i + 1; j < n; ++j)
         if(sorted_vol[j] > sorted_vol[i])
           {
            const double tmp = sorted_vol[i];
            sorted_vol[i] = sorted_vol[j];
            sorted_vol[j] = tmp;
           }

   double q = strategy_high_volume_quantile;
   if(q <= 0.0 || q > 1.0)
      q = 0.50;
   int cutoff_index = (int)MathFloor((double)n * q) - 1;
   if(cutoff_index < 0)
      cutoff_index = 0;
   if(cutoff_index >= n)
      cutoff_index = n - 1;
   const double volume_threshold = sorted_vol[cutoff_index];

   int worst_idx = -1;
   int best_idx = -1;
   double worst_return = DBL_MAX;
   double best_return = -DBL_MAX;

   for(int i = 0; i < n; ++i)
     {
      if(volume_scores[i] < volume_threshold)
         continue;
      if(returns[i] < worst_return)
        {
         worst_return = returns[i];
         worst_idx = eligible[i];
        }
      if(returns[i] > best_return)
        {
         best_return = returns[i];
         best_idx = eligible[i];
        }
     }

   if(worst_idx >= 0 && g_symbols[worst_idx] == symbol)
      return 1;
   if(best_idx >= 0 && g_symbols[best_idx] == symbol)
      return -1;
   return 0;
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

   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(d1_bar <= 0 || d1_bar == g_last_entry_d1_bar)
      return false;
   if(!LastClosedD1IsRebalanceDay())
      return false;

   ulong ticket;
   datetime open_time;
   if(HasOpenPositionForThisMagic(ticket, open_time))
      return false;

   if(SymbolSlot(_Symbol) < 0)
      return false;

   const int signal = SelectSignalForSymbol(_Symbol);
   if(signal == 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = (signal > 0) ? entry - (strategy_atr_sl_mult * atr) : entry + (strategy_atr_sl_mult * atr);
   req.tp = 0.0;
   req.reason = (signal > 0) ? "weekly_reversal_worst_return_long_volume_only" : "weekly_reversal_best_return_short_volume_only";
   g_last_entry_d1_bar = d1_bar;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies only the initial ATR hard stop; no trailing, BE, or partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket;
   datetime open_time;
   if(!HasOpenPositionForThisMagic(ticket, open_time))
      return false;

   const datetime now = TimeCurrent();
   if(LastClosedD1IsRebalanceDay() && (now - open_time) >= 5 * 86400)
      return true;
   if(strategy_max_hold_days > 0 && (now - open_time) >= strategy_max_hold_days * 86400)
      return true;
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!strategy_volume_only)
     {
      Print("QM5_1132 requires strategy_volume_only=true because open interest is unavailable in DWX data.");
      return INIT_FAILED;
     }

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1132\",\"volume_only\":true}");
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
