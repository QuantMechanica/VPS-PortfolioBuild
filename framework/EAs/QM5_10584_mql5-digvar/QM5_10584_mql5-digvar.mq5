#property strict
#property version   "5.0"
#property description "QM5_10584 DigVariation H8 direction-reversal EA"

#include <QM/QM_Common.mqh>

// Source mechanic:
//   Nikolay Kositsin, Exp_DigVariation, MQL5 CodeBase 13554.
//   MQL5 CodeBase path: /en/code/13554
// The source EA uses DigVariation with H8, SMA(12), digital smooth power 1,
// and trades a reversal in the oscillator's closed-bar direction.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10584;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf  = PERIOD_H8;
input int    strategy_dig_period          = 12;
input int    strategy_dig_smooth_power    = 1;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.0;
input double strategy_tp_r_mult           = 1.5;
input double strategy_max_spread_points   = 250.0;

int g_signal_direction = 0;

double Strategy_CloseAtShift(const double &closes[],
                             const int copied,
                             const int shift)
  {
   const int index = copied - shift;
   if(index < 0 || index >= copied)
      return 0.0;
   return closes[index];
  }

bool Strategy_DigValues(double &dig_shift_1,
                        double &dig_shift_2,
                        double &dig_shift_3)
  {
   if(strategy_dig_period < 2 ||
      (strategy_dig_smooth_power != 0 && strategy_dig_smooth_power != 1))
      return false;

   // SmoothPower=1 is the source default. Its FIR needs 20 raw variation
   // values. SmoothPower=0 is retained only as the source's no-smoothing
   // baseline.
   const int taps = (strategy_dig_smooth_power == 0) ? 1 : 20;
   const int max_calc_shift = 3 + taps - 1;
   const int max_ma_shift = max_calc_shift + strategy_dig_period - 1;
   const int close_count = max_ma_shift + strategy_dig_period - 1;

   double closes[];
   ArrayResize(closes, close_count);
   ArraySetAsSeries(closes, false);
   const int copied = CopyClose(_Symbol, strategy_signal_tf, 1, close_count, closes); // perf-allowed: bounded closed-bar read behind one H8 QM_IsNewBar gate.
   if(copied != close_count)
      return false;

   double price_ma[];
   double deviations[];
   ArrayResize(price_ma, max_ma_shift + 1);
   ArrayResize(deviations, max_ma_shift + 1);
   ArrayInitialize(price_ma, 0.0);
   ArrayInitialize(deviations, 0.0);

   for(int shift = 1; shift <= max_ma_shift; ++shift)
     {
      double sum = 0.0;
      for(int j = 0; j < strategy_dig_period; ++j)
        {
         const double value = Strategy_CloseAtShift(closes, copied, shift + j);
         if(value <= 0.0 || !MathIsValidNumber(value))
            return false;
         sum += value;
        }
      price_ma[shift] = sum / (double)strategy_dig_period;
      deviations[shift] =
         Strategy_CloseAtShift(closes, copied, shift) - price_ma[shift];
     }

   double raw_variation[];
   ArrayResize(raw_variation, max_calc_shift + 1);
   ArrayInitialize(raw_variation, 0.0);
   for(int shift = 1; shift <= max_calc_shift; ++shift)
     {
      double deviation_sum = 0.0;
      for(int j = 0; j < strategy_dig_period; ++j)
         deviation_sum += deviations[shift + j];

      const double variation_ma =
         deviation_sum / (double)strategy_dig_period;
      raw_variation[shift] =
         1000.0 *
         (Strategy_CloseAtShift(closes, copied, shift) -
          (price_ma[shift] + variation_ma));
     }

   double values[3];
   ArrayInitialize(values, 0.0);
   if(strategy_dig_smooth_power == 0)
     {
      values[0] = raw_variation[1];
      values[1] = raw_variation[2];
      values[2] = raw_variation[3];
     }
   else
     {
      const double coefficients[20] =
        {
         0.2926875484300,
         0.2698679548204,
         0.2277786802786,
         0.1726588586020,
         0.1124127695806,
         0.0550645669333,
         0.00733791069745,
        -0.02637426808863,
        -0.0445334647733,
        -0.0483673837716,
        -0.0412219004631,
        -0.02759007317598,
        -0.01206738017651,
         0.001567315986223,
         0.01094916192054,
         0.01530469318242,
         0.01532526278128,
         0.01296015381098,
         0.01157140552294,
        -0.00533181209765
        };

      for(int target_shift = 1; target_shift <= 3; ++target_shift)
        {
         double filtered = 0.0;
         for(int tap = 0; tap < taps; ++tap)
            filtered += coefficients[tap] *
                        raw_variation[target_shift + tap];
         values[target_shift - 1] = filtered;
        }
     }

   if(!MathIsValidNumber(values[0]) ||
      !MathIsValidNumber(values[1]) ||
      !MathIsValidNumber(values[2]))
      return false;

   dig_shift_1 = values[0];
   dig_shift_2 = values[1];
   dig_shift_3 = values[2];
   return true;
  }

int Strategy_DirectionChange()
  {
   double dig1 = 0.0;
   double dig2 = 0.0;
   double dig3 = 0.0;
   if(!Strategy_DigValues(dig1, dig2, dig3))
      return 0;

   // Source CopyBuffer ordering is [shift 3, shift 2, shift 1]. A trough at
   // shift 2 is a bullish reversal; a peak at shift 2 is bearish.
   if(dig3 > dig2 && dig1 > dig2)
      return 1;
   if(dig3 < dig2 && dig1 < dig2)
      return -1;
   return 0;
  }

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

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
      return true;
   if(strategy_max_spread_points > 0.0 &&
      (ask - bid) / _Point > strategy_max_spread_points)
      return true;

   const double atr =
      QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   return (atr <= 0.0 || !MathIsValidNumber(atr));
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_signal_direction == 0 || Strategy_HasOpenPosition())
      return false;
   if(strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_tp_r_mult <= 0.0)
      return false;

   const QM_OrderType side =
      (g_signal_direction > 0) ? QM_BUY : QM_SELL;
   const double entry =
      (g_signal_direction > 0)
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr =
      QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double sl =
      QM_StopATRFromValue(_Symbol,
                          side,
                          entry,
                          atr,
                          strategy_atr_sl_mult);
   if(sl <= 0.0 ||
      (g_signal_direction > 0 && sl >= entry) ||
      (g_signal_direction < 0 && sl <= entry))
      return false;

   const double risk = MathAbs(entry - sl);
   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = (g_signal_direction > 0)
            ? entry + risk * strategy_tp_r_mult
            : entry - risk * strategy_tp_r_mult;
   req.reason = "DIGVAR_REV";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(g_signal_direction == 0)
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

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && g_signal_direction < 0)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_signal_direction > 0)
         return true;
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
   QM_LogEvent(QM_INFO,
               "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();

   const bool is_signal_bar =
      QM_IsNewBar(_Symbol, strategy_signal_tf);
   g_signal_direction = 0;
   if(is_signal_bar)
      g_signal_direction = Strategy_DirectionChange();

   if(is_signal_bar && Strategy_ExitSignal())
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

   if(!is_signal_bar)
      return;

   QM_EquityStreamOnNewBar();
   if(g_signal_direction == 0)
      return;

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows =
         QM_NewsAllowsTrade2(_Symbol,
                             broker_now,
                             qm_news_temporal,
                             qm_news_compliance);
   else
      news_allows =
         QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || Strategy_NoTradeFilter())
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
