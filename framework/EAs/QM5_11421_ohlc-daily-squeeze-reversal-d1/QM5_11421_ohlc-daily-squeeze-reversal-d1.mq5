#property strict
#property version   "5.0"
#property description "QM5_11421 ohlc-daily-squeeze-reversal-d1 — OHLC squeeze reversal (D1, pending-stop)"

#include <QM/QM_Common.mqh>
#include <QM/QM_ChartPanel.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11421 ohlc-daily-squeeze-reversal-d1
// -----------------------------------------------------------------------------
// Source: "Forex Scalping Strategies" (anonymous), Strategy C "Forex Market
//   Squeeze". Card: artifacts/cards_approved/QM5_11421_ohlc-daily-squeeze-
//   reversal-d1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads; day 2 = shift 1, day 1 = shift 2, day 0 = shift 3):
//   Squeeze STATE (the compression is a STATE, not the trigger):
//     SHORT: two consecutive UP-closes  Close[1] > Close[2] > Close[3]
//            AND day-2 range sits predominantly above day-1's close:
//            (High[1] - Close[2]) >= day2_range / 2.
//     LONG : mirror — two consecutive DOWN-closes Close[1] < Close[2] < Close[3]
//            AND (Close[2] - Low[1]) >= day2_range / 2.
//     day2_range = High[1] - Low[1]; require day2_range >= min_range (pips).
//   Trigger EVENT (the single event): price breaks the prior CLOSE-anchored
//     stop level on the NEXT bar. Gapless-safe — the stop level is anchored to
//     the prior CLOSE (Close[1]) and the prior RANGE, never to a real price gap.
//     SHORT: SELLSTOP at Close[1] - entry_range_mult * day2_range.
//     LONG : BUYSTOP  at Close[1] + entry_range_mult * day2_range.
//   Stop loss : SHORT High[1] + sl_range_mult * day2_range (mirror for LONG),
//               capped at sl_cap_pips.
//   Take profit: distance = day2_range projected from the pending entry price.
//   Pending lifecycle: one pending-or-position per magic. The pending order is
//     auto-expired (expiration_seconds) and is also explicitly cancelled if the
//     next closed bar CONTINUES the same-direction close run (squeeze persists →
//     no reversal yet), so a fresh squeeze can re-arm.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN (zero modeled spread is tradeable; only a
//     genuinely wide spread blocks), scaled in pips via the pip factor.
//   - No swap gate; no external/macro CSV feed; pure OHLC arithmetic.
//   - Prior-CLOSE-anchored levels (gapless CFD safe), not a real-gap rule.
//   - Thresholds in PIPS via QM_StopRulesPipsToPriceDistance (5-digit/JPY safe).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11421;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;
input bool   qm_show_chart_panel        = true;
input bool   qm_apply_chart_scheme      = true;
input string qm_panel_build_hash        = "UNBOUND";
input QM_ConsoleMode qm_dashboard_mode  = QM_CONSOLE_FULL;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
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
input double strategy_entry_range_mult  = 1.0;    // SELLSTOP/BUYSTOP offset = mult * day2_range below/above Close[1]
input double strategy_sl_range_mult     = 1.5;    // stop distance = mult * day2_range beyond day-2 high/low
input double strategy_tp_range_mult     = 1.0;    // take-profit distance = mult * day2_range from entry
input double strategy_min_range_pips    = 30.0;   // skip squeeze bars narrower than this (day2_range)
input double strategy_sl_cap_pips       = 80.0;   // hard cap on stop distance (card P2 cap)
input int    strategy_pending_ttl_bars  = 1;      // pending order lives this many D1 bars before auto-expiry
input double strategy_spread_cap_pips   = 25.0;   // skip only a genuinely WIDE spread (fail-open on .DWX zero spread)
input bool   strategy_enable_long       = true;   // mirror LONG squeeze (descending closes); SHORT always on

