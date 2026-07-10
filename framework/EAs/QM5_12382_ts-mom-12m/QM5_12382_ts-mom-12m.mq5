#property strict
#property version   "5.0"
#property description "QM5_12382 Twelve-Month Time-Series Momentum"

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
input int    qm_ea_id                   = 12382;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_lookback_d1 = 252;
input int    strategy_vol_lookback_d1      = 60;
input int    strategy_spread_lookback_d1   = 60;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_stop_mult        = 3.0;
input int    strategy_min_warmup_bars      = 260;
input double strategy_portfolio_stop_r     = 6.0;

bool IsD1CalendarMonthBoundary()
  {
   // Use the framework calendar key instead of a local iTime/CopyRates month
   // detector.  The helper derives MN1 cadence from reliable D1 bars, so it
   // remains tester-safe on .DWX symbols where native MN1 bars are absent.
   const int current_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month   = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   return current_month > 0 && prior_month > 0 && current_month != prior_month;
  }

bool LoadD1Closes(const int required_bars, double &closes[])
  {
   if(required_bars <= 0)
      return false;
   ArrayResize(closes, required_bars);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, required_bars, closes); // perf-allowed: card requires 252D return plus 60D realized vol, called only on monthly D1 rebalance.
   return copied == required_bars;
  }

bool ComputeMomentumVol(double &momentum_return, double &annualized_vol)
  {
   momentum_return = 0.0;
   annualized_vol = 0.0;

   if(strategy_momentum_lookback_d1 <= 0 || strategy_vol_lookback_d1 <= 1)
      return false;

   const int required = MathMax(strategy_min_warmup_bars,
                                MathMax(strategy_momentum_lookback_d1 + 1,
                                        strategy_vol_lookback_d1 + 1));
   double closes[];
   if(!LoadD1Closes(required, closes))
      return false;

   const double recent_close = closes[0];
   const double lookback_close = closes[strategy_momentum_lookback_d1];
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;
   momentum_return = (recent_close / lookback_close) - 1.0;

   double sum_returns = 0.0;
   double returns[];
   ArrayResize(returns, strategy_vol_lookback_d1);
   for(int i = 0; i < strategy_vol_lookback_d1; ++i)
     {
      const double c0 = closes[i];
      const double c1 = closes[i + 1];
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;
      returns[i] = (c0 / c1) - 1.0;
      sum_returns += returns[i];
     }

   const double mean_return = sum_returns / (double)strategy_vol_lookback_d1;
   double variance_sum = 0.0;
   for(int j = 0; j < strategy_vol_lookback_d1; ++j)
     {
      const double delta = returns[j] - mean_return;
      variance_sum += delta * delta;
     }

   const double sample_variance = variance_sum / (double)(strategy_vol_lookback_d1 - 1);
   if(sample_variance <= 0.0)
      return false;

   annualized_vol = MathSqrt(sample_variance) * MathSqrt(252.0);
   return annualized_vol > 0.0;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   ticket = 0;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      return true;
     }

   return false;
  }

bool SignalSide(QM_OrderType &side, double &momentum_return, double &annualized_vol)
  {
   if(!ComputeMomentumVol(momentum_return, annualized_vol))
      return false;
   if(momentum_return > 0.0)
     {
      side = QM_BUY;
      return true;
     }
   if(momentum_return < 0.0)
     {
      side = QM_SELL;
      return true;
     }
   return false;
  }

bool SpreadAllowsEntry()
  {
   if(strategy_spread_lookback_d1 <= 0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread < 1)
      return true;

   MqlRates rates[];
   ArrayResize(rates, strategy_spread_lookback_d1);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_lookback_d1, rates); // perf-allowed: monthly entry-only median spread filter from card.
   if(copied != strategy_spread_lookback_d1)
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   int usable = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread < 1)
         continue;
      spreads[usable] = (double)rates[i].spread;
      usable++;
     }

   if(usable <= 0)
      return true;

   ArrayResize(spreads, usable);
   ArraySort(spreads);
   const double median_spread = (usable % 2 == 1)
                                ? spreads[usable / 2]
                                : (spreads[usable / 2 - 1] + spreads[usable / 2]) * 0.5;
   if(median_spread < 1.0)
      return true;

   return (double)current_spread <= median_spread * 2.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(!SpreadAllowsEntry())
      return false;

   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   if(GetOurPosition(ptype, ticket))
      return false;

   double momentum_return = 0.0;
   double annualized_vol = 0.0;
   QM_OrderType side = QM_BUY;
   if(!SignalSide(side, momentum_return, annualized_vol))
      return false;

   const double entry_price = QM_OrderTypeIsBuy(side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_value <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry_price, atr_value, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = StringFormat("TSMOM12M_%s_ret=%.6f_vol=%.6f",
                             QM_OrderTypeIsBuy(side) ? "LONG" : "SHORT",
                             momentum_return,
                             annualized_vol);
   return req.sl > 0.0;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   if(!GetOurPosition(ptype, ticket))
      return;

   if(strategy_portfolio_stop_r > 0.0)
     {
      const double open_pnl = QM_TM_OpenPnL(QM_FrameworkMagic());
      if(open_pnl <= -RISK_FIXED * strategy_portfolio_stop_r)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_KILLSWITCH);
         return;
        }
     }
  }

// The source changes direction only at the monthly rebalance. Keep that
// expensive 252-bar signal calculation out of the per-tick management hook,
// while the fixed-risk emergency stop above remains live on every tick.
void ManageMonthlyRebalance()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   if(!GetOurPosition(ptype, ticket))
      return;

   double momentum_return = 0.0;
   double annualized_vol = 0.0;
   QM_OrderType side = QM_BUY;
   if(!SignalSide(side, momentum_return, annualized_vol))
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      return;
     }

   const bool holding_buy = (ptype == POSITION_TYPE_BUY);
   if((holding_buy && side == QM_SELL) || (!holding_buy && side == QM_BUY))
      QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   string basket_symbols[] = {"EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","USDCHF.DWX","USDCAD.DWX","XAUUSD.DWX","XAGUSD.DWX","XTIUSD.DWX","SP500.DWX","NDX.DWX","WS30.DWX","GDAXI.DWX"};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, strategy_min_warmup_bars + 5);

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

   // Risk management stays live on every tick, including news windows.
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

   // Per-closed-D1-bar: monthly rebalance logic is evaluated only after the
   // framework gate consumes the new daily bar event.
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   if(!IsD1CalendarMonthBoundary())
      return;

   // Monthly sign-reversal exits also remain active through news windows.
   ManageMonthlyRebalance();

   // News gates block new entries only; they never suspend stop or rebalance
   // exits (binding 2026-07-02 OnTick ordering rule).
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
