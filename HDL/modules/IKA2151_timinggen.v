module IKA2151_timinggen
(
    //chip clock
    input   wire            i_EMUCLK, //emulator master clock

    //chip reset
    input   wire            i_IC_n,
    output  reg             o_MRST_n = 1'b0, //core internal reset

    input   wire            i_phiM_PCEN_n, //phiM clock enable

    //phiM/2
    output  wire            o_phi1, //phi1 output
    output  wire            o_phi1_PCEN_n, //positive edge clock enable for emulation
    output  wire            o_phi1_NCEN_n, //engative edge clock enable for emulation

    //SH1 and 2
    output  reg             o_SH1,
    output  reg             o_SH2,

    //timings
    output  reg             o_CYCLE_01,
    output  reg             o_CYCLE_31,

    output  reg             o_CYCLE_12_28,
    output  reg             o_CYCLE_05_21,
    output  reg             o_CYCLE_BYTE,

    output  reg             o_CYCLE_05,
    output  reg             o_CYCLE_10,

    output  reg             o_CYCLE_03,
    output  reg             o_CYCLE_00_16,
    output  reg             o_CYCLE_01_TO_16,

    output  reg             o_CYCLE_03_11_19_27,

    output  reg             o_CYCLE_12,
    output  reg             o_CYCLE_15_31
);

///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = o_phi1_PCEN_n;
wire            phi1ncen_n = o_phi1_NCEN_n;
wire            mrst_n = o_MRST_n;




///////////////////////////////////////////////////////////
//////  Reset generator
////

//2 stage SR for synchronization
reg     [1:0]   ic_n_internal = 2'b00;
always @(posedge i_EMUCLK) begin
    if(!i_phiM_PCEN_n) begin ic_n_internal[0] <= i_IC_n; 
                             ic_n_internal[1] <= ic_n_internal[0]; end //shift
end

//ICn falling edge detector for phi1 phase initialization
reg             phi1_init = 1'b1;
always @(posedge i_EMUCLK) begin
    if(!i_phiM_PCEN_n) phi1_init <= ~ic_n_internal[0] & ic_n_internal[1];
end

//internal master reset
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) o_MRST_n <= ic_n_internal[0];
end




///////////////////////////////////////////////////////////
//////  phi1 and clock enables generator
////

/*
    CLOCKING INFORMATION(ORIGINAL CHIP)
    
    phiM        _______|¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    ICn         ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    ICn neg     ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    ICn pos     ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    IC          _________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|__________________________________________________
    IC neg det  _________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________________________________________

    phi1        ¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________


    (FPGA)    
    EMUCLK      ¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|
    phiM cen    ¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯
    phiM        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|

    phi1p       ¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________
    phi1n       _______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯
*/

//actual phi1 output is phi1p(positive), and the inverted phi1 is phi1n(negative)
reg             phi1p = 1'b1; //for FPGA
reg             phi1n = 1'b0;
always @(posedge i_EMUCLK) begin
    if(!i_phiM_PCEN_n) begin
        if(phi1_init)   begin phi1p <= 1'b1;   phi1n <= 1'b0;   end //reset
        else            begin phi1p <= ~phi1p; phi1n <= ~phi1n; end //toggle
    end
end

//phi1 output(for reference)
assign  o_phi1 = phi1p;

//phi1 cen(internal)
assign  o_phi1_PCEN_n = phi1p | i_phiM_PCEN_n; //ORed signal
assign  o_phi1_NCEN_n = phi1n | i_phiM_PCEN_n | phi1_init;




///////////////////////////////////////////////////////////
//////  Timing Generator
////

//
//  counter
//

reg     [4:0]   timinggen_cntr = 5'h0;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        if(!mrst_n) begin
            timinggen_cntr <= 5'h0;
        end
        else begin
            if(timinggen_cntr == 5'h1F) timinggen_cntr <= 5'h0;
            else                        timinggen_cntr <= timinggen_cntr + 5'h1;
        end
    end
end


//
//  decoder
//

//sh1/sh2
wire            sh1 = timinggen_cntr[4:3] == 2'b11; //11XXX
wire            sh2 = timinggen_cntr[4:3] == 2'b01; //01XXX

//REG
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        o_CYCLE_01          <= timinggen_cntr == 5'd0;
        o_CYCLE_31          <= timinggen_cntr == 5'd30;
    end
end

//LFO
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        o_CYCLE_12_28 <= (timinggen_cntr == 5'd11) | (timinggen_cntr == 5'd27);
        o_CYCLE_05_21 <= (timinggen_cntr == 5'd4) | (timinggen_cntr == 5'd20);
        o_CYCLE_BYTE  <= (timinggen_cntr[3:1] == 3'b111) |
                         (timinggen_cntr[3:1] == 3'b010) |
                         (timinggen_cntr[3:2] == 2'b00);
    end
end

//PG
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        o_CYCLE_05          <= timinggen_cntr == 5'd4;
        o_CYCLE_10          <= timinggen_cntr == 5'd9;
    end
end

//EG
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        o_CYCLE_03          <= timinggen_cntr == 5'd2;
        o_CYCLE_00_16       <= (timinggen_cntr == 5'd31) | (timinggen_cntr == 5'd15);
        o_CYCLE_01_TO_16    <= ~timinggen_cntr[4];
    end
end

//OP
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        o_CYCLE_03_11_19_27 <= (timinggen_cntr == 5'd2) | (timinggen_cntr == 5'd10) | (timinggen_cntr == 5'd19) | (timinggen_cntr == 5'd27);
    end
end

//noise
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        o_CYCLE_12          <= timinggen_cntr == 5'd11;
        o_CYCLE_15_31       <= (timinggen_cntr == 5'd14) | (timinggen_cntr == 5'd30);
    end
end





///////////////////////////////////////////////////////////
//////  SH1 / SH2
////

reg     [4:0]   sh1_sr, sh2_sr;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        //sh1/2 shift register
        sh1_sr[0] <= sh1;
        sh2_sr[0] <= sh2;

        sh1_sr[4:1] <= sh1_sr[3:0];
        sh2_sr[4:1] <= sh2_sr[3:0];

        //sh1/2 output
        o_SH1 <= sh1_sr[4] & mrst_n;
        o_SH2 <= sh2_sr[4] & mrst_n;
    end
end

endmodule