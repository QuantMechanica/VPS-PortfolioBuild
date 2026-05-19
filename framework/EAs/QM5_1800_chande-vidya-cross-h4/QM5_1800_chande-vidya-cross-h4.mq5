#property strict
#property version   "5.0"
#property description "QM5_1800 Chande VIDYA Cross H4"

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
input int    qm_ea_id                   = 1800;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_fast_vidya_period = 12;
input int    strategy_fast_cmo_period   = 9;
input int    strategy_slow_vidya_period = 48;
input int    strategy_slow_cmo_period   = 27;
input int    strategy_d1_ema_period     = 50;
input int    strategy_atr_period        = 20;
input double strategy_initial_atr_mult  = 2.5;
input double strategy_trail_atr_mult    = 2.0;
input double strategy_trail_trigger_atr = 1.5;
input double strategy_spread_atr_mult   = 0.35;
input int    strategy_max_hold_h4_bars  = 30;
input int    strategy_vidya_warmup_bars = 160;

datetime g_last_entry_h4_bar = 0;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

double CloseAt(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(_Symbol, tf, shift);
  }

double CMOAt(const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period <= 0 || shift < 1)
      return 0.0;

   double su = 0.0;
   double sd = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double c0 = CloseAt(tf, i);
      const double c1 = CloseAt(tf, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;

      const double diff = c0 - c1;
      if(diff > 0.0)
         su += diff;
      else
         sd -= diff;
     }

   const double denom = su + sd;
   if(denom <= 0.0)
      return 0.0;
   return 100.0 * (su - sd) / denom;
  }

double VIDYAAt(const ENUM_TIMEFRAMES tf,
               const int ma_period,
               const int cmo_period,
               const int shift)
  {
   if(ma_period <= 1 || cmo_period <= 0 || shift < 1)
      return 0.0;

   const int available = iBars(_Symbol, tf);
   const int history = MathMax(strategy_vidya_warmup_bars, ma_period + cmo_period + 24);
   const int seed_shift = shift + history;
   if(available <= seed_shift + ma_period + cmo_period + 2)
      return 0.0;

   double vidya = 0.0;
   for(int i = seed_shift; i < seed_shift + ma_period; ++i)
     {
      const double c = CloseAt(tf, i);
      if(c <= 0.0)
         return 0.0;
      vidya += c;
     }
   vidya /= (double)ma_period;

   const double k = 2.0 / ((double)ma_period + 1.0);
   for(int s = seed_shift - 1; s >= shift; --s)
     {
      const double c = CloseAt(tf, s);
      const double cmo = MathAbs(CMOAt(tf, cmo_period, s)) / 100.0;
      if(c <= 0.0)
         return 0.0;
      vidya = k * cmo * c + (1.0 - k * cmo) * vidya;
     }

   return vidya;
  }

