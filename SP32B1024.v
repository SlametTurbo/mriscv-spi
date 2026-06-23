// SP32B1024 untuk mode SPI: TANPA init (RAM kosong, diisi via SPI saat runtime)
module SP32B1024 #(parameter INIT_FILE = "")(
    output reg [31:0] Q, input CLK, input CEN, input WEN, input [9:0] A, input [31:0] D);
    reg [31:0] mem [0:1023];
    integer i;
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
        else for (i=0;i<1024;i=i+1) mem[i]=32'h0;
    end
    always @(posedge CLK) if (CEN==1'b0) begin if (WEN==1'b0) mem[A]<=D; Q<=mem[A]; end
endmodule
