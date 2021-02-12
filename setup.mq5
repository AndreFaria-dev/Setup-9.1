//+------------------------------------------------------------------+
//|                                                 AutoProfit       |
//|                             Copyright 2021, Julio André C. Faria |
//|                              Setup Baseado no Larry Williams 9.3 |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>





/*
Julio André
*/

//Guardar os dados (abertura, maxima, minima e fechamento) dos candles dentro de um array para o robô enxergar tendência
//Atualizar arrays cada nova vela

input bool trailling_stop; //Trailling Stop
input int retorno = 1;   //Retorno x risco (Trailling Stop deve estar desabilitado)
input int velas=1; //Ajustar o stop a cada vela passada
input int lote=1; //Numero de ativos (minimo 100 para ações e 1 para contratos futuros)
input int hora_abertura = 09; //Hora de abertura 
input int minuto_abertura = 30; //Minuto de abertura
input int hora_encerramento = 16;//Hora de encerramento
input int minuto_encerramento = 00; //Minuto de encerramento

//Horario de negociação

const int periodo = 9;//Período da média movel

//Manipuladores
int mmeHandle = INVALID_HANDLE;

double mmexponencial[];//Array para passar os dados da média móvel

//Struct para captar dados de candles

struct Candle
  {
   double            open[10],high[10],low[10],close[10];     
   bool              touro;     
   double            tamanho_corpo; //Body size
   
  };
