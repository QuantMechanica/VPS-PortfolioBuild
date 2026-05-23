#property strict
#property version   "5.0"
#property description "QM5_1133 Quantpedia Country ETF Pairs Trading"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1133;
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
input int    strategy_formation_bars     = 120;
input int    strategy_min_bars           = 180;
input int    strategy_trade_window_days  = 20;
input double strategy_entry_stdev_mult   = 0.5;
input double strategy_exit_stdev_mult    = 0.1;
input double strategy_pair_stop_mult     = 2.5;
input int    strategy_atr_period         = 20;
input double strategy_atr_stop_mult      = 3.0;
input int    strategy_max_spread_points  = 250;

#define QM1133_UNIVERSE_SIZE 5
#define QM1133_MAX_PAIRS 10
#define QM1133_SELECTED_PAIRS 5

string g_qm1133_universe[QM1133_UNIVERSE_SIZE] =
  {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "SP500.DWX"
  };

struct PairState
  {
   string a;
   string b;
   double distance;
   double spread;
   double stdev;
   bool selected;
  };

PairState g_pair_states[QM1133_MAX_PAIRS];
int       g_pair_count = 0;
datetime  g_last_reform_bar = 0;
datetime  g_last_exit_refresh_bar = 0;
datetime  g_entry_bar_time = 0;
double    g_entry_spread = 0.0;
double    g_entry_stdev = 0.0;
bool      g_exit_pair_stop = false;
bool      g_exit_converged = false;
bool      g_exit_time = false;

int SymbolSlotFor(const string symbol)
  {
   if(symbol == "NDX.DWX")    return 0;
   if(symbol == "WS30.DWX")   return 1;
   if(symbol == "GDAXI.DWX")  return 2;
   if(symbol == "UK100.DWX")  return 3;
   if(symbol == "SP500.DWX")  return 4;
   return qm_magic_slot_offset;
  }

bool EnoughDailyBars(const string symbol)
  {
   return (Bars(symbol, PERIOD_D1) >= strategy_min_bars);
  }

bool LoadDailyCloses(const string symbol, const int count, double &closes[])
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, count, rates);
   if(copied != count)
      return false;

   ArrayResize(closes, count);
   for(int i = 0; i < count; ++i)
     {
      const int idx = count - 1 - i;
      if(rates[idx].close <= 0.0)
         return false;
      closes[i] = rates[idx].close;
     }
   return true;
  }

bool ComputePairState(const string a, const string b, PairState &state)
  {
   state.a = a;
   state.b = b;
   state.distance = DBL_MAX;
   state.spread = 0.0;
   state.stdev = 0.0;
   state.selected = false;

   if(strategy_formation_bars < 20)
      return false;
   if(!EnoughDailyBars(a) || !EnoughDailyBars(b))
      return false;

   double ca[], cb[];
   if(!LoadDailyCloses(a, strategy_formation_bars, ca))
      return false;
   if(!LoadDailyCloses(b, strategy_formation_bars, cb))
      return false;
   if(ca[0] <= 0.0 || cb[0] <= 0.0)
      return false;

   double spreads[];
   ArrayResize(spreads, strategy_formation_bars);
   double distance = 0.0;
   double sum = 0.0;
   for(int i = 0; i < strategy_formation_bars; ++i)
     {
      const double na = ca[i] / ca[0];
      const double nb = cb[i] / cb[0];
      const double s = na - nb;
      spreads[i] = s;
      distance += s * s;
      sum += s;
     }

   const double mean = sum / (double)strategy_formation_bars;
   double var = 0.0;
   for(int i = 0; i < strategy_formation_bars; ++i)
     {
      const double d = spreads[i] - mean;
      var += d * d;
     }

   const double stdev = MathSqrt(var / (double)MathMax(1, strategy_formation_bars - 1));
   if(stdev <= 0.0)
      return false;

   state.distance = distance;
   state.spread = spreads[strategy_formation_bars - 1];
   state.stdev = stdev;
   return true;
  }

void SelectTopPairs()
  {
   for(int i = 0; i < g_pair_count; ++i)
      g_pair_states[i].selected = false;

   for(int pick = 0; pick < MathMin(QM1133_SELECTED_PAIRS, g_pair_count); ++pick)
     {
      int best = -1;
      double best_distance = DBL_MAX;
      for(int i = 0; i < g_pair_count; ++i)
        {
         if(g_pair_states[i].selected)
            continue;
         if(g_pair_states[i].distance < best_distance)
           {
            best_distance = g_pair_states[i].distance;
            best = i;
           }
        }
      if(best >= 0)
         g_pair_states[best].selected = true;
     }
  }

