#property strict
#property version   "5.0"
#property description "QM5_12985 ndx-rsi2-shorthold-mr: RSI(2) Short-Hold Mean Reversion on US/EU indices (D1)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// ============================================================================
// QM5_12985 — NDX / SP500 / GDAXI RSI(2) Short-Hold Mean Reversion (prop-track)
// Source:  Connors & Alvarez (2009) Short Term Trading Strategies That Work,
//          Ch. 9 (licensed copy, library-mining lane P2)
// Card:    QM5_12985_ndx-rsi2-shorthold-mr
// ============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12985;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// RSI(2) dip threshold: fire BUY when RSI(2) of last closed D1 bar < this value.
input double rsi_entry_threshold          = 10.0;
// Maximum D1 bars to hold before forced exit (time stop).
input int    max_hold_bars                = 5;
// Protective SL = entry_price - stop_atr_mult * ATR(atr_period_sl).
// Prop-track deviation from Connors no-stop original (documented in card).
input double stop_atr_mult                = 3.0;
// Regime filter: close must be above SMA(sma_regime_period) to allow entry.
input int    sma_regime_period            = 200;
// Exit when close > SMA(sma_exit_period) — Connors canonical exit.
input int    sma_exit_period              = 5;
// RSI period (fixed at 2 per the published strategy).
input int    rsi_period                   = 2;
// ATR period for the protective stop calculation.
input int    atr_period_sl                = 14;

// ============================================================================
// Strategy hooks — implemented against the card mechanics (closed-bar D1)
// ============================================================================

// No intraday session filter needed; all signals use last closed D1 bar (shift 1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry: regime OK (close > SMA200) AND RSI(2) < threshold -> BUY at open.
// One position per magic; re-entry blocked while position is open.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Block if already in a position for this magic.
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Regime filter: last closed D1 bar close must be above SMA(200).
   // QM_Sig_Price_Above_MA returns +1 when close[shift] > SMA(period)[shift].
   if(QM_Sig_Price_Above_MA(_Symbol, PERIOD_D1, sma_regime_period, 0, 1) <= 0)
      return false;

   // Entry signal: RSI(2) of last closed D1 bar below entry threshold.
   const double rsi_val = QM_RSI(_Symbol, PERIOD_D1, rsi_period, 1, PRICE_CLOSE);
   if(rsi_val <= 0.0 || rsi_val >= rsi_entry_threshold)
      return false;

   // Fill entry request: BUY at next bar open (market order).
   req.type   = QM_BUY;
   req.price  = 0.0;   // market — framework fills at ask
   req.reason = "RSI2_DIP_BUY_ABOVE_SMA200";

   // Protective stop: entry - stop_atr_mult x ATR(14), set as price.
   // Use ask as entry estimate (framework will open at market on next bar).
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   req.sl = QM_StopATR(_Symbol, QM_BUY, ask, atr_period_sl, stop_atr_mult);
   req.tp = 0.0;   // no TP; exit via SMA(5) exit signal or time stop

   return true;
  }

// No active management beyond entry-set stop; exit is handled by ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit when: (a) close > SMA(5) [Connors canonical], or (b) time stop elapsed.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return false;

   // Exit condition A: last closed D1 bar close > SMA(sma_exit_period).
   if(QM_Sig_Price_Above_MA(_Symbol, PERIOD_D1, sma_exit_period, 0, 1) > 0)
      return true;

   // Exit condition B: time stop — position has been held >= max_hold_bars D1 bars.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime open_time  = (datetime)PositionGetInteger(POSITION_TIME);
      const int      bars_held  = (int)((TimeCurrent() - open_time) / PeriodSeconds(PERIOD_D1));
      if(bars_held >= max_hold_bars)
         return true;
      break;   // single position per magic; no need to iterate further
     }

   return false;
  }

// No custom news hook; defers entirely to framework two-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// ============================================================================

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
