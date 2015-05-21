



// Module     : mb_bench                                                                                     //
// Description: This is the top level stimulus module of the TAEC FPGA. 
//              It  instatiates dac_board                                                             //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`include "..\include\timescale.v"
`include "..\include\defines.v"

//-----------------------------------------------------------------------
module mb_bench;

//I/O ports
reg [7:0] addr ;                 // muxed address data
reg [1:0] mod_sel_in ;
reg cs ;
reg clk1;
reg clk2;
reg reset_n ;
reg ale ;
reg [15:0] ad_data ;
reg ad_sdi ;
reg [2:0] brd_id;
reg [19:0] ht;
reg sw_in ;

wire [19:0] hv_enable_n;         
wire  dsync_n ;
wire [11:0] dout ;
          
integer i;

// ---------------------------------------------------------------------------------
//Instantiate taec_top
taec_top taec_top1(
    .ADDR                            (addr), 
    .CS                                 (cs),
    .MOD_SEL_IN               (mod_sel_in), 
    .CLK1                             (clk1),
    .RESET_N                     (reset_n),
    .ALE                               (ale),
    .AD_SDI                         (ad_sdi),
    .BRD_ID                         (brd_id),
    .HT                                 (ht),
    .SWin                              (sw_in),
    //
    .DOUT                            (dout),
    .HV_EN_N                     (hv_enable_n),
    .HVON_N                       (hv_psuen), 
    .HV_DAC_SYNC_N      (hv_sync_n),
    .HV_DAC_SCLK            (hv_sclk),
    .HV_DAC_DIN               (hv_sdin),
    .THRH_DAC_SYNC_N    (thrh_sync_n),
    .THRH_DAC_SCLK         (thrh_sclk),
    .THRH_DAC_DIN             (thrh_sdin),
    .BIAS_DAC_SYNC_N      (bias_sync_n),
    .BIAS_DAC_SCLK            (bias_sclk),
    .BIAS_DAC_DIN               (bias_sdin),
    .AD_CONV_N                 (ad_conv_n1),
    .AD_SCLK                       (ad_sclk1 ),
    .D2                                   (D2_1),
    .D3                                   (D3_1),
    .D4                                   (D4_1),
    .HI_GAIN_N                    (hi_gain_n)
     ) ;

// ---------------------------------------------------------------------------------


always begin
     #3 clk1 = !clk1 ;
       assign ad_sdi = ad_data[15] ;           // ad_data & 1'b1 ;
end


always @ ( posedge clk1)
     begin
        clk2 <= ~clk2 ;
     end

always @ (posedge ad_sclk)
      begin
        ad_data <= (ad_data << 1) ;
      end
 
initial begin
       `ifdef Veritak
               $dumpvars;
       `endif

       ad_data = 16'b1101110110001101;

       addr =  8'b00000000 ;
       ale = 0 ;
       brd_id =  3'b010;
       clk1 = 0;
       clk2 = 0;
       reset_n = 0;

       #20 ht = 20'b00000000000000000000 ;
       #50 ht = 20'b00000000010000000000 ;
       #50 ht =  20'b00000000000000000000 ;

       #50 reset_n = 1'b1 ;
       #20 cs = 1'b0;                                  // de-select

  //-------------------------------------------------------------------------------------------
  //-------------------------------------------------------------------------------------------
       // turn OFF HV psu (HV switches disabled with reset_n @ power on

       #50  sw_in = 1'b0 ;
       #50 ht = 5'h00000 ;

      #100 // WRITE HV ENABLE/DISABLE bit --- turn ON HV
       #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b10000000 ;       //  select HVon command
       #50  ale = 1'b1 ;                      //    assert ale
       #50  cs = 1'b1 ;                       //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                      //    de-assert ale
       #50  addr[7:0]= 8'b00000000 ;          //    HV enable (active low)
       #50  cs = 1'b1 ;                       //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;


      #100 // Enable HV chan 0
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b00100000 ;     //  select HVen command
       #50  ale = 1'b1 ;                              //    assert ale
       #50  cs = 1'b1 ;                               //     strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  addr[7:0]= 8'b00000000 ;       //    active low
       #50  cs = 1'b1 ;                              //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

      #100 // Enable HV chan 1
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b00100001 ;     //  select HVen command
       #50  ale = 1'b1 ;                              //    assert ale
       #50  cs = 1'b1 ;                               //     strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  addr[7:0]= 8'b00000000 ;       //    active low
       #50  cs = 1'b1 ;                              //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

      #100 // disable HV chan 0   
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b00100000 ;    //  select HVen command
       #50  ale = 1'b1 ;                             //    assert ale
       #50  cs = 1'b1 ;                              //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                            //    de-assert ale
       #50  addr[7:0]= 8'b00000001 ;     //    active low
       #50  cs = 1'b1 ;                             //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

      // set threshold gain to LOW
     #100 // ----------------------------
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b00000000 ;     //  select Gain command
       #50  ale = 1'b1 ;                              //    assert ale
       #50  cs = 1'b1 ;                               //     strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  addr[7:0]= 8'b00000000 ;       //    active high gain
       #50  cs = 1'b1 ;                              //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

      // turn OFF HV psu

      #100 // WRITE HV ENABLE/DISABLE bit --- turn OFF HV
       #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b10000000 ;      //  select HVon command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                               //    de-assert ale
       #50  addr[7:0]= 8'b00000001 ;        //    HV enable (active low)
       #50  cs = 1'b1 ;                                //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

  // ------------------------------------------------------------------------------------------

      // read enclosure switch

  // ------------------------------------------------------------------------------------------

      // set gate bias DAC to 128 decimal

      #100 // WRITE GATE BIAS DAC
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b01000000 ;       //  select DAC command (gate == 00)
       #50  ale = 1'b1 ;                      //    assert ale
       #50  cs = 1'b1 ;                       //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                      //    de-assert ale
       #50  addr[7:0]= 8'b11111110 ;          //    DAC data 254
       #50  cs = 1'b1 ;                       //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

  // ------------------------------------------------------------------------------------------

      // set hv DAC to 80 decimal

     #2000 //
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b01000010 ;       //  select DAC command (hv == 10)
       #50  ale = 1'b1 ;                                //    assert ale
       #50  cs = 1'b1 ;                                 //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                                //    de-assert ale
       #50  addr[7:0]= 8'b01010000 ;          //    DAC data 80
       #50  cs = 1'b1 ;                                 //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

  // ------------------------------------------------------------------------------------------

      // set threshold gain HI and detect level 64 decimal

   #2000 // WRITE GAIN BIT
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b00000000 ;       //  select gain command
       #50  ale = 1'b1 ;                      //    assert ale
       #50  cs = 1'b1 ;                       //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                      //    de-assert ale
       #50  addr[7:0]= 8'b00000001 ;          //    set gain high
       #50  cs = 1'b1 ;                       //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;


      #300 // WRITE THRESHOLD DAC
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b01000001 ;       //  select DAC command (thresh = 01)
       #50  ale = 1'b1 ;                      //    assert ale
       #50  cs = 1'b1 ;                       //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                      //    de-assert ale
       #50  addr[7:0]= 8'b01000000 ;          //    DAC data 64
       #50  cs = 1'b1 ;                       //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

  // ------------------------------------------------------------------------------------------

      // set HV voltage level 128 decimal

     #2000 // WRITE HV PSU DAC
       #50  mod_sel_in = brd_id ;
      #100  addr[7:0] =  8'b01000010 ;       //  select DAC command (gate = 02)
       #50  ale = 1'b1 ;                      //    assert ale
       #50  cs = 1'b1 ;                       //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                      //    de-assert ale
       #50  addr[7:0]= 8'b10000000 ;          //    DAC data 128
       #50  cs = 1'b1 ;                       //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

  // ------------------------------------------------------------------------------------------

      // enable high voltage

      //  turn ON HV psu (HV switches disabled with reset_n @ power on

      #500 // WRITE HV ENABLE/DISABLE bit
       #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b10000000 ;       //  select HVen command
       #50  ale = 1'b1 ;                      //    assert ale
       #50  cs = 1'b1 ;                       //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                      //    de-assert ale
       #50  addr[7:0]= 8'b00000001 ;          //    HV enable (active high)
       #50  cs = 1'b1 ;                       //    strobe data
      #100  cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

  // ------------------------------------------------------------------------------------------
     #500 // read status 0
      #50  ht = 20'b00000000010000000000 ;

     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11000000 ;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale       #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;

     #300 // read status 1
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11000001 ;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  mod_sel_in = 2'b00 ;


    #300 // read status 2
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11000010 ;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;      
      #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale

       #50  mod_sel_in = 2'b00 ;

     #300 // read status 3
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11000011 ;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
      #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  mod_sel_in = 2'b00 ;

    // set SW and read stat 3 again
    #50  sw_in = 1'b1;

     #100  addr[7:0] =  8'b11000011 ;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
      #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  mod_sel_in = 2'b00 ;

     #300 // read status 4
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11000100;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;

       #50  mod_sel_in = 2'b00 ;

     #300 // read status 5
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11000101;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale      #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale

       #50  mod_sel_in = 2'b00 ;

     #300 // read status 6
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11000110;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
      #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  mod_sel_in = 2'b00 ;

     #300 // read status 7
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11000111;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
      #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  mod_sel_in = 2'b00 ;


    #300 // read status 8
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11001000;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
      #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  mod_sel_in = 2'b00 ;

    #300 // read status 9
     #50  mod_sel_in = brd_id ;

      #100  addr[7:0] =  8'b11001001;      //   select status command
       #50  ale = 1'b1 ;                               //    assert ale
       #50  cs = 1'b1 ;                                    //    strobe address
      #100  cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
      #50
       #50   cs = 1'b1 ;                             // strobe data ?
    #100    cs = 1'b0 ;
       #50  ale = 1'b0 ;                              //    de-assert ale
       #50  mod_sel_in = 2'b00 ;



  // ------------------------------------------------------------------------------------------

      // assert HT and check logic

  // ------------------------------------------------------------------------------------------

      // set temp control Tref

  // ------------------------------------------------------------------------------------------

      // set Kp, Ki, Kd

  // ------------------------------------------------------------------------------------------

     // enable heater

  // ------------------------------------------------------------------------------------------

      // set ADC mux channel


  // ------------------------------------------------------------------------------------------

      // adc read


  // ------------------------------------------------------------------------------------------

    #5000 $finish ;


///////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////
//// -------- BELOW HERE IS OLD STUFF -------------------------------------


end
       

endmodule
