#property strict
#property version   "5.0"
#property description "QM5_10979 FTMO MACD swing divergence reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10979;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H4;
input int    strategy_macd_fast                   = 12;
input int    strategy_macd_slow                   = 26;
input int    strategy_macd_signal                 = 9;
input int    strategy_atr_period                  = 14;
input int    strategy_fractal_left                = 3;
input int    strategy_fractal_right               = 3;
input int    strategy_divergence_lookback         = 60;
input int    strategy_min_swing_separation_bars   = 8;
input int    strategy_confirmation_bars           = 5;
input double strategy_sl_atr_mult                 = 0.5;
input double strategy_max_stop_atr_mult           = 3.0;
input double strategy_take_profit_r               = 2.0;
input int    strategy_opposite_swing_lookback     = 20;
input int    strategy_max_hold_bars               = 40;

bool LoadClosedBarRates(MqlRates &rates[])
  {
   const int need = strategy_divergence_lookback +
                    strategy_fractal_left +
                    strategy_fractal_right +
                    strategy_confirmation_bars +
                    8;
   if(need <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, need, rates); // perf-allowed: bounded structural swing scan after framework QM_IsNewBar gate.
   return (copied >= need);
  }

bool IsSwingLow(const MqlRates &rates[], const int shift)
  {
   const int total = ArraySize(rates);
   if(shift - strategy_fractal_right < 1 ||
      shift + strategy_fractal_left >= total)
      return false;

   const double value = rates[shift].low;
   for(int i = 1; i <= strategy_fractal_left; ++i)
      if(value >= rates[shift + i].low)
         return false;
   for(int i = 1; i <= strategy_fractal_right; ++i)
      if(value >= rates[shift - i].low)
         return false;
   return true;
  }

bool IsSwingHigh(const MqlRates &rates[], const int shift)
  {
   const int total = ArraySize(rates);
   if(shift - strategy_fractal_right < 1 ||
      shift + strategy_fractal_left >= total)
      return false;

   const double value = rates[shift].high;
   for(int i = 1; i <= strategy_fractal_left; ++i)
      if(value <= rates[shift + i].high)
         return false;
   for(int i = 1; i <= strategy_fractal_right; ++i)
      if(value <= rates[shift - i].high)
         return false;
   return true;
  }

bool BullishMacdCrossAt(const int shift)
  {
   const double main_now = QM_MACD_Main(_Symbol, strategy_timeframe,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, shift);
   const double sig_now = QM_MACD_Signal(_Symbol, strategy_timeframe,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, shift);
   const double main_prev = QM_MACD_Main(_Symbol, strategy_timeframe,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, shift + 1);
   const double sig_prev = QM_MACD_Signal(_Symbol, strategy_timeframe,
                                          strategy_macd_fast, strategy_macd_slow,
                                          strategy_macd_signal, shift + 1);
   return (main_now > sig_now && main_prev <= sig_prev);
  }

bool BearishMacdCrossAt(const int shift)
  {
   const double main_now = QM_MACD_Main(_Symbol, strategy_timeframe,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, shift);
   const double sig_now = QM_MACD_Signal(_Symbol, strategy_timeframe,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, shift);
   const double main_prev = QM_MACD_Main(_Symbol, strategy_timeframe,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, shift + 1);
   const double sig_prev = QM_MACD_Signal(_Symbol, strategy_timeframe,
                                          strategy_macd_fast, strategy_macd_slow,
                                          strategy_macd_signal, shift + 1);
   return (main_now < sig_now && main_prev >= sig_prev);
  }

bool FindBullishDivergence(const MqlRates &rates[], int &newer_shift)
  {
   newer_shift = -1;
   if(!BullishMacdCrossAt(1))
      return false;

   const int first_shift = strategy_fractal_right + 1;
   const int last_shift = MathMin(strategy_divergence_lookback,
                                  ArraySize(rates) - strategy_fractal_left - 1);
   const int max_recent_shift = strategy_confirmation_bars + 1;

   for(int newer = first_shift; newer <= MathMin(last_shift, max_recent_shift); ++newer)
     {
      if(!IsSwingLow(rates, newer))
         continue;

      for(int prior = newer + strategy_min_swing_separation_bars; prior <= last_shift; ++prior)
        {
         if(!IsSwingLow(rates, prior))
            continue;

         const double newer_macd = QM_MACD_Main(_Symbol, strategy_timeframe,
                                                strategy_macd_fast, strategy_macd_slow,
                                                strategy_macd_signal, newer);
         const double prior_macd = QM_MACD_Main(_Symbol, strategy_timeframe,
                                                strategy_macd_fast, strategy_macd_slow,
                                                strategy_macd_signal, prior);
         if(rates[newer].low < rates[prior].low && newer_macd > prior_macd)
           {
            newer_shift = newer;
            return true;
           }
         break;
        }
     }
   return false;
  }

