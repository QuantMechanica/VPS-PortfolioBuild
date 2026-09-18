#property strict
#property version   "5.0"
#property description "QM5_41477 fx-session-mean-reversion-m15 — session-flat FX session mean reversion (M15)"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>
#include <QM/QM_ChartPanelCompare.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_41477 fx-session-mean-reversion-m15
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md
//   (QM-RESEARCH-2026-0005 H-FXMR; preregistration c408f534...7475).
// Strategy logic: QM5_41477_FxSessionMrCore.mqh (the five Strategy_* hooks
// below delegate to it). Everything else is framework wiring and MUST stay
// intact.
//
// REGISTRY STATUS: ALLOCATED — governed allocator wrote active
// ea_id_registry.csv / magic_numbers.csv rows (magic = ea_id*10000 + slot,
// slots per approved-card symbol order) and QM_MagicResolver.mqh carries the
// tuples; the earlier PENDING_ALLOCATION note is historical (see the build
// receipt under docs/ops/evidence/). Updated 2026-09-18 (Fable critic pass).
//
// Session hours are inputs in UTC (card semantics); broker time is mapped to
// UTC through the shared QM_DSTAware include — no hand-rolled DST. Symbols
// are inputs, never literals: one input per symbol slot; the chart symbol
// must equal strategy_symbol_slot<qm_magic_slot_offset>.
//
// .DWX invariants honoured: zero modeled spread fails open in the spread
// filter (only a genuinely wide spread blocks); no external feed; native MT5
// news calendar only; session-flat so no overnight gap/swap tail.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41477;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;
input bool   qm_show_chart_panel        = true;
input bool   qm_apply_chart_scheme      = true;
input string qm_panel_build_hash        = "UNBOUND";
input QM_ConsoleMode qm_dashboard_mode  = QM_CONSOLE_FULL;
input QM_ConsoleDesign qm_design_version = QM_DESIGN_2; // 01/02 also switches in-chart without EA restart
input int    qm_visual_scale            = 100; // 80-150, presentation only
input QM_ConsoleLocale qm_number_locale = QM_LOCALE_DE_DE;
input bool   qm_show_active_range       = true;
input bool   qm_show_strategy_levels    = true;
input bool   qm_show_trade_levels       = true;
input bool   qm_show_trade_markers      = true;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// The card's news gate is the strategy-level high-impact blackout
// (strategy_news_blackout_minutes, fail-closed) evaluated in the new-bar
// entry path. The framework two-axis filter stays at its OFF defaults so the
// blackout is governed by the single card parameter.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_symbol_slot0      = "EURUSD.DWX"; // symbol slot 0 (magic ...000)
input string strategy_symbol_slot1      = "GBPUSD.DWX"; // symbol slot 1 (magic ...001)
input string strategy_symbol_slot2      = "USDJPY.DWX"; // symbol slot 2 (magic ...002)
input int    strategy_stretch_bars           = 3;     // 2..4 consecutive same-direction closes
input int    strategy_ema_period             = 14;    // 10..20 short EMA
input double strategy_stretch_atr_mult       = 1.0;   // 0.5..1.5 x ATR close-vs-EMA stretch
input int    strategy_atr_period             = 14;    // 10..20
input double strategy_stop_buffer_atr        = 0.25;  // 0.1..0.5 x ATR beyond stretch extreme
input double strategy_max_stop_atr           = 2.0;   // 1.5..2.5 x ATR stop-distance cap
input double strategy_target_r               = 1.25;  // 1.0..1.5 x stop distance
input int    strategy_time_stop_bars         = 10;    // 8..16 M15 bars
input double strategy_risk_per_trade_pct     = 0.25;  // 0.20..0.50 (live RISK_PERCENT basis)
input double strategy_daily_stop_pct         = -1.0;  // fixed by card
input double strategy_weekly_stop_pct        = -2.0;  // fixed by card
input double strategy_shock_atr_mult         = 2.0;   // 1.5..2.5 x ATR first window bar
input double strategy_spread_median_mult     = 1.5;   // 1.25..1.75 x 20-day median
input int    strategy_london_start_hour_utc  = 7;     // 7..8 UTC
input int    strategy_london_end_hour_utc    = 11;    // 10..12 UTC (exclusive)
input int    strategy_ny_start_hour_utc      = 12;    // 12..13 UTC
input int    strategy_ny_end_hour_utc        = 16;    // 15..16 UTC (exclusive)
input int    strategy_london_flat_min_utc    = 690;   // 660..720 = 11:00..12:00 UTC mandatory flat
input int    strategy_ny_flat_min_utc        = 990;   // 960..1020 = 16:00..17:00 UTC mandatory flat
input int    strategy_friday_cutoff_min_utc  = 840;   // 780..900 = 13:00..15:00 UTC Friday cutoff
input int    strategy_skip_first_minutes     = 15;    // 0..30 skip after window open
input int    strategy_max_positions_total    = 3;     // 2..4 across the EA family
input int    strategy_max_trades_per_day     = 4;     // 2..6 per symbol per UTC day
input int    strategy_news_blackout_minutes  = 30;    // 0..120 min around high-impact events
input int    strategy_spread_min_days        = 5;     // daily medians required before enforcing

