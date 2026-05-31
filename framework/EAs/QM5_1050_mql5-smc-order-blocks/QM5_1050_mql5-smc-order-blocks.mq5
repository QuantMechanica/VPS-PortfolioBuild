#property strict
#property version   "5.0"
#property description "QM5_1050 SMC Order Blocks + Break of Structure"

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
input int    qm_ea_id                   = 1050;
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
input ENUM_TIMEFRAMES strategy_trend_tf           = PERIOD_H4;
input int             strategy_ob_lookback        = 20;
input int             strategy_bos_lookback       = 10;
input int             strategy_atr_period         = 14;
input double          strategy_impulse_atr_mult   = 1.5;
input int             strategy_sl_offset_points   = 10;
input double          strategy_rr                 = 4.0;
input int             strategy_session_start_hour = 7;
input int             strategy_session_end_hour   = 17;
input int             strategy_max_spread_points  = 20;
input bool            strategy_require_inducement = false;
input bool            strategy_move_be_after_1r   = true;

struct SMC_OrderBlock
  {
   bool     valid;
   bool     bullish;
   double   high;
   double   low;
   datetime time;
  };

int            g_smc_trend = 0;
bool           g_smc_bos_up = false;
bool           g_smc_bos_down = false;
bool           g_smc_induce_up = false;
bool           g_smc_induce_down = false;
SMC_OrderBlock g_smc_bullish_ob;
SMC_OrderBlock g_smc_bearish_ob;

int BrokerHour()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
  }

bool SessionAllowsHour(const int hour)
  {
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour));
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (hour >= start_h && hour < end_h);
   return (hour >= start_h || hour < end_h);
  }

double HighestHigh(const ENUM_TIMEFRAMES tf, const int first_shift, const int bars)
  {
   double value = -DBL_MAX;
   const int n = MathMax(1, bars);
   for(int i = first_shift; i < first_shift + n; ++i)
     {
      const double high = iHigh(_Symbol, tf, i);
      if(high <= 0.0)
         return 0.0;
      value = MathMax(value, high);
     }
   return value;
  }

double LowestLow(const ENUM_TIMEFRAMES tf, const int first_shift, const int bars)
  {
   double value = DBL_MAX;
   const int n = MathMax(1, bars);
   for(int i = first_shift; i < first_shift + n; ++i)
     {
      const double low = iLow(_Symbol, tf, i);
      if(low <= 0.0)
         return 0.0;
      value = MathMin(value, low);
     }
   return value;
  }

int ReadTrendDirection()
  {
   const int n = MathMax(3, strategy_bos_lookback);
   const double recent_high = HighestHigh(strategy_trend_tf, 1, n);
   const double prior_high = HighestHigh(strategy_trend_tf, 1 + n, n);
   const double recent_low = LowestLow(strategy_trend_tf, 1, n);
   const double prior_low = LowestLow(strategy_trend_tf, 1 + n, n);
   if(recent_high <= 0.0 || prior_high <= 0.0 || recent_low <= 0.0 || prior_low <= 0.0)
      return 0;
   if(recent_high > prior_high && recent_low > prior_low)
      return 1;
   if(recent_high < prior_high && recent_low < prior_low)
      return -1;
   return 0;
  }

bool FindOrderBlock(const bool bullish, SMC_OrderBlock &ob)
  {
   ob.valid = false;
   ob.bullish = bullish;
   ob.high = 0.0;
   ob.low = 0.0;
   ob.time = 0;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double atr = QM_ATR(_Symbol, tf, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0 || strategy_impulse_atr_mult <= 0.0)
      return false;

   const int n = MathMax(3, strategy_ob_lookback);
   for(int shift = 2; shift <= n; ++shift)
     {
      const double ob_open = iOpen(_Symbol, tf, shift);
      const double ob_close = iClose(_Symbol, tf, shift);
      const double ob_high = iHigh(_Symbol, tf, shift);
      const double ob_low = iLow(_Symbol, tf, shift);
      const double imp_open = iOpen(_Symbol, tf, shift - 1);
      const double imp_close = iClose(_Symbol, tf, shift - 1);
      const double imp_high = iHigh(_Symbol, tf, shift - 1);
      const double imp_low = iLow(_Symbol, tf, shift - 1);
      if(ob_open <= 0.0 || ob_close <= 0.0 || ob_high <= 0.0 || ob_low <= 0.0 ||
         imp_open <= 0.0 || imp_close <= 0.0 || imp_high <= 0.0 || imp_low <= 0.0)
         continue;

      if((imp_high - imp_low) < atr * strategy_impulse_atr_mult)
         continue;

      if(bullish && ob_close < ob_open && imp_close > imp_open && imp_close > ob_high)
        {
         ob.valid = true;
         ob.bullish = true;
         ob.high = ob_high;
         ob.low = ob_low;
         ob.time = iTime(_Symbol, tf, shift);
         return true;
        }

      if(!bullish && ob_close > ob_open && imp_close < imp_open && imp_close < ob_low)
        {
         ob.valid = true;
         ob.bullish = false;
         ob.high = ob_high;
         ob.low = ob_low;
         ob.time = iTime(_Symbol, tf, shift);
         return true;
        }
     }

   return false;
  }

