// ============================================================
//  UART Controller — Combined Design File for EDA Playground
//  Contains: uart_tx, uart_rx, uart_top
//  Paste this entire file into the Design panel on EDA Playground
// ============================================================


// ============================================================
//  Module  : uart_tx  (UART Transmitter)
// ============================================================
module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam DONE  = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            tx          <= 1'b1;
            tx_busy     <= 1'b0;
            tx_done     <= 1'b0;
            clk_count   <= 16'd0;
            bit_index   <= 3'd0;
            tx_data_reg <= 8'd0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (tx_start) begin
                        tx_data_reg <= tx_data;
                        tx_busy     <= 1'b1;
                        state       <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 16'd0;
                        state     <= DATA;
                    end
                end

                DATA: begin
                    tx <= tx_data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 16'd0;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 16'd0;
                        state     <= DONE;
                    end
                end

                DONE: begin
                    tx_done <= 1'b1;
                    tx_busy <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule


// ============================================================
//  Module  : uart_rx  (UART Receiver)
// ============================================================
module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_done,
    output reg        rx_error
);
    localparam CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
    localparam CLKS_HALF_BIT = CLKS_PER_BIT / 2;

    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam DONE  = 3'd4;

    // 2-FF synchronizer
    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end
    wire rx_stable = rx_sync2;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            clk_count   <= 16'd0;
            bit_index   <= 3'd0;
            rx_data_reg <= 8'd0;
            rx_data     <= 8'd0;
            rx_done     <= 1'b0;
            rx_error    <= 1'b0;
        end else begin
            rx_done  <= 1'b0;
            rx_error <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (rx_stable == 1'b0)
                        state <= START;
                end

                START: begin
                    if (clk_count < CLKS_HALF_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 16'd0;
                        if (rx_stable == 1'b0)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end
                end

                DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 16'd0;
                        rx_data_reg[bit_index] <= rx_stable;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 16'd0;
                        state     <= DONE;
                        if (rx_stable == 1'b1)
                            rx_data  <= rx_data_reg;
                        else
                            rx_error <= 1'b1;
                    end
                end

                DONE: begin
                    rx_done <= 1'b1;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule


// ============================================================
//  Module  : uart_top  (Top-level wrapper)
// ============================================================
module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx,
    output wire       tx_busy,
    output wire       tx_done,
    input  wire       rx,
    output wire [7:0] rx_data,
    output wire       rx_done,
    output wire       rx_error
);
    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_tx (
        .clk(clk), .rst_n(rst_n), .tx_start(tx_start),
        .tx_data(tx_data), .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx(rx),
        .rx_data(rx_data), .rx_done(rx_done), .rx_error(rx_error)
    );
endmodule
