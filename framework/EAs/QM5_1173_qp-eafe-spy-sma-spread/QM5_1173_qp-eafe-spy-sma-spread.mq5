#property strict
#property version   "5.0"
#property description "QM5_1173 Quantpedia EAFE-US SMA Spread Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1173;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pair_slot           = 0;       // 0 GDAXI/SP500, 1 UK100/SP500
input int    strategy_sma_months          = 12;
input int    strategy_atr_months          = 12;
input double strategy_spread_atr_stop_mult = 2.5;
input double strategy_leg_atr_stop_mult   = 3.0;
input int    strategy_min_monthly_bars    = 48;
input int    strategy_deviation_points    = 20;
input bool   strategy_close_on_missing_data = true;

#define QM5_1173_PAIR_COUNT 2

string   g_eafe_symbols[QM5_1173_PAIR_COUNT] = {"GDAXI.DWX", "UK100.DWX"};
string   g_us_symbol                         = "SP500.DWX";
datetime g_last_rebalance_bar                = 0;
double   g_entry_spread                      = 0.0;
int      g_entry_direction                   = 0;

bool Strategy_ResolvePair(const int slot, string &eafe_symbol, string &us_symbol)
  {
   if(slot < 0 || slot >= QM5_1173_PAIR_COUNT)
      return false;
   eafe_symbol = g_eafe_symbols[slot];
   us_symbol = g_us_symbol;
   return true;
  }

bool Strategy_IsHostChart()
  {
   string eafe_symbol, us_symbol;
   if(!Strategy_ResolvePair(strategy_pair_slot, eafe_symbol, us_symbol))
      return false;
   return (_Symbol == eafe_symbol);
  }

bool Strategy_SelectSymbols()
  {
   string eafe_symbol, us_symbol;
   if(!Strategy_ResolvePair(strategy_pair_slot, eafe_symbol, us_symbol))
      return false;
   return (SymbolSelect(eafe_symbol, true) && SymbolSelect(us_symbol, true));
  }

bool Strategy_HasBars(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return false;
   return (iBars(symbol, PERIOD_MN1) >= strategy_min_monthly_bars);
  }

double Strategy_LogReturn(const string symbol, const int shift)
  {
   const double close_now = iClose(symbol, PERIOD_MN1, shift);
   const double close_prev = iClose(symbol, PERIOD_MN1, shift + 1);
   if(close_now <= 0.0 || close_prev <= 0.0)
      return EMPTY_VALUE;
   return MathLog(close_now / close_prev);
  }

bool Strategy_SpreadSeries(double &spread[], const int bars_needed)
  {
   string eafe_symbol, us_symbol;
   if(!Strategy_ResolvePair(strategy_pair_slot, eafe_symbol, us_symbol))
      return false;
   if(!Strategy_HasBars(eafe_symbol) || !Strategy_HasBars(us_symbol))
      return false;
   if(bars_needed < 3)
      return false;

   ArrayResize(spread, bars_needed);
   ArraySetAsSeries(spread, true);
   spread[bars_needed - 1] = 0.0;

   for(int shift = bars_needed - 2; shift >= 0; --shift)
     {
      const double eafe_ret = Strategy_LogReturn(eafe_symbol, shift + 1);
      const double us_ret = Strategy_LogReturn(us_symbol, shift + 1);
      if(eafe_ret == EMPTY_VALUE || us_ret == EMPTY_VALUE)
         return false;
      spread[shift] = spread[shift + 1] + (eafe_ret - us_ret);
     }
   return true;
  }

bool Strategy_CurrentSpreadSignal(double &current_spread, double &spread_sma, double &spread_atr, int &direction)
  {
   current_spread = 0.0;
   spread_sma = 0.0;
   spread_atr = 0.0;
   direction = 0;

   const int sma_months = MathMax(3, strategy_sma_months);
   const int atr_months = MathMax(3, strategy_atr_months);
   const int bars_needed = MathMax(strategy_min_monthly_bars, MathMax(sma_months, atr_months) + 6);

   double spread[];
   if(!Strategy_SpreadSeries(spread, bars_needed))
      return false;

   current_spread = spread[0];
   for(int i = 0; i < sma_months; ++i)
      spread_sma += spread[i];
   spread_sma /= (double)sma_months;

   for(int i = 0; i < atr_months; ++i)
      spread_atr += MathAbs(spread[i] - spread[i + 1]);
   spread_atr /= (double)atr_months;

   if(!MathIsValidNumber(current_spread) || !MathIsValidNumber(spread_sma) || spread_atr <= 0.0)
      return false;

   direction = (current_spread >= spread_sma) ? 1 : -1;
   return true;
  }

bool Strategy_IsPairPosition()
  {
   const int magic = (int)PositionGetInteger(POSITION_MAGIC);
   if(magic != QM_Magic(qm_ea_id, strategy_pair_slot))
      return false;

   string eafe_symbol, us_symbol;
   if(!Strategy_ResolvePair(strategy_pair_slot, eafe_symbol, us_symbol))
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   return (symbol == eafe_symbol || symbol == us_symbol);
  }