bool FindBearishDivergence(const MqlRates &rates[], int &newer_shift)
  {
   newer_shift = -1;
   if(!BearishMacdCrossAt(1))
      return false;

   const int first_shift = strategy_fractal_right + 1;
   const int last_shift = MathMin(strategy_divergence_lookback,
                                  ArraySize(rates) - strategy_fractal_left - 1);
   const int max_recent_shift = strategy_confirmation_bars + 1;

   for(int newer = first_shift; newer <= MathMin(last_shift, max_recent_shift); ++newer)
     {
      if(!IsSwingHigh(rates, newer))
         continue;

      for(int prior = newer + strategy_min_swing_separation_bars; prior <= last_shift; ++prior)
        {
         if(!IsSwingHigh(rates, prior))
            continue;

         const double newer_macd = QM_MACD_Main(_Symbol, strategy_timeframe,
                                                strategy_macd_fast, strategy_macd_slow,
                                                strategy_macd_signal, newer);
         const double prior_macd = QM_MACD_Main(_Symbol, strategy_timeframe,
                                                strategy_macd_fast, strategy_macd_slow,
                                                strategy_macd_signal, prior);
         if(rates[newer].high > rates[prior].high && newer_macd < prior_macd)
           {
            newer_shift = newer;
            return true;
           }
         break;
        }
     }
   return false;
  }

double NearestSwingHighAbove(const MqlRates &rates[], const double entry_price)
  {
   double best = 0.0;
   const int first_shift = strategy_fractal_right + 1;
   const int last_shift = MathMin(strategy_opposite_swing_lookback,
                                  ArraySize(rates) - strategy_fractal_left - 1);
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!IsSwingHigh(rates, shift))
         continue;
      const double level = rates[shift].high;
      if(level > entry_price && (best <= 0.0 || level < best))
         best = level;
     }
   return best;
  }

double NearestSwingLowBelow(const MqlRates &rates[], const double entry_price)
  {
   double best = 0.0;
   const int first_shift = strategy_fractal_right + 1;
   const int last_shift = MathMin(strategy_opposite_swing_lookback,
                                  ArraySize(rates) - strategy_fractal_left - 1);
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!IsSwingLow(rates, shift))
         continue;
      const double level = rates[shift].low;
      if(level < entry_price && (best <= 0.0 || level > best))
         best = level;
     }
   return best;
  }

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_timeframe != PERIOD_H4 ||
      strategy_fractal_left != 3 ||
      strategy_fractal_right != 3)
      return false;

   MqlRates rates[];
   if(!LoadClosedBarRates(rates))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   int swing_shift = -1;
   if(FindBullishDivergence(rates, swing_shift))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = rates[swing_shift].low - strategy_sl_atr_mult * atr;
      const double risk = entry - sl;
      if(entry <= 0.0 || sl <= 0.0 || risk <= 0.0 || risk > strategy_max_stop_atr_mult * atr)
         return false;

      double tp = entry + strategy_take_profit_r * risk;
      const double swing_tp = NearestSwingHighAbove(rates, entry);
      if(swing_tp > entry && swing_tp < tp)
         tp = swing_tp;

      req.type = QM_BUY;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "FTMO_MACD_DIV_LONG";
      return true;
     }

   if(FindBearishDivergence(rates, swing_shift))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = rates[swing_shift].high + strategy_sl_atr_mult * atr;
      const double risk = sl - entry;
      if(entry <= 0.0 || sl <= 0.0 || risk <= 0.0 || risk > strategy_max_stop_atr_mult * atr)
         return false;

      double tp = entry - strategy_take_profit_r * risk;
      const double swing_tp = NearestSwingLowBelow(rates, entry);
      if(swing_tp > 0.0 && swing_tp < entry && swing_tp > tp)
         tp = swing_tp;

      req.type = QM_SELL;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "FTMO_MACD_DIV_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const bool bearish_cross = BearishMacdCrossAt(1);
   const bool bullish_cross = BullishMacdCrossAt(1);
   const int tf_seconds = PeriodSeconds(strategy_timeframe);
   const int hold_seconds = (tf_seconds > 0 && strategy_max_hold_bars > 0)
                            ? strategy_max_hold_bars * tf_seconds
                            : 0;

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
      if(type == POSITION_TYPE_BUY && bearish_cross)
         return true;
      if(type == POSITION_TYPE_SELL && bullish_cross)
         return true;

      if(hold_seconds > 0)
        {
         const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened_at > 0 && TimeCurrent() - opened_at >= hold_seconds)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10979_ftmo-macd-div\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
