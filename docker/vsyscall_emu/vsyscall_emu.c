#define _GNU_SOURCE
#include <sys/syscall.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <ucontext.h>
#include <unistd.h>

static struct sigaction next_handler = {
	.sa_handler = SIG_DFL,
};

static int (*real_sigaction)(int, const struct sigaction *, struct sigaction *);

int
sigaction(int signum,
          const struct sigaction *act,
          struct sigaction *old_act)
{
	if (signum != SIGSEGV) {
		return real_sigaction(signum, act, old_act);
	}

	if (old_act) {
		*old_act = next_handler;
	}
	if (act) {
		next_handler = *act;
	}
	return 0;
}


static greg_t VSYS_gettimeofday = 0xffffffffff600000;
static long
syscall_gettimeofday(long arg1, long arg2) {
	return syscall(SYS_gettimeofday, arg1, arg2);
}

static greg_t VSYS_time = 0xffffffffff600400;
static long
syscall_time(long arg1) {
	return syscall(SYS_time, arg1);
}

static greg_t VSYS_getcpu = 0xffffffffff600800;
static long
syscall_getcpu(long arg1, long arg2, long arg3) {
	return syscall(SYS_getcpu, arg1, arg2, arg3);
}

static void
handler(int sig, siginfo_t *si, void *ctx)
{
	greg_t *regs = ((ucontext_t *)ctx)->uc_mcontext.gregs;
	if (regs[REG_RIP] == VSYS_gettimeofday) {
		regs[REG_RIP] = (greg_t)(void *)syscall_gettimeofday;
	} else if (regs[REG_RIP] == VSYS_time) {
		regs[REG_RIP] = (greg_t)(void *)syscall_time;
	} else if (regs[REG_RIP] == VSYS_getcpu) {
		regs[REG_RIP] = (greg_t)(void *)syscall_getcpu;
	} else if (next_handler.sa_flags & SA_SIGINFO) {
		next_handler.sa_sigaction(sig, si, ctx);
	} else if (next_handler.sa_handler != SIG_DFL && next_handler.sa_handler != SIG_IGN) {
		next_handler.sa_handler(sig);
	} else {
		// SIG_IGN is treated as SIG_DFL
		struct sigaction sa = {
			.sa_handler = SIG_DFL,
		};
		real_sigaction(sig, &sa, NULL);
	}
}

__attribute__((constructor))
static void
init(void)
{
	real_sigaction = dlsym(RTLD_NEXT, "sigaction");
	if (!real_sigaction) {
		fprintf(stderr, "dlsym(\"sigaction\"): %s", dlerror());
		abort();
	}

	struct sigaction sa = {
		.sa_sigaction = handler,
		.sa_flags = SA_RESTART | SA_SIGINFO,
	};
	if (real_sigaction(SIGSEGV, &sa, NULL) != 0) {
		perror("sigaction");
		abort();
	}
}
