#property strict
#property version   "5.0"
#property description "QM5_10447 MQL5 Bollinger RSI FullDump Reversal"

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
input int    qm_ea_id                   = 10447;
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
input int    strategy_bands_period      = 20;
input double strategy_bands_deviation   = 2.0;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;
input int    strategy_highlow_indent_pips = 20;
input int    strategy_depth_search      = 10;
input int    strategy_max_spread_points = 30;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

double Strategy_PipDistance(const int pips)
  {
   if(pips <= 0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return (double)pips * point * pip_factor;
  }

bool Strategy_HasLongSetup()
  {
   const int depth = MathMax(1, strategy_depth_search);
   for(int shift = 1; shift <= depth; ++shift)
     {
      const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, shift);
      const double lower = QM_BB_Lower(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, shift);
      const double low = iLow(_Symbol, _Period, shift);
      if(rsi > 0.0 && lower > 0.0 && low > 0.0 &&
         rsi < strategy_rsi_oversold && low <= lower)
         return true;
     }

   return false;
  }

bool Strategy_HasShortSetup()
  {
   const int depth = MathMax(1, strategy_depth_search);
   for(int shift = 1; shift <= depth; ++shift)
     {
      const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, shift);
      const double upper = QM_BB_Upper(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, shift);
      const double high = iHigh(_Symbol, _Period, shift);
      if(rsi > 0.0 && upper > 0.0 && high > 0.0 &&
         rsi > strategy_rsi_overbought && high >= upper)
         return true;
     }

   return false;
  }

bool Strategy_CrossedAboveMiddle()
  {
   const double c1 = iClose(_Symbol, _Period, 1);
   const double c2 = iClose(_Symbol, _Period, 2);
   const double m1 = QM_BB_Middle(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, 1);
   const double m2 = QM_BB_Middle(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, 2);
   return (c1 > 0.0 && c2 > 0.0 && m1 > 0.0 && m2 > 0.0 && c1 > m1 && c2 <= m2);
  }

bool Strategy_CrossedBelowMiddle()
  {
   const double c1 = iClose(_Symbol, _Period, 1);
   const double c2 = iClose(_Symbol, _Period, 2);
   const double m1 = QM_BB_Middle(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, 1);
   const double m2 = QM_BB_Middle(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, 2);
   return (c1 > 0.0 && c2 > 0.0 && m1 > 0.0 && m2 > 0.0 && c1 < m1 && c2 >= m2);
  }

bool Strategy_BuildEntry(const QM_OrderType side, QM_EntryRequest &req)
  {
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double indent = Strategy_PipDistance(strategy_highlow_indent_pips);
   const double structure_stop = QM_StopStructure(_Symbol, side, entry, MathMax(1, strategy_depth_search));
   if(indent <= 0.0 || structure_stop <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = (side == QM_BUY) ? NormalizeDouble(structure_stop - indent, _Digits)
                             : NormalizeDouble(structure_stop + indent, _Digits);
   req.tp = (side == QM_BUY)
            ? NormalizeDouble(QM_BB_Upper(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, 1), _Digits)
            : NormalizeDouble(QM_BB_Lower(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, 1), _Digits);
   req.reason = (side == QM_BUY) ? "FULLDUMP_BB_RSI_LONG" : "FULLDUMP_BB_RSI_SHORT";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(side == QM_BUY && (req.sl >= entry || req.tp <= entry))
      return false;
   if(side == QM_SELL && (req.sl <= entry || req.tp >= entry))
      return false;

   return true;
  }

// No Trade Filter (time, spread, news): time has no card restriction; news is
// handled by Strategy_NewsFilterHook/framework; this hook enforces spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: RSI/Bollinger setup inside depth window, then middle-band cross.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(strategy_bands_period <= 1 || strategy_rsi_period <= 1 ||
      strategy_bands_deviation <= 0.0 || strategy_depth_search <= 0)
      return false;

   if(Strategy_HasLongSetup() && Strategy_CrossedAboveMiddle())
      return Strategy_BuildEntry(QM_BUY, req);

   if(Strategy_HasShortSetup() && Strategy_CrossedBelowMiddle())
      return Strategy_BuildEntry(QM_SELL, req);

   return false;
  }

// Trade Management: move SL to breakeven after the current opposite outer band
// has been reached, matching the source management rule.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0)
         continue;

      if(position_type == POSITION_TYPE_BUY)
        {
         const double upper = QM_BB_Upper(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, 1);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(upper > 0.0 && bid >= upper && (current_sl <= 0.0 || current_sl < open_price))
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "bb_upper_breakeven");
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         const double lower = QM_BB_Lower(_Symbol, _Period, strategy_bands_period, strategy_bands_deviation, 1);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(lower > 0.0 && ask <= lower && (current_sl <= 0.0 || current_sl > open_price))
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "bb_lower_breakeven");
        }
     }
  }

// Trade Close: exits are handled by initial SL/TP plus framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no custom override; framework news axes remain authoritative.
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
