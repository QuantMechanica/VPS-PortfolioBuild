#property strict
#property version   "5.0"
#property description "QM5_12787 Volatility-Contraction Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: Volatility-Contraction Breakout
// Card: QM5_12787_vol-contraction-breakout, G0 APPROVED 2026-06-29.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12787;
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

enum StrategySqueezeMethod
  {
   STRAT_SQZ_NR_BAR = 0,
   STRAT_SQZ_BBANDWIDTH = 1,
   STRAT_SQZ_ATR_RATIO = 2,
   STRAT_SQZ_DONCHIAN_WIDTH = 3,
   STRAT_SQZ_BB_IN_KC = 4
  };

enum StrategyStopMode
  {
   STRAT_STOP_BOX = 0,
   STRAT_STOP_ATR = 1
  };

enum StrategyHoldMode
  {
   STRAT_HOLD_INTRADAY = 0,
   STRAT_HOLD_DAILY = 1
  };

input group "Strategy"
input StrategySqueezeMethod strategy_squeeze_method = STRAT_SQZ_NR_BAR;
input int    strategy_squeeze_lookback      = 7;
input int    strategy_squeeze_rank_lookback = 20;
input int    strategy_box_lookback          = 7;
input int    strategy_atr_short_period      = 5;
input int    strategy_atr_long_period       = 20;
input double strategy_squeeze_ratio         = 0.75;
input int    strategy_bb_period             = 20;
input double strategy_bb_deviation          = 2.0;
input double strategy_kc_atr_mult           = 1.5;
input int    strategy_atr_period            = 14;
input double strategy_entry_buffer_atr_mult = 0.10;
input double strategy_entry_buffer_pct      = 0.0;
input StrategyStopMode strategy_stop_mode   = STRAT_STOP_BOX;
input double strategy_sl_atr_mult           = 1.50;
input double strategy_tp_r                  = 1.75;
input double strategy_min_box_atr           = 0.20;
input double strategy_max_box_atr           = 3.00;
input double strategy_max_spread_atr        = 0.20;
input bool   strategy_atr_expansion_confirm = false;
input bool   strategy_move_to_be_enabled    = true;
input int    strategy_order_expiry_bars     = 0;     // 0 = GTC until EOD cleanup
input StrategyHoldMode strategy_hold_mode   = STRAT_HOLD_INTRADAY;
input int    strategy_close_hour_broker     = 21;
input int    strategy_close_minute_broker   = 0;

bool Strategy_IsPendingStopType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_IsAfterCloseTime(const datetime broker_time)
  {
   if(strategy_hold_mode != STRAT_HOLD_INTRADAY)
      return false;

   MqlDateTime t;
   TimeToStruct(broker_time, t);
   const int now_minutes = t.hour * 60 + t.min;
   const int close_minutes = strategy_close_hour_broker * 60 + strategy_close_minute_broker;
   return (now_minutes >= close_minutes);
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
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

void Strategy_RemovePendingStops(const string reason)
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

double Strategy_BarRange(const MqlRates &bar)
  {
   if(bar.high <= 0.0 || bar.low <= 0.0 || bar.high <= bar.low)
      return 0.0;
   return bar.high - bar.low;
  }

bool Strategy_ReadRates(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, count, rates); // perf-allowed: bounded closed-bar squeeze/box structure; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   return (copied == count);
  }

bool Strategy_BoxFromRates(const MqlRates &rates[], const int lookback,
                           double &box_high, double &box_low)
  {
   box_high = -DBL_MAX;
   box_low = DBL_MAX;
   if(lookback <= 0 || ArraySize(rates) < lookback)
      return false;

   for(int i = 0; i < lookback; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high <= rates[i].low)
         return false;
      box_high = MathMax(box_high, rates[i].high);
      box_low = MathMin(box_low, rates[i].low);
     }

   return (box_high > box_low && box_low > 0.0);
  }

