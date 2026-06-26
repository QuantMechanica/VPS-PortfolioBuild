#property strict
#property version   "5.0"
#property description "QM5_9184 JSTM pair cointegration FX"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9184;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_D1;
input int    strategy_lookback_bars            = 250;
input double strategy_entry_z                  = 1.0;
input double strategy_exit_abs_z               = 0.25;
input double strategy_stop_abs_z               = 3.0;
input double strategy_adf_t_critical           = -2.86;
input int    strategy_time_stop_bars           = 60;
input int    strategy_sizing_pips              = 200;
input int    strategy_max_spread_points        = 50;
input double strategy_max_spread_cost_fraction = 0.50;
input double strategy_beta_min                 = 0.10;
input double strategy_beta_max                 = 5.00;
input int    strategy_deviation_points         = 20;

string   g_pair_a = "AUDUSD.DWX";
string   g_pair_b = "NZDUSD.DWX";
int      g_slot_a = 0;
int      g_slot_b = 1;
double   g_alpha = 0.0;
double   g_beta = 1.0;
double   g_residual_mean = 0.0;
double   g_residual_sd = 0.0;
double   g_current_z = 0.0;
double   g_current_adf_t = 0.0;
bool     g_state_ready = false;

bool HostSymbolAllowed()
  {
   return (_Symbol == g_pair_a || _Symbol == g_pair_b);
  }

int SlotForSymbol(const string symbol)
  {
   if(symbol == g_pair_a)
      return g_slot_a;
   if(symbol == g_pair_b)
      return g_slot_b;
   return -1;
  }

double MidPrice(const string symbol)
  {
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
      return (bid + ask) * 0.5;
   if(bid > 0.0)
      return bid;
   if(ask > 0.0)
      return ask;
   return 0.0;
  }

bool LoadLogCloses(const string symbol, double &out[], const int bars)
  {
   if(bars < 30)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, strategy_signal_tf, 1, bars, closes); // perf-allowed: D1 pair state runs behind the framework QM_IsNewBar gate.
   if(copied != bars)
      return false;

   ArrayResize(out, bars);
   ArraySetAsSeries(out, true);
   for(int i = 0; i < bars; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      out[i] = MathLog(closes[i]);
     }
   return true;
  }

bool EstimateOls(const double &x[], const double &y[], const int bars, double &alpha, double &beta)
  {
   double sx = 0.0;
   double sy = 0.0;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      sx += x[i];
      sy += y[i];
      sxx += x[i] * x[i];
      sxy += x[i] * y[i];
     }

   const double n = (double)bars;
   const double denom = sxx - sx * sx / n;
   if(MathAbs(denom) < 1e-12)
      return false;

   beta = (sxy - sx * sy / n) / denom;
   alpha = sy / n - beta * sx / n;
   return (MathIsValidNumber(alpha) &&
           MathIsValidNumber(beta) &&
           MathAbs(beta) >= strategy_beta_min &&
           MathAbs(beta) <= strategy_beta_max);
  }

bool BuildResidualState(const double &x[], const double &y[], const int bars)
  {
   double residuals[];
   ArrayResize(residuals, bars);
   ArraySetAsSeries(residuals, true);

   for(int i = 0; i < bars; ++i)
      residuals[i] = y[i] - g_alpha - g_beta * x[i];

   g_residual_mean = 0.0;
   for(int i = 0; i < bars; ++i)
      g_residual_mean += residuals[i];
   g_residual_mean /= (double)bars;

   double var = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double d = residuals[i] - g_residual_mean;
      var += d * d;
     }

   g_residual_sd = MathSqrt(var / (double)MathMax(1, bars - 1));
   if(g_residual_sd <= 0.0 || !MathIsValidNumber(g_residual_sd))
      return false;

   g_current_z = (residuals[0] - g_residual_mean) / g_residual_sd;
   if(!MathIsValidNumber(g_current_z))
      return false;

   double sx = 0.0;
   double sy = 0.0;
   double sxx = 0.0;
   double sxy = 0.0;
   int n = 0;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double lagged = residuals[i + 1];
      const double delta = residuals[i] - residuals[i + 1];
      sx += lagged;
      sy += delta;
      sxx += lagged * lagged;
      sxy += lagged * delta;
      ++n;
     }

   const double dn = (double)n;
   const double denom = sxx - sx * sx / dn;
   if(MathAbs(denom) < 1e-12 || n <= 2)
      return false;

   const double slope = (sxy - sx * sy / dn) / denom;
   const double intercept = sy / dn - slope * sx / dn;
   double sse = 0.0;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double lagged = residuals[i + 1];
      const double delta = residuals[i] - residuals[i + 1];
      const double err = delta - (intercept + slope * lagged);
      sse += err * err;
     }

   const double se = MathSqrt((sse / (double)(n - 2)) / denom);
   if(se <= 0.0)
      return false;

   g_current_adf_t = slope / se;
   return MathIsValidNumber(g_current_adf_t);
  }

