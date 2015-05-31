// Module     : mb_bench2                                                                                    //
// Description: This is the top level stimulus module of the TAEC FPGA. 
//                      It  instatiates dac_board                                                             //
//          *** for debugging NI interface ***  
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

reg busy ;    // for test bench only
reg ack ;      // for test bench only
reg read;     // debug
reg [7:0] byte1;
reg [7:0] byte2;
reg cr20;

wire [19:0] hv_enable_n;         
wire  dsync_n ;
wire [11:0] dout ;

wire scl;
wire sda;
pullup(scl);
pullup(sda);
          
integer i;

parameter I2CADDR = 8'hAE ;
parameter CTL = 8'h02 ;
parameter TXR = 8'h03 ;
parameter CR  = 8'h04 ;

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
    .HI_GAIN_N                    (hi_gain_n),
    .I2C_SCL                       (scl),
    .I2C_SDA                         (sda)
     ) ;


  i2c_slave_rx  i2c_slave_rx1 (
     // inputs
     .cs         (reset_n),
    .sclk       (scl),
     // outputs
     .sda        (sda)
    );

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
       sw_in = 0;

      byte1 = 0;
      byte2 = 0;
      busy = 0;
      ack = 1;
      read = 0;
      cr20 = 0;

       #20 ht = 20'b00000000000000000000 ;
       #50 ht = 20'b00000000010000000000 ;
       #50 ht =  20'b00000000000000000000 ;

       #50 reset_n = 1'b1 ;
       #20 cs = 1'b0;                                  // de-select

  // -----------------------------------------------------------------------------------------
  // -----------------------------------------------------------------------------------------
  // -------- I2C debug -----------------------------------------------------------------

  // use command to set prescaler to 49 decimal
     #50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0100_0000 ;   //   select pre_low command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #300  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'b0011_0001 ;   //  div by 49
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

    #50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0100_0100 ;   //   select pre_hi command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'b0000_0000 ;   //  msb 0
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

  // enable the core (write 0x80 to CTL reg)
 	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0010_1000 ;   //   CTL reg
      #50    ale = 1'b1 ;                            //    assert ale
      #50      cs = 1'b1 ;                           //    strobe address
      #300    cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'h80 ;                 //    0x80
      #50      cs = 1'b1 ;                           //    strobe data
      #500    cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

 // ======================================================
 // Write a byte of data to the I2C
 // ======================================================

      // Send the slave address with the LSB = 0
 	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0010_0000 ;   //   TXR reg
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'haa ;                 //   0xaa
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

     // send CR to 8'h90 to enable start & write
	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50      cs = 1'b1 ;                           //    strobe address
      #500    cs = 1'b0 ;
      #50    ale = 1'b0 ;                           //    de-assert ale
      #50    addr[7:0] = 8'h90 ;                //    0x90
      #50      cs = 1'b1 ;                          //    strobe data
      #200    cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;
 #50000

   // check the TIP bit of the SR register for command done
   #50  mod_sel_in = brd_id ;
   busy = 1'b1 ;
   while (busy==1) begin
     #100  addr[7:0] = 8'b001011_00 ;   //   rd SR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50       cs = 1'b1 ;                         //    strobe address
     #500       cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50    cs = 1'b1 ;                           //    strobe data
       #200        busy = dout[1] ;             // TIP bit
     #500   cs = 1'b0 ;
     $display(" check busy");
    end
   #50  mod_sel_in = 2'b00 ;

   // set up the internal reg # to send to 
   #25000
 	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0010_0000 ;   //   TXR reg
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'hc3 ;                 //   0xc3
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

    //  set CR with 8'h10 to enable a write to send the slave memory address
	#50   mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'h10 ;                //    0x10
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50   mod_sel_in = 2'b00 ;

