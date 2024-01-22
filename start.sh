#!/bin/bash
export UUID=${UUID:-'92880617-c2f5-4c16-b1cb-68ccde9a1c1b'}
export NEZHA_SERVER=${NEZHA_SERVER:-'nz.f4i.com'}
export NEZHA_PORT=${NEZHA_PORT:-'5555'}   # 哪吒端口为{443,8443,2096,2087,2083,2053}其中之一时开启tls
export NEZHA_KEY=${NEZHA_KEY:-'wOij9z8Aj2GCrK3UFl'}        # 哪吒三个变量不全不运行
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}
export ARGO_AUTH=${ARGO_AUTH:-''}
export NAME=${NAME:-'Vls'}
export CFIP=${CFIP:-'government.se'}
export FILE_PATH=${FILE_PATH:-'./temp'}
export ARGO_PORT=${ARGO_PORT:-'8001'}  # argo隧道端口，若使用固定隧道token请改回8080或CF后台改为与这里对应

if [ ! -d "${FILE_PATH}" ]; then
    mkdir ${FILE_PATH}
fi

cleanup_oldfiles() {
  rm -rf ${FILE_PATH}/boot.log ${FILE_PATH}/sub.txt ${FILE_PATH}/config.json ${FILE_PATH}/tunnel.json ${FILE_PATH}/tunnel.yml
}
cleanup_oldfiles
sleep 1

generate_config() {
  cat > ${FILE_PATH}/config.json << EOF
{
  "log": { "access": "/dev/null", "error": "/dev/null", "loglevel": "none" },
  "inbounds": [
    {
      "port": $ARGO_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${UUID}", "flow": "xtls-rprx-vision" }],
        "decryption": "none",
        "fallbacks": [
          { "dest": 3001 }, { "path": "/vless", "dest": 3002 },
          { "path": "/vmess", "dest": 3003 }, { "path": "/trojan", "dest": 3004 }
        ]
      },
      "streamSettings": { "network": "tcp" }
    },
    {
      "port": 3001, "listen": "127.0.0.1", "protocol": "vless",
      "settings": { "clients": [{ "id": "${UUID}" }], "decryption": "none" },
      "streamSettings": { "network": "ws", "security": "none" }
    },
    {
      "port": 3002, "listen": "127.0.0.1", "protocol": "vless",
      "settings": { "clients": [{ "id": "${UUID}", "level": 0 }], "decryption": "none" },
      "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/vless" } },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "metadataOnly": false }
    },
    {
      "port": 3003, "listen": "127.0.0.1", "protocol": "vmess",
      "settings": { "clients": [{ "id": "${UUID}", "alterId": 0 }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "metadataOnly": false }
    },
    {
      "port": 3004, "listen": "127.0.0.1", "protocol": "trojan",
      "settings": { "clients": [{ "password": "${UUID}" }] },
      "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/trojan" } },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "metadataOnly": false }
    }
  ],
  "dns": { "servers": ["https+local://8.8.8.8/dns-query"] },
  "outbounds": [
    { "protocol": "freedom" },
    {
      "tag": "WARP", "protocol": "wireguard",
      "settings": {
        "secretKey": "YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
        "address": ["172.16.0.2/32", "2606:4700:110:8a36:df92:102a:9602:fa18/128"],
        "peers": [{ "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=", "allowedIPs": ["0.0.0.0/0", "::/0"], "endpoint": "162.159.193.10:2408" }],
        "reserved": [78, 135, 76], "mtu": 1280
      }
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [{ "type": "field", "domain": ["domain:openai.com", "domain:ai.com"], "outboundTag": "WARP" }]
  }
}
EOF
}
generate_config
sleep 2

