#property strict
#property version   "5.0"
#property description "QM5_12926 Renko Color-Streak H1 (N-Brick Confirmation Trend)"
// Strategy Card: artifacts/cards_approved/QM5_12926_renko-color-streak-h1.md
// source_id 6e967762-b26d-59a3-b076-35c17f2e7c36, G0 APPROVED 2026-05-18.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12926;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// Card Filters: "News-filter hook (off by default for P2 — callable for
// live)." Both axes default OFF here; live setfiles turn them on explicitly.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_brick_atr_period    = 14;   // Card Entry: brick size = ATR(period,D1) x mult, re-evaluated at each H1 open.
input double strategy_brick_atr_mult      = 0.1;  // Card Entry: brick size multiplier on the prior closed D1 ATR.
input int    strategy_min_streak          = 3;    // Card Entry/Filters: N same-color bricks required before the confirming brick (P3 sweep 2-5).
input bool   strategy_use_ema_bias        = true; // Card Entry: EMA bias gate on the Renko stream (P3-toggleable, default ON).
input int    strategy_ema_period          = 50;   // Card Entry: EMA period fed by brick closes.
input double strategy_sl_brick_mult       = 2.0;  // Card Stop Loss: initial SL = (1+mult) x brick-size beyond the entry brick's close (P3 sweep 1.5-3.0).
input double strategy_tp_rr               = 2.0;  // Card Exit (secondary): fixed RR take-profit multiple (P3 sweep 1.5/2.0/3.0).
input bool   strategy_trailing_enabled    = true; // Card Exit (tertiary): trailing-stop toggle (P3-toggleable).
input double strategy_trailing_brick_mult = 2.0;  // Card Exit (tertiary): trailing distance in brick-size multiples from the running extreme.
input int    strategy_spread_cap_points   = 25;   // Card Filters: spread cap, raw broker points.

// -----------------------------------------------------------------------------
// Renko brick engine — file-scope state, advanced once per tick by
// RenkoEngine_UpdateOnTick(). Bricks are price-distance events, not chart-bar
// events, so this cannot be expressed as a QM_IsNewBar() gate (see OnTick).
// -----------------------------------------------------------------------------
double g_brick_size          = 0.0;
double g_last_brick_close    = 0.0;   // 0 = not seeded yet (cold start)
int    g_streak_color        = 0;     // +1 green, -1 red, 0 none
int    g_streak_len          = 0;
double g_renko_ema           = 0.0;
bool   g_renko_ema_ready     = false;
bool   g_new_brick_this_tick = false;
int    g_last_brick_color_this_tick = 0;
double g_pos_extreme         = 0.0;   // running best brick close since entry (trailing reference)
bool   g_pos_extreme_valid   = false;

// Advances the Renko brick state machine from the current Bid. Brick size is
// re-cached once per H1 bar from the prior closed D1 ATR (card: "re-evaluated
// at each H1 open ... STATIC for the duration of the H1 bar"). Runs
// unconditionally every tick — bounded to 50 brick emissions/tick against a
// pathological gap tick.
void RenkoEngine_UpdateOnTick()
  {
   g_new_brick_this_tick = false;
   g_last_brick_color_this_tick = 0;

   if(QM_IsNewBar(_Symbol, PERIOD_H1))
     {
      const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_brick_atr_period, 1);
      if(atr_d1 > 0.0)
         g_brick_size = atr_d1 * strategy_brick_atr_mult;
     }

   if(g_brick_size <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return;

   if(g_last_brick_close <= 0.0)
     {
      // Cold start: seed the brick reference from the first valid tick. No
      // historical brick reconstruction (HR9 literal reading — see build
      // open_questions); the streak/EMA warm up from bricks formed live.
      g_last_brick_close = bid;
      return;
     }

   int iterations = 0;
   while(iterations < 50)
     {
      const double diff = bid - g_last_brick_close;
      if(MathAbs(diff) < g_brick_size)
         break;

      const bool up = (diff > 0.0);
      g_last_brick_close += up ? g_brick_size : -g_brick_size;
      const int brick_color = up ? 1 : -1;

      if(brick_color == g_streak_color)
         g_streak_len++;
      else
        {
         g_streak_color = brick_color;
         g_streak_len = 1;
        }

      if(!g_renko_ema_ready)
        {
         g_renko_ema = g_last_brick_close;
         g_renko_ema_ready = true;
        }
      else
        {
         const double alpha = 2.0 / (strategy_ema_period + 1.0);
         g_renko_ema = alpha * g_last_brick_close + (1.0 - alpha) * g_renko_ema;
        }

      g_new_brick_this_tick = true;
      g_last_brick_color_this_tick = brick_color;
      iterations++;
     }
  }

