#property strict
#property version   "5.0"
#property description "QM5_10133 TradingView EMA80 band scalper"

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
input int    qm_ea_id                   = 10133;
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
input int    strategy_ema_fast          = 80;
input int    strategy_ema_band_slow     = 90;
input int    strategy_ema_trend_fast    = 340;
input int    strategy_ema_trend_slow    = 500;
input int    strategy_sma_safety        = 325;
input double strategy_stop_pct          = 0.002;
input double strategy_be_trigger_pct    = 0.003;
input double strategy_secured_pct       = 0.002;
input double strategy_take_profit_pct   = 0.025;
input double strategy_max_spread_frac   = 0.08;
input int    strategy_cooldown_bars     = 100;
input int    strategy_fx_session_start  = 13;
input int    strategy_fx_session_end    = 17;
input int    strategy_dax_session_start = 8;
input int    strategy_dax_session_end   = 12;

bool     g_position_was_open = false;
bool     g_min_profit_activated = false;
datetime g_cooldown_until = 0;

bool IsDaxSymbol()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "DAX") >= 0);
  }

bool InSessionWindow(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool GetOurPosition(ulong &ticket,
                    ENUM_POSITION_TYPE &ptype,
                    double &open_price,
                    double &sl,
                    double &tp)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;

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

      ticket = pos_ticket;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      return true;
     }

   return false;
  }

double NormalizeSymbolPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

bool SpreadAllowed()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask <= bid || strategy_stop_pct <= 0.0)
      return false;

   const double spread = ask - bid;
   const double reference = (ask + bid) * 0.5;
   const double stop_distance = reference * strategy_stop_pct;
   return (stop_distance > 0.0 && spread <= stop_distance * strategy_max_spread_frac);
  }

bool MinProfitActivated(const ENUM_POSITION_TYPE ptype,
                        const double open_price,
                        const double sl)
  {
   if(g_min_profit_activated)
      return true;
   if(open_price <= 0.0 || sl <= 0.0)
      return false;
   if(ptype == POSITION_TYPE_BUY)
      return (sl >= open_price * (1.0 + strategy_secured_pct));
   return (sl <= open_price * (1.0 - strategy_secured_pct));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(TimeCurrent() < g_cooldown_until)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(IsDaxSymbol())
      return !InSessionWindow(dt.hour, strategy_dax_session_start, strategy_dax_session_end);
   return !InSessionWindow(dt.hour, strategy_fx_session_start, strategy_fx_session_end);
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

   if(!SpreadAllowed() || strategy_stop_pct <= 0.0 || strategy_take_profit_pct <= 0.0)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double pos_sl;
   double pos_tp;
   if(GetOurPosition(ticket, ptype, open_price, pos_sl, pos_tp))
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double ema80 = QM_EMA(_Symbol, tf, strategy_ema_fast, 1);
   const double ema90 = QM_EMA(_Symbol, tf, strategy_ema_band_slow, 1);
   const double ema340 = QM_EMA(_Symbol, tf, strategy_ema_trend_fast, 1);
   const double ema500 = QM_EMA(_Symbol, tf, strategy_ema_trend_slow, 1);
   const double sma325 = QM_SMA(_Symbol, tf, strategy_sma_safety, 1);
   const double close1 = iClose(_Symbol, tf, 1);
   const double open1 = iOpen(_Symbol, tf, 1);
   const double high1 = iHigh(_Symbol, tf, 1);
   const double low1 = iLow(_Symbol, tf, 1);
   if(ema80 <= 0.0 || ema90 <= 0.0 || ema340 <= 0.0 || ema500 <= 0.0 ||
      sma325 <= 0.0 || close1 <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double band_high = MathMax(ema80, ema90);
   const double band_low = MathMin(ema80, ema90);
   const bool touched_band = (low1 <= band_high && high1 >= band_low);

   if(ema80 > ema90 && ema90 > ema340 && ema340 > ema500 &&
      touched_band && close1 > open1 && close1 > ema80 && close1 > sma325)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = NormalizeSymbolPrice(ask * (1.0 - strategy_stop_pct));
      req.tp = NormalizeSymbolPrice(ask * (1.0 + strategy_take_profit_pct));
      req.reason = "EMA80_BAND_LONG";
      g_min_profit_activated = false;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(ema80 < ema90 && ema90 < ema340 && ema340 < ema500 &&
      touched_band && close1 < open1 && close1 < ema80 && close1 < sma325)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = NormalizeSymbolPrice(bid * (1.0 + strategy_stop_pct));
      req.tp = NormalizeSymbolPrice(bid * (1.0 - strategy_take_profit_pct));
      req.reason = "EMA80_BAND_SHORT";
      g_min_profit_activated = false;
      return (req.sl > 0.0 && req.tp > 0.0);
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
   double tp;
   const bool has_position = GetOurPosition(ticket, ptype, open_price, sl, tp);
   if(!has_position)
     {
      if(g_position_was_open)
        {
         const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
         g_cooldown_until = TimeCurrent() + (datetime)(MathMax(1, period_seconds) * strategy_cooldown_bars);
         g_min_profit_activated = false;
        }
      g_position_was_open = false;
      return;
     }

   g_position_was_open = true;
   if(open_price <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double trigger = is_buy ? open_price * (1.0 + strategy_be_trigger_pct)
                                 : open_price * (1.0 - strategy_be_trigger_pct);
   const bool reached_trigger = is_buy ? (market >= trigger) : (market <= trigger);
   if(!reached_trigger)
      return;

   g_min_profit_activated = true;
   const double target_sl = NormalizeSymbolPrice(is_buy ? open_price * (1.0 + strategy_secured_pct)
                                                        : open_price * (1.0 - strategy_secured_pct));
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(target_sl <= 0.0 || point <= 0.0)
      return;

   const bool improves = (sl <= 0.0) ||
                         (is_buy ? (target_sl > sl + point * 0.5)
                                 : (target_sl < sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, target_sl, "ema80_secure_profit");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   double tp;
   if(!GetOurPosition(ticket, ptype, open_price, sl, tp))
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double ema80 = QM_EMA(_Symbol, tf, strategy_ema_fast, 1);
   const double ema90 = QM_EMA(_Symbol, tf, strategy_ema_band_slow, 1);
   const double ema340 = QM_EMA(_Symbol, tf, strategy_ema_trend_fast, 1);
   const double ema500 = QM_EMA(_Symbol, tf, strategy_ema_trend_slow, 1);
   const double close1 = iClose(_Symbol, tf, 1);
   if(ema80 <= 0.0 || ema90 <= 0.0 || ema340 <= 0.0 || ema500 <= 0.0 || close1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
     {
      if(ema340 < ema500)
         return true;
      if(MinProfitActivated(ptype, open_price, sl) && close1 < MathMin(ema80, ema90))
         return true;
     }
   else
     {
      if(ema340 > ema500)
         return true;
      if(MinProfitActivated(ptype, open_price, sl) && close1 > MathMax(ema80, ema90))
         return true;
     }

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
