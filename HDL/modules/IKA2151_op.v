module IKA2151_op
(
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_03,

    input   wire    [9:0]   i_OP_ORIGINAL_PHASE,
    input   wire    [9:0]   i_OP_ATTENLEVEL
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;




///////////////////////////////////////////////////////////
//////  Cycle 41: Phase modulation
////

//
//  combinational part
//

wire    [9:0]   cyc56r_phasemod_value; //get value from the end of the pipeline
wire    [10:0]  cyc41c_modded_phase_adder = {1'b0, i_OP_ORIGINAL_PHASE}; //+ cyc56r_phasemod_value;


//
//  register part
//

reg     [7:0]   cyc41r_logsinrom_phase;
reg             cyc41r_level_fp_sign;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc41r_logsinrom_phase <= cyc41c_modded_phase_adder[8] ?  cyc41c_modded_phase_adder[7:0] : 
                                                              ~cyc41c_modded_phase_adder[7:0];

        cyc41r_level_fp_sign <= cyc41c_modded_phase_adder[9]; //discard carry
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 42: Get data from Sin ROM
////

//
//  register part
//

wire    [45:0]  cyc42r_logsinrom_out;
op_submdl_logsinrom u_cyc42r_logsinrom (
    .i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_ADDR(cyc41r_logsinrom_phase[5:1]), .o_DATA(cyc42r_logsinrom_out)
);

reg             cyc42r_logsinrom_phase_odd;
reg     [1:0]   cyc42r_logsinrom_bitsel;
reg             cyc42r_level_fp_sign;
always @(posedge i_EMUCLK) begin
if(!phi1ncen_n) begin
        cyc42r_logsinrom_phase_odd <= cyc41r_logsinrom_phase[0];
        cyc42r_logsinrom_bitsel <= cyc41r_logsinrom_phase[7:6];
        cyc42r_level_fp_sign <= cyc41r_level_fp_sign;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 43: Choose bits from Sin ROM and add them
////

//
//  combinational part
//

wire    [45:0]  ls = cyc42r_logsinrom_out; //alias signal
wire            odd = cyc42r_logsinrom_phase_odd; //alias signal

reg     [10:0]  cyc43c_logsinrom_addend0, cyc43c_logsinrom_addend1;
always @(*) begin
    case(cyc42r_logsinrom_bitsel)
        /*                                    D10      D9      D8      D7      D6      D5      D4      D3      D2      D1      D0  */
        2'd0: cyc43c_logsinrom_addend0 <= {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0, ls[29], ls[25], ls[18], ls[14],  ls[3]};
        2'd1: cyc43c_logsinrom_addend0 <= {  1'b0,   1'b0,   1'b0,   1'b0, ls[37], ls[34], ls[28], ls[24], ls[17], ls[13],  ls[2]};
        2'd2: cyc43c_logsinrom_addend0 <= {  1'b0,   1'b0, ls[43], ls[41], ls[36], ls[33], ls[27], ls[23], ls[16], ls[12],  ls[1]};
        2'd3: cyc43c_logsinrom_addend0 <= {  1'b0,   1'b0, ls[42], ls[40], ls[35], ls[32], ls[26], ls[22], ls[15], ls[11],  ls[0]};
    endcase

    case(cyc42r_logsinrom_bitsel)
        /*                                    D10      D9      D8      D7      D6      D5      D4      D3      D2      D1      D0  */
        2'd0: cyc43c_logsinrom_addend1 <= {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,  ls[7]} & {2'b11, {9{odd}}};
        2'd1: cyc43c_logsinrom_addend1 <= {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0, ls[10],  ls[6]} & {2'b11, {9{odd}}};
        2'd2: cyc43c_logsinrom_addend1 <= {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0, ls[20],  ls[9],  ls[5]} & {2'b11, {9{odd}}};
        2'd3: cyc43c_logsinrom_addend1 <= {ls[45], ls[44], ls[39], ls[39], ls[38], ls[31], ls[30], ls[21], ls[19],  ls[8],  ls[4]} & {2'b11, {9{odd}}};
    endcase 
end


//
//  register part
//

reg     [11:0]  cyc43r_logsin_raw;
reg             cyc43r_level_fp_sign;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc43r_logsin_raw <= cyc43c_logsinrom_addend0 + cyc43c_logsinrom_addend1;
        cyc43r_level_fp_sign <= cyc42r_level_fp_sign;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 44: Apply attenuation level
////

//
//  register part
//

