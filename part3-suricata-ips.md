# Phần 3: Cấu hình Suricata như một Intrusion Prevention System (IPS) trên Ubuntu 20.04

> **Tác giả:** Jamon Camisso | **Ngày xuất bản:** December 10, 2021

---

## Giới thiệu

Mặc định, Suricata hoạt động ở chế độ **IDS (Intrusion Detection System)** — chỉ theo dõi và ghi log, không chủ động chặn lưu lượng. Trong phần này, bạn sẽ học cách chuyển Suricata sang chế độ **IPS (Intrusion Prevention System)**, cho phép chủ động **drop** lưu lượng đáng ngờ ngoài việc tạo alert.

> **Cảnh báo:** Trước khi bật IPS mode, hãy kiểm tra kỹ các signature đã bật. Một signature cấu hình sai hoặc quá rộng có thể chặn lưu lượng hợp lệ, thậm chí block quyền truy cập SSH vào server.

---

## Yêu cầu

- Suricata đã cài đặt và chạy ([Phần 1](part1-install-suricata.md))
- Đã nắm vững cấu trúc signatures ([Phần 2](part2-suricata-signatures.md))
- ET Open Ruleset đã được tải
- `jq` đã được cài đặt:

```bash
sudo apt update && sudo apt install jq
```

---

## Bước 1 — Thêm Custom Signatures

### Tìm IP public của server

```bash
ip -brief address show
```

Kết quả mẫu:

```
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             203.0.113.5/20 10.20.0.5/16 2001:DB8::1/32 fe80::...
eth1             UP             10.137.0.2/16 fe80::...
```

Các IP public sẽ tương tự `203.0.113.5` (IPv4) và `2001:DB8::1/32` (IPv6).

### Tạo file rule tùy chỉnh

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

Thêm signature phát hiện SSH trên port không chuẩn:

```
alert ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; flow:to_client, not_established; classtype: misc-attack; target: dest_ip; sid:1000000;)
alert ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; flow:to_client, not_established; classtype: misc-attack; target: dest_ip; sid:1000001;)
```

Thay `203.0.113.5` và `2001:DB8::1/32` bằng IP thực tế của bạn.

Thêm signature cho HTTP traffic:

```
alert http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; flow:to_client, not_established; classtype:misc-activity; sid:1000002;)
alert http any any -> 2001:DB8::1/32 !80 (msg:"HTTP REQUEST on non-HTTP port"; flow:to_client, not_established; classtype:misc-activity; sid:1000003;)
```

Thêm signature cho TLS traffic:

```
alert tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS HTTP port"; flow:to_client, not_established; classtype:misc-activity; sid:1000004;)
alert tls any any -> 2001:DB8::1/32 !443 (msg:"TLS TRAFFIC on non-TLS HTTP port"; flow:to_client, not_established; classtype:misc-activity; sid:1000005;)
```

Lưu và đóng file. Thêm `local.rules` vào cấu hình Suricata:

```bash
sudo nano /etc/suricata/suricata.yaml
```

Tìm phần `rule-files:` và thêm:

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

## Bước 2 — Chuyển Signature Action sang `drop`

Sau khi đã kiểm tra và tin tưởng các signature, chuyển `alert` thành `drop`:

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

```
# /var/lib/suricata/rules/local.rules

drop ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype: misc-attack; target: dest_ip; sid:1000000;)
drop ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype: misc-attack; target: dest_ip; sid:1000001;)
drop http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000002;)
drop http any any -> 2001:DB8::1/32 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000003;)
drop tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS HTTP port"; classtype:misc-activity; sid:1000004;)
drop tls any any -> 2001:DB8::1/32 !443 (msg:"TLS TRAFFIC on non-TLS HTTP port"; classtype:misc-activity; sid:1000005;)
```

> **Khuyến nghị:** Đối với file `suricata.rules` (ET Open với hơn 30,000 rules), **không** chuyển toàn bộ sang `drop` ngay. Hãy để theo dõi alert vài ngày/tuần trước, sau đó chọn lọc những SID cụ thể để chuyển sang drop dựa trên dữ liệu thực tế.

### So sánh `drop` và `reject`

| Action | Cách hoạt động | Phù hợp với |
|---|---|---|
| `drop` | Loại bỏ gói tin, kết nối TCP sẽ timeout | Network scan, invalid packets |
| `reject` | Gửi TCP reset (TCP) hoặc ICMP error (UDP/khác) và drop packet | Cần phản hồi nhanh cho client |

---

## Bước 3 — Bật chế độ NFQUEUE (IPS Mode)

Mặc định Suricata chạy ở `af-packet` mode (IDS). Chuyển sang `nfqueue` mode để bật IPS:

```bash
sudo nano /etc/default/suricata
```

Tìm và sửa:

```bash
# LISTENMODE=af-packet
LISTENMODE=nfqueue
```

Khởi động lại Suricata:

```bash
sudo systemctl restart suricata.service
```

Kiểm tra trạng thái:

```bash
sudo systemctl status suricata.service
```

