`timescale 1ns/1ps

module i2c_master #(
    parameter CLK_FREQ = 1000,
    parameter I2C_FREQ = 100
)(
    input  wire       clk,
    input  wire       reset,

    input  wire       start,
    input  wire [6:0] slave_addr,
    input  wire [7:0] data_in,

    output reg        busy,
    output reg        done,
    output reg        ack_error,

    output wire       scl,
    inout  wire       sda
);

    // ------------------------------------------------
    // CLOCK DIVIDER
    // ------------------------------------------------

    localparam DIVIDER = CLK_FREQ / (I2C_FREQ * 2);

    reg [31:0] clk_count;
    reg tick;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_count <= 0;
            tick <= 0;
        end
        else begin
            if (clk_count == DIVIDER-1) begin
                clk_count <= 0;
                tick <= 1;
            end
            else begin
                clk_count <= clk_count + 1;
                tick <= 0;
            end
        end
    end


    // ------------------------------------------------
    // OPEN DRAIN OUTPUTS
    // ------------------------------------------------

    reg scl_low;
    reg sda_low;

    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;


    // ------------------------------------------------
    // FSM STATES
    // ------------------------------------------------

    localparam IDLE       = 4'd0;
    localparam START      = 4'd1;
    localparam SEND_LOW   = 4'd2;
    localparam SEND_HIGH  = 4'd3;
    localparam SEND_NEXT  = 4'd4;
    localparam ACK_LOW    = 4'd5;
    localparam ACK_HIGH   = 4'd6;
    localparam DATA_LOAD  = 4'd7;
    localparam STOP_LOW   = 4'd8;
    localparam STOP_HIGH  = 4'd9;
    localparam STOP_DONE  = 4'd10;

    reg [3:0] state;

    reg [7:0] shift_reg;
    reg [3:0] bit_count;

    reg address_phase;


    // ------------------------------------------------
    // MAIN FSM
    // ------------------------------------------------

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            state        <= IDLE;

            busy         <= 1'b0;
            done         <= 1'b0;
            ack_error    <= 1'b0;

            scl_low      <= 1'b0;
            sda_low      <= 1'b0;

            shift_reg    <= 8'h00;
            bit_count    <= 4'd0;

            address_phase <= 1'b1;

        end

        else if (tick) begin

            case (state)

                // ------------------------------------
                // IDLE
                // ------------------------------------

                IDLE: begin

                    busy      <= 1'b0;
                    done      <= 1'b0;

                    scl_low   <= 1'b0;
                    sda_low   <= 1'b0;

                    if (start) begin

                        busy          <= 1'b1;
                        ack_error     <= 1'b0;

                        shift_reg     <= {slave_addr,1'b0};

                        bit_count     <= 0;

                        address_phase <= 1'b1;

                        state         <= START;

                    end

                end


                // ------------------------------------
                // START CONDITION
                // ------------------------------------

                START: begin

                    // SCL HIGH
                    // SDA HIGH -> LOW

                    scl_low <= 1'b0;
                    sda_low <= 1'b1;

                    state <= SEND_LOW;

                end


                // ------------------------------------
                // PREPARE DATA BIT
                // ------------------------------------

                SEND_LOW: begin

                    // SCL LOW

                    scl_low <= 1'b1;

                    if (shift_reg[7] == 1'b0)
                        sda_low <= 1'b1;
                    else
                        sda_low <= 1'b0;

                    state <= SEND_HIGH;

                end


                // ------------------------------------
                // CLOCK DATA BIT
                // ------------------------------------

                SEND_HIGH: begin

                    // SCL HIGH

                    scl_low <= 1'b0;

                    state <= SEND_NEXT;

                end


                // ------------------------------------
                // NEXT BIT
                // ------------------------------------

                SEND_NEXT: begin

                    // SCL LOW

                    scl_low <= 1'b1;

                    if (bit_count == 7) begin

                        bit_count <= 0;

                        // Release SDA for ACK
                        sda_low <= 1'b0;

                        state <= ACK_LOW;

                    end

                    else begin

                        shift_reg <= {shift_reg[6:0],1'b0};

                        bit_count <= bit_count + 1'b1;

                        state <= SEND_LOW;

                    end

                end


                // ------------------------------------
                // ACK LOW
                // ------------------------------------

                ACK_LOW: begin

                    // SCL LOW
                    scl_low <= 1'b1;

                    // SDA released
                    sda_low <= 1'b0;

                    state <= ACK_HIGH;

                end


                // ------------------------------------
                // ACK HIGH
                // ------------------------------------

                ACK_HIGH: begin

    // SCL HIGH
    scl_low <= 1'b0;

    // Check ACK
    if (sda != 1'b0)
        ack_error <= 1'b1;

    if (address_phase) begin

        // Address ACK received
        state <= DATA_LOAD;

    end

    else begin

        // Data ACK received
        state <= STOP_LOW;

    end

end


                // ------------------------------------
                // LOAD DATA
                // ------------------------------------

                DATA_LOAD: begin

                    scl_low <= 1'b1;

                    shift_reg <= data_in;

                    bit_count <= 0;

                    address_phase <= 1'b0;

                    state <= SEND_LOW;

                    // After data byte, we need STOP
                    // handled below using address_phase
                end


                // ------------------------------------
                // STOP LOW
                // ------------------------------------

                STOP_LOW: begin

                    scl_low <= 1'b1;
                    sda_low <= 1'b1;

                    state <= STOP_HIGH;

                end


                // ------------------------------------
                // STOP HIGH
                // ------------------------------------

                STOP_HIGH: begin

                    scl_low <= 1'b0;
                    sda_low <= 1'b1;

                    state <= STOP_DONE;

                end


                // ------------------------------------
                // COMPLETE
                // ------------------------------------

                STOP_DONE: begin

                    scl_low <= 1'b0;
                    sda_low <= 1'b0;

                    busy <= 1'b0;
                    done <= 1'b1;

                    state <= IDLE;

                end


                default: begin
                    state <= IDLE;
                end

            endcase

        end
    end

endmodule