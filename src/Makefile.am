bin_PROGRAMS = leqm-nrt
leqm_nrt_SOURCES = leqm-nrt.c
leqm_nrt_CCFLAGS =

# Platform-specific linker flags
if LINUX
leqm_nrt_LDFLAGS = -Wl,--no-as-needed
endif

if OSX
leqm_nrt_LDFLAGS =
endif

if WINDOWS
leqm_nrt_LDFLAGS =
endif

# Custom targets for platform-specific builds with specific naming
leqm_macos: leqm-nrt
	mkdir -p ../build
	cp leqm-nrt ../build/leqm_macos

leqm_ubuntu: leqm-nrt
	mkdir -p ../build
	cp leqm-nrt ../build/leqm_ubuntu 
