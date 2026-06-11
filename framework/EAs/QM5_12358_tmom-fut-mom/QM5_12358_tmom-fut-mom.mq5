#property strict
#property version   "5.0"
#property description "QM5_12358 Futures Momentum Vote (ThewindMom/151-trading-strategies Strategy 10.4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12358 tmom-fut-mom
// Strategy 10.4 from ThewindMom/151-trading-strategies: multi-horizon D1
// momentum vote. Computes 20/60/120-bar return signs, sums to score [-1,1],
// enters long (score>0) or short (score<0), exits on signal reversal.
// Source: ThewindMom/151-trading-strategies, src/strategies/futures/trend_following.py (Strategy 10.4)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12358;
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
input int    strategy_short_lookback    = 20;    // D1 bars for short-horizon return
input int    strategy_medium_lookback   = 60;    // D1 bars for medium-horizon return
input int    strategy_long_lookback     = 120;   // D1 bars for long-horizon return
input int    strategy_atr_period        = 14;    // ATR period for stop-loss distance
input double strategy_atr_sl_mult       = 2.0;   // ATR multiplier for stop-loss
input int    strategy_warmup_bars       = 150;   // minimum D1 bars before first entry

// Cached per-closed-bar state (updated in EntrySignal after QM_IsNewBar())
double g_momentum_score = 0.0;
bool   g_score_ready    = false;

// -----------------------------------------------------------------------------
// Helper: check if this EA has any open position on current symbol
// -----------------------------------------------------------------------------
bool HasOurPosition(bool &has_long_out, bool &has_short_out)
  {
   has_long_out  = false;
   has_short_out = false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)  != magic)   continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)  has_long_out  = true;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) has_short_out = true;
     }
   return has_long_out || has_short_out;
  }

// -----------------------------------------------------------------------------
// Strategy_NoTradeFilter — block until warmup complete
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy_EntrySignal — compute momentum vote on closed bar, fire entry
// Called only after QM_IsNewBar() == true (skeleton guarantees this).
// iClose calls are // perf-allowed: bespoke multi-bar return computation,
// gated by QM_IsNewBar() so they run at most once per D1 bar close.
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Warmup: need strategy_warmup_bars bars, at minimum long_lookback+2 available
   int bars = Bars(_Symbol, PERIOD_CURRENT); // perf-allowed: warmup bar count, O(1) system call
   int min_bars = MathMax(strategy_warmup_bars, strategy_long_lookback + 2);
   if(bars < min_bars)
     {
      g_score_ready = false;
      return false;
     }

   // perf-allowed: bespoke structural logic — reading historical D1 closes for
   // return calculation; executed once per new D1 bar only.
   double close_now = iClose(_Symbol, PERIOD_D1, 1);                              // perf-allowed: bespoke multi-bar return, D1 new-bar gate
   double close_s   = iClose(_Symbol, PERIOD_D1, strategy_short_lookback  + 1);   // perf-allowed: bespoke multi-bar return, D1 new-bar gate
   double close_m   = iClose(_Symbol, PERIOD_D1, strategy_medium_lookback + 1);   // perf-allowed: bespoke multi-bar return, D1 new-bar gate
   double close_l   = iClose(_Symbol, PERIOD_D1, strategy_long_lookback   + 1);   // perf-allowed: bespoke multi-bar return, D1 new-bar gate

   if(close_now <= 0.0 || close_s <= 0.0 || close_m <= 0.0 || close_l <= 0.0)
      return false;

   double ret_s = (close_now - close_s) / close_s;
   double ret_m = (close_now - close_m) / close_m;
   double ret_l = (close_now - close_l) / close_l;

   int sig_s = (ret_s > 0.0) ? 1 : (ret_s < 0.0 ? -1 : 0);
   int sig_m = (ret_m > 0.0) ? 1 : (ret_m < 0.0 ? -1 : 0);
   int sig_l = (ret_l > 0.0) ? 1 : (ret_l < 0.0 ? -1 : 0);

   g_momentum_score = (sig_s + sig_m + sig_l) / 3.0;
   g_score_ready    = true;

   // Reject if any position is already open for this magic (cannot reverse intra-bar)
   bool has_long  = false;
   bool has_short = false;
   HasOurPosition(has_long, has_short);
   if(has_long || has_short)
      return false;

   // Long entry: all or majority of horizons point up
   if(g_momentum_score > 0.0)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;
      double sl_price = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      if(sl_price <= 0.0 || sl_price >= ask) return false;
      req.type              = QM_BUY;
      req.price             = 0.0;
      req.sl                = sl_price;
      req.tp                = 0.0;
      req.reason            = "TMOM_LONG";
      req.symbol_slot       = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // Short entry: all or majority of horizons point down
   if(g_momentum_score < 0.0)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;
      double sl_price = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
      if(sl_price <= 0.0 || sl_price <= bid) return false;
      req.type              = QM_SELL;
      req.price             = 0.0;
      req.sl                = sl_price;
      req.tp                = 0.0;
      req.reason            = "TMOM_SHORT";
      req.symbol_slot       = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy_ManageOpenPosition — no intra-trade management; SL is the stop
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Strategy_ExitSignal — close on signal reversal using cached momentum score
// Runs every tick; reads g_momentum_score cached by EntrySignal on last bar.
// A 1-tick delay on the new-bar close is acceptable for D1 cadence.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   if(!g_score_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)  != magic)   continue;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_momentum_score <= 0.0) return true;
      if(ptype == POSITION_TYPE_SELL && g_momentum_score >= 0.0) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy_NewsFilterHook — defer to framework two-axis news filter
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
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
