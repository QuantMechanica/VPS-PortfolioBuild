#ifndef QM_RISKSIZER_MQH
#define QM_RISKSIZER_MQH

// V5 Framework Step 05:
// Pure risk sizing math with MT5 symbol snapshot helpers.

enum QM_RiskMode
  {
   QM_RISK_MODE_UNSET   = 0,
   QM_RISK_MODE_PERCENT = 1,
   QM_RISK_MODE_FIXED   = 2
  };

struct QM_SymbolRiskSnapshot
  {
   double tick_value;
   double tick_size;
   double point;
   double volume_min;
   double volume_max;
   double volume_step;
   double contract_size;
   double margin_initial;
  };

QM_RiskMode g_qm_risk_mode                  = QM_RISK_MODE_UNSET;
double      g_qm_risk_percent               = 0.0;
double      g_qm_risk_fixed                 = 0.0;
double      g_qm_risk_portfolio_weight      = 1.0;
double      g_qm_risk_per_trade_cap_money   = 0.0;

bool QM_RiskSizerConfigure(const QM_RiskMode mode,
                           const double risk_percent,
                           const double risk_fixed,
                           const double portfolio_weight,
                           const double per_trade_cap_money = 0.0)
  {
   g_qm_risk_mode = mode;
   g_qm_risk_percent = risk_percent;
   g_qm_risk_fixed = risk_fixed;
   g_qm_risk_portfolio_weight = portfolio_weight;
   g_qm_risk_per_trade_cap_money = per_trade_cap_money;

   if(g_qm_risk_mode != QM_RISK_MODE_PERCENT && g_qm_risk_mode != QM_RISK_MODE_FIXED)
      return false;
   if(g_qm_risk_portfolio_weight <= 0.0 || g_qm_risk_portfolio_weight > 1.0)
      return false;
   if(g_qm_risk_mode == QM_RISK_MODE_PERCENT && g_qm_risk_percent <= 0.0)
      return false;
   if(g_qm_risk_mode == QM_RISK_MODE_FIXED && g_qm_risk_fixed <= 0.0)
      return false;
   return true;
  }

double QM_RiskSizerRiskMoney(const double equity)
  {
   if(equity <= 0.0)
      return 0.0;

   double base_risk = 0.0;
   if(g_qm_risk_mode == QM_RISK_MODE_PERCENT)
      base_risk = equity * (g_qm_risk_percent / 100.0);
   else if(g_qm_risk_mode == QM_RISK_MODE_FIXED)
      base_risk = g_qm_risk_fixed;
   else
      return 0.0;

   double weighted_risk = base_risk * g_qm_risk_portfolio_weight;
   if(weighted_risk <= 0.0)
      return 0.0;

   if(g_qm_risk_per_trade_cap_money > 0.0 && weighted_risk > g_qm_risk_per_trade_cap_money)
      weighted_risk = g_qm_risk_per_trade_cap_money;
   return weighted_risk;
  }

double QM_RiskSizerQuantizeLots(const double raw_lots,
                                const double volume_min,
                                const double volume_max,
                                const double volume_step)
  {
   if(raw_lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0)
      return 0.0;

   double capped = raw_lots;
   if(capped > volume_max)
      capped = volume_max;

   // Floor to broker volume step to avoid accidental risk overshoot.
   double steps = MathFloor((capped + 1e-12) / volume_step);
   double quantized = steps * volume_step;
   quantized = NormalizeDouble(quantized, 8);

   if(quantized < volume_min)
      return 0.0;
   if(quantized > volume_max)
      quantized = volume_max;
   return quantized;
  }

bool QM_RiskSizerReadSymbolSnapshot(const string symbol, QM_SymbolRiskSnapshot &snapshot)
  {
   snapshot.tick_value     = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   snapshot.tick_size      = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   snapshot.point          = SymbolInfoDouble(symbol, SYMBOL_POINT);
   snapshot.volume_min     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   snapshot.volume_max     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   snapshot.volume_step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   snapshot.contract_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   snapshot.margin_initial = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);

   if(snapshot.point <= 0.0 || snapshot.volume_min <= 0.0 || snapshot.volume_max <= 0.0 || snapshot.volume_step <= 0.0)
      return false;
   return true;
  }

double QM_LotsForRiskFromSnapshot(const QM_SymbolRiskSnapshot &snapshot,
                                  const double risk_money,
                                  const double sl_points)
  {
   if(risk_money <= 0.0 || sl_points <= 0.0)
      return 0.0;

   double point_value_per_lot = 0.0;
   if(snapshot.tick_value > 0.0 && snapshot.tick_size > 0.0 && snapshot.point > 0.0)
      point_value_per_lot = snapshot.tick_value * (snapshot.point / snapshot.tick_size);
   else if(snapshot.contract_size > 0.0 && snapshot.point > 0.0)
      point_value_per_lot = snapshot.contract_size * snapshot.point;

   if(point_value_per_lot <= 0.0)
      return 0.0;

   double loss_per_lot = sl_points * point_value_per_lot;
   if(loss_per_lot <= 0.0)
      return 0.0;

   double raw_lots = risk_money / loss_per_lot;
   if(raw_lots <= 0.0)
      return 0.0;

   double lots = QM_RiskSizerQuantizeLots(raw_lots, snapshot.volume_min, snapshot.volume_max, snapshot.volume_step);
   return lots;
  }

double QM_LotsForRisk(const string symbol, const double sl_points)
  {
   QM_SymbolRiskSnapshot snapshot;
   if(!QM_RiskSizerReadSymbolSnapshot(symbol, snapshot))
      return 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_money = QM_RiskSizerRiskMoney(equity);
   if(risk_money <= 0.0)
      return 0.0;

   double lots = QM_LotsForRiskFromSnapshot(snapshot, risk_money, sl_points);
   if(lots <= 0.0)
      return 0.0;

   // If broker provides a generic initial margin, cap by available margin.
   if(snapshot.margin_initial > 0.0)
     {
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(free_margin <= 0.0)
         return 0.0;

      double margin_cap_lots = free_margin / snapshot.margin_initial;
      lots = QM_RiskSizerQuantizeLots(MathMin(lots, margin_cap_lots),
                                      snapshot.volume_min,
                                      snapshot.volume_max,
                                      snapshot.volume_step);
     }

   return lots;
  }

#endif // QM_RISKSIZER_MQH
