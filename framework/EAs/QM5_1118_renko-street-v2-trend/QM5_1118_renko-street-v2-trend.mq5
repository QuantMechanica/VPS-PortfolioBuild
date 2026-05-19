#property strict
#property version   "5.0"
#property description "QM5_1118 Renko Street Trading System v2"

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
input int    qm_ea_id                   = 1118;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period_d1     = 14;
input double strategy_brick_atr_mult    = 0.10;
input int    strategy_confirm_bricks    = 2;
input bool   strategy_use_rr_tp         = true;
input double strategy_take_profit_rr    = 2.0;
input int    strategy_max_spread_points = 25;
input int    strategy_max_bricks_per_tick = 20;

double   g_brick_size = 0.0;
double   g_last_brick_close = 0.0;
double   g_last_closed_brick_low = 0.0;
double   g_last_closed_brick_high = 0.0;
double   g_flip_anchor_low = 0.0;
double   g_flip_anchor_high = 0.0;
int      g_brick_day_key = -1;
int      g_streak_dir = 0;
int      g_streak_count = 0;
int      g_pending_entry_dir = 0;
int      g_pending_exit_dir = 0;
double   g_pending_entry_sl = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int day_key = dt.year * 1000 + dt.day_of_year;
   if(day_key != g_brick_day_key || g_brick_size <= 0.0)
     {
      const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
      if(atr_d1 > 0.0 && strategy_brick_atr_mult > 0.0)
        {
         g_brick_size = atr_d1 * strategy_brick_atr_mult;
         g_brick_day_key = day_key;
        }
     }

   if(g_last_brick_close <= 0.0)
      g_last_brick_close = bid;

   if(g_brick_size > 0.0)
     {
      int bricks = 0;
      while(MathAbs(bid - g_last_brick_close) >= g_brick_size &&
            bricks < MathMax(1, strategy_max_bricks_per_tick))
        {
         const int new_dir = (bid > g_last_brick_close) ? 1 : -1;
         const double brick_open = g_last_brick_close;
         const double brick_close = g_last_brick_close + (new_dir * g_brick_size);
         const double brick_low = MathMin(brick_open, brick_close);
         const double brick_high = MathMax(brick_open, brick_close);

         if(g_streak_dir == 0)
           {
            g_streak_dir = new_dir;
            g_streak_count = 1;
           }
         else if(new_dir == g_streak_dir)
           {
            g_streak_count++;
           }
         else
           {
            g_flip_anchor_low = g_last_closed_brick_low;
            g_flip_anchor_high = g_last_closed_brick_high;
            g_streak_dir = new_dir;
            g_streak_count = 1;
           }

         g_last_brick_close = brick_close;
         g_last_closed_brick_low = brick_low;
         g_last_closed_brick_high = brick_high;

         if(g_streak_count == MathMax(1, strategy_confirm_bricks) &&
            g_flip_anchor_low > 0.0 &&
            g_flip_anchor_high > 0.0)
           {
            g_pending_entry_dir = g_streak_dir;
            g_pending_exit_dir = g_streak_dir;
            g_pending_entry_sl = (g_streak_dir > 0) ? g_flip_anchor_low : g_flip_anchor_high;
           }

         bricks++;
        }
     }

   const double spread_points = (ask - bid) / point;
   return (strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_pending_entry_dir == 0 || g_pending_entry_sl <= 0.0)
      return false;

   const double entry = (g_pending_entry_dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   if(g_pending_entry_dir > 0)
     {
      req.type = QM_BUY;
      req.sl = NormalizeDouble(g_pending_entry_sl, _Digits);
      if(req.sl >= entry)
         return false;
      req.reason = "RENKO_RED_TO_GREEN_CONFIRM";
     }
   else
     {
      req.type = QM_SELL;
      req.sl = NormalizeDouble(g_pending_entry_sl, _Digits);
      if(req.sl <= entry)
         return false;
      req.reason = "RENKO_GREEN_TO_RED_CONFIRM";
     }

   req.tp = strategy_use_rr_tp ? QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr) : 0.0;
   g_pending_entry_dir = 0;
   g_pending_entry_sl = 0.0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_pending_exit_dir == 0)
      return false;

   const int magic = QM_FrameworkMagic();
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
      const bool opposite_confirmed =
         (ptype == POSITION_TYPE_BUY && g_pending_exit_dir < 0) ||
         (ptype == POSITION_TYPE_SELL && g_pending_exit_dir > 0);
      if(opposite_confirmed)
        {
         g_pending_exit_dir = 0;
         return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

   // Event-time Renko entries are cached by Strategy_NoTradeFilter and consumed
   // on the tick that completes the confirmation brick.
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
