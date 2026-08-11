#property strict
#property version   "5.0"
#property description "QM5_1628 carney-5-0-pattern-h4 — Carney 5-0 Pattern (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1628 carney-5-0-pattern-h4
// -----------------------------------------------------------------------------
// Source: Scott Carney — Harmonic Trading Vol II (2010) ch. 6.
// Card: artifacts/cards_approved/QM5_1628_carney-5-0-pattern-h4.md
//       (g0_status APPROVED).
//
// Mechanics:
//   - X-A leg: any directional impulse.
//   - A-B leg: 1.130 to 1.618 extension of X-A (B extends beyond X).
//   - B-C leg: 1.618 to 2.240 extension of A-B (C extends beyond A).
//   - C-D leg: exactly 50% retracement of B-C (D lands at midpoint of B-C).
//   - Reversal entry at D with candle confirmation (close > open for BUY).
//   - With-trend filter: D1 Close > SMA(200, D1) (for BUY, mirror for SELL).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1628;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fractal_wing_bars        = 2;
input int    strategy_min_xd_bars              = 25;
input int    strategy_max_xd_bars              = 80;
input int    strategy_scan_bars                = 96;
input double strategy_cd_tolerance             = 0.02;  // ±2% tolerance on 50% retracement
input double strategy_ab_xa_min                = 1.130;
input double strategy_ab_xa_max                = 1.618;
input double strategy_bc_ab_min                = 1.618;
input double strategy_bc_ab_max                = 2.240;
input int    strategy_atr_period               = 14;
input double strategy_sl_atr_mult              = 0.5;   // beyond D-pivot by 0.5 * ATR
input double strategy_max_sl_atr_mult          = 3.5;   // ATR SL cap
input double strategy_tp1_cd_retracement       = 0.500; // 50% of CD as conservative target
input double strategy_tp2_cd_retracement       = 1.000; // C-pivot as aggressive target
input double strategy_tp1_close_fraction       = 0.50;  // close 50% at TP1
input int    strategy_cooldown_bars            = 12;
input int    strategy_time_stop_bars           = 48;
input double strategy_min_pattern_size_atr     = 2.0;   // X-A leg >= 2.0 * ATR(14)
input double strategy_spread_atr_limit         = 0.3;   // skip entry if spread > 0.3 * ATR

struct StrategyPivot
{
   int      kind;
   int      shift;
   double   price;
   datetime time;
};

double   g_active_tp1_price = 0.0;
bool     g_tp1_done = false;
datetime g_last_signal_time = 0;
datetime g_cooldown_until = 0;

double Strategy_NormalizePrice(const double price)
{
   return QM_StopRulesNormalizePrice(_Symbol, price);
}

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
{
   ticket = 0;
   position_type = POSITION_TYPE_BUY;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
}

bool Strategy_FractalHigh(const MqlRates &rates[], const int index, const int total, const int wing)
{
   if(index < wing || index >= total - wing)
      return false;

   const double value = rates[index].high;
   for(int i = 1; i <= wing; ++i)
     {
      if(value <= rates[index - i].high || value <= rates[index + i].high)
         return false;
     }
   return true;
}

bool Strategy_FractalLow(const MqlRates &rates[], const int index, const int total, const int wing)
{
   if(index < wing || index >= total - wing)
      return false;

   const double value = rates[index].low;
   for(int i = 1; i <= wing; ++i)
     {
      if(value >= rates[index - i].low || value >= rates[index + i].low)
         return false;
     }
   return true;
}

void Strategy_AddPivot(StrategyPivot &pivots[], int &count, const int kind,
                       const int shift, const double price, const datetime time)
{
   if(count > 0 && pivots[count - 1].kind == kind)
     {
      const bool replace = (kind > 0 && price > pivots[count - 1].price) ||
                           (kind < 0 && price < pivots[count - 1].price);
      if(replace)
        {
         pivots[count - 1].shift = shift;
         pivots[count - 1].price = price;
         pivots[count - 1].time = time;
        }
      return;
     }

   if(count >= 128)
      return;

   pivots[count].kind = kind;
   pivots[count].shift = shift;
   pivots[count].price = price;
   pivots[count].time = time;
   ++count;
}

int Strategy_CollectPivots(const MqlRates &rates[], const int total, StrategyPivot &pivots[])
{
   int count = 0;
   const int wing = MathMax(1, strategy_fractal_wing_bars);

   for(int i = total - wing - 1; i >= wing; --i)
     {
      const bool high = Strategy_FractalHigh(rates, i, total, wing);
      const bool low = Strategy_FractalLow(rates, i, total, wing);
      if(high && !low)
         Strategy_AddPivot(pivots, count, +1, i, rates[i].high, rates[i].time);
      else if(low && !high)
         Strategy_AddPivot(pivots, count, -1, i, rates[i].low, rates[i].time);
     }

   return count;
}

