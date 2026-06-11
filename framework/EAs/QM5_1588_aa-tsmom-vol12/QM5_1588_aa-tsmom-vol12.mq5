#property strict
#property version   "5.0"
#property description "QM5_1588 — Alpha Architect Volatility-Scaled 12-Month TSMOM"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1588 — aa-tsmom-vol12
// Alpha Architect Volatility-Scaled 12-Month Time-Series Momentum
// Source: Wesley Gray, Alpha Architect 2016-12-22 (ede348b4-0fa7-5be1-baa8-09e9089b67b7)
// Card: artifacts/cards_approved/QM5_1588_aa-tsmom-vol12.md
//
// D1-native: MN1 is untestable in MT5 tester for DWX custom symbols; 252 D1
// bars proxy the 12-month lookback. Monthly rebalance cadence is preserved —
// the signal only changes when the 12-month return sign flips (~monthly).
//
// Inverse-vol weighting: computed and cached for reference. P2 baseline uses
// framework PORTFOLIO_WEIGHT (default 1.0); per-symbol vol-weighted sizing is
// configured via PORTFOLIO_WEIGHT in the generated setfile at P3+/Q11.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1588;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
// Monthly positions must survive weekends; Friday close disabled by default.
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// 12-month trailing return lookback in D1 bars (252 ≈ 1 trading year)
input int    strategy_lookback_days       = 252;
// Realized-volatility window in D1 bars (used for cached diagnostic / setfile PORTFOLIO_WEIGHT calc)
input int    strategy_vol_period          = 20;
// Annual volatility target for inverse-vol sizing reference (0.12 = 12%)
input double strategy_vol_target          = 0.12;
// ATR period (D1 bars) and stop-loss multiplier (card §Stop Loss: 3× ATR20)
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;

// =============================================================================
// Per-bar cached state — updated once per new D1 bar.
// These store SIGNAL STATE, NOT a timing gate; timing gate is QM_IsNewBar().
// =============================================================================
int    g_signal      = 0;     // +1 long, -1 short, 0 hold-cash
double g_inv_vol     = 1.0;   // inverse-vol factor (diagnostic cache; see note above)
bool   g_cache_valid = false; // true after first successful state advance

// Advance cached signal and vol state once per new D1 bar.
// CopyRates called once per bar — perf-allowed: 12-month return and realized
// volatility require raw D1 close sequence unavailable from QM_* readers.
void AdvanceState_OnNewBar()
  {
   const int NEEDED = strategy_lookback_days + strategy_vol_period + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_D1, 1, NEEDED, rates); // perf-allowed
   if(copied < NEEDED)
     {
      g_signal     = 0;
      g_cache_valid = false;
      return;
     }

   // 12-month return: rates[0]=last closed D1 bar, rates[252]=252 bars ago
   double close_now = rates[0].close;
   double close_12m = rates[strategy_lookback_days].close;
   if(close_12m <= 0.0)
     {
      g_signal     = 0;
      g_cache_valid = false;
      return;
     }
   double ret_12m = (close_now - close_12m) / close_12m;
   g_signal = (ret_12m > 0.0) ? 1 : (ret_12m < 0.0) ? -1 : 0;

   // Realized annual vol: std dev of log returns over vol_period D1 bars
   // Cached for reference; use as PORTFOLIO_WEIGHT suggestion in setfiles.
   double returns[];
   ArrayResize(returns, strategy_vol_period);
   double mean = 0.0;
   for(int i = 0; i < strategy_vol_period; i++)
     {
      returns[i] = (rates[i].close > 0.0 && rates[i + 1].close > 0.0)
                   ? MathLog(rates[i].close / rates[i + 1].close)
                   : 0.0;
      mean += returns[i];
     }
   mean /= strategy_vol_period;
   double var = 0.0;
   for(int i = 0; i < strategy_vol_period; i++)
     {
      double diff = returns[i] - mean;
      var += diff * diff;
     }
   double sigma_ann = MathSqrt(var / strategy_vol_period) * MathSqrt(252.0);
   // Inverse-vol factor capped at 1.0 (no leverage per card)
   g_inv_vol    = (sigma_ann > 0.001) ? MathMin(strategy_vol_target / sigma_ann, 1.0) : 1.0;
   g_cache_valid = true;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No Trade Filter — TSMOM is direction-only; no intraday session filter.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry — enter long/short when 12-month return is non-zero on new D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Update cached signal once per new D1 bar (caller ensures QM_IsNewBar)
   AdvanceState_OnNewBar();

   if(!g_cache_valid || g_signal == 0) return false;

   // Skip if already positioned in the same direction (avoids REJECTED_DUPLICATE log noise)
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != (long)magic) continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_signal == 1)  return false;
      if(ptype == POSITION_TYPE_SELL && g_signal == -1) return false;
     }

   double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0) return false;
   double sl_dist = strategy_atr_sl_mult * atr;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_signal == 1)
     {
      req.type        = QM_BUY;
      req.price       = 0.0;          // 0 = market price (framework resolves)
      req.sl          = ask - sl_dist;
      req.tp          = 0.0;          // primary exit via signal reversal
      req.reason      = "TSMOM_LONG";
      req.symbol_slot = qm_magic_slot_offset;
     }
   else
     {
      req.type        = QM_SELL;
      req.price       = 0.0;
      req.sl          = bid + sl_dist;
      req.tp          = 0.0;
      req.reason      = "TSMOM_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
     }
   return true;
  }

// Trade Management — no active trail; initial SL from entry is the mechanical stop.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — close if signal reversed or hold-cash (incomplete data).
bool Strategy_ExitSignal()
  {
   if(!g_cache_valid) return false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(g_signal == 0) return true;   // hold-cash: incomplete data or zero return
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_signal == -1) return true;
      if(ptype == POSITION_TYPE_SELL && g_signal ==  1) return true;
     }
   return false;
  }

// News Filter Hook — defer to central framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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
                        const MqlTradeRequest    &request,
                        const MqlTradeResult     &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
