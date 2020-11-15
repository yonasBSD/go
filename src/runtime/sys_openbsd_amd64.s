// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// System calls and other sys.stuff for AMD64, OpenBSD.
// System calls are implemented in libc/libpthread, this file
// contains trampolines that convert from Go to C calling convention.
// Some direct system call implementations currently remain.
//

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

#define CLOCK_MONOTONIC	$3

TEXT runtime·settls(SB),NOSPLIT,$0
	// Nothing to do, pthread already set thread-local storage up.
	RET

// mstart_stub is the first function executed on a new thread started by pthread_create.
// It just does some low-level setup and then calls mstart.
// Note: called with the C calling convention.
TEXT runtime·mstart_stub(SB),NOSPLIT,$0
	// DI points to the m.
	// We are already on m's g0 stack.

	// Save callee-save registers.
	SUBQ	$48, SP
	MOVQ	BX, 0(SP)
	MOVQ	BP, 8(SP)
	MOVQ	R12, 16(SP)
	MOVQ	R13, 24(SP)
	MOVQ	R14, 32(SP)
	MOVQ	R15, 40(SP)

	// Load g and save to TLS entry.
	// See cmd/link/internal/ld/sym.go:computeTLSOffset.
	MOVQ	m_g0(DI), DX // g
	MOVQ	DX, -8(FS)

	// Someday the convention will be D is always cleared.
	CLD

	CALL	runtime·mstart(SB)

	// Restore callee-save registers.
	MOVQ	0(SP), BX
	MOVQ	8(SP), BP
	MOVQ	16(SP), R12
	MOVQ	24(SP), R13
	MOVQ	32(SP), R14
	MOVQ	40(SP), R15

	// Go is all done with this OS thread.
	// Tell pthread everything is ok (we never join with this thread, so
	// the value here doesn't really matter).
	XORL	AX, AX

	ADDQ	$48, SP
	RET

TEXT runtime·sigfwd(SB),NOSPLIT,$0-32
	MOVQ	fn+0(FP),    AX
	MOVL	sig+8(FP),   DI
	MOVQ	info+16(FP), SI
	MOVQ	ctx+24(FP),  DX
	PUSHQ	BP
	MOVQ	SP, BP
	ANDQ	$~15, SP     // alignment for x86_64 ABI
	CALL	AX
	MOVQ	BP, SP
	POPQ	BP
	RET

TEXT runtime·sigtramp(SB),NOSPLIT,$72
	// Save callee-saved C registers, since the caller may be a C signal handler.
	MOVQ	BX,  bx-8(SP)
	MOVQ	BP,  bp-16(SP)  // save in case GOEXPERIMENT=noframepointer is set
	MOVQ	R12, r12-24(SP)
	MOVQ	R13, r13-32(SP)
	MOVQ	R14, r14-40(SP)
	MOVQ	R15, r15-48(SP)
	// We don't save mxcsr or the x87 control word because sigtrampgo doesn't
	// modify them.

	MOVQ	DX, ctx-56(SP)
	MOVQ	SI, info-64(SP)
	MOVQ	DI, signum-72(SP)
	CALL	runtime·sigtrampgo(SB)

	MOVQ	r15-48(SP), R15
	MOVQ	r14-40(SP), R14
	MOVQ	r13-32(SP), R13
	MOVQ	r12-24(SP), R12
	MOVQ	bp-16(SP),  BP
	MOVQ	bx-8(SP),   BX
	RET

//
// These trampolines help convert from Go calling convention to C calling convention.
// They should be called with asmcgocall.
// A pointer to the arguments is passed in DI.
// A single int32 result is returned in AX.
// (For more results, make an args/results structure.)
TEXT runtime·pthread_attr_init_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	0(DI), DI		// arg 1 - attr
	CALL	libc_pthread_attr_init(SB)
	POPQ	BP
	RET

TEXT runtime·pthread_attr_destroy_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	0(DI), DI		// arg 1 - attr
	CALL	libc_pthread_attr_destroy(SB)
	POPQ	BP
	RET

TEXT runtime·pthread_attr_getstacksize_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 - stacksize
	MOVQ	0(DI), DI		// arg 1 - attr
	CALL	libc_pthread_attr_getstacksize(SB)
	POPQ	BP
	RET

