#property strict
#property version   "5.0"
#property description "QM5_10024 Robot Wealth FX commodity basket stat-arb"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10024;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_z_lookback         = 60;
input double strategy_z_entry            = 2.0;
input double strategy_z_exit             = 0.50;
input int    strategy_time_stop_days     = 20;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_catastrophe_sigma  = 2.5;
input int    strategy_max_spread_points  = 40;
input double strategy_weight_audusd      = 1.0;
input double strategy_weight_nzdusd      = 1.0;
input double strategy_weight_usdcad      = -1.0;
input double strategy_weight_audnzd      = -1.0;

string g_basket_symbols[4] = {"AUDUSD.DWX", "NZDUSD.DWX", "USDCAD.DWX", "AUDNZD.DWX"};
double g_last_zscore = 0.0;
bool   g_have_zscore = false;

double BasketWeight(const string symbol)
  {
   if(symbol == "AUDUSD.DWX")
      return strategy_weight_audusd;
   if(symbol == "NZDUSD.DWX")
      return strategy_weight_nzdusd;
   if(symbol == "USDCAD.DWX")
      return strategy_weight_usdcad;
   if(symbol == "AUDNZD.DWX")
      return strategy_weight_audnzd;
   return 0.0;
  }

int BasketSlot(const string symbol)
  {
   if(symbol == "AUDUSD.DWX")
      return 0;
   if(symbol == "NZDUSD.DWX")
      return 1;
   if(symbol == "USDCAD.DWX")
      return 2;
   if(symbol == "AUDNZD.DWX")
      return 3;
   return -1;
  }

bool BasketSymbolDataReady()
  {
   for(int i = 0; i < 4; ++i)
     {
      const string symbol = g_basket_symbols[i];
      if(!SymbolSelect(symbol, true))
         return false;

      const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
         return false;

      if(iTime(symbol, PERIOD_D1, 1) <= 0)
         return false;
     }
   return true;
  }

bool CopyBasketCloses(const int count, double &audusd[], double &nzdusd[], double &usdcad[], double &audnzd[])
  {
   ArraySetAsSeries(audusd, true);
   ArraySetAsSeries(nzdusd, true);
   ArraySetAsSeries(usdcad, true);
   ArraySetAsSeries(audnzd, true);

   if(CopyClose("AUDUSD.DWX", PERIOD_D1, 1, count, audusd) != count) // perf-allowed: called only from Strategy_EntrySignal after the framework new-bar gate.
      return false;
   if(CopyClose("NZDUSD.DWX", PERIOD_D1, 1, count, nzdusd) != count) // perf-allowed: called only from Strategy_EntrySignal after the framework new-bar gate.
      return false;
   if(CopyClose("USDCAD.DWX", PERIOD_D1, 1, count, usdcad) != count) // perf-allowed: called only from Strategy_EntrySignal after the framework new-bar gate.
      return false;
   if(CopyClose("AUDNZD.DWX", PERIOD_D1, 1, count, audnzd) != count) // perf-allowed: called only from Strategy_EntrySignal after the framework new-bar gate.
      return false;
   return true;
  }

double BasketSpreadAt(const int index, const double &audusd[], const double &nzdusd[], const double &usdcad[], const double &audnzd[])
  {
   if(audusd[index] <= 0.0 || nzdusd[index] <= 0.0 || usdcad[index] <= 0.0 || audnzd[index] <= 0.0)
      return 0.0;

   return strategy_weight_audusd * MathLog(audusd[index]) +
          strategy_weight_nzdusd * MathLog(nzdusd[index]) +
          strategy_weight_usdcad * MathLog(usdcad[index]) +
          strategy_weight_audnzd * MathLog(audnzd[index]);
  }

bool BasketZScore(double &zscore, double &spread_sigma)
  {
   zscore = 0.0;
   spread_sigma = 0.0;

   const int lookback = MathMax(10, strategy_z_lookback);
   double audusd[];
   double nzdusd[];
   double usdcad[];
   double audnzd[];
   if(!CopyBasketCloses(lookback, audusd, nzdusd, usdcad, audnzd))
      return false;

   double spreads[];
   ArrayResize(spreads, lookback);
   double sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      spreads[i] = BasketSpreadAt(i, audusd, nzdusd, usdcad, audnzd);
      if(spreads[i] == 0.0)
         return false;
      sum += spreads[i];
     }

   const double mean = sum / lookback;
   double var_sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double d = spreads[i] - mean;
      var_sum += d * d;
     }

   spread_sigma = MathSqrt(var_sum / MathMax(1, lookback - 1));
   if(spread_sigma <= 0.0)
      return false;

   zscore = (spreads[0] - mean) / spread_sigma;
   return true;
  }

bool GetOurPosition(datetime &opened)
  {
   opened = 0;

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

      opened = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int slot = BasketSlot(_Symbol);
   if(slot < 0 || slot != qm_magic_slot_offset)
      return true;

   return !BasketSymbolDataReady();
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

   double zscore = 0.0;
   double spread_sigma = 0.0;
   g_have_zscore = BasketZScore(zscore, spread_sigma);
   if(!g_have_zscore)
      return false;
   g_last_zscore = zscore;

   datetime opened;
   if(GetOurPosition(opened))
      return false;

   const double leg_weight = BasketWeight(_Symbol);
   if(leg_weight == 0.0)
      return false;

   int basket_signal = 0;
   if(zscore > strategy_z_entry)
      basket_signal = -1;
   else if(zscore < -strategy_z_entry)
      basket_signal = 1;
   else
      return false;

   const bool buy_leg = (basket_signal * leg_weight) > 0.0;
   req.type = buy_leg ? QM_BUY : QM_SELL;

   const double entry = buy_leg ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = StringFormat("RW_FX_COMM_BASKET z=%.2f sigma=%.6f", zscore, spread_sigma);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies basket exit, time stop, and platform SL only; no trailing/partial management.
  }

bool Strategy_ExitSignal()
  {
   datetime opened;
   if(!GetOurPosition(opened))
      return false;

   if(strategy_time_stop_days > 0 && opened > 0)
     {
      const int held_seconds = (int)(TimeCurrent() - opened);
      if(held_seconds >= strategy_time_stop_days * 86400)
         return true;
     }

   if(!g_have_zscore)
      return false;

   if(MathAbs(g_last_zscore) <= strategy_z_exit)
      return true;

   if(MathAbs(g_last_zscore) >= strategy_catastrophe_sigma)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10024\",\"strategy\":\"rw-fx-comm-basket\"}");
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
