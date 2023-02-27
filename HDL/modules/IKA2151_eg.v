module IKA2151_eg
(
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_31,
    input   wire            i_CYCLE_00_16,
    input   wire            i_CYCLE_01_TO_16,

    //register data
    input   wire            i_KON, //key on
    input   wire    [1:0]   i_KS,  //key scale
    input   wire    [4:0]   i_AR,  //attack rate
    input   wire    [4:0]   i_D1R, //first decay rate
    input   wire    [4:0]   i_D2R, //second decay rate
    input   wire    [4:0]   i_RR,  //release rate
    input   wire    [3:0]   i_D1L, //first decay level
    input   wire    [3:0]   i_TL,  //total level
    input   wire    [7:0]   i_LFA, //amplitude modulation from LFO
    input   wire    [7:0]   i_TEST, //test register

    //output data
    output  wire    [9:0]   o_OP_ENV_LEVEL, //envelope level
    output  wire            o_NOISE_ENV_LEVEL, //envelope level(for noise module)
    output  wire            o_REG_ENV_CH8_C2 //noise envelope level
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Cycle number
////

//additional cycle bits
reg             cycle_01_17;
reg             cycle_
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cycle_01_17 <= i_CYCLE_00_16;
    end
end



///////////////////////////////////////////////////////////
//////  Third sample flag
////

reg     [1:0]   samplecntr;
wire            third_sample = samplecntr[1] | i_TEST[0];

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        if(!i_MRST_n) begin
            samplecntr <= 2'd0;
        end
        else begin
            if(i_CYCLE_31) begin
                if(samplecntr == 2'd2) samplecntr <= 2'd0;
                else samplecntr <= samplecntr + 2'd1;
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  Attenuation rate generator
////

reg     [1:0]   timecntr_adder;
reg     [14:0]  timecntr_sr;

reg             onebit_det, mrst_dlyd;
reg     [3:0]   conseczerobitcntr;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        //adder
        timecntr_adder <= ((third_sample & i_CYCLE_01_TO_16) & (cycle_01_17 | timecntr_adder[1]) + 
                           timecntr_sr[0]) & i_MRST_n;

        //sr
        timecntr_sr[14] <= timecntr_adder[0];
        timecntr_sr[13:0] <= timecntr_sr[14:1];

        //consecutive zero bits counter
        mrst_dlyd <= ~mrst_n; //delay master reset, to synchronize the reset timing with timecntr_adder register

        if(mrst_dlyd | cycle_01_17) begin
            onebit_det <= 1'b0;
            conseczerobitcntr <= 4'd0;
        end
        else begin
            if(!onebit_det) begin
                if(timecntr_adder[0]) begin
                    onebit_det <= 1'b1;
                    conseczerobitcntr <= conseczerobitcntr;
                end
                else begin
                    onebit_det <= 1'b0;
                    conseczerobitcntr <= conseczerobitcntr + 4'd1;
                end
            end
        end
    end
end

reg     [1:0]   envcntr;
reg     [3:0]   attenrate;

always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) begin //positive edge!!!!
        if(third_sample & ~i_CYCLE_01_TO_16 & cycle_01_17) begin
            envcntr <= timecntr_sr[2:1];

            attenrate <= conseczerobitcntr;
        end
    end
end


endmodule