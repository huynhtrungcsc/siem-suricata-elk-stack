---
title: "Cấu hình Suricata như một Intrusion Prevention System (IPS) trên Ubuntu 20.04"
description: "Bật IPS mode cho Suricata với NFQUEUE, cấu hình action drop và reject cho custom signature, route lưu lượng mạng qua Suricata bằng UFW trên Ubuntu 20.04."
author: "Jamon Camisso"
date: 2021-12-10
category: Bảo mật
series: "SIEM với Suricata và Elastic Stack"
part: 3
tags:
  - suricata
  - ips
  - nfqueue
  - ufw
  - ubuntu
  - bảo-mật
  - intrusion-prevention
---

# Phần 3 — Cấu hình Suricata như một IPS trên Ubuntu 20.04

| | |
|---|---|
| **Chuỗi hướng dẫn** | SIEM với Suricata và Elastic Stack |
| **Phần** | 3 / 5 |
| **Độ khó** | Trung bình |
| **Thời gian** | ~30 phút |
| **Hệ điều hành** | Ubuntu 20.04 LTS |

---

## Giới thiệu

Mặc định, Suricata chạy ở chế độ **IDS** thụ động — quan sát traffic và tạo alert mà không chặn gì. Hướng dẫn này bao gồm việc chuyển sang **IPS mode** chủ động, cho phép Suricata drop hoặc reject các packet khớp trong thời gian thực.

> **Cảnh báo:** Trước khi bật IPS mode, hãy xem xét kỹ các signature đang kích hoạt. Một rule quá rộng hoặc cấu hình sai có thể chặn lưu lượng hợp lệ — kể cả quyền truy cập SSH của bạn vào server.

---

## Yêu cầu

- Suricata đã cài đặt và chạy ở IDS mode ([Phần 1](01-cai-dat-suricata.md))
- Quen thuộc với cấu trúc signature ([Phần 2](02-hieu-ve-signatures.md))
- ET Open ruleset đã tải qua `suricata-update`
- `jq` đã cài: `sudo apt install jq`

---

## Bước 1 — Thêm Custom Signatures

### Tìm IP public của server

```bash
ip -brief address show
```

Ví dụ kết quả:

```
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             203.0.113.5/20 2001:DB8::1/32 ...
eth1             UP             10.137.0.2/16 ...
```

Ghi nhớ IPv4 public (`203.0.113.5`) và IPv6 (`2001:DB8::1/32`).

### Tạo file rule nội bộ

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

Thêm các signature phát hiện traffic trên port không chuẩn. Thay `203.0.113.5` và `2001:DB8::1/32` bằng IP thực tế:

**SSH trên port không chuẩn:**

```
alert ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; flow:to_client,not_established; classtype:misc-attack; target:dest_ip; sid:1000000;)
alert ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; flow:to_client,not_established; classtype:misc-attack; target:dest_ip; sid:1000001;)
```

**HTTP trên port không chuẩn:**

```
alert http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; flow:to_client,not_established; classtype:misc-activity; sid:1000002;)
alert http any any -> 2001:DB8::1/32 !80 (msg:"HTTP REQUEST on non-HTTP port"; flow:to_client,not_established; classtype:misc-activity; sid:1000003;)
```

**TLS trên port không chuẩn:**

```
alert tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS port"; flow:to_client,not_established; classtype:misc-activity; sid:1000004;)
alert tls any any -> 2001:DB8::1/32 !443 (msg:"TLS TRAFFIC on non-TLS port"; flow:to_client,not_established; classtype:misc-activity; sid:1000005;)
```

Đăng ký file trong `suricata.yaml`:

```bash
sudo nano /etc/suricata/suricata.yaml
```

```yaml
rule-files:
  - suricata.rules
  - local.rules
```

Kiểm tra cấu hình:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```

---

## Bước 2 — Chuyển Action Signature sang `drop`

Sau khi các signature đã được kiểm tra và tạo alert đúng, chuyển `alert` thành `drop` để chặn traffic chủ động.

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

```
# /var/lib/suricata/rules/local.rules

drop ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype:misc-attack; target:dest_ip; sid:1000000;)
drop ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype:misc-attack; target:dest_ip; sid:1000001;)
drop http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000002;)
drop http any any -> 2001:DB8::1/32 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000003;)
drop tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS port"; classtype:misc-activity; sid:1000004;)
drop tls any any -> 2001:DB8::1/32 !443 (msg:"TLS TRAFFIC on non-TLS port"; classtype:misc-activity; sid:1000005;)
```

### So sánh `drop` và `reject`

| Action | Hành vi | Phù hợp với |
|---|---|---|
| `drop` | Loại bỏ gói tin; TCP connection timeout | Network scan, kết nối không hợp lệ |
| `reject` | Gửi TCP RST (TCP) hoặc ICMP unreachable (UDP/ICMP); drop packet | Cần phản hồi nhanh cho client |

> **Khuyến nghị với `suricata.rules`:** ET Open ruleset chứa 30.000+ signature. **Không** chuyển đổi hàng loạt sang `drop`. Thay vào đó, để ở `alert` vài ngày để phân tích SID nào tạo alert liên quan đến môi trường của bạn, rồi có chọn lọc chuyển những SID đó sang `drop`.

---

## Bước 3 — Bật NFQUEUE Mode (IPS)

Suricata mặc định dùng `af-packet` mode (passive capture). Chuyển sang `nfqueue` mode để chặn và xử lý packet chủ động qua Netfilter framework của Linux:

```bash
sudo nano /etc/default/suricata
```

```bash
# /etc/default/suricata

