#property strict
#property version   "5.0"
#property description "QM5_1123 Unger crude previous-day mean reversion"
// Strategy Card: eb97a148-0af9-5b9c-878c-25fb5dfa34f9 (unger-crude-prevday-meanrev), G0 APPROVED 2026-05-17.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1123;
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
// Card §Entry: LOW_TRIGGER=min(prev day low, low 5 sessions earlier);
// HIGH_TRIGGER=max(prev day high, high 5 sessions earlier); reclaim entry.
input int    strategy_atr_period               = 14;    // Card §Stop Loss: ATR(14,M15).
input double strategy_atr_sl_mult              = 1.5;   // Card §Stop Loss: SL = 1.5 * ATR.
input bool   strategy_use_vwap_target           = true;  // Card §Exit: prior-day (H+L+C)/3 target, default enabled.
input double strategy_tp_rr                     = 1.0;   // Card §Stop Loss: optional 1.0R TP when VWAP target disabled.
input int    strategy_atr_percentile_lookback   = 120;   // Card §Filter: 120-day ATR percentile window.
input double strategy_atr_percentile_pct        = 25.0;  // Card §Filter: skip below this ATR percentile.
input bool   strategy_skip_eia_day              = true;  // Card §Filter: skip EIA inventory release day.
input int    strategy_eia_day_of_week           = 3;     // Sunday=0 .. Wednesday=3 (weekly EIA release proxy; holiday-shifted Thursdays not modeled).
input int    strategy_session_start_hhmm        = 0;     // Broker-time HHMM entry window start.
input int    strategy_flatten_hhmm              = 2200;  // Card §Exit: EOD flatten + entry cutoff, broker time HHMM.
input int    strategy_max_spread_points         = 80;    // Card §Filter: standard V5 spread filter; zero spread stays tradeable.

// -----------------------------------------------------------------------------
// Cached per-day state (recomputed once per D1 calendar-period roll).
// -----------------------------------------------------------------------------
double g_low_trigger        = 0.0;
double g_high_trigger       = 0.0;
double g_vwap_proxy         = 0.0;
bool   g_atr_filter_ok      = false;
bool   g_long_taken_today   = false;
bool   g_short_taken_today  = false;
bool   g_stopped_out_today  = false;

// Tracked open-position lifecycle (for same-day-stopout detection).
ulong  g_open_ticket        = 0;
long   g_open_position_id   = 0;
int    g_open_dir           = 0; // +1 long, -1 short, 0 none

bool Strategy_DailyAtrFilterAllows()
  {
   if(strategy_atr_percentile_lookback < 20)
      return true;

   double samples[];
   ArrayResize(samples, strategy_atr_percentile_lookback);
   int count = 0;
   for(int shift = 1; shift <= strategy_atr_percentile_lookback; ++shift)
     {
      const double v = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(v > 0.0)
        {
         samples[count] = v;
         ++count;
        }
     }
   // Insufficient warmup history: fail-open so the early backtest window is
   // not permanently blocked before 120 D1 bars exist.
   if(count < 20)
      return true;

   ArrayResize(samples, count);
   ArraySort(samples);

   double pct = strategy_atr_percentile_pct;
   if(pct < 0.0)
      pct = 0.0;
   if(pct > 100.0)
      pct = 100.0;
   int idx = (int)MathFloor((pct / 100.0) * (count - 1));
   if(idx < 0)
      idx = 0;
   if(idx >= count)
      idx = count - 1;

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   return current_atr >= samples[idx];
  }

void Strategy_RecomputeDailyState()
  {
   g_long_taken_today  = false;
   g_short_taken_today = false;
   g_stopped_out_today = false;
   g_low_trigger       = 0.0;
   g_high_trigger      = 0.0;
   g_vwap_proxy        = 0.0;
   g_atr_filter_ok     = false;

   MqlRates prev_day, five_day;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, prev_day) || !QM_ReadBar(_Symbol, PERIOD_D1, 5, five_day))
      return;

   g_low_trigger  = MathMin(prev_day.low,  five_day.low);
   g_high_trigger = MathMax(prev_day.high, five_day.high);
   g_vwap_proxy   = (prev_day.high + prev_day.low + prev_day.close) / 3.0;
   g_atr_filter_ok = Strategy_DailyAtrFilterAllows();
  }

