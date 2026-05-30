#property strict
#property version   "5.0"
#property description "QM5_10249 Simple SuperTrend 4H Runner"

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
input int    qm_ea_id                   = 10249;
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
input int    strategy_atr_period        = 10;
input double strategy_atr_mult          = 3.0;
input int    strategy_supertrend_warmup = 120;
input double strategy_partial_rr        = 0.75;
input double strategy_partial_fraction  = 0.50;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;

bool   g_had_position = false;
bool   g_last_position_be_protected = false;
int    g_last_position_dir = 0;
int    g_be_reentry_dir = 0;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool GetOurPosition(ulong &ticket,
                    ENUM_POSITION_TYPE &ptype,
                    double &open_price,
                    double &sl,
                    double &volume)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   volume = 0.0;

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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      volume = PositionGetDouble(POSITION_VOLUME);
      return true;
     }

   return false;
  }

bool BuildSuperTrendAtShift(const int target_shift, int &dir, double &line)
  {
   dir = 0;
   line = 0.0;
   if(strategy_atr_period < 1 || strategy_atr_mult <= 0.0 || target_shift < 1)
      return false;

   int warmup = strategy_supertrend_warmup;
   if(warmup < strategy_atr_period + 5)
      warmup = strategy_atr_period + 5;

   const int oldest = target_shift + warmup;
   double prev_upper = 0.0;
   double prev_lower = 0.0;
   int prev_dir = 0;

   for(int shift = oldest; shift >= target_shift; --shift)
     {
      const double high = iHigh(_Symbol, _Period, shift);
      const double low = iLow(_Symbol, _Period, shift);
      const double close = iClose(_Symbol, _Period, shift);
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         return false;

      const double hl2 = (high + low) * 0.5;
      const double basic_upper = hl2 + strategy_atr_mult * atr;
      const double basic_lower = hl2 - strategy_atr_mult * atr;

      if(shift == oldest)
        {
         prev_upper = basic_upper;
         prev_lower = basic_lower;
         prev_dir = (close >= hl2) ? 1 : -1;
        }
      else
        {
         const double prev_close = iClose(_Symbol, _Period, shift + 1);
         if(prev_close <= 0.0)
            return false;

         const double upper = (basic_upper < prev_upper || prev_close > prev_upper) ? basic_upper : prev_upper;
         const double lower = (basic_lower > prev_lower || prev_close < prev_lower) ? basic_lower : prev_lower;

         int current_dir = prev_dir;
         if(prev_dir < 0 && close > upper)
            current_dir = 1;
         else if(prev_dir > 0 && close < lower)
            current_dir = -1;

         prev_upper = upper;
         prev_lower = lower;
         prev_dir = current_dir;
        }
     }

   dir = prev_dir;
   line = (dir > 0) ? prev_lower : prev_upper;
   line = NormalizeStrategyPrice(line);
   return (dir != 0 && line > 0.0);
  }

bool FillMarketEntry(QM_EntryRequest &req,
                     const QM_OrderType type,
                     const double sl,
                     const string reason)
  {
   const double price = (type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0 || sl <= 0.0)
      return false;
   if(type == QM_BUY && sl >= price)
      return false;
   if(type == QM_SELL && sl <= price)
      return false;

   req.type = type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
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
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double pos_sl;
   double volume;
   if(GetOurPosition(ticket, ptype, open_price, pos_sl, volume))
      return false;

   int dir_1 = 0;
   int dir_2 = 0;
   double st_line_1 = 0.0;
   double st_line_2 = 0.0;
   if(!BuildSuperTrendAtShift(1, dir_1, st_line_1) ||
      !BuildSuperTrendAtShift(2, dir_2, st_line_2))
      return false;

   if(dir_1 > 0 && dir_2 < 0)
      return FillMarketEntry(req, QM_BUY, st_line_1, "ST_FLIP_LONG");

   if(dir_1 < 0 && dir_2 > 0)
      return FillMarketEntry(req, QM_SELL, st_line_1, "ST_FLIP_SHORT");

   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(g_be_reentry_dir > 0 && dir_1 > 0 &&
      rsi_2 <= strategy_rsi_oversold && rsi_1 > strategy_rsi_oversold)
     {
      g_be_reentry_dir = 0;
      return FillMarketEntry(req, QM_BUY, st_line_1, "ST_RSI_BE_REENTRY_LONG");
     }

   if(g_be_reentry_dir < 0 && dir_1 < 0 &&
      rsi_2 >= strategy_rsi_overbought && rsi_1 < strategy_rsi_overbought)
     {
      g_be_reentry_dir = 0;
      return FillMarketEntry(req, QM_SELL, st_line_1, "ST_RSI_BE_REENTRY_SHORT");
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   double volume;
   if(!GetOurPosition(ticket, ptype, open_price, sl, volume))
     {
      if(g_had_position && g_last_position_be_protected)
         g_be_reentry_dir = g_last_position_dir;
      g_had_position = false;
      return;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || open_price <= 0.0 || sl <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   g_had_position = true;
   g_last_position_dir = is_buy ? 1 : -1;
   g_last_position_be_protected = is_buy ? (sl >= open_price - point * 2.0)
                                         : (sl <= open_price + point * 2.0);

   if(g_last_position_be_protected)
      return;

   const double risk = MathAbs(open_price - sl);
   if(risk <= 0.0)
      return;

   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(moved < risk * strategy_partial_rr)
      return;

   const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_fraction);
   if(partial_lots > 0.0 && partial_lots < volume)
      QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL);

   QM_TM_MoveSL(ticket, NormalizeStrategyPrice(open_price), "supertrend_partial_to_be");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   double volume;
   if(!GetOurPosition(ticket, ptype, open_price, sl, volume))
      return false;

   if(!QM_IsNewBar(_Symbol, _Period))
      return false;

   int dir_1 = 0;
   double st_line_1 = 0.0;
   if(!BuildSuperTrendAtShift(1, dir_1, st_line_1))
      return false;

   if(ptype == POSITION_TYPE_BUY && dir_1 < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && dir_1 > 0)
      return true;

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
