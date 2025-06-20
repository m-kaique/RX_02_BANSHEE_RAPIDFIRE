//+------------------------------------------------------------------+
//| RX_02_BANSHEE_RAPIDFIRE                                         |
//| EA Base demonstrando detecção de tendências Al Brooks           |
//+------------------------------------------------------------------+
#property copyright "RX_02_BANSHEE_RAPIDFIRE"
#property version "1.00"
#property strict

#include <Trade/Trade.mqh>
#include "graph/graph_utils.mqh"

//+------------------------------------------------------------------+
//| PARÂMETROS DE ENTRADA - MINIMALISTAS                            |
//+------------------------------------------------------------------+
input group "=== Configurações Básicas ===" input bool EnableTrading = false; // Habilitar trading real
input double RiskPercent = 1.0;                                               // Risco por trade (%)
input double MinConfidence = 60.0;                                            // Confiança mínima Al Brooks (%)
input int MinPatterns = 1;                                                    // Mínimo de padrões ativos

input group "=== Al Brooks Settings ===" input double SpikeStrength = 70.0; // Força mínima do spike
input int TrendFromOpenBars = 3;                                            // Barras mínimas trend from open
input double MaxPullbackPercent = 5.0;                                      // Pullback máximo permitido (%)

input group "=== Visualização ===" input bool ShowArrowsOnChart = true; // Mostrar setas no gráfic
//+------------------------------------------------------------------+
//| INCLUDES SIMPLIFICADOS - Usar apenas o necessário              |
//+------------------------------------------------------------------+

// Estruturas básicas necessárias
enum MARKET_PHASE
{
   PHASE_TREND,
   PHASE_RANGE,
   PHASE_REVERSAL,
   PHASE_UNDEFINED
};
enum SIGNAL_DIRECTION
{
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
};
enum SETUP_QUALITY
{
   SETUP_A_PLUS,
   SETUP_A,
   SETUP_B,
   SETUP_C
};

struct Signal
{
   bool valid;
   SIGNAL_DIRECTION direction;
   MARKET_PHASE phase;
   SETUP_QUALITY quality;
   double entry;
   double stop;
   double target;
   datetime timestamp;
   string strategy;
};

// Estrutura Al Brooks simplificada para este EA
struct SimpleAlBrooksData
{
   bool spikeDetected;
   bool trendFromOpenDetected;
   bool smallPullbackDetected;

   bool isUpTrend;
   double confidence;
   int activePatterns;
   string summary;
};

//+------------------------------------------------------------------+
//| CLASSES SIMPLIFICADAS                                           |
//+------------------------------------------------------------------+

class SimpleAlBrooksAnalyzer
{
private:
   double m_spikeThreshold;
   int m_trendFromOpenMin;
   double m_maxPullback;

public:
   SimpleAlBrooksAnalyzer(double spikeThresh, int trendMin, double maxPull)
   {
      m_spikeThreshold = spikeThresh;
      m_trendFromOpenMin = trendMin;
      m_maxPullback = maxPull;
   }

