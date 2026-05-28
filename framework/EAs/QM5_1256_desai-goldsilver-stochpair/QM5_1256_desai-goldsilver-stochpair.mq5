#property strict
#property version   "5.0"
#property description "QM5_1256 Desai Gold Silver Stochastic Pair"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1256;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string          strategy_gold_symbol          = "XAUUSD.DWX";
input string          strategy_silver_symbol        = "XAGUSD.DWX";
input ENUM_TIMEFRAMES strategy_timeframe            = PERIOD_H1;
input int             strategy_correlation_bars     = 1440;
input double          strategy_min_correlation      = 0.90;
input int             strategy_stoch_k              = 14;
input int             strategy_stoch_d              = 3;
input int             strategy_stoch_slowing        = 3;
input double          strategy_oversold             = 20.0;
input double          strategy_overbought           = 80.0;
input double          strategy_midline              = 50.0;
input int             strategy_zscore_bars          = 480;
input double          strategy_stop_z_adverse       = 2.5;
input int             strategy_max_hold_bars        = 240;
input int             strategy_vol_bars             = 1440;
input int             strategy_spread_median_bars   = 480;
input double          strategy_max_spread_mult      = 2.0;
input int             strategy_deviation_points     = 20;

datetime g_last_signal_bar = 0;
double   g_entry_z         = 0.0;
int      g_pair_side       = 0;    // 1 = long gold/short silver; -1 = short gold/long silver
bool     g_close_pair_now  = false;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == strategy_gold_symbol)
      return 0;
   if(symbol == strategy_silver_symbol)
      return 1;
   return qm_magic_slot_offset;
  }

bool Strategy_IsPairChart()
  {
   return (_Symbol == strategy_gold_symbol || _Symbol == strategy_silver_symbol);
  }

bool Strategy_LoadCloses(const string symbol, const ENUM_TIMEFRAMES tf, const int shift, const int count, double &closes[])
  {
   if(count <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, tf, shift, count, rates); // perf-allowed: caller is reached only from the framework closed-bar gate.
   if(copied != count)
      return false;

   ArrayResize(closes, count);
   for(int i = 0; i < count; ++i)
     {
      const int src = count - 1 - i;
      if(rates[src].close <= 0.0)
         return false;
      closes[i] = rates[src].close;
     }
   return true;
  }

bool Strategy_ComputeRatios(const int shift, const int count, double &ratios[])
  {
   double gold[], silver[];
   if(!Strategy_LoadCloses(strategy_gold_symbol, strategy_timeframe, shift, count, gold))
      return false;
   if(!Strategy_LoadCloses(strategy_silver_symbol, strategy_timeframe, shift, count, silver))
      return false;

   ArrayResize(ratios, count);
   for(int i = 0; i < count; ++i)
     {
      if(silver[i] <= 0.0)
         return false;
      ratios[i] = gold[i] / silver[i];
     }
   return true;
  }

bool Strategy_ComputeCorrelation(double &corr)
  {
   corr = 0.0;
   if(strategy_correlation_bars < 30)
      return false;

   double gold[], silver[];
   if(!Strategy_LoadCloses(strategy_gold_symbol, strategy_timeframe, 1, strategy_correlation_bars + 1, gold))
      return false;
   if(!Strategy_LoadCloses(strategy_silver_symbol, strategy_timeframe, 1, strategy_correlation_bars + 1, silver))
      return false;

   double sum_x = 0.0, sum_y = 0.0;
   const int n = strategy_correlation_bars;
   for(int i = 1; i <= n; ++i)
     {
      const double rx = MathLog(gold[i] / gold[i - 1]);
      const double ry = MathLog(silver[i] / silver[i - 1]);
      sum_x += rx;
      sum_y += ry;
     }

   const double mean_x = sum_x / (double)n;
   const double mean_y = sum_y / (double)n;
   double cov = 0.0, var_x = 0.0, var_y = 0.0;
   for(int i = 1; i <= n; ++i)
     {
      const double dx = MathLog(gold[i] / gold[i - 1]) - mean_x;
      const double dy = MathLog(silver[i] / silver[i - 1]) - mean_y;
      cov += dx * dy;
      var_x += dx * dx;
      var_y += dy * dy;
     }

   if(var_x <= 0.0 || var_y <= 0.0)
      return false;
   corr = cov / MathSqrt(var_x * var_y);
   return true;
  }

bool Strategy_StochKAtShift(const int shift, double &k_value)
  {
   k_value = 0.0;
   const int need = strategy_stoch_k + strategy_stoch_slowing + shift + 2;
   if(strategy_stoch_k < 2 || strategy_stoch_slowing < 1 || need < 5)
      return false;

   double ratios[];
   if(!Strategy_ComputeRatios(1, need, ratios))
      return false;

   double sum_raw_k = 0.0;
   for(int slow = 0; slow < strategy_stoch_slowing; ++slow)
     {
      const int end_idx = ArraySize(ratios) - 1 - shift - slow;
      const int start_idx = end_idx - strategy_stoch_k + 1;
      if(start_idx < 0 || end_idx < start_idx)
         return false;

      double hi = ratios[start_idx];
      double lo = ratios[start_idx];
      for(int i = start_idx; i <= end_idx; ++i)
        {
         hi = MathMax(hi, ratios[i]);
         lo = MathMin(lo, ratios[i]);
        }
      if(hi <= lo)
         return false;
      sum_raw_k += 100.0 * (ratios[end_idx] - lo) / (hi - lo);
     }

   k_value = sum_raw_k / (double)strategy_stoch_slowing;
   return true;
  }

