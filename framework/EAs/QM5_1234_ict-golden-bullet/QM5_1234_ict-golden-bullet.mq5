#property strict
#property version   "5.0"
#property description "QM5_1234 ICT Golden Bullet NY PM liquidity sweep"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1234;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.50;

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
input int    strategy_ny_utc_offset_hours = -4;
input int    strategy_sweep_buffer_points = 5;
input int    strategy_stop_buffer_points  = 5;
input int    strategy_min_stop_points     = 20;
input int    strategy_atr_period_m5       = 14;
input double strategy_max_stop_atr_mult   = 1.50;
input double strategy_min_reward_risk     = 1.50;
input double strategy_take_profit_rr      = 2.00;
input int    strategy_swing_lookback_bars = 12;
input int    strategy_max_spread_points   = 0;
input double strategy_max_spread_mult     = 2.50;
input double strategy_min_atr_hour_mult   = 0.50;

#define STRATEGY_SYMBOL_COUNT 12

const string STRATEGY_SYMBOLS[12] =
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

int      g_session_day = -1;
double   g_buy_side_liquidity = 0.0;
double   g_sell_side_liquidity = 0.0;
bool     g_short_swept = false;
bool     g_long_swept = false;
double   g_short_sweep_high = 0.0;
double   g_long_sweep_low = 0.0;
int      g_short_sweep_bars = 0;
int      g_long_sweep_bars = 0;
bool     g_short_ordered = false;
bool     g_long_ordered = false;
datetime g_last_entry_bar = 0;

datetime Strategy_BrokerToNY(const datetime broker_time)
  {
   return QM_BrokerToUTC(broker_time) + strategy_ny_utc_offset_hours * 3600;
  }

int Strategy_NYDateKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToNY(broker_time), dt);
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

bool Strategy_IsPMWindow(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(Strategy_BrokerToNY(broker_time), ny);
   return (ny.hour == 13);
  }

bool Strategy_IsCancelWindow(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(Strategy_BrokerToNY(broker_time), ny);
   return (ny.hour >= 14);
  }

bool Strategy_IsTimeExitWindow(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(Strategy_BrokerToNY(broker_time), ny);
   return (ny.hour > 14 || (ny.hour == 14 && ny.min >= 55));
  }

bool Strategy_CurrentSpread(double &spread_price, double &spread_points)
  {
   spread_price = 0.0;
   spread_points = 0.0;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || point <= 0.0)
      return false;

   spread_price = ask - bid;
   spread_points = spread_price / point;
   return true;
  }

bool Strategy_QualityFiltersOk()
  {
   double spread_price = 0.0;
   double spread_points = 0.0;
   if(!Strategy_CurrentSpread(spread_price, spread_points))
      return false;
   if(strategy_max_spread_points > 0 && spread_points > (double)strategy_max_spread_points)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: Strategy_QualityFiltersOk() is only called from EntrySignal after the framework new-bar gate.
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, 288 * 25, rates); // perf-allowed
   if(copied < 288)
      return false;

   MqlDateTime now_ny;
   TimeToStruct(Strategy_BrokerToNY(TimeCurrent()), now_ny);
   double spread_samples[];
   double atr_samples[];
   ArrayResize(spread_samples, 0);
   ArrayResize(atr_samples, 0);

   for(int i = 0; i < copied; ++i)
     {
      MqlDateTime bar_ny;
      TimeToStruct(Strategy_BrokerToNY(rates[i].time), bar_ny);
      if(bar_ny.hour != now_ny.hour || rates[i].spread <= 0)
         continue;

      const int idx = ArraySize(spread_samples);
      ArrayResize(spread_samples, idx + 1);
      ArrayResize(atr_samples, idx + 1);
      spread_samples[idx] = (double)rates[i].spread;
      atr_samples[idx] = MathMax(0.0, rates[i].high - rates[i].low);
     }

   if(ArraySize(spread_samples) >= 10)
     {
      ArraySort(spread_samples);
      const double median_spread = spread_samples[ArraySize(spread_samples) / 2];
      if(median_spread > 0.0 && spread_points > strategy_max_spread_mult * median_spread)
         return false;
     }

   if(ArraySize(atr_samples) >= 10)
     {
      ArraySort(atr_samples);
      const double median_range = atr_samples[ArraySize(atr_samples) / 2];
      const double atr_now = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period_m5), 1);
      if(median_range > 0.0 && atr_now < strategy_min_atr_hour_mult * median_range)
         return false;
     }

   return true;
  }

bool Strategy_OurPendingLimitType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT);
  }

bool Strategy_DeletePendingOrder(const ulong ticket, const string reason)
  {
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   request.symbol = _Symbol;
   request.comment = reason;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);
   QM_LogEvent(ok ? QM_INFO : QM_WARN,
               "PENDING_DELETE",
               StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
                            ticket,
                            QM_LoggerEscapeJson(reason),
                            ok ? "true" : "false",
                            result.retcode,
                            QM_LoggerEscapeJson(error_class)));
   return ok;
  }

