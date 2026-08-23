#property strict
#property version   "5.0"
#property description "QM5_12939 Carney Alternate-Bat Pattern (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12939
// Slug: carney-alternate-bat-h4
// Card: artifacts/cards_approved/QM5_12939_carney-alternate-bat-h4.md
// Source: Scott M. Carney — Harmonic Trading Vol II (2010) ch. 3
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12939;
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
input int    strategy_fractal_wing_bars   = 2;      // Swing pivot wing bars
input int    strategy_scan_bars           = 96;     // Swing pivot search depth
input double strategy_ratio_tolerance     = 0.05;   // ±5% harmonic ratio tolerance
input double strategy_ab_xa_ratio         = 0.382;  // Alternate Bat B-pivot constraint (0.382)
input double strategy_bc_ab_min           = 1.130;  // BC extension min
input double strategy_bc_ab_max           = 2.618;  // BC extension max
input double strategy_cd_bc_min           = 2.000;  // CD leg min extension
input double strategy_cd_bc_max           = 3.618;  // CD leg max extension
input double strategy_d_xa_ratio          = 1.130;  // D-pivot extension beyond X (1.13)
input double strategy_rsi_d1_min          = 25.0;   // D1 RSI filter range min
input double strategy_rsi_d1_max          = 75.0;   // D1 RSI filter range max
input int    strategy_atr_period          = 14;     // ATR period for stops and targets
input double strategy_atr_sl_mult         = 1.27;   // Beyond D-pivot by 1.27 * ATR
input double strategy_tp1_ad_retracement  = 0.382;  // T1 partial target: 50% position at 38.2% AD
input double strategy_tp2_ad_retracement  = 0.618;  // T2 final target: remaining 50% at 61.8% AD
input double strategy_atr_trail_mult      = 1.0;    // ATR trail multiplier after T1 hit
input int    strategy_max_hold_bars       = 30;     // Time stop in H4 bars
input int    strategy_cooldown_bars       = 18;     // Cooldown between entries in H4 bars
input double strategy_spread_max_atr_mult = 0.3;    // Maximum spread threshold in ATR

struct StrategyPivot
{
   int      kind;    // +1 = swing high, -1 = swing low
   int      shift;
   double   price;
   datetime time;
};

struct StrategyTradeState
{
   ulong    ticket;
   bool     t1_hit;
   double   t1_price;
   double   t2_price;
};

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per closed H4 bar)
// -----------------------------------------------------------------------------
double             g_atr_1 = 0.0;
bool               g_long_signal = false;
bool               g_short_signal = false;
double             g_long_sl = 0.0;
double             g_long_t1 = 0.0;
double             g_long_t2 = 0.0;
double             g_short_sl = 0.0;
double             g_short_t1 = 0.0;
double             g_short_t2 = 0.0;
bool               g_state_ready = false;
int                g_bars_since_last_long = 100;
int                g_bars_since_last_short = 100;
StrategyTradeState g_trade_state;

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
      const bool low  = Strategy_FractalLow(rates, i, total, wing);
      if(high && !low)
         Strategy_AddPivot(pivots, count, +1, i, rates[i].high, rates[i].time);
      else if(low && !high)
         Strategy_AddPivot(pivots, count, -1, i, rates[i].low, rates[i].time);
   }

   return count;
}

bool Strategy_RatioMatch(const double val, const double target, const double tol)
{
   return (val >= target * (1.0 - tol) && val <= target * (1.0 + tol));
}

bool Strategy_RangeMatch(const double val, const double lo, const double hi, const double tol)
{
   return (val >= lo * (1.0 - tol) && val <= hi * (1.0 + tol));
}

