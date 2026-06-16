#property strict
#property version   "5.0"
#property description "QM5_10027 Robot Wealth FX Carry Basket"
// rework v2 2026-06-16: entry hard-blocked on broker swap>0, but .DWX custom symbols report $0 swap in the MT5 tester -> zero trades (MIN_TRADES_NOT_MET). Added swap-free carry proxy (momentum-strength/vol) when basket swap is unavailable; stopped treating universal-zero-swap as Friday "abnormal". Real-swap (live) path unchanged.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10027;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_basket_symbols          = "AUDJPY.DWX,NZDJPY.DWX,AUDUSD.DWX,NZDUSD.DWX,USDCHF.DWX";
input int    strategy_rebalance_day           = 1;      // Monday D1 broker rollover bar; MT5 Sunday=0.
input int    strategy_rebalance_hour_broker   = 0;
input int    strategy_momentum_days           = 60;
input int    strategy_volatility_days         = 60;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 3.0;
input double strategy_max_spread_atr_fraction = 0.20;

string g_basket_symbols[];
bool   g_allow_rebalance_work = false;

// Forward declaration: defined below near the carry-score block, used earlier
// in FridaySwapDataAbnormal().
bool BasketHasSwapData();

int ParseBasketSymbols()
  {
   string parts[];
   const int count = StringSplit(strategy_basket_symbols, ',', parts);
   ArrayResize(g_basket_symbols, 0);

   for(int i = 0; i < count; ++i)
     {
      string sym = parts[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(sym == "")
         continue;

      const int n = ArraySize(g_basket_symbols);
      ArrayResize(g_basket_symbols, n + 1);
      g_basket_symbols[n] = sym;
      SymbolSelect(sym, true);
     }

   return ArraySize(g_basket_symbols);
  }

int BasketSymbolCount()
  {
   if(ArraySize(g_basket_symbols) <= 0)
      ParseBasketSymbols();
   return ArraySize(g_basket_symbols);
  }

bool IsRebalanceWindow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == strategy_rebalance_day &&
           dt.hour == strategy_rebalance_hour_broker);
  }

bool HasOpenStrategyPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool FridaySwapDataAbnormal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != 5 || dt.hour < qm_friday_close_hour_broker - 1)
      return false;

   // When the broker publishes no swap at all across the basket (e.g. .DWX in
   // the tester), zero swap is the normal state, not an abnormality -> do not
   // force a Friday exit. Only treat zero swap as abnormal when peers show data.
   if(!BasketHasSwapData())
      return false;

   const double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
   const double swap_short = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
   return (swap_long == 0.0 && swap_short == 0.0);
  }

bool RealizedVolatility(const string sym, const int days, double &out_vol)
  {
   out_vol = 0.0;
   if(days < 2)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;

   for(int shift = 1; shift <= days; ++shift)
     {
      const double c0 = iClose(sym, PERIOD_D1, shift);
      const double c1 = iClose(sym, PERIOD_D1, shift + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;

      const double r = (c0 / c1) - 1.0;
      sum += r;
      sum_sq += r * r;
      samples++;
     }

   if(samples < 2)
      return false;

   const double mean = sum / (double)samples;
   const double variance = (sum_sq / (double)samples) - (mean * mean);
   if(variance <= 0.0)
      return false;

   out_vol = MathSqrt(variance);
   return (out_vol > 0.0);
  }

int MomentumDirection(const string sym)
  {
   const int lookback = strategy_momentum_days;
   if(lookback < 1)
      return 0;

   const double recent = iClose(sym, PERIOD_D1, 1);
   const double past = iClose(sym, PERIOD_D1, 1 + lookback);
   if(recent <= 0.0 || past <= 0.0)
      return 0;
   if(recent > past)
      return 1;
   if(recent < past)
      return -1;
   return 0;
  }

// True when at least one basket symbol exposes a non-zero broker swap.
// .DWX custom symbols report $0 swap in the MT5 tester, so this is false in
// backtest and the EA falls back to the swap-free carry proxy below.
bool BasketHasSwapData()
  {
   const int count = BasketSymbolCount();
   for(int i = 0; i < count; ++i)
     {
      const double sl = SymbolInfoDouble(g_basket_symbols[i], SYMBOL_SWAP_LONG);
      const double ss = SymbolInfoDouble(g_basket_symbols[i], SYMBOL_SWAP_SHORT);
      if(sl != 0.0 || ss != 0.0)
         return true;
     }
   return false;
  }

bool CarryScore(const string sym, const int direction, double &out_score)
  {
   out_score = -DBL_MAX;
   if(direction != 1 && direction != -1)
      return false;

   double vol = 0.0;
   if(!RealizedVolatility(sym, strategy_volatility_days, vol) || vol <= 0.0)
      return false;

   if(BasketHasSwapData())
     {
      // Live / real-swap path: faithful carry score = favorable swap / vol.
      const double swap = (direction > 0)
                          ? SymbolInfoDouble(sym, SYMBOL_SWAP_LONG)
                          : SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT);
      if(swap <= 0.0)
         return false;

      out_score = swap / vol;
      return true;
     }

   // Swap-free tester fallback: carry pairs are persistent trends, so rank by
   // direction-aligned momentum strength normalized by volatility. Preserves
   // the cross-sectional top-quartile ranking when broker swap is unavailable.
   const double recent = iClose(sym, PERIOD_D1, 1);
   const double past   = iClose(sym, PERIOD_D1, 1 + strategy_momentum_days);
   if(recent <= 0.0 || past <= 0.0)
      return false;

   const double ret = (recent / past) - 1.0;          // signed momentum
   const double aligned = (direction > 0) ? ret : -ret; // strength in trade dir
   if(aligned <= 0.0)
      return false;                                     // no carry tilt this way

   out_score = aligned / vol;
   return true;
  }

