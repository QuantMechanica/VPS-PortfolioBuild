#property strict
#property version   "5.0"
#property description "QM5_10573 MQL5 Extrem_N Line Flip (mql5-extrem-n)"
// Strategy Card: QM5_10573 (mql5-extrem-n), G0 APPROVED 2026-05-22.
// Source: Nikolay Kositsin "Exp_Extrem_N", MQL5 CodeBase 14890, 2016.
//
// Mechanisation note (see SPEC.md §1 + open_questions): the Extrem_N indicator
// plots a green (bullish) / red (bearish) line whose colour flips when a new
// closed bar establishes a fresh N-bar extreme — green when the close breaks
// the prior N-bar high, red when it breaks the prior N-bar low. The card's
// "red/green line flip" entry/exit is therefore mechanised as a persistent
// N-bar extreme-channel regime (Donchian-style) read on closed bars via the
// framework QM_Sig_Range_Breakout primitive — no raw indicator math.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10573;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

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
// Extrem_N extreme-channel lookback: a green line flip = close breaks the prior
// N-bar high; a red line flip = close breaks the prior N-bar low. Card §Filter
// sweeps the Extrem_N indicator inputs; this is the closed-bar buffer length.
input int    strategy_extrem_n          = 12;    // N-bar extreme channel (Extrem_N period)
input int    strategy_atr_period        = 14;    // ATR period for the hard stop
input double strategy_atr_sl_mult       = 2.0;   // hard stop = ATR * mult (card P2 baseline 2.0)
input double strategy_tp_r_mult         = 1.5;   // target = 1.5R (card P2 baseline 1.5R)
// Optional volatility-minimum filter (card §Filter). 0 = disabled.
input double strategy_min_atr_points    = 0.0;   // block entry if ATR(period) < this many points

// -----------------------------------------------------------------------------
// File-scope cached state.
//   g_regime: persistent Extrem_N line colour. +1 green/bullish, -1 red/bearish,
//   0 not yet established. Advanced ONCE per closed bar inside Strategy_EntrySignal
//   (which the framework calls only behind its QM_IsNewBar gate). Read per-tick
//   by Strategy_ExitSignal — comparison only, no recompute / no lookback loop.
// -----------------------------------------------------------------------------
int g_regime = 0;

// Return the open-position direction for this EA's magic on this symbol:
//   +1 long, -1 short, 0 flat. O(positions) scan, no indicator math.
int OurPositionDir()
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
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// Optional volatility-minimum gate. Cheap O(1): QM_ATR is handle-pooled (single
// CopyBuffer). Disabled when strategy_min_atr_points <= 0.
bool Strategy_NoTradeFilter()
  {
   if(strategy_min_atr_points <= 0.0)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   return (atr < strategy_min_atr_points * point);
  }

// Called once per new closed bar (framework QM_IsNewBar gate). Advances the
// persistent Extrem_N regime, then fires a market entry when flat and the line
// colour calls for it.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance the persistent line colour from the last closed bar's extreme break.
   const int brk = QM_Sig_Range_Breakout(_Symbol, PERIOD_CURRENT, strategy_extrem_n, 1);
   if(brk != 0)
      g_regime = brk;

   if(g_regime == 0)
      return false;

   // One active position per symbol/magic — no entry while in a trade.
   if(OurPositionDir() != 0)
      return false;

   const bool go_long = (g_regime > 0);
   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;

   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   const double r_dist = MathAbs(entry - sl);
   if(r_dist <= 0.0)
      return false;
   const double tp = go_long ? entry + r_dist * strategy_tp_r_mult
                             : entry - r_dist * strategy_tp_r_mult;

   req.type               = side;
   req.price              = 0.0;            // 0 => framework fills at market (Ask/Bid)
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = go_long ? "EXTREM_N_GREEN_FLIP" : "EXTREM_N_RED_FLIP";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Card: no trailing / break-even / partial. Hard SL/TP set at entry handle exits.
void Strategy_ManageOpenPosition()
  {
  }

// Per-tick reversal exit: close when the Extrem_N line flips against the open
// position. Reads cached g_regime only — no recompute, no lookback loop.
bool Strategy_ExitSignal()
  {
   const int dir = OurPositionDir();
   if(dir == 0 || g_regime == 0)
      return false;
   return (dir > 0 && g_regime < 0) || (dir < 0 && g_regime > 0);
  }

// Defer to the central two-axis news filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10573_mql5_extrem_n\"}");
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

   if(!QM_IsNewBar())
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
