#property copyright "Xiangliang Meng"
#property link      "https://www.facebook.com/xiangliang.meng"
#property strict

string VERSION = "20140324";
extern double MA365_DIFF = 0.3;
extern double PROFIT_PIPS=0.5;
extern double MA30_60_DIFF = 0.3;

extern double LOTS = 0.1;
extern bool ENABLE_SIGN = true;
extern bool ENABLE_AUTO_SCALE_LOTS=true;
extern bool ENABLE_LOSTCUT=false;
extern bool ENABLE_DEBUG=false;

int ticket1 = -1,ticket2 = -1,ticket3=-1,ticket4=-1;
datetime last_ticket1_open_time=-1,last_ticket2_open_time = -1;

int current_bar;

double rsi,atr,ma365,ma60,ma30,ac0,ac1,ac2;
bool ac_plus_top=false, ac_minus_bottom=false, ac_minus_heavy=false, ac_plus_heavy=false;

double last_ticket1_win_pips = 0, last_ticket1_open_price=0;
double last_ticket2_profit_pips=0, last_ticket2_open_price=0;
double last_ticket3_open_price=0;
double last_ticket4_open_price=0;

void check_order_point(){
   bool ticket1_entry1=rsi<=15 && ma60<ma365 && ma365-Ask >= MA365_DIFF && (atr>=0.08 || rsi<=6);
   bool ticket1_entry2=ma30<ma365 && get_lowest_rsi(3,5)<=10 && ac_minus_bottom && atr>=0.08;
   bool ticket1_entry3=ac_minus_bottom && last_ticket1_win_pips>=0.08 && Ask-last_ticket1_open_price<=0.05 && (rsi<=10||Ask-last_ticket1_open_price<=-0.05) && TimeCurrent()-last_ticket1_open_time<=60*60*8;
   bool ticket1_entry4=rsi<3 && atr>=0.3;
   if(
      ticket1==-1 && (
      (
         MathMax(ma365,MathMax(ma60,ma30))-Ask>=0.8 && 
         ma30-Ask>=0.2 && MathAbs(ma30-ma60)>=MA30_60_DIFF &&
         (ticket1_entry1 || ticket1_entry2 || ticket1_entry3 || ticket1_entry4)
      ) ||
      (
         last_ticket1_win_pips >=0.1 && Ask <= last_ticket1_open_price && TimeCurrent()-last_ticket1_open_time<=3*3600
      )      
      )
   ){
      while(true){
         ticket1 = force_order(OP_BUY,LOTS,Ask,"t1");
         if(ticket1!=-1)break;
      }
      last_ticket1_open_price=Ask;
      last_ticket1_open_time=TimeCurrent();
      show_arrow(Ask, true, TimeCurrent(), Yellow,NULL,140);
   }else{
      if(ENABLE_DEBUG){
         if(ticket1_entry1 && ObjectFind(0,"t1e1_"+IntegerToString(current_bar))==-1)_sign("t1e1_"+IntegerToString(current_bar),Ask,140,Pink);
         if(ticket1_entry2 && ObjectFind(0,"t1e2_"+IntegerToString(current_bar))==-1)_sign("t1e2_"+IntegerToString(current_bar),Ask,141,Pink);
         if(ticket1_entry3 && ObjectFind(0,"t1e3_"+IntegerToString(current_bar))==-1)_sign("t1e3_"+IntegerToString(current_bar),Ask,142,Pink);
         if(ticket1_entry4 && ObjectFind(0,"t1e4_"+IntegerToString(current_bar))==-1)_sign("t1e4_"+IntegerToString(current_bar),Ask,143,Pink);
      }
   }
   if(ticket2==-1 && ticket1!=-1 &&
      TimeCurrent()-last_ticket2_open_time>=3*60 &&
      ma60 <= ma365 &&
      ma365 - Ask >= MA365_DIFF &&
      OrderSelect(ticket1,SELECT_BY_TICKET)
   ){
      double ticket1_lostpips = OrderOpenPrice() - Ask;
      bool ticket2_pass = (ticket1_lostpips>=0.2 && (ac_minus_bottom||ac_minus_heavy));
      if(ticket2_pass){
         while(true){
            ticket2 = force_order(OP_BUY,LOTS,Ask,"t2");
            last_ticket2_open_price=Ask;
            if(ticket2!=-1)break;
         }
         show_arrow(Ask, true, TimeCurrent(), Red,NULL,141);
         last_ticket2_open_time = TimeCurrent();
      }
   }
   if(ticket1!=-1 && ticket2!=-1 && ticket3==-1 && (last_ticket2_open_price-Ask>=0.5 ||last_ticket1_open_price-Ask>=1) && (ticket1_entry1 || ticket1_entry2 || ticket1_entry3 || ticket1_entry4)){
      while(true){
         ticket3=force_order(OP_BUY,LOTS,Ask,"t3");
         last_ticket3_open_price = Ask;
         if(ticket3!=-1)break;
      }
      show_arrow(Ask, true, TimeCurrent(), Pink,NULL,142);
   }
   if(ticket3!=-1 && ticket4==-1 && (ac_minus_heavy||ticket1_entry1) && get_lowest_rsi(3,3)<=5 &&
      ( (last_ticket3_open_price-Ask>=0.8 && ac_minus_bottom && rsi<=5) ||
         (Ask<=last_ticket4_open_price)
      )
   ){
      while(true){
         ticket4=force_order(OP_BUY,LOTS,Ask,"t4");
         last_ticket4_open_price=Ask;
         if(ticket4!=-1)break;
      }
      show_arrow(Ask, true, TimeCurrent(),Green,NULL,143);
   }
}