TEXT runtime·pthread_attr_setdetachstate_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 - detachstate
	MOVQ	0(DI), DI		// arg 1 - attr
	CALL	libc_pthread_attr_setdetachstate(SB)
	POPQ	BP
	RET

TEXT runtime·pthread_create_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	SUBQ	$16, SP
	MOVQ	0(DI), SI		// arg 2 - attr
	MOVQ	8(DI), DX		// arg 3 - start
	MOVQ	16(DI), CX		// arg 4 - arg
	MOVQ	SP, DI			// arg 1 - &thread (discarded)
	CALL	libc_pthread_create(SB)
	MOVQ	BP, SP
	POPQ	BP
	RET

TEXT runtime·thrkill_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	8(DI), SI		// arg 2 - signal
	MOVQ	$0, DX			// arg 3 - tcb
	MOVL	0(DI), DI		// arg 1 - tid
	CALL	libc_thrkill(SB)
	POPQ	BP
	RET

TEXT runtime·thrsleep_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	8(DI), SI		// arg 2 - clock_id
	MOVQ	16(DI), DX		// arg 3 - abstime
	MOVQ	24(DI), CX		// arg 4 - lock
	MOVQ	32(DI), R8		// arg 5 - abort
	MOVQ	0(DI), DI		// arg 1 - id
	CALL	libc_thrsleep(SB)
	POPQ	BP
	RET

TEXT runtime·thrwakeup_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	8(DI), SI		// arg 2 - count
	MOVQ	0(DI), DI		// arg 1 - id
	CALL	libc_thrwakeup(SB)
	POPQ	BP
	RET

TEXT runtime·exit_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	0(DI), DI		// arg 1 exit status
	CALL	libc_exit(SB)
	MOVL	$0xf1, 0xf1  // crash
	POPQ	BP
	RET

TEXT runtime·getthrid_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	DI, BX			// BX is caller-save
	CALL	libc_getthrid(SB)
	MOVL	AX, 0(BX)		// return value
	POPQ	BP
	RET

TEXT runtime·raiseproc_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	0(DI), BX	// signal
	CALL	libc_getpid(SB)
	MOVL	AX, DI		// arg 1 pid
	MOVL	BX, SI		// arg 2 signal
	CALL	libc_kill(SB)
	POPQ	BP
	RET

TEXT runtime·sched_yield_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	CALL	libc_sched_yield(SB)
	POPQ	BP
	RET

TEXT runtime·mmap_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP			// make a frame; keep stack aligned
	MOVQ	SP, BP
	MOVQ	DI, BX
	MOVQ	0(BX), DI		// arg 1 addr
	MOVQ	8(BX), SI		// arg 2 len
	MOVL	16(BX), DX		// arg 3 prot
	MOVL	20(BX), CX		// arg 4 flags
	MOVL	24(BX), R8		// arg 5 fid
	MOVL	28(BX), R9		// arg 6 offset
	CALL	libc_mmap(SB)
	XORL	DX, DX
	CMPQ	AX, $-1
	JNE	ok
	CALL	libc_errno(SB)
	MOVLQSX	(AX), DX		// errno
	XORQ	AX, AX
ok:
	MOVQ	AX, 32(BX)
	MOVQ	DX, 40(BX)
	POPQ	BP
	RET

TEXT runtime·munmap_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 len
	MOVQ	0(DI), DI		// arg 1 addr
	CALL	libc_munmap(SB)
	TESTQ	AX, AX
	JEQ	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	POPQ	BP
	RET

TEXT runtime·madvise_trampoline(SB), NOSPLIT, $0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI	// arg 2 len
	MOVL	16(DI), DX	// arg 3 advice
	MOVQ	0(DI), DI	// arg 1 addr
	CALL	libc_madvise(SB)
	// ignore failure - maybe pages are locked
	POPQ	BP
	RET

TEXT runtime·open_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	8(DI), SI		// arg 2 - flags
	MOVL	12(DI), DX		// arg 3 - mode
	MOVQ	0(DI), DI		// arg 1 - path
	XORL	AX, AX			// vararg: say "no float args"
	CALL	libc_open(SB)
	POPQ	BP
	RET

TEXT runtime·close_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	0(DI), DI		// arg 1 - fd
	CALL	libc_close(SB)
	POPQ	BP
	RET

