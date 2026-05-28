#property strict
#property version   "5.0"
#property description "QM5_1092 Quantpedia FX Value PPP"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1092;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_rebalance_months   = 3;
input int    strategy_rebalance_hour     = 1;
input int    strategy_bucket_size        = 3;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 5.0;
input int    strategy_spread_days        = 20;
input double strategy_spread_mult        = 3.0;
input int    strategy_stale_days_monthly = 45;
input int    strategy_stale_days_quarterly = 120;
input string strategy_ppp_csv_path       = "QM5_1092_ppp_fair_values.csv";

const int STRATEGY_UNIVERSE_SIZE = 7;
string g_symbols[7] = {"EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX", "USDCAD.DWX", "USDCHF.DWX", "NZDUSD.DWX"};
string g_ccys[7]    = {"EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int months = (strategy_rebalance_months <= 1) ? 1 : 3;
   const int bucket_month = ((dt.mon - 1) / months) * months + 1;
   return dt.year * 100 + bucket_month;
  }

bool Strategy_IsRebalanceClosedBar()
  {
   if(_Period != PERIOD_H1 && _Period != PERIOD_D1)
      return false;

   const datetime closed_bar = iTime(_Symbol, _Period, 1);
   const datetime current_bar = iTime(_Symbol, _Period, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   if(current_dt.hour < strategy_rebalance_hour)
      return false;

   if(strategy_rebalance_months <= 1)
      return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);

   const int closed_q = (closed_dt.mon - 1) / 3;
   const int current_q = (current_dt.mon - 1) / 3;
   return (closed_q != current_q || closed_dt.year != current_dt.year);
  }

datetime Strategy_ParseDate(const string raw)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) < 10)
      return 0;
   StringReplace(s, "-", ".");
   return StringToTime(s + " 00:00");
  }

bool Strategy_ReadLatestPppFairValue(const string ccy, double &out_fair_value, datetime &out_obs_date)
  {
   out_fair_value = 0.0;
   out_obs_date = 0;
   if(strategy_ppp_csv_path == "")
      return false;

   int handle = FileOpen(strategy_ppp_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_ppp_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      const string ccy_field = FileReadString(handle);
      const string ppp_field = FileReadString(handle);
      const string cpi_field = FileReadString(handle);
      if(date_field == "" || ccy_field == "")
         continue;
      if(ccy_field != ccy)
         continue;

      const datetime obs_date = Strategy_ParseDate(date_field);
      const double cpi_value = StringToDouble(cpi_field);
      const double ppp_value = StringToDouble(ppp_field);
      const double fair_value = (cpi_value > 0.0) ? cpi_value : ppp_value;
      if(obs_date <= 0 || fair_value <= 0.0)
         continue;
      if(obs_date > TimeCurrent())
         continue;
      if(obs_date >= out_obs_date)
        {
         out_obs_date = obs_date;
         out_fair_value = fair_value;
        }
     }

   FileClose(handle);
   if(out_fair_value <= 0.0 || out_obs_date <= 0)
      return false;

   const int stale_days = (strategy_rebalance_months <= 1) ? strategy_stale_days_monthly : strategy_stale_days_quarterly;
   if(stale_days > 0 && (TimeCurrent() - out_obs_date) > stale_days * 86400)
      return false;

   return true;
  }

double Strategy_SpotUsdPerCcy(const int index)
  {
   const string symbol = g_symbols[index];
   SymbolSelect(symbol, true);
   const double close = iClose(symbol, PERIOD_D1, 1);
   if(close <= 0.0)
      return 0.0;
   if(symbol == "USDJPY.DWX" || symbol == "USDCAD.DWX" || symbol == "USDCHF.DWX")
      return 1.0 / close;
   return close;
  }

bool Strategy_DeviationByIndex(const int index, double &out_deviation)
  {
   out_deviation = 0.0;
   if(index < 0 || index >= STRATEGY_UNIVERSE_SIZE)
      return false;

   double fair_value = 0.0;
   datetime obs_date = 0;
   if(!Strategy_ReadLatestPppFairValue(g_ccys[index], fair_value, obs_date))
      return false;

   const double spot_usd = Strategy_SpotUsdPerCcy(index);
   if(spot_usd <= 0.0 || fair_value <= 0.0)
      return false;

   out_deviation = (spot_usd / fair_value) - 1.0;
   return true;
  }

int Strategy_DirectionForSymbol()
  {
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

   const int bucket_size = MathMin(MathMax(strategy_bucket_size, 1), count / 2);
   if(bucket_size <= 0)
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

   int ccy_direction = 0;
   for(int i = 0; i < bucket_size; ++i)
      if(indexes[i] == current_index)
         ccy_direction = 1;
   for(int i = count - bucket_size; i < count; ++i)
      if(indexes[i] == current_index)
         ccy_direction = -1;
   if(ccy_direction == 0)
      return 0;

   const string symbol = g_symbols[current_index];
   const bool usd_base = (symbol == "USDJPY.DWX" || symbol == "USDCAD.DWX" || symbol == "USDCHF.DWX");
   return usd_base ? -ccy_direction : ccy_direction;
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
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_rebalance_months != 1 && strategy_rebalance_months != 3)
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

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, _Period, 1));
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

   const int slot = Strategy_CurrentSymbolIndex();
   req.symbol_slot = slot;
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
   // Trade Management: the card specifies only the broker hard stop and rebalance exits.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsRebalanceClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, _Period, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;

   const int magic = QM_FrameworkMagic();
   const int desired_direction = Strategy_DirectionForSymbol();
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
