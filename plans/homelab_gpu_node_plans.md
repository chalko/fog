# GPU Node Build Plans & Cost/Token Analysis

This document details three hardware tiers for building a local GPU-accelerated Kubernetes worker node using parts from local retail (Best Buy on Galleria Blvd in Roseville, CA). It analyzes performance (TPS), monthly power/hardware costs, and Cost Per Million Tokens (CPMT) under 4-hour and 16-hour daily batch workloads, compared to Google Gemini API costs.

---

## 1. Hardware Specifications & Upfront Costs

All components are selected to handle high electrical load and fit the physical dimensions of dual-GPU setups.

### Build B: The Budget Build (Total: ~$2,000)
*Designed for high-speed execution of smaller models (8B).*

* **GPUs**: 2x Nvidia RTX 4070 SUPER 12GB (Total 24 GB VRAM) — **$1,200**
* **CPU**: AMD Ryzen 7 7700X (8 Cores) — **$290**
* **Motherboard**: MSI MAG B650 Tomahawk WiFi — **$200**
* **RAM**: 64 GB DDR5 (2x32GB) — **$180**
* **Storage**: 2 TB Gen4 NVMe SSD — **$110**
* **Power Supply**: 1000W Gold Rated PSU (Modular) — **$160**
* **Case & Cooling**: Fractal Design Pop XL Air + Noctua air cooler — **$140**

### Build A: The Sweet Spot (Total: ~$3,000)
*Designed to run medium-sized reasoning models (32B) at high speed.*

* **GPUs**: 2x Nvidia RTX 4080 SUPER 16GB (Total 32 GB VRAM) — **$2,000**
* **CPU**: AMD Ryzen 9 7900X (12 Cores) — **$350**
* **Motherboard**: ASUS ProArt X670E (Allows dual-GPU spacing at x8/x8) — **$280**
* **RAM**: 64 GB DDR5 (2x32GB) — **$180**
* **Storage**: 2 TB Gen4 NVMe SSD (High speed) — **$140**
* **Power Supply**: 1300W Gold Rated PSU — **$250**
* **Case & Cooling**: Fractal Design Torrent + 360mm Liquid AIO — **$280**

### Build C: The Flagship Build (Total: ~$4,200)
*Designed to run large local models (70B) at comfortable reading speeds.*

* **GPUs**: 2x Nvidia RTX 4090 24GB (Total 48 GB VRAM) — **$3,200**
* **CPU**: AMD Ryzen 9 7950X (16 Cores) — **$500**
* **Motherboard**: ASUS ProArt X670E — **$280**
* **RAM**: 64 GB DDR5 (2x32GB) — **$180**
* **Storage**: 2 TB Gen4 NVMe SSD (High speed) — **$140**
* **Power Supply**: 1600W Titanium/Platinum PSU — **$280**
* **Case & Cooling**: Lian Li O11 Dynamic XL + High-airflow fans & Liquid AIO — **$300**

---

## 2. Performance (Tokens Per Second - TPS)

Throughput estimates running optimized backends (like vLLM) on local hardware:

| Model Tier | Ideal Local Model | Build B (2x 4070S) | Build A (2x 4080S) | Build C (2x 4090) |
| :--- | :--- | :--- | :--- | :--- |
| **8B Model** | `llama3:8b` (Q8 / FP16) | **60 - 75 TPS** | 75 - 90 TPS | 85 - 110 TPS |
| **32B Model** | `Qwen2.5-32B` (Q4 / Q8) | *N/A (Fits but slow)* | **35 - 45 TPS** | 45 - 55 TPS |
| **70B Model** | `llama3:70b` (Q4_K_M) | *N/A (Exceeds VRAM)* | *N/A (Exceeds VRAM)* | **30 - 35 TPS** |

---

## 3. Cost Per Million Tokens (CPMT) Analysis

> [!NOTE]
> **CPMT (Cost Per Million Tokens)** is the standard industry metric for measuring LLM operation costs.
> All calculations assume a **3-year hardware amortization** and average **$0.16/kWh** electricity pricing.

### A. 4-Hour Daily Batch Workload (Continuous generation 4h/day, Idle 20h/day)

* **Build B (Total: $71.69 / month)**:
  * Monthly Generation: **30.24 Million tokens**
  * **CPMT: $2.37**
* **Build A (Total: $103.30 / month)**:
  * Monthly Generation: **17.28 Million tokens**
  * **CPMT: $5.97**
* **Build C (Total: $142.59 / month)**:
  * Monthly Generation: **13.82 Million tokens**
  * **CPMT: $10.33**

### B. 16-Hour Daily Batch Workload (Continuous generation 16h/day, Idle 8h/day)

* **Build B (Total: $102.79 / month)**:
  * Monthly Generation: **120.96 Million tokens**
  * **CPMT: $0.85**
* **Build A (Total: $145.92 / month)**:
  * Monthly Generation: **69.12 Million tokens**
  * **CPMT: $2.11**
* **Build C (Total: $199.61 / month)**:
  * Monthly Generation: **55.30 Million tokens**
  * **CPMT: $3.61**

---

## 4. Local CPMT vs. Google Gemini Costs

This compares the local token cost against Google Gemini API's **Blended Rate** (estimating a standard production ratio of 80% input tokens / 20% output tokens).

* **Gemini 3.5 Flash Blended Rate**: **$3.00** per 1M tokens
* **Gemini 3.1 Pro Blended Rate**: **$4.00** per 1M tokens

### CPMT Comparison ($/1M Tokens)

| Build / Model | CPMT (4-Hour Load) | CPMT (16-Hour Load) | Gemini Equivalent Model | Gemini Blended CPMT |
| :--- | :--- | :--- | :--- | :--- |
| **Build B** (`llama3:8b` Q8) | **$2.37** | **$0.85** | Gemini 3.5 Flash | **$3.00** |
| **Build A** (`Qwen2.5-32B` Q4) | **$5.97** | **$2.11** | Gemini 3.5 Flash / Pro | **$3.00 – $4.00** |
| **Build C** (`llama3:70b` Q4) | **$10.33** | **$3.61** | Gemini 3.1 Pro | **$4.00** |

> [!TIP]
> **Summary Decision Matrix**:
> * Under **4-hour loads**, using cloud APIs is more cost-effective for larger models.
> * Under **16-hour loads**, the local homelab hardware **saves money on every token** across all tiers, with Build B running 3.5x cheaper than Gemini Flash, and Build C beating Gemini Pro.
