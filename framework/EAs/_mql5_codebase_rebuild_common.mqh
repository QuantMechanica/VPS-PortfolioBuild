#ifndef QM_MQL5_CODEBASE_REBUILD_COMMON_MQH
#define QM_MQL5_CODEBASE_REBUILD_COMMON_MQH

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
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

int Strategy_SymbolSlot()
  {
   for(int i = 0; i < ArraySize(strategy_symbols); ++i)
     {
      if(_Symbol == strategy_symbols[i])
         return i;
     }
   return qm_magic_slot_offset;
  }

double Strategy_Close(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(_Symbol, tf, shift);
  }

double Strategy_HighestHigh(const ENUM_TIMEFRAMES tf, const int start_shift, const int bars)
  {
   double highest = -DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double value = iHigh(_Symbol, tf, i);
      if(value > highest)
         highest = value;
     }
   return (highest == -DBL_MAX) ? 0.0 : highest;
  }

double Strategy_LowestLow(const ENUM_TIMEFRAMES tf, const int start_shift, const int bars)
  {
   double lowest = DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double value = iLow(_Symbol, tf, i);
      if(value > 0.0 && value < lowest)
         lowest = value;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
  }

double Strategy_TickVolumeAverage(const ENUM_TIMEFRAMES tf, const int start_shift, const int bars)
  {
   double total = 0.0;
   int samples = 0;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const long value = iVolume(_Symbol, tf, i);
      if(value > 0)
        {
         total += (double)value;
         samples++;
        }
     }
   return (samples > 0) ? total / samples : 0.0;
  }

bool Strategy_BuildEntry(QM_EntryRequest &req, const int direction)
  {
   if(direction == 0 || Strategy_HasOpenPosition())
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(direction > 0 && sl >= entry)
      return false;
   if(direction < 0 && sl <= entry)
      return false;

   const double risk = MathAbs(entry - sl);
   double tp = 0.0;
   if(strategy_tp_r_mult > 0.0)
      tp = (direction > 0) ? entry + risk * strategy_tp_r_mult : entry - risk * strategy_tp_r_mult;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = strategy_reason;
   req.symbol_slot = Strategy_SymbolSlot();
   req.expiration_seconds = 0;
   return true;
  }