bool Strategy_ComputeZ(double &z)
  {
   z = 0.0;
   if(strategy_zscore_bars < 30)
      return false;

   double ratios[];
   if(!Strategy_ComputeRatios(1, strategy_zscore_bars, ratios))
      return false;

   double sum = 0.0;
   for(int i = 0; i < strategy_zscore_bars; ++i)
      sum += ratios[i];
   const double mean = sum / (double)strategy_zscore_bars;

   double var = 0.0;
   for(int i = 0; i < strategy_zscore_bars; ++i)
     {
      const double d = ratios[i] - mean;
      var += d * d;
     }
   const double stdev = MathSqrt(var / (double)MathMax(1, strategy_zscore_bars - 1));
   if(stdev <= 0.0)
      return false;

   z = (ratios[strategy_zscore_bars - 1] - mean) / stdev;
   return true;
  }

bool Strategy_HasPairPosition(const string symbol, ulong &ticket, datetime &open_time)
  {
   ticket = 0;
   open_time = 0;
   const int magic = QM_Magic(qm_ea_id, Strategy_SlotForSymbol(symbol));
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_PairIsOpen()
  {
   ulong ticket;
   datetime open_time;
   return (Strategy_HasPairPosition(strategy_gold_symbol, ticket, open_time) ||
           Strategy_HasPairPosition(strategy_silver_symbol, ticket, open_time));
  }

double Strategy_MedianSpreadPoints(const string symbol)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count = MathMax(20, strategy_spread_median_bars);
   const int copied = CopyRates(symbol, strategy_timeframe, 1, count, rates); // perf-allowed: spread gate runs only once per closed signal bar.
   if(copied < 20)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, copied);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   for(int i = 0; i < copied; ++i)
      spreads[i] = (double)rates[i].spread;

   ArraySort(spreads);
   return spreads[copied / 2];
  }

bool Strategy_SpreadOk(const string symbol)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_max_spread_mult <= 0.0)
      return false;
   const double current = (SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID)) / point;
   const double median = Strategy_MedianSpreadPoints(symbol);
   if(current <= 0.0 || median <= 0.0)
      return false;
   return (current <= strategy_max_spread_mult * median);
  }

double Strategy_ReturnVol(const string symbol)
  {
   double closes[];
   if(!Strategy_LoadCloses(symbol, strategy_timeframe, 1, strategy_vol_bars + 1, closes))
      return 0.0;

   double sum = 0.0;
   for(int i = 1; i <= strategy_vol_bars; ++i)
      sum += MathLog(closes[i] / closes[i - 1]);
   const double mean = sum / (double)strategy_vol_bars;

   double var = 0.0;
   for(int i = 1; i <= strategy_vol_bars; ++i)
     {
      const double r = MathLog(closes[i] / closes[i - 1]) - mean;
      var += r * r;
     }
   return MathSqrt(var / (double)MathMax(1, strategy_vol_bars - 1));
  }

double Strategy_NormalizedLots(const string symbol, const double raw_lots)
  {
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(raw_lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   double lots = MathFloor(raw_lots / step) * step;
   lots = MathMax(min_lot, MathMin(max_lot, lots));
   return lots;
  }

double Strategy_LotsForLeg(const string symbol, const double vol, const double other_vol)
  {
   const double contract = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   const double price = (SymbolInfoDouble(symbol, SYMBOL_ASK) + SymbolInfoDouble(symbol, SYMBOL_BID)) * 0.5;
   if(contract <= 0.0 || price <= 0.0 || vol <= 0.0 || other_vol <= 0.0)
      return 0.0;

   const double total_risk = MathMax(RISK_FIXED, 1.0) * MathMax(PORTFOLIO_WEIGHT, 0.01);
   const double target_vol_dollars = total_risk * 0.5;
   const double raw = target_vol_dollars / (price * contract * vol);
   return Strategy_NormalizedLots(symbol, raw);
  }

bool Strategy_SendLeg(const string symbol, const bool buy, const int slot, const double lots, ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0 || lots <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double price = buy ? ask : bid;
   if(price <= 0.0)
      return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lots;
   request.type = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = price;
   request.sl = 0.0;
   request.tp = 0.0;
   request.deviation = strategy_deviation_points;
   request.magic = magic;
   request.comment = "QM5_1256_PAIR";
   request.type_filling = ORDER_FILLING_IOC;

   const bool ok = OrderSend(request, result);
   if(!ok || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED))
     {
      QM_LogEvent(QM_WARN, "PAIR_LEG_OPEN_FAIL",
                  StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"retcode\":%u}", symbol, slot, result.retcode));
      return false;
     }

   ticket = result.order;
   QM_LogEvent(QM_INFO, "PAIR_LEG_OPEN",
               StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"magic\":%d}", symbol, slot, magic));
   return true;
  }

