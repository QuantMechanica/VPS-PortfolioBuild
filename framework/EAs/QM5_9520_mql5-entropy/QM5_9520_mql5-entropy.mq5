#property strict
#property version   "5.0"
#property description "QM5_9520 MQL5 Market Entropy Momentum Compression EA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9520;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal       = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance     = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entropy_period       = 50;
input int    strategy_smoothing_period     = 10;
input int    strategy_momentum_period      = 5;
input int    strategy_fast_entropy_period  = 20;
input int    strategy_slow_entropy_period  = 100;
input int    strategy_price_step_points    = 1;
input double strategy_signal_threshold     = 0.15;
input double strategy_compression_zone     = 0.30;
input double strategy_decompression_zone   = 0.50;
input int    strategy_compression_bars     = 5;
input int    strategy_min_signal_gap_bars  = 10;
input int    strategy_stop_loss_points     = 100;
input int    strategy_take_profit_points   = 200;
input bool   strategy_reverse_on_opposite  = true;
input int    strategy_max_spread_points    = 0;

MqlRates g_entropy_rates[];
double   g_entropy_base[];
double   g_entropy_smooth[];
double   g_entropy_fast[];
double   g_entropy_slow[];
double   g_entropy_momentum[];
double   g_entropy_divergence[];
int      g_entropy_state[];
int      g_entropy_regime[];
int      g_entropy_compression[];
int      g_cached_signal = 0;
int      g_bars_since_buy_signal = 1000000;
int      g_bars_since_sell_signal = 1000000;

double EntropyFromStates(const int start_index, const int period)
  {
   if(period <= 0 || start_index < 0 || start_index + period > ArraySize(g_entropy_state))
      return EMPTY_VALUE;

   int up = 0;
   int down = 0;
   int flat = 0;
   for(int i = start_index; i < start_index + period; ++i)
     {
      if(g_entropy_state[i] == 1)
         up++;
      else if(g_entropy_state[i] == 2)
         down++;
      else
         flat++;
     }

   const int total = up + down + flat;
   if(total <= 0)
      return EMPTY_VALUE;

   double entropy = 0.0;
   const double p_up = (double)up / (double)total;
   const double p_down = (double)down / (double)total;
   const double p_flat = (double)flat / (double)total;
   if(p_up > 0.0)
      entropy -= p_up * MathLog(p_up);
   if(p_down > 0.0)
      entropy -= p_down * MathLog(p_down);
   if(p_flat > 0.0)
      entropy -= p_flat * MathLog(p_flat);

   return entropy / MathLog(3.0);
  }

double SmoothBaseEntropy(const int start_index)
  {
   const int period = MathMax(1, strategy_smoothing_period);
   if(start_index < 0 || start_index + period > ArraySize(g_entropy_base))
      return EMPTY_VALUE;

   double sum = 0.0;
   int samples = 0;
   for(int i = start_index; i < start_index + period; ++i)
     {
      if(g_entropy_base[i] == EMPTY_VALUE)
         return EMPTY_VALUE;
      sum += g_entropy_base[i];
      samples++;
     }

   if(samples <= 0)
      return EMPTY_VALUE;
   return sum / (double)samples;
  }

