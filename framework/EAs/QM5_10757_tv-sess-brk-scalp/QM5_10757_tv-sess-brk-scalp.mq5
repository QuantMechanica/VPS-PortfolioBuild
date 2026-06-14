#property strict
#property version   "5.0"
#property description "QM5_10757 TradingView Session Breakout Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10757;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_session_hour_broker    = 8;
input int    strategy_session_minute_broker  = 0;
input int    strategy_box_bars_each_side     = 3;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input double strategy_tp_rr                  = 1.5;
input int    strategy_regime_filter_mode     = 2;    // 0=off, 1=LWTI, 2=LWTI+Andean
input int    strategy_lwti_period            = 25;
input int    strategy_andean_length          = 50;
input int    strategy_max_spread_points      = 80;
input int    strategy_fx_min_sl_pips         = 5;
input int    strategy_fx_max_sl_pips         = 35;
input int    strategy_xau_min_sl_pips        = 50;
input int    strategy_xau_max_sl_pips        = 300;
input int    strategy_index_min_sl_pips      = 20;
input int    strategy_index_max_sl_pips      = 300;

bool g_strategy_regime_buy_ok = true;
bool g_strategy_regime_sell_ok = true;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return 10.0 * point;
   return point;
  }

bool Strategy_IsXauSymbol()
  {
   return (StringFind(_Symbol, "XAU") >= 0);
  }

bool Strategy_IsIndexSymbol()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 ||
           StringFind(_Symbol, "GER") >= 0 ||
           StringFind(_Symbol, "DE30") >= 0 ||
           StringFind(_Symbol, "UK100") >= 0 ||
           StringFind(_Symbol, "NDX") >= 0 ||
           StringFind(_Symbol, "WS30") >= 0 ||
           StringFind(_Symbol, "SP500") >= 0);
  }

double Strategy_BoundedStopDistance(const double atr_value)
  {
   const double pip = Strategy_PipSize();
   if(pip <= 0.0 || atr_value <= 0.0)
      return 0.0;

   int min_pips = strategy_fx_min_sl_pips;
   int max_pips = strategy_fx_max_sl_pips;
   if(Strategy_IsXauSymbol())
     {
      min_pips = strategy_xau_min_sl_pips;
      max_pips = strategy_xau_max_sl_pips;
     }
   else if(Strategy_IsIndexSymbol())
     {
      min_pips = strategy_index_min_sl_pips;
      max_pips = strategy_index_max_sl_pips;
     }

   double dist = atr_value * strategy_atr_sl_mult;
   dist = MathMax(dist, (double)min_pips * pip);
   dist = MathMin(dist, (double)max_pips * pip);
   return dist;
  }

bool Strategy_IsPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_CurrentPositionIsBuy(bool &is_buy)
  {
   is_buy = true;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      return true;
     }
   return false;
  }

bool Strategy_HasPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

datetime Strategy_TodaySessionStart(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   dt.hour = strategy_session_hour_broker;
   dt.min = strategy_session_minute_broker;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_IsSessionStartWindow(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int period_minutes = MathMax(1, PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60);
   return (dt.hour == strategy_session_hour_broker &&
           dt.min >= strategy_session_minute_broker &&
           dt.min < strategy_session_minute_broker + period_minutes);
  }

bool Strategy_HasSessionHistory(const datetime session_start)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || session_start <= 0)
      return false;
   if(!HistorySelect(session_start, TimeCurrent()))
      return false;

   for(int i = HistoryOrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
      if(Strategy_IsPendingStopType(type) || type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
         return true;
     }

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic)
         return true;
     }
   return false;
  }

double Strategy_LWTIValue(const int shift)
  {
   if(strategy_lwti_period <= 1)
      return 50.0;

   double diff_sum = 0.0;
   // perf-allowed: LWTI is bespoke card logic and runs only from the closed-bar entry hook.
   for(int i = shift; i < shift + strategy_lwti_period; ++i)
     {
      const double c_now = iClose(_Symbol, _Period, i);
      const double c_lag = iClose(_Symbol, _Period, i + strategy_lwti_period);
      if(c_now <= 0.0 || c_lag <= 0.0)
         return 50.0;
      diff_sum += (c_now - c_lag);
     }

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_lwti_period, shift);
   if(atr <= 0.0)
      return 50.0;

   const double diff_avg = diff_sum / (double)strategy_lwti_period;
   return diff_avg / atr * 50.0 + 50.0;
  }

bool Strategy_AndeanBullBear(double &bull, double &bear)
  {
   bull = 0.0;
   bear = 0.0;
   if(strategy_andean_length < 2)
      return false;

   const double alpha = 2.0 / ((double)strategy_andean_length + 1.0);
   const int oldest_shift = strategy_andean_length + 1;
   double c = iClose(_Symbol, _Period, oldest_shift);
   if(c <= 0.0)
      return false;

   double up1 = c;
   double up2 = c * c;
   double dn1 = c;
   double dn2 = c * c;

   // perf-allowed: Andean oscillator recursion is bounded and evaluated once per closed bar.
   for(int i = oldest_shift - 1; i >= 1; --i)
     {
      c = iClose(_Symbol, _Period, i);
      if(c <= 0.0)
         return false;
      const double c2 = c * c;
      up1 = MathMax(c, up1 - (up1 - c) * alpha);
      up2 = MathMax(c2, up2 - (up2 - c2) * alpha);
      dn1 = MathMin(c, dn1 + (c - dn1) * alpha);
      dn2 = MathMin(c2, dn2 + (c2 - dn2) * alpha);
     }

   bull = MathSqrt(MathMax(dn2 - dn1 * dn1, 0.0));
   bear = MathSqrt(MathMax(up2 - up1 * up1, 0.0));
   return true;
  }

