#!/bin/bash

MY_IP=$(curl -s https://checkip.amazonaws.com)
# Save it:
echo "my_ip = \"${MY_IP}/32\"" > my_ip.auto.tfvars
echo "Your IP (${MY_IP}/32) has been saved to my_ip.auto.tfvars"