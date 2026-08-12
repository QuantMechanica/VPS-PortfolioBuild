#property strict
#property version   "5.0"
#property description "QM5_1537 Alpha Architect high-volatility 10-day SMA timing"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 1537;
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
input int    strategy_sma_period           = 10;   // SMA(10, D1) timing MA per card
input int    strategy_min_daily_bars       = 270;  // card: min 270 D1 bars before eligibility
input int    strategy_atr_period           = 14;   // ATR(14, D1) for initial SL
input double strategy_atr_sl_mult          = 2.5;  // card: SL = 2.5 x ATR(14, D1)
input int    strategy_vol_lookback_days    = 252;  // card: prior-year realized volatility window
// Literal proxy for the card's "top volatility decile / top 3" cross-sectional
// selection: a per-symbol annualized realized-volatility floor. The registered
// basket (metals, energies, major indices) is the naturally high-realized-vol
// slice of the DWX universe; this floor keeps a symbol admitted only while its
// own trailing 252-day realized vol stays elevated, and re-evaluates monthly —
// see UpdateVolatilitySleeveMembership().
input double strategy_min_annualized_vol_pct = 15.0;
input int    strategy_max_spread_points    = 0;    // 0 = disabled (DWX quotes 0 spread in tester)

// -----------------------------------------------------------------------------
// Volatility-sleeve state — cached, recomputed once per calendar month via
// QM_IsNewCalendarPeriod(PERIOD_MN1) (never per-tick; see NoTradeFilter below).
// -----------------------------------------------------------------------------
bool   g_vol_sleeve_active        = false;
bool   g_vol_sleeve_initialized   = false;
double g_realized_vol_annualized_pct = 0.0;

// Recompute this symbol's trailing 252-day annualized realized volatility and
// update sleeve membership. Called at most once per calendar month (gated by
// QM_IsNewCalendarPeriod in Strategy_NoTradeFilter) — never per-tick.
void UpdateVolatilitySleeveMembership()
  {
   double closes[];
   ArraySetAsSeries(closes, true);
   // perf-allowed: bespoke realized-volatility ranking proxy has no QM_*
   // equivalent; bounded to strategy_vol_lookback_days+1 bars and gated to
   // fire at most once per calendar month.
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, strategy_vol_lookback_days + 1, closes);
   if(copied < strategy_vol_lookback_days + 1)
     {
      g_vol_sleeve_active = false;
      g_vol_sleeve_initialized = true;
      return;
     }

   double sum = 0.0;
   double sum_sq = 0.0;
   int n = 0;
   for(int i = 0; i < strategy_vol_lookback_days; ++i)
     {
      if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
         continue;
      const double log_ret = MathLog(closes[i] / closes[i + 1]);
      sum += log_ret;
      sum_sq += log_ret * log_ret;
      n++;
     }
   if(n < strategy_vol_lookback_days / 2)
     {
      g_vol_sleeve_active = false;
      g_vol_sleeve_initialized = true;
      return;
     }

   const double mean = sum / n;
   double variance = (sum_sq / n) - (mean * mean);
   if(variance < 0.0)
      variance = 0.0;
   const double daily_vol = MathSqrt(variance);
   g_realized_vol_annualized_pct = daily_vol * MathSqrt(252.0) * 100.0;
   g_vol_sleeve_active = (g_realized_vol_annualized_pct >= strategy_min_annualized_vol_pct);
   g_vol_sleeve_initialized = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   if(qm_magic_slot_offset == 0 && _Symbol != "XAUUSD.DWX") return true;
   if(qm_magic_slot_offset == 1 && _Symbol != "XAGUSD.DWX") return true;
   if(qm_magic_slot_offset == 2 && _Symbol != "XNGUSD.DWX") return true;
   if(qm_magic_slot_offset == 3 && _Symbol != "XTIUSD.DWX") return true;
   if(qm_magic_slot_offset == 4 && _Symbol != "NDX.DWX")    return true;
   if(qm_magic_slot_offset == 5 && _Symbol != "WS30.DWX")   return true;
   if(qm_magic_slot_offset == 6 && _Symbol != "GDAXI.DWX")  return true;
   if(qm_magic_slot_offset == 7 && _Symbol != "UK100.DWX")  return true;
   if(qm_magic_slot_offset == 8 && _Symbol != "SP500.DWX")  return true;
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset > 8)
      return true;

   // Card: "Recompute volatility sleeve monthly." Cheap on every tick except
   // the first tick of a new month, when it does the bounded 252-bar pass.
   if(QM_IsNewCalendarPeriod(PERIOD_MN1))
      UpdateVolatilitySleeveMembership();

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "AA_VOL_SMA10_CROSS_ABOVE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;
   if(strategy_sma_period <= 0 ||
      strategy_min_daily_bars < strategy_sma_period ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   // Card: long/cash default mode — only trade while this symbol sits in the
   // high-realized-volatility sleeve.
   if(!g_vol_sleeve_initialized || !g_vol_sleeve_active)
      return false;

   const double warmup_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_min_daily_bars, 1);
   if(warmup_sma <= 0.0)
      return false;

   const double sma10_now  = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double sma10_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 2);
   // QM_SMA(period=1) of the closed bar is exactly that bar's close price —
   // avoids a raw iClose() call for the cross check.
   const double close_now  = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   const double close_prev = QM_SMA(_Symbol, PERIOD_D1, 1, 2);
   if(sma10_now <= 0.0 || sma10_prev <= 0.0 || close_now <= 0.0 || close_prev <= 0.0)
      return false;

   const bool crossed_above = (close_prev <= sma10_prev) && (close_now > sma10_now);
   if(!crossed_above)
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

      return false; // one position per symbol/magic — no pyramiding (card)
     }

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card defines no trailing, break-even, partial close, or pyramiding —
   // exit is driven entirely by Strategy_ExitSignal (SMA10 cross-below or
   // sleeve departure) and the initial ATR stop loss.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(strategy_sma_period <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   bool has_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         has_long = true;
         break;
        }
     }
   if(!has_long)
      return false;

   // Card: "close symbols that leave the high-volatility sleeve" — checked
   // every tick from the monthly-cached flag (cheap bool read).
   if(g_vol_sleeve_initialized && !g_vol_sleeve_active)
      return true;

   const double sma10_now  = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double sma10_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 2);
   const double close_now  = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   const double close_prev = QM_SMA(_Symbol, PERIOD_D1, 1, 2);
   if(sma10_now <= 0.0 || sma10_prev <= 0.0 || close_now <= 0.0 || close_prev <= 0.0)
      return false;

   return (close_prev >= sma10_prev) && (close_now < sma10_now);
  }

// News Filter Hook (callable for P8 News Impact phase)
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
