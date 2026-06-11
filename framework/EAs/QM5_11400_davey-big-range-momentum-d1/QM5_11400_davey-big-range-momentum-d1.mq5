#property strict
#property version   "5.0"
#property description "QM5_11400 Davey — Big Range Momentum D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11400 — Davey Big Range Momentum (D1)
// Source: Kevin J. Davey "My 5 Favorite Entries", Entry #1.
// Signal: When a D1 bar's range is > 2*StdDev(range, xr) + avg(range, xr),
//         enter in the direction the close moved versus a lookback close.
// Exit:   ATR-based SL (1.5×) and TP (2.0×); breakeven at +1×ATR.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 11400;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_xr                = 20;    // range-StdDev lookback (bars)
input int    strategy_daysback          = 5;     // momentum reference bar shift
input double strategy_range_mult        = 2.0;   // threshold: mult*StdDev + avg
input int    strategy_atr_period        = 14;    // ATR period for SL/TP/BE
input double strategy_sl_atr_mult       = 1.5;   // SL distance = ATR * mult
input double strategy_tp_atr_mult       = 2.0;   // TP distance = ATR * mult
input double strategy_be_atr_mult       = 1.0;   // BE trigger at +1x ATR profit
input double strategy_spread_cap_pips   = 25.0;  // max spread (pips)

// -----------------------------------------------------------------------------
// Trade filter — spread cap (O(1) per tick).
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   // SYMBOL_SPREAD is in points; 1 pip = 10 points for standard fx pairs.
   const double spread_pips = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) / 10.0;
   return (spread_pips > strategy_spread_cap_pips);
  }

// -----------------------------------------------------------------------------
// Entry signal — evaluated once per new closed D1 bar (gated by QM_IsNewBar).
// Duplicate-position guard is handled by QM_Entry (ENTRY_REJECTED_DUPLICATE).
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(strategy_xr < 2 || strategy_daysback < 1)
      return false;

   // Need at least xr + daysback + 2 bars of history.
   const int bars_needed = strategy_xr + strategy_daysback + 2;
   if(Bars(_Symbol, PERIOD_D1) < bars_needed) // perf-allowed: history depth guard for bespoke range loop
      return false;

   // Range statistics over bars shifted 1..xr (all closed).
   // Inline loop — bespoke structural logic (range StdDev). perf-allowed.
   double sum_r = 0.0, sum_r2 = 0.0;
   for(int i = 1; i <= strategy_xr; i++)
     {
      const double r = iHigh(_Symbol, PERIOD_D1, i)   // perf-allowed: range stat loop
                     - iLow(_Symbol,  PERIOD_D1, i);   // perf-allowed: range stat loop
      sum_r  += r;
      sum_r2 += r * r;
     }
   const double avg_r     = sum_r / strategy_xr;
   const double var_r     = MathMax(0.0, sum_r2 / strategy_xr - avg_r * avg_r);
   const double std_r     = MathSqrt(var_r);
   const double threshold = strategy_range_mult * std_r + avg_r;

   // Signal bar = last completed bar (shift 1).
   const double bar_h  = iHigh(_Symbol,  PERIOD_D1, 1);                   // perf-allowed
   const double bar_l  = iLow(_Symbol,   PERIOD_D1, 1);                   // perf-allowed
   const double bar_c  = iClose(_Symbol, PERIOD_D1, 1);                   // perf-allowed
   const double ref_c  = iClose(_Symbol, PERIOD_D1, 1 + strategy_daysback); // perf-allowed

   if(bar_h <= 0.0 || bar_l <= 0.0 || bar_c <= 0.0 || ref_c <= 0.0)
      return false;

   const double sig_range = bar_h - bar_l;
   if(sig_range <= threshold)
      return false;

   // Momentum direction from close comparison.
   int dir = 0;
   if(bar_c > ref_c)       dir = +1; // bullish momentum → BUY
   else if(bar_c < ref_c)  dir = -1; // bearish momentum → SELL
   else                     return false;

   // ATR-based SL and TP.
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_dist = atr * strategy_sl_atr_mult;
   const double tp_dist = atr * strategy_tp_atr_mult;

   // Market entry: price=0 resolved to bid/ask at send time by QM_Entry.
   // SL/TP set relative to current bid/ask; QM_EntrySLPoints uses resolved price.
   req.price              = 0.0;
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(dir > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type   = QM_BUY;
      req.sl     = NormalizeDouble(ask - sl_dist, _Digits);
      req.tp     = NormalizeDouble(ask + tp_dist, _Digits);
      req.reason = "BIG_RANGE_LONG";
     }
   else
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type   = QM_SELL;
      req.sl     = NormalizeDouble(bid + sl_dist, _Digits);
      req.tp     = NormalizeDouble(bid - tp_dist, _Digits);
      req.reason = "BIG_RANGE_SHORT";
     }

   return true;
  }

// -----------------------------------------------------------------------------
// Trade management — move SL to break-even at +1×ATR profit.
// Called every tick; QM_ATR uses pooled handle (O(1)).
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   // 1 pip in price: standard forex pairs all use 10 points per pip.
   const double pip      = _Point * 10.0;
   const int be_trigger  = (int)MathRound(atr * strategy_be_atr_mult / pip);
   if(be_trigger <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, be_trigger, 2);
     }
  }

// -----------------------------------------------------------------------------
// Exit signal — exits via SL/TP and Friday-close only (no discretionary exit).
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// News filter hook — defer to framework two-axis filter.
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11400\",\"slug\":\"davey-big-range-momentum-d1\"}");
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
