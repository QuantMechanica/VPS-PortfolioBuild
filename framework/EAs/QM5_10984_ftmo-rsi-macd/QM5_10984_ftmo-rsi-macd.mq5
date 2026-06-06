#property strict
#property version   "5.0"
#property description "QM5_10984 FTMO RSI MACD synchronized reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10984;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_period          = 14;
input double strategy_rsi_oversold        = 30.0;
input double strategy_rsi_overbought      = 70.0;
input int    strategy_rsi_sequence_bars   = 3;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_confirm_bars        = 2;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_buffer       = 0.25;
input double strategy_min_sl_atr          = 0.80;
input double strategy_max_sl_atr          = 2.50;
input double strategy_tp_r_multiple       = 2.0;
input int    strategy_max_hold_bars       = 36;
input int    strategy_atr_percentile_bars = 250;
input double strategy_min_atr_percentile  = 20.0;
input int    strategy_spread_median_bars  = 20;
input double strategy_spread_median_mult  = 1.5;

double BarOpen(const int shift)
  {
   return iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed: H1 midpoint check on one closed bar.
  }

double BarHigh(const int shift)
  {
   return iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded H1 structural stop sequence.
  }

double BarLow(const int shift)
  {
   return iLow(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded H1 structural stop sequence.
  }

double BarClose(const int shift)
  {
   return iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: H1 midpoint check on one closed bar.
  }

bool MacdCrossUp(const int shift)
  {
   const double main_now = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double sig_now  = QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double main_old = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   const double sig_old  = QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   return (main_old <= sig_old && main_now > sig_now);
  }

bool MacdCrossDown(const int shift)
  {
   const double main_now = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double sig_now  = QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double main_old = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   const double sig_old  = QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   return (main_old >= sig_old && main_now < sig_now);
  }

bool RsiRecoveredUp(const int shift)
  {
   const double rsi_now = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift);
   const double rsi_old = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift + 1);
   if(!(rsi_old < strategy_rsi_oversold && rsi_now > strategy_rsi_oversold))
      return false;

   for(int i = shift + 1; i <= shift + strategy_rsi_sequence_bars; ++i)
     {
      if(QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, i) < strategy_rsi_oversold)
         return true;
     }
   return false;
  }

bool RsiRecoveredDown(const int shift)
  {
   const double rsi_now = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift);
   const double rsi_old = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift + 1);
   if(!(rsi_old > strategy_rsi_overbought && rsi_now < strategy_rsi_overbought))
      return false;

   for(int i = shift + 1; i <= shift + strategy_rsi_sequence_bars; ++i)
     {
      if(QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, i) > strategy_rsi_overbought)
         return true;
     }
   return false;
  }

int RecentRsiRecoveryShift(const bool long_side)
  {
   const int max_shift = MathMax(1, strategy_confirm_bars + 1);
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      if(long_side && RsiRecoveredUp(shift))
         return shift;
      if(!long_side && RsiRecoveredDown(shift))
         return shift;
     }
   return 0;
  }

bool EntryCandleMidpointOk(const bool long_side)
  {
   const double open1 = BarOpen(1);
   const double high1 = BarHigh(1);
   const double low1 = BarLow(1);
   const double close1 = BarClose(1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || high1 <= low1)
      return false;

   const double midpoint = (high1 + low1) * 0.5;
   if(long_side)
      return (close1 > midpoint);
   return (close1 < midpoint);
  }

double SequenceLow(const int recovery_shift)
  {
   double low = DBL_MAX;
   for(int i = recovery_shift; i <= recovery_shift + strategy_rsi_sequence_bars; ++i)
     {
      const double bar_low = BarLow(i);
      if(bar_low > 0.0)
         low = MathMin(low, bar_low);
     }
   return (low == DBL_MAX) ? 0.0 : low;
  }

