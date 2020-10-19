# # Targets
# TARGETS:=
# 
# # Subdirectories
# SUBDIRS = fpga
# SUBDIRS_CLEAN = $(patsubst %,%.clean,$(SUBDIRS))
# 
# # Rules
# .PHONY: all
# all: $(SUBDIRS) $(TARGETS)
# 
# .PHONY: $(SUBDIRS)
# $(SUBDIRS):
# 	cd $@ && $(MAKE)
# 
# .PHONY: $(SUBDIRS_CLEAN)
# $(SUBDIRS_CLEAN):
# 	cd $(@:.clean=) && $(MAKE) clean
# 
# .PHONY: clean
# clean: $(SUBDIRS_CLEAN)
# 	-rm -rf $(TARGETS)
# 
# program:
# 	#djtgcfg prog -d Atlys --index 0 --file fpga/fpga.bit
#
#

.PHONY: project clean

project:
	vivado -mode tcl -source tcl/create_project.tcl

clean:
	rm -rf project_synth
	rm vivado*
