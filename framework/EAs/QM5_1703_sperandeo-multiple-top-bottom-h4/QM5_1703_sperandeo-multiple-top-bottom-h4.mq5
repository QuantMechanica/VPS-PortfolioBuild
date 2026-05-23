#property strict
#property version   "5.0"
#property description "QM5_1703 Sperandeo Multiple Top/Bottom H4"

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
input int    qm_ea_id                   = 1703;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_H4;
input int    strategy_pivot_k           = 3;
input int    strategy_lookback_bars     = 50;
input int    strategy_min_rejections    = 3;
input int    strategy_atr_period        = 14;
input double strategy_zone_atr_mult     = 0.5;
input double strategy_spread_atr_mult   = 0.3;
input double strategy_break_atr_mult    = 0.5;
input double strategy_sl_atr_mult       = 0.5;
input double strategy_projection_mult   = 1.5;
input int    strategy_d1_sma_period     = 50;
input int    strategy_cooldown_bars     = 12;
input int    strategy_time_stop_bars    = 30;

struct QM1703_Zone
  {
   bool   valid;
   int    direction;
   double top;
   double bot;
   double width;
   double atr;
   int    rejection_count;
  };

datetime g_qm1703_last_long_entry_bar = 0;
datetime g_qm1703_last_short_entry_bar = 0;
datetime g_qm1703_last_exit_eval_bar = 0;
bool     g_qm1703_exit_cached = false;

bool QM1703_IsPivotHigh(const int shift)
  {
   const double h = iHigh(_Symbol, strategy_signal_tf, shift);
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= strategy_pivot_k; ++k)
     {
      if(h <= iHigh(_Symbol, strategy_signal_tf, shift - k))
         return false;
      if(h <= iHigh(_Symbol, strategy_signal_tf, shift + k))
         return false;
     }
   return true;
  }

bool QM1703_IsPivotLow(const int shift)
  {
   const double l = iLow(_Symbol, strategy_signal_tf, shift);
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= strategy_pivot_k; ++k)
     {
      if(l >= iLow(_Symbol, strategy_signal_tf, shift - k))
         return false;
      if(l >= iLow(_Symbol, strategy_signal_tf, shift + k))
         return false;
     }
   return true;
  }

int QM1703_BarsSince(const datetime then_bar)
  {
   if(then_bar <= 0)
      return 1000000;
   const int shift = iBarShift(_Symbol, strategy_signal_tf, then_bar, true);
   if(shift < 0)
      return 1000000;
   return shift;
  }

bool QM1703_FindZone(const int direction, QM1703_Zone &zone)
  {
   zone.valid = false;
   zone.direction = direction;
   zone.top = 0.0;
   zone.bot = 0.0;
   zone.width = 0.0;
   zone.atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   zone.rejection_count = 0;

   if(strategy_pivot_k < 1 || strategy_lookback_bars < strategy_min_rejections ||
      strategy_min_rejections < 3 || zone.atr <= 0.0)
      return false;

   double pivots[128];
   int found = 0;
   const int max_scan = MathMin(strategy_lookback_bars, 120);
   for(int shift = strategy_pivot_k + 1; shift <= max_scan && found < 128; ++shift)
     {
      const bool is_pivot = (direction > 0) ? QM1703_IsPivotLow(shift) : QM1703_IsPivotHigh(shift);
      if(!is_pivot)
         continue;
      pivots[found] = (direction > 0) ? iLow(_Symbol, strategy_signal_tf, shift)
                                      : iHigh(_Symbol, strategy_signal_tf, shift);
      found++;
     }

   if(found < strategy_min_rejections)
      return false;

   double ztop = pivots[0];
   double zbot = pivots[0];
   for(int i = 1; i < strategy_min_rejections; ++i)
     {
      ztop = MathMax(ztop, pivots[i]);
      zbot = MathMin(zbot, pivots[i]);
     }

   int rejections = 0;
   for(int i = 0; i < found; ++i)
      if(pivots[i] >= zbot && pivots[i] <= ztop)
         rejections++;

   const double width = ztop - zbot;
   if(rejections < strategy_min_rejections || width <= 0.0 ||
      width > strategy_zone_atr_mult * zone.atr)
      return false;

   zone.valid = true;
   zone.top = ztop;
   zone.bot = zbot;
   zone.width = width;
   zone.rejection_count = rejections;
   return true;
  }

bool QM1703_HasBreak(const QM1703_Zone &zone)
  {
   if(!zone.valid || zone.atr <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(close1 <= 0.0)
      return false;
   if(zone.direction > 0)
      return close1 > zone.top + strategy_break_atr_mult * zone.atr;
   return close1 < zone.bot - strategy_break_atr_mult * zone.atr;
  }

bool QM1703_TrendAllows(const int direction)
  {
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   if(d1_close <= 0.0 || d1_sma <= 0.0)
      return false;
   if(direction > 0)
      return d1_close > d1_sma;
   return d1_close < d1_sma;
  }

bool QM1703_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
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

   if(strategy_signal_tf != PERIOD_H4)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   QM1703_Zone top_zone;
   QM1703_Zone bottom_zone;
   const bool has_top = QM1703_FindZone(-1, top_zone) && QM1703_HasBreak(top_zone);
   const bool has_bottom = QM1703_FindZone(1, bottom_zone) && QM1703_HasBreak(bottom_zone);

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bar_time <= 0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(has_bottom && QM1703_TrendAllows(1) &&
      QM1703_BarsSince(g_qm1703_last_long_entry_bar) > strategy_cooldown_bars)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = bottom_zone.bot - strategy_sl_atr_mult * bottom_zone.atr;
      req.tp = ask + strategy_projection_mult * bottom_zone.width;
      req.reason = "QM5_1703_MULTIPLE_BOTTOM_BREAK";
      g_qm1703_last_long_entry_bar = bar_time;
      return req.sl > 0.0 && req.tp > ask;
     }

   if(has_top && QM1703_TrendAllows(-1) &&
      QM1703_BarsSince(g_qm1703_last_short_entry_bar) > strategy_cooldown_bars)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = top_zone.top + strategy_sl_atr_mult * top_zone.atr;
      req.tp = bid - strategy_projection_mult * top_zone.width;
      req.reason = "QM5_1703_MULTIPLE_TOP_BREAK";
      g_qm1703_last_short_entry_bar = bar_time;
      return req.sl > bid && req.tp > 0.0 && req.tp < bid;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP plus time/opposite-signal exits only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!QM1703_SelectOurPosition(ticket, ptype, open_time))
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0)
      return false;
   if(bar_time == g_qm1703_last_exit_eval_bar)
      return g_qm1703_exit_cached;

   g_qm1703_last_exit_eval_bar = bar_time;
   g_qm1703_exit_cached = false;

   const int open_shift = iBarShift(_Symbol, strategy_signal_tf, open_time, false);
   if(open_shift >= strategy_time_stop_bars)
     {
      g_qm1703_exit_cached = true;
      return true;
     }

   QM1703_Zone opposite_zone;
   const int opposite_direction = (ptype == POSITION_TYPE_BUY) ? -1 : 1;
   if(QM1703_FindZone(opposite_direction, opposite_zone) &&
      QM1703_HasBreak(opposite_zone))
     {
      g_qm1703_exit_cached = true;
      return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode))
      return true;
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
