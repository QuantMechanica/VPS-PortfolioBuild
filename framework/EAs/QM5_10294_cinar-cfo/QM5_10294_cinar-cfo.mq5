#property strict
#property version   "5.0"
#property description "QM5_10294 Cinar CFO zero-line stop-and-reverse"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10294;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cfo_period          = 14;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.0;

double RateClose(const MqlRates &rates[], const int copied, const int shift)
  {
   if(shift < 1 || shift > copied)
      return 0.0;
   return rates[shift - 1].close;
  }

bool Strategy_CfoAtShift(const MqlRates &rates[], const int copied, const int shift, double &cfo)
  {
   cfo = 0.0;
   if(strategy_cfo_period <= 1)
      return false;

   const int newest_shift = shift;
   const int oldest_shift = shift + strategy_cfo_period - 1;
   if(oldest_shift > copied)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_x2 = 0.0;

   for(int i = 0; i < strategy_cfo_period; ++i)
     {
      const int bar_shift = oldest_shift - i;
      const double y = RateClose(rates, copied, bar_shift);
      if(y <= 0.0)
         return false;

      const double x = (double)i;
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
     }

   const double period = (double)strategy_cfo_period;
   const double denominator = period * sum_x2 - sum_x * sum_x;
   if(MathAbs(denominator) <= DBL_EPSILON)
      return false;

   const double slope = (period * sum_xy - sum_x * sum_y) / denominator;
   const double intercept = (sum_y - slope * sum_x) / period;
   const double forecast = slope * (period - 1.0) + intercept;
   const double close_price = RateClose(rates, copied, newest_shift);
   if(close_price <= 0.0)
      return false;

   cfo = ((close_price - forecast) / close_price) * 100.0;
   return true;
  }

bool Strategy_CfoCrossSignal(int &signal_direction)
  {
   signal_direction = 0;
   if(strategy_cfo_period <= 1)
      return false;

   const int requested = strategy_cfo_period + 1;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, requested, rates); // perf-allowed: exact CFO regression window, called only from the skeleton's closed-bar entry path.
   if(copied < requested)
      return false;

   double cfo_current = 0.0;
   double cfo_previous = 0.0;
   if(!Strategy_CfoAtShift(rates, copied, 1, cfo_current))
      return false;
   if(!Strategy_CfoAtShift(rates, copied, 2, cfo_previous))
      return false;

   if(cfo_current >= 0.0 && cfo_previous < 0.0)
      signal_direction = 1;
   else if(cfo_current <= 0.0 && cfo_previous > 0.0)
      signal_direction = -1;

   return (signal_direction != 0);
  }

bool Strategy_GetOurPosition(int &position_direction, ulong &ticket)
  {
   position_direction = 0;
   ticket = 0;
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      ticket = pos_ticket;
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
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

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   int signal_direction = 0;
   if(!Strategy_CfoCrossSignal(signal_direction))
      return false;

   int current_direction = 0;
   ulong ticket = 0;
   if(Strategy_GetOurPosition(current_direction, ticket))
     {
      if(current_direction == signal_direction)
         return false;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   const bool go_long = (signal_direction > 0);
   req.type = go_long ? QM_BUY : QM_SELL;
   req.reason = go_long ? "CINAR_CFO_LONG" : "CINAR_CFO_SHORT";

   const double entry_price = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   return (req.sl > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Source strategy specifies stop-and-reverse only; no trailing, partial close, or break-even rule.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10294_cinar-cfo\"}");
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
