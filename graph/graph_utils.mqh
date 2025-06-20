//+------------------------------------------------------------------+
//| graph_utils.mqh                                                 |
//| Funções auxiliares para desenhar indicadores visuais no gráfico |
//+------------------------------------------------------------------+
#property copyright "RX_02_BANSHEE_RAPIDFIRE"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CONSTANTES PARA OBJETOS GRÁFICOS                               |
//+------------------------------------------------------------------+
#define MAX_ARROWS_ON_CHART 20
#define ARROW_PREFIX "AlBrooks_Arrow_"
#define ARROW_UP_CODE 233        // ↑ 
#define ARROW_DOWN_CODE 234      // ↓
#define ARROW_SIZE 1

//+------------------------------------------------------------------+
//| CORES PARA AS SETAS                                            |
//+------------------------------------------------------------------+
enum ARROW_COLOR_TYPE {
   COLOR_HIGH_CONFIDENCE,   // Amarelo para alta confiança
   COLOR_LOW_CONFIDENCE     // Cor padrão para baixa confiança
};

//+------------------------------------------------------------------+
//| Estrutura para dados da seta                                   |
//+------------------------------------------------------------------+
struct ArrowData {
   datetime time;
   double price;
   bool isUpTrend;
   double confidence;
   string strategy;
};

