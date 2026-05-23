#property strict
#property version   "5.0"
#property description "QM5_1440 Carter TTM Wave H4"

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
input int    qm_ea_id                   = 1440;
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
input int    strategy_atr_period             = 20;
input double strategy_wavea_atr_min          = 0.20;
input double strategy_spread_atr_max         = 0.20;
input double strategy_entry_buffer_atr       = 0.15;
input double strategy_sl_atr_mult            = 2.0;
input double strategy_hard_tp_atr_mult       = 2.5;
input int    strategy_max_hold_h4_bars       = 40;
input int    strategy_reuse_guard_h4_bars    = 30;

datetime g_last_long_trigger_bar = 0;
datetime g_last_short_trigger_bar = 0;
ulong    g_managed_ticket = 0;
bool     g_tp1_done = false;
bool     g_tp2_done = false;

double Strategy_Wave(const int slow_period, const int shift)
  {
   return QM_EMA(_Symbol, PERIOD_H4, 8, shift) - QM_EMA(_Symbol, PERIOD_H4, slow_period, shift);
  }

int Strategy_Alignment(const int shift)
  {
   const double wave_a = Strategy_Wave(34, shift);
   const double wave_b = Strategy_Wave(55, shift);
   const double wave_c = Strategy_Wave(89, shift);

   if(wave_a > 0.0 && wave_b > 0.0 && wave_c > 0.0)
      return 1;
   if(wave_a < 0.0 && wave_b < 0.0 && wave_c < 0.0)
      return -1;
   return 0;
  }

bool Strategy_AccelerationAligned(const int direction)
  {
   const double a1 = Strategy_Wave(34, 1);
   const double b1 = Strategy_Wave(55, 1);
   const double c1 = Strategy_Wave(89, 1);
   const double a2 = Strategy_Wave(34, 2);
   const double b2 = Strategy_Wave(55, 2);
   const double c2 = Strategy_Wave(89, 2);

   if(direction > 0)
      return (a1 > a2 && b1 > b2 && c1 > c2);
   return (a1 < a2 && b1 < b2 && c1 < c2);
  }

bool Strategy_AlignmentFresh(const int direction)
  {
   if(Strategy_Alignment(1) != direction)
      return false;
   if(Strategy_Alignment(2) != direction)
      return true;
   return (Strategy_Alignment(3) != direction);
  }

bool Strategy_MagnitudeOrdered(const int direction)
  {
   const double wave_a = Strategy_Wave(34, 1);
   const double wave_b = Strategy_Wave(55, 1);
   const double wave_c = Strategy_Wave(89, 1);

   if(direction > 0)
      return (wave_c >= wave_b && wave_b >= wave_a);
   return (wave_c <= wave_b && wave_b <= wave_a);
  }

