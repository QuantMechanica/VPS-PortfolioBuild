#property strict
#property version   "5.0"
#property description "QM5_1536 Alpha Architect MRAT 21/200"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1536;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

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
input int    strategy_fast_sma_d1          = 21;
input int    strategy_slow_sma_d1          = 200;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.0;
input double strategy_spread_atr_mult      = 0.25;
input int    strategy_sleeve_count_symbols = 2;
input int    strategy_min_valid_symbols    = 8;
input int    strategy_rebalance_day_cutoff = 5;

#define STRATEGY_SYMBOL_COUNT 10

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] = {
   "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "XAUUSD.DWX",
   "XAGUSD.DWX", "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "XTIUSD.DWX"
};

int g_strategy_slots[STRATEGY_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1536_AA_MRAT_NONE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(_Symbol == g_strategy_symbols[i])
         return i;
   return -1;
  }

bool Strategy_IsRebalanceWindow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int cutoff = MathMax(1, MathMin(10, strategy_rebalance_day_cutoff));
   return (dt.day >= 1 && dt.day <= cutoff);
  }

bool Strategy_HasCurrentPosition(ulong &ticket, QM_OrderType &side)
  {
   ticket = 0;
   side = QM_BUY;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ? QM_SELL : QM_BUY;
      return true;
     }
   return false;
  }

bool Strategy_ReadMRAT(double &mrat_values[], bool &valid_values[], int &valid_count)
  {
   valid_count = 0;
   ArrayResize(mrat_values, STRATEGY_SYMBOL_COUNT);
   ArrayResize(valid_values, STRATEGY_SYMBOL_COUNT);

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      mrat_values[i] = 0.0;
      valid_values[i] = false;

      if(!QM_SymbolAssertOrLog(g_strategy_symbols[i]))
         continue;

      const double fast = QM_SMA(g_strategy_symbols[i], PERIOD_D1, strategy_fast_sma_d1, 1, PRICE_CLOSE);
      const double slow = QM_SMA(g_strategy_symbols[i], PERIOD_D1, strategy_slow_sma_d1, 1, PRICE_CLOSE);
      if(fast <= 0.0 || slow <= 0.0)
         continue;

      const double ratio = fast / slow;
      if(ratio <= 0.0 || !MathIsValidNumber(ratio))
         continue;

      mrat_values[i] = ratio;
      valid_values[i] = true;
      valid_count++;
     }

   return (valid_count >= MathMax(2, strategy_min_valid_symbols));
  }

double Strategy_CrossSectionSigma(const double &mrat_values[], const bool &valid_values[], const int valid_count)
  {
   if(valid_count <= 1)
      return 0.0;

   double mean = 0.0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(valid_values[i])
         mean += mrat_values[i];
   mean /= (double)valid_count;

   double var_sum = 0.0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(!valid_values[i])
         continue;
      const double d = mrat_values[i] - mean;
      var_sum += d * d;
     }

   return MathSqrt(var_sum / (double)valid_count);
  }

int Strategy_RankDescending(const int index, const double &mrat_values[], const bool &valid_values[])
  {
   int rank = 1;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(i == index || !valid_values[i])
         continue;
      if(mrat_values[i] > mrat_values[index])
         rank++;
      else if(mrat_values[i] == mrat_values[index] && i < index)
         rank++;
     }
   return rank;
  }

int Strategy_RankAscending(const int index, const double &mrat_values[], const bool &valid_values[])
  {
   int rank = 1;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(i == index || !valid_values[i])
         continue;
      if(mrat_values[i] < mrat_values[index])
         rank++;
      else if(mrat_values[i] == mrat_values[index] && i < index)
         rank++;
     }
   return rank;
  }

