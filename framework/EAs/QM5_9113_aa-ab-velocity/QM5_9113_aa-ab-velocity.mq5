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

#define STRATEGY_SPREAD_LOOKBACK_DAYS    20
#define STRATEGY_MAX_RECONSTRUCTION_BARS 20000

bool     g_ab_state_ready = false;
bool     g_ab_snapshot_valid = false;
double   g_ab_position = 0.0;
double   g_ab_velocity = 0.0;
double   g_ab_velocity_previous = 0.0;
datetime g_ab_last_closed_bar_time = 0;
int      g_ab_processed_bars = 0;

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

double Strategy_MedianSpreadD1(const string sym, const int lookback)
{
   if(lookback <= 0)
      return 0.0;

   MqlRates rates[];
   if(ArrayResize(rates, lookback) != lookback)
      return 0.0;
   // perf-allowed: bounded 20-bar spread sample, reached only from the D1 new-bar entry path.
   const int copied = CopyRates(sym, PERIOD_D1, 1, lookback, rates); // perf-allowed
   if(copied != lookback || ArraySize(rates) != lookback)
      return 0.0;

   double spreads[];
   if(ArrayResize(spreads, lookback) != lookback || ArraySize(spreads) != lookback)
      return 0.0;
   for(int i = 0; i < lookback; ++i)
   {
      if(rates[i].spread <= 0)
         return 0.0;
      spreads[i] = (double)rates[i].spread;
   }

   ArraySort(spreads);
   const int middle = lookback / 2;
   const int spread_count = ArraySize(spreads);
   if(spread_count != lookback || middle < 0 || middle >= spread_count)
      return 0.0;
   double median = 0.0;
   if((lookback % 2) == 0)
   {
      if(middle <= 0)
         return 0.0;
      for(int i = 0; i < lookback; ++i)
      {
         if(i == middle - 1 || i == middle)
            median += 0.5 * spreads[i];
      }
      return median;
   }
   for(int i = 0; i < lookback; ++i)
   {
      if(i == middle)
         median = spreads[i];
   }
   return median;
}

bool Strategy_SpreadAllowsEntry()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || !(ask > bid))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double current_spread = (ask - bid) / point;
   if(current_spread <= 0.0)
      return false;

   const double median_spread = Strategy_MedianSpreadD1(_Symbol, STRATEGY_SPREAD_LOOKBACK_DAYS);
   if(median_spread <= 0.0)
      return false;

   const double cap = 2.5 * median_spread;
   return (current_spread <= cap);
}

bool Strategy_ABStep(const double close_price,
                     const double alpha,
                     const double beta,
                     double &position,
                     double &velocity)
{
   if(close_price <= 0.0 || alpha <= 0.0 || alpha >= 1.0 || beta <= 0.0 || beta >= 1.0)
      return false;

   const double position_prediction = position + velocity;
   const double residual = close_price - position_prediction;
   position = position_prediction + alpha * residual;
   velocity = velocity + beta * residual;
   return true;
}

bool Strategy_ABReferenceVectorPasses()
{
   const double closes[5] = {100.0, 101.0, 102.0, 101.0, 103.0};
   double position = closes[0];
   double velocity = 0.0;
   for(int i = 1; i < ArraySize(closes); ++i)
   {
      if(!Strategy_ABStep(closes[i], 0.29896, 0.05295, position, velocity))
         return false;
   }

   return (MathAbs(position - 101.68932923728812) <= 1.0e-9 &&
           MathAbs(velocity - 0.24001492360508736) <= 1.0e-9);
}

