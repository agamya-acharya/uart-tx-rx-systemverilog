// UART transmitter, 8N1 (8 data bits, no parity, 1 stop bit)
// Line is high when idle. Frame: start(0), 8 data bits LSB first, stop(1).
// CLKS_PER_BIT = clock frequency / baud rate (e.g. 100_000_000 / 9600 = 10417)
module uart_tx #(
    parameter int CLKS_PER_BIT = 10417
) (
    input  logic       clk,
    input  logic       rst,       // synchronous, active high
    input  logic       tx_start,  // 1-cycle pulse: begin sending tx_data
    input  logic [7:0] tx_data,
    output logic       tx,        // serial output line
    output logic       tx_busy    // high while a frame is being sent
);

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic [15:0] clk_cnt;   // counts clock cycles within one bit time
    logic [2:0]  bit_idx;   // which data bit is being sent (0..7)
    logic [7:0]  shreg;     // copy of the byte being sent

    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= IDLE;
            tx      <= 1'b1;
            tx_busy <= 1'b0;
            clk_cnt <= '0;
            bit_idx <= '0;
            shreg   <= '0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_cnt <= '0;
                    bit_idx <= '0;
                    if (tx_start) begin
                        shreg   <= tx_data;
                        tx_busy <= 1'b1;
                        tx      <= 1'b0;      // start bit
                        state   <= START;
                    end
                end

                START: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= '0;
                        tx      <= shreg[0];  // first data bit (LSB)
                        state   <= DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= '0;
                        if (bit_idx == 3'd7) begin
                            tx    <= 1'b1;    // stop bit
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                            tx      <= shreg[bit_idx + 1'b1];
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= '0;
                        tx_busy <= 1'b0;
                        state   <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