bool Strategy_RegimeAllows(const bool is_buy)
  {
   if(strategy_regime_filter_mode <= 0)
      return true;

   const double lwti = Strategy_LWTIValue(1);
   if(is_buy && lwti <= 50.0)
      return false;
   if(!is_buy && lwti >= 50.0)
      return false;

   if(strategy_regime_filter_mode < 2)
      return true;

   double bull = 0.0;
   double bear = 0.0;
   if(!Strategy_AndeanBullBear(bull, bear))
      return false;
   return is_buy ? (bull > bear) : (bull < bear);
  }

void Strategy_UpdateRegimeCache()
  {
   g_strategy_regime_buy_ok = Strategy_RegimeAllows(true);
   g_strategy_regime_sell_ok = Strategy_RegimeAllows(false);
  }

bool Strategy_BuildStopRequest(const QM_OrderType type,
                               const double price,
                               const double stop_distance,
                               const string reason,
                               QM_EntryRequest &req)
  {
   req.type = type;
   req.price = NormalizeDouble(price, _Digits);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = reason;

   if(req.price <= 0.0 || stop_distance <= 0.0 || strategy_tp_rr <= 0.0)
      return false;

   if(type == QM_BUY_STOP)
     {
      req.sl = NormalizeDouble(req.price - stop_distance, _Digits);
      req.tp = NormalizeDouble(req.price + stop_distance * strategy_tp_rr, _Digits);
      return (req.sl > 0.0 && req.tp > req.price);
     }

   req.sl = NormalizeDouble(req.price + stop_distance, _Digits);
   req.tp = NormalizeDouble(req.price - stop_distance * strategy_tp_rr, _Digits);
   return (req.tp > 0.0 && req.sl > req.price);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): central news runs before this hook;
   // session timing is enforced in Trade Entry/Trade Close so open trades can still be managed.
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: session range breakout stop straddle.
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_UpdateRegimeCache();

   const datetime broker_now = TimeCurrent();
   const datetime session_start = Strategy_TodaySessionStart(broker_now);
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0 || broker_now < session_start)
      return false;

   const int elapsed_bars = (int)((broker_now - session_start) / period_seconds);
   if(elapsed_bars != strategy_box_bars_each_side)
      return false;

   if(Strategy_HasOpenPosition() || Strategy_HasPendingStops() || Strategy_HasSessionHistory(session_start))
      return false;

   const int lookback = strategy_box_bars_each_side * 2 + 1;
   if(lookback < 3)
      return false;

   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   // perf-allowed: closed-bar session box construction is the card's structural breakout logic.
   for(int i = 1; i <= lookback; ++i)
     {
      const double h = iHigh(_Symbol, _Period, i);
      const double l = iLow(_Symbol, _Period, i);
      if(h <= 0.0 || l <= 0.0)
         return false;
      box_high = MathMax(box_high, h);
      box_low = MathMin(box_low, l);
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double stop_distance = Strategy_BoundedStopDistance(atr);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || box_high <= box_low || stop_distance <= 0.0)
      return false;

   const bool buy_allowed = g_strategy_regime_buy_ok;
   const bool sell_allowed = g_strategy_regime_sell_ok;
   if(!buy_allowed && !sell_allowed)
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   const bool buy_ok = buy_allowed &&
                       box_high > ask + point &&
                       Strategy_BuildStopRequest(QM_BUY_STOP, box_high, stop_distance,
                                                 "TV_SESS_BRK_BUY_STOP", buy_req);
   const bool sell_ok = sell_allowed &&
                        box_low < bid - point &&
                        Strategy_BuildStopRequest(QM_SELL_STOP, box_low, stop_distance,
                                                  "TV_SESS_BRK_SELL_STOP", sell_req);

   if(buy_ok && sell_ok)
     {
      ulong buy_ticket = 0;
      if(!QM_TM_OpenPosition(buy_req, buy_ticket))
         return false;
      req = sell_req;
      return true;
     }

   if(buy_ok)
     {
      req = buy_req;
      return true;
     }

   if(sell_ok)
     {
      req = sell_req;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: OCO peer cancellation; no trailing, BE, or partial logic in card.
   if(Strategy_HasOpenPosition())
     {
      Strategy_CancelPendingStops("oco_peer_cancel");
      return;
     }

   if(Strategy_IsSessionStartWindow(TimeCurrent()))
      Strategy_CancelPendingStops("new_session_cancel");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: close on the next configured session or when cached regime filter fails.
   bool is_buy = true;
   if(!Strategy_CurrentPositionIsBuy(is_buy))
      return false;

   if(Strategy_IsSessionStartWindow(TimeCurrent()))
      return true;

   if(strategy_regime_filter_mode > 0)
      return is_buy ? !g_strategy_regime_buy_ok : !g_strategy_regime_sell_ok;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no custom override; defer to central P8-compatible framework filter.
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
