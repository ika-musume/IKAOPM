module IKA2151_pg
(
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //register data
    input   wire    [6:0]   i_KC, //Key Code
    input   wire    [5:0]   i_KF, //Key Fraction
    input   wire    [2:0]   i_PMS, //Pulse Modulation Sensitivity
    input   wire    [1:0]   i_DT2, //Detune 2

    //Vibrato
    input   wire    [7:0]   i_LFP
);


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Cycle 0: PMS decoding, ex-LFP conversion
////

//  DESCRIPTION
//The original chip decodes PMS value in this step(we don't need to do it)
//and does extended LFP conversion with few adders.


//
//  combinational part
//

//ex-lfp conversion
wire    [2:0]   cyc0c_ex_lfp_weight0 = (i_PMS == 3'd7) ? i_LFP[6:4]        : {1'b0, i_LFP[6:5]};
wire    [2:0]   cyc0c_ex_lfp_weight1 = (i_PMS == 3'd7) ? {2'b00, i_LFP[6]} : 3'b000;
wire            cyc0c_ex_lfp_weight2 = (i_PMS == 3'd7) ? ((i_LFP[6] & i_LFP[5]) | (i_LFP[5] & i_LFP[4])) : 
                                      (i_PMS == 3'd6) ? (i_LFP[6] & i_LFP[5]) : 1'b0;
wire    [3:0]   cyc0c_ex_lfp_weightsum = cyc0c_ex_lfp_weight0 + cyc0c_ex_lfp_weight1 + cyc0c_ex_lfp_weight2;


//
//  register part
//

reg     [2:0]   cyc0r_pms_level;
reg     [7:0]   cyc0r_ex_lfp;
reg             cyc0r_ex_lfp_sign;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc0r_pms_level <= i_PMS;

        if(i_PMS == 3'd7) cyc0r_ex_lfp <= {cyc0c_ex_lfp_weightsum,      i_LFP[3:0]};
        else              cyc0r_ex_lfp <= {cyc0c_ex_lfp_weightsum[2:0], i_LFP[4:0]};

        //lfp_sign becomes 1 when PMS > 0 and LFP sign is negative to convert lfp_ex to 2's complement
        cyc0r_ex_lfp_sign <= ~((i_PMS == 3'd0) | ~i_LFP[7]); 
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 1: Pitch value calculation
////

//  DESCRIPTION
//The original chip decodes PMS value in this step(we don't need to do it)
//and does extended LFP conversion with few adders.


//
//  combinational part
//

reg     [12:0]  cyc1c_lfp_deviance;
wire    [13:0]  cyc1c_lfp_deviance_debug = (cyc0r_ex_lfp_sign == 1'b1) ? (~cyc1c_lfp_deviance + 7'h1) : cyc1c_lfp_deviance;
always @(*) begin
    case(pms_level)
        3'd0: cyc1c_lfp_deviance <= 13'b0;
        3'd1: cyc1c_lfp_deviance <= {11'b0, cyc0r_ex_lfp[6:5]      };
        3'd2: cyc1c_lfp_deviance <= {10'b0, cyc0r_ex_lfp[6:4]      };
        3'd3: cyc1c_lfp_deviance <= {9'b0,  cyc0r_ex_lfp[6:3]      };
        3'd4: cyc1c_lfp_deviance <= {8'b0,  cyc0r_ex_lfp[6:2]      };
        3'd5: cyc1c_lfp_deviance <= {7'b0,  cyc0r_ex_lfp[6:1]      };
        3'd6: cyc1c_lfp_deviance <= {4'b0,  cyc0r_ex_lfp[7:0], 1'b0};
        3'd7: cyc1c_lfp_deviance <= {3'b0,  cyc0r_ex_lfp[7:0], 2'b0};
    endcase
end

