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

module axi_adc_jesd204_if #(
  parameter DEVICE_TYPE = 0,
  parameter NUM_LANES = 1,
  parameter NUM_CHANNELS = 1,
  parameter CHANNEL_WIDTH = 16
) (
  // jesd interface
  // rx_clk is (line-rate/40)

  input                                       rx_clk,
  input       [3:0]                           rx_sof,
  input       [NUM_LANES*32-1:0]              rx_data,

  // adc data output

  output     [NUM_LANES*CHANNEL_WIDTH*2-1:0]  adc_data
);

  localparam TAIL_BITS = 16 - CHANNEL_WIDTH;
  localparam DATA_PATH_WIDTH = 2 * NUM_LANES / NUM_CHANNELS;
  localparam H = NUM_LANES / NUM_CHANNELS / 2;
  localparam HD = NUM_LANES > NUM_CHANNELS ? 1 : 0;
  localparam OCT_OFFSET = HD ? 32 : 8;

  wire [NUM_LANES*32-1:0] rx_data_s;

  // data multiplex

  generate
  genvar i;
  genvar j;
  for (i = 0; i < NUM_CHANNELS; i = i + 1) begin: g_deframer_outer
    for (j = 0; j < DATA_PATH_WIDTH; j = j + 1) begin: g_deframer_inner
      localparam k = j + i * DATA_PATH_WIDTH;
      localparam adc_lsb = k * CHANNEL_WIDTH;
      localparam adc_msb = adc_lsb + CHANNEL_WIDTH - 1;
      localparam oct0_lsb = HD ? ((i * H + j % H) * 64 + (j / H) * 8) : (k * 16);
      localparam oct0_msb = oct0_lsb + 7;
      localparam oct1_lsb = oct0_lsb + OCT_OFFSET + TAIL_BITS;
      localparam oct1_msb = oct0_msb + OCT_OFFSET;

      assign adc_data[adc_msb:adc_lsb] = {rx_data_s[oct0_msb:oct0_lsb],rx_data_s[oct1_msb:oct1_lsb]};
    end
  end
  endgenerate

  // frame-alignment

  generate
  genvar n;
  for (n = 0; n < NUM_LANES; n = n + 1) begin: g_xcvr_if
    ad_xcvr_rx_if #(
      .DEVICE_TYPE (DEVICE_TYPE)
    ) i_xcvr_if (
      .rx_clk (rx_clk),
      .rx_ip_sof (rx_sof),
      .rx_ip_data (rx_data[((n*32)+31):(n*32)]),
      .rx_sof (),
      .rx_data (rx_data_s[((n*32)+31):(n*32)])
    );
  end
  endgenerate

endmodule
