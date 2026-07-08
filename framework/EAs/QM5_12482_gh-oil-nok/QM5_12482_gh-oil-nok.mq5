#property strict
#property version   "5.0"
#property description "QM5_12482 Oil FX Residual Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12482 - GitHub Oil/NOK residual reversion, DWX port
// -----------------------------------------------------------------------------
// Original source regresses a NOK price series on Brent and trades residual
// extremes. Darwinex .DWX lacks USDNOK and XBRUSD in the current matrix, so this
// build uses the card-approved available port:
//   y = USDJPY.DWX traded leg
//   x = XTIUSD.DWX oil signal input
// The EA trades only USDJPY; oil is read as a signal series.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12482;
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
input int    strategy_train_len_d1      = 50;
input double strategy_r2_min            = 0.70;
input double strategy_entry_sigma       = 2.0;
input int    strategy_max_hold_days     = 10;
input double strategy_source_move_exit  = 0.50;
input int    strategy_atr_period_d1     = 20;
input double strategy_atr_sl_mult       = 2.5;
input int    strategy_usdjpy_max_spread_pts = 120;

string g_trade_symbol = "USDJPY.DWX";
string g_oil_symbol   = "XTIUSD.DWX";

double g_alpha = 0.0;
double g_beta = 0.0;
double g_r2 = 0.0;
double g_residual = 0.0;
double g_residual_sigma = 0.0;
bool   g_model_ready = false;
bool   g_has_last_accepted_beta = false;
double g_last_accepted_beta = 0.0;

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_trade_symbol && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed()
  {
   const long spread_points = SymbolInfoInteger(g_trade_symbol, SYMBOL_SPREAD);
   return (strategy_usdjpy_max_spread_pts <= 0 || spread_points <= strategy_usdjpy_max_spread_pts);
  }

bool Strategy_IsMine()
  {
   if(PositionGetString(POSITION_SYMBOL) != g_trade_symbol)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

int Strategy_OpenPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsMine())
         ++count;
     }
   return count;
  }

bool Strategy_BetaSignFlip(const double beta)
  {
   if(!g_has_last_accepted_beta)
      return false;
   if(beta == 0.0 || g_last_accepted_beta == 0.0)
      return false;
   return ((beta > 0.0 && g_last_accepted_beta < 0.0) ||
           (beta < 0.0 && g_last_accepted_beta > 0.0));
  }

bool Strategy_RefreshModel()
  {
   g_model_ready = false;
   const int lookback = MathMax(20, strategy_train_len_d1);

   double x[];
   double y[];
   ArraySetAsSeries(x, true);
   ArraySetAsSeries(y, true);
   if(CopyClose(g_oil_symbol, PERIOD_D1, 1, lookback, x) != lookback) // perf-allowed: entry path is called once per D1 closed bar.
      return false;
   if(CopyClose(g_trade_symbol, PERIOD_D1, 1, lookback, y) != lookback) // perf-allowed: entry path is called once per D1 closed bar.
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      if(x[i] <= 0.0 || y[i] <= 0.0)
         return false;
      sum_x += x[i];
      sum_y += y[i];
     }

   const double mean_x = sum_x / (double)lookback;
   const double mean_y = sum_y / (double)lookback;

   double ss_x = 0.0;
   double ss_y = 0.0;
   double ss_xy = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double dx = x[i] - mean_x;
      const double dy = y[i] - mean_y;
      ss_x += dx * dx;
      ss_y += dy * dy;
      ss_xy += dx * dy;
     }

   if(ss_x <= 0.0 || ss_y <= 0.0)
      return false;

   const double beta = ss_xy / ss_x;
   const double alpha = mean_y - beta * mean_x;
   const double r2 = (ss_xy * ss_xy) / (ss_x * ss_y);
   if(!MathIsValidNumber(beta) || !MathIsValidNumber(alpha) || !MathIsValidNumber(r2))
      return false;
   if(r2 < strategy_r2_min)
      return false;
   if(Strategy_BetaSignFlip(beta))
      return false;

   double resid_sum_sq = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double fitted = alpha + beta * x[i];
      const double resid = y[i] - fitted;
      resid_sum_sq += resid * resid;
     }

   const double sigma = MathSqrt(resid_sum_sq / (double)MathMax(1, lookback - 2));
   if(sigma <= 0.0 || !MathIsValidNumber(sigma))
      return false;

   g_alpha = alpha;
   g_beta = beta;
   g_r2 = r2;
   g_residual = y[0] - (alpha + beta * x[0]);
   g_residual_sigma = sigma;
   g_model_ready = MathIsValidNumber(g_residual);
   if(g_model_ready)
     {
      g_last_accepted_beta = beta;
      g_has_last_accepted_beta = true;
     }
   return g_model_ready;
  }

bool Strategy_BuildEntryRequest(const QM_OrderType type,
                                const string reason,
                                QM_EntryRequest &req)
  {
   if(!Strategy_SpreadAllowed())
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(g_trade_symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(g_trade_symbol, SYMBOL_BID);
   const double atr = QM_ATR(g_trade_symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(g_trade_symbol, SYMBOL_DIGITS);
   const double atr_stop_dist = strategy_atr_sl_mult * atr;
   const double source_stop_dist = MathMax(0.01, strategy_source_move_exit);
   const double stop_dist = MathMin(source_stop_dist, atr_stop_dist);

   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry - stop_dist, digits)
                                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry + source_stop_dist, digits)
                                    : NormalizeDouble(entry - source_stop_dist, digits);
   req.reason = reason;
   req.symbol_slot = 0;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_train_len_d1 < 20)
      return true;
   if(strategy_r2_min <= 0.0 || strategy_r2_min > 1.0)
      return true;
   if(strategy_entry_sigma <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   if(strategy_source_move_exit <= 0.0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(Strategy_OpenPositionCount() > 0)
      return false;
   if(!Strategy_RefreshModel())
      return false;

   const double threshold = strategy_entry_sigma * g_residual_sigma;
   if(g_residual < -threshold)
      return Strategy_BuildEntryRequest(QM_BUY, "QM5_12482_USDJPY_CHEAP_VS_OIL", req);
   if(g_residual > threshold)
      return Strategy_BuildEntryRequest(QM_SELL, "QM5_12482_USDJPY_RICH_VS_OIL", req);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, grid, or averaging.
  }

bool Strategy_ExitSignal()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsMine())
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const long type = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_price = (type == POSITION_TYPE_BUY)
                                   ? SymbolInfoDouble(g_trade_symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(g_trade_symbol, SYMBOL_ASK);

      if(opened > 0 && TimeCurrent() - opened >= (long)MathMax(1, strategy_max_hold_days) * 86400)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
        }
      if(open_price > 0.0 && current_price > 0.0 &&
         MathAbs(current_price - open_price) >= strategy_source_move_exit)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_trade_symbol, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_oil_symbol, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_trade_symbol, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_oil_symbol, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   SymbolSelect(g_trade_symbol, true);
   SymbolSelect(g_oil_symbol, true);

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

   string allowed[2] = {g_trade_symbol, g_oil_symbol};
   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_D1, MathMax(180, strategy_train_len_d1 + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12482\",\"ea\":\"gh-oil-nok\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || Strategy_NewsFilterHook(broker_now))
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
