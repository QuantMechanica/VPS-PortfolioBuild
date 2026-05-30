#property strict
#property version   "5.0"
#property description "QM5_1233 ICT Silver Bullet NY AM liquidity sweep"

#include <Trade/Trade.mqh>
#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1233;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf  = PERIOD_M5;
input int    strategy_ny_entry_start_hhmm = 1000;
input int    strategy_ny_entry_end_hhmm   = 1100;
input int    strategy_ny_time_exit_hhmm   = 1155;
input int    strategy_sweep_buffer_points = 5;
input int    strategy_stop_buffer_points  = 5;
input int    strategy_min_stop_points     = 25;
input int    strategy_atr_period_m5       = 14;
input int    strategy_atr_period_h1       = 14;
input double strategy_max_stop_atr_mult   = 1.50;
input double strategy_min_reward_risk     = 1.50;
input double strategy_take_profit_rr      = 2.00;
input int    strategy_max_displacement_bars = 3;
input double strategy_min_range_atr_h1_mult = 0.35;
input double strategy_min_atr_m5_mult     = 0.50;
input int    strategy_atr_median_days     = 20;
input int    strategy_max_spread_points   = 35;

#define STRATEGY_SYMBOL_COUNT 12

const string STRATEGY_SYMBOLS[STRATEGY_SYMBOL_COUNT] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "NZDUSD.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX"
  };

datetime g_last_entry_bar = 0;
int      g_last_filled_session_key = 0;

datetime Strategy_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   return utc + ny_offset_hours * 3600;
  }

int Strategy_Hhmm(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_SymbolSlot()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(_Symbol == STRATEGY_SYMBOLS[i])
         return i;
     }
   return -1;
  }

bool Strategy_SpreadOk()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   return ((ask - bid) / point <= (double)strategy_max_spread_points);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool Strategy_HasPendingOrder()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic)
         return true;
     }

   return false;
  }

void Strategy_CancelOwnPendingOrders(const string reason)
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return;

   CTrade trade;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      if(trade.OrderDelete(ticket))
         QM_LogEvent(QM_INFO, "PENDING_CANCEL", StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\"}", ticket, reason));
     }
  }

void Strategy_CancelInvalidPendingOrders()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(close_1 <= 0.0)
      return;

   CTrade trade;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      const double sl = OrderGetDouble(ORDER_SL);
      if(sl <= 0.0)
         continue;
      if((order_type == ORDER_TYPE_BUY_LIMIT && close_1 <= sl) ||
         (order_type == ORDER_TYPE_SELL_LIMIT && close_1 >= sl))
        {
         if(trade.OrderDelete(ticket))
            QM_LogEvent(QM_INFO, "PENDING_INVALIDATED", StringFormat("{\"ticket\":%I64u}", ticket));
        }
     }
  }

bool Strategy_BuildReferenceRange(datetime &ny_now,
                                  double &buy_side_liquidity,
                                  double &sell_side_liquidity,
                                  double &range_high,
                                  double &range_low)
  {
   ny_now = Strategy_BrokerToNewYork(TimeCurrent());
   const int today_key = Strategy_DateKey(ny_now);

   buy_side_liquidity = -DBL_MAX;
   sell_side_liquidity = DBL_MAX;
   range_high = -DBL_MAX;
   range_low = DBL_MAX;

   const double prev_h1_high = iHigh(_Symbol, PERIOD_H1, 1);
   const double prev_h1_low = iLow(_Symbol, PERIOD_H1, 1);
   if(prev_h1_high <= 0.0 || prev_h1_low <= 0.0 || prev_h1_high <= prev_h1_low)
      return false;

   for(int shift = 1; shift <= 288; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, strategy_signal_tf, shift);
      if(bar_time <= 0)
         break;

      const datetime ny_bar = Strategy_BrokerToNewYork(bar_time);
      if(Strategy_DateKey(ny_bar) != today_key)
         continue;

      const int hhmm = Strategy_Hhmm(ny_bar);
      if(hhmm >= 900 && hhmm < 1000)
        {
         const double high_i = iHigh(_Symbol, strategy_signal_tf, shift);
         const double low_i = iLow(_Symbol, strategy_signal_tf, shift);
         if(high_i <= 0.0 || low_i <= 0.0 || high_i < low_i)
            return false;
         if(high_i > range_high)
            range_high = high_i;
         if(low_i < range_low)
            range_low = low_i;
        }
     }

   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   buy_side_liquidity = MathMax(prev_h1_high, range_high);
   sell_side_liquidity = MathMin(prev_h1_low, range_low);
   return (buy_side_liquidity > sell_side_liquidity);
  }

