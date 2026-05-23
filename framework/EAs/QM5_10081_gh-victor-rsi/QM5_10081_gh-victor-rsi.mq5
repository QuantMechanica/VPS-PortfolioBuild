#property strict
#property version   "5.0"
#property description "QM5_10081 GitHub Victor Algo RSI Divergence Reversal"

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
input int    qm_ea_id                   = 10081;
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
input int    strategy_rsi_period        = 14;
input int    strategy_min_div_bars      = 20;
input int    strategy_max_div_bars      = 100;
input double strategy_rsi_buy_level     = 30.0;
input double strategy_rsi_sell_level    = 70.0;
input double strategy_trail_percent     = 1.0;
input int    strategy_extreme_radius    = 2;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_LocalLow(const int shift, const int radius)
  {
   const double v = iLow(_Symbol, _Period, shift);
   if(v <= 0.0)
      return false;
   for(int k = 1; k <= radius; ++k)
     {
      const double left = iLow(_Symbol, _Period, shift + k);
      const double right = iLow(_Symbol, _Period, shift - k);
      if(left <= 0.0 || right <= 0.0)
         return false;
      if(v > left || v > right)
         return false;
     }
   return true;
  }

bool Strategy_LocalHigh(const int shift, const int radius)
  {
   const double v = iHigh(_Symbol, _Period, shift);
   if(v <= 0.0)
      return false;
   for(int k = 1; k <= radius; ++k)
     {
      const double left = iHigh(_Symbol, _Period, shift + k);
      const double right = iHigh(_Symbol, _Period, shift - k);
      if(left <= 0.0 || right <= 0.0)
         return false;
      if(v < left || v < right)
         return false;
     }
   return true;
  }

bool Strategy_TradedDuringPriorBar()
  {
   const datetime prior_bar_open = iTime(_Symbol, _Period, 1);
   const datetime current_bar_open = iTime(_Symbol, _Period, 0);
   if(prior_bar_open <= 0 || current_bar_open <= prior_bar_open)
      return false;

   if(!HistorySelect(prior_bar_open, current_bar_open))
      return false;

   const long magic = (long)QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
     }
   return false;
  }

bool Strategy_HasDivergence(const bool bullish)
  {
   const int max_lookback = MathMax(strategy_min_div_bars + strategy_extreme_radius + 2,
                                    MathMin(strategy_max_div_bars, 100));
   const int min_sep = MathMax(1, strategy_min_div_bars);
   const int radius = MathMax(1, MathMin(strategy_extreme_radius, 5));
   if(Bars(_Symbol, _Period) <= max_lookback + radius + 5)
      return false;

   int extrema[32];
   double rsi_cache[128];
   int extrema_count = 0;
   ArrayInitialize(rsi_cache, EMPTY_VALUE);

   for(int shift = 2 + radius; shift <= max_lookback - radius && extrema_count < 32; ++shift)
     {
      const bool is_extreme = bullish ? Strategy_LocalLow(shift, radius)
                                      : Strategy_LocalHigh(shift, radius);
      if(!is_extreme)
         continue;

      const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, shift);
      if(rsi == EMPTY_VALUE || rsi <= 0.0)
         continue;
      if(bullish && rsi >= strategy_rsi_buy_level)
         continue;
      if(!bullish && rsi <= strategy_rsi_sell_level)
         continue;

      extrema[extrema_count] = shift;
      rsi_cache[shift] = rsi;
      ++extrema_count;
     }

   for(int recent_idx = 0; recent_idx < extrema_count; ++recent_idx)
     {
      const int recent_shift = extrema[recent_idx];
      for(int older_idx = recent_idx + 1; older_idx < extrema_count; ++older_idx)
        {
         const int older_shift = extrema[older_idx];
         const int separation = older_shift - recent_shift;
         if(separation < min_sep || separation > max_lookback)
            continue;

         const double recent_rsi = rsi_cache[recent_shift];
         const double older_rsi = rsi_cache[older_shift];
         if(recent_rsi == EMPTY_VALUE || older_rsi == EMPTY_VALUE)
            continue;

         if(bullish)
           {
            const double recent_low = iLow(_Symbol, _Period, recent_shift);
            const double older_low = iLow(_Symbol, _Period, older_shift);
            if(recent_low < older_low && recent_rsi > older_rsi)
               return true;
           }
         else
           {
            const double recent_high = iHigh(_Symbol, _Period, recent_shift);
            const double older_high = iHigh(_Symbol, _Period, older_shift);
            if(recent_high > older_high && recent_rsi < older_rsi)
               return true;
           }
        }
     }

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

   if(Strategy_TradedDuringPriorBar())
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(open1 <= 0.0 || close1 <= 0.0 || ask <= 0.0 || bid <= 0.0 || strategy_trail_percent <= 0.0)
      return false;

   const double pct = strategy_trail_percent / 100.0;
   if(close1 > open1 && Strategy_HasDivergence(true))
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask * (1.0 - pct);
      req.tp = 0.0;
      req.reason = "RSI_BULLISH_DIVERGENCE";
      return true;
     }

   if(close1 < open1 && Strategy_HasDivergence(false))
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid * (1.0 + pct);
      req.tp = 0.0;
      req.reason = "RSI_BEARISH_DIVERGENCE";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_trail_percent <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double pct = strategy_trail_percent / 100.0;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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
      const double current_sl = PositionGetDouble(POSITION_SL);
      double target_sl = 0.0;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         target_sl = NormalizeDouble(bid * (1.0 - pct), _Digits);
         if(current_sl <= 0.0 || target_sl > current_sl + point * 0.5)
            QM_TM_MoveSL(ticket, target_sl, "percent_trailing_stop");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         target_sl = NormalizeDouble(bid * (1.0 + pct), _Digits);
         if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
            QM_TM_MoveSL(ticket, target_sl, "percent_trailing_stop");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
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
