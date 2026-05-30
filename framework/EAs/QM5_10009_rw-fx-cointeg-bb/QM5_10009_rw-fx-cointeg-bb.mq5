#property strict
#property version   "5.0"
#property description "QM5_10009 Robot Wealth FX Cointegration Bollinger Bands"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10009;
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
input int    strategy_hedge_lookback       = 500;
input int    strategy_min_half_life_bars   = 5;
input int    strategy_max_half_life_bars   = 60;
input int    strategy_min_z_lookback       = 20;
input int    strategy_max_z_lookback       = 120;
input double strategy_entry_z              = 2.0;
input double strategy_exit_z               = 1.0;
input double strategy_emergency_z          = 4.0;
input int    strategy_max_hold_cap_bars    = 90;
input int    strategy_leg_stop_pips        = 250;

string  g_symbols[3] = {"AUDUSD.DWX", "NZDUSD.DWX", "USDCAD.DWX"};
int     g_slots[3] = {0, 1, 2};
double  g_weights[3] = {1.0, -1.0, -1.0};
double  g_spreads[600];
int     g_spread_count = 0;
int     g_current_month_key = -1;
int     g_z_lookback = 20;
double  g_half_life = 20.0;
double  g_current_z = 0.0;
int     g_signal_direction = 0;
bool    g_state_ready = false;
datetime g_entry_bar_time = 0;

int MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

double PipDistance(const string symbol, const int pips)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || pips <= 0)
      return 0.0;
   const double pip_points = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   return pips * pip_points * point;
  }

bool ReadCloses(double &aud[], double &nzd[], double &cad_inv[], const int bars)
  {
   if(bars < 50)
      return false;

   ArraySetAsSeries(aud, true);
   ArraySetAsSeries(nzd, true);
   ArraySetAsSeries(cad_inv, true);

   double cad_raw[];
   ArraySetAsSeries(cad_raw, true);
   if(CopyClose(g_symbols[0], PERIOD_D1, 1, bars, aud) != bars)
      return false;
   if(CopyClose(g_symbols[1], PERIOD_D1, 1, bars, nzd) != bars)
      return false;
   if(CopyClose(g_symbols[2], PERIOD_D1, 1, bars, cad_raw) != bars)
      return false;

   ArrayResize(cad_inv, bars);
   for(int i = 0; i < bars; ++i)
     {
      if(aud[i] <= 0.0 || nzd[i] <= 0.0 || cad_raw[i] <= 0.0)
         return false;
      cad_inv[i] = 1.0 / cad_raw[i];
     }
   return true;
  }

bool EstimateWeights(const double &aud[], const double &nzd[], const double &cad_inv[], const int bars)
  {
   double sx1 = 0.0, sx2 = 0.0, sy = 0.0;
   double sx1x1 = 0.0, sx2x2 = 0.0, sx1x2 = 0.0, sx1y = 0.0, sx2y = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double x1 = nzd[i];
      const double x2 = cad_inv[i];
      const double y = aud[i];
      sx1 += x1;
      sx2 += x2;
      sy += y;
      sx1x1 += x1 * x1;
      sx2x2 += x2 * x2;
      sx1x2 += x1 * x2;
      sx1y += x1 * y;
      sx2y += x2 * y;
     }

   const double n = (double)bars;
   const double a11 = sx1x1 - sx1 * sx1 / n;
   const double a22 = sx2x2 - sx2 * sx2 / n;
   const double a12 = sx1x2 - sx1 * sx2 / n;
   const double b1 = sx1y - sx1 * sy / n;
   const double b2 = sx2y - sx2 * sy / n;
   const double det = a11 * a22 - a12 * a12;
   if(MathAbs(det) < 1e-12)
      return false;

   const double beta1 = (b1 * a22 - b2 * a12) / det;
   const double beta2 = (a11 * b2 - a12 * b1) / det;
   if(!MathIsValidNumber(beta1) || !MathIsValidNumber(beta2) ||
      MathAbs(beta1) > 20.0 || MathAbs(beta2) > 20.0)
      return false;

   g_weights[0] = 1.0;
   g_weights[1] = -beta1;
   g_weights[2] = -beta2;
   return true;
  }

void BuildSpreadSeries(const double &aud[], const double &nzd[], const double &cad_inv[], const int bars)
  {
   g_spread_count = MathMin(bars, 600);
   for(int i = 0; i < g_spread_count; ++i)
      g_spreads[i] = g_weights[0] * aud[i] + g_weights[1] * nzd[i] + g_weights[2] * cad_inv[i];
  }

bool EstimateHalfLife()
  {
   const int bars = MathMin(g_spread_count, strategy_hedge_lookback);
   if(bars < 50)
      return false;

   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   int n = 0;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double lagged = g_spreads[i + 1];
      const double delta = g_spreads[i] - g_spreads[i + 1];
      sx += lagged;
      sy += delta;
      sxx += lagged * lagged;
      sxy += lagged * delta;
      ++n;
     }

   const double denom = sxx - sx * sx / (double)n;
   if(MathAbs(denom) < 1e-12)
      return false;

   const double beta = (sxy - sx * sy / (double)n) / denom;
   if(!MathIsValidNumber(beta) || beta >= 0.0)
      return false;

   g_half_life = -MathLog(2.0) / beta;
   if(!MathIsValidNumber(g_half_life))
      return false;
   return (g_half_life >= strategy_min_half_life_bars && g_half_life <= strategy_max_half_life_bars);
  }

