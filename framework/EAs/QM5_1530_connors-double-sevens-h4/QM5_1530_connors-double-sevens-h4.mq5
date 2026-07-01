#property strict
#property version   "5.0"
#property description "QM5_1530 Connors Double-7s H4 mean reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1530;
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
input int    strategy_extreme_bars          = 7;
input int    strategy_regime_sma_period     = 200;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 3.0;
input int    strategy_time_stop_bars        = 14;
input double strategy_spread_atr_fraction   = 0.40;
input bool   strategy_allow_shorts          = true;

bool Strategy_ReadClose(const ENUM_TIMEFRAMES tf, const int shift, double &value)
  {
   value = 0.0;
   if(shift < 0)
      return false;

   double buf[];
   ArraySetAsSeries(buf, true);
   const int got = CopyClose(_Symbol, tf, shift, 1, buf); // perf-allowed: single closed-bar close read behind the framework bar gate.
   if(got != 1 || buf[0] <= 0.0)
      return false;

   value = buf[0];
   return true;
  }

bool Strategy_HighestClose(const ENUM_TIMEFRAMES tf,
                           const int start_shift,
                           const int bars,
                           double &value)
  {
   value = 0.0;
   if(start_shift < 0 || bars <= 0)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int got = CopyClose(_Symbol, tf, start_shift, bars, closes); // perf-allowed: bounded 7-bar close window for Double-7s primitive.
   if(got != bars)
      return false;

   double highest = -DBL_MAX;
   for(int i = 0; i < bars; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      if(closes[i] > highest)
         highest = closes[i];
     }

   if(highest <= 0.0)
      return false;
   value = highest;
   return true;
  }

bool Strategy_LowestClose(const ENUM_TIMEFRAMES tf,
                          const int start_shift,
                          const int bars,
                          double &value)
  {
   value = 0.0;
   if(start_shift < 0 || bars <= 0)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int got = CopyClose(_Symbol, tf, start_shift, bars, closes); // perf-allowed: bounded 7-bar close window for Double-7s primitive.
   if(got != bars)
      return false;

   double lowest = DBL_MAX;
   for(int i = 0; i < bars; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      if(closes[i] < lowest)
         lowest = closes[i];
     }

   if(lowest <= 0.0 || lowest == DBL_MAX)
      return false;
   value = lowest;
   return true;
  }

bool Strategy_IsLongExtreme(const int signal_shift)
  {
   double close_signal = 0.0;
   double prior_low = 0.0;
   if(!Strategy_ReadClose((ENUM_TIMEFRAMES)_Period, signal_shift, close_signal))
      return false;
   if(!Strategy_LowestClose((ENUM_TIMEFRAMES)_Period, signal_shift + 1, strategy_extreme_bars, prior_low))
      return false;
   return (close_signal < prior_low);
  }

bool Strategy_IsShortExtreme(const int signal_shift)
  {
   double close_signal = 0.0;
   double prior_high = 0.0;
   if(!Strategy_ReadClose((ENUM_TIMEFRAMES)_Period, signal_shift, close_signal))
      return false;
   if(!Strategy_HighestClose((ENUM_TIMEFRAMES)_Period, signal_shift + 1, strategy_extreme_bars, prior_high))
      return false;
   return (close_signal > prior_high);
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at)
  {
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_SpreadOK(const double atr_value)
  {
   if(strategy_spread_atr_fraction <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ask > bid && atr_value > 0.0)
     {
      const double spread = ask - bid;
      const double cap = atr_value * strategy_spread_atr_fraction;
      if(cap > 0.0 && spread > cap)
         return false;
     }

   return true;
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

   if(strategy_extreme_bars < 2 ||
      strategy_regime_sma_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_time_stop_bars <= 0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double close1 = 0.0;
   if(!Strategy_ReadClose((ENUM_TIMEFRAMES)_Period, 1, close1))
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(regime_sma <= 0.0 || atr <= 0.0)
      return false;
   if(!Strategy_SpreadOK(atr))
      return false;

   const bool fresh_long_extreme = Strategy_IsLongExtreme(1) && !Strategy_IsLongExtreme(2);
   const bool fresh_short_extreme = Strategy_IsShortExtreme(1) && !Strategy_IsShortExtreme(2);

   QM_OrderType side = QM_BUY;
   bool has_signal = false;
   if(close1 > regime_sma && fresh_long_extreme)
     {
      side = QM_BUY;
      has_signal = true;
     }
   else if(strategy_allow_shorts && close1 < regime_sma && fresh_short_extreme)
     {
      side = QM_SELL;
      has_signal = true;
     }

   if(!has_signal)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = (side == QM_BUY) ? "CONNORS_D7_LONG" : "CONNORS_D7_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial exits.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at = 0;
   if(!Strategy_GetOurPosition(ptype, opened_at))
      return false;

   if(ptype == POSITION_TYPE_BUY && Strategy_IsShortExtreme(1))
      return true;
   if(ptype == POSITION_TYPE_SELL && Strategy_IsLongExtreme(1))
      return true;

   if(strategy_time_stop_bars > 0 && opened_at > 0)
     {
      const int open_shift = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, opened_at, false); // perf-allowed: one position age lookup for fixed H4 time stop.
      if(open_shift >= strategy_time_stop_bars)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_1530_connors_double_sevens_h4\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
