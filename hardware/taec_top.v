
//-----------------------------------------------------------------------------
//  Project  : TAEC FPGA

//  Module   : taec_top.v

//  Parent   :  none
//  Children :  ni_intf1, rst_gen1, dac_mux1, adc3_intf1, 
//              hv_enable1, i2c_infc1, status1, bias1
//
//  Description: 
//     This module is the top level module for this project
//     Revised 03/06/2015 added WISHBONE i2c_interface

//     Revised 5/24/15 to work in read mode, bpt.

//  Parameters:
//     None

//  Notes: 

`include "..\include\timescale.v"
`include "..\include\defines.v"

//-----------------------------------------------------------------------
module taec_top(  
           // inputs
           input [7:0] ADDR,         // muxed address/data  bus from NI controller
           input CS,                 // chip select active high
           input [1:0] MOD_SEL_IN,   // module select bits [1:0]
           input CLK1,               // video strobe clock (xtal)
           input RESET_N,            // fpga reset from IBUF
           input ALE,                // address latch enable (high for address/low for data)
           input AD_SDI,             // AD data input  
           input [2:0] BRD_ID,       // Board ID bits [2:0]
           input [19:0] HT,          // HV comp trip state
           input SWin,               // enclosure safety switch (high == fault)
           // outputs
           output [11:0] DOUT,       // data bus to NI controller (tristateable)
           output [19:0] HV_EN_N,    // enables to output pins (active low)
           output HVON_N,            // HV PSU enable (active low)            
           output HV_DAC_SYNC_N,     // HV (5VV2) DAC
           output HV_DAC_SCLK,       //
           output HV_DAC_DIN,        //
           output THRH_DAC_SYNC_N,   // threshold DAC
           output THRH_DAC_SCLK,     //
           output THRH_DAC_DIN,      //
           output BIAS_DAC_SYNC_N,   // gate bias DAC
           output BIAS_DAC_SCLK,     //
           output BIAS_DAC_DIN,      //
           output AD_CONV_N,      	 // ADC convert
           output AD_SCLK,           // ADC clock
			  output [5:0] MUX_DOUT,    // mux select lines
           output D2,                // LED D2 tp (P51)
           output D3,                // LED D3 tp (P50)
           output D4,                // LED D4 tp (P68)
           output HI_GAIN_N,         // Hi_gain\ 
			  output TP12,              // debug test point
			  output TP14,              // debug test point
			  output TP15,              // debug test point  
			  // bi-directional
		     inout I2C_SCL,            // I2C clock
			  inout I2C_SDA             // I2C data
);



wire [7:0] bdout ;           // buffered data from NI controller
// wire [7:0] baddr ;        // not used
wire [5:0] saddr;            // status word index
wire [1:0] byte_cnt;

wire sp_clk;        
wire clk_out_100;
wire adc_valid ;
wire [11:0] adc_data_xq ;
wire chip_sel ;

wire [7:0] gate ;
wire [7:0] thrsh ;
wire [7:0] hvdc ;
wire [19:0] hv_en_n_out ;
wire [19:0] alarm_out ;          // channel alarm status


reg [15:0] stat_word;


wire set_stat_w;
wire set_hven_w;
wire set_hvdac_w ;
wire set_biasdac_w ; 
wire set_thrshdac_w ;
wire set_chen_w;
wire set_adc_w ;
wire set_gain_w ;
wire set_adcmux_w ;
wire set_tx_w;
wire set_cr_w;
wire set_ctl_w;
wire set_sr_w;
wire set_pre_low_w;
wire set_pre_hi_w;
wire set_ht1_w;
wire set_ht2_w;
wire set_ht3_w;
wire rd_RXR_w;

wire [7:0] stat_word_lsb ;
wire [7:0] stat_word_msb ;



// WISHBONE reg

reg [2:0] wb_adr_i;		// lower address bits
reg [7:0] wb_dat_i;		// data to the core
reg wb_we_i;				// write enable input
reg wb_stb_i;				// Strobe signal/Core select input
reg wb_cyc_i;				// WB cyc input

