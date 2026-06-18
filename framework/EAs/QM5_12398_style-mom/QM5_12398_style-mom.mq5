#property strict
#property version   "5.0"
#property description "QM5_12398 style-mom - monthly long-short style momentum rotation"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// QuantMechanica V5 EA - QM5_12398 style-mom
// Source: Papers With Backtest / Quantpedia implementation,
// Momentum Factor and Style Rotation Effect, source_id
// b7832a20-938e-5f24-b9d7-e0b2ab63b623.
//
// Basket EA: every host symbol ranks the same registered DWX index proxy
// universe on closed D1 bars once per calendar month. The basket holds one
// long leg in the strongest symbol and one short leg in the weakest symbol.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12398;
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
input int    strategy_momentum_lookback_d1 = 252;  // card: 12-month momentum on D1 closes
input int    strategy_min_ready_symbols    = 4;    // card: require at least four valid symbols
input int    strategy_atr_period           = 20;   // emergency stop ATR period
input double strategy_stop_atr_mult        = 3.0;  // card: 3.0 * ATR(20,D1)
input double strategy_basket_stop_r_mult   = 5.0;  // card: close basket if combined PnL <= -5R
input int    strategy_spread_days          = 60;   // card: MedianSpread(60D)
input double strategy_spread_median_mult   = 2.0;  // card: block spread > 2 * MedianSpread

#define QM_SMR_MAX_SYMBOLS 5

string g_symbols[QM_SMR_MAX_SYMBOLS];
int    g_symbol_count = 0;

double g_momentum[QM_SMR_MAX_SYMBOLS];
bool   g_ready_symbol[QM_SMR_MAX_SYMBOLS];
int    g_rank[QM_SMR_MAX_SYMBOLS];
int    g_ready_count = 0;
int    g_long_slot = -1;
int    g_short_slot = -1;
int    g_eval_month_key = 0;
bool   g_eval_ready = false;
bool   g_rebalance_bar = false;
bool   g_rebalance_executed = false;

void SMR_BuildUniverse()
  {
   string u[] =
     {
      "SP500.DWX",
      "NDX.DWX",
      "WS30.DWX",
      "GDAXI.DWX",
      "UK100.DWX"
     };

   g_symbol_count = ArraySize(u);
   if(g_symbol_count > QM_SMR_MAX_SYMBOLS)
      g_symbol_count = QM_SMR_MAX_SYMBOLS;

   for(int i = 0; i < g_symbol_count; ++i)
      g_symbols[i] = u[i];
  }

void SMR_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_symbol_count + 1);
   int n = 0;
   out[n++] = _Symbol;

   for(int i = 0; i < g_symbol_count; ++i)
     {
      bool duplicate = false;
      for(int j = 0; j < n; ++j)
        {
         if(out[j] == g_symbols[i])
           {
            duplicate = true;
            break;
           }
        }
      if(!duplicate)
         out[n++] = g_symbols[i];
     }

   ArrayResize(out, n);
  }

int SMR_MonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

bool SMR_IsFirstTradableBarOfMonth()
  {
   const int key = SMR_MonthKey();
   return (key > 0 && key != g_eval_month_key);
  }

int SMR_SlotForSymbol(const string sym)
  {
   for(int i = 0; i < g_symbol_count; ++i)
      if(g_symbols[i] == sym)
         return i;
   return -1;
  }

double SMR_CloseMomentum(const string sym)
  {
   if(strategy_momentum_lookback_d1 < 2)
      return 0.0;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int count = strategy_momentum_lookback_d1 + 1;
   // perf-allowed: bounded D1 basket momentum read only after the framework
   // new-bar gate and only once per calendar month.
   const int got = CopyClose(sym, PERIOD_D1, 1, count, closes); // perf-allowed
   if(got != count)
      return 0.0;

   const double recent = closes[0];
   const double past = closes[strategy_momentum_lookback_d1];
   if(recent <= 0.0 || past <= 0.0)
      return 0.0;

   return (recent / past) - 1.0;
  }