bool Strategy_SelectionForCurrentSymbol(QM_OrderType &side, int &active_selected_count)
  {
   side = QM_BUY;
   active_selected_count = 0;

   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return false;

   double mrat_values[];
   bool valid_values[];
   int valid_count = 0;
   if(!Strategy_ReadMRAT(mrat_values, valid_values, valid_count))
      return false;
   if(!valid_values[current_index])
      return false;

   const int sleeve_count = MathMax(1, MathMin(strategy_sleeve_count_symbols, valid_count / 2));
   if(sleeve_count < 2)
      return false;

   const double sigma = Strategy_CrossSectionSigma(mrat_values, valid_values, valid_count);
   if(sigma <= 0.0)
      return false;

   int long_count = 0;
   int short_count = 0;
   int current_side = 0;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(!valid_values[i])
         continue;

      const bool long_selected = (Strategy_RankDescending(i, mrat_values, valid_values) <= sleeve_count &&
                                  (mrat_values[i] - 1.0) >= sigma);
      const bool short_selected = (Strategy_RankAscending(i, mrat_values, valid_values) <= sleeve_count &&
                                   (1.0 - mrat_values[i]) >= sigma);

      if(long_selected)
        {
         long_count++;
         if(i == current_index)
            current_side = 1;
        }
      if(short_selected)
        {
         short_count++;
         if(i == current_index)
            current_side = -1;
        }
     }

   if(long_count < sleeve_count || short_count < sleeve_count)
      return false;

   active_selected_count = long_count + short_count;
   if(current_side > 0)
     {
      side = QM_BUY;
      return true;
     }
   if(current_side < 0)
     {
      side = QM_SELL;
      return true;
     }

   return false;
  }

bool Strategy_ConfigureEqualRisk(const int active_selected_count)
  {
   if(active_selected_count <= 0)
      return false;

   const double k = 1.0 / (double)active_selected_count;
   if(RISK_PERCENT > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_PERCENT, RISK_PERCENT * k, 0.0, PORTFOLIO_WEIGHT);
   if(RISK_FIXED > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, 0.0, RISK_FIXED * k, PORTFOLIO_WEIGHT);
   return false;
  }

bool Strategy_SpreadTooWide()
  {
   if(strategy_spread_atr_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask <= bid)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;

   return ((ask - bid) > strategy_spread_atr_mult * atr);
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(Strategy_SpreadTooWide())
      return true;
   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   if(!Strategy_IsRebalanceWindow())
      return false;

   ulong ticket = 0;
   QM_OrderType open_side = QM_BUY;
   if(Strategy_HasCurrentPosition(ticket, open_side))
      return false;

   QM_OrderType selected_side = QM_BUY;
   int active_selected_count = 0;
   if(!Strategy_SelectionForCurrentSymbol(selected_side, active_selected_count))
      return false;
   if(!Strategy_ConfigureEqualRisk(active_selected_count))
      return false;

   const double entry = (selected_side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, selected_side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(selected_side == QM_BUY && sl >= entry)
      return false;
   if(selected_side == QM_SELL && sl <= entry)
      return false;

   req.type = selected_side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (selected_side == QM_BUY) ? "QM5_1536_AA_MRAT_LONG"
                                          : "QM5_1536_AA_MRAT_SHORT";
   req.symbol_slot = g_strategy_slots[Strategy_CurrentSymbolIndex()];
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // The card specifies no trailing, break-even, pyramiding, or averaging.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!Strategy_IsRebalanceWindow())
      return false;

   ulong ticket = 0;
   QM_OrderType open_side = QM_BUY;
   if(!Strategy_HasCurrentPosition(ticket, open_side))
      return false;

   QM_OrderType selected_side = QM_BUY;
   int active_selected_count = 0;
   if(!Strategy_SelectionForCurrentSymbol(selected_side, active_selected_count))
      return true;

   return (selected_side != open_side);
  }

// News Filter Hook (callable for P8 News Impact phase).
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

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, MathMax(300, strategy_slow_sma_d1 + strategy_atr_period_d1 + 20));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1536_aa-mrat-21-200\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