void Strategy_DeleteOurPendingLimits(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_OurPendingLimitType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      Strategy_DeletePendingOrder(ticket, reason);
     }
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

bool Strategy_HasOurPendingLimit()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_OurPendingLimitType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_ResetSession(const datetime broker_time)
  {
   g_session_day = Strategy_NYDateKey(broker_time);
   g_buy_side_liquidity = 0.0;
   g_sell_side_liquidity = 0.0;
   g_short_swept = false;
   g_long_swept = false;
   g_short_sweep_high = 0.0;
   g_long_sweep_low = 0.0;
   g_short_sweep_bars = 0;
   g_long_sweep_bars = 0;
   g_short_ordered = false;
   g_long_ordered = false;
  }

bool Strategy_PrepareReferenceRange(const datetime broker_time)
  {
   if(g_session_day != Strategy_NYDateKey(broker_time))
      Strategy_ResetSession(broker_time);
   if(g_buy_side_liquidity > 0.0 && g_sell_side_liquidity > 0.0)
      return true;

   const double prev_h1_high = iHigh(_Symbol, PERIOD_H1, 1);
   const double prev_h1_low = iLow(_Symbol, PERIOD_H1, 1);
   if(prev_h1_high <= 0.0 || prev_h1_low <= 0.0 || prev_h1_high <= prev_h1_low)
      return false;

   double hour_high = -DBL_MAX;
   double hour_low = DBL_MAX;
   for(int i = 1; i <= 48; ++i)
     {
      const datetime bt = iTime(_Symbol, strategy_signal_tf, i);
      if(bt <= 0)
         continue;
      MqlDateTime ny;
      TimeToStruct(Strategy_BrokerToNY(bt), ny);
      if(ny.hour != 12)
         continue;

      const double high_i = iHigh(_Symbol, strategy_signal_tf, i);
      const double low_i = iLow(_Symbol, strategy_signal_tf, i);
      if(high_i > hour_high)
         hour_high = high_i;
      if(low_i < hour_low)
         hour_low = low_i;
     }

   if(hour_high <= 0.0 || hour_low <= 0.0 || hour_high <= hour_low)
      return false;

   g_buy_side_liquidity = MathMax(prev_h1_high, hour_high);
   g_sell_side_liquidity = MathMin(prev_h1_low, hour_low);
   return (g_buy_side_liquidity > g_sell_side_liquidity);
  }

bool Strategy_SessionRangeOk()
  {
   double high_12 = -DBL_MAX;
   double low_12 = DBL_MAX;
   for(int i = 1; i <= 48; ++i)
     {
      const datetime bt = iTime(_Symbol, strategy_signal_tf, i);
      if(bt <= 0)
         continue;
      MqlDateTime ny;
      TimeToStruct(Strategy_BrokerToNY(bt), ny);
      if(ny.hour != 12)
         continue;
      high_12 = MathMax(high_12, iHigh(_Symbol, strategy_signal_tf, i));
      low_12 = MathMin(low_12, iLow(_Symbol, strategy_signal_tf, i));
     }

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, MathMax(1, strategy_atr_period_m5), 1);
   return (high_12 > low_12 && atr_h1 > 0.0 && (high_12 - low_12) >= 0.30 * atr_h1);
  }

double Strategy_NearestSwingTarget(const bool want_high, const double entry)
  {
   double target = 0.0;
   for(int i = 1; i <= MathMax(2, strategy_swing_lookback_bars); ++i)
     {
      const datetime bt = iTime(_Symbol, strategy_signal_tf, i);
      if(bt <= 0)
         continue;
      MqlDateTime ny;
      TimeToStruct(Strategy_BrokerToNY(bt), ny);
      if(ny.hour != 12)
         continue;

      if(want_high)
        {
         const double h = iHigh(_Symbol, strategy_signal_tf, i);
         if(h > entry && (target <= 0.0 || h < target))
            target = h;
        }
      else
        {
         const double l = iLow(_Symbol, strategy_signal_tf, i);
         if(l < entry && (target <= 0.0 || l > target))
            target = l;
        }
     }
   return target;
  }

bool Strategy_StopDistanceOk(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const double stop_points = MathAbs(entry - sl) / point;
   if(stop_points < (double)MathMax(1, strategy_min_stop_points))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period_m5), 1);
   if(atr <= 0.0)
      return false;

   return (MathAbs(entry - sl) <= strategy_max_stop_atr_mult * atr);
  }