void AdvanceState_OnNewBar()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int n = MathMax(3, strategy_bos_lookback);
   const double close1 = iClose(_Symbol, tf, 1);
   const double prior_high = HighestHigh(tf, 2, n);
   const double prior_low = LowestLow(tf, 2, n);
   if(close1 <= 0.0 || prior_high <= 0.0 || prior_low <= 0.0)
      return;

   g_smc_trend = ReadTrendDirection();
   g_smc_bos_up = (close1 > prior_high);
   g_smc_bos_down = (close1 < prior_low);
   if(g_smc_bos_up)
      g_smc_bos_down = false;
   if(g_smc_bos_down)
      g_smc_bos_up = false;

   const int induce_n = MathMax(3, MathMin(strategy_bos_lookback, strategy_ob_lookback));
   const double low2 = iLow(_Symbol, tf, 2);
   const double high2 = iHigh(_Symbol, tf, 2);
   const double close2 = iClose(_Symbol, tf, 2);
   const double induce_low = LowestLow(tf, 3, induce_n);
   const double induce_high = HighestHigh(tf, 3, induce_n);
   g_smc_induce_up = (low2 > 0.0 && close2 > 0.0 && induce_low > 0.0 && low2 < induce_low && close2 > induce_low);
   g_smc_induce_down = (high2 > 0.0 && close2 > 0.0 && induce_high > 0.0 && high2 > induce_high && close2 < induce_high);

   SMC_OrderBlock bullish_ob;
   SMC_OrderBlock bearish_ob;
   if(FindOrderBlock(true, bullish_ob))
      g_smc_bullish_ob = bullish_ob;
   if(FindOrderBlock(false, bearish_ob))
      g_smc_bearish_ob = bearish_ob;
  }

bool SelectOurPosition(ulong &ticket, double &open_price, double &sl, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   open_price = 0.0;
   sl = 0.0;
   ptype = POSITION_TYPE_BUY;

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

      ticket = t;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
// Return TRUE to BLOCK trading this tick. Cheap O(1) checks only.
bool Strategy_NoTradeFilter()
  {
   if(!SessionAllowsHour(BrokerHour()))
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > strategy_max_spread_points)
      return true;

   return false;
  }

// Trade Entry
// Populate `req` with entry order parameters and return TRUE on this closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   AdvanceState_OnNewBar();

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double close1 = iClose(_Symbol, tf, 1);
   const double close2 = iClose(_Symbol, tf, 2);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || close1 <= 0.0 || close2 <= 0.0 || strategy_rr <= 0.0)
      return false;

   const bool inducement_long_ok = (!strategy_require_inducement || g_smc_induce_up);
   const bool inducement_short_ok = (!strategy_require_inducement || g_smc_induce_down);

   if(g_smc_trend > 0 && g_smc_bos_up && inducement_long_ok && g_smc_bullish_ob.valid)
     {
      if(close2 >= g_smc_bullish_ob.low && close2 <= g_smc_bullish_ob.high && close1 > g_smc_bullish_ob.high)
        {
         req.type = QM_BUY;
         req.price = ask;
         req.sl = g_smc_bullish_ob.low - strategy_sl_offset_points * point;
         req.tp = ask + (ask - req.sl) * strategy_rr;
         req.reason = "SMC_BULLISH_OB_BOS_RETEST";
         return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
        }
     }

   if(g_smc_trend < 0 && g_smc_bos_down && inducement_short_ok && g_smc_bearish_ob.valid)
     {
      if(close2 <= g_smc_bearish_ob.high && close2 >= g_smc_bearish_ob.low && close1 < g_smc_bearish_ob.low)
        {
         req.type = QM_SELL;
         req.price = bid;
         req.sl = g_smc_bearish_ob.high + strategy_sl_offset_points * point;
         req.tp = bid - (req.sl - bid) * strategy_rr;
         req.reason = "SMC_BEARISH_OB_BOS_RETEST";
         return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
        }
     }

   return false;
  }

// Trade Management
// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_move_be_after_1r)
      return;

   ulong ticket = 0;
   double open_price = 0.0;
   double sl = 0.0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, open_price, sl, ptype))
      return;
   if(open_price <= 0.0 || sl <= 0.0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double risk = open_price - sl;
      if(risk > 0.0 && bid >= open_price + risk && sl < open_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price + point, _Digits), "smc_move_be_after_1r");
     }
   else
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk = sl - open_price;
      if(risk > 0.0 && ask <= open_price - risk && sl > open_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price - point, _Digits), "smc_move_be_after_1r");
     }
  }

// Trade Close
// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
// Return TRUE to suppress trading regardless of framework news mode.
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
