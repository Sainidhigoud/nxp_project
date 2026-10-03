`timescale 1ns/1ps

module i2c_master_tb;

    reg clk;
    reg reset;
    reg start;
    reg [6:0] slave_addr;
    reg [7:0] data_in;

    wire busy;
    wire done;
    wire ack_error;

    tri1 scl;
    tri1 sda;

    reg slave_sda_low;


    // -----------------------------------------
    // DUT
    // -----------------------------------------

    i2c_master #(
        .CLK_FREQ(1000),
        .I2C_FREQ(100)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .slave_addr(slave_addr),
        .data_in(data_in),
        .busy(busy),
        .done(done),
        .ack_error(ack_error),
        .scl(scl),
        .sda(sda)
    );


    // -----------------------------------------
    // Clock generation
    // -----------------------------------------

    always #5 clk = ~clk;


    // -----------------------------------------
    // SIMPLE ACK SLAVE
    //
    // State 5 = ACK_LOW
    // State 6 = ACK_HIGH
    // -----------------------------------------

    always @(*) begin

        if ((dut.state == 4'd5) ||
            (dut.state == 4'd6))

            slave_sda_low = 1'b1;

        else

            slave_sda_low = 1'b0;

    end


    // Slave open-drain output

    assign sda = slave_sda_low ? 1'b0 : 1'bz;


    // -----------------------------------------
    // Test
    // -----------------------------------------

    initial begin

        $dumpfile("i2c_master.vcd");
        $dumpvars(0, i2c_master_tb);

        clk = 0;
        reset = 1;
        start = 0;

        slave_addr = 7'h50;
        data_in = 8'hA5;

        #50;

        reset = 0;

        #50;

        // Start transaction

        start = 1;

        #20;

        start = 0;


        // Wait until DONE becomes 1

        @(posedge done);

        #10;

        $display("--------------------------------");
        $display("I2C MASTER TEST");
        $display("--------------------------------");

        $display("BUSY      = %b", busy);
        $display("DONE      = %b", done);
        $display("ACK ERROR = %b", ack_error);

        if (ack_error == 0)
            $display("TEST PASSED");

        else
            $display("TEST FAILED");

        $display("--------------------------------");

        #50;

        $finish;

    end


    // -----------------------------------------
    // Timeout protection
    // -----------------------------------------

    initial begin

        #20000;

        $display("TIMEOUT: Simulation took too long");

        $finish;

    end

endmodule