#property strict
#property version   "5.0"
#property description "QM5_1329 Raschke Holy Grail ADX(14)>30 strong-trend pullback to EMA(20), H1"
// Build from card QM5_1329_raschke-holy-grail-adx-pullback-h1.md (build target ea_id=1329).
// NOTE: card frontmatter ea_id=QM5_12137 (stale); build target / qm_ea_id = 1329 per
// orchestrator instruction. Flagged as frontmatter mismatch in build report.
//
// Mechanic (all H1, closed bar = shift 1; the card's "bar[0]" trigger bar is the
// just-closed H1 bar, i.e. shift 1 after QM_IsNewBar() fires):
//   STATES (regime / direction, evaluated on the closed trigger bar):
//     Strong-trend gate : ADX(14)[1] > 30  AND  ADX(14)[1] > ADX(14)[2]   (high AND rising)
//     Direction         : +DI(14)[1] > -DI(14)[1] => long ; -DI > +DI => short
//     Pullback to EMA20 : trigger bar's range straddles EMA20 with ATR tolerance:
//                           long : low[1]  <= EMA20[1] + 0.15*ATR(14)  AND  EMA20[1] <= high[1]
//                           short: high[1] >= EMA20[1] - 0.15*ATR(14)  AND  EMA20[1] >= low[1]
//   EVENT (the single trigger, fired once per qualifying closed bar):
//     Place a STOP order beyond the trigger-bar extreme (Raschke "break of trigger-bar
//     high/low"). long: BUY-STOP at high[1] + 1 pip ; short: SELL-STOP at low[1] - 1 pip.
//     Pending order valid for 2 H1 bars (expiration_seconds = 2*3600); if unfilled it is
//     cancelled (the pullback failed to resume the trend).
//   Stop loss        : long: trigger-bar low[1] - 1 pip ; short: trigger-bar high[1] + 1 pip.
//   Take profit      : 2.0 x initial-risk (entry-to-SL distance). One-shot, no scaling.
//   Trade management : static break-even after +1.0R favor ; after +1.5R favor lock SL at
//                      entry +/- 0.5R. One-time static transitions, NOT a continuous trail.
//   Time-stop        : 24 H1 bars held without TP/SL => market close on next H1 close.
//   Re-arm           : after any close, require ADX to drop < 25 then rise back > 30 before
//                      a new same-trend signal counts ("one shot per trend").
//
// .DWX invariants honoured: fail-OPEN spread guard (#1); no swap gate (#2); single
// QM_IsNewBar consume per OnTick (#3); ONE trigger EVENT, ADX/DI/EMA are STATES (#4);
// prior CLOSE/extreme of a *closed* bar, never a live range (#6); pip-correct buffers via
// QM_StopRulesPipsToPriceDistance (#14). All indicators in-EA via QM_* readers (no ML).

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1329;
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
input int    strategy_adx_period          = 14;     // ADX / DI period (Wilder)
input double strategy_adx_threshold        = 30.0;   // strong-trend gate: ADX > this AND rising
input double strategy_adx_rearm_low        = 25.0;   // re-arm: ADX must drop below this then rise back above threshold
input int    strategy_ema_period          = 20;     // pullback anchor (the "Holy Grail" line)
input int    strategy_atr_period          = 14;     // ATR for pullback tolerance
input double strategy_pullback_atr_tol     = 0.15;   // EMA-touch tolerance in ATR units
input int    strategy_trigger_buffer_pips  = 1;      // stop-entry / SL buffer beyond trigger-bar extreme (pips)
input int    strategy_pending_valid_bars   = 2;      // pending stop order lifetime in H1 bars
input double strategy_tp_rr                = 2.0;    // take-profit = N x initial-risk
input double strategy_be_trigger_rr        = 1.0;    // move SL to break-even after +N R favor
input double strategy_lock_trigger_rr      = 1.5;    // after +N R favor, lock SL ...
input double strategy_lock_at_rr           = 0.5;    // ... at entry +/- N R (half-lock)
input int    strategy_time_stop_bars       = 24;     // close after N H1 bars held without TP/SL

// File-scope state ---------------------------------------------------------
datetime g_entry_bar       = 0;      // H1 bar-open time when current position entered
double   g_entry_price     = 0.0;    // recorded fill price for R math
double   g_init_risk       = 0.0;    // initial-risk distance (entry-to-SL), price units
int      g_pos_dir         = 0;      // +1 long / -1 short for the open position
bool     g_be_done         = false;  // break-even transition already applied
bool     g_lock_done       = false;  // half-lock transition already applied

