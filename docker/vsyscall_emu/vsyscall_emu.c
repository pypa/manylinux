#define _GNU_SOURCE
#include <sys/syscall.h>
#include <dlfcn.h>
#include <signal.h>
#include <ucontext.h>
#include <unistd.h>

static struct sigaction next_handler = {
	.sa_handler = SIG_DFL,
};

static int (*real_sigaction)(int, const struct sigaction *, struct sigaction *);

static sigset_t visible_oldset;

static int (*real_sigprocmask)(int, const sigset_t *, sigset_t *);

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

sighandler_t
signal(int signum, sighandler_t handler)
{
	struct sigaction sa = {
		.sa_handler = handler,
		.sa_flags = SA_RESETHAND | SA_NODEFER,
	}, oldsa;
	if (sigaction(signum, &sa, &oldsa) == 0) {
		return oldsa.sa_handler;
	} else {
		return SIG_ERR;
	}
}

int
sigprocmask (int how, const sigset_t *newset, sigset_t *oldset)
{
	sigset_t newset_without_sigsegv;
	const sigset_t *to_install;
	int result;

	if (newset && how == SIG_BLOCK && sigismember(newset, SIGSEGV)) {
		newset_without_sigsegv = *newset;
		sigdelset(&newset_without_sigsegv, SIGSEGV);
		to_install = &newset_without_sigsegv;
	} else {
		to_install = newset;
	}

	result = real_sigprocmask(how, to_install, oldset);
	if (oldset) {
		*oldset = visible_oldset;
	}
	if (newset) {
		visible_oldset = *newset;
	}
	return result;
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
		return;
	}

	real_sigprocmask = dlsym(RTLD_NEXT, "sigprocmask");
	if (!real_sigprocmask) {
		return;
	}
	if (real_sigprocmask(SIG_BLOCK, NULL, &visible_oldset) == -1) {
		return;
	}

	struct sigaction sa = {
		.sa_sigaction = handler,
		.sa_flags = SA_RESTART | SA_SIGINFO,
	};
	real_sigaction(SIGSEGV, &sa, NULL);
}