#include "QM5_41477_FxSessionMrCore.mqh"

CQMChartPanelCompare g_fxmr_panel;

// EA identity comes from the registered source filename, not renderer copy.
string QM41477_ConsoleStrategyName()
  {
   string name = MQLInfoString(MQL_PROGRAM_NAME);
   const string prefix = "QM5_" + IntegerToString(qm_ea_id) + "_";
   if(StringFind(name, prefix) == 0)
      name = StringSubstr(name, StringLen(prefix));
   string words[];
   const int count = StringSplit(name, '-', words);
   string title = "";
   for(int i = 0; i < count; ++i)
     {
      string word = words[i];
      if(i == count - 1 && word == "m15")
         continue; // registered slug suffix, not chart identity
      if(StringLen(word) > 0)
        {
         string first = StringSubstr(word, 0, 1);
         StringToUpper(first);
         word = first + StringSubstr(word, 1);
        }
      title += (title == "" ? "" : " ") + word;
     }
   return title;
  }

// Resolve the chart symbol to its slot input. Returns -1 when the chart
// symbol matches no declared slot.
int QM41477_ResolveSlot()
  {
   const string slots[3] = {strategy_symbol_slot0, strategy_symbol_slot1, strategy_symbol_slot2};
   for(int i = 0; i < 3; ++i)
     {
      if(slots[i] != "" && slots[i] == _Symbol)
         return i;
     }
   return -1;
  }

