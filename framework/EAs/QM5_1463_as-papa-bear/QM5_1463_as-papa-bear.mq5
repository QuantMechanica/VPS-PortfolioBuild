#property strict
#property version   "5.0"
#property description "Papa Bear Portfolio — monthly 3/6/12 composite-momentum rotation, top-3 of 5 index/commodity proxies"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// BASKET SYMBOL TABLE — five assets, fixed magic slots
//   magic = ea_id*10000 + slot
//   Registered in magic_numbers.csv: QM5_1463
//     slot 0 → NDX.DWX    (Nasdaq 100, primary chart, live-tradable)
//     slot 1 → WS30.DWX   (Dow 30, live-tradable)
//     slot 2 → SP500.DWX  (S&P 500, backtest-only, OWNER custom symbol)
//     slot 3 → XAUUSD.DWX (Gold)
//     slot 4 → XTIUSD.DWX (WTI Crude Oil)
//
// FW7: basket EA — QM_SymbolGuardInit called in OnInit.
// FW9: QM_BasketWarmupHistory called in OnInit to pre-load D1 history in tester.
// =============================================================================
#define PAPA_BASKET_SIZE 5
#define PAPA_TOP_N       3

string g_papa_syms[PAPA_BASKET_SIZE]  = { "NDX.DWX", "WS30.DWX", "SP500.DWX", "XAUUSD.DWX", "XTIUSD.DWX" };
int    g_papa_slots[PAPA_BASKET_SIZE] = { 0, 1, 2, 3, 4 };

int g_last_rebalance_month_key = -1; // year*12+month at last rebalance; -1 = not yet run

// =============================================================================
// INPUTS
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1463;
input int    qm_magic_slot_offset       = 0;    // not used by basket; per-symbol slot is fixed
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 0.333; // 1/3 per sleeve (three equal allocations)

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled              = false; // monthly holds must not be interrupted on Friday
input int    qm_friday_close_hour_broker          = 21;

input group "Stress"
input double qm_stress_reject_probability         = 0.0;

input group "Strategy"
input int    strategy_momentum_3m_bars  = 63;   // ~3 calendar months in D1 bars
input int    strategy_momentum_6m_bars  = 126;  // ~6 months
input int    strategy_momentum_12m_bars = 252;  // ~12 months
input double strategy_sl_atr_mult       = 5.0;  // SL = entry_ask - ATR*mult (wide safety net)
input int    strategy_sl_atr_period     = 14;   // ATR lookback period

// =============================================================================
// BASKET HELPERS
// =============================================================================

// Arithmetic average of 3m, 6m, 12m returns using D1 closes.
// Returns -9999 when historical data for the requested shift is unavailable.
double PapaBear_CompositeReturn(const string sym)
  {
   // perf-allowed: iClose on D1 at fixed historical shifts — bespoke structural logic;
   // no QM_ helper computes raw close at an arbitrary bar offset.
   double c0   = iClose(sym, PERIOD_D1, 1);
   double c3m  = iClose(sym, PERIOD_D1, strategy_momentum_3m_bars);
   double c6m  = iClose(sym, PERIOD_D1, strategy_momentum_6m_bars);
   double c12m = iClose(sym, PERIOD_D1, strategy_momentum_12m_bars);

   if(c0 <= 0.0 || c3m <= 0.0 || c6m <= 0.0 || c12m <= 0.0)
      return -9999.0; // insufficient warmup; this symbol ranks last

   double r3  = (c0 - c3m)  / c3m;
   double r6  = (c0 - c6m)  / c6m;
   double r12 = (c0 - c12m) / c12m;
   return (r3 + r6 + r12) / 3.0;
  }

// Mark the PAPA_TOP_N highest-scoring indices in in_top3[].
void PapaBear_SelectTop(const double &scores[], bool &in_top3[])
  {
   int i;
   for(i = 0; i < PAPA_BASKET_SIZE; i++)
      in_top3[i] = false;

   bool used[PAPA_BASKET_SIZE];
   for(i = 0; i < PAPA_BASKET_SIZE; i++)
      used[i] = false;

   for(int k = 0; k < PAPA_TOP_N; k++)
     {
      int    best       = -1;
      double best_score = -99999.0;
      for(i = 0; i < PAPA_BASKET_SIZE; i++)
        {
         if(!used[i] && scores[i] > best_score)
           {
            best_score = scores[i];
            best       = i;
           }
        }
      if(best >= 0)
        {
         in_top3[best] = true;
         used[best]    = true;
        }
     }
  }

