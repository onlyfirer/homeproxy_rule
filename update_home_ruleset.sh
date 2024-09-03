#!/bin/bash

# 配置文件路径
CONFIG_FILE="/etc/config/homeproxy"
URL_FILE="url_file.txt"

# 生成配置文件--节点设置
generate_config_content_jd() {
    local name="$1"
    local content="config node 'open_$name'\n"
    content+="\toption label '$name'\n"
    content+="\toption type 'urltest'\n"
    content+="\toption test_url 'http://cp.cloudflare.com/'\n"
    content+="\toption interval '10m'\n"
    content+="\toption idle_timeout '30m'\n"
    content+="\tlist order 'direct-out'\n"
    content+=" \n"
    echo -e "$content"
}

# 生成配置文件--路由节点
generate_config_content_node() {
    local name="$1"
    local content="config routing_node '$name'\n"
    content+="\toption label 'jd_$name'\n"
    content+="\toption enabled '1'\n"
    content+="\toption node 'open_$name'\n"
    content+=" \n"
    echo -e "$content"
}

# 生成配置文件--路由规则
generate_config_content_rule() {
    local name="$1"
    local content="config routing_rule 'guize_$name'\n"
    content+="\toption label 'guize_$name'\n"
    content+="\toption enabled '1'\n"
    content+="\toption mode 'default'\n"
    content+="\toption source_ip_is_private '0'\n"
    content+="\toption ip_is_private '0'\n"
    content+="\tlist rule_set 'rule_$name'\n"   
    content+="\toption rule_set_ipcidr_match_source '0'\n"
    content+="\toption outbound '$name'\n"
    content+=" \n"
    echo -e "$content"
}

# 生成配置文件--规则集
generate_config_content() {
    local name="$1"
    local url="$2"
    local content="config ruleset 'rule_$name'\n"
    content+="\toption label 'rule_$name'\n"
    content+="\toption enabled '1'\n"
    content+="\toption type 'remote'\n"
    content+="\toption format 'binary'\n"
    content+="\toption url '$url'\n"
    content+="\toption outbound 'direct-out'\n"
    content+=" \n"
    echo -e "$content"
}
# 生成其他 DNS 规则
generate_other_dns_rule() {
    local content="config dns_rule 'any_domain'\n"
    content+="\toption label 'any_domain'\n"
    content+="\toption enabled '1'\n"
    content+="\toption mode 'default'\n"
    content+="\toption source_ip_is_private '0'\n"
    content+="\tlist outbound 'any-out'\n"
    content+="\toption server 'default-dns'\n"
    content+=" \n"
    echo -e "$content"
}

# 生成配置文件--DNS 规则
generate_config_content_dns_rule() {
    local content=""
    content+="config dns_rule 'clash_mode_domain'\n"
    content+="\toption label 'clash_mode_直连'\n"
    content+="\toption enabled '1'\n"
    content+="\toption mode 'default'\n"
    content+="\toption source_ip_is_private '0'\n"
    content+="\toption clash_mode 'direct'\n"
    content+="\toption server 'dns_cndns'\n"
    content+=" \n"

    content+="config dns_rule 'clash_mode2_domain'\n"
    content+="\toption label 'clash_mode_全局'\n"
    content+="\toption enabled '1'\n"
    content+="\toption mode 'default'\n"
    content+="\toption source_ip_is_private '0'\n"
    content+="\toption clash_mode 'global'\n"
    content+="\toption server 'dns_google'\n"
    content+=" \n"
    
    content+="config dns_rule 'ads_domain'\n"
    content+="\toption label '全球拦截'\n"
    content+="\toption enabled '1'\n"
    content+="\toption mode 'default'\n"
    content+="\toption source_ip_is_private '0'\n"
    content+="\tlist rule_set 'rule_ads'\n"
    content+="\toption server 'block-dns'\n"
    content+=" \n"

    content+="config dns_server 'dns_google'\n"
    content+="\toption label 'dns_google'\n"
    content+="\toption enabled '1'\n"
    content+="\toption address 'https://8.8.8.8/dns-query'\n"
    content+="\toption outbound 'proxy'\n"
    content+=" \n"
    echo -e "$content" 
        
    content+="config dns_server 'dns_con'\n"
    content+="\toption label 'dns_con'\n"
    content+="\toption enabled '1'\n"
    content+="\toption address 'tls://1.1.1.1'\n"
    content+="\toption outbound 'youtube'\n"
    content+="\toption address_strategy 'prefer_ipv4'\n"
    content+=" \n"
    echo -e "$content"    
}