double SequenceHigh(const int recovery_shift)
  {
   double high = 0.0;
   for(int i = recovery_shift; i <= recovery_shift + strategy_rsi_sequence_bars; ++i)
     {
      const double bar_high = BarHigh(i);
      if(bar_high > 0.0)
         high = MathMax(high, bar_high);
     }
   return high;
  }

bool AtrPercentileAllows()
  {
   if(strategy_atr_percentile_bars <= 1)
      return true;

   double atr_values[];
   ArrayResize(atr_values, strategy_atr_percentile_bars);
   int count = 0;
   for(int shift = 1; shift <= strategy_atr_percentile_bars; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      atr_values[count] = atr;
      count++;
     }

   if(count < strategy_atr_percentile_bars)
      return false;

   ArrayResize(atr_values, count);
   ArraySort(atr_values);
   int idx = (int)MathFloor((count - 1) * strategy_min_atr_percentile / 100.0);
   idx = MathMax(0, MathMin(count - 1, idx));

   const double current_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   return (current_atr >= atr_values[idx]);
  }

bool SpreadAllows()
  {
   if(strategy_spread_median_bars <= 1 || strategy_spread_median_mult <= 0.0)
      return true;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, strategy_spread_median_bars, rates); // perf-allowed: closed-bar spread median filter.
   if(copied < strategy_spread_median_bars)
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   for(int i = 0; i < copied; ++i)
      spreads[i] = (double)rates[i].spread;

   ArraySort(spreads);
   const double median_spread = spreads[copied / 2];
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread <= 0.0 || current_spread < 0)
      return false;

   return ((double)current_spread <= strategy_spread_median_mult * median_spread);
  }

bool BuildRequest(const bool long_side, const int recovery_shift, QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const double entry = long_side ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   if(long_side)
     {
      const double seq_low = SequenceLow(recovery_shift);
      if(seq_low <= 0.0)
         return false;
      sl = seq_low - (strategy_sl_atr_buffer * atr);
      double distance = entry - sl;
      if(distance < strategy_min_sl_atr * atr)
        {
         distance = strategy_min_sl_atr * atr;
         sl = entry - distance;
        }
      if(distance > strategy_max_sl_atr * atr)
         return false;
      req.type = QM_BUY;
      req.tp = entry + (strategy_tp_r_multiple * distance);
     }
   else
     {
      const double seq_high = SequenceHigh(recovery_shift);
      if(seq_high <= 0.0)
         return false;
      sl = seq_high + (strategy_sl_atr_buffer * atr);
      double distance = sl - entry;
      if(distance < strategy_min_sl_atr * atr)
        {
         distance = strategy_min_sl_atr * atr;
         sl = entry + distance;
        }
      if(distance > strategy_max_sl_atr * atr)
         return false;
      req.type = QM_SELL;
      req.tp = entry - (strategy_tp_r_multiple * distance);
     }

   req.price = 0.0;
   req.sl = sl;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = long_side ? "FTMO_RSI_MACD_LONG" : "FTMO_RSI_MACD_SHORT";
   return (MathAbs(entry - req.sl) / point > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(_Period != PERIOD_H1)
      return false;
   if(strategy_rsi_period <= 1 || strategy_macd_fast <= 1 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 1 || strategy_atr_period <= 1)
      return false;
   if(!AtrPercentileAllows() || !SpreadAllows())
      return false;

   if(MacdCrossUp(1) && EntryCandleMidpointOk(true))
     {
      const int recovery_shift = RecentRsiRecoveryShift(true);
      if(recovery_shift > 0)
         return BuildRequest(true, recovery_shift, req);
     }

   if(MacdCrossDown(1) && EntryCandleMidpointOk(false))
     {
      const int recovery_shift = RecentRsiRecoveryShift(false);
      if(recovery_shift > 0)
         return BuildRequest(false, recovery_shift, req);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && MacdCrossDown(1))
         return true;
      if(ptype == POSITION_TYPE_SELL && MacdCrossUp(1))
         return true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && strategy_max_hold_bars > 0)
        {
         const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_H1);
         if(TimeCurrent() - opened >= hold_seconds)
            return true;
        }
     }
   return false;
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
