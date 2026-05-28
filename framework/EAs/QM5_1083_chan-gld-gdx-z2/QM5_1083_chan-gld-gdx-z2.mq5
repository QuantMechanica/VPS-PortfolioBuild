#property strict
#property version   "5.0"
#property description "QM5_1083 Chan GLD-GDX two-sigma spread proxy"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1083;
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
input int    strategy_pair_index         = 0;      // 0=XAU/XAG primary, 1=XAU/XTI alternative
input int    strategy_lookback_d1        = 100;
input double strategy_entry_z            = 2.0;
input double strategy_exit_z             = 0.0;
input double strategy_stop_z             = 4.0;
input int    strategy_min_half_life_bars = 2;
input int    strategy_max_half_life_bars = 60;
input double strategy_adf_t_max          = -1.30;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 4.0;
input int    strategy_max_spread_points  = 0;

#define STRATEGY_PAIR_COUNT 2

string g_pair_y[STRATEGY_PAIR_COUNT] = {"XAUUSD.DWX", "XAUUSD.DWX"};
string g_pair_x[STRATEGY_PAIR_COUNT] = {"XAGUSD.DWX", "XTIUSD.DWX"};
int    g_pair_y_slot[STRATEGY_PAIR_COUNT] = {0, 0};
int    g_pair_x_slot[STRATEGY_PAIR_COUNT] = {1, 2};

int      g_active_pair = -1;
double   g_beta = 1.0;
double   g_z_now = 0.0;
double   g_z_prev = 0.0;
double   g_half_life = 20.0;
bool     g_state_ready = false;

bool Strategy_HasDwxSuffix(const string symbol)
  {
   return (StringFind(symbol, ".DWX") == StringLen(symbol) - 4);
  }

bool Strategy_IsPairLeg(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   return (symbol == g_pair_y[pair_index] || symbol == g_pair_x[pair_index]);
  }

int Strategy_PairForHostSymbol(const string symbol)
  {
   if(symbol == g_pair_x[0])
      return 0;
   if(symbol == g_pair_x[1])
      return 1;
   if(symbol == g_pair_y[0])
      return MathMax(0, MathMin(STRATEGY_PAIR_COUNT - 1, strategy_pair_index));
   return -1;
  }

int Strategy_SlotForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return qm_magic_slot_offset;
   if(symbol == g_pair_y[pair_index])
      return g_pair_y_slot[pair_index];
   if(symbol == g_pair_x[pair_index])
      return g_pair_x_slot[pair_index];
   return qm_magic_slot_offset;
  }

bool Strategy_CopyPairCloses(const int pair_index, const int bars, double &y[], double &x[])
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || bars < 20)
      return false;

   ArraySetAsSeries(y, true);
   ArraySetAsSeries(x, true);
   SymbolSelect(g_pair_y[pair_index], true);
   SymbolSelect(g_pair_x[pair_index], true);
   // perf-allowed: this helper is called only after the D1 QM_IsNewBar gate.
   if(CopyClose(g_pair_y[pair_index], PERIOD_D1, 1, bars, y) != bars) // perf-allowed: called only after D1 new-bar gate.
      return false;
   if(CopyClose(g_pair_x[pair_index], PERIOD_D1, 1, bars, x) != bars) // perf-allowed: called only after D1 new-bar gate.
      return false;

   for(int i = 0; i < bars; ++i)
     {
      if(y[i] <= 0.0 || x[i] <= 0.0)
         return false;
     }
   return true;
  }

bool Strategy_EstimateBeta(const double &y[], const double &x[], const int bars, double &beta)
  {
   beta = 1.0;
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      sx += x[i];
      sy += y[i];
      sxx += x[i] * x[i];
      sxy += x[i] * y[i];
     }

   const double n = (double)bars;
   const double denom = n * sxx - sx * sx;
   if(MathAbs(denom) <= DBL_EPSILON)
      return false;

   beta = (n * sxy - sx * sy) / denom;
   return (MathIsValidNumber(beta) && MathAbs(beta) > 0.0001 && MathAbs(beta) < 10000.0);
  }

bool Strategy_BuildSpread(const double &y[], const double &x[], const int bars, const double beta, double &spread[])
  {
   ArrayResize(spread, bars);
   ArraySetAsSeries(spread, true);
   for(int i = 0; i < bars; ++i)
     {
      spread[i] = y[i] - beta * x[i];
      if(!MathIsValidNumber(spread[i]))
         return false;
     }
   return true;
  }

