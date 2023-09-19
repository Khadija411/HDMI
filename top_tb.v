module test ();
    reg pixclk=0,reset=0;
    wire TMDSp_clock, TMDSn_clock;
    wire [2:0] TMDSp, TMDSn;
top DUT(
    .pixclk(pixclk),
    .reset(reset),
    .TMDSp(TMDSp),
    .TMDSn(TMDSn),
    .TMDSp_clock(TMDSp_clock),
    .TMDSn_clock(TMDSn_clock)
);

always #2 pixclk=~pixclk;

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0,test);

    #2
    reset = 'b1;

    #100000
    $finish();
    $stop();
end

endmodule
