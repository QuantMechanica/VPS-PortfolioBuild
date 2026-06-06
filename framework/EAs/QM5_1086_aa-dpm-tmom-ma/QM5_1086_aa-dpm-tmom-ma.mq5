#property strict
#property version   "5.0"
#property description "QM5_1086 Alpha Architect Downside Protection TMOM/MA"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1086 — Alpha Architect Downside Protection Model (TMOM + 12m MA)
// -----------------------------------------------------------------------------
// Card: aa-dpm-tmom-ma (source ede348b4-0fa7-5be1-baa8-09e9089b67b7).
// Wesley Gray, "Avoiding the Big Drawdown with Trend-Following Investment
// Strategies", Alpha Architect (2015).
//
// Two monthly trend rules assessed at the monthly close:
//   1. TMOM : 12-month total return minus a cash-return proxy.
//   2. MA   : monthly close versus its 12-month simple moving average.
// Exposure ladder (per the source):
//   both positive  -> 100% of risk budget
//   one  positive  ->  50% of risk budget
//   none positive  ->   0% (cash)
//
// Execution model (V5):
//   * The EA runs natively on the MN1 chart so the framework new-bar gate in
//     OnTick fires exactly once per monthly close — that single gate IS the
//     monthly rebalance event. We deliberately do NOT call QM_IsNewBar a second
//     time anywhere (the tracker is keyed by symbol|period and is consuming, so
//     a second same-key call would swallow the rebalance and starve entries).
//   * Long-only risk-on/risk-off allocator. The 50%/100% ladder is realised by
//     scaling the framework risk budget via QM_RiskSizerConfigure (weight =
//     PORTFOLIO_WEIGHT * exposure) before each open — i.e. a 50% state risks
//     $500 instead of $1000, which is the literal "% of the risk budget".
//   * All monthly reconciliation (close-on-cash, close+reopen-on-resize, open
//     -on-risk-on) is centralised in the new-bar-gated Strategy_EntrySignal so
//     a resize happens on the SAME rebalance bar (no one-month lag) and there is
//     a single new-bar gate. Strategy_ExitSignal therefore stays passive: the
//     signal close is driven from the rebalance hook, and the per-position ATR
//     stop (a D1-ATR catastrophic backstop) covers intra-month tail risk.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1086;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// Monthly-close allocation rule: intraday news windows are not material to a
// month-end rebalance, so all news axes are OFF. stale_max stays at the 336h
// bound (not inflated); with every axis OFF the framework skips the calendar
// load entirely, so this is news-agnostic, not a fail-closed-gate bypass.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
// MUST stay false: this strategy holds a position across weeks/months. The
// Friday-close guard would liquidate the held allocation every Friday.
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_months       = 12;     // Card: 12-month TMOM + 12-month SMA.
input double strategy_cash_return_12m_pct    = 0.0;    // Card: cash/T-bill proxy (0 = price-only TMOM).
input int    strategy_atr_period             = 14;     // D1 ATR period for the catastrophic stop.
input double strategy_atr_sl_mult            = 3.0;    // ATR multiple for the per-position stop.
input int    strategy_max_spread_points      = 5000;   // Spread guard at rebalance; 0 disables.

#define QM5_1086_SYMBOL_COUNT 13

// Held exposure fraction for this EA's position (0.0 / 0.5 / 1.0). Tracks the
// allocation we last opened so monthly reconciliation can detect resizes. It is
// NOT a new-bar gate — it carries intent across the per-month rebalance only.
double g_held_exposure = 0.0;

string Strategy_SymbolForSlot(const int slot)
  {
   if(slot == 0)  return "SP500.DWX";
   if(slot == 1)  return "NDX.DWX";
   if(slot == 2)  return "WS30.DWX";
   if(slot == 3)  return "GDAXI.DWX";
   if(slot == 4)  return "XAUUSD.DWX";
   if(slot == 5)  return "XTIUSD.DWX";
   if(slot == 6)  return "EURUSD.DWX";
   if(slot == 7)  return "GBPUSD.DWX";
   if(slot == 8)  return "USDJPY.DWX";
   if(slot == 9)  return "AUDUSD.DWX";
   if(slot == 10) return "USDCAD.DWX";
   if(slot == 11) return "USDCHF.DWX";
   if(slot == 12) return "NZDUSD.DWX";
   return "";
  }

