#property strict
#property version   "5.0"
#property description "QM5_9525 — EMA-50 M15 Intraday Retest Bounce"

#include <QM/QM_Common.mqh>

// ============================================================
// QM5_9525 — EMA-50 M15 Intraday Retest Bounce
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9525_mql5-ema50-retest.md
// Source: Clemence Benjamin, MQL5 Articles 2026-02-20
// ============================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9525;
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
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period        = 50;    // EMA period for the retest level (card: InpMAPeriod=50)
input int    strategy_sl_points         = 300;   // Fixed SL in points (card: StopLossPoints=300)
input int    strategy_tp_points         = 600;   // Fixed TP in points (card: TakeProfitPoints=600)
input double strategy_min_body_ratio    = 0.25;  // Minimum body/range ratio for candle confirmation
input bool   strategy_use_defense       = false; // Require prior EMA defense confirmation (optional)
input int    strategy_defense_lookback  = 4;     // Bars to look back for prior EMA defense

// -------- Strategy helpers ----------------------------------------

// Checks whether EMA acted as prior support (bullish=true) or resistance (bullish=false)
// in the bars at shifts 2..strategy_defense_lookback+1 (all closed bars before shift 1).
bool _HasPriorDefense(bool bullish)
  {
   const int lb = (strategy_defense_lookback < 1) ? 1 : (strategy_defense_lookback > 20 ? 20 : strategy_defense_lookback);
   for(int i = 2; i <= lb + 1; i++)
     {
      const double ema_i = QM_EMA(_Symbol, _Period, strategy_ema_period, i);
      if(ema_i <= 0.0)
         continue;
      if(bullish)
        {
         if(iLow(_Symbol, _Period, i) < ema_i && iClose(_Symbol, _Period, i) > ema_i)  // perf-allowed: structural closed-bar check, shift=i
            return true;
        }
      else
        {
         if(iHigh(_Symbol, _Period, i) > ema_i && iClose(_Symbol, _Period, i) < ema_i)  // perf-allowed: structural closed-bar check, shift=i
            return true;
        }
     }
   return false;
  }

// -------- Strategy hooks ------------------------------------------

// No Trade Filter — return true to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   return false; // no session or spread filter by default
  }

// Entry Signal — populate req and return true to open a position.
// Called only when QM_IsNewBar() is true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema1 <= 0.0)
      return false;

   // OHLC of last closed bar — bespoke structural pierce-and-close logic.
   const double open1  = iOpen(_Symbol, _Period, 1);   // perf-allowed: structural closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);   // perf-allowed: structural closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);    // perf-allowed: structural closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: structural closed-bar read

   const double range1 = high1 - low1;
   if(range1 <= 0.0)
      return false;

   const double body_ratio = MathAbs(close1 - open1) / range1;
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double sl = strategy_sl_points * pt;
   const double tp = strategy_tp_points * pt;

   // --- Bullish: bar's low pierces EMA, closes back above with bullish body ---
   if(low1 < ema1 && close1 > ema1 && close1 > open1 && body_ratio >= strategy_min_body_ratio)
     {
      if(strategy_use_defense && !_HasPriorDefense(true))
         return false;
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type             = QM_BUY;
      req.price            = ask;
      req.sl               = ask - sl;
      req.tp               = ask + tp;
      req.symbol_slot      = qm_magic_slot_offset;
      req.reason           = "EMA50_RETEST_LONG";
      req.expiration_seconds = 0;
      return true;
     }

   // --- Bearish: bar's high pierces EMA, closes back below with bearish body ---
   if(high1 > ema1 && close1 < ema1 && close1 < open1 && body_ratio >= strategy_min_body_ratio)
     {
      if(strategy_use_defense && !_HasPriorDefense(false))
         return false;
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type             = QM_SELL;
      req.price            = bid;
      req.sl               = bid + sl;
      req.tp               = bid - tp;
      req.symbol_slot      = qm_magic_slot_offset;
      req.reason           = "EMA50_RETEST_SHORT";
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Trade Management — called every tick when a position is open.
void Strategy_ManageOpenPosition()
  {
   // Positions managed by fixed SL/TP via broker — no active trail required.
  }

// Exit Signal — return true to close the open position immediately.
bool Strategy_ExitSignal()
  {
   return false; // SL/TP exits only; no time or signal exit
  }

// News Filter Hook — return true to suppress trading regardless of qm_news_mode.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework two-axis news filter
  }

// -------- Framework wiring — do NOT edit below --------------------

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

   // Per-closed-bar: entry-signal evaluation.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled.
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
