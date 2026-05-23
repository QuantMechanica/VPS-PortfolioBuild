#property strict
#property version   "5.0"
#property description "QM5_10009 Robot Wealth FX Cointegration Bollinger Bands"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10009;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_hedge_lookback_d1  = 500;
input int    strategy_min_z_lookback     = 20;
input int    strategy_max_z_lookback     = 120;
input double strategy_entry_z            = 2.0;
input double strategy_exit_z             = 1.0;
input double strategy_emergency_z        = 4.0;
input double strategy_min_half_life      = 5.0;
input double strategy_max_half_life      = 60.0;
input double strategy_time_stop_mult     = 3.0;
input int    strategy_time_stop_cap_d1   = 90;
input int    strategy_atr_period         = 20;
input double strategy_stop_excursion_mult = 1.5;
input int    strategy_max_spread_points  = 50;

#define QM10009_LEGS 3

string g_symbols[QM10009_LEGS] = {"AUDUSD.DWX", "NZDUSD.DWX", "USDCAD.DWX"};
double g_weights[QM10009_LEGS] = {1.0, -1.0, 1.0};
int    g_weight_month_key = 0;
bool   g_weight_valid = false;
double g_cached_z = 0.0;
double g_cached_half_life = 0.0;
double g_cached_stdev = 0.0;
bool   g_cached_state_valid = false;
bool   g_exit_state = false;

int SymbolSlotFor(const string symbol)
  {
   if(symbol == "AUDUSD.DWX") return 0;
   if(symbol == "NZDUSD.DWX") return 1;
   if(symbol == "USDCAD.DWX") return 2;
   return qm_magic_slot_offset;
  }

int SymbolIndex(const string symbol)
  {
   for(int i = 0; i < QM10009_LEGS; ++i)
      if(symbol == g_symbols[i])
         return i;
   return -1;
  }

double SpreadTermWeight(const int idx)
  {
   if(idx == 2)
      return -g_weights[idx]; // USDCAD is inverted to keep quote-currency direction consistent.
   return g_weights[idx];
  }

int SignOf(const double value)
  {
   if(value > 0.0) return 1;
   if(value < 0.0) return -1;
   return 0;
  }

int MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool LoadLogCloses(const string symbol, const int count, double &out[])
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, count, rates); // perf-allowed: called only from the closed-bar path after QM_IsNewBar().
   if(copied != count)
      return false;

   ArrayResize(out, count);
   for(int i = 0; i < count; ++i)
     {
      if(rates[i].close <= 0.0)
         return false;
      out[i] = MathLog(rates[i].close);
      if(!MathIsValidNumber(out[i]))
         return false;
     }
   return true;
  }

bool Invert3x3(const double &m[][3], double &inv[][3])
  {
   const double a = m[0][0], b = m[0][1], c = m[0][2];
   const double d = m[1][0], e = m[1][1], f = m[1][2];
   const double g = m[2][0], h = m[2][1], i = m[2][2];
   const double det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
   if(MathAbs(det) <= 1e-12 || !MathIsValidNumber(det))
      return false;

   inv[0][0] =  (e * i - f * h) / det;
   inv[0][1] = -(b * i - c * h) / det;
   inv[0][2] =  (b * f - c * e) / det;
   inv[1][0] = -(d * i - f * g) / det;
   inv[1][1] =  (a * i - c * g) / det;
   inv[1][2] = -(a * f - c * d) / det;
   inv[2][0] =  (d * h - e * g) / det;
   inv[2][1] = -(a * h - b * g) / det;
   inv[2][2] =  (a * e - b * d) / det;
   return true;
  }

