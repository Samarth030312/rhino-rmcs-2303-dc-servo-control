# Third-party components

Nothing below is redistributed in this repository. The installers fetch each component
from its official source at the pinned version, into a folder used only by this project.

| Component | Version | Licence | Used by |
|---|---|---|---|
| [Arduino CLI](https://github.com/arduino/arduino-cli) | 1.5.1 | GPL-3.0 (tool, not linked) | compile and upload the firmware |
| [Arduino AVR core](https://github.com/arduino/ArduinoCore-avr) (`arduino:avr`) | 1.8.8 | LGPL-2.1 | every sketch (Uno) |
| [AltSoftSerial](https://www.pjrc.com/teensy/td_libs_AltSoftSerial.html) (Paul Stoffregen) | 1.4 | MIT (stated in the source headers) | DC motor: Modbus link to the RMCS-2303 |
| [DHT sensor library](https://github.com/adafruit/DHT-sensor-library) (Adafruit) | 1.4.7 | MIT | temperature: DHT11 |
| [Adafruit Unified Sensor](https://github.com/adafruit/Adafruit_Sensor) | 1.1.15 | Apache-2.0 | dependency of the DHT library |
| [LiquidCrystal](https://github.com/arduino-libraries/LiquidCrystal) (Arduino, Adafruit) | 1.0.7 | LGPL-2.1 or later | temperature: parallel 16x2 LCD |
| [LiquidCrystal I2C](https://github.com/marcoschwartz/LiquidCrystal_I2C) (Frank de Brabander) | 1.1.2 | none stated in the distributed library | temperature: I2C 16x2 LCD (optional) |

MATLAB and Simulink (MathWorks) are required to run the apps and models and are not part
of this repository; the [CI](.github/workflows/ci.yml) uses MathWorks' free licensing for
public projects on GitHub-hosted runners.

Not included and not redistributed: the ENR312 course handouts, the Rhino Motion Controls
RMCS-2303 and RMCS-5032 manuals and datasheets, the sensor datasheets and the Festo
FluidSIM software. They are cited in
[`docs/knowledge-base/SOURCE_REGISTER.csv`](docs/knowledge-base/SOURCE_REGISTER.csv).
