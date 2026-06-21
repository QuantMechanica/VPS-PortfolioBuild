#property strict
#property version   "5.0"
#property description "QM5_1703 Sperandeo Multiple Top/Bottom H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1703 sperandeo-multiple-top-bottom-h4
// Strategy: Sperandeo Trader Vic II Multiple-Top / Multiple-Bottom (H4)
// Source:   6e967762-b26d-59a3-b076-35c17f2e7c36
// Card:     artifacts/cards_approved/QM5_1703_sperandeo-multiple-top-bottom-h4.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                          = 1703;
input int    qm_magic_slot_offset              = 0;
input uint   qm_rng_seed                       = 42;

input group "Risk"
input double RISK_PERCENT                      = 0.0;
input double RISK_FIXED                        = 1000.0;
input double PORTFOLIO_WEIGHT                  = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled           = true;
input int    qm_friday_close_hour_broker        = 21;

input group "Stress"
input double qm_stress_reject_probability      = 0.0;

input group "Strategy"
input int    strategy_pivot_k                  = 3;    // bars each side for pivot confirm
input int    strategy_lookback_bars            = 50;   // Sperandeo Vic-II ch7: 50-bar window
input int    strategy_min_rejections           = 3;    // min pivot count in zone (>=3)
input int    strategy_atr_period               = 14;   // ATR lookback
input double strategy_zone_atr_mult            = 0.5;  // zone width <= this * ATR
input double strategy_spread_atr_mult          = 0.3;  // spread filter: skip if > X * ATR
input double strategy_break_atr_mult           = 0.5;  // break buffer below/above zone
input double strategy_sl_atr_mult              = 0.5;  // SL buffer beyond zone edge
input double strategy_projection_mult          = 1.5;  // measured-move TP multiplier
input int    strategy_d1_sma_period            = 50;   // D1 trend-filter SMA period
input int    strategy_cooldown_bars            = 12;   // min H4 bars between same-dir entries
input int    strategy_time_stop_bars           = 30;   // max bars to hold position

// ---------------------------------------------------------------------------
// Closed-bar cache: updated ONCE per new H4 bar via AdvanceState_OnNewBar().
// All strategy logic reads from this cache — no per-tick iX calls.
// ---------------------------------------------------------------------------
MqlRates g_rates[];          // PERIOD_H4 CopyRates result, newest-first
bool     g_rates_valid = false;
double   g_atr_h4     = 0.0;

struct QM1703_Zone
  {
   bool   valid;
   int    direction;   // +1 = long (Multiple-Bottom), -1 = short (Multiple-Top)
   double top;
   double bot;
   double width;
   double atr;
   int    rejection_count;
  };

QM1703_Zone g_short_zone;   // refreshed each bar
QM1703_Zone g_long_zone;    // refreshed each bar
bool        g_exit_eval_done   = false;
bool        g_exit_result      = false;

datetime    g_last_long_entry_bar  = 0;
datetime    g_last_short_entry_bar = 0;

// ---------------------------------------------------------------------------
// Pivot helpers — operate on g_rates[], no iX calls.
// ---------------------------------------------------------------------------
bool QM1703_IsPivotHigh(const int shift)
  {
   if(shift - strategy_pivot_k < 0) return false;
   if(shift + strategy_pivot_k >= ArraySize(g_rates)) return false;
   const double h = g_rates[shift].high;
   if(h <= 0.0) return false;
   for(int k = 1; k <= strategy_pivot_k; ++k)
     {
      if(h <= g_rates[shift - k].high) return false;
      if(h <= g_rates[shift + k].high) return false;
     }
   return true;
  }

bool QM1703_IsPivotLow(const int shift)
  {
   if(shift - strategy_pivot_k < 0) return false;
   if(shift + strategy_pivot_k >= ArraySize(g_rates)) return false;
   const double l = g_rates[shift].low;
   if(l <= 0.0) return false;
   for(int k = 1; k <= strategy_pivot_k; ++k)
     {
      if(l >= g_rates[shift - k].low) return false;
      if(l >= g_rates[shift + k].low) return false;
     }
   return true;
  }