void Strategy_ClosePair()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != strategy_gold_symbol && symbol != strategy_silver_symbol)
         continue;
      const int slot = Strategy_SlotForSymbol(symbol);
      if((int)PositionGetInteger(POSITION_MAGIC) != QM_Magic(qm_ea_id, slot))
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
   g_pair_side = 0;
   g_entry_z = 0.0;
  }

bool Strategy_OpenPair(const int side, const double z)
  {
   if(side == 0)
      return false;
   if(!Strategy_SpreadOk(strategy_gold_symbol) || !Strategy_SpreadOk(strategy_silver_symbol))
      return false;

   const double gold_vol = Strategy_ReturnVol(strategy_gold_symbol);
   const double silver_vol = Strategy_ReturnVol(strategy_silver_symbol);
   const double gold_lots = Strategy_LotsForLeg(strategy_gold_symbol, gold_vol, silver_vol);
   const double silver_lots = Strategy_LotsForLeg(strategy_silver_symbol, silver_vol, gold_vol);
   if(gold_lots <= 0.0 || silver_lots <= 0.0)
      return false;

   ulong gold_ticket = 0, silver_ticket = 0;
   const bool long_gold = (side > 0);
   const bool ok_gold = Strategy_SendLeg(strategy_gold_symbol, long_gold, 0, gold_lots, gold_ticket);
   const bool ok_silver = Strategy_SendLeg(strategy_silver_symbol, !long_gold, 1, silver_lots, silver_ticket);
   if(ok_gold && ok_silver)
     {
      g_pair_side = side;
      g_entry_z = z;
      return true;
     }

   Strategy_ClosePair();
   return false;
  }

int Strategy_HeldBars()
  {
   ulong ticket;
   datetime open_time;
   if(!Strategy_HasPairPosition(strategy_gold_symbol, ticket, open_time) &&
      !Strategy_HasPairPosition(strategy_silver_symbol, ticket, open_time))
      return 0;

   const int shift = iBarShift(_Symbol, strategy_timeframe, open_time, false);
   return MathMax(0, shift);
  }

double Strategy_CombinedProfit()
  {
   double profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != strategy_gold_symbol && symbol != strategy_silver_symbol)
         continue;
      const int magic = QM_Magic(qm_ea_id, Strategy_SlotForSymbol(symbol));
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      profit += PositionGetDouble(POSITION_PROFIT);
     }
   return profit;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsPairChart())
      return true;
   if(_Period != strategy_timeframe)
      return true;
   if(strategy_gold_symbol == strategy_silver_symbol)
      return true;
   if(strategy_stoch_k < 2 || strategy_stoch_slowing < 1 || strategy_stoch_d < 1)
      return true;
   if(strategy_correlation_bars < 30 || strategy_zscore_bars < 30 || strategy_vol_bars < 30)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "PAIR_ENTRY_MANUAL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime signal_bar = iTime(_Symbol, strategy_timeframe, 0);
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return false;
   g_last_signal_bar = signal_bar;

   double corr = 0.0;
   if(!Strategy_ComputeCorrelation(corr) || corr <= strategy_min_correlation)
      return false;

   double k1 = 0.0, k2 = 0.0, z = 0.0;
   if(!Strategy_StochKAtShift(0, k1) || !Strategy_StochKAtShift(1, k2) || !Strategy_ComputeZ(z))
      return false;

   if(Strategy_PairIsOpen())
     {
      const bool midline_exit = (g_pair_side > 0 && k2 < strategy_midline && k1 >= strategy_midline) ||
                                (g_pair_side < 0 && k2 > strategy_midline && k1 <= strategy_midline);
      const bool adverse_z = (g_pair_side > 0 && z <= g_entry_z - strategy_stop_z_adverse) ||
                             (g_pair_side < 0 && z >= g_entry_z + strategy_stop_z_adverse);
      const bool emergency_r = (Strategy_CombinedProfit() <= -1.5 * MathMax(RISK_FIXED, 1.0) * MathMax(PORTFOLIO_WEIGHT, 0.01));
      g_close_pair_now = (midline_exit || adverse_z || emergency_r || Strategy_HeldBars() >= strategy_max_hold_bars);
      return false;
     }

   const bool long_gold_short_silver = (k2 < strategy_oversold && k1 >= strategy_oversold);
   const bool short_gold_long_silver = (k2 > strategy_overbought && k1 <= strategy_overbought);
   if(long_gold_short_silver)
      Strategy_OpenPair(1, z);
   else if(short_gold_long_silver)
      Strategy_OpenPair(-1, z);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!g_close_pair_now)
      return false;
   g_close_pair_now = false;
   Strategy_ClosePair();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1256\",\"strategy\":\"desai-goldsilver-stochpair\"}");
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
