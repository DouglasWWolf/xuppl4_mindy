# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DATA_WBITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FD_FIFO_DEPTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FD_FIFO_TYPE" -parent ${Page_0}


}

proc update_PARAM_VALUE.DATA_WBITS { PARAM_VALUE.DATA_WBITS } {
	# Procedure called to update DATA_WBITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WBITS { PARAM_VALUE.DATA_WBITS } {
	# Procedure called to validate DATA_WBITS
	return true
}

proc update_PARAM_VALUE.FD_FIFO_DEPTH { PARAM_VALUE.FD_FIFO_DEPTH } {
	# Procedure called to update FD_FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FD_FIFO_DEPTH { PARAM_VALUE.FD_FIFO_DEPTH } {
	# Procedure called to validate FD_FIFO_DEPTH
	return true
}

proc update_PARAM_VALUE.FD_FIFO_TYPE { PARAM_VALUE.FD_FIFO_TYPE } {
	# Procedure called to update FD_FIFO_TYPE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FD_FIFO_TYPE { PARAM_VALUE.FD_FIFO_TYPE } {
	# Procedure called to validate FD_FIFO_TYPE
	return true
}


proc update_MODELPARAM_VALUE.DATA_WBITS { MODELPARAM_VALUE.DATA_WBITS PARAM_VALUE.DATA_WBITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WBITS}] ${MODELPARAM_VALUE.DATA_WBITS}
}

proc update_MODELPARAM_VALUE.FD_FIFO_DEPTH { MODELPARAM_VALUE.FD_FIFO_DEPTH PARAM_VALUE.FD_FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FD_FIFO_DEPTH}] ${MODELPARAM_VALUE.FD_FIFO_DEPTH}
}

proc update_MODELPARAM_VALUE.FD_FIFO_TYPE { MODELPARAM_VALUE.FD_FIFO_TYPE PARAM_VALUE.FD_FIFO_TYPE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FD_FIFO_TYPE}] ${MODELPARAM_VALUE.FD_FIFO_TYPE}
}

