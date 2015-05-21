//  Project  : TAEC FPGA
//  Module   : ni_intf.v

//  Parent   : hemt_top.v 
//  Children : 

//  Description: 

//     This module processes inputs from the NI 6501 interface
//     using multiplexed address/data and ALE

//  Parameters:

//  None

//  Notes    :  Modified  3/10/2015 btremaine

// =================================================================================
//	ADDR[7:2]	ADDR[1:0]					ADDR[7:0]	ADDR[7:0]	ADDR[7:0]		
//	cmd			modifier		#data bytes		byte 1		byte 2		byte 3	mode I2C?
//	0	HV cntl	-				1				d[0]				-				-			w	n
//	1	gain		-				1				d[0]				-				-			w	n
//	2	hv dac	-				1				dac value		-				-			w	n
//	3	bias dac	-				1				dac value		-				-			w	n
//	4	thresh dac	-			1				dac value		-				-			w	n
//	5	chen [19:0]	-			1				d[7] | chan #	-				-			w	n
//	6	adc mux sel	-			1				chan #			-				-			w	n 
// 7 	start_adc -          0                 			-				-			w	n
// 8	set TXR reg				
//	9	set CR reg
// 10	set CTL reg
// 11 read SR reg
// 12	read status
//	13	read HT[7:0]			1	     		d[7:0]		
// 14	set HT[15:8]			1				d[7:0]
// 15 read HT[19:16]			1				{0,0,0,SWin, d[3:0]}
// 16 prescaler low			1
// 17 prescaleer high		1

`include "..\include\timescale.v"
`include "..\include\defines.v"

// -----------------------------------------------------------------------------------
module ni_intf(
      // Inputs
      input [7:0] addr,    	// address/data from NI Cnt'l (NI clk domain)
      input ale,              // Address latch enable  (NI clk domain)
      input mod_sel,          // module select bit
      input clk,              // master fpga clk
      input rst_n,            // synchronized reset active low
      // Outputs
		output reg [7:0] dout,	// data out bus (to reg)
		output reg [7:0] baddr, // buffered ADDR
      output reg [5:0] saddr,
      output reg [1:0] byte_cnt, 
		output set_hven,
		output set_gain,
		output set_hvdac,
		output set_biasdac,
		output set_thrshdac,
		output set_chanen,
		output set_adcmux,
		output set_adc_cnvrt,
		output set_TXR,
		output set_CR,
		output set_CTL,
		output set_SR,
		output set_stat,
		output set_HT1,
		output set_HT2,
		output set_HT3,
		output set_pre_low,
		output set_pre_hi
) ;
// command parameters
parameter 	cmd0 = 6'b000000;
parameter 	cmd1 = 6'b000001;
parameter	cmd2 = 6'b000010;
parameter	cmd3 = 6'b000011;	
parameter 	cmd4 = 6'b000100;
parameter 	cmd5 = 6'b000101;
parameter	cmd6 = 6'b000110;
parameter	cmd7 = 6'b000111;	
parameter 	cmd8 = 6'b001000;
parameter 	cmd9 = 6'b001001;
parameter	cmd10 = 6'b001010;
parameter	cmd11 = 6'b001011;	
parameter 	cmd12 = 6'b001100;
parameter 	cmd13 = 6'b001101;
parameter	cmd14 = 6'b001110;
parameter	cmd15 = 6'b001111;
parameter 	cmd16 = 6'b010000;
parameter 	cmd17 = 6'b010001;


reg mod_sel_dly1 ;
reg [5:0] sel_addr ;

wire [1:0] byte_cnt_d ;
wire select_w;
wire decode_w;
      
        always @ (posedge clk) begin
				mod_sel_dly1 <= mod_sel ;
				byte_cnt <= byte_cnt_d ;		
        end
		  
        always @ (negedge clk) begin
             if ((decode_w & ale) || !rst_n) begin
                  baddr <= addr[7:0] & {8{rst_n}} ;
                  sel_addr[5:0] <= addr[7:2]  & {6{rst_n}} ;  // command word
             end
				 if(byte_cnt == 2'b01 & !ale) begin
					saddr[5:0] <= addr[5:0];
					dout[7:0] <= addr[7:0];
				 end
         end
 
// assignments 
         assign decode_w = ~mod_sel_dly1 & mod_sel ;
         assign select_w =  mod_sel & mod_sel_dly1 ;  
			
			assign byte_cnt_d = (decode_w & !ale) ? ((byte_cnt + 2'b01) & {2{rst_n}})  : (byte_cnt & {2{!ale}}) ;		

         assign set_hven = 		(cmd0==sel_addr[5:0]) & select_w & ~ale;
         assign set_gain = 		(cmd1==sel_addr[5:0]) & select_w & ~ale;
         assign set_hvdac =      (cmd2==sel_addr[5:0]) & select_w & ~ale;  
         assign set_biasdac =   	(cmd3==sel_addr[5:0]) & select_w & ~ale;
         assign set_thrshdac = 	(cmd4==sel_addr[5:0]) & select_w & ~ale;
         assign set_chanen =   	(cmd5==sel_addr[5:0]) & select_w & ~ale; 
         assign set_adcmux =  	(cmd6==sel_addr[5:0]) & select_w & ~ale;
			assign set_adc_cnvrt =  (cmd7==sel_addr[5:0]) & select_w &  ale;
			assign set_TXR =   		(cmd8==sel_addr[5:0]) & select_w & ~ale; 
         assign set_CR =  			(cmd9==sel_addr[5:0]) & select_w & ~ale;
			assign set_CTL =  		(cmd10==sel_addr[5:0]) & select_w & ~ale;
			assign set_SR =  			(cmd11==sel_addr[5:0]) & select_w ; //&  ale;
			assign set_stat =  		(cmd12==sel_addr[5:0]) & select_w & ~ale;
			
			assign set_HT1 =  		(cmd13==sel_addr[5:0]) & select_w & ~ale;
			assign set_HT2 =  		(cmd14==sel_addr[5:0]) & select_w & ~ale;
			assign set_HT3 =  		(cmd15==sel_addr[5:0]) & select_w & ~ale;
			assign set_pre_low =  	(cmd16==sel_addr[5:0]) & select_w & ~ale;
			assign set_pre_hi =  	(cmd17==sel_addr[5:0]) & select_w & ~ale;
					
                                
endmodule