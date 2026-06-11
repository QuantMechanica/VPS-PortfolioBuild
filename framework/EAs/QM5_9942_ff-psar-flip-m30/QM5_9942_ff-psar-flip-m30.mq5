#property strict
#property version   "5.0"
#property description "QM5_9942 ForexFactory PSAR Flip M30"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9942;
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
input ENUM_TIMEFRAMES strategy_signal_tf             = PERIOD_M30;
input ENUM_TIMEFRAMES strategy_bias_tf               = PERIOD_H4;
input double          strategy_psar_step             = 0.02;
input double          strategy_psar_maximum          = 0.20;
input int             strategy_atr_period            = 14;
input double          strategy_swing_atr_buffer_mult = 0.15;
input int             strategy_swing_confirm_bars    = 5;
input int             strategy_swing_search_bars     = 20;
input double          strategy_fallback_atr_mult     = 1.20;
input double          strategy_max_initial_risk_atr  = 2.00;
input double          strategy_lock1_trigger_r       = 0.80;
input double          strategy_lock1_stop_r          = 0.25;
input double          strategy_lock2_trigger_r       = 1.50;
input double          strategy_lock2_stop_r          = 0.80;
input bool            strategy_skip_weekly_open_30m  = true;

#define QM9942_TRACKED_POSITIONS 16
ulong  g_initial_risk_ticket[QM9942_TRACKED_POSITIONS];
double g_initial_risk_price[QM9942_TRACKED_POSITIONS];

double PriceClose(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return QM_SMA(_Symbol, tf, 1, shift, PRICE_CLOSE);
  }

double PriceHigh(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return QM_SMA(_Symbol, tf, 1, shift, PRICE_HIGH);
  }

double PriceLow(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return QM_SMA(_Symbol, tf, 1, shift, PRICE_LOW);
  }

double StrategyPSAR(const ENUM_TIMEFRAMES tf, const int shift)
  {
   if(strategy_psar_step <= 0.0 || strategy_psar_maximum <= 0.0 || shift < 0)
      return 0.0;

   return QM_SAR(_Symbol, tf, strategy_psar_step, strategy_psar_maximum, shift);
  }

bool HasOurPosition()
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

double TrackedInitialRisk(const ulong ticket, const double open_price, const double current_sl)
  {
   if(ticket == 0 || open_price <= 0.0 || current_sl <= 0.0)
      return 0.0;

   for(int i = 0; i < QM9942_TRACKED_POSITIONS; ++i)
      if(g_initial_risk_ticket[i] == ticket)
         return g_initial_risk_price[i];

   const double risk = MathAbs(open_price - current_sl);
   if(risk <= 0.0)
      return 0.0;

   for(int i = 0; i < QM9942_TRACKED_POSITIONS; ++i)
     {
      if(g_initial_risk_ticket[i] == 0)
        {
         g_initial_risk_ticket[i] = ticket;
         g_initial_risk_price[i] = risk;
         return risk;
        }
     }
   return risk;
  }

bool IsConfirmedSwingLow(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const int flank = strategy_swing_confirm_bars / 2;
   const double center = PriceLow(tf, shift);
   if(center <= 0.0 || flank <= 0)
      return false;
   for(int offset = 1; offset <= flank; ++offset)
     {
      const double newer = PriceLow(tf, shift - offset);
      const double older = PriceLow(tf, shift + offset);
      if(newer <= 0.0 || older <= 0.0 || center >= newer || center >= older)
         return false;
     }
   return true;
  }

bool IsConfirmedSwingHigh(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const int flank = strategy_swing_confirm_bars / 2;
   const double center = PriceHigh(tf, shift);
   if(center <= 0.0 || flank <= 0)
      return false;
   for(int offset = 1; offset <= flank; ++offset)
     {
      const double newer = PriceHigh(tf, shift - offset);
      const double older = PriceHigh(tf, shift + offset);
      if(newer <= 0.0 || older <= 0.0 || center <= newer || center <= older)
         return false;
     }
   return true;
  }

double FindSwingStop(const ENUM_TIMEFRAMES tf,
                     const QM_OrderType side,
                     const double entry,
                     const double atr)
  {
   if(entry <= 0.0 || atr <= 0.0 || strategy_swing_search_bars < strategy_swing_confirm_bars)
      return 0.0;

   const int flank = strategy_swing_confirm_bars / 2;
   const double buffer = atr * strategy_swing_atr_buffer_mult;
   for(int shift = flank + 1; shift <= strategy_swing_search_bars; ++shift)
     {
      if(side == QM_BUY && IsConfirmedSwingLow(tf, shift))
         return PriceLow(tf, shift) - buffer;
      if(side == QM_SELL && IsConfirmedSwingHigh(tf, shift))
         return PriceHigh(tf, shift) + buffer;
     }

   return (side == QM_BUY) ? (entry - atr * strategy_fallback_atr_mult)
                           : (entry + atr * strategy_fallback_atr_mult);
  }