// Bars since a given bar open time, using the cached rates array.
int QM1703_BarsSince(const datetime then_bar)
  {
   if(then_bar <= 0 || !g_rates_valid) return 1000000;
   const int n = ArraySize(g_rates);
   for(int i = 0; i < n; ++i)
      if(g_rates[i].time <= then_bar)
         return i;
   return 1000000;
  }

// Scan g_rates for a valid Sperandeo horizontal rejection zone.
// direction: +1 = Multiple-Bottom (pivot lows cluster), -1 = Multiple-Top (pivot highs cluster)
bool QM1703_FindZone(const int direction, QM1703_Zone &zone)
  {
   zone.valid          = false;
   zone.direction      = direction;
   zone.top            = 0.0;
   zone.bot            = 0.0;
   zone.width          = 0.0;
   zone.atr            = g_atr_h4;
   zone.rejection_count = 0;

   if(!g_rates_valid || zone.atr <= 0.0 ||
      strategy_pivot_k < 1 || strategy_min_rejections < 3)
      return false;

   double pivots[128];
   int    found   = 0;
   const int n    = ArraySize(g_rates);
   // scan from shift = pivot_k+1 (ensuring newer k-bars exist) to lookback
   const int max_scan = MathMin(strategy_lookback_bars,
                                n - strategy_pivot_k - 1);
   for(int shift = strategy_pivot_k + 1; shift <= max_scan && found < 128; ++shift)
     {
      const bool is_piv = (direction > 0)
                          ? QM1703_IsPivotLow(shift)
                          : QM1703_IsPivotHigh(shift);
      if(!is_piv) continue;
      pivots[found] = (direction > 0) ? g_rates[shift].low
                                      : g_rates[shift].high;
      found++;
     }

   if(found < strategy_min_rejections) return false;

   // Initial zone = bounding box of the first min_rejections pivots found
   double ztop = pivots[0];
   double zbot = pivots[0];
   for(int i = 1; i < strategy_min_rejections; ++i)
     {
      ztop = MathMax(ztop, pivots[i]);
      zbot = MathMin(zbot, pivots[i]);
     }

   // Count all found pivots inside [zbot, ztop]
   int rejections = 0;
   for(int i = 0; i < found; ++i)
      if(pivots[i] >= zbot && pivots[i] <= ztop)
         rejections++;

   const double width = ztop - zbot;
   if(rejections < strategy_min_rejections || width <= 0.0 ||
      width > strategy_zone_atr_mult * zone.atr)
      return false;

   zone.valid           = true;
   zone.top             = ztop;
   zone.bot             = zbot;
   zone.width           = width;
   zone.rejection_count = rejections;
   return true;
  }

// True if the last closed bar has broken OUT of the zone in the zone's direction.
bool QM1703_HasBreak(const QM1703_Zone &zone)
  {
   if(!zone.valid || zone.atr <= 0.0 || !g_rates_valid ||
      ArraySize(g_rates) < 2)
      return false;
   const double c1 = g_rates[1].close;
   if(c1 <= 0.0) return false;
   if(zone.direction > 0)   // Multiple-Bottom: break UP
      return c1 > zone.top + strategy_break_atr_mult * zone.atr;
   // Multiple-Top: break DOWN
   return c1 < zone.bot - strategy_break_atr_mult * zone.atr;
  }

// D1 trend filter using QM_SMA.  SMA(1,D1,1) = last completed D1 close price.
bool QM1703_TrendAllows(const int direction)
  {
   const double d1_close = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   const double d1_sma   = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   if(d1_close <= 0.0 || d1_sma <= 0.0) return false;
   if(direction > 0) return d1_close > d1_sma;
   return d1_close < d1_sma;
  }