bool Strategy_RatioInRange(const double value, const double lo, const double hi)
{
   return (value >= lo && value <= hi);
}

bool Strategy_BullishMacroOK()
{
   const double sma200_d1 = QM_SMA(_Symbol, PERIOD_D1, 200, 1);
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1);
   return (sma200_d1 > 0.0 && close_d1 > 0.0 && close_d1 > sma200_d1);
}

bool Strategy_BearishMacroOK()
{
   const double sma200_d1 = QM_SMA(_Symbol, PERIOD_D1, 200, 1);
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1);
   return (sma200_d1 > 0.0 && close_d1 > 0.0 && close_d1 < sma200_d1);
}

bool Strategy_BuildEntry(const bool bullish, const double c_price, const double d_price,
                          const double zone_edge, const double atr, QM_EntryRequest &req)
{
   const QM_OrderType order_type = bullish ? QM_BUY : QM_SELL;
   const double entry = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   double sl = bullish ? (d_price - strategy_sl_atr_mult * atr)
                       : (d_price + strategy_sl_atr_mult * atr);
   const double max_risk = strategy_max_sl_atr_mult * atr;
   if(bullish && entry - sl > max_risk)
      sl = entry - max_risk;
   if(!bullish && sl - entry > max_risk)
      sl = entry + max_risk;

   const double cd = MathAbs(c_price - d_price);
   if(cd <= 0.0)
      return false;

   const double tp1 = bullish ? (d_price + strategy_tp1_cd_retracement * cd)
                              : (d_price - strategy_tp1_cd_retracement * cd);
   const double tp2 = bullish ? (d_price + strategy_tp2_cd_retracement * cd)
                              : (d_price - strategy_tp2_cd_retracement * cd);

   if(bullish && (sl >= entry || tp2 <= entry))
      return false;
   if(!bullish && (sl <= entry || tp2 >= entry))
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = Strategy_NormalizePrice(tp2);
   req.reason = bullish ? "HARMONIC_5_0_BULLISH" : "HARMONIC_5_0_BEARISH";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_active_tp1_price = Strategy_NormalizePrice(tp1);
   g_tp1_done = false;
   return (req.sl > 0.0 && req.tp > 0.0 && g_active_tp1_price > 0.0);
}

bool Strategy_CheckBullish(const StrategyPivot &x, const StrategyPivot &a,
                           const StrategyPivot &b, const StrategyPivot &c,
                           const MqlRates &d_bar, const double atr, QM_EntryRequest &req)
{
   if(x.kind != -1 || a.kind != +1 || b.kind != -1 || c.kind != +1)
      return false;
   if(x.shift < strategy_min_xd_bars || x.shift > strategy_max_xd_bars)
      return false;
   if(!(b.price < x.price && c.price > a.price))
      return false;

   const double xa = MathAbs(a.price - x.price);
   const double ab = MathAbs(a.price - b.price);
   const double bc = MathAbs(c.price - b.price);
   if(xa <= 0.0 || ab <= 0.0 || bc <= 0.0)
      return false;

   // Minimum Pattern Size Gate
   if(xa < strategy_min_pattern_size_atr * atr)
      return false;

   if(!Strategy_RatioInRange(ab / xa, strategy_ab_xa_min, strategy_ab_xa_max))
      return false;
   if(!Strategy_RatioInRange(bc / ab, strategy_bc_ab_min, strategy_bc_ab_max))
      return false;

   // 50% retracement of B-C
   const double d_target = c.price - 0.500 * (c.price - b.price);
   const double zone_low = d_target - strategy_cd_tolerance * bc;
   const double zone_high = d_target + strategy_cd_tolerance * bc;

   const bool low_touched = (d_bar.low >= zone_low && d_bar.low <= zone_high);
   const bool bullish_bar = (d_bar.close > d_bar.open);
   if(!low_touched || !bullish_bar)
      return false;

   // Price at D within 0.3 * ATR
   if(MathAbs(d_bar.low - d_target) > 0.3 * atr)
      return false;

   if(!Strategy_BullishMacroOK())
      return false;

   return Strategy_BuildEntry(true, c.price, d_bar.low, zone_low, atr, req);
}

