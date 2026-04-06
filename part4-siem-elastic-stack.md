# Phần 4: Xây dựng SIEM với Suricata và Elastic Stack trên Ubuntu 20.04

> **Tác giả:** Jamon Camisso | **Ngày xuất bản:** January 15, 2022

---

## Giới thiệu

Các phần trước đã hướng dẫn cài đặt và cấu hình Suricata như một IDS/IPS. Trong phần này, bạn sẽ tích hợp Suricata với **Elastic Stack** để xây dựng hệ thống **SIEM (Security Information and Event Management)** hoàn chỉnh.

### Các thành phần sẽ triển khai

| Thành phần | Vai trò |
|---|---|
| **Elasticsearch** | Lưu trữ, lập chỉ mục, tương quan và tìm kiếm sự kiện bảo mật |
| **Kibana** | Hiển thị và điều hướng trong dữ liệu sự kiện bảo mật |
| **Filebeat** | Đọc file `eve.json` của Suricata và gửi tới Elasticsearch |
| **Suricata** | Quét lưu lượng mạng, ghi log và drop packet theo rules |

---

## Yêu cầu

### Suricata Server (đã có từ các phần trước)
- Ubuntu 20.04
- Suricata đã cài đặt và cấu hình ([Phần 1](part1-install-suricata.md) — [Phần 3](part3-suricata-ips.md))
- Signatures đã được tải và cấu hình

### Elasticsearch Server (mới)
- Ubuntu 20.04
- **4GB RAM và 2 CPU tối thiểu**
- Người dùng non-root có quyền `sudo`
- Có thể giao tiếp với Suricata server qua **private IP**

> **Lưu ý:** Có thể chạy tất cả trên cùng một server cho mục đích thử nghiệm.

---

## Bước 1 — Cài đặt Elasticsearch và Kibana

Thực hiện trên **Elasticsearch Server**.

Thêm Elastic GPG key:

```bash
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
```

Thêm Elastic repository:

```bash
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
```

Cài đặt Elasticsearch và Kibana:

```bash
sudo apt update
sudo apt install elasticsearch kibana
```

Tìm private IP của Elasticsearch server:

```bash
ip -brief address show
```

Kết quả mẫu:

```
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             159.89.122.115/20 10.20.0.8/16 ...
eth1             UP             10.137.0.5/16 ...
```

Ghi nhớ private IP (ví dụ `10.137.0.5`) — sẽ dùng trong các bước tiếp theo.

---

## Bước 2 — Cấu hình Elasticsearch

### Cấu hình Network

Mở file cấu hình:

```bash
sudo nano /etc/elasticsearch/elasticsearch.yml
```

Tìm dòng `#network.host: 192.168.0.1` và thêm phía dưới:

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

Lưu và đóng file.

Mở firewall cho private network interface:

```bash
sudo ufw allow in on eth1
sudo ufw allow out on eth1
```

Thay `eth1` bằng tên interface private network thực tế.

### Khởi động Elasticsearch

```bash
sudo systemctl start elasticsearch.service
```

### Tạo mật khẩu cho Elasticsearch users

```bash
cd /usr/share/elasticsearch/bin
sudo ./elasticsearch-setup-passwords auto
```

Nhấn `y` khi được hỏi. Kết quả mẫu:

```
Changed password for user kibana_system
PASSWORD kibana_system = 1HLVxfqZMd7aFQS6Uabl

Changed password for user elastic
PASSWORD elastic = 6kNbsxQGYZ2EQJiqJpgl
```

> **Quan trọng:** Lưu lại tất cả mật khẩu này ở nơi an toàn. Bạn sẽ không thể chạy lại lệnh này. Cần dùng:
> - `kibana_system` password → cấu hình Kibana
> - `elastic` password → cấu hình Filebeat

---

## Bước 3 — Cấu hình Kibana

### Tạo Encryption Keys

```bash
cd /usr/share/kibana/bin/
sudo ./kibana-encryption-keys generate -q
```

Kết quả mẫu:

```
xpack.encryptedSavedObjects.encryptionKey: 66fbd85ceb3cba51c0e939fb2526f585
xpack.reporting.encryptionKey: 9358f4bc7189ae0ade1b8deeec7f38ef
xpack.security.encryptionKey: 8f847a594e4a813c4187fa93c884e92b
```

Mở file cấu hình Kibana:

```bash
sudo nano /etc/kibana/kibana.yml
```

Thêm 3 dòng encryption keys vào cuối file:

```yaml
xpack.encryptedSavedObjects.encryptionKey: 66fbd85ceb3cba51c0e939fb2526f585
xpack.reporting.encryptionKey: 9358f4bc7189ae0ade1b8deeec7f38ef
xpack.security.encryptionKey: 8f847a594e4a813c4187fa93c884e92b
```

### Cấu hình Network

Tìm dòng `#server.host: "localhost"` và thêm phía dưới:

```yaml
#server.host: "localhost"
server.host: "your_private_ip"
```

Lưu và đóng file.