# 生成配置文件--DNS 国内直连规则
generate_config_content_direct_dns_rule() {
    local rule_sets=("$@")
    local content="config dns_rule 'cn_direct_domain'\n"
    content+="\toption label 'cn_direct_domain'\n"
    content+="\toption enabled '1'\n"
    content+="\toption mode 'default'\n"
    content+="\toption source_ip_is_private '0'\n"
    content+="\toption server 'default-dns'\n"
    
    for rule_set in "${rule_sets[@]}"; do
        content+="\tlist rule_set '$rule_set'\n"
    done
    
    content+=" \n"
    echo -e "$content"
}    

# 读取 URL 文件中的地址列表
while IFS= read -r url; do
    # 跳过空行和以#开头的注释行
    if [[ "$url" =~ ^[[:space:]]*$|^# ]]; then
        continue
    fi
    
    # 去除行末尾的空白字符
    url=$(echo "$url" | sed -e 's/[[:space:]]*$//')
    
    urls+=("$url")
done < "$URL_FILE"

# 检查是否成功读取 URL 文件
if [ ${#urls[@]} -eq 0 ]; then
    echo "Error: No URLs found in $URL_FILE" >&2
    exit 1
fi

# 生成配置文件内容
config_content=""
config_content_jd=""
config_content_node=""
config_content_rule=""
# 使用关联数组存储每个规则集的计数
declare -A name_counts

for url in "${urls[@]}"; do
    # 从 URL 中提取文件名作为规则集名称
    filename="$(basename "$url")"
    name="${filename%.srs}"  # 移除文件扩展名
    name="${name//./_}"      # 将点替换为下划线，确保名称的合法性
    name="${name//-/_}"      # 将点替换为下划线，确保名称的合法性
    name="${name//!/no_}"    # 将点替换为下划线，确保名称的合法性        
    
    # 检查该名称是否已经存在，如果是则递增计数
    if [[ -n "${name_counts[$name]}" ]]; then
        ((name_counts[$name]++))
    else
        name_counts[$name]=1
    fi
    
    # 如果相同名称的个数大于1，添加序列号
    if ((name_counts[$name] > 1)); then
        new_name="${name}_${name_counts[$name]}"
    else
        new_name="$name"
    fi

    rule_sets+=("rule_$new_name")

    config_content_jd+="$(generate_config_content_jd "$new_name")\n"
    config_content_node+="$(generate_config_content_node "$new_name")\n"
    config_content_rule+="$(generate_config_content_rule "$new_name")\n"
    config_content+="$(generate_config_content "$new_name" "$url")\n" 
    echo "DEBUG: Added rule set for $new_name" >&2
done

# 生成 DNS 规则配置内容
config_content_dns_rule="$(generate_config_content_dns_rule)"

# 生成其他 DNS 规则配置内容
other_dns_rule="$(generate_other_dns_rule)"

# 生成配置文件--DNS 国内直连规则
config_content_direct_dns_rule="$(generate_config_content_direct_dns_rule "${rule_sets[@]}")"

# 将配置内容写入文件
{
    echo -e "$config_content_jd"
    echo -e "$config_content_node"
    echo -e "$config_content_rule"
    echo -e "$config_content"
    echo -e "$other_dns_rule"
    echo -e "$config_content_dns_rule"
    echo -e "$config_content_direct_dns_rule"
} >> "$CONFIG_FILE"

echo "配置文件已生成：$CONFIG_FILE"
echo "DNS 规则已添加到 config dns_rule 'cn_direct_domain' 部分"




