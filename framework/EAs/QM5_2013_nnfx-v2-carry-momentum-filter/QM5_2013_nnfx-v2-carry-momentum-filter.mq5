#property strict
#property version   "5.0"
#property description "QM5_2013 NNFX V2 Carry Momentum Filter"

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
input int    qm_ea_id                   = 2013;
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
input int    strategy_d1_ema_period      = 100;
input int    strategy_h4_ema_period      = 55;
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input int    strategy_ssl_period         = 10;
input int    strategy_momentum_bars_d1   = 60;
input double strategy_short_momentum_max = -4.0;
input int    strategy_min_flat_h4_bars   = 8;
input int    strategy_atr_period         = 14;
input double strategy_initial_atr_mult   = 2.5;
input double strategy_trail_atr_mult     = 3.0;
input double strategy_be_trigger_r       = 1.0;
input double strategy_trail_trigger_r    = 2.0;
input int    strategy_max_hold_h4_bars   = 60;

int g_flat_h4_bars = 9999;

bool HasOurPosition(ulong &ticket, ENUM_POSITION_TYPE &type, double &open_price, datetime &open_time)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
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
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double D1MomentumPct(const int shift)
  {
   const int lookback_shift = shift + strategy_momentum_bars_d1;
   const double now_close = iClose(_Symbol, PERIOD_D1, shift);
   const double then_close = iClose(_Symbol, PERIOD_D1, lookback_shift);
   if(now_close <= 0.0 || then_close <= 0.0)
      return 0.0;
   return 100.0 * (now_close - then_close) / then_close;
  }

bool LongSetup(const int shift)
  {
   const double d1_close = iClose(_Symbol, PERIOD_D1, shift);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, shift);
   const double h4_close = iClose(_Symbol, PERIOD_H4, shift);
   const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, shift);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);

   return (d1_close > 0.0 &&
           d1_ema > 0.0 &&
           h4_close > 0.0 &&
           h4_ema > 0.0 &&
           d1_close > d1_ema &&
           h4_close > h4_ema &&
           macd_main > macd_signal);
  }

bool SSLBearish(const int shift)
  {
   const double h4_close = iClose(_Symbol, PERIOD_H4, shift);
   const double ssl_low = QM_SMA(_Symbol, PERIOD_H4, strategy_ssl_period, shift, PRICE_LOW);
   return (h4_close > 0.0 && ssl_low > 0.0 && h4_close < ssl_low);
  }

bool ShortSetup(const int shift)
  {
   const double momentum = D1MomentumPct(shift);
   const double h4_close = iClose(_Symbol, PERIOD_H4, shift);
   const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, shift);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);

   return (momentum < strategy_short_momentum_max &&
           h4_close > 0.0 &&
           h4_ema > 0.0 &&
           h4_close < h4_ema &&
           macd_main < macd_signal &&
           SSLBearish(shift));
  }

double CurrentRiskDistance()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_initial_atr_mult <= 0.0)
      return 0.0;
   return atr * strategy_initial_atr_mult;
  }

void UpdateFlatBarCount()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   datetime open_time;
   if(HasOurPosition(ticket, type, open_price, open_time))
     {
      g_flat_h4_bars = 0;
      return;
     }

   if(g_flat_h4_bars < 1000000)
      g_flat_h4_bars++;
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
   UpdateFlatBarCount();
   if(g_flat_h4_bars < strategy_min_flat_h4_bars)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const bool long_now = LongSetup(1);
   const bool long_prev = LongSetup(2);
   const bool short_now = ShortSetup(1);
   const bool short_prev = ShortSetup(2);
   if(!long_now && !short_now)
      return false;

   int side_code = -1;
   if(long_now && !long_prev)
      side_code = (int)QM_BUY;
   else if(short_now && !short_prev)
      side_code = (int)QM_SELL;
   if(side_code < 0)
      return false;

   const QM_OrderType side = (QM_OrderType)side_code;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_initial_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.reason = (side == QM_BUY) ? "NNFX_CARRY_MOM_LONG" : "NNFX_CARRY_MOM_SHORT_EXCEPTION";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   datetime open_time;
   if(!HasOurPosition(ticket, type, open_price, open_time))
      return;

   const bool is_buy = (type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double risk_distance = CurrentRiskDistance();
   if(market <= 0.0 || open_price <= 0.0 || risk_distance <= 0.0)
      return;

   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(moved >= risk_distance * strategy_be_trigger_r)
      QM_TM_MoveSL(ticket, open_price, "nnfx_move_to_breakeven_after_1r");
   if(moved >= risk_distance * strategy_trail_trigger_r)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   datetime open_time;
   if(!HasOurPosition(ticket, type, open_price, open_time))
      return false;

   const bool is_buy = (type == POSITION_TYPE_BUY);
   const double h4_close = iClose(_Symbol, PERIOD_H4, 1);
   const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, 1);
   if(h4_close <= 0.0 || h4_ema <= 0.0)
      return false;

   if(is_buy && h4_close < h4_ema)
      return true;
   if(!is_buy && h4_close > h4_ema)
      return true;

   const double momentum = D1MomentumPct(1);
   if(is_buy && momentum < 0.0)
      return true;
   if(!is_buy && momentum >= 0.0)
      return true;

   const int open_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(open_shift >= strategy_max_hold_h4_bars)
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