void _close_ticket1(double lots,double profit_pips){
    force_close(ticket1,lots,Bid);
    ticket1=-1;
    last_ticket2_profit_pips=0;
    last_ticket1_win_pips=profit_pips;
}

void check_close_point(){
   int timediff;
   double diff_pips,target_ma,ask_minweight,target_profitpips;
   bool is_over10min,is_over30min,is_over60min,is_over48hour,is_over5day;

   if(ticket1!=-1 && OrderSelect(ticket1,SELECT_BY_TICKET)){
      timediff = (int)(TimeCurrent()-last_ticket1_open_time);
      diff_pips = Bid - OrderOpenPrice();
      is_over10min = timediff>=10*60;
      is_over30min = timediff>=30*60;
      is_over60min = timediff>=60*60;
      is_over48hour = timediff>=60*60*48;
      is_over5day = timediff>=60*60*24*5;
      if(get_net_profit() >= 0){
         target_ma = !is_over10min ? ma365 : (ac2>ac1?ma60:ma30);
         ask_minweight = is_over60min ? 0.05 : 0;
         if(ma30>ma365){
            target_ma = ma30;
            if(is_over10min)target_ma = ma365;
         }
         if( Bid-ask_minweight >= target_ma ||
            ( ma60<ma365 && ac_plus_top && (diff_pips >= 0.2 || (diff_pips >= 0.1 && ma30 - Bid < 0.1) || ( diff_pips>=0.1 && ac1>=0.04) )) ||
            (ma30-Bid<=0.1 && diff_pips>=0.1 && rsi>=90) ||
            (diff_pips>=0.4 && ac_plus_top)
         ){
            _close_ticket1(OrderLots(),diff_pips);
         }
      }else if(ENABLE_LOSTCUT && is_over60min && last_ticket2_profit_pips>0 && diff_pips+last_ticket2_profit_pips>=0){
         _close_ticket1(OrderLots(),diff_pips);
      }
   }

   if(ticket2!=-1 && OrderSelect(ticket2,SELECT_BY_TICKET) && get_net_profit()>=0){
      timediff = (int)(TimeCurrent()-last_ticket2_open_time);
      diff_pips = Bid - OrderOpenPrice();
      is_over10min = timediff>=10*60;
      is_over30min = timediff>=30*60;
      is_over60min = timediff>=60*60;
      is_over48hour = timediff>=60*60*48;
      is_over5day = timediff>=60*60*24*5;
      target_ma = !is_over10min ? ma365 : (ac2>ac1?ma60:ma30);
      ask_minweight = is_over60min ? 0.05 : 0;
      target_profitpips = PROFIT_PIPS;
      if(Ask-ask_minweight >= target_ma || diff_pips >= target_profitpips || rsi >= 90 || (diff_pips >= 0.1 && ac_plus_top && ac_plus_heavy)){
         force_close(ticket2,OrderLots(),Bid);
         ticket2=-1;
         last_ticket2_profit_pips += diff_pips;
         if(ENABLE_LOSTCUT && ticket1!=-1 && Bid>=ma60 && diff_pips<=0.05 && OrderSelect(ticket1,SELECT_BY_TICKET) && Bid - OrderOpenPrice()<=0.1){
            _close_ticket1(OrderLots(),Bid - OrderOpenPrice());
         }
         if(ticket3!=-1 && OrderSelect(ticket3,SELECT_BY_TICKET)){
            force_close(ticket3,OrderLots(),Bid);
            ticket3=-1;
         }
      }
   }
   if(ticket3!=-1 && Ask-ma30<=0.1 && OrderSelect(ticket3,SELECT_BY_TICKET) && get_net_profit()>=0 ){
      diff_pips = Bid - OrderOpenPrice();
      if((diff_pips >= 0.3 && ac_plus_top) || Bid>=ma30){
         force_close(ticket3,OrderLots(),Bid);
         ticket3=-1;
         if(ticket2!=-1 && OrderSelect(ticket2,SELECT_BY_TICKET) && get_net_profit()<0){
            double diff_pips2 = OrderOpenPrice()-Bid;
            if(diff_pips2<=diff_pips){
               force_close(ticket2,OrderLots(),Bid);
               ticket2=-1;
               last_ticket2_profit_pips += -1*diff_pips2;
            }
         }
      }
   }
   
   if(ticket4!=-1 && OrderSelect(ticket4,SELECT_BY_TICKET) && get_net_profit()>0 && (Bid>=ma30 || (OrderOpenPrice()-Bid>=0.2 && ac_plus_top))){
      force_close(ticket4,OrderLots(),Bid);
      ticket4=-1;
   }
}

