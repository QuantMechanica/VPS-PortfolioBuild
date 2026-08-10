#property strict
#property version   "5.0"
#property description "QM5_20073 Pip Hunter Heiken-Ashi H1 — HA color-streak + EMA(200) bias + RSI(14) 50-cross trigger"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20073 pip-hunter-heiken-ashi-r1-recovery
//
// Single-TF (H1) trend-follower. Entry requires a >=2-bar Heiken-Ashi color
// streak with a flat trend-bar wick (HA_Open == HA_Low for long, HA_Open ==
// HA_High for short), an EMA(200) directional bias, and an RSI(14) crossing of
// the 50 midline in the trade direction. Exit on HA color flip, RSI re-cross of
// 50 against the trade, or the order-attached RR=2.0 take-profit; stop is
// ATR(14)x2.0. One position per symbol per magic. Heiken-Ashi is a bespoke
// recursive OHLC transform (no MT5 built-in / no QM_* reader), so it is
// computed inline once per new H1 bar and cached (raw iOHLC reads tagged
// `// perf-allowed` per the Framework Corset exception for structural logic).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20073;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_ema_period          = 200;   // EMA period for directional bias (H1)
input int    strategy_rsi_period          = 14;    // RSI period for 50-cross trigger (H1)
input double strategy_rsi_midline         = 50.0;  // RSI cross level
input int    strategy_atr_period          = 14;    // ATR period for stop distance (H1)
input double strategy_atr_sl_mult         = 2.0;   // SL = entry -/+ ATR x this
input double strategy_rr_target           = 2.0;   // TP = RR multiple of stop distance
input int    strategy_min_streak_bars     = 2;     // required same-color HA streak length
input int    strategy_ha_lookback_bars    = 40;    // bars used to seed the recursive HA chain
input int    strategy_max_spread_points   = 25;    // skip entry if spread exceeds this

// -----------------------------------------------------------------------------
// Cached Heiken-Ashi state (recomputed once per new H1 bar)
// -----------------------------------------------------------------------------
struct QM20073_HAState
  {
   bool     valid;
   datetime bar_time;     // iTime(_Symbol, PERIOD_H1, 0) at last compute
   bool     is_green1;    // HA color of the last closed bar [1]
   int      streak_len;   // consecutive same-color HA run ending at [1]
   double   ha_open1;
   double   ha_high1;
   double   ha_low1;
   double   ha_close1;
   double   raw_close1;   // raw Close[1] (used for EMA bias compare)
  };
QM20073_HAState g_ha20073;

// Recompute the Heiken-Ashi chain from a fresh price-history window and cache the
// values the strategy needs. Self-guarded: no-ops if already computed for the
// current forming bar, so it is safe (and cheap) to call every tick from both
// the exit and entry hooks. This is the framework's "advance cached state on new
// bar" discipline done with an independent bar-time guard (NOT QM_IsNewBar(),
// which would collide with the framework's own H1 new-bar tracker key).
void QM20073_AdvanceHAState()
  {
   const datetime t0 = iTime(_Symbol, PERIOD_H1, 0);   // perf-allowed
   if(t0 <= 0)
      return;
   if(g_ha20073.valid && g_ha20073.bar_time == t0)
      return; // already fresh for this bar

   int lookback = strategy_ha_lookback_bars;
   if(lookback < 10)
      lookback = 10;

   double raw_o[]; double raw_h[]; double raw_l[]; double raw_c[];
   ArrayResize(raw_o, lookback);
   ArrayResize(raw_h, lookback);
   ArrayResize(raw_l, lookback);
   ArrayResize(raw_c, lookback);

   for(int s = 0; s < lookback; ++s)
     {
      raw_o[s] = iOpen(_Symbol, PERIOD_H1, s);   // perf-allowed
      raw_h[s] = iHigh(_Symbol, PERIOD_H1, s);   // perf-allowed
      raw_l[s] = iLow(_Symbol, PERIOD_H1, s);    // perf-allowed
      raw_c[s] = iClose(_Symbol, PERIOD_H1, s);  // perf-allowed
      if(raw_o[s] <= 0.0 || raw_h[s] <= 0.0 || raw_l[s] <= 0.0 || raw_c[s] <= 0.0)
        {
         // Not enough history yet — mark invalid but remember the bar so we do
         // not thrash recomputes every tick.
         g_ha20073.valid    = false;
         g_ha20073.bar_time = t0;
         return;
        }
     }

   double ha_o[]; double ha_h[]; double ha_l[]; double ha_c[];
   ArrayResize(ha_o, lookback);
   ArrayResize(ha_h, lookback);
   ArrayResize(ha_l, lookback);
   ArrayResize(ha_c, lookback);

   // Forward-compute from the oldest bar (highest shift) to the newest.
   for(int s = lookback - 1; s >= 0; --s)
     {
      ha_c[s] = (raw_o[s] + raw_h[s] + raw_l[s] + raw_c[s]) / 4.0;
      if(s == lookback - 1)
         ha_o[s] = (raw_o[s] + raw_c[s]) / 2.0;      // seed oldest bar with raw midpoint
      else
         ha_o[s] = (ha_o[s + 1] + ha_c[s + 1]) / 2.0; // recursion off the older HA bar
      ha_h[s] = MathMax(raw_h[s], MathMax(ha_o[s], ha_c[s]));
      ha_l[s] = MathMin(raw_l[s], MathMin(ha_o[s], ha_c[s]));
     }

   const bool green1 = (ha_c[1] > ha_o[1]);
   int streak = 1;
   for(int s = 2; s < lookback; ++s)
     {
      const bool green_s = (ha_c[s] > ha_o[s]);
      if(green_s == green1)
         streak++;
      else
         break;
     }

   g_ha20073.valid      = true;
   g_ha20073.bar_time   = t0;
   g_ha20073.is_green1  = green1;
   g_ha20073.streak_len = streak;
   g_ha20073.ha_open1   = ha_o[1];
   g_ha20073.ha_high1   = ha_h[1];
   g_ha20073.ha_low1    = ha_l[1];
   g_ha20073.ha_close1  = ha_c[1];
   g_ha20073.raw_close1 = raw_c[1];
  }

