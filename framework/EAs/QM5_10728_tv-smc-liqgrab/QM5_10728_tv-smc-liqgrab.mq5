#property strict
#property version   "5.0"
#property description "QM5_10728 TradingView SMC Liquidity Grab Pro"

#include <QM/QM_Common.mqh>

// =============================================================================
// TradingView SMC Liquidity Grab Pro
// Source: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10728;
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
input ENUM_TIMEFRAMES strategy_htf_timeframe = PERIOD_H4;
input int    strategy_swing_lookback         = 5;
input int    strategy_atr_period             = 14;
input double strategy_min_stop_atr           = 0.30;
input double strategy_max_stop_atr           = 3.00;
input double strategy_rr                     = 2.00;
input int    strategy_max_spread_points      = 0;

bool ReadClosedBar(const ENUM_TIMEFRAMES tf, const int shift, MqlRates &bar)
  {
   if(shift < 1)
      return false;

   MqlRates rates[1];
   const int copied = CopyRates(_Symbol, tf, shift, 1, rates); // perf-allowed: one closed-bar OHLC read inside Strategy_EntrySignal's framework QM_IsNewBar gate.
   if(copied != 1)
      return false;

   bar = rates[0];
   return true;
  }

bool ReadSwingExtreme(const bool want_low, const int lookback, double &extreme)
  {
   if(lookback < 1)
      return false;

   MqlRates rates[];
   ArrayResize(rates, lookback);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, lookback, rates); // perf-allowed: bounded structural swing scan called only after the framework QM_IsNewBar gate.
   if(copied < 1)
      return false;

   extreme = want_low ? DBL_MAX : -DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      if(want_low)
         extreme = MathMin(extreme, rates[i].low);
      else
         extreme = MathMax(extreme, rates[i].high);
     }

   return (want_low ? (extreme < DBL_MAX) : (extreme > -DBL_MAX));
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool StopDistanceAllowed(const double entry, const double stop)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(entry <= 0.0 || stop <= 0.0 || atr <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - stop);
   return (stop_distance >= strategy_min_stop_atr * atr &&
           stop_distance <= strategy_max_stop_atr * atr);
  }

bool HasOpenPositionForMagic()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }

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

   if(HasOpenPositionForMagic())
      return false;
   if(strategy_swing_lookback < 1 || strategy_atr_period < 1 || strategy_rr <= 0.0)
      return false;

   MqlRates htf_bar;
   MqlRates exec_bar;
   if(!ReadClosedBar(strategy_htf_timeframe, 1, htf_bar))
      return false;
   if(!ReadClosedBar((ENUM_TIMEFRAMES)_Period, 1, exec_bar))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(exec_bar.low < htf_bar.low && exec_bar.close > htf_bar.low)
     {
      double swing_low = 0.0;
      if(!ReadSwingExtreme(true, strategy_swing_lookback, swing_low))
         swing_low = exec_bar.low;

      const double entry = ask;
      const double sl = NormalizeStrategyPrice(MathMin(swing_low, exec_bar.low));
      if(sl <= 0.0 || sl >= entry || !StopDistanceAllowed(entry, sl))
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = NormalizeStrategyPrice(QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_rr));
      req.reason = "SMC_LIQ_GRAB_LONG";
      return (req.tp > entry);
     }

   if(exec_bar.high > htf_bar.high && exec_bar.close < htf_bar.high)
     {
      double swing_high = 0.0;
      if(!ReadSwingExtreme(false, strategy_swing_lookback, swing_high))
         swing_high = exec_bar.high;

      const double entry = bid;
      const double sl = NormalizeStrategyPrice(MathMax(swing_high, exec_bar.high));
      if(sl <= 0.0 || sl <= entry || !StopDistanceAllowed(entry, sl))
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = NormalizeStrategyPrice(QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_rr));
      req.reason = "SMC_LIQ_GRAB_SHORT";
      return (req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP management only.
  }

bool Strategy_ExitSignal()
  {
   // Exits are broker SL/TP plus framework Friday close.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10728_tv_smc_liqgrab\"}");
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
