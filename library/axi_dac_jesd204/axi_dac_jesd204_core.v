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
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module axi_dac_jesd204_core #(
  parameter ID = 0,
  parameter DATAPATH_DISABLE = 0,
  parameter NUM_CHANNELS = 1,
  parameter DATA_PATH_WIDTH = 4
) (
  // dac interface

  input                                          dac_clk,
  output                                         dac_rst,
  output  [DATA_PATH_WIDTH*NUM_CHANNELS*16-1:0]  dac_data,

  // dma interface

  output  [NUM_CHANNELS-1:0]                     dac_valid,
  output  [NUM_CHANNELS-1:0]                     dac_enable,
  input   [DATA_PATH_WIDTH*NUM_CHANNELS*16-1:0]  dac_ddata,
  input                                          dac_dunf,

  // processor interface

  input                                          up_clk,
  input                                          up_rstn,
  input                                          up_wreq,
  input       [13:0]                             up_waddr,
  input       [31:0]                             up_wdata,
  output reg                                     up_wack,
  input                                          up_rreq,
  input       [13:0]                             up_raddr,
  output reg  [31:0]                             up_rdata,
  output reg                                     up_rack
);

  // internal registers

  reg     [31:0]            up_rdata_all;

  // internal signals

  wire                      dac_sync_s;
  wire                      dac_datafmt_s;
  wire    [31:0]            up_rdata_s[0:NUM_CHANNELS];
  wire    [0:NUM_CHANNELS]  up_rack_s;
  wire    [0:NUM_CHANNELS]  up_wack_s;

  // dac valid

  assign dac_valid = {NUM_CHANNELS{1'b1}};

  // processor read interface

  integer n;

  always @(*) begin
    up_rdata_all = 'h00;
    for (n = 0; n < NUM_CHANNELS + 1; n = n + 1) begin
      up_rdata_all = up_rdata_all | up_rdata_s[n];
     end
  end

  always @(posedge up_clk) begin
    if (up_rstn == 1'b0) begin
      up_rdata <= 'd0;
      up_rack <= 'd0;
      up_wack <= 'd0;
    end else begin
      up_rdata <= up_rdata_all;
      up_rack <= |up_rack_s;
      up_wack <= |up_wack_s;
    end
  end

  // dac channel

  localparam CDW = 16 * DATA_PATH_WIDTH;

  generate
  genvar i;
  for (i = 0; i < NUM_CHANNELS; i = i + 1) begin: g_channel
    axi_dac_jesd204_channel #(
      .CHANNEL_ID(i),
      .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
      .DATAPATH_DISABLE(DATAPATH_DISABLE)
    ) i_channel (
      .dac_clk (dac_clk),
      .dac_rst (dac_rst),
      .dac_enable (dac_enable[i]),
      .dac_data (dac_data[CDW*(i+1)-1:CDW*i]),
      .dma_data (dac_ddata[CDW*(i+1)-1:CDW*i]),
      .dac_data_sync (dac_sync_s),
      .dac_dds_format (dac_datafmt_s),

      .up_clk (up_clk),
      .up_rstn (up_rstn),
      .up_wreq (up_wreq),
      .up_waddr (up_waddr),
      .up_wdata (up_wdata),
      .up_wack (up_wack_s[i+1]),
      .up_rreq (up_rreq),
      .up_raddr (up_raddr),
      .up_rdata (up_rdata_s[i+1]),
      .up_rack (up_rack_s[i+1])
    );
  end
  endgenerate

  // dac common processor interface

  up_dac_common #(
    .ID(ID)
  ) i_up_dac_common (
    .mmcm_rst (),
    .dac_clk (dac_clk),
    .dac_rst (dac_rst),
    .dac_sync (dac_sync_s),
    .dac_frame (),
    .dac_clksel (),
    .dac_par_type (),
    .dac_par_enb (),
    .dac_r1_mode (),
    .dac_datafmt (dac_datafmt_s),
    .dac_datarate (),
    .dac_status (1'b1),
    .dac_status_unf (dac_dunf),
    .dac_clk_ratio (DATA_PATH_WIDTH),
    .up_drp_sel (),
    .up_drp_wr (),
    .up_drp_addr (),
    .up_drp_wdata (),
    .up_drp_rdata (32'd0),
    .up_drp_ready (1'd0),
    .up_drp_locked (1'd1),
    .up_usr_chanmax (),
    .dac_usr_chanmax (8'd3),
    .up_dac_gpio_in (32'd0),
    .up_dac_gpio_out (),
    .up_dac_ce (),

    .up_clk (up_clk),
    .up_rstn (up_rstn),
    .up_wreq (up_wreq),
    .up_waddr (up_waddr),
    .up_wdata (up_wdata),
    .up_wack (up_wack_s[0]),
    .up_rreq (up_rreq),
    .up_raddr (up_raddr),
    .up_rdata (up_rdata_s[0]),
    .up_rack (up_rack_s[0])
  );

endmodule
