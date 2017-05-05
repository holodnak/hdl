# ip

source ../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip.tcl

adi_ip_create axi_adc_jesd204
adi_ip_files axi_adc_jesd204 [list \
  "$ad_hdl_dir/library/common/ad_rst.v" \
  "$ad_hdl_dir/library/common/ad_pnmon.v" \
  "$ad_hdl_dir/library/common/ad_datafmt.v" \
  "$ad_hdl_dir/library/common/up_axi.v" \
  "$ad_hdl_dir/library/common/up_xfer_cntrl.v" \
  "$ad_hdl_dir/library/common/up_xfer_status.v" \
  "$ad_hdl_dir/library/common/up_clock_mon.v" \
  "$ad_hdl_dir/library/common/up_adc_common.v" \
  "$ad_hdl_dir/library/common/up_adc_channel.v" \
  "$ad_hdl_dir/library/common/ad_xcvr_rx_if.v" \
  "axi_adc_jesd204_core.v" \
  "axi_adc_jesd204_channel.v" \
  "axi_adc_jesd204_if.v" \
  "axi_adc_jesd204_pnmon.v" \
  "axi_adc_jesd204.v" \
  ]

adi_ip_properties axi_adc_jesd204

set_property hide_in_gui {1} [ipx::current_core]

ipx::save_core [ipx::current_core]

