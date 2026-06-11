#property strict
#property version   "5.0"
#property description "QM5_9929 ForexFactory BB RSI Stoch M30"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_9929_ff-bb-rsi-stoch-m30
// Source: 6e967762-b26d-59a3-b076-35c17f2e7c36
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9929;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M30;
input ENUM_TIMEFRAMES strategy_trend_tf           = PERIOD_H4;
input int    strategy_bb_period                   = 50;
input double strategy_bb_deviation                = 2.0;
input int    strategy_rsi_period                  = 7;
input int    strategy_stoch_k                     = 14;
input int    strategy_stoch_d                     = 3;
input int    strategy_stoch_slowing               = 3;
input int    strategy_h4_ema_period               = 50;
input int    strategy_atr_period                  = 14;
input double strategy_rsi_oversold                = 30.0;
input double strategy_rsi_overbought              = 70.0;
input double strategy_stoch_oversold              = 20.0;
input double strategy_stoch_overbought            = 80.0;
input double strategy_atr_sl_mult                 = 1.5;
input double strategy_max_stop_atr_mult           = 2.8;
input int    strategy_atr_percentile_lookback     = 100;
input double strategy_min_atr_percentile          = 20.0;
input double strategy_pin_wick_body_mult          = 1.5;
input double strategy_pin_close_zone_pct          = 40.0;
input double strategy_tp1_close_percent           = 50.0;
input int    strategy_time_stop_bars              = 20;

