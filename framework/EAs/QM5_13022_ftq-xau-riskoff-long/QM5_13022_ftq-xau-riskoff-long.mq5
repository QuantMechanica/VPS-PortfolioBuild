#property strict
#property version   "5.0"
#property description "QM5_13022 Flight-To-Quality Gold Long In Equity Risk-Off Regimes"

// Baur, Dirk G. and Brian M. Lucey. Is Gold a Hedge or a Safe Haven? An
// Analysis of Stocks, Bonds and Gold. The Financial Review, 45(2), 2010.
// Baur, Dirk G. and Thomas K. McDermott. Is gold a safe haven? International
// evidence. Journal of Banking & Finance, 34(8), 2010.
//
// Card: QM5_13022_ftq-xau-riskoff-long. Long-only XAUUSD.DWX D1 Donchian
// breakout gated by a bear-equity regime read from a cross-symbol data-only
// input (default SP500.DWX, never traded) plus gold's own momentum. Exits:
// ATR hard stop, regime-flip, Donchian(10) trail, max-hold time stop.
// Mechanical, deterministic, no ML (Hard Rule 14).

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13022;
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
// Cross-symbol DATA input only — never traded, never receives orders, no
// magic slot. Backtest default is SP500.DWX (backtest-only custom symbol).
// Live preset MUST override with the broker's live-routable equity index
// equivalent (see card Risk section, env_symbol_mapping hard-rule-at-risk).
input string strategy_regime_symbol     = "SP500.DWX";
input int    strategy_regime_sma        = 200;    // equity bear-regime SMA period
input int    strategy_mom_sma           = 50;     // gold own-momentum SMA period
input int    strategy_donchian_entry    = 20;     // entry breakout lookback
input int    strategy_atr_period        = 14;     // hard-stop ATR period
input double strategy_atr_sl_mult       = 2.5;    // hard-stop ATR multiple
input int    strategy_donchian_trail    = 10;     // exit channel-trail lookback
input int    strategy_max_hold_bars     = 60;     // time-stop, D1 bars
input int    strategy_max_spread_points = 80;     // spread cap, points

// -----------------------------------------------------------------------------
// Cross-symbol regime gate helpers.
//
// Fail-closed by design (card "Fail-closed" rule): if the regime symbol's D1
// series or SMA cannot be computed, the entry gate returns false (blocks
// entry) rather than defaulting to open. No QM_Sig_* helper covers an
// arbitrary-symbol SMA read (QM_Sig_Price_Above_MA hardcodes EMA; this card
// requires SMA), so this reads the regime symbol's closed-bar price directly.
// -----------------------------------------------------------------------------

// Bear-equity regime: regime symbol's D1 close below its own SMA(regime_sma).
bool QM13022_RegimeBearish()
  {
   if(!QM_SymbolAssertOrLog(strategy_regime_symbol))
      return false; // fail-closed: symbol not in the guard's allowed set

   const double sma = QM_SMA(strategy_regime_symbol, PERIOD_D1, strategy_regime_sma, 1);
   if(sma <= 0.0)
      return false; // fail-closed: regime SMA unavailable -> no entry

   const double px = iClose(strategy_regime_symbol, PERIOD_D1, 1); // perf-allowed: single cross-symbol D1 close read, called once per closed bar from Strategy_EntrySignal / Strategy_ExitSignal; no QM_* helper reads an arbitrary symbol's raw close (see QM_Sig_Price_Above_MA precedent, QM_Signals.mqh).
   if(px <= 0.0)
      return false; // fail-closed: regime close unavailable -> no entry

   return (px < sma);
  }

// Regime-flip: regime symbol's D1 close has moved back above its SMA, i.e.
// the bear-equity regime that justified the position has ended. Returns
// false (no flip confirmed) when data is unavailable — a broken regime feed
// must not force a false exit.
bool QM13022_RegimeNormalized()
  {
   if(!QM_SymbolAssertOrLog(strategy_regime_symbol))
      return false;

   const double sma = QM_SMA(strategy_regime_symbol, PERIOD_D1, strategy_regime_sma, 1);
   if(sma <= 0.0)
      return false;

   const double px = iClose(strategy_regime_symbol, PERIOD_D1, 1); // perf-allowed: see QM13022_RegimeBearish above.
   if(px <= 0.0)
      return false;

   return (px >= sma);
  }

// Gold own-momentum gate: XAUUSD D1 close above its own SMA(mom_sma). Guards
// against liquidation-cascade phases where gold sells off with equities.
bool QM13022_MomentumBullish()
  {
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_mom_sma, 1);
   if(sma <= 0.0)
      return false;

   const double px = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single own-symbol D1 close read for the SMA momentum gate; QM_Sig_Price_Above_MA hardcodes EMA, this card requires SMA.
   if(px <= 0.0)
      return false;

   return (px > sma);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Card scope: trade only XAUUSD.DWX on D1 with the registered single slot.
   if(_Symbol != "XAUUSD.DWX")
      return true;
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;

   // Never fail-closed on a genuinely zero .DWX spread — only block a
   // real wide spread (DWX backtest invariant #1).
   const long spread = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position at a time (card: "no entry while a position is open").
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Bear-equity regime gate, fail-closed.
   if(!QM13022_RegimeBearish())
      return false;

   // Gold own-momentum gate.
   if(!QM13022_MomentumBullish())
      return false;

   // Trigger: D1 close above the Donchian(donchian_entry) high of the prior bars.
   if(QM_Sig_Range_Breakout(_Symbol, PERIOD_D1, strategy_donchian_entry, 1) <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "FTQ_XAU_RISKOFF_DONCHIAN_BRK";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No SL/TP adjustment, no break-even, no trailing modify, no partial
   // close, no pyramiding (card: "no pyramiding, gridding, martingale, or
   // partial close"). Position is released entirely via Strategy_ExitSignal
   // (regime-flip / Donchian trail / time stop) or the ATR hard stop.
  }

bool Strategy_ExitSignal()
  {
   // Regime-flip exit: bear-equity regime that justified the position ended.
   if(QM13022_RegimeNormalized())
      return true;

   // Channel trail: D1 close below the Donchian(donchian_trail) low.
   if(QM_Sig_Range_Breakout(_Symbol, PERIOD_D1, strategy_donchian_trail, 1) < 0)
      return true;

   // Time stop: close after max_hold_bars D1 bars.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, opened, false);
      if(bars_held >= strategy_max_hold_bars)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...) / QM_NewsAllowsTrade2(...)
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

   // FW9 — the regime symbol is a foreign (non-chart) DATA-only read. Widen
   // the symbol guard past the single-symbol default and force the tester to
   // load its D1 history, or every QM_SMA/iClose read on it returns 0 and the
   // fail-closed regime gate silently zero-trades the EA.
   string guard_list[2];
   guard_list[0] = _Symbol;
   guard_list[1] = strategy_regime_symbol;
   QM_SymbolGuardInit(guard_list);
   QM_BasketWarmupHistory(guard_list, PERIOD_D1, 300);

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

   bool news_allows = true;
   if(Strategy_NewsFilterHook(broker_now))
      news_allows = false;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = news_allows && QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = news_allows && QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
