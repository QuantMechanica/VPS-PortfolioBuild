#property strict
#property version   "5.0"
#property description "QM5_10338 Intraday Component Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10338;
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
input string strategy_basket_symbols          = "SP500.DWX,NDX.DWX,WS30.DWX,GDAXI.DWX";
input int    strategy_rebalance_day_of_week   = 1;
input int    strategy_component_lookback       = 20;
input int    strategy_rank_atr_period          = 20;
input double strategy_rank_atr_mult            = 0.50;
input int    strategy_stop_atr_period          = 14;
input double strategy_stop_atr_mult            = 2.0;
input int    strategy_hold_sessions            = 5;
input int    strategy_min_valid_symbols        = 3;
input int    strategy_spread_lookback          = 80;
input double strategy_spread_percentile        = 80.0;
input double strategy_min_stop_spread_mult     = 4.0;
input double strategy_overnight_conflict_ratio = 1.0;
input int    strategy_basket_warmup_bars       = 96;

struct ComponentScore
  {
   string symbol;
   bool   valid;
   double intraday;
   double overnight;
   double close_price;
   double atr_rank;
  };

bool   g_state_valid = false;
int    g_state_direction = 0;
double g_state_score = 0.0;
double g_state_median = 0.0;

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

bool IsBasketSymbol(const string symbol)
  {
   string symbols[];
   const int n = SplitBasket(symbols);
   for(int i = 0; i < n; ++i)
      if(symbols[i] == symbol)
         return true;
   return false;
  }

bool IsRebalanceDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return (dt.day_of_week == strategy_rebalance_day_of_week);
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

double CurrentSpreadPoints(const string symbol)
  {
   const long spread_raw = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_raw > 0)
      return (double)spread_raw;

   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

double Percentile(double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   double p = percentile;
   if(p < 0.0)
      p = 0.0;
   if(p > 100.0)
      p = 100.0;

   const double rank = (p / 100.0) * (double)(count - 1);
   const int lo = (int)MathFloor(rank);
   const int hi = (int)MathCeil(rank);
   if(lo == hi)
      return values[lo];

   const double frac = rank - (double)lo;
   return values[lo] + (values[hi] - values[lo]) * frac;
  }

double Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

bool SpreadAllows(const string symbol, MqlRates &rates[])
  {
   const int available = ArraySize(rates);
   const int samples = MathMin(strategy_spread_lookback, available);
   if(samples < 20)
      return true;

   double spreads[];
   ArrayResize(spreads, samples);
   int count = 0;
   for(int i = 0; i < samples; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[count] = (double)rates[i].spread;
      count++;
     }

   if(count < 20)
      return true;

   const double threshold = Percentile(spreads, count, strategy_spread_percentile);
   const double current = CurrentSpreadPoints(symbol);
   if(threshold <= 0.0 || current <= 0.0)
      return true;
   return (current <= threshold);
  }

bool ReadComponentScore(const string symbol, ComponentScore &score)
  {
   score.symbol = symbol;
   score.valid = false;
   score.intraday = 0.0;
   score.overnight = 0.0;
   score.close_price = 0.0;
   score.atr_rank = 0.0;

   if(strategy_component_lookback <= 0)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   const int need = MathMax(strategy_component_lookback + 1, strategy_spread_lookback);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, need, rates); // perf-allowed: basket component ranking is called only from the framework QM_IsNewBar-gated entry path.
   if(copied < strategy_component_lookback + 1)
      return false;
   if(!SpreadAllows(symbol, rates))
      return false;

   double intraday = 0.0;
   double overnight = 0.0;
   for(int i = 0; i < strategy_component_lookback; ++i)
     {
      if(rates[i].open <= 0.0 || rates[i].close <= 0.0 || rates[i + 1].close <= 0.0)
         return false;
      intraday += MathLog(rates[i].close / rates[i].open);
      overnight += MathLog(rates[i].open / rates[i + 1].close);
     }

   const double atr_rank = QM_ATR(symbol, PERIOD_D1, strategy_rank_atr_period, 1);
   if(atr_rank <= 0.0 || rates[0].close <= 0.0)
      return false;

   score.valid = true;
   score.intraday = intraday;
   score.overnight = overnight;
   score.close_price = rates[0].close;
   score.atr_rank = atr_rank;
   return true;
  }

