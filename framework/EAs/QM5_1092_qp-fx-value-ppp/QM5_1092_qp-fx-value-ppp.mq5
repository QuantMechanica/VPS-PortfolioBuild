#property strict
#property version   "5.0"
#property description "QM5_1092 Quantpedia FX Value PPP"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1092;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rebalance_months        = 3;
input int    strategy_rebalance_window_days   = 7;
input int    strategy_bucket_size             = 3;
input int    strategy_atr_period              = 20;
input double strategy_atr_sl_mult             = 5.0;
input int    strategy_max_spread_points       = 30;
input int    strategy_stale_days_monthly      = 45;
input int    strategy_stale_days_quarterly    = 120;
input int    strategy_ppp_observation_yyyymmdd = 20231231;
input double strategy_ppp_eur_usd             = 1.5000;
input double strategy_ppp_gbp_usd             = 1.4000;
input double strategy_ppp_jpy_usd             = 0.0075;
input double strategy_ppp_aud_usd             = 0.7500;
input double strategy_ppp_cad_usd             = 0.8000;
input double strategy_ppp_chf_usd             = 1.1000;
input double strategy_ppp_nzd_usd             = 0.6800;

const int STRATEGY_UNIVERSE_SIZE = 7;
string g_strategy_symbols[7] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "USDCHF.DWX",
   "NZDUSD.DWX"
  };

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_IsUsdBasePair(const int index)
  {
   return (index == 2 || index == 4 || index == 5);
  }

double Strategy_FairValueUsdPerCurrency(const int index)
  {
   if(index == 0)
      return strategy_ppp_eur_usd;
   if(index == 1)
      return strategy_ppp_gbp_usd;
   if(index == 2)
      return strategy_ppp_jpy_usd;
   if(index == 3)
      return strategy_ppp_aud_usd;
   if(index == 4)
      return strategy_ppp_cad_usd;
   if(index == 5)
      return strategy_ppp_chf_usd;
   if(index == 6)
      return strategy_ppp_nzd_usd;
   return 0.0;
  }

datetime Strategy_ObservationDate()
  {
   const int y = strategy_ppp_observation_yyyymmdd / 10000;
   const int m = (strategy_ppp_observation_yyyymmdd / 100) % 100;
   const int d = strategy_ppp_observation_yyyymmdd % 100;
   if(y < 1970 || m < 1 || m > 12 || d < 1 || d > 31)
      return 0;
   return StringToTime(StringFormat("%04d.%02d.%02d 00:00", y, m, d));
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int months = (strategy_rebalance_months <= 1) ? 1 : 3;
   const int bucket_month = ((dt.mon - 1) / months) * months + 1;
   return dt.year * 100 + bucket_month;
  }

bool Strategy_IsRebalanceWindow(const datetime t)
  {
   if(strategy_rebalance_months != 1 && strategy_rebalance_months != 3)
      return false;
   if(strategy_rebalance_window_days < 1)
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.day > strategy_rebalance_window_days)
      return false;
   if(strategy_rebalance_months <= 1)
      return true;
   return (dt.mon == 1 || dt.mon == 4 || dt.mon == 7 || dt.mon == 10);
  }

bool Strategy_PppObservationFresh()
  {
   const datetime obs = Strategy_ObservationDate();
   if(obs <= 0)
      return false;

   const datetime now = TimeCurrent();
   if(obs > now)
      return false;

   const int stale_days = (strategy_rebalance_months <= 1) ? strategy_stale_days_monthly : strategy_stale_days_quarterly;
   if(stale_days <= 0)
      return true;
   return ((now - obs) <= stale_days * 86400);
  }

double Strategy_SpotUsdPerCurrency(const int index)
  {
   if(index < 0 || index >= STRATEGY_UNIVERSE_SIZE)
      return 0.0;

   const string symbol = g_strategy_symbols[index];
   SymbolSelect(symbol, true);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double mid = 0.0;
   if(bid > 0.0 && ask > 0.0)
      mid = 0.5 * (bid + ask);
   else if(bid > 0.0)
      mid = bid;
   else if(ask > 0.0)
      mid = ask;
   if(mid <= 0.0)
      return 0.0;

   if(Strategy_IsUsdBasePair(index))
      return 1.0 / mid;
   return mid;
  }

bool Strategy_DeviationByIndex(const int index, double &out_deviation)
  {
   out_deviation = 0.0;
   const double fair = Strategy_FairValueUsdPerCurrency(index);
   const double spot = Strategy_SpotUsdPerCurrency(index);
   if(fair <= 0.0 || spot <= 0.0)
      return false;

   out_deviation = (spot / fair) - 1.0;
   return true;
  }

int Strategy_DirectionForSymbol()
  {
   if(!Strategy_PppObservationFresh())
      return 0;

   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[7];
   int indexes[7];
   int count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double deviation = 0.0;
      if(!Strategy_DeviationByIndex(i, deviation))
         continue;
      scores[count] = deviation;
      indexes[count] = i;
      ++count;
     }

   if(count < 3)
      return 0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] < scores[i])
           {
            const double score_tmp = scores[i];
            scores[i] = scores[j];
            scores[j] = score_tmp;
            const int index_tmp = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = index_tmp;
           }

   const int bucket_size = MathMin(MathMax(strategy_bucket_size, 1), count / 2);
   int currency_direction = 0;
   for(int i = 0; i < bucket_size; ++i)
      if(indexes[i] == current_index)
         currency_direction = 1;
   for(int i = count - bucket_size; i < count; ++i)
      if(indexes[i] == current_index)
         currency_direction = -1;

   if(currency_direction == 0)
      return 0;
   if(Strategy_IsUsdBasePair(current_index))
      return -currency_direction;
   return currency_direction;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(ask < bid)
      return false;
   if(ask == bid)
      return true;

   const double spread_points = (ask - bid) / point;
   return (spread_points <= strategy_max_spread_points);
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

bool Strategy_PositionOpenedBeforeCurrentRebalance()
  {
   const int magic = QM_FrameworkMagic();
   const int current_key = Strategy_RebalanceKey(TimeCurrent());
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
      return (Strategy_RebalanceKey(open_time) < current_key);
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_rebalance_months != 1 && strategy_rebalance_months != 3)
      return true;
   if(strategy_bucket_size < 1 || strategy_bucket_size > 3)
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

   const datetime now = TimeCurrent();
   if(!Strategy_IsRebalanceWindow(now))
      return false;

   const int rebalance_key = Strategy_RebalanceKey(now);
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_DirectionForSymbol();
   if(direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   req.symbol_slot = Strategy_CurrentSymbolIndex();
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (direction > 0) ? "QP_FX_VALUE_PPP_UNDERVALUED_LONG" : "QP_FX_VALUE_PPP_OVERVALUED_SHORT";
   if(req.sl <= 0.0)
      return false;

   g_last_entry_rebalance_key = rebalance_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: the card specifies only the ATR hard stop and scheduled rebalance exits.
  }

bool Strategy_ExitSignal()
  {
   const datetime now = TimeCurrent();
   if(!Strategy_IsRebalanceWindow(now))
      return false;

   const int rebalance_key = Strategy_RebalanceKey(now);
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   if(!Strategy_PositionOpenedBeforeCurrentRebalance())
      return false;

   g_last_exit_rebalance_key = rebalance_key;
   return true;
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
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, 40);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1092_qp_fx_value_ppp\"}");
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
