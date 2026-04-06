---
title: "Cài đặt Suricata trên Ubuntu 20.04"
description: "Hướng dẫn từng bước cài đặt Suricata từ kho OISF, cấu hình network interface, quản lý ruleset với suricata-update và kiểm tra khả năng phát hiện mối đe dọa trên Ubuntu 20.04."
author: "Jamon Camisso"
date: 2021-10-23
category: Bảo mật
series: "SIEM với Suricata và Elastic Stack"
part: 1
tags:
  - suricata
  - ubuntu
  - bảo-mật
  - ids
  - ips
  - mạng
  - cài-đặt
---

# Phần 1 — Cài đặt Suricata trên Ubuntu 20.04

| | |
|---|---|
| **Chuỗi hướng dẫn** | SIEM với Suricata và Elastic Stack |
| **Phần** | 1 / 5 |
| **Độ khó** | Trung bình |
| **Thời gian** | ~30 phút |
| **Hệ điều hành** | Ubuntu 20.04 LTS |

---

## Mục lục

- [Giới thiệu](#giới-thiệu)
- [Yêu cầu](#yêu-cầu)
- [Bước 1 — Cài đặt Suricata](#bước-1--cài-đặt-suricata)
- [Bước 2 — Cấu hình ban đầu](#bước-2--cấu-hình-ban-đầu)
  - [Bật Community Flow ID](#bật-community-flow-id-khuyến-nghị)
  - [Cấu hình Network Interface](#cấu-hình-network-interface)
  - [Bật Live Rule Reloading](#bật-live-rule-reloading)
- [Bước 3 — Cập nhật Rulesets](#bước-3--cập-nhật-rulesets)
- [Bước 4 — Kiểm tra cấu hình](#bước-4--kiểm-tra-cấu-hình)
- [Bước 5 — Khởi chạy Suricata](#bước-5--khởi-chạy-suricata)
- [Bước 6 — Kiểm tra phát hiện](#bước-6--kiểm-tra-phát-hiện)
- [Bước 7 — Xử lý Alerts](#bước-7--xử-lý-alerts)
- [Tóm tắt](#tóm-tắt)

---

## Giới thiệu

**Suricata** là công cụ Network Security Monitoring (NSM) mã nguồn mở, kiểm tra lưu lượng mạng dựa trên các signature rule được xây dựng bởi cộng đồng và người dùng. Suricata có khả năng tạo log sự kiện, kích hoạt cảnh báo và chặn các gói tin độc hại khớp với mẫu mối đe dọa cụ thể.

Suricata hoạt động theo hai chế độ chính:

| Chế độ | Hành vi |
|---|---|
| **IDS** *(Intrusion Detection System)* | Giám sát thụ động; chỉ ghi log và tạo cảnh báo |
| **IPS** *(Intrusion Prevention System)* | Giám sát chủ động và chặn lưu lượng đáng ngờ |

Cài đặt mặc định sử dụng IDS mode. Hướng dẫn này bao gồm cài đặt, cấu hình ban đầu, quản lý ruleset và kiểm tra cơ bản. IPS mode được đề cập trong [Phần 3](03-cau-hinh-ips.md).

---

## Yêu cầu

- Ubuntu 20.04 server với **2+ CPU** và **4+ GB RAM**
- Người dùng non-root có quyền `sudo`
- UFW firewall đã được cấu hình và bật

---

## Bước 1 — Cài đặt Suricata

Thêm PPA repository của Open Information Security Foundation (OISF):

```bash
sudo add-apt-repository ppa:oisf/suricata-stable
```

Nhấn **ENTER** để xác nhận. Cài đặt Suricata:

```bash
sudo apt install suricata
```

Bật dịch vụ khởi động cùng hệ thống:

```bash
sudo systemctl enable suricata.service
```

Dừng dịch vụ trước khi thực hiện thay đổi cấu hình:

```bash
sudo systemctl stop suricata.service
```

---

## Bước 2 — Cấu hình ban đầu

Mở file cấu hình chính:

```bash
sudo nano /etc/suricata/suricata.yaml
```

### Bật Community Flow ID *(Khuyến nghị)*

Community Flow ID cung cấp định danh nhất quán cho các network flow — cần thiết khi tương quan sự kiện Suricata với Elasticsearch hoặc Zeek.

Điều hướng đến dòng 120 (trong nano: `CTRL+_`, nhập `120`):

```yaml
# /etc/suricata/suricata.yaml  (dòng ~120)

      # enable/disable the community id feature.
      community-id: true
```

### Cấu hình Network Interface

Xác định network interface mặc định:

```bash
ip -p -j route show default
```

Ví dụ kết quả:

```json
[ {
        "dst": "default",
        "gateway": "203.0.113.254",
        "dev": "eth0",
        "protocol": "static"
    } ]
```

Ghi nhớ giá trị `"dev"`. Cập nhật phần `af-packet` (dòng ~580):

```yaml
# /etc/suricata/suricata.yaml  (dòng ~580)

af-packet:
  - interface: eth0    # Thay bằng tên interface thực tế
    cluster-id: 99
```

Để giám sát **nhiều interface**, thêm các mục trước `- interface: default`. Mỗi interface cần có `cluster-id` riêng biệt:

```yaml
  - interface: eth0
    cluster-id: 99

  - interface: enp0s1
    cluster-id: 98

  - interface: default
```

### Bật Live Rule Reloading

Thêm vào cuối file:

```yaml
# /etc/suricata/suricata.yaml  (cuối file)

detect-engine:
  - rule-reload: true
```

Với cài đặt này, tải lại rule mà không cần khởi động lại Suricata:

```bash
sudo kill -usr2 $(pidof suricata)
```

Lưu và đóng file (`CTRL+X`, `Y`, `ENTER`).

---

## Bước 3 — Cập nhật Rulesets

Suricata tích hợp `suricata-update` — công cụ quản lý ruleset từ các nguồn threat intelligence.

Tải xuống **ET Open** ruleset từ Emerging Threats:

```bash
sudo suricata-update
```

Kết quả mong đợi:

```
19/10/2021 -- 19:31:03 - <Info> -- Fetching https://rules.emergingthreats.net/...
 100% - 3044855/3044855
...
19/10/2021 -- 19:31:06 - <Info> -- Writing rules to /var/lib/suricata/rules/suricata.rules:
  total: 31011; enabled: 23649; added: 31011
```

### Thêm nguồn ruleset khác

Xem danh sách nhà cung cấp:

```bash
sudo suricata-update list-sources
```

Bật thêm nguồn (ví dụ):

```bash
sudo suricata-update enable-source tgreen/hunting
sudo suricata-update
```

---

## Bước 4 — Kiểm tra cấu hình

Chạy Suricata ở chế độ test để xác thực cấu hình và toàn bộ rule đã tải:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```

> **Lưu ý:** Quá trình kiểm tra có thể mất 1–2 phút tùy số lượng rule.

Kết quả thành công kết thúc bằng:

```
<Notice> - Configuration provided was successfully loaded. Exiting.
```

Nếu có lỗi, Suricata hiển thị mã lỗi và mô tả cụ thể. Ví dụ, file rules không tồn tại:

```
<Warning> - [ERRCODE: SC_ERR_NO_RULES(42)] - No rule files match the pattern /var/lib/suricata/rules/test.rules
```

---

## Bước 5 — Khởi chạy Suricata

Khởi động dịch vụ:

```bash
sudo systemctl start suricata.service
```

Xác minh trạng thái:

```bash
sudo systemctl status suricata.service
```

Kết quả mong đợi:

```
● suricata.service - LSB: Next Generation IDS/IPS
     Active: active (running) since Thu 2021-10-21 18:22:56 UTC
...
Starting suricata in IDS (af-packet) mode... done.
```

Theo dõi log cho đến khi Suricata khởi tạo hoàn tất:

```bash
sudo tail -f /var/log/suricata/suricata.log
```

Suricata đã sẵn sàng khi xuất hiện:

```
<Info> - All AFP capture threads are running.
```

Nhấn `CTRL+C` để dừng lệnh tail.

---

## Bước 6 — Kiểm tra phát hiện

Kích hoạt rule `sid:2100498` với HTTP request:

```bash
curl http://testmynids.org/uid/index.html
```

Server trả về response giả lập (`uid=0(root) gid=0(root)...`) được thiết kế để khớp rule này.

### Kiểm tra `fast.log`

```bash
grep 2100498 /var/log/suricata/fast.log
```

Kết quả mong đợi:

```
10/21/2021-18:35:57.247239  [**] [1:2100498:7] GPL ATTACK_RESPONSE id check returned root [**]
[Classification: Potentially Bad Traffic] [Priority: 2] {TCP} 204.246.178.81:80 -> 203.0.113.1:36364
```

### Kiểm tra `eve.json` với `jq`

Cài đặt `jq` nếu chưa có:

```bash
sudo apt install jq
```

Truy vấn EVE log theo signature cụ thể:

```bash
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json
```

Kết quả mong đợi (rút gọn):

```json
{
  "timestamp": "2021-10-21T19:42:47.368856+0000",
  "event_type": "alert",
  "src_ip": "204.246.178.81",
  "dest_ip": "203.0.113.1",
  "community_id": "1:XLNse90QNVTgyXCWN9JDovC0XF4=",
  "alert": {
    "action": "allowed",
    "signature_id": 2100498,
    "signature": "GPL ATTACK_RESPONSE id check returned root",
    "category": "Potentially Bad Traffic"
  }
}
```

Bản ghi khớp trong một trong hai file log xác nhận Suricata đang kiểm tra traffic và tạo alert thành công.

---

## Bước 7 — Xử lý Alerts

Sau khi alerts hoạt động, có thể áp dụng các chiến lược phản hồi:

| Chiến lược | Mô tả |
|---|---|
| **Chỉ ghi log** | Lưu alerts trong EVE log để kiểm toán và điều tra |
| **Chặn bằng tường lửa** | Phân tích EVE log với `jq`, trích xuất IP nguồn, thêm UFW rule |
| **IPS mode** | Chuyển `alert` thành `drop` và bật NFQUEUE (xem [Phần 3](03-cau-hinh-ips.md)) |
| **Tích hợp SIEM** | Chuyển log đến Elasticsearch qua Filebeat (xem [Phần 4](04-xay-dung-siem.md)) |

---

## Tóm tắt

Trong hướng dẫn này, bạn đã:

- Cài đặt Suricata từ OISF stable PPA
- Cấu hình Community Flow ID, network interface và live rule reloading
- Tải xuống ET Open ruleset bằng `suricata-update`
- Kiểm tra cấu hình và khởi chạy Suricata daemon
- Tạo alert thử nghiệm và xác nhận trong `fast.log` và `eve.json`

---

## Tài liệu tham khảo

- [Tài liệu chính thức Suricata](https://suricata.readthedocs.io/)
- [OISF Suricata GitHub](https://github.com/OISF/suricata)
- [ET Open Ruleset](https://rules.emergingthreats.net)

---

## Điều hướng

| | |
|---|---|
| **← Trước** | [README — Tổng quan chuỗi](README.md) |
| **Tiếp theo →** | [Phần 2: Hiểu về Suricata Signatures](02-hieu-ve-signatures.md) |
