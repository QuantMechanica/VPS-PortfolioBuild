#property strict
#property version   "5.0"
#property description "QM5_12552 EMA-Stretch Mean-Reversion with Bounded 1%-Risk ATR Scale-In"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12552 ema-stretch-mr-bounded-grid
// -----------------------------------------------------------------------------
// Single-symbol H1 mean-reversion. Enters when price is stretched far from
// EMA(200) with RSI confirmation, then scales into a BOUNDED ladder whose
// full-ladder worst-case loss is capped at risk_budget_pct (default 1%) of
// equity by a SINGLE shared catastrophic stop S, and exits the whole basket
// via one of 4 TP modes. The video's 1.5x averaging-down martingale is REPLACED
// by a backward-solved lot ladder + shared stop (R4/HR14-critical property).
//
// Framework-contract notes (read before editing):
//   * QM_EntryRequest carries NO lot field, and QM_Entry() (a) sizes lots via
//     QM_LotsForRisk and (b) rejects a 2nd position on the same magic+symbol
//     (QM_ENTRY_REJECTED_DUPLICATE). A bounded multi-level grid needs explicit
//     per-level lots AND multiple simultaneous same-magic positions, so the
//     framework auto-entry path cannot express this strategy.
//   * Therefore Strategy_EntrySignal() ALWAYS returns false (no framework
//     auto-entry). ALL fills — level 1 and the grid adds — are placed inside
//     Strategy_ManageOpenPosition() through a single bounded-lot send helper
//     that mirrors the framework idioms: QM_FrameworkMagic() for the magic,
//     QM_TradeContextSend() for the broker round-trip (requote/kill handling +
//     logging-class), QM_TM_NormalizeVolume / QM_TM_NormalizePrice for
//     normalization. This is the framework's own trade context — not a raw
//     bypass — so kill-switch, news and Friday-close gating in OnTick still
//     fully govern when adds may happen.
//   * The 1% budget IS the risk model input for this card (card "Position
//     Sizing"): the backward-solved L_1..L_N replace QM_LotsForRisk by design.
//   * All indicator reads use the pooled QM_* readers on CLOSED bars (shift 1).
//     QM_IsNewBar() is consumed ONCE by the framework OnTick entry gate; the
//     grid_min_bars latch tracks iTime(_Symbol,PERIOD_H1,0) instead of calling
//     QM_IsNewBar() again (which would double-consume the bar tracker).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12552;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

// -----------------------------------------------------------------------------
// Strategy parameters (card "Parameters To Test")
// -----------------------------------------------------------------------------
enum QM_TP_Mode
  {
   TP_SLOW_MA       = 0,   // close all when price crosses back through EMA(200)
   TP_RSI_RECOVERY  = 1,   // close all when RSI recovers past the opposite offset
   TP_VWAP_PIPS     = 2,   // hard broker TP at basket VWAP +/- vwap_target_pips
   TP_VWAP_ATR      = 3    // hard broker TP at basket VWAP +/- vwap_atr_mult*ATR(long)
  };

input group "Strategy"
input double   M_entry              = 10.0;   // entry stretch in ATR(long) multiples
input int      rsi_offset           = 15;     // RSI confirmation offset around 50
input int      atr_long_period      = 100;    // "long" ATR (stretch + stop span)
input int      atr_short_period     = 14;     // "short" ATR (grid spacing)
input int      rsi_period           = 14;     // Wilder RSI period
input int      ema_period           = 200;    // slow mean (stretch anchor)
input int      grid_levels          = 5;      // N total ladder levels (incl. level 1)
input double   lot_mult             = 1.15;   // lot ladder multiplier, in [1.0, 1.3]
input double   grid_base_atr_mult   = 1.0;    // base ATR-spacing multiplier
input double   grid_min_pips        = 50.0;   // per-symbol spacing floor, in pips
input int      grid_min_bars        = 1;      // min closed H1 bars between fills
input double   stop_span_atr        = 14.0;   // shared stop distance in ATR(long) mult
input double   risk_budget_pct      = 1.0;    // FULL-ladder worst-case risk (% equity)
input QM_TP_Mode tp_mode            = TP_SLOW_MA;
input double   vwap_target_pips     = 200.0;  // TP_VWAP_PIPS target, in pips
input double   vwap_atr_mult        = 1.0;    // TP_VWAP_ATR target, in ATR(long) mult
input int      max_hold_hours       = 0;      // basket time-exit, 0 = off
input int      trail_step_points    = 0;      // trail stop step, in points, 0 = off
input bool     use_trailing         = false;  // tighten shared S toward break-even
input bool     enable_short         = true;   // allow short baskets
input double   max_spread_points    = 80.0;   // wide-spread block (points)