CQMChartPanel g_qm_signature_panel;
// EA identity comes from the registered source filename, not renderer copy.
string QM11421_ConsoleStrategyName()
  {
   string name=MQLInfoString(MQL_PROGRAM_NAME);
   const string prefix="QM5_"+IntegerToString(qm_ea_id)+"_";
   if(StringFind(name,prefix)==0) name=StringSubstr(name,StringLen(prefix));
   string words[]; const int count=StringSplit(name,'-',words);
   string title="";
   for(int i=0;i<count;++i)
     {
      string word=words[i];
      if(i==count-1 && word=="d1") continue; // registered slug suffix, not chart identity
      if(word=="ohlc") word="OHLC";
      else if(StringLen(word)>0)
        { string first=StringSubstr(word,0,1); StringToUpper(first); word=first+StringSubstr(word,1); }
      title+=(title==""?"":" ")+word;
     }
   return title;
  }

void QM11421_RefreshChartPanel()
  {
   if(!g_qm_signature_panel.Ready()) return;
   QM_ConsoleSnapshot snapshot; snapshot.Reset();
   snapshot.strategy_name=QM11421_ConsoleStrategyName();
   snapshot.timeframe=QM_PanelTimeframeName((ENUM_TIMEFRAMES)_Period);
   snapshot.symbol=_Symbol; snapshot.environment=QM_PanelEnvironment(); snapshot.version="5.0";
   snapshot.state=QM_CONSOLE_WAITING_SETUP;
   snapshot.reason="Squeeze evaluated on the next D1 bar";
   const datetime now=TimeCurrent();
   const datetime bar=iTime(_Symbol,PERIOD_D1,0);
   const datetime next=bar+PeriodSeconds(PERIOD_D1);
   snapshot.next_event=bar>0 && next>now?
      "Next D1 evaluation in "+QM_PanelDuration((long)(next-now))+" | "+QM_PanelDateTime(next)+" BT":
      "Next D1 evaluation on a fresh market quote";

   const bool terminal_ready=TerminalInfoInteger(TERMINAL_CONNECTED) &&
      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
      AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   const bool contract_ready=g_qm_runtime_execution_state!=QM_RUNTIME_EXECUTION_REQUIRED_BLOCKED;
   QM_ConsoleAddGate(snapshot,"execution","Execution",!terminal_ready?"Permission off":
      (!contract_ready?"Contract blocked":"Permission open"),
      terminal_ready && contract_ready?QM_GATE_PASS:QM_GATE_BLOCK);

   QM_ConsoleGateState news=QM_GATE_WAIT;
   string news_reason="Awaiting quote";
   if(!g_qm_news_active) { news=QM_GATE_OFF; news_reason="Disabled"; }
   else if(!g_qm_news_loaded || !g_qm_news_available)
     { news=QM_GATE_ERROR; news_reason="Calendar unavailable"; }
   else if(g_qm_news_cache_valid && g_qm_news_cache_symbol==_Symbol)
     {
      const long age=(long)(TimeGMT()-g_qm_news_cache_wall_utc);
      if(age<0 || age>=60) { news=QM_GATE_STALE; news_reason="Quote cache stale"; }
      else { news=g_qm_news_cache_verdict?QM_GATE_PASS:QM_GATE_BLOCK;
             news_reason=g_qm_news_cache_verdict?"Native MT5 clear":"Native MT5 blackout"; }
     }
   QM_ConsoleAddGate(snapshot,"news","News",news_reason,news);
   QM_ConsoleAddGate(snapshot,"kill","Kill switch",g_qm_ks_halted?"Halted":"Armed",
      g_qm_ks_halted?QM_GATE_BLOCK:QM_GATE_PASS);
   // Read-only calendar arithmetic; no flatten operation is called for display.
   MqlDateTime clock; TimeToStruct(now,clock);
   const bool friday=qm_friday_close_enabled && clock.day_of_week==5 &&
      clock.hour>=qm_friday_close_hour_broker;
   QM_ConsoleAddGate(snapshot,"friday","Friday",!qm_friday_close_enabled?"Disabled":
      (friday?"Close boundary":"Before close"),
      !qm_friday_close_enabled?QM_GATE_OFF:(friday?QM_GATE_BLOCK:QM_GATE_PASS));

   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double pip=SqueezePipFactor();
   const bool quote=ask>0.0 && bid>0.0 && pip>0.0;
   const double spread=quote?(ask-bid)/pip:0.0;
   // Same fail-open predicate as Strategy_NoTradeFilter (including disabled cap).
   const bool spread_block=quote && spread>0.0 && strategy_spread_cap_pips>0.0 && spread>strategy_spread_cap_pips;
   QM_ConsoleAddGate(snapshot,"spread","Spread",quote?QM_PanelPips(spread):"No valid quote",
      !quote?QM_GATE_WARN:(strategy_spread_cap_pips<=0.0?QM_GATE_OFF:(spread_block?QM_GATE_BLOCK:QM_GATE_PASS)));

   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double next_risk=(g_qm_risk_mode==QM_RISK_MODE_PERCENT?
      equity*g_qm_risk_percent/100.0:g_qm_risk_fixed)*g_qm_risk_portfolio_weight;
   const double cap=g_qm_risk_mode==QM_RISK_MODE_PERCENT && g_qm_risk_per_trade_cap_pct>0.0?
      equity*g_qm_risk_per_trade_cap_pct/100.0:g_qm_risk_per_trade_cap_money;
   if(cap>0.0) next_risk=MathMin(next_risk,cap);
   // The canary declares the legacy DXZ contract: no governor is bound.
   // This future-bound branch reads the existing immutable client only; the
   // renderer never invokes it and no governor/room is implied while unbound.
   if(QM_RuntimeExecutionGovernorRequired())
     {
      double scale=0.0; string reason="";
      const bool allows=QM_FTMO_ReadGovernorScale(g_qm_runtime_execution_contract.governor_policy_id,
         g_qm_runtime_execution_contract.challenge_instance_id,
         g_qm_runtime_execution_contract.governor_heartbeat_max_age_seconds,scale,reason);
      QM_ConsoleAddGate(snapshot,"governor","Governor",allows?"Entry open":"Entry locked",
         allows?QM_GATE_PASS:QM_GATE_BLOCK);
      next_risk=allows?next_risk*scale:0.0;
     }
   QM_ConsoleAddLine(snapshot.risk,"Next trade",QM_PanelPercent(equity>0.0?next_risk/equity*100.0:0.0)+
      " | "+QM_PanelMoney(next_risk));
   g_qm_signature_panel.Populate(snapshot);
   QM_ConsoleAddLine(snapshot.risk,"Stop basis","Prior range x "+QM_PanelFormatNumber(strategy_sl_range_mult,2)+
      " | cap "+QM_PanelPips(strategy_sl_cap_pips));

   const bool capacity=snapshot.positions==0 && snapshot.pending_orders==0;
   QM_ConsoleAddGate(snapshot,"capacity","Capacity",capacity?"One slot free":"Slot occupied",
      capacity?QM_GATE_PASS:QM_GATE_BLOCK);
   QM_ConsoleAddGate(snapshot,"squeeze","Squeeze","On D1 close",QM_GATE_WAIT);

   if(snapshot.positions>0)
     { snapshot.state=QM_CONSOLE_POSITION_ACTIVE; snapshot.reason="Position managed by fixed SL / TP";
       snapshot.next_event="Next event: SL / TP or Friday close"; }
   else if(snapshot.pending_orders>0)
     { snapshot.state=QM_CONSOLE_WAITING_TRIGGER; snapshot.reason="Pending stop armed; no additional entry";
       snapshot.next_event="Next event: trigger, expiry or D1 re-evaluation"; }
   else
      for(int i=0;i<ArraySize(snapshot.gates);++i)
        {
         const QM_ConsoleGateState state=snapshot.gates[i].state;
         if(state==QM_GATE_BLOCK || state==QM_GATE_ERROR || state==QM_GATE_STALE ||
            (snapshot.gates[i].key=="news" && state==QM_GATE_WAIT))
           {
            snapshot.state=state==QM_GATE_ERROR?QM_CONSOLE_ERROR:QM_CONSOLE_BLOCKED;
            snapshot.reason=snapshot.gates[i].label+" - "+snapshot.gates[i].reason;
            if(snapshot.gates[i].key=="news") snapshot.next_event="Next news check on a fresh market quote";
            break;
           }
        }

   // The prior OHLC range is meaningful only for an actionable pending setup.
   // Use its setup bar, not today's unrelated range or a historical catalogue.
   for(int i=0;i<ArraySize(snapshot.exposure);++i)
     {
      const QM_ConsoleExposure item=snapshot.exposure[i];
      if(!item.pending || item.symbol!=_Symbol) continue;
      const int shift=iBarShift(_Symbol,PERIOD_D1,item.opened,false);
      if(shift>=0)
        {
         snapshot.range_start=iTime(_Symbol,PERIOD_D1,shift+1);
         snapshot.range_end=iTime(_Symbol,PERIOD_D1,shift)+PeriodSeconds(PERIOD_D1);
         snapshot.range_high=iHigh(_Symbol,PERIOD_D1,shift+1);
         snapshot.range_low=iLow(_Symbol,PERIOD_D1,shift+1);
         snapshot.active_range=snapshot.range_start>0 && snapshot.range_high>snapshot.range_low &&
            snapshot.range_low>0.0;
        }
      break;
     }
   g_qm_signature_panel.Refresh(snapshot);
  }

