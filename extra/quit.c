#include <stdio.h>
#include <unistd.h>
#include <sys/reboot.h>
#include <sys/syscall.h>

void _start() {
  char buf[] = "YOU'VE REACHED USER MODE!\n";
  syscall(__NR_write, 1, buf, sizeof(buf));
  reboot(RB_POWER_OFF);
}
