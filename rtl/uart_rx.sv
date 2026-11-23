// UART receiver, 8N1. Samples each bit in the middle of its bit time.
module uart_rx #(
    parameter int CLKS_PER_BIT = 10417
) (
    input  logic       clk,
    input  logic       rst,         // synchronous, active high
    input  logic       rx,          // serial input line
    output logic [7:0] rx_data,     // received byte (valid when rx_valid = 1)
    output logic       rx_valid,    // 1-cycle pulse: a good byte arrived
    output logic       frame_err    // 1-cycle pulse: stop bit was not 1
);

    // Two flip-flops to bring the asynchronous rx line into the clk domain
    logic rx_meta, rx_s;
    always_ff @(posedge clk) begin
        rx_meta <= rx;
        rx_s    <= rx_meta;
    end

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic [15:0] clk_cnt;
    logic [2:0]  bit_idx;

    always_ff @(posedge clk) begin
        rx_valid  <= 1'b0;   // default: pulses last one cycle
        frame_err <= 1'b0;
        if (rst) begin
            state   <= IDLE;
            clk_cnt <= '0;
            bit_idx <= '0;
            rx_data <= '0;
        end else begin
            case (state)
                IDLE: begin
                    clk_cnt <= '0;
                    bit_idx <= '0;
                    if (rx_s == 1'b0) state <= START;   // possible start bit
                end

                START: begin
                    // wait half a bit, then confirm the line is still low
                    if (clk_cnt == (CLKS_PER_BIT - 1) / 2) begin
                        clk_cnt <= '0;
                        if (rx_s == 1'b0) state <= DATA;
                        else              state <= IDLE;   // glitch, ignore
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin
                    // one full bit time later = middle of each data bit
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt          <= '0;
                        rx_data[bit_idx] <= rx_s;
                        if (bit_idx == 3'd7) state <= STOP;
                        else                 bit_idx <= bit_idx + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt   <= '0;
                        rx_valid  <= rx_s;      // good frame if stop bit = 1
                        frame_err <= ~rx_s;
                        state     <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
