
`include "timescale.v"

module tb_i2c_infc ();
reg 		sp_clk;
reg 		sp_rst_n;
reg		i2c_en_xq;
reg		i2c_read_xq;
reg[7:0]	i2c_adr_xq;
reg[7:0]	i2c_wdata_xq;

tri1		i2c_sda;   
tri1 		i2c_scl;
wire		i2c_cs;
wire[7:0]	i2c_rdata_xq;

initial begin
   sp_clk		= 1'b0;
   sp_rst_n		= 1'b0;
   i2c_en_xq		= 1'b0;
   i2c_read_xq		= 1'b0;
   i2c_adr_xq		= 8'h21;
   i2c_wdata_xq		= 8'hf6;
   #50
   sp_rst_n		= 1'b1;
   @(posedge sp_clk); 
   i2c_en_xq		= 1'b1;
   @(posedge sp_clk); 
   i2c_en_xq		= 1'b0;
   @(posedge sp_clk); 
   @(posedge sp_clk); 
   wait (~i2c_cs);
   repeat(500) @(posedge sp_clk); 
   i2c_adr_xq		= 8'hab;
   i2c_read_xq		= 1'b1;
   i2c_en_xq		= 1'b1;
   @(posedge sp_clk); 
   i2c_en_xq		= 1'b0;
   @(posedge sp_clk); 
   @(posedge sp_clk); 
   wait (~i2c_cs);
   repeat (500) @(posedge sp_clk); 
   $finish;
end

	// Generate 100MHz clock.
always sp_clk = #5 ~sp_clk;

i2c_infc u_i2c_intf (
   .clk_ip		(sp_clk),
   .rst_n_ip		(sp_rst_n),
   .i2c_enb_ip		(i2c_en_xq),
   .i2c_rw_ip		(i2c_read_xq),
   .i2c_reg_adr_ip	(i2c_adr_xq),
   .i2c_wdata_ip	(i2c_wdata_xq),
   .i2c_rd_data_op	(i2c_rdata_xq),
   .scl_op		(i2c_scl),
   .sda_io		(i2c_sda),
   .i2c_tx_active_op	(i2c_cs)
);

reg		i2c_sda_xq;	// Registered I2C data pin
reg		busy_xq = 1'b0;	// Slave transaction started
reg[7:0]	data_xq = 8'h0;	// Data received
reg[3:0]	bit_cnt_xq;	// Count bits received
reg[2:0]	byte_cnt_xq;	// Count bytes received
reg		drive_ack_xq;	// Drive acknowledge
reg[7:0]	slave_id_xq;
reg[7:0]	adr_xq;
reg[7:0]	wdata_xq;

	// Start condition when clock is high and data transitions high to low.
wire start_xz = i2c_scl && ~i2c_sda && i2c_sda_xq;

	// Stop condition when clock is high and data transitions low to high.
wire stop_xz = i2c_scl &&  i2c_sda && ~i2c_sda_xq;

	// Busy once started until stopped.
wire busy_xd = (start_xz || busy_xq) && ~stop_xz;

	// Shift in I2C data.
wire[7:0] data_xd = {data_xq[6:0],i2c_sda};

	// Drive acknowledge after receiving slave address.
wire drive_ack_xd = (bit_cnt_xq == 4'h8);

	// Bytes is received after 8 bits.
wire byte_done_xz = (bit_cnt_xq == 4'h8);

	// Count bits received.
wire[3:0] bit_cnt_xd = byte_done_xz ? 4'h0 : bit_cnt_xq + 1'b1;

	// Count bytes received.
wire[2:0] byte_cnt_xd = byte_done_xz ? byte_cnt_xq + 1'b1 : byte_cnt_xq;

wire[7:0] slave_id_xd = byte_done_xz && (byte_cnt_xq == 3'h0) ? data_xq : slave_id_xq;
wire[7:0] adr_xd = byte_done_xz && (byte_cnt_xq == 3'h1) ? data_xq : adr_xq;
wire[7:0] wdata_xd = byte_done_xz && (byte_cnt_xq == 3'h2) ? data_xq : wdata_xq;

	// Drive data pin low for acknowledge.
assign i2c_sda = drive_ack_xq ? 1'b0 : 1'bz;

always @(posedge sp_clk) begin
   i2c_sda_xq	<= i2c_sda;
   busy_xq	<= busy_xd;
   slave_id_xq	<= slave_id_xd;
   adr_xq	<= adr_xd;
   wdata_xq	<= wdata_xd;
end
always @(posedge i2c_scl or posedge start_xz) begin
   if (start_xz && ~busy_xq) begin
      data_xq		<= 8'h0;
      bit_cnt_xq	<= 4'h0;
      byte_cnt_xq	<= 3'h0;
   end else begin
      data_xq		<= data_xd;
      bit_cnt_xq	<= bit_cnt_xd;
      byte_cnt_xq	<= byte_cnt_xd;
   end
end
always @(negedge i2c_scl or negedge sp_rst_n) begin
   if (~sp_rst_n) begin
      drive_ack_xq	<= 1'b0;
   end else begin
      drive_ack_xq	<= drive_ack_xd;
   end
end
endmodule