void AdvanceState_OnNewBar()
{
   g_long_signal = false;
   g_short_signal = false;
   g_bars_since_last_long++;
   g_bars_since_last_short++;

   if(iBars(_Symbol, _Period) < strategy_scan_bars + 20 || iBars(_Symbol, PERIOD_D1) < 30) // perf-allowed
   {
      g_state_ready = false;
      return;
   }

   g_atr_1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(g_atr_1 <= 0.0)
   {
      g_state_ready = false;
      return;
   }
   g_state_ready = true;

   const double d1_rsi = QM_RSI(_Symbol, PERIOD_D1, 14, 1);
   if(d1_rsi < strategy_rsi_d1_min || d1_rsi > strategy_rsi_d1_max)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, strategy_scan_bars, rates); // perf-allowed
   if(copied < 30)
      return;

   StrategyPivot pivots[128];
   const int pivot_count = Strategy_CollectPivots(rates, copied, pivots);
   if(pivot_count < 5)
      return;

   // Check most recent 5 alternating pivots X, A, B, C, D (where D is newest = pivots[pivot_count-1])
   const StrategyPivot d_piv = pivots[pivot_count - 1];
   const StrategyPivot c_piv = pivots[pivot_count - 2];
   const StrategyPivot b_piv = pivots[pivot_count - 3];
   const StrategyPivot a_piv = pivots[pivot_count - 4];
   const StrategyPivot x_piv = pivots[pivot_count - 5];

   const double tol = strategy_ratio_tolerance;

   // 1. Bullish Alternate Bat (X low, A high, B low, C high, D low)
   if(x_piv.kind == -1 && a_piv.kind == +1 && b_piv.kind == -1 && c_piv.kind == +1 && d_piv.kind == -1)
   {
      const double xa = a_piv.price - x_piv.price;
      const double ab = a_piv.price - b_piv.price;
      const double bc = c_piv.price - b_piv.price;
      const double cd = c_piv.price - d_piv.price;
      const double d_ext = a_piv.price - d_piv.price;

      if(xa > 0.0 && ab > 0.0 && bc > 0.0 && cd > 0.0)
      {
         const double ab_xa = ab / xa;
         const double bc_ab = bc / ab;
         const double cd_bc = cd / bc;
         const double d_xa  = d_ext / xa;

         const bool ab_ok = Strategy_RatioMatch(ab_xa, strategy_ab_xa_ratio, tol);
         const bool bc_ok = Strategy_RangeMatch(bc_ab, strategy_bc_ab_min, strategy_bc_ab_max, tol);
         const bool cd_ok = Strategy_RangeMatch(cd_bc, strategy_cd_bc_min, strategy_cd_bc_max, tol);
         const bool d_ok  = Strategy_RatioMatch(d_xa, strategy_d_xa_ratio, tol);

         // D must be below X for alternate bat extension
         const bool d_below_x = (d_piv.price < x_piv.price);

         // Confirmation candle: closed bar (shift 1) closes above D-pivot bar high
         const double d_bar_high = rates[d_piv.shift].high;
         const double close_1    = iClose(_Symbol, _Period, 1); // perf-allowed
         const bool confirm      = (close_1 > d_bar_high);

         if(ab_ok && bc_ok && cd_ok && d_ok && d_below_x && confirm && g_bars_since_last_long >= strategy_cooldown_bars)
         {
            g_long_signal = true;
            g_long_sl = d_piv.price - strategy_atr_sl_mult * g_atr_1;
            const double ad = a_piv.price - d_piv.price;
            g_long_t1 = d_piv.price + strategy_tp1_ad_retracement * ad;
            g_long_t2 = d_piv.price + strategy_tp2_ad_retracement * ad;
         }
      }
   }

   // 2. Bearish Alternate Bat (X high, A low, B high, C low, D high)
   if(x_piv.kind == +1 && a_piv.kind == -1 && b_piv.kind == +1 && c_piv.kind == -1 && d_piv.kind == +1)
   {
      const double xa = x_piv.price - a_piv.price;
      const double ab = b_piv.price - a_piv.price;
      const double bc = b_piv.price - c_piv.price;
      const double cd = d_piv.price - c_piv.price;
      const double d_ext = d_piv.price - a_piv.price;

      if(xa > 0.0 && ab > 0.0 && bc > 0.0 && cd > 0.0)
      {
         const double ab_xa = ab / xa;
         const double bc_ab = bc / ab;
         const double cd_bc = cd / bc;
         const double d_xa  = d_ext / xa;

         const bool ab_ok = Strategy_RatioMatch(ab_xa, strategy_ab_xa_ratio, tol);
         const bool bc_ok = Strategy_RangeMatch(bc_ab, strategy_bc_ab_min, strategy_bc_ab_max, tol);
         const bool cd_ok = Strategy_RangeMatch(cd_bc, strategy_cd_bc_min, strategy_cd_bc_max, tol);
         const bool d_ok  = Strategy_RatioMatch(d_xa, strategy_d_xa_ratio, tol);

         // D must be above X for alternate bat extension
         const bool d_above_x = (d_piv.price > x_piv.price);

         // Confirmation candle: closed bar (shift 1) closes below D-pivot bar low
         const double d_bar_low = rates[d_piv.shift].low;
         const double close_1   = iClose(_Symbol, _Period, 1); // perf-allowed
         const bool confirm     = (close_1 < d_bar_low);

         if(ab_ok && bc_ok && cd_ok && d_ok && d_above_x && confirm && g_bars_since_last_short >= strategy_cooldown_bars)
         {
            g_short_signal = true;
            g_short_sl = d_piv.price + strategy_atr_sl_mult * g_atr_1;
            const double ad = d_piv.price - a_piv.price;
            g_short_t1 = d_piv.price - strategy_tp1_ad_retracement * ad;
            g_short_t2 = d_piv.price - strategy_tp2_ad_retracement * ad;
         }
      }
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!g_state_ready) return true;
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(g_atr_1 > 0.0 && spread > strategy_spread_max_atr_mult * g_atr_1)
      return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready) return false;

   if(g_long_signal)
   {
      req.type = QM_BUY;
      req.reason = "QM5_12939_ALT_BAT_BUY";
      req.price = 0.0;
      req.sl = NormalizeDouble(g_long_sl, _Digits);
      req.tp = NormalizeDouble(g_long_t2, _Digits);

      g_bars_since_last_long = 0;
      return true;
   }

   if(g_short_signal)
   {
      req.type = QM_SELL;
      req.reason = "QM5_12939_ALT_BAT_SELL";
      req.price = 0.0;
      req.sl = NormalizeDouble(g_short_sl, _Digits);
      req.tp = NormalizeDouble(g_short_t2, _Digits);

      g_bars_since_last_short = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(g_trade_state.ticket != ticket)
      {
         g_trade_state.ticket = ticket;
         g_trade_state.t1_hit = false;
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY)
         {
            g_trade_state.t1_price = g_long_t1;
            g_trade_state.t2_price = g_long_t2;
         }
         else
         {
            g_trade_state.t1_price = g_short_t1;
            g_trade_state.t2_price = g_short_t2;
         }
      }

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_open = iBarShift(_Symbol, _Period, open_time); // perf-allowed

      // Time stop exit: 30 H4 bars
      if(bars_open >= strategy_max_hold_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_vol = PositionGetDouble(POSITION_VOLUME);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         // T1 partial close: 50% at 38.2% AD retracement
         if(!g_trade_state.t1_hit && g_trade_state.t1_price > 0.0 && bid >= g_trade_state.t1_price)
         {
            const double half_vol = QM_TM_NormalizeVolume(_Symbol, current_vol * 0.5);
            if(half_vol > 0.0 && half_vol < current_vol)
            {
               QM_TM_PartialClose(ticket, half_vol, QM_EXIT_STRATEGY);
            }
            g_trade_state.t1_hit = true;
         }

         // Post-T1 ATR trail: trail SL at ATR(14) * 1.0 below bar 1 low
         if(g_trade_state.t1_hit)
         {
            const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
            if(atr > 0.0)
            {
               const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed
               const double trail_sl = QM_TM_NormalizePrice(_Symbol, bar_low - atr * strategy_atr_trail_mult);
               const double current_sl = PositionGetDouble(POSITION_SL);
               const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               if(trail_sl > current_sl + point * 0.5 && trail_sl < bid)
               {
                  QM_TM_MoveSL(ticket, trail_sl, "alt_bat_post_t1_atr_trail");
               }
            }
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         // T1 partial close: 50% at 38.2% AD retracement
         if(!g_trade_state.t1_hit && g_trade_state.t1_price > 0.0 && ask <= g_trade_state.t1_price)
         {
            const double half_vol = QM_TM_NormalizeVolume(_Symbol, current_vol * 0.5);
            if(half_vol > 0.0 && half_vol < current_vol)
            {
               QM_TM_PartialClose(ticket, half_vol, QM_EXIT_STRATEGY);
            }
            g_trade_state.t1_hit = true;
         }

         // Post-T1 ATR trail: trail SL at ATR(14) * 1.0 above bar 1 high
         if(g_trade_state.t1_hit)
         {
            const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
            if(atr > 0.0)
            {
               const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed
               const double trail_sl = QM_TM_NormalizePrice(_Symbol, bar_high + atr * strategy_atr_trail_mult);
               const double current_sl = PositionGetDouble(POSITION_SL);
               const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               if((current_sl <= 0.0 || trail_sl < current_sl - point * 0.5) && trail_sl > ask)
               {
                  QM_TM_MoveSL(ticket, trail_sl, "alt_bat_post_t1_atr_trail");
               }
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_short_signal)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_long_signal)
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   ZeroMemory(g_trade_state);
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12939_carney-alternate-bat-h4\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;

   const bool is_new_bar = QM_IsNewBar(_Symbol, _Period);
   if(is_new_bar)
   {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
   }

   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if((ptype == POSITION_TYPE_BUY && g_short_signal) || (ptype == POSITION_TYPE_SELL && g_long_signal))
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         }
      }
   }

   if(!is_new_bar) return;

   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) == 0)
   {
      QM_EntryRequest req;
      ZeroMemory(req);
      if(Strategy_EntrySignal(req))
      {
         ulong ticket = 0;
         QM_TM_OpenPosition(req, ticket);
      }
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