// -----------------------------------------------------------------------------
// Position helpers (one position per symbol per magic)
// -----------------------------------------------------------------------------
bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = candidate;
      return true;
     }
   return false;
  }

bool Strategy_HasOurPosition()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   return Strategy_SelectOurPosition(position_type, ticket);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

// Caller (OnTick) guarantees QM_IsNewBar() == true before this runs.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_period < 1 || strategy_rsi_period < 2 ||
      strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0 ||
      strategy_rr_target <= 0.0 || strategy_min_streak_bars < 1)
      return false;

   // One position per magic — never stack. Opposite momentum is handled by the
   // HA-flip exit (which closes first); the >=2-bar streak requirement means a
   // fresh opposite entry cannot qualify on the same bar the position closes.
   if(Strategy_HasOurPosition())
      return false;

   QM20073_AdvanceHAState();
   if(!g_ha20073.valid)
      return false;

   if(g_ha20073.streak_len < strategy_min_streak_bars)
      return false;

   double eps = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(eps <= 0.0)
      eps = 1e-8;

   const double ema1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   if(ema1 <= 0.0)
      return false;
   const double rsi1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double rsi2 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 2);

   const bool long_wick_ok  = (MathAbs(g_ha20073.ha_open1 - g_ha20073.ha_low1)  <= eps);
   const bool short_wick_ok = (MathAbs(g_ha20073.ha_open1 - g_ha20073.ha_high1) <= eps);
   const bool rsi_cross_up   = (rsi1 > strategy_rsi_midline && rsi2 <= strategy_rsi_midline);
   const bool rsi_cross_down = (rsi1 < strategy_rsi_midline && rsi2 >= strategy_rsi_midline);

   QM_OrderType side = QM_BUY;
   string reason = "";

   if(g_ha20073.is_green1 && long_wick_ok && g_ha20073.raw_close1 > ema1 && rsi_cross_up)
     {
      side = QM_BUY;
      reason = "HA_GREEN_STREAK_EMA_UP_RSI50X_UP";
     }
   else if(!g_ha20073.is_green1 && short_wick_ok && g_ha20073.raw_close1 < ema1 && rsi_cross_down)
     {
      side = QM_SELL;
      reason = "HA_RED_STREAK_EMA_DN_RSI50X_DN";
     }
   else
      return false;

   const double entry_price = (side == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry_price, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;

   req.type               = side;
   req.price              = 0.0;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = reason;
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline: no trailing stop, no break-even, no partial close, no
   // scale-in. Stop-loss (ATRx2.0) and take-profit (RR=2.0) are order-attached
   // at entry and enforced by the broker/framework.
  }

// Framework closes our positions with QM_EXIT_STRATEGY when this returns TRUE.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(position_type, ticket))
      return false;

   QM20073_AdvanceHAState();
   if(!g_ha20073.valid)
      return false;

   // Primary exit: HA color flip against the open position (closed bar [1]).
   if(position_type == POSITION_TYPE_BUY && !g_ha20073.is_green1)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_ha20073.is_green1)
      return true;

   // Secondary exit: RSI re-crosses the midline against the trade direction.
   if(strategy_rsi_period >= 2)
     {
      const double rsi1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
      const double rsi2 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 2);
      if(position_type == POSITION_TYPE_BUY &&
         rsi1 < strategy_rsi_midline && rsi2 >= strategy_rsi_midline)
         return true;
      if(position_type == POSITION_TYPE_SELL &&
         rsi1 > strategy_rsi_midline && rsi2 <= strategy_rsi_midline)
         return true;
     }

   // Tertiary exit (RR=2.0 take-profit) is order-attached — no action here.
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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20073\",\"strategy\":\"pip-hunter-heiken-ashi-r1-recovery\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
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
