//+------------------------------------------------------------------+
//| RX_02_BANSHEE_RAPIDFIRE                                         |
//| EA Base demonstrando detecção de tendências Al Brooks           |
//+------------------------------------------------------------------+
#property copyright "RX_02_BANSHEE_RAPIDFIRE"
#property version "1.00"
#property strict

#include <Trade/Trade.mqh>
#include "graph/graph_utils.mqh"
#include "utils.mqh"

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
   SETUP_QUALITY quality;
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
      data.quality = SETUP_C;

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
      data.quality = DetermineQuality(data);

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
      const int atrPeriod = 20;
      const double minBodyRatio = 0.6;
      const double closePct = 0.2; // fechar no extremo

      bool upSpike = true, downSpike = true;

      for (int i = 1; i <= bars; i++)
      {
         double open = iOpen(symbol, tf, i);
         double close = iClose(symbol, tf, i);
         double high = iHigh(symbol, tf, i);
         double low = iLow(symbol, tf, i);
         double range = high - low;

         double atr = GetATR(symbol, tf, atrPeriod, i);
         if (range <= 0 || atr <= 0)
            return false;

         double body = MathAbs(close - open);

         bool strongUp = close > open && body >= range * minBodyRatio && range > atr * 1.5 && close >= high - range * closePct;
         bool strongDown = close < open && body >= range * minBodyRatio && range > atr * 1.5 && close <= low + range * closePct;

         if (!strongUp)
            upSpike = false;
         if (!strongDown)
            downSpike = false;
      }

      // permitir spike de uma barra seguida por continuidade
      if (!upSpike && !downSpike)
      {
         double open1 = iOpen(symbol, tf, 1);
         double close1 = iClose(symbol, tf, 1);
         double high1 = iHigh(symbol, tf, 1);
         double low1 = iLow(symbol, tf, 1);
         double range1 = high1 - low1;
         double atr1 = GetATR(symbol, tf, atrPeriod, 1);
         double body1 = MathAbs(close1 - open1);
         bool strongUp1 = close1 > open1 && body1 >= range1 * minBodyRatio && range1 > atr1 * 1.5 && close1 >= high1 - range1 * closePct;
         bool strongDown1 = close1 < open1 && body1 >= range1 * minBodyRatio && range1 > atr1 * 1.5 && close1 <= low1 + range1 * closePct;

         if (strongUp1)
         {
            bool cont = true;
            for (int i = 2; i <= bars; i++)
            {
               if (iClose(symbol, tf, i) <= iClose(symbol, tf, i - 1))
               {
                  cont = false; break;
               }
            }
            if (cont)
               upSpike = true;
         }
         if (strongDown1)
         {
            bool cont = true;
            for (int i = 2; i <= bars; i++)
            {
               if (iClose(symbol, tf, i) >= iClose(symbol, tf, i - 1))
               {
                  cont = false; break;
               }
            }
            if (cont)
               downSpike = true;
         }
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
      datetime dayStart = iTime(symbol, PERIOD_D1, 0);
      int dayStartBar = iBarShift(symbol, tf, dayStart);

      if (dayStartBar <= 0)
         return false;

      const int checkBars = 10; // analisar apenas início do dia
      double openPrice = iOpen(symbol, tf, dayStartBar);
      bool isUpMove = iClose(symbol, tf, dayStartBar - 1) > openPrice;

      int strongCount = 0;
      double highSinceOpen = openPrice;
      double lowSinceOpen = openPrice;

      for (int i = dayStartBar - 1; i >= MathMax(dayStartBar - checkBars, 0); i--)
      {
         double open = iOpen(symbol, tf, i);
         double close = iClose(symbol, tf, i);
         double high = iHigh(symbol, tf, i);
         double low = iLow(symbol, tf, i);
         double range = high - low;
         double atr = GetATR(symbol, tf, 20, i);
         if (atr <= 0 || range <= 0)
            break;

         bool strongUp = close > open && close >= high - range * 0.2 && range > atr * 1.2;
         bool strongDown = close < open && close <= low + range * 0.2 && range > atr * 1.2;

         if ((isUpMove && strongUp) || (!isUpMove && strongDown))
            strongCount++;
         else
            break;

         highSinceOpen = MathMax(highSinceOpen, high);
         lowSinceOpen = MathMin(lowSinceOpen, low);
      }

      if (strongCount < m_trendFromOpenMin)
         return false;

      double totalMove = MathAbs((isUpMove ? highSinceOpen : lowSinceOpen) - openPrice);
      double current = iClose(symbol, tf, 0);
      double pullback = MathAbs(current - (isUpMove ? highSinceOpen : lowSinceOpen));

      if (totalMove <= 0)
         return false;

      if (pullback / totalMove > 0.4)
         return false;

      isUp = isUpMove;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Detecta Small Pullback - poucos e pequenos pullbacks           |
   //+------------------------------------------------------------------+
   bool DetectSmallPullback(const string symbol, ENUM_TIMEFRAMES tf, bool &isUp)
   {
      const int analyzeBars = 15;
      int consecutivePull = 0;

      bool isUpTrend = iClose(symbol, tf, 0) > iClose(symbol, tf, analyzeBars);
      double highest = iHigh(symbol, tf, analyzeBars);
      double lowest = iLow(symbol, tf, analyzeBars);

      for (int i = analyzeBars; i >= 0; i--)
      {
         double close = iClose(symbol, tf, i);
         double ema = GetEMA(symbol, tf, 20, i);
         highest = MathMax(highest, iHigh(symbol, tf, i));
         lowest = MathMin(lowest, iLow(symbol, tf, i));

         if (isUpTrend)
         {
            if (close < ema)
               consecutivePull++;
            else
               consecutivePull = 0;
         }
         else
         {
            if (close > ema)
               consecutivePull++;
            else
               consecutivePull = 0;
         }

         if (consecutivePull > 2)
            return false;
      }

      double leg = MathAbs(iClose(symbol, tf, 0) - (isUpTrend ? lowest : highest));
      double pullDepth = MathAbs(iClose(symbol, tf, 0) - (isUpTrend ? highest : lowest));

      if (leg <= 0 || pullDepth / leg > 0.4)
         return false;

      isUp = isUpTrend;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Calcula confiança baseada nos padrões detectados               |
   //+------------------------------------------------------------------+
   double CalculateConfidence(const SimpleAlBrooksData &data)
   {
      SETUP_QUALITY q = DetermineQuality(data);
      switch(q)
      {
         case SETUP_A_PLUS: return 90.0;
         case SETUP_A:      return 75.0;
         case SETUP_B:      return 55.0;
         default:           return 40.0;
      }
   }

   //+------------------------------------------------------------------+
   //| Determina qualidade do setup                                    |
   //+------------------------------------------------------------------+
   SETUP_QUALITY DetermineQuality(const SimpleAlBrooksData &data)
   {
      if (data.spikeDetected && data.trendFromOpenDetected && data.smallPullbackDetected)
         return SETUP_A_PLUS;
      if ((data.spikeDetected && data.trendFromOpenDetected) ||
          (data.trendFromOpenDetected && data.smallPullbackDetected) ||
          (data.spikeDetected && data.smallPullbackDetected))
         return SETUP_A;
      if (data.spikeDetected || data.trendFromOpenDetected || data.smallPullbackDetected)
         return SETUP_B;
      return SETUP_C;
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

      string qualityText;
      switch(data.quality)
      {
         case SETUP_A_PLUS: qualityText = "A+"; break;
         case SETUP_A:      qualityText = "A";  break;
         case SETUP_B:      qualityText = "B";  break;
         default:           qualityText = "C";  break;
      }

      return StringFormat("%s: %s[%s]", dir, patterns, qualityText);
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

   ManagePositions();
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
      sig.strategy = "AlBrooks_Spike";
   else if (data.trendFromOpenDetected)
      sig.strategy = "AlBrooks_TrendFromOpen";
   else if (data.smallPullbackDetected)
      sig.strategy = "AlBrooks_SmallPullback";
   else
      sig.strategy = "AlBrooks";

   sig.quality = data.quality;

   const int lookback = 20;
   double buffer = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   if (sig.direction == SIGNAL_BUY)
   {
      double swing = GetRecentSwingLow(_Symbol, _Period, lookback);
      sig.stop = swing - buffer;
   }
   else
   {
      double swing = GetRecentSwingHigh(_Symbol, _Period, lookback);
      sig.stop = swing + buffer;
   }

   double risk = MathAbs(sig.entry - sig.stop);
   sig.target = sig.entry + (sig.direction == SIGNAL_BUY ? risk : -risk) * 2.0;


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
//| Gerencia posições abertas com trailing simples                  |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(PositionGetTicket(i)==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

      ulong ticket=PositionGetTicket(i);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double stop=PositionGetDouble(POSITION_SL);
      double take=PositionGetDouble(POSITION_TP);
      int type=PositionGetInteger(POSITION_TYPE);

      double price=(type==POSITION_TYPE_BUY)?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double risk=MathAbs(open-stop);
      if(risk<=0) continue;

      bool move=false;
      if(type==POSITION_TYPE_BUY && price-open>=risk && stop<open)
         move=true;
      if(type==POSITION_TYPE_SELL && open-price>=risk && stop>open)
         move=true;

      if(move)
         trade.PositionModify(ticket,open,take);
   }
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