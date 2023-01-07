#include <arch/arch.h>
#include <panic/panic.h>
#include <stdint.h>

void OwlKernelMain() {
  /* Ensure that the IOwlArch signature is present */
  if (owlArch.signature != 0x686372416c774f49) {
    /* The kernel cannot properly operate without a valid IOwlArch
     * Implementation, Halt Hart 0x00 */
    while (1) {
    };
  }
  owlArch.initialize_early(); /* Initialize some early architectural features
                                 that are immediately needed at boot. */
  IOwlLogger logger = owlArch.get_logger();
  if(logger == NULL) { /* Can't continue without a logging device */
    while(1) {
    };
  }
  va_list fake_args;
  LogWrite(logger,"\e[49m      \e[38;5;15;49m▄▄\e[49;38;5;15m▀▀▀\e[38;5;15;49m▄▄\e[49m \e[m\n",fake_args);
  LogWrite(logger,"\e[49m \e[49;38;5;15m▀\e[49m \e[38;5;15;49m▄\e[49m \e[48;5;15m \e[49m \e[38;5;15;49m▄\e[49m   \e[38;5;15;49m▄\e[49m \e[48;5;15m \e[m\n",fake_args);
  LogWrite(logger,"\e[49m \e[49;38;5;15m▀\e[49m \e[38;5;15;49m▄\e[49m \e[48;5;15m \e[49m \e[49;38;5;15m▀\e[48;5;15m \e[38;5;15;49m▄\e[48;5;15m \e[49;38;5;15m▀\e[49m \e[48;5;15m \e[m\n",fake_args);
  LogWrite(logger,"\e[49;38;5;15m▀\e[49m \e[49;38;5;15m▀\e[38;5;15;49m▄\e[49;38;5;15m▀\e[38;5;15;49m▄\e[49;38;5;15m▀\e[49m  \e[49;38;5;15m▀\e[49m   \e[48;5;15m \e[m  Owl Microkernel (for zorroOS)\n",fake_args);
  LogWrite(logger,"\e[49;38;5;15m▀\e[49m \e[49;38;5;15m▀\e[38;5;15;49m▄\e[49;38;5;15m▀\e[49m \e[38;5;15;49m▄\e[49;38;5;15m▀\e[49m   \e[38;5;15;49m▄\e[48;5;15m  \e[m  (C) 2020-2023 TalonFox and contributors\n",fake_args);
  LogWrite(logger,"\e[49;38;5;15m▀\e[49m \e[49;38;5;15m▀\e[38;5;15;49m▄\e[49;38;5;15m▀\e[49m \e[38;5;15;49m▄\e[49m \e[38;5;15;49m▄\e[49m \e[48;5;15m \e[49;38;5;15m▀\e[49m \e[48;5;15m \e[m\n",fake_args);
  LogWrite(logger,"\e[49;38;5;15m▀\e[49m \e[49;38;5;15m▀\e[38;5;15;49m▄\e[49;38;5;15m▀\e[49m  \e[49;38;5;15m▀\e[49m  \e[48;5;15m \e[49m  \e[48;5;15m \e[m\n",fake_args);
  LogWrite(logger,"\e[49;38;5;15m▀\e[49m \e[49;38;5;15m▀\e[49m \e[49;38;5;15m▀\e[49m     \e[49;38;5;15m▀▀▀\e[49m \e[m\n",fake_args);
  owlArch.initialize();
  PanicCat(PANIC_RAMDISK,"No Ramdisk");
  for(;;) {};
}