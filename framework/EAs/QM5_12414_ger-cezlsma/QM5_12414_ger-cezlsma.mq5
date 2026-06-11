#property strict
#property version   "5.0"
#property description "QM5_12414 Geraked CE ZLSMA Heikin Trend"

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
input int    qm_ea_id                   = 12414;
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
input int    ce_atr_period              = 1;
input double ce_atr_mult                = 0.75;
input int    zl_period                  = 50;
input int    time_stop_bars             = 96;
input int    sl_dev_points              = 650;
input double catastrophic_atr_mult      = 2.0;

bool   g_signal_valid      = false;
bool   g_long_signal       = false;
bool   g_short_signal      = false;
bool   g_long_exit_cross   = false;
bool   g_short_exit_cross  = false;
double g_ce_long_stop      = 0.0;
double g_ce_short_stop     = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool HasOurPosition()
  {
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
      return true;
     }
   return false;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype,
                    double &profit,
                    datetime &opened_at,
                    double &current_sl,
                    ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   profit = 0.0;
   opened_at = 0;
   current_sl = 0.0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      current_sl = PositionGetDouble(POSITION_SL);
      ticket = pos_ticket;
      return true;
     }

   return false;
  }

double HAClose(MqlRates &rates[], const int shift)
  {
   return (rates[shift].open + rates[shift].high + rates[shift].low + rates[shift].close) / 4.0;
  }

double LinearRegressionHA(MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 1)
      return HAClose(rates, shift);

   double sx = 0.0;
   double sy = 0.0;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int j = 0; j < period; ++j)
     {
      const double x = (double)j;
      const int rate_shift = shift + period - 1 - j;
      const double y = HAClose(rates, rate_shift);
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
     }

   const double n = (double)period;
   const double denom = (n * sxx) - (sx * sx);
   if(MathAbs(denom) <= DBL_EPSILON)
      return sy / n;

   const double slope = ((n * sxy) - (sx * sy)) / denom;
   const double intercept = (sy - slope * sx) / n;
   return intercept + slope * (n - 1.0);
  }

double LinearRegressionSeriesValue(const double &values[], const int period)
  {
   if(period <= 1)
      return values[0];

   double sx = 0.0;
   double sy = 0.0;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int j = 0; j < period; ++j)
     {
      const double x = (double)j;
      const double y = values[period - 1 - j];
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
     }

   const double n = (double)period;
   const double denom = (n * sxx) - (sx * sx);
   if(MathAbs(denom) <= DBL_EPSILON)
      return sy / n;

   const double slope = ((n * sxy) - (sx * sy)) / denom;
   const double intercept = (sy - slope * sx) / n;
   return intercept + slope * (n - 1.0);
  }

double ZLSMA(MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 1)
      return HAClose(rates, shift);

   double lsma_values[];
   ArrayResize(lsma_values, period);
   for(int j = 0; j < period; ++j)
      lsma_values[j] = LinearRegressionHA(rates, shift + j, period);

   const double lsma1 = lsma_values[0];
   const double lsma2 = LinearRegressionSeriesValue(lsma_values, period);
   return lsma1 + (lsma1 - lsma2);
  }

double HighestHigh(MqlRates &rates[], const int shift, const int period)
  {
   double out = -DBL_MAX;
   for(int i = 0; i < period; ++i)
      out = MathMax(out, rates[shift + i].high);
   return out;
  }

double LowestLow(MqlRates &rates[], const int shift, const int period)
  {
   double out = DBL_MAX;
   for(int i = 0; i < period; ++i)
      out = MathMin(out, rates[shift + i].low);
   return out;
  }

double TrueRange(MqlRates &rates[], const int shift)
  {
   const double hl = rates[shift].high - rates[shift].low;
   const double hc = MathAbs(rates[shift].high - rates[shift + 1].close);
   const double lc = MathAbs(rates[shift].low - rates[shift + 1].close);
   return MathMax(hl, MathMax(hc, lc));
  }

double ATRFromRates(MqlRates &rates[], const int shift, const int period)
  {
   double sum = 0.0;
   for(int i = 0; i < period; ++i)
      sum += TrueRange(rates, shift + i);
   return sum / (double)period;
  }

void ChandelierStops(MqlRates &rates[],
                     const int shift,
                     const int period,
                     const double mult,
                     double &long_stop,
                     double &short_stop)
  {
   const double atr = ATRFromRates(rates, shift, period);
   long_stop = HighestHigh(rates, shift, period) - (atr * mult);
   short_stop = LowestLow(rates, shift, period) + (atr * mult);
  }

int ChandelierDirection(MqlRates &rates[],
                        const int copied,
                        const int target_shift,
                        const int period,
                        const double mult)
  {
   int direction = 0;
   const int oldest_shift = copied - period - 2;
   for(int shift = oldest_shift; shift >= target_shift; --shift)
     {
      double long_stop = 0.0;
      double short_stop = 0.0;
      ChandelierStops(rates, shift, period, mult, long_stop, short_stop);
      if(rates[shift].close > short_stop)
         direction = 1;
      else if(rates[shift].close < long_stop)
         direction = -1;
     }
   return direction;
  }

