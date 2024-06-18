#!/bin/bash

# Probably not the best nor the safest way of doing this.
# Ideally, this should not run with elevated privileges.
# The LED controls for /sys/class/leds/led*/brightness gets reset upon reboot though.
# And time isn't really on my side.
# /Björn Ringmann

# Update & Upgrade system
echo "Updating and upgrading system..."
sudo apt update
sudo apt upgrade -y
sudo apt install nano systemd gcc python3-dev python3 python3-pip unclutter -y
sudo apt autoremove -y

# Check installed versions
echo "Checking installed versions..."
python3 --version
pip3 -V
sudo pip install psutil

# Create pyled script
echo "Creating pyled.py script..."
cat << 'EOF' > /home/linaro/pyled.py
import json
import threading
import subprocess
import psutil
import platform
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer

class MyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/blue':
            lamp_blue_all()
            response = json.dumps({ 'success': True}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
        elif self.path == '/green':
            lamp_green_all()
            response = json.dumps({ 'success': True}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
        elif self.path == '/red':
            lamp_red_all()
            response = json.dumps({ 'success': True}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
        elif self.path == '/off':
            lamp_off_all()
            response = json.dumps({ 'success': True}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
        elif self.path == '/diagnostics':
            metrics = get_system_metrics()
            response = json.dumps(metrics).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
        elif self.path == '/kill':
            kill_chromium()
            response = json.dumps({ 'success': True}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
        elif self.path == '/reboot':
            reboot()
            response = json.dumps({ 'success': True}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found.")

def run_server(server_class=HTTPServer, handler_class=MyHandler, port=8000):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print('Starting server on port {}...'.format(port))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('Server stopped.')
        httpd.server_close()

def run_server_in_thread():
    server_thread = threading.Thread(target=run_server)
    server_thread.daemon = True
    server_thread.start()

def lamp_reset_colors():
    with open("/sys/class/leds/ledR/brightness", "w") as file:
        file.write("0")
    with open("/sys/class/leds/ledG/brightness", "w") as file:
        file.write("0")
    with open("/sys/class/leds/ledB/brightness", "w") as file:
        file.write("0")

def lamp_green_all():
    lamp_reset_colors()
    with open("/sys/class/leds/led_pwr/brightness", "w") as file:
        file.write("255")
    with open("/sys/class/leds/ledG/brightness", "w") as file:
        file.write("255")

def lamp_red_all():
    lamp_reset_colors()
    with open("/sys/class/leds/led_pwr/brightness", "w") as file:
        file.write("255")
    with open("/sys/class/leds/ledR/brightness", "w") as file:
        file.write("255") 

def lamp_blue_all():
    lamp_reset_colors()
    with open("/sys/class/leds/led_pwr/brightness", "w") as file:
        file.write("255")
    with open("/sys/class/leds/ledB/brightness", "w") as file:
        file.write("255")

def lamp_off_all():
    lamp_reset_colors()
    with open("/sys/class/leds/led_pwr/brightness", "w") as file:
        file.write("0")
        
def kill_chromium():
    try:
        subprocess.run(['killall', 'chromium-bin'], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        print("Error occurred:", e)

def reboot():
    try:
        subprocess.run(['sudo', 'reboot'], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        print("Error occurred:", e)

def get_system_metrics():
    cpu_load = psutil.cpu_percent(interval=1)
    cpu_core_usage = psutil.cpu_percent(interval=1, percpu=True)
    
    cpu_freq = psutil.cpu_freq()
    cpu_frequency = {
        'current': cpu_freq.current,
        'min': cpu_freq.min,
        'max': cpu_freq.max
    }

    memory_info = psutil.virtual_memory()
    memory_usage = {
        'total': memory_info.total,
        'available': memory_info.available,
        'percent': memory_info.percent,
        'used': memory_info.used,
        'free': memory_info.free,
        'buffers': memory_info.buffers,
        'cached': memory_info.cached
    }

    swap_info = psutil.swap_memory()
    swap_usage = {
        'total': swap_info.total,
        'used': swap_info.used,
        'free': swap_info.free,
        'percent': swap_info.percent,
        'sin': swap_info.sin,
        'sout': swap_info.sout
    }

    disk_info = psutil.disk_usage('/')
    disk_usage = {
        'total': disk_info.total,
        'used': disk_info.used,
        'free': disk_info.free,
        'percent': disk_info.percent
    }

    disk_io = psutil.disk_io_counters()
    disk_io_stats = {
        'read_count': disk_io.read_count,
        'write_count': disk_io.write_count,
        'read_bytes': disk_io.read_bytes,
        'write_bytes': disk_io.write_bytes,
        'read_time': disk_io.read_time,
        'write_time': disk_io.write_time
    }

    net_info = psutil.net_if_addrs()
    network = {}
    for interface_name, interface_addresses in net_info.items():
        for address in interface_addresses:
            if str(address.family) == 'AddressFamily.AF_INET':
                network[interface_name] = {
                    'ip_address': address.address,
                    'netmask': address.netmask,
                    'broadcast': address.broadcast
                }

    net_io = psutil.net_io_counters()
    network_io_stats = {
        'bytes_sent': net_io.bytes_sent,
        'bytes_recv': net_io.bytes_recv,
        'packets_sent': net_io.packets_sent,
        'packets_recv': net_io.packets_recv,
        'errin': net_io.errin,
        'errout': net_io.errout,
        'dropin': net_io.dropin,
        'dropout': net_io.dropout
    }

    try:
        temps = psutil.sensors_temperatures()
        temperatures = {name: [temp.current for temp in temp_group] for name, temp_group in temps.items()}
    except AttributeError:
        temperatures = "Temperature sensors not supported"

    try:
        battery = psutil.sensors_battery()
        battery_status = {
            'percent': battery.percent,
            'secsleft': battery.secsleft,
            'power_plugged': battery.power_plugged
        } if battery else "No battery"
    except AttributeError:
        battery_status = "Battery sensors not supported"

    load_avg = psutil.getloadavg()
    
    uptime = datetime.now() - datetime.fromtimestamp(psutil.boot_time())
    
    users = psutil.users()
    user_list = [{'name': user.name, 'terminal': user.terminal, 'host': user.host, 'started': user.started} for user in users]

    return {
        'cpu_load': cpu_load,
        'cpu_core_usage': cpu_core_usage,
        'cpu_frequency': cpu_frequency,
        'memory_usage': memory_usage,
        'swap_usage': swap_usage,
        'disk_usage': disk_usage,
        'disk_io_stats': disk_io_stats,
        'network': network,
        'network_io_stats': network_io_stats,
        'temperatures': temperatures,
        'battery_status': battery_status,
        'platform': platform.platform(),
        'uptime': str(uptime),
        'load_average': load_avg,
        'current_users': user_list
    }


def main():
    print("ProDVX LED Control")
    stop_event = threading.Event()
    try:
        stop_event.wait()
    except KeyboardInterrupt:
        print("Stopping main thread.")

if __name__ == "__main__":
    run_server_in_thread()
    main()

EOF

# Make LEDs editable for non-root/all users
# This is not permanent and will be reset upon reboot.
echo "Making LEDs editable for non-root users..."
sudo chmod 777 /sys/class/leds/led_pwr/brightness
sudo chmod 777 /sys/class/leds/ledR/brightness
sudo chmod 777 /sys/class/leds/ledG/brightness
sudo chmod 777 /sys/class/leds/ledB/brightness

# Create service
echo "Creating ledctl.service..."
cat << 'EOF' | sudo tee /etc/systemd/system/ledctl.service > /dev/null
[Unit]
Description=ProDVX LED strip control
After=multi-user.target

[Service]
Type=simple
Restart=always
ExecStart=/usr/bin/python3 /home/linaro/pyled.py

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable services
echo "Reloading and enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable ledctl.service
sudo systemctl start ledctl.service
sudo systemctl status ledctl.service

# Create chromium script
echo "Updating Chromium wrapper..."
if grep -q '^CHROME_EXTRA_ARGS=' /usr/lib/chromium/chromium-wrapper; then
    sudo sed -i 's|^CHROME_EXTRA_ARGS=.*|CHROME_EXTRA_ARGS="--use-gl=egl --noerrdialogs --kiosk --noerrors --disable-session-crashed-bubble --disable-infobars --disable-web-security --user-data-dir=/home/linaro/chromium-data-dir --no-sandbox --start-fullscreen --gpu-sandbox-start-early --ignore-gpu-blacklist --ignore-gpu-blocklist --enable-remote-extensions --no-default-browser-check --enable-webgpu-developer-features --enable-unsafe-webgpu --show-component-extension-options --enable-gpu-rasterization --no-default-browser-check --disable-pings --media-router=0 --enable-accelerated-video-decode --enable-features=VaapiVideoDecoder,VaapiVideoEncoder --test-type https://play.onedisplay.se"|' /usr/lib/chromium/chromium-wrapper
else
    echo 'CHROME_EXTRA_ARGS="--use-gl=egl --noerrdialogs --kiosk --noerrors --disable-session-crashed-bubble --disable-infobars --disable-web-security --user-data-dir=/home/linaro/chromium-data-dir --no-sandbox --start-fullscreen --gpu-sandbox-start-early --ignore-gpu-blacklist --ignore-gpu-blocklist --enable-remote-extensions --no-default-browser-check --enable-webgpu-developer-features --enable-unsafe-webgpu --show-component-extension-options --enable-gpu-rasterization --no-default-browser-check --disable-pings --media-router=0 --enable-accelerated-video-decode --enable-features=VaapiVideoDecoder,VaapiVideoEncoder --test-type https://play.onedisplay.se"' | sudo tee -a /usr/lib/chromium/chromium-wrapper > /dev/null
fi

# Create autostart entry for Chromium
echo "Creating autostart entry for Chromium..."
cat << 'EOF' | sudo tee /etc/xdg/autostart/chromium.desktop > /dev/null
[Desktop Entry]
Name=Chromium
Exec=chromium
Terminal=false
Type=Application
Categories=
EOF

# Create autostart entry for Unclutter
echo "Creating autostart entry for Unclutter..."
cat << 'EOF' | sudo tee /etc/xdg/autostart/unclutter.desktop > /dev/null
[Desktop Entry]
Name=Unclutter
Exec=unclutter -idle 0
Terminal=false
Type=Application
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Categories=
EOF

echo "Testing LED color strip."

# Red LED strip
wget http://localhost:8000/red -O /dev/null
sleep 2
# Green LED strip
wget http://localhost:8000/green -O /dev/null
sleep 2
# Blue LED strip
wget http://localhost:8000/blue -O /dev/null
sleep 2
# No LED strip
wget http://localhost:8000/off -O /dev/null

echo "Setup complete. Please restart your system."
