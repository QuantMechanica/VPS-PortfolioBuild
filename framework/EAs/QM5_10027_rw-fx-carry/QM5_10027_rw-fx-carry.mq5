#property strict
#property version   "5.0"
#property description "QM5_10027 Robot Wealth FX Carry Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10027;
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
input int    strategy_momentum_days      = 60;
input int    strategy_vol_days           = 60;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 3.0;
input double strategy_spread_atr_max     = 0.20;
input int    strategy_rebalance_day      = 1;    // Monday, MT5 Sunday=0.
input int    strategy_rebalance_hour     = 1;    // After rollover has settled.
input int    strategy_top_quartile_count = 2;    // Five-symbol basket top quartile, rounded up.
input int    strategy_top_half_count     = 3;    // Five-symbol basket top half, rounded up.

bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != strategy_rebalance_day)
      return true;
   if(dt.hour < strategy_rebalance_hour)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(atr > 0.0 && point > 0.0 && (spread_points * point) > (strategy_spread_atr_max * atr))
      return true;

   const double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
   const double swap_short = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
   if(swap_long <= 0.0 && swap_short <= 0.0)
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
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const string symbols[5] = {"AUDJPY.DWX", "NZDJPY.DWX", "AUDUSD.DWX", "NZDUSD.DWX", "USDCHF.DWX"};
   double long_scores[5] = {0.0, 0.0, 0.0, 0.0, 0.0};
   double short_scores[5] = {0.0, 0.0, 0.0, 0.0, 0.0};
   double momentum[5] = {0.0, 0.0, 0.0, 0.0, 0.0};
   bool valid[5] = {false, false, false, false, false};

   int current_idx = -1;
   int valid_count = 0;
   const int vol_days = MathMax(2, strategy_vol_days);
   const int mom_days = MathMax(1, strategy_momentum_days);

   for(int i = 0; i < 5; ++i)
     {
      if(symbols[i] == _Symbol)
         current_idx = i;
      if(!SymbolSelect(symbols[i], true))
         continue;

      double sum = 0.0;
      double sum_sq = 0.0;
      int samples = 0;
      for(int shift = 1; shift <= vol_days; ++shift)
        {
         const double close_now = iClose(symbols[i], PERIOD_D1, shift);
         const double close_prev = iClose(symbols[i], PERIOD_D1, shift + 1);
         if(close_now <= 0.0 || close_prev <= 0.0)
           {
            samples = 0;
            break;
           }
         const double ret = (close_now / close_prev) - 1.0;
         sum += ret;
         sum_sq += ret * ret;
         samples++;
        }
      if(samples < 2)
         continue;

      const double mean = sum / samples;
      const double variance = (sum_sq / samples) - (mean * mean);
      if(variance <= 0.0)
         continue;

      const double close_recent = iClose(symbols[i], PERIOD_D1, 1);
      const double close_past = iClose(symbols[i], PERIOD_D1, mom_days + 1);
      if(close_recent <= 0.0 || close_past <= 0.0)
         continue;

      const double vol = MathSqrt(variance);
      const double swap_long = SymbolInfoDouble(symbols[i], SYMBOL_SWAP_LONG);
      const double swap_short = SymbolInfoDouble(symbols[i], SYMBOL_SWAP_SHORT);
      if(swap_long <= 0.0 && swap_short <= 0.0)
         continue;

      long_scores[i] = (swap_long > 0.0) ? (swap_long / vol) : 0.0;
      short_scores[i] = (swap_short > 0.0) ? (swap_short / vol) : 0.0;
      momentum[i] = (close_recent / close_past) - 1.0;
      valid[i] = true;
      valid_count++;
     }

   if(current_idx < 0 || !valid[current_idx] || valid_count < strategy_top_half_count)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   int long_rank = 1;
   int short_rank = 1;
   for(int j = 0; j < 5; ++j)
     {
      if(j == current_idx || !valid[j])
         continue;
      if(long_scores[j] > long_scores[current_idx])
         long_rank++;
      if(short_scores[j] > short_scores[current_idx])
         short_rank++;
     }

   const int top_quartile = MathMax(1, MathMin(5, strategy_top_quartile_count));
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(long_scores[current_idx] > 0.0 && long_rank <= top_quartile && momentum[current_idx] > 0.0)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "RW_FX_CARRY_LONG";
      return (req.sl > 0.0 && req.sl < req.price);
     }

   if(short_scores[current_idx] > 0.0 && short_rank <= top_quartile && momentum[current_idx] < 0.0)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "RW_FX_CARRY_SHORT";
      return (req.sl > req.price);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   bool position_is_buy = true;
   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_position = true;
      position_is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }
   if(!have_position)
      return false;

   const string symbols[5] = {"AUDJPY.DWX", "NZDJPY.DWX", "AUDUSD.DWX", "NZDUSD.DWX", "USDCHF.DWX"};
   double long_scores[5] = {0.0, 0.0, 0.0, 0.0, 0.0};
   double short_scores[5] = {0.0, 0.0, 0.0, 0.0, 0.0};
   double momentum[5] = {0.0, 0.0, 0.0, 0.0, 0.0};
   bool valid[5] = {false, false, false, false, false};

   int current_idx = -1;
   const int vol_days = MathMax(2, strategy_vol_days);
   const int mom_days = MathMax(1, strategy_momentum_days);
   for(int i = 0; i < 5; ++i)
     {
      if(symbols[i] == _Symbol)
         current_idx = i;
      if(!SymbolSelect(symbols[i], true))
         continue;

      double sum = 0.0;
      double sum_sq = 0.0;
      int samples = 0;
      for(int shift = 1; shift <= vol_days; ++shift)
        {
         const double close_now = iClose(symbols[i], PERIOD_D1, shift);
         const double close_prev = iClose(symbols[i], PERIOD_D1, shift + 1);
         if(close_now <= 0.0 || close_prev <= 0.0)
           {
            samples = 0;
            break;
           }
         const double ret = (close_now / close_prev) - 1.0;
         sum += ret;
         sum_sq += ret * ret;
         samples++;
        }
      if(samples < 2)
         continue;

      const double mean = sum / samples;
      const double variance = (sum_sq / samples) - (mean * mean);
      const double close_recent = iClose(symbols[i], PERIOD_D1, 1);
      const double close_past = iClose(symbols[i], PERIOD_D1, mom_days + 1);
      const double swap_long = SymbolInfoDouble(symbols[i], SYMBOL_SWAP_LONG);
      const double swap_short = SymbolInfoDouble(symbols[i], SYMBOL_SWAP_SHORT);
      if(variance <= 0.0 || close_recent <= 0.0 || close_past <= 0.0 || (swap_long <= 0.0 && swap_short <= 0.0))
         continue;

      const double vol = MathSqrt(variance);
      long_scores[i] = (swap_long > 0.0) ? (swap_long / vol) : 0.0;
      short_scores[i] = (swap_short > 0.0) ? (swap_short / vol) : 0.0;
      momentum[i] = (close_recent / close_past) - 1.0;
      valid[i] = true;
     }

   if(current_idx < 0 || !valid[current_idx])
      return true;

   int long_rank = 1;
   int short_rank = 1;
   for(int j = 0; j < 5; ++j)
     {
      if(j == current_idx || !valid[j])
         continue;
      if(long_scores[j] > long_scores[current_idx])
         long_rank++;
      if(short_scores[j] > short_scores[current_idx])
         short_rank++;
     }

   const int top_half = MathMax(1, MathMin(5, strategy_top_half_count));
   if(position_is_buy)
      return (momentum[current_idx] <= 0.0 || long_rank > top_half);
   return (momentum[current_idx] >= 0.0 || short_rank > top_half);
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
