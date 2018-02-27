PLATFORM ?= $(shell uname -m)

ifeq ($(PLATFORM),x86_64)
  TARGETS = vsyscall_trace vsyscall_trace_test
else
  TARGETS =
endif

all: $(TARGETS)

vsyscall_trace: vsyscall_trace.c
	$(CC) -o $@ $< -ldl

vsyscall_trace_test: vsyscall_trace.c
	$(CC) -o $@ $< -ldl -DVSYSCALL_BASE=0xfffffffffe600000 -DDEBUG

clean:
	$(RM) $(TARGETS)

.PHONY: clean
