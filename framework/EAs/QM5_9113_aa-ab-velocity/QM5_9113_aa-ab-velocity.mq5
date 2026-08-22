#property strict
#property version   "5.0"
#property description "QM5_9113 Alpha Architect Alpha-Beta Velocity Filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9113
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9113;
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
input double strategy_alpha             = 0.29896;
input double strategy_beta              = 0.05295;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 3.0;
input int    strategy_min_warmup_bars   = 120;
input bool   strategy_enable_shorts     = false;

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

bool Strategy_HasOpenPosition(int &pos_type, ulong &out_ticket)
{
   pos_type = -1;
   out_ticket = 0;
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

      pos_type = (int)PositionGetInteger(POSITION_TYPE);
      out_ticket = ticket;
      return true;
   }
   return false;
}

int Strategy_MedianSpreadD1(const string sym, const int lookback)
{
   if(lookback <= 0)
      return 0;

   MqlRates rates[];
   const int copied = CopyRates(sym, PERIOD_D1, 1, lookback, rates);
   if(copied <= 0)
      return 0;

   double spreads[];
   ArrayResize(spreads, copied);
   for(int i = 0; i < copied; ++i)
   {
      spreads[i] = (rates[i].spread >= 0) ? (double)rates[i].spread : 0.0;
   }

   ArraySort(spreads);
   return (int)MathRound(spreads[copied / 2]);
}

bool Strategy_SpreadAllowsEntry()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(!(ask > bid))
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int current_spread = (int)MathRound((ask - bid) / point);
   if(current_spread <= 0)
      return true;

   const int median_spread = Strategy_MedianSpreadD1(_Symbol, 20);
   if(median_spread <= 0)
      return true;

   const int cap = (int)MathMax(1.0, MathRound(2.5 * (double)median_spread));
   return (current_spread <= cap);
}

bool Strategy_CalculateABVelocity(double &vel_shift1, double &vel_shift2)
{
   vel_shift1 = 0.0;
   vel_shift2 = 0.0;
   if(strategy_alpha <= 0.0 || strategy_alpha >= 1.0 || strategy_beta <= 0.0 || strategy_beta >= 1.0)
      return false;

   const int warmup = MathMax(strategy_min_warmup_bars, 120);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, warmup + 10, rates);
   if(copied < warmup)
      return false;

   const int oldest = copied - 1;
   const double seed_close = rates[oldest].close;
   if(seed_close <= 0.0)
      return false;

   double pos = seed_close;
   double vel = 0.0;

   for(int i = oldest; i >= 0; --i)
   {
      const double c = rates[i].close;
      if(c <= 0.0)
         return false;

      const double pos_pred = pos + vel;
      const double vel_pred = vel;
      const double residual = c - pos_pred;

      pos = pos_pred + strategy_alpha * residual;
      vel = vel_pred + strategy_beta * residual;

      if(i == 1)
         vel_shift2 = vel;
      else if(i == 0)
         vel_shift1 = vel;
   }

   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(_Period != PERIOD_D1)
      return true;
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_warmup_bars, 120))
      return true;
   if(!Strategy_SpreadAllowsEntry())
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

   int current_pos = -1;
   ulong ticket = 0;
   if(Strategy_HasOpenPosition(current_pos, ticket))
      return false;

   double v1 = 0.0, v2 = 0.0;
   if(!Strategy_CalculateABVelocity(v1, v2))
      return false;

   if(v2 <= 0.0 && v1 > 0.0)
   {
      req.type = QM_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl = QM_StopATR(_Symbol, QM_BUY, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "AA_AB_VELOCITY_ZERO_CROSS_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      return (req.sl > 0.0 && req.sl < req.price);
   }

   if(strategy_enable_shorts && v2 >= 0.0 && v1 < 0.0)
   {
      req.type = QM_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl = QM_StopATR(_Symbol, QM_SELL, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "AA_AB_VELOCITY_ZERO_CROSS_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      return (req.sl > 0.0 && req.sl > req.price);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   int current_pos = -1;
   ulong ticket = 0;
   if(!Strategy_HasOpenPosition(current_pos, ticket))
      return false;

   double v1 = 0.0, v2 = 0.0;
   if(!Strategy_CalculateABVelocity(v1, v2))
      return false;

   if(current_pos == (int)POSITION_TYPE_BUY && v1 < 0.0)
      return true;
   if(current_pos == (int)POSITION_TYPE_SELL && v1 > 0.0)
      return true;

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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
