#property strict
#property version   "5.0"
#property description "QM5_2012 NNFX V2 FX Basket Top3 Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 2012;
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
input int    strategy_d1_momentum_bars   = 60;
input int    strategy_h4_ema_period      = 100;
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input int    strategy_ssl_period         = 10;
input int    strategy_breakout_bars      = 10;
input int    strategy_top_n              = 3;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_trail_atr_mult     = 2.8;
input double strategy_trail_start_r      = 1.5;
input int    strategy_max_hold_h4_bars   = 45;
input int    strategy_max_family_positions = 3;
input int    strategy_max_spread_points  = 0;

#define QM2012_BASKET_SIZE 6

string g_qm2012_symbols[QM2012_BASKET_SIZE] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "AUDUSD.DWX",
   "NZDUSD.DWX",
   "USDJPY.DWX",
   "USDCAD.DWX"
  };

int BasketSlotForSymbol(const string symbol)
  {
   for(int i = 0; i < QM2012_BASKET_SIZE; ++i)
      if(g_qm2012_symbols[i] == symbol)
         return i;
   return -1;
  }

double D1Momentum(const string symbol, const int d1_shift)
  {
   if(strategy_d1_momentum_bars <= 0)
      return 0.0;

   const double close_now = iClose(symbol, PERIOD_D1, d1_shift);
   const double close_then = iClose(symbol, PERIOD_D1, d1_shift + strategy_d1_momentum_bars);
   if(close_now <= 0.0 || close_then <= 0.0)
      return 0.0;
   return (close_now / close_then) - 1.0;
  }

int H4TrendScore(const string symbol, const int h4_shift)
  {
   const double close_h4 = iClose(symbol, PERIOD_H4, h4_shift);
   if(close_h4 <= 0.0)
      return 0;

   int score = 0;

   const double ema100 = QM_EMA(symbol, PERIOD_H4, strategy_h4_ema_period, h4_shift);
   if(ema100 > 0.0)
      score += (close_h4 > ema100) ? 1 : ((close_h4 < ema100) ? -1 : 0);

   const double macd_main = QM_MACD_Main(symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, h4_shift);
   const double macd_signal = QM_MACD_Signal(symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, h4_shift);
   if(macd_main != 0.0 || macd_signal != 0.0)
      score += (macd_main > macd_signal) ? 1 : ((macd_main < macd_signal) ? -1 : 0);

   const double ssl_high = QM_SMA(symbol, PERIOD_H4, strategy_ssl_period, h4_shift, PRICE_HIGH);
   const double ssl_low = QM_SMA(symbol, PERIOD_H4, strategy_ssl_period, h4_shift, PRICE_LOW);
   if(ssl_high > 0.0 && ssl_low > 0.0)
      score += (close_h4 > ssl_high) ? 1 : ((close_h4 < ssl_low) ? -1 : 0);

   return score;
  }

bool DirectionEligible(const string symbol, const int direction, const int h4_shift)
  {
   const double momentum = D1Momentum(symbol, 1);
   const int trend_score = H4TrendScore(symbol, h4_shift);

   if(direction > 0)
      return (momentum > 0.0 && trend_score >= 2);
   if(direction < 0)
      return (momentum < 0.0 && trend_score <= -2);
   return false;
  }

bool IsTopMomentumCandidate(const string symbol, const int direction, const int h4_shift)
  {
   if(strategy_top_n <= 0)
      return false;
   if(!DirectionEligible(symbol, direction, h4_shift))
      return false;

   const double own_abs_momentum = MathAbs(D1Momentum(symbol, 1));
   if(own_abs_momentum <= 0.0)
      return false;

   int stronger_count = 0;
   for(int i = 0; i < QM2012_BASKET_SIZE; ++i)
     {
      const string other = g_qm2012_symbols[i];
      if(other == symbol)
         continue;
      if(!DirectionEligible(other, direction, h4_shift))
         continue;

      const double other_abs_momentum = MathAbs(D1Momentum(other, 1));
      if(other_abs_momentum > own_abs_momentum)
         stronger_count++;
     }

   return (stronger_count < strategy_top_n);
  }