bool Strategy_SessionRangeQualityOk(const double range_high, const double range_low)
  {
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, MathMax(1, strategy_atr_period_h1), 1);
   if(atr_h1 <= 0.0)
      return false;
   return ((range_high - range_low) >= strategy_min_range_atr_h1_mult * atr_h1);
  }

bool Strategy_AtrQualityOk()
  {
   const int period = MathMax(1, strategy_atr_period_m5);
   const double current_atr = QM_ATR(_Symbol, strategy_signal_tf, period, 1);
   if(current_atr <= 0.0)
      return false;

   double samples[20];
   int count = 0;
   const int days = MathMin(20, MathMax(1, strategy_atr_median_days));
   for(int day = 1; day <= days; ++day)
     {
      const int shift = day * 288 + 1;
      const double sample = QM_ATR(_Symbol, strategy_signal_tf, period, shift);
      if(sample > 0.0 && count < 20)
        {
         samples[count] = sample;
         ++count;
        }
     }

   if(count < MathMin(5, days))
      return true;

   for(int i = 0; i < count - 1; ++i)
     {
      for(int j = i + 1; j < count; ++j)
        {
         if(samples[j] < samples[i])
           {
            const double tmp = samples[i];
            samples[i] = samples[j];
            samples[j] = tmp;
           }
        }
     }
   const double median_atr = samples[count / 2];
   return (median_atr <= 0.0 || current_atr >= strategy_min_atr_m5_mult * median_atr);
  }

bool Strategy_StopDistanceOk(const QM_OrderType side, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(side) && sl >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(side) && sl <= entry)
      return false;

   const double stop_points = MathAbs(entry - sl) / point;
   if(stop_points < (double)MathMax(1, strategy_min_stop_points))
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level > 0 && stop_points <= (double)stops_level)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period_m5), 1);
   if(atr <= 0.0)
      return false;

   return (MathAbs(entry - sl) <= strategy_max_stop_atr_mult * atr);
  }

bool Strategy_FindOpposingSwingTarget(const bool long_side,
                                      const double entry,
                                      const double sl,
                                      const double range_high,
                                      const double range_low,
                                      double &target)
  {
   target = 0.0;
   if(entry <= 0.0 || sl <= 0.0)
      return false;

   if(long_side)
      target = range_high;
   else
      target = range_low;

   if(target <= 0.0)
      return false;

   const double reward = long_side ? (target - entry) : (entry - target);
   const double risk = MathAbs(entry - sl);
   if(risk <= 0.0 || reward / risk < strategy_min_reward_risk)
      return false;

   target = NormalizeDouble(target, _Digits);
   return true;
  }

bool Strategy_BuildLongSetup(QM_EntryRequest &req,
                             const double sell_side_liquidity,
                             const double range_high,
                             const double range_low)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int max_bars = MathMax(1, strategy_max_displacement_bars);
   double sweep_low = DBL_MAX;
   bool swept = false;
   for(int shift = 1; shift <= max_bars; ++shift)
     {
      const double low_i = iLow(_Symbol, strategy_signal_tf, shift);
      if(low_i > 0.0 && low_i <= sell_side_liquidity - (double)strategy_sweep_buffer_points * point)
        {
         swept = true;
         if(low_i < sweep_low)
            sweep_low = low_i;
        }
     }
   if(!swept || iClose(_Symbol, strategy_signal_tf, 1) <= sell_side_liquidity)
      return false;

   const double fvg_low = iLow(_Symbol, strategy_signal_tf, 1);
   const double fvg_high = iHigh(_Symbol, strategy_signal_tf, 3);
   if(fvg_low <= 0.0 || fvg_high <= 0.0 || fvg_low <= fvg_high)
      return false;

   const double entry = NormalizeDouble((fvg_low + fvg_high) * 0.5, _Digits);
   const double sl = NormalizeDouble(MathMin(sweep_low, fvg_high) - (double)strategy_stop_buffer_points * point, _Digits);
   if(!Strategy_StopDistanceOk(QM_BUY_LIMIT, entry, sl))
      return false;

   double tp = 0.0;
   if(!Strategy_FindOpposingSwingTarget(true, entry, sl, range_high, range_low, tp))
      tp = NormalizeDouble(entry + MathAbs(entry - sl) * strategy_take_profit_rr, _Digits);

   req.type = QM_BUY_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = "ict_silver_bullet_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 3600;
   return true;
  }

