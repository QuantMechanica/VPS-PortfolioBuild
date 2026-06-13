#property strict
#property version   "5.0"
#property description "QM5_1056 Moskowitz TSMOM Multi-Asset"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1056;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

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
input int    strategy_lookback_d1_bars   = 252;
input int    strategy_min_d1_bars        = 275;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 4.0;
input int    strategy_spread_days        = 20;
input double strategy_spread_mult        = 3.0;

#define QM5_1056_SYMBOL_COUNT 10

string g_symbols[QM5_1056_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX", "USDCAD.DWX",
   "XAUUSD.DWX", "XTIUSD.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX"
  };

int g_slots[QM5_1056_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1056_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthRebalanceBar()
  {
   if(_Period != PERIOD_D1)
      return false;

   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: monthly D1 boundary detection
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: monthly D1 boundary detection
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.year != current_dt.year || closed_dt.mon != current_dt.mon);
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

double Strategy_MedianDailySpreadPoints()
  {
   const int n = strategy_spread_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

int Strategy_TsmomDirection()
  {
   if(strategy_lookback_d1_bars <= 0)
      return 0;
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_d1_bars, strategy_lookback_d1_bars + 5)) // perf-allowed: fixed D1 history availability guard
      return 0;

   const double recent_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: card requires 12-month D1 return sign
   const double lookback_close = iClose(_Symbol, PERIOD_D1, 1 + strategy_lookback_d1_bars); // perf-allowed: card requires 12-month D1 return sign
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return 0;

   if(recent_close > lookback_close)
      return 1;
   if(recent_close < lookback_close)
      return -1;
   return 0;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthRebalanceBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 0)); // perf-allowed: monthly duplicate guard
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_TsmomDirection();
   if(direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.reason = (direction > 0) ? "QM5_1056_TSMOM_12M_LONG" : "QM5_1056_TSMOM_12M_SHORT";
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= req.price)
      return false;
   if(req.type == QM_SELL && req.sl <= req.price)
      return false;

   g_last_entry_rebalance_key = rebalance_key;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthRebalanceBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 0)); // perf-allowed: monthly duplicate guard
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;

   if(Strategy_HasOpenPosition())
     {
      g_last_exit_rebalance_key = rebalance_key;
      return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1056\",\"ea\":\"moskowitz-tsmom-multiasset\"}");
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
