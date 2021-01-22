#---------------------------------------------------------------------------------
# Clear the implicit built in rules
#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------
ifeq ($(strip $(DEVKITPPC)),)
$(error "Please set DEVKITPPC in your environment. export DEVKITPPC=<path to>devkitPPC")
endif

include $(DEVKITPPC)/gamecube_rules

ifeq ($(REGION),)

all: us jp eu
us: elf2rel
	@$(MAKE) --no-print-directory REGION=us GAMECODE=GM2E8P
gaiden: elf2rel
	@$(MAKE) --no-print-directory REGION=us GAMECODE=GM2EGD
jp: elf2rel
	@$(MAKE) --no-print-directory REGION=jp GAMECODE=GM2J8P
eu: elf2rel
	@$(MAKE) --no-print-directory REGION=eu GAMECODE=GM2P8P

clean: clean_elf2rel
	@$(MAKE) --no-print-directory clean_target REGION=us GAMECODE=GM2E8P
	@$(MAKE) --no-print-directory clean_target REGION=us GAMECODE=GM2EGD
	@$(MAKE) --no-print-directory clean_target REGION=jp GAMECODE=GM2J8P
	@$(MAKE) --no-print-directory clean_target REGION=eu GAMECODE=GM2P8P

#---------------------------------------------------------------------------------
# For now, make elf2rel a phony target
# Place target here (instead of inside recursive Makefile call) so it's only built once
#---------------------------------------------------------------------------------

# Unexport some compiler vars exported by devkitppc as they interfere
# when we build elf2rel, which uses the system compiler
unexport AS
unexport CC
unexport CXX
unexport AR
unexport OBJCOPY
unexport STRIP
unexport NM
unexport RANLIB

ELF2REL_BUILD := $(CURDIR)/dep/ttyd-tools/ttyd-tools/elf2rel/build

elf2rel:
	@echo "Compiling elf2rel..."
	mkdir -p $(ELF2REL_BUILD)
	cd $(ELF2REL_BUILD) && cmake ..
	$(MAKE) -C $(ELF2REL_BUILD) -f $(ELF2REL_BUILD)/Makefile

clean_elf2rel:
	@echo "clean ... elf2rel"
	@rm -rf $(ELF2REL_BUILD)

.PHONY: all clean us jp eu elf2rel clean_elf2rel

else

