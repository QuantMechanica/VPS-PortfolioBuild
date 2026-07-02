#property strict
#property version   "5.0"
#property description "QM5_12605 CME Oil/Gold Ratio Channel Breakout"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_12605 - cme-oilgold-brk
// D1 two-leg commodity basket: log-ratio Donchian channel breakout.
//   spread = ln(XTIUSD.DWX close) - beta * ln(XAUUSD.DWX close)
//   Long ratio:  buy XTI + sell XAU when spread breaks above entry channel high.
//   Short ratio: sell XTI + buy XAU when spread breaks below entry channel low.
//   Exit: channel reversal on exit_lookback window; hard ATR stop on each leg.
// EA runs on XTIUSD.DWX host chart, D1. Both basket legs trade via
// QM_BasketOrder. QM_SymbolGuardInit(basket) ensures framework Friday close
// sweeps both legs.
// OnTick order follows 2026-07-02 audit: news gate sits below management.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12605;
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
input int    strategy_entry_lookback_d1 = 120;   // Entry channel lookback (D1 bars, excl. most recent)
input int    strategy_exit_lookback_d1  = 40;    // Exit channel lookback (D1 bars, excl. most recent)
input double strategy_beta              = 1.0;   // Log-spread hedge coefficient: spread=ln(XTI)-beta*ln(XAU)
input int    strategy_atr_period_d1     = 20;    // ATR period for per-leg hard stop
input double strategy_atr_sl_mult       = 3.0;   // ATR stop multiplier
input int    strategy_xti_max_spread_pts = 1000; // XTIUSD.DWX spread entry cap in points
input int    strategy_xau_max_spread_pts = 500;  // XAUUSD.DWX spread entry cap in points
input int    strategy_deviation_points   = 20;   // Order deviation tolerance in points

// ---- basket leg symbols ----
string g_sym_xti = "XTIUSD.DWX";
string g_sym_xau = "XAUUSD.DWX";

// ---- cached spread state: updated on each new D1 bar in OnTick ----
double g_spread_now  = 0.0;  // spread at shift=1 (most recent closed D1 bar)
double g_entry_high  = 0.0;  // max spread over [shift 2..entry_lookback+1]
double g_entry_low   = 0.0;  // min spread over [shift 2..entry_lookback+1]
double g_exit_high   = 0.0;  // max spread over [shift 2..exit_lookback+1]
double g_exit_low    = 0.0;  // min spread over [shift 2..exit_lookback+1]
bool   g_state_ready = false;

// ===========================================================================
// Basket helpers
// ===========================================================================

// Count open basket legs (XTI magic slot 0 + XAU magic slot 1)
int PairLegCount()
{
   const long xti_magic = (long)QM_Magic(qm_ea_id, 0);
   const long xau_magic = (long)QM_Magic(qm_ea_id, 1);
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long m = PositionGetInteger(POSITION_MAGIC);
      if(m == xti_magic || m == xau_magic)
         ++count;
   }
   return count;
}

// Direction of the open package: +1=long-ratio(buy XTI/sell XAU), -1=short, 0=none
int PairDirection()
{
   const long xti_magic = (long)QM_Magic(qm_ea_id, 0);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != xti_magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_sym_xti)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
   }
   return 0;
}

// Close all owned basket legs (both XTI and XAU magics)
void ClosePair(const QM_ExitReason reason)
{
   const long xti_magic = (long)QM_Magic(qm_ea_id, 0);
   const long xau_magic = (long)QM_Magic(qm_ea_id, 1);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long m = PositionGetInteger(POSITION_MAGIC);
      if(m == xti_magic || m == xau_magic)
         QM_TM_ClosePosition(ticket, reason);
   }
}

// Open one basket leg via QM_BasketOpenPosition; framework sizes lots from ATR SL
bool OpenLeg(const string symbol,
             const QM_OrderType order_type,
             const int slot,
             const string reason)
{
   const double entry = (order_type == QM_BUY)
                        ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(symbol, order_type, entry,
                                 strategy_atr_period_d1, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol             = symbol;
   req.type               = order_type;
   req.price              = 0.0;   // market price at send
   req.sl                 = sl;
   req.tp                 = 0.0;
   req.lots               = 0.0;   // framework sizes from SL via QM_LotsForRisk
   req.reason             = reason;
   req.symbol_slot        = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy,
                                strategy_deviation_points, req, ticket);
}

