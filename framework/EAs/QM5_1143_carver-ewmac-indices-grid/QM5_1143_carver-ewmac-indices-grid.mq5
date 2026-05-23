#property strict
#property version   "5.0"
#property description "QM5_1143 Carver EWMAC Indices Grid"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1143;
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
input int    strategy_fast_ema_period       = 16;
input int    strategy_slow_ema_period       = 64;
input int    strategy_vol_lookback_bars     = 25;
input int    strategy_rebalance_period_bars = 5;
input double strategy_signal_threshold_min  = 0.5;
input double strategy_signal_threshold_max  = 2.0;
input double strategy_target_vol_pct        = 0.20;
input int    strategy_atr_period            = 14;
input double strategy_atr_stop_mult         = 4.0;
input bool   strategy_long_only             = false;
input bool   strategy_regime_filter         = false;
input int    strategy_regime_sma_period     = 200;
input int    strategy_max_spread_points     = 30;

const int STRATEGY_SYMBOL_COUNT = 5;
string g_strategy_symbols[5] =
  {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "SP500.DWX"
  };

int      g_last_rebalance_bars = -1;
datetime g_last_entry_bar_time = 0;

bool Strategy_IsRegisteredSymbol()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return true;
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_IsRegisteredSymbol())
      return true;
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }
   return false;
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

bool Strategy_CloseOpenPositions()
  {
   bool ok = true;
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
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         ok = false;
     }
   return ok;
  }

double Strategy_RealizedVolPct()
  {
   const int lookback = MathMax(5, strategy_vol_lookback_bars);
   const int need = lookback + 1;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, need, closes); // perf-allowed: D1 CopyClose runs only after QM_IsNewBar(PERIOD_D1).
   if(copied < need)
      return 0.0;

   double sum = 0.0;
   double sum_sq = 0.0;
   int count = 0;
   for(int i = 0; i < lookback; ++i)
     {
      if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
         return 0.0;
      const double r = MathLog(closes[i] / closes[i + 1]);
      sum += r;
      sum_sq += r * r;
      ++count;
     }

   if(count < 2)
      return 0.0;
   const double mean = sum / (double)count;
   const double variance = MathMax(0.0, (sum_sq / (double)count) - mean * mean);
   return MathSqrt(variance);
  }

double Strategy_EwmacSignal()
  {
   const int fast = MathMax(2, strategy_fast_ema_period);
   const int slow = MathMax(fast * 2, strategy_slow_ema_period);
   const int vol_lookback = MathMax(5, strategy_vol_lookback_bars);

   const double fast_ema = QM_EMA(_Symbol, PERIOD_D1, fast, 1);
   const double slow_ema = QM_EMA(_Symbol, PERIOD_D1, slow, 1);
   const double close_value = iClose(_Symbol, PERIOD_D1, 1);
   const double daily_vol_pct = Strategy_RealizedVolPct();
   if(fast_ema <= 0.0 || slow_ema <= 0.0 || close_value <= 0.0 || daily_vol_pct <= 0.0)
      return 0.0;

   double signal = (fast_ema - slow_ema) / (close_value * daily_vol_pct);
   const double cap_value = MathAbs(strategy_signal_threshold_max);
   if(cap_value > 0.0)
      signal = MathMax(-cap_value, MathMin(cap_value, signal));
   return signal;
  }

int Strategy_TargetDirection(const double signal)
  {
   const double threshold = MathMax(0.0, strategy_signal_threshold_min);
   if(MathAbs(signal) < threshold)
      return 0;

   int direction = (signal > 0.0) ? 1 : -1;
   if(strategy_long_only && direction < 0)
      return 0;

   if(strategy_regime_filter)
     {
      const int sma_period = MathMax(20, strategy_regime_sma_period);
      const double close_value = iClose(_Symbol, PERIOD_D1, 1);
      const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, sma_period, 1);
      if(close_value <= 0.0 || regime_sma <= 0.0)
         return 0;
      if(direction > 0 && close_value < regime_sma)
         return 0;
      if(direction < 0 && close_value > regime_sma)
         return 0;
     }

   return direction;
  }

bool Strategy_RebalanceDue()
  {
   const int current_bars = iBars(_Symbol, PERIOD_D1);
   if(current_bars <= 0)
      return false;
   const int period = MathMax(1, strategy_rebalance_period_bars);
   if(g_last_rebalance_bars < 0)
     {
      g_last_rebalance_bars = current_bars;
      return true;
     }
   if(current_bars - g_last_rebalance_bars < period)
      return false;

   g_last_rebalance_bars = current_bars;
   return true;
  }

bool Strategy_OpenTargetPosition(const int direction, const double signal)
  {
   if(direction == 0)
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 1);
   if(bar_time <= 0 || bar_time == g_last_entry_bar_time)
      return false;

   QM_EntryRequest req;
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "QM5_1143_EWMAC_LONG" : "QM5_1143_EWMAC_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.price <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   double vol_scale = 1.0;
   const double annualized_vol = Strategy_RealizedVolPct() * MathSqrt(252.0);
   if(annualized_vol > 0.0 && strategy_target_vol_pct > 0.0)
      vol_scale = MathMax(0.50, MathMin(1.50, annualized_vol / strategy_target_vol_pct));

   const double stop_mult = strategy_atr_stop_mult * vol_scale;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, stop_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= req.price)
      return false;
   if(req.type == QM_SELL && req.sl <= req.price)
      return false;

   req.reason = StringFormat("%s signal=%.4f vol_scale=%.4f", req.reason, signal, vol_scale);
   g_last_entry_bar_time = bar_time;

   ulong out_ticket = 0;
   return QM_TM_OpenPosition(req, out_ticket);
  }

void Strategy_Rebalance()
  {
   const double signal = Strategy_EwmacSignal();
   const int target_direction = Strategy_TargetDirection(signal);
   const int current_direction = Strategy_OpenPositionDirection();

   // EWMAC is a weekly rebalanced forecast, not a fire-and-forget entry.
   // Closing/reopening on each rebalance approximates signal/vol rescaling
   // within the fixed-risk V5 entry interface.
   if(current_direction != 0)
     {
      if(!Strategy_CloseOpenPositions())
         return;
     }

   if(target_direction != 0)
      Strategy_OpenTargetPosition(target_direction, signal);
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

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_strategy_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1143\",\"ea\":\"carver-ewmac-indices-grid\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   if(!Strategy_RebalanceDue())
      return;

   Strategy_Rebalance();
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