bool LoadEntropyState()
  {
   const int max_period = MathMax(strategy_slow_entropy_period,
                                  MathMax(strategy_entropy_period,
                                          strategy_fast_entropy_period));
   const int needed = max_period +
                      MathMax(1, strategy_smoothing_period) +
                      MathMax(1, strategy_momentum_period) +
                      MathMax(1, strategy_compression_bars) + 10;
   if(needed < 30)
      return false;

   ArraySetAsSeries(g_entropy_rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, needed, g_entropy_rates); // perf-allowed: called only from Strategy_EntrySignal after the framework QM_IsNewBar() gate.
   if(copied < needed - 5)
      return false;

   ArrayResize(g_entropy_state, copied);
   ArrayResize(g_entropy_base, copied);
   ArrayResize(g_entropy_smooth, copied);
   ArrayResize(g_entropy_fast, copied);
   ArrayResize(g_entropy_slow, copied);
   ArrayResize(g_entropy_momentum, copied);
   ArrayResize(g_entropy_divergence, copied);
   ArrayResize(g_entropy_regime, copied);
   ArrayResize(g_entropy_compression, copied);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double threshold = MathMax(0, strategy_price_step_points) * point;

   for(int i = copied - 1; i >= 0; --i)
     {
      g_entropy_base[i] = EMPTY_VALUE;
      g_entropy_smooth[i] = EMPTY_VALUE;
      g_entropy_fast[i] = EMPTY_VALUE;
      g_entropy_slow[i] = EMPTY_VALUE;
      g_entropy_momentum[i] = EMPTY_VALUE;
      g_entropy_divergence[i] = EMPTY_VALUE;
      g_entropy_regime[i] = -1;
      g_entropy_compression[i] = 0;

      if(i + 1 >= copied)
        {
         g_entropy_state[i] = 0;
         continue;
        }

      const double change = g_entropy_rates[i].close - g_entropy_rates[i + 1].close;
      if(change > threshold)
         g_entropy_state[i] = 1;
      else if(change < -threshold)
         g_entropy_state[i] = 2;
      else
         g_entropy_state[i] = 0;
     }

   for(int i = copied - 1; i >= 0; --i)
     {
      g_entropy_base[i] = EntropyFromStates(i, strategy_entropy_period);
      g_entropy_fast[i] = EntropyFromStates(i, strategy_fast_entropy_period);
      g_entropy_slow[i] = EntropyFromStates(i, strategy_slow_entropy_period);
     }

   for(int i = copied - 1; i >= 0; --i)
     {
      g_entropy_smooth[i] = SmoothBaseEntropy(i);
      if(g_entropy_smooth[i] != EMPTY_VALUE)
        {
         if(g_entropy_smooth[i] < 0.35)
            g_entropy_regime[i] = 0;
         else if(g_entropy_smooth[i] < 0.65)
            g_entropy_regime[i] = 1;
         else
            g_entropy_regime[i] = 2;
        }

      if(i + strategy_momentum_period < copied &&
         g_entropy_smooth[i] != EMPTY_VALUE &&
         g_entropy_smooth[i + strategy_momentum_period] != EMPTY_VALUE)
         g_entropy_momentum[i] = g_entropy_smooth[i] - g_entropy_smooth[i + strategy_momentum_period];

      if(g_entropy_fast[i] != EMPTY_VALUE && g_entropy_slow[i] != EMPTY_VALUE)
         g_entropy_divergence[i] = g_entropy_fast[i] - g_entropy_slow[i];

      if(i + 1 < copied &&
         g_entropy_smooth[i] != EMPTY_VALUE &&
         g_entropy_smooth[i + 1] != EMPTY_VALUE)
        {
         if(g_entropy_smooth[i] < g_entropy_smooth[i + 1] &&
            g_entropy_smooth[i] < strategy_compression_zone)
            g_entropy_compression[i] = -1;
         else if(g_entropy_smooth[i] > g_entropy_smooth[i + 1] &&
                 g_entropy_smooth[i] > strategy_decompression_zone)
            g_entropy_compression[i] = 1;
        }
     }

   return true;
  }