void Strategy_UpdateSweepState()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const double high_1 = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low_1 = iLow(_Symbol, strategy_signal_tf, 1);
   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double sweep_buffer = MathMax(0, strategy_sweep_buffer_points) * point;

   if(!g_short_ordered)
     {
      if(!g_short_swept && high_1 >= g_buy_side_liquidity + sweep_buffer)
        {
         g_short_swept = true;
         g_short_sweep_high = high_1;
         g_short_sweep_bars = 0;
        }
      else if(g_short_swept)
        {
         ++g_short_sweep_bars;
         g_short_sweep_high = MathMax(g_short_sweep_high, high_1);
         if(g_short_sweep_bars > 3 || close_1 > g_buy_side_liquidity + sweep_buffer)
            g_short_swept = false;
        }
     }

   if(!g_long_ordered)
     {
      if(!g_long_swept && low_1 <= g_sell_side_liquidity - sweep_buffer)
        {
         g_long_swept = true;
         g_long_sweep_low = low_1;
         g_long_sweep_bars = 0;
        }
      else if(g_long_swept)
        {
         ++g_long_sweep_bars;
         g_long_sweep_low = MathMin(g_long_sweep_low, low_1);
         if(g_long_sweep_bars > 3 || close_1 < g_sell_side_liquidity - sweep_buffer)
            g_long_swept = false;
        }
     }
  }

bool Strategy_BuildShortLimit(QM_EntryRequest &req)
  {
   if(!g_short_swept || g_short_ordered)
      return false;
   if(iClose(_Symbol, strategy_signal_tf, 1) >= g_buy_side_liquidity)
      return false;

   const double fvg_bottom = iHigh(_Symbol, strategy_signal_tf, 3);
   const double fvg_top = iLow(_Symbol, strategy_signal_tf, 1);
   if(fvg_bottom <= 0.0 || fvg_top <= 0.0 || fvg_bottom >= fvg_top)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double entry = NormalizeDouble((fvg_bottom + fvg_top) * 0.5, _Digits);
   const double sl = NormalizeDouble(MathMax(g_short_sweep_high, fvg_top) + MathMax(0, strategy_stop_buffer_points) * point, _Digits);
   if(sl <= entry || !Strategy_StopDistanceOk(entry, sl))
      return false;

   double tp = Strategy_NearestSwingTarget(false, entry);
   const double risk = sl - entry;
   if(tp <= 0.0 || (entry - tp) / risk < strategy_min_reward_risk)
      tp = entry - strategy_take_profit_rr * risk;

   req.type = QM_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = "ict_golden_bullet_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 3600;
   g_short_ordered = true;
   return true;
  }

bool Strategy_BuildLongLimit(QM_EntryRequest &req)
  {
   if(!g_long_swept || g_long_ordered)
      return false;
   if(iClose(_Symbol, strategy_signal_tf, 1) <= g_sell_side_liquidity)
      return false;

   const double fvg_bottom = iHigh(_Symbol, strategy_signal_tf, 1);
   const double fvg_top = iLow(_Symbol, strategy_signal_tf, 3);
   if(fvg_bottom <= 0.0 || fvg_top <= 0.0 || fvg_bottom >= fvg_top)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double entry = NormalizeDouble((fvg_bottom + fvg_top) * 0.5, _Digits);
   const double sl = NormalizeDouble(MathMin(g_long_sweep_low, fvg_bottom) - MathMax(0, strategy_stop_buffer_points) * point, _Digits);
   if(sl >= entry || !Strategy_StopDistanceOk(entry, sl))
      return false;

   double tp = Strategy_NearestSwingTarget(true, entry);
   const double risk = entry - sl;
   if(tp <= 0.0 || (tp - entry) / risk < strategy_min_reward_risk)
      tp = entry + strategy_take_profit_rr * risk;

   req.type = QM_BUY_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = "ict_golden_bullet_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 3600;
   g_long_ordered = true;
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
   if(strategy_signal_tf != PERIOD_M5)
      return true;
   if(strategy_max_stop_atr_mult <= 0.0 || strategy_take_profit_rr <= 0.0)
      return true;
   if(Bars(_Symbol, strategy_signal_tf) < 320)
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

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_entry_bar)
      return false;
   g_last_entry_bar = bar_time;

   if(Strategy_IsCancelWindow(TimeCurrent()))
      Strategy_DeleteOurPendingLimits("ny_pm_window_closed");
   if(!Strategy_IsPMWindow(bar_time))
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_HasOurPendingLimit())
      return false;
   if(!Strategy_PrepareReferenceRange(bar_time))
      return false;
   if(!Strategy_SessionRangeOk())
      return false;
   if(!Strategy_QualityFiltersOk())
      return false;

   Strategy_UpdateSweepState();

   if(Strategy_BuildShortLimit(req))
      return true;
   if(Strategy_BuildLongLimit(req))
      return true;

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_IsCancelWindow(TimeCurrent()))
      Strategy_DeleteOurPendingLimits("ny_pm_window_closed");

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!Strategy_OurPendingLimitType(type))
         continue;

      const double sl = OrderGetDouble(ORDER_SL);
      if((type == ORDER_TYPE_BUY_LIMIT && close_1 < sl) ||
         (type == ORDER_TYPE_SELL_LIMIT && close_1 > sl))
         Strategy_DeletePendingOrder(ticket, "closed_beyond_stop_side");
     }
  }

bool Strategy_ExitSignal()
  {
   return Strategy_IsTimeExitWindow(TimeCurrent());
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