bool EstimateMonthlyWeights()
  {
   const int n = MathMax(60, strategy_hedge_lookback_d1);
   double logs0[], logs1[], logs2[];
   if(!LoadLogCloses(g_symbols[0], n, logs0))
      return false;
   if(!LoadLogCloses(g_symbols[1], n, logs1))
      return false;
   if(!LoadLogCloses(g_symbols[2], n, logs2))
      return false;

   double mean[QM10009_LEGS] = {0.0, 0.0, 0.0};
   for(int k = 0; k < n; ++k)
     {
      mean[0] += logs0[k];
      mean[1] += logs1[k];
      mean[2] += -logs2[k];
     }
   for(int j = 0; j < QM10009_LEGS; ++j)
      mean[j] /= (double)n;

   double cov[3][3];
   ArrayInitialize(cov, 0.0);
   for(int k = 0; k < n; ++k)
     {
      const double x0 = logs0[k] - mean[0];
      const double x1 = logs1[k] - mean[1];
      const double x2 = -logs2[k] - mean[2];
      const double x[3] = {x0, x1, x2};
      for(int r = 0; r < 3; ++r)
         for(int c = 0; c < 3; ++c)
            cov[r][c] += x[r] * x[c];
     }
   for(int r = 0; r < 3; ++r)
      for(int c = 0; c < 3; ++c)
         cov[r][c] /= (double)MathMax(1, n - 1);

   cov[0][0] += 1e-10;
   cov[1][1] += 1e-10;
   cov[2][2] += 1e-10;

   double inv[3][3];
   ArrayInitialize(inv, 0.0);
   if(!Invert3x3(cov, inv))
      return false;

   double v[3] = {1.0, -1.0, 1.0};
   for(int iter = 0; iter < 12; ++iter)
     {
      double y[3] =
        {
         inv[0][0] * v[0] + inv[0][1] * v[1] + inv[0][2] * v[2],
         inv[1][0] * v[0] + inv[1][1] * v[1] + inv[1][2] * v[2],
         inv[2][0] * v[0] + inv[2][1] * v[1] + inv[2][2] * v[2]
        };
      const double norm = MathAbs(y[0]) + MathAbs(y[1]) + MathAbs(y[2]);
      if(norm <= 0.0 || !MathIsValidNumber(norm))
         return false;
      for(int j = 0; j < 3; ++j)
         v[j] = y[j] / norm;
     }

   if(v[0] < 0.0)
      for(int j = 0; j < 3; ++j)
         v[j] = -v[j];

   const double abs_sum = MathAbs(v[0]) + MathAbs(v[1]) + MathAbs(v[2]);
   if(abs_sum <= 0.0)
      return false;
   for(int j = 0; j < 3; ++j)
     {
      g_weights[j] = v[j] / abs_sum;
      if(!MathIsValidNumber(g_weights[j]) || MathAbs(g_weights[j]) <= 1e-8)
         return false;
     }
   g_weight_valid = true;
   return true;
  }

double SpreadAt(const double &logs0[], const double &logs1[], const double &logs2[], const int idx)
  {
   return g_weights[0] * logs0[idx] + g_weights[1] * logs1[idx] - g_weights[2] * logs2[idx];
  }

bool RefreshSpreadState()
  {
   g_cached_state_valid = false;
   g_exit_state = false;

   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 1);
   if(bar_time <= 0)
      return false;

   const int mk = MonthKey(bar_time);
   if(!g_weight_valid || mk != g_weight_month_key)
     {
      if(!EstimateMonthlyWeights())
         return false;
      g_weight_month_key = mk;
     }

   const int need = MathMax(strategy_hedge_lookback_d1, strategy_max_z_lookback + 5);
   double logs0[], logs1[], logs2[];
   if(!LoadLogCloses(g_symbols[0], need, logs0))
      return false;
   if(!LoadLogCloses(g_symbols[1], need, logs1))
      return false;
   if(!LoadLogCloses(g_symbols[2], need, logs2))
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   const int ar_n = MathMin(strategy_hedge_lookback_d1 - 1, need - 1);
   for(int i = 1; i <= ar_n; ++i)
     {
      const double prev = SpreadAt(logs0, logs1, logs2, i);
      const double curr = SpreadAt(logs0, logs1, logs2, i - 1);
      const double delta = curr - prev;
      sum_x += prev;
      sum_y += delta;
      sum_xx += prev * prev;
      sum_xy += prev * delta;
     }

   const double denom = (double)ar_n * sum_xx - sum_x * sum_x;
   if(denom <= 1e-12)
      return false;
   const double lambda = ((double)ar_n * sum_xy - sum_x * sum_y) / denom;
   if(lambda >= 0.0 || !MathIsValidNumber(lambda))
      return false;

   g_cached_half_life = -MathLog(2.0) / lambda;
   if(!MathIsValidNumber(g_cached_half_life) ||
      g_cached_half_life < strategy_min_half_life ||
      g_cached_half_life > strategy_max_half_life)
      return false;

   int z_n = (int)MathRound(g_cached_half_life);
   z_n = MathMax(strategy_min_z_lookback, MathMin(strategy_max_z_lookback, z_n));
   if(z_n + 1 > need)
      return false;

   double spread_sum = 0.0;
   double spread_sumsq = 0.0;
   for(int i = 0; i < z_n; ++i)
     {
      const double s = SpreadAt(logs0, logs1, logs2, i);
      spread_sum += s;
      spread_sumsq += s * s;
     }

   const double mean = spread_sum / (double)z_n;
   const double var = (spread_sumsq / (double)z_n) - mean * mean;
   if(var <= 0.0)
      return false;

   g_cached_stdev = MathSqrt(var);
   g_cached_z = (SpreadAt(logs0, logs1, logs2, 0) - mean) / g_cached_stdev;
   g_cached_state_valid = MathIsValidNumber(g_cached_z);
   return g_cached_state_valid;
  }

