#property strict
#property version   "5.0"
#property description "QM5_1448 DeMark TD Combo Exhaustion H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1448;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_setup_bars         = 9;
input int    strategy_combo_bars         = 13;
input int    strategy_setup_lookback     = 26;
input int    strategy_uniqueness_bars    = 20;
input int    strategy_atr_period         = 20;
input double strategy_atr_amplitude_mult = 2.0;
input double strategy_spread_atr_mult    = 0.15;
input double strategy_macro_slope_atr    = 0.50;
input int    strategy_macro_sma_period   = 50;
input int    strategy_macro_slope_bars   = 10;
input double strategy_sl_atr_mult        = 1.5;
input double strategy_sl_range_mult      = 0.30;
input double strategy_sl_atr_cap         = 3.0;
input double strategy_tp1_range_mult     = 1.0;
input double strategy_tp2_range_mult     = 1.618;
input double strategy_tp1_close_fraction = 0.60;
input int    strategy_time_stop_bars     = 40;
input double strategy_invalidation_atr   = 0.30;
input int    strategy_max_combo_positions = 2;

datetime g_last_bullish_combo_bar = 0;
datetime g_last_bearish_combo_bar = 0;
int      g_active_side = 0;
double   g_active_tp1 = 0.0;
double   g_active_invalidation = 0.0;
bool     g_tp1_done = false;

struct TDComboPattern
  {
   int      side;
   datetime trigger_time;
   double   setup_first_close;
   double   pattern_high;
   double   pattern_low;
   double   atr;
  };

double BarOpen(const int shift)  { return iOpen(_Symbol, PERIOD_H4, shift); }
double BarHigh(const int shift)  { return iHigh(_Symbol, PERIOD_H4, shift); }
double BarLow(const int shift)   { return iLow(_Symbol, PERIOD_H4, shift); }
double BarClose(const int shift) { return iClose(_Symbol, PERIOD_H4, shift); }

bool SameSymbolMagicPosition(ulong &ticket)
  {
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
      return true;
     }
   ticket = 0;
   return false;
  }

int TDComboOpenPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(magic >= 14480000 && magic <= 14489999)
         ++count;
     }
   return count;
  }

bool BullishSetupComplete(const int setup_end_shift)
  {
   for(int n = 0; n < strategy_setup_bars; ++n)
     {
      const int shift = setup_end_shift + n;
      const double c = BarClose(shift);
      const double c4 = BarClose(shift + 4);
      if(c <= 0.0 || c4 <= 0.0 || !(c < c4))
         return false;
     }
   return true;
  }

bool BearishSetupComplete(const int setup_end_shift)
  {
   for(int n = 0; n < strategy_setup_bars; ++n)
     {
      const int shift = setup_end_shift + n;
      const double c = BarClose(shift);
      const double c4 = BarClose(shift + 4);
      if(c <= 0.0 || c4 <= 0.0 || !(c > c4))
         return false;
     }
   return true;
  }

bool BullishComboQualifies(const int count, const int shift)
  {
   const double c = BarClose(shift);
   if(c <= 0.0)
      return false;
   if(!(c <= BarLow(shift + 2)))
      return false;
   if(!(BarLow(shift) < BarLow(shift + 1)))
      return false;
   if(!(c < BarClose(shift + 1)))
      return false;
   if(count > 1 && !(c < BarClose(shift + count - 1)))
      return false;
   return true;
  }

bool BearishComboQualifies(const int count, const int shift)
  {
   const double c = BarClose(shift);
   if(c <= 0.0)
      return false;
   if(!(c >= BarHigh(shift + 2)))
      return false;
   if(!(BarHigh(shift) > BarHigh(shift + 1)))
      return false;
   if(!(c > BarClose(shift + 1)))
      return false;
   if(count > 1 && !(c > BarClose(shift + count - 1)))
      return false;
   return true;
  }

bool ComboSequenceComplete(const int side, const int trigger_shift)
  {
   for(int count = 1; count <= strategy_combo_bars; ++count)
     {
      const int shift = trigger_shift + strategy_combo_bars - count;
      if(side > 0)
        {
         if(!BullishComboQualifies(count, shift))
            return false;
        }
      else
        {
         if(!BearishComboQualifies(count, shift))
            return false;
        }
     }
   return true;
  }