bool OvernightConflict(const ComponentScore &score, const int direction)
  {
   if(direction == 0 || score.overnight == 0.0 || score.intraday == 0.0)
      return false;

   const int overnight_dir = (score.overnight > 0.0) ? 1 : -1;
   if(overnight_dir == direction)
      return false;

   return (MathAbs(score.overnight) >= MathAbs(score.intraday) * strategy_overnight_conflict_ratio);
  }

bool UpdateBasketState()
  {
   g_state_valid = false;
   g_state_direction = 0;
   g_state_score = 0.0;
   g_state_median = 0.0;

   string symbols[];
   const int n = SplitBasket(symbols);
   if(n < strategy_min_valid_symbols)
      return false;

   ComponentScore scores[];
   ArrayResize(scores, n);
   double valid_scores[];
   ArrayResize(valid_scores, n);
   int valid_count = 0;
   int current_idx = -1;

   for(int i = 0; i < n; ++i)
     {
      if(!ReadComponentScore(symbols[i], scores[i]))
         continue;
      if(symbols[i] == _Symbol)
         current_idx = i;
      valid_scores[valid_count] = scores[i].intraday;
      valid_count++;
     }

   if(valid_count < strategy_min_valid_symbols || current_idx < 0 || !scores[current_idx].valid)
      return false;

   const double median = Median(valid_scores, valid_count);
   int top_idx = -1;
   int bottom_idx = -1;
   double top_score = -DBL_MAX;
   double bottom_score = DBL_MAX;
   for(int i = 0; i < n; ++i)
     {
      if(!scores[i].valid)
         continue;
      if(scores[i].intraday > top_score)
        {
         top_score = scores[i].intraday;
         top_idx = i;
        }
      if(scores[i].intraday < bottom_score)
        {
         bottom_score = scores[i].intraday;
         bottom_idx = i;
        }
     }

   const ComponentScore current = scores[current_idx];
   const double threshold = strategy_rank_atr_mult * current.atr_rank / current.close_price;
   int direction = 0;

   if(current_idx == top_idx &&
      current.intraday > 0.0 &&
      current.intraday >= median + threshold &&
      !OvernightConflict(current, 1))
      direction = 1;

   if(current_idx == bottom_idx &&
      current.intraday < 0.0 &&
      current.intraday <= median - threshold &&
      !OvernightConflict(current, -1))
      direction = -1;

   g_state_valid = true;
   g_state_direction = direction;
   g_state_score = current.intraday;
   g_state_median = median;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return !HasOurPosition();
   if(!IsBasketSymbol(_Symbol))
      return !HasOurPosition();
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

   if(!UpdateBasketState())
      return false;
   if(HasOurPosition())
      return false;
   if(!IsRebalanceDay(TimeCurrent()))
      return false;
   if(g_state_direction == 0)
      return false;

   const QM_OrderType side = (g_state_direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_stop_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = atr * strategy_stop_atr_mult;
   const double spread_points = CurrentSpreadPoints(_Symbol);
   if(spread_points > 0.0 && (stop_distance / point) < strategy_min_stop_spread_mult * spread_points)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (g_state_direction > 0) ? "INTRADAY_COMP_TOP_LONG" : "INTRADAY_COMP_BOTTOM_SHORT";
   return true;
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
      if(strategy_hold_sessions > 0 &&
         open_time > 0 &&
         TimeCurrent() - open_time >= strategy_hold_sessions * PeriodSeconds(PERIOD_D1))
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(g_state_valid)
        {
         if(ptype == POSITION_TYPE_BUY && g_state_score <= g_state_median)
            return true;
         if(ptype == POSITION_TYPE_SELL && g_state_score >= g_state_median)
            return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
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

   string symbols[];
   if(SplitBasket(symbols) >= strategy_min_valid_symbols)
     {
      QM_SymbolGuardInit(symbols);
      QM_BasketWarmupHistory(symbols, PERIOD_D1, strategy_basket_warmup_bars);
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10338\",\"strategy\":\"intraday-comp-mom\"}");
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
