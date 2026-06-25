#property strict
#property version   "5.0"
#property description "QM5_11197 ft-inform-btc - M5 EMA trend with NDX M15 informative filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11197 ft-inform-btc
// -----------------------------------------------------------------------------
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_11197_ft-inform-btc.md
// Source: xmatthias, InformativeSample.py, freqtrade-strategies.
//
// Mechanics:
//   Entry: M5 traded-symbol EMA20 > EMA50 and NDX.DWX M15 close > SMA20.
//   Exit : M5 traded-symbol EMA20 < EMA50 and NDX.DWX M15 close < SMA20.
//   Stop : ATR(14) * 2.0 at entry, per card MT5 baseline.
//   Take : source ROI ladder, long side: 5%, then 4% after 20 minutes,
//          3% after 30 minutes, and 1% after 60 minutes.
//   Filters: framework news/Friday close, one active position per magic, spread
//            <= 8% of planned stop distance, traded/informative warmup.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11197;
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
input int    strategy_ema_fast_period      = 20;
input int    strategy_ema_slow_period      = 50;
input int    strategy_informative_sma      = 20;
input int    strategy_atr_period           = 14;
input double strategy_atr_stop_mult        = 2.0;
input double strategy_spread_pct_of_stop   = 8.0;
input string strategy_informative_symbol   = "NDX.DWX";
input ENUM_TIMEFRAMES strategy_informative_tf = PERIOD_M15;

bool InformativeRiskOn()
  {
   const double ndx_close = QM_SMA(strategy_informative_symbol,
                                   strategy_informative_tf,
                                   1,
                                   1,
                                   PRICE_CLOSE);
   const double ndx_sma = QM_SMA(strategy_informative_symbol,
                                 strategy_informative_tf,
                                 strategy_informative_sma,
                                 1,
                                 PRICE_CLOSE);
   if(ndx_close <= 0.0 || ndx_sma <= 0.0)
      return false;
   return (ndx_close > ndx_sma);
  }

bool InformativeRiskOff()
  {
   const double ndx_close = QM_SMA(strategy_informative_symbol,
                                   strategy_informative_tf,
                                   1,
                                   1,
                                   PRICE_CLOSE);
   const double ndx_sma = QM_SMA(strategy_informative_symbol,
                                 strategy_informative_tf,
                                 strategy_informative_sma,
                                 1,
                                 PRICE_CLOSE);
   if(ndx_close <= 0.0 || ndx_sma <= 0.0)
      return false;
   return (ndx_close < ndx_sma);
  }

double RoiPctForHeldSeconds(const long held_seconds)
  {
   if(held_seconds >= 60 * 60)
      return 0.01;
   if(held_seconds >= 30 * 60)
      return 0.03;
   if(held_seconds >= 20 * 60)
      return 0.04;
   return 0.05;
  }

double LongRoiTargetPrice(const double open_price, const double roi_pct)
  {
   if(open_price <= 0.0 || roi_pct <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, open_price * (1.0 + roi_pct));
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   const double stop_distance = atr_value * strategy_atr_stop_mult;
   const double spread = ask - bid;
   if(spread > 0.0 && stop_distance > 0.0 &&
      spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1, PRICE_CLOSE);
   if(fast <= 0.0 || slow <= 0.0 || fast <= slow)
      return false;

   if(!InformativeRiskOn())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   const double tp = LongRoiTargetPrice(entry, 0.05);
   if(tp <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "ft_inform_btc_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const long held_seconds = (long)(now - open_time);
      const double target = LongRoiTargetPrice(open_price, RoiPctForHeldSeconds(held_seconds));
      if(target <= 0.0)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > 0.0 && bid >= target)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      const double current_tp = PositionGetDouble(POSITION_TP);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point > 0.0 && (current_tp <= 0.0 || MathAbs(current_tp - target) > point))
         QM_TM_MoveTP(ticket, target, "ft_inform_btc_roi_ladder");
     }
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1, PRICE_CLOSE);
   if(fast <= 0.0 || slow <= 0.0 || fast >= slow)
      return false;

   return InformativeRiskOff();
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

   string allowed[];
   ArrayResize(allowed, 4);
   allowed[0] = "EURUSD.DWX";
   allowed[1] = "GBPUSD.DWX";
   allowed[2] = "XAUUSD.DWX";
   allowed[3] = "NDX.DWX";
   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, strategy_informative_tf, MathMax(strategy_ema_slow_period, strategy_informative_sma) + 20);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11197_ft-inform-btc\"}");
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