// -----------------------------------------------------------------------------
// File-scope basket state. One direction at a time per magic+symbol.
// -----------------------------------------------------------------------------
#define QM_MAX_GRID_LEVELS 32

bool      g_basket_active        = false;          // a basket is currently open / opening
int       g_basket_dir           = 0;              // +1 long / -1 short
int       g_planned_levels       = 0;              // N actually planned (>= 1)
int       g_fill_count           = 0;             // levels filled so far
double    g_plan_price[QM_MAX_GRID_LEVELS];        // planned fill prices p_1..p_N
double    g_plan_lots[QM_MAX_GRID_LEVELS];         // bounded ladder lots L_1..L_N
double    g_shared_stop          = 0.0;            // shared catastrophic stop S
datetime  g_last_fill_bar        = 0;              // H1 bar-open time of the last fill
datetime  g_basket_open_time     = 0;              // wall-clock open time of level 1

// =============================================================================
// Helpers
// =============================================================================

// Pip size: 10 points on 3/5-digit FX quotes, 1 point otherwise. Used so
// grid_min_pips / vwap_target_pips read as conventional pips per symbol.
double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

// Money lost per lot per unit of adverse price travel (tick value / tick size).
double Strategy_ValuePerLotPerPriceUnit()
  {
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_value > 0.0 && tick_size > 0.0)
      return tick_value / tick_size;
   // Fallback: contract_size (1 price unit == contract_size of quote currency).
   const double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   return (contract > 0.0) ? contract : 0.0;
  }

// Reset all basket state (no positions for this magic remain).
void Strategy_ResetBasket()
  {
   g_basket_active    = false;
   g_basket_dir       = 0;
   g_planned_levels   = 0;
   g_fill_count       = 0;
   g_shared_stop      = 0.0;
   g_last_fill_bar    = 0;
   g_basket_open_time = 0;
   for(int i = 0; i < QM_MAX_GRID_LEVELS; ++i)
     {
      g_plan_price[i] = 0.0;
      g_plan_lots[i]  = 0.0;
     }
  }

// Count this magic's open positions, and (by ref) collect aggregate info used
// by trailing / VWAP. Returns the open count.
int Strategy_CountBasketPositions(double &out_weighted_price, double &out_total_lots, double &out_agg_profit)
  {
   out_weighted_price = 0.0;
   out_total_lots     = 0.0;
   out_agg_profit     = 0.0;
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const double vol  = PositionGetDouble(POSITION_VOLUME);
      const double open = PositionGetDouble(POSITION_PRICE_OPEN);
      out_weighted_price += open * vol;
      out_total_lots     += vol;
      out_agg_profit     += PositionGetDouble(POSITION_PROFIT)
                          + PositionGetDouble(POSITION_SWAP);
      count++;
     }
   if(out_total_lots > 0.0)
      out_weighted_price /= out_total_lots;
   return count;
  }

// Lot-weighted VWAP of the open basket (0 if empty).
double Strategy_BasketVWAP()
  {
   double vwap, lots, profit;
   if(Strategy_CountBasketPositions(vwap, lots, profit) <= 0)
      return 0.0;
   return vwap;
  }