bool Bar13CloseConfirmation(const int side, const int trigger_shift)
  {
   const double c = BarClose(trigger_shift);
   const double o = BarOpen(trigger_shift);
   const double c_prev = BarClose(trigger_shift + 1);
   if(c <= 0.0 || o <= 0.0 || c_prev <= 0.0)
      return false;
   if(side > 0)
      return (c > o && c > c_prev);
   return (c < o && c < c_prev);
  }

bool MacroBiasAllows(const int side)
  {
   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1);
   const double sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1 + strategy_macro_slope_bars);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_now <= 0.0 || sma_prior <= 0.0 || atr_d1 <= 0.0)
      return false;
   const double slope = sma_now - sma_prior;
   if(side > 0)
      return (slope >= -strategy_macro_slope_atr * atr_d1);
   return (slope <= strategy_macro_slope_atr * atr_d1);
  }

void FillPatternExtremes(const int setup_end_shift, const int trigger_shift, TDComboPattern &pattern)
  {
   pattern.pattern_high = -DBL_MAX;
   pattern.pattern_low = DBL_MAX;
   const int setup_start_shift = setup_end_shift + strategy_setup_bars - 1;
   pattern.setup_first_close = BarClose(setup_start_shift);

   for(int s = setup_end_shift; s <= setup_start_shift; ++s)
     {
      pattern.pattern_high = MathMax(pattern.pattern_high, BarHigh(s));
      pattern.pattern_low = MathMin(pattern.pattern_low, BarLow(s));
     }
   for(int s = trigger_shift; s < trigger_shift + strategy_combo_bars; ++s)
     {
      pattern.pattern_high = MathMax(pattern.pattern_high, BarHigh(s));
      pattern.pattern_low = MathMin(pattern.pattern_low, BarLow(s));
     }
  }

bool SetupFoundForTrigger(const int side, const int trigger_shift, int &setup_end_shift)
  {
   const int first = trigger_shift + strategy_combo_bars;
   const int last = trigger_shift + strategy_setup_lookback;
   for(int s = first; s <= last; ++s)
     {
      if(side > 0 && BullishSetupComplete(s))
        {
         setup_end_shift = s;
         return true;
        }
      if(side < 0 && BearishSetupComplete(s))
        {
         setup_end_shift = s;
         return true;
        }
     }
   return false;
  }

bool TDComboAtShift(const int side, const int trigger_shift, TDComboPattern &pattern)
  {
   if(!ComboSequenceComplete(side, trigger_shift))
      return false;
   if(!Bar13CloseConfirmation(side, trigger_shift))
      return false;
   if(!MacroBiasAllows(side))
      return false;

   int setup_end_shift = 0;
   if(!SetupFoundForTrigger(side, trigger_shift, setup_end_shift))
      return false;

   pattern.side = side;
   pattern.trigger_time = iTime(_Symbol, PERIOD_H4, trigger_shift);
   pattern.atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, trigger_shift);
   if(pattern.trigger_time <= 0 || pattern.atr <= 0.0)
      return false;

   FillPatternExtremes(setup_end_shift, trigger_shift, pattern);
   const double trigger_close = BarClose(trigger_shift);
   if(side > 0)
     {
      if(pattern.setup_first_close - trigger_close < strategy_atr_amplitude_mult * pattern.atr)
         return false;
     }
   else
     {
      if(trigger_close - pattern.setup_first_close < strategy_atr_amplitude_mult * pattern.atr)
         return false;
     }
   return (pattern.pattern_high > pattern.pattern_low);
  }

bool HasRecentSameDirectionCombo(const int side)
  {
   TDComboPattern ignored;
   for(int shift = 2; shift <= strategy_uniqueness_bars; ++shift)
      if(TDComboAtShift(side, shift, ignored))
         return true;
   return false;
  }

