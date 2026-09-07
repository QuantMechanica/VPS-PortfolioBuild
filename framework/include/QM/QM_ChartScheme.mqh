#ifndef QM_CHARTSCHEME_MQH
#define QM_CHARTSCHEME_MQH

// QuantMechanica light chart scheme. Presentation only: no trade operations.

#define QM_SCHEME_BG       C'255,255,255'
#define QM_SCHEME_SURFACE  C'248,250,252'
#define QM_SCHEME_BORDER   C'203,213,225'
#define QM_SCHEME_TEXT     C'15,23,42'
#define QM_SCHEME_MUTED    C'71,85,105'
#define QM_SCHEME_STEEL    C'41,84,212'
#define QM_SCHEME_EMERALD  C'5,150,105'
#define QM_SCHEME_AMBER    C'217,119,6'
#define QM_SCHEME_RED      C'239,68,68'

struct QMChartSchemeSnapshot
  {
   bool applied;
   long chart_id;
   long background;
   long foreground;
   long grid;
   long chart_up;
   long chart_down;
   long candle_bull;
   long candle_bear;
   long chart_line;
   long volume;
   long bid;
   long ask;
   long last;
   long stop_level;
   long chart_mode;
   long chart_scale;
   long show_grid;
   long show_bid;
   long show_ask;
  };

QMChartSchemeSnapshot g_qm_chart_scheme_snapshot;

bool QM_ChartScheme_Apply(const long chart_id)
  {
   if(MQLInfoInteger(MQL_TESTER) != 0 || chart_id < 0)
      return false;
   if(g_qm_chart_scheme_snapshot.applied)
      return (g_qm_chart_scheme_snapshot.chart_id == chart_id);

   g_qm_chart_scheme_snapshot.chart_id = chart_id;
   g_qm_chart_scheme_snapshot.background = ChartGetInteger(chart_id, CHART_COLOR_BACKGROUND, 0);
   g_qm_chart_scheme_snapshot.foreground = ChartGetInteger(chart_id, CHART_COLOR_FOREGROUND, 0);
   g_qm_chart_scheme_snapshot.grid = ChartGetInteger(chart_id, CHART_COLOR_GRID, 0);
   g_qm_chart_scheme_snapshot.chart_up = ChartGetInteger(chart_id, CHART_COLOR_CHART_UP, 0);
   g_qm_chart_scheme_snapshot.chart_down = ChartGetInteger(chart_id, CHART_COLOR_CHART_DOWN, 0);
   g_qm_chart_scheme_snapshot.candle_bull = ChartGetInteger(chart_id, CHART_COLOR_CANDLE_BULL, 0);
   g_qm_chart_scheme_snapshot.candle_bear = ChartGetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, 0);
   g_qm_chart_scheme_snapshot.chart_line = ChartGetInteger(chart_id, CHART_COLOR_CHART_LINE, 0);
   g_qm_chart_scheme_snapshot.volume = ChartGetInteger(chart_id, CHART_COLOR_VOLUME, 0);
   g_qm_chart_scheme_snapshot.bid = ChartGetInteger(chart_id, CHART_COLOR_BID, 0);
   g_qm_chart_scheme_snapshot.ask = ChartGetInteger(chart_id, CHART_COLOR_ASK, 0);
   g_qm_chart_scheme_snapshot.last = ChartGetInteger(chart_id, CHART_COLOR_LAST, 0);
   g_qm_chart_scheme_snapshot.stop_level = ChartGetInteger(chart_id, CHART_COLOR_STOP_LEVEL, 0);
   g_qm_chart_scheme_snapshot.chart_mode = ChartGetInteger(chart_id, CHART_MODE, 0);
   g_qm_chart_scheme_snapshot.chart_scale = ChartGetInteger(chart_id, CHART_SCALE, 0);
   g_qm_chart_scheme_snapshot.show_grid = ChartGetInteger(chart_id, CHART_SHOW_GRID, 0);
   g_qm_chart_scheme_snapshot.show_bid = ChartGetInteger(chart_id, CHART_SHOW_BID_LINE, 0);
   g_qm_chart_scheme_snapshot.show_ask = ChartGetInteger(chart_id, CHART_SHOW_ASK_LINE, 0);
   g_qm_chart_scheme_snapshot.applied = true;

   bool ok = true;
   ok = ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, QM_SCHEME_BG) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, QM_SCHEME_TEXT) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_GRID, QM_SCHEME_BORDER) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, QM_SCHEME_EMERALD) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, QM_SCHEME_RED) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, QM_SCHEME_EMERALD) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, QM_SCHEME_RED) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, QM_SCHEME_TEXT) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_VOLUME, QM_SCHEME_STEEL) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_BID, QM_SCHEME_STEEL) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_ASK, QM_SCHEME_STEEL) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_LAST, QM_SCHEME_STEEL) && ok;
   ok = ChartSetInteger(chart_id, CHART_COLOR_STOP_LEVEL, QM_SCHEME_RED) && ok;
   ok = ChartSetInteger(chart_id, CHART_MODE, CHART_CANDLES) && ok;
   ok = ChartSetInteger(chart_id, CHART_SCALE, 3) && ok;
   ok = ChartSetInteger(chart_id, CHART_SHOW_GRID, false) && ok;
   ok = ChartSetInteger(chart_id, CHART_SHOW_BID_LINE, true) && ok;
   ok = ChartSetInteger(chart_id, CHART_SHOW_ASK_LINE, true) && ok;
   if(!ok)
     {
      QM_ChartScheme_Restore(chart_id);
      return false;
     }
   ChartRedraw(chart_id);
   return true;
  }

