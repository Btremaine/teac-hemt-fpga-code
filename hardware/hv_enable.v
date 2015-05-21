//  Project  : TAEC FPGA
//  Module   : hv_enable.v

//  Parent   : hemt_top.v 
//  Children : 

//  Description: 

//     This module controls then channel high voltage enables
//     1. enable a selected channel from the ni_interface
//     2. overide any enable with an alarm if the alarm trip is set.

//  Parameters:

//  None

//  Notes    :  Modified 8/31/2014 btremaine


`include "..\include\timescale.v"
`include "..\include\defines.v"

//-----------------------------------------------------------------------

module hv_enable(
           // Inputs
           input [4:0] addr,      // channel selection
           input din,                // chan state (on/off, active high)
           input [19:0] trip,     // channel trip signals (active high)
           input enable_cntl,     // cmnd to change enables
           input clk,             // master fpga clk
           input rst_n,           // synchronized reset active low
           // Outputs
           output reg [19:0] hv_en_n, // data out bus (to reg)
           output reg [19:0] alarm    // latched alarm status
) ;


always @(posedge clk) begin


    if(!rst_n) begin
         hv_en_n <= 16'hFFFF ;
         alarm <= 16'h0000 ;
    end

     alarm <= trip ;

    if( enable_cntl & rst_n) begin   // TEST chan 0 no trip
    case ( addr[4:0])
         5'b00000:   hv_en_n[0] <=  ~din; // (~din | trip[0]) ;
         5'b00001:   hv_en_n[1] <=  ~din; // (~din | trip[1]) ;
         5'b00010:   hv_en_n[2] <=  ~din; //(~din | trip[2]) ;
         5'b00011:   hv_en_n[3] <=  ~din; //(~din | trip[3]) ;
         5'b00100:   hv_en_n[4] <=  ~din; //(~din | trip[4]) ;
         5'b00101:   hv_en_n[5] <=  ~din; //(~din | trip[5]) ; 
         5'b00110:   hv_en_n[6] <=  ~din; //(~din | trip[6]) ; 
         5'b00111:   hv_en_n[7] <=  ~din; //(~din | trip[7]) ; 
         5'b01000:   hv_en_n[8] <=  ~din; //(~din | trip[8]) ; 
         5'b01001:   hv_en_n[9] <=  ~din; //(~din | trip[9]) ; 
         5'b01010:   hv_en_n[10] <= ~din; //(~din | trip[10]) ; 
         5'b01011:   hv_en_n[11] <= ~din; //(~din | trip[11]) ; 
         5'b01100:   hv_en_n[12] <= ~din; //(~din | trip[12]) ; 
         5'b01101:   hv_en_n[13] <= ~din; //(~din | trip[13]) ; 
         5'b01110:   hv_en_n[14] <= ~din; //(~din | trip[14]) ; 
         5'b01111:   hv_en_n[15] <= ~din; //(~din | trip[15]) ; 
         5'b10000:   hv_en_n[16] <= ~din; //(~din | trip[16]) ; 
         5'b10001:   hv_en_n[17] <= ~din; //(~din | trip[17]) ; 
         5'b10010:   hv_en_n[18] <= ~din; //(~din | trip[18]) ; 
         5'b10011:   hv_en_n[19] <= ~din; //(~din | trip[19]) ; 
         5'b10100:   hv_en_n[19:0] <= ({20{~din}}); //({20{~din}} | trip) ;    // 20==set all 
         default:    hv_en_n[0] <=  (~din | trip[0]) ; 
    endcase
    end


end


endmodule