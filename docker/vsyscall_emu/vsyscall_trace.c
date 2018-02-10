/* Using ptrace, catch when a process in a process tree is about to
 * segfault from an attempted vsyscall, and fix it up to use the vDSO
 * instead.
 *
 * usage: vsyscall_trace -p <pid>...
 *        vsyscall_trace <cmd> [args...]
 *
 * In the first mode, traces a process and all its children, until they
 * exit. In the second mode, run and trace a child process -- unless
 * vsyscalls are enabled, in which case it will just exec the child
 * process directly. Because the second mode waits on child processes (as
 * required by the ptrace API), it is usable as init inside a container.
 * Whether or not it runs as init, it will block until all descendant
 * processes exit.
 *
 * This program itself uses no vsyscalls, so it can be safely
 * dynamically linked against an older glibc.
 */

#define _GNU_SOURCE
#include <sys/auxv.h>
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#ifdef DEBUG
#define debug_printf printf
#else
#define debug_printf(...) 0
#endif

/* These are ABI constants: see arch/x86/include/uapi/asm/vsyscall.h
 * in the kernel source (probably installed on your system as
 * <asm/vsyscall.h>). They start at VSYSCALL_ADDR, and
 * increase by 1024 for each call. */
const unsigned long VSYS_gettimeofday = 0xffffffffff600000,
                    VSYS_time = 0xffffffffff600400,
                    VSYS_getcpu = 0xffffffffff600800;

/* The vDSO is an area of memory that looks like a normal relocatable
 * dynamic library, magically placed in your address space by the
 * kernel. While it's mapped at a different address in each process when
 * ASLR is enabled, the relative offsets are the same, since the kernel
 * only contains one vDSO. These variables contain the relative offsets
 * as found in the current process. */
unsigned long VDSO_gettimeofday, VDSO_time, VDSO_getcpu;

/* Look up the vDSO base address for a process in its auxiliary vector.
 * See proc(5) and getauxval(3). If we can ptrace the process, we should
 * have permissions to do this. */
unsigned long vdso_address(pid_t pid) {
	char *filename;
	asprintf(&filename, "/proc/%d/auxv", pid);
	int fd = open(filename, O_RDONLY);
	if (fd == -1) {
		return 0;
	}
	unsigned long buf[128];
	int i;
	if (read(fd, buf, sizeof(buf)) == -1) {
		close(fd);
		return 0;
	}
	close(fd);
	free(filename);

	for (i = 0; i < 128; i += 2) {
		if (buf[i] == AT_SYSINFO_EHDR) {
			return buf[i+1];
		} else if (buf[i] == 0) {
			return 0;
		}
	}
}

/* If the ptraced process segfaulted because it tried to call one of the
 * three vsyscalls, redirect its instruction pointer to the
 * corresponding vDSO address. The calling conventions are the same, so
 * we don't need to change / inspect arguments or do any other safety
 * checks - the process could have gotten here on its own. */
int handle_vsyscall(pid_t pid) {
	struct user_regs_struct regs;
	ptrace(PTRACE_GETREGS, pid, 0, &regs);
	if ((regs.rip & 0xfffffffffffff0ff) == 0xffffffffff600000) {
		debug_printf("handling vsyscall for %d\n", pid);
		unsigned long vdso = vdso_address(pid);
		if (vdso_address == 0) {
			debug_printf("couldn't find vdso\n");
			return 0;
		}

		if (regs.rip == VSYS_gettimeofday) {
			regs.rip = vdso | VDSO_gettimeofday;
		} else if (regs.rip == VSYS_time) {
			regs.rip = vdso | VDSO_time;
		} else if (regs.rip == VSYS_getcpu) {
			regs.rip = vdso | VDSO_getcpu;
		} else {
			debug_printf("invalid vsyscall %x\n", regs.rip);
			return 0;
		}
		ptrace(PTRACE_SETREGS, pid, 0, &regs);
		return 1;
	}
	return 0;
}