bool Strategy_ADFProxy(const double &spread[], const int bars, double &t_stat)
  {
   t_stat = 0.0;
   if(bars < 30)
      return false;

   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   int n = 0;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double lagged = spread[i + 1];
      const double delta = spread[i] - spread[i + 1];
      sx += lagged;
      sy += delta;
      sxx += lagged * lagged;
      sxy += lagged * delta;
      ++n;
     }

   const double denom = sxx - sx * sx / (double)n;
   if(denom <= DBL_EPSILON)
      return false;

   const double beta = (sxy - sx * sy / (double)n) / denom;
   const double alpha = (sy - beta * sx) / (double)n;
   double rss = 0.0;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double err = (spread[i] - spread[i + 1]) - alpha - beta * spread[i + 1];
      rss += err * err;
     }

   const double se = MathSqrt((rss / MathMax(1, n - 2)) / denom);
   if(se <= 0.0)
      return false;

   t_stat = beta / se;
   return MathIsValidNumber(t_stat);
  }

bool Strategy_HalfLife(const double &spread[], const int bars, double &half_life)
  {
   half_life = 20.0;
   if(bars < 30)
      return false;

   double mean = 0.0;
   for(int i = 0; i < bars; ++i)
      mean += spread[i];
   mean /= (double)bars;

   double num = 0.0, den = 0.0;
   for(int i = 0; i < bars - 1; ++i)
     {
      const double curr = spread[i] - mean;
      const double lag = spread[i + 1] - mean;
      num += curr * lag;
      den += lag * lag;
     }

   if(den <= DBL_EPSILON)
      return false;

   const double phi = num / den;
   if(!MathIsValidNumber(phi) || phi <= 0.0 || phi >= 1.0)
      return false;

   half_life = -MathLog(2.0) / MathLog(phi);
   return MathIsValidNumber(half_life);
  }

bool Strategy_ZScore(const double &spread[], const int lookback, double &z_now, double &z_prev)
  {
   z_now = 0.0;
   z_prev = 0.0;
   if(lookback < 20)
      return false;

   double mean = 0.0;
   for(int i = 1; i <= lookback; ++i)
      mean += spread[i];
   mean /= (double)lookback;

   double var = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double d = spread[i] - mean;
      var += d * d;
     }

   const double sd = MathSqrt(var / MathMax(1, lookback - 1));
   if(sd <= 0.0 || !MathIsValidNumber(sd))
      return false;

   z_now = (spread[0] - mean) / sd;
   z_prev = (spread[1] - mean) / sd;
   return (MathIsValidNumber(z_now) && MathIsValidNumber(z_prev));
  }

bool Strategy_SpreadsNormal(const int pair_index)
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const long y_spread = SymbolInfoInteger(g_pair_y[pair_index], SYMBOL_SPREAD);
   const long x_spread = SymbolInfoInteger(g_pair_x[pair_index], SYMBOL_SPREAD);
   return (y_spread > 0 && x_spread > 0 &&
           y_spread <= strategy_max_spread_points &&
           x_spread <= strategy_max_spread_points);
  }

bool Strategy_DataAllows(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   if(!Strategy_HasDwxSuffix(g_pair_y[pair_index]) || !Strategy_HasDwxSuffix(g_pair_x[pair_index]))
      return false;
   return Strategy_SpreadsNormal(pair_index);
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_active_pair = Strategy_PairForHostSymbol(_Symbol);
   if(!Strategy_DataAllows(g_active_pair))
      return false;

   const int lookback = MathMax(30, strategy_lookback_d1);
   const int bars = MathMax(lookback + 2, MathMax(strategy_max_half_life_bars + 20, 80));
   double y[];
   double x[];
   if(!Strategy_CopyPairCloses(g_active_pair, bars, y, x))
      return false;

   if(!Strategy_EstimateBeta(y, x, lookback, g_beta))
      return false;

   double spread[];
   if(!Strategy_BuildSpread(y, x, bars, g_beta, spread))
      return false;

   double adf_t = 0.0;
   if(!Strategy_ADFProxy(spread, lookback, adf_t))
      return false;
   if(adf_t > strategy_adf_t_max)
      return false;

   if(!Strategy_HalfLife(spread, lookback, g_half_life))
      return false;
   if(g_half_life < strategy_min_half_life_bars || g_half_life > strategy_max_half_life_bars)
      return false;

   if(!Strategy_ZScore(spread, lookback, g_z_now, g_z_prev))
      return false;

   g_state_ready = true;
   return true;
  }

bool Strategy_IsPairPosition(const int pair_index)
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   if(!Strategy_IsPairLeg(pair_index, symbol))
      return false;

   const int slot = Strategy_SlotForSymbol(pair_index, symbol);
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenPairLegCount(const int pair_index)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition(pair_index))
         ++count;
     }
   return count;
  }

datetime Strategy_PairOpenTime(const int pair_index)
  {
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition(pair_index))
         continue;
      const datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || t < oldest)
         oldest = t;
     }
   return oldest;
  }

