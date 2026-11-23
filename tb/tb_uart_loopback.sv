`timescale 1ns/1ps
// Self-checking loopback testbench: TX output wired to RX input.
// Small CLKS_PER_BIT keeps simulation fast; use the real value for synthesis.
module tb_uart_loopback;

    localparam int CLKS_PER_BIT = 8;

    logic       clk = 0;
    logic       rst;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       line;           // the serial wire connecting TX to RX
    logic       tx_busy;
    logic [7:0] rx_data;
    logic       rx_valid, frame_err;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;       // 100 MHz

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
        .tx(line), .tx_busy(tx_busy));

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk(clk), .rst(rst), .rx(line),
        .rx_data(rx_data), .rx_valid(rx_valid), .frame_err(frame_err));

    // Send one byte and check what the receiver gets
    task automatic send_and_check(input logic [7:0] b);
        int timeout;
        begin
            @(posedge clk);
            while (tx_busy) @(posedge clk);
            tx_data  <= b;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;

            timeout = 0;
            while (!rx_valid && !frame_err && timeout < 20 * CLKS_PER_BIT) begin
                @(posedge clk);
                timeout++;
            end

            checks++;
            if (timeout >= 20 * CLKS_PER_BIT) begin
                errors++;
                $display("FAIL: timeout sending 0x%02h", b);
            end else if (frame_err) begin
                errors++;
                $display("FAIL: framing error sending 0x%02h", b);
            end else if (rx_data !== b) begin
                errors++;
                $display("FAIL: sent 0x%02h, received 0x%02h", b, rx_data);
            end else begin
                $display("PASS: 0x%02h", b);
            end
        end
    endtask

    initial begin
        $dumpfile("uart_loopback.vcd");
        $dumpvars(0, tb_uart_loopback);

        rst = 1; tx_start = 0; tx_data = 0;
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (5) @(posedge clk);

        // Corner cases
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h55);
        send_and_check(8'hAA);
        send_and_check(8'h41);   // 'A'
        send_and_check(8'h01);
        send_and_check(8'h80);

        // Random bytes, back to back
        repeat (30) send_and_check($urandom_range(0, 255));

        if (errors == 0) $display("ALL TESTS PASSED (%0d checks)", checks);
        else             $display("TESTS FAILED: %0d of %0d", errors, checks);
        $finish;
    end
endmodule