bool Strategy_NoTradeFilter()
  {
   if(!strategy_skip_weekly_open_30m)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.day_of_week == 0 || dt.day_of_week == 1) && dt.hour == 0 && dt.min < 30)
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

   if(HasOurPosition())
      return false;
   if(strategy_swing_confirm_bars != 5 || strategy_swing_search_bars < 5 ||
      strategy_atr_period <= 0 || strategy_max_initial_risk_atr <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = strategy_signal_tf;
   const double close_1 = PriceClose(tf, 1);
   const double close_2 = PriceClose(tf, 2);
   const double psar_1 = StrategyPSAR(tf, 1);
   const double psar_2 = StrategyPSAR(tf, 2);
   const double h4_close_1 = PriceClose(strategy_bias_tf, 1);
   const double h4_psar_1 = StrategyPSAR(strategy_bias_tf, 1);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(close_1 <= 0.0 || close_2 <= 0.0 || psar_1 <= 0.0 || psar_2 <= 0.0 ||
      h4_close_1 <= 0.0 || h4_psar_1 <= 0.0 || atr <= 0.0)
      return false;

   const bool long_flip = (close_2 < psar_2 && close_1 > psar_1 && h4_psar_1 < h4_close_1);
   const bool short_flip = (close_2 > psar_2 && close_1 < psar_1 && h4_psar_1 > h4_close_1);
   if(!long_flip && !short_flip)
      return false;

   const QM_OrderType side = long_flip ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = FindSwingStop(tf, side, entry, atr);
   if(sl <= 0.0)
      return false;

   const double risk = MathAbs(entry - sl);
   if(risk <= 0.0 || risk > atr * strategy_max_initial_risk_atr)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.sl = NormalizeDouble(sl, _Digits);
   req.reason = (side == QM_BUY) ? "FF_PSAR_FLIP_M30_LONG" : "FF_PSAR_FLIP_M30_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double psar_1 = StrategyPSAR(strategy_signal_tf, 1);
   if(psar_1 <= 0.0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double initial_risk = TrackedInitialRisk(ticket, open_price, current_sl);
      if(open_price <= 0.0 || current_sl <= 0.0 || market <= 0.0 || initial_risk <= 0.0)
         continue;

      double desired_sl = current_sl;
      const double moved = is_buy ? (market - open_price) : (open_price - market);

      if(is_buy)
        {
         if(psar_1 < market && psar_1 > desired_sl)
            desired_sl = psar_1;
         if(moved >= initial_risk * strategy_lock1_trigger_r)
            desired_sl = MathMax(desired_sl, open_price + initial_risk * strategy_lock1_stop_r);
         if(moved >= initial_risk * strategy_lock2_trigger_r)
            desired_sl = MathMax(desired_sl, open_price + initial_risk * strategy_lock2_stop_r);
         desired_sl = NormalizeDouble(desired_sl, _Digits);
         if(desired_sl > current_sl + point * 0.5 && desired_sl < market)
            QM_TM_MoveSL(ticket, desired_sl, "psar_flip_m30_long_trail_lock");
        }
      else
        {
         if(psar_1 > market && psar_1 < desired_sl)
            desired_sl = psar_1;
         if(moved >= initial_risk * strategy_lock1_trigger_r)
            desired_sl = MathMin(desired_sl, open_price - initial_risk * strategy_lock1_stop_r);
         if(moved >= initial_risk * strategy_lock2_trigger_r)
            desired_sl = MathMin(desired_sl, open_price - initial_risk * strategy_lock2_stop_r);
         desired_sl = NormalizeDouble(desired_sl, _Digits);
         if(desired_sl < current_sl - point * 0.5 && desired_sl > market)
            QM_TM_MoveSL(ticket, desired_sl, "psar_flip_m30_short_trail_lock");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = strategy_signal_tf;
   const double close_1 = PriceClose(tf, 1);
   const double close_2 = PriceClose(tf, 2);
   const double psar_1 = StrategyPSAR(tf, 1);
   const double psar_2 = StrategyPSAR(tf, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0 || psar_1 <= 0.0 || psar_2 <= 0.0)
      return false;

   const bool bullish_flip = (close_2 < psar_2 && close_1 > psar_1);
   const bool bearish_flip = (close_2 > psar_2 && close_1 < psar_1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && bearish_flip)
         return true;
      if(position_type == POSITION_TYPE_SELL && bullish_flip)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9942_ff-psar-flip-m30\"}");
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
