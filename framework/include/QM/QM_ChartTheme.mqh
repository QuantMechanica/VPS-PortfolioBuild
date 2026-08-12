#ifndef QM_CHARTTHEME_MQH
#define QM_CHARTTHEME_MQH

//+------------------------------------------------------------------+
//| QM_ChartTheme.mqh                                                |
//| QuantMechanica V5 - Light chart/panel colour scheme             |
//|                                                                  |
//| OWNER intent (2026-07-20): "helles rot/gruen auf weissem, hellem |
//| Hintergrund Farbschema" - bright red/green on a white/light      |
//| background, replacing the drab default look. Integrable so live  |
//| and future EAs simply recompile to adopt it.                     |
//|                                                                  |
//| CONTRACT                                                         |
//|  - Pure constants + tiny helpers. NO objects are created at      |
//|    include time (safe to include from any tester-bound EA).      |
//|  - Colour literals are standard MQL5 C'RED,GREEN,BLUE' order,    |
//|    which is what the MT5 standard <Controls> library uses too    |
//|    (verified against Controls\Defines.mqh). NOTE: the older      |
//|    QM_Branding.mqh writes literals byte-swapped (B,G,R) - do NOT |
//|    copy that convention here; this file is the corrected scheme. |
//|  - QM_ThemeApplyChart() is the only stateful helper and it       |
//|    guards itself against the Strategy Tester internally.         |
//|                                                                  |
//| CONSUMERS                                                        |
//|  - framework/monitor/QM_AccountMonitor.mq5 (now).                |
//|  - QM_ChartUI.mqh adoption + fleet recompile ride the Saturday   |
//|    wave; that live-book-critical include is intentionally NOT    |
//|    edited here.                                                  |
//+------------------------------------------------------------------+

// --- Surface -------------------------------------------------------
#define QM_THEME_BG          C'250,250,252'   // #FAFAFC  near-white chart background
#define QM_THEME_PANEL       C'255,255,255'   // #FFFFFF  panel / card fill
#define QM_THEME_BORDER      C'214,220,228'   // #D6DCE4  light-gray hairline border
#define QM_THEME_GRID        C'233,236,241'   // #E9ECF1  faint chart grid

// --- Text ----------------------------------------------------------
#define QM_THEME_TEXT        C'17,24,39'      // #111827  near-black primary text
#define QM_THEME_MUTED       C'107,114,128'   // #6B7280  muted label / secondary text

// --- P&L (bright, traditional trading colours) ---------------------
#define QM_THEME_PROFIT      C'0,166,80'      // #00A650  crisp bright green
#define QM_THEME_LOSS        C'229,57,53'     // #E53935  crisp bright red

// --- Accent (one restrained accent) --------------------------------
#define QM_THEME_ACCENT      C'37,99,235'     // #2563EB  restrained blue

// --- Typography ----------------------------------------------------
#define QM_THEME_FONT        "Segoe UI"
#define QM_THEME_FONT_MONO   "Consolas"
#define QM_THEME_FONT_SIZE_TITLE   11
#define QM_THEME_FONT_SIZE_NORMAL  9
#define QM_THEME_FONT_SIZE_SMALL   8

//+------------------------------------------------------------------+
//| Return the P&L colour for a signed value.                        |
//|   v > 0 -> profit green, v < 0 -> loss red, v == 0 -> muted.     |
//+------------------------------------------------------------------+
color QM_ThemePnlColor(const double v)
  {
   if(v > 0.0)
      return QM_THEME_PROFIT;
   if(v < 0.0)
      return QM_THEME_LOSS;
   return QM_THEME_MUTED;
  }

//+------------------------------------------------------------------+
//| Apply the light scheme to a chart's colours.                     |
//| Bull candles = theme green, bear = theme red, background white,  |
//| grid faint. No-op under the Strategy Tester (guarded here so     |
//| callers never have to special-case it).                          |
//+------------------------------------------------------------------+
void QM_ThemeApplyChart(const long chart_id)
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return; // never touch chart colours during backtests

   ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, QM_THEME_BG);
   ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, QM_THEME_TEXT);
   ChartSetInteger(chart_id, CHART_COLOR_GRID,       QM_THEME_GRID);

   ChartSetInteger(chart_id, CHART_COLOR_CHART_UP,   QM_THEME_PROFIT);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, QM_THEME_LOSS);
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, QM_THEME_PROFIT);
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, QM_THEME_LOSS);

   ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, QM_THEME_TEXT);
   ChartSetInteger(chart_id, CHART_COLOR_VOLUME,     QM_THEME_ACCENT);
   ChartSetInteger(chart_id, CHART_COLOR_BID,        QM_THEME_MUTED);
   ChartSetInteger(chart_id, CHART_COLOR_ASK,        QM_THEME_MUTED);
   ChartSetInteger(chart_id, CHART_COLOR_LAST,       QM_THEME_ACCENT);
   ChartSetInteger(chart_id, CHART_COLOR_STOP_LEVEL, QM_THEME_LOSS);

   ChartRedraw(chart_id);
  }

#endif // QM_CHARTTHEME_MQH
