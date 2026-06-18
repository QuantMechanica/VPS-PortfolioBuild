#property strict
#property version   "5.0"
#property description "QM5_12402 Consistent Momentum Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12402;
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
input int    strategy_recent_window_d1       = 126;  // t-6 to t return proxy.
input int    strategy_skip_window_d1         = 126;  // t-7 to t-1 return proxy length.
input int    strategy_skip_days              = 21;   // One-month skip between formation windows.
input int    strategy_bucket_size            = 1;    // Top/bottom N symbols in both ranks.
input int    strategy_hold_months            = 6;    // Six-month holding period.
input int    strategy_min_valid_symbols      = 5;    // Portable DWX basket after matrix validation.
input int    strategy_min_warmup_d1          = 160;
input int    strategy_atr_period             = 20;
input double strategy_atr_sl_mult            = 3.0;
input double strategy_basket_stop_r          = 6.0;
input int    strategy_spread_median_days     = 60;
input double strategy_spread_median_multiple = 2.0;

const int STRATEGY_SYMBOL_COUNT = 5;
string g_universe[5] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX"
  };

int g_selected_side = 0;      // +1 long, -1 short, 0 flat for _Symbol.
int g_last_rank_key = 0;      // yyyymm cache key.

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_MonthDiff(const datetime from_time, const datetime to_time)
  {
   MqlDateTime a;
   MqlDateTime b;
   TimeToStruct(from_time, a);
   TimeToStruct(to_time, b);
   return (b.year - a.year) * 12 + (b.mon - a.mon);
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_universe[i] == _Symbol)
         return i;
   return -1;
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

bool Strategy_HeldAtLeastMonths(const int months)
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      return (Strategy_MonthDiff(opened, TimeCurrent()) >= months);
     }
   return false;
  }

int Strategy_OpenPositionSide()
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         return 1;
      if(ptype == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

bool Strategy_Returns(const string symbol, double &recent_return, double &skip_return)
  {
   recent_return = 0.0;
   skip_return = 0.0;

   const int skip_recent_shift = 1 + strategy_skip_days;
   const int skip_past_shift = skip_recent_shift + strategy_skip_window_d1;
   const int bars_needed = MathMax(strategy_min_warmup_d1, skip_past_shift + 2);

   if(Bars(symbol, PERIOD_D1) < bars_needed) // perf-allowed: monthly cross-symbol history check.
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1); // perf-allowed: monthly D1 return rank.
   const double recent_past = iClose(symbol, PERIOD_D1, 1 + strategy_recent_window_d1); // perf-allowed: monthly D1 return rank.
   const double skip_close = iClose(symbol, PERIOD_D1, skip_recent_shift); // perf-allowed: monthly D1 return rank.
   const double skip_past = iClose(symbol, PERIOD_D1, skip_past_shift); // perf-allowed: monthly D1 return rank.

   if(recent_close <= 0.0 || recent_past <= 0.0 || skip_close <= 0.0 || skip_past <= 0.0)
      return false;

   recent_return = (recent_close / recent_past) - 1.0;
   skip_return = (skip_close / skip_past) - 1.0;
   return true;
  }