// Cheap per-tick spread guard. .DWX symbols quote ask==bid (0 modeled spread)
// in the tester — only a genuinely wide/crossed quote blocks (DWX invariant).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double cap = strategy_spread_cap_points * point;
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > cap)
      return true;
   return false;
  }

// Card Trigger: a 4-brick (N+1) same-color streak ending on the brick that
// just closed, gated by the Renko-stream EMA bias. Caller guarantees a new
// brick closed this tick (see OnTick).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_new_brick_this_tick)
      return false;
   if(g_streak_len < strategy_min_streak + 1)
      return false;
   if(strategy_use_ema_bias && !g_renko_ema_ready)
      return false;

   const double sl_dist = (1.0 + strategy_sl_brick_mult) * g_brick_size;
   if(sl_dist <= 0.0)
      return false;

   if(g_last_brick_color_this_tick > 0)
     {
      if(strategy_use_ema_bias && g_last_brick_close <= g_renko_ema)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = g_last_brick_close - sl_dist;
      req.tp = QM_TakeRR(_Symbol, QM_BUY, g_last_brick_close, req.sl, strategy_tp_rr);
      req.reason = "RENKO_STREAK_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   if(g_last_brick_color_this_tick < 0)
     {
      if(strategy_use_ema_bias && g_last_brick_close >= g_renko_ema)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = g_last_brick_close + sl_dist;
      req.tp = QM_TakeRR(_Symbol, QM_SELL, g_last_brick_close, req.sl, strategy_tp_rr);
      req.reason = "RENKO_STREAK_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Card Exit (tertiary): trail SL by strategy_trailing_brick_mult x brick-size
// from the running best brick close since entry. Only ever tightens (mirrors
// the framework's own QM_TM_TrailATR "improves" idiom).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double current_sl = 0.0;
   bool has_position = false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      current_sl = PositionGetDouble(POSITION_SL);
      has_position = true;
      break;
     }

   if(!has_position)
     {
      g_pos_extreme_valid = false;
      return;
     }

   if(!g_new_brick_this_tick || !strategy_trailing_enabled)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   if(!g_pos_extreme_valid)
     {
      g_pos_extreme = g_last_brick_close;
      g_pos_extreme_valid = true;
     }
   else if(is_buy && g_last_brick_close > g_pos_extreme)
      g_pos_extreme = g_last_brick_close;
   else if(!is_buy && g_last_brick_close < g_pos_extreme)
      g_pos_extreme = g_last_brick_close;

   const double trail_dist = strategy_trailing_brick_mult * g_brick_size;
   if(trail_dist <= 0.0)
      return;

   const double target_sl = QM_TM_NormalizePrice(_Symbol, is_buy ? (g_pos_extreme - trail_dist) : (g_pos_extreme + trail_dist));
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(!improves)
      return;

   QM_TM_MoveSL(ticket, target_sl, "renko_trail_2xbrick");
  }

// Card Exit (primary): a single opposite-color brick close exits immediately.
bool Strategy_ExitSignal()
  {
   if(!g_new_brick_this_tick)
      return false;

   const int magic = QM_FrameworkMagic();
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_last_brick_color_this_tick < 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_last_brick_color_this_tick > 0)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2/QM_NewsAllowsTrade (both axes OFF by default per card)
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return.
   QM_FrameworkTrackOpenPositionMae();

   // Renko brick engine — runs unconditionally, every tick, ahead of every
   // guard below. Card (Implementation Notes): "logic is brick-driven not
   // bar-driven" — brick-close events do not align with H1 bar closes, so the
   // framework's default QM_IsNewBar() entry gate (one evaluation per chart
   // bar) cannot express the card's Trigger rule ("a new brick close").
   // RenkoEngine_UpdateOnTick() replaces that one gate below with a
   // "new brick just closed" event; every other framework guard/lifecycle
   // call keeps the canonical 2026-07-02 audit order.
   RenkoEngine_UpdateOnTick();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL on open positions. Management
   // and rule-based exits keep running through news windows — the news gate
   // below blocks NEW entries only (2026-07-02 audit rule).
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

   // FW1 — 2-axis check, gates NEW entries only (see banner above).
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   // Card Trigger: "a new brick close" — replaces QM_IsNewBar() (see banner above).
   if(!g_new_brick_this_tick)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