#20000

   //  check the TIP bit of the SR register for command done
   #50   mod_sel_in = brd_id ;
   busy = 1'b1 ;
   while (busy==1) begin
     #100  addr[7:0] = 8'b001011_00 ;   //   rd SR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50    cs = 1'b1 ;                           //    strobe address
     #500    cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50    cs = 1'b1 ;                           //    strobe data
       #200        busy = dout[1] ;                   // TIP bit
     #500  cs = 1'b0 ;
     $display(" check busy");
    end
     #50    mod_sel_in = 2'b00 ;

    // send the data to the register
	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0010_0000 ;   //   TXR reg
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'h55 ;                 //   0x55 (data to be sent)
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

      //  set CR with 8'h10 to enable a write to send the slave memory address
	#50   mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'h50 ;                //    0x50                     includes stop
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50   mod_sel_in = 2'b00 ;

  #10000
 //  check the TIP bit of the SR register for command done
   #50   mod_sel_in = brd_id ;
   busy = 1'b1 ;
   while (busy==1) begin
     #100  addr[7:0] = 8'b001011_00 ;   //   rd SR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50    cs = 1'b1 ;                           //    strobe address
     #500    cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50    cs = 1'b1 ;                           //    strobe data
       #200        busy = dout[1] ;                   // TIP bit
     #500  cs = 1'b0 ;
     $display(" check busy");
    end
     #50    mod_sel_in = 2'b00 ;

     #50 read = 0;
     #50 read = 1;
     #500 read =0;
 // =================================================
 // =================================================


#60000
      read = 1;
// =================================================
// read I2C slave data register 
//==================================================
      // (1) Set the slave address with the LSB = 0
 	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0010_0000 ;   //   TXR reg
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'haa ;                 //   0xaa (LSB 0, write)
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

     // (2) Send CR to 8'h90 to enable start & write
	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50      cs = 1'b1 ;                           //    strobe address
      #500    cs = 1'b0 ;
      #50    ale = 1'b0 ;                           //    de-assert ale
      #50    addr[7:0] = 8'h90 ;                //    0x90
      #50      cs = 1'b1 ;                          //    strobe data
      #200    cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;
 #50000

   // (3) check the TIP bit of the SR register for command done
   #50  mod_sel_in = brd_id ;
   busy = 1'b1 ;
   while (busy==1) begin
     #100  addr[7:0] = 8'b001011_00 ;   //   rd SR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50       cs = 1'b1 ;                         //    strobe address
     #500       cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50    cs = 1'b1 ;                           //    strobe data
       #200        busy = dout[1] ;             // TIP bit
     #500   cs = 1'b0 ;
     $display(" check busy");
    end

  #50  mod_sel_in = 2'b00 ;

   // (4) Set up the internal reg # from which to read 
   #20000
 	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0010_0000 ;   //   TXR reg
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'hd0 ;                 //   0xd0  internal reg #
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

    // (5)  set CR with 8'h10 to enable a write to send the register #
	#50   mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'h10 ;                //    0x10
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50   mod_sel_in = 2'b00 ;

   //  (6) check the TIP bit of the SR register for command done
   #50   mod_sel_in = brd_id ;
   busy = 1'b1 ;
   while (busy==1) begin
     #100  addr[7:0] = 8'b001011_00 ;   //   rd SR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50    cs = 1'b1 ;                           //    strobe address
     #500    cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50    cs = 1'b1 ;                           //    strobe data
       #200        busy = dout[1] ;                   // TIP bit
     #500  cs = 1'b0 ;
     $display(" check busy");
    end
     #50    mod_sel_in = 2'b00 ;

    // (7) Set the slave address from which to read with LSB==1
	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b0010_0000 ;   //   TXR reg
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'hab ;                 //   0xab  (slave + lsb=1, read)
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

     //  (8) set CR with 8'h90 to enable a write to send the slave memory address
	#50   mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'h90 ;                //    0x90 
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50   mod_sel_in = 2'b00 ;

  //  (9) check the TIP bit of the SR register for command done
   #50   mod_sel_in = brd_id ;
   busy = 1'b1 ;
   while (busy==1) begin
     #100  addr[7:0] = 8'b001011_00 ;   //   rd SR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50    cs = 1'b1 ;                           //    strobe address
     #500    cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50    cs = 1'b1 ;                           //    strobe data
       #200        busy = dout[1] ;                   // TIP bit
     #500  cs = 1'b0 ;
     $display(" check busy");
    end
     #50    mod_sel_in = 2'b00 ;

