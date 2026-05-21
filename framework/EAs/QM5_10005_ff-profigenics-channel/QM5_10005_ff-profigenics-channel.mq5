#property strict
#property version   "5.0"
#property description "QM5_10005 ForexFactory Profigenics MTF Channel Pullback"

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
input int    qm_ea_id                   = 10005;
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
input ENUM_TIMEFRAMES strategy_htf      = PERIOD_H1;
input int    strategy_channel_period    = 3;
input int    strategy_bias_period       = 34;
input int    strategy_director_fast     = 5;
input int    strategy_director_slow     = 21;
input int    strategy_atr_period        = 14;
input double strategy_max_atr_mult      = 3.0;
input double strategy_min_sl_pips       = 8.0;
input double strategy_rr                = 1.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Time, spread, and news filters: card defines no extra time/spread block;
   // news is handled by QM_NewsAllowsTrade plus Strategy_NewsFilterHook.
   return false;
  }

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

bool Strategy_Channel(const ENUM_TIMEFRAMES tf,
                      const int shift,
                      double &channel_high,
                      double &channel_low,
                      double &bias,
                      double &director_fast,
                      double &director_slow)
  {
   channel_high = QM_SMA(_Symbol, tf, strategy_channel_period, shift, PRICE_HIGH);
   channel_low = QM_SMA(_Symbol, tf, strategy_channel_period, shift, PRICE_LOW);
   bias = QM_EMA(_Symbol, tf, strategy_bias_period, shift, PRICE_OPEN);
   director_fast = QM_SMA(_Symbol, tf, strategy_director_fast, shift, PRICE_CLOSE);
   director_slow = QM_EMA(_Symbol, tf, strategy_director_slow, shift, PRICE_CLOSE);

   return (channel_high > 0.0 &&
           channel_low > 0.0 &&
           bias > 0.0 &&
           director_fast > 0.0 &&
           director_slow > 0.0 &&
           channel_high > channel_low);
  }

bool Strategy_HasOpenPosition()
  {
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
      return true;
     }
   return false;
  }

bool Strategy_StopDistanceAllowed(const double entry_price, const double sl_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pip = Strategy_PipSize();
   if(point <= 0.0 || pip <= 0.0 || entry_price <= 0.0 || sl_price <= 0.0)
      return false;

   const double distance = MathAbs(entry_price - sl_price);
   const double min_distance = strategy_min_sl_pips * pip;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   return (distance >= min_distance && distance <= strategy_max_atr_mult * atr);
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

   if(Strategy_HasOpenPosition())
      return false;

   double htf_high, htf_low, htf_bias, htf_fast, htf_slow;
   double ltf_high, ltf_low, ltf_bias, ltf_fast, ltf_slow;
   if(!Strategy_Channel(strategy_htf, 1, htf_high, htf_low, htf_bias, htf_fast, htf_slow))
      return false;
   if(!Strategy_Channel((ENUM_TIMEFRAMES)_Period, 1, ltf_high, ltf_low, ltf_bias, ltf_fast, ltf_slow))
      return false;
   if(htf_fast <= 0.0 || htf_slow <= 0.0)
      return false;

   const double close_htf = iClose(_Symbol, strategy_htf, 1);
   const double close_ltf = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double low_ltf = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double high_ltf = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   if(close_htf <= 0.0 || close_ltf <= 0.0 || low_ltf <= 0.0 || high_ltf <= 0.0)
      return false;

   const double width = ltf_high - ltf_low;
   if(width <= 0.0)
      return false;

   const bool htf_long = (htf_low > htf_bias && close_htf > htf_low);
   const bool ltf_long = (ltf_low > ltf_bias && close_ltf > ltf_low && ltf_fast > ltf_slow && low_ltf <= ltf_low);
   if(htf_long && ltf_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = ltf_low - width;
      if(!Strategy_StopDistanceAllowed(entry, sl))
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = entry + (entry - sl) * strategy_rr;
      req.reason = "PROFIGENICS_LONG_CHANNEL_TOUCH";
      return true;
     }

   const bool htf_short = (htf_high < htf_bias && close_htf < htf_high);
   const bool ltf_short = (ltf_high < ltf_bias && close_ltf < ltf_high && ltf_fast < ltf_slow && high_ltf >= ltf_high);
   if(htf_short && ltf_short)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = ltf_high + width;
      if(!Strategy_StopDistanceAllowed(entry, sl))
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = entry - (sl - entry) * strategy_rr;
      req.reason = "PROFIGENICS_SHORT_CHANNEL_TOUCH";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   double ltf_high, ltf_low, ltf_bias, ltf_fast, ltf_slow;
   if(!Strategy_Channel((ENUM_TIMEFRAMES)_Period, 1, ltf_high, ltf_low, ltf_bias, ltf_fast, ltf_slow))
      return;
   if(ltf_bias <= 0.0 || ltf_fast <= 0.0 || ltf_slow <= 0.0)
      return;

   const double close_ltf = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   if(close_ltf <= 0.0)
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
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(ptype == POSITION_TYPE_BUY && bid > open_price && close_ltf > ltf_high)
        {
         if(current_sl <= 0.0 || ltf_low > current_sl)
            QM_TM_MoveSL(ticket, ltf_low, "profigenics_channel_trail_long");
        }
      else if(ptype == POSITION_TYPE_SELL && ask < open_price && close_ltf < ltf_low)
        {
         if(current_sl <= 0.0 || ltf_high < current_sl)
            QM_TM_MoveSL(ticket, ltf_high, "profigenics_channel_trail_short");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   double ltf_high, ltf_low, ltf_bias, ltf_fast, ltf_slow;
   if(!Strategy_Channel((ENUM_TIMEFRAMES)_Period, 1, ltf_high, ltf_low, ltf_bias, ltf_fast, ltf_slow))
      return false;
   if(ltf_high <= 0.0 || ltf_low <= 0.0 || ltf_bias <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && ltf_fast < ltf_slow)
         return true;
      if(ptype == POSITION_TYPE_SELL && ltf_fast > ltf_slow)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
