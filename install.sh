#!/bin/bash

# Update & Upgrade system
echo "Updating and upgrading system..."
sudo apt update
sudo apt upgrade -y
sudo apt install nano systemd python3 python3-pip unclutter -y
sudo apt autoremove -y

# Check installed versions
echo "Checking installed versions..."
python3 --version
pip3 -V

# Create pyled script
echo "Creating pyled.py script..."
cat << 'EOF' > /home/linaro/pyled.py
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

class MyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/blue':
            lamp_blue_all()
            self.send_response(200)
            self.end_headers()
        elif self.path == '/green':
            lamp_green_all()
            self.send_response(200)
            self.end_headers()
        elif self.path == '/red':
            lamp_red_all()
            self.send_response(200)
            self.end_headers()
        elif self.path == '/off':
            lamp_off_all()
            self.send_response(200)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found.")

    def trigger_specific_function(self):
        # Put your specific function here
        print("Specific function triggered.")

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
    server_thread.daemon = True  # Daemonize thread so it will be killed when main program exits
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

def main():
    print("ProDVX LED Control")
    while True:
        pass

if __name__ == "__main__":
    run_server_in_thread()
    main()
EOF

# Make LEDs editable for non-root/all users
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
    sudo sed -i 's|^CHROME_EXTRA_ARGS=.*|CHROME_EXTRA_ARGS="--use-gl=egl --disable-web-security --user-data-dir=/home/linaro/chromium-data-dir --no-sandbox --start-fullscreen --gpu-sandbox-start-early --ignore-gpu-blacklist --ignore-gpu-blocklist --enable-remote-extensions --no-default-browser-check --enable-webgpu-developer-features --enable-unsafe-webgpu --show-component-extension-options --enable-gpu-rasterization --no-default-browser-check --disable-pings --media-router=0 --enable-accelerated-video-decode --enable-features=VaapiVideoDecoder,VaapiVideoEncoder --test-type https://play.onedisplay.se"|' /usr/lib/chromium/chromium-wrapper
else
    echo 'CHROME_EXTRA_ARGS="--use-gl=egl --disable-web-security --user-data-dir=/home/linaro/chromium-data-dir --no-sandbox --start-fullscreen --gpu-sandbox-start-early --ignore-gpu-blacklist --ignore-gpu-blocklist --enable-remote-extensions --no-default-browser-check --enable-webgpu-developer-features --enable-unsafe-webgpu --show-component-extension-options --enable-gpu-rasterization --no-default-browser-check --disable-pings --media-router=0 --enable-accelerated-video-decode --enable-features=VaapiVideoDecoder,VaapiVideoEncoder --test-type https://play.onedisplay.se"' | sudo tee -a /usr/lib/chromium/chromium-wrapper > /dev/null
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
echo "Creating autostart entry for Chromium..."
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

echo "Setup complete. Please restart your system."