#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# INCLUDES is a list of directories containing extra header files
#---------------------------------------------------------------------------------
TARGET		:=	$(notdir $(CURDIR)).$(GAMECODE)
BUILD		:=	build.$(GAMECODE)
SOURCES		:=	rel $(wildcard rel/*)
DATA		:=	data  
INCLUDES	:=	rel/include

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------

MACHDEP		= -mno-sdata -mgcn -DGEKKO -mcpu=750 -meabi -mhard-float

CFLAGS		= -nostdlib -ffreestanding -ffunction-sections -fdata-sections -g -Os -Wall $(MACHDEP) $(INCLUDE)
CXXFLAGS	= -fno-exceptions -fno-rtti -std=gnu++17 $(CFLAGS)
ASFLAGS     = -mregnames # Don't require % in front of register names

LDFLAGS		= -r -e _prolog -u _prolog -u _epilog -u _unresolved -Wl,--gc-sections -nostdlib -g $(MACHDEP) -Wl,-Map,$(notdir $@).map

# Platform options
ifeq ($(GAMECODE),GM2E8P)
	CFLAGS += -DMKB2_US
	ASFLAGS += -DMKB2_US
	PRINTVER = "US"
else ifeq ($(GAMECODE),GM2EGD)
	CFLAGS += -DMKB2_US
	ASFLAGS += -DMKB2_US
	PRINTVER = "GAIDEN"
else ifeq ($(GAMECODE),GM2J8P)
	CFLAGS += -DMKB2_JP
	ASFLAGS += -DMKB2_JP
	PRINTVER = "JP"
else ifeq ($(GAMECODE),GM2P8P)
	CFLAGS += -DMKB2_EU
	ASFLAGS += -DMKB2_EU
	PRINTVER = "EU"
endif


#---------------------------------------------------------------------------------
# any extra libraries we wish to link with the project
#---------------------------------------------------------------------------------
# Temporarily remove the math library to avoid conflicts
# LIBS	:= -lm
LIBS	:= 

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS	:=

#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT	:=	$(CURDIR)/$(TARGET)

export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
			$(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR	:=	$(CURDIR)/$(BUILD)

#---------------------------------------------------------------------------------
# automatically build a list of object files for our project
#---------------------------------------------------------------------------------
CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
sFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.S)))
BINFILES	:=	$(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
	export LD	:=	$(CC)
else
	export LD	:=	$(CXX)
endif

export OFILES_BIN	:=	$(addsuffix .o,$(BINFILES))
export OFILES_SOURCES := $(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(sFILES:.s=.o) $(SFILES:.S=.o)
export OFILES := $(OFILES_BIN) $(OFILES_SOURCES)

export HFILES := $(addsuffix .h,$(subst .,_,$(BINFILES)))

# For REL linking
export LDFILES		:= $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.ld)))
export MAPFILE		:= $(CURDIR)/rel/include/mkb2.$(REGION).lst
ifeq ($(REGION),us)
	export BANNERFILE	:= $(CURDIR)/image/banner_us.raw
	export ICONFILE		:= $(CURDIR)/image/icon_us.raw
else ifeq ($(REGION),jp)
	export BANNERFILE	:= $(CURDIR)/image/banner_jp.raw
	export ICONFILE		:= $(CURDIR)/image/icon_jp.raw
else ifeq ($(REGION),eu)
	export BANNERFILE	:= $(CURDIR)/image/banner_eu.raw
	export ICONFILE		:= $(CURDIR)/image/icon_eu.raw
endif

#---------------------------------------------------------------------------------
# build a list of include paths
#---------------------------------------------------------------------------------
export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
			$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
			-I$(CURDIR)/$(BUILD) \
			-I$(LIBOGC_INC)

#---------------------------------------------------------------------------------
# build a list of library paths
#---------------------------------------------------------------------------------
export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib) \
			-L$(LIBOGC_LIB)

export OUTPUT	:=	$(CURDIR)/$(TARGET)
.PHONY: $(BUILD) clean_target

#---------------------------------------------------------------------------------
$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

#---------------------------------------------------------------------------------
clean_target:
	@echo clean ... $(GAMECODE)
	@rm -fr $(BUILD) $(OUTPUT).elf $(OUTPUT).dol $(OUTPUT).rel $(OUTPUT).gci

#---------------------------------------------------------------------------------
else

DEPENDS	:=	$(OFILES:.o=.d)

TTYDTOOLS := $(abspath $(CURDIR)/../dep/ttyd-tools/ttyd-tools)
ELF2REL := $(TTYDTOOLS)/elf2rel/build/elf2rel
GCIPACK := /usr/bin/env python3 $(TTYDTOOLS)/gcipack/gcipack.py

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
$(OUTPUT).gci: $(OUTPUT).rel $(BANNERFILE) $(ICONFILE)
$(OUTPUT).rel: $(OUTPUT).elf $(MAPFILE)
$(OUTPUT).elf: $(LDFILES) $(OFILES)

$(OFILES_SOURCES) : $(HFILES)

# REL linking
%.rel: %.elf
	@echo output ... $(notdir $@)
	@$(ELF2REL) $< -s $(MAPFILE) --rel-version 2
	
%.gci: %.rel
	@echo packing ... $(notdir $@)
	@$(GCIPACK) $< "rel" "Super Monkey Ball 2" "ApeSphere ($(PRINTVER))" $(BANNERFILE) $(ICONFILE) $(GAMECODE)
	
#---------------------------------------------------------------------------------
# This rule links in binary data with the .jpg extension
#---------------------------------------------------------------------------------
%.jpg.o	%_jpg.h :	%.jpg
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	$(bin2o)

-include $(DEPENDS)

#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------
endif
