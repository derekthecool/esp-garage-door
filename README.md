# ESP Garage Door

ESP32 controller for a Genie garage door opener. Triggers the opener via a
transistor-wired spare Intellicode remote, sidestepping the Series III wall
console's serial protocol entirely.

Position feedback (HC-SR04 ultrasonic) is planned but not yet wired.

## Hardware

| Part | Source |
|------|--------|
| ESP32 dev board | — |
| Genie Intellicode remote (CR2032-powered), spare | — |
| 2N3904 NPN transistor (TO-92) | — |
| 1 kΩ resistor | — |
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

## Home Assistant integration

Once the ESP32 boots and joins WiFi:

1. Home Assistant shows a discovery notification for **ESPHome**.
2. Click **Add**.
3. Paste the `api_encryption_key` from `secrets.yaml`.
4. The **Garage Door** cover entity appears under the ESPHome integration.

You can now open/close/stop the door from HA. The cover is currently
`optimistic: true` (HA assumes the requested state) because there's no position
sensor yet — that changes once the HC-SR04 is wired in.

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