bool RuntimeReuseBlocked(const int side, const datetime trigger_time)
  {
   const datetime last_time = (side > 0) ? g_last_bullish_combo_bar : g_last_bearish_combo_bar;
   if(last_time <= 0)
      return false;
   const int last_shift = iBarShift(_Symbol, PERIOD_H4, last_time, false);
   const int trigger_shift = iBarShift(_Symbol, PERIOD_H4, trigger_time, false);
   if(last_shift < 0 || trigger_shift < 0)
      return false;
   return (MathAbs(last_shift - trigger_shift) <= strategy_uniqueness_bars);
  }

bool BuildSignal(TDComboPattern &pattern)
  {
   TDComboPattern bullish;
   if(TDComboAtShift(1, 1, bullish) && !HasRecentSameDirectionCombo(1) && !RuntimeReuseBlocked(1, bullish.trigger_time))
     {
      pattern = bullish;
      return true;
     }

   TDComboPattern bearish;
   if(TDComboAtShift(-1, 1, bearish) && !HasRecentSameDirectionCombo(-1) && !RuntimeReuseBlocked(-1, bearish.trigger_time))
     {
      pattern = bearish;
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(Period() != PERIOD_H4)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   return ((ask - bid) > strategy_spread_atr_mult * atr);
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

   ulong existing_ticket = 0;
   if(SameSymbolMagicPosition(existing_ticket))
      return false;
   if(TDComboOpenPositionCount() >= strategy_max_combo_positions)
      return false;

   TDComboPattern pattern;
   if(!BuildSignal(pattern))
      return false;

   const double entry = (pattern.side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   const double pattern_range = pattern.pattern_high - pattern.pattern_low;
   const double sl_distance = MathMin(strategy_sl_atr_cap * pattern.atr,
                                      MathMax(strategy_sl_atr_mult * pattern.atr,
                                              strategy_sl_range_mult * pattern_range));
   const double tp1_distance = strategy_tp1_range_mult * pattern_range;
   const double tp2_distance = strategy_tp2_range_mult * tp1_distance;
   if(sl_distance <= 0.0 || tp1_distance <= 0.0 || tp2_distance <= 0.0)
      return false;

   if(pattern.side > 0)
     {
      req.type = QM_BUY;
      req.sl = entry - sl_distance;
      req.tp = entry + tp2_distance;
      g_active_invalidation = pattern.pattern_low - strategy_invalidation_atr * pattern.atr;
      g_active_tp1 = entry + tp1_distance;
      g_last_bullish_combo_bar = pattern.trigger_time;
      req.reason = "TD_COMBO_BULLISH_13";
     }
   else
     {
      req.type = QM_SELL;
      req.sl = entry + sl_distance;
      req.tp = entry - tp2_distance;
      g_active_invalidation = pattern.pattern_high + strategy_invalidation_atr * pattern.atr;
      g_active_tp1 = entry - tp1_distance;
      g_last_bearish_combo_bar = pattern.trigger_time;
      req.reason = "TD_COMBO_BEARISH_13";
     }

   g_active_side = pattern.side;
   g_tp1_done = false;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(!SameSymbolMagicPosition(ticket) || !PositionSelectByTicket(ticket))
      return;
   if(g_tp1_done || g_active_side == 0 || g_active_tp1 <= 0.0)
      return;

   const double volume = PositionGetDouble(POSITION_VOLUME);
   if(volume <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const bool tp1_hit = (g_active_side > 0) ? (bid >= g_active_tp1) : (ask <= g_active_tp1);
   if(!tp1_hit)
      return;

   const double lots_to_close = volume * strategy_tp1_close_fraction;
   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
      g_tp1_done = true;
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!SameSymbolMagicPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int open_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(open_shift >= strategy_time_stop_bars)
      return true;

   if(g_active_side > 0 && g_active_invalidation > 0.0)
     {
      if(BarLow(1) < g_active_invalidation)
         return true;
     }
   if(g_active_side < 0 && g_active_invalidation > 0.0)
     {
      if(BarHigh(1) > g_active_invalidation)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1448\",\"ea\":\"QM5_1448_demark_td_combo_h4\"}");
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