bool FindOurPosition(ulong &ticket,
                     ENUM_POSITION_TYPE &position_type,
                     double &open_price,
                     datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double PositionExtremeSinceEntry(const ENUM_POSITION_TYPE position_type,
                                 const datetime open_time)
  {
   double extreme = 0.0;
   const int max_scan = MathMax(strategy_max_hold_h4_bars + 2, 2);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_H4, shift);
      if(bar_time <= 0)
         break;
      if(bar_time < open_time)
         break;

      if(position_type == POSITION_TYPE_BUY)
        {
         const double high = iHigh(_Symbol, PERIOD_H4, shift);
         if(high > 0.0 && (extreme <= 0.0 || high > extreme))
            extreme = high;
        }
      else
        {
         const double low = iLow(_Symbol, PERIOD_H4, shift);
         if(low > 0.0 && (extreme <= 0.0 || low < extreme))
            extreme = low;
        }
     }

   return extreme;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if((ask - bid) > strategy_spread_atr_mult * atr)
      return true;

   return false;
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

   const datetime h4_bar = iTime(_Symbol, PERIOD_H4, 0);
   if(h4_bar <= 0 || h4_bar == g_last_entry_h4_bar)
      return false;
   g_last_entry_h4_bar = h4_bar;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close_1 = CloseAt(PERIOD_H4, 1);
   const double close_2 = CloseAt(PERIOD_H4, 2);
   const double fast_1 = VIDYAAt(PERIOD_H4, strategy_fast_vidya_period, strategy_fast_cmo_period, 1);
   const double fast_2 = VIDYAAt(PERIOD_H4, strategy_fast_vidya_period, strategy_fast_cmo_period, 2);
   const double slow_1 = VIDYAAt(PERIOD_H4, strategy_slow_vidya_period, strategy_slow_cmo_period, 1);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(close_1 <= 0.0 || close_2 <= 0.0 || fast_1 <= 0.0 || fast_2 <= 0.0 ||
      slow_1 <= 0.0 || d1_ema <= 0.0 || atr <= 0.0)
      return false;

   const bool cross_up = (close_2 <= fast_2 && close_1 > fast_1);
   const bool cross_down = (close_2 >= fast_2 && close_1 < fast_1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(cross_up && fast_1 > fast_2 && fast_1 > slow_1 && close_1 > d1_ema && ask > 0.0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(ask - strategy_initial_atr_mult * atr);
      req.tp = 0.0;
      req.reason = "CHAND_VIDYA_CROSS_H4_LONG";
      return (req.sl > 0.0);
     }

   if(cross_down && fast_1 < fast_2 && fast_1 < slow_1 && close_1 < d1_ema && bid > 0.0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(bid + strategy_initial_atr_mult * atr);
      req.tp = 0.0;
      req.reason = "CHAND_VIDYA_CROSS_H4_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || open_price <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double favorable_move = is_buy ? (market - open_price) : (open_price - market);
   if(favorable_move < strategy_trail_trigger_atr * atr)
      return;

   const double extreme = PositionExtremeSinceEntry(position_type, open_time);
   if(extreme <= 0.0)
      return;

   const double target_sl = NormalizeStrategyPrice(is_buy ? (extreme - strategy_trail_atr_mult * atr)
                                                          : (extreme + strategy_trail_atr_mult * atr));
   if(target_sl <= 0.0)
      return;

   const double current_sl = PositionGetDouble(POSITION_SL);
   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, target_sl, "chande_vidya_atr_trail");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   static datetime last_eval_bar = 0;
   static bool     cached_exit = false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
     {
      cached_exit = false;
      return false;
     }

   const datetime h4_bar = iTime(_Symbol, PERIOD_H4, 0);
   if(h4_bar <= 0)
      return false;
   if(h4_bar == last_eval_bar)
      return cached_exit;

   last_eval_bar = h4_bar;
   cached_exit = false;

   const double close_1 = CloseAt(PERIOD_H4, 1);
   const double close_2 = CloseAt(PERIOD_H4, 2);
   const double fast_1 = VIDYAAt(PERIOD_H4, strategy_fast_vidya_period, strategy_fast_cmo_period, 1);
   const double fast_2 = VIDYAAt(PERIOD_H4, strategy_fast_vidya_period, strategy_fast_cmo_period, 2);
   if(close_1 > 0.0 && close_2 > 0.0 && fast_1 > 0.0 && fast_2 > 0.0)
     {
      const bool cross_down = (close_2 >= fast_2 && close_1 < fast_1);
     const bool cross_up = (close_2 <= fast_2 && close_1 > fast_1);
     if(position_type == POSITION_TYPE_BUY && cross_down)
        {
         cached_exit = true;
         return true;
        }
     if(position_type == POSITION_TYPE_SELL && cross_up)
        {
         cached_exit = true;
         return true;
        }
     }

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds > 0 && open_time > 0 &&
      TimeCurrent() - open_time >= strategy_max_hold_h4_bars * h4_seconds)
     {
      cached_exit = true;
      return true;
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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
