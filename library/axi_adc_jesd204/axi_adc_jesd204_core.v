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

module axi_adc_jesd204_core #(
  parameter ID = 0,
  parameter NUM_CHANNELS = 1,
  parameter CHANNEL_WIDTH = 14,
  parameter DATA_PATH_WIDTH = 4,
  parameter TWOS_COMPLEMENT = 1
) (
  input                                                         adc_clk,

  input      [DATA_PATH_WIDTH*NUM_CHANNELS*CHANNEL_WIDTH-1:0]   adc_if_data,

  output     [NUM_CHANNELS-1:0]                                 adc_enable,
  output     [NUM_CHANNELS-1:0]                                 adc_valid,
  output     [DATA_PATH_WIDTH*NUM_CHANNELS*16-1:0]              adc_data,
  input                                                         adc_dovf,


  input                                                         up_clk,
  input                                                         up_rstn,

  input                                                         up_wreq,
  output reg                                                    up_wack,
  input      [13:0]                                             up_waddr,
  input      [31:0]                                             up_wdata,
  input                                                         up_rreq,
  output reg                                                    up_rack,
  input      [13:0]                                             up_raddr,
  output reg [31:0]                                             up_rdata
);

  // internal registers

  reg                         adc_status;

  reg                         up_status_pn_err = 'd0;
  reg                         up_status_pn_oos = 'd0;
  reg     [31:0]              up_rdata_all;

  // internal signals

  wire                        adc_rst;

  wire    [NUM_CHANNELS-1:0]  up_adc_pn_err_s;
  wire    [NUM_CHANNELS-1:0]  up_adc_pn_oos_s;
  wire    [31:0]              up_rdata_s[0:NUM_CHANNELS];
  wire    [NUM_CHANNELS:0]    up_rack_s;
  wire    [NUM_CHANNELS:0]    up_wack_s;

  assign adc_valid = {NUM_CHANNELS{1'b1}};

  // status

  always @(posedge adc_clk) begin
    if (adc_rst == 1'b1) begin
      adc_status <= 1'b0;
    end else begin
      adc_status <= 1'b1;
    end
  end

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
      up_status_pn_err <= 'd0;
      up_status_pn_oos <= 'd0;
      up_rdata <= 'd0;
      up_rack <= 'd0;
      up_wack <= 'd0;
    end else begin
      up_status_pn_err <= |up_adc_pn_err_s;
      up_status_pn_oos <= |up_adc_pn_oos_s;

      up_rdata <= up_rdata_all;
      up_rack <= |up_rack_s;
      up_wack <= |up_wack_s;
    end
  end

  // channel

  localparam CDW = CHANNEL_WIDTH * DATA_PATH_WIDTH;
  localparam CDW2 = 16 * DATA_PATH_WIDTH;

  generate
  genvar i;
  for (i = 0; i < NUM_CHANNELS; i = i + 1) begin: g_channel
    axi_adc_jesd204_channel #(
      .CHANNEL_ID(i),
      .CHANNEL_WIDTH(CHANNEL_WIDTH),
      .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
      .TWOS_COMPLEMENT(TWOS_COMPLEMENT)
    ) i_channel (
      .adc_clk (adc_clk),
      .adc_rst (adc_rst),
      .adc_data (adc_if_data[CDW*(i+1)-1:CDW*i]),
      .adc_dfmt_data (adc_data[CDW2*(i+1)-1:CDW2*i]),
      .adc_enable (adc_enable[i]),

      .up_adc_pn_err (up_adc_pn_err_s[i]),
      .up_adc_pn_oos (up_adc_pn_oos_s[i]),

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

  // common processor control

  up_adc_common #(
    .ID(ID)
  ) i_up_adc_common (
    .mmcm_rst (),
    .adc_clk (adc_clk),
    .adc_rst (adc_rst),
    .adc_r1_mode (),
    .adc_ddr_edgesel (),
    .adc_pin_mode (),
    .adc_status (adc_status),
    .adc_sync_status (1'd0),
    .adc_status_ovf (adc_dovf),
    .adc_clk_ratio (DATA_PATH_WIDTH),
    .adc_start_code (),
    .adc_sync (),

    .up_status_pn_err (up_status_pn_err),
    .up_status_pn_oos (up_status_pn_oos),
    .up_status_or (1'b0),
    .up_drp_sel (),
    .up_drp_wr (),
    .up_drp_addr (),
    .up_drp_wdata (),
    .up_drp_rdata (32'd0),
    .up_drp_ready (1'd0),
    .up_drp_locked (1'd1),
    .up_usr_chanmax (),
    .adc_usr_chanmax (8'd1),
    .up_adc_gpio_in (32'd0),
    .up_adc_gpio_out (),
    .up_adc_ce(),

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