double Strategy_DonchianWidthFromRates(const MqlRates &rates[], const int start_idx, const int lookback)
  {
   if(start_idx < 0 || lookback <= 0 || ArraySize(rates) < start_idx + lookback)
      return 0.0;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i = start_idx; i < start_idx + lookback; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high <= rates[i].low)
         return 0.0;
      hi = MathMax(hi, rates[i].high);
      lo = MathMin(lo, rates[i].low);
     }

   if(hi <= lo || lo <= 0.0)
      return 0.0;
   return hi - lo;
  }

double Strategy_BandWidth(const int shift)
  {
   const double upper = QM_BB_Upper(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                    strategy_bb_period, strategy_bb_deviation, shift);
   const double lower = QM_BB_Lower(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                    strategy_bb_period, strategy_bb_deviation, shift);
   const double mid = QM_BB_Middle(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                   strategy_bb_period, strategy_bb_deviation, shift);
   if(upper <= 0.0 || lower <= 0.0 || mid <= 0.0 || upper <= lower)
      return 0.0;
   return (upper - lower) / mid;
  }

bool Strategy_SqueezeOn(const MqlRates &rates[])
  {
   if(strategy_squeeze_method == STRAT_SQZ_NR_BAR)
     {
      if(ArraySize(rates) < strategy_squeeze_lookback + 1)
         return false;
      const double current_range = Strategy_BarRange(rates[0]);
      if(current_range <= 0.0)
         return false;

      double min_prior = DBL_MAX;
      for(int i = 1; i <= strategy_squeeze_lookback; ++i)
        {
         const double r = Strategy_BarRange(rates[i]);
         if(r <= 0.0)
            return false;
         min_prior = MathMin(min_prior, r);
        }
      return (current_range <= min_prior);
     }

   if(strategy_squeeze_method == STRAT_SQZ_BBANDWIDTH)
     {
      const double current_width = Strategy_BandWidth(1);
      if(current_width <= 0.0)
         return false;

      double min_prior = DBL_MAX;
      for(int shift = 2; shift <= strategy_squeeze_rank_lookback + 1; ++shift)
        {
         const double width = Strategy_BandWidth(shift);
         if(width <= 0.0)
            return false;
         min_prior = MathMin(min_prior, width);
        }
      return (current_width <= min_prior);
     }

   if(strategy_squeeze_method == STRAT_SQZ_ATR_RATIO)
     {
      const double atr_short = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                      strategy_atr_short_period, 1);
      const double atr_long = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                     strategy_atr_long_period, 1);
      if(atr_short <= 0.0 || atr_long <= 0.0)
         return false;
      return ((atr_short / atr_long) < strategy_squeeze_ratio);
     }

   if(strategy_squeeze_method == STRAT_SQZ_DONCHIAN_WIDTH)
     {
      const double current_width = Strategy_DonchianWidthFromRates(rates, 0, strategy_squeeze_lookback);
      if(current_width <= 0.0)
         return false;

      double min_prior = DBL_MAX;
      for(int start = 1; start <= strategy_squeeze_rank_lookback; ++start)
        {
         const double width = Strategy_DonchianWidthFromRates(rates, start, strategy_squeeze_lookback);
         if(width <= 0.0)
            return false;
         min_prior = MathMin(min_prior, width);
        }
      return (current_width <= min_prior);
     }

   if(strategy_squeeze_method == STRAT_SQZ_BB_IN_KC)
     {
      const double upper = QM_BB_Upper(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                       strategy_bb_period, strategy_bb_deviation, 1);
      const double lower = QM_BB_Lower(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                       strategy_bb_period, strategy_bb_deviation, 1);
      const double mid = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, 1);
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      if(upper <= 0.0 || lower <= 0.0 || mid <= 0.0 || atr <= 0.0)
         return false;

      const double kc_upper = mid + atr * strategy_kc_atr_mult;
      const double kc_lower = mid - atr * strategy_kc_atr_mult;
      return (upper < kc_upper && lower > kc_lower);
     }

   return false;
  }