// Refresh cached log-spread state from closed D1 bars.
// Called ONLY when QM_IsNewBar() returns true; compute once per day.
void RefreshSpreadState()
{
   g_state_ready = false;
   const int entry_lb = MathMax(20, strategy_entry_lookback_d1);
   const int exit_lb  = MathMax(5,  strategy_exit_lookback_d1);
   // n bars needed: shift 1 (most recent) + entry_lb bars for channel
   const int n = entry_lb + 1;

   double xti[], xau[];
   ArraySetAsSeries(xti, true);
   ArraySetAsSeries(xau, true);
   // perf-allowed: CopyClose called once per new D1 bar via QM_IsNewBar gate in OnTick
   if(CopyClose(g_sym_xti, PERIOD_D1, 1, n, xti) < n)
      return;
   // perf-allowed: CopyClose called once per new D1 bar via QM_IsNewBar gate in OnTick
   if(CopyClose(g_sym_xau, PERIOD_D1, 1, n, xau) < n)
      return;

   if(xti[0] <= 0.0 || xau[0] <= 0.0)
      return;

   // Build spread array: spread[i] = ln(xti[i]) - beta*ln(xau[i])
   // spread[0] = most recent closed bar (shift 1)
   // spread[1..n-1] = prior bars (shift 2..n), used for channel
   double spreads[];
   ArrayResize(spreads, n);
   for(int i = 0; i < n; ++i)
   {
      if(xti[i] <= 0.0 || xau[i] <= 0.0)
         return;
      const double s = MathLog(xti[i]) - strategy_beta * MathLog(xau[i]);
      if(!MathIsValidNumber(s))
         return;
      spreads[i] = s;
   }

   g_spread_now = spreads[0];

   // Entry channel: max/min over indices 1..entry_lb (= shifts 2..entry_lb+1)
   g_entry_high = spreads[1];
   g_entry_low  = spreads[1];
   for(int i = 1; i < n; ++i)
   {
      if(spreads[i] > g_entry_high) g_entry_high = spreads[i];
      if(spreads[i] < g_entry_low)  g_entry_low  = spreads[i];
   }

   // Exit channel: max/min over indices 1..exit_lb (subset of entry data)
   const int elim = MathMin(exit_lb, n - 1);
   g_exit_high = spreads[1];
   g_exit_low  = spreads[1];
   for(int i = 1; i <= elim; ++i)
   {
      if(spreads[i] > g_exit_high) g_exit_high = spreads[i];
      if(spreads[i] < g_exit_low)  g_exit_low  = spreads[i];
   }

   if(!MathIsValidNumber(g_spread_now) || !MathIsValidNumber(g_entry_high) ||
      !MathIsValidNumber(g_exit_high)  || g_entry_high <= g_entry_low    ||
      g_exit_high <= g_exit_low)
      return;

   g_state_ready = true;
}

// ===========================================================================
// Framework hooks — 5 required strategy functions
// ===========================================================================

