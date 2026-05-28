#property strict
#property version   "5.0"
#property description "QM5_1129 Gatev Distance Pairs Trading"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1129;
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
input string strategy_pair_a              = "AUDUSD.DWX";
input string strategy_pair_b              = "NZDUSD.DWX";
input int    strategy_formation_bars      = 252;
input int    strategy_min_bars            = 260;
input double strategy_entry_z             = 2.0;
input double strategy_exit_abs_z          = 0.1;
input double strategy_stop_abs_z          = 4.0;
input int    strategy_max_hold_bars       = 126;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 3.0;
input int    strategy_max_spread_points   = 0;
input int    strategy_deviation_points    = 20;

datetime g_last_d1_bar = 0;
datetime g_pair_entry_time = 0;
double   g_last_z = 0.0;
bool     g_close_pair_now = false;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == strategy_pair_a)
      return 0;
   if(symbol == strategy_pair_b)
      return 1;
   return qm_magic_slot_offset;
  }

bool Strategy_IsPairChart()
  {
   return (_Symbol == strategy_pair_a || _Symbol == strategy_pair_b);
  }

bool Strategy_LoadClosedCloses(const string symbol, const int count, double &closes[])
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, count, rates); // perf-allowed: caller runs only behind QM_IsNewBar() D1 evaluation.
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

bool Strategy_ComputeZ(double &z)
  {
   z = 0.0;
   if(strategy_formation_bars < 30)
      return false;
   if(Bars(strategy_pair_a, PERIOD_D1) < strategy_min_bars ||
      Bars(strategy_pair_b, PERIOD_D1) < strategy_min_bars)
      return false;

   double a[], b[];
   if(!Strategy_LoadClosedCloses(strategy_pair_a, strategy_formation_bars, a))
      return false;
   if(!Strategy_LoadClosedCloses(strategy_pair_b, strategy_formation_bars, b))
      return false;
   if(a[0] <= 0.0 || b[0] <= 0.0)
      return false;

   double spreads[];
   ArrayResize(spreads, strategy_formation_bars);
   double sum = 0.0;
   for(int i = 0; i < strategy_formation_bars; ++i)
     {
      const double na = a[i] / a[0];
      const double nb = b[i] / b[0];
      spreads[i] = na - nb;
      sum += spreads[i];
     }

   const double mean = sum / (double)strategy_formation_bars;
   double var = 0.0;
   for(int i = 0; i < strategy_formation_bars; ++i)
     {
      const double d = spreads[i] - mean;
      var += d * d;
     }

   const double stdev = MathSqrt(var / (double)MathMax(1, strategy_formation_bars - 1));
   if(stdev <= 0.0)
      return false;

   z = (spreads[strategy_formation_bars - 1] - mean) / stdev;
   return true;
  }

bool Strategy_HasPairPosition(const string symbol, ulong &ticket, datetime &open_time)
  {
   ticket = 0;
   open_time = 0;
   const int slot = Strategy_SlotForSymbol(symbol);
   const int magic = QM_Magic(qm_ea_id, slot);
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
   return (Strategy_HasPairPosition(strategy_pair_a, ticket, open_time) ||
           Strategy_HasPairPosition(strategy_pair_b, ticket, open_time));
  }

int Strategy_HeldD1Bars()
  {
   ulong ticket;
   datetime open_time;
   if(!Strategy_HasPairPosition(strategy_pair_a, ticket, open_time) &&
      !Strategy_HasPairPosition(strategy_pair_b, ticket, open_time))
      return 0;

   int held = 0;
   for(int shift = 1; shift <= strategy_max_hold_bars + 5; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift);
      if(bar_time <= 0)
         break;
      if(bar_time >= open_time)
         held++;
     }
   return held;
  }

bool Strategy_SpreadOk(const string symbol)
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double spread_points = (SymbolInfoDouble(symbol, SYMBOL_ASK) -
                                 SymbolInfoDouble(symbol, SYMBOL_BID)) / point;
   return (spread_points <= (double)strategy_max_spread_points);
  }

double Strategy_LotsForLeg(const string symbol)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return 0.0;
   const double sl_points = (strategy_atr_stop_mult * atr) / point;
   const double lots = QM_LotsForRisk(symbol, sl_points) * 0.5;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;
   double normalized = MathFloor(lots / step) * step;
   normalized = MathMax(min_lot, MathMin(max_lot, normalized));
   return normalized;
  }

bool Strategy_SendLeg(const string symbol, const bool buy, const int slot, ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
   const double lots = Strategy_LotsForLeg(symbol);
   if(atr <= 0.0 || lots <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double price = buy ? ask : bid;
   const double sl = buy ? price - strategy_atr_stop_mult * atr
                         : price + strategy_atr_stop_mult * atr;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lots;
   request.type = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = price;
   request.sl = NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   request.tp = 0.0;
   request.deviation = strategy_deviation_points;
   request.magic = magic;
   request.comment = "QM5_1129_PAIR";
   request.type_filling = ORDER_FILLING_IOC;

   const bool ok = OrderSend(request, result);
   if(!ok || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED))
     {
      QM_LogEvent(QM_WARN, "PAIR_LEG_OPEN_FAIL",
                  StringFormat("{\"symbol\":\"%s\",\"retcode\":%u}", symbol, result.retcode));
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
      if(symbol != strategy_pair_a && symbol != strategy_pair_b)
         continue;
      const int slot = Strategy_SlotForSymbol(symbol);
      if((int)PositionGetInteger(POSITION_MAGIC) != QM_Magic(qm_ea_id, slot))
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
   g_pair_entry_time = 0;
  }

bool Strategy_OpenPair(const double z)
  {
   if(!Strategy_SpreadOk(strategy_pair_a) || !Strategy_SpreadOk(strategy_pair_b))
      return false;

   const bool short_a_long_b = (z > 0.0);
   ulong ticket_a = 0;
   ulong ticket_b = 0;

   const bool ok_a = Strategy_SendLeg(strategy_pair_a, !short_a_long_b, 0, ticket_a);
   const bool ok_b = Strategy_SendLeg(strategy_pair_b, short_a_long_b, 1, ticket_b);
   if(ok_a && ok_b)
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair();
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return !Strategy_IsPairChart();
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

   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar <= 0 || d1_bar == g_last_d1_bar)
      return false;
   g_last_d1_bar = d1_bar;

   double z = 0.0;
   if(!Strategy_ComputeZ(z))
      return false;
   g_last_z = z;

   if(Strategy_PairIsOpen())
     {
      g_close_pair_now = (MathAbs(z) <= strategy_exit_abs_z ||
                          MathAbs(z) >= strategy_stop_abs_z ||
                          Strategy_HeldD1Bars() >= strategy_max_hold_bars);
      return false;
     }

   if(MathAbs(z) < strategy_entry_z)
      return false;

   Strategy_OpenPair(z);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1129\",\"strategy\":\"gatev-pairs-trading-distance\"}");
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