wire [7:0] wb_dat_o;
wire wb_ack_o;
wire wb_inta_o;
wire  scl_padoen_o;
wire  sda_padoen_o;
wire scl_pad_o;
wire sda_pad_o;
wire scl_pad_i;
wire sda_pad_i;

parameter I2CADDR = 8'hAE ;

parameter PRE_LO = 	3'h0 ;  // R/W
parameter PRE_HI = 	3'h1 ;  // R/W
parameter CTL = 		3'h2 ;  // R/W
parameter TXR = 		3'h3 ;  // W
parameter RXR =      3'h3 ;  // R
parameter CR  = 		3'h4 ;  // W
parameter SR  =      3'h4 ;  // R

reg CS_sync ;
reg ale_sync ;
reg mod_sel ;
reg [5:0] adc_mux_contrl ;
reg [11:0] a ;                  // adc read-back
reg [7:0] alarm_stat;      // alarm status
reg [2:0] sel_db;				// dbout control

wire start_xfer;
reg start_xfer_dly;
reg start_xfer_dly2;

reg hvon ;                 // hv enable (active high)

reg hi_gain_nr;            // hi_gain_n reg
reg SWin_sync;             // SWin safety switch
reg [19:0] HT_sync ;     	// channel trip status\
reg [3:0] htron ;          // heater on/off control ---- I2C
reg [3:0] srvon ;          // TC servo enable --- I2C

wire [11:0] db_out ;     	// data bus output from FPGA to NI, selected 
wire [11:0] db_out0 ;   	// data bus output from FPGA to NI, adc
wire [11:0] db_out1 ;  	   // data bus output from FPGA to NI, status LSB
wire [11:0] db_out2 ;      // data bus output from FPGA to NI, status MSB
wire [11:0] db_out3 ;      // data bus output from FPGA to NI, ht byte
wire [11:0] db_out4 ;      // data bus output from FPGA to NI, wb_data

wire sync_rst_n ;


assign chip_sel = (MOD_SEL_IN[1:0]==BRD_ID[1:0]) ? 1'b1:1'b0 ;
assign MUX_DOUT =  adc_mux_contrl ;
assign HVON_N = ~hvon;
assign HV_EN_N = hv_en_n_out;
assign HI_GAIN_N = hi_gain_nr;

// i2c IO
assign I2C_SDA = sda_padoen_o ? 1'bz: sda_pad_o;
assign I2C_SCL = scl_padoen_o ? 1'bz : scl_pad_o;
assign scl_pad_i = I2C_SCL;
assign sda_pad_i = I2C_SDA;


// Debug LEDs ---------------------------------------------------
assign D2 = wb_cyc_i; 
assign D3 = chip_sel;
assign D4 = 1'b0;    // pin error ?? doesn't route

// --- Debug test points
assign TP12 = scl_padoen_o; // wb_stb_i;
assign TP14 = sda_padoen_o; //wb_ack_o;
assign TP15 = set_tx_w;
// --- end debug section





always @(posedge sp_clk) begin
       CS_sync <= CS & sync_rst_n ;
       ale_sync <= ALE ;
       mod_sel <= chip_sel & CS_sync ; 
       SWin_sync <= SWin ;
       HT_sync <= HT ;
end


reg sp_clk2;        // debug slower clock

`ifdef BENCH        // defined in defines.v for testbench simulation
wire dcm_lock ;
assign dcm_lock = 1'b1;

reg clk3;
reg clk4;

initial 
  begin
  clk3 <= 0 ;
  clk4 <= 0 ;
  end 
  
  assign clk_out_100 = CLK1 ;
  always @ (posedge CLK1)
     clk3 <= ~clk3 ;
 always @ (posedge clk3)
     clk4 <= ~clk4 ; 
 assign sp_clk = clk4 ;

 // DCM for implementation, not in testbench
`else
wire dcm_lock;
 dcm1 instance_name (
 .CLKIN_IN   (CLK1),           // 100MHz xtal
 .RST_IN     (~RESET_N), 
 .CLKDV_OUT  (sp_clk),         // 25MHz output
 .CLKIN_IBUFG_OUT (), 
 .CLK0_OUT   (clk_out_100),    // 100Mhz output
 .LOCKED_OUT (dcm_lock)
 ); 
