# ha-openwrt-devicetracker

Local device tracker using hostapd events (i.e. laptop connects/disconnects from wifi) which are immediately sent through webhook to Home Assistant. Tested with Openwrt but in theory it could be run in different systems too.

## Note about security / disclaimer

This code is provided as-is and I'm not responsible for any security problems or other consequences that it causes.

Home Assistant documentation has a chapter about webhook security which you should read first: https://www.home-assistant.io/docs/automation/trigger/#webhook-security

## "How it works"

Openwrt (open-source linux based router firmware) is configured to start hostapd_cli on start as a service. Hostapd_cli calls a script whenever hostapd events occur. Script checks if the event is "AP-STA-CONNECTED" or "AP-STA-DISCONNECTED" and calls Home Assistant Webhook. Trigger-based template sensor records the data to a sensor attribute which can be used in other template sensors or in automations.

Flow of the data is roughly like this:
Hostapd -> hostapd_cli -> /root/onHostapdChange.sh -> Home Assistant Webhook API -> Template sensors for tracking status/individual devices.

## Installation

Instructions were written after the original implementation so small errors might be present.

### Openwrt

Install "hostapd-utils":
```
opkg update
opkg install hostapd-utils
```

Copy files from openwrt directory to your openwrt router. Modify file /root/onHostapdChange.sh to have correct Home Assistant address and a LONG and SECRET webhook id. Use HTTPS connection to Home Assistant whenever possible and treat webhook id like a password. 

Make files executable and enable "hostapd_cli_events" service:
```
chmod a+x /root/onHostapdChange.sh
chmod a+x /etc/init.d/hostapd_cli_events
/etc/init.d/hostapd_cli_events enable
```

### Home Assistant

Add the following to your Home Assistant configuration.yaml and modify webhook_id to match the one you configured to /root/onHostapdChange.sh on openwrt router. If you want, you can use conditions to filter out devices that you don't want to track. You can remove those lines if you want to track all devices.

```
template:
  - triggers:
      trigger: webhook
      allowed_methods:
        - POST
        - PUT
      local_only: true
      webhook_id: VERY-LONG-UNIQUE-ID-DEFINED-IN-OPENWRT # <- CHANGE THIS, USE LONG ID, TREAT LIKE PASSWORD
    conditions:
      - condition: template
        value_template: "{{ trigger.json.mac == \"aa:bb:cc:dd:ee:ff\" or trigger.json.mac == \"11:22:33:44:55:66\" }}"
    sensor:
      - name: device_tracker
        unique_id: devicetrackersensor
        state: "tracking"
        attributes:
          devices: >-
            {% set x = this.attributes.devices | default({}) %}
            {% set x = iif(trigger.json.state ==  "CLEAR_ATTRIBUTE_DATA", {}, x) %}
            {% set mac = trigger.json.mac %}
            {% if not mac in x %}
              {% set x = dict(x, **{mac: ""}) %}
            {% endif %}
            {% if trigger.json.state == "home" and not trigger.json.source in x[mac] %}
              {% set x  = dict(x, **{mac: trigger.json.source}) %}
            {% elif trigger.json.state == "not_home" and trigger.json.source in x[mac] %}
              {% set x  = dict(x, **{mac: ""}) %}
            {% endif %}
            {{ x }}
```

Then you can create binary sensors for each device you want to track/show in UI. Change MAC address to match the device mac address. Attribute delay_off is used to filter out cases where the wireless device is moving from one access point to another or for some other reason momentarily disconnects from wifi.
```
  - binary_sensor:
    - name: Phone Device Tracker
      unique_id: phonedevicetracker
      device_class: precense
      state: "{{ state_attr('sensor.device_tracker', 'devices')['aa:bb:cc:dd:ee:ff'] | default('') != '' }}"
      delay_off:
        seconds: 20
```


## Why this approach
I tried first these methods to track presence:
- Home Assistant Companion: GPS
- ICMP/PING integration
- Home Assistant Companion: currently connected Wifi network

I wanted an automation to trigger whenever we left home. All of these previous methods either did not trigger reliably on ALL of our household phones (GPS/Wifi name from Home Assistant Companion) or they reported the device as "not_home" even though they were at home all the time. I did not want to use existing Openwrt luci based integration as it would have required me to store openwrt credentials on Home Assistant host. ICMP/PING presence detection on the other hand is reported to increase battery consumption on mobile devices.

This also worked well with multiple access points broadcasting the same Wifi network and using 802.11r.

List of the benefits:
- Does not require client software
- Does not depend on the mobile device sending the updates
- Does not increase battery consumption on mobile devices
- No need to store openwrt credentials on Home Assistant
- Almost instant (some delay caused by "delay_off" setting)
- Local push style "integration" so polling not required