void QM41477_RefreshChartPanel()
  {
   if(!g_fxmr_panel.Ready())
      return;

   QM_ConsoleSnapshot snapshot;
   snapshot.Reset();
   snapshot.strategy_name = QM41477_ConsoleStrategyName();
   snapshot.timeframe = QM_PanelTimeframeName((ENUM_TIMEFRAMES)_Period);
   snapshot.symbol = _Symbol;
   snapshot.environment = QM_PanelEnvironment();
   snapshot.version = "5.0";
   snapshot.state = QM_CONSOLE_WAITING_SETUP;
   snapshot.reason = "Session reversion evaluated on the next M15 bar";

   const datetime now = TimeCurrent();
   const datetime bar = iTime(_Symbol, PERIOD_M15, 0);
   const datetime next = bar + PeriodSeconds(PERIOD_M15);
   snapshot.next_event = (bar > 0 && next > now)
      ? "Next M15 evaluation in " + QM_PanelDuration((long)(next - now)) + " | " + QM_PanelDateTime(next) + " BT"
      : "Next M15 evaluation on a fresh market quote";

   const bool terminal_ready = TerminalInfoInteger(TERMINAL_CONNECTED) &&
      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
      AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   QM_ConsoleAddGate(snapshot, "execution", "Execution", terminal_ready ? "Permission open" : "Permission off",
                     terminal_ready ? QM_GATE_PASS : QM_GATE_BLOCK);

   const bool news_enabled = (strategy_news_blackout_minutes > 0);
   QM_ConsoleAddGate(snapshot, "news", "News blackout",
                     !news_enabled ? "Disabled" : (g_fxmr_news_cache_blocked ? "Blackout window" : "Clear"),
                     !news_enabled ? QM_GATE_OFF : (g_fxmr_news_cache_blocked ? QM_GATE_BLOCK : QM_GATE_PASS));
   QM_ConsoleAddGate(snapshot, "kill", "Kill switch", g_qm_ks_halted ? "Halted" : "Armed",
                     g_qm_ks_halted ? QM_GATE_BLOCK : QM_GATE_PASS);

   const int minute_of_day = FxmrUtcMinuteOfDay(now);
   const int session = FxmrSessionAtMinute(minute_of_day);
   string session_text;
   QM_ConsoleGateState session_gate;
   if(minute_of_day >= strategy_ny_flat_min_utc)
     {
      session_text = "Flat window (day)";
      session_gate = QM_GATE_BLOCK;
     }
   else if(minute_of_day >= strategy_london_flat_min_utc &&
           minute_of_day < strategy_ny_start_hour_utc * 60)
     {
      session_text = "Lunch gap (flat)";
      session_gate = QM_GATE_BLOCK;
     }
   else if(session == 1)
     {
      session_text = "London window";
      session_gate = QM_GATE_PASS;
     }
   else if(session == 2)
     {
      session_text = "NY window";
      session_gate = QM_GATE_PASS;
     }
   else
     {
      session_text = "Before window";
      session_gate = QM_GATE_WAIT;
     }
   QM_ConsoleAddGate(snapshot, "session", "Session", session_text, session_gate);

   MqlDateTime utc_now;
   FxmrUtcStruct(now, utc_now);
   QM_ConsoleAddGate(snapshot, "friday", "Friday cutoff",
                     (utc_now.day_of_week == 5 && minute_of_day >= strategy_friday_cutoff_min_utc)
                        ? "Cutoff reached" : "Before cutoff",
                     (utc_now.day_of_week == 5 && minute_of_day >= strategy_friday_cutoff_min_utc)
                        ? QM_GATE_BLOCK : QM_GATE_PASS);
   QM_ConsoleAddGate(snapshot, "shock", "Shock filter",
                     (g_fxmr_shock_london || g_fxmr_shock_ny) ? "Window shock" : "Clear",
                     (g_fxmr_shock_london || g_fxmr_shock_ny) ? QM_GATE_BLOCK : QM_GATE_PASS);
   QM_ConsoleAddGate(snapshot, "breaker_day", "Daily breaker",
                     g_fxmr_breaker_day_hit ? "Hit (-1.0%)" : "Armed",
                     g_fxmr_breaker_day_hit ? QM_GATE_BLOCK : QM_GATE_PASS);
   QM_ConsoleAddGate(snapshot, "breaker_week", "Weekly breaker",
                     g_fxmr_breaker_week_hit ? "Hit (-2.0%)" : "Armed",
                     g_fxmr_breaker_week_hit ? QM_GATE_BLOCK : QM_GATE_PASS);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const bool quote = (point > 0.0 && ask > 0.0 && bid > 0.0);
   FxmrSpreadMedianRefresh();
   const int spread_days = ArraySize(g_fxmr_daily_median);
   QM_ConsoleAddGate(snapshot, "spread", "Spread vs 20d median",
                     !quote ? "No valid quote"
                            : (spread_days < strategy_spread_min_days
                                  ? "Warmup " + IntegerToString(spread_days) + "/" + IntegerToString(strategy_spread_min_days) + " days"
                                  : (g_fxmr_spread_median > 0.0
                                        ? "Median " + QM_PanelFormatNumber(g_fxmr_spread_median, 1) + " pts"
                                        : "No median")),
                     !quote ? QM_GATE_WARN : QM_GATE_PASS);

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double next_risk = (g_qm_risk_mode == QM_RISK_MODE_PERCENT
                          ? equity * g_qm_risk_percent / 100.0
                          : g_qm_risk_fixed) * g_qm_risk_portfolio_weight;
   const double cap = (g_qm_risk_mode == QM_RISK_MODE_PERCENT && g_qm_risk_per_trade_cap_pct > 0.0)
                         ? equity * g_qm_risk_per_trade_cap_pct / 100.0
                         : g_qm_risk_per_trade_cap_money;
   if(cap > 0.0)
      next_risk = MathMin(next_risk, cap);
   QM_ConsoleAddLine(snapshot.risk, "Next trade",
                     QM_PanelPercent(equity > 0.0 ? next_risk / equity * 100.0 : 0.0) + " | " + QM_PanelMoney(next_risk));
   QM_ConsoleAddLine(snapshot.risk, "Risk basis",
                     "Card " + QM_PanelPercent(strategy_risk_per_trade_pct) + " live | stretch stop x " +
                     QM_PanelFormatNumber(strategy_stop_buffer_atr, 2) + " buf | TP " +
                     QM_PanelFormatNumber(strategy_target_r, 2) + "R");

   const int family = FxmrPortfolioPositionCount();
   QM_ConsoleAddGate(snapshot, "capacity", "Capacity",
                     IntegerToString(family) + "/" + IntegerToString(strategy_max_positions_total) + " positions",
                     family >= strategy_max_positions_total ? QM_GATE_BLOCK : QM_GATE_PASS);
   QM_ConsoleAddGate(snapshot, "day_trades", "Day trades",
                     IntegerToString(g_fxmr_trades_today) + "/" + IntegerToString(strategy_max_trades_per_day),
                     g_fxmr_trades_today >= strategy_max_trades_per_day ? QM_GATE_BLOCK : QM_GATE_PASS);

   // Stretch reference range of the current candidate (bars 2..stretch_bars+1).
   if(g_fxmr_stretch_ready)
     {
      MqlDateTime utc_bar;
      FxmrUtcStruct(now, utc_bar);
      const datetime bar2 = iTime(_Symbol, PERIOD_M15, 2);
      const datetime barN = iTime(_Symbol, PERIOD_M15, strategy_stretch_bars + 1);
      snapshot.range_start = (barN > 0) ? barN : now;
      snapshot.range_end = (bar2 > 0) ? bar2 + PeriodSeconds(PERIOD_M15) : now;
      snapshot.range_high = g_fxmr_stretch_high;
      snapshot.range_low = g_fxmr_stretch_low;
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      snapshot.range_high_text = QM_PanelFormatNumber(snapshot.range_high, digits);
      snapshot.range_low_text = QM_PanelFormatNumber(snapshot.range_low, digits);
      snapshot.active_range = true;
     }

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   if(FxmrSelectOurPosition(ticket, ptype, open_price, sl))
     {
      snapshot.state = QM_CONSOLE_POSITION_ACTIVE;
      snapshot.reason = "Position managed by SL/TP, time stop and session flat";
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const long held_bars = (opened > 0) ? (long)((now - opened) / PeriodSeconds(PERIOD_M15)) : 0;
      const long left_bars = (long)strategy_time_stop_bars - held_bars;
      snapshot.next_event = "Time stop in " + IntegerToString((int)MathMax(0, left_bars)) + " bars | flat by " +
                            ((ptype == POSITION_TYPE_BUY || ptype == POSITION_TYPE_SELL)
                               ? (minute_of_day < strategy_london_flat_min_utc
                                    ? IntegerToString(strategy_london_flat_min_utc / 60) + ":" +
                                      (strategy_london_flat_min_utc % 60 == 0 ? "00" : "30") + " UTC"
                                    : IntegerToString(strategy_ny_flat_min_utc / 60) + ":" +
                                      (strategy_ny_flat_min_utc % 60 == 0 ? "00" : "30") + " UTC")
                               : "session end") + " latest";
     }
   else if((session == 1 && g_fxmr_traded_london_today) || (session == 2 && g_fxmr_traded_ny_today))
     {
      snapshot.state = QM_CONSOLE_WAITING_SETUP;
      snapshot.reason = "Entry taken this window; waiting for the next session";
     }
   else if(g_fxmr_trades_today >= strategy_max_trades_per_day)
     {
      snapshot.state = QM_CONSOLE_WAITING_SETUP;
      snapshot.reason = "Day trade cap reached; waiting for the next session";
     }
   else if(g_fxmr_breaker_day_hit || g_fxmr_breaker_week_hit)
     {
      snapshot.state = QM_CONSOLE_BLOCKED;
      snapshot.reason = g_fxmr_breaker_day_hit ? "Daily breaker hit — no entries today"
                                               : "Weekly breaker hit — no entries this week";
     }

   g_fxmr_panel.Populate(snapshot);
   g_fxmr_panel.Refresh(snapshot);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — thin delegates to the strategy module.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return FxmrNoTradeFilter();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return FxmrEntrySignal(req);
  }

