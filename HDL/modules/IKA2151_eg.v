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
    input   wire    [3:0]   i_RR,  //release rate
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

/*
    YM2151 uses serial counter and shift register to get the rate below

    timecntr = X_0000_00000_00000 = 0
    timecntr = X_1000_00000_00000 = 14
    timecntr = X_X100_00000_00000 = 13
    timecntr = X_XX10_00000_00000 = 12
    ...
    timecntr = X_XXXX_XXXXX_XXX10 = 2
    timecntr = X_XXXX_XXXXX_XXXX1 = 1

    I used parallel 4-bit counter instead of the shift register to save
    FPGA resources.
*/

reg             mrst_z;
reg     [1:0]   timecntr_adder;
reg     [14:0]  timecntr_sr; //this sr can hold 15-bit integer

reg             onebit_det, mrst_dlyd;
reg     [3:0]   conseczerobitcntr;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        //adder
        timecntr_adder <= mrst_n ? (((third_sample & i_CYCLE_01_TO_16) & (cycle_01_17 | timecntr_adder[1])) + timecntr_sr[0]) :
                                   2'd0;

        //sr
        timecntr_sr[14] <= timecntr_adder[0];
        timecntr_sr[13:0] <= timecntr_sr[14:1];

        //consecutive zero bits counter
        mrst_z <= ~mrst_n; //delay master reset, to synchronize the reset timing with timecntr_adder register

        if(mrst_z | cycle_01_17) begin
            onebit_det <= 1'b0;
            conseczerobitcntr <= 4'd1; //start from 1
        end
        else begin
            if(!onebit_det) begin
                if(timecntr_adder[0]) begin
                    onebit_det <= 1'b1;
                    conseczerobitcntr <= conseczerobitcntr;
                end
                else begin
                    onebit_det <= 1'b0;
                    conseczerobitcntr <= (conseczerobitcntr == 4'd14) ? 4'd0 : conseczerobitcntr + 4'd1; //max 14
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



///////////////////////////////////////////////////////////
//////  Previous KON shift register
////

//These shift registers holds KON values from previous 32 cycles
reg     [3:0]   cyc6r_cyc9r_kon_current_dlyline; //outer process delay compensation(4 cycles)
reg     [27:0]  cyc10r_cyc37r_kon_previous; //previous KON values
reg     [3:0]   cyc6r_cyc9r_kon_previous; //delayed concurrently with the current kon delay line

wire            cyc9r_kon_current = cyc6r_cyc9r_kon_current_dlyline[3]; //current kon value
wire            cyc9r_kon_detected = ~cyc6r_cyc9r_kon_previous[3] & cyc9r_kon_current; //prev=0, curr=1, new kon detected

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc6r_cyc9r_kon_current_dlyline[0] <= i_KON;
        cyc6r_cyc9r_kon_current_dlyline[3:1] <= cyc6r_cyc9r_kon_current_dlyline[2:0];

        cyc10r_cyc41r_kon_previous[0] <= cyc6r_cyc9r_kon_current_dlyline[3];
        cyc10r_cyc41r_kon_previous[27:1] <= cyc10r_cyc41r_kon_previous[26:0];

        cyc6r_cyc9r_kon_previous[0] <= cyc10r_cyc37r_kon_previous[27];
        cyc6r_cyc9r_kon_previous[3:1] <= cyc6r_cyc9r_kon_previous[2:0];
    end
end



///////////////////////////////////////////////////////////
//////  Envelope state machine
////

localparam ATTACK = 2'd0;
localparam FIRST_DECAY = 2'd1;
localparam SECOND_DECAY = 2'd2;
localparam RELEASE = 2'd3;


//
//  combinational part
//

//flags and prev state for FSM
wire            cyc10c_first_decay_end;
wire            cyc10c_env_level_max;
wire            cyc10c_env_level_min;
wire    [1:0]   cyc10c_envstate_previous = cyc6r_cyc9r_envstate_previous[3];


//
//  register part
//

//total 32 stages to store states of all operators
reg     [1:0]   cyc6r_cyc9r_envstate_previous[0:3]; //4 stages
reg     [1:0]   cyc10r_envstate_current; //1 stage
reg     [1:0]   cyc11r_cyc37r_envstate_previous[0:26]; //27 stages

//sr4
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        //if kon detected, make previous envstate ATTACK
        cyc6r_cyc9r_envstate_previous[0] <= (~cyc11r_cyc37r_kon_previous[27] & i_KON) ? ATTACK : cyc11r_cyc37r_envstate_previous[26];
        cyc6r_cyc9r_envstate_previous[1] <= cyc6r_cyc9r_envstate_previous[0];
        cyc6r_cyc9r_envstate_previous[2] <= cyc6r_cyc9r_envstate_previous[1];
        cyc6r_cyc9r_envstate_previous[3] <= cyc6r_cyc9r_envstate_previous[2];
    end
end

//state machine
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        if(!mrst_n) begin
            cyc10r_envstate_current <= RELEASE;
        end
        else begin
            if(cyc9r_kon_detected) begin
                cyc10r_envstate_current <= ATTACK; //start attack
            end
            else begin
                if(cyc9r_kon_current) begin
                    case(cyc10c_envstate_previous)
                        //current state 0: attack
                        2'd0: begin
                            if(cyc10c_env_level_max) begin
                                cyc10r_envstate_current <= FIRST_DECAY; //start first decay
                            end
                            else begin
                                cyc10r_envstate_current <= ATTACK; //hold state
                            end
                        end

                        //current state 1: first decay
                        2'd1: begin
                            if(cyc10c_env_level_min) begin
                                cyc10r_envstate_current <= RELEASE; //start release
                            end
                            else begin
                                if(cyc10c_first_decay_end) begin
                                    cyc10r_envstate_current <= SECOND_DECAY; //start second decay
                                end
                                else begin
                                    cyc10r_envstate_current <= FIRST_DECAY; //hold state
                                end
                            end
                        end 

                        //current state 2: second decay
                        2'd2: begin
                            if(cyc10c_env_level_min) begin
                                cyc10r_envstate_current <= RELEASE; //start release
                            end
                            else begin
                                cyc10r_envstate_current <= SECOND_DECAY; //hold state
                            end
                        end

                        //current state 3: release
                        2'd3: begin
                            cyc10r_envstate_current <= RELEASE; //hold state
                        end
                    endcase                    
                end
                else begin
                    cyc10r_envstate_current <= RELEASE; //key off -> start release
                end
            end
        end
    end
end

//sr27 first stage
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc11r_cyc37r_envstate_previous[0] <= cyc10r_envstate_current;
    end
end

//sr27 the other stages
genvar stage;
generate
for(stage = 0; stage < 26; stage = stage + 1) begin : envstate_sr27
    always @(posedge i_EMUCLK) begin
        if(!phi1ncen_n) begin
            cyc11r_cyc37r_envstate_previous[stage + 1] <= cyc11r_cyc37r_envstate_previous[stage];
        end
    end
end
endgenerate



///////////////////////////////////////////////////////////
//////  Data pipeline Cycle 8: EG param/KS latch 
////


//
//  combinational part
//

reg     [4:0]   cyc8c_egparam;
always @(*) begin
    if(!mrst_n) begin
        cyc8c_egparam <= 5'd32;
    end
    else begin
        case(cyc6r_cyc9r_envstate_previous[1])
            ATTACK:         cyc8c_egparam <= i_AR;
            FIRST_DECAY:    cyc8c_egparam <= i_D1R;
            SECOND_DECAY:   cyc8c_egparam <= i_D2R;
            RELEASE:        cyc8c_egparam <= {i_RR, 1'b0};
        endcase
    end
end


//
//  register part
//

reg     [4:0]   cyc8r_egparam;
reg             cyc8r_egparam_zero;
reg     [4:0]   cyc8r_keyscale;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc8r_egparam <= cyc8c_egparam;
        cyc8r_egparam_zero <= cyc8c_egparam == 5'd0;
    end
end










reg             cyc10r_env_underflow;

//flag
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc10r_env_underflow <= (cyc10c_envstate_previous != ATTACK) & ~cyc9r_kon_detected & cyc10c_env_level_min;
    end
end







endmodule