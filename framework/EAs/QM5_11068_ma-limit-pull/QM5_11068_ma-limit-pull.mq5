#property strict
#property version   "5.0"
#property description "QM5_11068 ma-limit-pull — M5 EMA-trend dynamic limit-order pullback (EURUSD)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11068 ma-limit-pull
// -----------------------------------------------------------------------------
// Source: Boris Odintsov, "Interview with Boris Odintsov (ATC 2010)",
//   MQL5 Articles 2010-10-21, https://www.mql5.com/en/articles/532
// Card: artifacts/cards_approved/QM5_11068_ma-limit-pull.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; pending limit-order pullback entry):
//   Trend STATE  : fast EMA vs slow EMA AND fast-EMA slope over slope_lookback.
//                    bullish = fast>slow AND (fast[1]-fast[1+slope]) > 0
//                    bearish = fast<slow AND (fast[1]-fast[1+slope]) < 0
//   Regime gate  : ADX(adx_period) >= adx_min (default 18, card filter).
//                  Vol-expansion: ATR(atr_period)/ATR(atr_long_period) must be
//                    <= max_vol_expansion (default 2.0) — skip explosive vol.
//   Entry        : while bullish and flat, place/refresh a BUY LIMIT at
//                    Bid - pullback_atr * ATR(atr_period).
//                  while bearish and flat, place/refresh a SELL LIMIT at
//                    Ask + pullback_atr * ATR(atr_period).
//                  The limit price is recomputed once per closed bar: the prior
//                  pending order for this magic/symbol is removed and re-placed.
//                  Pending auto-expires after pending_expiry_bars (framework
//                  expiration_seconds) and is cancelled when the trend flips/dies.
//   Stop / Take  : SL = sl_atr_mult * ATR from the LIMIT price (card 1.2*ATR).
//                  TP = tp_atr_mult * ATR from the LIMIT price (card 1.8*ATR).
//   Exit         : opposite EMA trend STATE -> close the open position.
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// One active position AND at most one pending order per symbol/magic. No
// averaging, grid, martingale, or ML. Only the 5 Strategy_* hooks + Strategy
// inputs are EA-specific; framework wiring below MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11068;
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

input group "Strategy"
input int    strategy_fast_ma_period      = 12;    // fast EMA period (close)
input int    strategy_slow_ma_period      = 36;    // slow EMA period (close)
input int    strategy_slope_lookback      = 3;     // fast-EMA slope lookback (bars)
input int    strategy_atr_period          = 14;    // ATR period (offset / stop / target)
input int    strategy_atr_long_period     = 96;    // long ATR for vol-expansion baseline
input double strategy_pullback_atr        = 0.35;  // pullback limit offset = mult * ATR
input double strategy_sl_atr_mult         = 1.2;   // stop distance = mult * ATR from limit
input double strategy_tp_atr_mult         = 1.8;   // take-profit distance = mult * ATR from limit
input int    strategy_pending_expiry_bars = 12;    // cancel unfilled pending after N bars
input double strategy_adx_min             = 18.0;  // ADX floor (card filter; 0 = disabled)
input int    strategy_adx_period          = 14;    // ADX period
input double strategy_max_vol_expansion   = 2.0;   // skip if ATR/ATR_long > this (0 = disabled)
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (EA-local, bespoke pending-order state — framework has no pending
// counter; this is not an indicator/new-bar reimplementation).
// -----------------------------------------------------------------------------

// Short-term EMA trend STATE on closed bars: +1 bullish, -1 bearish, 0 none.
// Applies the ADX floor and the vol-expansion regime gate from the card.
int Strategy_TrendState()
  {
   const double fast1 = QM_EMA(_Symbol, _Period, strategy_fast_ma_period, 1);
   const double slow1 = QM_EMA(_Symbol, _Period, strategy_slow_ma_period, 1);
   if(fast1 <= 0.0 || slow1 <= 0.0)
      return 0;

   const int slope_shift = 1 + ((strategy_slope_lookback > 0) ? strategy_slope_lookback : 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_fast_ma_period, slope_shift);
   if(fast_prev <= 0.0)
      return 0;
   const double slope = fast1 - fast_prev;

   // ADX trend-strength floor (card default 18; skip flat regime).
   if(strategy_adx_min > 0.0)
     {
      const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      if(adx <= 0.0 || adx < strategy_adx_min)
         return 0;
     }

   // Vol-expansion gate: short ATR vs long ATR baseline. Skip explosive vol.
   if(strategy_max_vol_expansion > 0.0)
     {
      const double atr_short = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      const double atr_long  = QM_ATR(_Symbol, _Period, strategy_atr_long_period, 1);
      if(atr_short > 0.0 && atr_long > 0.0 &&
         (atr_short / atr_long) > strategy_max_vol_expansion)
         return 0;
     }

   if(fast1 > slow1 && slope > 0.0)
      return 1;
   if(fast1 < slow1 && slope < 0.0)
      return -1;
   return 0;
  }

// Remove any pending order belonging to this EA's magic on this symbol.
// Bespoke order-state scan: the framework exposes QM_TM_RemovePendingOrder but
// no per-magic pending counter.
void Strategy_RemoveOwnPending(const int magic)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, "refresh_or_cancel");
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). Places /
// refreshes / cancels the pending limit order once per closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One active position per symbol/magic: while filled, keep no pending.
   if(QM_TM_OpenPositionCount(magic) > 0)
     {
      Strategy_RemoveOwnPending(magic);
      return false;
     }

   const int trend = Strategy_TrendState();

   // Trend disappeared (or regime gate blocked) → cancel pending, stand down.
   if(trend == 0)
     {
      Strategy_RemoveOwnPending(magic);
      return false;
     }

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double offset = strategy_pullback_atr * atr_value;
   if(offset <= 0.0)
      return false;

   // Refresh: drop the prior pending so we re-place at the current bar's price.
   Strategy_RemoveOwnPending(magic);

   const int expiry_seconds = (strategy_pending_expiry_bars > 0)
                              ? strategy_pending_expiry_bars * PeriodSeconds(_Period)
                              : 0;

   if(trend > 0)
     {
      // BUY LIMIT below market (pullback entry).
      const double limit_price = QM_TM_NormalizePrice(_Symbol, bid - offset);
      if(limit_price <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY_LIMIT, limit_price, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY_LIMIT, limit_price, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;

      req.type               = QM_BUY_LIMIT;
      req.price              = limit_price;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "ma_limit_pull_buy";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   // trend < 0 → SELL LIMIT above market (pullback entry).
   const double limit_price = QM_TM_NormalizePrice(_Symbol, ask + offset);
   if(limit_price <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL_LIMIT, limit_price, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL_LIMIT, limit_price, atr_value, strategy_tp_atr_mult);
   if(tp <= 0.0)
      return false;

   req.type               = QM_SELL_LIMIT;
   req.price              = limit_price;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = "ma_limit_pull_sell";
   req.expiration_seconds = expiry_seconds;
   return true;
  }

// Fixed ATR stop/target carry the position; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite EMA trend STATE closes the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int trend = Strategy_TrendState();
   if(trend == 0)
      return false;

   // Determine the direction of the open position; close on opposite trend.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && trend < 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && trend > 0)
         return true;
     }
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