void Strategy_RefreshSelectionIfNeeded()
  {
   const int key = Strategy_MonthKey(TimeCurrent());
   if(key == g_last_rank_key)
      return;

   g_last_rank_key = key;
   g_selected_side = 0;

   double recent[5];
   double skip[5];
   bool valid[5];
   int valid_count = 0;
   int my_index = -1;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      recent[i] = 0.0;
      skip[i] = 0.0;
      valid[i] = Strategy_Returns(g_universe[i], recent[i], skip[i]);
      if(valid[i])
         ++valid_count;
      if(g_universe[i] == _Symbol)
         my_index = i;
     }

   if(my_index < 0 || !valid[my_index] || valid_count < strategy_min_valid_symbols)
     {
      QM_LogEvent(QM_INFO, "REBALANCE",
                  StringFormat("{\"selected\":0,\"valid\":%d,\"month_key\":%d}", valid_count, key));
      return;
     }

   int recent_better = 0;
   int recent_worse = 0;
   int skip_better = 0;
   int skip_worse = 0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(i == my_index || !valid[i])
         continue;
      if(recent[i] > recent[my_index])
         ++recent_better;
      if(recent[i] < recent[my_index])
         ++recent_worse;
      if(skip[i] > skip[my_index])
         ++skip_better;
      if(skip[i] < skip[my_index])
         ++skip_worse;
     }

   const int bucket = MathMax(1, MathMin(strategy_bucket_size, valid_count));
   if(recent_better < bucket && skip_better < bucket)
      g_selected_side = 1;
   else if(recent_worse < bucket && skip_worse < bucket)
      g_selected_side = -1;

   QM_LogEvent(QM_INFO, "REBALANCE",
               StringFormat("{\"selected\":%d,\"recent\":%.6f,\"skip\":%.6f,\"valid\":%d,\"month_key\":%d}",
                            g_selected_side, recent[my_index], skip[my_index], valid_count, key));
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_median_multiple <= 0.0)
      return true;

   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, rates); // perf-allowed: D1 entry hook only; median spread filter from card.
   if(copied <= 0)
      return true;

   double spreads[];
   ArrayResize(spreads, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[count] = (double)rates[i].spread;
         ++count;
        }
     }
   if(count <= 0)
      return true;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(spreads[j] < spreads[i])
           {
            const double tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }

   const double median = spreads[count / 2];
   if(median <= 0.0)
      return true;
   return ((double)current_spread <= median * strategy_spread_median_multiple);
  }

double Strategy_RiskMoneyPerLeg()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED;
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(RISK_PERCENT > 0.0 && equity > 0.0)
      return equity * RISK_PERCENT / 100.0;
   return 0.0;
  }

bool Strategy_MagicBelongsToEA(const int magic)
  {
   const int base = qm_ea_id * 10000;
   return (magic >= base && magic < base + STRATEGY_SYMBOL_COUNT);
  }

double Strategy_BasketOpenPnL()
  {
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(!Strategy_MagicBelongsToEA(magic))
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT);
     }
   return pnl;
  }

void Strategy_CloseBasketForStop()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(!Strategy_MagicBelongsToEA(magic))
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   const int symbol_index = Strategy_CurrentSymbolIndex();
   if(symbol_index < 0)
      return true;
   if(symbol_index != qm_magic_slot_offset)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_RefreshSelectionIfNeeded();

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_selected_side == 0)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const QM_OrderType side = (g_selected_side > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "CONS_MOM_TOP_DUAL_RANK_LONG" : "CONS_MOM_BOTTOM_DUAL_RANK_SHORT";

   if(side == QM_BUY && (req.sl <= 0.0 || req.sl >= entry))
      return false;
   if(side == QM_SELL && (req.sl <= 0.0 || req.sl <= entry))
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const double risk_money = Strategy_RiskMoneyPerLeg();
   if(risk_money <= 0.0 || strategy_basket_stop_r <= 0.0)
      return;

   const double basket_pnl = Strategy_BasketOpenPnL();
   if(basket_pnl <= -strategy_basket_stop_r * risk_money)
      Strategy_CloseBasketForStop();
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   Strategy_RefreshSelectionIfNeeded();

   if(!Strategy_HasOpenPosition())
      return false;
   if(!Strategy_HeldAtLeastMonths(strategy_hold_months))
      return false;

   const int open_side = Strategy_OpenPositionSide();
   if(g_selected_side == 0)
      return true;
   return (open_side != g_selected_side);
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

   QM_SymbolGuardInit(g_universe);
   QM_BasketWarmupHistory(g_universe, PERIOD_D1, MathMax(strategy_min_warmup_d1, strategy_skip_days + strategy_skip_window_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12402\",\"ea\":\"QM5_12402_cons-mom\"}");
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
