# Phần 1: Cài đặt Suricata trên Ubuntu 20.04

> **Tác giả:** Jamon Camisso | **Ngày cập nhật:** October 23, 2021

---

## Giới thiệu

Suricata là công cụ **Network Security Monitoring (NSM)** sử dụng các bộ signature (rule) do cộng đồng và người dùng định nghĩa để kiểm tra và xử lý lưu lượng mạng. Suricata có thể:

- Ghi lại sự kiện (log events)
- Kích hoạt cảnh báo (alerts)
- Chặn lưu lượng (drop traffic) khi phát hiện gói tin hoặc request đáng ngờ

Mặc định Suricata hoạt động ở chế độ **IDS (Intrusion Detection System)** — chỉ theo dõi và ghi log, không chặn traffic. Có thể cấu hình thêm để chạy ở chế độ **IPS (Intrusion Prevention System)** — vừa ghi log, vừa chặn traffic theo rule.

---

## Yêu cầu

- Ubuntu 20.04 server với tối thiểu 2 CPU
- Người dùng non-root có quyền `sudo`
- UFW firewall đã được bật
- Kiến thức cơ bản về Linux command line

---

## Bước 1 — Cài đặt Suricata

Thêm repository của Open Information Security Foundation (OISF):

```bash
sudo add-apt-repository ppa:oisf/suricata-stable
```

Nhấn **ENTER** khi được hỏi xác nhận. Sau đó cài đặt Suricata:

```bash
sudo apt install suricata
```

Bật Suricata khởi động cùng hệ thống:

```bash
sudo systemctl enable suricata.service
```

Dừng Suricata trước khi cấu hình (để tránh lỗi khi reload):

```bash
sudo systemctl stop suricata.service
```

---

## Bước 2 — Cấu hình Suricata lần đầu

### (Tuỳ chọn) Bật Community Flow ID

Community ID giúp tương quan sự kiện giữa các công cụ khác nhau (Zeek, Elasticsearch, v.v.). Nên bật nếu có kế hoạch tích hợp với Elastic Stack.

Mở file cấu hình:

```bash
sudo nano /etc/suricata/suricata.yaml
```

Đến dòng 120 (dùng `CTRL+_` trong nano), tìm phần `# Community Flow ID` và bật lên:

```yaml
# /etc/suricata/suricata.yaml

      # enable/disable the community id feature.
      community-id: true
```

Lưu và đóng file (`CTRL+X`, `Y`, `ENTER`).

---

### Xác định network interface cần giám sát

Tìm interface mặc định:

```bash
ip -p -j route show default
```

Kết quả mẫu:

```json
[ {
        "dst": "default",
        "gateway": "203.0.113.254",
        "dev": "eth0",
        "protocol": "static",
        "flags": [ ]
    } ]
```

Giá trị `"dev": "eth0"` là tên interface. Ghi nhớ giá trị này.

Mở file cấu hình và chỉnh sửa phần `af-packet` (khoảng dòng 580):

```yaml
# /etc/suricata/suricata.yaml

af-packet:
  - interface: eth0
    cluster-id: 99
```

Thay `eth0` bằng tên interface thực tế của bạn.

Để giám sát nhiều interface, thêm các block `- interface:` trước phần `- interface: default`:

```yaml
  - interface: enp0s1
    cluster-id: 98

  - interface: default
```

> **Lưu ý:** Mỗi interface cần có `cluster-id` khác nhau.

---

### Cấu hình Live Rule Reloading

Thêm phần sau vào cuối file `/etc/suricata/suricata.yaml`:

```yaml
detect-engine:
  - rule-reload: true
```

Với cấu hình này, có thể tải lại rule mà không cần khởi động lại Suricata:

```bash
sudo kill -usr2 $(pidof suricata)
```

Lưu và đóng file.

---

## Bước 3 — Cập nhật Suricata Rulesets

Suricata đi kèm tool `suricata-update` để tải ruleset từ các nguồn bên ngoài. Tải ruleset ET Open miễn phí:

```bash
sudo suricata-update
```

Kết quả mẫu:

```
19/10/2021 -- 19:31:03 - <Info> -- No sources configured, will use Emerging Threats Open
19/10/2021 -- 19:31:03 - <Info> -- Fetching https://rules.emergingthreats.net/open/suricata-6.0.3/emerging.rules.tar.gz.
 100% - 3044855/3044855
...
19/10/2021 -- 19:31:06 - <Info> -- Writing rules to /var/lib/suricata/rules/suricata.rules: total: 31011; enabled: 23649; added: 31011; removed 0; modified: 0
```

