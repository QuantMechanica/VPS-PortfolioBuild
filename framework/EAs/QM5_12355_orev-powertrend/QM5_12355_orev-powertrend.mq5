#property strict
#property version   "5.0"
#property description "QM5_12355 Oreilm49 Powertrend Persistence (D1, long-only)"
// Strategy Card: QM5_12355 (orev-powertrend), G0 APPROVED 2026-07-27.
// Source: oreilm49/quantconnect, Powertrend/main.py (SymbolIndicators.powertrend_on).
//         Source ID 72f9fcfa-6c75-5544-80c4-31e15c9817ab.
//
// =============================================================================
// QuantMechanica V5 EA: QM5_12355 — Powertrend persistence (long-only, D1)
// -----------------------------------------------------------------------------
// LONG entry (all on closed D1 bars): every one of the last 10 bars has
//   low > EMA(21); every one of the last 5 bars has EMA(21) > SMA(50); SMA(50)
//   is rising vs the prior bar; and the signal bar is bullish (close[1] > open[1]);
//   and no open position for this magic/symbol -> market BUY at the new bar open.
// EXIT long: close when EMA(21) < SMA(50) on the last closed bar (state check).
// Safety: V5 catastrophic ATR hard stop (4.0 * ATR(21)); V5 Friday close; news gate.
// Long-only — no short side described in the card. One position per magic/symbol,
// no pyramiding, no grid (card §7).
//
// Closed-bar strategy state (persistence windows + exit state) is computed ONCE
// per new D1 bar in AdvanceState_OnNewBar() and cached in file-scope g_* vars;
// the per-tick management/exit path reads only the cached state. OHLC values are
// read corset-clean via a period-1 SMA on the relevant applied price (no raw
// iLow/iOpen/iClose). Only the five Strategy_* hooks, AdvanceState_OnNewBar, and
// the single-consume new-bar latch in OnTick are strategy code.
// =============================================================================

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12355;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
input uint   qm_rng_seed                = 42;

input group "Risk"
// HR4: both risk inputs exist. Backtest defaults to RISK_FIXED ($1000); the
// live setfile sets RISK_PERCENT=0.5 and RISK_FIXED=0.
input double RISK_PERCENT               = 0.5;
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
input int    strategy_ema_period            = 21;   // EMA fast trend line (Powertrend EMA21)
input int    strategy_sma_period            = 50;   // SMA slow trend line (Powertrend SMA50)
input int    strategy_low_above_ema_window  = 10;   // require low > EMA over the last N closed bars
input int    strategy_ema_above_sma_window  = 5;    // require EMA > SMA over the last N closed bars
input int    strategy_atr_period            = 21;   // ATR period for the catastrophic stop
input double strategy_atr_stop_mult         = 4.0;  // catastrophic stop distance = mult * ATR(period)

// -----------------------------------------------------------------------------
// Cached closed-bar strategy state — advanced once per new D1 bar.
// -----------------------------------------------------------------------------
bool g_entry_ready = false;   // all Powertrend persistence conditions met on the last closed bar
bool g_exit_state  = false;   // EMA(21) < SMA(50) on the last closed bar (long exit trigger)