bool RefreshPairState()
  {
   const int bars = MathMax(30, strategy_lookback_bars);
   double log_a[];
   double log_b[];
   if(!LoadLogCloses(g_pair_a, log_a, bars) || !LoadLogCloses(g_pair_b, log_b, bars))
     {
      g_state_ready = false;
      return false;
     }

   if(!EstimateOls(log_a, log_b, bars, g_alpha, g_beta))
     {
      g_state_ready = false;
      return false;
     }

   g_state_ready = BuildResidualState(log_a, log_b, bars);
   return g_state_ready;
  }

bool HasPositionForSymbolSlot(const string symbol, const int slot)
  {
   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool PairHasOpenPosition()
  {
   return HasPositionForSymbolSlot(g_pair_a, g_slot_a) ||
          HasPositionForSymbolSlot(g_pair_b, g_slot_b);
  }

bool ClosePositionForSymbolSlot(const string symbol, const int slot, const QM_ExitReason reason)
  {
   bool closed_any = false;
   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         closed_any = true;
     }
   return closed_any;
  }

bool ClosePairPositions(const QM_ExitReason reason)
  {
   bool closed_any = false;
   if(ClosePositionForSymbolSlot(g_pair_a, g_slot_a, reason))
      closed_any = true;
   if(ClosePositionForSymbolSlot(g_pair_b, g_slot_b, reason))
      closed_any = true;
   return closed_any;
  }

bool PairTimeStopExceeded()
  {
   const long max_seconds = (long)strategy_time_stop_bars * (long)PeriodSeconds(strategy_signal_tf);
   if(max_seconds <= 0)
      return false;

   const string symbols[2] = {g_pair_a, g_pair_b};
   const int slots[2] = {g_slot_a, g_slot_b};
   const datetime now = TimeCurrent();
   for(int leg = 0; leg < 2; ++leg)
     {
      const int magic = QM_MagicChecked(qm_ea_id, slots[leg], symbols[leg]);
      if(magic <= 0)
         continue;

      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbols[leg])
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened > 0 && now - opened >= max_seconds)
            return true;
        }
     }
   return false;
  }

double SizingLots(const string symbol, const double leg_scale)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double price_distance = QM_StopRulesPipsToPriceDistance(symbol, strategy_sizing_pips);
   if(point <= 0.0 || price_distance <= 0.0 || leg_scale <= 0.0)
      return 0.0;

   const double sl_points = price_distance / point;
   const double lots = QM_LotsForRisk(symbol, sl_points) * leg_scale * 0.5;
   return QM_TM_NormalizeVolume(symbol, lots);
  }

bool SpreadCostAllowsEntry()
  {
   const double bid_a = SymbolInfoDouble(g_pair_a, SYMBOL_BID);
   const double ask_a = SymbolInfoDouble(g_pair_a, SYMBOL_ASK);
   const double bid_b = SymbolInfoDouble(g_pair_b, SYMBOL_BID);
   const double ask_b = SymbolInfoDouble(g_pair_b, SYMBOL_ASK);
   const double mid_a = MidPrice(g_pair_a);
   const double mid_b = MidPrice(g_pair_b);
   if(bid_a <= 0.0 || ask_a <= 0.0 || bid_b <= 0.0 || ask_b <= 0.0 || mid_a <= 0.0 || mid_b <= 0.0)
      return false;

   double cost = 0.0;
   if(ask_a > bid_a)
      cost += (ask_a - bid_a) / mid_a;
   if(ask_b > bid_b)
      cost += MathAbs(g_beta) * (ask_b - bid_b) / mid_b;

   const double expected_revert = MathAbs(g_current_z) * g_residual_sd;
   if(expected_revert <= 0.0)
      return false;

   return (cost <= strategy_max_spread_cost_fraction * expected_revert);
  }

