#!/bin/bash
echo "Deploying Admin Panel..."
scp -r adminpanel/dist/* root@91.132.49.137:/var/www/adminpanel/

echo "Deploying Backend SDK..."
scp -r Skincore.Api/publish/* root@91.132.49.137:/var/www/skincore-api/
scp Skincore.Api/image_proxy.py root@91.132.49.137:/var/www/skincore-api/

echo "Installing Python dependencies on server..."
ssh root@91.132.49.137 "python3 -m pip install curl_cffi Pillow --quiet"

echo "Restarting backend service..."
ssh root@91.132.49.137 "systemctl restart skincore-api"

echo "Done!"
