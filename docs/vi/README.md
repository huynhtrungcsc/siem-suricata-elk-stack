<div align="center">

# SIEM: Suricata + Elastic Stack

**Phát hiện, Ngăn chặn Xâm nhập Mạng và Phân tích Bảo mật Tập trung**

Hướng dẫn triển khai hệ thống SIEM production-grade trên Ubuntu 20.04 LTS

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](../../LICENSE)
[![Phiên bản](https://img.shields.io/badge/phiên%20bản-1.0.0-blue.svg)]()
[![Nền tảng](https://img.shields.io/badge/nền%20tảng-Ubuntu%2020.04%20LTS-E95420?logo=ubuntu&logoColor=white)]()
[![Stack](https://img.shields.io/badge/stack-Suricata%20|%20Elasticsearch%20|%20Kibana%20|%20Filebeat-005571?logo=elastic&logoColor=white)]()

<br/>

[← Về trang chính](../../README.md) · [🇬🇧 Read in English](../en/README.md)

</div>

---

## Mục lục

- [Tổng quan](#tổng-quan)
- [Kiến trúc hệ thống](#kiến-trúc-hệ-thống)
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Nội dung tài liệu](#nội-dung-tài-liệu)
- [Công nghệ sử dụng](#công-nghệ-sử-dụng)
- [Tham chiếu nhanh](#tham-chiếu-nhanh)
- [Ghi nhận](#ghi-nhận)

---

## Tổng quan

Bộ tài liệu này cung cấp hướng dẫn đầy đủ từ đầu đến cuối để triển khai hệ thống **Security Information and Event Management (SIEM)** sử dụng **Suricata** làm engine phát hiện và ngăn chặn mối đe dọa mạng, tích hợp với **Elastic Stack** (Elasticsearch, Kibana, Filebeat) trên Ubuntu 20.04 LTS.

Tài liệu bao phủ toàn bộ vòng đời vận hành:

| Giai đoạn | Phần | Mô tả |
|---|---|---|
| **Phát hiện** | Phần 1–2 | Triển khai Suricata, cấu hình signature, cập nhật ruleset |
| **Ngăn chặn** | Phần 3 | Bật IPS mode, route traffic qua Suricata với NFQUEUE |
| **Phân tích** | Phần 4–5 | Xây dựng SIEM với Elastic Stack, tạo detection rule và quản lý case |

---

## Kiến trúc hệ thống

```
┌─────────────────────────────────────┐         ┌─────────────────────────────────────┐
│           Suricata Server           │         │         Elasticsearch Server         │
│                                     │         │                                     │
│  Lưu lượng mạng ──► Suricata        │         │  Elasticsearch  ◄── Filebeat        │
│                      (IDS/IPS)      │  Mạng   │       │                             │
│                         │           │  nội bộ │       ▼                             │
│                    eve.json         │         │  Kibana (port 5601)                 │
│                         │           │         │   ├─ SIEM Dashboards               │
│                         ▼           │         │   ├─ Detection Rules               │
│                      Filebeat ──────────────► │   ├─ Timelines                     │
│                                     │         │   └─ Case Management               │
└─────────────────────────────────────┘         └─────────────────────────────────────┘
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
| Tường lửa | UFW đã cấu hình và bật |

### Elasticsearch Server

| Yêu cầu | Thông số |
|---|---|
| Hệ điều hành | Ubuntu 20.04 LTS |
| CPU | Tối thiểu 2 nhân |
| RAM | **Tối thiểu 4 GB** (khuyến nghị 8 GB) |
| Quyền truy cập | Người dùng non-root có `sudo` |
| Mạng | Private IP có thể kết nối từ Suricata server |

> **Lưu ý:** Có thể chạy tất cả dịch vụ trên một server cho mục đích thử nghiệm. Cấu hình hai server riêng biệt được khuyến nghị cho môi trường production để tránh tranh chấp tài nguyên giữa khối lượng kiểm tra packet của Suricata và JVM heap của Elasticsearch.

---

## Nội dung tài liệu

| Phần | Tiêu đề | Thời gian | Mô tả |
|---|---|---|---|
| [Phần 1](01-cai-dat-suricata.md) | **Cài đặt Suricata trên Ubuntu 20.04** | ~30 phút | Cài từ OISF PPA, cấu hình interface và Community Flow ID, tải ET Open ruleset, xác minh alert đầu tiên |
| [Phần 2](02-hieu-ve-signatures.md) | **Hiểu về Suricata Signatures** | ~20 phút | Cấu trúc signature, action, header, option — viết custom rule phát hiện SSH, HTTP và TLS |
| [Phần 3](03-cau-hinh-ips.md) | **Cấu hình Suricata như một IPS** | ~30 phút | Chuyển từ IDS sang IPS mode với NFQUEUE, route tất cả traffic qua Suricata, bảo toàn SSH access |
| [Phần 4](04-xay-dung-siem.md) | **Xây dựng SIEM với Elastic Stack** | ~45 phút | Triển khai Elasticsearch và Kibana với xpack security, chuyển Suricata EVE log qua Filebeat |
| [Phần 5](05-kibana-siem.md) | **Kibana SIEM: Rules, Timelines và Cases** | ~30 phút | Tạo detection rule, xây dựng timeline tương quan theo community_id, quản lý security case |

**Tổng thời gian ước tính:** ~2.5 giờ

---

## Công nghệ sử dụng

| Thành phần | Phiên bản | Vai trò |
|---|---|---|
| [Suricata](https://suricata.io) | 6.x | Engine phát hiện và ngăn chặn xâm nhập mạng |
| [Elasticsearch](https://www.elastic.co/elasticsearch/) | 7.x | Lưu trữ, lập chỉ mục và tương quan sự kiện phân tán |
| [Kibana](https://www.elastic.co/kibana) | 7.x | SIEM dashboard, detection rule, timeline và quản lý case |
| [Filebeat](https://www.elastic.co/beats/filebeat) | 7.x | Thu thập và chuyển tiếp log nhẹ |
| [ET Open Ruleset](https://rules.emergingthreats.net) | Mới nhất | Signature tình báo mối đe dọa từ cộng đồng (~30.000 rule) |
| Ubuntu | 20.04 LTS | Hệ điều hành |

---

## Tham chiếu nhanh

```bash
# Kiểm tra cấu hình Suricata trước khi áp dụng thay đổi
sudo suricata -T -c /etc/suricata/suricata.yaml -v

# Cập nhật ruleset threat intelligence
sudo suricata-update

# Tải lại rule mà không cần restart daemon
sudo kill -usr2 $(pidof suricata)

# Kiểm tra trạng thái dịch vụ Suricata
sudo systemctl status suricata.service

# Theo dõi log Suricata trong thời gian thực
sudo tail -f /var/log/suricata/suricata.log

# Truy vấn EVE log theo Suricata alert cụ thể (thay SID tùy ý)
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json

# Kích hoạt alert test (khớp SID 2100498)
curl http://testmynids.org/uid/index.html
```

---

## Ghi nhận

Bộ tài liệu này được biên soạn với tham chiếu từ chuỗi hướng dẫn gốc của [**Jamon Camisso**](https://www.digitalocean.com/community/users/jamonation), đăng trên nền tảng [DigitalOcean Community](https://www.digitalocean.com/community). Nội dung trong repository này đã được tái cấu trúc độc lập, mở rộng đáng kể, dịch sang tiếng Việt, và bổ sung thêm ngữ cảnh lý thuyết, kinh nghiệm vận hành thực tế và tài liệu về lỗi thường gặp.

---

*[← Về trang chính Repository](../../README.md)*
