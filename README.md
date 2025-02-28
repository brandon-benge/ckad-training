# CKAD Training - Monitoring & AI Ops Pipeline

This repository provides scripts to deploy and manage a **monitoring and AI Ops pipeline** using **Prometheus**, **Thanos**, **MinIO**, **Kafka**, **OpenStack**, and **Apache Spark**. The goal is to enable efficient data collection, processing, and storage to build an AI-powered system for predictive scaling.

## 💜 Overview
The project consists of the following components:

### **Monitoring Stack**
- **MinIO** (Object Storage for Thanos)
- **Prometheus** (Metrics Collection with Thanos Sidecar)
- **Thanos** (Long-Term Storage and Querying for Prometheus Metrics)
- **Grafana** (Visualization Dashboard)

### **AI Ops Pipeline**
- **OpenStack** (Extracts Prometheus data and pushes it to Kafka)
- **Kafka** (Message broker for real-time data ingestion)
- **Apache Spark** (Structured Streaming job to transform data into Hudi format)
- **Hudi + MinIO** (Long-term storage of structured data)
- **Machine Learning** (Future phase - train models on stored data)

The entire stack is designed to run on **Rancher Desktop on a local Mac**, with a **small resource footprint**. Due to hardware constraints, we plan to **deploy the pipeline in phases**, rather than running everything simultaneously.

---

## 🚀 Installation Steps

### 1️⃣ Start Rancher Desktop (if not running)
\`\`\`bash
/bin/bash scripts/rancher/start_rancher.sh
\`\`\`

### 2️⃣ Install MinIO
\`\`\`bash
/bin/bash scripts/minio/install_minio.sh
\`\`\`

### 3️⃣ Install Prometheus & Thanos
\`\`\`bash
/bin/bash scripts/prometheus/install_prometheus.sh
/bin/bash scripts/thanos/install_thanos.sh
\`\`\`

### 4️⃣ Install Kafka
\`\`\`bash
/bin/bash scripts/kafka/install_kafka.sh
\`\`\`

### 5️⃣ Install OpenStack (TBD)
\`\`\`bash
/bin/bash scripts/openstack/install_openstack.sh
\`\`\`

### 6️⃣ Deploy Apache Spark Job (TBD)
\`\`\`bash
/bin/bash scripts/spark/install_spark.sh
\`\`\`

---

## 🛑 Uninstallation Steps

To remove all components, run:

\`\`\`bash
/bin/bash scripts/thanos/uninstall_thanos.sh
/bin/bash scripts/prometheus/uninstall_prometheus.sh
/bin/bash scripts/minio/uninstall_minio.sh
/bin/bash scripts/kafka/uninstall_kafka.sh
/bin/bash scripts/openstack/uninstall_openstack.sh
/bin/bash scripts/spark/uninstall_spark.sh
/bin/bash scripts/rancher/stop_rancher.sh
\`\`\`

---

## 🛠️ Troubleshooting & Verification

### 🔎 Verify Kafka Brokers
\`\`\`bash
kubectl get pods -n kafka
kubectl logs -n kafka -l app.kubernetes.io/name=kafka
\`\`\`

### 🔎 Verify Prometheus Logs
\`\`\`bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -c prometheus
\`\`\`

### 🔎 Verify Thanos Sidecar Logs
\`\`\`bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -c thanos-sidecar | grep "uploaded"
\`\`\`

### 🔎 Verify MinIO Service
\`\`\`bash
kubectl get pods -n minio
kubectl get svc -n minio
\`\`\`

---

## 📊 Accessing Dashboards

### **MinIO**
- URL: [http://localhost:9001](http://localhost:9001)
- Default login: \`minio\` / \`minio123\`

### **Grafana**
- URL: [http://localhost:3000](http://localhost:3000)
- Default login: \`admin\` / \`prom-operator\`

### **Prometheus**
- URL: [http://localhost:9090](http://localhost:9090)

### **Thanos Query**
- URL: [http://localhost:10902](http://localhost:10902)

---

## 📌 To-Do List

1️⃣ **Fix Kafka installation**
- Resolve authentication issues and ensure brokers are properly registered with the controller.

2️⃣ **Integrate OpenStack with Prometheus & Kafka**
- Extract Prometheus data and push it into Kafka for real-time processing.

3️⃣ **Create Apache Spark Streaming Job**
- Use **Spark Structured Streaming** to consume Kafka data and write it to MinIO in **Hudi format**.

4️⃣ **Phase-based Deployment Strategy**
- Since the system runs on a local Mac with limited capacity, implement **phased execution** to avoid overloading resources.

5️⃣ **Future Work: Train AI Models**
- In a separate project, use the structured data from MinIO to train **predictive AI models for AI Ops**.

---

## 🔄 Project Status & Future Plans

🚨 **Currently on hold**: I am going on paternity leave for **6 weeks**, so this project will be paused.  
📌 **Next Steps**: After returning, I will focus on fixing Kafka and integrating OpenStack.

If you’re interested in contributing, feel free to fork the repo or raise an issue!

---

## ✅ Conclusion
This project is evolving into a **real-time AI Ops pipeline**, enabling data-driven scaling decisions. Stay tuned for future updates! 🚀