`endif      
              

// Instaniate ni_intf                                  
   ni_intf ni_intf1(
   // inputs
   .addr     		(ADDR),              // multiplexed address/data
   .ale      		(ale_sync),     
   .mod_sel  		(mod_sel),
   .clk      		(sp_clk),
   .rst_n    		(sync_rst_n),      	// active low reset
   // outputs
   .dout      		(bdout),            	// buffered data
   .baddr     		(),                  // buffered address, not used baddr
   .saddr        	(saddr),             // status word address
   .byte_cnt     	(byte_cnt),          // i/o byte count
	.set_hven		(set_hven_w),
   .set_gain 		(set_gain_w),
	.set_hvdac		(set_hvdac_w),
	.set_biasdac	(set_biasdac_w),
	.set_thrshdac	(set_thrshdac_w),
	.set_chanen		(set_chen_w),
	.set_adcmux		(set_adcmux_w),
	.set_adc_cnvrt (set_adc_w),
	.set_TXR			(set_tx_w),				// wishbone i2c TXR reg 
	.set_CR			(set_cr_w),				// wishbone i2c CR reg
	.set_CTL			(set_ctl_w),			// wishbone i2c CTL reg
	.set_SR			(set_sr_w),				// wishbone i2c SR reg
	.set_stat		(set_stat_w),			// not totally defined yet
	.set_HT1			(set_ht1_w),			// read ht[7:0]
	.set_HT2			(set_ht2_w),			// read ht[15:8]
	.set_HT3			(set_ht3_w),			// read ht[19:16]
	.set_pre_low	(set_pre_low_w),     // i2c lsb prescale counter
	.set_pre_hi    (set_pre_hi_w),	   // i2c msb prescale counter
	.rd_RXR        (rd_RXR_w)           // read wb RX register
	);
	        		 

// instaniate rst_gen
   rst_gen rst_gen1(
          .reset_n      	(RESET_N),  	// reset from IBUFF
          .clk          	(sp_clk),   	// master clock source
          .sync_rst_n 		(sync_rst_n)  	// synchronized reset
          );

// instantiate dac_mux.v
	dac_mux dac_mux1 (
				// inputs
				.idac_data_xq        (bdout),            	// latched 8-bit data bus from NI controller
				.start_dac1 			(set_thrshdac_w),  	// control bit 1
				.start_dac2				(set_biasdac_w),  	// control bit 2
				.start_dac3				(set_hvdac_w),  		// control bit 3
				.sp_clk              (sp_clk2),      		// master clk
				.sp_rst_n            (sync_rst_n),    		// reset/
				.ale                 (ale_sync), 			// data enable (active low)
				//outputs                  
				.idac_clk1       		(THRH_DAC_SCLK),  	// DAC081 clock
				.idac_cs_n1   			(THRH_DAC_SYNC_N),	// DAC081 sync_n 
				.idac_sdout1 			(THRH_DAC_DIN),      // DAC081 data_in
				.dout_w1             (thrsh),           	// data bus out1
				.idac_clk2       		(BIAS_DAC_SCLK),  	// DAC081 clock
				.idac_cs_n2   			(BIAS_DAC_SYNC_N),	// DAC081 sync_n 
				.idac_sdout2 			(BIAS_DAC_DIN),      // DAC081 data_in
				.dout_w2             (gate),           	// data bus out2
				.idac_clk3         	(HV_DAC_SCLK),  		// DAC081 clock
				.idac_cs_n3        	(HV_DAC_SYNC_N),		// DAC081 sync_n 
				.idac_sdout3       	(HV_DAC_DIN),   		// DAC081 data_in
				.dout_w3          	(hvdc)               // data bus out
			  );		 
			

// Instantiate  adc  
   adc3_intf adc3_intf1(
            // Outputs
            .adc_clk          	(AD_SCLK),  			// adc clock
            .adc_cs_n         	(AD_CONV_N),			// adc cs\
            .adc_data_xq      	(adc_data_xq),
            .adc_data_val_xq  	(adc_valid),
            // Inputs
            .tx_clk           	(sp_clk),           	// 25Mhz clock
            .tx_rst_n         	(sync_rst_n),     	// reset\
            .bb_adc_sdin      	(1'b0),           	// unused input
            .sol_adc_sdin     	(AD_SDI),         	// serial data in
            .adc_convert      	(set_adc_w),      	// adc start signal
            .convert_slow     	(1'b0)            	// always fast clock
            );  


// instantiate hv_enable
   hv_enable hv_enable1( 
            // inputs
            .addr             	(bdout[4:0]),        // channel selection
            .din              	(bdout[7]),         	// enable/disable state
            .trip             	(HT_sync),        	// channel trip input
            .enable_cntl      	(set_chen_w),   		//
            .clk              	(sp_clk),         	//
            .rst_n            	(sync_rst_n),    		// active low reset
            // outputs
            .hv_en_n          	(hv_en_n_out),
            .alarm            	(alarm_out)          // channel alarm status
            );

// instantiate i2c_master_top
	i2c_master_top i2c_master_top1(
		// inputs
			.wb_clk_i			(sp_clk),  		//  Master clock
			.wb_rst_i			(!sync_rst_n), 	//  synchronous reset, active high    
			.arst_i				(RESET_N),		//  asynchronous reset,
			.wb_adr_i			(wb_adr_i),		//  lower address bits 
			.wb_dat_i			(wb_dat_i),		//  data towards the core
			.wb_we_i				(wb_we_i), 		//  write enable input
			.wb_stb_i			(wb_stb_i),		//  write enable input
			.wb_cyc_i			(wb_cyc_i),		//  valid bus cycle input 
			.scl_pad_i			(scl_pad_i),	//  serial clock line in
			.sda_pad_i			(sda_pad_i),	//  serial data line in
			// output
			.wb_dat_o			(wb_dat_o),		//  data from the core
			.wb_ack_o			(wb_ack_o),		//  bus cycle acknowledge output
			.wb_inta_o			(wb_inta_o),	//  interrupt signal output
			.scl_pad_o			(scl_pad_o), 	//
			.scl_padoen_o		(scl_padoen_o),// 
			.sda_pad_o			(sda_pad_o), 	//
			.sda_padoen_o		(sda_padoen_o)	//
);

// instantiate status
  status status1(
            // inputs
           .ht             (alarm_out),         // channel alarm bits
           .hvon           (hvon),            	// hv dc on/off state
           .hven_n        	(hv_en_n_out),      	// channel enable bits (active low)
           .bias_dac     	(gate),            	// gate bias dac
           .thrsh_dac    	(thrsh),           	// threshold dac
           .hvdc_dac     	(hvdc),           	// hv dc dac
           .swin           (SWin_sync),  			// safety switch state
           .gain           (hi_gain_nr), 		   // thresh sens gain
           .addr           (saddr),           	// addr of status word  
           .enable_cntl  	(set_stat_w),  		// control to set status
           .clk            (sp_clk),          	// master fpga clk
           .rst_n          (sync_rst_n),   		// synchronized reset active low
            // outputs
           .stat_lsb    	(stat_word_lsb),
           .stat_msb    	(stat_word_msb)
           );


always @(negedge sp_clk) begin

     sp_clk2 <= ~sp_clk2 & sync_rst_n	;  // debug slower clock

      ///////////////////////////////////////////////////////  read adc
		if (adc_valid) begin
         a[11:0] <= adc_data_xq[11:0]; 
			sel_db <= 3'b010;
		end			
      ///////////////////////////////////////////////////////	set HV enablon/off
      if( set_hven_w | !sync_rst_n) begin
          hvon <=   bdout[0] & sync_rst_n;
      end
      ///////////////////////////////////////////////////////	set hi/low thresh gain
      if( set_gain_w ) begin
          hi_gain_nr <=   ~bdout[0] ;	 
      end
      ///////////////////////////////////////////////////////	dacs handled in dac_mux
		///////////////////////////////////////////////////////	set chan enable in hv_enable
      ///////////////////////////////////////////////////////  set adc cnvrt in adc3_intf		

      ///////////////////////////////////////////////////////	read HT
      if( set_ht1_w ) begin
          alarm_stat <=   HT_sync[7:0] ;	
          sel_db <= 3'b011;			 
      end
		if( set_ht2_w ) begin
          alarm_stat <=   HT_sync[15:8] ;	 
			 sel_db <= 3'b011;
      end
		if( set_ht3_w ) begin
          alarm_stat[7:0] <=  { 0,0, SWin_sync, HT_sync[19:16] } ;
          sel_db <= 3'b011;			 
      end
      ////////////////////////////////////////////////////////
		// ----------------------------------------------------
	  if(set_stat_w && (byte_cnt[1:0]==2'b10) ) begin
          stat_word[7:0] <= stat_word_lsb ;
			 sel_db <= 3'b000;
     end
	  if(set_stat_w && (byte_cnt[1:0]==2'b11) ) begin
          stat_word[15:8] <= stat_word_msb ;
			 sel_db <= 3'b001;
     end
	  ///////////////////////////////////////////////////////// set TXR
	  if(set_tx_w | !sync_rst_n) begin
			wb_adr_i[2:0] <= TXR & {3{sync_rst_n}};
			wb_dat_i[7:0] <= bdout[7:0] & {8{sync_rst_n}} ;
	  end
	  ///////////////////////////////////////////////////////// set CR
	   if(set_cr_w | !sync_rst_n) begin
			wb_adr_i[2:0] <= CR & {3{sync_rst_n}};
			wb_dat_i[7:0] <= bdout[7:0] & {8{sync_rst_n}} ;
	  end
	  ///////////////////////////////////////////////////////// set CTL
	   if(set_ctl_w | !sync_rst_n ) begin
			wb_adr_i[2:0] <= CTL & {3{sync_rst_n}};
			wb_dat_i[7:0] <= bdout[7:0] & {8{sync_rst_n}} ;
	  end
	  ///////////////////////////////////////////////////////// set SR
	  if((set_sr_w & ale_sync) | !sync_rst_n) begin
	       wb_adr_i[2:0] <= SR & {3{sync_rst_n}};
	  end
	  if((set_sr_w & !ale_sync) | !sync_rst_n) begin
	       sel_db <= 3'b100;
	  end 
	  ///////////////////////////////////////////////////////// set prescaler hi msb
	  if(set_pre_hi_w | !sync_rst_n) begin
			wb_adr_i[2:0] <= PRE_HI & {3{sync_rst_n}};
			wb_dat_i[7:0] <= bdout[7:0] & {8{sync_rst_n}};  
	  end
	  ///////////////////////////////////////////////////////// set prescaler low msb
	  if(set_pre_low_w | !sync_rst_n) begin
			wb_adr_i[2:0] <= PRE_LO & {3{sync_rst_n}};
			wb_dat_i[7:0] <= bdout[7:0] & {8{sync_rst_n}} ;
	  end
	  ///////////////////////////////////////////////////////// rd_RXR
	  if((rd_RXR_w & ale_sync) | !sync_rst_n) begin
	       wb_adr_i[2:0] <= RXR & {3{sync_rst_n}};
	  end
	  if((rd_RXR_w & !ale_sync) | !sync_rst_n) begin
	       sel_db <= 3'b100;
             wb_adr_i[2:0] <= RXR & {3{sync_rst_n}};
	  end 
	  /////////////////////////////////////////////////////////
	  
	  wb_we_i <= (set_pre_low_w | set_pre_hi_w | set_ctl_w | set_cr_w | set_tx_w) & (sync_rst_n & !set_sr_w & !rd_RXR_w);
	    
end

always @(negedge sp_clk) begin
		start_xfer_dly <= start_xfer ;
		start_xfer_dly2 <= start_xfer_dly;
end		

always @(negedge sp_clk) begin 
			wb_stb_i <=  !wb_ack_o & sync_rst_n & start_xfer_dly & !start_xfer_dly2;
			wb_cyc_i <=  !wb_ack_o & sync_rst_n & start_xfer_dly & !start_xfer_dly2;
end



parameter chan0 = 3'b111 ;
parameter chan1 = 3'b110 ;
parameter chan2 = 3'b101 ;
parameter chan3 = 3'b100 ;
parameter chan4 = 3'b011 ;
parameter chan5 = 3'b010 ;
parameter chan6 = 3'b001 ;
parameter chan7 = 3'b000 ;
parameter mux0  = 3'b001 ;
parameter mux1  = 3'b010 ;
parameter mux2  = 3'b100 ;


always @(negedge sp_clk) begin
    if (set_adcmux_w == 1'b1) 
	 
    case ( bdout[4:0])
         5'b00000:   adc_mux_contrl <= { mux0 , chan0 } ; // (CH0)
         5'b00001:   adc_mux_contrl <= { mux0 , chan1 } ; // :
         5'b00010:   adc_mux_contrl <= { mux0 , chan2 } ; // :
         5'b00011:   adc_mux_contrl <= { mux0 , chan3 } ;
         5'b00100:   adc_mux_contrl <= { mux0 , chan4 } ;
         5'b00101:   adc_mux_contrl <= { mux0 , chan5 } ;
         5'b00110:   adc_mux_contrl <= { mux0 , chan6 } ;
         5'b00111:   adc_mux_contrl <= { mux0 , chan7 } ;
         5'b01000:   adc_mux_contrl <= { mux1 , chan0 } ;
         5'b01001:   adc_mux_contrl <= { mux1 , chan1 } ;
         5'b01010:   adc_mux_contrl <= { mux1 , chan2 } ;
         5'b01011:   adc_mux_contrl <= { mux1 , chan3 } ;
         5'b01100:   adc_mux_contrl <= { mux1 , chan4 } ;
         5'b01101:   adc_mux_contrl <= { mux1 , chan5 } ;
         5'b01110:   adc_mux_contrl <= { mux1 , chan6 } ;
         5'b01111:   adc_mux_contrl <= { mux1 , chan7 } ;
         5'b10000:   adc_mux_contrl <= { mux2 , chan0 } ;
         5'b10001:   adc_mux_contrl <= { mux2 , chan1 } ; // :
         5'b10010:   adc_mux_contrl <= { mux2 , chan2 } ; // :
         5'b10011:   adc_mux_contrl <= { mux2 , chan3 } ; // (CH19)
         5'b10100:   adc_mux_contrl <= { mux2 , chan4 } ; // TP21 (CH20-spare)
         5'b10101:   adc_mux_contrl <= { mux2 , chan5 } ; // TP22 (CH21-spare)
         5'b10110:   adc_mux_contrl <= { mux2 , chan6 } ; // TP23 (CH22-spare)
         5'b10111:   adc_mux_contrl <= { mux2 , chan7 } ; // TP24 (CH23-HV)
         default:    adc_mux_contrl <= { mux0 , chan0 } ; // default
    endcase
 end
 
assign start_xfer = (set_pre_low_w | set_pre_hi_w | (set_sr_w & ale_sync) | set_ctl_w | set_cr_w | set_tx_w | rd_RXR_w) ; // & !wb_ack_o ;
 
 
 // data output bus
assign db_out0 = (sel_db==3'b010)? a : 12'b0;	            				// adc data
assign db_out1 = (sel_db==3'b000)? {3'b001,stat_word[7:0]} : 12'b0;   	// status data LSB
assign db_out2 = (sel_db==3'b001)? {3'b010,stat_word[15:8]} : 12'b0;		// status data MSB
assign db_out3 = (sel_db==3'b011)? {3'b011,alarm_stat} : 12'b0;			// alarm data
assign db_out4 = (sel_db==3'b100)? {3'b100,wb_dat_o} : 12'b0;			   // wb data

assign db_out = db_out0 | db_out1 | db_out2 | db_out3 | db_out4;
assign DOUT =	( mod_sel ) ? db_out : 12'bz ;

  
endmodule