int Strategy_CurrentPairDirection()
  {
   string eafe_symbol, us_symbol;
   if(!Strategy_ResolvePair(strategy_pair_slot, eafe_symbol, us_symbol))
      return 0;

   int eafe_dir = 0;
   int us_dir = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition())
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int dir = (type == POSITION_TYPE_BUY) ? 1 : -1;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol == eafe_symbol)
         eafe_dir = dir;
      else if(symbol == us_symbol)
         us_dir = dir;
     }

   if(eafe_dir == 1 && us_dir == -1)
      return 1;
   if(eafe_dir == -1 && us_dir == 1)
      return -1;
   return 0;
  }

int Strategy_ClosePair(const QM_ExitReason reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition())
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         ++closed;
     }
   return closed;
  }

double Strategy_LotsForLeg(const string symbol, const double atr_mult)
  {
   const double atr = QM_ATR(symbol, PERIOD_MN1, strategy_atr_months, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || atr_mult <= 0.0)
      return 0.0;

   const double sl_points = atr_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * 0.5;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

bool Strategy_SendLeg(const string symbol, const bool buy)
  {
   const double atr = QM_ATR(symbol, PERIOD_MN1, strategy_atr_months, 1);
   const double lots = Strategy_LotsForLeg(symbol, strategy_leg_atr_stop_mult);
   if(atr <= 0.0 || lots <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double price = buy ? ask : bid;
   const double sl = buy ? price - strategy_leg_atr_stop_mult * atr
                         : price + strategy_leg_atr_stop_mult * atr;

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
   request.magic = QM_Magic(qm_ea_id, strategy_pair_slot);
   request.comment = "QM5_1173_SPREAD";
   request.type_filling = ORDER_FILLING_IOC;

   const bool ok = OrderSend(request, result);
   if(!ok || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED))
     {
      QM_LogEvent(QM_WARN, "SPREAD_LEG_OPEN_FAIL",
                  StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"retcode\":%u}", symbol, strategy_pair_slot, result.retcode));
      return false;
     }
   return true;
  }

bool Strategy_OpenPair(const int direction, const double current_spread)
  {
   string eafe_symbol, us_symbol;
   if(!Strategy_ResolvePair(strategy_pair_slot, eafe_symbol, us_symbol))
      return false;

   const bool long_eafe = (direction > 0);
   bool opened = false;
   if(Strategy_SendLeg(eafe_symbol, long_eafe))
      opened = true;
   if(Strategy_SendLeg(us_symbol, !long_eafe))
      opened = true;

   if(!opened)
      Strategy_ClosePair(QM_EXIT_STRATEGY);
   else
     {
      g_entry_spread = current_spread;
      g_entry_direction = direction;
     }
   return opened;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_MN1)
      return true;
   if(!Strategy_IsHostChart())
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "EAFE_SPY_SMA_SPREAD_HOST";
   req.symbol_slot = strategy_pair_slot;
   req.expiration_seconds = 0;

   const datetime last_month = iTime(_Symbol, PERIOD_MN1, 1);
   if(last_month <= 0 || last_month == g_last_rebalance_bar)
      return false;

   double current_spread, spread_sma, spread_atr;
   int target_direction;
   if(!Strategy_CurrentSpreadSignal(current_spread, spread_sma, spread_atr, target_direction))
     {
      if(strategy_close_on_missing_data)
         Strategy_ClosePair(QM_EXIT_STRATEGY);
      g_last_rebalance_bar = last_month;
      return false;
     }

   const int current_direction = Strategy_CurrentPairDirection();
   if(current_direction == target_direction)
     {
      g_last_rebalance_bar = last_month;
      return false;
     }

   if(current_direction != 0)
      Strategy_ClosePair(QM_EXIT_STRATEGY);

   Strategy_OpenPair(target_direction, current_spread);
   g_last_rebalance_bar = last_month;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   double current_spread, spread_sma, spread_atr;
   int direction;
   if(!Strategy_CurrentSpreadSignal(current_spread, spread_sma, spread_atr, direction))
      return;

   int active_direction = Strategy_CurrentPairDirection();
   if(active_direction == 0)
      active_direction = g_entry_direction;
   if(active_direction == 0 || spread_atr <= 0.0)
      return;

   const double entry_spread = (g_entry_spread != 0.0) ? g_entry_spread : current_spread;
   const double adverse_move = active_direction * (entry_spread - current_spread);
   if(adverse_move > strategy_spread_atr_stop_mult * spread_atr)
      Strategy_ClosePair(QM_EXIT_SL_HIT);
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_SelectSymbols())
     {
      if(strategy_close_on_missing_data)
         Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   string eafe_symbol, us_symbol;
   if(!Strategy_ResolvePair(strategy_pair_slot, eafe_symbol, us_symbol))
      return true;

   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(eafe_symbol, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(us_symbol, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(eafe_symbol, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(us_symbol, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   Strategy_SelectSymbols();

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1173\",\"strategy\":\"qp-eafe-spy-sma-spread\"}");
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