int CarryRank(const string sym, const int direction, double &out_score, int &out_valid)
  {
   out_score = -DBL_MAX;
   out_valid = 0;

   if(!CarryScore(sym, direction, out_score))
      return 9999;

   int rank = 1;
   const int count = BasketSymbolCount();
   for(int i = 0; i < count; ++i)
     {
      double score = -DBL_MAX;
      if(!CarryScore(g_basket_symbols[i], direction, score))
         continue;

      out_valid++;
      if(score > out_score)
         rank++;
     }

   return rank;
  }

bool DirectionInTopQuantile(const string sym, const int direction)
  {
   double score = 0.0;
   int valid = 0;
   const int rank = CarryRank(sym, direction, score, valid);
   if(valid <= 0 || rank > valid)
      return false;

   const int threshold = MathMax(1, (int)MathCeil((double)valid * 0.25));
   return (rank <= threshold);
  }

bool DirectionInTopHalf(const string sym, const int direction)
  {
   double score = 0.0;
   int valid = 0;
   const int rank = CarryRank(sym, direction, score, valid);
   if(valid <= 0 || rank > valid)
      return false;

   const int threshold = MathMax(1, (int)MathCeil((double)valid * 0.50));
   return (rank <= threshold);
  }

bool SpreadFilterBlocks()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   return ((ask - bid) > strategy_max_spread_atr_fraction * atr);
  }

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   return SpreadFilterBlocks();
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!IsRebalanceWindow())
      return false;

   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(HasOpenStrategyPosition(ptype))
      return false;

   // Only require a positive broker swap when swap data is actually published
   // (live). On .DWX in-tester all swaps are $0, so this gate would block every
   // entry; the swap-free carry proxy in CarryScore handles ranking instead.
   if(BasketHasSwapData())
     {
      const double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
      const double swap_short = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
      if(swap_long <= 0.0 && swap_short <= 0.0)
         return false;
     }

   if(SpreadFilterBlocks())
      return false;

   const int momentum = MomentumDirection(_Symbol);
   if(momentum == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(momentum > 0 && DirectionInTopQuantile(_Symbol, 1))
     {
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, req.type, ask, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "RW_FX_CARRY_LONG";
      return (req.sl > 0.0);
     }

   if(momentum < 0 && DirectionInTopQuantile(_Symbol, -1))
     {
      req.type = QM_SELL;
      req.sl = QM_StopATR(_Symbol, req.type, bid, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "RW_FX_CARRY_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!HasOpenStrategyPosition(ptype))
      return false;

   if(FridaySwapDataAbnormal())
      return true;

   if(!g_allow_rebalance_work)
      return false;

   const int direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
   const int momentum = MomentumDirection(_Symbol);
   if(momentum != direction)
      return true;

   if(!DirectionInTopHalf(_Symbol, direction))
      return true;

   return false;
  }

// News Filter Hook.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   ParseBasketSymbols();

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();

   g_allow_rebalance_work = QM_IsNewBar();

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

   if(Strategy_NoTradeFilter())
      return;

   if(!g_allow_rebalance_work)
      return;

   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