// -----------------------------------------------------------------------------
// Helpers (pure OHLC geometry — structural reads, // perf-allowed exceptions).
// All reads are at fixed closed-bar shifts; no per-tick lookback loops.
// -----------------------------------------------------------------------------

double SqueezePipFactor()
  {
   // Price distance of one pip on this symbol (5-digit/JPY safe).
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread blocks; zero/negative modeled spread passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double pip = SqueezePipFactor();
   if(pip <= 0.0)
      return false;

   const double cap_price = strategy_spread_cap_pips * pip;
   const double spread = ask - bid;
   if(spread > 0.0 && cap_price > 0.0 && spread > cap_price)
      return true; // genuinely wide spread — block

   return false;
  }

// Build the squeeze pending order. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One open position per magic.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Closed-bar OHLC: day2 = shift 1, day1 = shift 2, day0 = shift 3.
   const double high2  = iHigh(_Symbol, _Period, 1);   // perf-allowed: structural OHLC geometry
   const double low2   = iLow(_Symbol, _Period, 1);    // perf-allowed: structural OHLC geometry
   const double close2 = iClose(_Symbol, _Period, 1);  // perf-allowed: structural OHLC geometry
   const double close1 = iClose(_Symbol, _Period, 2);  // perf-allowed: structural OHLC geometry
   const double close0 = iClose(_Symbol, _Period, 3);  // perf-allowed: structural OHLC geometry
   if(high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0 || close1 <= 0.0 || close0 <= 0.0)
      return false;

   const bool asc_closes  = (close2 > close1 && close1 > close0);
   const bool desc_closes = (close2 < close1 && close1 < close0);

   // Pending-order lifecycle (new-bar gated — this hook only fires on a fresh
   // closed bar). One pending-or-position per magic. If a pending stop is armed
   // and the squeeze CONTINUES (same-direction close run extends → no reversal
   // yet), cancel it so a fresh squeeze can re-arm; otherwise leave it to fill
   // or auto-expire (req.expiration_seconds). Either way, do not stack a second.
   const int total_orders = OrdersTotal();
   for(int i = total_orders - 1; i >= 0; --i)
     {
      const ulong oticket = OrderGetTicket(i);
      if(oticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(otype == ORDER_TYPE_SELL_STOP && asc_closes)
         QM_TM_RemovePendingOrder(oticket, "squeeze_continues_cancel_sellstop");
      else if(otype == ORDER_TYPE_BUY_STOP && desc_closes)
         QM_TM_RemovePendingOrder(oticket, "squeeze_continues_cancel_buystop");
      else
         return false; // a still-valid pending order is armed — do not stack
     }

   const double day2_range = high2 - low2;
   if(day2_range <= 0.0)
      return false;

   const double pip = SqueezePipFactor();
   if(pip <= 0.0)
      return false;

   // Minimum day-2 range filter (avoid very narrow squeeze bars).
   if(day2_range < strategy_min_range_pips * pip)
      return false;

   // Stop-distance cap (in price) from the pips cap.
   const double sl_cap_price = strategy_sl_cap_pips * pip;

   // --- SHORT squeeze: two ascending closes + range predominantly above day-1 close ---
   if(asc_closes && (high2 - close1) >= (day2_range * 0.5))
     {
      const double entry = close2 - strategy_entry_range_mult * day2_range;
      double sl          = high2 + strategy_sl_range_mult * day2_range;
      // Apply the stop-distance cap (relative to the pending entry price).
      if(sl_cap_price > 0.0 && (sl - entry) > sl_cap_price)
         sl = entry + sl_cap_price;
      const double tp = entry - strategy_tp_range_mult * day2_range;

      if(entry <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;
      // Pending stop must sit below current bid to be a valid SELLSTOP.
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || entry >= bid)
         return false;

      req.type               = QM_SELL_STOP;
      req.price              = entry;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "squeeze_short_sellstop";
      req.symbol_slot        = qm_magic_slot_offset;   // match the framework magic slot
      req.expiration_seconds = QM_PendingTTLSeconds();
      return true;
     }

   // --- LONG squeeze (mirror): two descending closes + range predominantly below day-1 close ---
   if(strategy_enable_long)
     {
      if(desc_closes && (close1 - low2) >= (day2_range * 0.5))
        {
         const double entry = close2 + strategy_entry_range_mult * day2_range;
         double sl          = low2 - strategy_sl_range_mult * day2_range;
         if(sl_cap_price > 0.0 && (entry - sl) > sl_cap_price)
            sl = entry - sl_cap_price;
         const double tp = entry + strategy_tp_range_mult * day2_range;

         if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || sl >= entry)
            return false;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || entry <= ask)
            return false;

         req.type               = QM_BUY_STOP;
         req.price              = entry;
         req.sl                 = sl;
         req.tp                 = tp;
         req.reason             = "squeeze_long_buystop";
         req.symbol_slot        = qm_magic_slot_offset;   // match the framework magic slot
         req.expiration_seconds = QM_PendingTTLSeconds();
         return true;
        }
     }

   return false;
  }

