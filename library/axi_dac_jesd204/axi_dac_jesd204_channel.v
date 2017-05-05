// ***************************************************************************
// ***************************************************************************
// Copyright 2011-2017(c) Analog Devices, Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//     - Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     - Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in
//       the documentation and/or other materials provided with the
//       distribution.
//     - Neither the name of Analog Devices, Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//     - The use of this software may or may not infringe the patent rights
//       of one or more patent holders.  This license does not release you
//       from the requirement that you obtain separate licenses from these
//       patent holders to use this software.
//     - Use of the software either in source or binary form, must be run
//       on or directly connected to an Analog Devices Inc. component.
//
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, INTELLECTUAL PROPERTY
// RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module axi_dac_jesd204_channel #(
  parameter CHANNEL_ID = 0,
  parameter DATAPATH_DISABLE = 0,
  parameter DATA_PATH_WIDTH = 4
) (
  // dac interface

  input                                 dac_clk,
  input                                 dac_rst,
  output reg                            dac_enable,
  output reg  [DATA_PATH_WIDTH*16-1:0]  dac_data,
  input       [DATA_PATH_WIDTH*16-1:0]  dma_data,

  // processor interface

  input                                 dac_data_sync,
  input                                 dac_dds_format,

  // bus interface

  input                                 up_clk,
  input                                 up_rstn,
  input                                 up_wreq,
  input       [13:0]                    up_waddr,
  input       [31:0]                    up_wdata,
  output                                up_wack,
  input                                 up_rreq,
  input       [13:0]                    up_raddr,
  output      [31:0]                    up_rdata,
  output                                up_rack
);

  localparam DW = DATA_PATH_WIDTH * 16 - 1;

  // internal registers

  reg     [DW:0]  dac_pn7_data = 'd0;
  reg     [DW:0]  dac_pn15_data = 'd0;
  reg     [15:0]  dac_dds_phase_0[0:DATA_PATH_WIDTH-1];
  reg     [15:0]  dac_dds_phase_1[0:DATA_PATH_WIDTH-1];
  reg     [15:0]  dac_dds_incr_0 = 'd0;
  reg     [15:0]  dac_dds_incr_1 = 'd0;
  reg     [DW:0]  dac_dds_data = 'd0;

  // internal signals

  wire    [DW:0]  dac_dds_data_s;
  wire    [15:0]  dac_dds_scale_1_s;
  wire    [15:0]  dac_dds_init_1_s;
  wire    [15:0]  dac_dds_incr_1_s;
  wire    [15:0]  dac_dds_scale_2_s;
  wire    [15:0]  dac_dds_init_2_s;
  wire    [15:0]  dac_dds_incr_2_s;
  wire    [15:0]  dac_pat_data_1_s;
  wire    [15:0]  dac_pat_data_2_s;
  wire    [ 3:0]  dac_data_sel_s;

  wire    [DW:0]    pn15;
  wire    [DW+15:0] pn15_full_state;
  wire    [DW:0]    dac_pn15_data_s;
  wire    [DW:0]    pn7;
  wire    [DW+7:0]  pn7_full_state;
  wire    [DW:0]    dac_pn7_data_s;

  // PN15 x^15 + x^14 + 1
  assign pn15 = pn15_full_state[DW+15:15] ^ pn15_full_state[DW+14:14];
  assign pn15_full_state = {dac_pn15_data[14:0],pn15};

  // PN7 x^7 + x^6 + 1
  assign pn7 = pn7_full_state[DW+7:7] ^ pn7_full_state[DW+6:6];
  assign pn7_full_state = {dac_pn7_data[6:0],pn7};

  generate
  genvar i;
  for (i = 0; i < DATA_PATH_WIDTH; i = i + 1) begin: g_pn_swizzle
    localparam src_lsb = i * 16;
    localparam src_msb = src_lsb + 15;
    localparam dst_lsb = (DATA_PATH_WIDTH - i - 1) * 16;
    localparam dst_msb = dst_lsb + 15;

    assign dac_pn15_data_s[dst_msb:dst_lsb] = dac_pn15_data[src_msb:src_lsb];
    assign dac_pn7_data_s[dst_msb:dst_lsb] = dac_pn7_data[src_msb:src_lsb];
  end
  endgenerate

  // dac data select

  always @(posedge dac_clk) begin
    dac_enable <= (dac_data_sel_s == 4'h2) ? 1'b1 : 1'b0;
    case (dac_data_sel_s)
      4'h7: dac_data <= dac_pn15_data_s;
      4'h6: dac_data <= dac_pn7_data_s;
      4'h5: dac_data <= ~dac_pn15_data_s;
      4'h4: dac_data <= ~dac_pn7_data_s;
      4'h3: dac_data <= 'h00;
      4'h2: dac_data <= dma_data;
      4'h1: dac_data <= {DATA_PATH_WIDTH/2{dac_pat_data_2_s, dac_pat_data_1_s}};
      default: dac_data <= dac_dds_data;
    endcase
  end

  // pn registers

  always @(posedge dac_clk) begin
    if (dac_data_sync == 1'b1) begin
      dac_pn15_data <= {DW+1{1'd1}};
      dac_pn7_data <= {DW+1{1'd1}};
    end else begin
      dac_pn15_data <= pn15;
      dac_pn7_data <= pn7;
    end
  end

  // dds

  generate
  if (DATAPATH_DISABLE == 1) begin
    always @(posedge dac_clk) begin
      dac_dds_data <= 64'd0;
    end
  end else begin
    genvar i;

    always @(posedge dac_clk) begin
      if (dac_data_sync == 1'b1) begin
        dac_dds_incr_0 <= dac_dds_incr_1_s * DATA_PATH_WIDTH;
        dac_dds_incr_1 <= dac_dds_incr_2_s * DATA_PATH_WIDTH;
        dac_dds_data <= 64'd0;
      end else begin
        dac_dds_incr_0 <= dac_dds_incr_0;
        dac_dds_incr_1 <= dac_dds_incr_1;
        dac_dds_data <= dac_dds_data_s;
      end
    end

    for (i = 0; i < DATA_PATH_WIDTH; i = i + 1) begin: g_dds_phase

      always @(posedge dac_clk) begin
        if (dac_data_sync == 1'b1) begin
          if (i == 0) begin
            dac_dds_phase_0[i] <= dac_dds_init_1_s;
            dac_dds_phase_1[i] <= dac_dds_init_2_s;
          end else begin
            dac_dds_phase_0[i] <= dac_dds_phase_0[i-1] + dac_dds_incr_1_s;
            dac_dds_phase_1[i] <= dac_dds_phase_1[i-1] + dac_dds_incr_2_s;
          end
        end else begin
          dac_dds_phase_0[i] <= dac_dds_phase_0[i] + dac_dds_incr_0;
          dac_dds_phase_1[i] <= dac_dds_phase_1[i] + dac_dds_incr_1;
        end
      end

      ad_dds i_dds (
        .clk (dac_clk),
        .dds_format (dac_dds_format),
        .dds_phase_0 (dac_dds_phase_0[i]),
        .dds_scale_0 (dac_dds_scale_1_s),
        .dds_phase_1 (dac_dds_phase_1[i]),
        .dds_scale_1 (dac_dds_scale_2_s),
        .dds_data (dac_dds_data_s[16*(i+1)-1:16*i])
      );
    end
  end
  endgenerate

  // single channel processor

  up_dac_channel #(
    .CHANNEL_ID(CHANNEL_ID)
  ) i_up_dac_channel (
    .dac_clk (dac_clk),
    .dac_rst (dac_rst),
    .dac_dds_scale_1 (dac_dds_scale_1_s),
    .dac_dds_init_1 (dac_dds_init_1_s),
    .dac_dds_incr_1 (dac_dds_incr_1_s),
    .dac_dds_scale_2 (dac_dds_scale_2_s),
    .dac_dds_init_2 (dac_dds_init_2_s),
    .dac_dds_incr_2 (dac_dds_incr_2_s),
    .dac_pat_data_1 (dac_pat_data_1_s),
    .dac_pat_data_2 (dac_pat_data_2_s),
    .dac_data_sel (dac_data_sel_s),
    .dac_iq_mode (),
    .dac_iqcor_enb (),
    .dac_iqcor_coeff_1 (),
    .dac_iqcor_coeff_2 (),
    .up_usr_datatype_be (),
    .up_usr_datatype_signed (),
    .up_usr_datatype_shift (),
    .up_usr_datatype_total_bits (),
    .up_usr_datatype_bits (),
    .up_usr_interpolation_m (),
    .up_usr_interpolation_n (),
    .dac_usr_datatype_be (1'b0),
    .dac_usr_datatype_signed (1'b1),
    .dac_usr_datatype_shift (8'd0),
    .dac_usr_datatype_total_bits (8'd16),
    .dac_usr_datatype_bits (8'd16),
    .dac_usr_interpolation_m (16'd1),
    .dac_usr_interpolation_n (16'd1),

    .up_clk (up_clk),
    .up_rstn (up_rstn),
    .up_wreq (up_wreq),
    .up_waddr (up_waddr),
    .up_wdata (up_wdata),
    .up_wack (up_wack),
    .up_rreq (up_rreq),
    .up_raddr (up_raddr),
    .up_rdata (up_rdata),
    .up_rack (up_rack)
  );

endmodule
