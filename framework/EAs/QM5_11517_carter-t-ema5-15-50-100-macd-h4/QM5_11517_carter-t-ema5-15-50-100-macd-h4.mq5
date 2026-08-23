#property strict
#property version   "5.0"
#property description "QM5_11517 Carter-T 4-EMA Ribbon (5/15/50/100) + MACD (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11517
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11517;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_ema_fast_period      = 5;
input int    strategy_ema_slow_period      = 15;
input int    strategy_ema_trend1_period    = 50;
input int    strategy_ema_trend2_period    = 100;
input int    strategy_macd_fast            = 12;
input int    strategy_macd_slow            = 26;
input int    strategy_macd_signal          = 9;
input int    strategy_cross_lookback       = 3;
input int    strategy_sl_pips              = 30;
input int    strategy_tp_pips              = 60;
input int    strategy_spread_cap_pips      = 15;
input bool   strategy_no_friday_entry      = true;

// -----------------------------------------------------------------------------
// Helper functions
// -----------------------------------------------------------------------------

double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

bool IsFridayBrokerTime()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

bool SpreadWithinCap()
  {
   const double max_spread = PipDistance(strategy_spread_cap_pips);
   if(max_spread <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   return ((ask - bid) <= max_spread);
  }

int FindEmaCrossShift(const bool bullish, const int max_lookback = 3)
  {
   for(int s = 1; s <= max_lookback; ++s)
     {
      const double ema_fast_now = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_fast_period, s);
      const double ema_slow_now = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_slow_period, s);
      const double ema_fast_prev = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_fast_period, s + 1);
      const double ema_slow_prev = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_slow_period, s + 1);
      if(ema_fast_now <= 0.0 || ema_slow_now <= 0.0 || ema_fast_prev <= 0.0 || ema_slow_prev <= 0.0)
         return -1;

      if(bullish && ema_fast_now > ema_slow_now && ema_fast_prev <= ema_slow_prev)
         return s;
      if(!bullish && ema_fast_now < ema_slow_now && ema_fast_prev >= ema_slow_prev)
         return s;
     }
   return -1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return !SpreadWithinCap();
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

   if(strategy_no_friday_entry && IsFridayBrokerTime())
      return false;
   if(!SpreadWithinCap())
      return false;

   if(strategy_ema_fast_period <= 0 || strategy_ema_slow_period <= 0 ||
      strategy_ema_trend1_period <= 0 || strategy_ema_trend2_period <= 0 ||
      strategy_sl_pips <= 0 || strategy_tp_pips <= 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: single closed-bar close; no QM close reader exists.
   const double ema50 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_trend1_period, 1);
   const double ema100 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_trend2_period, 1);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   if(close1 <= 0.0 || ema50 <= 0.0 || ema100 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // LONG setup: EMA5 crosses EMA15 up within 3 bars, close1 > EMA50, close1 > EMA100, MACD > 0
   const int cross_shift_long = FindEmaCrossShift(true, strategy_cross_lookback);
   if(cross_shift_long >= 1 && close1 > ema50 && close1 > ema100 && macd_main > 0.0)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_sl_pips);
      const double tp = ask + PipDistance(strategy_tp_pips);
      if(sl > 0.0 && sl < ask && tp > ask)
        {
         req.type = QM_BUY;
         req.sl = sl;
         req.tp = tp;
         req.reason = "CARTER_EMA5_15_50_100_MACD_LONG";
         return true;
        }
     }

   // SHORT setup: EMA5 crosses EMA15 down within 3 bars, close1 < EMA50, close1 < EMA100, MACD < 0
   const int cross_shift_short = FindEmaCrossShift(false, strategy_cross_lookback);
   if(cross_shift_short >= 1 && close1 < ema50 && close1 < ema100 && macd_main < 0.0)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_sl_pips);
      const double tp = bid - PipDistance(strategy_tp_pips);
      if(sl > 0.0 && sl > bid && tp < bid && tp > 0.0)
        {
         req.type = QM_SELL;
         req.sl = sl;
         req.tp = tp;
         req.reason = "CARTER_EMA5_15_50_100_MACD_SHORT";
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11517\",\"ea\":\"carter_t_ema5_15_50_100_macd_h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
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
