#property strict
#property version   "5.0"
#property description "QM5_1059 Jegadeesh Short-Term Reversal Index Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1059;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 22;

input group "Strategy"
input string strategy_universe_symbols   = "NDX.DWX,WS30.DWX,GER40.DWX,UK100.DWX,JPN225.DWX,AUS200.DWX";
input int    strategy_min_available_symbols = 5;
input int    strategy_signal_hour_broker = 22;
input int    strategy_return_d1_bars     = 5;
input int    strategy_atr_stop_period    = 14;
input double strategy_atr_stop_mult      = 3.0;
input int    strategy_vol_atr_period     = 20;
input double strategy_vol_max_atr_close  = 0.03;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 5.0;

const int STRATEGY_MAX_UNIVERSE_SIZE = 16;
string    g_universe_symbols[16];
bool      g_universe_selected[16];
int       g_universe_count = 0;
int       g_last_entry_week_key = 0;
int       g_last_exit_week_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < g_universe_count; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_WeekKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 1000) + (dt.day_of_year / 7);
  }

bool Strategy_IsFridaySignalWindow(const datetime broker_time)
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(current_d1, dt);
   if(dt.day_of_week != 5)
      return false;

   return (broker_time >= current_d1 + MathMax(0, MathMin(23, strategy_signal_hour_broker)) * 3600);
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

string Strategy_Trim(const string value)
  {
   string result = value;
   StringTrimLeft(result);
   StringTrimRight(result);
   return result;
  }

bool Strategy_TrySelectSymbol(const string symbol)
  {
   if(symbol == "")
      return false;
   return SymbolSelect(symbol, true);
  }

string Strategy_ResolveUniverseSymbol(const string requested, bool &selected)
  {
   selected = false;
   string symbol = Strategy_Trim(requested);
   if(symbol == "")
      return "";

   if(Strategy_TrySelectSymbol(symbol))
     {
      selected = true;
      return symbol;
     }

   if(StringFind(symbol, ".DWX") < 0)
     {
      const string dwx_symbol = symbol + ".DWX";
      if(Strategy_TrySelectSymbol(dwx_symbol))
        {
         selected = true;
         return dwx_symbol;
        }
     }
   else
     {
      const string bare_symbol = StringSubstr(symbol, 0, StringLen(symbol) - 4);
      if(Strategy_TrySelectSymbol(bare_symbol))
        {
         selected = true;
         return bare_symbol;
        }
     }

   if(symbol == "GER40.DWX" || symbol == "GER40")
     {
      if(Strategy_TrySelectSymbol("GDAXI.DWX"))
        {
         selected = true;
         return "GDAXI.DWX";
        }
     }

   return symbol;
  }

void Strategy_InitUniverse()
  {
   g_universe_count = 0;
   string tokens[];
   const int token_count = StringSplit(strategy_universe_symbols, ',', tokens);
   for(int i = 0; i < token_count && g_universe_count < STRATEGY_MAX_UNIVERSE_SIZE; ++i)
     {
      bool selected = false;
      const string symbol = Strategy_ResolveUniverseSymbol(tokens[i], selected);
      if(symbol == "")
         continue;

      bool duplicate = false;
      for(int j = 0; j < g_universe_count; ++j)
        {
         if(g_universe_symbols[j] == symbol)
           {
            duplicate = true;
            break;
           }
        }
      if(duplicate)
         continue;

      g_universe_symbols[g_universe_count] = symbol;
      g_universe_selected[g_universe_count] = selected;
      ++g_universe_count;
     }
  }

string Strategy_UniverseLogJson()
  {
   string selected = "";
   string unavailable = "";
   int selected_count = 0;
   for(int i = 0; i < g_universe_count; ++i)
     {
      if(g_universe_selected[i])
        {
         if(selected != "")
            selected += ",";
         selected += g_universe_symbols[i];
         ++selected_count;
        }
      else
        {
         if(unavailable != "")
            unavailable += ",";
         unavailable += g_universe_symbols[i];
        }
     }

   return StringFormat("{\"configured\":%d,\"selected\":%d,\"min_required\":%d,\"symbols\":\"%s\",\"unavailable\":\"%s\"}",
                       g_universe_count,
                       selected_count,
                       MathMax(1, strategy_min_available_symbols),
                       selected,
                       unavailable);
  }