bool Strategy_ReconstructABState()
{
   g_ab_state_ready = false;
   g_ab_snapshot_valid = false;

   if(strategy_alpha <= 0.0 || strategy_alpha >= 1.0 ||
      strategy_beta <= 0.0 || strategy_beta >= 1.0)
      return false;

   const int warmup = MathMax(strategy_min_warmup_bars, 120);
   const int closed_bars = Bars(_Symbol, PERIOD_D1) - 1; // perf-allowed: one bounded reconstruction size read on the D1 refresh boundary.
   if(closed_bars < warmup || closed_bars > STRATEGY_MAX_RECONSTRUCTION_BARS)
      return false;

   MqlRates rates[];
   if(ArrayResize(rates, closed_bars) != closed_bars)
      return false;
   ArraySetAsSeries(rates, true);
   // perf-allowed: restart-only bounded reconstruction from the first available closed D1 bar.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, closed_bars, rates); // perf-allowed
   if(copied != closed_bars || ArraySize(rates) != closed_bars)
      return false;

   const int oldest = copied - 1;
   const double seed_close = rates[oldest].close;
   if(seed_close <= 0.0 || rates[0].time <= 0)
      return false;

   double position = seed_close;
   double velocity = 0.0;
   double previous_velocity = 0.0;
   int processed = 1;
   for(int i = oldest - 1; i >= 0; --i)
   {
      previous_velocity = velocity;
      if(!Strategy_ABStep(rates[i].close, strategy_alpha, strategy_beta, position, velocity))
         return false;
      ++processed;
   }

   g_ab_position = position;
   g_ab_velocity_previous = previous_velocity;
   g_ab_velocity = velocity;
   g_ab_last_closed_bar_time = rates[0].time;
   g_ab_processed_bars = processed;
   g_ab_state_ready = true;
   g_ab_snapshot_valid = (processed >= warmup);
   return true;
}

bool Strategy_AdvanceABState()
{
   if(!g_ab_state_ready || g_ab_last_closed_bar_time <= 0)
      return Strategy_ReconstructABState();

   const int last_shift = iBarShift(_Symbol, PERIOD_D1, g_ab_last_closed_bar_time, true); // perf-allowed: O(1) restart-safe D1 continuity lookup on the new-bar boundary.
   if(last_shift < 0)
      return Strategy_ReconstructABState();

   const int bars_to_process = last_shift - 1;
   if(bars_to_process <= 0)
      return g_ab_snapshot_valid;
   if(bars_to_process > STRATEGY_MAX_RECONSTRUCTION_BARS)
      return false;

   MqlRates rates[];
   if(ArrayResize(rates, bars_to_process) != bars_to_process)
      return false;
   ArraySetAsSeries(rates, true);
   // perf-allowed: bounded catch-up of only unseen completed D1 bars on the new-bar boundary.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, bars_to_process, rates); // perf-allowed
   if(copied != bars_to_process || ArraySize(rates) != bars_to_process)
      return false;

   for(int i = copied - 1; i >= 0; --i)
   {
      if(rates[i].time <= g_ab_last_closed_bar_time)
         return Strategy_ReconstructABState();
      g_ab_velocity_previous = g_ab_velocity;
      if(!Strategy_ABStep(rates[i].close, strategy_alpha, strategy_beta, g_ab_position, g_ab_velocity))
         return false;
      g_ab_last_closed_bar_time = rates[i].time;
      ++g_ab_processed_bars;
   }

   g_ab_snapshot_valid = (g_ab_processed_bars >= MathMax(strategy_min_warmup_bars, 120));
   return g_ab_snapshot_valid;
}

bool Strategy_RefreshABSnapshot()
{
   if(!g_ab_state_ready)
      return Strategy_ReconstructABState();
   return Strategy_AdvanceABState();
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(_Period != PERIOD_D1)
      return true;
   if(!g_ab_snapshot_valid || g_ab_processed_bars < MathMax(strategy_min_warmup_bars, 120))
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

   if(!g_ab_snapshot_valid)
      return false;

   if(g_ab_velocity_previous <= 0.0 && g_ab_velocity > 0.0)
   {
      req.type = QM_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl = QM_StopATR(_Symbol, QM_BUY, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "AA_AB_VELOCITY_ZERO_CROSS_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      return (req.sl > 0.0 && req.sl < req.price);
   }

   if(strategy_enable_shorts && g_ab_velocity_previous >= 0.0 && g_ab_velocity < 0.0)
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

   if(!g_ab_snapshot_valid)
      return false;

   if(current_pos == (int)POSITION_TYPE_BUY && g_ab_velocity < 0.0)
      return true;
   if(current_pos == (int)POSITION_TYPE_SELL && g_ab_velocity > 0.0)
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
   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "CARD_D1_WITH_V5_FRIDAY_CLOSE"))
      return INIT_FAILED;
   if(!Strategy_ABReferenceVectorPasses())
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;

   Strategy_ManageOpenPosition();

   const bool is_new_d1_bar = QM_IsNewBar(_Symbol, PERIOD_D1);
   if(is_new_d1_bar)
   {
      g_ab_snapshot_valid = Strategy_RefreshABSnapshot();
      QM_EquityStreamOnNewBar();
   }

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!is_new_d1_bar) return;

   // News, history, timeframe, and spread rules are entry-only gates.
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(Strategy_NoTradeFilter()) return;

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
