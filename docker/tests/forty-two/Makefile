.PHONY: all

all: ten/libten.so eleven/libeleven.so

ten/libten.so: ten/ten.c ten/ten.h
	# rpath will be removed by patchelf
	gcc -fPIC -shared -o $@ -Wl,-rpath=$$ORIGIN -Wl,--no-undefined $<

eleven/libeleven.so: eleven/eleven.c eleven/eleven.h ten/libten.so
	# rpath will be added by patchelf
	gcc -fPIC -shared -o $@ -Wl,--no-undefined $< -Lten -lten
