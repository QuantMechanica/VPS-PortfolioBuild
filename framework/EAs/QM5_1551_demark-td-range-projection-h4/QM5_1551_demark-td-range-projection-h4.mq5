#property strict
#property version   "5.0"
#property description "QM5_1551 DeMark TD Range Projection H4"

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
input int    qm_ea_id                   = 1551;
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
input int    strategy_td_setup_bars     = 9;
input int    strategy_td_compare_bars   = 4;
input int    strategy_setup_window_bars = 6;
input int    strategy_d1_sma_period     = 50;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.8;
input double strategy_spread_atr_mult   = 0.35;
input double strategy_tp2_range_mult    = 2.5;
input int    strategy_pt1_after_bars    = 6;
input double strategy_pt1_close_frac    = 0.75;
input int    strategy_time_stop_bars    = 18;

datetime g_last_entry_setup_time = 0;
bool     g_pt1_done              = false;

double NormalizeStrategyPrice(const double price)
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool ComputeTDRP(const int base_shift, double &proj_high, double &proj_low, double &proj_mid)
  {
   proj_high = 0.0;
   proj_low = 0.0;
   proj_mid = 0.0;
   if(base_shift < 1)
      return false;

   const double open = iOpen(_Symbol, PERIOD_H4, base_shift);
   const double high = iHigh(_Symbol, PERIOD_H4, base_shift);
   const double low = iLow(_Symbol, PERIOD_H4, base_shift);
   const double close = iClose(_Symbol, PERIOD_H4, base_shift);
   if(open <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0 || high <= low)
      return false;

   double x = 0.0;
   if(close < open)
      x = high + 2.0 * low + close;
   else if(close > open)
      x = 2.0 * high + low + close;
   else
      x = high + low + 2.0 * close;

   proj_high = NormalizeStrategyPrice(x / 2.0 - low);
   proj_low = NormalizeStrategyPrice(x / 2.0 - high);
   proj_mid = NormalizeStrategyPrice((proj_high + proj_low) / 2.0);
   return (proj_high > 0.0 && proj_low > 0.0 && proj_high > proj_low);
  }

bool SetupCompleteAt(const bool buy_setup, const int start_shift)
  {
   if(strategy_td_setup_bars < 1 || strategy_td_compare_bars < 1 || start_shift < 1)
      return false;

   for(int k = 0; k < strategy_td_setup_bars; ++k)
     {
      const int shift = start_shift + k;
      const double c_now = iClose(_Symbol, PERIOD_H4, shift);
      const double c_ref = iClose(_Symbol, PERIOD_H4, shift + strategy_td_compare_bars);
      if(c_now <= 0.0 || c_ref <= 0.0)
         return false;
      if(buy_setup)
        {
         if(!(c_now < c_ref))
            return false;
        }
      else
        {
         if(!(c_now > c_ref))
            return false;
        }
     }
   return true;
  }

bool RecentSetup(const bool buy_setup, datetime &setup_time)
  {
   setup_time = 0;
   for(int shift = 1; shift <= strategy_setup_window_bars; ++shift)
     {
      if(!SetupCompleteAt(buy_setup, shift))
         continue;
      setup_time = iTime(_Symbol, PERIOD_H4, shift);
      return (setup_time > 0);
     }
   return false;
  }

bool FindOurPosition(ulong &ticket,
                     ENUM_POSITION_TYPE &ptype,
                     double &open_price,
                     datetime &open_time,
                     double &volume)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;
   volume = 0.0;

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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      volume = PositionGetDouble(POSITION_VOLUME);
      return true;
     }

   g_pt1_done = false;
   return false;
  }

int H4BarsSince(const datetime t)
  {
   if(t <= 0)
      return 0;
   const int seconds = PeriodSeconds(PERIOD_H4);
   if(seconds <= 0)
      return 0;
   return (int)((TimeCurrent() - t) / seconds);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
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

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   double volume;
   if(FindOurPosition(ticket, ptype, open_price, open_time, volume))
      return false;

   double tdrp_high;
   double tdrp_low;
   double tdrp_mid;
   if(!ComputeTDRP(2, tdrp_high, tdrp_low, tdrp_mid))
      return false;

   const double signal_close = iClose(_Symbol, PERIOD_H4, 1);
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double range = tdrp_high - tdrp_low;
   if(signal_close <= 0.0 || d1_close <= 0.0 || d1_sma <= 0.0 || atr <= 0.0 || range <= 0.0)
      return false;

   datetime buy_setup_time;
   datetime sell_setup_time;
   const bool buy_setup = RecentSetup(true, buy_setup_time);
   const bool sell_setup = RecentSetup(false, sell_setup_time);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(buy_setup &&
      buy_setup_time != g_last_entry_setup_time &&
      signal_close > tdrp_high &&
      d1_close > d1_sma)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(ask - strategy_atr_sl_mult * atr);
      req.tp = NormalizeStrategyPrice(ask + strategy_tp2_range_mult * range);
      req.reason = "TDRP_LONG_SETUP9_BREAK";
      g_last_entry_setup_time = buy_setup_time;
      g_pt1_done = false;
      return (req.sl > 0.0 && req.tp > ask);
     }

   if(sell_setup &&
      sell_setup_time != g_last_entry_setup_time &&
      signal_close < tdrp_low &&
      d1_close < d1_sma)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(bid + strategy_atr_sl_mult * atr);
      req.tp = NormalizeStrategyPrice(bid - strategy_tp2_range_mult * range);
      req.reason = "TDRP_SHORT_SETUP9_BREAK";
      g_last_entry_setup_time = sell_setup_time;
      g_pt1_done = false;
      return (req.sl > bid && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   double volume;
   if(!FindOurPosition(ticket, ptype, open_price, open_time, volume))
      return;

   if(g_pt1_done || H4BarsSince(open_time) < strategy_pt1_after_bars)
      return;

   double tdrp_high;
   double tdrp_low;
   double tdrp_mid;
   if(!ComputeTDRP(1, tdrp_high, tdrp_low, tdrp_mid))
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool hit = false;
   if(ptype == POSITION_TYPE_BUY && tdrp_mid > open_price && bid >= tdrp_mid)
      hit = true;
   if(ptype == POSITION_TYPE_SELL && tdrp_mid < open_price && ask <= tdrp_mid)
      hit = true;
   if(!hit)
      return;

   const double lots_to_close = volume * strategy_pt1_close_frac;
   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
     {
      g_pt1_done = true;
      QM_TM_MoveSL(ticket, open_price, "TDRP_PT1_BREAK_EVEN");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   double volume;
   if(!FindOurPosition(ticket, ptype, open_price, open_time, volume))
      return false;

   return (H4BarsSince(open_time) >= strategy_time_stop_bars);
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
