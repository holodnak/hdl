// ***************************************************************************
// ***************************************************************************
// Copyright 2011(c) Analog Devices, Inc.
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

module axi_ad9144 #(

  parameter   ID = 0,
  parameter   DEVICE_TYPE = 0,
  parameter   QUAD_OR_DUAL_N = 1,
  parameter   DAC_DATAPATH_DISABLE = 0) (

  // jesd interface
  // tx_clk is (line-rate/40)

  input                   tx_clk,
  output                  tx_valid,
  output      [(128*QUAD_OR_DUAL_N)+127:0]  tx_data,
  input                   tx_ready,

  // dma interface

  output                  dac_clk,
  output                  dac_valid_0,
  output                  dac_enable_0,
  input       [63:0]      dac_ddata_0,
  output                  dac_valid_1,
  output                  dac_enable_1,
  input       [63:0]      dac_ddata_1,
  output                  dac_valid_2,
  output                  dac_enable_2,
  input       [63:0]      dac_ddata_2,
  output                  dac_valid_3,
  output                  dac_enable_3,
  input       [63:0]      dac_ddata_3,
  input                   dac_dunf,

  // axi interface

  input                   s_axi_aclk,
  input                   s_axi_aresetn,
  input                   s_axi_awvalid,
  input       [ 15:0]     s_axi_awaddr,
  input       [ 2:0]      s_axi_awprot,
  output                  s_axi_awready,
  input                   s_axi_wvalid,
  input       [ 31:0]     s_axi_wdata,
  input       [ 3:0]      s_axi_wstrb,
  output                  s_axi_wready,
  output                  s_axi_bvalid,
  output      [ 1:0]      s_axi_bresp,
  input                   s_axi_bready,
  input                   s_axi_arvalid,
  input       [ 15:0]     s_axi_araddr,
  input       [ 2:0]      s_axi_arprot,
  output                  s_axi_arready,
  output                  s_axi_rvalid,
  output      [ 31:0]     s_axi_rdata,
  output      [ 1:0]      s_axi_rresp,
  input                   s_axi_rready);

  // internal signals

  wire    [255:0]                         tx_data_s;

  // dual/quad cores

  assign tx_data = (QUAD_OR_DUAL_N == 1) ? tx_data_s : tx_data_s[127:0];

  assign dac_clk = tx_clk;

  axi_dac_jesd204 #(
    .ID(ID),
    .DEVICE_TYPE(DEVICE_TYPE),
    .NUM_LANES(8),
    .NUM_CHANNELS(4),
    .DAC_DATAPATH_DISABLE(DAC_DATAPATH_DISABLE)
  ) i_dac_jesd204 (
    .tx_clk(tx_clk),
    .tx_valid(tx_valid),
    .tx_data(tx_data_s),
    .tx_ready(tx_ready),

    .dac_valid({dac_valid_3,dac_valid_2,dac_valid_1,dac_valid_0}),
    .dac_enable({dac_enable_3,dac_enable_2,dac_enable_1,dac_enable_0}),
    .dac_ddata({dac_ddata_3,dac_ddata_2,dac_ddata_1,dac_ddata_0}),
    .dac_dunf(dac_dunf),

    .s_axi_aclk(s_axi_aclk),
    .s_axi_aresetn(s_axi_aresetn),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awready(s_axi_awready),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wready(s_axi_wready),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bready(s_axi_bready),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arready(s_axi_arready),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rready(s_axi_rready)
  );

endmodule