int Strategy_Direction()
  {
   const double close1 = Strategy_Close(strategy_signal_tf, 1);
   const double close2 = Strategy_Close(strategy_signal_tf, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return 0;

   if(strategy_model == 0)
     {
      const double adx1 = QM_ADX(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
      const double adx2 = QM_ADX(_Symbol, strategy_signal_tf, strategy_adx_period, 2);
      const double ama1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 1);
      const double ama2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 2);
      if(adx1 > 0.0 && adx2 > 0.0 && adx1 < adx2 && ama1 > ama2)
         return 1;
      if(adx1 > 0.0 && adx2 > 0.0 && adx1 > adx2 && ama1 < ama2)
         return -1;
     }
   else if(strategy_model == 1)
     {
      const double hi = Strategy_HighestHigh(strategy_signal_tf, 2, strategy_channel_bars);
      const double lo = Strategy_LowestLow(strategy_signal_tf, 2, strategy_channel_bars);
      if(lo > 0.0 && close1 < lo)
         return 1;
      if(hi > 0.0 && close1 > hi)
         return -1;
     }
   else if(strategy_model == 2)
     {
      const double rsi1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
      const double rsi2 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 2);
      const double e1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 1);
      const double e2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 2);
      const double m1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_mid_period, 1);
      const double m2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_mid_period, 2);
      const double s1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_period, 1);
      const double s2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_period, 2);
      if(rsi2 < 50.0 && rsi1 > 50.0 && e1 - e2 > strategy_delta && m1 - m2 > strategy_delta && s1 - s2 > strategy_delta)
         return 1;
      if(rsi2 > 50.0 && rsi1 < 50.0 && e2 - e1 > strategy_delta && m2 - m1 > strategy_delta && s2 - s1 > strategy_delta)
         return -1;
     }
   else if(strategy_model == 3)
     {
      const double fast1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 1);
      const double fast2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 2);
      const double slow1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_period, 1);
      const double slow2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_period, 2);
      const double mom = close1 - Strategy_Close(strategy_signal_tf, MathMax(2, strategy_momentum_period));
      if(fast1 > slow1 + strategy_min_distance_points * _Point && fast2 < slow2 - strategy_min_distance_points * _Point && mom > 0.0)
         return 1;
      if(fast1 < slow1 - strategy_min_distance_points * _Point && fast2 > slow2 + strategy_min_distance_points * _Point && mom < 0.0)
         return -1;
     }
   else if(strategy_model == 4)
     {
      const double rsi = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
      const double ema1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 1);
      const double ema2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 2);
      if(close1 > ema1 && ema1 > ema2 && rsi > 50.0)
         return 1;
      if(close1 < ema1 && ema1 < ema2 && rsi < 50.0)
         return -1;
     }
   else if(strategy_model == 5)
     {
      const double ma1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_period, 1);
      const double ma2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_period, 2);
      if(close1 > ma1 && ma1 > ma2)
         return 1;
      if(close1 < ma1 && ma1 < ma2)
         return -1;
     }
   else if(strategy_model == 6)
     {
      const double d_hi = iHigh(_Symbol, PERIOD_D1, 1);
      const double d_lo = iLow(_Symbol, PERIOD_D1, 1);
      const double vol = (double)iVolume(_Symbol, strategy_signal_tf, 1);
      const double vol_avg = Strategy_TickVolumeAverage(strategy_signal_tf, 2, strategy_volume_lookback);
      if(d_hi > 0.0 && vol_avg > 0.0 && close1 > d_hi + strategy_breakout_buffer_points * _Point && vol >= vol_avg * strategy_volume_mult)
         return 1;
      if(d_lo > 0.0 && vol_avg > 0.0 && close1 < d_lo - strategy_breakout_buffer_points * _Point && vol >= vol_avg * strategy_volume_mult)
         return -1;
     }
   else if(strategy_model == 7)
     {
      const double fast1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 1);
      const double fast2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_period, 2);
      const double slow1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_mid_period, 1);
      const double slow2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_mid_period, 2);
      if(fast2 <= slow2 && fast1 > slow1 && close1 > fast1)
         return 1;
      if(fast2 >= slow2 && fast1 < slow1 && close1 < fast1)
         return -1;
     }
   else if(strategy_model == 8)
     {
      const double hi = Strategy_HighestHigh(strategy_signal_tf, 2, strategy_channel_bars);
      const double lo = Strategy_LowestLow(strategy_signal_tf, 2, strategy_channel_bars);
      if(hi > 0.0 && close1 > hi)
         return 1;
      if(lo > 0.0 && close1 < lo)
         return -1;
     }
   else if(strategy_model == 9)
     {
      const double rsi1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
      const double rsi2 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 2);
      if(rsi1 > 55.0 && rsi1 > rsi2)
         return 1;
      if(rsi1 < 45.0 && rsi1 < rsi2)
         return -1;
     }
   else if(strategy_model == 10)
     {
      const double ma1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_mid_period, 1);
      const double ma2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_mid_period, 2);
      if(close2 <= ma2 && close1 > ma1 && ma1 > ma2)
         return 1;
      if(close2 >= ma2 && close1 < ma1 && ma1 < ma2)
         return -1;
     }
   else if(strategy_model == 11)
     {
      const double roc1 = close1 - Strategy_Close(strategy_signal_tf, strategy_momentum_period);
      const double roc2 = close2 - Strategy_Close(strategy_signal_tf, strategy_momentum_period + 1);
      if(roc2 <= 0.0 && roc1 > 0.0)
         return 1;
      if(roc2 >= 0.0 && roc1 < 0.0)
         return -1;
     }
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
         return true;
      if((ask - bid) / _Point > strategy_max_spread_points)
         return true;
     }
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(strategy_min_atr_points > 0.0 && atr > 0.0 && atr / _Point < strategy_min_atr_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return Strategy_BuildEntry(req, Strategy_Direction());
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const datetime closed_bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(closed_bar_time <= 0)
      return false;
   if(closed_bar_time == g_strategy_exit_eval_bar)
      return g_strategy_exit_signal_cached;

   g_strategy_exit_eval_bar = closed_bar_time;
   g_strategy_exit_signal_cached = false;
   const int direction = Strategy_Direction();
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

      const long type = PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_time_stop_bars > 0 && opened > 0)
        {
         const int held = iBarShift(_Symbol, strategy_signal_tf, opened, false);
         if(held >= strategy_time_stop_bars)
           {
            g_strategy_exit_signal_cached = true;
            return true;
           }
        }
      if(type == POSITION_TYPE_BUY && direction < 0)
        {
         g_strategy_exit_signal_cached = true;
         return true;
        }
      if(type == POSITION_TYPE_SELL && direction > 0)
        {
         g_strategy_exit_signal_cached = true;
         return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

#endif // QM_MQL5_CODEBASE_REBUILD_COMMON_MQH