// Close the open position for (sym, slot) if one exists for this EA.
void PapaBear_CloseIfOpen(const string sym, const int slot)
  {
   const long magic = (long)(qm_ea_id * 10000 + slot);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// Open a market-buy for (sym, slot) unless a position is already open.
// SL is set to entry_ask - ATR(D1,14)*strategy_sl_atr_mult as a wide safety net.
// Rotation is the primary exit mechanism; the SL guards against catastrophic moves.
void PapaBear_OpenIfMissing(const string sym, const int slot)
  {
   const long magic = (long)(qm_ea_id * 10000 + slot);
   if(QM_BasketHasOpenPosition(magic, sym))
      return;

   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   if(ask <= 0.0)
      return;

   const double atr = QM_ATR(sym, PERIOD_D1, strategy_sl_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double sl_price = ask - atr * strategy_sl_atr_mult;
   if(sl_price <= 0.0)
      return;

   QM_BasketOrderRequest req;
   req.symbol             = sym;
   req.type               = QM_ORDER_BUY;
   req.price              = 0.0;           // market price
   req.sl                 = sl_price;
   req.tp                 = 0.0;           // no TP; rotation is the exit
   req.lots               = 0.0;           // auto-sized via QM_LotsForRisk(sym, sl_points)
   req.reason             = "papa_bear_monthly_rotation";
   req.symbol_slot        = slot;
   req.expiration_seconds = 0;

   ulong out_ticket = 0;
   QM_BasketOpenPosition(qm_ea_id, QM_NEWS_OFF, 20, req, out_ticket);
  }

// =============================================================================
// STRATEGY HOOKS
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: no additional session or regime gate beyond the framework.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Monthly rotation gate: only act on the first D1 bar of a new month.
   // perf-allowed: iTime for month-change detection — bespoke structural logic.
   // Card specifies MN1 timeframe; MN1 is untestable in the MT5 tester (0 bars/ticks
   // generated for DWX custom symbols). D1 with month-change detection is the
   // equivalent; the actual rebalance uses D1 bar-1 close data (last trading day
   // of the previous month).
   datetime cur_bar_time = iTime(_Symbol, PERIOD_D1, 0);
   MqlDateTime dt;
   TimeToStruct(cur_bar_time, dt);
   const int cur_month_key = dt.year * 12 + dt.mon;

   if(cur_month_key == g_last_rebalance_month_key)
      return false; // same month — no rebalance needed

   g_last_rebalance_month_key = cur_month_key;

   // Compute composite 3/6/12-month returns for all basket symbols
   double scores[PAPA_BASKET_SIZE];
   int i;
   for(i = 0; i < PAPA_BASKET_SIZE; i++)
      scores[i] = PapaBear_CompositeReturn(g_papa_syms[i]);

   // Rank: select top 3 (highest composite momentum)
   bool in_top3[PAPA_BASKET_SIZE];
   PapaBear_SelectTop(scores, in_top3);

   // Phase 1: close positions for symbols that rotated out
   for(i = 0; i < PAPA_BASKET_SIZE; i++)
     {
      if(!in_top3[i])
         PapaBear_CloseIfOpen(g_papa_syms[i], g_papa_slots[i]);
     }
   // Phase 2: open positions for top-3 symbols not yet held
   for(i = 0; i < PAPA_BASKET_SIZE; i++)
     {
      if(in_top3[i])
         PapaBear_OpenIfMissing(g_papa_syms[i], g_papa_slots[i]);
     }

   // Return false: basket openings/closings were handled manually above.
   // The framework must NOT attempt an additional single-symbol entry.
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: monthly holds have no intraday management.
   // Positions are held until the next monthly rotation exit.
  }

bool Strategy_ExitSignal()
  {
   // Trade Close: rotation exits happen inside Strategy_EntrySignal on new-month bars.
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade (framework handles)
  }

// =============================================================================
// FRAMEWORK WIRING — do NOT edit below this line unless you know why
// =============================================================================

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

   // FW7: basket opt-in — register all 5 symbols so guard violations are suppressed.
   QM_SymbolGuardInit(g_papa_syms);

   // FW9: pre-load D1 history for all basket symbols in the MT5 tester so that
   // iClose(sym, D1, 252) returns valid data on the first rebalance bar.
   QM_BasketWarmupHistory(g_papa_syms, PERIOD_D1, strategy_momentum_12m_bars + 10);

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