double SMR_MedianSpreadPoints(const string sym)
  {
   if(strategy_spread_days <= 0)
      return 0.0;

   MqlRates rates[];
   const int need = MathMin(strategy_spread_days, 120);
   // perf-allowed: bounded D1 spread snapshot for card MedianSpread(60D),
   // called only on monthly rebalance bars, never on the per-tick path.
   const int got = CopyRates(sym, PERIOD_D1, 1, need, rates); // perf-allowed
   if(got <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, got);
   int n = 0;
   for(int i = 0; i < got; ++i)
     {
      if(rates[i].spread > 0)
         spreads[n++] = (double)rates[i].spread;
     }
   if(n <= 0)
      return 0.0; // .DWX zero modeled spread must fail open.

   ArrayResize(spreads, n);
   for(int a = 0; a < n; ++a)
      for(int b = a + 1; b < n; ++b)
         if(spreads[b] < spreads[a])
           {
            const double tmp = spreads[a];
            spreads[a] = spreads[b];
            spreads[b] = tmp;
           }

   if((n % 2) == 1)
      return spreads[n / 2];
   return 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

bool SMR_SpreadAllowsSymbol(const string sym)
  {
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ask <= bid)
      return true; // .DWX zero modeled spread must not block.

   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double median_spread = SMR_MedianSpreadPoints(sym);
   if(median_spread <= 0.0)
      return true;

   const double current_spread = (ask - bid) / point;
   return (current_spread <= strategy_spread_median_mult * median_spread);
  }

void SMR_AdvanceRank()
  {
   g_eval_ready = false;
   g_rebalance_bar = true;
   g_rebalance_executed = false;
   g_ready_count = 0;
   g_long_slot = -1;
   g_short_slot = -1;
   g_eval_month_key = SMR_MonthKey();

   for(int i = 0; i < g_symbol_count; ++i)
     {
      g_momentum[i] = 0.0;
      g_ready_symbol[i] = false;
      g_rank[i] = -1;

      const double mom = SMR_CloseMomentum(g_symbols[i]);
      if(mom == 0.0)
         continue;

      g_momentum[i] = mom;
      g_ready_symbol[i] = true;
      ++g_ready_count;
     }

   if(g_ready_count < strategy_min_ready_symbols)
      return;

   int idx[QM_SMR_MAX_SYMBOLS];
   int n = 0;
   for(int i = 0; i < g_symbol_count; ++i)
      if(g_ready_symbol[i])
         idx[n++] = i;

   for(int a = 0; a < n; ++a)
      for(int b = a + 1; b < n; ++b)
         if(g_momentum[idx[b]] > g_momentum[idx[a]])
           {
            const int tmp = idx[a];
            idx[a] = idx[b];
            idx[b] = tmp;
           }

   for(int a = 0; a < n; ++a)
      g_rank[idx[a]] = a;

   g_long_slot = idx[0];
   g_short_slot = idx[n - 1];
   g_eval_ready = (g_long_slot >= 0 && g_short_slot >= 0 && g_long_slot != g_short_slot);
  }

bool SMR_TargetSide(const string sym, ENUM_POSITION_TYPE &target_type)
  {
   const int slot = SMR_SlotForSymbol(sym);
   if(slot < 0 || !g_eval_ready)
      return false;

   if(slot == g_long_slot)
     {
      target_type = POSITION_TYPE_BUY;
      return true;
     }

   if(slot == g_short_slot)
     {
      target_type = POSITION_TYPE_SELL;
      return true;
     }

   return false;
  }

bool SMR_HasTargetPosition(const int slot, const ENUM_POSITION_TYPE target_type)
  {
   if(slot < 0 || slot >= g_symbol_count)
      return false;

   const int magic = QM_Magic(qm_ea_id, slot);
   const string sym = g_symbols[slot];
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == target_type)
         return true;
     }
   return false;
  }

