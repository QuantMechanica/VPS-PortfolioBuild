#property strict
#property version   "5.0"
#property description "QM5_1058 Gatev FX pairs z-score reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1058;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_lookback_bars      = 60;
input double strategy_entry_z            = 2.0;
input double strategy_exit_z             = 0.5;
input double strategy_hard_stop_z        = 4.0;
input double strategy_min_corr           = 0.6;
input int    strategy_time_stop_bars     = 20;
input int    strategy_max_spread_points  = 50;

#define STRATEGY_PAIR_COUNT 2

string g_pair_a[STRATEGY_PAIR_COUNT] = {"EURUSD.DWX", "AUDUSD.DWX"};
string g_pair_b[STRATEGY_PAIR_COUNT] = {"GBPUSD.DWX", "NZDUSD.DWX"};
int    g_pair_slot_a[STRATEGY_PAIR_COUNT] = {0, 2};
int    g_pair_slot_b[STRATEGY_PAIR_COUNT] = {1, 3};

int      g_active_pair = -1;
double   g_beta = 1.0;
double   g_z_now = 0.0;
double   g_corr_now = 0.0;
bool     g_state_ready = false;

int Strategy_PairForHostSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      if(symbol == g_pair_a[i] || symbol == g_pair_b[i])
         return i;
     }
   return -1;
  }

bool Strategy_IsPairLeg(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   return (symbol == g_pair_a[pair_index] || symbol == g_pair_b[pair_index]);
  }

int Strategy_SlotForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return qm_magic_slot_offset;
   if(symbol == g_pair_a[pair_index])
      return g_pair_slot_a[pair_index];
   if(symbol == g_pair_b[pair_index])
      return g_pair_slot_b[pair_index];
   return qm_magic_slot_offset;
  }

bool Strategy_CopyLogCloses(const string symbol, const int bars, double &logs[])
  {
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   ArrayResize(logs, bars);
   ArraySetAsSeries(logs, true);

   double closes[];
   ArrayResize(closes, bars);
   ArraySetAsSeries(closes, true);
   if(CopyClose(symbol, PERIOD_D1, 1, bars, closes) != bars) // perf-allowed: this custom pair-stat read is called only after a D1 QM_IsNewBar gate.
      return false;

   for(int i = 0; i < bars; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      logs[i] = MathLog(closes[i]);
      if(!MathIsValidNumber(logs[i]))
         return false;
     }
   return true;
  }

bool Strategy_EstimateBeta(const double &log_a[], const double &log_b[], const int n, double &beta)
  {
   beta = 1.0;
   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;

   for(int i = 0; i < n; ++i)
     {
      const double x = log_b[i];
      const double y = log_a[i];
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double dn = (double)n;
   const double denom = dn * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) <= DBL_EPSILON)
      return false;

   beta = (dn * sum_xy - sum_x * sum_y) / denom;
   return (MathIsValidNumber(beta) && MathAbs(beta) > 0.0001 && MathAbs(beta) < 100.0);
  }

bool Strategy_ZScore(const double &log_a[], const double &log_b[], const int n, const double beta, double &z)
  {
   z = 0.0;
   double spread[];
   ArrayResize(spread, n);
   ArraySetAsSeries(spread, true);

   double mean = 0.0;
   for(int i = 0; i < n; ++i)
     {
      spread[i] = log_a[i] - beta * log_b[i];
      if(!MathIsValidNumber(spread[i]))
         return false;
      mean += spread[i];
     }
   mean /= (double)n;

   double variance = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double d = spread[i] - mean;
      variance += d * d;
     }

   const double sd = MathSqrt(variance / MathMax(1, n - 1));
   if(sd <= 0.0 || !MathIsValidNumber(sd))
      return false;

   z = (spread[0] - mean) / sd;
   return MathIsValidNumber(z);
  }

bool Strategy_ReturnCorrelation(const double &log_a[], const double &log_b[], const int n, double &corr)
  {
   corr = 0.0;
   double sum_a = 0.0;
   double sum_b = 0.0;
   double sum_aa = 0.0;
   double sum_bb = 0.0;
   double sum_ab = 0.0;

   for(int i = 0; i < n; ++i)
     {
      const double ra = log_a[i] - log_a[i + 1];
      const double rb = log_b[i] - log_b[i + 1];
      sum_a += ra;
      sum_b += rb;
      sum_aa += ra * ra;
      sum_bb += rb * rb;
      sum_ab += ra * rb;
     }

   const double dn = (double)n;
   const double denom = MathSqrt((dn * sum_aa - sum_a * sum_a) *
                                 (dn * sum_bb - sum_b * sum_b));
   if(denom <= DBL_EPSILON)
      return false;

   corr = (dn * sum_ab - sum_a * sum_b) / denom;
   return MathIsValidNumber(corr);
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_active_pair = Strategy_PairForHostSymbol(_Symbol);
   if(g_active_pair < 0)
      return false;

   const int n = MathMax(20, strategy_lookback_bars);
   const int bars = n + 1;
   double log_a[];
   double log_b[];
   if(!Strategy_CopyLogCloses(g_pair_a[g_active_pair], bars, log_a))
      return false;
   if(!Strategy_CopyLogCloses(g_pair_b[g_active_pair], bars, log_b))
      return false;

   if(!Strategy_EstimateBeta(log_a, log_b, n, g_beta))
      return false;
   if(!Strategy_ZScore(log_a, log_b, n, g_beta, g_z_now))
      return false;
   if(!Strategy_ReturnCorrelation(log_a, log_b, n, g_corr_now))
      return false;

   g_state_ready = true;
   return true;
  }

