#property strict
#property version   "5.0"
#property description "QM5_10332 Coi Flow"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10332;
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
input string strategy_basket_symbols       = "SP500.DWX,NDX.DWX,WS30.DWX,GDAXI.DWX";
input int    strategy_flow_lookback        = 100;
input double strategy_flow_percentile      = 80.0;
input int    strategy_min_valid_members    = 3;
input int    strategy_atr_period           = 14;
input double strategy_atr_stop_mult        = 0.50;
input double strategy_min_stop_spread_mult = 4.0;
input int    strategy_spread_lookback      = 100;
input double strategy_spread_percentile    = 80.0;
input int    strategy_session_start_hhmm   = 1540;
input int    strategy_session_end_hhmm     = 2150;

struct FlowSignal
  {
   bool   valid;
   int    flow_dir;
   int    trade_dir;
   double abs_flow;
   double zscore;
  };

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

bool InTradingWindow(const datetime t)
  {
   const int hhmm = Hhmm(t);
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      return (hhmm >= strategy_session_start_hhmm && hhmm < strategy_session_end_hhmm);
   return (hhmm >= strategy_session_start_hhmm || hhmm < strategy_session_end_hhmm);
  }

int SplitBasket(string &symbols[])
  {
   string raw[];
   const int count = StringSplit(strategy_basket_symbols, ',', raw);
   ArrayResize(symbols, 0);
   for(int i = 0; i < count; ++i)
     {
      string s = raw[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(StringLen(s) <= 0)
         continue;
      const int n = ArraySize(symbols);
      ArrayResize(symbols, n + 1);
      symbols[n] = s;
     }
   return ArraySize(symbols);
  }

double SignedFlow(const MqlRates &bar)
  {
   if(bar.close > bar.open)
      return (double)bar.tick_volume;
   if(bar.close < bar.open)
      return -(double)bar.tick_volume;
   return 0.0;
  }

double Percentile(double &values[], const double pct)
  {
   const int n = ArraySize(values);
   if(n <= 0)
      return 0.0;
   ArraySort(values);
   const double clipped = MathMax(0.0, MathMin(100.0, pct));
   const double rank = (clipped / 100.0) * (double)(n - 1);
   const int lo = (int)MathFloor(rank);
   const int hi = (int)MathCeil(rank);
   if(lo == hi)
      return values[lo];
   const double frac = rank - (double)lo;
   return values[lo] + (values[hi] - values[lo]) * frac;
  }

bool LoadRates(const string symbol, MqlRates &rates[])
  {
   const int lookback = MathMax(strategy_flow_lookback, strategy_spread_lookback);
   const int need = MathMax(lookback + 1, 3);
   ArraySetAsSeries(rates, true);
   // perf-allowed: Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   const int copied = CopyRates(symbol, (ENUM_TIMEFRAMES)_Period, 1, need, rates);
   return (copied >= need);
  }

bool FlowStats(MqlRates &rates[], double &threshold, double &mean_abs, double &stdev_abs)
  {
   threshold = 0.0;
   mean_abs = 0.0;
   stdev_abs = 0.0;

   const int available = ArraySize(rates);
   const int samples = MathMin(strategy_flow_lookback, available - 1);
   if(samples < 20)
      return false;

   double abs_values[];
   ArrayResize(abs_values, samples);
   for(int i = 0; i < samples; ++i)
     {
      const double v = MathAbs(SignedFlow(rates[i + 1]));
      abs_values[i] = v;
      mean_abs += v;
     }
   mean_abs /= (double)samples;

   double var_sum = 0.0;
   for(int i = 0; i < samples; ++i)
     {
      const double d = abs_values[i] - mean_abs;
      var_sum += d * d;
     }
   stdev_abs = MathSqrt(var_sum / (double)samples);
   threshold = Percentile(abs_values, strategy_flow_percentile);
   return (threshold > 0.0 && stdev_abs > 0.0);
  }

double SpreadPercentile(MqlRates &rates[])
  {
   const int available = ArraySize(rates);
   const int samples = MathMin(strategy_spread_lookback, available - 1);
   if(samples < 20)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, samples);
   for(int i = 0; i < samples; ++i)
      spreads[i] = (double)rates[i + 1].spread;
   return Percentile(spreads, strategy_spread_percentile);
  }

double CurrentSpreadPoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

int CurrentSymbolIndex(string &symbols[])
  {
   const int n = ArraySize(symbols);
   for(int i = 0; i < n; ++i)
      if(symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool BuildFlowSignals(string &symbols[], FlowSignal &signals[])
  {
   const int n = ArraySize(symbols);
   ArrayResize(signals, n);

   int valid_members = 0;
   int flow_dirs[];
   double abs_flows[];
   double zscores[];
   ArrayResize(flow_dirs, n);
   ArrayResize(abs_flows, n);
   ArrayResize(zscores, n);

   for(int i = 0; i < n; ++i)
     {
      signals[i].valid = false;
      signals[i].flow_dir = 0;
      signals[i].trade_dir = 0;
      signals[i].abs_flow = 0.0;
      signals[i].zscore = 0.0;

      MqlRates rs[];
      if(!LoadRates(symbols[i], rs))
         continue;

      if(symbols[i] == _Symbol)
        {
         const double spread_p80 = SpreadPercentile(rs);
         const double curr_spread = CurrentSpreadPoints();
         if(spread_p80 > 0.0 && curr_spread > spread_p80)
            return false;
        }

      double threshold = 0.0;
      double mean_abs = 0.0;
      double stdev_abs = 0.0;
      if(!FlowStats(rs, threshold, mean_abs, stdev_abs))
         continue;

      const double sf = SignedFlow(rs[0]);
      const double af = MathAbs(sf);
      const int dir = (sf > 0.0) ? 1 : ((sf < 0.0) ? -1 : 0);
      if(dir == 0 || af <= threshold)
         continue;

      signals[i].valid = true;
      signals[i].flow_dir = dir;
      signals[i].abs_flow = af;
      signals[i].zscore = (af - mean_abs) / stdev_abs;
      flow_dirs[i] = dir;
      abs_flows[i] = af;
      zscores[i] = signals[i].zscore;
      valid_members++;
     }

   if(valid_members < strategy_min_valid_members)
      return false;

   const int other_half = MathMax(1, (valid_members - 1 + 1) / 2);
   for(int i = 0; i < n; ++i)
     {
      if(!signals[i].valid)
         continue;

      int same_others = 0;
      for(int j = 0; j < n; ++j)
        {
         if(i == j || !signals[j].valid)
            continue;
         if(signals[j].flow_dir == signals[i].flow_dir)
            same_others++;
        }

      if(same_others >= other_half)
         signals[i].trade_dir = -signals[i].flow_dir;
      else
         signals[i].trade_dir = signals[i].flow_dir;
     }

   return true;
  }

bool HasOurPosition()
  {
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
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(HasOurPosition())
      return false;
   return !InTradingWindow(TimeCurrent());
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

   if(!InTradingWindow(TimeCurrent()))
      return false;

   string symbols[];
   if(SplitBasket(symbols) < strategy_min_valid_members)
      return false;

   const int current_idx = CurrentSymbolIndex(symbols);
   if(current_idx < 0)
      return false;

   FlowSignal signals[];
   if(!BuildFlowSignals(symbols, signals))
      return false;
   if(!signals[current_idx].valid || signals[current_idx].trade_dir == 0)
      return false;

   double strongest = -DBL_MAX;
   for(int i = 0; i < ArraySize(signals); ++i)
      if(signals[i].valid && signals[i].trade_dir != 0 && signals[i].zscore > strongest)
         strongest = signals[i].zscore;
   if(signals[current_idx].zscore + 0.000001 < strongest)
      return false;

   const QM_OrderType side = (signals[current_idx].trade_dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   const double stop_dist = atr * strategy_atr_stop_mult;
   const double spread_points = CurrentSpreadPoints();
   if(spread_points > 0.0 && (stop_dist / point) < strategy_min_stop_spread_mult * spread_points)
      return false;

   req.type = side;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = (signals[current_idx].trade_dir == signals[current_idx].flow_dir)
                ? "COI_ISOLATED_WITH_FLOW"
                : "COI_COMOVING_FADE";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(TimeCurrent() - open_time >= PeriodSeconds((ENUM_TIMEFRAMES)_Period))
         return true;
      if(!InTradingWindow(TimeCurrent()))
         return true;
     }
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
