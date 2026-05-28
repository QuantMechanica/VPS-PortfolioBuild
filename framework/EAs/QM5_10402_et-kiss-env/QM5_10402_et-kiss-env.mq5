#property strict
#property version   "5.0"
#property description "QM5_10402 Elite Trader KISS Envelope Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10402;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_M15;
input int             strategy_sma1_period     = 10;
input int             strategy_sma2_period     = 20;
input int             strategy_sma3_period     = 50;
input int             strategy_d1_sma_period   = 20;
input double          strategy_envelope_pct    = 0.15;
input int             strategy_stop_pips       = 10;
input int             strategy_atr_period      = 20;
input double          strategy_atr_stop_cap    = 1.5;
input double          strategy_take_profit_rr  = 1.0;
input int             strategy_session_start_h = 7;
input int             strategy_session_end_h   = 21;
input double          strategy_max_spread_sl_frac = 0.15;

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_signal_tf)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return true;

   const int start_h = MathMax(0, MathMin(23, strategy_session_start_h));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_h));
   if(start_h == end_h)
      return false;
   if(start_h < end_h)
      return !(dt.hour >= start_h && dt.hour < end_h);
   return !(dt.hour >= start_h || dt.hour < end_h);
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
   if(strategy_sma1_period <= 1 || strategy_sma2_period <= 1 || strategy_sma3_period <= 1)
      return false;
   if(strategy_stop_pips <= 0 || strategy_atr_period <= 1 || strategy_envelope_pct <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = strategy_signal_tf;
   const double sma1_1 = QM_SMA(_Symbol, tf, strategy_sma1_period, 1, PRICE_TYPICAL);
   const double sma1_2 = QM_SMA(_Symbol, tf, strategy_sma1_period, 2, PRICE_TYPICAL);
   const double sma2_1 = QM_SMA(_Symbol, tf, strategy_sma2_period, 1, PRICE_TYPICAL);
   const double sma2_2 = QM_SMA(_Symbol, tf, strategy_sma2_period, 2, PRICE_TYPICAL);
   const double sma3_1 = QM_SMA(_Symbol, tf, strategy_sma3_period, 1, PRICE_TYPICAL);
   const double sma3_2 = QM_SMA(_Symbol, tf, strategy_sma3_period, 2, PRICE_TYPICAL);
   const double d1_close = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);

   if(sma1_1 <= 0.0 || sma1_2 <= 0.0 || sma2_1 <= 0.0 || sma2_2 <= 0.0 ||
      sma3_1 <= 0.0 || sma3_2 <= 0.0 || d1_close <= 0.0 || d1_sma <= 0.0 || atr <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, tf, 1);
   const double close2 = iClose(_Symbol, tf, 2);
   const double low2 = iLow(_Symbol, tf, 2);
   const double high2 = iHigh(_Symbol, tf, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || low2 <= 0.0 || high2 <= 0.0)
      return false;

   const double lower2 = sma1_2 * (1.0 - strategy_envelope_pct / 100.0);
   const double upper2 = sma1_2 * (1.0 + strategy_envelope_pct / 100.0);
   const double ten_pip_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_pips);
   const double atr_cap_distance = atr * strategy_atr_stop_cap;
   if(ten_pip_distance <= 0.0 || atr_cap_distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const bool long_filter = (d1_close > d1_sma && sma2_1 > sma2_2 && sma3_1 > sma3_2);
   const bool short_filter = (d1_close < d1_sma && sma2_1 < sma2_2 && sma3_1 < sma3_2);
   const bool long_setup = (close2 <= sma1_2 || low2 <= lower2);
   const bool short_setup = (close2 >= sma1_2 || high2 >= upper2);
   const bool long_cross = (close2 <= sma1_2 && close1 > sma1_1 && sma1_1 > sma1_2);
   const bool short_cross = (close2 >= sma1_2 && close1 < sma1_1 && sma1_1 < sma1_2);

   if(long_filter && long_setup && long_cross)
     {
      const double entry = ask;
      const double envelope_distance = MathAbs(entry - (sma1_1 * (1.0 - strategy_envelope_pct / 100.0)));
      double stop_distance = MathMax(ten_pip_distance, envelope_distance);
      stop_distance = MathMin(stop_distance, atr_cap_distance);
      if((ask - bid) > stop_distance * strategy_max_spread_sl_frac)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(entry - stop_distance, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr);
      req.reason = "ET_KISS_ENV_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(short_filter && short_setup && short_cross)
     {
      const double entry = bid;
      const double envelope_distance = MathAbs((sma1_1 * (1.0 + strategy_envelope_pct / 100.0)) - entry);
      double stop_distance = MathMax(ten_pip_distance, envelope_distance);
      stop_distance = MathMin(stop_distance, atr_cap_distance);
      if((ask - bid) > stop_distance * strategy_max_spread_sl_frac)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(entry + stop_distance, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr);
      req.reason = "ET_KISS_ENV_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no break-even, trailing, partial close, or scaling.
  }

bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   bool in_session = false;
   if(dt.day_of_week != 0 && dt.day_of_week != 6)
     {
      const int start_h = MathMax(0, MathMin(23, strategy_session_start_h));
      const int end_h = MathMax(0, MathMin(24, strategy_session_end_h));
      if(start_h == end_h)
         in_session = true;
      else if(start_h < end_h)
         in_session = (dt.hour >= start_h && dt.hour < end_h);
      else
         in_session = (dt.hour >= start_h || dt.hour < end_h);
     }

   if(in_session)
      return false;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10402\",\"ea\":\"QM5_10402_et-kiss-env\"}");
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

   const bool no_trade = Strategy_NoTradeFilter();

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

   if(no_trade)
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