double Strategy_MedianDailySpreadPoints(const string symbol)
  {
   const int n = strategy_spread_median_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(symbol, PERIOD_D1, shift);
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

bool Strategy_SpreadAllowsEntry(const string symbol)
  {
   const double median_spread = Strategy_MedianDailySpreadPoints(symbol);
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_VolatilityAllowsEntry(const string symbol)
  {
   const double close = iClose(symbol, PERIOD_D1, 1);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_vol_atr_period, 1);
   if(close <= 0.0 || atr <= 0.0)
      return false;
   return ((atr / close) <= strategy_vol_max_atr_close);
  }

bool Strategy_SymbolReturn(const string symbol, double &out_return)
  {
   out_return = 0.0;
   if(strategy_return_d1_bars <= 0)
      return false;

   SymbolSelect(symbol, true);
   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, 1 + strategy_return_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_return = (recent_close / lookback_close) - 1.0;
   return true;
  }

bool Strategy_SymbolAvailableForRank(const int index)
  {
   if(index < 0 || index >= g_universe_count)
      return false;
   if(!g_universe_selected[index])
      return false;

   const string symbol = g_universe_symbols[index];
   if(!Strategy_SpreadAllowsEntry(symbol))
      return false;
   return true;
  }

void Strategy_PrintDiagnostics(const int candidates_count)
  {
   string symbols = "";
   for(int i = 0; i < g_universe_count; ++i)
     {
      if(symbols != "")
         symbols += ",";
      symbols += g_universe_symbols[i];
     }

   PrintFormat("QM1059_DIAG universe_count=%d candidates_count=%d min_required=%d symbols=%s",
               g_universe_count,
               candidates_count,
               strategy_min_available_symbols,
               symbols);

   for(int i = 0; i < g_universe_count; ++i)
     {
      const string sym = g_universe_symbols[i];
      const bool ok = SymbolSelect(sym, true);
      const int bars = iBars(sym, PERIOD_D1);
      const double c0 = iClose(sym, PERIOD_D1, 0);
      const double c5 = iClose(sym, PERIOD_D1, 5);
      PrintFormat("QM1059_DIAG symbol=%s selected=%s bars=%d close[0]=%.5f close[5]=%.5f",
                  sym,
                  ok ? "true" : "false",
                  bars,
                  c0,
                  c5);
     }
  }

int Strategy_ReversalDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;
   if(!Strategy_SymbolAvailableForRank(current_index))
      return 0;

   double scores[16];
   int indexes[16];
   int count = 0;
   for(int i = 0; i < g_universe_count; ++i)
     {
      if(!Strategy_SymbolAvailableForRank(i))
         continue;
      double score = 0.0;
      if(!Strategy_SymbolReturn(g_universe_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   Strategy_PrintDiagnostics(count);

   if(count < MathMax(1, strategy_min_available_symbols))
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

   if(indexes[0] == current_index)
      return 1;
   if(indexes[count - 1] == current_index)
      return -1;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1059_STMR_WEEKLY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsFridaySignalWindow(broker_now))
      return false;

   const int week_key = Strategy_WeekKey(broker_now);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const int direction = Strategy_ReversalDirection();
   if(direction == 0)
      return false;
   const bool volatility_ok = Strategy_VolatilityAllowsEntry(_Symbol);
   PrintFormat("QM1059_DIAG symbol=%s direction=%d volatility_ok=%s", _Symbol, direction, volatility_ok ? "true" : "false");
   if(!volatility_ok)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_stop_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1059_STMR_LONG_BOTTOM1" : "QM5_1059_STMR_SHORT_TOP1";
   g_last_entry_week_key = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies weekly hold with hard 3x ATR stop only.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsFridaySignalWindow(broker_now))
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int week_key = Strategy_WeekKey(broker_now);
   if(week_key <= 0 || week_key == g_last_exit_week_key)
      return false;
   g_last_exit_week_key = week_key;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_InitUniverse();

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "UNIVERSE_INIT", Strategy_UniverseLogJson());
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1059\",\"ea\":\"jegadeesh-stm-reversal-indices\"}");
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
   if(qm_friday_close_enabled && QM_FrameworkHandleFridayClose())
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

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }

   if(!QM_IsNewBar())
      return;
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