double HighestHigh(const string symbol, const ENUM_TIMEFRAMES tf, const int start_shift, const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double highest = -DBL_MAX;
   bool have_value = false;
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double high = iHigh(symbol, tf, shift);
      if(high <= 0.0)
         continue;
      highest = have_value ? MathMax(highest, high) : high;
      have_value = true;
     }

   return have_value ? highest : 0.0;
  }

double LowestLow(const string symbol, const ENUM_TIMEFRAMES tf, const int start_shift, const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double lowest = DBL_MAX;
   bool have_value = false;
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double low = iLow(symbol, tf, shift);
      if(low <= 0.0)
         continue;
      lowest = have_value ? MathMin(lowest, low) : low;
      have_value = true;
     }

   return have_value ? lowest : 0.0;
  }

bool BreakoutSignal(const string symbol, const int direction, const int h4_shift)
  {
   const double close_h4 = iClose(symbol, PERIOD_H4, h4_shift);
   if(close_h4 <= 0.0 || strategy_breakout_bars <= 0)
      return false;

   if(direction > 0)
     {
      const double prior_high = HighestHigh(symbol, PERIOD_H4, h4_shift + 1, strategy_breakout_bars);
      return (prior_high > 0.0 && close_h4 > prior_high);
     }

   if(direction < 0)
     {
      const double prior_low = LowestLow(symbol, PERIOD_H4, h4_shift + 1, strategy_breakout_bars);
      return (prior_low > 0.0 && close_h4 < prior_low);
     }

   return false;
  }

int CurrentPositionDirection(ulong &ticket, datetime &open_time)
  {
   ticket = 0;
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return (type == POSITION_TYPE_BUY) ? 1 : -1;
     }

   return 0;
  }

int FamilyOpenPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;

      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      for(int slot = 0; slot < QM2012_BASKET_SIZE; ++slot)
        {
         if(magic == QM_Magic(qm_ea_id, slot))
           {
            count++;
            break;
           }
        }
     }

   return count;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int slot = BasketSlotForSymbol(_Symbol);
   if(slot < 0)
      return false;
   req.symbol_slot = slot;

   if(strategy_max_family_positions > 0 && FamilyOpenPositionCount() >= strategy_max_family_positions)
      return false;

   ulong existing_ticket = 0;
   datetime open_time = 0;
   if(CurrentPositionDirection(existing_ticket, open_time) != 0)
      return false;

   int direction = 0;
   if(IsTopMomentumCandidate(_Symbol, 1, 1) && BreakoutSignal(_Symbol, 1, 1))
      direction = 1;
   else if(IsTopMomentumCandidate(_Symbol, -1, 1) && BreakoutSignal(_Symbol, -1, 1))
      direction = -1;
   else
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "QM5_2012_TOP3_LONG_H4_BREAKOUT" : "QM5_2012_TOP3_SHORT_H4_BREAKOUT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl <= 0.0)
         continue;

      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk_distance = MathAbs(open_price - sl);
      const double profit_distance = is_buy ? (market - open_price) : (open_price - market);
      if(risk_distance > 0.0 && profit_distance >= risk_distance * strategy_trail_start_r)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime open_time = 0;
   const int position_direction = CurrentPositionDirection(ticket, open_time);
   if(position_direction == 0)
      return false;

   if(BreakoutSignal(_Symbol, -position_direction, 1))
      return true;

   if(open_time > 0 && strategy_max_hold_h4_bars > 0)
     {
      const int open_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
      if(open_shift >= strategy_max_hold_h4_bars)
         return true;
     }

   const bool eligible_last = IsTopMomentumCandidate(_Symbol, position_direction, 1);
   const bool eligible_prev = IsTopMomentumCandidate(_Symbol, position_direction, 2);
   if(!eligible_last && !eligible_prev)
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
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2012\",\"ea\":\"QM5_2012_nnfx-v2-fx-basket-top3-trend\"}");
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

   const bool h4_new_bar = QM_IsNewBar(_Symbol, PERIOD_H4);
   if(!h4_new_bar)
      return;

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
      return;
     }

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