// No Trade Filter: host-chart guard, parameter guard, spread cap guard.
// Only returns TRUE to BLOCK entry; management still runs every tick.
bool Strategy_NoTradeFilter()
{
   // Host chart guard: EA only valid on XTIUSD.DWX D1
   if(_Symbol != g_sym_xti || _Period != PERIOD_D1)
      return true;

   // Parameter guards
   if(strategy_entry_lookback_d1 < 20 || strategy_exit_lookback_d1 < 5)
      return true;
   if(strategy_exit_lookback_d1 >= strategy_entry_lookback_d1)
      return true;
   if(strategy_beta <= 0.0 || strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;

   // Spread cap guards — DWX invariant: never block on zero spread (ask==bid in tester)
   const double xti_ask   = SymbolInfoDouble(g_sym_xti, SYMBOL_ASK);
   const double xti_bid   = SymbolInfoDouble(g_sym_xti, SYMBOL_BID);
   const double xti_point = SymbolInfoDouble(g_sym_xti, SYMBOL_POINT);
   if(xti_ask > 0.0 && xti_bid > 0.0 && xti_ask > xti_bid && xti_point > 0.0)
   {
      const double xti_sp = (xti_ask - xti_bid) / xti_point;
      if(xti_sp > strategy_xti_max_spread_pts)
         return true;
   }

   const double xau_ask   = SymbolInfoDouble(g_sym_xau, SYMBOL_ASK);
   const double xau_bid   = SymbolInfoDouble(g_sym_xau, SYMBOL_BID);
   const double xau_point = SymbolInfoDouble(g_sym_xau, SYMBOL_POINT);
   if(xau_ask > 0.0 && xau_bid > 0.0 && xau_ask > xau_bid && xau_point > 0.0)
   {
      const double xau_sp = (xau_ask - xau_bid) / xau_point;
      if(xau_sp > strategy_xau_max_spread_pts)
         return true;
   }

   return false;
}

// Trade Entry: evaluate spread channel breakout; open both basket legs directly.
// Returns FALSE always — standard single-leg open path is never used for baskets.
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready)
      return false;
   if(PairLegCount() > 0)
      return false;

   // Determine breakout direction
   int direction = 0;
   if(g_spread_now > g_entry_high)
      direction = 1;   // long ratio: buy XTI / sell XAU
   else if(g_spread_now < g_entry_low)
      direction = -1;  // short ratio: sell XTI / buy XAU

   if(direction == 0)
      return false;

   const QM_OrderType xti_type = (direction > 0) ? QM_BUY  : QM_SELL;
   const QM_OrderType xau_type = (direction > 0) ? QM_SELL : QM_BUY;
   const string pkg            = (direction > 0) ? "QM5_12605_LONG_RATIO"
                                                  : "QM5_12605_SHORT_RATIO";

   const bool xti_ok = OpenLeg(g_sym_xti, xti_type, 0, pkg + "_XTI");
   const bool xau_ok = OpenLeg(g_sym_xau, xau_type, 1, pkg + "_XAU");

   if(xti_ok && !xau_ok)
   {
      // XTI opened but XAU failed; close XTI immediately to avoid orphan
      ClosePair(QM_EXIT_STRATEGY);
   }

   return false;  // never invoke standard single-leg path
}

// Trade Management: orphan detection (every tick) + channel exit (uses cached state).
// Called on every tick before the news gate (2026-07-02 corrected order).
void Strategy_ManageOpenPosition()
{
   const int legs = PairLegCount();
   if(legs == 0)
      return;

   // Orphan: one leg open, other missing — close immediately
   if(legs == 1)
   {
      ClosePair(QM_EXIT_STRATEGY);
      return;
   }

   // Both legs open: check channel-reversal exit using cached spread state
   if(!g_state_ready)
      return;

   const int dir = PairDirection();
   if(dir == 0)
      return;

   if(dir > 0 && g_spread_now < g_exit_low)
      ClosePair(QM_EXIT_STRATEGY);
   else if(dir < 0 && g_spread_now > g_exit_high)
      ClosePair(QM_EXIT_STRATEGY);
}

// Trade Close: basket exits are handled in Strategy_ManageOpenPosition.
bool Strategy_ExitSignal()
{
   return false;
}

// News Filter Hook: defers to framework QM_NewsAllowsTrade2 in OnTick.
bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// ===========================================================================
// Framework lifecycle
// ===========================================================================

int OnInit()
{
   SymbolSelect(g_sym_xti, true);
   SymbolSelect(g_sym_xau, true);

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

   // Register both basket legs so QM_FrameworkOwnsMagicSymbol recognises both
   // magics during Friday close sweeps and kill-switch operations.
   string basket_syms[2] = {g_sym_xti, g_sym_xau};
   QM_SymbolGuardInit(basket_syms);
   QM_BasketWarmupHistory(basket_syms, PERIOD_D1,
                          MathMax(160, strategy_entry_lookback_d1 + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12605\",\"ea\":\"cme-oilgold-brk\"}");
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

   // FridayClose: QM_SymbolGuardInit ensures the sweep closes both basket legs
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Latch QM_IsNewBar once; advance spread state immediately so management
   // and entry see fresh data on the same tick. (2026-07-02 canonical order)
   const bool nb = QM_IsNewBar();
   if(nb)
   {
      RefreshSpreadState();
      QM_EquityStreamOnNewBar();
   }

   // Management runs every tick, using cached spread state.
   // Positioned before the news gate so risk management is never news-blocked.
   Strategy_ManageOpenPosition();

   // Entry: only on new D1 bar, after news gate (news blocks entry only)
   if(!nb)
      return;

   const datetime broker_now = TimeCurrent();
   bool news_ok = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_ok = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_ok = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);

   if(!news_ok)
      return;

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
