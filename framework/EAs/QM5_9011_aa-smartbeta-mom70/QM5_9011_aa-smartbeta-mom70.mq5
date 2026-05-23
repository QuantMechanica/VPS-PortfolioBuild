#property strict
#property version   "5.0"
#property description "QM5_9011 Alpha Architect 70/30 Momentum Smart-Beta"

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
input int    qm_ea_id                   = 9011;
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
input int    strategy_mom_recent_shift  = 2;
input int    strategy_mom_old_shift     = 13;
input int    strategy_min_monthly_bars  = 14;
input double strategy_top_pct           = 5.0;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 3.0;
input double strategy_spread_median_mult = 2.5;
input string strategy_broad_proxy       = "SP500.DWX";
input string strategy_symbol_0          = "SP500.DWX";
input string strategy_symbol_1          = "NDX.DWX";
input string strategy_symbol_2          = "WS30.DWX";

datetime g_last_entry_month = 0;
datetime g_last_exit_month = 0;
double   g_cached_median_spread_points = 0.0;

int Strategy_BasketSize()
  {
   int count = 0;
   if(StringLen(strategy_symbol_0) > 0) count++;
   if(StringLen(strategy_symbol_1) > 0) count++;
   if(StringLen(strategy_symbol_2) > 0) count++;
   return count;
  }

string Strategy_BasketSymbol(const int idx)
  {
   if(idx == 0) return strategy_symbol_0;
   if(idx == 1) return strategy_symbol_1;
   if(idx == 2) return strategy_symbol_2;
   return "";
  }

void Strategy_SelectBasketSymbols()
  {
   const int basket_size = Strategy_BasketSize();
   for(int i = 0; i < basket_size; ++i)
     {
      const string symbol = Strategy_BasketSymbol(i);
      if(StringLen(symbol) > 0)
         SymbolSelect(symbol, true);
     }
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

bool Strategy_HasMinimumMonthlyBars(const string symbol)
  {
   return (Bars(symbol, PERIOD_MN1) >= strategy_min_monthly_bars);
  }

double Strategy_Momentum(const string symbol)
  {
   if(!Strategy_HasMinimumMonthlyBars(symbol))
      return -DBL_MAX;

   const double recent_close = iClose(symbol, PERIOD_MN1, strategy_mom_recent_shift);
   const double old_close = iClose(symbol, PERIOD_MN1, strategy_mom_old_shift);
   if(recent_close <= 0.0 || old_close <= 0.0)
      return -DBL_MAX;
   return (recent_close / old_close) - 1.0;
  }

int Strategy_SleeveCount()
  {
   const int basket_size = Strategy_BasketSize();
   if(basket_size <= 0)
      return 0;
   const int selected = (int)MathCeil((double)basket_size * strategy_top_pct / 100.0);
   return MathMax(1, MathMin(basket_size, selected));
  }

int Strategy_RankOfSymbol(const string symbol)
  {
   const double target_mom = Strategy_Momentum(symbol);
   if(target_mom == -DBL_MAX)
      return 9999;

   int rank = 0;
   const int basket_size = Strategy_BasketSize();
   for(int i = 0; i < basket_size; ++i)
     {
      const string peer = Strategy_BasketSymbol(i);
      if(StringLen(peer) <= 0 || peer == symbol)
         continue;
      const double peer_mom = Strategy_Momentum(peer);
      if(peer_mom == -DBL_MAX)
         continue;
      if(peer_mom > target_mom)
         rank++;
     }
   return rank;
  }

bool Strategy_IsBroadProxy()
  {
   return (_Symbol == strategy_broad_proxy);
  }

bool Strategy_IsMomentumSleeve()
  {
   return (Strategy_RankOfSymbol(_Symbol) < Strategy_SleeveCount());
  }

void Strategy_UpdateMedianSpread()
  {
   double spreads[20];
   int samples = 0;
   for(int i = 1; i <= 20; ++i)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, i);
      if(spread <= 0)
         continue;
      spreads[samples] = (double)spread;
      samples++;
     }

   if(samples <= 0)
     {
      g_cached_median_spread_points = 0.0;
      return;
     }

   ArrayResize(spreads, samples);
   ArraySort(spreads);
   if((samples % 2) == 1)
      g_cached_median_spread_points = spreads[samples / 2];
   else
      g_cached_median_spread_points = (spreads[(samples / 2) - 1] + spreads[samples / 2]) / 2.0;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(g_cached_median_spread_points <= 0.0)
      return true;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= g_cached_median_spread_points * strategy_spread_median_mult);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return !Strategy_SpreadAllowsEntry();
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime current_month = iTime(_Symbol, PERIOD_MN1, 0);
   if(current_month <= 0 || current_month == g_last_entry_month)
      return false;
   g_last_entry_month = current_month;

   Strategy_SelectBasketSymbols();
   Strategy_UpdateMedianSpread();
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_HasMinimumMonthlyBars(_Symbol))
      return false;
   if(!Strategy_IsBroadProxy() && !Strategy_IsMomentumSleeve())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_d1 <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_d1, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = Strategy_IsBroadProxy() ? "AA_MOM70_BROAD_PROXY" : "AA_MOM70_TOP5_SLEEVE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime current_month = iTime(_Symbol, PERIOD_MN1, 0);
   if(current_month <= 0 || current_month == g_last_exit_month)
      return false;

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

      const datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(position_time >= current_month)
         continue;

      Strategy_SelectBasketSymbols();
      if(Strategy_IsBroadProxy() || !Strategy_IsMomentumSleeve())
        {
         g_last_exit_month = current_month;
         return true;
        }
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
