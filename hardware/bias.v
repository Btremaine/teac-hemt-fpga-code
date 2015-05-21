//////////////////////////////////////////////////////////////////////////
// Module: idac_intf                                                    //
// Description: This module provides the interface to the TI            //
//              DAC081S101. This is a 10 bit serial DAC used to set     //
//              the PCAL offset. The maximum frequency is 30MHz.     //
//////////////////////////////////////////////////////////////////////////

`include "..\include\timescale.v"

module bias (
   // Outputs
   idac_clk,
   idac_cs_n,
   idac_sdout,
   dout_w,
   // Inputs
   sp_clk,
   sp_rst_n,
   idac_data_xq,
   idac_data_val_xq,
   ale
);

// ++++++++++++++++++++++++++++++++++++++++++++++++++++

output            idac_clk;               // IDAC clock out
output            idac_cs_n;            // IDAC chip select
output            idac_sdout;           // IDAC serial data out
output [7:0]    dout_w;                 // data output

input          sp_clk;                    // Transmit clock
input          sp_rst_n;                     // Serial Port Synchronous Reset
input [7:0]  idac_data_xq;             // Data to send to IDAC
input          idac_data_val_xq;       // Send data to IDAC
input          ale;                             // data enable (active low) 

reg            cs_xq;                        // IDAC chip select
reg[1:0]       div_cnt_xq;              // TX clock divide register
reg[3:0]       idac_cnt_xq;            // Falling edge clock count
reg[12:0]     idac_dout_xq;         // IDAC data out shift register
reg [7:0]      dout;

reg rd_active ;

initial begin
   cs_xq       = 1'b0;
   div_cnt_xq  = 2'h0;
   idac_cnt_xq = 4'h0;
   idac_dout_xq = 15'h0;
end
// ++++++++++++++++++++++++++++++++++++++++++++++++++++

       // Detect falling edge of clock.
wire idac_rising  = (div_cnt_xq == 2'h2);     // bpt
wire idac_falling = (div_cnt_xq == 2'h0) && cs_xq;

       // Set chip select when we get valid data. Reset chip select
       // cycle after 16 falling edges.
// ## fixed error next line *!ale* 9/2/14 bpt
wire cs_xd = ((idac_data_val_xq && !ale) || cs_xq) && ~((idac_cnt_xq == 4'hF) && idac_falling);

       // Divide 100MHz clock by 4 to get 25MHz clock.
wire[1:0] div_cnt_xd = ~cs_xd ? 2'h0 : div_cnt_xq + 1'b1;

       // Increase clock count every falling edge clock cycle.
wire[3:0] idac_cnt_xd = ~cs_xq        ? {4{1'b0}}          :
                         idac_falling ? idac_cnt_xq + 1'b1 :
                                        idac_cnt_xq;

       // Shift out IDAC data. First and last 2 bits xx. 13:12 is mode. 00 is
       // normal operation. Need 1 extra leading bit because data is shifted
       // on first rising clock. Don't need 2 lower LSBs because they are
       // zero.
wire[12:0] idac_dout_xd = idac_data_val_xq ? {5'h0,idac_data_xq}  :
                          idac_rising      ? {idac_dout_xq[11:0],1'b0} :
                                              idac_dout_xq;

always @(posedge sp_clk) begin
   if (~sp_rst_n) begin
      cs_xq            <= 1'b0;
      div_cnt_xq       <= {2{1'b0}};
      idac_cnt_xq      <= {4{1'b0}};
      idac_dout_xq     <= {15{1'b0}};
   end else begin
      cs_xq            <= cs_xd;
      div_cnt_xq       <= div_cnt_xd;
      idac_cnt_xq      <= idac_cnt_xd;
      idac_dout_xq     <= idac_dout_xd;
   end
end

always @(negedge sp_clk) begin
    rd_active <= (idac_data_val_xq || rd_active) & ale;
    if( idac_data_val_xq & !ale)
       dout <= idac_data_xq ;
end

assign
   idac_clk   = div_cnt_xq[1],
   idac_cs_n  = ~cs_xq,
   idac_sdout = idac_dout_xq[12];

assign  dout_w = {dout} ; // {8{rd_active}} & {dout}; 9/3/14

endmodule
