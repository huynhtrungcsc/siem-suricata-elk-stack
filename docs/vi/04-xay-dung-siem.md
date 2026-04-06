---
title: "Xây dựng hệ thống SIEM với Suricata và Elastic Stack trên Ubuntu 20.04"
description: "Cài đặt và cấu hình Elasticsearch, Kibana với xpack security, triển khai Filebeat trên Suricata server để chuyển EVE log, và truy cập Kibana SIEM dashboard."
author: "Jamon Camisso"
date: 2022-01-15
category: Bảo mật
series: "SIEM với Suricata và Elastic Stack"
part: 4
tags:
  - suricata
  - elasticsearch
  - kibana
  - filebeat
  - siem
  - ubuntu
  - elastic-stack
  - bảo-mật
---

# Phần 4 — Xây dựng hệ thống SIEM với Suricata và Elastic Stack

| | |
|---|---|
| **Chuỗi hướng dẫn** | SIEM với Suricata và Elastic Stack |
| **Phần** | 4 / 5 |
| **Độ khó** | Trung bình |
| **Thời gian** | ~45 phút |
| **Hệ điều hành** | Ubuntu 20.04 LTS (cả hai server) |

---

## Mục lục

- [Giới thiệu](#giới-thiệu)
- [Yêu cầu](#yêu-cầu)
- [Bước 1 — Cài đặt Elasticsearch và Kibana](#bước-1--cài-đặt-elasticsearch-và-kibana)
- [Bước 2 — Cấu hình Elasticsearch](#bước-2--cấu-hình-elasticsearch)
  - [Network](#network)
  - [Tạo mật khẩu](#tạo-mật-khẩu)
- [Bước 3 — Cấu hình Kibana](#bước-3--cấu-hình-kibana)
  - [Tạo Encryption Keys](#tạo-encryption-keys)
  - [Network Binding](#network-binding)
  - [Xác thực (Phương pháp Keystore)](#xác-thực-phương-pháp-keystore)
- [Bước 4 — Cài đặt và cấu hình Filebeat](#bước-4--cài-đặt-và-cấu-hình-filebeat)
- [Bước 5 — Truy cập Kibana SIEM Dashboards](#bước-5--truy-cập-kibana-siem-dashboards)
- [Các trường Elasticsearch Index quan trọng](#các-trường-elasticsearch-index-quan-trọng)
- [Tóm tắt](#tóm-tắt)

---

## Giới thiệu

Các hướng dẫn trước đã đề cập cài đặt và vận hành Suricata như IDS/IPS. Hướng dẫn này tích hợp Suricata với **Elastic Stack** để tạo SIEM tập trung phục vụ lưu trữ, trực quan hóa và điều tra sự kiện bảo mật.

### Kiến trúc

| Thành phần | Server | Vai trò |
|---|---|---|
| Suricata | Suricata Server | Tạo log sự kiện `eve.json` |
| Filebeat | Suricata Server | Chuyển `eve.json` đến Elasticsearch |
| Elasticsearch | Elasticsearch Server | Lập chỉ mục và lưu trữ tất cả sự kiện |
| Kibana | Elasticsearch Server | Trực quan hóa sự kiện và cung cấp SIEM UI |

---

## Yêu cầu

### Suricata Server
- Suricata đã cài đặt, chạy và tạo EVE log ([Phần 1–3](README.md))

### Elasticsearch Server *(mới)*
- Ubuntu 20.04 với tối thiểu **4 GB RAM** và **2 CPU**
- Người dùng non-root có `sudo`
- Private IP address có thể liên lạc từ Suricata server

---

## Bước 1 — Cài đặt Elasticsearch và Kibana

*Thực hiện trên **Elasticsearch server**.*

Thêm GPG signing key của Elastic:

```bash
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
```

Thêm repository Elastic 7.x:

```bash
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
```

Cài đặt cả hai package:

```bash
sudo apt update
sudo apt install elasticsearch kibana
```

Tìm private IP của server (ghi nhớ tên interface):

```bash
ip -brief address show
```

---

## Bước 2 — Cấu hình Elasticsearch

### Network

Mở file cấu hình:

```bash
sudo nano /etc/elasticsearch/elasticsearch.yml
```

Tìm `#network.host:` và thêm dòng bind host bên dưới:

```yaml
# /etc/elasticsearch/elasticsearch.yml

#network.host: 192.168.0.1
network.bind_host: ["127.0.0.1", "your_private_ip"]
```

Thêm vào cuối file:

```yaml
discovery.type: single-node
xpack.security.enabled: true
```

Cho phép traffic trên private network interface:

```bash
sudo ufw allow in on eth1
sudo ufw allow out on eth1
```

Thay `eth1` bằng tên interface thực tế.

### Khởi động Elasticsearch

```bash
sudo systemctl start elasticsearch.service
```

### Tạo mật khẩu

```bash
cd /usr/share/elasticsearch/bin
sudo ./elasticsearch-setup-passwords auto
```

Nhấn `y` để tiếp tục. Ví dụ kết quả:

```
Changed password for user kibana_system
PASSWORD kibana_system = 1HLVxfqZMd7aFQS6Uabl

Changed password for user elastic
PASSWORD elastic = 6kNbsxQGYZ2EQJiqJpgl
```

> **Quan trọng:** Lưu tất cả mật khẩu đã tạo ở nơi an toàn. Tiện ích này không thể chạy lại. Bạn sẽ cần:
> - Mật khẩu `kibana_system` → Cấu hình Kibana
> - Mật khẩu `elastic` → Cấu hình Filebeat và đăng nhập Kibana

---

## Bước 3 — Cấu hình Kibana

### Tạo Encryption Keys

```bash
cd /usr/share/kibana/bin/
sudo ./kibana-encryption-keys generate -q
```

Ví dụ output:

```
xpack.encryptedSavedObjects.encryptionKey: 66fbd85ceb3cba51c0e939fb2526f585
xpack.reporting.encryptionKey: 9358f4bc7189ae0ade1b8deeec7f38ef
xpack.security.encryptionKey: 8f847a594e4a813c4187fa93c884e92b
```

Mở file cấu hình Kibana:

```bash
sudo nano /etc/kibana/kibana.yml
```

**Thêm** ba dòng encryption key vào cuối file:

```yaml
xpack.encryptedSavedObjects.encryptionKey: 66fbd85ceb3cba51c0e939fb2526f585
xpack.reporting.encryptionKey: 9358f4bc7189ae0ade1b8deeec7f38ef
xpack.security.encryptionKey: 8f847a594e4a813c4187fa93c884e92b
```

### Network Binding

Tìm `#server.host: "localhost"` và thêm dòng sau bên dưới:

```yaml
#server.host: "localhost"
server.host: "your_private_ip"
```

### Xác thực (Phương pháp Keystore)

Lưu thông tin xác thực vào keystore mã hóa của Kibana (ưu tiên hơn chỉnh sửa `kibana.yml` trực tiếp):

```bash
cd /usr/share/kibana/bin

# Thêm username Elasticsearch
sudo ./kibana-keystore add elasticsearch.username
# Nhập: kibana_system

# Thêm password Elasticsearch
sudo ./kibana-keystore add elasticsearch.password
# Nhập: <mật khẩu kibana_system từ Bước 2>
```

### Khởi động Kibana

```bash
sudo systemctl start kibana.service
```

---

## Bước 4 — Cài đặt và cấu hình Filebeat

*Thực hiện trên **Suricata server**.*

Thêm GPG key và repository Elastic:

```bash
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update && sudo apt install filebeat
```

Mở cấu hình Filebeat:

```bash
sudo nano /etc/filebeat/filebeat.yml
```

**Cấu hình Kibana endpoint** (dòng ~100):

```yaml
setup.kibana:
  #host: "localhost:5601"
  host: "your_private_ip:5601"
```

**Cấu hình Elasticsearch output** (dòng ~130):

```yaml
output.elasticsearch:
  hosts: ["your_private_ip:9200"]

  username: "elastic"
  password: "your_elastic_password"
```

Bật Suricata module tích hợp sẵn:

```bash
sudo filebeat modules enable suricata
```

Nạp SIEM dashboard và ingest pipeline vào Elasticsearch:

```bash
sudo filebeat setup
```

Kết quả mong đợi:

```
Index setup finished.
Loading dashboards (Kibana must be running and reachable)
Loaded dashboards
Loaded Ingest pipelines
```

Khởi động Filebeat:

```bash
sudo systemctl start filebeat.service
```

---

## Bước 5 — Truy cập Kibana SIEM Dashboards

### Tạo SSH Tunnel

Do Kibana chỉ lắng nghe trên private IP, tạo port forward từ máy trạm của bạn:

```bash
ssh -L 5601:your_private_ip:5601 your_user@your_public_ip -N
```

| Flag | Mục đích |
|---|---|
| `-L 5601:...` | Forward port local 5601 đến Kibana trên server từ xa |
| `-N` | Giữ kết nối mà không chạy shell command |

Nhấn `CTRL+C` để đóng tunnel.

### Đăng nhập Kibana

Mở browser và truy cập: `http://127.0.0.1:5601`

| Trường | Giá trị |
|---|---|
| Username | `elastic` |
| Password | *(đã tạo ở Bước 2)* |

### Tìm Suricata Dashboards

Trong ô tìm kiếm toàn cục của Kibana, nhập:

```
type:dashboard suricata
```

Hai dashboard xuất hiện:

| Dashboard | Nội dung |
|---|---|
| **[Filebeat Suricata] Events Overview** | Tất cả sự kiện Suricata đã ghi |
| **[Filebeat Suricata] Alerts** | Alert được kích hoạt bởi signature |

### Security Network Dashboard

Điều hướng đến **Security → Network** từ menu bên trái để xem:
- Bản đồ thế giới về nguồn gốc sự kiện
- Thống kê tổng hợp lưu lượng
- Bảng sự kiện có thể cuộn

---

## Các trường Elasticsearch Index quan trọng

| Trường | Mô tả |
|---|---|
| `event.type` | Loại sự kiện: `alert`, `flow`, `dns`, `http`, v.v. |
| `suricata.eve.alert.signature` | Tên signature đã kích hoạt |
| `suricata.eve.alert.signature_id` | Suricata SID |
| `network.community_id` | Community Flow ID để tương quan đa công cụ |
| `source.ip` / `destination.ip` | Địa chỉ nguồn và đích |

---

## Tóm tắt

Trong hướng dẫn này, bạn đã:

- Cài đặt Elasticsearch và Kibana với xpack security
- Tạo và lưu trữ an toàn mật khẩu cho các Elasticsearch user tích hợp sẵn
- Cấu hình Kibana với encryption key và keystore credential
- Cài đặt Filebeat trên Suricata server và bật Suricata module
- Nạp SIEM dashboard và xác nhận sự kiện Suricata xuất hiện trong Kibana

---

## Tài liệu tham khảo

- [Tài liệu Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/)
- [Tài liệu Kibana](https://www.elastic.co/guide/en/kibana/current/)
- [Filebeat Suricata Module](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-module-suricata.html)

---

## Điều hướng

| | |
|---|---|
| **← Trước** | [Phần 3: Cấu hình Suricata như một IPS](03-cau-hinh-ips.md) |
| **Tiếp theo →** | [Phần 5: Kibana SIEM — Rules, Timelines và Cases](05-kibana-siem.md) |
| **↑ Tổng quan** | [README — Tổng quan chuỗi](README.md) |