bool Strategy_StopsLevelAllows(const QM_OrderType side, const double entry,
                               const double sl, const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   if(stops_level <= 0)
      return true;

   const double min_dist = stops_level * point;
   if(MathAbs(entry - sl) < min_dist || MathAbs(entry - tp) < min_dist)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   if(side == QM_BUY_STOP && entry - ask < min_dist)
      return false;
   if(side == QM_SELL_STOP && bid - entry < min_dist)
      return false;

   return true;
  }

void Strategy_AssignRequest(QM_EntryRequest &dst, const QM_EntryRequest &src)
  {
   dst.type = src.type;
   dst.price = src.price;
   dst.sl = src.sl;
   dst.tp = src.tp;
   dst.reason = src.reason;
   dst.symbol_slot = src.symbol_slot;
   dst.expiration_seconds = src.expiration_seconds;
  }

bool Strategy_BuildStopRequest(const QM_OrderType side, const double entry,
                               const double sl, const double tp,
                               const int expiry_seconds, const string reason,
                               QM_EntryRequest &req)
  {
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;
   if(!Strategy_StopsLevelAllows(side, entry, sl, tp))
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   if(side == QM_BUY_STOP && entry <= ask)
      return false;
   if(side == QM_SELL_STOP && entry >= bid)
      return false;

   req.type = side;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Keep exits/cleanup reachable when
// positions or pending stops already exist.
bool Strategy_NoTradeFilter()
  {
   const bool has_open = Strategy_HasOpenPosition();
   const bool has_pending = Strategy_HasPendingStops();

   if(Strategy_IsAfterCloseTime(TimeCurrent()) && !has_open && !has_pending)
      return true;

   if(!has_open && !has_pending && strategy_max_spread_atr > 0.0)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      if(bid <= 0.0 || ask <= 0.0 || atr <= 0.0)
         return true;
      if(ask > bid && (ask - bid) > atr * strategy_max_spread_atr)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_IsAfterCloseTime(TimeCurrent()))
      return false;
   if(Strategy_HasOpenPosition() || Strategy_HasPendingStops())
      return false;

   if(strategy_squeeze_lookback < 2 || strategy_squeeze_lookback > 100)
      return false;
   if(strategy_squeeze_rank_lookback < 2 || strategy_squeeze_rank_lookback > 250)
      return false;
   if(strategy_box_lookback < 2 || strategy_box_lookback > 100)
      return false;
   if(strategy_atr_short_period <= 0 || strategy_atr_long_period <= 0 ||
      strategy_atr_period <= 0 || strategy_bb_period <= 1)
      return false;
   if(strategy_squeeze_ratio <= 0.0 || strategy_bb_deviation <= 0.0 ||
      strategy_kc_atr_mult <= 0.0 || strategy_entry_buffer_atr_mult < 0.0 ||
      strategy_entry_buffer_pct < 0.0 || strategy_sl_atr_mult <= 0.0 ||
      strategy_tp_r <= 0.0 || strategy_min_box_atr <= 0.0 ||
      strategy_max_box_atr <= strategy_min_box_atr || strategy_order_expiry_bars < 0)
      return false;

   const int need_bars = MathMax(strategy_box_lookback,
                         MathMax(strategy_squeeze_lookback + 1,
                                 strategy_squeeze_lookback + strategy_squeeze_rank_lookback + 1));
   MqlRates rates[];
   if(!Strategy_ReadRates(rates, need_bars))
      return false;

   if(!Strategy_SqueezeOn(rates))
      return false;

   double box_high = 0.0;
   double box_low = 0.0;
   if(!Strategy_BoxFromRates(rates, strategy_box_lookback, box_high, box_low))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const double box_range = box_high - box_low;
   const double box_units = box_range / (atr * MathSqrt((double)strategy_box_lookback));
   if(box_units < strategy_min_box_atr || box_units > strategy_max_box_atr)
      return false;

   if(strategy_atr_expansion_confirm && Strategy_BarRange(rates[0]) <= box_range)
      return false;

   double buffer = atr * strategy_entry_buffer_atr_mult;
   if(strategy_entry_buffer_pct > 0.0)
      buffer = MathMax(buffer, box_high * strategy_entry_buffer_pct / 100.0);
   buffer = MathMax(buffer, point);

   const double buy_entry = box_high + buffer;
   const double sell_entry = box_low - buffer;

   double buy_sl = box_low;
   double sell_sl = box_high;
   if(strategy_stop_mode == STRAT_STOP_ATR)
     {
      buy_sl = QM_StopATRFromValue(_Symbol, QM_BUY_STOP, buy_entry, atr, strategy_sl_atr_mult);
      sell_sl = QM_StopATRFromValue(_Symbol, QM_SELL_STOP, sell_entry, atr, strategy_sl_atr_mult);
     }
   else
     {
      buy_sl = QM_StopRulesNormalizePrice(_Symbol, buy_sl);
      sell_sl = QM_StopRulesNormalizePrice(_Symbol, sell_sl);
     }

   const double buy_tp = QM_TakeRR(_Symbol, QM_BUY_STOP, buy_entry, buy_sl, strategy_tp_r);
   const double sell_tp = QM_TakeRR(_Symbol, QM_SELL_STOP, sell_entry, sell_sl, strategy_tp_r);
   if(buy_sl <= 0.0 || sell_sl <= 0.0 || buy_tp <= 0.0 || sell_tp <= 0.0)
      return false;

   const int expiry_seconds = (strategy_order_expiry_bars <= 0)
                              ? 0
                              : strategy_order_expiry_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   const bool buy_ok = Strategy_BuildStopRequest(QM_BUY_STOP, buy_entry, buy_sl, buy_tp,
                                                 expiry_seconds, "vcb_buy_stop", buy_req);
   const bool sell_ok = Strategy_BuildStopRequest(QM_SELL_STOP, sell_entry, sell_sl, sell_tp,
                                                  expiry_seconds, "vcb_sell_stop", sell_req);

   if(!buy_ok && !sell_ok)
      return false;

   if(buy_ok && sell_ok)
     {
      ulong buy_ticket = 0;
      QM_TM_OpenPosition(buy_req, buy_ticket);
      Strategy_AssignRequest(req, sell_req);
      return true;
     }

   if(buy_ok)
      Strategy_AssignRequest(req, buy_req);
   else
      Strategy_AssignRequest(req, sell_req);

   return true;
  }

// Called every tick. Removes opposite pending stops after a fill, performs EOD
// pending cleanup, and optionally moves SL to break-even after 1R.
void Strategy_ManageOpenPosition()
  {
   const bool after_close = Strategy_IsAfterCloseTime(TimeCurrent());
   const bool has_open = Strategy_HasOpenPosition();

   if(after_close || has_open)
      Strategy_RemovePendingStops(after_close ? "eod_pending_cleanup" : "opposite_stop_after_fill");

   if(!strategy_move_to_be_enabled || !has_open)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(magic <= 0 || point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double risk = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(risk <= 0.0 || moved < risk)
         continue;

      const double target_sl = QM_StopRulesNormalizePrice(_Symbol, open_price);
      const bool improves = is_buy ? (current_sl < target_sl - point * 0.5)
                                   : (current_sl > target_sl + point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "move_to_be_1r");
     }
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   if(strategy_hold_mode != STRAT_HOLD_INTRADAY)
      return false;
   if(!Strategy_IsAfterCloseTime(TimeCurrent()))
      return false;
   return Strategy_HasOpenPosition();
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)/QM_NewsAllowsTrade2(...)
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
