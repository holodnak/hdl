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

module axi_adc_jesd204 #(
  parameter ID = 0,
  parameter DEVICE_TYPE = 0,
  parameter NUM_CHANNELS = 1,
  parameter CHANNEL_WIDTH = 14,
  parameter NUM_LANES = 1,
  parameter TWOS_COMPLEMENT = 1
) (
  // jesd interface
  // rx_clk is (line-rate/40)

  input                            rx_clk,

  input      [3:0]                 rx_sof,
  input                            rx_valid,
  input      [NUM_LANES*32-1:0]    rx_data,
  output                           rx_ready,

  // dma interface

  output     [NUM_CHANNELS-1:0]    adc_enable,
  output     [NUM_CHANNELS-1:0]    adc_valid,
  output     [NUM_LANES*32-1:0]    adc_data,
  input                            adc_dovf,

  // axi interface

  input                            s_axi_aclk,
  input                            s_axi_aresetn,
  input                            s_axi_awvalid,
  input      [15:0]                s_axi_awaddr,
  output                           s_axi_awready,
  input                            s_axi_wvalid,
  input      [31:0]                s_axi_wdata,
  input      [ 3:0]                s_axi_wstrb,
  output                           s_axi_wready,
  output                           s_axi_bvalid,
  output     [ 1:0]                s_axi_bresp,
  input                            s_axi_bready,
  input                            s_axi_arvalid,
  input      [15:0]                s_axi_araddr,
  output                           s_axi_arready,
  output                           s_axi_rvalid,
  output     [ 1:0]                s_axi_rresp,
  output     [31:0]                s_axi_rdata,
  input                            s_axi_rready
);

  // Number of samples per channel that are processed in parallel.
  // Assumes 2 octets per sample.
  localparam DATA_PATH_WIDTH = 2 * NUM_LANES / NUM_CHANNELS;

  // internal clocks & resets

  wire up_clk;
  wire up_rstn;

  // internal signals

  wire    [NUM_LANES*2*CHANNEL_WIDTH-1:0] adc_if_data_s;

  wire                                    up_wreq_s;
  wire    [13:0]                          up_waddr_s;
  wire    [31:0]                          up_wdata_s;
  wire                                    up_wack_s;
  wire                                    up_rreq_s;
  wire    [13:0]                          up_raddr_s;
  wire    [31:0]                          up_rdata_s;
  wire                                    up_rack_s;

  // signal name changes

  assign up_clk = s_axi_aclk;
  assign up_rstn = s_axi_aresetn;

  // defaults

  assign rx_ready = 1'b1;

  // main (device interface)

  axi_adc_jesd204_if #(
    .DEVICE_TYPE (DEVICE_TYPE),
    .NUM_LANES(NUM_LANES),
    .NUM_CHANNELS(NUM_CHANNELS),
    .CHANNEL_WIDTH(CHANNEL_WIDTH)
  ) i_if (
    .rx_clk (rx_clk),
    .rx_sof (rx_sof),
    .rx_data (rx_data),
    .adc_data (adc_if_data_s)
  );

  // core

  axi_adc_jesd204_core #(
    .NUM_CHANNELS(NUM_CHANNELS),
    .CHANNEL_WIDTH(CHANNEL_WIDTH),
    .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
    .TWOS_COMPLEMENT(TWOS_COMPLEMENT)
  ) i_core (
    .adc_clk(rx_clk),
    .adc_if_data(adc_if_data_s),
    .adc_enable(adc_enable),
    .adc_valid(adc_valid),
    .adc_data(adc_data),
    .adc_dovf(adc_dovf),

    .up_clk(up_clk),
    .up_rstn(up_rstn),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_s),
    .up_rack (up_rack_s)
  );

  // up bus interface

  up_axi #(
    .AXI_ADDRESS_WIDTH(16)
  ) i_up_axi (
    .up_clk (up_clk),
    .up_rstn (up_rstn),

    .up_axi_awvalid (s_axi_awvalid),
    .up_axi_awaddr (s_axi_awaddr),
    .up_axi_awready (s_axi_awready),
    .up_axi_wvalid (s_axi_wvalid),
    .up_axi_wdata (s_axi_wdata),
    .up_axi_wstrb (s_axi_wstrb),
    .up_axi_wready (s_axi_wready),
    .up_axi_bvalid (s_axi_bvalid),
    .up_axi_bresp (s_axi_bresp),
    .up_axi_bready (s_axi_bready),
    .up_axi_arvalid (s_axi_arvalid),
    .up_axi_araddr (s_axi_araddr),
    .up_axi_arready (s_axi_arready),
    .up_axi_rvalid (s_axi_rvalid),
    .up_axi_rresp (s_axi_rresp),
    .up_axi_rdata (s_axi_rdata),
    .up_axi_rready (s_axi_rready),

    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_s),
    .up_rack (up_rack_s)
  );

endmodule