int init(){
   ObjectsDeleteAll();
   current_bar = Bars;
   init_accountbalance = AccountBalance();
   init_lots = LOTS;
   MathSrand((int)TimeLocal());
   read_exists();
   print_lots();
   return(0);
}
void print_lots(){
   Comment("VER: ", VERSION ,"\nLOTS ", DoubleToStr(LOTS,1),"\nticket1 ",ticket1,"\nticket2 ",ticket2,"\nticket3 ",ticket3,"\nticket4 ",ticket4,"\nlast_ticket1_open_price ",last_ticket1_open_price,"\nlast_ticket2_open_price ",last_ticket2_open_price,"\nlast_ticket3_open_price ",last_ticket3_open_price,"\nlast_ticket4_open_price ",last_ticket4_open_price);
}
void read_exists(){
   double OLD_LOTS=LOTS;
   for(int i=0;i<OrdersTotal();i++){
      if(OrderSelect(i,SELECT_BY_POS) && OrderCloseTime()==0){
         string comment = OrderComment();
         if(ticket1==-1 && comment=="t1"){
            Print("find ticket1! ");
            ticket1=OrderTicket();
            LOTS=OrderLots();
            last_ticket1_open_price = OrderOpenPrice();
            last_ticket1_open_time = OrderOpenTime();
            show_arrow(OrderOpenPrice(), true, OrderOpenTime(), Yellow,NULL,140);
         }
         if(ticket2==-1 && comment=="t2"){
            Print("find ticket2! ");
            ticket2=OrderTicket();
            LOTS=OrderLots();
            last_ticket2_open_price = OrderOpenPrice();
            last_ticket2_open_time = OrderOpenTime();
            show_arrow(OrderOpenPrice(), true, OrderOpenTime(), Red,NULL,141);
         }
         if(ticket3==-1 && comment=="t3"){
            Print("find ticket3! ");
            ticket3=OrderTicket();
            LOTS=OrderLots();
            last_ticket3_open_price = OrderOpenPrice();
            show_arrow(OrderOpenPrice(), true, OrderOpenTime(), Pink,NULL,142);
         }
         if(ticket4==-1 && comment=="t4"){
            Print("find ticket4! ");
            ticket4=OrderTicket();
            LOTS=OrderLots();
            last_ticket4_open_price = OrderOpenPrice();
            show_arrow(OrderOpenPrice(), true, OrderOpenTime(), Green,NULL,143);
         }
      }
   }
   if(OLD_LOTS!=LOTS)print_lots();
}
int deinit(){return(0);}
void get_data(){
   current_bar = Bars;
   rsi=get_rsi(3);
   atr=get_atr(3);
   ma365 = get_ma(365); ma60 = get_ma(60); ma30 = get_ma(30);
   ac2 = iAC(NULL,0,0); ac1 = iAC(NULL,0,1); ac0 = iAC(NULL,0,2);
   ac_plus_top=ac2>0&&ac1>0&&ac0>0&&ac2<ac1&&ac1>ac0&&ac1>=0.03;
   ac_minus_bottom=ac2<0&&ac1<0&&ac0<0&&ac2>ac1&&ac1<ac0&&ac1<=-0.03;
   ac_minus_heavy=ac2<0&&ac1<0&&ac0<0&&ac2<=-0.05;
   ac_plus_heavy=ac2>0&&ac1>0&&ac0>0&&ac2>=0.05;
}