wire    [6:0]   cyc1c_frac_adder      = i_KF      + (cyc1c_lfp_deviance[5:0]  ^ {6{cyc0r_ex_lfp_sign}}) + cyc0r_ex_lfp_sign; 
wire    [7:0]   cyc1c_int_adder       = i_KC      + (cyc1c_lfp_deviance[12:6] ^ {7{cyc0r_ex_lfp_sign}}) + cyc1c_frac_adder[6];
wire    [2:0]   cyc1c_notegroup_adder = i_KC[1:0] + (cyc1c_lfp_deviance[7:6]  ^ {2{cyc0r_ex_lfp_sign}}) + cyc1c_frac_adder[6];
wire    [12:0]  cyc1c_modded_raw_pitchval = (cyc0r_ex_lfp_sign == 1'b0) ? {i_KC, i_KF} + cyc1c_lfp_deviance : {i_KC, i_KF} + ~cyc1c_lfp_deviance + 13'd1;


//
//  register part
//

reg     [12:0]  cyc1r_modded_pitchval; //add or subtract LFP value from KC, KF
reg             cyc1r_modded_pitchval_ovfl;
reg             cyc1r_notegroup_nopmod; //this flag set when no "LFP" addend is given to a "note group" range(note group: 012/456/89A/CDE)
reg             cyc1r_notegroup_ovfl; //note group overflow, e.g. 6(3'b1_10) + 2(3'b0_10)
reg             cyc1r_lfp_sign;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc1r_modded_pitchval      <= {cyc1c_int_adder[6:0], cyc1c_frac_adder[5:0]};

        cyc1r_modded_pitchval_ovfl <= cyc1c_int_adder[7];
        cyc1r_notegroup_noaddend <= ~(cyc1c_lfp_deviance[6] | cyc1c_lfp_deviance[7]);
        cyc1r_notegroup_ovfl <= cyc1c_notegroup_adder[2];

        //bypass
        cyc1r_lfp_sign <= cyc0r_ex_lfp_sign; 
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 2: Notegroup rearrange
////

//  DESCRIPTION
//The pitch value modulated by the LFP value can cause notegroup violation.
//Modify the integer part of this pitch value if it is out of the note group range.
//Notegroup (note group: 012/456/89A/CDE)

//
//  combinational part
//

wire            cyc2c_int_adder_add1 = ((cyc1r_modded_pitchval[7:6] == 2'd3) | cyc1r_notegroup_ovfl) & ~cyc1r_lfp_sign;
wire            cyc2c_int_adder_sub1 = ~(cyc1r_notegroup_noaddend | cyc1r_notegroup_ovfl | ~cyc1r_lfp_sign);
wire    [7:0]   cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + {7{cyc2c_int_adder_sub1}} + cyc2c_int_adder_add1;


//
//  register part
//

reg     [12:0]  cyc2r_rearranged_pitchval;
reg             cyc2r_rearranged_pitchval_ovfl;
reg             cyc2r_modded_pitchval_ovfl;
reg             cyc2r_int_sub1;
reg             cyc2r_lfp_sign;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc2r_rearranged_pitchval <= {cyc2c_int_adder[6:0], cyc1r_modded_pitchval[5:0]};
        cyc2r_rearranged_pitchval_ovfl <= cyc2c_int_adder[7];

        cyc2r_int_adder_sub1 <= cyc2c_int_adder_sub1;

        cyc2r_modded_pitchval_ovfl <= cyc1r_modded_pitchval_ovfl;
        cyc2r_lfp_sign <= cyc1r_lfp_sign;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 3: Overflow control
////

//  DESCRIPTION
//Controls the rearranged pitch values to be saturated.

//
//  register part
//

reg     [12:0]  cyc3r_saturated_pitchval;
reg     [1:0]   cyc3r_dt2; //just delays, the original chip decodes DT2 input here, we don't have to do.

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        casez({cyc2r_lfp_sign, cyc2r_modded_pitchval_ovfl, cyc2r_int_sub1, cyc2r_rearranged_pitchval_ovfl})
            //lfp = positive
            4'b0000: cyc3r_saturated_pitchval <= step2_tuned_pitchval;
            4'b00?1: cyc3r_saturated_pitchval <= 13'b111_1110_111111; //max
            4'b01?0: cyc3r_saturated_pitchval <= 13'b111_1110_111111;
            4'b01?1: cyc3r_saturated_pitchval <= 13'b111_1110_111111;
            4'b0010: cyc3r_saturated_pitchval <= 13'b000_0000_000000; //will never happen

            //lfp = negative
            4'b1000: cyc3r_saturated_pitchval <= 13'b000_0000_000000; //min
            4'b1001: cyc3r_saturated_pitchval <= 13'b000_0000_000000;
            4'b1010: cyc3r_saturated_pitchval <= 13'b000_0000_000000;
            4'b1011: cyc3r_saturated_pitchval <= 13'b000_0000_000000;
            4'b1100: cyc3r_saturated_pitchval <= step2_tuned_pitchval;
            4'b1101: cyc3r_saturated_pitchval <= step2_tuned_pitchval;
            4'b1110: cyc3r_saturated_pitchval <= 13'b000_0000_000000;
            4'b1111: cyc3r_saturated_pitchval <= step2_tuned_pitchval;
        endcase

        cyc3r_dt2 <= i_DT2;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 4: apply DT2 to fractional part
////

//  DESCRIPTION
//Apply DT2 to fractional part of the pitch value
//fixed point, fractional part is 6 bits. 0.015625 step value

//
//  register part
//


reg     [6:0]   cyc4r_frac_detuned_pitchval; //carry + 6bit value
reg     [6:0]   cyc4r_int_pitchval;
reg     [1:0]   cyc4r_dt2;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        case(cyc3_dt2)
            2'd0: cyc4r_frac_detuned_pitchval <= cyc3r_saturated_pitchval[5:0] + 6'd0  + 1'd0;
            2'd1: cyc4r_frac_detuned_pitchval <= cyc3r_saturated_pitchval[5:0] + 6'd0  + 1'd0;
            2'd2: cyc4r_frac_detuned_pitchval <= cyc3r_saturated_pitchval[5:0] + 6'd52 + 1'd0; //fractional part +0.8125
            2'd3: cyc4r_frac_detuned_pitchval <= cyc3r_saturated_pitchval[5:0] + 6'd32 + 1'd0; //fractional part +0.5
        endcase

        cyc4r_int_pitchval <= cyc3r_saturated_pitchval[12:6];

        cyc4r_dt2 <= cyc3r_dt2;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 5: apply DT2 to integer part
////

//  DESCRIPTION
//Apply DT2 to integer part of the pitch value

//
//  register part
//

reg     [5:0]   cyc5r_frac_detuned_pitchval; //no carry here
reg     [7:0]   cyc5r_int_detuned_pitchval; //carry + 7bit value

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        casez({cyc4r_dt2, cyc4r_frac_detuned_pitchval[6], cyc4r_int_pitchval[1:0]})
            //dt2 = 0
            5'd00_0_00: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd0;
            5'd00_0_01: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd0;
            5'd00_0_10: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd0;
            5'd00_0_11: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd0;
            5'd00_1_00: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd0 + 7'd1;
            5'd00_1_01: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd0 + 7'd1;
            5'd00_1_10: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd0 + 7'd2;
            5'd00_1_11: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd0 + 7'd2;
            //                                        |--------base value------| +  dt2 + carry(avoids notegroup violation)

            //dt2 = 1
            5'd01_0_00: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd8;
            5'd01_0_01: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd8;
            5'd01_0_10: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd8;
            5'd01_0_11: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd8;
            5'd01_1_00: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd8 + 7'd1;
            5'd01_1_01: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd8 + 7'd1;
            5'd01_1_10: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd8 + 7'd2;
            5'd01_1_11: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd8 + 7'd2;

            //dt2 = 2
            5'd10_0_00: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd9;
            5'd10_0_01: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd9;
            5'd10_0_10: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd9 + 7'd1;
            5'd10_0_11: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd9 + 7'd1;
            5'd10_1_00: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd9 + 7'd1;
            5'd10_1_01: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd9 + 7'd2;
            5'd10_1_10: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd9 + 7'd2;
            5'd10_1_11: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd9 + 7'd2;

            //dt2 = 3
            5'd11_0_00: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd12;
            5'd11_0_01: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd12;
            5'd11_0_10: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd12;
            5'd11_0_11: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd12;
            5'd11_1_00: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd12 + 7'd1;
            5'd11_1_01: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd12 + 7'd1;
            5'd11_1_10: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd12 + 7'd2;
            5'd11_1_11: cyc5r_int_detuned_pitchval <= cyc5r_int_detuned_pitchval + 7'd12 + 7'd2;
        endcase

        cyc5r_frac_detuned_pitchval <= cyc4r_frac_detuned_pitchval[5:0]; //discard carry
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 6: Overflow control
////

//  DESCRIPTION
//Controls the final pitch values to be saturated.

//
//  register part
//

reg    [12:0]  cyc6r_final_pitchval; //no carry here

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc6r_final_pitchval <= (cyc5r_int_detuned_pitchval[7] == 1'b1) ? 13'b111_1110_111111 : {cyc5r_int_detuned_pitchval[6:0], cyc5r_frac_detuned_pitchval};
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 7: Key code to F-num conversion step 1
////

//  DESCRIPTION
//This ROM has absolute phase increment value(pdelta) and 
//fine tuning value for small phase changes. Now we get the values
//from the conversion table.

//
//  register part
//

reg     [4:0]   cyc7r_pdelta_shift_control;
reg     [11:0]  cyc7r_pdelta_abs_rom;
reg     [4:0]   cyc7r_pdelta_tune_rom;
reg     [3:0]   cyc7r_pdelta_tune_control;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin

        //phase rom
        case(cyc6r_final_pitchval[9:4])
            6'h00: begin cyc7r_pdelta_tune_rom <= 5'b10011; cyc7r_pdelta_abs_rom <= 12'b010100_010011; end
            6'h01: begin cyc7r_pdelta_tune_rom <= 5'b10011; cyc7r_pdelta_abs_rom <= 12'b010100_100110; end
            6'h02: begin cyc7r_pdelta_tune_rom <= 5'b10011; cyc7r_pdelta_abs_rom <= 12'b010100_111001; end
            6'h03: begin cyc7r_pdelta_tune_rom <= 5'b00101; cyc7r_pdelta_abs_rom <= 12'b010101_001100; end
            6'h04: begin cyc7r_pdelta_tune_rom <= 5'b00101; cyc7r_pdelta_abs_rom <= 12'b010101_100000; end
            6'h05: begin cyc7r_pdelta_tune_rom <= 5'b00101; cyc7r_pdelta_abs_rom <= 12'b010101_110100; end
            6'h06: begin cyc7r_pdelta_tune_rom <= 5'b10101; cyc7r_pdelta_abs_rom <= 12'b010110_001000; end
            6'h07: begin cyc7r_pdelta_tune_rom <= 5'b00101; cyc7r_pdelta_abs_rom <= 12'b010110_011101; end
            6'h08: begin cyc7r_pdelta_tune_rom <= 5'b10101; cyc7r_pdelta_abs_rom <= 12'b010110_110010; end
            6'h09: begin cyc7r_pdelta_tune_rom <= 5'b10101; cyc7r_pdelta_abs_rom <= 12'b010111_000111; end
            6'h0A: begin cyc7r_pdelta_tune_rom <= 5'b00111; cyc7r_pdelta_abs_rom <= 12'b010111_011101; end
            6'h0B: begin cyc7r_pdelta_tune_rom <= 5'b00111; cyc7r_pdelta_abs_rom <= 12'b010111_110011; end

            6'h10: begin cyc7r_pdelta_tune_rom <= 5'b00111; cyc7r_pdelta_abs_rom <= 12'b011000_001001; end
            6'h11: begin cyc7r_pdelta_tune_rom <= 5'b00111; cyc7r_pdelta_abs_rom <= 12'b011000_011111; end
            6'h12: begin cyc7r_pdelta_tune_rom <= 5'b10111; cyc7r_pdelta_abs_rom <= 12'b011000_110110; end
            6'h13: begin cyc7r_pdelta_tune_rom <= 5'b10111; cyc7r_pdelta_abs_rom <= 12'b011001_001101; end
            6'h14: begin cyc7r_pdelta_tune_rom <= 5'b10111; cyc7r_pdelta_abs_rom <= 12'b011001_100101; end
            6'h15: begin cyc7r_pdelta_tune_rom <= 5'b01001; cyc7r_pdelta_abs_rom <= 12'b011001_111100; end
            6'h16: begin cyc7r_pdelta_tune_rom <= 5'b01001; cyc7r_pdelta_abs_rom <= 12'b011010_010101; end
            6'h17: begin cyc7r_pdelta_tune_rom <= 5'b01001; cyc7r_pdelta_abs_rom <= 12'b011010_101101; end
            6'h18: begin cyc7r_pdelta_tune_rom <= 5'b11001; cyc7r_pdelta_abs_rom <= 12'b011011_000110; end
            6'h19: begin cyc7r_pdelta_tune_rom <= 5'b11001; cyc7r_pdelta_abs_rom <= 12'b011011_011111; end
            6'h1A: begin cyc7r_pdelta_tune_rom <= 5'b01011; cyc7r_pdelta_abs_rom <= 12'b011011_111001; end
            6'h1B: begin cyc7r_pdelta_tune_rom <= 5'b01011; cyc7r_pdelta_abs_rom <= 12'b011100_010011; end

            6'h20: begin cyc7r_pdelta_tune_rom <= 5'b01011; cyc7r_pdelta_abs_rom <= 12'b011100_101101; end
            6'h21: begin cyc7r_pdelta_tune_rom <= 5'b11011; cyc7r_pdelta_abs_rom <= 12'b011101_001000; end
            6'h22: begin cyc7r_pdelta_tune_rom <= 5'b11011; cyc7r_pdelta_abs_rom <= 12'b011101_100011; end
            6'h23: begin cyc7r_pdelta_tune_rom <= 5'b01101; cyc7r_pdelta_abs_rom <= 12'b011101_111110; end
            6'h24: begin cyc7r_pdelta_tune_rom <= 5'b01101; cyc7r_pdelta_abs_rom <= 12'b011110_011010; end
            6'h25: begin cyc7r_pdelta_tune_rom <= 5'b01101; cyc7r_pdelta_abs_rom <= 12'b011110_110111; end
            6'h26: begin cyc7r_pdelta_tune_rom <= 5'b11101; cyc7r_pdelta_abs_rom <= 12'b011111_010011; end
            6'h27: begin cyc7r_pdelta_tune_rom <= 5'b01111; cyc7r_pdelta_abs_rom <= 12'b011111_110000; end
            6'h28: begin cyc7r_pdelta_tune_rom <= 5'b01111; cyc7r_pdelta_abs_rom <= 12'b100000_001110; end
            6'h29: begin cyc7r_pdelta_tune_rom <= 5'b01111; cyc7r_pdelta_abs_rom <= 12'b100000_101100; end
            6'h2A: begin cyc7r_pdelta_tune_rom <= 5'b11111; cyc7r_pdelta_abs_rom <= 12'b100001_001010; end
            6'h2B: begin cyc7r_pdelta_tune_rom <= 5'b11111; cyc7r_pdelta_abs_rom <= 12'b100001_101001; end

            6'h30: begin cyc7r_pdelta_tune_rom <= 5'b11111; cyc7r_pdelta_abs_rom <= 12'b100010_001001; end
            6'h31: begin cyc7r_pdelta_tune_rom <= 5'b11110; cyc7r_pdelta_abs_rom <= 12'b100010_101000; end
            6'h32: begin cyc7r_pdelta_tune_rom <= 5'b11110; cyc7r_pdelta_abs_rom <= 12'b100011_001001; end
            6'h33: begin cyc7r_pdelta_tune_rom <= 5'b11110; cyc7r_pdelta_abs_rom <= 12'b100011_101001; end
            6'h34: begin cyc7r_pdelta_tune_rom <= 5'b11110; cyc7r_pdelta_abs_rom <= 12'b100100_001011; end
            6'h35: begin cyc7r_pdelta_tune_rom <= 5'b11110; cyc7r_pdelta_abs_rom <= 12'b100100_101100; end
            6'h36: begin cyc7r_pdelta_tune_rom <= 5'b01110; cyc7r_pdelta_abs_rom <= 12'b100101_001110; end
            6'h37: begin cyc7r_pdelta_tune_rom <= 5'b01110; cyc7r_pdelta_abs_rom <= 12'b100101_110001; end
            6'h38: begin cyc7r_pdelta_tune_rom <= 5'b01110; cyc7r_pdelta_abs_rom <= 12'b100110_010100; end
            6'h39: begin cyc7r_pdelta_tune_rom <= 5'b01110; cyc7r_pdelta_abs_rom <= 12'b100110_111000; end
            6'h3A: begin cyc7r_pdelta_tune_rom <= 5'b01110; cyc7r_pdelta_abs_rom <= 12'b100111_011100; end
            6'h3B: begin cyc7r_pdelta_tune_rom <= 5'b01110; cyc7r_pdelta_abs_rom <= 12'b101000_000001; end
        endcase

        cyc7r_pdelta_shift_control <= cyc6r_final_pitchval[12:8];
        cyc7r_pdelta_tune_control <= cyc6r_final_pitchval[3:0];
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 7: Key code to F-num conversion step 2
////

//  DESCRIPTION
//Now we have to generate the value to tune the absolute phase
//delta. YM2151 makes three addends by choosing and ORing the bits
//from the ROM first, and then sums them. This will adjust the
//absolute value in the next step(cycle 8)

//
//  combinational part
//






endmodule