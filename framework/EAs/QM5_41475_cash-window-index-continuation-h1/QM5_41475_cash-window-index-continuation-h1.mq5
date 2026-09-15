#property strict
#property version   "5.0"
#property description "QM5_41475 cash-window-index-continuation-h1 — session-flat cash-window index continuation (H1)"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>
#include <QM/QM_ChartPanelCompare.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_41475 cash-window-index-continuation-h1
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md
//   (QM-RESEARCH-2026-0002 H-CW; preregistration cd661891...322e).
// Strategy logic: QM5_41475_CashWindowCore.mqh (the five Strategy_* hooks
// below delegate to it). Everything else is framework wiring and MUST stay
// intact.
//
// REGISTRY STATUS: identity/magic PENDING_ALLOCATION — the governed allocator
// accepted this card (dry-run action=allocate, 3 rows) but its apply step
// refused on an environmental guard (two unrelated EA dirs, QM5_11924 /
// QM5_11941, exist only as uncommitted content in the canonical worktree, so
// the resolver regeneration would drop their active rows from a clean
// worktree). No registry rows for ea_id 41475 exist; do NOT pipeline or
// deploy before allocation completes. See
// docs/ops/evidence/2026-09-15_kimi_hcw/magic_allocation_report.json.
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
input int    qm_ea_id                   = 41475;
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
input string strategy_symbol_slot0      = "NDX.DWX";   // symbol slot 0 (magic ...000)
input string strategy_symbol_slot1      = "GDAXI.DWX"; // symbol slot 1 (magic ...001)
input string strategy_symbol_slot2      = "SP500.DWX"; // symbol slot 2 (magic ...002)
input int    strategy_breakout_window_bars   = 3;      // 2..4 (card range)
input int    strategy_ema_period             = 20;     // 15..30
input double strategy_breakout_buffer_atr    = 0.025;  // 0.0..0.05 x ATR
input int    strategy_atr_period             = 14;     // 10..20
input double strategy_atr_stop_mult          = 1.0;    // fixed by card
input double strategy_target_r               = 1.75;   // 1.5..2.0 x stop distance
input int    strategy_time_stop_bars         = 6;      // 4..8 H1 bars
input double strategy_risk_per_trade_pct     = 0.25;   // 0.20..0.50 (live RISK_PERCENT basis)
input double strategy_daily_stop_pct         = -1.0;   // fixed by card
input double strategy_weekly_stop_pct        = -2.0;   // fixed by card
input double strategy_shock_atr_mult         = 2.0;    // 1.5..2.5 x ATR
input double strategy_spread_median_mult     = 1.5;    // 1.25..1.75 x 20-day median
input int    strategy_session_start_hour_utc = 13;     // 13..14 UTC
input int    strategy_session_end_hour_utc   = 17;     // 16..17 UTC (last entry hour, inclusive)
input int    strategy_flatten_hour_utc       = 20;     // 20..21 UTC mandatory flat
input int    strategy_friday_cutoff_hour_utc = 17;     // 17..18 UTC Friday entry cutoff
input int    strategy_max_positions_total    = 2;      // 1..3 across the EA family
input int    strategy_news_blackout_minutes  = 60;     // 0..120 min around high-impact events
input int    strategy_spread_min_days        = 5;      // daily medians required before enforcing
input bool   strategy_breakeven_at_one_atr   = true;   // optional BE move at +1.0 ATR

#include "QM5_41475_CashWindowCore.mqh"

CQMChartPanelCompare g_hcw_panel;

// EA identity comes from the registered source filename, not renderer copy.
string QM41475_ConsoleStrategyName()
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
      if(i == count - 1 && word == "h1")
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
int QM41475_ResolveSlot()
  {
   const string slots[3] = {strategy_symbol_slot0, strategy_symbol_slot1, strategy_symbol_slot2};
   for(int i = 0; i < 3; ++i)
     {
      if(slots[i] != "" && slots[i] == _Symbol)
         return i;
     }
   return -1;
  }