// Direct, framework-faithful market send at an EXPLICIT bounded lot. Mirrors
// QM_Entry's request shape but carries our own L_k volume (which QM_Entry can
// not). Uses QM_TradeContextSend so requote/kill/logging-class behaviour and
// the kill-switch corset are identical to the framework path.
bool Strategy_SendBounded(const int dir, const double lots, const double sl, const double tp, const string reason)
  {
   const double norm_lots = QM_TM_NormalizeVolume(_Symbol, lots);
   if(norm_lots <= 0.0)
      return false;

   const bool is_buy = (dir > 0);
   const double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0)
      return false;

   MqlTradeRequest request;
   ZeroMemory(request);
   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.magic     = QM_FrameworkMagic();
   request.volume    = norm_lots;
   request.type      = is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price     = QM_TM_NormalizePrice(_Symbol, price);
   request.sl        = (sl > 0.0) ? QM_TM_NormalizePrice(_Symbol, sl) : 0.0;
   request.tp        = (tp > 0.0) ? QM_TM_NormalizePrice(_Symbol, tp) : 0.0;
   request.deviation = QM_TM_DEFAULT_DEVIATION_POINTS;
   request.comment   = reason;

   MqlTradeResult result;
   string error_class = "";
   const bool ok = QM_TradeContextSend(request, result, error_class);

   const string payload = StringFormat(
      "{\"symbol\":\"%s\",\"dir\":%d,\"lots\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
      QM_LoggerEscapeJson(_Symbol), dir, norm_lots, request.sl, request.tp,
      QM_LoggerEscapeJson(reason), ok ? "true" : "false", result.retcode,
      QM_LoggerEscapeJson(error_class));
   QM_LogEvent(ok ? QM_INFO : QM_WARN, "GRID_FILL", payload);
   return ok;
  }

// Compute the hard broker TP for a given basket VWAP (VWAP modes only).
// Returns 0 for virtual modes (TP_SLOW_MA / TP_RSI_RECOVERY) which exit at
// market via Strategy_ExitSignal.
double Strategy_HardTP(const int dir, const double vwap)
  {
   if(vwap <= 0.0)
      return 0.0;
   if(tp_mode == TP_VWAP_PIPS)
     {
      const double pip = Strategy_PipSize();
      if(pip <= 0.0)
         return 0.0;
      return (dir > 0) ? vwap + vwap_target_pips * pip
                       : vwap - vwap_target_pips * pip;
     }
   if(tp_mode == TP_VWAP_ATR)
     {
      const double atr_long = QM_ATR(_Symbol, PERIOD_H1, atr_long_period, 1);
      if(atr_long <= 0.0)
         return 0.0;
      return (dir > 0) ? vwap + vwap_atr_mult * atr_long
                       : vwap - vwap_atr_mult * atr_long;
     }
   return 0.0;
  }

// Re-stamp the hard VWAP TP on every open basket position after a new fill /
// each bar (VWAP shifts as the basket grows). No-op for virtual TP modes.
void Strategy_RefreshVwapTP()
  {
   if(tp_mode != TP_VWAP_PIPS && tp_mode != TP_VWAP_ATR)
      return;
   const double vwap = Strategy_BasketVWAP();
   const double tp   = Strategy_HardTP(g_basket_dir, vwap);
   if(tp <= 0.0)
      return;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const double cur_tp = PositionGetDouble(POSITION_TP);
      // Only modify when the target actually moved (avoid redundant sends).
      if(MathAbs(cur_tp - QM_TM_NormalizePrice(_Symbol, tp)) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 0.5)
         QM_TM_MoveTP(ticket, tp, "vwap_tp_refresh");
     }
  }