double init_accountbalance = 0,init_lots = 0;
void change_lots(){
   double ab = AccountBalance();
   if(!ENABLE_AUTO_SCALE_LOTS || ab <= 0 || ticket1!=-1 || ticket2!=-1)return;
   double ratio = NormalizeDouble(ab / init_accountbalance * init_lots,1);
   LOTS=ratio;
}

int start(){
   read_exists();
   get_data();
   change_lots();
   check_order_point();
   check_close_point();
   print_lots();
   return(0);
}
//===================================== Utils ================================================
double get_ma(int time=60,int delay=0){return(iMA(NULL,0,time,delay,MODE_SMMA,PRICE_CLOSE,0));}
double get_atr(int val=14, int shift=0){return(iATR(NULL,0,val,shift));}
double get_rsi(int val=14, int shift=0){return(iRSI(NULL,0,val,PRICE_LOW,shift));}

double get_highest_atr(int val=14,int shift_count=1){
   double rtn = get_atr(val);
   for(int i=1;i<shift_count;i++){
      double _val = get_atr(val,i);
      if(_val>rtn)rtn=_val;
   }
   return(rtn);
}
double get_lowest_rsi(int val=14,int shift_count=1){
   double rtn = get_rsi(val);
   for(int i=1;i<shift_count;i++){
      double _val = get_rsi(val,i);
      if(_val<rtn)rtn=_val;
   }
   return(rtn);
}

void show_arrow(double price,bool is_up,datetime dt,color clr=Blue,string add_txt = "",int signcode=0){
   if(!ENABLE_SIGN)return;
   string oid = "a."+DoubleToStr(MathRand())+"."+TimeToStr(TimeCurrent());
   ObjectCreate(oid, OBJ_ARROW, 0, dt, price);
   ObjectSet(oid,OBJPROP_ARROWCODE, signcode==0?(is_up?233:234):signcode);
   ObjectSet(oid,OBJPROP_COLOR, clr);
   ObjectCreate(oid+"_t", OBJ_TEXT, 0,dt,price+0.05);
   ObjectSetText(oid+"_t", DoubleToStr(price,3)+" "+add_txt, 10, "Times New Roman", clr);
}
int SPD=3;
int force_order(int order_type,double order_volumn, double price,string comment=""){
   return OrderSend(Symbol(), order_type, order_volumn, price, SPD, 0, 0, comment, 0, 0, (ENABLE_SIGN?CLR_NONE:(order_type == OP_BUY?Red:Yellow)));
}
bool force_close(int ticket, double order_lots, double price){
   bool succ = OrderClose(ticket, order_lots, price, SPD, CLR_NONE);
   if(!succ && OrderSelect(ticket,SELECT_BY_TICKET) && OrderCloseTime()>0)return(true);
   return(succ);
}

void _sign(string oid,double price,int code, color clr){
   ObjectCreate(oid, OBJ_ARROW, 0, TimeCurrent(), price);
   ObjectSet(oid,OBJPROP_ARROWCODE, code);
   ObjectSet(oid,OBJPROP_COLOR, clr);
}

void logfile(string cnt){
   int fh = FileOpen("log.txt",FILE_TXT|FILE_READ|FILE_WRITE);
   if(fh!=INVALID_HANDLE){
      FileWrite(fh,TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS),cnt);
      FileClose(fh);
   }
}
double get_net_profit(){
   return OrderProfit()+OrderCommission()+OrderSwap();
}