bool ComputeZScore()
  {
   g_z_lookback = (int)MathRound(g_half_life);
   g_z_lookback = MathMax(strategy_min_z_lookback, MathMin(strategy_max_z_lookback, g_z_lookback));
   if(g_spread_count <= g_z_lookback)
      return false;

   double mean = 0.0;
   for(int i = 1; i <= g_z_lookback; ++i)
      mean += g_spreads[i];
   mean /= (double)g_z_lookback;

   double var = 0.0;
   for(int i = 1; i <= g_z_lookback; ++i)
     {
      const double d = g_spreads[i] - mean;
      var += d * d;
     }
   const double sd = MathSqrt(var / (double)(g_z_lookback - 1));
   if(sd <= 0.0 || !MathIsValidNumber(sd))
      return false;

   g_current_z = (g_spreads[0] - mean) / sd;
   return MathIsValidNumber(g_current_z);
  }

bool RefreshState()
  {
   for(int i = 0; i < 3; ++i)
      SymbolSelect(g_symbols[i], true);

   const int bars = MathMax(strategy_hedge_lookback + 5, strategy_max_z_lookback + 10);
   double aud[], nzd[], cad_inv[];
   if(!ReadCloses(aud, nzd, cad_inv, bars))
     {
      g_state_ready = false;
      return false;
     }

   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 1);
   const int month_key = MonthKey(bar_time);
   if(month_key != g_current_month_key)
     {
      if(!EstimateWeights(aud, nzd, cad_inv, strategy_hedge_lookback))
        {
         g_state_ready = false;
         return false;
        }
      g_current_month_key = month_key;
     }

   BuildSpreadSeries(aud, nzd, cad_inv, bars);
   if(!EstimateHalfLife() || !ComputeZScore())
     {
      g_state_ready = false;
      return false;
     }

   g_state_ready = true;
   return true;
  }

bool HasBasketPosition()
  {
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      for(int leg = 0; leg < 3; ++leg)
        {
         if(PositionGetString(POSITION_SYMBOL) == g_symbols[leg] &&
            (int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, g_slots[leg], g_symbols[leg]))
            return true;
        }
     }
   return false;
  }

int CloseBasket(const QM_ExitReason reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      for(int leg = 0; leg < 3; ++leg)
        {
         if(symbol == g_symbols[leg] &&
            (int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, g_slots[leg], g_symbols[leg]))
           {
            if(QM_TM_ClosePosition(ticket, reason))
               ++closed;
            break;
           }
        }
     }
   return closed;
  }

bool OpenBasket(const int signal_direction)
  {
   double sum_abs = 0.0;
   for(int leg = 0; leg < 3; ++leg)
      sum_abs += MathAbs(g_weights[leg]);
   if(sum_abs <= 0.0)
      return false;

   bool any_opened = false;
   for(int leg = 0; leg < 3; ++leg)
     {
      const string symbol = g_symbols[leg];
      const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0)
         continue;

      const bool buy_leg = (signal_direction * g_weights[leg] < 0.0);
      const double entry = buy_leg ? ask : bid;
      const double stop_dist = PipDistance(symbol, strategy_leg_stop_pips);
      if(stop_dist <= 0.0)
         continue;

      QM_BasketOrderRequest breq;
      breq.symbol = symbol;
      breq.type = buy_leg ? QM_BUY : QM_SELL;
      breq.price = 0.0;
      breq.sl = buy_leg ? entry - stop_dist : entry + stop_dist;
      breq.tp = 0.0;
      breq.symbol_slot = g_slots[leg];
      breq.expiration_seconds = 0;
      breq.reason = (signal_direction > 0) ? "RW_COINTEG_SHORT_POS_SPREAD" : "RW_COINTEG_LONG_NEG_SPREAD";

      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const double sl_points = (point > 0.0) ? stop_dist / point : 0.0;
      breq.lots = QM_LotsForRisk(symbol, sl_points) * MathAbs(g_weights[leg]) / sum_abs;

      ulong ticket = 0;
      if(QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, breq, ticket))
         any_opened = true;
     }

   if(any_opened)
      g_entry_bar_time = iTime(_Symbol, PERIOD_D1, 1);
   return any_opened;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_D1);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "RW_COINTEG_BASKET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!RefreshState() || HasBasketPosition())
      return false;

   g_signal_direction = 0;
   if(g_current_z >= strategy_entry_z)
      g_signal_direction = 1;
   else if(g_current_z <= -strategy_entry_z)
      g_signal_direction = -1;

   if(g_signal_direction == 0)
      return false;

   OpenBasket(g_signal_direction);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasBasketPosition())
      return false;

   if(MathAbs(g_current_z) <= strategy_exit_z)
     {
      CloseBasket(QM_EXIT_STRATEGY);
      return false;
     }

   if(MathAbs(g_current_z) >= strategy_emergency_z)
     {
      CloseBasket(QM_EXIT_STRATEGY);
      return false;
     }

   if(g_entry_bar_time > 0)
     {
      const datetime current_bar = iTime(_Symbol, PERIOD_D1, 1);
      const int max_hold = MathMin(strategy_max_hold_cap_bars, MathMax(1, (int)MathRound(3.0 * g_half_life)));
      const int held_seconds = (int)(current_bar - g_entry_bar_time);
      if(held_seconds >= max_hold * 86400)
        {
         CloseBasket(QM_EXIT_TIME_STOP);
         return false;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   for(int i = 0; i < 3; ++i)
     {
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(g_symbols[i], broker_time, qm_news_temporal, qm_news_compliance))
            return true;
        }
      else if(!QM_NewsAllowsTrade(g_symbols[i], broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < 3; ++i)
      SymbolSelect(g_symbols[i], true);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10009_rw_fx_cointeg_bb\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   Strategy_ManageOpenPosition();
   RefreshState();
   Strategy_ExitSignal();

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
