#property strict
#property version   "5.0"
#property description "QM5_9953 FF SuperTrend Pullback 100 Pip H4"

// Strategy: SuperTrend(10,3) middle-line first-pullback on H4; 100-pip fixed SL/TP.
// Source: jamesagnew, ForexFactory 2026 (6e967762-b26d-59a3-b076-35c17f2e7c36)

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// Input declarations
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9953;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 10;   // SuperTrend ATR period (card: 10)
input double strategy_st_multiplier       = 3.0;  // SuperTrend multiplier (card: 3.0)
input int    strategy_min_trend_bars      = 3;    // min consecutive bars before pullback scan (card: 3)
input int    strategy_sl_tp_pips          = 100;  // fixed SL and TP in pips (card: 100)
input int    strategy_pending_cancel_bars = 2;    // cancel limit after N new bars (card: 2)

// =============================================================================
// Module-level state
// =============================================================================

CTrade g_trade;

// SuperTrend state cached per closed bar
bool   g_st_init   = false;
double g_st_upper  = 0.0;
double g_st_lower  = 0.0;
double g_st_middle = 0.0;
int    g_st_dir    = 0;     // +1 bullish, -1 bearish, 0 unknown

// Trend bar counting and first-pullback gating
int    g_dir_bar_count     = 0;
bool   g_pullback_consumed = false;

// Entry signal set by AdvanceState, read by Strategy_EntrySignal
bool   g_signal_long  = false;
bool   g_signal_short = false;
double g_signal_price = 0.0;
double g_signal_sl    = 0.0;
double g_signal_tp    = 0.0;

// Pending order 2-bar expiry counter (0 = no pending tracked)
int    g_pending_bars = 0;

// =============================================================================
// Helpers
// =============================================================================

double PipsToPrice(const int pips)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip_size = (digits == 3 || digits == 5) ? 10.0 * _Point : _Point;
   return pips * pip_size;
  }

bool HasOurPendingOrder()
  {
   const long magic = (long)QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

bool HasOurPosition()
  {
   const long magic = (long)QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
     }
   return false;
  }

void CancelOurPendingOrders(const string reason)
  {
   const long magic = (long)QM_FrameworkMagic();
   if(magic <= 0) return;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
      if(!g_trade.OrderDelete(t))
         QM_LogEvent(QM_WARN, "PENDING_CANCEL_FAIL", StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\"}", t, reason));
     }
   g_pending_bars = 0;
  }

// =============================================================================
// SuperTrend per-bar state advancement
// Called once per new bar via MaybeAdvanceState().
// Uses iHigh/iLow/iClose with perf-allowed for bespoke SuperTrend math.
// =============================================================================

void AdvanceState_OnNewBar()
  {
   const double high1  = iHigh(_Symbol, _Period, 1);    // perf-allowed: bespoke SuperTrend
   const double low1   = iLow(_Symbol, _Period, 1);     // perf-allowed: bespoke SuperTrend
   const double close1 = iClose(_Symbol, _Period, 1);   // perf-allowed: bespoke SuperTrend
   const double close2 = iClose(_Symbol, _Period, 2);   // perf-allowed: bespoke SuperTrend

   const double atr1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return;

   // Bootstrap: seed initial upper/lower from bar 2 on first call
   if(!g_st_init)
     {
      const double h2   = iHigh(_Symbol, _Period, 2);   // perf-allowed: bespoke SuperTrend init
      const double l2   = iLow(_Symbol, _Period, 2);    // perf-allowed: bespoke SuperTrend init
      const double atr2 = QM_ATR(_Symbol, _Period, strategy_atr_period, 2);
      const double hl2  = (h2 + l2) / 2.0;
      g_st_upper = hl2 + strategy_st_multiplier * atr2;
      g_st_lower = hl2 - strategy_st_multiplier * atr2;
      g_st_init  = true;
     }

   // Compute basic bands from bar 1
   const double hl2_1        = (high1 + low1) / 2.0;
   const double basic_upper  = hl2_1 + strategy_st_multiplier * atr1;
   const double basic_lower  = hl2_1 - strategy_st_multiplier * atr1;

   // Persistent band update (standard SuperTrend rule)
   const double prev_upper = g_st_upper;
   const double prev_lower = g_st_lower;

   g_st_upper  = (basic_upper < prev_upper || close2 > prev_upper) ? basic_upper : prev_upper;
   g_st_lower  = (basic_lower > prev_lower || close2 < prev_lower) ? basic_lower : prev_lower;
   g_st_middle = (g_st_upper + g_st_lower) / 2.0;

   // Determine trend direction from bar 1 close vs bands
   const int prev_dir = g_st_dir;
   if(close1 > g_st_upper)
      g_st_dir = 1;   // bullish: price above upper band
   else if(close1 < g_st_lower)
      g_st_dir = -1;  // bearish: price below lower band
   // else: direction unchanged (transitional bar inside bands)

   // Track consecutive bars; reset on flip
   if(g_st_dir != prev_dir && prev_dir != 0)
     {
      g_dir_bar_count    = 1;
      g_pullback_consumed = false;
      g_signal_long      = false;
      g_signal_short     = false;
     }
   else if(g_st_dir == 1 || g_st_dir == -1)
     {
      g_dir_bar_count++;
     }

   // Pending order 2-bar expiry tracking
   if(g_pending_bars > 0)
     {
      if(!HasOurPendingOrder())
        {
         g_pending_bars = 0;  // order filled or externally cancelled
        }
      else
        {
         g_pending_bars++;
         if(g_pending_bars > strategy_pending_cancel_bars)
            CancelOurPendingOrders("2bar_expiry");
        }
     }

   // Clear stale entry signal from previous bar
   g_signal_long  = false;
   g_signal_short = false;

   // First-pullback detection (only once per trend leg)
   if(!g_pullback_consumed && g_dir_bar_count >= strategy_min_trend_bars && g_st_middle > 0.0)
     {
      const double pip_dist = PipsToPrice(strategy_sl_tp_pips);
      if(g_st_dir == 1)
        {
         // Long: H4 low touches/pierces middle line; bar closes back above
         if(low1 <= g_st_middle && close1 > g_st_middle)
           {
            g_signal_long       = true;
            g_signal_price      = g_st_middle;
            g_signal_sl         = g_st_middle - pip_dist;
            g_signal_tp         = g_st_middle + pip_dist;
            g_pullback_consumed = true;
           }
        }
      else if(g_st_dir == -1)
        {
         // Short: H4 high touches/pierces middle line; bar closes back below
         if(high1 >= g_st_middle && close1 < g_st_middle)
           {
            g_signal_short      = true;
            g_signal_price      = g_st_middle;
            g_signal_sl         = g_st_middle + pip_dist;
            g_signal_tp         = g_st_middle - pip_dist;
            g_pullback_consumed = true;
           }
        }
     }
  }

