# SIEM System: Suricata + Elastic Stack

> Hướng dẫn triển khai hệ thống **Security Information and Event Management (SIEM)** sử dụng Suricata kết hợp với Elastic Stack (Elasticsearch, Kibana, Filebeat) trên Ubuntu 20.04.

---

## Tổng quan

Hệ thống SIEM được xây dựng trong tài liệu này gồm hai thành phần chính:

| Thành phần | Vai trò |
|---|---|
| **Suricata** | Network Security Monitoring — phát hiện và ngăn chặn lưu lượng mạng đáng ngờ |
| **Elasticsearch** | Lưu trữ, lập chỉ mục, tương quan và tìm kiếm sự kiện bảo mật |
| **Kibana** | Hiển thị, phân tích và điều tra sự kiện bảo mật theo thời gian thực |
| **Filebeat** | Đọc file log `eve.json` của Suricata và chuyển tiếp đến Elasticsearch |

Luồng dữ liệu tổng thể:

```
Network Traffic
      │
      ▼
  Suricata (IDS/IPS)
      │  eve.json
      ▼
  Filebeat
      │
      ▼
  Elasticsearch ──► Kibana (SIEM Dashboards)
```

---

## Nội dung hướng dẫn

Tài liệu được chia thành **5 phần**, theo thứ tự từ cơ bản đến nâng cao:

| # | Tiêu đề | Mô tả |
|---|---|---|
| [Phần 1](part1-install-suricata.md) | **Cài đặt Suricata trên Ubuntu 20.04** | Cài đặt, cấu hình ban đầu, cập nhật ruleset và kiểm tra hoạt động |
| [Phần 2](part2-suricata-signatures.md) | **Hiểu về Suricata Signatures** | Cấu trúc rule, các keyword quan trọng và cách viết rule tùy chỉnh |
| [Phần 3](part3-suricata-ips.md) | **Cấu hình Suricata IPS** | Bật chế độ IPS (Intrusion Prevention System) với NFQUEUE và UFW |
| [Phần 4](part4-siem-elastic-stack.md) | **Xây dựng SIEM với Elastic Stack** | Tích hợp Elasticsearch, Kibana và Filebeat với Suricata |
| [Phần 5](part5-kibana-siem-apps.md) | **Tạo Rules, Timelines và Cases trong Kibana** | Sử dụng công cụ SIEM của Kibana để điều tra và quản lý sự kiện |

---

## Yêu cầu hệ thống

### Server chạy Suricata
- Ubuntu 20.04
- Tối thiểu 2 CPU, 4GB RAM
- Người dùng non-root có quyền `sudo`
- UFW firewall đã được bật

### Server chạy Elastic Stack (Elasticsearch + Kibana)
- Ubuntu 20.04
- Tối thiểu 2 CPU, 4GB RAM
- Có khả năng giao tiếp với Suricata server qua private IP

> **Lưu ý:** Có thể chạy tất cả các thành phần trên cùng một server để thử nghiệm, nhưng không khuyến khích cho môi trường production.

---

## Kiến trúc triển khai

```
┌─────────────────────────┐        ┌──────────────────────────────┐
│      Suricata Server    │        │      Elasticsearch Server     │
│                         │        │                              │
│  ┌─────────────────┐    │        │  ┌────────────────────────┐  │
│  │    Suricata     │    │        │  │     Elasticsearch      │  │
│  │  (IDS/IPS Mode) │    │        │  │      Port 9200         │  │
│  └────────┬────────┘    │        │  └──────────┬─────────────┘  │
│           │ eve.json    │        │             │                │
│  ┌────────▼────────┐    │ Private│  ┌──────────▼─────────────┐  │
│  │    Filebeat     │────┼───IP──►│  │        Kibana          │  │
│  │  (log shipper)  │    │        │  │      Port 5601         │  │
│  └─────────────────┘    │        │  └────────────────────────┘  │
└─────────────────────────┘        └──────────────────────────────┘
```

---

## Công nghệ sử dụng

- **Suricata** v6.x — [suricata.io](https://suricata.io)
- **Elasticsearch** v7.x — [elastic.co](https://www.elastic.co/elasticsearch/)
- **Kibana** v7.x — [elastic.co/kibana](https://www.elastic.co/kibana)
- **Filebeat** v7.x — [elastic.co/beats/filebeat](https://www.elastic.co/beats/filebeat)
- **ET Open Ruleset** — [emergingthreats.net](https://rules.emergingthreats.net)

---

## Bắt đầu

Bắt đầu từ [Phần 1: Cài đặt Suricata trên Ubuntu 20.04](part1-install-suricata.md).

---

*Tài liệu được biên soạn dựa trên hướng dẫn của [Jamon Camisso](https://www.digitalocean.com/community/users/jamonation) — DigitalOcean Community.*