#25000

 // (10) set CR with 8'h20 to enable a read
     cr20 = 0;
     #50 cr20=1;
     #50 cr20=0;


	#50   mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'h20 ;                //    0x20
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50   mod_sel_in = 2'b00 ;

 //  (11) check the TIP bit of the SR register for command done
   #50   mod_sel_in = brd_id ;
   busy = 1'b1 ;
   while (busy==1) begin
     #100  addr[7:0] = 8'b001011_00 ;   //   rd SR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50    cs = 1'b1 ;                           //    strobe address
     #500    cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50    cs = 1'b1 ;                           //    strobe data
       #200        busy = dout[1] ;                   // TIP bit
     #500  cs = 1'b0 ;
     $display(" check busy");
    end
     #50    mod_sel_in = 2'b00 ;

 //  (12) get 1st data byte
       #50   mod_sel_in = brd_id ;
     #100  addr[7:0] = 8'b010010_00;   //   rd TXR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50       cs = 1'b1 ;                        //    strobe address
     #500       cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50       cs = 1'b1 ;                        //    strobe data
       #200       byte1 = dout ;                 // data byte
     #500      cs = 1'b0 ;
     #50    mod_sel_in = 2'b00 ;

 // (13) set CR with 8'h28 to enable a final read
     #10000

	#50   mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'h28 ;                //    0x28
      #50    cs = 1'b1 ;                             //    strobe data
      #500  cs = 1'b0 ;
      #50   mod_sel_in = 2'b00 ;

 //  (14) check the TIP bit of the SR register for command done
   #50   mod_sel_in = brd_id ;
   busy = 1'b1 ;
   while (busy==1) begin
     #100  addr[7:0] = 8'b001011_00 ;   //   rd SR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50    cs = 1'b1 ;                           //    strobe address
     #500    cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50    cs = 1'b1 ;                           //    strobe data
       #200        busy = dout[1] ;                   // TIP bit
     #500  cs = 1'b0 ;
     $display(" check busy");
    end
     #50    mod_sel_in = 2'b00 ; 

 //  (11) get 2nd data byte
       #50   mod_sel_in = brd_id ;
     #100  addr[7:0] = 8'b010010_00;    //   rd TXR reg cmnd
       #50    ale = 1'b1 ;                          //    assert ale
       #50       cs = 1'b1 ;                        //    strobe address
     #500       cs = 1'b0 ;
       #50    ale = 1'b0 ;                          //    de-assert ale
       #50       cs = 1'b1 ;                        //    strobe data
       #200       byte2 = dout ;                 // data byte
     #500      cs = 1'b0 ;
     #50    mod_sel_in = 2'b00 ;

     // set CR to 8'h40 to send STOP
	#50  mod_sel_in = brd_id ;
      #100  addr[7:0] = 8'b001001_00 ;   //   CR reg cmnd
      #50    ale = 1'b1 ;                            //    assert ale
      #50      cs = 1'b1 ;                           //    strobe address
      #500    cs = 1'b0 ;
      #50    ale = 1'b0 ;                           //    de-assert ale
      #50    addr[7:0] = 8'h40 ;                //    0x40
      #50      cs = 1'b1 ;                          //    strobe data
      #200    cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

     #50 read = 0;
     #50 read = 1;
     #500 read =0;

