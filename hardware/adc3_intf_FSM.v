//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Module: adc3_intf                                                    //
// Description: This module provides the interface to both the SOL and  //
//              the Big Brother AD7276 and AD7278 Analog to Digital     //
//              Converters. Both ADCs share clock and chip select lines //
//              and therefore are read at the same time. However, the    //
//              data is never needed for both at the same time so the     //
//              ADC register can be shared. Because of the long cable   //
//              for BB, the clock must run at a much slower rate. See   //
//              AD7276 Spec for details.                                              //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

`include "../include/timescale.v"

module adc3_intf (
   // Outputs
  output		adc_clk,		          // ADC clock out to ADC
  output		adc_cs_n,		       // Chip select output to ADC
  output reg [11:0] adc_data_xq,  // ADC digital data
  output reg adc_data_val_xq,     // Digital data out valid
   // Inputs
  input		tx_clk,			       // Transmit clock
  input		tx_rst_n,		       // Transmit asynchronous reset
  input		bb_adc_sdin,		    // BB ADC serial data in
  input		sol_adc_sdin,		    // SOL ADC serial data in
  input		adc_convert,		    // Get data from ADC
  input		convert_slow		    // Do conversion with slow clock
);

// ++++++++++++++++++++++++++++++++++++++++++++++++++++

reg[3:0]	       adc_cnt_xq;		 // ADC falling edge clock count
reg		       cs_xq;			    // ADC chip select
reg		       fast_xq;		    // Do conversion with fast clock
reg[4:0]	       div_cnt_xq;		 // TX clock divide register
reg		       adc_clk_xq;		 // Registered ADC clock out

// ++++++++++++++++++++++++++++++++++++++++++++++++++++
// --- parameters ---
parameter [2:0] FIRST  = 3'b000 ;
parameter [2:0] SECOND = 3'b001;
parameter [2:0] THIRD  = 3'b010 ;
parameter [2:0] FOURTH = 3'b100 ;
//+++++++++++++++++++++++++++++++++++++++++++++++++++++

	// Set chip select on the start of the conversion. Reset chip select
	// after 15 clocks.
wire cs_xd = (adc_convert || cs_xq) && ~((adc_cnt_xq == 4'hF) && adc_clk_xq);

	// Save if we are doing a fast conversion or not.
wire fast_xd = adc_convert ? ~convert_slow : fast_xq;

	// Divide 100MHz clock by 4 if doing a fast conversion. Otherwise,
	// divide by 32.
wire[4:0] div_cnt_xd = ~cs_xd                           ? 5'h0 : 
                        fast_xq && (div_cnt_xq == 5'h3) ? 5'h0 :
                        div_cnt_xq + 1'b1;

	// Create ADC clock with 50% duty cycle.
wire adc_clk_xd = fast_xq ? (div_cnt_xq < 5'h2) :
                           ~(div_cnt_xq[4]);

	// Detect falling edge of clock based on 4 or 32 clock cycles.
wire adc_falling = fast_xq ? (div_cnt_xq == 5'h2) : (div_cnt_xq == 5'd16);

	// Increase clock count every ADC falling edge clock cycle.
wire[3:0] adc_cnt_xd = ~cs_xq       ? {4{1'b0}}         :
                        adc_falling ? adc_cnt_xq + 1'b1 :
                                      adc_cnt_xq;

	// Shift in data on falling edge of clock for 14 clocks.
	// There are two leading zeros.
wire adc_shift_xz = adc_falling && (adc_cnt_xq < 4'hE);

	// Shift in ADC digital data.
wire[11:0] adc_data_xd = adc_shift_xz &&  fast_xq ? {adc_data_xq[10:0],sol_adc_sdin} :
                         adc_shift_xz && ~fast_xq ? {adc_data_xq[10:0],bb_adc_sdin}  :
                                                     adc_data_xq;

	// Conversion is done after 14 clocks.
wire adc_data_val_xd = (adc_cnt_xq == 4'hE) && (div_cnt_xq == 5'h1);

always @(posedge tx_clk) begin
   adc_cnt_xq	<= adc_cnt_xd;
   adc_data_xq	<= adc_data_xd & {12{tx_rst_n}} ;
end


always @(posedge tx_clk or negedge tx_rst_n) begin
   if (~tx_rst_n) begin
      cs_xq		<= 1'b0;
      fast_xq		<= 1'b0;
      div_cnt_xq	<= {5{1'b0}};
      adc_data_val_xq	<= 1'b0;
      adc_clk_xq	<= 1'b1;
   end else begin
      cs_xq		<= cs_xd;
      fast_xq		<= fast_xd;
      div_cnt_xq	<= div_cnt_xd;
      adc_data_val_xq	<= adc_data_val_xd;
      adc_clk_xq	<= adc_clk_xd;
   end
end

assign
   adc_cs_n = ~cs_xq,
   adc_clk  = adc_clk_xq;

endmodule