bool Strategy_SpreadsNormal(const int pair_index)
  {
   if(strategy_max_spread_points <= 0)
      return true;
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const long spread_a = SymbolInfoInteger(g_pair_a[pair_index], SYMBOL_SPREAD);
   const long spread_b = SymbolInfoInteger(g_pair_b[pair_index], SYMBOL_SPREAD);
   return (spread_a > 0 && spread_b > 0 &&
           spread_a <= strategy_max_spread_points &&
           spread_b <= strategy_max_spread_points);
  }

bool Strategy_RolloverWindow(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   return (minute_of_day >= 1410 || minute_of_day < 30);
  }

bool Strategy_IsPairPosition(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   if(!Strategy_IsPairLeg(pair_index, symbol))
      return false;

   const int slot = Strategy_SlotForSymbol(pair_index, symbol);
   const int expected_magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   return (expected_magic > 0 && (int)PositionGetInteger(POSITION_MAGIC) == expected_magic);
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

int Strategy_BarsHeld(const int pair_index)
  {
   const datetime opened = Strategy_PairOpenTime(pair_index);
   const int seconds = PeriodSeconds(PERIOD_D1);
   if(opened <= 0 || seconds <= 0)
      return 0;
   return (int)((TimeCurrent() - opened) / seconds);
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

bool Strategy_OpenLeg(const int pair_index,
                      const string symbol,
                      const double leg_weight,
                      const int spread_direction,
                      const string reason)
  {
   const bool buy_leg = (spread_direction * leg_weight) > 0.0;
   const double entry_price = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double notional_points = entry_price / point;
   const double lots = QM_LotsForRisk(symbol, notional_points) * MathAbs(leg_weight);
   if(lots <= 0.0 || !MathIsValidNumber(lots))
      return false;

   QM_BasketOrderRequest breq;
   breq.symbol = symbol;
   breq.type = buy_leg ? QM_BUY : QM_SELL;
   breq.price = 0.0;
   breq.sl = 0.0;
   breq.tp = 0.0;
   breq.lots = lots;
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

   const string reason = (spread_direction > 0) ? "QM5_1058_LONG_PAIR_Z_LT_NEG2"
                                                : "QM5_1058_SHORT_PAIR_Z_GT_POS2";
   const double leg_a_weight = 1.0;
   const double leg_b_weight = -g_beta;

   const bool opened_a = Strategy_OpenLeg(pair_index, g_pair_a[pair_index],
                                          leg_a_weight, spread_direction, reason);
   const bool opened_b = Strategy_OpenLeg(pair_index, g_pair_b[pair_index],
                                          leg_b_weight, spread_direction, reason);
   if(opened_a && opened_b)
      return true;

   Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
   return false;
  }

// No Trade Filter: D1 cadence, registered pair membership, spread, and rollover gate.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int pair_index = Strategy_PairForHostSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   const int expected_slot = Strategy_SlotForSymbol(pair_index, _Symbol);
   if(qm_magic_slot_offset != expected_slot)
      return true;

   if(!Strategy_SpreadsNormal(pair_index))
      return true;

   if(Strategy_RolloverWindow(TimeCurrent()))
      return true;

   return false;
  }

// Trade Entry: rolling OLS beta, spread z-score threshold, and correlation gate.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1058_GATEV_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready)
      return false;
   if(Strategy_OpenPairLegCount(g_active_pair) > 0)
      return false;
   if(g_corr_now <= strategy_min_corr)
      return false;

   if(g_z_now < -MathAbs(strategy_entry_z))
      Strategy_OpenPair(g_active_pair, 1);
   else if(g_z_now > MathAbs(strategy_entry_z))
      Strategy_OpenPair(g_active_pair, -1);

   return false;
  }

// Trade Management: the card specifies no trailing, break-even, partial, or add-on logic.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: mean-reversion exit, structural-break stop, and 20-bar time stop.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || Strategy_OpenPairLegCount(g_active_pair) <= 0)
      return false;

   if(MathAbs(g_z_now) < MathAbs(strategy_exit_z))
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   if(MathAbs(g_z_now) > MathAbs(strategy_hard_stop_z))
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   if(strategy_time_stop_bars > 0 && Strategy_BarsHeld(g_active_pair) >= strategy_time_stop_bars)
      Strategy_ClosePair(g_active_pair, QM_EXIT_TIME_STOP);

   return false;
  }

// News Filter Hook: require both legs to pass the framework news gate.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const int pair_index = Strategy_PairForHostSymbol(_Symbol);
   if(pair_index < 0)
      return false;

   string symbols[2];
   symbols[0] = g_pair_a[pair_index];
   symbols[1] = g_pair_b[pair_index];
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
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   string allowed[4];
   allowed[0] = "EURUSD.DWX";
   allowed[1] = "GBPUSD.DWX";
   allowed[2] = "AUDUSD.DWX";
   allowed[3] = "NZDUSD.DWX";
   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_D1, MathMax(300, strategy_lookback_bars + 5));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1058\",\"strategy\":\"gatev-fx-pairs-zscore\"}");
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
