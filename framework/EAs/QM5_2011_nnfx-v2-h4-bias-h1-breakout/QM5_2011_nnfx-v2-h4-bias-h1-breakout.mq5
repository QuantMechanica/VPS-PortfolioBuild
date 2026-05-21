#property strict
#property version   "5.0"
#property description "QM5_2011 NNFX V2 H4 Bias H1 Breakout"

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
//   - Call raw indicator handles directly — use the QM_* readers above.
//     The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2011;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_h4_ema_period             = 100;
input int    strategy_ssl_period                = 10;
input int    strategy_macd_fast                 = 12;
input int    strategy_macd_slow                 = 26;
input int    strategy_macd_signal               = 9;
input int    strategy_h1_atr_period             = 14;
input int    strategy_compression_median_bars   = 80;
input int    strategy_compression_prior_bars    = 8;
input int    strategy_compression_required_bars = 3;
input int    strategy_entry_donchian_bars       = 20;
input int    strategy_exit_donchian_bars        = 10;
input int    strategy_rsi_period                = 14;
input double strategy_rsi_long_min              = 52.0;
input double strategy_rsi_short_max             = 48.0;
input double strategy_initial_atr_mult          = 2.2;
input double strategy_trail_trigger_r           = 1.5;
input double strategy_trail_atr_mult            = 2.5;
input int    strategy_time_exit_h1_bars         = 96;
input int    strategy_weekly_close_skip_bars    = 2;

int Strategy_SSLBias(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   for(int s = shift; s <= shift + period * 3; ++s)
     {
      const double close = iClose(sym, tf, s);
      const double sma_high = QM_SMA(sym, tf, period, s, PRICE_HIGH);
      const double sma_low = QM_SMA(sym, tf, period, s, PRICE_LOW);
      if(close <= 0.0 || sma_high <= 0.0 || sma_low <= 0.0)
         return 0;
      if(close > sma_high)
         return +1;
      if(close < sma_low)
         return -1;
     }
   return 0;
  }

int Strategy_H4Bias()
  {
   const double close = iClose(_Symbol, PERIOD_H4, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, 1);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         1);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H4,
                                             strategy_macd_fast,
                                             strategy_macd_slow,
                                             strategy_macd_signal,
                                             1);
   const int ssl = Strategy_SSLBias(_Symbol, PERIOD_H4, strategy_ssl_period, 1);
   if(close <= 0.0 || ema <= 0.0)
      return 0;
   if(close > ema && macd_main > macd_signal && ssl > 0)
      return +1;
   if(close < ema && macd_main < macd_signal && ssl < 0)
      return -1;
   return 0;
  }

double Strategy_HighestHigh(const ENUM_TIMEFRAMES tf, const int first_shift, const int bars)
  {
   double highest = -DBL_MAX;
   for(int i = first_shift; i < first_shift + bars; ++i)
     {
      const double value = iHigh(_Symbol, tf, i);
      if(value <= 0.0)
         return 0.0;
      highest = MathMax(highest, value);
     }
   return highest;
  }

double Strategy_LowestLow(const ENUM_TIMEFRAMES tf, const int first_shift, const int bars)
  {
   double lowest = DBL_MAX;
   for(int i = first_shift; i < first_shift + bars; ++i)
     {
      const double value = iLow(_Symbol, tf, i);
      if(value <= 0.0)
         return 0.0;
      lowest = MathMin(lowest, value);
     }
   return lowest;
  }

double Strategy_ATRMedian(const int first_shift, const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double values[];
   ArrayResize(values, bars);
   for(int i = 0; i < bars; ++i)
     {
      values[i] = QM_ATR(_Symbol, PERIOD_H1, strategy_h1_atr_period, first_shift + i);
      if(values[i] <= 0.0)
         return 0.0;
     }

   ArraySort(values);
   const int mid = bars / 2;
   if((bars % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool Strategy_CompressionOK()
  {
   const double median = Strategy_ATRMedian(strategy_compression_prior_bars + 1,
                                            strategy_compression_median_bars);
   if(median <= 0.0)
      return false;

   int compressed = 0;
   for(int s = 1; s <= strategy_compression_prior_bars; ++s)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_h1_atr_period, s);
      if(atr > 0.0 && atr < median)
         compressed++;
     }
   return (compressed >= strategy_compression_required_bars);
  }

bool Strategy_HasOurPosition(ulong &ticket,
                             ENUM_POSITION_TYPE &position_type,
                             double &open_price,
                             double &sl,
                             datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int Strategy_H1BarsSince(const datetime t)
  {
   if(t <= 0)
      return 0;
   return iBarShift(_Symbol, PERIOD_H1, t, false);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= qm_friday_close_hour_broker - strategy_weekly_close_skip_bars)
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

   if(_Period != PERIOD_H1)
      return false;

   const int bias = Strategy_H4Bias();
   if(bias == 0 || !Strategy_CompressionOK())
      return false;

   const double close_h1 = iClose(_Symbol, PERIOD_H1, 1);
   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_h1_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_h1 <= 0.0 || rsi <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   const double highest = Strategy_HighestHigh(PERIOD_H1, 2, strategy_entry_donchian_bars);
   const double lowest = Strategy_LowestLow(PERIOD_H1, 2, strategy_entry_donchian_bars);
   if(highest <= 0.0 || lowest <= 0.0)
      return false;

   if(bias > 0 && close_h1 > highest && rsi > strategy_rsi_long_min)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(entry - atr * strategy_initial_atr_mult, _Digits);
      req.tp = 0.0;
      req.reason = "H4_BIAS_H1_BREAKOUT_LONG";
      return (entry > 0.0 && req.sl > 0.0 && req.sl < entry);
     }

   if(bias < 0 && close_h1 < lowest && rsi < strategy_rsi_short_max)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(entry + atr * strategy_initial_atr_mult, _Digits);
      req.tp = 0.0;
      req.reason = "H4_BIAS_H1_BREAKOUT_SHORT";
      return (entry > 0.0 && req.sl > entry);
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
   double sl;
   datetime open_time;
   if(!Strategy_HasOurPosition(ticket, position_type, open_price, sl, open_time))
      return;

   if(open_price <= 0.0 || sl <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double initial_risk = MathAbs(open_price - sl);
   const double open_profit = is_buy ? (market_price - open_price)
                                     : (open_price - market_price);
   if(initial_risk > 0.0 && open_profit >= initial_risk * strategy_trail_trigger_r)
      QM_TM_TrailATR(ticket, strategy_h1_atr_period, strategy_trail_atr_mult);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double sl;
   datetime open_time;
   if(!Strategy_HasOurPosition(ticket, position_type, open_price, sl, open_time))
      return false;

   if(strategy_time_exit_h1_bars > 0 && Strategy_H1BarsSince(open_time) >= strategy_time_exit_h1_bars)
      return true;

   const int bias = Strategy_H4Bias();
   if((position_type == POSITION_TYPE_BUY && bias < 0) ||
      (position_type == POSITION_TYPE_SELL && bias > 0))
      return true;

   const double close_h1 = iClose(_Symbol, PERIOD_H1, 1);
   if(close_h1 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double lowest = Strategy_LowestLow(PERIOD_H1, 2, strategy_exit_donchian_bars);
      return (lowest > 0.0 && close_h1 < lowest);
     }

   const double highest = Strategy_HighestHigh(PERIOD_H1, 2, strategy_exit_donchian_bars);
   return (highest > 0.0 && close_h1 > highest);
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
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
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
