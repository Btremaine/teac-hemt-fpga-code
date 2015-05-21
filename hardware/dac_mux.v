//////////////////////////////////////////////////////////////////////////
// Module: dac_mux                                                      //
// Description: This module provides the interface to the TI            //
//              DAC081S101 for 3 modules. This is a 10 bit serial       //
//					 DAC used to set the various offsets.                    //
//              The maximum frequency is 30MHz.                         //
//////////////////////////////////////////////////////////////////////////

// revised: 3/7/2015 bpt

`include "..\include\timescale.v"
`include "..\include\defines.v"

module dac_mux (
         // inputs
			input [7:0]idac_data_xq,   // latched 8-bit data bus from NI controller
			input start_dac1,  			// control bit 1
			input start_dac2,  			// control bit 2
			input start_dac3,  			// control bit 3
			input sp_clk,					// master clk
			input sp_rst_n,    			// reset/
			input ale, 						// data enable (active low)
			// outputs                  
			output idac_clk1,  			// DAC081 clock1
			output idac_cs_n1,			// DAC081 sync_n1 
			output idac_sdout1,      	// DAC081 data_in1
			output [7:0] dout_w1,      // data bus out1
			//
			output idac_clk2,  			// DAC081 clock2
			output idac_cs_n2,			// DAC081 sync_n2 
			output idac_sdout2,      	// DAC081 data_in2
			output [7:0] dout_w2, 		// data bus out2
			//
			output idac_clk3,  			// DAC081 clock3
			output idac_cs_n3,			// DAC081 sync_n3 
			output idac_sdout3,   		// DAC081 data_in3
			output [7:0] dout_w3       // data bus out3

);
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

wire idac_clk ;
wire idac_cs_n ;
wire idac_sdout ;
wire [7:0] dout_w ;
wire [2:0] addr_sel ;
wire start_dac;
wire load;

reg [1:0] select ;
reg start_dac_dly1;
reg start_dac_dly2;

		// ------------------------------------------------------
		// setup select signal - use start_dac1..3 to
		// select mux to direct signals to proper DAC output pins
		// *** ASSUME only one DAC will be set at a time ***
		always @(negedge sp_clk) begin
			if(addr_sel!=3'b000) begin
				case (addr_sel)
				3'b001:	select <= 2'b01 ;
				3'b010:  select <= 2'b10 ;
				3'b100:  select <= 2'b11 ;
				default: select <= 2'b00 ;
				endcase
			end
		end

      always @(posedge sp_clk or negedge sp_rst_n) begin
			if( !sp_rst_n) begin
				start_dac_dly1 <= 1'b0;
                           start_dac_dly2 <= 1'b0;
         end
         else begin
				start_dac_dly1 <= start_dac;
                          start_dac_dly2 <= start_dac_dly1;
			end	
		end
             	
		
		// -------------------------------------------------------
assign addr_sel = ({start_dac3, start_dac2, start_dac1}) ;		
assign start_dac = (addr_sel==2'b00)? 1'b0 : 1'b1;
assign load = start_dac_dly1 & ~start_dac_dly2 ;	

assign idac_clk1 = (select==2'b01)? idac_clk : 1'b0;
assign idac_clk2 = (select==2'b10)? idac_clk : 1'b0;
assign idac_clk3 = (select==2'b11)? idac_clk : 1'b0;

assign idac_cs_n1 = (select==2'b01)? idac_cs_n : 1'b1;
assign idac_cs_n2 = (select==2'b10)? idac_cs_n : 1'b1;
assign idac_cs_n3 = (select==2'b11)? idac_cs_n : 1'b1;

assign idac_sdout1 = (select==2'b01)? idac_sdout : 1'b0;
assign idac_sdout2 = (select==2'b10)? idac_sdout : 1'b0;
assign idac_sdout3 = (select==2'b11)? idac_sdout : 1'b0;

assign dout_w1 = (select==2'b01)? dout_w : 1'b0;
assign dout_w2 = (select==2'b10)? dout_w : 1'b0;
assign dout_w3 = (select==2'b11)? dout_w : 1'b0;

 	
	
// instaniate bias.v   (muxed dac control)
   bias bias1 (
           .idac_data_xq     		(idac_data_xq),      // latched 8-bit data bus from NI controller
           .idac_data_val_xq 		(load ),  		   // decoded control bit from NI controller
           .sp_clk           		(sp_clk),            // master clk
           .sp_rst_n         		(sp_rst_n),   			// reset/
           .ale              	      	(1'b0),       			// data enable (active low)
           //outputs
           .idac_clk         		(idac_clk),  			// DAC081 clock
           .idac_cs_n        		(idac_cs_n),			// DAC081 sync_n 
           .idac_sdout       		(idac_sdout),   		// DAC081 data_in
           .dout_w          		(dout_w)             // data bus out
          );

endmodule
