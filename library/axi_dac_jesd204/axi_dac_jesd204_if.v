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

module axi_dac_jesd204_if #(
  parameter DEVICE_TYPE = 0, // altera (0x1) or xilinx (0x0)
  parameter NUM_LANES = 8,
  parameter NUM_CHANNELS = 4
) (
  // jesd interface
  // tx_clk is (line-rate/40)

  input                       tx_clk,
  output [NUM_LANES*32-1:0]   tx_data,

  // dac interface

  input                       dac_rst,
  input   [NUM_LANES*32-1:0]  dac_data
);

  localparam DATA_PATH_WIDTH = 2 * NUM_LANES / NUM_CHANNELS;
  localparam H = NUM_LANES / NUM_CHANNELS / 2;
  localparam HD = NUM_LANES > NUM_CHANNELS ? 1 : 0;
  localparam OCT_OFFSET = HD ? 32 : 8;

  // internal registers

  reg    [NUM_LANES*32-1:0]  tx_data_r = 'd0;
  wire   [NUM_LANES*32-1:0]  tx_data_s;

  always @(posedge tx_clk) begin
    if (dac_rst == 1'b1) begin
      tx_data_r <= 'h00;
    end else begin
      tx_data_r <= tx_data_s;
    end
  end

  generate
  genvar lsb;
  genvar i, j;
  if (DEVICE_TYPE == 1) begin
    for (lsb = 0; lsb < NUM_LANES*32; lsb = lsb + 32) begin: g_swizzle
       assign tx_data[lsb+31:lsb] = {
         tx_data_r[lsb+7:lsb],
         tx_data_r[lsb+15:lsb+8],
         tx_data_r[lsb+23:lsb+16],
         tx_data_r[lsb+31:lsb+24]
       };
    end
  end else begin
    assign tx_data = tx_data_r;
  end

  for (i = 0; i < NUM_CHANNELS; i = i + 1) begin: g_framer_outer
    for (j = 0; j < DATA_PATH_WIDTH; j = j + 1) begin: g_framer_inner
      localparam k = j + i * DATA_PATH_WIDTH;
      localparam dac_lsb = k * 16;
      localparam oct0_lsb = HD ? ((i * H + j % H) * 64 + (j / H) * 8) : (k * 16);
      localparam oct0_msb = oct0_lsb + 7;
      localparam oct1_lsb = oct0_lsb + OCT_OFFSET;
      localparam oct1_msb = oct0_msb + OCT_OFFSET;

      assign tx_data_s[oct0_msb:oct0_lsb] = dac_data[dac_lsb+15:dac_lsb+8];
      assign tx_data_s[oct1_msb:oct1_lsb] = dac_data[dac_lsb+7:dac_lsb];
    end
  end
  endgenerate

endmodule