int Strategy_BarsHeld(const int pair_index)
  {
   const datetime open_time = Strategy_PairOpenTime(pair_index);
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_D1, open_time, false);
   return (shift < 0) ? 0 : shift;
  }

void Strategy_ClosePair(const int pair_index, const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition(pair_index))
         QM_TM_ClosePosition(ticket, reason);
     }
  }

double Strategy_StopDistance(const string symbol)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return 0.0;
   return atr * strategy_atr_sl_mult;
  }

bool Strategy_OpenLeg(const int pair_index,
                      const string symbol,
                      const double weight,
                      const double weight_sum,
                      const int spread_direction,
                      const string reason)
  {
   const bool buy_leg = (spread_direction * weight) > 0.0;
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double stop_dist = Strategy_StopDistance(symbol);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || stop_dist <= 0.0 || point <= 0.0 || weight_sum <= 0.0)
      return false;

   QM_BasketOrderRequest breq;
   breq.symbol = symbol;
   breq.type = buy_leg ? QM_BUY : QM_SELL;
   breq.price = 0.0;
   breq.sl = buy_leg ? entry - stop_dist : entry + stop_dist;
   breq.tp = 0.0;
   breq.lots = QM_LotsForRisk(symbol, stop_dist / point) * MathAbs(weight) / weight_sum;
   breq.reason = reason;
   breq.symbol_slot = Strategy_SlotForSymbol(pair_index, symbol);
   breq.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, breq, ticket);
  }

bool Strategy_OpenPair(const int pair_index, const int spread_direction)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || spread_direction == 0)
      return false;
   if(Strategy_OpenPairLegCount(pair_index) > 0)
      return false;

   const double y_weight = 1.0;
   const double x_weight = -g_beta;
   const double weight_sum = MathAbs(y_weight) + MathAbs(x_weight);
   if(weight_sum <= 0.0)
      return false;

   const string reason = (spread_direction > 0) ? "QM5_1083_LONG_SPREAD_Z_LE_NEG2"
                                                : "QM5_1083_SHORT_SPREAD_Z_GE_POS2";

   bool opened = false;
   if(Strategy_OpenLeg(pair_index, g_pair_y[pair_index], y_weight, weight_sum, spread_direction, reason))
      opened = true;
   if(Strategy_OpenLeg(pair_index, g_pair_x[pair_index], x_weight, weight_sum, spread_direction, reason))
      opened = true;
   return opened;
  }

// No Trade Filter: timeframe, registered pair membership, spread sanity, DWX suffix.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int pair_index = Strategy_PairForHostSymbol(_Symbol);
   if(!Strategy_DataAllows(pair_index))
      return true;

   const int expected_slot = Strategy_SlotForSymbol(pair_index, _Symbol);
   if(qm_magic_slot_offset != expected_slot)
      return true;

   return false;
  }

// Trade Entry: Chan two-sigma spread entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1083_CHAN_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready || Strategy_OpenPairLegCount(g_active_pair) > 0)
      return false;

   if(g_z_now <= -MathAbs(strategy_entry_z))
      Strategy_OpenPair(g_active_pair, 1);
   else if(g_z_now >= MathAbs(strategy_entry_z))
      Strategy_OpenPair(g_active_pair, -1);

   return false;
  }

// Trade Management: no trailing, break-even, partial cover, add-on, or rebalance in the card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: zero-crossing, z-score stop, and 3x half-life timeout.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || Strategy_OpenPairLegCount(g_active_pair) <= 0)
      return false;

   if(MathAbs(g_z_now) >= MathAbs(strategy_stop_z))
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   if(strategy_exit_z <= 0.0)
     {
      if((g_z_prev < 0.0 && g_z_now >= 0.0) || (g_z_prev > 0.0 && g_z_now <= 0.0))
        {
         Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
         return false;
        }
     }
   else if(MathAbs(g_z_now) <= MathAbs(strategy_exit_z))
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   const int max_hold = MathMax(1, (int)MathCeil(3.0 * g_half_life));
   if(Strategy_BarsHeld(g_active_pair) >= max_hold)
      Strategy_ClosePair(g_active_pair, QM_EXIT_TIME_STOP);

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const int pair_index = Strategy_PairForHostSymbol(_Symbol);
   if(pair_index < 0)
      return false;

   string symbols[2] = {g_pair_y[pair_index], g_pair_x[pair_index]};
   for(int i = 0; i < 2; ++i)
     {
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbols[i], broker_time, qm_news_temporal, qm_news_compliance))
            return true;
        }
      else if(!QM_NewsAllowsTrade(symbols[i], broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      SymbolSelect(g_pair_y[i], true);
      SymbolSelect(g_pair_x[i], true);
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1083\",\"strategy\":\"chan-gld-gdx-z2\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();
   Strategy_RefreshState();
   Strategy_ManageOpenPosition();
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
