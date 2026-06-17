#property strict
#property version   "5.0"
#property description "QM5_11062 pst-scalper — pysystemtrade bracket mean-reversion (intraday, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11062 pst-scalper
// -----------------------------------------------------------------------------
// Source: Rob Carver / pysystemtrade provided `scalper` system
//   (systems/provided/scalper/components.py — get_bracket_orders,
//    buy_bracket_price, sell_bracket_price, get_stop_loss_order_given_current_trade).
// Card: artifacts/cards_approved/QM5_11062_pst-scalper.md (g0_status APPROVED).
//
// CARD MECHANIC (literal):
//   Estimate a short-horizon price range R = mean of the last `R_bars` completed
//   bar ranges at the strategy horizon, clamped to [min_R, max_R]. While flat,
//   place a SYMMETRIC pair of resting limit orders around the current mid:
//     buy-limit  = mid - F*(R/2)
//     sell-limit = mid + F*(R/2)      with F = limit_mult_F (0.75 default)
//   When one bracket fills, the OPPOSITE bracket price is the take-profit and a
//   protective stop is attached at K_to_L*R = (stop_mult_K - limit_mult_F)*R
//   (default (0.875-0.75)=0.125 * R) from the opening price, at least min_stop_ticks
//   away. Spread filter: trade only when spread < spread_mult * R. Stop opening
//   new brackets when less than session_cutoff_horizons*horizon remains in the
//   session; cancel outstanding orders at session close.
//
// FRAMEWORK REALISATION (flagged — see SPEC.md §1 and build flags):
//   The V5 corset is single-entry / one-position-per-magic: Strategy_EntrySignal
//   returns ONE req per closed bar and the framework sends exactly one order. A
//   simultaneous TWO-sided resting bracket is therefore expressed as a single
//   resting LIMIT that FADES the most recent bar displacement (mean-reversion):
//     - bar closed DOWN vs its open  -> place BUY_LIMIT at mid - F*(R/2)
//     - bar closed UP   vs its open  -> place SELL_LIMIT at mid + F*(R/2)
//   The opposite-bracket price is attached as the order's TP and the K_to_L*R
//   stop is attached as the order's SL, so a fill reproduces the card's
//   fill->opposite-bracket-TP / stop geometry EXACTLY for that direction. The
//   order carries an expiration of horizon_seconds (the card cancels unmatched
//   brackets each horizon). This is a faithful single-leg port of a symmetric
//   two-leg rule; the symmetric-pair simplification is the only deviation.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11062;
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
// Range / bracket geometry (from configuration.py StratParameters).
input int    strategy_R_bars             = 4;      // completed bars used to estimate R
input double strategy_limit_mult_F       = 0.75;   // bracket offset fraction F: limit = mid +/- F*(R/2)
input double strategy_stop_mult_K        = 0.875;  // stop multiple K; stop distance = (K - F)*R from open
input double strategy_min_R_points       = 50.0;   // min clamp for R, in raw points (per-symbol via setfile)
input double strategy_max_R_points       = 5000.0; // max clamp for R, in raw points (per-symbol via setfile)
input int    strategy_min_stop_ticks     = 3;      // stop at least this many ticks from entry
input double strategy_spread_mult        = 0.25;   // skip if spread > spread_mult * R (fail-open on zero spread)
input int    strategy_horizon_seconds    = 600;    // bracket horizon -> pending-order expiration
input int    strategy_session_start_h    = 7;      // broker-hour: first hour brackets may be placed
input int    strategy_session_end_h      = 20;     // broker-hour: last hour brackets may be placed
input int    strategy_cutoff_horizons    = 3;      // stop new brackets within cutoff_horizons*horizon of session end

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/range work is on the
// closed-bar entry path. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing quote

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero / negative modeled spread (.DWX) — fail-open

   // Range R reference for the spread cap, scaled to the symbol via points.
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   double r_value = 0.0;
   if(!ComputeRangeR(r_value))
      return false; // no R yet — defer to the entry gate, do not block here

   const double spread_cap = strategy_spread_mult * r_value;
   if(spread_cap > 0.0 && spread > spread_cap)
      return true; // genuinely wide spread relative to the bracket range

   return false;
  }