bool Strategy_D1BiasAgrees(const int direction)
  {
   const double ema1 = QM_EMA(_Symbol, PERIOD_D1, 34, 1);
   const double ema2 = QM_EMA(_Symbol, PERIOD_D1, 34, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   if(direction > 0)
      return (ema1 >= ema2);
   return (ema1 <= ema2);
  }

bool Strategy_ReuseGuardAllows(const int direction, const datetime trigger_bar)
  {
   const datetime last_bar = (direction > 0) ? g_last_long_trigger_bar : g_last_short_trigger_bar;
   if(last_bar <= 0 || trigger_bar <= last_bar)
      return true;

   const int period_seconds = PeriodSeconds(PERIOD_H4);
   if(period_seconds <= 0)
      return true;

   const int bars_since = (int)((trigger_bar - last_bar) / period_seconds);
   return (bars_since > strategy_reuse_guard_h4_bars);
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, double &open_price, double &volume, datetime &open_time)
  {
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

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   volume = 0.0;
   open_time = 0;
   return false;
  }

int Strategy_PositionDirection(const ENUM_POSITION_TYPE position_type)
  {
   return (position_type == POSITION_TYPE_BUY) ? 1 : -1;
  }

int Strategy_H4BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(shift < 0)
      return 0;
   return shift;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: no time-of-day restriction in the card; spread gate is ATR-scaled.
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   if((ask - bid) > strategy_spread_atr_max * atr)
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

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double volume;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, position_type, open_price, volume, open_time))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const datetime trigger_bar = iTime(_Symbol, PERIOD_H4, 1);
   const double trigger_close = iClose(_Symbol, PERIOD_H4, 1);
   if(trigger_bar <= 0 || trigger_close <= 0.0)
      return false;

   int direction = 0;
   if(Strategy_Alignment(1) > 0)
      direction = 1;
   else if(Strategy_Alignment(1) < 0)
      direction = -1;
   else
      return false;

   const double wave_a = Strategy_Wave(34, 1);
   if(MathAbs(wave_a) < strategy_wavea_atr_min * atr)
      return false;
   if(!Strategy_AccelerationAligned(direction))
      return false;
   if(!Strategy_AlignmentFresh(direction))
      return false;
   if(!Strategy_MagnitudeOrdered(direction))
      return false;
   if(!Strategy_D1BiasAgrees(direction))
      return false;
   if(!Strategy_ReuseGuardAllows(direction, trigger_bar))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(direction > 0)
     {
      if(ask > trigger_close + strategy_entry_buffer_atr * atr)
         return false;
      req.type = QM_BUY;
      req.price = ask;
      req.sl = ask - strategy_sl_atr_mult * atr;
      req.reason = "TTM_WAVE_LONG";
      g_last_long_trigger_bar = trigger_bar;
      return true;
     }

   if(bid < trigger_close - strategy_entry_buffer_atr * atr)
      return false;
   req.type = QM_SELL;
   req.price = bid;
   req.sl = bid + strategy_sl_atr_mult * atr;
   req.reason = "TTM_WAVE_SHORT";
   g_last_short_trigger_bar = trigger_bar;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double volume;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, volume, open_time))
     {
      g_managed_ticket = 0;
      g_tp1_done = false;
      g_tp2_done = false;
      return;
     }

   if(ticket != g_managed_ticket)
     {
      g_managed_ticket = ticket;
      g_tp1_done = false;
      g_tp2_done = false;
     }

   const int direction = Strategy_PositionDirection(position_type);
   const double wave_a = Strategy_Wave(34, 1);
   const double wave_b = Strategy_Wave(55, 1);

   if(!g_tp1_done && ((direction > 0 && wave_a < 0.0) || (direction < 0 && wave_a > 0.0)))
     {
      if(QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL))
         g_tp1_done = true;
      return;
     }

   if(!g_tp2_done && ((direction > 0 && wave_b < 0.0) || (direction < 0 && wave_b > 0.0)))
     {
      if(QM_TM_SelectPosition(ticket))
        {
         const double remaining = PositionGetDouble(POSITION_VOLUME);
         if(QM_TM_PartialClose(ticket, remaining * 0.5, QM_EXIT_PARTIAL))
            g_tp2_done = true;
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double volume;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, volume, open_time))
      return false;

   const int direction = Strategy_PositionDirection(position_type);
   const double wave_c = Strategy_Wave(89, 1);
   if((direction > 0 && wave_c < 0.0) || (direction < 0 && wave_c > 0.0))
      return true;

   const int bars_held = Strategy_H4BarsHeld(open_time);
   if(bars_held >= strategy_max_hold_h4_bars)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || open_price <= 0.0)
      return false;

   const double market_price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return false;

   const double favorable_move = (direction > 0) ? (market_price - open_price)
                                                 : (open_price - market_price);
   if(!g_tp1_done && !g_tp2_done && bars_held >= strategy_max_hold_h4_bars &&
      favorable_move > strategy_hard_tp_atr_mult * atr)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: central QM news mode carries the card's high-impact pause.
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
