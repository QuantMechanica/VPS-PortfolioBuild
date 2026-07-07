#property strict
#property version   "5.0"
#property description "QM5_12934 Alpha Architect commodity spot 12-month reversal"

#include <QM/QM_Common.mqh>

#define STRATEGY_BASKET_SIZE 4

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12934;
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
input int    strategy_lookback_days        = 260;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_min_quintile_universe = 10;
input int    strategy_max_spread_points    = 5000;

string g_strategy_symbols[STRATEGY_BASKET_SIZE] =
  {
   "XAUUSD.DWX",
   "XAGUSD.DWX",
   "XTIUSD.DWX",
   "XNGUSD.DWX"
  };

int g_last_entry_period_key = 0;
int g_last_exit_period_key = 0;

int Strategy_BasketIndex(const string symbol)
  {
   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      if(g_strategy_symbols[i] == symbol)
         return i;
     }
   return -1;
  }

int Strategy_BasketSignalForSymbol(const string symbol)
  {
   const int target_index = Strategy_BasketIndex(symbol);
   if(target_index < 0)
      return 0;
   if(strategy_lookback_days < 2)
      return 0;

   double momentum[STRATEGY_BASKET_SIZE];
   bool valid[STRATEGY_BASKET_SIZE];
   int valid_count = 0;

   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      momentum[i] = 0.0;
      valid[i] = false;

      const string sym = g_strategy_symbols[i];
      if(!QM_SymbolAssertOrLog(sym))
         continue;

      const double mom = QM_Momentum(sym, PERIOD_D1, strategy_lookback_days, 1);
      if(mom <= 0.0)
         continue;

      momentum[i] = mom;
      valid[i] = true;
      ++valid_count;
     }

   if(valid_count < 2 || !valid[target_index])
      return 0;

   int bucket_count = 1;
   if(valid_count >= strategy_min_quintile_universe)
     {
      bucket_count = valid_count / 5;
      if(bucket_count < 1)
         bucket_count = 1;
     }

   int rank_ascending = 0;
   const double target_mom = momentum[target_index];
   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      if(!valid[i] || i == target_index)
         continue;
      if(momentum[i] < target_mom ||
         (MathAbs(momentum[i] - target_mom) <= 1.0e-9 && i < target_index))
         ++rank_ascending;
     }

   if(rank_ascending < bucket_count)
      return 1;
   if(rank_ascending >= valid_count - bucket_count)
      return -1;
   return 0;
  }

bool Strategy_SelectOurPosition(int &direction)
  {
   direction = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(strategy_max_spread_points > 0 && point > 0.0 && ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int period_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(period_key <= 0)
      return false;
   if(period_key == g_last_entry_period_key)
      return false;
   g_last_entry_period_key = period_key;

   int existing_direction = 0;
   if(Strategy_SelectOurPosition(existing_direction))
      return false;

   const int signal = Strategy_BasketSignalForSymbol(_Symbol);
   if(signal == 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   if(signal > 0)
     {
      req.type = QM_BUY;
      req.reason = "AA_COMM_SPOT_REV_LONG_LOSER";
     }
   else
     {
      req.type = QM_SELL;
      req.reason = "AA_COMM_SPOT_REV_SHORT_WINNER";
     }

   const double entry_price = (signal > 0) ? ask : bid;
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   int existing_direction = 0;
   if(!Strategy_SelectOurPosition(existing_direction))
      return false;

   const int period_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(period_key <= 0)
      return false;
   if(period_key == g_last_exit_period_key)
      return false;
   g_last_exit_period_key = period_key;

   const int signal = Strategy_BasketSignalForSymbol(_Symbol);
   if(signal == 0)
      return true;
   return (signal != existing_direction);
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

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols,
                          PERIOD_D1,
                          strategy_lookback_days + strategy_atr_period + 20);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12934_aa_comm_spot_rev_card\"}");
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

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