// Recompute cached Powertrend state from the just-closed D1 bar. Called ONCE per
// new bar from OnTick (behind the single-consume QM_IsNewBar latch). Reads only
// closed-bar shifts (>=1) via pooled QM_* readers. Never gated by its own
// timestamp check and never looped further back than the configured windows.
void AdvanceState_OnNewBar()
  {
   g_entry_ready = false;
   g_exit_state  = false;

   const int ema_p   = strategy_ema_period;
   const int sma_p   = strategy_sma_period;
   const int win_low = strategy_low_above_ema_window;
   const int win_ema = strategy_ema_above_sma_window;
   if(ema_p < 1 || sma_p < 1 || win_low < 1 || win_ema < 1)
      return; // degenerate params — stay flat

   // Persistence window 1: every one of the last `win_low` closed bars has
   // low > EMA(ema_p). Corset-clean OHLC read: a period-1 SMA on PRICE_LOW at
   // shift i equals low[i] (no raw iLow, no CopyRates).
   bool low_above_ema_all = true;
   for(int i = 1; i <= win_low; ++i)
     {
      const double low_i = QM_SMA(_Symbol, PERIOD_D1, 1, i, PRICE_LOW);
      const double ema_i = QM_EMA(_Symbol, PERIOD_D1, ema_p, i);
      if(low_i <= 0.0 || ema_i <= 0.0 || low_i <= ema_i)
        {
         low_above_ema_all = false;
         break;
        }
     }

   // Persistence window 2: every one of the last `win_ema` closed bars has
   // EMA(ema_p) > SMA(sma_p).
   bool ema_above_sma_all = true;
   for(int i = 1; i <= win_ema; ++i)
     {
      const double ema_i = QM_EMA(_Symbol, PERIOD_D1, ema_p, i);
      const double sma_i = QM_SMA(_Symbol, PERIOD_D1, sma_p, i);
      if(ema_i <= 0.0 || sma_i <= 0.0 || ema_i <= sma_i)
        {
         ema_above_sma_all = false;
         break;
        }
     }

   // SMA(sma_p) rising vs the prior bar's SMA value.
   const double sma1 = QM_SMA(_Symbol, PERIOD_D1, sma_p, 1);
   const double sma2 = QM_SMA(_Symbol, PERIOD_D1, sma_p, 2);
   const bool sma_rising = (sma1 > 0.0 && sma2 > 0.0 && sma1 > sma2);

   // Signal bar bullish: close[1] > open[1]. Period-1 SMA on the applied price
   // returns the raw OHLC value for that bar (corset-clean).
   const double open1  = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_OPEN);
   const double close1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const bool bullish_bar = (open1 > 0.0 && close1 > 0.0 && close1 > open1);

   g_entry_ready = (low_above_ema_all && ema_above_sma_all && sma_rising && bullish_bar);

   // Long-exit state: EMA(ema_p) < SMA(sma_p) on the last closed bar.
   const double ema1 = QM_EMA(_Symbol, PERIOD_D1, ema_p, 1);
   g_exit_state = (ema1 > 0.0 && sma1 > 0.0 && ema1 < sma1);
  }

// Count of this EA's open positions on the current symbol/magic.
int OpenPositionCount()
  {
   return QM_TM_OpenPositionCount(QM_FrameworkMagic());
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No-trade filter (time / spread / news component). The card relies on the V5
// framework news + kill-switch + Friday-close defaults and adds no custom
// no-trade condition, so this is a cheap O(1) pass-through.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry: cached Powertrend persistence gate. Caller guarantees a new closed bar
// (single-consume latch in OnTick), and g_entry_ready was advanced this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;   // 0 => framework fills market at the new bar's open tick
   req.sl                 = 0.0;
   req.tp                 = 0.0;   // no TP; exit via EMA<SMA state / catastrophic stop / Friday close
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_entry_ready)
      return false;

   // One position per magic/symbol — long-only, no pyramiding (card §7).
   if(OpenPositionCount() > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   // V5 catastrophic ATR hard stop — a WIDE safety backstop (mult * ATR), not a
   // tactical stop. The strategy's real exit is the EMA<SMA state cross.
   req.type   = QM_BUY;
   req.reason = "QM5_12355_POWERTREND_LONG";
   req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false; // refuse to enter without a valid catastrophic stop below entry

   return true;
  }

// No trailing / break-even / partial logic — the position is held to the
// EMA<SMA state exit or the catastrophic stop set at entry (card §7).
void Strategy_ManageOpenPosition()
  {
  }

// Exit: close the long when EMA(21) < SMA(50) on the last closed bar. State
// check (not a same-bar double-event) read from cached g_exit_state, advanced
// once per new bar; fires on the first tick of the new bar (~"close on next open").
bool Strategy_ExitSignal()
  {
   if(OpenPositionCount() <= 0)
      return false;
   return g_exit_state;
  }

// Defer to the central 2-axis news filter (no custom high-impact handling).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — canonical skeleton, with the sanctioned intraday-discipline
// AdvanceState latch. QM_IsNewBar() is consumed exactly once per tick (DWX
// invariant #3): latched into `nb` and reused for both the state advance and the
// entry gate.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_12355_orev_powertrend\"}");
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

   // Single-consume new-bar event (DWX invariant #3): call QM_IsNewBar() once,
   // latch it, and reuse for both the closed-bar state advance and the entry gate.
   const bool nb = QM_IsNewBar();
   if(nb)
      AdvanceState_OnNewBar();

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (EMA<SMA state). Separate from SL/TP.
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

   if(!nb)
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