void Strategy_ManageOpenPosition()
  {
   FxmrManageOpenPosition();
  }

bool Strategy_ExitSignal()
  {
   return FxmrExitSignal();
  }

// The card's high-impact blackout is enforced in the new-bar entry path
// (FxmrNewsBlackoutBlocks) so it can never suppress exits or the flatten.
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

   g_fxmr_slot = QM41477_ResolveSlot();
   if(g_fxmr_slot != qm_magic_slot_offset)
     {
      QM_LogEvent(QM_ERROR, "INIT_SLOT_MISMATCH",
                  StringFormat("{\"chart\":\"%s\",\"slot\":%d,\"offset\":%d}",
                               QM_LoggerEscapeJson(_Symbol), g_fxmr_slot, qm_magic_slot_offset));
      return INIT_FAILED;
     }

   // Tester / optimization bypass: never evaluate presentation inputs or
   // identity while the non-visual strategy path is running.
   if(MQLInfoInteger(MQL_TESTER) == 0 && MQLInfoInteger(MQL_OPTIMIZATION) == 0)
     {
      g_qm_console_locale = qm_number_locale;
      if(qm_show_chart_panel && qm_apply_chart_scheme)
         QM_ChartScheme_Apply(ChartID());

      if(g_fxmr_panel.Initialize(ChartID(),
                                qm_ea_id,
                                QM41477_ConsoleStrategyName(),
                                QM_FrameworkMagic(),
                                qm_panel_build_hash,
                                qm_show_chart_panel,
                                qm_dashboard_mode, qm_visual_scale,
                                qm_show_active_range, qm_show_strategy_levels,
                                qm_show_trade_levels, qm_show_trade_markers,
                                qm_design_version, qm_apply_chart_scheme))
        {
         if(EventSetTimer(5))
            g_qm_fw_timer_active = true;
         else
            g_fxmr_panel.Shutdown();
        }
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_41477_fx-session-mean-reversion-m15\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_fxmr_panel.Shutdown();
   if(qm_apply_chart_scheme)
      QM_ChartScheme_Restore(ChartID());
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   if(Strategy_NewsFilterHook(TimeCurrent()))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management (a card-mandated no-op), rule-based exits and the Friday
   // sweep above keep running through news windows — the news gate below
   // blocks NEW entries only (2026-07-02 audit rule; canonical order per
   // QM5_12821 OnTick).
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   // FW1 — 2-axis framework check (at OFF/DXZ defaults here; the card blackout
   // lives in the entry path). Gates NEW entries only.
   const datetime broker_now = TimeCurrent();
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_M15))
      return;

   QM_EquityStreamOnNewBar();

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
   QM41477_RefreshChartPanel();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
   g_fxmr_panel.InvalidatePerformance();
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_fxmr_panel.OnChartEvent(id, sparam);
   // An explicit display retry may be the first successful renderer startup.
   if(!g_qm_fw_timer_active && g_fxmr_panel.Ready())
     {
      if(EventSetTimer(5))
         g_qm_fw_timer_active = true;
      else
         g_fxmr_panel.Shutdown();
     }
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