// Plan the FULL ladder geometry, the shared stop S, and the backward-solved
// bounded lot ladder. Stores everything in file-scope state. Returns the number
// of levels actually plannable (>= 1) or 0 if sizing is impossible.
int Strategy_PlanBasket(const int dir, const double entry1)
  {
   const double atr_long  = QM_ATR(_Symbol, PERIOD_H1, atr_long_period, 1);
   const double atr_short = QM_ATR(_Symbol, PERIOD_H1, atr_short_period, 1);
   if(atr_long <= 0.0 || atr_short <= 0.0 || entry1 <= 0.0)
      return 0;

   int N = grid_levels;
   if(N < 1)
      N = 1;
   if(N > QM_MAX_GRID_LEVELS)
      N = QM_MAX_GRID_LEVELS;

   const double pip   = Strategy_PipSize();
   const double floor_dist = grid_min_pips * pip;
   // Per-level add distance (card formula): vol-ratio-scaled ATR, floored.
   const double step_dist  = MathMax(floor_dist,
                                     grid_base_atr_mult * atr_short * (atr_short / atr_long));

   // Planned fill prices: p_1 = entry1, p_k = entry1 -/+ (k-1)*step_dist.
   for(int k = 0; k < N; ++k)
     {
      const double cum = step_dist * (double)k;
      g_plan_price[k] = (dir > 0) ? (entry1 - cum) : (entry1 + cum);
     }

   // Shared catastrophic stop S beyond level N.
   const double stop_dist = stop_span_atr * atr_long;
   g_shared_stop = (dir > 0) ? (entry1 - stop_dist) : (entry1 + stop_dist);
   if(g_shared_stop <= 0.0)
      return 0;

   // Backward-solve L_1 so the FULL ladder filled at p_k then stopped at S
   // loses exactly risk_budget_pct of equity:
   //   L_1 = budget / Σ_k lot_mult^(k-1) * |p_k - S| * value_per_unit
   const double value_unit = Strategy_ValuePerLotPerPriceUnit();
   if(value_unit <= 0.0)
      return 0;
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double budget = (risk_budget_pct / 100.0) * equity;
   if(budget <= 0.0)
      return 0;

   double denom = 0.0;
   for(int k = 0; k < N; ++k)
     {
      const double w   = MathPow(lot_mult, (double)k);   // lot_mult^(k-1), 0-based k
      const double adv = MathAbs(g_plan_price[k] - g_shared_stop);
      denom += w * adv * value_unit;
     }
   if(denom <= 0.0)
      return 0;

   const double L1 = budget / denom;

   // Build the ladder L_k = L_1 * lot_mult^(k-1), normalized to min/step.
   // Levels whose lot rounds below the broker minimum are dropped (never
   // up-sized past the 1% budget). The plan keeps the contiguous filled prefix
   // of levels that DO round to a valid lot.
   int plannable = 0;
   for(int k = 0; k < N; ++k)
     {
      const double raw = L1 * MathPow(lot_mult, (double)k);
      const double norm = QM_TM_NormalizeVolume(_Symbol, raw);
      g_plan_lots[k] = norm;          // 0.0 means "skip this level"
      if(norm > 0.0)
         plannable++;
     }
   if(plannable <= 0 || g_plan_lots[0] <= 0.0)
      return 0;                       // cannot even afford level 1 -> skip basket

   g_planned_levels = N;
   return N;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// Spread filter only. Block ONLY a genuinely wide spread; NEVER block on a
// zero / degenerate spread (.DWX quotes ask==bid / spread==0 in the tester).
bool Strategy_NoTradeFilter()
  {
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > max_spread_points * point)
      return true;   // genuinely wide spread -> block
   return false;
  }

// No framework auto-entry: the bounded grid (explicit per-level lots + multiple
// same-magic positions) cannot go through QM_Entry. All fills are placed in
// Strategy_ManageOpenPosition() via Strategy_SendBounded(). Always return false.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return false;
  }

