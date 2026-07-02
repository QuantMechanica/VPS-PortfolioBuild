#property strict
#property version   "5.0"
#property description "QM5_12613 — TSMOM 3-Month Sign Momentum on XAUUSD"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12613 tsmom-3m-commodity-xauusd
// Strategy: Time-series momentum (sign) at 3-month (63 D1 bar) lookback on
// XAUUSD. Monthly rebalance: if close[1] > close[1+lookback], go long; else
// go short. Source: Moskowitz, Ooi & Pedersen (2012) JFE 104(2), Table 2.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12613;
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
input int    strategy_lookback_bars     = 63;   // D1 bars for 3-month return (≈63 trading days)
input int    strategy_atr_period        = 14;   // ATR period for stop distance
input double strategy_atr_sl_mult       = 2.5;  // ATR multiplier for stop-loss
input int    strategy_spread_max_pips   = 30;   // Block entry if spread exceeds this (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block entry if spread is genuinely abnormal.
// DWX .DWX symbols quote spread=0 in the tester — only block real wide spreads.
bool Strategy_NoTradeFilter()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0 && bid > 0 && ask > bid)
     {
      double spread_limit = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_max_pips);
      if((ask - bid) > spread_limit)
         return true;  // abnormal spread — block entry
     }
   return false;
  }

// Compute 3-month sign-momentum and enter/reverse on monthly boundary.
// Called after QM_IsNewBar() so this fires once per D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Monthly rebalance gate: only act on the first D1 bar of each new month.
   if(!QM_IsNewCalendarPeriod(PERIOD_MN1))
      return false;

   double close_now = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke N-bar lookback return, no QM_* reader covers arbitrary close shift
   double close_ago = iClose(_Symbol, PERIOD_D1, 1 + strategy_lookback_bars); // perf-allowed: bespoke N-bar lookback return, no QM_* reader covers arbitrary close shift
   if(close_now <= 0 || close_ago <= 0)
      return false;

   int signal = (close_now > close_ago) ? 1 : -1;

   const int magic = QM_FrameworkMagic();
   bool has_long  = false;
   bool has_short = false;

   // Audit current positions for this EA
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)  has_long  = true;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) has_short = true;
     }

   // Close opposite position on reversal (close short → go long, or vice versa)
   if(signal > 0 && has_short)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
      has_short = false;
     }
   else if(signal < 0 && has_long)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
      has_long = false;
     }

   // Already in the correct direction — hold
   if(signal > 0 && has_long)  return false;
   if(signal < 0 && has_short) return false;

   // Compute ATR stop for new position
   double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0)
      return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   req.type  = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;  // market order; framework fills at current price

   double entry_ref = (req.type == QM_BUY) ? ask : bid;
   req.sl   = QM_StopATR(_Symbol, req.type, entry_ref, strategy_atr_period, strategy_atr_sl_mult);
   req.tp   = 0.0;   // no TP; exit via monthly reversal or SL
   req.reason = StringFormat("TSMOM3M sig=%d c1=%.2f c%d=%.2f",
                             signal, close_now, 1 + strategy_lookback_bars, close_ago);
   req.symbol_slot       = 0;
   req.expiration_seconds = 0;

   return true;
  }

// No per-tick management needed: SL enforced by framework; reversal handled in EntrySignal.
void Strategy_ManageOpenPosition()
  {
  }

// No standalone exit signal: exits happen via SL or monthly reversal in EntrySignal.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News filter hook: defer to framework 2-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

// OnTick order (2026-07-02 binding): kill-switch → Friday-close → NoTradeFilter →
// ManageOpenPosition → ExitSignal → news gate → IsNewBar → EntrySignal.
// News gate sits below exit handling so position management runs through news windows.
void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();

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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // News gate: blocks entry path only (management runs above regardless of news)
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