void RebuildPairUniverse()
  {
   g_pair_count = 0;
   for(int i = 0; i < QM1133_UNIVERSE_SIZE; ++i)
     {
      for(int j = i + 1; j < QM1133_UNIVERSE_SIZE; ++j)
        {
         if(g_pair_count >= QM1133_MAX_PAIRS)
            return;
         PairState state;
         if(!ComputePairState(g_qm1133_universe[i], g_qm1133_universe[j], state))
            continue;
         g_pair_states[g_pair_count] = state;
         g_pair_count++;
        }
     }
   SelectTopPairs();
  }

bool CurrentSymbolInPair(const PairState &state)
  {
   return (_Symbol == state.a || _Symbol == state.b);
  }

int DirectionForCurrentSymbol(const PairState &state)
  {
   if(!CurrentSymbolInPair(state) || state.stdev <= 0.0)
      return 0;

   if(MathAbs(state.spread) <= strategy_entry_stdev_mult * state.stdev)
      return 0;

   const bool a_overvalued = (state.spread > 0.0);
   if(_Symbol == state.a)
      return a_overvalued ? -1 : 1;
   return a_overvalued ? 1 : -1;
  }

bool GetBestCurrentPair(PairState &best_state, int &direction)
  {
   direction = 0;
   double best_z = 0.0;
   bool found = false;
   for(int i = 0; i < g_pair_count; ++i)
     {
      const PairState state = g_pair_states[i];
      if(!state.selected || !CurrentSymbolInPair(state) || state.stdev <= 0.0)
         continue;
      const int dir = DirectionForCurrentSymbol(state);
      if(dir == 0)
         continue;
      const double z = MathAbs(state.spread / state.stdev);
      if(!found || z > best_z)
        {
         best_state = state;
         direction = dir;
         best_z = z;
         found = true;
        }
     }
   return found;
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

int HeldD1Bars(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   int held = 0;
   for(int shift = 1; shift <= strategy_trade_window_days + 5; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift);
      if(bar_time <= 0)
         break;
      if(bar_time >= open_time)
         held++;
     }
   return held;
  }

void RefreshExitState()
  {
   g_exit_pair_stop = false;
   g_exit_converged = false;
   g_exit_time = false;

   ulong ticket;
   datetime open_time;
   if(!HasOpenPositionForThisMagic(ticket, open_time))
      return;

   PairState state;
   int direction = 0;
   if(GetBestCurrentPair(state, direction))
     {
      g_exit_pair_stop = (MathAbs(state.spread) >= strategy_pair_stop_mult * state.stdev);
      g_exit_converged = ((g_entry_spread > 0.0 && state.spread <= 0.0) ||
                          (g_entry_spread < 0.0 && state.spread >= 0.0) ||
                          (MathAbs(state.spread) <= strategy_exit_stdev_mult * state.stdev));
     }

   g_exit_time = (HeldD1Bars(open_time) >= strategy_trade_window_days);
  }

bool Strategy_NoTradeFilter()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return true;

   const double spread_points = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
   if(spread_points > (double)strategy_max_spread_points)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = SymbolSlotFor(_Symbol);
   req.expiration_seconds = 0;

   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar <= 0)
      return false;

   if(g_last_reform_bar == 0 || (iBarShift(_Symbol, PERIOD_D1, g_last_reform_bar, true) >= strategy_trade_window_days))
     {
      RebuildPairUniverse();
      g_last_reform_bar = d1_bar;
     }

   ulong ticket;
   datetime open_time;
   if(HasOpenPositionForThisMagic(ticket, open_time))
     {
      RefreshExitState();
      return false;
     }

   PairState state;
   int direction = 0;
   if(!GetBestCurrentPair(state, direction))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_dist = strategy_atr_stop_mult * atr;
   if(direction > 0)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = ask - stop_dist;
      req.tp = 0.0;
      req.reason = "QP_COUNTRY_PAIR_UNDERVALUED_LONG";
     }
   else
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = bid + stop_dist;
      req.tp = 0.0;
      req.reason = "QP_COUNTRY_PAIR_OVERVALUED_SHORT";
     }

   g_entry_bar_time = d1_bar;
   g_entry_spread = state.spread;
   g_entry_stdev = state.stdev;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
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

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(open_price <= 0.0 || atr <= 0.0)
         continue;

      const double desired_sl = (type == POSITION_TYPE_BUY)
                                ? open_price - strategy_atr_stop_mult * atr
                                : open_price + strategy_atr_stop_mult * atr;
      if(current_sl <= 0.0)
         QM_TM_MoveSL(ticket, desired_sl, "QP_COUNTRY_ATR_EMERGENCY_STOP");
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar > 0 && d1_bar != g_last_exit_refresh_bar)
     {
      g_last_exit_refresh_bar = d1_bar;
      RebuildPairUniverse();
      RefreshExitState();
     }
   return (g_exit_converged || g_exit_time || g_exit_pair_stop);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1133\",\"strategy\":\"qp-country-etf-pairs\"}");
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
