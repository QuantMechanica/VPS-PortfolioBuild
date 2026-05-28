#property strict
#property version   "5.0"
#property description "QM5_1077 Allocate Smartly Sector Relative Strength"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1077;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 0.333333;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_symbol_1          = "NDX.DWX";
input string strategy_symbol_2          = "WS30.DWX";
input string strategy_symbol_3          = "GDAXI.DWX";
input string strategy_symbol_4          = "UK100.DWX";
input string strategy_symbol_5          = "XAUUSD.DWX";
input string strategy_symbol_6          = "XTIUSD.DWX";
input string strategy_symbol_7          = "SP500.DWX";
input int    strategy_top_n             = 3;
input int    strategy_lookback_months   = 12;
input bool   strategy_use_sma_filter    = true;
input int    strategy_sma_months        = 10;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 3.0;

const int STRATEGY_UNIVERSE_COUNT = 7;
string g_strategy_symbols[7];

void Strategy_LoadUniverse()
  {
   g_strategy_symbols[0] = strategy_symbol_1;
   g_strategy_symbols[1] = strategy_symbol_2;
   g_strategy_symbols[2] = strategy_symbol_3;
   g_strategy_symbols[3] = strategy_symbol_4;
   g_strategy_symbols[4] = strategy_symbol_5;
   g_strategy_symbols[5] = strategy_symbol_6;
   g_strategy_symbols[6] = strategy_symbol_7;
  }

int Strategy_D1BarsForMonths(const int months)
  {
   if(months <= 1)
      return 22;
   return months * 21;
  }

int Strategy_MonthOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.mon;
  }

bool Strategy_IsMonthlyRebalance()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || prior_d1 <= 0)
      return false;
   return (Strategy_MonthOf(current_d1) != Strategy_MonthOf(prior_d1));
  }

int Strategy_SymbolSlot(const string symbol)
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
     {
      if(g_strategy_symbols[i] != "" && symbol == g_strategy_symbols[i])
         return i;
     }
   return -1;
  }

double Strategy_Close(const string symbol, const int shift)
  {
   if(symbol == "" || shift < 0)
      return 0.0;
   if(!SymbolSelect(symbol, true))
      return 0.0;
   return QM_SMA(symbol, PERIOD_D1, 1, shift);
  }

double Strategy_Return(const string symbol, const int bars_back)
  {
   if(symbol == "" || bars_back < 1)
      return -DBL_MAX;
   if(!SymbolSelect(symbol, true))
      return -DBL_MAX;
   if(Bars(symbol, PERIOD_D1) < bars_back + 2)
      return -DBL_MAX;

   const double recent_close = Strategy_Close(symbol, 1);
   const double lookback_close = Strategy_Close(symbol, 1 + bars_back);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return -DBL_MAX;

   return (recent_close / lookback_close) - 1.0;
  }

bool Strategy_PassesTrendFilter(const string symbol)
  {
   if(!strategy_use_sma_filter)
      return true;

   const int sma_bars = Strategy_D1BarsForMonths(strategy_sma_months);
   if(Bars(symbol, PERIOD_D1) < sma_bars + 2)
      return false;

   const double recent_close = Strategy_Close(symbol, 1);
   const double sma = QM_SMA(symbol, PERIOD_D1, sma_bars, 1);
   if(recent_close <= 0.0 || sma <= 0.0)
      return false;

   return (recent_close > sma);
  }

void Strategy_RankedSlots(int &ranked_slots[], double &ranked_scores[])
  {
   ArrayResize(ranked_slots, STRATEGY_UNIVERSE_COUNT);
   ArrayResize(ranked_scores, STRATEGY_UNIVERSE_COUNT);

   const int lookback_bars = Strategy_D1BarsForMonths(strategy_lookback_months);
   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
     {
      ranked_slots[i] = i;
      ranked_scores[i] = Strategy_Return(g_strategy_symbols[i], lookback_bars);
     }

   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT - 1; ++i)
     {
      for(int j = i + 1; j < STRATEGY_UNIVERSE_COUNT; ++j)
        {
         if(ranked_scores[j] > ranked_scores[i])
           {
            const double score_tmp = ranked_scores[i];
            ranked_scores[i] = ranked_scores[j];
            ranked_scores[j] = score_tmp;

            const int slot_tmp = ranked_slots[i];
            ranked_slots[i] = ranked_slots[j];
            ranked_slots[j] = slot_tmp;
           }
        }
     }
  }

bool Strategy_IsSelectedSymbol(const string symbol)
  {
   const int max_selected = MathMax(1, MathMin(strategy_top_n, STRATEGY_UNIVERSE_COUNT));
   int ranked_slots[];
   double ranked_scores[];
   Strategy_RankedSlots(ranked_slots, ranked_scores);

   int selected_count = 0;
   for(int rank = 0; rank < STRATEGY_UNIVERSE_COUNT && selected_count < max_selected; ++rank)
     {
      const int slot = ranked_slots[rank];
      if(slot < 0 || slot >= STRATEGY_UNIVERSE_COUNT)
         continue;
      if(ranked_scores[rank] == -DBL_MAX)
         continue;
      const string ranked_symbol = g_strategy_symbols[slot];
      if(!Strategy_PassesTrendFilter(ranked_symbol))
         continue;

      ++selected_count;
      if(ranked_symbol == symbol)
         return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const int expected_slot = Strategy_SymbolSlot(_Symbol);
   if(expected_slot < 0)
      return true;
   return (expected_slot != qm_magic_slot_offset);
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

   if(!Strategy_IsMonthlyRebalance())
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsSelectedSymbol(_Symbol))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.sl = sl;
   req.reason = "AS_SECTOR_RS_MONTHLY_TOPN_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline holds until monthly rotation; only framework SL/Friday/KS exits apply intramonth.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthlyRebalance())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   return !Strategy_IsSelectedSymbol(_Symbol);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_LoadUniverse();

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
