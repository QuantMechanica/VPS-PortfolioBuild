#property strict
#property version   "5.0"
#property description "QM5_9511 Leveraged Trading Starter 16/64 MA — Robert Carver starter system"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9511 — lt-starter-ma
// Strategy: 16/64 SMA crossover on D1. Long on bullish cross, Short on bearish
// cross. Emergency hard stop at 2.5×ATR(20,D1). Exit on opposite cross.
// Source: Robert Carver, Leveraged Trading (Harriman House, 2019), Ch. 5-6.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9511;
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
input int    strategy_fast_period       = 16;    // Fast SMA period (bars)
input int    strategy_slow_period       = 64;    // Slow SMA period (bars)
input int    strategy_atr_period        = 20;    // ATR period for emergency stop
input double strategy_atr_sl_mult       = 2.5;   // ATR multiplier for hard stop
input int    strategy_spread_lookback   = 20;    // Bars for median spread filter (days)
input double strategy_spread_mult       = 2.0;   // Max spread = mult * median spread

// -----------------------------------------------------------------------------
// Closed-bar cached state — advanced once per new D1 bar
// -----------------------------------------------------------------------------
double g_fast_prev  = 0.0;   // fast SMA on the bar before last closed bar
double g_slow_prev  = 0.0;   // slow SMA on the bar before last closed bar
double g_fast_last  = 0.0;   // fast SMA on the last closed bar
double g_slow_last  = 0.0;   // slow SMA on the last closed bar
bool   g_warmed_up  = false;  // true once 64+ valid bars have been seen

// Spread median cache
double g_spread_cache[];      // ring of recent spread values (daily close-spread proxy)
int    g_spread_idx   = 0;
bool   g_spread_ready = false;


// -----------------------------------------------------------------------------
// Helper: advance cached SMA/ATR state on each new closed D1 bar
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   // Shift: prev ← last
   g_fast_prev = g_fast_last;
   g_slow_prev = g_slow_last;

   // Read fresh closed-bar values (shift=1 = last fully-closed bar)
   g_fast_last = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_period, 1);
   g_slow_last = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_period, 1);

   // Warm-up gate: need at least slow_period valid bars
   const int bars_avail = iBars(_Symbol, PERIOD_D1);
   g_warmed_up = (bars_avail >= strategy_slow_period + 2);

   // Update spread ring for median cap
   const int slen = ArraySize(g_spread_cache);
   if(slen > 0)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double spread_pts = (ask - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      g_spread_cache[g_spread_idx % slen] = spread_pts;
      ++g_spread_idx;
      g_spread_ready = (g_spread_idx >= slen);
     }
  }

// Return median of g_spread_cache (simple sort-copy approach — only 20 items)
double MedianSpread()
  {
   const int n = ArraySize(g_spread_cache);
   if(n == 0) return 0.0;
   double tmp[];
   ArrayCopy(tmp, g_spread_cache);
   ArraySort(tmp);
   if(n % 2 == 1) return tmp[n / 2];
   return (tmp[n / 2 - 1] + tmp[n / 2]) * 0.5;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Spread cap: skip if current spread > spread_mult * median_spread
   if(g_spread_ready)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double current_spread = (ask - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double median = MedianSpread();
      if(median > 0.0 && current_spread > strategy_spread_mult * median)
         return true; // block
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Only trade on a new closed D1 bar (framework guarantees QM_IsNewBar before call)
   if(!g_warmed_up) return false;

   // Check for existing position managed by this EA
   const int magic = QM_FrameworkMagic();
   bool has_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
        { has_pos = true; break; }
     }
   if(has_pos) return false; // already in position; exit handled by ExitSignal

   // Use QM_Sig_MA_Cross for the cross detection (shift=1 = last closed bar)
   int cross = QM_Sig_MA_Cross(_Symbol, PERIOD_D1, strategy_fast_period, strategy_slow_period, 1);
   if(cross == 0) return false;

   // Compute emergency hard stop via ATR
   double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_val <= 0.0) return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(cross > 0)
     {
      // Bullish cross: go LONG
      req.type  = QM_BUY;
      req.price = ask;
      req.sl    = ask - strategy_atr_sl_mult * atr_val;
      req.tp    = 0.0; // no TP; exit on opposite cross
     }
   else
     {
      // Bearish cross: go SHORT
      req.type  = QM_SELL;
      req.price = bid;
      req.sl    = bid + strategy_atr_sl_mult * atr_val;
      req.tp    = 0.0;
     }

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No active trailing on this system — the hard ATR stop set at entry is the
   // only mechanical stop. No SL modification needed per the card spec.
  }

bool Strategy_ExitSignal()
  {
   if(!g_warmed_up) return false;
   if(!QM_IsNewBar()) return false; // exit only evaluated on new closed D1 bar

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long pos_type = PositionGetInteger(POSITION_TYPE);
      // Close LONG when fast < slow
      if(pos_type == POSITION_TYPE_BUY && g_fast_last < g_slow_last)
         return true;
      // Close SHORT when fast > slow
      if(pos_type == POSITION_TYPE_SELL && g_fast_last > g_slow_last)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
// -----------------------------------------------------------------------------

int OnInit()
  {
   // Initialise spread cache ring
   ArrayResize(g_spread_cache, strategy_spread_lookback);
   ArrayInitialize(g_spread_cache, 0.0);
   g_spread_idx   = 0;
   g_spread_ready = false;

   // Prime cached SMA state from historical bars
   g_fast_last = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_period, 1);
   g_slow_last = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_period, 1);
   g_fast_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_period, 2);
   g_slow_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_period, 2);
   const int bars_avail = iBars(_Symbol, PERIOD_D1);
   g_warmed_up = (bars_avail >= strategy_slow_period + 2);

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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   // Advance closed-bar cached state FIRST (before entry check)
   AdvanceState_OnNewBar();

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
