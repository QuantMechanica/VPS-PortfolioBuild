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
input int    strategy_atr_period                = 14;
input int    strategy_compression_median_bars   = 80;
input int    strategy_compression_scan_bars     = 8;
input int    strategy_compression_required_bars = 3;
input int    strategy_entry_donchian_bars       = 20;
input int    strategy_exit_donchian_bars        = 10;
input int    strategy_rsi_period                = 14;
input double strategy_rsi_long_min              = 52.0;
input double strategy_rsi_short_max             = 48.0;
input double strategy_initial_atr_mult          = 2.2;
input double strategy_trail_atr_mult            = 2.5;
input double strategy_trail_trigger_r           = 1.5;
input int    strategy_time_exit_h1_bars         = 96;
input int    strategy_friday_entry_cutoff_hour  = 19;

double PriceClose(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(sym, tf, shift);
  }

double PriceHigh(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iHigh(sym, tf, shift);
  }

double PriceLow(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iLow(sym, tf, shift);
  }

int H4Bias()
  {
   const double close_h4 = PriceClose(_Symbol, PERIOD_H4, 1);
   const double ema_h4 = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, 1);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double ssl_high = QM_SMA(_Symbol, PERIOD_H4, strategy_ssl_period, 1, PRICE_HIGH);
   const double ssl_low = QM_SMA(_Symbol, PERIOD_H4, strategy_ssl_period, 1, PRICE_LOW);

   if(close_h4 <= 0.0 || ema_h4 <= 0.0 || ssl_high <= 0.0 || ssl_low <= 0.0)
      return 0;

   if(close_h4 > ema_h4 && macd_main > macd_signal && close_h4 > ssl_high)
      return 1;
   if(close_h4 < ema_h4 && macd_main < macd_signal && close_h4 < ssl_low)
      return -1;
   return 0;
  }

double MedianATR(const int first_shift, const int bars)
  {
   if(bars <= 0 || bars > 128)
      return 0.0;

   double values[128];
   int n = 0;
   for(int i = 0; i < bars; ++i)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, first_shift + i);
      if(atr <= 0.0)
         return 0.0;
      values[n++] = atr;
     }

   for(int i = 1; i < n; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }

   if((n % 2) == 1)
      return values[n / 2];
   return (values[(n / 2) - 1] + values[n / 2]) * 0.5;
  }

bool CompressionOK()
  {
   int compressed = 0;
   for(int shift = 1; shift <= strategy_compression_scan_bars; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
      const double median = MedianATR(shift + 1, strategy_compression_median_bars);
      if(atr <= 0.0 || median <= 0.0)
         return false;
      if(atr < median)
         compressed++;
     }
   return (compressed >= strategy_compression_required_bars);
  }

double HighestHigh(const ENUM_TIMEFRAMES tf, const int first_shift, const int bars)
  {
   double highest = -DBL_MAX;
   for(int i = 0; i < bars; ++i)
     {
      const double high = PriceHigh(_Symbol, tf, first_shift + i);
      if(high <= 0.0)
         return 0.0;
      if(high > highest)
         highest = high;
     }
   return highest;
  }

double LowestLow(const ENUM_TIMEFRAMES tf, const int first_shift, const int bars)
  {
   double lowest = DBL_MAX;
   for(int i = 0; i < bars; ++i)
     {
      const double low = PriceLow(_Symbol, tf, first_shift + i);
      if(low <= 0.0)
         return 0.0;
      if(low < lowest)
         lowest = low;
     }
   return lowest;
  }

bool InFinalTwoH1BarsBeforeWeeklyClose()
  {
   const datetime closed_bar_time = iTime(_Symbol, PERIOD_H1, 1);
   if(closed_bar_time <= 0)
      return false;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(closed_bar_time, dt);
   return (dt.day_of_week == FRIDAY && dt.hour >= strategy_friday_entry_cutoff_hour);
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &type, double &open_price, double &sl, datetime &opened_at, ulong &ticket)
  {
   type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   opened_at = 0;
   ticket = 0;

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

      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      ticket = t;
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

   if(InFinalTwoH1BarsBeforeWeeklyClose())
      return false;
   if(!CompressionOK())
      return false;

   const int bias = H4Bias();
   if(bias == 0)
      return false;

   const double close_h1 = PriceClose(_Symbol, PERIOD_H1, 1);
   const double rsi_h1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(close_h1 <= 0.0 || rsi_h1 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(bias > 0)
     {
      const double prior_high = HighestHigh(PERIOD_H1, 2, strategy_entry_donchian_bars);
      if(prior_high <= 0.0 || close_h1 <= prior_high || rsi_h1 <= strategy_rsi_long_min)
         return false;

      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_initial_atr_mult);
      req.reason = "NNFX_V2_H4_BIAS_H1_BREAKOUT_LONG";
      return (req.sl > 0.0);
     }

   const double prior_low = LowestLow(PERIOD_H1, 2, strategy_entry_donchian_bars);
   if(prior_low <= 0.0 || close_h1 >= prior_low || rsi_h1 >= strategy_rsi_short_max)
      return false;

   req.type = QM_SELL;
   req.price = bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_initial_atr_mult);
   req.reason = "NNFX_V2_H4_BIAS_H1_BREAKOUT_SHORT";
   return (req.sl > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE type;
   double open_price = 0.0;
   double sl = 0.0;
   datetime opened_at = 0;
   ulong ticket = 0;
   if(!SelectOurPosition(type, open_price, sl, opened_at, ticket))
      return;

   const bool is_buy = (type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double risk = MathAbs(open_price - sl);
   if(market <= 0.0 || risk <= 0.0)
      return;

   const double profit_distance = is_buy ? (market - open_price) : (open_price - market);
   if(profit_distance >= risk * strategy_trail_trigger_r)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE type;
   double open_price = 0.0;
   double sl = 0.0;
   datetime opened_at = 0;
   ulong ticket = 0;
   if(!SelectOurPosition(type, open_price, sl, opened_at, ticket))
      return false;

   const double close_h1 = PriceClose(_Symbol, PERIOD_H1, 1);
   if(close_h1 <= 0.0)
      return false;

   if(type == POSITION_TYPE_BUY)
     {
      const double exit_low = LowestLow(PERIOD_H1, 2, strategy_exit_donchian_bars);
      if(exit_low > 0.0 && close_h1 < exit_low)
         return true;
      if(H4Bias() < 0)
         return true;
     }
   else
     {
      const double exit_high = HighestHigh(PERIOD_H1, 2, strategy_exit_donchian_bars);
      if(exit_high > 0.0 && close_h1 > exit_high)
         return true;
      if(H4Bias() > 0)
         return true;
     }

   if(opened_at > 0 && TimeCurrent() - opened_at >= strategy_time_exit_h1_bars * 3600)
      return true;

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
