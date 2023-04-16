module IKA2151_timer (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_31,

    //control input
    input   wire    [7:0]   i_CLKA1,
    input   wire    [1:0]   i_CLKA2,
    input   wire    [7:0]   i_CLKB,
    input   wire            i_TIMERA_RUN,
    input   wire            i_TIMERB_RUN,
    input   wire            i_TIMERA_IRQ_EN,
    input   wire            i_TIMERB_IRQ_EN,
    input   wire            i_TIMERA_FRST,
    input   wire            i_TIMERB_FRST,
    input   wire    [7:0]   i_TEST, //test register

    //timer output
    output  wire            o_TIMERA_OVFL,
    output  reg             o_TIMERA_FLAG,
    output  reg             o_TIMERB_FLAG,
    output  reg             o_IRQ_n
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Timer A
////

reg             timera_cnt, timera_ld, timera_rst, timera_ovfl_z;
wire            timera_ovfl;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    timera_cnt <= (i_CYCLE_31 & i_TIMERA_RUN) | i_TEST[2];
    timera_ld  <= (i_TIMERA_RUN & timera_rst) | timera_ovfl; //run reg postive edge detector
    timera_rst <= ~i_TIMERA_RUN;

    timera_ovfl_z <= timera_ovfl;
end

primitive_counter #(.WIDTH(10)) u_timera (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(timera_cnt), .i_LD(timera_ld), .i_RST(~mrst_n | timera_rst),
    .i_D(10'd0), .o_Q(), .o_CO(timera_ovfl)
);

assign  o_TIMERA_OVFL = timera_ld; //for CSM



///////////////////////////////////////////////////////////
//////  Timer B
////

//Prescaler
reg             timerb_prescaler_cnt, timerb_prescaler_ovfl_z;
wire            timerb_prescaler_ovfl;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    timerb_prescaler_ovfl_z <= timerb_prescaler_ovfl; //save carry

    timerb_prescaler_cnt <= i_CYCLE_31;
end

primitive_counter #(.WIDTH(4)) u_timerb_prescaler (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(timerb_prescaler_cnt), .i_LD(1'b0), .i_RST(~mrst_n),
    .i_D(4'd0), .o_Q(), .o_CO(timerb_prescaler_ovfl)
);

//Timer B
reg             timerb_cnt, timerb_ld, timerb_rst, timerb_ovfl_z;
wire            timerb_ovfl;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    timerb_cnt <= (timerb_prescaler_ovfl_z & i_TIMERB_RUN) | i_TEST[2];
    timerb_ld  <= (i_TIMERB_RUN & timerb_rst) | timerb_ovfl; //run reg postive edge detector
    timerb_rst <= ~i_TIMERB_RUN;

    timerb_ovfl_z <= timerb_ovfl;
end

primitive_counter #(.WIDTH(8)) u_timerb (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(timerb_cnt), .i_LD(timerb_ld), .i_RST(~mrst_n | timerb_rst),
    .i_D(8'd0), .o_Q(), .o_CO(timerb_ovfl)
);



///////////////////////////////////////////////////////////
//////  Flag and IRQ generator
////

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(~mrst_n || i_TIMERA_FRST) begin
        o_TIMERA_FLAG <= 1'b0;
    end
    else begin
        if(i_TIMERA_IRQ_EN) o_TIMERA_FLAG <= timera_ld | o_TIMERA_FLAG;
        else o_TIMERA_FLAG <= 1'b0;
    end

    if(~mrst_n || i_TIMERB_FRST) begin
        o_TIMERB_FLAG <= 1'b0;
    end
    else begin
        if(i_TIMERB_IRQ_EN) o_TIMERB_FLAG <= timerb_ld | o_TIMERB_FLAG;
        else o_TIMERB_FLAG <= 1'b0;
    end

    o_IRQ_n <= ~(o_TIMERA_FLAG | o_TIMERB_FLAG);
end

endmodule