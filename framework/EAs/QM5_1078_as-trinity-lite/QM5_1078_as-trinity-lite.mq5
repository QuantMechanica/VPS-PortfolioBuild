#property strict
#property version   "5.0"
#property description "QM5_1078 Allocate Smartly Trinity Portfolio Lite"

#include <QM/QM_Common.mqh>

#define STRATEGY_SYMBOL_COUNT 6

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1078;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.333333;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_concentration_count = 3;
input int    strategy_sma_months          = 10;
input int    strategy_min_monthly_bars    = 14;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 6.0;
input int    strategy_max_spread_points   = 5000;

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
  };

int g_strategy_slots[STRATEGY_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5};
int g_last_entry_month_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(g_strategy_symbols[i] == _Symbol)
         return i;
     }
   return -1;
  }

bool Strategy_ConfigMatchesSymbol()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return false;
   return (g_strategy_slots[idx] == qm_magic_slot_offset);
  }

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthEndClosedBar()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
  }

bool Strategy_ReadMonthEndCloses(const string symbol, double &closes[])
  {
   if(symbol == "" || !SymbolSelect(symbol, true))
      return false;

   const int required = MathMax(strategy_min_monthly_bars,
                                MathMax(strategy_sma_months + 1, 13));
   ArrayResize(closes, required);

   int found = 0;
   int last_key = 0;
   for(int shift = 1; shift < 900 && found < required; ++shift)
     {
      const datetime bar_time = iTime(symbol, PERIOD_D1, shift);
      const double close = iClose(symbol, PERIOD_D1, shift);
      if(bar_time <= 0 || close <= 0.0)
         break;

      const int key = Strategy_MonthKey(bar_time);
      if(key == last_key)
         continue;

      closes[found] = close;
      found++;
      last_key = key;
     }

   return (found >= required);
  }

bool Strategy_CompositeMomentum(const string symbol, double &score)
  {
   score = -DBL_MAX;

   double closes[];
   if(!Strategy_ReadMonthEndCloses(symbol, closes))
      return false;
   if(ArraySize(closes) < 13 || closes[0] <= 0.0)
      return false;

   const int shifts[4] = {1, 3, 6, 12};
   double total = 0.0;
   for(int i = 0; i < 4; ++i)
     {
      const int shift = shifts[i];
      if(closes[shift] <= 0.0)
         return false;
      total += (closes[0] / closes[shift]) - 1.0;
     }

   score = total / 4.0;
   return true;
  }

bool Strategy_TrendFilterPasses(const string symbol)
  {
   if(strategy_sma_months <= 0)
      return false;

   double closes[];
   if(!Strategy_ReadMonthEndCloses(symbol, closes))
      return false;
   if(ArraySize(closes) < strategy_sma_months || closes[0] <= 0.0)
      return false;

   double sum = 0.0;
   for(int i = 0; i < strategy_sma_months; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      sum += closes[i];
     }

   const double sma = sum / (double)strategy_sma_months;
   return (sma > 0.0 && closes[0] > sma);
  }

bool Strategy_IsSelectedSymbol(const string symbol)
  {
   const int concentration = MathMax(1, MathMin(strategy_concentration_count, STRATEGY_SYMBOL_COUNT));

   double target_score = 0.0;
   if(!Strategy_CompositeMomentum(symbol, target_score))
      return false;

   int better_count = 0;
   int target_idx = -1;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(g_strategy_symbols[i] == symbol)
        {
         target_idx = i;
         break;
        }
     }
   if(target_idx < 0)
      return false;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      double peer_score = 0.0;
      if(!Strategy_CompositeMomentum(g_strategy_symbols[i], peer_score))
         return false;
      if(peer_score > target_score || (peer_score == target_score && i < target_idx))
         better_count++;
     }

   return (better_count < concentration);
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_SpreadWithinCap()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool Strategy_ShouldHoldCurrentSymbol()
  {
   return (Strategy_IsSelectedSymbol(_Symbol) && Strategy_TrendFilterPasses(_Symbol));
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_ConfigMatchesSymbol())
      return true;
   if(!Strategy_SpreadWithinCap())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "AS_TRINITY_LITE_TOP_MOMENTUM_TREND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_MonthKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_month_key)
      return false;
   g_last_entry_month_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_ShouldHoldCurrentSymbol())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Trinity Lite rebalances monthly; no trailing, BE, pyramiding, or partials.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthEndClosedBar())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   return !Strategy_ShouldHoldCurrentSymbol();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1078\",\"ea\":\"as-trinity-lite\"}");
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