### Thêm nguồn ruleset khác

Xem danh sách nguồn có sẵn:

```bash
sudo suricata-update list-sources
```

Ví dụ thêm ruleset `tgreen/hunting`:

```bash
sudo suricata-update enable-source tgreen/hunting
sudo suricata-update
```

---

## Bước 4 — Kiểm tra cấu hình

Chạy Suricata ở chế độ test để kiểm tra cấu hình và rules:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```

Kết quả thành công:

```
21/10/2021 -- 15:01:13 - <Notice> - Configuration provided was successfully loaded. Exiting.
```

Nếu có lỗi, Suricata sẽ hiển thị thông báo cụ thể để debug. Ví dụ lỗi file rules không tồn tại:

```
<Warning> - [ERRCODE: SC_ERR_NO_RULES(42)] - No rule files match the pattern /var/lib/suricata/rules/test.rules
```

---

## Bước 5 — Khởi chạy Suricata

Khởi động Suricata:

```bash
sudo systemctl start suricata.service
```

Kiểm tra trạng thái:

```bash
sudo systemctl status suricata.service
```

Kết quả mong đợi:

```
● suricata.service - LSB: Next Generation IDS/IPS
     Active: active (running) since Thu 2021-10-21 18:22:56 UTC; 1min 57s ago
...
Oct 21 18:22:56 suricata suricata[22636]: Starting suricata in IDS (af-packet) mode... done.
```

Theo dõi log để biết Suricata đã sẵn sàng:

```bash
sudo tail -f /var/log/suricata/suricata.log
```

Khi thấy dòng sau, Suricata đã sẵn sàng xử lý traffic:

```
19/10/2021 -- 19:22:39 - <Info> - All AFP capture threads are running.
```

Nhấn `CTRL+C` để thoát.

---

## Bước 6 — Kiểm tra Suricata Rules

Tạo request HTTP test để kích hoạt rule `2100498`:

```bash
curl http://testmynids.org/uid/index.html
```

Kết quả trả về:

```
uid=0(root) gid=0(root) groups=0(root)
```

### Kiểm tra log fast.log

```bash
grep 2100498 /var/log/suricata/fast.log
```

Kết quả mẫu (IPv4):

```
10/21/2021-18:35:57.247239  [**] [1:2100498:7] GPL ATTACK_RESPONSE id check returned root [**]
[Classification: Potentially Bad Traffic] [Priority: 2] {TCP} 204.246.178.81:80 -> 203.0.113.1:36364
```

### Kiểm tra log eve.json

Cài đặt `jq` nếu chưa có:

```bash
sudo apt install jq
```

Tìm kiếm alert theo signature ID:

```bash
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json
```

Kết quả mẫu:

```json
{
  "timestamp": "2021-10-21T19:42:47.368856+0000",
  "event_type": "alert",
  "src_ip": "203.0.113.1",
  "src_port": 80,
  "community_id": "1:XLNse90QNVTgyXCWN9JDovC0XF4=",
  "alert": {
    "action": "allowed",
    "signature_id": 2100498,
    "signature": "GPL ATTACK_RESPONSE id check returned root",
    "category": "Potentially Bad Traffic"
  }
}
```

---

## Bước 7 — Xử lý Suricata Alerts

Sau khi có alerts, có thể:

- **Chỉ log:** Phù hợp cho mục đích audit
- **Chặn traffic:** Dùng `jq` trích xuất thông tin từ EVE log rồi thêm UFW/iptables rules

Ví dụ dùng `jq` lấy IP nguồn:

```bash
jq 'select(.alert .signature_id==2100498) | .src_ip' /var/log/suricata/eve.json
```

---

## Kết luận

Bạn đã hoàn thành:

- Cài đặt Suricata từ OISF repository
- Cấu hình Community Flow ID, network interface và live rule reloading
- Tải xuống ET Open ruleset
- Xác thực cấu hình và chạy Suricata thành công
- Kiểm tra alert trong cả hai file log (`fast.log` và `eve.json`)

---

## Tham khảo

- [Trang chủ Suricata](https://suricata.io)
- [Suricata User Guide](https://suricata.readthedocs.io/)

---

## Điều hướng

| | |
|---|---|
| **Tiếp theo:** | [Phần 2: Hiểu về Suricata Signatures →](part2-suricata-signatures.md) |
| **Tổng quan:** | [← README](README.md) |
