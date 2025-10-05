# Twinkly Edge Driver for SmartThings

This Edge Driver allows you to control your **Twinkly smart lights** directly through your **SmartThings Hub**, using **local LAN communication** instead of cloud-to-cloud control.  
It supports turning lights on/off, adjusting brightness, and changing color.

---

## 🧩 Requirements

- A SmartThings Hub that supports **Edge Drivers** (e.g. SmartThings V2, V3, or Aeotec Hub)
- Your Twinkly light connected to the **same local network (LAN)** as your hub
- Your Twinkly must be **paired in the official Twinkly mobile app first**
- You must assign your Twinkly a **static IP address** on your router (important for reliable control)
- Supported and tested models:
  - `TWKP200RGB-G` (Twinkly Candies / Pearl)
  - Other RGB-based Twinkly models may work, but are untested

---

## ⚙️ Installation

### 1. Join the Driver Channel

Visit the public channel link to enroll:
👉 **[SmartThings Channel Link](https://callaway.smartthings.com/channels/912e7705-ec88-413c-a3ac-1c5ecd9015ba)**

Sign in with your Samsung account and click **Enroll**.

---

### 2. Install the Driver on Your Hub

Once enrolled:
1. Go to the **SmartThings mobile app**.
2. Tap **Menu → Hubs → Your Hub → Drivers**.
3. Tap **Add driver** and select **Twinkly Edge**.
4. Wait for the installation to complete (usually a few seconds).

---

### 3. Add a New Device

The driver uses a **placeholder mechanism** for setup:

1. In the SmartThings app, go to **Add Device → Scan Nearby**.
2. The driver will create a **placeholder device** called  
   `Twinkly Color Light (twinkly-XXXXXXXXXX)` — this is normal.
3. Open the new device’s settings (⚙️ icon).
4. Enter the **local IP address** of your Twinkly light in the **IP Address** field.  
   Example: `192.168.1.42`
5. Tap **Save** to apply settings.

---

### 4. Configure Polling Interval (Optional)

- You can set how often the driver polls your Twinkly to refresh its state.  
  Default: **30 seconds**  
  Range: **5–3600 seconds**

A shorter interval makes the device more responsive but increases network traffic slightly.

---

## 💡 Features

| Capability     | Description |
|----------------|--------------|
| **Switch** | Turn lights on and off |
| **Brightness** | Adjust light intensity (0–100%) |
| **Color Control** | Set colors via SmartThings color picker |
| **Refresh** | Manually request state update |
| **Local Control** | Works fully offline once configured |

---

## ⚠️ Known Caveats

- **Static IP Required**  
  The Twinkly device must keep the same IP address. Configure this in your router or use DHCP reservation.
- **Placeholder Device Behavior**  
  Discovery always creates one placeholder. You can edit its IP under Settings to link it to your real Twinkly light.
- **No Automatic LAN Discovery**  
  SmartThings cannot detect Twinkly automatically — you must enter the IP manually.
- **Single-Device Per IP**  
  Each placeholder corresponds to one Twinkly device.
- **Effect Selection**  
  Currently, selecting custom Twinkly “effects” (from the Twinkly app) is not supported — only static color and brightness control are available.
- **Color Accuracy**  
  Twinkly uses a non-standard RGB order on some firmware versions. If colors appear swapped (e.g., red appears green), ensure your firmware is up-to-date.

---

## 🧰 Troubleshooting

| Issue | Possible Cause / Solution |
|-------|----------------------------|
| Device stays “Offline” | Check that IP address is correct and reachable on LAN |
| Commands not working | Ensure Twinkly is on the same Wi-Fi as your SmartThings hub |
| No color or brightness control | Use the “Twinkly Color Light” profile when adding the placeholder |
| Lost connection after reboot | Assign a static IP in your router’s DHCP settings |
| Driver not updating | Uninstall and reinstall driver from channel to refresh version |
| Logs are empty | Enable debug mode and check SmartThings CLI logs: `smartthings edge:drivers:logcat` |

---

## 🧑‍💻 For Developers

The developer documentation is avabile in the README-DEV.md file. 

---

## 💬 Support and Feedback

If you encounter problems or have feature requests (such as adding Twinkly effect support), please open an issue in this repository.