// No per-tick position management. Pending-order lifecycle (cancel-on-squeeze-
// continuation + one-per-magic) is handled new-bar-gated inside Strategy_Entry-
// Signal; un-triggered pendings auto-expire via req.expiration_seconds. The
// filled position rides its fixed SL/TP. Kept empty to avoid a per-EA new-bar
// gate (forbidden) on the per-tick path.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary position exit — SL/TP (and pending expiry) carry the trade.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// Pending order time-to-live, expressed in seconds for the framework expiration.
// strategy_pending_ttl_bars D1 bars; D1 bar = 86400 s.
int QM_PendingTTLSeconds()
  {
   const int bars = (strategy_pending_ttl_bars > 0) ? strategy_pending_ttl_bars : 1;
   return bars * 86400;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   // This canary has one visualization owner, including when visualization is off.
   // A renderer/suppression failure never aborts EA initialization.
   QM_FrameworkSetChartUISuppressed(true);
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   // Full optimization/tester bypass: do not even evaluate presentation inputs
   // or identity while the non-visual strategy path is running.
   if(MQLInfoInteger(MQL_TESTER)==0 && MQLInfoInteger(MQL_OPTIMIZATION)==0)
     {
      g_qm_console_locale=qm_number_locale;
      if(qm_show_chart_panel && qm_apply_chart_scheme)
         QM_ChartScheme_Apply(ChartID());

      if(g_qm_signature_panel.Initialize(ChartID(),
                                          qm_ea_id,
                                          QM11421_ConsoleStrategyName(),
                                          QM_FrameworkMagic(),
                                          qm_panel_build_hash,
                                          qm_show_chart_panel,
                                          qm_dashboard_mode,qm_visual_scale,
                                          qm_show_active_range,qm_show_strategy_levels,
                                          qm_show_trade_levels,qm_show_trade_markers))
        {
         if(EventSetTimer(5))
            g_qm_fw_timer_active = true;
         else
            g_qm_signature_panel.Shutdown();
        }
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_qm_signature_panel.Shutdown();
   if(qm_apply_chart_scheme)
      QM_ChartScheme_Restore(ChartID());
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. The kill-switch retains a compatibility fallback, but current V5
   // builds keep this explicit first-statement hook.
   QM_FrameworkTrackOpenPositionMae();

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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

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
   QM11421_RefreshChartPanel();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
   g_qm_signature_panel.InvalidatePerformance();
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   g_qm_signature_panel.OnChartEvent(id,sparam);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
