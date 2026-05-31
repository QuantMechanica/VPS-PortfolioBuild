#property strict
#property version   "5.0"
#property description "QM5_10545 MQL5 Gazonkos Momentum Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10545;
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
input ENUM_TIMEFRAMES strategy_timeframe      = PERIOD_H1;
input int    strategy_t1                      = 3;
input int    strategy_t2                      = 2;
input int    strategy_delta_points            = 40;
input int    strategy_rollback_points         = 16;
input int    strategy_stop_loss_points        = 40;
input int    strategy_take_profit_points      = 16;
input int    strategy_time_stop_bars          = 1;
input int    strategy_max_spread_points       = 0;
input int    strategy_active_trades           = 1;

double Strategy_PointUnit()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_LoadSignalBars(double &close_t1,
                             double &close_t2,
                             double &open_1,
                             double &high_1,
                             double &low_1,
                             double &close_1,
                             double &high_t2,
                             double &low_t2)
  {
   close_t1 = 0.0;
   close_t2 = 0.0;
   open_1 = 0.0;
   high_1 = 0.0;
   low_1 = 0.0;
   close_1 = 0.0;
   high_t2 = 0.0;
   low_t2 = 0.0;

   if(strategy_t1 < 1 || strategy_t2 < 1 || strategy_t1 == strategy_t2)
      return false;

   const int warmup = MathMax(strategy_t1, strategy_t2) + 2;
   if(Bars(_Symbol, strategy_timeframe) < warmup)
      return false;

   close_t1 = iClose(_Symbol, strategy_timeframe, strategy_t1);
   close_t2 = iClose(_Symbol, strategy_timeframe, strategy_t2);
   open_1   = iOpen(_Symbol, strategy_timeframe, 1);
   high_1   = iHigh(_Symbol, strategy_timeframe, 1);
   low_1    = iLow(_Symbol, strategy_timeframe, 1);
   close_1  = iClose(_Symbol, strategy_timeframe, 1);
   high_t2  = iHigh(_Symbol, strategy_timeframe, strategy_t2);
   low_t2   = iLow(_Symbol, strategy_timeframe, strategy_t2);

   return (close_t1 > 0.0 && close_t2 > 0.0 &&
           open_1 > 0.0 && high_1 > 0.0 && low_1 > 0.0 && close_1 > 0.0 &&
           high_t2 > 0.0 && low_t2 > 0.0);
  }

// No Trade Filter (time, spread, news): framework handles time, news, and
// Friday close; this hook adds the card's optional spread ceiling.
bool Strategy_NoTradeFilter()
  {
   if(strategy_active_trades < 1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points < 0 || spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: source momentum is close(t2)-close(t1), followed by a rollback
// from the local move extreme and a same-direction closed-bar resumption.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   double close_t1, close_t2, open_1, high_1, low_1, close_1, high_t2, low_t2;
   if(!Strategy_LoadSignalBars(close_t1, close_t2, open_1, high_1, low_1, close_1, high_t2, low_t2))
      return false;

   const double unit = Strategy_PointUnit();
   if(unit <= 0.0)
      return false;

   const double delta = strategy_delta_points * unit;
   const double rollback = strategy_rollback_points * unit;
   const double stop_dist = strategy_stop_loss_points * unit;
   const double take_dist = strategy_take_profit_points * unit;
   if(delta <= 0.0 || rollback <= 0.0 || stop_dist <= 0.0 || take_dist <= 0.0)
      return false;

   const double upward_momentum = close_t2 - close_t1;
   const double downward_momentum = close_t1 - close_t2;
   const bool long_pullback = (upward_momentum > delta &&
                               low_1 <= (high_t2 - rollback) &&
                               close_1 > open_1);
   const bool short_pullback = (downward_momentum > delta &&
                                high_1 >= (low_t2 + rollback) &&
                                close_1 < open_1);

   if(!long_pullback && !short_pullback)
      return false;

   const QM_OrderType side = long_pullback ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.price = NormalizeDouble(entry, _Digits);
   if(side == QM_BUY)
     {
      req.sl = NormalizeDouble(entry - stop_dist, _Digits);
      req.tp = NormalizeDouble(entry + take_dist, _Digits);
      req.reason = "GAZONKOS_MOM_PULLBACK_LONG";
     }
   else
     {
      req.sl = NormalizeDouble(entry + stop_dist, _Digits);
      req.tp = NormalizeDouble(entry - take_dist, _Digits);
      req.reason = "GAZONKOS_MOM_PULLBACK_SHORT";
     }

   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Trade Management: the baseline source uses fixed broker SL/TP only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: optional one-H1-session time stop if SL/TP has not fired.
bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_timeframe);
   if(seconds_per_bar <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int max_hold_seconds = seconds_per_bar * strategy_time_stop_bars;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (now - opened) >= max_hold_seconds)
         return true;
     }

   return false;
  }

// News Filter Hook: no card-specific override; central framework news mode applies.
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