// Estimate R = mean of the last `strategy_R_bars` completed bar ranges
// (high-low) at the current timeframe, clamped to [min_R, max_R] (points->price).
// Returns false until enough completed bars exist.
bool ComputeRangeR(double &out_r)
  {
   out_r = 0.0;
   if(strategy_R_bars <= 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   double sum = 0.0;
   int    n   = 0;
   for(int s = 1; s <= strategy_R_bars; ++s)
     {
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar range read
      const double lo = iLow(_Symbol, _Period, s);
      if(hi <= 0.0 || lo <= 0.0 || hi < lo)
         continue;
      sum += (hi - lo);
      n++;
     }
   if(n < strategy_R_bars) // require all horizon bars present (card: >=R_bars)
      return false;

   double r = sum / n;

   const double min_r = strategy_min_R_points * point;
   const double max_r = strategy_max_R_points * point;
   if(min_r > 0.0 && r < min_r)
      r = min_r;
   if(max_r > 0.0 && r > max_r)
      r = max_r;

   if(r <= 0.0)
      return false;
   out_r = r;
   return true;
  }

// Broker-hour session window with a horizon-aware cutoff before the close.
// Brackets are only placed inside [session_start_h, session_end_h), and not
// within cutoff_horizons*horizon of session_end_h.
bool InsideBracketWindow(const datetime broker_now)
  {
   MqlDateTime t;
   TimeToStruct(broker_now, t);
   const int hour = t.hour;
   if(hour < strategy_session_start_h || hour >= strategy_session_end_h)
      return false;

   // Seconds remaining until the session-end hour boundary on this broker day.
   const int secs_now      = hour * 3600 + t.min * 60 + t.sec;
   const int secs_end      = strategy_session_end_h * 3600;
   const int secs_to_close = secs_end - secs_now;
   const int cutoff_secs   = strategy_cutoff_horizons * strategy_horizon_seconds;
   if(secs_to_close <= cutoff_secs)
      return false;

   return true;
  }

// Entry: place ONE resting limit fading the last closed bar's displacement.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (no pyramiding).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Only place brackets inside the liquid session, away from the close.
   if(!InsideBracketWindow(TimeCurrent()))
      return false;

   double r_value = 0.0;
   if(!ComputeRangeR(r_value))
      return false;

   // Last closed bar displacement decides which side we fade (mean-reversion).
   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(open1 <= 0.0 || close1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const double mid = 0.5 * (ask + bid);

   const double half_offset = strategy_limit_mult_F * (r_value * 0.5); // F*(R/2)
   if(half_offset <= 0.0)
      return false;

   // Stop distance = (K - F) * R from the opening (fill) price; min ticks floor.
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick       = (tick_size > 0.0) ? tick_size : point;
   double stop_distance = (strategy_stop_mult_K - strategy_limit_mult_F) * r_value;
   const double min_stop  = strategy_min_stop_ticks * tick;
   if(stop_distance < min_stop)
      stop_distance = min_stop;
   if(stop_distance <= 0.0)
      return false;

   QM_OrderType side;
   double limit_price;
   double tp_price;   // opposite bracket price
   double sl_price;

   if(close1 < open1)
     {
      // Down move -> fade up: BUY_LIMIT below mid; TP at the opposite (sell) bracket.
      side        = QM_BUY_LIMIT;
      limit_price = mid - half_offset;
      tp_price    = mid + half_offset;
      sl_price    = limit_price - stop_distance;
     }
   else if(close1 > open1)
     {
      // Up move -> fade down: SELL_LIMIT above mid; TP at the opposite (buy) bracket.
      side        = QM_SELL_LIMIT;
      limit_price = mid + half_offset;
      tp_price    = mid - half_offset;
      sl_price    = limit_price + stop_distance;
     }
   else
     {
      return false; // doji-flat bar: no displacement to fade
     }

   limit_price = QM_TM_NormalizePrice(_Symbol, limit_price);
   tp_price    = QM_TM_NormalizePrice(_Symbol, tp_price);
   sl_price    = QM_TM_NormalizePrice(_Symbol, sl_price);
   if(limit_price <= 0.0 || tp_price <= 0.0 || sl_price <= 0.0)
      return false;

   req.type               = side;
   req.price              = limit_price;            // resting pending limit
   req.sl                 = sl_price;
   req.tp                 = tp_price;
   req.reason             = "pst_bracket_meanrev";
   req.expiration_seconds = strategy_horizon_seconds; // cancel unmatched bracket after one horizon
   return true;
  }

// Stop/TP ride on the resting order; no active management beyond the bracket.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the attached opposite-bracket TP and stop.
bool Strategy_ExitSignal()
  {
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
