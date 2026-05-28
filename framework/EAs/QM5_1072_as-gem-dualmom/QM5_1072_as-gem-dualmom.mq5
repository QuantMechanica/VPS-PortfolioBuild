#property strict
#property version   "5.0"
#property description "QM5_1072 Allocate Smartly GEM Dual Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1072;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_us_symbol           = "SP500.DWX";
input string strategy_international_symbol = "GDAXI.DWX";
input int    strategy_momentum_days       = 252;
input double strategy_cash_return_pct     = 0.0;
input int    strategy_rebalance_hour      = 1;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 4.0;
input int    strategy_spread_median_days  = 20;
input double strategy_spread_cap_mult     = 3.0;

string   g_selected_symbol = "";
bool     g_selection_valid = false;
datetime g_selection_d1_bar = 0;

int BrokerHour()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
  }

int MonthOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.mon;
  }

int YearOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
  }

bool IsMonthlyRebalanceBar()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   const datetime just_closed = iTime(_Symbol, PERIOD_D1, 1);
   if(current_bar <= 0 || just_closed <= 0)
      return false;

   return (MonthOf(current_bar) != MonthOf(just_closed) ||
           YearOf(current_bar) != YearOf(just_closed));
  }

bool IsAllowedSymbol(const string symbol)
  {
   return (symbol == "SP500.DWX" ||
           symbol == "GDAXI.DWX" ||
           symbol == "NDX.DWX" ||
           symbol == "WS30.DWX");
  }

int Strategy_SymbolSlot(const string symbol)
  {
   if(symbol == "SP500.DWX") return 0;
   if(symbol == "GDAXI.DWX") return 1;
   if(symbol == "NDX.DWX")   return 2;
   if(symbol == "WS30.DWX")  return 3;
   return -1;
  }

bool TwelveMonthReturn(const string symbol, double &ret)
  {
   ret = 0.0;
   if(strategy_momentum_days < 20)
      return false;
   if(!SymbolSelect(symbol, true))
      return false;

   const double close_now = iClose(symbol, PERIOD_D1, 1);
   const double close_then = iClose(symbol, PERIOD_D1, 1 + strategy_momentum_days);
   if(close_now <= 0.0 || close_then <= 0.0)
      return false;

   ret = (close_now / close_then) - 1.0;
   return true;
  }

bool RefreshSelection()
  {
   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar <= 0)
      return false;
   if(g_selection_d1_bar == d1_bar)
      return g_selection_valid;

   g_selection_d1_bar = d1_bar;
   g_selected_symbol = "";
   g_selection_valid = false;

   if(!IsAllowedSymbol(strategy_us_symbol) || !IsAllowedSymbol(strategy_international_symbol))
      return false;
   if(strategy_us_symbol == strategy_international_symbol)
      return false;

   double us_ret = 0.0;
   double intl_ret = 0.0;
   if(!TwelveMonthReturn(strategy_us_symbol, us_ret))
      return false;
   if(!TwelveMonthReturn(strategy_international_symbol, intl_ret))
      return false;

   const double cash_return = strategy_cash_return_pct / 100.0;
   if(us_ret <= cash_return)
     {
      g_selected_symbol = "";
      g_selection_valid = true;
      return true;
     }

   g_selected_symbol = (us_ret >= intl_ret) ? strategy_us_symbol : strategy_international_symbol;
   g_selection_valid = true;
   return true;
  }

bool HasCurrentSymbolPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

int PortfolioPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(magic >= 10720000 && magic <= 10729999)
         count++;
     }
   return count;
  }

bool SpreadWithinCap()
  {
   const int days = MathMax(1, strategy_spread_median_days);
   int spreads[];
   ArrayResize(spreads, days);
   int samples = 0;

   for(int shift = 1; shift <= days; ++shift)
     {
      const int spread = (int)iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[samples] = spread;
      samples++;
     }

   if(samples <= 0)
      return true;

   ArrayResize(spreads, samples);
   ArraySort(spreads);

   const double median = (samples % 2 == 1)
      ? (double)spreads[samples / 2]
      : ((double)spreads[(samples / 2) - 1] + (double)spreads[samples / 2]) * 0.5;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   if(median <= 0.0 || current_spread <= 0)
      return true;
   return ((double)current_spread <= strategy_spread_cap_mult * median);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_SymbolSlot(_Symbol) < 0)
      return true;
   if(qm_magic_slot_offset != Strategy_SymbolSlot(_Symbol))
      return true;
   if(BrokerHour() < strategy_rebalance_hour)
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

   if(!IsMonthlyRebalanceBar())
      return false;
   if(HasCurrentSymbolPosition())
      return false;
   if(PortfolioPositionCount() > 0)
      return false;
   if(!SpreadWithinCap())
      return false;
   if(!RefreshSelection())
      return false;
   if(g_selected_symbol != _Symbol)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.tp = 0.0;
   req.reason = "GEM_DUALMOM_MONTHLY_ROTATION";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Monthly rotation only; no intramonth trailing, break-even, or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(!IsMonthlyRebalanceBar())
      return false;
   if(!HasCurrentSymbolPosition())
      return false;
   if(!RefreshSelection())
      return false;

   return (g_selected_symbol != _Symbol);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1072\",\"ea\":\"as-gem-dualmom\"}");
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