# 下载依赖
ARCH=$(uname -m) && DOWNLOAD_DIR="${FILE_PATH}" && mkdir -p "$DOWNLOAD_DIR" && declare -a FILE_INFO 
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ]|| [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/bot13 bot" "https://github.com/eooce/test/releases/download/ARM/web web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/amd64/bot13 bot" "https://github.com/eooce/test/releases/download/123/web web" "https://github.com/eooce/test/releases/download/bulid/swith npm")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    NEW_FILENAME=$(echo "$entry" | cut -d ' ' -f 2)
    FILENAME="$DOWNLOAD_DIR/$NEW_FILENAME"
    curl -L -sS -o "$FILENAME" "$URL"
    echo "Downloading $FILENAME"
done
wait
for entry in "${FILE_INFO[@]}"; do
    NEW_FILENAME=$(echo "$entry" | cut -d ' ' -f 2)
    FILENAME="$DOWNLOAD_DIR/$NEW_FILENAME"
    chmod +x "$FILENAME"
    echo "$FILENAME downloaded and permission successfully "
done

#生成固定隧道配置文件
argo_configure() {
  if [[ -z $ARGO_AUTH || -z $ARGO_DOMAIN ]]; then
    echo "ARGO_DOMAIN or ARGO_AUTH variable is empty, use quick tunnel"
    return
  fi

  if [[ $ARGO_AUTH =~ TunnelSecret ]]; then
    echo $ARGO_AUTH > ${FILE_PATH}/tunnel.json
    cat > ${FILE_PATH}/tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< "$ARGO_AUTH")
credentials-file: ${FILE_PATH}/tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:$ARGO_PORT
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  else
    echo "ARGO_AUTH mismatch TunnelSecret,use token connect to tunnel"
  fi
}
argo_configure
sleep 2

run() {
  if [ -e "${FILE_PATH}/npm" ]; then
    	tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
    	if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
    		NEZHA_TLS="--tls"
    	else
    		NEZHA_TLS=""
    	fi
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
        nohup ${FILE_PATH}/npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
        sleep 2
        pgrep -x "npm" > /dev/null && echo "npm is running" || { echo "npm is not running, restarting..."; pkill -x "npm" && nohup ${FILE_PATH}/npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & sleep 2; echo "npm restarted"; }
    else
        echo "NEZHA variable is empty,skip runing"
    fi
  fi

  if [ -e "${FILE_PATH}/web" ]; then
    nohup ${FILE_PATH}/web -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
    sleep 2
    pgrep -x "web" > /dev/null && echo "web is running" || { echo "web is not running, restarting..."; pkill -x "web" && nohup ${FILE_PATH}/web -c ${FILE_PATH}/config.json >/dev/null 2>&1 & sleep 2; echo "web restarted"; }

  fi

  if [ -e "${FILE_PATH}/bot" ]; then
    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
    elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
      args="tunnel --edge-ip-version auto --config ${FILE_PATH}/tunnel.yml run"
    else
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${FILE_PATH}/boot.log --loglevel info --url http://localhost:$ARGO_PORT"
    fi
    nohup ${FILE_PATH}/bot $args >/dev/null 2>&1 &
    sleep 3
    pgrep -x "bot" > /dev/null && echo "bot is running" || { echo "bot is not running, restarting..."; pkill -x "bot" && nohup ${FILE_PATH}/bot $args >/dev/null 2>&1 & sleep 2; echo "bot restarted"; }
  fi
} 
run

function get_argodomain() {
  if [[ -n "$ARGO_AUTH" ]]; then
    echo "$ARGO_DOMAIN"
  else
    cat ${FILE_PATH}/boot.log | grep trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}'
  fi
}

generate_links() {
  argodomain=$(get_argodomain)
  sleep 3
  echo "Argodomain:$argodomain"

  isp=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')
  sleep 2

  VMESS="{ \"v\": \"2\", \"ps\": \"${NAME}-${isp}\", \"add\": \"${CFIP}\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${argodomain}\", \"path\": \"/vmess?ed=2048\", \"tls\": \"tls\", \"sni\": \"${argodomain}\", \"alpn\": \"\" }"

  cat > ${FILE_PATH}/list.txt <<EOF
vless://${UUID}@${CFIP}:443?encryption=none&security=tls&sni=${argodomain}&type=ws&host=${argodomain}&path=%2Fvless?ed=2048#${NAME}-${isp}

vmess://$(echo "$VMESS" | base64 -w0)

trojan://${UUID}@${CFIP}:443?security=tls&sni=${argodomain}&type=ws&host=${argodomain}&path=%2Ftrojan?ed=2048#${NAME}-${isp}
EOF

  base64 -w0 ${FILE_PATH}/list.txt > ${FILE_PATH}/sub.txt
  cat ${FILE_PATH}/sub.txt
  echo -e "\nFile saved successfully"
  sleep 8  
  rm -rf ${FILE_PATH}/list.txt${FILE_PATH}/boot.log ${FILE_PATH}/config.json ${FILE_PATH}/tunnel.json ${FILE_PATH}/tunnel.yml
}
generate_links
sleep 15
clear

echo "Server is running"
echo "Thank you for using this script,enjoy!"