TEXT runtime·read_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 - buf
	MOVL	16(DI), DX		// arg 3 - count
	MOVL	0(DI), DI		// arg 1 - fd
	CALL	libc_read(SB)
	TESTL	AX, AX
	JGE	noerr
	CALL	libc_errno(SB)
	MOVL	(AX), AX		// errno
	NEGL	AX			// caller expects negative errno value
noerr:
	POPQ	BP
	RET

TEXT runtime·write_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 buf
	MOVL	16(DI), DX		// arg 3 count
	MOVL	0(DI), DI		// arg 1 fd
	CALL	libc_write(SB)
	TESTL	AX, AX
	JGE	noerr
	CALL	libc_errno(SB)
	MOVL	(AX), AX		// errno
	NEGL	AX			// caller expects negative errno value
noerr:
	POPQ	BP
	RET

TEXT runtime·pipe2_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	8(DI), SI		// arg 2 flags
	MOVQ	0(DI), DI		// arg 1 filedes
	CALL	libc_pipe2(SB)
	TESTL	AX, AX
	JEQ	3(PC)
	CALL	libc_errno(SB)
	MOVL	(AX), AX		// errno
	NEGL	AX			// caller expects negative errno value
	POPQ	BP
	RET

TEXT runtime·setitimer_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 new
	MOVQ	16(DI), DX		// arg 3 old
	MOVL	0(DI), DI		// arg 1 which
	CALL	libc_setitimer(SB)
	POPQ	BP
	RET

TEXT runtime·usleep_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	0(DI), DI		// arg 1 usec
	CALL	libc_usleep(SB)
	POPQ	BP
	RET

TEXT runtime·sysctl_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	8(DI), SI		// arg 2 miblen
	MOVQ	16(DI), DX		// arg 3 out
	MOVQ	24(DI), CX		// arg 4 size
	MOVQ	32(DI), R8		// arg 5 dst
	MOVQ	40(DI), R9		// arg 6 ndst
	MOVQ	0(DI), DI		// arg 1 mib
	CALL	libc_sysctl(SB)
	POPQ	BP
	RET

TEXT runtime·kqueue_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	CALL	libc_kqueue(SB)
	POPQ	BP
	RET

TEXT runtime·kevent_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 keventt
	MOVL	16(DI), DX		// arg 3 nch
	MOVQ	24(DI), CX		// arg 4 ev
	MOVL	32(DI), R8		// arg 5 nev
	MOVQ	40(DI), R9		// arg 6 ts
	MOVL	0(DI), DI		// arg 1 kq
	CALL	libc_kevent(SB)
	CMPL	AX, $-1
	JNE	ok
	CALL	libc_errno(SB)
	MOVL	(AX), AX		// errno
	NEGL	AX			// caller expects negative errno value
ok:
	POPQ	BP
	RET

TEXT runtime·clock_gettime_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP			// make a frame; keep stack aligned
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 tp
	MOVL	0(DI), DI		// arg 1 clock_id
	CALL	libc_clock_gettime(SB)
	TESTL	AX, AX
	JEQ	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	POPQ	BP
	RET

TEXT runtime·fcntl_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVL	4(DI), SI		// arg 2 cmd
	MOVL	8(DI), DX		// arg 3 arg
	MOVL	0(DI), DI		// arg 1 fd
	XORL	AX, AX			// vararg: say "no float args"
	CALL	libc_fcntl(SB)
	POPQ	BP
	RET

TEXT runtime·sigaction_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 new
	MOVQ	16(DI), DX		// arg 3 old
	MOVL	0(DI), DI		// arg 1 sig
	CALL	libc_sigaction(SB)
	TESTL	AX, AX
	JEQ	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	POPQ	BP
	RET

TEXT runtime·sigprocmask_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI	// arg 2 new
	MOVQ	16(DI), DX	// arg 3 old
	MOVL	0(DI), DI	// arg 1 how
	CALL	libc_pthread_sigmask(SB)
	TESTL	AX, AX
	JEQ	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	POPQ	BP
	RET

TEXT runtime·sigaltstack_trampoline(SB),NOSPLIT,$0
	PUSHQ	BP
	MOVQ	SP, BP
	MOVQ	8(DI), SI		// arg 2 old
	MOVQ	0(DI), DI		// arg 1 new
	CALL	libc_sigaltstack(SB)
	TESTQ	AX, AX
	JEQ	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	POPQ	BP
	RET