// ==================================================
// ==================================================

 // -------------------------------------------------------------------------------------------
 #50000
  // -----------------------------------------------------------------------------------------
  // enable chan 7
      #1000  
      #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b00010100 ;    //   select chen command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'b10000111 ;     //  enable chen 7
      #50    cs = 1'b1 ;                             //    strobe data
      #100  cs = 1'b0 ;

      #50  mod_sel_in = 2'b00 ;

      // set all active
    #500  
      #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b00010100 ;    //   select chen command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'b10010100 ;     //  enable chen 20
      #50    cs = 1'b1 ;                             //    strobe data
      #100  cs = 1'b0 ;

      #50  mod_sel_in = 2'b00 ;


  //-------------------------------------------------------------------------------------------
  //  set HV dac
      #1000  
      #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b00001000 ;    //   select HVdac command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'b10000001 ;     //    DAC byte
      #50    cs = 1'b1 ;                             //    strobe data
      #100  cs = 1'b0 ;

      #50  mod_sel_in = 2'b00 ;

  // --------------------------------------
  // enable HV 
      #2000  
      #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b00000000 ;    //   select HVen command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'b00000001 ;     //   enable bit
      #50    cs = 1'b1 ;                             //    strobe data
      #100  cs = 1'b0 ;

      #50  mod_sel_in = 2'b00 ;

  // --------------------------------------
  // set gain high
      #500  
      #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b00000001 ;    //   select gain command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'b00000001 ;     //   enable bit
      #50    cs = 1'b1 ;                             //    strobe data
      #100  cs = 1'b0 ;

      #50  mod_sel_in = 2'b00 ;

  // --------------------------------------------------------------------------------------------
  // set adc mux channel
     #500  
      #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b000110_00 ;    //    select mux command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0] = 8'b00010111 ;     //   mux channel #23
      #50    cs = 1'b1 ;                             //    strobe data
      #100  cs = 1'b0 ;

      #50  mod_sel_in = 2'b00 ;

  // --------------------------------------------------------------------------------------------
  // capture adc
  # 2000
     #500  
      #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b000111_00 ;    //    select adc_cnvrt command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #2000  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #2000 // long wait    
      #50    cs = 1'b1 ;                             //    strobe data
      #50    // read output data
      #100  cs = 1'b0 ;

      #50  mod_sel_in = 2'b00 ;
      #1000 // wait adc complete;
  //-------------------------------------------------------------------------------------------

  // ------------------------------------------------------------------------------------------
  //  write bias DAC
  // 
      #2000  
      #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] =  8'b00001100 ;    //   select bias command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #500  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #50    addr[7:0]= 8'b101010101 ;    //    dac value
      #50    cs = 1'b1 ;                             //    strobe data
      #1000  cs = 1'b0 ;


      #5000  mod_sel_in = 2'b00 ;
   // -------------------------------------------------------------------------------------------
   // read all ht & SWin
   // read HT[7:0]
     #50 sw_in = 1'b1;   // asserted
     #50  ht = {4'ha, 8'h55, 8'haa} ;
   // 

     #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b001101_00 ;    //    select HT1 command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #500  
      #50    cs = 1'b1 ;                             //    strobe data
      #500  // NI read period
      #100  cs = 1'b0 ;

     // read HT[15:8]
     #50  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b001110_00 ;    //    select HT2 command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #500  
      #50    cs = 1'b1 ;                             //    strobe data
      #500  // NI read period
      #100  cs = 1'b0 ;
      #50  mod_sel_in = 2'b00 ;

     // read SWin & HT[19:16]

     #100  mod_sel_in = brd_id ;
 
      #100  addr[7:0] = 8'b001111_00 ;   //    select HT3 command
      #50    ale = 1'b1 ;                            //    assert ale
      #50    cs = 1'b1 ;                             //    strobe address
      #100  cs = 1'b0 ;
      #50    ale = 1'b0 ;                            //    de-assert ale
      #500  
      #50    cs = 1'b1 ;                             //    strobe data
      #500  // NI read period
      #100  cs = 1'b0 ;

      #50  mod_sel_in = 2'b00 ;

  // ------------------------------------------------------------------------------------------
 



    #20000 $finish ;


///////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////
//// -------- BELOW HERE IS OLD STUFF -------------------------------------


end
       

endmodule
