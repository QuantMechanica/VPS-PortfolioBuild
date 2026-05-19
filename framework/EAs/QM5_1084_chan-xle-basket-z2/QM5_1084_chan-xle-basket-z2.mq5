#property strict
#property version   "5.0"
#property description "QM5_1084 Chan XLE Basket Z-Score Arbitrage"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1084;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_z_lookback_bars     = 60;
input double strategy_entry_z             = 2.0;
input double strategy_exit_z              = 0.0;
input double strategy_stop_z              = 4.0;
input int    strategy_half_life_bars      = 20;
input int    strategy_max_spread_points   = 250;
input double strategy_ndx_weight          = 0.3333333333;
input double strategy_ws30_weight         = 0.3333333333;
input double strategy_gdaxi_weight        = 0.3333333333;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.0;

const int STRATEGY_SYMBOL_COUNT = 4;
string g_symbols[4] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX"};
int    g_slots[4]   = {0, 1, 2, 3};

datetime g_last_state_bar = 0;
bool     g_state_valid = false;
double   g_cached_z = 0.0;
int      g_cached_spread_direction = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(_Symbol == g_symbols[i])
         return i;
     }
   return -1;
  }

int Strategy_CurrentSlot()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_slots[idx];
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

int Strategy_PositionBarsHeld()
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int shift = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      return (shift < 0) ? 0 : shift;
     }
   return 0;
  }

int Strategy_OpenSpreadDirection()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return 0;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int leg_direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      return (idx == 0) ? leg_direction : -leg_direction;
     }

   return 0;
  }

double Strategy_SpreadAtShift(const int shift)
  {
   const double target = iClose(g_symbols[0], PERIOD_D1, shift);
   const double ndx    = iClose(g_symbols[1], PERIOD_D1, shift);
   const double ws30   = iClose(g_symbols[2], PERIOD_D1, shift);
   const double gdaxi  = iClose(g_symbols[3], PERIOD_D1, shift);
   if(target <= 0.0 || ndx <= 0.0 || ws30 <= 0.0 || gdaxi <= 0.0)
      return EMPTY_VALUE;
   return target - (strategy_ndx_weight * ndx +
                    strategy_ws30_weight * ws30 +
                    strategy_gdaxi_weight * gdaxi);
  }

bool Strategy_ComputeZ(double &z)
  {
   z = 0.0;
   const int n = strategy_z_lookback_bars;
   if(n < 20)
      return false;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      SymbolSelect(g_symbols[i], true);
      if(Bars(g_symbols[i], PERIOD_D1) < n + 3)
         return false;
     }

   double sum = 0.0;
   double sumsq = 0.0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const double spread = Strategy_SpreadAtShift(shift);
      if(spread == EMPTY_VALUE)
         return false;
      sum += spread;
      sumsq += spread * spread;
     }

   const double mean = sum / (double)n;
   const double variance = (sumsq / (double)n) - mean * mean;
   if(variance <= 0.0)
      return false;

   const double spread_now = Strategy_SpreadAtShift(1);
   if(spread_now == EMPTY_VALUE)
      return false;

   z = (spread_now - mean) / MathSqrt(variance);
   return MathIsValidNumber(z);
  }

void Strategy_AdvanceStateIfNeeded()
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 0);
   if(bar_time <= 0 || bar_time == g_last_state_bar)
      return;

   g_last_state_bar = bar_time;
   g_state_valid = false;
   g_cached_z = 0.0;
   g_cached_spread_direction = 0;

   double z = 0.0;
   if(!Strategy_ComputeZ(z))
      return;

   g_cached_z = z;
   g_state_valid = true;
   if(z <= -strategy_entry_z)
      g_cached_spread_direction = 1;
   else if(z >= strategy_entry_z)
      g_cached_spread_direction = -1;
  }

int Strategy_LegDirection()
  {
   if(g_cached_spread_direction == 0)
      return 0;

   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return 0;

   if(idx == 0)
      return g_cached_spread_direction;
   return -g_cached_spread_direction;
  }

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   Strategy_AdvanceStateIfNeeded();
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1084_CHAN_BASKET_Z2";
   req.symbol_slot = Strategy_CurrentSlot();
   req.expiration_seconds = 0;

   if(!g_state_valid || Strategy_HasOpenPosition())
      return false;

   const int direction = Strategy_LegDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double stop_dist = atr * strategy_atr_sl_mult;
   req.sl = (req.type == QM_BUY) ? entry - stop_dist : entry + stop_dist;
   req.reason = (g_cached_spread_direction > 0) ? "QM5_1084_LONG_TARGET_SHORT_HEDGES"
                                                : "QM5_1084_SHORT_TARGET_LONG_HEDGES";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_valid)
      return false;

   const int spread_direction = Strategy_OpenSpreadDirection();
   if(spread_direction > 0 && g_cached_z >= strategy_exit_z)
      return true;
   if(spread_direction < 0 && g_cached_z <= -strategy_exit_z)
      return true;
   if(MathAbs(g_cached_z) >= strategy_stop_z)
      return true;
   if(strategy_half_life_bars > 0 && Strategy_PositionBarsHeld() >= strategy_half_life_bars * 3)
      return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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
