#property strict
#property version   "5.0"
#property description "QM5_1243 Carver leveraged EWMAC"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1243;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.083333;

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
input int    strategy_fast_ema           = 16;
input int    strategy_slow_ema           = 64;
input int    strategy_atr_period         = 25;
input int    strategy_sma_filter_period  = 100;
input double strategy_entry_forecast     = 1.0;
input double strategy_exit_forecast      = 0.0;
input double strategy_initial_stop_atr   = 3.0;
input double strategy_trail_atr_mult     = 1.0;
input double strategy_trail_trigger_r    = 1.5;
input int    strategy_max_hold_bars      = 160;
input int    strategy_min_history_bars   = 260;
input int    strategy_median_atr_days    = 252;
input double strategy_min_atr_ratio      = 0.50;
input int    strategy_spread_median_days = 60;
input double strategy_spread_mult        = 2.0;

#define QM5_1243_SYMBOL_COUNT 12

string g_symbols[QM5_1243_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX",
   "USDCAD.DWX", "NZDUSD.DWX", "XAUUSD.DWX", "XTIUSD.DWX",
   "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"
  };

int g_slots[QM5_1243_SYMBOL_COUNT] =
  {
   0, 1, 2, 3,
   4, 5, 6, 7,
   8, 9, 10, 11
  };

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1243_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double Strategy_MedianAtr()
  {
   const int lookback = MathMax(2, strategy_median_atr_days);
   double values[];
   ArrayResize(values, lookback);
   int count = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      values[count] = atr;
      ++count;
     }

   if(count <= 0)
      return 0.0;
   ArrayResize(values, count);
   ArraySort(values);
   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

double Strategy_MedianSpreadPoints()
  {
   const int lookback = MathMax(2, strategy_spread_median_days);
   double spreads[];
   ArrayResize(spreads, lookback);
   int count = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = (double)spread;
      ++count;
     }

   if(count <= 0)
      return 0.0;
   ArrayResize(spreads, count);
   ArraySort(spreads);
   if((count % 2) == 1)
      return spreads[count / 2];
   return 0.5 * (spreads[(count / 2) - 1] + spreads[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_mult <= 0.0)
      return true;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   const double median_spread = Strategy_MedianSpreadPoints();
   if(median_spread <= 0.0)
      return true;
   return ((double)current_spread <= strategy_spread_mult * median_spread);
  }

bool Strategy_ForecastAtShift(const int shift, double &out_forecast)
  {
   out_forecast = 0.0;
   const int fast = MathMax(2, strategy_fast_ema);
   const int slow = MathMax(fast + 1, strategy_slow_ema);
   const int atr_period = MathMax(2, strategy_atr_period);
   if(iBars(_Symbol, PERIOD_D1) < MathMax(strategy_min_history_bars, slow + atr_period + shift + 4))
      return false;

   const double fast_ema = QM_EMA(_Symbol, PERIOD_D1, fast, shift);
   const double slow_ema = QM_EMA(_Symbol, PERIOD_D1, slow, shift);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, atr_period, shift);
   if(fast_ema <= 0.0 || slow_ema <= 0.0 || atr <= 0.0)
      return false;

   out_forecast = (fast_ema - slow_ema) / atr;
   return true;
  }

bool Strategy_AtrRegimeAllowsEntry()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double median_atr = Strategy_MedianAtr();
   if(atr <= 0.0 || median_atr <= 0.0)
      return false;
   return (atr >= median_atr * strategy_min_atr_ratio);
  }

int Strategy_OpenPositionDirection()
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
         return 1;
      if(pos_type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

bool Strategy_TimeStopHit()
  {
   if(strategy_max_hold_bars <= 0)
      return false;

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
      const int open_shift = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(open_shift >= strategy_max_hold_bars)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(Strategy_SlotForCurrentSymbol() != qm_magic_slot_offset)
      return true;
   if(strategy_fast_ema < 2 || strategy_slow_ema <= strategy_fast_ema)
      return true;
   if(strategy_atr_period < 2 || strategy_sma_filter_period < 2)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_initial_stop_atr <= 0.0)
      return true;
   if(strategy_min_history_bars < strategy_slow_ema + strategy_atr_period)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "CARVER_EWMAC_LEV";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_entry_bar || signal_bar == g_last_exit_bar)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_AtrRegimeAllowsEntry() || !Strategy_SpreadAllowsEntry())
      return false;

   double forecast = 0.0;
   double prev_forecast = 0.0;
   if(!Strategy_ForecastAtShift(1, forecast) || !Strategy_ForecastAtShift(2, prev_forecast))
      return false;

   const double close_price = iClose(_Symbol, PERIOD_D1, 1);
   const double sma_filter = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_filter_period, 1);
   if(close_price <= 0.0 || sma_filter <= 0.0)
      return false;

   const bool long_signal = (forecast >= strategy_entry_forecast &&
                             prev_forecast < strategy_entry_forecast &&
                             close_price > sma_filter);
   const bool short_signal = (forecast <= -strategy_entry_forecast &&
                              prev_forecast > -strategy_entry_forecast &&
                              close_price < sma_filter);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_initial_stop_atr);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = NormalizeDouble(sl, _Digits);
   req.reason = long_signal ? "EWMAC_LEV_LONG" : "EWMAC_LEV_SHORT";
   g_last_entry_bar = signal_bar;
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_sl <= 0.0 || current_price <= 0.0)
         continue;

      const double initial_r = MathAbs(open_price - current_sl);
      if(initial_r <= 0.0)
         continue;
      const double gained = is_buy ? (current_price - open_price) : (open_price - current_price);
      if(gained < strategy_trail_trigger_r * initial_r)
         continue;

      const double slow_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_slow_ema, 1);
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(slow_ema <= 0.0 || atr <= 0.0)
         continue;

      const double target_sl = is_buy ? (slow_ema - strategy_trail_atr_mult * atr)
                                      : (slow_ema + strategy_trail_atr_mult * atr);
      if(is_buy && target_sl > current_sl && target_sl < current_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(target_sl, _Digits), "ewmac_slowema_atr_trail");
      if(!is_buy && target_sl < current_sl && target_sl > current_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(target_sl, _Digits), "ewmac_slowema_atr_trail");
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_exit_bar)
      return false;

   if(Strategy_TimeStopHit())
     {
      g_last_exit_bar = signal_bar;
      return true;
     }

   const int direction = Strategy_OpenPositionDirection();
   if(direction == 0)
      return false;

   double forecast = 0.0;
   if(!Strategy_ForecastAtShift(1, forecast))
      return false;

   const double close_price = iClose(_Symbol, PERIOD_D1, 1);
   const double slow_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_slow_ema, 1);
   if(close_price <= 0.0 || slow_ema <= 0.0)
      return false;

   bool exit_now = false;
   if(direction > 0 && (forecast <= strategy_exit_forecast || close_price < slow_ema))
      exit_now = true;
   if(direction < 0 && (forecast >= -strategy_exit_forecast || close_price > slow_ema))
      exit_now = true;

   if(exit_now)
      g_last_exit_bar = signal_bar;
   return exit_now;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1243\",\"ea\":\"carver-ewmac-lev\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