int EvaluateEntropySignal()
  {
   if(!LoadEntropyState())
      return 0;

   if(ArraySize(g_entropy_smooth) < 3 ||
      g_entropy_fast[0] == EMPTY_VALUE ||
      g_entropy_slow[0] == EMPTY_VALUE ||
      g_entropy_fast[1] == EMPTY_VALUE ||
      g_entropy_slow[1] == EMPTY_VALUE ||
      g_entropy_smooth[0] == EMPTY_VALUE ||
      g_entropy_momentum[0] == EMPTY_VALUE ||
      g_entropy_divergence[0] == EMPTY_VALUE)
      return 0;

   const bool cross_up = (g_entropy_fast[0] > g_entropy_slow[0] &&
                          g_entropy_fast[1] <= g_entropy_slow[1]);
   const bool cross_down = (g_entropy_fast[0] < g_entropy_slow[0] &&
                            g_entropy_fast[1] >= g_entropy_slow[1]);
   const bool compression_breakout = (g_entropy_compression[0] == 1 &&
                                      g_entropy_smooth[0] > 0.20 &&
                                      g_entropy_smooth[0] < strategy_decompression_zone);
   const bool decompression_end_buy = (g_entropy_compression[1] == -1 &&
                                       g_entropy_compression[0] != -1 &&
                                       g_entropy_momentum[0] > 0.0);
   const bool chaotic_entry = (g_entropy_regime[0] == 2 &&
                               g_entropy_regime[1] != 2);
   const bool strong_negative_divergence = (g_entropy_divergence[0] < -strategy_signal_threshold &&
                                            MathAbs(g_entropy_divergence[0]) > MathAbs(g_entropy_divergence[1]));
   const bool compression_end_sell = (g_entropy_compression[1] == 1 &&
                                      g_entropy_compression[0] != 1 &&
                                      g_entropy_momentum[0] < 0.0);

   const bool long_primary = (cross_up || compression_breakout || decompression_end_buy);
   const bool long_confirm = (g_entropy_smooth[0] < 0.70 &&
                              g_entropy_momentum[0] > 0.0 &&
                              g_entropy_divergence[0] > -strategy_signal_threshold * 1.5);
   if(long_primary && long_confirm)
      return 1;

   const bool short_primary = (cross_down || chaotic_entry ||
                               strong_negative_divergence || compression_end_sell);
   const bool short_confirm = (g_entropy_smooth[0] > 0.50 &&
                               g_entropy_momentum[0] < 0.0 &&
                               g_entropy_divergence[0] < strategy_signal_threshold);
   if(short_primary && short_confirm)
      return -1;

   return 0;
  }

double PriceFromPointDistance(const QM_OrderType type,
                              const double entry_price,
                              const int point_distance,
                              const bool take_profit)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || point_distance <= 0)
      return 0.0;

   const double dist = point * (double)point_distance;
   double price = 0.0;
   if(take_profit)
      price = (type == QM_BUY) ? entry_price + dist : entry_price - dist;
   else
      price = (type == QM_BUY) ? entry_price - dist : entry_price + dist;
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

int CurrentPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         return 1;
      if(ptype == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   if(ask > bid && ((ask - bid) / point) > (double)strategy_max_spread_points)
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

   if(g_bars_since_buy_signal < 1000000)
      g_bars_since_buy_signal++;
   if(g_bars_since_sell_signal < 1000000)
      g_bars_since_sell_signal++;

   g_cached_signal = EvaluateEntropySignal();
   if(g_cached_signal == 0)
      return false;

   if(g_cached_signal > 0 && g_bars_since_buy_signal < strategy_min_signal_gap_bars)
      return false;
   if(g_cached_signal < 0 && g_bars_since_sell_signal < strategy_min_signal_gap_bars)
      return false;

   const int current_direction = CurrentPositionDirection();
   if(current_direction == g_cached_signal)
      return false;
   if(strategy_reverse_on_opposite && current_direction != 0 && current_direction != g_cached_signal)
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   const QM_OrderType type = (g_cached_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = type;
   req.price = 0.0;
   req.sl = PriceFromPointDistance(type, entry, strategy_stop_loss_points, false);
   req.tp = PriceFromPointDistance(type, entry, strategy_take_profit_points, true);
   req.reason = (type == QM_BUY) ? "ENTROPY_LONG" : "ENTROPY_SHORT";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   if(type == QM_BUY)
      g_bars_since_buy_signal = 0;
   else
      g_bars_since_sell_signal = 0;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Source strategy uses fixed SL/TP plus optional reverse-on-opposite signal.
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_reverse_on_opposite || g_cached_signal == 0)
      return false;

   const int current_direction = CurrentPositionDirection();
   if(current_direction == 0)
      return false;
   return (current_direction != g_cached_signal);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9520_mql5_entropy\"}");
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
