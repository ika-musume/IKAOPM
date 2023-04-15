module IKA2151_acc (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_12,
    input   wire            i_CYCLE_29,
    input   wire            i_CYCLE_00_16,
    input   wire            i_CYCLE_06_22,
    input   wire            i_CYCLE_01_TO_16,

    //data
    input   wire            i_NE,
    input   wire    [1:0]   i_RL,

    input   wire            i_ACC_SNDADD,
    input   wire    [13:0]  i_ACC_NOISE,
    input   wire    [13:0]  i_ACC_OPDATA,

    output  reg             o_SO
);



///////////////////////////////////////////////////////////
//////  Cycle number
////

//additional cycle bits
reg             cycle_13, cycle_01_17;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cycle_13 <= i_CYCLE_12;
    cycle_01_17 <= i_CYCLE_00_16;
end



///////////////////////////////////////////////////////////
//////  Sound input MUX / RL acc enable
////

//noise data will be launched at master cycle 12
reg     [13:0]  sound_inlatch;
reg             r_add, l_add;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    sound_inlatch <= (i_NE & i_CYCLE_12) ? i_ACC_NOISE : i_ACC_OPDATA;

    r_add <= i_ACC_SNDADD & i_RL[1];
    l_add <= i_ACC_SNDADD & i_RL[0];
end



///////////////////////////////////////////////////////////
//////  R/L channel accmulators
////

reg     [17:0]  r_accumulator, l_accumulator;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cycle_13)   r_accumulator <= r_add ? {{4{sound_inlatch[13]}}, sound_inlatch}                 : 17'd0;         //reset
    else           r_accumulator <= r_add ? {{4{sound_inlatch[13]}}, sound_inlatch} + r_accumulator : r_accumulator; //accumulation

    if(i_CYCLE_29) l_accumulator <= l_add ? {{4{sound_inlatch[13]}}, sound_inlatch}                 : 17'd0;         //reset
    else           l_accumulator <= l_add ? {{4{sound_inlatch[13]}}, sound_inlatch} + l_accumulator : l_accumulator; //accumulation
end



///////////////////////////////////////////////////////////
//////  R/L PISO register
////

/*
    Sign bit is inverted in this stage.
    11111...(positive max)
    10000...(positive min)
    01111...(negative min)
    00000...(negatice max)
*/

reg     [15:0]  mcyc14_r_piso, mcyc30_l_piso;
reg     [2:0]   mcyc14_r_saturation_ctrl, mcyc14_l_saturation_ctrl;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cycle_13) begin
        mcyc14_r_piso <= {~r_accumulator[17], r_accumulator[14:0]}; //FLIP THE SIGN BIT!!
        mcyc14_r_saturation_ctrl <= r_accumulator[17:15];
    end

    if(i_CYCLE_29) begin
        mcyc30_l_piso <= {~l_accumulator[17], l_accumulator[14:0]}; //FLIP THE SIGN BIT!!
        mcyc30_l_saturation_ctrl <= l_accumulator[17:15];
    end
end



///////////////////////////////////////////////////////////
//////  R/L Saturation control
////

reg             mcyc15_r_stream, mcyc31_l_stream;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    case(r_saturation_ctrl)
        3'b000: mcyc15_r_stream <= mcyc14_r_piso[0];
        3'b001: mcyc15_r_stream <= 1'b1; //saturated to positive maximum
        3'b010: mcyc15_r_stream <= 1'b1;
        3'b011: mcyc15_r_stream <= 1'b1;
        3'b100: mcyc15_r_stream <= 1'b0; //saturated to negative maximum
        3'b101: mcyc15_r_stream <= 1'b0;
        3'b110: mcyc15_r_stream <= 1'b0;
        3'b111: mcyc15_r_stream <= mcyc14_r_piso[0];
    endcase

    if(i_CYCLE_29) {l_saturation_ctrl, l_piso} <= l_accumulator;
end



///////////////////////////////////////////////////////////
//////  R/L Saturation control
////

reg             mcyc16_r_stream_z, mcyc17_r_stream_zz;
reg             mcyc16_l_stream_z, mcyc17_l_stream_zz;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    mcyc16_r_stream_z <= mcyc15_r_stream;
    mcyc16_l_stream_z <= mcyc15_l_stream;
    mcyc17_r_stream_zz <= mcyc16_r_stream_z;
    mcyc17_l_stream_zz <= mcyc16_l_stream_z;
end



///////////////////////////////////////////////////////////
//////  SIPO/SO register
////

reg     [20:0]  sound_data_lookaround_register;
reg     [6:0]   sound_data_bit_15_9;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    //Serial sound data is placed on the MSB register at master cycle == 17. It flows in from the LSB.
    sound_data_lookaround_register[20] <= i_CYCLE_00_TO_16 ? mcyc17_l_stream_zz : mcyc17_r_stream_zz; //sound data LSB is latched at master cycle 18
    sound_data_lookaround_register[19:0] <= sound_data_lookaround_register[20:1];

    if(cycle_01_17) sound_data_bit_15_9 <= sound_data_lookaround_register[20:14];
end



///////////////////////////////////////////////////////////
//////  Output MUX
////







endmodule