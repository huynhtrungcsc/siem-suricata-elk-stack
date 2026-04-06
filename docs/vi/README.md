---
title: "Xây dựng hệ thống SIEM với Suricata và Elastic Stack — Tài liệu hướng dẫn"
description: "Hướng dẫn từng bước triển khai hệ thống Security Information and Event Management (SIEM) sử dụng Suricata IDS/IPS kết hợp Elastic Stack trên Ubuntu 20.04."
author: "Jamon Camisso"
date: 2022-03-01
category: Bảo mật
series: "SIEM với Suricata và Elastic Stack"
tags:
  - suricata
  - elasticsearch
  - kibana
  - filebeat
  - siem
  - ubuntu
  - bảo-mật
  - ids
  - ips
---

# Xây dựng hệ thống SIEM với Suricata và Elastic Stack

Bộ tài liệu hướng dẫn đầy đủ để triển khai hệ thống **Security Information and Event Management (SIEM)** sử dụng **Suricata** làm engine phát hiện mạng, tích hợp với **Elasticsearch**, **Kibana** và **Filebeat** trên Ubuntu 20.04.

---

## Mục lục

- [Kiến trúc hệ thống](#kiến-trúc-hệ-thống)
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Nội dung tài liệu](#nội-dung-tài-liệu)
- [Công nghệ sử dụng](#công-nghệ-sử-dụng)
- [Tham chiếu nhanh](#tham-chiếu-nhanh)

---

## Kiến trúc hệ thống

```
                        ┌───────────────────────────────┐
                        │         Suricata Server        │
                        │                               │
  Lưu lượng mạng ──────►│  Suricata (IDS/IPS)           │
                        │       │                       │
                        │       │ eve.json              │
                        │       ▼                       │
                        │  Filebeat ──────────────────────────────┐
                        └───────────────────────────────┘         │
                                                              Mạng nội bộ
                        ┌───────────────────────────────┐         │
                        │      Elasticsearch Server      │         │
                        │                               │         │
                        │  Elasticsearch (port 9200) ◄──────────┘
                        │       │                       │
                        │       ▼                       │
                        │  Kibana (port 5601)            │
                        │   - SIEM Dashboards            │
                        │   - Detection Rules            │
                        │   - Timelines & Cases          │
                        └───────────────────────────────┘
```

---

## Yêu cầu hệ thống

### Suricata Server

| Yêu cầu | Thông số |
|---|---|
| Hệ điều hành | Ubuntu 20.04 LTS |
| CPU | Tối thiểu 2 nhân |
| RAM | Tối thiểu 4 GB |
| Quyền truy cập | Người dùng non-root có `sudo` |
| Tường lửa | UFW đã bật |

### Elasticsearch Server

| Yêu cầu | Thông số |
|---|---|
| Hệ điều hành | Ubuntu 20.04 LTS |
| CPU | Tối thiểu 2 nhân |
| RAM | **Tối thiểu 4 GB** (khuyến nghị 8 GB) |
| Quyền truy cập | Người dùng non-root có `sudo` |
| Mạng | Private IP có thể liên lạc với Suricata server |

> **Lưu ý:** Có thể chạy tất cả các dịch vụ trên một server cho mục đích thử nghiệm, nhưng cấu hình hai server riêng biệt được khuyến nghị cho môi trường production.

---

## Nội dung tài liệu

| Phần | Tiêu đề | Mô tả |
|---|---|---|
| [Phần 1](01-cai-dat-suricata.md) | **Cài đặt Suricata trên Ubuntu 20.04** | Cài đặt Suricata, cấu hình network interface, cập nhật ruleset và kiểm tra hoạt động |
| [Phần 2](02-hieu-ve-signatures.md) | **Hiểu về Suricata Signatures** | Cấu trúc signature, các action, header, option và cách viết custom rule |
| [Phần 3](03-cau-hinh-ips.md) | **Cấu hình Suricata như một IPS** | Bật IPS mode với NFQUEUE, cấu hình UFW để route traffic qua Suricata |
| [Phần 4](04-xay-dung-siem.md) | **Xây dựng SIEM với Elastic Stack** | Triển khai Elasticsearch và Kibana, cấu hình Filebeat để chuyển log Suricata |
| [Phần 5](05-kibana-siem.md) | **Kibana SIEM: Rules, Timelines và Cases** | Tạo detection rule, xây dựng timeline điều tra và quản lý security case |

---

## Công nghệ sử dụng

| Thành phần | Phiên bản | Vai trò |
|---|---|---|
| [Suricata](https://suricata.io) | 6.x | Phát hiện và ngăn chặn mối đe dọa mạng |
| [Elasticsearch](https://www.elastic.co/elasticsearch/) | 7.x | Lưu trữ, lập chỉ mục và tương quan sự kiện |
| [Kibana](https://www.elastic.co/kibana) | 7.x | Trực quan hóa, SIEM dashboard và quản lý case |
| [Filebeat](https://www.elastic.co/beats/filebeat) | 7.x | Thu thập và chuyển tiếp log |
| [ET Open Ruleset](https://rules.emergingthreats.net) | Mới nhất | Signature tình báo mối đe dọa từ cộng đồng |

---

## Tham chiếu nhanh

```bash
# Tải lại Suricata rules mà không cần restart
sudo kill -usr2 $(pidof suricata)

# Kiểm tra cấu hình Suricata
sudo suricata -T -c /etc/suricata/suricata.yaml -v

# Cập nhật ruleset
sudo suricata-update

# Truy vấn EVE log theo signature ID
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json

# Kiểm tra trạng thái Suricata
sudo systemctl status suricata.service
```

---

## Bắt đầu

Bắt đầu từ [Phần 1: Cài đặt Suricata trên Ubuntu 20.04](01-cai-dat-suricata.md).

---

*Tài liệu dựa trên chuỗi hướng dẫn của [Jamon Camisso](https://www.digitalocean.com/community/users/jamonation) — DigitalOcean Community.*
