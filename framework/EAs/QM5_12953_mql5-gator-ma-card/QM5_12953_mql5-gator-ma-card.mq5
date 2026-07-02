#property strict
#property version   "5.0"
#property description "QM5_12953 MQL5 Gator MA Phase Signal"

// Strategy Card: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (mql5-gator-ma-card), G0 APPROVED 2026-05-19.
// Source: Mohamed Abdelmaaboud, MQL5 Articles, "Learn how to design a trading system by Gator Oscillator".

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12953;
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
input int    strategy_jaw_period        = 13;
input int    strategy_jaw_shift         = 8;
input int    strategy_teeth_period      = 8;
input int    strategy_teeth_shift       = 5;
input int    strategy_lips_period       = 5;
input int    strategy_lips_shift        = 3;
input int    strategy_ma_period         = 50;
input int    strategy_ma_slope_bars     = 5;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.7;
input double strategy_rr_take_profit    = 2.1;
input int    strategy_max_hold_bars     = 48;
input int    strategy_spread_cap_points = 1000;

// =============================================================================
// Strategy helpers
// =============================================================================

bool Strategy_ReadClosedBars(MqlRates &rates[], const int count)
  {
   if(count < 2)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, count, rates); // perf-allowed: bounded closed-bar OHLC read for the card's close-vs-SMA rule.
   return (copied >= count);
  }

double Strategy_GatorUpperValue(const int shift)
  {
   const double jaw = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_jaw_period,
                              shift + strategy_jaw_shift, PRICE_MEDIAN);
   const double teeth = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_teeth_period,
                                shift + strategy_teeth_shift, PRICE_MEDIAN);
   if(jaw <= 0.0 || teeth <= 0.0)
      return 0.0;
   return MathAbs(jaw - teeth);
  }

double Strategy_GatorLowerValue(const int shift)
  {
   const double teeth = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_teeth_period,
                                shift + strategy_teeth_shift, PRICE_MEDIAN);
   const double lips = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_lips_period,
                               shift + strategy_lips_shift, PRICE_MEDIAN);
   if(teeth <= 0.0 || lips <= 0.0)
      return 0.0;
   return -MathAbs(teeth - lips);
  }

bool Strategy_GatorUpperRising(const int shift)
  {
   const double curr = Strategy_GatorUpperValue(shift);
   const double prev = Strategy_GatorUpperValue(shift + 1);
   if(curr <= 0.0 || prev <= 0.0)
      return false;
   return (curr > prev);
  }

bool Strategy_GatorUpperFalling(const int shift)
  {
   const double curr = Strategy_GatorUpperValue(shift);
   const double prev = Strategy_GatorUpperValue(shift + 1);
   if(curr <= 0.0 || prev <= 0.0)
      return false;
   return (curr < prev);
  }

bool Strategy_GatorLowerRising(const int shift)
  {
   const double curr = Strategy_GatorLowerValue(shift);
   const double prev = Strategy_GatorLowerValue(shift + 1);
   if(curr == 0.0 || prev == 0.0)
      return false;
   return (curr > prev);
  }

bool Strategy_GatorLowerFalling(const int shift)
  {
   const double curr = Strategy_GatorLowerValue(shift);
   const double prev = Strategy_GatorLowerValue(shift + 1);
   if(curr == 0.0 || prev == 0.0)
      return false;
   return (curr < prev);
  }

int Strategy_MASlopeDirection()
  {
   if(strategy_ma_period <= 0 || strategy_ma_slope_bars <= 0)
      return 0;

   const double ma_recent = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 1, PRICE_CLOSE);
   const double ma_prior = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period,
                                  1 + strategy_ma_slope_bars, PRICE_CLOSE);
   if(ma_recent <= 0.0 || ma_prior <= 0.0)
      return 0;
   if(ma_recent > ma_prior)
      return 1;
   if(ma_recent < ma_prior)
      return -1;
   return 0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_GetPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void Strategy_ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   if(strategy_spread_cap_points <= 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_spread_cap_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetEntryRequest(req);

   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_rr_take_profit <= 0.0)
      return false;

   MqlRates rates[];
   if(!Strategy_ReadClosedBars(rates, 2))
      return false;

   const double close1 = rates[1].close;
   const double ma1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || ma1 <= 0.0)
      return false;

   const int ma_slope = Strategy_MASlopeDirection();
   const bool long_signal = Strategy_GatorUpperRising(1) &&
                            Strategy_GatorLowerFalling(1) &&
                            close1 > ma1 &&
                            ma_slope > 0;
   const bool short_signal = Strategy_GatorUpperFalling(1) &&
                             Strategy_GatorLowerRising(1) &&
                             close1 < ma1 &&
                             ma_slope < 0;
   if(!long_signal && !short_signal)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const bool go_long = long_signal;
   const double entry_price = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.type = go_long ? QM_BUY : QM_SELL;
   const double raw_stop = go_long ? (entry_price - strategy_atr_sl_mult * atr)
                                   : (entry_price + strategy_atr_sl_mult * atr);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, raw_stop);
   if(req.sl <= 0.0)
      return false;
   if(go_long && req.sl >= entry_price)
      return false;
   if(!go_long && req.sl <= entry_price)
      return false;

   req.tp = QM_TakeRR(_Symbol, req.type, entry_price, req.sl, strategy_rr_take_profit);
   if(go_long && req.tp <= entry_price)
      return false;
   if(!go_long && (req.tp <= 0.0 || req.tp >= entry_price))
      return false;

   req.price = 0.0;
   req.reason = go_long ? "GATOR_MA_LONG" : "GATOR_MA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, partial close, or scale-in logic.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_GetPosition(ptype, open_time))
      return false;

   int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      period_seconds = 3600;
   if(strategy_max_hold_bars > 0 &&
      TimeCurrent() - open_time >= (long)strategy_max_hold_bars * period_seconds)
      return true;

   MqlRates rates[];
   if(!Strategy_ReadClosedBars(rates, 2))
      return false;

   const double close1 = rates[1].close;
   const double ma1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || ma1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
     {
      if(Strategy_GatorUpperFalling(1) && Strategy_GatorLowerRising(1))
         return true;
      if(close1 < ma1)
         return true;
     }
   else
     {
      if(Strategy_GatorUpperRising(1) && Strategy_GatorLowerFalling(1))
         return true;
      if(close1 > ma1)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"mql5-gator-ma-card\",\"ea\":\"QM5_12953\"}");
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