// All entry / scale-in logic. Runs every tick (framework calls this before the
// QM_IsNewBar entry gate). Opens level 1 on a fresh stretch signal, then scales
// the bounded ladder as price reaches each planned add. New-bar work (entry
// signal eval + grid_min_bars latch) is gated on the H1 bar-open time so it runs
// once per closed bar without double-consuming QM_IsNewBar().
void Strategy_ManageOpenPosition()
  {
   double vwap, total_lots, agg_profit;
   const int open_count = Strategy_CountBasketPositions(vwap, total_lots, agg_profit);

   // Basket fully closed externally (TP/SL/Friday/kill) -> reset state.
   if(open_count <= 0 && g_basket_active)
     {
      Strategy_ResetBasket();
      return;
     }

   // perf-allowed: H1 bar-open time used purely as a once-per-bar latch and as
   // the grid_min_bars spacing reference. Not an indicator/series math read.
   const datetime cur_bar = iTime(_Symbol, PERIOD_H1, 0); // perf-allowed
   static datetime s_last_eval_bar = 0;
   const bool is_new_bar = (cur_bar > 0 && cur_bar != s_last_eval_bar);

   // ------------------------------------------------------------------
   // No basket open: look for a fresh level-1 stretch signal (bar close).
   // ------------------------------------------------------------------
   if(open_count <= 0 && !g_basket_active)
     {
      if(!is_new_bar)
         return;
      s_last_eval_bar = cur_bar;

      const double ema      = QM_EMA(_Symbol, PERIOD_H1, ema_period, 1);
      const double atr_long = QM_ATR(_Symbol, PERIOD_H1, atr_long_period, 1);
      const double rsi      = QM_RSI(_Symbol, PERIOD_H1, rsi_period, 1);
      if(ema <= 0.0 || atr_long <= 0.0 || rsi <= 0.0)
         return;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0)
         return;

      const double stretch = M_entry * atr_long;
      int dir = 0;
      if(ask < ema - stretch && rsi < (50.0 - rsi_offset))
         dir = 1;                                  // long
      else if(enable_short && bid > ema + stretch && rsi > (50.0 + rsi_offset))
         dir = -1;                                 // short
      if(dir == 0)
         return;

      const double entry1 = (dir > 0) ? ask : bid;
      if(Strategy_PlanBasket(dir, entry1) <= 0)
         return;

      // Open level 1 at its bounded lot, with the shared stop S as SL and the
      // hard VWAP TP (0 for virtual modes).
      g_basket_dir       = dir;
      const double tp1   = Strategy_HardTP(dir, entry1);   // level-1 VWAP == entry1
      if(Strategy_SendBounded(dir, g_plan_lots[0], g_shared_stop, tp1,
                              (dir > 0) ? "EMA_STRETCH_MR_L1_LONG" : "EMA_STRETCH_MR_L1_SHORT"))
        {
         g_basket_active = true;
         g_fill_count    = 1;
         g_last_fill_bar = cur_bar;
         g_basket_open_time = TimeCurrent();
         Strategy_RefreshVwapTP();
        }
      return;
     }

   // ------------------------------------------------------------------
   // Basket open: manage grid adds, VWAP TP refresh, optional trailing.
   // ------------------------------------------------------------------
   if(open_count <= 0)
      return;

   // (1) Grid add: next planned level reached + grid_min_bars elapsed.
   if(g_fill_count < g_planned_levels)
     {
      const int    k       = g_fill_count;            // 0-based index of next level
      const double target  = g_plan_price[k];
      const double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // Reached the next add price (price moved further against the basket)?
      bool reached = false;
      if(g_basket_dir > 0)
         reached = (ask > 0.0 && ask <= target);
      else
         reached = (bid > 0.0 && bid >= target);

      // grid_min_bars: count distinct closed H1 bars since the last fill.
      bool bars_ok = true;
      if(grid_min_bars > 0)
        {
         const int bars_since = iBarShift(_Symbol, PERIOD_H1, g_last_fill_bar, false); // perf-allowed
         bars_ok = (bars_since >= grid_min_bars);
        }

      if(reached && bars_ok && g_plan_lots[k] > 0.0)
        {
         // VWAP TP recomputed AFTER the fill below; send level k with current
         // basket TP target as a placeholder (refreshed immediately after).
         const double tp_k = Strategy_HardTP(g_basket_dir, Strategy_BasketVWAP());
         if(Strategy_SendBounded(g_basket_dir, g_plan_lots[k], g_shared_stop, tp_k,
                                 (g_basket_dir > 0) ? "EMA_STRETCH_MR_ADD_LONG" : "EMA_STRETCH_MR_ADD_SHORT"))
           {
            g_fill_count++;
            g_last_fill_bar = cur_bar;
            Strategy_RefreshVwapTP();   // VWAP shifted -> re-stamp all TPs
           }
        }
      else if(g_plan_lots[k] <= 0.0)
        {
         // Skipped (sub-min) level: advance past it so the next plannable level
         // can be evaluated without stalling the ladder.
         g_fill_count++;
        }
     }

   // (2) Keep the hard VWAP TP current once per new bar even without a fill
   //     (the basket VWAP is fixed between fills, so this is mostly a no-op,
   //     but it self-heals any TP that failed to stamp on a prior tick).
   if(is_new_bar)
     {
      s_last_eval_bar = cur_bar;
      Strategy_RefreshVwapTP();
     }

   // (3) Optional trailing: once the basket is in aggregate profit, tighten the
   //     shared stop S toward break-even (VWAP) in the profit direction only,
   //     by trail_step_points. Never loosens. Re-modify ALL basket SLs.
   if(use_trailing && trail_step_points > 0 && agg_profit > 0.0 && total_lots > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double step  = trail_step_points * point;
      const double basket_vwap = vwap;   // break-even reference
      double new_stop = g_shared_stop;
      if(g_basket_dir > 0)
        {
         const double candidate = basket_vwap - step;          // trail up toward BE
         if(candidate > new_stop)
            new_stop = candidate;
         if(new_stop > basket_vwap)                             // never past BE
            new_stop = basket_vwap;
        }
      else
        {
         const double candidate = basket_vwap + step;          // trail down toward BE
         if(candidate < new_stop || new_stop <= 0.0)
            new_stop = candidate;
         if(new_stop < basket_vwap)                             // never past BE
            new_stop = basket_vwap;
        }

      // Only apply if it strictly tightens (moves toward price) vs current S.
      const bool tightens = (g_basket_dir > 0) ? (new_stop > g_shared_stop + point * 0.5)
                                               : (new_stop < g_shared_stop - point * 0.5);
      if(tightens)
        {
         g_shared_stop = new_stop;
         const int magic = QM_FrameworkMagic();
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(ticket == 0 || !PositionSelectByTicket(ticket))
               continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != magic)
               continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol)
               continue;
            QM_TM_MoveSL(ticket, g_shared_stop, "basket_trail_to_be");
           }
        }
     }
  }