bool RefreshSignalState()
  {
   g_signal_valid = false;
   g_long_signal = false;
   g_short_signal = false;
   g_long_exit_cross = false;
   g_short_exit_cross = false;
   g_ce_long_stop = 0.0;
   g_ce_short_stop = 0.0;

   if(ce_atr_period < 1 || ce_atr_period > 250 || ce_atr_mult <= 0.0 ||
      zl_period < 2 || zl_period > 250 || sl_dev_points < 0 ||
      time_stop_bars < 1 || catastrophic_atr_mult <= 0.0)
      return false;

   const int required = (zl_period * 2) + ce_atr_period + 10;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, required, rates); // perf-allowed: bounded CE/ZLSMA/HA snapshot, caller is framework new-bar gated.
   if(copied < required)
      return false;

   const double ha1 = HAClose(rates, 1);
   const double ha2 = HAClose(rates, 2);
   const double z1 = ZLSMA(rates, 1, zl_period);
   const double z2 = ZLSMA(rates, 2, zl_period);
   if(ha1 <= 0.0 || ha2 <= 0.0 || z1 <= 0.0 || z2 <= 0.0)
      return false;

   ChandelierStops(rates, 1, ce_atr_period, ce_atr_mult, g_ce_long_stop, g_ce_short_stop);
   const int ce_direction = ChandelierDirection(rates, copied, 1, ce_atr_period, ce_atr_mult);

   g_long_signal = (ce_direction > 0 && ha1 > z1);
   g_short_signal = (ce_direction < 0 && ha1 < z1);
   g_long_exit_cross = (ha2 >= z2 && ha1 < z1);
   g_short_exit_cross = (ha2 <= z2 && ha1 > z1);
   g_signal_valid = true;
   return true;
  }

double NormalizeTradePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double EntryStop(const QM_OrderType side, const double entry)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stop = 0.0;
   if(point > 0.0)
     {
      if(side == QM_BUY && g_ce_long_stop > 0.0)
         stop = g_ce_long_stop - (sl_dev_points * point);
      else if(side == QM_SELL && g_ce_short_stop > 0.0)
         stop = g_ce_short_stop + (sl_dev_points * point);
     }

   if(side == QM_BUY && stop > 0.0 && stop < entry)
      return NormalizeTradePrice(stop);
   if(side == QM_SELL && stop > entry)
      return NormalizeTradePrice(stop);

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, 14, 1);
   if(atr <= 0.0)
      return 0.0;
   if(side == QM_BUY)
      return NormalizeTradePrice(entry - (atr * catastrophic_atr_mult));
   return NormalizeTradePrice(entry + (atr * catastrophic_atr_mult));
  }

// Return TRUE to BLOCK trading this tick. The card adds no extra session/regime
// filter beyond V5 spread/news/Friday guards and one-position discipline.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!RefreshSignalState())
      return false;
   if(HasOurPosition())
      return false;

   if(g_long_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = EntryStop(req.type, entry);
      req.reason = "CEZLSMA_LONG";
      return (entry > 0.0 && req.sl > 0.0);
     }

   if(g_short_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.sl = EntryStop(req.type, entry);
      req.reason = "CEZLSMA_SHORT";
      return (entry > 0.0 && req.sl > 0.0);
     }

   return false;
  }

// Tighten SL toward the latest cached CE stop only; never loosen it.
void Strategy_ManageOpenPosition()
  {
   if(!g_signal_valid)
      return;

   ENUM_POSITION_TYPE ptype;
   double profit;
   datetime opened_at;
   double current_sl;
   ulong ticket;
   if(!GetOurPosition(ptype, profit, opened_at, current_sl, ticket))
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY && g_ce_long_stop > 0.0)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double new_sl = NormalizeTradePrice(g_ce_long_stop - (sl_dev_points * point));
      if(new_sl > 0.0 && new_sl < bid && (current_sl <= 0.0 || new_sl > current_sl))
         QM_TM_MoveSL(ticket, new_sl, "cezlsma_ce_stop_long");
     }
   else if(ptype == POSITION_TYPE_SELL && g_ce_short_stop > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double new_sl = NormalizeTradePrice(g_ce_short_stop + (sl_dev_points * point));
      if(new_sl > ask && (current_sl <= 0.0 || new_sl < current_sl))
         QM_TM_MoveSL(ticket, new_sl, "cezlsma_ce_stop_short");
     }
  }

// Close on profitable HA/ZLSMA cross or after the 96-bar M15 baseline time stop.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   double profit;
   datetime opened_at;
   double current_sl;
   ulong ticket;
   if(!GetOurPosition(ptype, profit, opened_at, current_sl, ticket))
      return false;

   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds_per_bar > 0 && opened_at > 0 &&
      (TimeCurrent() - opened_at) >= (time_stop_bars * seconds_per_bar))
      return true;

   if(!g_signal_valid || profit <= 0.0)
      return false;
   if(ptype == POSITION_TYPE_BUY)
      return g_long_exit_cross;
   if(ptype == POSITION_TYPE_SELL)
      return g_short_exit_cross;
   return false;
  }

// Optional news-filter override. The card defers news handling to later phases.
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