// No Trade Filter: session window, EIA-day suppression, spread guard.
// Cheap O(1) checks only; the D1-cadence trigger/ATR recompute lives in
// Strategy_EntrySignal (gated behind QM_IsNewBar()), not here.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hhmm = dt.hour * 100 + dt.min;
   if(hhmm < strategy_session_start_hhmm || hhmm >= strategy_flatten_hhmm)
      return true;

   // EIA Petroleum Status Report ~10:30 ET; DXZ broker time = ET+7h year-round
   // (broker DST tracks US DST), so the release lands ~17:30-18:30 broker.
   // Wednesday is the standard release day; holiday-shifted Thursdays are a
   // documented gap (see SPEC.md / open_questions).
   if(strategy_skip_eia_day && dt.day_of_week == strategy_eia_day_of_week)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   // .DWX quotes ask==bid (0 modeled spread) in the tester; only block a
   // genuinely wide spread, never zero/degenerate spread.
   if(ask > bid && ((ask - bid) / point) > strategy_max_spread_points)
      return true;

   return false;
  }

// Trade Entry: prior-day/five-session extreme reclaim, one trade per
// direction per day, no reversal after a same-day stopout (card §Entry item 5).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_IsNewCalendarPeriod(PERIOD_D1))
      Strategy_RecomputeDailyState();

   if(g_low_trigger <= 0.0 || g_high_trigger <= 0.0 || !g_atr_filter_ok)
      return false;

   if(g_open_ticket != 0)
      return false;

   if(g_stopped_out_today)
      return false;

   MqlRates bar;
   if(!QM_ReadBar(_Symbol, PERIOD_M15, 1, bar))
      return false;

   const bool long_ready  = (bar.low  < g_low_trigger)  && (bar.close >= g_low_trigger);
   const bool short_ready = (bar.high > g_high_trigger) && (bar.close <= g_high_trigger);

   if(long_ready && !g_long_taken_today)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_sl_mult);
      if(entry_price <= 0.0 || sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = strategy_use_vwap_target
                   ? ((g_vwap_proxy > entry_price) ? QM_StopRulesNormalizePrice(_Symbol, g_vwap_proxy) : 0.0)
                   : ((strategy_tp_rr > 0.0) ? QM_TakeRR(_Symbol, QM_BUY, entry_price, sl, strategy_tp_rr) : 0.0);
      req.reason = "prevday_5session_reclaim_long";
      req.symbol_slot = 0;
      req.expiration_seconds = 0;
      g_long_taken_today = true;
      return true;
     }

   if(short_ready && !g_short_taken_today)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = QM_StopATR(_Symbol, QM_SELL, entry_price, strategy_atr_period, strategy_atr_sl_mult);
      if(entry_price <= 0.0 || sl <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = strategy_use_vwap_target
                   ? ((g_vwap_proxy < entry_price) ? QM_StopRulesNormalizePrice(_Symbol, g_vwap_proxy) : 0.0)
                   : ((strategy_tp_rr > 0.0) ? QM_TakeRR(_Symbol, QM_SELL, entry_price, sl, strategy_tp_rr) : 0.0);
      req.reason = "prevday_5session_reclaim_short";
      req.symbol_slot = 0;
      req.expiration_seconds = 0;
      g_short_taken_today = true;
      return true;
     }

   return false;
  }

// Trade Management: VWAP-proxy mean-reversion target close, plus same-day
// stopout tracking for the "no reversal after a stopout" entry gate.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   bool found = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      found = true;
      if(g_open_ticket == 0)
        {
         g_open_ticket      = ticket;
         g_open_position_id = (long)PositionGetInteger(POSITION_IDENTIFIER);
         g_open_dir         = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
        }

      if(strategy_use_vwap_target && g_vwap_proxy > 0.0)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(g_open_dir > 0 && bid >= g_vwap_proxy)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         else if(g_open_dir < 0 && ask <= g_vwap_proxy)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      break; // one position per magic (card §Filter).
     }

   if(!found && g_open_ticket != 0)
     {
      if(HistorySelectByPosition(g_open_position_id))
        {
         for(int d = HistoryDealsTotal() - 1; d >= 0; --d)
           {
            const ulong deal_ticket = HistoryDealGetTicket(d);
            if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
               continue;
            if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON) == DEAL_REASON_SL)
               g_stopped_out_today = true;
            break;
           }
        }
      g_open_ticket      = 0;
      g_open_position_id = 0;
      g_open_dir         = 0;
     }
  }

// Trade Close: flatten all open positions before session end (card §Exit).
bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hhmm = dt.hour * 100 + dt.min;
   return (hhmm >= strategy_flatten_hhmm);
  }

// News Filter Hook: defers to the central V5 2-axis news filter (card §Filter
// "Standard V5 spread/news filters").
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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