void QM41475_RefreshChartPanel()
  {
   if(!g_hcw_panel.Ready())
      return;

   QM_ConsoleSnapshot snapshot;
   snapshot.Reset();
   snapshot.strategy_name = QM41475_ConsoleStrategyName();
   snapshot.timeframe = QM_PanelTimeframeName((ENUM_TIMEFRAMES)_Period);
   snapshot.symbol = _Symbol;
   snapshot.environment = QM_PanelEnvironment();
   snapshot.version = "5.0";
   snapshot.state = QM_CONSOLE_WAITING_SETUP;
   snapshot.reason = "Session breakout evaluated on the next H1 bar";

   const datetime now = TimeCurrent();
   const datetime bar = iTime(_Symbol, PERIOD_H1, 0);
   const datetime next = bar + PeriodSeconds(PERIOD_H1);
   snapshot.next_event = (bar > 0 && next > now)
      ? "Next H1 evaluation in " + QM_PanelDuration((long)(next - now)) + " | " + QM_PanelDateTime(next) + " BT"
      : "Next H1 evaluation on a fresh market quote";

   const bool terminal_ready = TerminalInfoInteger(TERMINAL_CONNECTED) &&
      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
      AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   QM_ConsoleAddGate(snapshot, "execution", "Execution", terminal_ready ? "Permission open" : "Permission off",
                     terminal_ready ? QM_GATE_PASS : QM_GATE_BLOCK);

   const bool news_enabled = (strategy_news_blackout_minutes > 0);
   QM_ConsoleAddGate(snapshot, "news", "News blackout",
                     !news_enabled ? "Disabled" : (g_hcw_news_cache_blocked ? "Blackout window" : "Clear"),
                     !news_enabled ? QM_GATE_OFF : (g_hcw_news_cache_blocked ? QM_GATE_BLOCK : QM_GATE_PASS));
   QM_ConsoleAddGate(snapshot, "kill", "Kill switch", g_qm_ks_halted ? "Halted" : "Armed",
                     g_qm_ks_halted ? QM_GATE_BLOCK : QM_GATE_PASS);

   MqlDateTime utc;
   HcwUtcStruct(now, utc);
   const bool in_entry_window = (utc.hour >= strategy_session_start_hour_utc + strategy_breakout_window_bars &&
                                 utc.hour <= strategy_session_end_hour_utc);
   const bool flatten_due = (utc.hour >= strategy_flatten_hour_utc);
   QM_ConsoleAddGate(snapshot, "session", "Session",
                     flatten_due ? "Flat window" : (in_entry_window ? "Entry window" : "Before entry window"),
                     flatten_due ? QM_GATE_BLOCK : (in_entry_window ? QM_GATE_PASS : QM_GATE_WAIT));
   QM_ConsoleAddGate(snapshot, "friday", "Friday cutoff",
                     (utc.day_of_week == 5 && utc.hour >= strategy_friday_cutoff_hour_utc)
                        ? "Cutoff reached" : "Before cutoff",
                     (utc.day_of_week == 5 && utc.hour >= strategy_friday_cutoff_hour_utc)
                        ? QM_GATE_BLOCK : QM_GATE_PASS);
   QM_ConsoleAddGate(snapshot, "shock", "Shock filter",
                     g_hcw_shock_blocked ? "First bar shock" : "Clear",
                     g_hcw_shock_blocked ? QM_GATE_BLOCK : QM_GATE_PASS);
   QM_ConsoleAddGate(snapshot, "breaker_day", "Daily breaker",
                     g_hcw_breaker_day_hit ? "Hit (-1.0%)" : "Armed",
                     g_hcw_breaker_day_hit ? QM_GATE_BLOCK : QM_GATE_PASS);
   QM_ConsoleAddGate(snapshot, "breaker_week", "Weekly breaker",
                     g_hcw_breaker_week_hit ? "Hit (-2.0%)" : "Armed",
                     g_hcw_breaker_week_hit ? QM_GATE_BLOCK : QM_GATE_PASS);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const bool quote = (point > 0.0 && ask > 0.0 && bid > 0.0);
   HcwSpreadMedianRefresh();
   const int spread_days = ArraySize(g_hcw_daily_median);
   QM_ConsoleAddGate(snapshot, "spread", "Spread vs 20d median",
                     !quote ? "No valid quote"
                            : (spread_days < strategy_spread_min_days
                                  ? "Warmup " + IntegerToString(spread_days) + "/" + IntegerToString(strategy_spread_min_days) + " days"
                                  : (g_hcw_spread_median > 0.0
                                        ? "Median " + QM_PanelFormatNumber(g_hcw_spread_median, 1) + " pts"
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
                     "Card " + QM_PanelPercent(strategy_risk_per_trade_pct) + " live | ATR stop x " +
                     QM_PanelFormatNumber(strategy_atr_stop_mult, 2) + " | TP " + QM_PanelFormatNumber(strategy_target_r, 2) + "R");

   const int family = HcwPortfolioPositionCount();
   QM_ConsoleAddGate(snapshot, "capacity", "Capacity",
                     IntegerToString(family) + "/" + IntegerToString(strategy_max_positions_total) + " positions",
                     family >= strategy_max_positions_total ? QM_GATE_BLOCK : QM_GATE_PASS);

   // Breakout reference range of the current session.
   if(g_hcw_window_ready)
     {
      MqlDateTime utc_bar;
      HcwUtcStruct(now, utc_bar);
      snapshot.range_start = now - utc_bar.hour * 3600 - utc_bar.min * 60 - utc_bar.sec +
                             strategy_session_start_hour_utc * 3600;
      snapshot.range_end = snapshot.range_start + strategy_breakout_window_bars * PeriodSeconds(PERIOD_H1);
      snapshot.range_high = g_hcw_breakout_high;
      snapshot.range_low = g_hcw_breakout_low;
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      snapshot.range_high_text = QM_PanelFormatNumber(snapshot.range_high, digits);
      snapshot.range_low_text = QM_PanelFormatNumber(snapshot.range_low, digits);
      snapshot.active_range = true;
     }

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   if(HcwSelectOurPosition(ticket, ptype, open_price, sl))
     {
      snapshot.state = QM_CONSOLE_POSITION_ACTIVE;
      snapshot.reason = "Position managed by SL/TP, time stop and session flat";
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const long held_bars = (opened > 0) ? (long)((now - opened) / PeriodSeconds(PERIOD_H1)) : 0;
      const long left_bars = (long)strategy_time_stop_bars - held_bars;
      snapshot.next_event = "Time stop in " + IntegerToString((int)MathMax(0, left_bars)) + " bars | flat by " +
                            IntegerToString(strategy_flatten_hour_utc) + ":00 UTC";
     }
   else if(g_hcw_trade_taken_today)
     {
      snapshot.state = QM_CONSOLE_WAITING_SETUP;
      snapshot.reason = "Entry taken today; waiting for the next session";
     }
   else if(g_hcw_breaker_day_hit || g_hcw_breaker_week_hit)
     {
      snapshot.state = QM_CONSOLE_BLOCKED;
      snapshot.reason = g_hcw_breaker_day_hit ? "Daily breaker hit — no entries today"
                                              : "Weekly breaker hit — no entries this week";
     }

   g_hcw_panel.Populate(snapshot);
   g_hcw_panel.Refresh(snapshot);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — thin delegates to the strategy module.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return HcwNoTradeFilter();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return HcwEntrySignal(req);
  }

void Strategy_ManageOpenPosition()
  {
   HcwManageOpenPosition();
  }

bool Strategy_ExitSignal()
  {
   return HcwExitSignal();
  }

// The card's high-impact blackout is enforced in the new-bar entry path
// (HcwNewsBlackoutBlocks) so it can never suppress exits or the flatten.
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

   g_hcw_slot = QM41475_ResolveSlot();
   if(g_hcw_slot != qm_magic_slot_offset)
     {
      QM_LogEvent(QM_ERROR, "INIT_SLOT_MISMATCH",
                  StringFormat("{\"chart\":\"%s\",\"slot\":%d,\"offset\":%d}",
                               QM_LoggerEscapeJson(_Symbol), g_hcw_slot, qm_magic_slot_offset));
      return INIT_FAILED;
     }

   // Tester / optimization bypass: never evaluate presentation inputs or
   // identity while the non-visual strategy path is running.
   if(MQLInfoInteger(MQL_TESTER) == 0 && MQLInfoInteger(MQL_OPTIMIZATION) == 0)
     {
      g_qm_console_locale = qm_number_locale;
      if(qm_show_chart_panel && qm_apply_chart_scheme)
         QM_ChartScheme_Apply(ChartID());

      if(g_hcw_panel.Initialize(ChartID(),
                                qm_ea_id,
                                QM41475_ConsoleStrategyName(),
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
            g_hcw_panel.Shutdown();
        }
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_41475_cash-window-index-continuation-h1\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_hcw_panel.Shutdown();
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

   // Management, rule-based exits and the Friday sweep above keep running
   // through news windows — the news gate below blocks NEW entries only
   // (2026-07-02 audit rule; canonical order per QM5_12821 OnTick).
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

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
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
   QM41475_RefreshChartPanel();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
   g_hcw_panel.InvalidatePerformance();
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_hcw_panel.OnChartEvent(id, sparam);
   // An explicit display retry may be the first successful renderer startup.
   if(!g_qm_fw_timer_active && g_hcw_panel.Ready())
     {
      if(EventSetTimer(5))
         g_qm_fw_timer_active = true;
      else
         g_hcw_panel.Shutdown();
     }
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
