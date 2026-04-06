# Phần 2: Hiểu về Suricata Signatures

> **Tác giả:** Jamon Camisso | **Ngày xuất bản:** November 25, 2021

---

## Giới thiệu

Phần 1 đã hướng dẫn cài đặt Suricata và tải xuống bộ ruleset ET Open. Tuy nhiên, bộ ruleset này bao gồm hàng chục nghìn rule và không phải tất cả đều phù hợp với môi trường của bạn.

Trong phần này, bạn sẽ học:

- **Cấu trúc** của một Suricata signature
- **Các keyword quan trọng** thường dùng trong rule
- Cách **viết rule tùy chỉnh** phù hợp với mạng của mình

Khi hiểu rõ cách xây dựng signature, bạn có thể viết rule riêng — giúp Suricata hoạt động hiệu quả hơn và chỉ xử lý những rule thực sự cần thiết.

---

## Yêu cầu

- Suricata đã được cài đặt và chạy (theo [Phần 1](part1-install-suricata.md))
- ET Open Ruleset đã được tải về bằng lệnh `suricata-update`
- Quen thuộc với cơ bản về network protocol (TCP/UDP/ICMP, port, IP)

---

## Cấu trúc tổng quát của một Suricata Signature

Một Suricata signature gồm ba phần chính:

```
ACTION HEADER OPTIONS
```

| Phần | Mô tả |
|---|---|
| **Action** | Hành động khi traffic khớp với rule |
| **Header** | Mô tả host, IP, port, protocol và chiều lưu lượng |
| **Options** | Nội dung cụ thể cần kiểm tra trong gói tin, message log, SID, v.v. |

Ví dụ signature đầy đủ (`sid:2100498`):

```
alert ip any any -> any any (msg:"GPL ATTACK_RESPONSE id check returned root"; content:"uid=0|28|root|29|"; classtype:bad-unknown; sid:2100498; rev:7; metadata:created_at 2010_09_23, updated_at 2010_09_23;)
```

Phân tích:
- **Action:** `alert`
- **Header:** `ip any any -> any any`
- **Options:** `(msg:"GPL ATTACK_RESPONSE..."; content:"uid=0|28|root|29|"; ...)`

---

## Actions (Hành động)

Action xác định Suricata sẽ làm gì khi packet khớp với rule:

| Action | Chế độ | Mô tả |
|---|---|---|
| `pass` | IDS/IPS | Cho phép gói tin đi qua, không tạo alert |
| `drop` | **IPS only** | Loại bỏ gói tin ngay lập tức và tạo alert. TCP connection sẽ bị timeout |
| `reject` | **IPS only** | Gửi TCP reset (với TCP) hoặc ICMP error (với các protocol khác) và drop packet |
| `alert` | IDS/IPS | Tạo alert và ghi log để phân tích thêm |

> **Quan trọng:** `drop` và `reject` chỉ hoạt động khi Suricata chạy ở chế độ IPS. Ở chế độ IDS mặc định, chúng sẽ tạo alert thay vì chặn traffic.

---

## Headers (Phần mô tả lưu lượng)

Header xác định loại lưu lượng mà rule áp dụng:

```
<PROTOCOL> <SOURCE IP> <SOURCE PORT> -> <DESTINATION IP> <DESTINATION PORT>
```

### Protocol

| Giá trị | Mô tả |
|---|---|
| `tcp` | Lưu lượng TCP |
| `udp` | Lưu lượng UDP |
| `icmp` | ICMP |
| `ip` | Tất cả IP traffic |
| `http`, `tls`, `dns`, `ssh`, v.v. | Application layer protocols |

### IP và Port

- Địa chỉ IP cụ thể: `203.0.113.5`
- Dải mạng CIDR: `203.0.113.0/24`
- Bất kỳ IP nào: `any`
- Toán tử phủ định `!`: ví dụ `!22` nghĩa là "không phải port 22"

### Chiều lưu lượng

- `->` — Một chiều (source → destination)
- `<>` — Hai chiều (hiếm dùng)

### Ví dụ headers

```
# Tất cả TCP traffic từ bất kỳ nguồn đến port 80
tcp any any -> any 80

# SSH traffic vào mạng 203.0.113.0/24 trên port KHÔNG phải 22
ssh any any -> 203.0.113.0/24 !22

# Tất cả traffic (catch-all)
ip any any -> any any
```

---

## Options (Tuỳ chọn)

Options nằm trong cặp ngoặc `(...)`, phân cách nhau bằng dấu `;`, thường có dạng `key:value;`.

### `content` — Kiểm tra nội dung gói tin

```
content:"uid=0|28|root|29|";
```

Ký tự trong `|...|` là hex. Ví dụ trên tìm chuỗi `uid=0(root)`.

Mặc định phân biệt chữ hoa/thường. Thêm `nocase;` để không phân biệt:

