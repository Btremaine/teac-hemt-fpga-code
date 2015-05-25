`include "\include\timescale.v"

/*
* This module behaves like  I2C interface
* It shall capture the data bytes when FPGA sends rd/wr cmd
* to the National thru I2C
 */

module i2c_slave_rx (
    input   cs, sclk,
    inout   sda
);


reg	         sda_o;
reg           strt_val,cap_reg_addr,cap_data,send_reg_data,stop_val;    //flags
integer     sl_addr_cnt,sl_reg_cnt,tx_bit_cnt;
reg [7:0]   sl_addr;    //7bit MSB-slave addr; LSB bit - wr/rd
reg [7:0]   reg_addr; //slave reg address
reg [7:0]   rx_data;   //slave reg data received
reg [7:0]   tx_data;   //slave reg data to be sent

assign sda = sda_o;

initial
begin
    sl_addr_cnt     = 0;
    sl_reg_cnt      = 0;
    sda_o           = 1'bz;
    strt_val        = 1'b0;
    cap_reg_addr    = 1'b0;
    cap_data        = 1'b0;
    send_reg_data   = 1'b0;
    stop_val        = 1'b0;
    rx_data         = 8'b0;
    tx_data         = 8'hc3;
end


always @ (negedge sda)
begin
    if (cs && sclk)
    begin
        strt_val = 1'b1;
        stop_val = 1'b0;
    end
end

always @ (posedge sda)
begin
    if (cs && sclk)
    begin
        stop_val        = 1'b1;
        //reset all other flags
        strt_val        = 1'b0;
        cap_reg_addr    = 1'b0;
        cap_data        = 1'b0;
        send_reg_data   = 1'b0;
    end
end

wire busy       = strt_val | cap_reg_addr | cap_data | send_reg_data;

//Capture slave address & send ack
always @ (strt_val)
begin
    if (strt_val)
    begin
        for (sl_addr_cnt=7;sl_addr_cnt>=0;sl_addr_cnt=sl_addr_cnt-1)
        begin
            @ (posedge sclk);
            sl_addr[sl_addr_cnt]=sda;
        end
        @ (negedge sclk);

        if (sl_addr == 8'hAA)
        begin
            $display ("%t i2c_slave_rx: Valid slave addr with WR reqst rxd ---",$time);
            #  3_000 sda_o             = 1'b0; //ACK bit
            @ (negedge sclk);
            # 3_000 sda_o    = 1'bz;
            cap_reg_addr       = 1'b1;
            strt_val = 1'b0;
        end
        else if (sl_addr == 8'hAB) 
        begin
            $display ("%t i2c_slave_rx: Valid slave addr with RD reqst rxd ---",$time);
            #  3_000 sda_o        = 1'b0; //ACK bit
            send_reg_data           = 1'b1;
            strt_val = 1'b0;
        end
        else
        begin
            $display ("%t i2c_slave_rx: Error: Invalid slave addr rxd",$time);
            strt_val = 1'b0;
        end
    end
end

//Capture slave reg address & send ack
always @ (posedge sclk)
begin
    if (cap_reg_addr)
    begin
        for (sl_reg_cnt=7;sl_reg_cnt>=1;sl_reg_cnt=sl_reg_cnt-1)
        begin
            reg_addr[sl_reg_cnt]    = sda_o;
            @ (posedge sclk);
        end
        reg_addr[0] = sda_o;
        @ (negedge sclk);

        # 3_000 sda_o              = 1'b0; //ACK bit        
        @ (negedge sclk);
        #3_000 sda_o    = 1'bz;
        cap_data                = 1'b1;
        cap_reg_addr = 1'b0;
    end
end

always @ (posedge sclk)
begin
    if (cap_data)
    begin
        rx_data[7] = sda_o;
        @ (posedge sclk);
        if (strt_val) //Repeat start indicating I2C read
        begin
            cap_data    = 1'b0;
        end
        else  //I2C write
        begin
            for(sl_reg_cnt=6;sl_reg_cnt>=1;sl_reg_cnt=sl_reg_cnt-1)
            begin
                rx_data[sl_reg_cnt] = sda_o;
                @ (posedge sclk);
            end
            rx_data[0] = sda_o;
            @ (negedge sclk);

            # 3_000 sda_o              = 1'b0; //ACK bit        
            @ (negedge sclk) ;
            #3_000 sda_o    = 1'bz;
            @ (posedge sclk);
            # 3_000; //wait till sclk=high level
           // $display("\nAt time %t, SCL is high now !", $time);
            if (~stop_val)
            begin
                 $display ("%t i2c_slave_rx: Error: Invalid STOP bit rxd ---",$time);
            end
            cap_data    = 1'b0;
        end
    end
end

always @ (negedge sclk)
begin
    if (send_reg_data)
    begin
        // tx_data = $random; //Modified to send the data which is been received.
        for (tx_bit_cnt=7;tx_bit_cnt>=0;tx_bit_cnt=tx_bit_cnt-1)
        begin
            #3_000 sda_o = tx_data[tx_bit_cnt];
            @ (negedge sclk);
        end
        #3_000 sda_o = 1'bz;
        @ (posedge sclk);
        if (sda)
        begin
            $display ("%t i2c_slave_rx: Valid NACK bit rxd",$time);
            @ (posedge sclk);
            # 3_000; //wait till sclk=high level
            if (stop_val)
            begin
                $display ("%t i2c_slave_rx: Valid STOP bit rxd",$time);
                send_reg_data = 1'b0;
            end
            else
            begin
                $display ("%t i2c_slave_rx: Error: Invalid STOP bit rxd",$time);
                send_reg_data = 1'b0;
            end
        end
        else
        begin
            $display ("%t i2c_slave_rx: Invalid NACK bit rxd",$time);
            send_reg_data = 1'b0;
        end
    end
end

endmodule