void SMR_CloseNonTargets()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      const string sym = PositionGetString(POSITION_SYMBOL);
      const int slot = SMR_SlotForSymbol(sym);
      if(slot < 0)
         continue;

      const int magic = QM_Magic(qm_ea_id, slot);
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ENUM_POSITION_TYPE target_type = POSITION_TYPE_BUY;
      const bool has_target = SMR_TargetSide(sym, target_type);
      const ENUM_POSITION_TYPE held_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(!has_target || held_type != target_type)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

double SMR_BasketOpenPnL()
  {
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      const string sym = PositionGetString(POSITION_SYMBOL);
      const int slot = SMR_SlotForSymbol(sym);
      if(slot < 0)
         continue;

      const int magic = QM_Magic(qm_ea_id, slot);
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
      pnl += PositionGetDouble(POSITION_COMMISSION);
     }
   return pnl;
  }

double SMR_RiskDollars()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED;
   if(RISK_PERCENT > 0.0)
      return AccountInfoDouble(ACCOUNT_EQUITY) * RISK_PERCENT / 100.0;
   return 0.0;
  }

void SMR_CloseBasketForEmergencyStop()
  {
   const double risk_dollars = SMR_RiskDollars();
   if(risk_dollars <= 0.0 || strategy_basket_stop_r_mult <= 0.0)
      return;

   const double pnl = SMR_BasketOpenPnL();
   if(pnl > -strategy_basket_stop_r_mult * risk_dollars)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      const string sym = PositionGetString(POSITION_SYMBOL);
      const int slot = SMR_SlotForSymbol(sym);
      if(slot < 0)
         continue;

      const int magic = QM_Magic(qm_ea_id, slot);
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool SMR_OpenTargetLeg(const int slot, const QM_OrderType side)
  {
   if(slot < 0 || slot >= g_symbol_count)
      return false;

   const ENUM_POSITION_TYPE target_type = QM_OrderTypeIsBuy(side) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   if(SMR_HasTargetPosition(slot, target_type))
      return false;

   const string sym = g_symbols[slot];
   if(!SMR_SpreadAllowsSymbol(sym))
      return false;

   const double entry = QM_BasketMarketPrice(sym, side);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(sym, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = sym;
   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(sym, side, entry, atr, strategy_stop_atr_mult);
   req.tp = 0.0;
   req.lots = 0.0;
   req.reason = QM_OrderTypeIsBuy(side) ? "style_mom_monthly_strongest_long" : "style_mom_monthly_weakest_short";
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0)
      return false;

   ulong out_ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, req, out_ticket);
  }

void SMR_ExecuteRebalance()
  {
   if(!g_eval_ready || g_rebalance_executed)
      return;

   SMR_CloseNonTargets();
   SMR_OpenTargetLeg(g_long_slot, QM_BUY);
   SMR_OpenTargetLeg(g_short_slot, QM_SELL);
   g_rebalance_executed = true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
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

   if(!g_rebalance_bar)
      return false;

   SMR_ExecuteRebalance();
   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   SMR_CloseBasketForEmergencyStop();
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring. Basket warmup and single-consume new-bar latching are needed
// for cross-symbol closed-bar ranking.
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

   SMR_BuildUniverse();

   string warmup[];
   SMR_BuildWarmupList(warmup);
   QM_SymbolGuardInit(warmup);
   QM_BasketWarmupHistory(warmup, PERIOD_D1, strategy_momentum_lookback_d1 + strategy_atr_period + strategy_spread_days + 10);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"ea\":\"QM5_12398_style_mom\",\"host\":\"%s\",\"universe\":%d}",
                            _Symbol, g_symbol_count));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   g_rebalance_bar = false;

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

   const bool nb = QM_IsNewBar();
   if(nb && SMR_IsFirstTradableBarOfMonth())
      SMR_AdvanceRank();

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(!nb)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
