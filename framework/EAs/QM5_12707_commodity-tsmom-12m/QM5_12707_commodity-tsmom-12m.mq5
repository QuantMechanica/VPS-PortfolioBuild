#property strict
#property version   "5.0"
#property description "QM5_12707 Commodity TS-MOM 12M D1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12707;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input ENUM_TIMEFRAMES strategy_signal_tf             = PERIOD_D1;
input int             strategy_momentum_lookback     = 252;
input int             strategy_atr_period            = 20;
input double          strategy_atr_sl_mult           = 2.0;
input double          strategy_min_atr_close_ratio   = 0.003;
input int             strategy_max_spread_points     = 0;

ENUM_TIMEFRAMES Strategy_SignalTF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

bool Strategy_SelectOpenPosition(ulong &ticket,
                                 ENUM_POSITION_TYPE &ptype,
                                 double &volume,
                                 double &open_price,
                                 datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   volume = 0.0;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_IsMonthlyRebalance()
  {
   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();
   const datetime this_bar = iTime(_Symbol, tf, 0); // perf-allowed: D1 calendar month boundary check.
   const datetime prev_bar = iTime(_Symbol, tf, 1); // perf-allowed: D1 calendar month boundary check.
   if(this_bar <= 0 || prev_bar <= 0)
      return false;

   MqlDateTime now_dt;
   MqlDateTime prev_dt;
   TimeToStruct(this_bar, now_dt);
   TimeToStruct(prev_bar, prev_dt);
   return (now_dt.year != prev_dt.year || now_dt.mon != prev_dt.mon);
  }

bool Strategy_MomentumDirection(int &direction, double &atr_value, double &recent_close)
  {
   direction = 0;
   atr_value = 0.0;
   recent_close = 0.0;

   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();
   recent_close = iClose(_Symbol, tf, 1); // perf-allowed: card-defined 12M close return on closed D1 bars.
   const double past_close = iClose(_Symbol, tf, 1 + strategy_momentum_lookback); // perf-allowed: card-defined 12M close return on closed D1 bars.
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;

   atr_value = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double r12 = (recent_close - past_close) / past_close;
   if(r12 > 0.0)
      direction = 1;
   else if(r12 < 0.0)
      direction = -1;
   else
      direction = 0;

   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_momentum_lookback < 20 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_min_atr_close_ratio < 0.0 ||
      strategy_max_spread_points < 0)
      return true;

   const int warmup = strategy_momentum_lookback + strategy_atr_period + 10;
   if(Bars(_Symbol, Strategy_SignalTF()) < warmup) // perf-allowed: O(1) warm-up availability check.
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > 0 && spread > strategy_max_spread_points)
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

   if(!Strategy_IsMonthlyRebalance())
      return false;

   int direction = 0;
   double atr = 0.0;
   double recent_close = 0.0;
   if(!Strategy_MomentumDirection(direction, atr, recent_close))
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   const bool has_position = Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time);

   if(direction == 0)
     {
      if(has_position)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      return false;
     }

   const bool already_long = (has_position && ptype == POSITION_TYPE_BUY);
   const bool already_short = (has_position && ptype == POSITION_TYPE_SELL);
   if((direction > 0 && already_long) || (direction < 0 && already_short))
      return false;

   if(has_position)
     {
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   if(recent_close <= 0.0 || atr / recent_close < strategy_min_atr_close_ratio)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (direction > 0) ? "COMMODITY_TSMOM_12M_LONG" : "COMMODITY_TSMOM_12M_SHORT";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
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
                        60,
                        60,
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