double Strategy_NormalizePrice(const double price)
  {
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

double Strategy_Open(const int shift)
  {
   return iOpen(_Symbol, strategy_signal_tf, shift); // perf-allowed: card requires fixed candle-shape tests on closed M30 bars.
  }

double Strategy_High(const int shift)
  {
   return iHigh(_Symbol, strategy_signal_tf, shift); // perf-allowed: card requires fixed candle-shape tests on closed M30 bars.
  }

double Strategy_Low(const int shift)
  {
   return iLow(_Symbol, strategy_signal_tf, shift); // perf-allowed: card requires fixed candle-shape tests on closed M30 bars.
  }

double Strategy_Close(const int shift)
  {
   return iClose(_Symbol, strategy_signal_tf, shift); // perf-allowed: card requires fixed candle-shape tests on closed M30 bars.
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &volume,
                                double &sl,
                                double &tp,
                                datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   volume = 0.0;
   sl = 0.0;
   tp = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOurPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double volume;
   double sl;
   double tp;
   datetime open_time;
   return Strategy_SelectOurPosition(ticket, position_type, open_price, volume, sl, tp, open_time);
  }

bool Strategy_AtrAboveMinimum()
  {
   if(strategy_atr_period <= 0 || strategy_atr_percentile_lookback <= 0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int observed = 0;
   int less_or_equal = 0;
   for(int shift = 2; shift < 2 + strategy_atr_percentile_lookback; ++shift)
     {
      const double hist_atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, shift);
      if(hist_atr <= 0.0)
         continue;
      observed++;
      if(hist_atr <= atr)
         less_or_equal++;
     }

   if(observed < MathMax(20, strategy_atr_percentile_lookback / 2))
      return false;

   const double percentile = 100.0 * (double)less_or_equal / (double)observed;
   return (percentile > strategy_min_atr_percentile);
  }

bool Strategy_BullishEngulfing()
  {
   const double o1 = Strategy_Open(1);
   const double c1 = Strategy_Close(1);
   const double o2 = Strategy_Open(2);
   const double c2 = Strategy_Close(2);
   if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return false;
   return (c1 > o1 && c2 < o2 && o1 <= c2 && c1 >= o2);
  }

bool Strategy_BearishEngulfing()
  {
   const double o1 = Strategy_Open(1);
   const double c1 = Strategy_Close(1);
   const double o2 = Strategy_Open(2);
   const double c2 = Strategy_Close(2);
   if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return false;
   return (c1 < o1 && c2 > o2 && o1 >= c2 && c1 <= o2);
  }

bool Strategy_BullishPin()
  {
   const double o1 = Strategy_Open(1);
   const double h1 = Strategy_High(1);
   const double l1 = Strategy_Low(1);
   const double c1 = Strategy_Close(1);
   const double body = MathAbs(c1 - o1);
   const double range = h1 - l1;
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 || range <= 0.0)
      return false;

   const double effective_body = MathMax(body, SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   const double lower_wick = MathMin(o1, c1) - l1;
   const double close_position = (c1 - l1) / range;
   return (lower_wick >= strategy_pin_wick_body_mult * effective_body &&
           close_position >= (1.0 - strategy_pin_close_zone_pct / 100.0));
  }

bool Strategy_BearishPin()
  {
   const double o1 = Strategy_Open(1);
   const double h1 = Strategy_High(1);
   const double l1 = Strategy_Low(1);
   const double c1 = Strategy_Close(1);
   const double body = MathAbs(c1 - o1);
   const double range = h1 - l1;
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 || range <= 0.0)
      return false;

   const double effective_body = MathMax(body, SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   const double upper_wick = h1 - MathMax(o1, c1);
   const double close_position = (c1 - l1) / range;
   return (upper_wick >= strategy_pin_wick_body_mult * effective_body &&
           close_position <= strategy_pin_close_zone_pct / 100.0);
  }

bool Strategy_StopDistanceAllowed(const QM_OrderType type,
                                  const double entry,
                                  const double sl,
                                  const double atr)
  {
   if(entry <= 0.0 || sl <= 0.0 || atr <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr_mult * atr)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level > 0 && stop_distance < stops_level * point)
      return false;

   if(type == QM_BUY && sl >= entry)
      return false;
   if(type == QM_SELL && sl <= entry)
      return false;

   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

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

   if(_Period != strategy_signal_tf)
      return false;
   if(strategy_bb_period <= 0 || strategy_rsi_period <= 0 || strategy_h4_ema_period <= 0 ||
      strategy_stoch_k <= 0 || strategy_stoch_d <= 0 || strategy_stoch_slowing <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_max_stop_atr_mult <= 0.0)
      return false;
   if(Strategy_HasOurPosition())
      return false;
   if(!Strategy_AtrAboveMinimum())
      return false;

   const double close1 = Strategy_Close(1);
   const double close2 = Strategy_Close(2);
   const double high1 = Strategy_High(1);
   const double low1 = Strategy_Low(1);
   if(close1 <= 0.0 || close2 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double h4_ema = QM_EMA(_Symbol, strategy_trend_tf, strategy_h4_ema_period, 1);
   const double bb_lower1 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower2 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_upper1 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_upper2 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double rsi2 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 2);
   const double stoch2 = QM_Stoch_K(_Symbol, strategy_signal_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(h4_ema <= 0.0 || bb_lower1 <= 0.0 || bb_lower2 <= 0.0 || bb_upper1 <= 0.0 || bb_upper2 <= 0.0 ||
      rsi2 <= 0.0 || stoch2 <= 0.0 || atr <= 0.0)
      return false;

   const bool long_setup = (close1 > h4_ema &&
                            close2 < bb_lower2 &&
                            rsi2 < strategy_rsi_oversold &&
                            stoch2 < strategy_stoch_oversold &&
                            close1 > bb_lower1 &&
                            (Strategy_BullishEngulfing() || Strategy_BullishPin()));

   const bool short_setup = (close1 < h4_ema &&
                             close2 > bb_upper2 &&
                             rsi2 > strategy_rsi_overbought &&
                             stoch2 > strategy_stoch_overbought &&
                             close1 < bb_upper1 &&
                             (Strategy_BearishEngulfing() || Strategy_BearishPin()));

   if(long_setup)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = Strategy_NormalizePrice(low1 - strategy_atr_sl_mult * atr);
      const double tp = Strategy_NormalizePrice(bb_upper1);
      if(!Strategy_StopDistanceAllowed(QM_BUY, entry, sl, atr) || tp <= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FF_BB_RSI_STOCH_M30_LONG";
      return true;
     }

   if(short_setup)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = Strategy_NormalizePrice(high1 + strategy_atr_sl_mult * atr);
      const double tp = Strategy_NormalizePrice(bb_lower1);
      if(!Strategy_StopDistanceAllowed(QM_SELL, entry, sl, atr) || tp >= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FF_BB_RSI_STOCH_M30_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double volume;
   double sl;
   double tp;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, volume, sl, tp, open_time))
      return;

   if(open_price <= 0.0 || volume <= 0.0 || strategy_tp1_close_percent <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const bool sl_at_or_better_than_entry = (sl > 0.0) &&
      (is_buy ? (sl >= open_price - point * 0.5) : (sl <= open_price + point * 0.5));
   if(sl_at_or_better_than_entry)
      return;

   const double middle = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   if(middle <= 0.0)
      return;

   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const bool tp1_hit = is_buy ? (market_price >= middle) : (market_price <= middle);
   if(!tp1_hit)
      return;

   const double lots_to_close = volume * strategy_tp1_close_percent / 100.0;
   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
      QM_TM_MoveSL(ticket, Strategy_NormalizePrice(open_price), "tp1_middle_band_move_sl_to_entry");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double volume;
   double sl;
   double tp;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, volume, sl, tp, open_time))
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_signal_tf);
   if(seconds_per_bar > 0 && strategy_time_stop_bars > 0 && open_time > 0)
     {
      if(TimeCurrent() - open_time >= strategy_time_stop_bars * seconds_per_bar)
         return true;
     }

   const double close1 = Strategy_Close(1);
   if(close1 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double lower = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
      return (lower > 0.0 && close1 < lower);
     }

   const double upper = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   return (upper > 0.0 && close1 > upper);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do not edit below this line.
// -----------------------------------------------------------------------------

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