void QM_ChartScheme_Restore(const long chart_id)
  {
   if(!g_qm_chart_scheme_snapshot.applied ||
      g_qm_chart_scheme_snapshot.chart_id != chart_id)
      return;
   ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, g_qm_chart_scheme_snapshot.background);
   ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, g_qm_chart_scheme_snapshot.foreground);
   ChartSetInteger(chart_id, CHART_COLOR_GRID, g_qm_chart_scheme_snapshot.grid);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, g_qm_chart_scheme_snapshot.chart_up);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, g_qm_chart_scheme_snapshot.chart_down);
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, g_qm_chart_scheme_snapshot.candle_bull);
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, g_qm_chart_scheme_snapshot.candle_bear);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, g_qm_chart_scheme_snapshot.chart_line);
   ChartSetInteger(chart_id, CHART_COLOR_VOLUME, g_qm_chart_scheme_snapshot.volume);
   ChartSetInteger(chart_id, CHART_COLOR_BID, g_qm_chart_scheme_snapshot.bid);
   ChartSetInteger(chart_id, CHART_COLOR_ASK, g_qm_chart_scheme_snapshot.ask);
   ChartSetInteger(chart_id, CHART_COLOR_LAST, g_qm_chart_scheme_snapshot.last);
   ChartSetInteger(chart_id, CHART_COLOR_STOP_LEVEL, g_qm_chart_scheme_snapshot.stop_level);
   ChartSetInteger(chart_id, CHART_MODE, g_qm_chart_scheme_snapshot.chart_mode);
   ChartSetInteger(chart_id, CHART_SCALE, g_qm_chart_scheme_snapshot.chart_scale);
   ChartSetInteger(chart_id, CHART_SHOW_GRID, g_qm_chart_scheme_snapshot.show_grid);
   ChartSetInteger(chart_id, CHART_SHOW_BID_LINE, g_qm_chart_scheme_snapshot.show_bid);
   ChartSetInteger(chart_id, CHART_SHOW_ASK_LINE, g_qm_chart_scheme_snapshot.show_ask);
   ChartRedraw(chart_id);
   g_qm_chart_scheme_snapshot.applied = false;
  }

#endif // QM_CHARTSCHEME_MQH
