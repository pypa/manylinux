ifeq ($(PLATFORM),x86_64)
  all: vsyscall_emu.so
else
  all:
endif

vsyscall_emu.so: vsyscall_emu.c
	$(CC) -fPIC -shared -o $@ $< -ldl

clean:
	$(RM) -f vsyscall_emu.so

.PHONY: clean