reg     [12:0]  cyc44r_logsin_attenuated;
reg             cyc44r_level_fp_sign;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc44r_logsin_attenuated <= cyc43r_logsin_raw + {i_OP_ATTENLEVEL, 2'b00};
        cyc44r_level_fp_sign <= cyc43r_level_fp_sign;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 45: Saturation
////

//
//  register part
//

reg     [11:0]  cyc45r_logsin_saturated;
reg             cyc45r_level_fp_sign;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc45r_logsin_saturated <= cyc44r_logsin_attenuated[12] ? 12'd4095 : cyc44r_logsin_attenuated;
        cyc45r_level_fp_sign <= cyc44r_level_fp_sign;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 46: Get data from exp ROM
////

//
//  register part
//

wire    [44:0]  cyc46r_exprom_out;
op_submdl_exprom u_cyc46r_exprom (
    .i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_ADDR(cyc45r_logsin_saturated[5:1]), .o_DATA(cyc46r_exprom_out)
);

reg             cyc46r_logsin_even;
reg     [1:0]   cyc46r_exprom_bitsel;
reg     [3:0]   cyc46r_level_fp_exp;
reg             cyc46r_level_fp_sign;
always @(posedge i_EMUCLK) begin
if(!phi1ncen_n) begin
        cyc46r_logsin_even <= ~cyc45r_logsin_saturated[0]; //inverted!! EVEN flag!!
        cyc46r_exprom_bitsel <= cyc45r_logsin_saturated[7:6];
        cyc46r_level_fp_exp <= ~cyc45r_logsin_saturated[11:8]; //invert
        cyc46r_level_fp_sign <= cyc45r_level_fp_sign;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 47: Choose bits from exp ROM and add them
////

//
//  combinational part
//

wire    [44:0]  e = cyc46r_exprom_out; //alias signal
wire            even = cyc46r_logsin_even; //alias signal

reg     [9:0]  cyc47c_exprom_addend0, cyc47c_exprom_addend1;
always @(*) begin
    case(cyc46r_exprom_bitsel)
        /*                                  D9      D8      D7      D6      D5      D4      D3      D2      D1     D0  */
        2'd0: cyc47c_exprom_addend0 <= {  1'b1,  e[43],  e[40],  e[36],  e[32],  e[28],  e[24],  e[18],  e[14],   e[3]};
        2'd1: cyc47c_exprom_addend0 <= { e[44],  e[42],  e[39],  e[35],  e[31],  e[27],  e[23],  e[17],  e[13],   e[2]};
        2'd2: cyc47c_exprom_addend0 <= {  1'b0,  e[41],  e[38],  e[34],  e[30],  e[26],  e[22],  e[16],  e[12],   e[1]};
        2'd3: cyc47c_exprom_addend0 <= {  1'b0,   1'b0,  e[37],  e[33],  e[29],  e[25],  e[21],  e[15],  e[11],   e[0]};
    endcase

    case(cyc46r_exprom_bitsel)
        /*                                  D9      D8      D7      D6      D5      D4      D3      D2      D1      D0  */
        2'd0: cyc47c_exprom_addend1 <= {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b1,  e[10],   e[7]} & {7'b1111111, {3{even}}};
        2'd1: cyc47c_exprom_addend1 <= {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b1,   1'b0,   e[6]} & {7'b1111111, {3{even}}};
        2'd2: cyc47c_exprom_addend1 <= {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,  e[19],   e[9],   e[5]} & {7'b1111111, {3{even}}};
        2'd3: cyc47c_exprom_addend1 <= {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,  e[20],   e[8],   e[4]} & {7'b1111111, {3{even}}};
    endcase 
end


//
//  register part
//

reg     [9:0]   cyc47r_level_fp_mant;
reg     [3:0]   cyc47r_level_fp_exp;
reg             cyc47r_level_fp_sign;
reg             cyc47r_level_negate;
always @(posedge i_EMUCLK) begin
if(!phi1ncen_n) begin
        cyc47r_level_fp_mant <= cyc47c_exprom_addend0 + cyc47c_exprom_addend1; //discard carrycyc48r_int_
        cyc47r_level_fp_exp <= cyc46r_level_fp_exp;
        cyc47r_level_fp_sign <= cyc46r_level_fp_sign;
        cyc47r_level_negate <= 1'b0;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 48: Floating point to integer
////

//
//  combinational part
//

