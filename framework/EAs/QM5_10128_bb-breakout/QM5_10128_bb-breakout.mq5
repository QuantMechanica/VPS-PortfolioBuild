#property strict
#property version   "5.0"
#property description "QM5_10128 Bollinger Band One-Sigma Breakout D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10128 — Bollinger Band One-Sigma Breakout
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_10128_bb-breakout.md
// Source: Raposa 2021-07-21, "Trading Bollinger Band Breakouts"
// Strategy: SMA(TP,20) ± 1-sigma on typical price (TP=(H+L+C)/3) per D1 bar.
//   Enter LONG on D1 close above upper band; SHORT on close below lower band.
//   Exit when close re-enters the band (LONG: close<=upper; SHORT: close>=lower).
//   Emergency SL: ATR(14) × strategy_sl_atr_mult (card has no explicit stop).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10128;
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
input int    strategy_bb_period         = 20;    // BB lookback (D1 bars, per card)
input double strategy_bb_dev            = 1.0;   // Entry sigma multiplier (1.0 per card)
input int    strategy_sl_atr_period     = 14;    // ATR period for emergency stop
input double strategy_sl_atr_mult       = 3.0;   // ATR multiplier for emergency stop

// --- Cached closed-bar state (advanced once per D1 bar in AdvanceState_OnNewBar) ---
// QM_BB_Upper/Lower with PRICE_TYPICAL wraps MT5 iBands(PRICE_TYPICAL) — no CopyRates needed.
double g_bb_upper    = 0.0;
double g_bb_lower    = 0.0;
double g_last_close  = 0.0;
bool   g_state_valid = false;

// Called once per closed D1 bar (inside QM_IsNewBar gate in OnTick).
// Reads TP-based Bollinger Bands via QM_BB_Upper/Lower(PRICE_TYPICAL) and
// caches the just-closed bar's close for exit/entry comparison.
void AdvanceState_OnNewBar()
  {
   g_bb_upper = QM_BB_Upper(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_dev, 1, PRICE_TYPICAL);
   g_bb_lower = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_dev, 1, PRICE_TYPICAL);
   g_last_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single shift=1 close read, gated by QM_IsNewBar (once per D1 bar)
   g_state_valid = (g_bb_upper > 0.0 && g_bb_lower > 0.0 &&
                    g_bb_upper > g_bb_lower && g_last_close > 0.0);
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No additional trade filter beyond framework news/Friday/kill-switch.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry on D1 bar close outside the BB bands (called only on new bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_valid)
      return false;

   req.price             = 0.0;
   req.tp                = 0.0;
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_last_close > g_bb_upper)
     {
      req.type   = QM_BUY;
      req.reason = "BB_BREAK_LONG";
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_sl_atr_period, strategy_sl_atr_mult);
      return (req.sl > 0.0);
     }

   if(g_last_close < g_bb_lower)
     {
      req.type   = QM_SELL;
      req.reason = "BB_BREAK_SHORT";
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_sl_atr_period, strategy_sl_atr_mult);
      return (req.sl > 0.0);
     }

   return false;
  }

// No intrabar management; SL set at entry is the only emergency guard.
void Strategy_ManageOpenPosition()
  {
  }

// Exit when close re-enters the band (checked on each closed D1 bar).
bool Strategy_ExitSignal()
  {
   if(!g_state_valid)
      return false;

   const long magic = (long)QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_last_close <= g_bb_upper)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_last_close >= g_bb_lower)
         return true;
     }
   return false;
  }

// Defer to central news filter (no custom override needed).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"bb-breakout\",\"ea\":\"QM5_10128_bb-breakout\"}");
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

   // Both exit and entry are closed-bar signals; gate to new-bar cadence.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Advance cached BB state from the just-closed D1 bar before exit/entry.
   AdvanceState_OnNewBar();
   if(!g_state_valid)
      return;

   if(Strategy_ExitSignal())
     {
      const long magic = (long)QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
