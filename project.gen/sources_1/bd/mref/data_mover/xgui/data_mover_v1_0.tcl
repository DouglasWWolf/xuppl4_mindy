# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "AW" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BURST_SIZE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BYTE_COUNT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DW" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SRC_ADDRESS" -parent ${Page_0}


}

proc update_PARAM_VALUE.AW { PARAM_VALUE.AW } {
	# Procedure called to update AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AW { PARAM_VALUE.AW } {
	# Procedure called to validate AW
	return true
}

proc update_PARAM_VALUE.BURST_SIZE { PARAM_VALUE.BURST_SIZE } {
	# Procedure called to update BURST_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BURST_SIZE { PARAM_VALUE.BURST_SIZE } {
	# Procedure called to validate BURST_SIZE
	return true
}

proc update_PARAM_VALUE.BYTE_COUNT { PARAM_VALUE.BYTE_COUNT } {
	# Procedure called to update BYTE_COUNT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BYTE_COUNT { PARAM_VALUE.BYTE_COUNT } {
	# Procedure called to validate BYTE_COUNT
	return true
}

proc update_PARAM_VALUE.DW { PARAM_VALUE.DW } {
	# Procedure called to update DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DW { PARAM_VALUE.DW } {
	# Procedure called to validate DW
	return true
}

proc update_PARAM_VALUE.SRC_ADDRESS { PARAM_VALUE.SRC_ADDRESS } {
	# Procedure called to update SRC_ADDRESS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SRC_ADDRESS { PARAM_VALUE.SRC_ADDRESS } {
	# Procedure called to validate SRC_ADDRESS
	return true
}


proc update_MODELPARAM_VALUE.DW { MODELPARAM_VALUE.DW PARAM_VALUE.DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DW}] ${MODELPARAM_VALUE.DW}
}

proc update_MODELPARAM_VALUE.AW { MODELPARAM_VALUE.AW PARAM_VALUE.AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AW}] ${MODELPARAM_VALUE.AW}
}

proc update_MODELPARAM_VALUE.BYTE_COUNT { MODELPARAM_VALUE.BYTE_COUNT PARAM_VALUE.BYTE_COUNT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BYTE_COUNT}] ${MODELPARAM_VALUE.BYTE_COUNT}
}

proc update_MODELPARAM_VALUE.BURST_SIZE { MODELPARAM_VALUE.BURST_SIZE PARAM_VALUE.BURST_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BURST_SIZE}] ${MODELPARAM_VALUE.BURST_SIZE}
}

proc update_MODELPARAM_VALUE.SRC_ADDRESS { MODELPARAM_VALUE.SRC_ADDRESS PARAM_VALUE.SRC_ADDRESS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SRC_ADDRESS}] ${MODELPARAM_VALUE.SRC_ADDRESS}
}