// Whole-basket virtual exit. Returns true -> the framework OnTick loop closes
// ALL positions of this magic. VWAP modes (3/4) exit via the hard broker TP, so
// they return false here EXCEPT for the optional time-exit. Evaluated on closed
// bars only for the indicator-condition exits.
bool Strategy_ExitSignal()
  {
   if(!g_basket_active || g_basket_dir == 0)
      return false;

   // Time exit (all modes) — wall-clock hours since level-1 open.
   if(max_hold_hours > 0 && g_basket_open_time > 0)
     {
      if((TimeCurrent() - g_basket_open_time) >= (long)max_hold_hours * 3600)
         return true;
     }

   // Indicator-condition exits only on a closed bar.
   // perf-allowed: bar-open time latch (not indicator/series math).
   const datetime cur_bar = iTime(_Symbol, PERIOD_H1, 0); // perf-allowed
   static datetime s_last_exit_bar = 0;
   if(cur_bar <= 0 || cur_bar == s_last_exit_bar)
      return false;
   s_last_exit_bar = cur_bar;

   if(tp_mode == TP_SLOW_MA)
     {
      const double ema = QM_EMA(_Symbol, PERIOD_H1, ema_period, 1);
      if(ema <= 0.0)
         return false;
      const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed
      if(close1 <= 0.0)
         return false;
      // Long basket: price crossed back UP through EMA200. Short: back DOWN.
      if(g_basket_dir > 0 && close1 >= ema)
         return true;
      if(g_basket_dir < 0 && close1 <= ema)
         return true;
      return false;
     }

   if(tp_mode == TP_RSI_RECOVERY)
     {
      const double rsi = QM_RSI(_Symbol, PERIOD_H1, rsi_period, 1);
      if(rsi <= 0.0)
         return false;
      // Long: RSI recovered past the opposite (upper) offset. Short: lower.
      if(g_basket_dir > 0 && rsi >= (50.0 + rsi_offset))
         return true;
      if(g_basket_dir < 0 && rsi <= (50.0 - rsi_offset))
         return true;
      return false;
     }

   // TP_VWAP_PIPS / TP_VWAP_ATR: exit via the hard broker TP (no virtual exit).
   return false;
  }

// Optional news-filter override. Defer to the central framework filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   Strategy_ResetBasket();
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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
      Strategy_ResetBasket();
     }

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