int main(int argc, char *argv[]) {
	pid_t pid, child_pid = 0;
	int wstatus, child_wstatus = 0;

	if (argc < 2) {
		printf("usage: vsyscall_trace -p <pid>...\n");
		printf("       vsyscall_trace <cmd> [args...]\n");
		return 1;
	}

	/* Seize all the processes via ptrace. We don't need to track
	 * them, we only need to call wait(), and the options we're
	 * passing to PTRACE_SEIZE will cause us to silently pick up
	 * child processes too. */
	if (strcmp(argv[1], "-p") == 0) {
		int i;
		for (i = 2; i < argc; i++) {
			pid = atoi(argv[i]);
			if (ptrace(PTRACE_SEIZE, pid, 0, PTRACE_O_TRACEFORK | PTRACE_O_TRACEVFORK | PTRACE_O_TRACECLONE) != 0) {
				perror("PTRACE_SEIZE");
				return 1;
			}
		}
	} else {
		/* Test to see if vsyscalls work on this machine. If so,
		 * we don't need to do anything - exec the given command
		 * so we get entirely out of the way and don't risk
		 * breaking the process. */
		child_pid = fork();
		if (child_pid == -1) {
			perror("fork");
			return 1;
		} else if (child_pid == 0) {
			((time_t (*)(time_t *))VSYS_time)(NULL);
			return 0;
		} else {
			waitpid(child_pid, &wstatus, 0);
			/* If the child process segfaulted, it will show
			 * up as WIFSIGNALED instead of WIFEXITED. */
			if (WIFEXITED(wstatus)) {
				execvp(argv[1], &argv[1]);
				perror("execvp");
				return 1;
			}
		}

		/* Actually start the child process. */
		child_pid = fork();
		if (child_pid == -1) {
			perror("fork");
			return 1;
		} else if (child_pid == 0) {
			/* Allow the parent process to run PTRACE_SEIZE
			 * before continuing. */
			raise(SIGSTOP);
			execvp(argv[1], &argv[1]);
			perror("execvp");
			return 1;
		} else {
			if (ptrace(PTRACE_SEIZE, child_pid, 0, PTRACE_O_TRACEFORK | PTRACE_O_TRACEVFORK | PTRACE_O_TRACECLONE) != 0) {
				if (errno == EPERM) {
					fprintf(stderr, "Error: no kernel vsyscall support and ptrace is disabled.\n");
					fprintf(stderr, "Your kernel does not provide vsyscall emulation, and we cannot\n");
					fprintf(stderr, "work around this because ptrace is prohibited inside this container.\n");
					fprintf(stderr, "Either permit ptrace for this container (e.g., for Docker, use\n");
					fprintf(stderr, "docker run --security-opt=seccomp:unconfined) or boot your kernel\n");
					fprintf(stderr, "with vsyscall=emulate.\n");
				} else {
					perror("PTRACE_SEIZE");
				}
				kill(child_pid, SIGKILL);
				return 1;
			}

			fprintf(stderr, "Warning: using ptrace-based vsyscall emulation.\n");
			fprintf(stderr, "This container contains old binaries which require the use of the legacy\n");
			fprintf(stderr, "'vsyscall' feature of the Linux kernel, and your kernel does not provide\n");
			fprintf(stderr, "vsyscall emulation. We will attempt to emulate vsyscalls ourselves using\n");
			fprintf(stderr, "ptrace, but performance may suffer and other tools that use ptrace (e.g.,\n");
			fprintf(stderr, "gdb and strace) will not work.\n");
			fprintf(stderr, "To avoid this emulation, please boot your kernel with vsyscall=emulate.\n");
			kill(child_pid, SIGCONT);
		}
	}

	/* The vDSO shows up as an object in our address space naemd
	 * "linux-vdso.so.1" that's already been loaded. */
	void *vdso = dlopen("linux-vdso.so.1", RTLD_LAZY | RTLD_NOLOAD);
	VDSO_gettimeofday = (unsigned long)dlsym(vdso, "__vdso_gettimeofday") & 0xfff;
	VDSO_time = (unsigned long)dlsym(vdso, "__vdso_time") & 0xfff;
	VDSO_getcpu = (unsigned long)dlsym(vdso, "__vdso_getcpu") & 0xfff;

	while ((pid = waitpid(-1, &wstatus, 0)) != -1) {
		if (WIFSTOPPED(wstatus)) {
			if (WSTOPSIG(wstatus) == SIGSEGV && handle_vsyscall(pid)) {
				/* The last argument to PTRACE_CONT is
				 * the signal to send - passing 0 means
				 * to suppress the signal. */
				ptrace(PTRACE_CONT, pid, 0, 0);
			} else {
				ptrace(PTRACE_CONT, pid, 0, WSTOPSIG(wstatus));
			}
		} else if (pid == child_pid && WIFEXITED(wstatus)) {
			/* Save this exit status so we can use it as our
			 * own exit status. But don't exit yet if there
			 * are further descendant processes still
			 * running. */
			child_wstatus = wstatus;
		}
	}
	if (errno != ECHILD) {
		perror("waitpid");
		return 1;
	}
	if (WIFSIGNALED(wstatus)) {
		/* Send ourselves the same signal that killed the child
		 * process, so our own parent process reports the right
		 * exit status. */
		raise(WTERMSIG(wstatus));
		/* In case that signal is not fatal, return nonzero. */
		return 1;
	} else {
		return WEXITSTATUS(wstatus);
	}
}