bool HasOpenPosition(ulong &ticket, datetime &open_time)
  {
   ticket = 0;
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int HeldD1Bars(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_D1, open_time, false);
   return (shift < 0) ? 0 : shift;
  }

double StopDistanceForLeg(const int idx, const double entry_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double term_weight = MathAbs(SpreadTermWeight(idx));
   double log_dist = 0.0;
   if(term_weight > 0.0 && g_cached_stdev > 0.0)
      log_dist = strategy_stop_excursion_mult * MathAbs(strategy_entry_z) * g_cached_stdev / term_weight;

   double price_dist = (log_dist > 0.0 && entry_price > 0.0) ? entry_price * (MathExp(log_dist) - 1.0) : 0.0;
   if(atr > 0.0)
      price_dist = MathMax(price_dist, atr);
   if(point > 0.0)
      price_dist = MathMax(price_dist, 50.0 * point);
   return price_dist;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(SymbolIndex(_Symbol) < 0)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
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
   req.symbol_slot = SymbolSlotFor(_Symbol);
   req.expiration_seconds = 0;

   ulong ticket;
   datetime open_time;
   if(HasOpenPosition(ticket, open_time))
      return false;

   if(!RefreshSpreadState())
      return false;

   int spread_direction = 0;
   if(g_cached_z >= strategy_entry_z)
      spread_direction = -1;
   else if(g_cached_z <= -strategy_entry_z)
      spread_direction = 1;
   else
      return false;

   const int idx = SymbolIndex(_Symbol);
   const int leg_sign = SignOf(SpreadTermWeight(idx));
   if(leg_sign == 0)
      return false;

   const int leg_direction = spread_direction * leg_sign;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(leg_direction > 0)
     {
      req.type = QM_BUY;
      req.price = ask;
      const double stop_dist = StopDistanceForLeg(idx, ask);
      if(stop_dist <= 0.0)
         return false;
      req.sl = ask - stop_dist;
      req.reason = "RW_FX_COINTEG_BB_LONG_LEG";
     }
   else
     {
      req.type = QM_SELL;
      req.price = bid;
      const double stop_dist = StopDistanceForLeg(idx, bid);
      if(stop_dist <= 0.0)
         return false;
      req.sl = bid + stop_dist;
      req.reason = "RW_FX_COINTEG_BB_SHORT_LEG";
     }

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies basket-level exits only; no trailing, partial, break-even, or add-on logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket;
   datetime open_time;
   if(!HasOpenPosition(ticket, open_time))
      return false;

   if(!RefreshSpreadState())
      return false;

   if(MathAbs(g_cached_z) <= strategy_exit_z)
      return true;
   if(MathAbs(g_cached_z) >= strategy_emergency_z)
      return true;

   const int max_bars = MathMin(strategy_time_stop_cap_d1,
                                (int)MathCeil(strategy_time_stop_mult * g_cached_half_life));
   if(max_bars > 0 && HeldD1Bars(open_time) >= max_bars)
      return true;

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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   for(int i = 0; i < QM10009_LEGS; ++i)
      SymbolSelect(g_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10009\",\"strategy\":\"rw-fx-cointeg-bb\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   if(Strategy_ExitSignal())
     {
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      return;
     }

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