# LISTENMODE=af-packet
LISTENMODE=nfqueue
```

Khởi động lại dịch vụ:

```bash
sudo systemctl restart suricata.service
```

Xác minh IPS mode đang hoạt động:

```bash
sudo systemctl status suricata.service
```

Tìm dòng xác nhận:

```
Starting suricata in IPS (nfqueue) mode... done.
```

---

## Bước 4 — Cấu hình UFW Route Traffic qua Suricata

Mở file UFW IPv4 rules:

```bash
sudo nano /etc/ufw/before.rules
```

Thêm block sau ngay **sau** comment `# End required lines`:

```
## Start Suricata NFQUEUE rules
-I INPUT 1 -p tcp --dport 22 -j NFQUEUE --queue-bypass
-I OUTPUT 1 -p tcp --sport 22 -j NFQUEUE --queue-bypass
-I FORWARD -j NFQUEUE
-I INPUT 2 -j NFQUEUE
-I OUTPUT 2 -j NFQUEUE
## End Suricata NFQUEUE rules
```

Thêm **cùng block** vào `/etc/ufw/before6.rules` cho IPv6.

### Giải thích các rule

| Rule | Mục đích |
|---|---|
| `INPUT 1 --dport 22 --queue-bypass` | Bypass Suricata cho SSH vào — giữ quyền truy cập nếu Suricata dừng |
| `OUTPUT 1 --sport 22 --queue-bypass` | Bypass Suricata cho SSH ra — lý do an toàn tương tự |
| `FORWARD -j NFQUEUE` | Route traffic forward (gateway mode) qua Suricata |
| `INPUT 2 -j NFQUEUE` | Route tất cả traffic vào còn lại qua Suricata |
| `OUTPUT 2 -j NFQUEUE` | Route tất cả traffic ra còn lại qua Suricata |

> **Quan trọng:** Các rule SSH bypass đảm bảo quyền truy cập SSH được duy trì ngay cả khi Suricata dừng hoặc crash. Nếu thiếu, toàn bộ traffic sẽ bị xếp hàng vào NFQUEUE chết và bị drop — khóa hoàn toàn quyền truy cập server.

Tải lại UFW:

```bash
sudo systemctl restart ufw.service
```

### Thay thế: firewalld

```bash
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp --dport 22 -j NFQUEUE --queue-bypass
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 0 -p tcp --dport 22 -j NFQUEUE --queue-bypass
firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 1 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv6 filter FORWARD 0 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p tcp --sport 22 -j NFQUEUE --queue-bypass
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv6 filter OUTPUT 0 -p tcp --sport 22 -j NFQUEUE --queue-bypass
firewall-cmd --permanent --direct --add-rule ipv6 filter OUTPUT 1 -j NFQUEUE
```

---

## Bước 5 — Kiểm tra chặn traffic

Sửa `sid:2100498` trong `/var/lib/suricata/rules/suricata.rules` sang `drop`:

```
drop ip any any -> any any (msg:"GPL ATTACK_RESPONSE id check returned root"; content:"uid=0|28|root|29|"; classtype:bad-unknown; sid:2100498; rev:7; metadata:created_at 2010_09_23, updated_at 2010_09_23;)
```

Tải lại signature:

```bash
sudo kill -usr2 $(pidof suricata)
```

Gửi request test:

```bash
curl --max-time 5 http://testmynids.org/uid/index.html
```

Kết quả mong đợi — request timeout:

```
curl: (28) Operation timed out after 5000 milliseconds with 0 out of 39 bytes received
```

Xác nhận việc chặn trong EVE log:

```bash
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json
```

Kết quả mong đợi:

```json
{
  "alert": {
    "action": "blocked",
    "signature_id": 2100498,
    "signature": "GPL ATTACK_RESPONSE id check returned root",
    "category": "Potentially Bad Traffic",
    "severity": 2
  }
}
```

Trường `"action": "blocked"` xác nhận Suricata đang chủ động chặn traffic ở IPS mode.

---

## Tóm tắt

Trong hướng dẫn này, bạn đã:

- Tạo custom signature cho SSH, HTTP, TLS traffic trên port không chuẩn
- Chuyển action từ `alert` sang `drop` để chặn chủ động
- Chuyển Suricata từ IDS (`af-packet`) sang IPS (`nfqueue`) mode
- Cấu hình UFW route tất cả traffic qua Suricata đồng thời giữ SSH access
- Xác minh việc chặn traffic qua curl timeout và EVE log

---

## Tài liệu tham khảo

- [Tài liệu IPS Mode Suricata](https://suricata.readthedocs.io/en/latest/setting-up-ipsinline-for-linux.html)
- [Netfilter NFQUEUE](https://netfilter.org/projects/libnetfilter_queue/)

---

## Điều hướng

| | |
|---|---|
| **← Trước** | [Phần 2: Hiểu về Suricata Signatures](02-hieu-ve-signatures.md) |
| **Tiếp theo →** | [Phần 4: Xây dựng SIEM với Elastic Stack](04-xay-dung-siem.md) |
| **↑ Tổng quan** | [README — Tổng quan chuỗi](README.md) |
