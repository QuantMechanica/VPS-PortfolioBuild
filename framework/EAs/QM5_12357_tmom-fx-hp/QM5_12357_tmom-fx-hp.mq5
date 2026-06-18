#property strict
#property version   "5.0"
#property description "QM5_12357 tmom-fx-hp"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12357;
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
input double strategy_hp_lambda          = 1600.0;
input int    strategy_hp_lookback        = 100;
input int    strategy_slope_lag          = 4;
input int    strategy_warmup_bars        = 130;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_min_deviation_pct  = 0.0;

int g_last_hp_signal = 0;

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool SolveHPTrend(const double &closes[], const int n, const double lambda, double &trend[])
  {
   if(n < 6 || lambda <= 0.0)
      return false;

   double a[];
   double b[];
   ArrayResize(a, n * n);
   ArrayResize(b, n);
   ArrayResize(trend, n);
   ArrayInitialize(a, 0.0);

   for(int i = 0; i < n; ++i)
     {
      const int row = i * n;
      b[i] = closes[i];

      double diag = 1.0 + 6.0 * lambda;
      if(i == 0 || i == n - 1)
         diag = 1.0 + lambda;
      else if(i == 1 || i == n - 2)
         diag = 1.0 + 5.0 * lambda;

      a[row + i] = diag;
      if(i + 1 < n)
        {
         const double off1 = (i == 0 || i == n - 2) ? -2.0 * lambda : -4.0 * lambda;
         a[row + i + 1] = off1;
         a[(i + 1) * n + i] = off1;
        }
      if(i + 2 < n)
        {
         a[row + i + 2] = lambda;
         a[(i + 2) * n + i] = lambda;
        }
     }

   for(int k = 0; k < n; ++k)
     {
      const int pivot_row = k * n;
      const double pivot = a[pivot_row + k];
      if(MathAbs(pivot) < 1.0e-12)
         return false;

      int last_col = k + 2;
      if(last_col >= n)
         last_col = n - 1;

      int last_row = k + 2;
      if(last_row >= n)
         last_row = n - 1;

      for(int i = k + 1; i <= last_row; ++i)
        {
         const int row = i * n;
         const double factor = a[row + k] / pivot;
         if(factor == 0.0)
            continue;

         a[row + k] = 0.0;
         for(int j = k + 1; j <= last_col; ++j)
            a[row + j] -= factor * a[pivot_row + j];
         b[i] -= factor * b[k];
        }
     }

   for(int i = n - 1; i >= 0; --i)
     {
      double sum = b[i];
      int last_col = i + 2;
      if(last_col >= n)
         last_col = n - 1;

      for(int j = i + 1; j <= last_col; ++j)
         sum -= a[i * n + j] * trend[j];

      const double diag = a[i * n + i];
      if(MathAbs(diag) < 1.0e-12)
         return false;
      trend[i] = sum / diag;
     }

   return true;
  }

bool CalculateHPTrendSignal(int &signal)
  {
   signal = 0;

   const int n = strategy_hp_lookback;
   if(n < 6 || strategy_slope_lag < 1 || strategy_slope_lag >= n)
      return false;

   int required = strategy_warmup_bars;
   if(required < n)
      required = n;

   MqlRates rates[];
   ArrayResize(rates, required);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, required, rates); // perf-allowed: card requires bounded HP close window on completed D1 bars.
   if(copied < required)
      return false;

   double closes[];
   double trend[];
   ArrayResize(closes, n);

   const int start = required - n;
   for(int i = 0; i < n; ++i)
     {
      const double close_i = rates[start + i].close;
      if(close_i <= 0.0)
         return false;
      closes[i] = close_i;
     }

   if(!SolveHPTrend(closes, n, strategy_hp_lambda, trend))
      return false;

   const double close_now = closes[n - 1];
   const double trend_now = trend[n - 1];
   const double trend_slope = trend[n - 1] - trend[n - 1 - strategy_slope_lag];
   if(trend_now == 0.0)
      return false;

   if(strategy_min_deviation_pct > 0.0)
     {
      const double deviation_pct = MathAbs(close_now - trend_now) / MathAbs(trend_now) * 100.0;
      if(deviation_pct < strategy_min_deviation_pct)
         return true;
     }

   if(trend_slope > 0.0 && close_now > trend_now)
      signal = 1;
   else if(trend_slope < 0.0 && close_now < trend_now)
      signal = -1;

   return true;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong current_ticket = PositionGetTicket(i);
      if(current_ticket == 0 || !PositionSelectByTicket(current_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = current_ticket;
      return true;
     }

   return false;
  }

bool ClosePositionsNotMatchingSignal(const int signal)
  {
   bool all_ok = true;
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool long_position = (position_type == POSITION_TYPE_BUY);
      const bool signal_still_matches = (signal > 0 && long_position) || (signal < 0 && !long_position);
      if(signal_still_matches)
         continue;

      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         all_ok = false;
     }

   return all_ok;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);

   int signal = 0;
   if(!CalculateHPTrendSignal(signal))
      return false;
   g_last_hp_signal = signal;

   if(!ClosePositionsNotMatchingSignal(signal))
      return false;
   if(signal == 0)
      return false;

   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   if(GetOurPosition(position_type, ticket))
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   const double entry_price = (req.type == QM_BUY) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (signal > 0) ? "HP_TREND_LONG" : "HP_TREND_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0)
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(g_last_hp_signal == 0)
      return false;

   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   if(!GetOurPosition(position_type, ticket))
      return false;

   const bool long_position = (position_type == POSITION_TYPE_BUY);
   if(long_position && g_last_hp_signal <= 0)
      return true;
   if(!long_position && g_last_hp_signal >= 0)
      return true;
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
