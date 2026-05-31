#property strict
#property version   "5.0"
#property description "QM5_10619 MQL5 Dark Cloud/Piercing Line RSI"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10619_mql5-dcpl-rsi
// Strategy Card: b8b5125a-c67f-5bbc-baff-33456e08f5b2
// Implements only the five Strategy_* hooks below; framework wiring is copied
// from framework/templates/EA_Skeleton.mq5.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10619;
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
input int    strategy_rsi_period        = 20;
input double strategy_rsi_long_max      = 40.0;
input double strategy_rsi_short_min     = 60.0;
input double strategy_exit_low          = 30.0;
input double strategy_exit_high         = 70.0;
input int    strategy_ma_period         = 14;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_cap_mult   = 1.75;
input double strategy_take_profit_rr    = 1.5;

// No Trade Filter (time, spread, news): card authorizes only framework defaults.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: completed-bar Piercing Line/Dark Cloud Cover plus RSI.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   if(magic <= 0)
      return false;

   if(strategy_rsi_period <= 0 || strategy_ma_period <= 0 || strategy_atr_period <= 0)
      return false;

   const double rsi1 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi1 <= 0.0)
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double open2 = iOpen(_Symbol, _Period, 2);
   const double close2 = iClose(_Symbol, _Period, 2);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double low2 = iLow(_Symbol, _Period, 2);
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 ||
      open2 <= 0.0 || close2 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   double avg_body = 0.0;
   int body_samples = 0;
   for(int shift = 1; shift < 1 + strategy_ma_period; ++shift)
     {
      const double o = iOpen(_Symbol, _Period, shift);
      const double c = iClose(_Symbol, _Period, shift);
      if(o <= 0.0 || c <= 0.0)
         continue;
      avg_body += MathAbs(c - o);
      body_samples++;
     }
   if(body_samples <= 0)
      return false;
   avg_body /= (double)body_samples;

   const double body1 = MathAbs(close1 - open1);
   const double body2 = MathAbs(close2 - open2);
   const double mid2 = (open2 + close2) * 0.5;
   const double close_avg_shift2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 2, PRICE_CLOSE);
   const double close_avg_shift1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 1, PRICE_CLOSE);
   const bool piercing =
      close2 < open2 &&
      close1 > open1 &&
      body1 > avg_body &&
      body2 > avg_body &&
      open1 < low2 &&
      close1 > close2 &&
      close1 < open2 &&
      close1 > mid2 &&
      mid2 < close_avg_shift2;
   const bool dark_cloud =
      close2 > open2 &&
      close1 < open1 &&
      body1 > avg_body &&
      body2 > avg_body &&
      open1 > high2 &&
      close1 < close2 &&
      close1 > open2 &&
      close1 < mid2 &&
      mid2 > close_avg_shift1;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_cap_mult <= 0.0 || strategy_take_profit_rr <= 0.0)
      return false;

   if(piercing && rsi1 < strategy_rsi_long_max)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double stop_distance = entry - MathMin(low1, low2);
      const double cap_distance = atr * strategy_atr_sl_cap_mult;
      if(entry <= 0.0 || stop_distance <= 0.0 || cap_distance <= 0.0)
         return false;
      if(stop_distance > cap_distance)
         stop_distance = cap_distance;

      const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, entry, stop_distance);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_profit_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "PIERCING_LINE_RSI";
      return true;
     }

   if(dark_cloud && rsi1 > strategy_rsi_short_min)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double stop_distance = MathMax(high1, high2) - entry;
      const double cap_distance = atr * strategy_atr_sl_cap_mult;
      if(entry <= 0.0 || stop_distance <= 0.0 || cap_distance <= 0.0)
         return false;
      if(stop_distance > cap_distance)
         stop_distance = cap_distance;

      const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_SELL, entry, stop_distance);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_profit_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "DARK_CLOUD_RSI";
      return true;
     }

   return false;
  }

// Trade Management: no trailing, break-even, partial close, or pyramiding in card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: RSI threshold crosses; SL/TP and Friday close remain framework-driven.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   bool have_position = false;
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   if(strategy_rsi_period <= 0)
      return false;

   const double rsi1 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi2 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 2, PRICE_CLOSE);
   if(rsi1 <= 0.0 || rsi2 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return ((rsi2 > strategy_exit_high && rsi1 <= strategy_exit_high) ||
              (rsi2 > strategy_exit_low && rsi1 <= strategy_exit_low));

   if(position_type == POSITION_TYPE_SELL)
      return ((rsi2 < strategy_exit_low && rsi1 >= strategy_exit_low) ||
              (rsi2 < strategy_exit_high && rsi1 >= strategy_exit_high));

   return false;
  }

// News Filter Hook: callable P8 hook; central framework news filter remains active.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
