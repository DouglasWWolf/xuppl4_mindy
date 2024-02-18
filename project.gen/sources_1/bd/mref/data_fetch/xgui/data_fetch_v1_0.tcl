# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "AXI_BURST_SIZE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FD_FIFO_DEPTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FD_FIFO_TYPE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PCIE_BITS" -parent ${Page_0}


}

proc update_PARAM_VALUE.AXI_BURST_SIZE { PARAM_VALUE.AXI_BURST_SIZE } {
	# Procedure called to update AXI_BURST_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_BURST_SIZE { PARAM_VALUE.AXI_BURST_SIZE } {
	# Procedure called to validate AXI_BURST_SIZE
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

proc update_PARAM_VALUE.PCIE_BITS { PARAM_VALUE.PCIE_BITS } {
	# Procedure called to update PCIE_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PCIE_BITS { PARAM_VALUE.PCIE_BITS } {
	# Procedure called to validate PCIE_BITS
	return true
}


proc update_MODELPARAM_VALUE.PCIE_BITS { MODELPARAM_VALUE.PCIE_BITS PARAM_VALUE.PCIE_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PCIE_BITS}] ${MODELPARAM_VALUE.PCIE_BITS}
}

proc update_MODELPARAM_VALUE.AXI_BURST_SIZE { MODELPARAM_VALUE.AXI_BURST_SIZE PARAM_VALUE.AXI_BURST_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_BURST_SIZE}] ${MODELPARAM_VALUE.AXI_BURST_SIZE}
}

proc update_MODELPARAM_VALUE.FD_FIFO_DEPTH { MODELPARAM_VALUE.FD_FIFO_DEPTH PARAM_VALUE.FD_FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FD_FIFO_DEPTH}] ${MODELPARAM_VALUE.FD_FIFO_DEPTH}
}

proc update_MODELPARAM_VALUE.FD_FIFO_TYPE { MODELPARAM_VALUE.FD_FIFO_TYPE PARAM_VALUE.FD_FIFO_TYPE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FD_FIFO_TYPE}] ${MODELPARAM_VALUE.FD_FIFO_TYPE}
}

