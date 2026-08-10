#property strict
#property version   "5.0"
#property description "QM5_11563 Connors RSI(2) + SMA(200) Mean Reversion (D1, FX)"
// Strategy Card: QM5_11563 (connors-rsi2-sma200-mean-reversion-d1), G0 APPROVED 2026-07-26.
// Source: Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That Work" (2009),
//         Strategies 8-9 "The 2-Period RSI". Source ID 278c6e13-0726-5779-83fe-a38f5a2e480f.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11563 — Connors RSI(2)/SMA(200) mean reversion
// -----------------------------------------------------------------------------
// LONG : close[1] > SMA(200)[1] AND RSI(2)[1] < 10        -> market buy
// SHORT: close[1] < SMA(200)[1] AND RSI(2)[1] > 90        -> market sell
// EXIT long : RSI(2)[1] > 65 -> close   |  EXIT short: RSI(2)[1] < 35 -> close
// Safety stop: 2 * ATR(14) from entry, capped at 150 pips (P2 addition).
// Filters: D1, spread cap 15 pips, no Friday entry.
// Only the five Strategy_* hooks + two local helpers are strategy code; the
// OnInit/OnTick framework wiring below is the canonical skeleton, untouched.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11563;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
input uint   qm_rng_seed                = 42;

input group "Risk"
// HR4: both risk inputs exist. Backtest defaults to RISK_FIXED ($1000); the
// live setfile sets RISK_PERCENT=0.5 and RISK_FIXED=0.
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
input int    strategy_sma_period          = 200;    // SMA trend filter period (Connors SMA200)
input int    strategy_rsi_period          = 2;      // RSI period (Connors RSI2)
input double strategy_rsi_entry_long      = 10.0;   // LONG entry: RSI(2)[1] below this in uptrend
input double strategy_rsi_entry_short     = 90.0;   // SHORT entry: RSI(2)[1] above this in downtrend
input double strategy_rsi_exit_long       = 65.0;   // LONG exit: close when RSI(2)[1] above this
input double strategy_rsi_exit_short      = 35.0;   // SHORT exit: close when RSI(2)[1] below this
input int    strategy_atr_period          = 14;     // ATR period for the safety stop
input double strategy_atr_sl_mult         = 2.0;    // Safety stop distance = mult * ATR(14)
input int    strategy_sl_cap_pips         = 150;    // Safety stop distance cap (pips)
input int    strategy_spread_cap_pips     = 15;     // Block entries when spread exceeds this (pips)
input bool   strategy_no_friday_entry     = true;   // Skip NEW entries on Fridays (exits still run)

// -----------------------------------------------------------------------------
// Local helpers (used only by the strategy hooks below).
// -----------------------------------------------------------------------------

// Safety stop PRICE for `side` from `entry_ref`: 2*ATR(14), capped at
// strategy_sl_cap_pips. Returns the stop closest to entry (the tighter of the
// ATR distance and the pip cap). 0.0 => no valid stop.
double ComputeSafetyStop(const QM_OrderType side, const double entry_ref)
  {
   const double sl_atr = QM_StopATR(_Symbol, side, entry_ref, strategy_atr_period, strategy_atr_sl_mult);
   const double sl_cap = QM_StopFixedPips(_Symbol, side, entry_ref, strategy_sl_cap_pips);
   if(sl_atr <= 0.0 && sl_cap <= 0.0)
      return 0.0;
   if(sl_atr <= 0.0)
      return sl_cap;
   if(sl_cap <= 0.0)
      return sl_atr;
   // BUY: stop sits below entry, tighter = higher price. SELL: mirror.
   return (side == QM_BUY) ? MathMax(sl_atr, sl_cap) : MathMin(sl_atr, sl_cap);
  }

// Direction of this EA's open position on the current symbol: +1 long, -1
// short, 0 none. One-position-per-magic mean reversion, so the first match wins.
int OpenPositionDir()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No-trade filter (spread component). DWX quotes ask==bid (0 modeled spread) in
// the tester, so this never blocks there; it only blocks a genuinely wide live
// spread. Never fail-closed on zero spread (DWX invariant #1).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double cap_price = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
      if(cap_price > 0.0 && (ask - bid) > cap_price)
         return true; // block: genuinely wide spread
     }
   return false;
  }

// Entry: RSI(2) extreme in the SMA(200) trend regime. Caller guarantees
// QM_IsNewBar()==true, so the closed-bar reads at shift 1 advance once per bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;   // 0 => framework fills market price
   req.sl                 = 0.0;
   req.tp                 = 0.0;   // no TP; exit via RSI reversal
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One position per magic — single-entry mean reversion.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No-Friday-entry (broker time). Entry-only gate: exits keep running on Fri.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Sun=0 .. Fri=5 .. Sat=6
         return false;
     }

   const double sma200 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double rsi2   = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   const double close1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE); // close[1]: period-1 SMA = the closed-bar close (corset-clean, no raw iClose)
   if(sma200 <= 0.0 || close1 <= 0.0)
      return false; // warmup / bad read

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool go_long  = (close1 > sma200) && (rsi2 < strategy_rsi_entry_long);
   const bool go_short = (close1 < sma200) && (rsi2 > strategy_rsi_entry_short);

   if(go_long)
     {
      req.type   = QM_BUY;
      req.reason = "QM5_11563_RSI2_LONG";
      req.sl     = ComputeSafetyStop(QM_BUY, ask);
     }
   else if(go_short)
     {
      req.type   = QM_SELL;
      req.reason = "QM5_11563_RSI2_SHORT";
      req.sl     = ComputeSafetyStop(QM_SELL, bid);
     }
   else
      return false;

   if(req.sl <= 0.0)
      return false; // refuse to enter without a valid safety stop

   return true;
  }

// No trailing / break-even / partial logic — Connors RSI2 holds to the RSI
// reversal exit (Strategy_ExitSignal) or the hard safety stop set at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: RSI(2) reversal. LONG closes when RSI(2)[1] > 65, SHORT when < 35.
// Closed-bar shift 1 fires on the first tick of the new bar (~"close on next
// open"), matching the entry's shift-1 convention.
bool Strategy_ExitSignal()
  {
   const int dir = OpenPositionDir();
   if(dir == 0)
      return false;
   const double rsi2 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   if(dir > 0)
      return (rsi2 > strategy_rsi_exit_long);
   return (rsi2 < strategy_rsi_exit_short);
  }

// Defer to the central 2-axis news filter (no custom high-impact handling).
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11563_connors_rsi2_sma200\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

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
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick).
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

   // FW1 — 2-axis news check. Gates NEW entries only — never the
   // management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 — emit end-of-day equity snapshot if the day rolled since last tick.
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