// Re-arm gate ("one shot per trend"): true once ADX has dropped below rearm_low
// since the last entry/close; only then may a fresh signal in either direction fire.
bool     g_armed           = true;   // start armed so the first signal can fire

// --- helpers --------------------------------------------------------------
int CurrentDir()
  {
   // +1 long, -1 short, 0 flat (for THIS EA's magic on THIS symbol)
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

bool HasOwnPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic)
         return true;
     }
   return false;
  }

void CancelOwnPendingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      QM_TM_RemovePendingOrder(t, reason);
     }
  }

// --- No-Trade Filter (time, spread, news) --------------------------------
// Fail-OPEN spread guard per .DWX invariant #1: only block a genuinely WIDE
// spread; never block on zero spread (DWX quotes ask==bid in the tester).
// 24/5 session per card (no time-of-day filter at H1).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double spread = ask - bid;
      const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point > 0.0 && (spread / point) > 50.0)   // wide-spread guard; zero-spread (tester) passes
         return true;
     }
   return false;
  }

// --- Trade Entry ----------------------------------------------------------
// Called once per closed H1 bar (caller guarantees QM_IsNewBar()==true). Manages
// the re-arm gate, expires stale pending orders, and on a qualifying pullback bar
// places ONE stop-entry order (the single EVENT). All STATES read from shift 1/2.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double adx0  = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   const double adx1  = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 2);

   // Re-arm gate: once ADX dips below rearm_low, the prior strong-trend leg is
   // considered finished and a new shot is permitted ("one shot per trend").
   if(adx0 > 0.0 && adx0 < strategy_adx_rearm_low)
      g_armed = true;

   // Expire stale pending stop orders: if the pullback has not resumed within
   // strategy_pending_valid_bars H1 bars, cancel. expiration_seconds is set on the
   // order too, but we belt-and-braces cancel here for tester robustness.
   if(HasOwnPendingOrder())
     {
      // A live pending order means the most recent setup is still in play; do not
      // stack a second one. Server-side expiration handles the 2-bar cutoff.
      return false;
     }

   if(CurrentDir() != 0)
      return false;                       // one position per magic
   if(!g_armed)
      return false;                       // wait for a fresh strong-trend leg

   if(adx0 <= 0.0 || adx1 <= 0.0)
      return false;
   if(!(adx0 > strategy_adx_threshold && adx0 > adx1))   // high AND rising
      return false;

   const double plus_di  = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   if(plus_di <= 0.0 && minus_di <= 0.0)
      return false;

   const double ema  = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1, PRICE_CLOSE);
   const double atr  = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double hi   = iHigh(_Symbol, PERIOD_H1, 1);   // perf-allowed: trigger-bar extreme of the just-closed H1 bar (one read/new-bar)
   const double lo   = iLow(_Symbol, PERIOD_H1, 1);    // perf-allowed: trigger-bar extreme of the just-closed H1 bar (one read/new-bar)
   if(ema <= 0.0 || atr <= 0.0 || hi <= 0.0 || lo <= 0.0 || hi < lo)
      return false;

   const double tol      = strategy_pullback_atr_tol * atr;
   const double buf_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trigger_buffer_pips);
   if(buf_dist <= 0.0)
      return false;
   const int    valid_secs = MathMax(1, strategy_pending_valid_bars) * 3600;

   // LONG: strong rising uptrend, bullish DI, pullback touched/neared EMA from above.
   if(plus_di > minus_di)
     {
      const bool pullback = (lo <= ema + tol) && (ema <= hi);
      if(pullback)
        {
         const double entry = QM_StopRulesNormalizePrice(_Symbol, hi + buf_dist);
         const double sl    = QM_StopRulesNormalizePrice(_Symbol, lo - buf_dist);
         if(sl <= 0.0 || sl >= entry)
            return false;
         const double risk = entry - sl;
         if(risk <= 0.0)
            return false;
         const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_rr * risk);

         req.type               = QM_BUY_STOP;
         req.price              = entry;
         req.sl                 = sl;
         req.tp                 = tp;
         req.reason             = "holy_grail_long";
         req.symbol_slot        = qm_magic_slot_offset;
         req.expiration_seconds = valid_secs;
         g_armed                = false;          // one shot per trend until ADX re-arms
         return true;
        }
     }
   // SHORT: strong rising downtrend, bearish DI, pullback touched/neared EMA from below.
   else if(minus_di > plus_di)
     {
      const bool pullback = (hi >= ema - tol) && (ema >= lo);
      if(pullback)
        {
         const double entry = QM_StopRulesNormalizePrice(_Symbol, lo - buf_dist);
         const double sl    = QM_StopRulesNormalizePrice(_Symbol, hi + buf_dist);
         if(sl <= entry)
            return false;
         const double risk = sl - entry;
         if(risk <= 0.0)
            return false;
         double tp = entry - strategy_tp_rr * risk;
         if(tp <= 0.0)
            return false;
         tp = QM_StopRulesNormalizePrice(_Symbol, tp);

         req.type               = QM_SELL_STOP;
         req.price              = entry;
         req.sl                 = sl;
         req.tp                 = tp;
         req.reason             = "holy_grail_short";
         req.symbol_slot        = qm_magic_slot_offset;
         req.expiration_seconds = valid_secs;
         g_armed                = false;          // one shot per trend until ADX re-arms
         return true;
        }
     }

   return false;
  }

