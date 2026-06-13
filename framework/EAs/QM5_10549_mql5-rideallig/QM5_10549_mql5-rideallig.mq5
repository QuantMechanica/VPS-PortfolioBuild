#property strict
#property version   "5.0"
#property description "QM5_10549 MQL5 RideAlligator"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10549;
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
input int    strategy_alligator_period  = 5;
input ENUM_MA_METHOD strategy_alligator_method = MODE_LWMA;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_take_rr           = 1.5;
input double strategy_adx_floor         = 0.0;

int Strategy_GoldenPeriod(const int seed, const int steps)
  {
   int value = MathMax(1, seed);
   for(int i = 0; i < steps; ++i)
      value = (int)MathRound((double)value * 1.61803398874989);
   return MathMax(1, value);
  }

double Strategy_MA(const int period, const int visual_shift, const int closed_bar_shift)
  {
   const int read_shift = MathMax(1, closed_bar_shift) + MathMax(0, visual_shift);
   switch(strategy_alligator_method)
     {
      case MODE_SMA:
         return QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, period, read_shift, PRICE_MEDIAN);
      case MODE_EMA:
         return QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, period, read_shift, PRICE_MEDIAN);
      case MODE_SMMA:
         return QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, period, read_shift, PRICE_MEDIAN);
      case MODE_LWMA:
         return QM_LWMA(_Symbol, (ENUM_TIMEFRAMES)_Period, period, read_shift, PRICE_MEDIAN);
     }
   return QM_LWMA(_Symbol, (ENUM_TIMEFRAMES)_Period, period, read_shift, PRICE_MEDIAN);
  }

bool Strategy_ReadAlligator(double &lips_now,
                            double &lips_pre,
                            double &jaws_now,
                            double &jaws_pre,
                            double &teeth_now)
  {
   const int base = MathMax(1, strategy_alligator_period);
   const int a1 = Strategy_GoldenPeriod(base, 1);
   const int a2 = Strategy_GoldenPeriod(base, 2);
   const int a3 = Strategy_GoldenPeriod(base, 3);

   lips_now  = Strategy_MA(a1, base, 1);
   lips_pre  = Strategy_MA(a1, base, 2);
   jaws_now  = Strategy_MA(a3, a2,   1);
   jaws_pre  = Strategy_MA(a3, a2,   2);
   teeth_now = Strategy_MA(a2, a1,   1);

   return (lips_now > 0.0 && lips_pre > 0.0 && jaws_now > 0.0 &&
           jaws_pre > 0.0 && teeth_now > 0.0);
  }

bool Strategy_BullishEntry()
  {
   double lips_now, lips_pre, jaws_now, jaws_pre, teeth_now;
   if(!Strategy_ReadAlligator(lips_now, lips_pre, jaws_now, jaws_pre, teeth_now))
      return false;
   return (lips_now > jaws_now && teeth_now < jaws_now && lips_pre < jaws_pre);
  }

bool Strategy_BearishEntry()
  {
   double lips_now, lips_pre, jaws_now, jaws_pre, teeth_now;
   if(!Strategy_ReadAlligator(lips_now, lips_pre, jaws_now, jaws_pre, teeth_now))
      return false;
   return (lips_now < jaws_now && teeth_now > jaws_now && lips_pre > jaws_pre);
  }

int Strategy_AlligatorState()
  {
   double lips_now, lips_pre, jaws_now, jaws_pre, teeth_now;
   if(!Strategy_ReadAlligator(lips_now, lips_pre, jaws_now, jaws_pre, teeth_now))
      return 0;
   if(lips_now > jaws_now && teeth_now < jaws_now)
      return 1;
   if(lips_now < jaws_now && teeth_now > jaws_now)
      return -1;
   return 0;
  }

bool Strategy_HasOurPosition(ENUM_POSITION_TYPE &position_type)
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_adx_floor <= 0.0)
      return false;
   const double adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   return (adx > 0.0 && adx < strategy_adx_floor);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_take_rr <= 0.0)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(Strategy_HasOurPosition(position_type))
      return false;

   const bool go_long = Strategy_BullishEntry();
   const bool go_short = Strategy_BearishEntry();
   if(!go_long && !go_short)
      return false;

   req.type = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_rr);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = go_long ? "RIDEALLIGATOR_LONG" : "RIDEALLIGATOR_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // P2 baseline uses the card's ATR hard stop and 1.5R target; Alligator trailing is deferred to P3.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_HasOurPosition(position_type))
      return false;

   const int state = Strategy_AlligatorState();
   if(position_type == POSITION_TYPE_BUY)
      return (state != 1);
   if(position_type == POSITION_TYPE_SELL)
      return (state != -1);
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"mql5-rideallig\",\"ea\":\"QM5_10549\"}");
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
