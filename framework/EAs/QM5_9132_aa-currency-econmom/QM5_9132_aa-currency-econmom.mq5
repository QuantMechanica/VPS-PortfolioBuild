#property strict
#property version   "5.0"
#property description "QM5_9132 Alpha Architect Currency Economic Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9132;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.142857142857;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input bool   strategy_macro_panel_approved = true;
input int    strategy_rebalance_day        = 20;
input int    strategy_tercile_size         = 3;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 2.5;
input int    strategy_max_spread_points    = 50;
input double strategy_score_usd            = -3.0;
input double strategy_score_gbp            = 2.0;
input double strategy_score_nzd            = 0.0;
input double strategy_score_cad            = -1.0;
input double strategy_score_aud            = -0.5;
input double strategy_score_chf            = -2.0;
input double strategy_score_jpy            = 1.0;
input double strategy_score_eur            = 3.0;

int g_last_entry_rebalance_key = 0;

int MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool IsRebalanceWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int day = MathMax(1, MathMin(28, strategy_rebalance_day));
   return (dt.day >= day);
  }

string CleanSymbol()
  {
   string s = _Symbol;
   const int dot = StringFind(s, ".");
   if(dot > 0)
      s = StringSubstr(s, 0, dot);
   return s;
  }

string BaseCurrency()
  {
   const string s = CleanSymbol();
   if(StringLen(s) < 6)
      return "";
   return StringSubstr(s, 0, 3);
  }

string QuoteCurrency()
  {
   const string s = CleanSymbol();
   if(StringLen(s) < 6)
      return "";
   return StringSubstr(s, 3, 3);
  }

double CurrencyScore(const string ccy)
  {
   if(ccy == "USD") return strategy_score_usd;
   if(ccy == "EUR") return strategy_score_eur;
   if(ccy == "GBP") return strategy_score_gbp;
   if(ccy == "JPY") return strategy_score_jpy;
   if(ccy == "AUD") return strategy_score_aud;
   if(ccy == "CAD") return strategy_score_cad;
   if(ccy == "CHF") return strategy_score_chf;
   if(ccy == "NZD") return strategy_score_nzd;
   return 0.0;
  }

bool IsKnownCurrency(const string ccy)
  {
   return (ccy == "USD" || ccy == "EUR" || ccy == "GBP" || ccy == "JPY" ||
           ccy == "AUD" || ccy == "CAD" || ccy == "CHF" || ccy == "NZD");
  }

int CurrencyRankHigh(const string ccy)
  {
   const double score = CurrencyScore(ccy);
   int rank = 1;
   const string ccys[8] = {"USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"};
   for(int i = 0; i < 8; ++i)
     {
      if(CurrencyScore(ccys[i]) > score)
         ++rank;
     }
   return rank;
  }

bool IsTopTercile(const string ccy)
  {
   return (CurrencyRankHigh(ccy) <= MathMax(1, strategy_tercile_size));
  }

bool IsBottomTercile(const string ccy)
  {
   return (CurrencyRankHigh(ccy) > 8 - MathMax(1, strategy_tercile_size));
  }

int DesiredPairDirection()
  {
   if(!strategy_macro_panel_approved)
      return 0;

   const string base = BaseCurrency();
   const string quote = QuoteCurrency();
   if(!IsKnownCurrency(base) || !IsKnownCurrency(quote))
      return 0;

   const bool base_top = IsTopTercile(base);
   const bool base_bottom = IsBottomTercile(base);
   const bool quote_top = IsTopTercile(quote);
   const bool quote_bottom = IsBottomTercile(quote);

   if(base_top && quote_bottom)
      return 1;
   if(base_bottom && quote_top)
      return -1;
   return 0;
  }

bool HasOpenPositionForMagic()
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

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!strategy_macro_panel_approved)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
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
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime now = TimeCurrent();
   if(!IsRebalanceWindow(now))
      return false;

   const int month_key = MonthKey(now);
   if(month_key == g_last_entry_rebalance_key)
      return false;

   if(HasOpenPositionForMagic())
      return false;

   const int direction = DesiredPairDirection();
   if(direction == 0)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "ECON_MOM_TOP_BASE_BOTTOM_QUOTE"
                                : "ECON_MOM_BOTTOM_BASE_TOP_QUOTE";
   g_last_entry_rebalance_key = month_key;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no discretionary trailing, partial close, or break-even rule.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const datetime now = TimeCurrent();
   if(!IsRebalanceWindow(now))
      return false;

   const int desired = DesiredPairDirection();
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(desired == 0)
         return true;
      if(desired > 0 && ptype == POSITION_TYPE_SELL)
         return true;
      if(desired < 0 && ptype == POSITION_TYPE_BUY)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9132\",\"ea\":\"QM5_9132_aa_currency_econmom\"}");
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
