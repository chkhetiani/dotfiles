#!/usr/bin/env bash

rclone mount pgDrive:/ ~/pgDrive --allow-non-empty --vfs-cache-mode=full &