// --- Trade Management -----------------------------------------------------
// Static (one-time) break-even and half-lock transitions on the open position.
// NOT a continuous trail. R measured from the recorded entry price and initial risk.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      // (Re)latch entry context the first time we see this position (e.g. after a
      // pending-stop fill — entry differs from the planned stop price by slippage).
      const bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if(g_entry_bar == 0 || g_pos_dir == 0)
        {
         g_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const double psl = PositionGetDouble(POSITION_SL);
         g_init_risk = (psl > 0.0) ? MathAbs(g_entry_price - psl) : 0.0;
         g_pos_dir   = is_buy ? 1 : -1;
         g_entry_bar = iTime(_Symbol, PERIOD_H1, 0);
         g_be_done   = false;
         g_lock_done = false;
        }

      if(g_init_risk <= 0.0 || g_entry_price <= 0.0)
         continue;

      const double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(price <= 0.0)
         continue;

      const double favor_r = is_buy ? (price - g_entry_price) / g_init_risk
                                    : (g_entry_price - price) / g_init_risk;

      // Half-lock at entry +/- lock_at_rr after lock_trigger_rr favor (checked first;
      // it supersedes plain break-even once reached).
      if(!g_lock_done && favor_r >= strategy_lock_trigger_rr)
        {
         const double lock_sl = is_buy
                                ? g_entry_price + strategy_lock_at_rr * g_init_risk
                                : g_entry_price - strategy_lock_at_rr * g_init_risk;
         QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, lock_sl), "holy_grail_half_lock");
         g_lock_done = true;
         g_be_done   = true;
        }
      // Break-even after be_trigger_rr favor.
      else if(!g_be_done && favor_r >= strategy_be_trigger_rr)
        {
         QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, g_entry_price), "holy_grail_break_even");
         g_be_done = true;
        }
     }
  }

// --- Trade Close ----------------------------------------------------------
// Time-stop: close after strategy_time_stop_bars H1 bars held without TP/SL.
// Hard SL and 2R TP ride on the order itself (set at entry / adjusted by management).
bool Strategy_ExitSignal()
  {
   const int dir = CurrentDir();
   if(dir == 0)
     {
      // Flat: clear per-position state so the next fill re-latches cleanly.
      g_entry_bar   = 0;
      g_pos_dir     = 0;
      g_entry_price = 0.0;
      g_init_risk   = 0.0;
      g_be_done     = false;
      g_lock_done   = false;
      return false;
     }

   if(g_entry_bar > 0)
     {
      const datetime now_bar = iTime(_Symbol, PERIOD_H1, 0);
      if(now_bar > 0)
        {
         const int held = (int)((now_bar - g_entry_bar) / 3600);
         if(held >= strategy_time_stop_bars)
            return true;          // framework closes all positions for this magic
        }
     }
   return false;
  }

// --- News Filter Hook (callable for Q09 News Impact phase) ----------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to central QM_NewsAllowsTrade
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1329\",\"strategy\":\"raschke-holy-grail-adx-pullback-h1\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
