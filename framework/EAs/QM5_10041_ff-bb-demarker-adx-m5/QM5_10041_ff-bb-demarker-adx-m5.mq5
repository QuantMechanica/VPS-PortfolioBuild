#property strict
#property version   "5.0"
#property description "QM5_10041 ForexFactory 5-Min Bollinger DeMarker ADX Breakout"

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
input int    qm_ea_id                   = 10041;
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
input int    strategy_bb_period          = 14;
input double strategy_bb_deviation       = 2.0;
input int    strategy_demarker_period    = 14;
input double strategy_demarker_high      = 0.70;
input double strategy_demarker_low       = 0.30;
input int    strategy_adx_period         = 14;
input double strategy_adx_min            = 40.0;
input int    strategy_ema_period         = 14;
input int    strategy_h4_atr_period      = 100;
input double strategy_sl_atr_mult        = 10.0;
input int    strategy_tp_pips            = 20;
input int    strategy_band_window_pips   = 5;
input int    strategy_max_sl_pips        = 600;
input int    strategy_d1_atr_period      = 14;
input double strategy_d1_atr_cap_mult    = 6.0;
input int    strategy_time_stop_days     = 5;
input int    strategy_max_spread_points  = 35;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute_of_week = (dt.day_of_week * 24 * 60) + (dt.hour * 60) + dt.min;
   if(minute_of_week < 15)
      return true;
   const int friday_end = (5 * 24 * 60) - 15;
   if(minute_of_week >= friday_end)
      return true;

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

double Strategy_DeMarker(const int period, const int shift)
  {
   if(period <= 0 || shift < 1)
      return EMPTY_VALUE;

   double demax_sum = 0.0;
   double demin_sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double high_now = iHigh(_Symbol, _Period, i);
      const double high_prev = iHigh(_Symbol, _Period, i + 1);
      const double low_now = iLow(_Symbol, _Period, i);
      const double low_prev = iLow(_Symbol, _Period, i + 1);
      if(high_now <= 0.0 || high_prev <= 0.0 || low_now <= 0.0 || low_prev <= 0.0)
         return EMPTY_VALUE;

      if(high_now > high_prev)
         demax_sum += high_now - high_prev;
      if(low_now < low_prev)
         demin_sum += low_prev - low_now;
     }

   const double denom = demax_sum + demin_sum;
   if(denom <= 0.0)
      return 0.5;
   return demax_sum / denom;
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

   const double pip = Strategy_PipSize();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip <= 0.0 || point <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_LOW);
   const double lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_HIGH);
   const double demarker = Strategy_DeMarker(strategy_demarker_period, 1);
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(close1 <= 0.0 || upper <= 0.0 || lower <= 0.0 || demarker == EMPTY_VALUE || adx <= 0.0)
      return false;

   if(adx < strategy_adx_min)
      return false;
   if(!(demarker > strategy_demarker_high || demarker < strategy_demarker_low))
      return false;

   const double h4_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_h4_atr_period, 1);
   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_d1_atr_period, 1);
   if(h4_atr <= 0.0 || d1_atr <= 0.0)
      return false;

   const double sl_dist = h4_atr * strategy_sl_atr_mult;
   if(sl_dist <= 0.0)
      return false;
   if(sl_dist > strategy_max_sl_pips * pip)
      return false;
   if(sl_dist > strategy_d1_atr_cap_mult * d1_atr)
      return false;

   const double window = strategy_band_window_pips * pip;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(MathAbs(close1 - upper) <= window)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ask - sl_dist, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.tp = NormalizeDouble(ask + (strategy_tp_pips * pip), (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.reason = "FF_BB_DEMARKER_ADX_LONG";
      return true;
     }

   if(MathAbs(close1 - lower) <= window)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(bid + sl_dist, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.tp = NormalizeDouble(bid - (strategy_tp_pips * pip), (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.reason = "FF_BB_DEMARKER_ADX_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, partial close, or break-even rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_TYPICAL);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(ema <= 0.0 || close1 <= 0.0)
      return false;

   const int max_hold_seconds = strategy_time_stop_days * 24 * 60 * 60;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(max_hold_seconds > 0 && TimeCurrent() - opened >= max_hold_seconds)
         return true;

      const double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit <= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 < ema)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 > ema)
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