reg     [12:0]  cyc48c_shifter0, cyc48c_shifter1;
always @(*) begin
    case(cyc47r_level_fp_exp[1:0])
        2'b00: cyc48c_shifter0 <= {3'b000, 1'b1, cyc47r_level_fp_mant[9:1]};
        2'b01: cyc48c_shifter0 <= {2'b00, 1'b1, cyc47r_level_fp_mant      };
        2'b10: cyc48c_shifter0 <= {1'b0, 1'b1, cyc47r_level_fp_mant, 1'b0 };
        2'b11: cyc48c_shifter0 <= {     1'b1, cyc47r_level_fp_mant, 2'b00 };
    endcase

    case(cyc47r_level_fp_exp[3:2])
        2'b00: cyc48c_shifter1 <= {12'b0, cyc48c_shifter0[12]  };
        2'b01: cyc48c_shifter1 <= { 8'b0, cyc48c_shifter0[12:8]};
        2'b10: cyc48c_shifter1 <= { 4'b0, cyc48c_shifter0[12:4]};
        2'b11: cyc48c_shifter1 <= cyc48c_shifter0;
    endcase
end

//
//  register part
//

reg             cyc48r_level_negate;
reg             cyc48r_level_sign;
reg     [12:0]  cyc48r_level_magnitude;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc48r_level_negate <= cyc47r_level_negate;
        cyc48r_level_sign <= cyc47r_level_fp_sign;
        cyc48r_level_magnitude <= cyc48c_shifter1;
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 49: sign-magnitude to signed integer
////