```
content:"your_domain.com"; nocase;
```

Kết hợp với application-layer keyword:

```
alert dns any any -> any any (msg:"DNS LOOKUP for your_domain.com"; dns.query; content:"your_domain.com"; nocase; sid:1000001;)
```

---

### `msg` — Thông điệp mô tả alert

```
msg:"SSH TRAFFIC on non-SSH port";
```

Nên viết ngắn gọn, đủ thông tin để hiểu tại sao alert được tạo ra.

---

### `sid` và `rev` — Signature ID và phiên bản

Mỗi signature **bắt buộc** phải có `sid` duy nhất:

```
sid:1000000;
```

Phạm vi SID:

| Phạm vi | Dùng cho |
|---|---|
| `1000000–1999999` | Rule tùy chỉnh (custom rules) |
| `2200000–2299999` | Suricata built-in rules |

Nếu hai rule có cùng SID, Suricata sẽ báo lỗi:

```
[ERRCODE: SC_ERR_DUPLICATE_SIG(176)] - Duplicate signature "..."
```

Tùy chọn `rev` dùng để theo dõi phiên bản của rule:

```
sid:1000000; rev:2;
```

---

### `reference` — Liên kết tài liệu tham khảo

```
reference:cve,2014-0160;
reference:url,heartbleed.com;
```

Danh sách prefix có trong file `/etc/suricata/reference.config`.

---

### `classtype` — Phân loại traffic

```
classtype:bad-unknown;
classtype:misc-attack;
classtype:misc-activity;
```

Các classtype và độ ưu tiên được định nghĩa trong `/etc/suricata/classification.config`:

```
config classification: bad-unknown,Potentially Bad Traffic, 2
config classification: misc-attack,Misc Attack, 2
```

Có thể override độ ưu tiên bằng option `priority`:

```
priority:1;
```

---

### `target` — Xác định host mục tiêu trong log

```
target:dest_ip;    # Traffic vào server
target:src_ip;     # Traffic ra từ server
```

Khi dùng `target`, log EVE sẽ bổ sung thông tin chi tiết:

```json
"source": {
  "ip": "127.0.0.1",
  "port": 35272
},
"target": {
  "ip": "203.0.113.1",
  "port": 2022
}
```

---

## Ví dụ thực tế — Viết rule tùy chỉnh

### 1. Phát hiện SSH trên port không chuẩn

```
alert ssh any any -> 203.0.113.0/24 !22 (msg:"SSH TRAFFIC on non-SSH port"; target:dest_ip; sid:1000000; rev:1;)
```

### 2. Phát hiện HTTP trên port không chuẩn

```
alert http any any -> 203.0.113.0/24 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000002;)
```

### 3. Phát hiện TLS trên port không chuẩn

```
alert tls any any -> 203.0.113.0/24 !443 (msg:"TLS TRAFFIC on non-TLS HTTP port"; classtype:misc-activity; sid:1000004;)
```

### 4. Phát hiện DNS query theo domain cụ thể

```
alert dns any any -> any any (msg:"DNS LOOKUP for example.com"; dns.query; content:"example.com"; nocase; sid:1000010;)
```

### 5. Kiểm tra heartbleed (ví dụ từ Suricata built-in)

```
alert tls any any -> any any (msg:"SURICATA TLS invalid heartbeat encountered, possible exploit attempt (heartbleed)"; flow:established; app-layer-event:tls.invalid_heartbeat_message; classtype:protocol-command-decode; reference:cve,2014-0160; sid:2230013; rev:1;)
```

---

## Thêm Custom Rules vào Suricata

Tạo file rule tùy chỉnh:

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

Thêm rules, sau đó chỉnh file cấu hình:

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

Tải lại rule mà không restart Suricata:

```bash
sudo kill -usr2 $(pidof suricata)
```

---

## Kết luận

Bạn đã nắm được:

- Ba phần cấu thành một Suricata signature: **Action**, **Header**, **Options**
- Các action: `alert`, `drop`, `reject`, `pass`
- Cách xây dựng header theo protocol, IP, port và chiều lưu lượng
- Các keyword quan trọng: `content`, `msg`, `sid`, `rev`, `reference`, `classtype`, `target`
- Cách viết và thêm custom rules vào Suricata

---

## Tham khảo

- [Suricata Rules Documentation](https://suricata.readthedocs.io/en/latest/rules/)
- [Emerging Threats SID Allocation](https://doc.emergingthreats.net/bin/view/Main/SidAllocation)

---

## Điều hướng

| | |
|---|---|
| **Trước đó:** | [← Phần 1: Cài đặt Suricata](part1-install-suricata.md) |
| **Tiếp theo:** | [Phần 3: Cấu hình Suricata IPS →](part3-suricata-ips.md) |
| **Tổng quan:** | [← README](README.md) |