//+------------------------------------------------------------------+
//| Classe para gerenciar setas no gráfico                         |
//+------------------------------------------------------------------+
class GraphArrowManager {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   double m_minConfidence;
   int m_arrowCounter;
   
public:
   //+------------------------------------------------------------------+
   //| Construtor                                                       |
   //+------------------------------------------------------------------+
   GraphArrowManager(string symbol, ENUM_TIMEFRAMES tf, double minConf) {
      m_symbol = symbol;
      m_timeframe = tf;
      m_minConfidence = minConf;
      m_arrowCounter = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Desenha seta de tendência no gráfico                           |
   //+------------------------------------------------------------------+
   bool DrawTrendArrow(const ArrowData &arrowData) {
      // Limpar objetos antigos primeiro
      CleanOldArrows();
      
      // Gerar nome único para o objeto
      string objectName = ARROW_PREFIX + IntegerToString(m_arrowCounter++);
      
      // Determinar posição da seta
      double arrowPrice = CalculateArrowPosition(arrowData.time, arrowData.isUpTrend);
      
      // Determinar tipo de seta
      int arrowCode = arrowData.isUpTrend ? ARROW_UP_CODE : ARROW_DOWN_CODE;
      
      // Criar objeto seta
      if (!ObjectCreate(0, objectName, OBJ_ARROW, 0, arrowData.time, arrowPrice)) {
         Print("Erro ao criar seta: ", GetLastError());
         return false;
      }
      
      // Configurar propriedades da seta
      SetupArrowProperties(objectName, arrowCode, arrowData);
      
      // Log da criação
      PrintArrowInfo(objectName, arrowData);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Remove todas as setas do gráfico                               |
   //+------------------------------------------------------------------+
   void ClearAllArrows() {
      int totalObjects = ObjectsTotal(0);
      
      for (int i = totalObjects - 1; i >= 0; i--) {
         string objName = ObjectName(0, i);
         if (StringFind(objName, ARROW_PREFIX) == 0) {
            ObjectDelete(0, objName);
         }
      }
      
      m_arrowCounter = 0;
      Print("Todas as setas removidas do gráfico");
   }
   
private:
   //+------------------------------------------------------------------+
   //| Calcula posição da seta baseada no candle                      |
   //+------------------------------------------------------------------+
   double CalculateArrowPosition(datetime time, bool isUpTrend) {
      int barIndex = iBarShift(m_symbol, m_timeframe, time);
      if (barIndex < 0) barIndex = 0;
      
      double high = iHigh(m_symbol, m_timeframe, barIndex);
      double low = iLow(m_symbol, m_timeframe, barIndex);
      double range = high - low;
      
      // Margem para posicionar a seta
      double margin = range * 0.3;
      if (margin <= 0) margin = SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10;
      
      if (isUpTrend) {
         return high + margin;  // Seta acima do candle
      } else {
         return low - margin;   // Seta abaixo do candle
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configura propriedades visuais da seta                        |
   //+------------------------------------------------------------------+
   void SetupArrowProperties(string objectName, int arrowCode, const ArrowData &data) {
      // Código da seta
      ObjectSetInteger(0, objectName, OBJPROP_ARROWCODE, arrowCode);
      
      // Tamanho da seta
      ObjectSetInteger(0, objectName, OBJPROP_WIDTH, ARROW_SIZE);
      
      // Cor baseada na confiança
      color arrowColor = GetArrowColor(data.confidence);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, arrowColor);
      
      // Tooltip com informações
      string tooltip = GenerateTooltip(data);
      ObjectSetString(0, objectName, OBJPROP_TOOLTIP, tooltip);
      
      // Configurações adicionais
      ObjectSetInteger(0, objectName, OBJPROP_BACK, false);      // Frente
      ObjectSetInteger(0, objectName, OBJPROP_SELECTED, false);  // Não selecionado
      ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, true); // Selecionável
      ObjectSetInteger(0, objectName, OBJPROP_HIDDEN, false);    // Visível
   }
   
   //+------------------------------------------------------------------+
   //| Determina cor da seta baseada na confiança                     |
   //+------------------------------------------------------------------+
   color GetArrowColor(double confidence) {
      if (confidence >= m_minConfidence) {
         return clrBlue;  // Alta confiança = Amarelo
      } else {
         return clrOrangeRed;  // Baixa confiança = Cinza claro
      }
   }
   
   //+------------------------------------------------------------------+
   //| Gera tooltip informativo para a seta                          |
   //+------------------------------------------------------------------+
   string GenerateTooltip(const ArrowData &data) {
      string direction = data.isUpTrend ? "ALTA" : "BAIXA";
      string confLevel = data.confidence >= m_minConfidence ? "ALTA" : "BAIXA";
      
      return StringFormat(
         "Al Brooks - %s\n" +
         "Direção: %s\n" +
         "Confiança: %.1f%% (%s)\n" +
         "Estratégia: %s\n" +
         "Tempo: %s",
         direction,
         direction,
         data.confidence,
         confLevel,
         data.strategy,
         TimeToString(data.time, TIME_DATE | TIME_MINUTES)
      );
   }
   
   //+------------------------------------------------------------------+
   //| Remove setas antigas para manter apenas as últimas 20          |
   //+------------------------------------------------------------------+
   void CleanOldArrows() {
      // Coletar todas as setas existentes
      string arrowNames[];
      datetime arrowTimes[];
      int arrowCount = 0;
      
      int totalObjects = ObjectsTotal(0);
      
      // Primeiro, contar quantas setas temos
      for (int i = 0; i < totalObjects; i++) {
         string objName = ObjectName(0, i);
         if (StringFind(objName, ARROW_PREFIX) == 0) {
            arrowCount++;
         }
      }
      
      // Se ainda não excedeu o limite, não precisa limpar
      if (arrowCount < MAX_ARROWS_ON_CHART) {
         return;
      }
      
      // Redimensionar arrays
      ArrayResize(arrowNames, arrowCount);
      ArrayResize(arrowTimes, arrowCount);
      
      // Coletar informações das setas
      int index = 0;
      for (int i = 0; i < totalObjects; i++) {
         string objName = ObjectName(0, i);
         if (StringFind(objName, ARROW_PREFIX) == 0) {
            arrowNames[index] = objName;
            arrowTimes[index] = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
            index++;
         }
      }
      
      // Ordenar por tempo (mais antigas primeiro)
      SortArrowsByTime(arrowNames, arrowTimes, arrowCount);
      
      // Remover as mais antigas
      int toRemove = arrowCount - MAX_ARROWS_ON_CHART + 1;
      for (int i = 0; i < toRemove; i++) {
         ObjectDelete(0, arrowNames[i]);
      }
      
      if (toRemove > 0) {
         Print("Removidas ", toRemove, " setas antigas. Mantidas ", MAX_ARROWS_ON_CHART - 1);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Ordena setas por tempo (bubble sort simples)                   |
   //+------------------------------------------------------------------+
   void SortArrowsByTime(string &names[], datetime &times[], int count) {
      for (int i = 0; i < count - 1; i++) {
         for (int j = 0; j < count - i - 1; j++) {
            if (times[j] > times[j + 1]) {
               // Trocar tempos
               datetime tempTime = times[j];
               times[j] = times[j + 1];
               times[j + 1] = tempTime;
               
               // Trocar nomes
               string tempName = names[j];
               names[j] = names[j + 1];
               names[j + 1] = tempName;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Imprime informações sobre a seta criada                        |
   //+------------------------------------------------------------------+
   void PrintArrowInfo(string objectName, const ArrowData &data) {
      string direction = data.isUpTrend ? "↑" : "↓";
      string confStatus = data.confidence >= m_minConfidence ? "ALTA" : "baixa";
      
      Print(StringFormat("Seta %s criada: %s %.1f%% (%s) - %s", 
            direction, 
            data.strategy,
            data.confidence, 
            confStatus,
            objectName));
   }
};

//+------------------------------------------------------------------+
//| FUNÇÃO PRINCIPAL PARA USO NO EA                                |
//+------------------------------------------------------------------+

// Instância global do gerenciador (será inicializada no EA)
GraphArrowManager* g_arrowManager = NULL;

//+------------------------------------------------------------------+
//| Inicializa o gerenciador de setas                              |
//+------------------------------------------------------------------+
bool InitializeArrowManager(string symbol, ENUM_TIMEFRAMES tf, double minConfidence) {
   if (g_arrowManager != NULL) {
      delete g_arrowManager;
   }
   
   g_arrowManager = new GraphArrowManager(symbol, tf, minConfidence);
   
   if (g_arrowManager == NULL) {
      Print("Erro: Falha ao inicializar gerenciador de setas");
      return false;
   }
   
   Print("Gerenciador de setas inicializado com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Desenha seta baseada nos dados Al Brooks                       |
//+------------------------------------------------------------------+
bool DrawAlBrooksArrow(datetime time, bool isUpTrend, double confidence, string strategy) {
   if (g_arrowManager == NULL) {
      Print("Erro: Gerenciador de setas não inicializado");
      return false;
   }
   
   ArrowData data;
   data.time = time;
   data.isUpTrend = isUpTrend;
   data.confidence = confidence;
   data.strategy = strategy;
   
   return g_arrowManager.DrawTrendArrow(data);
}

//+------------------------------------------------------------------+
//| Limpa todas as setas do gráfico                                |
//+------------------------------------------------------------------+
void ClearAllAlBrooksArrows() {
   if (g_arrowManager != NULL) {
      g_arrowManager.ClearAllArrows();
   }
}

//+------------------------------------------------------------------+
//| Finaliza o gerenciador de setas                                |
//+------------------------------------------------------------------+
void DeinitializeArrowManager() {
   if (g_arrowManager != NULL) {
      delete g_arrowManager;
      g_arrowManager = NULL;
   }
   Print("Gerenciador de setas finalizado");
}