bool Strategy_CheckBearish(const StrategyPivot &x, const StrategyPivot &a,
                           const StrategyPivot &b, const StrategyPivot &c,
                           const MqlRates &d_bar, const double atr, QM_EntryRequest &req)
{
   if(x.kind != +1 || a.kind != -1 || b.kind != +1 || c.kind != -1)
      return false;
   if(x.shift < strategy_min_xd_bars || x.shift > strategy_max_xd_bars)
      return false;
   if(!(b.price > x.price && c.price < a.price))
      return false;

   const double xa = MathAbs(a.price - x.price);
   const double ab = MathAbs(a.price - b.price);
   const double bc = MathAbs(c.price - b.price);
   if(xa <= 0.0 || ab <= 0.0 || bc <= 0.0)
      return false;

   // Minimum Pattern Size Gate
   if(xa < strategy_min_pattern_size_atr * atr)
      return false;

   if(!Strategy_RatioInRange(ab / xa, strategy_ab_xa_min, strategy_ab_xa_max))
      return false;
   if(!Strategy_RatioInRange(bc / ab, strategy_bc_ab_min, strategy_bc_ab_max))
      return false;

   // 50% retracement of B-C
   const double d_target = c.price + 0.500 * (b.price - c.price);
   const double zone_low = d_target - strategy_cd_tolerance * bc;
   const double zone_high = d_target + strategy_cd_tolerance * bc;

   const bool high_touched = (d_bar.high >= zone_low && d_bar.high <= zone_high);
   const bool bearish_bar = (d_bar.close < d_bar.open);
   if(!high_touched || !bearish_bar)
      return false;

   // Price at D within 0.3 * ATR
   if(MathAbs(d_bar.high - d_target) > 0.3 * atr)
      return false;

   if(!Strategy_BearishMacroOK())
      return false;

   return Strategy_BuildEntry(false, c.price, d_bar.high, zone_high, atr, req);
}

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // Spread filter
   if((ask - bid) > strategy_spread_atr_limit * atr)
      return true;

   if(g_cooldown_until > 0 && TimeCurrent() < g_cooldown_until)
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int bars_needed = (strategy_scan_bars > strategy_max_xd_bars + 8) ? strategy_scan_bars : strategy_max_xd_bars + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, rates);
   if(copied < strategy_min_xd_bars + 6)
      return false;

   StrategyPivot pivots[128];
   const int pivot_count = Strategy_CollectPivots(rates, copied, pivots);
   if(pivot_count < 4)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   for(int i = pivot_count - 4; i >= 0; --i)
     {
      // Verify new pivot D to avoid re-triggering on same bar
      if(pivots[i].time == g_last_signal_time)
         continue;

      if(Strategy_CheckBullish(pivots[i], pivots[i + 1], pivots[i + 2], pivots[i + 3], rates[0], atr, req))
        {
         g_last_signal_time = pivots[i].time;
         g_cooldown_until = TimeCurrent() + strategy_cooldown_bars * PeriodSeconds(PERIOD_H4);
         return true;
        }
      if(Strategy_CheckBearish(pivots[i], pivots[i + 1], pivots[i + 2], pivots[i + 3], rates[0], atr, req))
        {
         g_last_signal_time = pivots[i].time;
         g_cooldown_until = TimeCurrent() + strategy_cooldown_bars * PeriodSeconds(PERIOD_H4);
         return true;
        }
     }

   return false;
}

void Strategy_ManageOpenPosition()
{
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_SelectOurPosition(ticket, position_type))
     {
      g_tp1_done = false;
      g_active_tp1_price = 0.0;
      return;
     }

   if(g_tp1_done || g_active_tp1_price <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const bool tp1_hit = is_buy ? (market >= g_active_tp1_price) : (market <= g_active_tp1_price);
   if(!tp1_hit)
      return;

   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_close_fraction);
   if(partial_lots > 0.0 && partial_lots < volume)
      QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL);

   // Move SL to BE + spread
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double be_sl = is_buy ? (open_price + spread) : (open_price - spread);
   be_sl = Strategy_NormalizePrice(be_sl);
   QM_TM_MoveSL(ticket, be_sl, "tp1_move_to_be_spread");
   g_tp1_done = true;
}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_SelectOurPosition(ticket, position_type))
      return false;

   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   const int open_shift = iBarShift(_Symbol, PERIOD_H4, opened, false);
   if(open_shift >= strategy_time_stop_bars)
      return true;

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

   g_active_tp1_price = 0.0;
   g_tp1_done = false;
   g_last_signal_time = 0;
   g_cooldown_until = 0;

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
