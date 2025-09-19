AUTOMAKE_OPTIONS = foreign
SUBDIRS = src
dist_doc_DATA = README.md

# Define temp directory for build artifacts
TEMPDIR = temp

# Debug build settings moved to temp directory
DBGDIR = $(TEMPDIR)/debug
DBGEXE = $(DBGDIR)/leqm-nrt
DBGOBJS = $(addprefix $(DBGDIR)/, $(OBJS))
DBGCFLAGS = -g3 -O0 -DDEBUG -DHAVE_LIBSNDFILE -DHAVE_LIBDI -DVERSION=\"0.30\" -I/usr/include/di -lm -lpthread -lrt -lsndfile -L/usr/lib/di -o src/leqm-nrt  src/leqm-nrt.c -ldi -lrt -lpthread -lm -lsndfile

# Debug rules
debug: $(DBGEXE)

$(DBGEXE): $(DBGOBJS)
	mkdir -p $(DBGDIR)
	$(CC) $(DBGCFLAGS) -o $(DBGEXE) $^

$(DBGDIR)/%.o: %.c
	mkdir -p $(DBGDIR)
	$(CC) -c $(DBGCFLAGS) -o $@ $<

# Clean temp directory and all build artifacts
clean-local:
	rm -rf $(TEMPDIR)
	rm -rf build

debug-clean:
	rm -rf $(DBGDIR)