// Place limit order via CTrade (separate from QM_TM_OpenPosition to support pending orders)
bool PlaceLimitEntry(const QM_EntryRequest &req)
  {
   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   const double sl_points = MathAbs(req.price - req.sl) / _Point;
   if(sl_points <= 0.0)
      return false;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   bool ok = false;
   if(req.type == QM_BUY)
      ok = g_trade.BuyLimit(lots, req.price, _Symbol, req.sl, req.tp,
                            ORDER_TIME_GTC, 0, req.reason);
   else
      ok = g_trade.SellLimit(lots, req.price, _Symbol, req.sl, req.tp,
                             ORDER_TIME_GTC, 0, req.reason);
   if(ok)
      g_pending_bars = 1;
   return ok;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No Trade Filter — card has no additional session or spread filter
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry Signal — emit buy/sell limit req if first-pullback signal is active
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type              = QM_BUY;
   req.price             = 0.0;
   req.sl                = 0.0;
   req.tp                = 0.0;
   req.reason            = "";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOurPosition() || HasOurPendingOrder() || g_pending_bars > 0)
      return false;

   if(g_signal_long)
     {
      req.type   = QM_BUY;
      req.price  = g_signal_price;
      req.sl     = g_signal_sl;
      req.tp     = g_signal_tp;
      req.reason = "ST_PULLBACK_LONG";
      return true;
     }
   if(g_signal_short)
     {
      req.type   = QM_SELL;
      req.price  = g_signal_price;
      req.sl     = g_signal_sl;
      req.tp     = g_signal_tp;
      req.reason = "ST_PULLBACK_SHORT";
      return true;
     }
   return false;
  }

// Trade Management — card specifies no trailing or break-even; SL/TP manage exits
void Strategy_ManageOpenPosition()
  {
  }

// Exit Signal — close if H4 closes beyond the opposite SuperTrend boundary
bool Strategy_ExitSignal()
  {
   if(g_st_dir == 0) return false;
   const long magic = (long)QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_st_dir == -1) return true;
      if(ptype == POSITION_TYPE_SELL && g_st_dir ==  1) return true;
     }
   return false;
  }

// News Filter Hook — defer to framework two-axis news filter
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework lifecycle
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

   g_trade.SetDeviationInPoints(10);
   QM_LogEvent(QM_INFO, "INIT_OK", StringFormat("{\"ea\":\"QM5_9953\",\"atr\":%d,\"mult\":%.1f,\"sl_tp_pips\":%d}",
               strategy_atr_period, strategy_st_multiplier, strategy_sl_tp_pips));
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

   if(!QM_IsNewBar()) return;

   // Advance SuperTrend state from last closed bar, then evaluate exit and entry.
   // Exit condition ("H4 closes beyond opposite boundary") is bar-based — checking
   // once per closed bar is correct and avoids per-tick state recompute.
   AdvanceState_OnNewBar();
   QM_EquityStreamOnNewBar();

   if(Strategy_ExitSignal())
     {
      const long magic = (long)QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(HasOurPendingOrder() || HasOurPosition()) return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
      PlaceLimitEntry(req);
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest    &request,
                        const MqlTradeResult     &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
