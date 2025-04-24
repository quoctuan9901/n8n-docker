# Sử dụng image gốc của n8n làm base image
FROM n8nio/n8n:latest

# Chuyển sang người dùng root để có quyền cài đặt phần mềm
USER root

# Cài đặt curl và jq bằng apk (Alpine Linux package manager)
RUN apk update && apk add --no-cache curl jq