bool Strategy_BuildShortSetup(QM_EntryRequest &req,
                              const double buy_side_liquidity,
                              const double range_high,
                              const double range_low)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int max_bars = MathMax(1, strategy_max_displacement_bars);
   double sweep_high = -DBL_MAX;
   bool swept = false;
   for(int shift = 1; shift <= max_bars; ++shift)
     {
      const double high_i = iHigh(_Symbol, strategy_signal_tf, shift);
      if(high_i > 0.0 && high_i >= buy_side_liquidity + (double)strategy_sweep_buffer_points * point)
        {
         swept = true;
         if(high_i > sweep_high)
            sweep_high = high_i;
        }
     }
   if(!swept || iClose(_Symbol, strategy_signal_tf, 1) >= buy_side_liquidity)
      return false;

   const double fvg_high = iHigh(_Symbol, strategy_signal_tf, 1);
   const double fvg_low = iLow(_Symbol, strategy_signal_tf, 3);
   if(fvg_high <= 0.0 || fvg_low <= 0.0 || fvg_high >= fvg_low)
      return false;

   const double entry = NormalizeDouble((fvg_high + fvg_low) * 0.5, _Digits);
   const double sl = NormalizeDouble(MathMax(sweep_high, fvg_low) + (double)strategy_stop_buffer_points * point, _Digits);
   if(!Strategy_StopDistanceOk(QM_SELL_LIMIT, entry, sl))
      return false;

   double tp = 0.0;
   if(!Strategy_FindOpposingSwingTarget(false, entry, sl, range_high, range_low, tp))
      tp = NormalizeDouble(entry - MathAbs(sl - entry) * strategy_take_profit_rr, _Digits);

   req.type = QM_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = "ict_silver_bullet_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 3600;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   const int slot = Strategy_SymbolSlot();
   if(slot < 0)
      return true;
   if(qm_magic_slot_offset != slot)
      return true;
   if(_Period != strategy_signal_tf)
      return true;
   if(Bars(_Symbol, strategy_signal_tf) < 310)
      return true;

   const datetime ny_now = Strategy_BrokerToNewYork(TimeCurrent());
   if(Strategy_Hhmm(ny_now) >= strategy_ny_entry_end_hhmm)
      Strategy_CancelOwnPendingOrders("ny_window_closed");

   Strategy_CancelInvalidPendingOrders();
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

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_entry_bar)
      return false;

   datetime ny_now = 0;
   double buy_side_liq = 0.0;
   double sell_side_liq = 0.0;
   double range_high = 0.0;
   double range_low = 0.0;
   if(!Strategy_BuildReferenceRange(ny_now, buy_side_liq, sell_side_liq, range_high, range_low))
      return false;

   const int hhmm = Strategy_Hhmm(ny_now);
   if(hhmm < strategy_ny_entry_start_hhmm || hhmm >= strategy_ny_entry_end_hhmm)
      return false;

   const int session_key = Strategy_DateKey(ny_now);
   if(g_last_filled_session_key == session_key)
      return false;
   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrder())
      return false;
   if(!Strategy_SpreadOk() || !Strategy_SessionRangeQualityOk(range_high, range_low) || !Strategy_AtrQualityOk())
      return false;

   bool signal = Strategy_BuildShortSetup(req, buy_side_liq, range_high, range_low);
   if(!signal)
      signal = Strategy_BuildLongSetup(req, sell_side_liq, range_high, range_low);

   if(signal)
      g_last_entry_bar = bar_time;

   return signal;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOpenPosition())
     {
      const datetime ny_now = Strategy_BrokerToNewYork(TimeCurrent());
      if(Strategy_Hhmm(ny_now) >= strategy_ny_entry_start_hhmm)
         g_last_filled_session_key = Strategy_DateKey(ny_now);
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime ny_now = Strategy_BrokerToNewYork(TimeCurrent());
   return (Strategy_Hhmm(ny_now) >= strategy_ny_time_exit_hhmm);
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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

   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
