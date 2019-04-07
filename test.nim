import note
import tables, terminal


var pad: Pad = @[]



pad.info("Trying to update...", {"progress": $0})
pad.info("Trying to update...", {"progress": $10})
pad.info("Trying to update...", {"progress": $20})
pad.info("Trying to update...", {"progress": $30})
pad.info("Trying to update...", {"progress": $40})
pad.info("Trying to update...", {"progress": $50})
pad.info("Trying to update...", {"progress": $60})
pad.info("Trying to update...", {"progress": $70})
pad.info("Trying to update...", {"progress": $80, "threat_detected": "STACK_LIMIT_NEAR_MAX"})
pad.warn("Stack Limit Reached! Trying to extend...", {"threat": "STACK_LIMIT_NEAR_MAX"})
pad.debug("||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||", {"bruh": "moment"})
pad.error("This is a ridiculously long error message and should be clipping in the terminal, make sure to contact the systems administrator to make sure the rest of the mainframe doesn't catch fire!")