// Update all per-bar cached state.  Called once per new closed H4 bar.
void AdvanceState_OnNewBar()
  {
   const int needed = strategy_lookback_bars + strategy_pivot_k + 3;
   const int copied = CopyRates(_Symbol, PERIOD_H4, 0, needed, g_rates);
   g_rates_valid = (copied >= strategy_min_rejections + strategy_pivot_k * 2 + 1);

   g_atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);

   QM1703_FindZone(-1, g_short_zone);   // Multiple-Top candidates
   QM1703_FindZone(+1, g_long_zone);    // Multiple-Bottom candidates

   // Reset per-bar exit cache
   g_exit_eval_done = false;
   g_exit_result    = false;
  }

// Select our single open position for this EA magic + symbol.
bool QM1703_SelectPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket    = 0;
   ptype     = POSITION_TYPE_BUY;
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ticket    = t;
      ptype     = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   if(g_atr_h4 <= 0.0) return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return true;
   // Block only on a genuinely wide spread; 0 spread (.DWX tester) is tradeable.
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * g_atr_h4) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type              = QM_BUY;
   req.price             = 0.0;
   req.sl                = 0.0;
   req.tp                = 0.0;
   req.reason            = "";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_rates_valid || g_atr_h4 <= 0.0) return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0) return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return false;

   const datetime bar1_time = g_rates[1].time;

   // Multiple-Bottom break: long entry
   if(g_long_zone.valid && QM1703_HasBreak(g_long_zone) &&
      QM1703_TrendAllows(1) &&
      QM1703_BarsSince(g_last_long_entry_bar) > strategy_cooldown_bars)
     {
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = g_long_zone.bot - strategy_sl_atr_mult * g_long_zone.atr;
      req.tp     = ask + strategy_projection_mult * g_long_zone.width;
      req.reason = "QM5_1703_MULTIPLE_BOTTOM_BREAK";
      if(req.sl > 0.0 && req.tp > ask)
        {
         g_last_long_entry_bar = bar1_time;
         return true;
        }
      return false;
     }

   // Multiple-Top break: short entry
   if(g_short_zone.valid && QM1703_HasBreak(g_short_zone) &&
      QM1703_TrendAllows(-1) &&
      QM1703_BarsSince(g_last_short_entry_bar) > strategy_cooldown_bars)
     {
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = g_short_zone.top + strategy_sl_atr_mult * g_short_zone.atr;
      req.tp     = bid - strategy_projection_mult * g_short_zone.width;
      req.reason = "QM5_1703_MULTIPLE_TOP_BREAK";
      if(req.sl > bid && req.tp > 0.0 && req.tp < bid)
        {
         g_last_short_entry_bar = bar1_time;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing stop or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(g_exit_eval_done) return g_exit_result;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!QM1703_SelectPosition(ticket, ptype, open_time))
     {
      g_exit_eval_done = true;
      g_exit_result    = false;
      return false;
     }

   // Time stop: close after strategy_time_stop_bars H4 bars
   const int bars_held = QM1703_BarsSince(open_time);
   if(bars_held >= strategy_time_stop_bars)
     {
      g_exit_eval_done = true;
      g_exit_result    = true;
      return true;
     }

   // Reverse-signal exit: opposite zone break fires
   const int opposite = (ptype == POSITION_TYPE_BUY) ? -1 : 1;
   if(opposite == -1 && g_short_zone.valid && QM1703_HasBreak(g_short_zone))
     {
      g_exit_eval_done = true;
      g_exit_result    = true;
      return true;
     }
   if(opposite == 1 && g_long_zone.valid && QM1703_HasBreak(g_long_zone))
     {
      g_exit_eval_done = true;
      g_exit_result    = true;
      return true;
     }

   g_exit_eval_done = true;
   g_exit_result    = false;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;  // defer to framework two-axis check in OnTick
  }

// =============================================================================
// Framework wiring
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
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar()) return;

   AdvanceState_OnNewBar();
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
