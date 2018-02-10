ifeq ($(PLATFORM),x86_64)
  all: vsyscall_trace
else
  all:
endif

vsyscall_trace: vsyscall_trace.c
	$(CC) -o $@ $< -ldl

clean:
	$(RM) -f vsyscall_trace

.PHONY: clean