Candle vela; //declaração da variavel
CTrade meutrade; //Criando um objeto para realizar ordens



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()//Inicialização do algoritmo
  {

   ArraySetAsSeries(mmexponencial,true);
   int deslocamentoMedia=0;

//atribuir para a manipulação da média movel
   mmeHandle = iMA(_Symbol,_Period,periodo,deslocamentoMedia,MODE_EMA,PRICE_CLOSE);




   return(INIT_SUCCEEDED);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()//Executa essa função em cada atualização do preço
  {
   if(novaBarra()) //Executar ordens apenas quando aparece um novo candle
     {

      //Obtenção dos dados

      int candles = 10; //Quantidade de velas para ler uma tendência

      int copied = CopyBuffer(mmeHandle,0,0,candles,mmexponencial);

      double stopCorrente = PositionGetDouble(POSITION_SL);
      ulong PositionTicket= PositionGetInteger(POSITION_TICKET);

      //Verificar posição
      bool comprado = false;
      bool vendido = false;

      //Inicialização
      bool sinalCompra = false;
      bool sinalVenda = false;

      //Verificar posição aberta
      if(PositionSelect(_Symbol))
        {
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            comprado = true;
           }
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            vendido = true;
           }
        }


      //printf("\nDEPURAÇÃO\nComprado: %d \nVendido: %d \nMédia Móvel: %f\nStopCorrente: %d\n",comprado,vendido,mmexponencial[1],stopCorrente);
      //Print(PositionTicket);
      if(horarioNegociacao())
        {
         int touros=0; //Contar velas acima da media movel
         double alvo;
         

         if(copied==candles)
           {
               
               
               for(int i=1; i<10; i++){
               
                  vela.open[i]   =  iOpen(_Symbol,_Period,i);
                  vela.close[i]  =  iClose(_Symbol,_Period,i);
                  vela.high[i]   =  iHigh(_Symbol,_Period,i);
                  vela.low[i] =  iLow(_Symbol,_Period,i);
                  
              
                  if(vela.open[i] > mmexponencial[i]){   touros+=1;   }
                  
               }
            
               if(touros <= 2){
                  Print("Baixa");
               }
               else if(touros >= 8){
                  Print("Alta");
               }
               else{
                  Print("Mercado lateral");
               }
               
               
           }


         if(!comprado && !vendido) //Posição deve estar zerada
           {
            if(gatilhoCompra(touros))
              {
                  //Disparar ordem de compra
                  stopCorrente = vela.low[velas]; 
                  alvo = vela.close[1] + ((stopCorrente - iClose(_Symbol,_Period,velas)*retorno));

                  meutrade.Buy(1,_Symbol,0,stopCorrente,alvo);

              }
            if(gatilhoVenda(touros))
              {
                  //Dispara ordem de venda
                  
                  stopCorrente = vela.high[velas];
                  alvo = vela.close[1] - ((stopCorrente - iClose(_Symbol,_Period,velas)*retorno));
                  
                  meutrade.Sell(1,_Symbol,0,stopCorrente,alvo);
                  
              }
           }
         else
            if(comprado)
              {
                  //Ajustar o stop

                  stopCorrente = vela.low[velas]; 
                  if(trailling_stop){ alvo = 0;  meutrade.PositionModify(_Symbol,stopCorrente,alvo);   }
                  Print(stopCorrente," Alvo: ",alvo);
              }
            else
               if(vendido)
                 {
                  //Ajustar o stop

                  stopCorrente = vela.high[velas];
                  if(trailling_stop){ alvo = 0; meutrade.PositionModify(_Symbol,stopCorrente,alvo);   }
                  Print(stopCorrente," Alvo: ",alvo);
                 }

        }
      else
        {

         if(comprado)
           {
            meutrade.Sell(1,_Symbol,0,0,0,"Venda zerar posição");
           }
         if(vendido)
           {
            meutrade.Buy(1,_Symbol,0,0,0,"Compra zerar posição");
           }
        }
     }
  }



   
   //Funcionalidade: Identificar horário de operação
   bool horarioNegociacao()
     {
      bool condicao = false;
   
      MqlDateTime mqldt;
      TimeCurrent(mqldt);
   
      int hora = mqldt.hour;
      int minuto = mqldt.min;
   
   //Zeragem compulsória pelo robô
      if(hora >= hora_abertura && minuto >=minuto_abertura)
         if(hora <= hora_encerramento && minuto >=minuto_encerramento)
            condicao = true;
   
      return condicao;
     }
   
   
   
   //+------------------------------------------------------------------+
   //|  Gatilhos de entrada 9.3                                         |
   //+------------------------------------------------------------------+
   bool gatilhoCompra(int touros)
     {
         bool sinal = false;

         //Dados das velas devem estar capturados
   
         if(touros <= velas)   //As velas anteriores devem fechar abaixo da média móvel
            if((vela.close[1] > mmexponencial[1]) && (vela.close[1] > vela.open[1]) )//Ultimas velas devem ser de alta e romper a média movel
                  if(vela.close[2] < vela.open[2])//Penultima vela deve ser de baixa para cumprir a regra do setup
                     { sinal = true; }
                     
         return sinal;
      }
      
   
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   bool gatilhoVenda(int touros)
     {
      
         bool sinal = false;
         
         //Dados das velas devem estar capturados
         
         if(touros >= velas)   //As velas anteriores devem fechar acima da média móvel(touro)
            if((vela.close[1] < mmexponencial[1]) && (vela.close[1] < vela.open[1]) )//Ultimas velas devem ser de baixa e romper a média movel
                  if(vela.close[2] > vela.open[2])//Penultima vela deve ser de alta para cumprir a regra do setup
                     { sinal = true;  }
                     
                         
      return sinal;
     }
   
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   bool novaBarra()
     {
   //--- memorize the time of opening of the last bar in the static variable
      static datetime last_time=0;
   //--- current time
      datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   
   //--- if it is the first call of the function
      if(last_time==0)
        {
         //--- set the time and exit
         last_time=lastbar_time;
         return(false);
        }
   
   //--- if the time differs
      if(last_time!=lastbar_time)
        {
         //--- memorize the time and return true
         last_time=lastbar_time;
         return(true);
        }
   //--- if we passed to this line, then the bar is not new; return false
      return(false);
     }
   //+------------------------------------------------------------------+
