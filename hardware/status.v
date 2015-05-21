//  Project  : TAEC FPGA
//  Module   : status.v

//  Parent   : hemt_top.v 
//  Children : 

//  Description: 

//     This module processes the status command and packs the 
//     selected data into two 8-bit words to send to the NI interface

//  Parameters:

//  None

//  Notes    :  Modified 3/06/2015 btremaine


`include "..\include\timescale.v"
`include "..\include\defines.v"

//-----------------------------------------------------------------------

module status(
           // Inputs
           input [19:0] ht,        // channel alarm bits
           input hvon,             // hv dc on/off state
           input [19:0] hven_n,    // channel enable bits
           input [7:0] 	bias_dac,  // bias dac
           input [7:0] 	thrsh_dac, // threshold dac
           input [7:0] 	hvdc_dac,  // hv dc dac
           input swin,               // safety switch state
           input gain,               // threshold sense hi/low gain
           input [5:0]addr,          // addr of status word
           input enable_cntl,        // control bit to set status
           input clk,                // master fpga clk
           input rst_n,              // synchronized reset active low
           // Outputs
           output reg [7:0] stat_lsb,// data out bus (to reg)
           output reg [7:0] stat_msb // data out bus (to reg)

) ;

wire [7:0] statwd1;
wire [7:0] statwd2;

assign statwd1 = {4'b0, hven_n[19:16]};
assign statwd2 = {6'b0,hvon,swin};


always @(negedge clk) begin

    if(!rst_n) begin
         stat_lsb <= 8'b0 ;
         stat_msb <= 8'b0;
    end

    // can allow up to 64 status words but using 41.  bpt 1/23/2015
    if( enable_cntl ) begin
    case ( addr[5:0])
	  //    6'b100000:   begin stat_msb <= hven_n[; stat_lsb <= xxxxxxxxxx; end
			6'b100001:   begin stat_msb <=  8'b0; stat_lsb <= statwd2; end
			6'b100010:   begin stat_msb <=  8'b0; stat_lsb <= hvdc_dac[7:0]; end
			6'b100011:   begin stat_msb <=  8'b0; stat_lsb <= bias_dac[7:0]; end
			6'b100100:   begin stat_msb <=  8'b0; stat_lsb <= thrsh_dac[7:0]; end
			6'b100101:   begin stat_msb <=  8'b0; stat_lsb <=  hven_n[19:16]; end
         6'b100110:   begin stat_msb <=  hven_n[15:8]; stat_lsb <=  hven_n[7:0]; end
         6'b100111:   begin stat_msb <=  8'b0 ; stat_lsb <= {4'b0, ht[19:16]}; end
         6'b101000:   begin stat_msb <=  ht[15:8]; stat_lsb <=  ht[7:0] ; end
         6'b101001:   begin stat_msb <=  8'b0; stat_lsb <=  {7'b0,gain} ; end
         default:     begin stat_msb <=  8'b0; stat_lsb <=  8'b0; end
    endcase
    end


end


endmodule