bool Strategy_SymbolSlotAllowed()
  {
   return (_Symbol == Strategy_SymbolForSlot(qm_magic_slot_offset));
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

void Strategy_CloseOurPositions()
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
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// Monthly signal -> target exposure (0.0 / 0.5 / 1.0). Reads only closed MN1
// bars via handle-pooled QM_SMA (period-1 SMA = the bar close); no raw iClose.
double Strategy_TargetExposure()
  {
   if(strategy_lookback_months <= 0)
      return 0.0;

   const int recent_shift   = 1;                              // last closed monthly bar
   const int lookback_shift = recent_shift + strategy_lookback_months;
   const double recent_close   = QM_SMA(_Symbol, PERIOD_MN1, 1, recent_shift, PRICE_CLOSE);
   const double lookback_close = QM_SMA(_Symbol, PERIOD_MN1, 1, lookback_shift, PRICE_CLOSE);
   const double ma_12m         = QM_SMA(_Symbol, PERIOD_MN1, strategy_lookback_months, recent_shift, PRICE_CLOSE);
   if(recent_close <= 0.0 || lookback_close <= 0.0 || ma_12m <= 0.0)
      return 0.0;

   const double total_return_pct = 100.0 * ((recent_close / lookback_close) - 1.0);
   const bool tmom_positive = (total_return_pct > strategy_cash_return_12m_pct);
   const bool ma_positive   = (recent_close > ma_12m);

   if(tmom_positive && ma_positive)
      return 1.0;
   if(tmom_positive || ma_positive)
      return 0.5;
   return 0.0;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points <= 0)
      return true;
   return (spread_points <= strategy_max_spread_points);
  }

// Scale the framework risk budget to the target exposure fraction so a 50%
// signal risks half of RISK_FIXED — the literal "% of the strategy risk budget".
bool Strategy_ConfigureRiskForExposure(const double exposure)
  {
   const double weight = PORTFOLIO_WEIGHT * exposure;
   if(weight <= 0.0 || weight > 1.0)
      return false;

   QM_RiskMode mode = (RISK_FIXED > 0.0) ? QM_RISK_MODE_FIXED : QM_RISK_MODE_PERCENT;
   const double risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
   return QM_RiskSizerConfigure(mode, RISK_PERCENT, RISK_FIXED, weight, risk_cap_money);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_MN1)          // monthly-close rebalance EA — MN1 only
      return true;
   if(!Strategy_SymbolSlotAllowed())  // each instance trades only its slot's symbol
      return true;
   return false;
  }

// Trade Entry — runs once per closed MN1 bar (OnTick QM_IsNewBar gate). This is
// the monthly rebalance: it both reconciles an existing allocation and opens a
// new one, so a resize closes and reopens on the same bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Keep the held-exposure tracker honest if the stop took us out intra-month.
   if(!Strategy_HasOpenPosition())
      g_held_exposure = 0.0;

   const double target_exposure = Strategy_TargetExposure();

   // Reconcile an existing allocation: close when the signal says cash, or when
   // the target exposure changed (resize via close-then-reopen below).
   if(g_held_exposure > 0.0 &&
      (target_exposure <= 0.0 || MathAbs(target_exposure - g_held_exposure) > 1e-9))
     {
      Strategy_CloseOurPositions();
      g_held_exposure = 0.0;
     }

   // Risk-on: open the target allocation when flat.
   if(g_held_exposure <= 0.0 && target_exposure > 0.0)
     {
      if(!Strategy_SpreadAllowsEntry())
         return false;
      if(!Strategy_ConfigureRiskForExposure(target_exposure))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_sl_mult);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.price = entry;
      req.sl = sl;
      req.tp = 0.0;   // signal-based exit; no fixed target
      req.reason = (target_exposure >= 1.0) ? "DPM_TMOM_MA_FULL" : "DPM_TMOM_MA_HALF";
      g_held_exposure = target_exposure;
      return true;
     }

   return false;
  }

// Trade Management — signal-only monthly allocator; no trailing/BE/partials.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — the monthly signal close is executed in the rebalance hook
// (Strategy_EntrySignal) so close+reopen land on the same bar and a single
// new-bar gate is preserved. The per-position D1-ATR stop handles tail risk.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // monthly allocation rule is news-agnostic; defer to framework
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1086\",\"ea\":\"aa-dpm-tmom-ma\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