### Cấu hình Credentials (sử dụng Keystore)

```bash
cd /usr/share/kibana/bin
```

Thêm username:

```bash
sudo ./kibana-keystore add elasticsearch.username
```

Nhập `kibana_system` khi được hỏi.

Thêm password:

```bash
sudo ./kibana-keystore add elasticsearch.password
```

Dán password `kibana_system` đã tạo ở Bước 2.

### Khởi động Kibana

```bash
sudo systemctl start kibana.service
```

---

## Bước 4 — Cài đặt và cấu hình Filebeat

Thực hiện trên **Suricata Server**.

Thêm Elastic GPG key:

```bash
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
```

Cài đặt Filebeat:

```bash
sudo apt update
sudo apt install filebeat
```

Mở file cấu hình:

```bash
sudo nano /etc/filebeat/filebeat.yml
```

### Cấu hình Kibana endpoint (khoảng dòng 100)

```yaml
setup.kibana:
  #host: "localhost:5601"
  host: "your_private_ip:5601"
```

### Cấu hình Elasticsearch output (khoảng dòng 130)

```yaml
output.elasticsearch:
  hosts: ["your_private_ip:9200"]

  username: "elastic"
  password: "6kNbsxQGYZ2EQJiqJpgl"
```

Thay `your_private_ip` bằng IP private của Elasticsearch server và `6kNbsxQGYZ2EQJiqJpgl` bằng mật khẩu `elastic` thực tế.

Lưu và đóng file.

### Bật Suricata module trong Filebeat

```bash
sudo filebeat modules enable suricata
```

### Nạp dashboards và pipelines vào Elasticsearch

```bash
sudo filebeat setup
```

Kết quả thành công:

```
Index setup finished.
Loading dashboards (Kibana must be running and reachable)
Loaded dashboards
Loaded Ingest pipelines
```

### Khởi động Filebeat

```bash
sudo systemctl start filebeat.service
```

---

## Bước 5 — Truy cập Kibana SIEM Dashboards

### Kết nối Kibana qua SSH Tunnel

Do Kibana chỉ lắng nghe trên private IP, cần tạo SSH tunnel để truy cập từ máy local.

Chạy lệnh sau trên máy tính cá nhân (Linux/macOS/Windows 10+):

```bash
ssh -L 5601:your_private_ip:5601 sammy@203.0.113.5 -N
```

Các tham số:
- `-L 5601:your_private_ip:5601` — Forward port local 5601 đến Kibana
- `sammy@203.0.113.5` — User và public IP của Elasticsearch server
- `-N` — Chỉ giữ kết nối, không chạy command

Để đóng tunnel: nhấn `CTRL+C`.

### Đăng nhập Kibana

Mở browser và truy cập: `http://127.0.0.1:5601`

Đăng nhập với:
- **Username:** `elastic`
- **Password:** password đã tạo ở Bước 2

### Tìm Suricata Dashboards

Trong ô tìm kiếm ở đầu trang Kibana, nhập:

```
type:dashboard suricata
```

Hai dashboard sẽ xuất hiện:
- **[Filebeat Suricata] Events Overview** — Tổng quan tất cả sự kiện
- **[Filebeat Suricata] Alerts** — Danh sách alerts

### Security Dashboard

Truy cập Security → Network từ menu bên trái để xem:
- Bản đồ các sự kiện mạng
- Dữ liệu tổng hợp về traffic trên mạng
- Bảng danh sách tất cả sự kiện theo timeframe

---

## Cấu trúc dữ liệu trong Elasticsearch

Filebeat tạo các index patterns sau:
- `filebeat-*` — Tất cả logs từ Filebeat
- Index được phân vùng theo ngày: `filebeat-7.x.x-YYYY.MM.DD`

Các trường quan trọng trong Suricata events:
- `event.type` — Loại sự kiện (`alert`, `flow`, `dns`, v.v.)
- `suricata.eve.alert.signature` — Tên signature đã kích hoạt
- `suricata.eve.alert.signature_id` — SID của signature
- `network.community_id` — Community Flow ID để tương quan sự kiện
- `source.ip`, `destination.ip` — IP nguồn và đích

---

## Kết luận

Bạn đã hoàn thành:

- Cài đặt và cấu hình Elasticsearch với xpack security
- Cài đặt và cấu hình Kibana với encryption keys và credentials
- Cài đặt và cấu hình Filebeat trên Suricata server
- Kết nối tất cả thành phần và xác nhận hoạt động
- Truy cập và khám phá Kibana SIEM dashboards

---

## Tham khảo

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Filebeat Suricata Module](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-module-suricata.html)

---

## Điều hướng

| | |
|---|---|
| **Trước đó:** | [← Phần 3: Cấu hình Suricata IPS](part3-suricata-ips.md) |
| **Tiếp theo:** | [Phần 5: Tạo Rules, Timelines và Cases trong Kibana →](part5-kibana-siem-apps.md) |
| **Tổng quan:** | [← README](README.md) |
