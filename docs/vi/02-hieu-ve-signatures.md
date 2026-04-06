---
title: "Hiểu về Suricata Signatures"
description: "Tìm hiểu sâu về cấu trúc Suricata signature — actions, headers và options — kèm ví dụ thực tế để viết custom detection rule."
author: "Jamon Camisso"
date: 2021-11-25
category: Bảo mật
series: "SIEM với Suricata và Elastic Stack"
part: 2
tags:
  - suricata
  - signatures
  - rules
  - ids
  - bảo-mật
  - mạng
---

# Phần 2 — Hiểu về Suricata Signatures

| | |
|---|---|
| **Chuỗi hướng dẫn** | SIEM với Suricata và Elastic Stack |
| **Phần** | 2 / 5 |
| **Độ khó** | Trung bình |
| **Thời gian** | ~20 phút |
| **Hệ điều hành** | Bất kỳ (khuyến nghị Linux) |

---

## Mục lục

- [Giới thiệu](#giới-thiệu)
- [Yêu cầu](#yêu-cầu)
- [Cấu trúc Signature](#cấu-trúc-signature)
- [Actions (Hành động)](#actions-hành-động)
- [Headers (Phần mô tả lưu lượng)](#headers-phần-mô-tả-lưu-lượng)
  - [Protocols](#protocols)
  - [Cú pháp địa chỉ và port](#cú-pháp-địa-chỉ-và-port)
  - [Chiều lưu lượng](#chiều-lưu-lượng)
- [Options (Tùy chọn)](#options-tùy-chọn)
  - [msg — Thông điệp mô tả alert](#msg--thông-điệp-mô-tả-alert)
  - [content — Kiểm tra payload](#content--kiểm-tra-nội-dung-payload)
  - [sid và rev](#sid-và-rev--signature-id-và-phiên-bản)
  - [reference](#reference--tài-liệu-tham-khảo-ngoài)
  - [classtype](#classtype--phân-loại-traffic)
  - [target](#target--xác-định-host-nguồn-và-đích)
- [Viết Custom Rules](#viết-custom-rules)
- [Triển khai Custom Rules](#triển-khai-custom-rules)
- [Tóm tắt](#tóm-tắt)

---

## Giới thiệu

[Hướng dẫn trước](01-cai-dat-suricata.md) đã đề cập cài đặt Suricata và tải ET Open ruleset với hơn 30.000 signature. Tuy nhiên, nhiều signature trong số đó có thể không phù hợp với môi trường của bạn.

Hướng dẫn này giải thích:

- **Cấu trúc** của một Suricata signature
- Các **action**, trường **header** và **option** quan trọng
- Cách **viết custom rule** phù hợp với mạng của bạn

Hiểu rõ signature cho phép duy trì ruleset gọn, có mục tiêu — giảm false positive và cải thiện hiệu suất xử lý của Suricata.

---

## Yêu cầu

- Suricata đã cài đặt và chạy ([Phần 1](01-cai-dat-suricata.md))
- ET Open ruleset đã tải về qua `suricata-update`
- Kiến thức cơ bản về mạng (TCP/UDP, port, địa chỉ IP)

---

## Cấu trúc Signature

Mọi Suricata signature đều theo cấu trúc ba phần:

```
ACTION HEADER (OPTIONS)
```

| Thành phần | Mô tả |
|---|---|
| **Action** | Hành động khi traffic khớp với rule |
| **Header** | Xác định phạm vi mạng: protocol, IP nguồn/đích, port và chiều lưu lượng |
| **Options** | Logic cụ thể của rule: message, content matching, metadata, phân loại |

### Ví dụ Signature đầy đủ

```
alert ip any any -> any any (msg:"GPL ATTACK_RESPONSE id check returned root"; content:"uid=0|28|root|29|"; classtype:bad-unknown; sid:2100498; rev:7; metadata:created_at 2010_09_23, updated_at 2010_09_23;)
```

Phân tích:

| Thành phần | Giá trị |
|---|---|
| **Action** | `alert` |
| **Header** | `ip any any -> any any` |
| **Options** | `msg:"..."` `content:"..."` `classtype:...` `sid:...` `rev:...` |

---

## Actions (Hành động)

Action xác định phản hồi của Suricata khi packet khớp signature:

| Action | Chế độ | Hành vi |
|---|---|---|
| `alert` | IDS & IPS | Tạo alert entry và ghi log sự kiện |
| `pass` | IDS & IPS | Cho phép packet đi qua; bỏ qua việc tạo alert |
| `drop` | **Chỉ IPS** | Loại bỏ gói tin; TCP connection sẽ timeout |
| `reject` | **Chỉ IPS** | Gửi TCP RST (TCP) hoặc ICMP unreachable (khác) rồi drop packet |

> **Quan trọng:** `drop` và `reject` không có tác dụng ở IDS mode — Suricata sẽ tạo alert thay thế. Cấu hình IPS mode được đề cập trong [Phần 3](03-cau-hinh-ips.md).

---

## Headers (Phần mô tả lưu lượng)

Header xác định phạm vi traffic áp dụng cho signature.

### Cú pháp

```
<PROTOCOL> <IP_NGUON> <PORT_NGUON> -> <IP_DICH> <PORT_DICH>
```

### Protocols

| Giá trị | Phạm vi |
|---|---|
| `tcp` | Lưu lượng TCP |
| `udp` | Lưu lượng UDP |
| `icmp` | Lưu lượng ICMP |
| `ip` | Tất cả IP traffic |
| `http`, `tls`, `dns`, `ssh`, `ftp`, v.v. | Application-layer protocol |

### Cú pháp địa chỉ và port

| Cú pháp | Ý nghĩa |
|---|---|
| `203.0.113.5` | Địa chỉ IP cụ thể |
| `203.0.113.0/24` | Dải mạng CIDR |
| `any` | Khớp tất cả địa chỉ hoặc port |
| `!22` | Phủ định — khớp tất cả **ngoại trừ** port 22 |
| `[80, 443]` | Nhóm port |

### Chiều lưu lượng

| Toán tử | Ý nghĩa |
|---|---|
| `->` | Một chiều (nguồn → đích) |
| `<>` | Hai chiều |

### Ví dụ Headers

```
# Tất cả TCP traffic đến port 80
tcp any any -> any 80

# SSH traffic vào mạng 203.0.113.0/24 trên port không phải 22
ssh any any -> 203.0.113.0/24 !22

# Catch-all: kiểm tra tất cả traffic
ip any any -> any any
```

---

## Options (Tùy chọn)

Options được đặt trong ngoặc đơn `(...)`, ngăn cách nhau bằng dấu chấm phẩy `;`, thường theo dạng `key:value;`.

### `msg` — Thông điệp mô tả alert

```
msg:"SSH TRAFFIC on non-SSH port";
```

Luôn đặt `msg` mô tả rõ ràng. Đây là định danh chính khi xem alert trong log hoặc SIEM dashboard.

---

### `content` — Kiểm tra nội dung payload

Khớp chuỗi byte hoặc chuỗi ký tự cụ thể trong payload:

```
content:"uid=0|28|root|29|";
```

> Giá trị trong `|...|` là chuỗi byte hexadecimal.

Content matching mặc định **phân biệt chữ hoa/thường**. Dùng `nocase;` để không phân biệt:

```
content:"your_domain.com"; nocase;
```

Kết hợp với application-layer keyword để kiểm tra chính xác hơn:

```
alert dns any any -> any any (msg:"DNS query cho example.com"; dns.query; content:"example.com"; nocase; sid:1000010;)
```

---

### `sid` và `rev` — Signature ID và Phiên bản

Mỗi signature cần có **Signature ID (SID)** duy nhất:

```
sid:1000000;
```

**Phạm vi SID:**

| Phạm vi | Mục đích |
|---|---|
| `1000000–1999999` | Rule tùy chỉnh / nội bộ |
| `2200000–2299999` | Suricata built-in rules |
| `2000000–2099999` | Emerging Threats ET Open |

SID trùng lặp ngăn Suricata khởi động:

```
[ERRCODE: SC_ERR_DUPLICATE_SIG(176)] - Duplicate signature "..."
```

`rev` theo dõi lịch sử phiên bản của rule:

```
sid:1000000; rev:2;
```

---

### `reference` — Tài liệu tham khảo ngoài

Liên kết đến nguồn tài nguyên bên ngoài cho alert:

```
reference:cve,2014-0160;
reference:url,heartbleed.com;
```

Các loại reference được định nghĩa trong `/etc/suricata/reference.config`.

---

### `classtype` — Phân loại Traffic

Gán danh mục phân loại cho signature:

```
classtype:bad-unknown;
classtype:misc-attack;
classtype:misc-activity;
classtype:protocol-command-decode;
```

Các mục phân loại, mô tả và độ ưu tiên mặc định được định nghĩa trong `/etc/suricata/classification.config`:

```
config classification: bad-unknown,Potentially Bad Traffic,2
config classification: misc-attack,Misc Attack,2
```

Override độ ưu tiên mặc định bằng `priority` (1 là cao nhất):

```
classtype:misc-attack; priority:1;
```

---

### `target` — Xác định host nguồn và đích

Chỉ định Suricata gắn nhãn host nguồn và đích trong EVE log:

```
target:dest_ip;    # Traffic hướng vào server của bạn
target:src_ip;     # Traffic xuất phát từ server của bạn
```

Khi `target` được đặt, `eve.json` bổ sung thông tin host có cấu trúc:

```json
"source": {
  "ip": "198.51.100.10",
  "port": 54321
},
"target": {
  "ip": "203.0.113.5",
  "port": 2022
}
```

Thông tin này làm giàu SIEM query khi tìm kiếm alert theo nạn nhân hoặc kẻ tấn công.

---

## Viết Custom Rules

### 1. SSH trên port không chuẩn

```
alert ssh any any -> 203.0.113.5 !22 (
  msg:"SSH TRAFFIC on non-SSH port";
  flow:to_client, not_established;
  classtype:misc-attack;
  target:dest_ip;
  sid:1000000;
  rev:1;
)
```

### 2. HTTP trên port không chuẩn

```
alert http any any -> 203.0.113.5 !80 (
  msg:"HTTP REQUEST on non-HTTP port";
  flow:to_client, not_established;
  classtype:misc-activity;
  sid:1000002;
  rev:1;
)
```

### 3. TLS trên port không chuẩn

```
alert tls any any -> 203.0.113.5 !443 (
  msg:"TLS TRAFFIC on non-standard port";
  flow:to_client, not_established;
  classtype:misc-activity;
  sid:1000004;
  rev:1;
)
```

### 4. DNS query cho domain cụ thể

```
alert dns any any -> any any (
  msg:"DNS query cho domain đáng ngờ";
  dns.query;
  content:"malicious-domain.com";
  nocase;
  sid:1000010;
  rev:1;
)
```

---

## Triển khai Custom Rules

Tạo file rule nội bộ:

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

Thêm rule và đăng ký file trong `suricata.yaml`:

```bash
sudo nano /etc/suricata/suricata.yaml
```

```yaml
rule-files:
  - suricata.rules
  - local.rules
```

Kiểm tra cấu hình đã cập nhật:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```

Tải lại rule mà không cần restart:

```bash
sudo kill -usr2 $(pidof suricata)
```

---

## Tóm tắt

Trong hướng dẫn này, bạn đã:

- Nắm được cấu trúc ba phần của signature: **Action**, **Header**, **Options**
- Hiểu từng loại action và khi nào `drop`/`reject` có tác dụng
- Xây dựng header với protocol, IP, port, phủ định và toán tử chiều lưu lượng
- Khám phá các option quan trọng: `content`, `msg`, `sid`, `rev`, `reference`, `classtype`, `target`
- Tạo và triển khai custom rule cho SSH, HTTP, TLS và DNS traffic

---

## Tài liệu tham khảo

- [Tài liệu Rules Suricata](https://suricata.readthedocs.io/en/latest/rules/)
- [Emerging Threats SID Allocation](https://doc.emergingthreats.net/bin/view/Main/SidAllocation)

---

## Điều hướng

| | |
|---|---|
| **← Trước** | [Phần 1: Cài đặt Suricata trên Ubuntu 20.04](01-cai-dat-suricata.md) |
| **Tiếp theo →** | [Phần 3: Cấu hình Suricata như một IPS](03-cau-hinh-ips.md) |
| **↑ Tổng quan** | [README — Tổng quan chuỗi](README.md) |
