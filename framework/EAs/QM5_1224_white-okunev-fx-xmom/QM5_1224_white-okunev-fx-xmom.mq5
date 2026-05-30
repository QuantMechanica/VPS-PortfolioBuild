#property strict
#property version   "5.0"
#property description "QM5_1224 White-Okunev FX Cross-Sectional MA Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1224;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 500.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period_d1      = 120;
input int    strategy_min_d1_bars        = 160;
input int    strategy_exit_rank_band     = 2;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 3.0;
input double strategy_basket_loss_r      = 2.0;
input int    strategy_rebalance_mode     = 1;      // 0=weekly, 1=monthly
input int    strategy_spread_days        = 20;
input double strategy_spread_mult        = 3.0;

const int STRATEGY_UNIVERSE_SIZE = 7;
string g_symbols[7] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX",
   "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX"
  };

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key  = 0;
int g_last_kill_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_IsUsdBaseSymbol(const string symbol)
  {
   return (symbol == "USDCAD.DWX" || symbol == "USDCHF.DWX" || symbol == "USDJPY.DWX");
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(strategy_rebalance_mode == 0)
      return dt.year * 1000 + (dt.day_of_year / 7);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsRebalanceClosedBar()
  {
   if(_Period != PERIOD_D1)
      return false;

   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);

   if(strategy_rebalance_mode == 0)
      return (Strategy_RebalanceKey(closed_bar) != Strategy_RebalanceKey(current_bar));
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
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

double Strategy_SmaClose(const string symbol, const int period)
  {
   if(period <= 0 || period > 512)
      return 0.0;

   double sum = 0.0;
   int count = 0;
   for(int shift = 1; shift <= period; ++shift)
     {
      const double close = iClose(symbol, PERIOD_D1, shift);
      if(close <= 0.0)
         return 0.0;
      sum += close;
      ++count;
     }

   if(count != period)
      return 0.0;
   return sum / (double)period;
  }

bool Strategy_SymbolScore(const string symbol, double &out_score)
  {
   out_score = 0.0;
   if(strategy_sma_period_d1 <= 0 || strategy_min_d1_bars < strategy_sma_period_d1 + 1)
      return false;

   SymbolSelect(symbol, true);
   if(Bars(symbol, PERIOD_D1) < strategy_min_d1_bars)
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double sma_close = Strategy_SmaClose(symbol, strategy_sma_period_d1);
   if(recent_close <= 0.0 || sma_close <= 0.0)
      return false;

   double raw_score = (recent_close / sma_close) - 1.0;
   if(Strategy_IsUsdBaseSymbol(symbol))
      raw_score = -raw_score;

   out_score = raw_score;
   return true;
  }

int Strategy_RankDirectionForSymbol(const int exit_band)
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[7];
   int indexes[7];
   int count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double score = 0.0;
      if(!Strategy_SymbolScore(g_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count < 5)
      return 0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] < scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;
            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   const int band = MathMin(MathMax(exit_band, 1), count / 2);
   int foreign_ccy_direction = 0;
   for(int i = 0; i < band; ++i)
      if(indexes[i] == current_index)
         foreign_ccy_direction = -1;
   for(int i = count - band; i < count; ++i)
      if(indexes[i] == current_index)
         foreign_ccy_direction = 1;

   if(foreign_ccy_direction == 0)
      return 0;
   return Strategy_IsUsdBaseSymbol(g_symbols[current_index]) ? -foreign_ccy_direction : foreign_ccy_direction;
  }

double Strategy_OpenBasketProfit()
  {
   double profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      int slot = -1;
      for(int s = 0; s < STRATEGY_UNIVERSE_SIZE; ++s)
         if(g_symbols[s] == symbol)
            slot = s;
      if(slot < 0)
         continue;

      const int expected_magic = QM_Magic(qm_ea_id, slot);
      if((int)PositionGetInteger(POSITION_MAGIC) != expected_magic)
         continue;

      profit += PositionGetDouble(POSITION_PROFIT);
     }
   return profit;
  }

bool Strategy_CloseBasketIfLossLimit()
  {
   if(strategy_basket_loss_r <= 0.0)
      return false;

   const int rebalance_key = Strategy_RebalanceKey(TimeCurrent());
   if(rebalance_key > 0 && rebalance_key == g_last_kill_rebalance_key)
      return false;

   const double loss_limit = strategy_basket_loss_r * MathMax(RISK_FIXED, 1.0);
   if(Strategy_OpenBasketProfit() > -loss_limit)
      return false;

   bool closed_any = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      int slot = -1;
      for(int s = 0; s < STRATEGY_UNIVERSE_SIZE; ++s)
         if(g_symbols[s] == symbol)
            slot = s;
      if(slot < 0)
         continue;

      const int expected_magic = QM_Magic(qm_ea_id, slot);
      if((int)PositionGetInteger(POSITION_MAGIC) != expected_magic)
         continue;

      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      closed_any = true;
     }

   if(closed_any)
      g_last_kill_rebalance_key = rebalance_key;
   return closed_any;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_sma_period_d1 <= 0 || strategy_min_d1_bars < 160)
      return true;
   if(strategy_exit_rank_band <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_rebalance_mode < 0 || strategy_rebalance_mode > 1)
      return true;
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

   if(!Strategy_IsRebalanceClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_RankDirectionForSymbol(1);
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
   req.symbol_slot = Strategy_CurrentSymbolIndex();
   req.reason = (direction > 0) ? "WHITE_OKUNEV_FX_TOP_LONG" : "WHITE_OKUNEV_FX_BOTTOM_SHORT";
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= req.price)
      return false;
   if(req.type == QM_SELL && req.sl <= req.price)
      return false;

   g_last_entry_rebalance_key = rebalance_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseBasketIfLossLimit();
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsRebalanceClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;

   const int desired_direction = Strategy_RankDirectionForSymbol(strategy_exit_rank_band);
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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const int current_direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
      if(desired_direction == 0 || desired_direction != current_direction)
        {
         g_last_exit_rebalance_key = rebalance_key;
         return true;
        }
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_min_d1_bars + 5);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1224\",\"ea\":\"white-okunev-fx-xmom\"}");
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
