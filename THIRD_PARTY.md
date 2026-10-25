# Third-party components

Nothing below is redistributed in this repository. The installers fetch each component
from its official source at the pinned version, into a tool folder of your user account.

| Component | Version | Licence | Used by |
|---|---|---|---|
| [Arduino CLI](https://github.com/arduino/arduino-cli) | 1.5.1 | GPL-3.0 (tool, not linked) | compile and upload the firmware |
| [Arduino AVR core](https://github.com/arduino/ArduinoCore-avr) (`arduino:avr`) | 1.8.8 | LGPL-2.1 | every sketch (Uno) |
| [AltSoftSerial](https://www.pjrc.com/teensy/td_libs_AltSoftSerial.html) (Paul Stoffregen) | 1.4 | MIT (stated in the source headers) | Modbus link to the RMCS-2303 |

MATLAB and Simulink (MathWorks) are required to run the apps and models and are not part
of this repository; the [CI](.github/workflows/ci.yml) uses MathWorks' free licensing for
public projects on GitHub-hosted runners.

Not included and not redistributed: the lab handouts and the Rhino Motion Controls RMCS-2303 and RMCS-5032 manuals and datasheets, and the Rhino configuration software. They are cited in
[`docs/knowledge-base/SOURCE_REGISTER.csv`](docs/knowledge-base/SOURCE_REGISTER.csv).