bool OpenPair(const int direction)
  {
   if(direction == 0 || PairHasOpenPosition())
      return false;

   const double lots_a = SizingLots(g_pair_a, 1.0);
   const double lots_b = SizingLots(g_pair_b, MathAbs(g_beta));
   if(lots_a <= 0.0 || lots_b <= 0.0)
      return false;

   QM_BasketOrderRequest req_a;
   req_a.symbol = g_pair_a;
   req_a.type = (direction > 0) ? QM_BUY : QM_SELL;
   req_a.price = 0.0;
   req_a.sl = 0.0;
   req_a.tp = 0.0;
   req_a.lots = lots_a;
   req_a.reason = (direction > 0) ? "JSTM_LONG_SPREAD_A" : "JSTM_SHORT_SPREAD_A";
   req_a.symbol_slot = g_slot_a;
   req_a.expiration_seconds = 0;

   QM_BasketOrderRequest req_b;
   req_b.symbol = g_pair_b;
   req_b.type = (direction > 0) ? QM_SELL : QM_BUY;
   req_b.price = 0.0;
   req_b.sl = 0.0;
   req_b.tp = 0.0;
   req_b.lots = lots_b;
   req_b.reason = (direction > 0) ? "JSTM_LONG_SPREAD_B" : "JSTM_SHORT_SPREAD_B";
   req_b.symbol_slot = g_slot_b;
   req_b.expiration_seconds = 0;

   ulong ticket_a = 0;
   ulong ticket_b = 0;
   const bool opened_a = QM_BasketOpenPosition(qm_ea_id, QM_NEWS_OFF, strategy_deviation_points, req_a, ticket_a);
   const bool opened_b = opened_a ? QM_BasketOpenPosition(qm_ea_id, QM_NEWS_OFF, strategy_deviation_points, req_b, ticket_b) : false;
   if(opened_a && !opened_b)
      ClosePositionForSymbolSlot(g_pair_a, g_slot_a, QM_EXIT_STRATEGY);
   return (opened_a && opened_b);
  }

bool PairNewsBlocked(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_pair_a, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_pair_b, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_pair_a, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_pair_b, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!HostSymbolAllowed())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid && strategy_max_spread_points > 0)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > strategy_max_spread_points)
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
   req.reason = "JSTM_PAIR_HOST";
   req.symbol_slot = SlotForSymbol(_Symbol);
   req.expiration_seconds = 0;

   if(req.symbol_slot < 0)
      return false;
   if(PairHasOpenPosition())
      return false;
   if(!RefreshPairState())
      return false;
   if(g_current_adf_t > strategy_adf_t_critical)
      return false;
   if(!SpreadCostAllowsEntry())
      return false;

   int direction = 0;
   if(g_current_z < -strategy_entry_z)
      direction = 1;
   else if(g_current_z > strategy_entry_z)
      direction = -1;

   if(direction == 0)
      return false;

   OpenPair(direction);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HostSymbolAllowed() || !PairHasOpenPosition())
      return false;

   RefreshPairState();
   if(PairTimeStopExceeded())
     {
      ClosePairPositions(QM_EXIT_TIME_STOP);
      return false;
     }

   if(!g_state_ready)
      return false;

   const double abs_z = MathAbs(g_current_z);
   if(abs_z < strategy_exit_abs_z)
     {
      ClosePairPositions(QM_EXIT_STRATEGY);
      return false;
     }
   if(abs_z > strategy_stop_abs_z)
     {
      ClosePairPositions(QM_EXIT_STRATEGY);
      return false;
     }
   if(g_current_adf_t > strategy_adf_t_critical)
     {
      ClosePairPositions(QM_EXIT_STRATEGY);
      return false;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!HostSymbolAllowed())
      return true;
   return PairNewsBlocked(broker_time);
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

   string symbols[2];
   symbols[0] = g_pair_a;
   symbols[1] = g_pair_b;
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, strategy_signal_tf, strategy_lookback_bars + 5);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9184\",\"strategy\":\"jstm_pair_cointegration_fx\"}");
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
   Strategy_ExitSignal();

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