   //+------------------------------------------------------------------+
   //| Análise simplificada Al Brooks                                  |
   //+------------------------------------------------------------------+
   SimpleAlBrooksData AnalyzeMarket(const string symbol, ENUM_TIMEFRAMES tf)
   {
      SimpleAlBrooksData data;
      data.spikeDetected = false;
      data.trendFromOpenDetected = false;
      data.smallPullbackDetected = false;
      data.activePatterns = 0;
      data.confidence = 0.0;

      // 1. SPIKE DETECTION - 3 barras consecutivas fortes
      data.spikeDetected = DetectSpike(symbol, tf, data.isUpTrend);
      if (data.spikeDetected)
         data.activePatterns++;

      // 2. TREND FROM OPEN - Movimento desde abertura do dia
      data.trendFromOpenDetected = DetectTrendFromOpen(symbol, tf, data.isUpTrend);
      if (data.trendFromOpenDetected)
         data.activePatterns++;

      // 3. SMALL PULLBACK - Pullbacks pequenos consistentes
      data.smallPullbackDetected = DetectSmallPullback(symbol, tf, data.isUpTrend);
      if (data.smallPullbackDetected)
         data.activePatterns++;

      // 4. CALCULAR CONFIANÇA
      data.confidence = CalculateConfidence(data);

      // 5. GERAR RESUMO
      data.summary = GenerateSummary(data);

      return data;
   }

private:
   //+------------------------------------------------------------------+
   //| Detecta Spike simples - 3 barras fortes na mesma direção       |
   //+------------------------------------------------------------------+
   bool DetectSpike(const string symbol, ENUM_TIMEFRAMES tf, bool &isUp)
   {
      const int bars = 3;
      const double minBodyRatio = 0.6;

      bool upSpike = true, downSpike = true;

      for (int i = 1; i <= bars; i++)
      {
         double open = iOpen(symbol, tf, i);
         double close = iClose(symbol, tf, i);
         double high = iHigh(symbol, tf, i);
         double low = iLow(symbol, tf, i);
         double range = high - low;

         if (range <= 0)
            return false;

         double body = MathAbs(close - open);

         // Verificar spike de alta
         if (close <= open || body < range * minBodyRatio)
            upSpike = false;

         // Verificar spike de baixa
         if (close >= open || body < range * minBodyRatio)
            downSpike = false;
      }

      if (upSpike)
      {
         isUp = true;
         return true;
      }
      if (downSpike)
      {
         isUp = false;
         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Detecta Trend from Open - movimento desde abertura             |
   //+------------------------------------------------------------------+
   bool DetectTrendFromOpen(const string symbol, ENUM_TIMEFRAMES tf, bool &isUp)
   {
      // Pegar abertura do dia
      datetime dayStart = iTime(symbol, PERIOD_D1, 0);
      int dayStartBar = iBarShift(symbol, tf, dayStart);

      if (dayStartBar <= 0 || dayStartBar > 50)
         return false;

      double openPrice = iOpen(symbol, tf, dayStartBar);
      double currentPrice = iClose(symbol, tf, 0);

      // Contar barras consecutivas na direção
      bool isUpMove = currentPrice > openPrice;
      int consecutiveBars = 0;
      double maxPullback = 0.0;
      double totalMove = MathAbs(currentPrice - openPrice);

      for (int i = dayStartBar - 1; i >= 0; i--)
      {
         double close = iClose(symbol, tf, i);
         double prevClose = iClose(symbol, tf, i + 1);

         if ((isUpMove && close > prevClose) || (!isUpMove && close < prevClose))
         {
            consecutiveBars++;
         }
         else
         {
            double pullback = MathAbs(close - prevClose) / totalMove * 100.0;
            if (pullback > maxPullback)
               maxPullback = pullback;
            if (pullback > m_maxPullback)
               break;
         }
      }

      if (consecutiveBars >= m_trendFromOpenMin && maxPullback <= m_maxPullback)
      {
         isUp = isUpMove;
         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Detecta Small Pullback - poucos e pequenos pullbacks           |
   //+------------------------------------------------------------------+
   bool DetectSmallPullback(const string symbol, ENUM_TIMEFRAMES tf, bool &isUp)
   {
      const int analyzeBars = 10;
      double closes[];
      ArrayResize(closes, analyzeBars);

      for (int i = 0; i < analyzeBars; i++)
         closes[i] = iClose(symbol, tf, analyzeBars - 1 - i);

      bool isUpTrend = closes[analyzeBars - 1] > closes[0];
      int pullbackCount = 0;
      int strongCloses = 0;

      for (int i = 1; i < analyzeBars - 1; i++)
      {
         // Contar pullbacks pequenos
         if ((isUpTrend && closes[i] < closes[i - 1]) ||
             (!isUpTrend && closes[i] > closes[i - 1]))
         {
            pullbackCount++;
         }

         // Contar fechamentos fortes
         double high = iHigh(symbol, tf, analyzeBars - 1 - i);
         double low = iLow(symbol, tf, analyzeBars - 1 - i);
         double range = high - low;

         if (range > 0)
         {
            if (isUpTrend && (high - closes[i]) / range <= 0.3)
               strongCloses++;
            if (!isUpTrend && (closes[i] - low) / range <= 0.3)
               strongCloses++;
         }
      }

      if (pullbackCount <= 2 && strongCloses >= analyzeBars * 0.6)
      {
         isUp = isUpTrend;
         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Calcula confiança baseada nos padrões detectados               |
   //+------------------------------------------------------------------+
   double CalculateConfidence(const SimpleAlBrooksData &data)
   {
      double baseConf = (data.activePatterns / 3.0) * 70.0; // Base até 70%

      // Bonus por padrões específicos
      if (data.spikeDetected)
         baseConf += 10.0;
      if (data.trendFromOpenDetected)
         baseConf += 15.0;
      if (data.smallPullbackDetected)
         baseConf += 5.0;

      return MathMin(baseConf, 100.0);
   }

   //+------------------------------------------------------------------+
   //| Gera resumo textual dos padrões detectados                     |
   //+------------------------------------------------------------------+
   string GenerateSummary(const SimpleAlBrooksData &data)
   {
      if (data.activePatterns == 0)
         return "Nenhum padrão detectado";

      string dir = data.isUpTrend ? "ALTA" : "BAIXA";
      string patterns = "";

      if (data.spikeDetected)
         patterns += "Spike ";
      if (data.trendFromOpenDetected)
         patterns += "TrendOpen ";
      if (data.smallPullbackDetected)
         patterns += "SmallPull ";

      return StringFormat("%s: %s(%.0f%%)", dir, patterns, data.confidence);
   }
};

//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS                                               |
//+------------------------------------------------------------------+
CTrade trade;
SimpleAlBrooksAnalyzer *analyzer = NULL;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== SIMPLE AL BROOKS EA INICIANDO ===");

   // Inicializar analisador
   analyzer = new SimpleAlBrooksAnalyzer(
       SpikeStrength / 100.0,
       TrendFromOpenBars,
       MaxPullbackPercent);

   if (ShowArrowsOnChart)
   {
      if (!InitializeArrowManager(_Symbol, _Period, MinConfidence))
      {
         Print("Aviso: Falha ao inicializar visualização de setas");
      }
   }

   if (!EnableTrading)
      Print("MODO DEMO: Trading desabilitado - apenas análise");

   Print("Configurações: Conf.Min=", MinConfidence, "% Padrões.Min=", MinPatterns);
   Print("Setas no gráfico: ", ShowArrowsOnChart ? "ATIVADO" : "DESATIVADO");
   Print("=== INICIALIZAÇÃO COMPLETA ===");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeinitializeArrowManager();

   if (analyzer != NULL)
   {
      delete analyzer;
      analyzer = NULL;
   }
   Print("=== SIMPLE AL BROOKS EA FINALIZADO ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Verificar nova barra
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if (currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;

   // Análise Al Brooks
   SimpleAlBrooksData data = analyzer.AnalyzeMarket(_Symbol, _Period);

   // Log da análise
   if (data.activePatterns > 0)
   {
      Print("AL BROOKS: ", data.summary);
      PrintPatternDetails(data);
      // NOVO: Desenhar seta no gráfico
      if (ShowArrowsOnChart)
      {
         string strategy = GetPrimaryStrategy(data);
         bool arrowDrawn = DrawAlBrooksArrow(
             currentBarTime,
             data.isUpTrend,
             data.confidence,
             strategy);

         if (!arrowDrawn)
         {
            Print("Aviso: Falha ao desenhar seta no gráfico");
         }
      }
   }

   // Verificar critérios para trading
   if (ShouldTrade(data))
   {
      Signal signal = GenerateSignal(data);
      if (signal.valid)
      {
         ExecuteSignal(signal);
      }
   }
}

//+------------------------------------------------------------------+
//| Verifica se deve operar baseado nos critérios                  |
//+------------------------------------------------------------------+
bool ShouldTrade(const SimpleAlBrooksData &data)
{
   if (!EnableTrading)
      return false;
   if (data.confidence < MinConfidence)
      return false;
   if (data.activePatterns < MinPatterns)
      return false;
   if (PositionsTotal() > 0)
      return false; // Uma posição por vez

   return true;
}

//+------------------------------------------------------------------+
//| Gera sinal baseado na análise Al Brooks                        |
//+------------------------------------------------------------------+
Signal GenerateSignal(const SimpleAlBrooksData &data)
{
   Signal sig;
   sig.valid = true;
   sig.direction = data.isUpTrend ? SIGNAL_BUY : SIGNAL_SELL;
   sig.phase = PHASE_TREND;
   sig.entry = SymbolInfoDouble(_Symbol, data.isUpTrend ? SYMBOL_ASK : SYMBOL_BID);
   sig.timestamp = TimeCurrent();

   // Determinar estratégia prioritária
   if (data.spikeDetected)
   {
      sig.strategy = "AlBrooks_Spike";
      sig.quality = SETUP_A;
   }
   else if (data.trendFromOpenDetected)
   {
      sig.strategy = "AlBrooks_TrendFromOpen";
      sig.quality = SETUP_A;
   }
   else
   {
      sig.strategy = "AlBrooks_SmallPullback";
      sig.quality = SETUP_B;
   }

   // Calcular stop e target simples
   double atr = iATR(_Symbol, _Period, 14, 1);
   double stopDistance = atr * 1.5;

   if (sig.direction == SIGNAL_BUY)
   {
      sig.stop = sig.entry - stopDistance;
      sig.target = sig.entry + (stopDistance * 2.0); // R/R 1:2
   }
   else
   {
      sig.stop = sig.entry + stopDistance;
      sig.target = sig.entry - (stopDistance * 2.0);
   }

   return sig;
}

//+------------------------------------------------------------------+
//| Executa o sinal gerado                                          |
//+------------------------------------------------------------------+
void ExecuteSignal(const Signal &signal)
{
   double volume = CalculateVolume(signal);

   Print("=== EXECUTANDO SINAL ===");
   Print("Estratégia: ", signal.strategy);
   Print("Direção: ", signal.direction == SIGNAL_BUY ? "BUY" : "SELL");
   Print("Entry: ", signal.entry);
   Print("Stop: ", signal.stop);
   Print("Target: ", signal.target);
   Print("Volume: ", volume);

   if (EnableTrading && volume > 0)
   {
      bool result = false;

      if (signal.direction == SIGNAL_BUY)
      {
         result = trade.Buy(volume, _Symbol, signal.entry, signal.stop, signal.target,
                            signal.strategy);
      }
      else
      {
         result = trade.Sell(volume, _Symbol, signal.entry, signal.stop, signal.target,
                             signal.strategy);
      }

      if (result)
      {
         Print("✅ ORDEM EXECUTADA COM SUCESSO");
      }
      else
      {
         Print("❌ ERRO NA EXECUÇÃO: ", trade.ResultRetcode());
      }
   }
   else
   {
      Print("📊 MODO DEMO - Ordem não enviada");
   }
   Print("=======================");
}

//+------------------------------------------------------------------+
//| Calcula volume baseado no risco definido                        |
//+------------------------------------------------------------------+
double CalculateVolume(const Signal &signal)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double stopPoints = MathAbs(signal.entry - signal.stop) / tickSize;

   if (stopPoints <= 0 || tickValue <= 0)
      return 0;

   double volume = riskAmount / (stopPoints * tickValue);

   // Normalizar volume
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   volume = MathMax(volume, minVol);
   volume = MathMin(volume, maxVol);
   volume = MathFloor(volume / stepVol) * stepVol;

   return volume;
}

//+------------------------------------------------------------------+
//| Imprime detalhes dos padrões detectados                        |
//+------------------------------------------------------------------+
void PrintPatternDetails(const SimpleAlBrooksData &data)
{
   if (data.spikeDetected)
      Print("  ✓ Spike detectado");
   if (data.trendFromOpenDetected)
      Print("  ✓ Trend from Open detectado");
   if (data.smallPullbackDetected)
      Print("  ✓ Small Pullback detectado");
}

//+------------------------------------------------------------------+
//| FUNÇÕES AUXILIARES SIMPLES                                      |
//+------------------------------------------------------------------+

// Função simplificada para ATR
double iATR(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iATR(symbol, tf, period);
   if (handle == INVALID_HANDLE)
      return 0;

   double buffer[1];
   if (CopyBuffer(handle, 0, shift, 1, buffer) == 1)
   {
      IndicatorRelease(handle);
      return buffer[0];
   }

   IndicatorRelease(handle);
   return 0;
}

//+------------------------------------------------------------------+
//| Determina estratégia primária baseada nos padrões detectados   |
//+------------------------------------------------------------------+
string GetPrimaryStrategy(const SimpleAlBrooksData &data) {
   if (data.spikeDetected) {
      return "Spike";
   } else if (data.trendFromOpenDetected) {
      return "TrendFromOpen";
   } else if (data.smallPullbackDetected) {
      return "SmallPullback";
   } else {
      return "AlBrooks";
   }
}

//+------------------------------------------------------------------+
//| Função para limpar todas as setas (pode ser chamada manualmente)|
//+------------------------------------------------------------------+
void ClearAllArrows() {
   ClearAllAlBrooksArrows();
   Print("Comando executado: Todas as setas removidas");
}

//+------------------------------------------------------------------+
//| EXEMPLO DE USO EM FUNÇÃO DE TECLADO (OPCIONAL)                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
   // Exemplo: Pressionar 'C' para limpar setas
   if (id == CHARTEVENT_KEYDOWN) {
      if (lparam == 67) { // Tecla 'C'
         ClearAllArrows();
      }
   }
}