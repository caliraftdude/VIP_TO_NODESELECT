# version 0.1
# Node select iRule
# The intention of this irule is to ease the configuration of VIPs in an environment where SSL inspection
# is being performed using an F5 sandwich.  The outside F5 uses a network vip (for example, a /29).  The
# inside F5 is configured the same way it always is.  The datagroup is then populated with IP translation
# that translates the resolved DNS name for the outside IP to the inside node address.  That way, a
# datagroup is the only other additional configuration item to support this process.

when RULE_INIT {
    #  NOTE:  You must have a datagroup named VIP_TO_POOL_MEMBER for this irule to function.
	
	log local0. "workday-node-select iRule starting..."
	set static::poolname "web01"
	set static::nodeport 80
	
	# 1, 2, 4, or 8 or any sum of these for different log levels
	set static::debug 4
}


when CLIENT_ACCEPTED {
	
	if { [class match [IP::local_addr] equals VIP_TO_POOL_MEMBER] } {
		call logger 2 [IP::local_addr] "Matched [IP::local_addr] in the VIP_TO_POOL_MEMBER datagroup"
	
		set nodeip [class match -value [IP::local_addr] equals VIP_TO_POOL_MEMBER]
		call logger 2 [IP::local_addr] "Set LB server to $static::poolname $nodeip $static::nodeport"
		
		# Use the pool command if the real server is in the pool, node if it is not.
		node $nodeip $static::nodeport
		#pool $static::poolname member $nodeip $static::nodeport
		
		unset -nocomplain static::nowebsite
	}
	else {
		call logger 2 [IP::local_addr] "VIP address was not matched, returning a 404 page"
		set static::nowebsite 1
	}
}

when HTTP_REQUEST {
	if { [info exists static::nowebsite] } {
		HTTP::respond 404 content "<html><head><title>Forbidden</title></head><body><br /><br /><br /><br /> <table width='100%'><tr><td align='center'><p class=MsoNormal> <u>404:  Incorrect request</u><br /><br />NOTICE: The requested application is not available</p></table></body></html>"	
	}
}

# proc logger
# params:
#    level:   logging level for the message.  1, 2, 4, or 8 or any sum of these for different log levels
#    vipip:   VIP ip address to add some clarity and value to the log entries
#    message: The message to log
#
# todo:  Add HSL support
proc logger {level vipip message} {
	if {$static::debug & $level} {	
		set key "($vipip)"
		log local0. "$key::   $message"
	}
}