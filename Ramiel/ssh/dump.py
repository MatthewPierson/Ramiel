#!/usr/local/bin/python3

import paramiko
        
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

client.connect(hostname="localhost", password="alpine", username="root", port=2222)
command = "dd if=/dev/disk1 bs=256 count=$((0x4000))"
stdin, stdout, stderr = client.exec_command(command)
result = stdout.read()

f = open("/tmp/dump.raw", "wb")
f.write(result)
f.close()
