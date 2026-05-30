#property strict
#property version   "5.0"
#property description "QM5_1250 Carver very slow absolute mean reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1250;
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
input int    strategy_lookback_days      = 1000;
input int    strategy_vol_ewma_days      = 25;
input double strategy_entry_z            = 1.5;
input double strategy_exit_z             = 0.25;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_time_stop_days     = 180;
input int    strategy_extra_warmup_days  = 250;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 2.0;

#define QM5_1250_SYMBOL_COUNT 12

string g_symbols[QM5_1250_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX",
   "USDCAD.DWX", "NZDUSD.DWX", "XAUUSD.DWX", "XTIUSD.DWX",
   "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"
  };

int g_slots[QM5_1250_SYMBOL_COUNT] =
  {
   0, 1, 2, 3,
   4, 5, 6, 7,
   8, 9, 10, 11
  };

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar  = 0;
datetime g_last_exit_check_bar = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1250_SYMBOL_COUNT; ++i)
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
   if(strategy_time_stop_days <= 0)
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
      if(open_time <= 0)
         continue;
      const int open_shift = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(open_shift >= strategy_time_stop_days)
         return true;
     }
   return false;
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   ArrayResize(values, count);
   ArraySort(values);
   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

double Strategy_EwmaVolatility(const int shift)
  {
   const int period = MathMax(2, strategy_vol_ewma_days);
   if(iBars(_Symbol, PERIOD_D1) <= shift + period + 2)
      return 0.0;

   const double alpha = 2.0 / ((double)period + 1.0);
   double variance = 0.0;
   bool seeded = false;

   for(int i = shift + period - 1; i >= shift; --i)
     {
      const double c0 = iClose(_Symbol, PERIOD_D1, i);
      const double c1 = iClose(_Symbol, PERIOD_D1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double r = (c0 - c1) / c1;
      const double r2 = r * r;
      if(!seeded)
        {
         variance = r2;
         seeded = true;
        }
      else
         variance = alpha * r2 + (1.0 - alpha) * variance;
     }

   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

double Strategy_NormalizedReturn(const int shift)
  {
   const double c0 = iClose(_Symbol, PERIOD_D1, shift);
   const double c1 = iClose(_Symbol, PERIOD_D1, shift + 1);
   const double vol = Strategy_EwmaVolatility(shift);
   if(c0 <= 0.0 || c1 <= 0.0 || vol <= 0.0)
      return 0.0;

   const double value = ((c0 - c1) / c1) / vol;
   return MathMax(-8.0, MathMin(8.0, value));
  }

double Strategy_NormalizedPrice(const int shift)
  {
   const int lookback = MathMax(20, strategy_lookback_days);
   double sum = 0.0;
   for(int i = shift + lookback - 1; i >= shift; --i)
      sum += Strategy_NormalizedReturn(i);
   return sum;
  }

bool Strategy_ZScore(const int shift, double &z)
  {
   z = 0.0;
   const int lookback = MathMax(20, strategy_lookback_days);
   const int min_bars = lookback * 2 + MathMax(2, strategy_vol_ewma_days) + MathMax(0, strategy_extra_warmup_days) + shift + 5;
   if(iBars(_Symbol, PERIOD_D1) < min_bars)
      return false;

   double values[];
   ArrayResize(values, lookback);
   double sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double value = Strategy_NormalizedPrice(shift + i);
      values[i] = value;
      sum += value;
     }

   const double anchor = sum / (double)lookback;
   double var = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double d = values[i] - anchor;
      var += d * d;
     }
   var /= (double)MathMax(lookback - 1, 1);
   const double sd = MathSqrt(var);
   if(sd <= 0.0)
      return false;

   z = (values[0] - anchor) / sd;
   return true;
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
   return Strategy_Median(spreads, count);
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

bool Strategy_InvalidInputs()
  {
   if(qm_ea_id != 1250)
      return true;
   if(strategy_lookback_days < 20)
      return true;
   if(strategy_vol_ewma_days < 2)
      return true;
   if(strategy_entry_z <= 0.0 || strategy_exit_z < 0.0 || strategy_exit_z >= strategy_entry_z)
      return true;
   if(strategy_atr_period_d1 < 2 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "CARVER_SLOWABS_MR";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_entry_bar || signal_bar == g_last_exit_bar)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double z = 0.0;
   if(!Strategy_ZScore(1, z))
      return false;

   const bool long_signal = (z < -strategy_entry_z);
   const bool short_signal = (z > strategy_entry_z);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = NormalizeDouble(sl, _Digits);
   req.reason = long_signal ? "SLOWABS_MR_LONG" : "SLOWABS_MR_SHORT";
   g_last_entry_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_exit_bar || signal_bar == g_last_exit_check_bar)
      return false;
   g_last_exit_check_bar = signal_bar;

   if(Strategy_TimeStopHit())
     {
      g_last_exit_bar = signal_bar;
      return true;
     }

   const int direction = Strategy_OpenPositionDirection();
   if(direction == 0)
      return false;

   double z = 0.0;
   if(!Strategy_ZScore(1, z))
      return false;

   bool exit_now = false;
   if(direction > 0 && z >= -strategy_exit_z)
      exit_now = true;
   if(direction < 0 && z <= strategy_exit_z)
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
   if(Strategy_InvalidInputs())
      return INIT_FAILED;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1250\",\"ea\":\"carver-slowabs-mr\"}");
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
   if(QM_FrameworkFridayCloseNow(broker_now))
     {
      QM_FrameworkCloseAllByMagic(QM_FrameworkMagic(), "friday_close");
      return;
     }

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