reg     [13:0]  cyc49r_level_signed;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc49r_level_signed <= cyc48r_level_sign ? (~{cyc48r_level_negate, cyc48r_level_magnitude} + 14'd1) : 
                                                     {cyc48r_level_negate, cyc48r_level_magnitude};
    end
end










reg     [6:0]   debug_cycdly;
reg     [11:0]  debug_logsin;
reg             debug_logsin_sign;
reg     [9:0]   debug_level_fp_mant;
reg     [3:0]   debug_level_fp_exp;
reg             debug_level_fp_sign;
reg     [13:0]  debug_val;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        debug_cycdly[6:1] <= debug_cycdly[5:0];
        debug_cycdly[0] <= i_CYCLE_03;

        if(debug_cycdly[2]) begin debug_logsin <= cyc45r_logsin_saturated; debug_logsin_sign <= cyc45r_level_fp_sign; end
        if(debug_cycdly[4]) begin debug_level_fp_mant <= cyc47r_level_fp_mant; debug_level_fp_exp <= cyc47r_level_fp_exp; debug_level_fp_sign <= cyc47r_level_fp_sign; end
        if(debug_cycdly[6]) debug_val <= cyc49r_level_signed;
    end
end





endmodule


module op_submdl_logsinrom
(
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //clock enable
    input   wire            i_CEN_n, //positive edge clock enable for emulation

    input   wire    [4:0]   i_ADDR,
    output  reg     [45:0]  o_DATA
);

always @(posedge i_EMUCLK) begin
    if(!i_CEN_n) begin
        case(i_ADDR)
            5'd0 : o_DATA <= 46'b000110000010010001000100_0010101010101001010010;
            5'd1 : o_DATA <= 46'b000110000011010000010000_0010010001001101000001;
            5'd2 : o_DATA <= 46'b000110000011010000010011_0010001011001101100000;
            5'd3 : o_DATA <= 46'b000111000001000000000011_0010110001001101110010;
            5'd4 : o_DATA <= 46'b000111000001000000110000_0010111010001101101001;
            5'd5 : o_DATA <= 46'b000111000001010000100110_0010000000101101111010;
            5'd6 : o_DATA <= 46'b000111000001010000110110_0010010011001101011010;
            5'd7 : o_DATA <= 46'b000111000001110000010101_0010111000101111111100;

            5'd8 : o_DATA <= 46'b000111000011100000000111_0010101110001101110111;
            5'd9 : o_DATA <= 46'b000111000011100001010011_1000011101011010100110;
            5'd10: o_DATA <= 46'b000111000011110001100001_1000111100001001111010;
            5'd11: o_DATA <= 46'b000111000011110001110011_1001101011001001110111;
            5'd12: o_DATA <= 46'b010010000101000001000101_1001001000111010110111;
            5'd13: o_DATA <= 46'b010010000101010001000100_1001110001111100101010;
            5'd14: o_DATA <= 46'b010010000101010001010110_1101111110100101000110;
            5'd15: o_DATA <= 46'b010010001110000000100001_1001010110101101111001;

            5'd16: o_DATA <= 46'b010010001110010000100010_1011100101001011101111;
            5'd17: o_DATA <= 46'b010010001110110000011101_1010000001011010110001;
            5'd18: o_DATA <= 46'b010011001100100000011110_1010000010111010111111;
            5'd19: o_DATA <= 46'b010011001100110000101101_1110101110110110000001;
            5'd20: o_DATA <= 46'b010011001110100001101011_1011001010001101110001;
            5'd21: o_DATA <= 46'b010011001110110101101011_0101111001010100001111;
            5'd22: o_DATA <= 46'b011100001000000101011100_0101010101010110010111;
            5'd23: o_DATA <= 46'b011100001000010101011111_0111110101010010111011;

            5'd24: o_DATA <= 46'b011100001011010110100010_1100001000010000011001;
            5'd25: o_DATA <= 46'b011101001001100110010001_1110100100010010010010;
            5'd26: o_DATA <= 46'b011101001011101010010110_0101000000110100100011;
            5'd27: o_DATA <= 46'b101000001001101010110101_1101100001110010011010;
            5'd28: o_DATA <= 46'b101000001011111111110010_0111010100010000111001;
            5'd29: o_DATA <= 46'b101001011111010011001000_1100111001010110100000;
            5'd30: o_DATA <= 46'b101101011101001111101101_1110000100110010100001;
            5'd31: o_DATA <= 46'b111001101111000111101110_0111100001110110100111;
        endcase
    end
end

endmodule


module op_submdl_exprom
(
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //clock enable
    input   wire            i_CEN_n, //positive edge clock enable for emulation

    input   wire    [4:0]   i_ADDR,
    output  reg     [44:0]  o_DATA
);

always @(posedge i_EMUCLK) begin
    if(!i_CEN_n) begin
        case(i_ADDR)
            5'd0 : o_DATA <= 45'b110111111000111111010001_011000000100110011101;
            5'd1 : o_DATA <= 45'b110111111000110100111110_000001100001110110011;
            5'd2 : o_DATA <= 45'b110111111000000111101101_011101110100111011010;
            5'd3 : o_DATA <= 45'b110111111000000111000011_011100000010101010110;
            5'd4 : o_DATA <= 45'b110111111000000100001100_010100000010101011011;
            5'd5 : o_DATA <= 45'b110111010010101010111011_011000111100111011101;
            5'd6 : o_DATA <= 45'b110110010110111011110100_111001011000011000000;
            5'd7 : o_DATA <= 45'b110110010110111001001011_010001001100111011110;

            5'd8 : o_DATA <= 45'b110110010110011010001101_011000101000111011010;
            5'd9 : o_DATA <= 45'b110110010110000011100110_011110010100111010100;
            5'd10: o_DATA <= 45'b110110000111000101111001_010110110100110010101;
            5'd11: o_DATA <= 45'b110100001111100110011110_011111110000110011011;
            5'd12: o_DATA <= 45'b110100001111100110000001_001111001101110111101;
            5'd13: o_DATA <= 45'b110100001001111101101111_010110101010101010001;
            5'd14: o_DATA <= 45'b110100001001111101100000_010110001100110010011;
            5'd15: o_DATA <= 45'b110100001001011010110101_011001110000111010101;

            5'd16: o_DATA <= 45'b110100001001011000011010_001001010101110110111;
            5'd17: o_DATA <= 45'b110100001001001001010100_000000111001110110001;
            5'd18: o_DATA <= 45'b110100000001100011101011_000000011101110110011;
            5'd19: o_DATA <= 45'b110100000001100000101100_001011100001111110101;
            5'd20: o_DATA <= 45'b110100000000100100010011_011011000100110010101;
            5'd21: o_DATA <= 45'b011101000100010111011101_000010101001110110101;
            5'd22: o_DATA <= 45'b011001100110011111110010_000010001101111110011;
            5'd23: o_DATA <= 45'b011001100110011100100111_001001100001110110001;

            5'd24: o_DATA <= 45'b001011101110111110101001_001000000001110101010;
            5'd25: o_DATA <= 45'b001011101110101111000110_000000101101110111000;
            5'd26: o_DATA <= 45'b001011101110101001011001_010001001000110011010;
            5'd27: o_DATA <= 45'b001011101110100000110110_010011000100110010000;
            5'd28: o_DATA <= 45'b001011101110000010110000_001010101001110110001;
            5'd29: o_DATA <= 45'b001011101010010001001111_001010001101110111011;
            5'd30: o_DATA <= 45'b001011101010010001000010_011001000100100000000;
            5'd31: o_DATA <= 45'b001011100010110010001100_000000101001110110000;
        endcase
    end
end

endmodule