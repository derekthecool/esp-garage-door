# ESP Garage Door

ESP32 controller for a Genie garage door opener. Triggers the opener via a
transistor-wired spare Intellicode remote, sidestepping the Series III wall
console's serial protocol entirely. Position feedback comes from an HC-SR04
ultrasonic sensor aimed at the top door panel.

## Hardware

| Part | Source |
|------|--------|
| ESP32 dev board | — |
| Genie Intellicode remote (CR2032-powered), spare | — |
| 2N3904 NPN transistor (TO-92) | — |
| 1 kΩ resistor | — |
| HC-SR04 ultrasonic sensor (or HC-SR04P, 3 V variant — no divider needed) | — |
| 2 kΩ + 1 kΩ resistors for ECHO voltage divider (skip if using HC-SR04P) | — |
| Hookup wire | — |

## Wiring

```
ESP32 3.3V ──────────────────►  Remote "+" battery pad
ESP32 GND  ──────────────────►  Remote "−" battery pad
ESP32 GPIO33 ──[ 1 kΩ ]────►  2N3904 Base (pin 2)
ESP32 GND  ──────────────────►  2N3904 Emitter (pin 1)
2N3904 Collector (pin 3) ────►  Button input pad on remote PCB
```

2N3904 pinout (TO-92, flat face toward you, legs down): **1=E, 2=B, 3=C**.

The remote is permanently powered from the ESP32's 3.3 V rail — no battery
needed once wired.

### HC-SR04 ultrasonic sensor

```
ESP32 5V  ─────────────►  HC-SR04 VCC
ESP32 GND ─────────────►  HC-SR04 GND
ESP32 GPIO23 ─────────►  HC-SR04 TRIG
HC-SR04 ECHO ──[ 2 kΩ ]──┬──►  ESP32 GPIO22
                          │
                        [ 1 kΩ ]
                          │
                         GND
```

**The ECHO pin outputs 5 V — do not wire it directly to GPIO22.** Use the
2 kΩ / 1 kΩ divider shown above, or substitute an HC-SR04P (3 V variant) which
needs no divider.

### Mounting the HC-SR04

Mount on top of the powerhead (or ceiling right next to it), pointing straight
down at the top door panel. For a standard sectional door:

- **Door OPEN:** top panel horizontal, close to ceiling → small distance
- **Door CLOSED:** top panel vertical, at the front of the opening → large distance

So `distance < threshold` ⇒ OPEN, `distance > threshold` ⇒ CLOSED.

### Identifying the button input pad

With multimeter in continuity mode, probe between the remote's battery "−" pad
and each pad of the door button. The pad with continuity to battery "−" is the
ground side (already on the shared rail — leave it alone). The other pad is the
input — wire the transistor collector there.

Sanity-check before soldering: with battery still in the remote, briefly jumper
the input pad to battery "−". Door should fire.

## First flash

1. Install ESPHome:

   ```bash
   pip install esphome
   ```

2. Copy the secrets template:

   ```bash
   cp secrets.yaml.example secrets.yaml
   ```

3. Edit `secrets.yaml` with your WiFi credentials and generate fresh keys:

   ```bash
   openssl rand -base64 32  # → api_encryption_key
   openssl rand -hex 16     # → ota_password and fallback_ap_password
   ```

4. Plug the ESP32 into USB.

5. Flash:

   ```bash
   esphome run esp-garage-door.yaml
   ```

   First flash requires USB. After that, OTA updates work over WiFi.

### Docker alternative (when the native toolchain breaks)

If your native esphome / PlatformIO / xtensa toolchain has issues (the
GCC 14.2.0 internal-compiler-error on the combined arduino+espidf framework
is a known one), use the official docker image instead:

```powershell
./scripts/Invoke-EsphomeDocker.ps1                                  # run (compile + flash, prompts for USB/OTA)
./scripts/Invoke-EsphomeDocker.ps1 -Command compile                  # just compile, no flash
./scripts/Invoke-EsphomeDocker.ps1 -Command logs                     # stream logs over OTA
./scripts/Invoke-EsphomeDocker.ps1 -Device /dev/ttyACM0              # force a specific USB port
./scripts/Invoke-EsphomeDocker.ps1 -Device 192.168.1.74              # OTA direct to IP (no USB, no mDNS)
```

The `-Device <IP>` form is the recommended way to push updates once the
device is on WiFi — no USB cable needed, no mDNS dependency (uses TCP on
port 3232 directly). Find the current IP in HA under the ESPHome
integration's device page, or via your router's DHCP table.

Requires docker installed and the user in the `docker` group (Linux) or
Docker Desktop running (macOS/Windows).

## Home Assistant integration

Once the ESP32 boots and joins WiFi:

1. Home Assistant shows a discovery notification for **ESPHome**.
2. Click **Add**.
3. Paste the `api_encryption_key` from `secrets.yaml`.
4. The **Garage Door** cover entity appears under the ESPHome integration.

You can now open/close/stop the door from HA. The cover state is derived from
the HC-SR04 distance reading versus the threshold (`Door Distance Threshold`
number entity, default 1.0 m — adjustable from HA's UI).

### Tuning the threshold

1. With the door **closed**, note the `Garage Door Distance` sensor reading in
   HA (e.g., 2.4 m).
2. With the door **open**, note the same reading (e.g., 0.3 m).
3. Pick a threshold halfway between (e.g., ~1.3 m) and set it on the
   `Door Distance Threshold` number entity.
4. Cycle the door a few times to confirm the cover state flips reliably at
   the right moment. Add margin if it flickers mid-travel.

The threshold persists across reboots (`restore_value: true`).

## CI

GitHub Actions validates the YAML (`esphome config`) and compiles the firmware
(`esphome compile`) on every push to `master`/`main` and on PRs. Secrets are
generated fresh in CI as throwaway values — they just need to be structurally
valid.

## Project layout

```
.
├── esp-garage-door.yaml     # Main ESPHome config
├── secrets.yaml             # Your local secrets (gitignored)
├── secrets.yaml.example     # Template — committed
├── .github/workflows/ci.yml
└── README.md
```