Kết quả mong đợi:

```
● suricata.service - LSB: Next Generation IDS/IPS
     Active: active (running) since Wed 2021-12-01 15:54:28 UTC; 2s ago
...
Dec 01 15:54:28 suricata suricata[1452]: Starting suricata in IPS (nfqueue) mode... done.
```

Lưu ý dòng **`Starting suricata in IPS (nfqueue) mode... done.`** xác nhận Suricata đang chạy ở IPS mode.

---

## Bước 4 — Cấu hình UFW để chuyển traffic qua Suricata

Mở file UFW IPv4 rules:

```bash
sudo nano /etc/ufw/before.rules
```

Thêm các dòng sau vào ngay sau phần `# End required lines`:

```bash
# /etc/ufw/before.rules

# Don't delete these required lines, otherwise there will be errors
*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]
:ufw-not-local - [0:0]
# End required lines

## Start Suricata NFQUEUE rules
-I INPUT 1 -p tcp --dport 22 -j NFQUEUE --queue-bypass
-I OUTPUT 1 -p tcp --sport 22 -j NFQUEUE --queue-bypass
-I FORWARD -j NFQUEUE
-I INPUT 2 -j NFQUEUE
-I OUTPUT 2 -j NFQUEUE
## End Suricata NFQUEUE rules
```

Thêm **nội dung tương tự** vào file `/etc/ufw/before6.rules` cho IPv6.

### Giải thích các rule

| Rule | Mục đích |
|---|---|
| `INPUT 1 --dport 22 --queue-bypass` | Bypass Suricata cho SSH **incoming** khi Suricata không chạy |
| `OUTPUT 1 --sport 22 --queue-bypass` | Bypass Suricata cho SSH **outgoing** khi Suricata không chạy |
| `FORWARD -j NFQUEUE` | Chuyển traffic forward (gateway mode) qua Suricata |
| `INPUT 2 -j NFQUEUE` | Chuyển tất cả traffic incoming còn lại qua Suricata |
| `OUTPUT 2 -j NFQUEUE` | Chuyển tất cả traffic outgoing còn lại qua Suricata |

> **Quan trọng:** Hai rule SSH đầu tiên đảm bảo bạn vẫn có thể truy cập server qua SSH ngay cả khi Suricata không chạy. Nếu thiếu các rule này, khi Suricata dừng, tất cả traffic sẽ bị gửi đến NFQUEUE và bị drop — bao gồm cả SSH.

Khởi động lại UFW:

```bash
sudo systemctl restart ufw.service
```

### Dùng firewalld thay vì UFW

Nếu sử dụng `firewalld`:

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

## Bước 5 — Kiểm tra traffic bị chặn

Trước tiên, đổi signature `sid:2100498` trong `/var/lib/suricata/rules/suricata.rules` từ `alert` thành `drop`:

```
drop ip any any -> any any (msg:"GPL ATTACK_RESPONSE id check returned root"; content:"uid=0|28|root|29|"; classtype:bad-unknown; sid:2100498; rev:7; metadata:created_at 2010_09_23, updated_at 2010_09_23;)
```

Tải lại rule:

```bash
sudo kill -usr2 $(pidof suricata)
```

Test bằng `curl` với timeout 5 giây:

```bash
curl --max-time 5 http://testmynids.org/uid/index.html
```

Kết quả mong đợi (request bị chặn):

```
curl: (28) Operation timed out after 5000 milliseconds with 0 out of 39 bytes received
```

Xác nhận Suricata đã block bằng log:

```bash
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json
```

Kết quả:

```json
{
  "community_id": "1:tw19kjR2LeWacglA094gRfEEuDU=",
  "alert": {
    "action": "blocked",
    "signature_id": 2100498,
    "signature": "GPL ATTACK_RESPONSE id check returned root",
    "category": "Potentially Bad Traffic",
    "severity": 2
  }
}
```

Dòng **`"action": "blocked"`** xác nhận Suricata đã thành công chặn traffic.

---

## Kết luận

Bạn đã hoàn thành:

- Tạo custom signature cho SSH, HTTP, TLS traffic trên port không chuẩn
- Chuyển action từ `alert` sang `drop` cho IPS mode
- Bật Suricata ở chế độ `nfqueue` (IPS)
- Cấu hình UFW để chuyển traffic qua Suricata
- Xác nhận Suricata đang chặn lưu lượng đáng ngờ

---

## Tham khảo

- [Suricata IPS Mode Documentation](https://suricata.readthedocs.io/en/latest/setting-up-ipsinline-for-linux.html)
- [Netfilter NFQUEUE](https://netfilter.org/projects/libnetfilter_queue/)

---

## Điều hướng

| | |
|---|---|
| **Trước đó:** | [← Phần 2: Hiểu về Suricata Signatures](part2-suricata-signatures.md) |
| **Tiếp theo:** | [Phần 4: Xây dựng SIEM với Elastic Stack →](part4-siem-elastic-stack.md) |
| **Tổng quan:** | [← README](README.md) |
